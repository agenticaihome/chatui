import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../bridge/api/btc.dart';

/// The last figures of the Bitcoin wallet, kept so that the overview shows them while the
/// wallet is locked (issue #103), as the Ergo wallet keeps its public snapshot.
class BtcSnapshot {
  const BtcSnapshot({
    required this.network,
    required this.confirmedSat,
    required this.pendingSat,
    required this.immatureSat,
    required this.receiveAddress,
    required this.at,
    this.transactions = const [],
  });

  /// The number of transactions that a snapshot keeps.
  static const keep = 10;

  final String network;
  final int confirmedSat;
  final int pendingSat;
  final int immatureSat;
  final String receiveAddress;

  /// When the figures were read.
  final DateTime at;

  /// The newest first.
  final List<BtcTxView> transactions;

  int get totalSat => confirmedSat + pendingSat + immatureSat;

  factory BtcSnapshot.of(BtcWalletView view, List<BtcTxView> txs, DateTime at) => BtcSnapshot(
        network: view.network,
        confirmedSat: view.confirmedSat.toInt(),
        pendingSat: view.pendingSat.toInt(),
        immatureSat: view.immatureSat.toInt(),
        receiveAddress: view.receiveAddress,
        at: at,
        transactions: txs.take(keep).toList(),
      );

  Map<String, Object> toJson() => {
        'network': network,
        'confirmed': confirmedSat,
        'pending': pendingSat,
        'immature': immatureSat,
        'receive': receiveAddress,
        'at': at.millisecondsSinceEpoch,
        'txs': [
          for (final t in transactions)
            {
              'txid': t.txid,
              'net': t.netSat,
              'fee': t.feeSat.toInt(),
              'feeKnown': t.feeKnown,
              'conf': t.confirmations,
              'time': t.time.toInt(),
            },
        ],
      };

  static BtcSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    int n(Object? v) => v is num ? v.toInt() : 0;
    final network = json['network'];
    final at = json['at'];
    if (network is! String || at is! num) return null;
    final txs = <BtcTxView>[];
    for (final t in json['txs'] is List ? json['txs'] as List : const []) {
      if (t is! Map || t['txid'] is! String) continue;
      txs.add(BtcTxView(
        txid: t['txid'] as String,
        netSat: n(t['net']),
        feeSat: BigInt.from(n(t['fee'])),
        feeKnown: t['feeKnown'] == true,
        confirmations: n(t['conf']),
        time: BigInt.from(n(t['time'])),
      ));
    }
    return BtcSnapshot(
      network: network,
      confirmedSat: n(json['confirmed']),
      pendingSat: n(json['pending']),
      immatureSat: n(json['immature']),
      receiveAddress: json['receive'] is String ? json['receive'] as String : '',
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      transactions: txs,
    );
  }
}

/// Where the Bitcoin snapshot and the public descriptors are kept: the app's preferences,
/// by wallet and by network, as the Ergo snapshot. The descriptors give the addresses of
/// the wallet and no key.
class BtcSnapshotStore {
  const BtcSnapshotStore();

  static String _snapshotKey(String walletId, String network) => 'btc_snapshot_v1_${walletId}_$network';
  static String _watchKey(String walletId, String network) => 'btc_watch_v1_${walletId}_$network';

  Future<BtcSnapshot?> snapshot(String walletId, String network) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey(walletId, network));
    if (raw == null) return null;
    try {
      return BtcSnapshot.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> saveSnapshot(String walletId, BtcSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey(walletId, snapshot.network), jsonEncode(snapshot.toJson()));
  }

  Future<BtcDescriptors?> descriptors(String walletId, String network) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_watchKey(walletId, network));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['receive'] is! String || json['change'] is! String) return null;
      return BtcDescriptors(network: network, receive: json['receive'] as String, change: json['change'] as String);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveDescriptors(String walletId, BtcDescriptors d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_watchKey(walletId, d.network), jsonEncode({'receive': d.receive, 'change': d.change}));
  }
}
