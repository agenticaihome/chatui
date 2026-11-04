import 'dart:async';

import 'package:flutter/material.dart';

import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bitcoin/btc_format.dart';
import '../../bridge/api/btc.dart';
import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_btc_deposit.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/host_port.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../confirm_transaction_sheet.dart';
import '../widgets/soft_card.dart';
import 'bitcoin_send_screen.dart';
import 'bitcoin_wallet_screen.dart';

/// The smallest BTC deposit, in satoshi (`MIN_DEPOSIT_SAT`).
const minBtcDepositSat = 1000;

/// How often the screen asks the server for the confirmations of a deposit.
const btcDepositPoll = Duration(seconds: 15);

/// A deposit in BTC to a node (issue #92). The node must advertise a BTC payment contract
/// on the network of the wallet: if not, the screen says why and offers nothing.
///
/// Check the node, prepare (the deposit token goes in an `OP_RETURN` output), confirm,
/// the fingerprint or the screen lock, send, then wait for the confirmations that the
/// node wants before it checks the deposit once (`Payable`).
class BtcDepositScreen extends StatefulWidget {
  const BtcDepositScreen({super.key, required this.wallet, this.node, this.poll = btcDepositPoll});

  final BitcoinWallet wallet;

  /// The node to check first (from the ERG deposit screen).
  final NodeAddress? node;

  final Duration poll;

  @override
  State<BtcDepositScreen> createState() => _BtcDepositScreenState();
}

