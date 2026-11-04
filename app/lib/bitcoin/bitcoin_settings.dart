import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Bitcoin networks, by the names of nodo's ledger declaration (`network=`).
enum BtcNetworkName {
  mainnet,
  testnet,
  signet,
  regtest;

  static BtcNetworkName? parse(String? name) {
    for (final n in values) {
      if (n.name == name) return n;
    }
    return null;
  }

  /// True only on mainnet: these coins have a value.
  bool get real => this == mainnet;
}

/// The network and the Esplora server of the Bitcoin wallet (issue #92), as
/// [NetworkController] keeps the nodes and the explorer of Ergo.
///
/// The default network is signet: the Bitcoin wallet is new, and its coins on signet have
/// no value. Mainnet is a choice in the settings, after a warning.
class BitcoinSettings extends ChangeNotifier {
  BitcoinSettings({this.defaultNetwork = BtcNetworkName.signet});

  static const _networkKey = 'btc_network_v1';
  static const _serverKeyPrefix = 'btc_server_v1_';

  final BtcNetworkName defaultNetwork;

  BtcNetworkName network = BtcNetworkName.signet;

  /// The Esplora server of each network that the user set. Missing or empty: the default
  /// of the network (`btc_default_server`); regtest has none.
  final Map<BtcNetworkName, String> servers = {};

  bool loaded = false;

  String serverOf(BtcNetworkName n) => servers[n] ?? '';

  String get server => serverOf(network);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    network = BtcNetworkName.parse(prefs.getString(_networkKey)) ?? defaultNetwork;
    for (final n in BtcNetworkName.values) {
      final s = prefs.getString('$_serverKeyPrefix${n.name}');
      if (s != null && s.trim().isNotEmpty) servers[n] = s.trim();
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> setNetwork(BtcNetworkName next) async {
    network = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_networkKey, next.name);
  }

  /// [url] empty: back to the default server of [n].
  Future<void> setServer(BtcNetworkName n, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      servers.remove(n);
    } else {
      servers[n] = trimmed;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove('$_serverKeyPrefix${n.name}');
    } else {
      await prefs.setString('$_serverKeyPrefix${n.name}', trimmed);
    }
  }
}

final bitcoinSettings = BitcoinSettings();
