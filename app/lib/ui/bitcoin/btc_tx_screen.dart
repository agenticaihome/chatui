import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bitcoin/btc_format.dart';
import '../../bridge/api/btc.dart';
import '../../l10n/l10n.dart';
import '../../services/address_label_service.dart';
import '../../services/session_lock.dart';
import '../../theme/argus_theme.dart';
import '../confirm_transaction_sheet.dart';
import '../widgets/soft_card.dart';
import 'bitcoin_send_screen.dart';
import 'bitcoin_wallet_screen.dart';

/// A Bitcoin transaction (issue #103), as the Ergo transaction screen: the amount, the
/// state, the fee, the inputs and the outputs, the ID to copy and the explorer. A payment
/// that waits can be sent again with a higher fee (RBF). Pops with the ID of the new
/// transaction after a fee bump.
class BtcTxScreen extends StatefulWidget {
  const BtcTxScreen({super.key, required this.wallet, required this.txid});

  final BitcoinWallet wallet;
  final String txid;

  @override
  State<BtcTxScreen> createState() => _BtcTxScreenState();
}

class _BtcTxScreenState extends State<BtcTxScreen> {
  BtcTxDetailView? _tx;
  Object? _error;
  bool _busy = false;

  BitcoinWallet get _w => widget.wallet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tx = await _w.transaction(widget.txid);
      if (mounted) setState(() => _tx = tx);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _explorer(String url) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await sessionLock.run(() => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
      if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.txExplorerFailed)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.txExplorerFailed)));
    }
  }

  Future<void> _bump(BtcTxDetailView tx) async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    BtcPreparedView? prepared;
    try {
      final rates = await _w.feeRates();
      if (!mounted) return;
      final rate = await showModalBottomSheet<double>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (_) => _BumpSheet(rates: rates, current: tx.feeRate),
      );
      if (rate == null || !mounted) return;
      prepared = await _w.prepareBump(tx.tx.txid, rate);
      if (!mounted) return;
      final choice = await showConfirmTransactionChoice(
        context,
        title: l.btcBumpConfirmTitle,
        confirmLabel: l.btcSendLabel,
        recipientAddress: prepared.to,
        rows: [
          ConfirmTxRow(l.btcRowNetwork, _w.settings.network.name),
          ConfirmTxRow(l.btcRowAmount, '${formatBtc(prepared.amountSat.toInt())} BTC', bold: true),
          ConfirmTxRow(l.btcBumpOldFee, formatSat(tx.tx.feeSat.toInt())),
          ConfirmTxRow(l.btcRowFee, formatSat(prepared.feeSat.toInt()), bold: true),
          ConfirmTxRow(l.btcRowFeeRate, '${formatFeeRate(prepared.feeRate)} sat/vB'),
        ],
      );
      if (choice != ConfirmChoice.broadcast || !mounted) {
        _w.cancel(prepared);
        return;
      }
      if (!await _w.consent(context)) {
        _w.cancel(prepared);
        if (mounted) setState(() => _error = l.btcConsentNeeded);
        return;
      }
      final txid = await _w.send(prepared);
      if (mounted) Navigator.of(context).pop(txid);
    } catch (e) {
      if (prepared != null) _w.cancel(prepared);
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tx = _tx;
    return BitcoinLook(
      child: Scaffold(
        appBar: AppBar(title: Text(l.txTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (tx == null && _error == null) const LinearProgressIndicator(),
              if (tx != null) ..._detail(context, tx),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SoftCard(
                  child: Text(
                    _error is String ? _error as String : btcErrorText(context, _error!),
                    key: const Key('btc-tx-error'),
                    style: TextStyle(color: rustFor(context)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _detail(BuildContext context, BtcTxDetailView d) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    final t = d.tx;
    final network = _w.settings.network.name;
    final url = btcExplorerTx(network, t.txid);
    final when = t.time == BigInt.zero
        ? null
        : DateTime.fromMillisecondsSinceEpoch(t.time.toInt() * 1000).toLocal().toString().substring(0, 16);
    Widget row(String label, String value, {Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(label, style: TextStyle(color: muted))),
              Expanded(child: Text(value, key: key)),
            ],
          ),
        );
    String part(BtcTxPartView p) {
      if (p.data) return l.btcTxData;
      final who = p.address.isEmpty ? l.btcTxUnknownScript : (addressLabelService.labelFor(p.address) ?? shortBtc(p.address));
      final amount = p.satKnown ? '${formatBtc(p.sat.toInt())} BTC' : '?';
      return '$amount · $who${p.mine ? ' · ${l.btcTxYours}' : ''}';
    }

    return [
      Text(
        '${t.netSat >= 0 ? '+' : ''}${formatBtc(t.netSat)} BTC',
        key: const Key('btc-tx-amount'),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        t.confirmations == 0 ? l.btcUnconfirmed : l.btcConfirmations(t.confirmations.toString()),
        key: const Key('btc-tx-state'),
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 16),
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (when != null) row(l.btcTxTime, when),
            row(l.btcRowFee, t.feeKnown ? formatSat(t.feeSat.toInt()) : '?', key: const Key('btc-tx-fee')),
            if (t.feeKnown) row(l.btcRowFeeRate, '${formatFeeRate(d.feeRate)} sat/vB'),
            row(l.btcTxSize, '${d.vsize} vB'),
            row(l.txIdLabel, t.txid),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(l.txFrom, style: TextStyle(color: muted)),
      for (final (i, p) in d.inputs.indexed) Text(part(p), key: Key('btc-tx-in-$i')),
      const SizedBox(height: 12),
      Text(l.txTo, style: TextStyle(color: muted)),
      for (final (i, p) in d.outputs.indexed) Text(part(p), key: Key('btc-tx-out-$i')),
      const SizedBox(height: 20),
      if (d.canBump) ...[
        FilledButton.icon(
          key: const Key('btc-tx-bump'),
          onPressed: _busy ? null : () => _bump(d),
          icon: const Icon(Icons.speed),
          label: Text(l.btcBump),
        ),
        const SizedBox(height: 4),
        Text(l.btcBumpHint, style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 12),
      ],
      OutlinedButton(
        key: const Key('btc-tx-copy'),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: t.txid));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.txIdCopied)));
        },
        child: Text(l.commonCopyId),
      ),
      if (url != null) ...[
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('btc-tx-explorer'),
          onPressed: () => _explorer(url),
          child: Text(l.txOpenExplorer),
        ),
      ],
    ];
  }
}