class _BtcDepositScreenState extends State<BtcDepositScreen> {
  final _nodeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '10000');

  String? _nodeError;
  String? _amountError;
  bool _busy = false;
  bool _checking = false;
  NodeAddress? _node;
  BtcDepositNodeView? _info;
  BtcFeeRates? _rates;
  BtcFeeChoice _fee = BtcFeeChoice.normal;
  List<BtcDepositSentView> _sent = const [];

  /// The deposit that the screen waits for, and what the server says about it.
  String? _waitingFor;
  BtcDepositStatusView? _status;
  BtcDepositDoneView? _done;
  Object? _error;
  Timer? _timer;

  BitcoinWallet get _w => widget.wallet;

  @override
  void initState() {
    super.initState();
    final node = widget.node;
    if (node != null) _nodeCtrl.text = '${node.host}:${node.port}';
    _sent = _w.sentDeposits();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (node != null) _check();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nodeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final parsed = parseHostPort(_nodeCtrl.text).value;
    if (parsed == null) {
      setState(() => _nodeError = context.l10n.btcDepNodeInvalid);
      return;
    }
    final node = NodeAddress(host: parsed.host, port: parsed.port);
    FocusScope.of(context).unfocus();
    setState(() {
      _nodeError = null;
      _busy = true;
      _checking = true;
      _error = null;
      _info = null;
      _done = null;
    });
    try {
      final info = await _w.depositNode(node);
      if (!mounted) return;
      setState(() {
        _node = node;
        _info = info;
      });
      if (info.accepts && _rates == null && await _w.unlock(context)) {
        await _w.open();
        final rates = await _w.feeRates();
        if (mounted) setState(() => _rates = rates);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _checking = false;
        });
      }
    }
  }

  Future<void> _deposit() async {
    final l = context.l10n;
    final node = _node;
    final info = _info;
    final rates = _rates;
    if (node == null || info == null || rates == null) return;
    FocusScope.of(context).unfocus();
    final sat = int.tryParse(_amountCtrl.text.trim());
    if (sat == null || sat < minBtcDepositSat) {
      setState(() => _amountError = l.btcDepAmountInvalid(minBtcDepositSat.toString()));
      return;
    }
    setState(() {
      _amountError = null;
      _busy = true;
      _error = null;
    });
    BtcDepositPreparedView? prepared;
    try {
      prepared = await _w.prepareDeposit(node, sat, btcRateOf(rates, _fee));
      if (!mounted) return;
      final tx = prepared.transaction;
      final choice = await showConfirmTransactionChoice(
        context,
        title: l.btcDepConfirmTitle,
        confirmLabel: l.btcSendLabel,
        recipientAddress: prepared.payToAddress,
        detail: l.btcDepConfirmDetail(prepared.confirmations.toString()),
        rows: [
          ConfirmTxRow(l.btcRowNetwork, _w.settings.network.name),
          ConfirmTxRow(l.btcDepRowNode, shorten(prepared.peerId, head: 10, tail: 8)),
          ConfirmTxRow(l.btcRowAmount, '${formatBtc(tx.amountSat.toInt())} BTC', bold: true),
          ConfirmTxRow(l.btcDepRowMu, '${groupMu(prepared.mu)} MU', bold: true),
          ConfirmTxRow(l.btcRowFee, formatSat(tx.feeSat.toInt())),
          if (tx.changeSat > BigInt.zero) ConfirmTxRow(l.btcRowChange, '${formatBtc(tx.changeSat.toInt())} BTC'),
          ConfirmTxRow(l.btcRowTotal, '${formatBtc((tx.amountSat + tx.feeSat).toInt())} BTC', bold: true),
        ],
      );
      // The sheet gives the focus back to a field, and its keyboard would cover the page.
      FocusManager.instance.primaryFocus?.unfocus();
      if (choice != ConfirmChoice.broadcast || !mounted) {
        _w.cancelDeposit(prepared);
        return;
      }
      if (!await _w.consent(context)) {
        _w.cancelDeposit(prepared);
        if (mounted) setState(() => _error = l.btcConsentNeeded);
        return;
      }
      // Sent from here on: the deposit is "sent" in the database before the broadcast.
      final sending = prepared;
      prepared = null;
      await _w.sendDeposit(sending);
      if (mounted) _waitFor(sending.depositId);
    } catch (e) {
      if (prepared != null) _w.cancelDeposit(prepared);
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _sent = _w.sentDeposits();
        });
      }
    }
  }

  void _waitFor(String depositId) {
    _timer?.cancel();
    setState(() {
      _waitingFor = depositId;
      _status = null;
      _done = null;
    });
    _tick();
    _timer = Timer.periodic(widget.poll, (_) => _tick());
  }

  bool _ticking = false;

  Future<void> _tick() async {
    final id = _waitingFor;
    if (id == null || _ticking) return;
    _ticking = true;
    try {
      final status = await _w.depositStatus(id);
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
      if (status.confirmations >= status.needed) {
        _timer?.cancel();
        final done = await _w.notifyDeposit(id);
        if (!mounted) return;
        setState(() {
          _done = done;
          _waitingFor = null;
          _sent = _w.sentDeposits();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _ticking = false;
    }
  }

  Future<void> _forget(String depositId) async {
    try {
      await _w.forgetDeposit(depositId);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
    if (mounted) setState(() => _sent = _w.sentDeposits());
  }

  String _errorText(BuildContext context, Object e) {
    if (e is String) return e;
    if (e is CelautError) return context.l10n.btcErrOther(e.message);
    return btcErrorText(context, e);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final info = _info;
    return BitcoinLook(
      child: Scaffold(
        appBar: AppBar(title: Text(l.btcDepTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('btc-dep-node'),
                controller: _nodeCtrl,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _check(),
                decoration: InputDecoration(labelText: l.btcDepNode, errorText: _nodeError),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  key: const Key('btc-dep-check'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(88, 48)),
                  onPressed: _busy ? null : _check,
                  child: Text(l.btcDepCheck),
                ),
              ),
              if (_checking) const LinearProgressIndicator(),
              if (info != null) ...[
                const SizedBox(height: 12),
                info.accepts ? _offer(context, info) : _noBtc(context, info),
              ],
              if (_waitingFor != null || _done != null) ...[
                const SizedBox(height: 12),
                _progress(context),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                SoftCard(
                  child: Text(
                    _errorText(context, _error!),
                    key: const Key('btc-dep-error'),
                    style: TextStyle(color: rustFor(context)),
                  ),
                ),
              ],
              if (_sent.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionLabel(l.btcDepPendingTitle),
                for (final d in _sent) _sentRow(context, d),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _noBtc(BuildContext context, BtcDepositNodeView info) {
    final l = context.l10n;
    return SoftCard(
      child: Column(
        key: const Key('btc-dep-no-btc'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.btcDepNoBtc(_w.settings.network.name)),
          if (info.networks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.btcDepNodeNetworks(info.networks.join(', ')),
              style: TextStyle(color: ArgusColors.of(context).muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _offer(BuildContext context, BtcDepositNodeView info) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return SoftCard(
      child: Column(
        key: const Key('btc-dep-offer'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.btcDepPayTo, style: TextStyle(color: muted, fontSize: 12)),
          SelectableText(info.payToAddress, key: const Key('btc-dep-pay-to')),
          const SizedBox(height: 8),
          Text(l.btcDepRate(groupMu(info.muPerSat)), key: const Key('btc-dep-rate')),
          Text(l.btcDepCredit(groupMu(info.clientBalanceMu))),
          const SizedBox(height: 4),
          Text(
            info.nodeSaysConfirmations
                ? l.btcDepWaitsFor(info.confirmations.toString())
                : l.btcDepWaitsDefault(info.confirmations.toString()),
            key: const Key('btc-dep-confirmations'),
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('btc-dep-amount'),
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l.btcDepAmount, errorText: _amountError),
          ),
          const SizedBox(height: 8),
          SectionLabel(l.btcFeeTitle),
          BtcFeePicker(rates: _rates, choice: _fee, onChanged: (c) => setState(() => _fee = c)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('btc-dep-prepare'),
            onPressed: _busy || _rates == null || _waitingFor != null ? null : _deposit,
            child: Text(l.btcDepPrepare),
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final l = context.l10n;
    final done = _done;
    if (done != null) {
      return SoftCard(
        child: Text(
          done.accepted
              ? l.btcDepAccepted(groupMu(done.clientBalanceMu))
              : l.btcDepRefused(done.nodeMessage ?? ''),
          key: const Key('btc-dep-done'),
          style: TextStyle(color: done.accepted ? null : rustFor(context), fontWeight: FontWeight.w600),
        ),
      );
    }
    final s = _status;
    return SoftCard(
      child: Column(
        key: const Key('btc-dep-waiting'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s == null
                ? l.btcDepTelling
                : s.known
                    ? l.btcDepWaiting(s.confirmations.toString(), s.needed.toString())
                    : l.btcDepUnknownTx,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: s == null || s.needed == 0 ? null : (s.confirmations / s.needed).clamp(0, 1)),
        ],
      ),
    );
  }

  Widget _sentRow(BuildContext context, BtcDepositSentView d) {
    final l = context.l10n;
    return ListTile(
      key: Key('btc-dep-sent-${d.depositId}'),
      contentPadding: EdgeInsets.zero,
      title: Text('${formatSat(d.sat.toInt())} · ${d.network}'),
      subtitle: Text('${shorten(d.peerId, head: 8, tail: 6)} · ${d.txId.substring(0, 10)}…'),
      trailing: Wrap(
        spacing: 4,
        children: [
          TextButton(
            key: Key('btc-dep-wait-${d.depositId}'),
            onPressed: _waitingFor == d.depositId ? null : () => _waitFor(d.depositId),
            child: Text(l.btcDepWait),
          ),
          TextButton(
            key: Key('btc-dep-forget-${d.depositId}'),
            onPressed: () => _forget(d.depositId),
            child: Text(l.btcDepForget),
          ),
        ],
      ),
    );
  }
}
