import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bitcoin/btc_format.dart';
import '../../l10n/l10n.dart';
import '../../services/address_label_service.dart';
import '../../theme/argus_theme.dart';
import '../widgets/entry_dialogs.dart';
import 'bitcoin_wallet_screen.dart';

/// Receive bitcoin (issue #103), as the Ergo Receive screen: the address of the wallet as
/// text and as a QR code, an amount to ask for in the QR code (a `bitcoin:` URI, BIP-21),
/// a label on the address, copy and share.
class BitcoinReceiveScreen extends StatefulWidget {
  const BitcoinReceiveScreen({super.key, required this.wallet, required this.address});

  final BitcoinWallet wallet;

  /// The first receive address with no transaction.
  final String address;

  @override
  State<BitcoinReceiveScreen> createState() => _BitcoinReceiveScreenState();
}

class _BitcoinReceiveScreenState extends State<BitcoinReceiveScreen> {
  final _amount = TextEditingController();
  int _sat = 0;
  bool _amountBad = false;

  String get _qr => widget.wallet.paymentUri(widget.address, _sat);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _onAmount(String text) {
    final sat = text.trim().isEmpty ? 0 : parseBtc(text);
    setState(() {
      _amountBad = sat == null;
      _sat = sat ?? 0;
    });
  }

  Future<void> _label() async {
    final label = await showAddressLabelDialog(
      context,
      address: widget.address,
      existing: addressLabelService.labelFor(widget.address) ?? '',
    );
    if (label == null) return;
    await addressLabelService.setLabel(widget.address, label);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    final label = addressLabelService.labelFor(widget.address);
    final network = widget.wallet.settings.network.name;
    return BitcoinLook(
      child: Scaffold(
        appBar: AppBar(title: Text(l.btcReceiveTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  color: paper,
                  padding: const EdgeInsets.all(14),
                  child: QrImageView(
                    key: const Key('btc-receive-qr'),
                    data: _qr,
                    semanticsLabel: widget.address,
                    size: 220,
                    backgroundColor: paper,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ink),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (label != null && label.isNotEmpty) ...[
                Text(label, key: const Key('btc-address-label'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
              ],
              SelectableText(widget.address, key: const Key('btc-address'), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                l.btcReceiveNote(network),
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('btc-receive-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onChanged: _onAmount,
                decoration: InputDecoration(
                  labelText: l.btcReceiveAmount,
                  helperText: l.btcReceiveAmountHelp,
                  errorText: _amountBad ? l.btcSendAmountInvalid : null,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('btc-copy-address'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _sat == 0 ? widget.address : _qr));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.btcAddressCopied)));
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(l.btcCopyAddress),
                  ),
                  OutlinedButton.icon(
                    key: const Key('btc-share-address'),
                    onPressed: () => SharePlus.instance.share(ShareParams(text: _qr)),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l.receiveShare),
                  ),
                  OutlinedButton.icon(
                    key: const Key('btc-label-address'),
                    onPressed: _label,
                    icon: const Icon(Icons.label_outline),
                    label: Text(label == null || label.isEmpty ? l.receiveAddLabel : l.receiveEditLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