/// `tb1qcr8t…chgx`.
String shortBtc(String address) =>
    address.length <= 16 ? address : '${address.substring(0, 8)}…${address.substring(address.length - 4)}';

/// The new fee rate of a bump: the server's estimates above the rate of now, or a rate typed.
class _BumpSheet extends StatefulWidget {
  const _BumpSheet({required this.rates, required this.current});

  final BtcFeeRates rates;

  /// The fee rate of the transaction now (sat/vB).
  final double current;

  @override
  State<_BumpSheet> createState() => _BumpSheetState();
}

class _BumpSheetState extends State<_BumpSheet> {
  late BtcFeeChoice _choice = BtcFeeChoice.fast;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// The lowest rate that relays as a replacement: 1 sat/vB more than now.
  double get _min => ((widget.current + 1) * 10).ceil() / 10;

  double? get _rate => btcRateOfChoice(widget.rates, _choice, _custom.text);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rate = _rate;
    final low = rate != null && rate < _min;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.btcBump, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l.btcBumpNow(formatFeeRate(widget.current), formatFeeRate(_min))),
            BtcFeePicker(
              rates: widget.rates,
              choice: _choice,
              custom: _custom,
              onChanged: (c) => setState(() => _choice = c),
              onCustom: () => setState(() {}),
            ),
            if (low)
              Text(l.btcBumpTooLow(formatFeeRate(_min)), key: const Key('btc-bump-low'), style: TextStyle(color: rustFor(context))),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('btc-bump-review'),
              onPressed: rate == null || low ? null : () => Navigator.of(context).pop(rate),
              child: Text(l.btcReview),
            ),
          ],
        ),
      ),
    );
  }
}
