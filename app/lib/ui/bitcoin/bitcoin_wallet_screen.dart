import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../bitcoin/bitcoin_settings.dart';
import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bitcoin/btc_format.dart';
import '../../bridge/api/btc.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../../theme/theme_controller.dart';
import '../home/home_style.dart';
import '../home/home_widgets.dart';
import '../home/wallet_tools_sheet.dart' show HomeSheetHeader, showHomeSheet;
import '../scan_screen.dart';
import '../widgets/soft_card.dart';
import 'bitcoin_receive_screen.dart';
import 'bitcoin_send_screen.dart';
import 'bitcoin_settings_screen.dart';
import 'btc_deposit_screen.dart';
import 'btc_lists_screen.dart';
import 'btc_tx_screen.dart';

/// The text of a Bitcoin error for the user.
String btcErrorText(BuildContext context, Object e) {
  final l = context.l10n;
  if (e is BtcError) {
    return switch (e.kind) {
      BtcErrorKind.locked => l.btcErrLocked,
      BtcErrorKind.funds => l.btcErrFunds,
      BtcErrorKind.unreachable => l.btcErrUnreachable,
      _ => l.btcErrOther(e.message),
    };
  }
  return l.btcErrOther(e.toString());
}

/// Shows the Bitcoin look ([bitcoinPalette]) while [child]'s route is open. The flag
/// changes after a frame: the app rebuilds on it, and a build must not start another.
class BitcoinLook extends StatefulWidget {
  const BitcoinLook({super.key, required this.child});

  final Widget child;

  @override
  State<BitcoinLook> createState() => _BitcoinLookState();
}

class _BitcoinLookState extends State<BitcoinLook> {
  static int _open = 0;

