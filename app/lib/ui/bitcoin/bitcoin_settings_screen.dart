import 'package:flutter/material.dart';

import '../../bitcoin/bitcoin_settings.dart';
import '../../bridge/api/btc.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import 'bitcoin_wallet_screen.dart';

/// The network and the Esplora server of the Bitcoin wallet. Mainnet asks first. Pops
/// with true when something changed.
class BitcoinSettingsScreen extends StatefulWidget {
  const BitcoinSettingsScreen({super.key, required this.settings, this.defaultServer});

  final BitcoinSettings settings;

  /// The default server of a network. Tests give their own.
  final String Function(BtcNetworkName network)? defaultServer;

  @override
  State<BitcoinSettingsScreen> createState() => _BitcoinSettingsScreenState();
}

class _BitcoinSettingsScreenState extends State<BitcoinSettingsScreen> {
  late BtcNetworkName _network = widget.settings.network;
  late final _server = TextEditingController(text: widget.settings.serverOf(_network));
  String? _serverError;

  String _default(BtcNetworkName n) =>
      widget.defaultServer?.call(n) ?? btcDefaultServer(network: n.name);

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  String _label(BtcNetworkName n) {
    final l = context.l10n;
    return switch (n) {
      BtcNetworkName.mainnet => l.btcNetMainnet,
      BtcNetworkName.testnet => l.btcNetTestnet,
      BtcNetworkName.signet => l.btcNetSignet,
      BtcNetworkName.regtest => l.btcNetRegtest,
    };
  }

  Future<void> _pick(BtcNetworkName n) async {
    if (n == _network) return;
    if (n.real) {
      final l = context.l10n;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.btcMainnetWarnTitle),
          content: Text(l.btcMainnetWarnBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.commonCancel)),
            FilledButton(
              key: const Key('btc-mainnet-ok'),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.btcMainnetWarnOk),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _network = n;
      _server.text = widget.settings.serverOf(n);
      _serverError = null;
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    final url = _server.text.trim();
    if (url.isNotEmpty && !(url.startsWith('https://') || url.startsWith('http://'))) {
      setState(() => _serverError = l.btcServerInvalid);
      return;
    }
    if (url.isEmpty && _default(_network).isEmpty) {
      setState(() => _serverError = l.btcServerNoDefault);
      return;
    }
    final changed = _network != widget.settings.network || url != widget.settings.serverOf(_network);
    await widget.settings.setServer(_network, url);
    await widget.settings.setNetwork(_network);
    if (mounted) Navigator.of(context).pop(changed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    final def = _default(_network);
    return BitcoinLook(
      child: Scaffold(
        appBar: AppBar(title: Text(l.btcSettingsTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionLabel(l.btcNetworkTitle),
              RadioGroup<BtcNetworkName>(
                groupValue: _network,
                onChanged: (v) => _pick(v ?? _network),
                child: Column(
                  children: [
                    for (final n in BtcNetworkName.values)
                      RadioListTile<BtcNetworkName>(
                        key: Key('btc-net-${n.name}'),
                        contentPadding: EdgeInsets.zero,
                        value: n,
                        title: Text(_label(n)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionLabel(l.btcServerTitle),
              const SizedBox(height: 6),
              TextField(
                key: const Key('btc-server'),
                controller: _server,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: def.isEmpty ? null : def,
                  helperText: def.isEmpty ? l.btcServerNoDefault : l.btcServerHint(def),
                  helperMaxLines: 2,
                  errorText: _serverError,
                ),
              ),
              const SizedBox(height: 16),
              Text(l.btcSeedNote, style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 20),
              FilledButton(key: const Key('btc-settings-save'), onPressed: _save, child: Text(l.btcSave)),
            ],
          ),
        ),
      ),
    );
  }
}
