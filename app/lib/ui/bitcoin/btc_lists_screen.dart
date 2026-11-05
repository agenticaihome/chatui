import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bitcoin/bitcoin_wallet_api.dart';
import '../../bitcoin/btc_format.dart';
import '../../bridge/api/btc.dart';
import '../../l10n/l10n.dart';
import '../../services/address_label_service.dart';
import '../../theme/argus_theme.dart';
import '../widgets/entry_dialogs.dart';
import '../widgets/soft_card.dart';
import 'bitcoin_wallet_screen.dart';
import 'btc_tx_screen.dart' show shortBtc;

/// A list of the Bitcoin wallet that loads once, with its error.
abstract class _BtcListState<W extends StatefulWidget, T> extends State<W> {
  List<T>? items;
  Object? error;

  Future<List<T>> read();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final all = await read();
      if (mounted) setState(() => items = all);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Widget page(BuildContext context, {required String title, required String empty, required Widget Function(T) row}) {
    final all = items;
    return BitcoinLook(
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (all == null && error == null) const LinearProgressIndicator(),
              if (error != null)
                SoftCard(child: Text(btcErrorText(context, error!), style: TextStyle(color: rustFor(context)))),
              if (all != null && all.isEmpty) Text(empty, style: TextStyle(color: ArgusColors.of(context).muted)),
              if (all != null && all.isNotEmpty)
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: DividedColumn(indent: 16, children: [for (final item in all) row(item)]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every address that the Bitcoin wallet showed or used (issue #103), as the Ergo
/// Addresses tool: what each holds, whether it was used, and its label.
class BtcAddressesScreen extends StatefulWidget {
  const BtcAddressesScreen({super.key, required this.wallet});

  final BitcoinWallet wallet;

  @override
  State<BtcAddressesScreen> createState() => _BtcAddressesScreenState();
}

class _BtcAddressesScreenState extends _BtcListState<BtcAddressesScreen, BtcAddressView> {
  @override
  Future<List<BtcAddressView>> read() => widget.wallet.addresses();

  Future<void> _label(String address) async {
    final label = await showAddressLabelDialog(
      context,
      address: address,
      existing: addressLabelService.labelFor(address) ?? '',
    );
    if (label == null) return;
    await addressLabelService.setLabel(address, label);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return page(
      context,
      title: l.commonAddresses,
      empty: l.homeNoAddressesDot,
      row: (a) {
        final label = addressLabelService.labelFor(a.address);
        final kind = a.change ? l.btcAddressChange(a.index.toString()) : l.btcAddressReceive(a.index.toString());
        return ListTile(
          key: Key('btc-address-${a.address}'),
          title: Text(label == null || label.isEmpty ? shortBtc(a.address) : '$label · ${shortBtc(a.address)}'),
          subtitle: Text(
            [kind, a.used ? l.btcAddressUsed : l.btcAddressUnused].join(' · '),
            style: TextStyle(color: muted),
          ),
          trailing: Text('${formatBtc(a.sat.toInt())} BTC'),
          onTap: () {
            Clipboard.setData(ClipboardData(text: a.address));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.btcAddressCopied)));
          },
          onLongPress: () => _label(a.address),
        );
      },
    );
  }
}

/// The unspent outputs of the Bitcoin wallet (issue #103), as the list of the Ergo UTXO
/// tool: amount, address and confirmations.
class BtcUtxosScreen extends StatefulWidget {
  const BtcUtxosScreen({super.key, required this.wallet});

  final BitcoinWallet wallet;

  @override
  State<BtcUtxosScreen> createState() => _BtcUtxosScreenState();
}

class _BtcUtxosScreenState extends _BtcListState<BtcUtxosScreen, BtcUtxoView> {
  @override
  Future<List<BtcUtxoView>> read() => widget.wallet.utxos();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return page(
      context,
      title: l.btcUtxosTitle,
      empty: l.btcUtxosNone,
      row: (u) => ListTile(
        key: Key('btc-utxo-${u.txid}:${u.vout}'),
        title: Text('${formatBtc(u.sat.toInt())} BTC'),
        subtitle: Text(
          [
            addressLabelService.labelFor(u.address) ?? shortBtc(u.address),
            u.confirmations == 0 ? l.btcUnconfirmed : l.btcConfirmations(u.confirmations.toString()),
          ].join(' · '),
          style: TextStyle(color: muted),
        ),
        trailing: Text('${u.txid.substring(0, 6)}…:${u.vout}', style: TextStyle(color: muted, fontSize: 12)),
        onTap: () {
          Clipboard.setData(ClipboardData(text: '${u.txid}:${u.vout}'));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.btcOutpointCopied)));
        },
      ),
    );
  }
}
