import 'package:flutter/material.dart';

import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_btc_deposit.dart';
import '../../bridge/api/celaut_deposit.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/deposit_strings.dart';
import '../../celaut/host_port.dart';
import '../../celaut/payers.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../services/network_controller.dart';
import '../../services/wallet_service.dart';
import '../../services/wallet_sync_controller.dart';
import '../../theme/argus_theme.dart';
import '../confirm_transaction_sheet.dart';
import '../settings/settings_shared.dart';
import '../bitcoin/btc_deposit_screen.dart';
import '../widgets/soft_card.dart';
import 'client_unknown_dialog.dart';
import 'deposit_confirm.dart';

/// The smallest deposit: the minimum value of an Ergo box.
const minDepositNano = 1000000;

/// The largest limit of the deposits to one node: 1 ERG (`docs/celaut/ui.md`, section 3).
const maxLimitNano = 1000000000;

/// What the deposit screen needs from the wallets of the app. The app uses
/// [AppDepositWallets]; tests give their own.
///
/// The wallet of the app pays (`docs/celaut/ui.md`, section 1). Before the deposit the
/// screen asks for the fingerprint or screen lock for the wallet ([FullWallets.unlock]), also when
/// it is already open.
abstract class DepositWallets implements FullWallets {
  /// Prepare the deposit (`celaut_deposit_prepare`) with the addresses of [payer]. The
  /// payer must be the open wallet.
  Future<DepositPreparedView> prepare(PayerWallet payer, NodeAddress node, int amountNanoErg);

  /// Sign and send the preparation, as every send of the wallet. Gives the
  /// transaction id.
  Future<String> send(int preparationId);
}

/// The wallets of the app.
class AppDepositWallets extends AppFullWallets implements DepositWallets {
  const AppDepositWallets();

  @override
  Future<DepositPreparedView> prepare(PayerWallet payer, NodeAddress node, int amountNanoErg) {
    // The addresses of the open wallet, from its sync.
    if (!walletSyncController.ownsWallet(payer.walletId)) {
      throw StateError(DepositStrings.payerLocked);
    }
    final args = walletSyncController.routeArgs;
    return walletService.prepareCelautDeposit(
      payerWalletId: payer.walletId,
      node: node,
      senderAddress: args.senderAddress,
      spendAddresses: args.historyAddresses,
      changeAddress: args.changeAddress,
      amountNanoErg: amountNanoErg,
      nodeUrl: networkController.activeUrl,
    );
  }

  @override
  Future<String> send(int preparationId) async {
    final sent = await walletService.sendErgDetailed(preparationId: preparationId);
    return sent['tx_id'] as String? ?? '';
  }
}

/// Debug screen of milestone M3: deposit ERG to a node from the wallet. Check the node, prepare the deposit, confirm it in the confirmation
/// sheet of the wallet, wait until the explorer shows the box, then the node checks it
/// once (`Payable`). With no wallet in the app, the screen says so and does not start.
class DepositScreen extends StatefulWidget {
  const DepositScreen({
    super.key,
    this.wallets = const AppDepositWallets(),
    this.newClient,
    this.bitcoin = const AppBitcoinWallet(),
  });

  final DepositWallets wallets;

  /// The Bitcoin wallet: the screen offers a deposit in BTC when the node takes BTC on
  /// its network (issue #92).
  final BitcoinWallet bitcoin;

  /// Make a new client on a node that forgot the client id. Tests give their own.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _nodeCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0.01');

  String? _nodeError;
  String? _limitError;
  String? _amountError;
  bool _checking = false;
  bool _preparing = false;
  bool _waiting = false;

  List<PayerWallet>? _payers;
  PayerWallet? _payer;
  List<DepositSentView> _sentBefore = const [];
  String? _waitingFor;

  NodeAddress? _node;
  DepositNodeView? _info;

  /// The BTC contract of the node on the network of the Bitcoin wallet; null if it has none.
  BtcDepositNodeView? _btc;
  DepositPreparedView? _sent;
  String? _txId;
  DepositDoneView? _done;
  String? _note;
  CelautError? _error;

  @override
  void initState() {
    super.initState();
    _loadPayers();
  }

  Future<void> _loadPayers() async {
    final payers = await widget.wallets.payers();
    if (!mounted) return;
    setState(() {
      _payers = payers;
      _payer = payers.isEmpty ? null : payers.first;
      _sentBefore = celautSentDeposits();
    });
  }

