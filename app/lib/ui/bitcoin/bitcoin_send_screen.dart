import 'package:flutter/material.dart';

import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bitcoin/btc_format.dart';
import '../../bridge/api/btc.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../confirm_transaction_sheet.dart';
import '../widgets/soft_card.dart';
import 'bitcoin_wallet_screen.dart';

/// The fee choices: the three estimates of the server.
enum BtcFeeChoice { fast, normal, slow }

double btcRateOf(BtcFeeRates rates, BtcFeeChoice c) => switch (c) {
      BtcFeeChoice.fast => rates.fast,
      BtcFeeChoice.normal => rates.normal,
      BtcFeeChoice.slow => rates.slow,
    };

String _rate(double r) => r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);

/// The fee rate choice, with the estimates of the server.
class BtcFeePicker extends StatelessWidget {
  const BtcFeePicker({super.key, required this.rates, required this.choice, required this.onChanged});

  final BtcFeeRates? rates;
  final BtcFeeChoice choice;
  final ValueChanged<BtcFeeChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = rates;
    if (r == null) return const LinearProgressIndicator();
    String label(BtcFeeChoice c) => switch (c) {
          BtcFeeChoice.fast => l.btcFeeFast(_rate(r.fast)),
          BtcFeeChoice.normal => l.btcFeeNormal(_rate(r.normal)),
          BtcFeeChoice.slow => l.btcFeeSlow(_rate(r.slow)),
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<BtcFeeChoice>(
          groupValue: choice,
          onChanged: (v) => onChanged(v ?? choice),
          child: Column(
            children: [
              for (final c in BtcFeeChoice.values)
                RadioListTile<BtcFeeChoice>(
                  key: Key('btc-fee-${c.name}'),
                  contentPadding: EdgeInsets.zero,
                  value: c,
                  title: Text(label(c)),
                ),
            ],
          ),
        ),
        if (!r.estimated)
          Text(l.btcFeeNoEstimate, style: TextStyle(color: ArgusColors.of(context).muted, fontSize: 12)),
      ],
    );
  }
}

/// Send bitcoin: address, amount (or everything), fee rate, then the confirmation sheet
/// and the fingerprint or screen lock. Pops with the transaction id.
class BitcoinSendScreen extends StatefulWidget {
  const BitcoinSendScreen({super.key, required this.wallet});

  final BitcoinWallet wallet;

  @override
  State<BitcoinSendScreen> createState() => _BitcoinSendScreenState();
}

class _BitcoinSendScreenState extends State<BitcoinSendScreen> {
  final _to = TextEditingController();
  final _amount = TextEditingController();
  bool _all = false;
  BtcFeeRates? _rates;
  BtcFeeChoice _fee = BtcFeeChoice.normal;
  String? _toError;
  String? _amountError;
  Object? _error;
  bool _busy = false;

  BitcoinWallet get _w => widget.wallet;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    try {
      final r = await _w.feeRates();
      if (mounted) setState(() => _rates = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    final to = _to.text.trim();
    final sat = _all ? 0 : parseBtc(_amount.text);
    setState(() {
      _toError = _w.isAddress(to) ? null : l.btcSendToInvalid(_w.settings.network.name);
      _amountError = _all || (sat != null && sat > 0) ? null : l.btcSendAmountInvalid;
      _error = null;
    });
    final rates = _rates;
    if (_toError != null || _amountError != null || rates == null) return;
    setState(() => _busy = true);
    BtcPreparedView? prepared;
    try {
      prepared = await _w.prepareSend(to, sat ?? 0, sendAll: _all, feeRate: btcRateOf(rates, _fee));
      if (!mounted) return;
      final choice = await showConfirmTransactionChoice(
        context,
        title: l.btcConfirmTitle,
        confirmLabel: l.btcSendLabel,
        recipientAddress: prepared.to,
        rows: [
          ConfirmTxRow(l.btcRowNetwork, _w.settings.network.name),
          ConfirmTxRow(l.btcRowAmount, '${formatBtc(prepared.amountSat.toInt())} BTC', bold: true),
          ConfirmTxRow(l.btcRowFee, formatSat(prepared.feeSat.toInt())),
          ConfirmTxRow(l.btcRowFeeRate, '${_rate(prepared.feeRate)} sat/vB'),
          if (prepared.changeSat > BigInt.zero)
            ConfirmTxRow(l.btcRowChange, '${formatBtc(prepared.changeSat.toInt())} BTC'),
          ConfirmTxRow(
            l.btcRowTotal,
            '${formatBtc((prepared.amountSat + prepared.feeSat).toInt())} BTC',
            bold: true,
          ),
        ],
      );
      // The sheet gives the focus back to a field, and its keyboard would cover the page.
      FocusManager.instance.primaryFocus?.unfocus();
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
    return BitcoinLook(
      child: Scaffold(
        appBar: AppBar(title: Text(l.btcSendTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('btc-send-to'),
                controller: _to,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.btcSendTo, errorText: _toError),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('btc-send-amount'),
                controller: _amount,
                enabled: !_all,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l.btcSendAmount, errorText: _amountError),
              ),
              SwitchListTile(
                key: const Key('btc-send-all'),
                contentPadding: EdgeInsets.zero,
                value: _all,
                onChanged: (v) => setState(() => _all = v),
                title: Text(l.btcSendAll),
                subtitle: Text(l.btcSendAllHint),
              ),
              const SizedBox(height: 8),
              SectionLabel(l.btcFeeTitle),
              BtcFeePicker(rates: _rates, choice: _fee, onChanged: (c) => setState(() => _fee = c)),
              const SizedBox(height: 16),
              if (_error != null) ...[
                SoftCard(
                  child: Text(
                    _error is String ? _error as String : btcErrorText(context, _error!),
                    key: const Key('btc-send-error'),
                    style: TextStyle(color: rustFor(context)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                key: const Key('btc-send-review'),
                onPressed: _busy || _rates == null ? null : _review,
                child: Text(l.btcReview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