  static void _apply() {
    SchedulerBinding.instance.addPostFrameCallback((_) => bitcoinThemeActive.value = _open > 0);
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void initState() {
    super.initState();
    _open++;
    _apply();
  }

  @override
  void dispose() {
    _open--;
    _apply();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What the More sheet of the Bitcoin wallet offers, as the More sheet of the Ergo wallet.
enum BtcTool { addresses, utxos, deposit, network, backup, lock }

/// The Bitcoin wallet (issues #92 and #103): the balance, receive, send, scan, the history
/// with each transaction, and in More the addresses, the unspent outputs, a deposit to a
/// node, the network, the recovery phrase and lock. It has its own look
/// ([bitcoinPalette]), as the Ergo part has its own.
class BitcoinWalletScreen extends StatefulWidget {
  const BitcoinWalletScreen({super.key, this.wallet = const AppBitcoinWallet(), this.onRead});

  final BitcoinWallet wallet;

  /// The figures and the history after each read, for the overview's snapshot.
  final Future<void> Function(BtcWalletView view, List<BtcTxView> txs)? onRead;

  @override
  State<BitcoinWalletScreen> createState() => _BitcoinWalletScreenState();
}

class _BitcoinWalletScreenState extends State<BitcoinWalletScreen> {
  BtcWalletView? _view;
  List<BtcTxView> _txs = const [];
  Object? _error;
  bool _locked = false;
  bool _syncing = false;

  BitcoinWallet get _w => widget.wallet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _locked = false;
    });
    if (!await _w.unlock(context)) {
      if (mounted) setState(() => _locked = true);
      return;
    }
    try {
      final view = await _w.open();
      if (!mounted) return;
      setState(() => _view = view);
      await _sync();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final view = await _w.sync();
      final txs = await _w.transactions();
      await widget.onRead?.call(view, txs);
      if (!mounted) return;
      setState(() {
        _view = view;
        _txs = txs;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _settings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BitcoinSettingsScreen(settings: _w.settings)),
    );
    if (changed == true && mounted) {
      setState(() {
        _view = null;
        _txs = const [];
      });
      await _open();
    }
  }

  Future<void> _send() async {
    final txid = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => BitcoinSendScreen(wallet: _w)),
    );
    if (txid != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.btcSent(txid))));
      await _sync();
    }
  }

  Future<void> _deposit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BtcDepositScreen(wallet: _w)),
    );
    if (mounted) await _sync();
  }

  Future<void> _receive(String address) => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => BitcoinReceiveScreen(wallet: _w, address: address)),
      );

  /// A scanned QR code opens Send with its address and amount.
  Future<void> _scan() async {
    final raw = await Navigator.push<String>(context, fadeRoute(const ScanScreen()));
    if (!mounted || raw == null) return;
    final request = _w.paymentRequest(raw);
    if (request == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.btcScanNotBitcoin(_w.settings.network.name))),
      );
      return;
    }
    final txid = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BitcoinSendScreen(
          wallet: _w,
          initialTo: request.address,
          initialSat: request.amountSat.toInt(),
        ),
      ),
    );
    if (txid != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.btcSent(txid))));
      await _sync();
    }
  }

  Future<void> _openTx(String txid) async {
    final bumped = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => BtcTxScreen(wallet: _w, txid: txid)),
    );
    if (bumped != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.btcBumped(bumped))));
      await _sync();
    }
  }

  Future<void> _more() async {
    final tool = await showHomeSheet<BtcTool>(context, builder: (ctx) => const _BtcToolsSheet());
    if (tool == null || !mounted) return;
    final navigator = Navigator.of(context);
    switch (tool) {
      case BtcTool.addresses:
        await navigator.push<void>(MaterialPageRoute(builder: (_) => BtcAddressesScreen(wallet: _w)));
      case BtcTool.utxos:
        await navigator.push<void>(MaterialPageRoute(builder: (_) => BtcUtxosScreen(wallet: _w)));
      case BtcTool.deposit:
        await _deposit();
      case BtcTool.network:
        await _settings();
      case BtcTool.backup:
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.btcBackupTitle),
            content: Text(ctx.l10n.btcBackupBody),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonClose))],
          ),
        );
      case BtcTool.lock:
        final route = ModalRoute.of(context);
        await _w.lock();
        // The app closes the pages of a locked wallet itself; close this one only if it
        // is still open.
        if (mounted && route != null && route.isCurrent) navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final view = _view;
    return BitcoinLook(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.btcTitle),
          actions: [
            if (view != null)
              IconButton(
                key: const Key('btc-scan'),
                tooltip: l.dashboardScanQrTooltip,
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
              ),
            IconButton(
              key: const Key('btc-refresh'),
              tooltip: l.btcRefresh,
              onPressed: view == null || _syncing ? null : _sync,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              key: const Key('btc-settings'),
              tooltip: l.btcSettingsTitle,
              onPressed: _settings,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: view == null ? _open : _sync,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_syncing) const LinearProgressIndicator(key: Key('btc-syncing')),
                if (_locked) _lockedCard(context),
                if (view != null) ...[
                  _networkNote(context, view),
                  const SizedBox(height: 12),
                  _balanceCard(context, view),
                  const SizedBox(height: 12),
                  _actions(context, view),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorCard(context, _error!),
                ],
                if (view != null) ...[
                  const SizedBox(height: 20),
                  SectionLabel(l.btcHistory),
                  const SizedBox(height: 8),
                  _history(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockedCard(BuildContext context) {
    final l = context.l10n;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.btcLocked, key: const Key('btc-locked')),
          const SizedBox(height: 12),
          FilledButton(key: const Key('btc-unlock'), onPressed: _open, child: Text(l.btcUnlock)),
        ],
      ),
    );
  }

  Widget _networkNote(BuildContext context, BtcWalletView view) {
    final l = context.l10n;
    final network = BtcNetworkName.parse(view.network);
    final real = network?.real ?? false;
    return Row(
      key: const Key('btc-network'),
      children: [
        Icon(real ? Icons.warning_amber_rounded : Icons.science_outlined, size: 18, color: accentOf(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            real ? l.btcMainnetNote : l.btcTestNetwork(view.network),
            style: TextStyle(color: ArgusColors.of(context).muted, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _balanceCard(BuildContext context, BtcWalletView view) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    final confirmed = view.confirmedSat.toInt();
    final pending = view.pendingSat.toInt();
    final immature = view.immatureSat.toInt();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.btcConfirmed, style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${formatBtc(confirmed)} BTC',
            key: const Key('btc-balance'),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
          ),
          Text(formatSat(confirmed), style: TextStyle(color: muted)),
          if (pending > 0) ...[
            const SizedBox(height: 6),
            Text(l.btcPending(formatBtc(pending)), key: const Key('btc-pending')),
          ],
          if (immature > 0) ...[
            const SizedBox(height: 6),
            Text(l.btcImmature(formatBtc(immature)), key: const Key('btc-immature')),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, BtcWalletView view) {
    final l = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          key: const Key('btc-receive'),
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: () => _receive(view.receiveAddress),
          icon: const Icon(Icons.call_received),
          label: Text(l.btcReceive),
        ),
        FilledButton.icon(
          key: const Key('btc-send'),
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: _send,
          icon: const Icon(Icons.call_made),
          label: Text(l.btcSend),
        ),
        OutlinedButton.icon(
          key: const Key('btc-deposit'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: _deposit,
          icon: const Icon(Icons.savings_outlined),
          label: Text(l.btcDepositAction),
        ),
        OutlinedButton.icon(
          key: const Key('btc-more'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: _more,
          icon: const Icon(Icons.more_horiz),
          label: Text(l.homeActionMore),
        ),
      ],
    );
  }

  Widget _history(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    if (_txs.isEmpty) {
      return Text(l.btcNoHistory, key: const Key('btc-no-history'), style: TextStyle(color: muted));
    }
    return SoftCard(
      padding: EdgeInsets.zero,
      child: DividedColumn(
        indent: 16,
        children: [
          for (final t in _txs)
            ListTile(
              key: Key('btc-tx-${t.txid}'),
              leading: Icon(t.netSat >= 0 ? Icons.call_received : Icons.call_made),
              title: Text('${t.netSat >= 0 ? '+' : ''}${formatBtc(t.netSat)} BTC'),
              subtitle: Text(
                [
                  t.confirmations == 0 ? l.btcUnconfirmed : l.btcConfirmations(t.confirmations.toString()),
                  if (t.time > BigInt.zero)
                    DateTime.fromMillisecondsSinceEpoch(t.time.toInt() * 1000).toLocal().toString().substring(0, 16),
                ].join(' · '),
              ),
              trailing: Text('${t.txid.substring(0, 6)}…', style: TextStyle(color: muted, fontSize: 12)),
              onTap: () => _openTx(t.txid),
            ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, Object e) {
    return SoftCard(
      child: Text(btcErrorText(context, e), key: const Key('btc-error'), style: TextStyle(color: rustFor(context))),
    );
  }
}

/// The More sheet of the Bitcoin wallet: the same rows and look as the More sheet of the
/// Ergo wallet, with Lock set apart under a rule.
class _BtcToolsSheet extends StatelessWidget {
  const _BtcToolsSheet();

  static ({IconData icon, String title, String blurb}) _look(BtcTool tool) => switch (tool) {
        BtcTool.addresses => (icon: Icons.account_tree_outlined, title: appL10n.commonAddresses, blurb: appL10n.btcToolAddressesBlurb),
        BtcTool.utxos => (icon: Icons.grid_view_outlined, title: appL10n.btcUtxosTitle, blurb: appL10n.btcToolUtxosBlurb),
        BtcTool.deposit => (icon: Icons.savings_outlined, title: appL10n.btcDepositAction, blurb: appL10n.chatsDepositRowSubtitle),
        BtcTool.network => (icon: Icons.language_outlined, title: appL10n.btcSettingsTitle, blurb: appL10n.btcToolNetworkBlurb),
        BtcTool.backup => (icon: Icons.key_outlined, title: appL10n.btcBackupTitle, blurb: appL10n.btcToolBackupBlurb),
        BtcTool.lock => (icon: Icons.lock_outline, title: appL10n.homeToolLock, blurb: appL10n.btcToolLockBlurb),
      };

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    Widget row(BtcTool tool, {bool chevron = true}) {
      final look = _look(tool);
      return HomeRow(
        inkKey: Key('btc-tool-${tool.name}'),
        onTap: () => Navigator.pop(context, tool),
        semanticLabel: '${look.title}, ${look.blurb}',
        leading: HomeDisc(child: Icon(look.icon, size: 18, color: t.ink)),
        title: Text(look.title, style: t.primary),
        subtitle: TextSpan(text: look.blurb),
        trailing: chevron ? Icon(Icons.chevron_right, size: 18, color: t.muted) : null,
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSheetHeader(title: context.l10n.homeActionMore, subject: context.l10n.coinBitcoin),
            for (final tool in BtcTool.values)
              if (tool != BtcTool.lock) row(tool),
            const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: HomeRule()),
            row(BtcTool.lock, chevron: false),
          ],
        ),
      ),
    );
  }
}