  @override
  void dispose() {
    _nodeCtrl.dispose();
    _limitCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final parsed = parseHostPort(_nodeCtrl.text);
    if (parsed.value == null) {
      setState(
        () => _nodeError = switch (parsed.error) {
          HostPortError.empty => CelautStrings.addressEmpty,
          HostPortError.port => CelautStrings.portInvalid,
          _ => CelautStrings.addressInvalid,
        },
      );
      return;
    }
    final node = NodeAddress(host: parsed.value!.host, port: parsed.value!.port);
    // The keyboard closes: it covered the contract of the node under the field.
    FocusScope.of(context).unfocus();
    setState(() {
      _nodeError = null;
      _checking = true;
      _error = null;
    });
    try {
      final info = await celautDepositNode(node: node);
      if (!mounted) return;
      setState(() {
        _node = node;
        _info = info;
        _btc = null;
        _limitCtrl.text = formatErg(info.limitNanoErg.toInt(), unit: false);
      });
      _checkBtc(node);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
      if (mounted && e.kind == CelautErrorKind.clientUnknown) {
        final choice = await showClientUnknownChoice(
          context,
          node: node,
          error: e.message,
          newClient: widget.newClient,
        );
        if (choice == ClientUnknownChoice.newClient && mounted) {
          setState(() => _checking = false);
          await _check();
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Offer BTC only when the node advertises a BTC payment contract on the network of the
  /// Bitcoin wallet. Any failure means no offer: the ERG deposit does not change.
  Future<void> _checkBtc(NodeAddress node) async {
    try {
      final btc = await widget.bitcoin.depositNode(node);
      if (mounted && _node == node) setState(() => _btc = btc.accepts ? btc : null);
    } catch (_) {
      if (mounted) setState(() => _btc = null);
    }
  }

  Future<void> _payInBtc() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BtcDepositScreen(wallet: widget.bitcoin, node: _node)),
    );
  }

  Widget _btcCard(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: const Key('deposit-pay-btc'),
          leading: const Icon(Icons.currency_bitcoin),
          title: Text(l.btcDepPayInBtc),
          subtitle: Text(l.btcDepPayInBtcSubtitle(widget.bitcoin.settings.network.name)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _payInBtc,
        ),
      ),
    );
  }

  Future<void> _setLimit() async {
    final info = _info;
    if (info == null) return;
    final limit = parseErgToNano(_limitCtrl.text.trim());
    if (limit == null || limit < 0 || limit > maxLimitNano) {
      setState(() => _limitError = DepositStrings.limitInvalid);
      return;
    }
    setState(() => _limitError = null);
    try {
      await celautSetDepositLimit(peerId: info.peerId, limitNanoErg: BigInt.from(limit));
      await _check();
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _deposit() async {
    final node = _node;
    if (node == null) return;
    final amount = parseErgToNano(_amountCtrl.text.trim());
    if (amount == null || amount < minDepositNano) {
      setState(() => _amountError = DepositStrings.amountInvalid);
      return;
    }
    var payer = _payer;
    setState(() {
      _amountError = payer == null ? DepositStrings.noFullWallet : null;
      _error = null;
      _note = null;
      _done = null;
      _txId = null;
      _sent = null;
    });
    if (payer == null) return;

    // Without this, the node field gets the focus back after the unlock prompt, and the
    // keyboard covers the result.
    FocusScope.of(context).unfocus();
    // The fingerprint or screen lock for the paying wallet, also when it is open. A locked
    // wallet opens with it.
    final consent = await widget.wallets.unlock(context, payer);
    if (!mounted) return;
    if (!consent) {
      setState(() => _note = appL10n.celautDepositAuthNeeded);
      return;
    }
    await _loadPayers();
    if (!mounted) return;
    payer = _payer;
    if (payer == null || !payer.open) {
      setState(() => _note = appL10n.celautDepositAuthNeeded);
      return;
    }

    setState(() => _preparing = true);
    DepositPreparedView prepared;
    try {
      prepared = await widget.wallets.prepare(payer, node, amount);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
      return;
    } catch (e) {
      if (mounted) setState(() => _note = '$e');
      return;
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted) return;

    final choice = await showDepositConfirmation(context, prepared, payer);
    if (!mounted) return;
    if (choice != ConfirmChoice.broadcast) {
      try {
        await celautDepositCancel(depositId: prepared.depositId);
      } on CelautError catch (_) {
        // A deposit that was not sent always cancels; nothing else to do.
      }
      if (mounted) setState(() => _note = DepositStrings.cancelled);
      return;
    }

    // The deposit is "sent" in the database before the send, so that a stop of the app
    // during the send does not lose it.
    try {
      await celautDepositSending(depositId: prepared.depositId);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
      return;
    }
    String txId;
    try {
      txId = await widget.wallets.send(prepared.preparationId.toInt());
    } catch (e) {
      try {
        // Works if the send did not use the preparation; else the deposit stays in the
        // list of the deposits that wait for the node.
        await celautDepositCancel(depositId: prepared.depositId);
      } on CelautError catch (_) {}
      if (mounted) {
        setState(() {
          _note = DepositStrings.sendFailed('$e');
          _sentBefore = celautSentDeposits();
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _sent = prepared;
      _txId = txId;
    });
    await _wait();
  }

  Future<void> _wait() async {
    final sent = _sent;
    final txId = _txId;
    if (sent == null || txId == null) return;
    setState(() {
      _waiting = true;
      _error = null;
    });
    try {
      final done = await celautDepositNotify(depositId: sent.depositId, txId: txId);
      if (mounted) setState(() => _done = done);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _waiting = false;
          _sentBefore = celautSentDeposits();
        });
      }
    }
  }

  /// Wait for a deposit that was sent earlier, also in an earlier run of the app. It
  /// needs no wallet: the transaction is already sent.
  Future<void> _waitFor(DepositSentView d) async {
    setState(() {
      _waitingFor = d.depositId;
      _error = null;
      _note = null;
    });
    try {
      final done = await celautDepositNotify(depositId: d.depositId, txId: d.txId);
      if (mounted) {
        setState(() {
          _txId = d.txId;
          _done = done;
        });
      }
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _waitingFor = null;
          _sentBefore = celautSentDeposits();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final payers = _payers;
    return SettingsPage(
      title: DepositStrings.screenTitle,
      children: [
        SettingsNote(DepositStrings.intro),
        if (payers == null)
          const Center(child: CircularProgressIndicator())
        else if (payers.isEmpty)
          SoftCard(
            child: Text(
              DepositStrings.noFullWallet,
              key: const Key('deposit-no-full-wallet'),
              style: TextStyle(color: rustFor(context)),
            ),
          )
        else ...[
          _payerCard(context),
          const SizedBox(height: 16),
          _nodeInput(context),
        ],
        const SizedBox(height: 24),
        if (_error != null) _errorCard(context, _error!),
        if (_note != null) SoftCard(child: SelectableText(_note!, key: const Key('deposit-note'))),
        if (_txId != null) _statusCard(context),
        if (_btc != null) _btcCard(context),
        if (info != null && _payer != null) ..._nodeCards(context, info),
        if (_sentBefore.isNotEmpty) ..._sentCards(context),
      ],
    );
  }

  Widget _payerCard(BuildContext context) {
    final payer = _payer;
    final muted = ArgusColors.of(context).muted;
    return SoftCard(
      child: Column(
        key: const Key('deposit-payer-card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(DepositStrings.payerTitle),
          const SizedBox(height: 6),
          if (payer != null) ...[
            Text(payer.name, key: const Key('deposit-payer')),
            const SizedBox(height: 4),
            Text(
              DepositStrings.payerBalance(ergOrUnknown(payer.balanceNano)),
              key: const Key('deposit-payer-balance'),
            ),
            Text(
              payer.open ? DepositStrings.payerOpen : DepositStrings.payerLocked,
              key: const Key('deposit-payer-state'),
              style: TextStyle(fontSize: 12, color: payer.open ? muted : rustFor(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _nodeInput(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('deposit-node'),
            controller: _nodeCtrl,
            autocorrect: false,
            enableSuggestions: false,
            // As the address of a node on the Nodes screen: the keyboard for an address,
            // and its action key checks the node.
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _checking ? null : _check(),
            decoration: InputDecoration(
              labelText: DepositStrings.nodeLabel,
              hintText: DepositStrings.nodeHint,
              errorText: _nodeError,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('deposit-check'),
            onPressed: _checking ? null : _check,
            child: Text(_checking ? DepositStrings.checking : DepositStrings.check),
          ),
        ],
      ),
    );
  }

  List<Widget> _sentCards(BuildContext context) {
    final muted = ArgusColors.of(context).muted;
    return [
      const SizedBox(height: 10),
      SectionLabel(DepositStrings.sentTitle),
      const SizedBox(height: 10),
      for (final d in _sentBefore)
        SoftCard(
          child: Column(
            key: Key('deposit-sent-${d.depositId}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DepositStrings.sentRow(
                  formatErg(d.amountNanoErg.toInt()),
                  groupMu(d.amountMu),
                  shorten(d.peerId, head: 10, tail: 8),
                ),
              ),
              SelectableText(
                DepositStrings.tx(d.txId),
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (d.expired)
                Text(DepositStrings.sentExpired, style: TextStyle(color: rustFor(context))),
              const SizedBox(height: 6),
              OutlinedButton(
                key: Key('deposit-sent-wait-${d.depositId}'),
                onPressed: _waitingFor != null || _waiting ? null : () => _waitFor(d),
                child: Text(
                  _waitingFor == d.depositId ? DepositStrings.waiting : DepositStrings.waitAgain,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _nodeCards(BuildContext context, DepositNodeView info) {
    final muted = ArgusColors.of(context).muted;
    final busy = _preparing || _waiting;
    return [
      const SizedBox(height: 10),
      SectionLabel(DepositStrings.nodeTitle),
      const SizedBox(height: 10),
      SoftCard(
        child: Column(
          key: const Key('deposit-info'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(info.peerId, style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 6),
            SelectableText(DepositStrings.payTo(info.payToAddress)),
            Text(DepositStrings.rate(groupMu(info.muPerNanoErg))),
            Text(
              DepositStrings.balance(groupMu(info.clientBalanceMu)),
              key: const Key('deposit-balance'),
            ),
            Text(
              DepositStrings.used(
                formatErg(info.depositedNanoErg.toInt()),
                formatErg(info.limitNanoErg.toInt()),
              ),
              key: const Key('deposit-used'),
            ),
            const SizedBox(height: 8),
            Row(
              // The field has a line under it: the button stays level with the field.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('deposit-limit'),
                    controller: _limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => busy ? null : _setLimit(),
                    decoration: InputDecoration(
                      labelText: DepositStrings.limitLabel,
                      // The maximum is under the field: in the label it was cut.
                      helperText: DepositStrings.limitHelper,
                      helperMaxLines: 2,
                      errorText: _limitError,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const Key('deposit-set-limit'),
                  // The theme minimum is Size.fromHeight: infinite width in a Row.
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: busy ? null : _setLimit,
                  child: Text(DepositStrings.setLimit),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('deposit-amount'),
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              // Done only closes the keyboard: a deposit always needs a tap on its button.
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: DepositStrings.amountLabel,
                hintText: DepositStrings.amountHint,
                errorText: _amountError,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('deposit-prepare'),
              onPressed: busy ? null : _deposit,
              child: Text(_preparing ? DepositStrings.preparing : DepositStrings.prepare),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _statusCard(BuildContext context) {
    final muted = ArgusColors.of(context).muted;
    final done = _done;
    return SoftCard(
      child: Column(
        key: const Key('deposit-status'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(DepositStrings.tx(_txId!), style: TextStyle(fontSize: 12, color: muted)),
          if (done != null) ...[
            SelectableText(
              DepositStrings.box(done.boxId),
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 6),
            Text(
              done.accepted
                  ? DepositStrings.accepted(groupMu(done.clientBalanceMu))
                  : DepositStrings.refused(done.nodeMessage ?? ''),
              key: const Key('deposit-done'),
              style: done.accepted ? null : TextStyle(color: rustFor(context)),
            ),
          ] else if (_waiting) ...[
            const SizedBox(height: 6),
            Text(DepositStrings.waiting, key: const Key('deposit-waiting')),
          ] else ...[
            const SizedBox(height: 6),
            OutlinedButton(
              key: const Key('deposit-wait-again'),
              onPressed: _wait,
              child: Text(DepositStrings.waitAgain),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, CelautError e) {
    return SoftCard(
      child: Column(
        key: const Key('deposit-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CelautStrings.errorText(e.kind),
            style: TextStyle(fontSize: 14, color: rustFor(context)),
          ),
          if (e.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              CelautStrings.detailLabel(e.message),
              style: TextStyle(fontSize: 12, color: ArgusColors.of(context).muted),
            ),
          ],
        ],
      ),
    );
  }
}
