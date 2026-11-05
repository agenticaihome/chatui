import 'package:flutter/material.dart';

import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bitcoin/btc_format.dart';
import '../../bridge/api/btc.dart';
import '../../l10n/l10n.dart';
import '../../services/contacts_service.dart';
import '../../theme/argus_theme.dart';
import '../confirm_transaction_sheet.dart';
import '../contacts_screen.dart';
import '../scan_screen.dart';
import '../widgets/entry_dialogs.dart';
import '../widgets/soft_card.dart';
import 'bitcoin_wallet_screen.dart';

/// The fee choices: the three estimates of the server, or a rate that the user types.
enum BtcFeeChoice { fast, normal, slow, custom }

/// The rate of an estimate. [BtcFeeChoice.custom] has none here: see [btcRateOfChoice].
double btcRateOf(BtcFeeRates rates, BtcFeeChoice c) => switch (c) {
      BtcFeeChoice.fast => rates.fast,
      BtcFeeChoice.normal => rates.normal,
      BtcFeeChoice.slow => rates.slow,
      BtcFeeChoice.custom => rates.normal,
    };

/// The rate of [c], with [customText] for [BtcFeeChoice.custom]: null if that is not a
/// rate from 1 to 1000 sat/vB.
double? btcRateOfChoice(BtcFeeRates rates, BtcFeeChoice c, String customText) {
  if (c != BtcFeeChoice.custom) return btcRateOf(rates, c);
  final r = double.tryParse(customText.trim().replaceAll(',', '.'));
  if (r == null || !r.isFinite || r < 1 || r > 1000) return null;
  return r;
}

/// The fee rate choice, with the estimates of the server, and a rate to type when [custom]
/// is given.
class BtcFeePicker extends StatelessWidget {
  const BtcFeePicker({
    super.key,
    required this.rates,
    required this.choice,
    required this.onChanged,
    this.custom,
    this.onCustom,
  });

  final BtcFeeRates? rates;
  final BtcFeeChoice choice;
  final ValueChanged<BtcFeeChoice> onChanged;

  /// The typed rate (sat/vB). Null: no custom choice.
  final TextEditingController? custom;
  final VoidCallback? onCustom;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = rates;
    if (r == null) return const LinearProgressIndicator();
    String label(BtcFeeChoice c) => switch (c) {
          BtcFeeChoice.fast => l.btcFeeFast(formatFeeRate(r.fast)),
          BtcFeeChoice.normal => l.btcFeeNormal(formatFeeRate(r.normal)),
          BtcFeeChoice.slow => l.btcFeeSlow(formatFeeRate(r.slow)),
          BtcFeeChoice.custom => l.btcFeeCustom,
        };
    final field = custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<BtcFeeChoice>(
          groupValue: choice,
          onChanged: (v) => onChanged(v ?? choice),
          child: Column(
            children: [
              for (final c in BtcFeeChoice.values)
                if (c != BtcFeeChoice.custom || field != null)
                  RadioListTile<BtcFeeChoice>(
                    key: Key('btc-fee-${c.name}'),
                    contentPadding: EdgeInsets.zero,
                    value: c,
                    title: Text(label(c)),
                  ),
            ],
          ),
        ),
        if (field != null && choice == BtcFeeChoice.custom)
          TextField(
            key: const Key('btc-fee-rate'),
            controller: field,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onCustom?.call(),
            decoration: InputDecoration(
              labelText: l.btcFeeCustomLabel,
              suffixText: 'sat/vB',
              errorText: field.text.isNotEmpty && btcRateOfChoice(r, choice, field.text) == null ? l.btcFeeCustomInvalid : null,
            ),
          ),
        if (!r.estimated)
          Text(l.btcFeeNoEstimate, style: TextStyle(color: ArgusColors.of(context).muted, fontSize: 12)),
      ],
    );
  }
}

/// Send bitcoin: address (typed, scanned or from the address book), amount (or
/// everything), fee rate, then the confirmation sheet and the fingerprint or screen lock.
/// Pops with the transaction id.
class BitcoinSendScreen extends StatefulWidget {
  const BitcoinSendScreen({super.key, required this.wallet, this.initialTo, this.initialSat});

  final BitcoinWallet wallet;

  /// From a payment request (a scanned QR code).
  final String? initialTo;
  final int? initialSat;

  @override
  State<BitcoinSendScreen> createState() => _BitcoinSendScreenState();
}

class _BitcoinSendScreenState extends State<BitcoinSendScreen> {
  late final _to = TextEditingController(text: widget.initialTo ?? '');
  late final _amount = TextEditingController(
    text: widget.initialSat == null || widget.initialSat == 0 ? '' : formatBtc(widget.initialSat!),
  );
  final _customFee = TextEditingController();
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
    _customFee.dispose();
    super.dispose();
  }

  /// A scanned QR code: an address or a payment request of the wallet's network.
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
    setState(() {
      _to.text = request.address;
      _toError = null;
      if (request.amountSat > BigInt.zero) {
        _all = false;
        _amount.text = formatBtc(request.amountSat.toInt());
      }
    });
  }

  /// A recipient from the address book: only the addresses of this network.
  Future<void> _pickContact() async {
    final picked = await Navigator.push<WalletContact>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(arguments: true),
        builder: (_) => ContactsScreen(accepts: _w.isAddress),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _to.text = picked.address;
        _toError = null;
      });
    }
  }

  String? _contactName(String address) {
    for (final c in contactsService.contacts) {
      if (c.address == address) return c.name;
    }
    return null;
  }

  Future<void> _saveContact() async {
    final address = _to.text.trim();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => TextEntryDialog(
        title: context.l10n.sendSaveToContacts,
        label: context.l10n.commonName,
        textCapitalization: TextCapitalization.words,
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await contactsService.add(name.trim(), address);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.sendContactSaved)));
      setState(() {});
    }
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
    final rate = rates == null ? null : btcRateOfChoice(rates, _fee, _customFee.text);
    if (_toError != null || _amountError != null || rate == null) return;
    setState(() => _busy = true);
    BtcPreparedView? prepared;
    try {
      prepared = await _w.prepareSend(to, sat ?? 0, sendAll: _all, feeRate: rate);
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
          ConfirmTxRow(l.btcRowFeeRate, '${formatFeeRate(prepared.feeRate)} sat/vB'),
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.btcSendTo,
                  errorText: _toError,
                  helperText: _contactName(_to.text.trim()) == null ? null : l.sendContactName(_contactName(_to.text.trim())!),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('btc-send-scan'),
                        tooltip: l.dashboardScanQrTooltip,
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scan,
                      ),
                      IconButton(
                        key: const Key('btc-send-contacts'),
                        tooltip: l.commonContacts,
                        icon: const Icon(Icons.contacts_outlined),
                        onPressed: _pickContact,
                      ),
                    ],
                  ),
                ),
              ),
              if (_w.isAddress(_to.text.trim()) && _contactName(_to.text.trim()) == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('btc-send-save-contact'),
                    onPressed: _saveContact,
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(l.sendSaveToContacts),
                  ),
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
              BtcFeePicker(
                rates: _rates,
                choice: _fee,
                custom: _customFee,
                onChanged: (c) => setState(() => _fee = c),
                onCustom: () => setState(() {}),
              ),
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
