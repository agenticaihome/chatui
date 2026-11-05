import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge/api/btc.dart';
import '../format.dart' show formatSyncAge;
import '../l10n/l10n.dart';
import '../ui/bitcoin/bitcoin_receive_screen.dart';
import '../ui/bitcoin/bitcoin_send_screen.dart';
import '../ui/bitcoin/bitcoin_wallet_screen.dart';
import '../ui/home/home_format.dart';
import '../ui/home/home_models.dart';
import '../wallets/coin_wallet.dart';
import 'bitcoin_settings.dart';
import 'bitcoin_wallet_api.dart';
import 'btc_snapshot.dart';

/// The Bitcoin wallet behind [CoinWallet] (issue #103).
///
/// While the wallet is open, a refresh opens the Bitcoin wallet and reads it with its key,
/// and keeps its public descriptors and a snapshot of its figures ([BtcSnapshotStore]).
/// While the wallet is locked, a refresh reads the figures again with the descriptors and
/// no key, as the Ergo wallet reads its public addresses; before the first unlock there is
/// nothing to read.
class BitcoinCoinWallet extends ChangeNotifier implements CoinWallet {
  BitcoinCoinWallet({
    required this.walletId,
    this.api = const AppBitcoinWallet(),
    this.store = const BtcSnapshotStore(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    api.settings.addListener(_onSettings);
  }

  /// The id of the app's wallet, also while it is locked; null with no wallet.
  final String? Function() walletId;

  final BitcoinWallet api;
  final BtcSnapshotStore store;
  final DateTime Function() _clock;

  /// The latest transactions that the overview shows, as for Ergo.
  static const recentLimit = 3;

  /// A locked wallet is read again at most this often by [refreshIfDue].
  static const refreshEvery = Duration(minutes: 5);

  BtcSnapshot? _snapshot;
  bool _loading = false;
  bool _read = false;
  Object? _error;
  DateTime? _lastRefresh;
  bool _lastUnlocked = false;
  String? _for;

  BtcSnapshot? get snapshot => _snapshot;

  /// Another network or server: the snapshot of that network, and a read there.
  void _onSettings() {
    if (!_read || _for == '${walletId()}/${_network.name}') return;
    unawaited(reload().then((_) => refreshIfDue()));
  }

  @override
  void dispose() {
    api.settings.removeListener(_onSettings);
    super.dispose();
  }

  @override
  Coin get coin => Coin.bitcoin;

  @override
  String get name => appL10n.coinBitcoin;

  @override
  Set<WalletFeature> get features => {
        ...WalletFeature.values.where((f) => !(coinOnlyFeatures[Coin.ergo]?.containsKey(f) ?? false)),
      };

  BtcNetworkName get _network => api.settings.network;

  @override
  CoinFigures get figures {
    final s = _snapshot;
    final testNetwork = _network.real ? null : _network.name;
    if (s == null) {
      return CoinFigures(
        loading: _loading,
        testNetwork: testNetwork,
        note: _loading ? null : (_error != null ? appL10n.btcOverviewUnreachable : appL10n.btcOverviewUnlockOnce),
      );
    }
    final pending = s.pendingSat > 0
        ? PendingBalance(confirmedNano: s.confirmedSat + s.immatureSat, pendingInNano: s.pendingSat, transactions: 1)
        : null;
    final age = _clock().difference(s.at);
    return CoinFigures(
      total: s.totalSat,
      pending: pending,
      loading: _loading,
      asOf: api.unlocked && age < refreshEvery ? null : formatSyncAge(s.at, now: _clock()),
      testNetwork: testNetwork,
      recent: [for (final t in s.transactions.take(recentLimit)) btcActivityRow(t)],
      note: _error != null ? appL10n.btcOverviewUnreachable : null,
    );
  }

  /// Keep figures that a screen of the Bitcoin wallet read.
  Future<void> remember(BtcWalletView view, List<BtcTxView> txs) async {
    final id = walletId();
    if (id == null) return;
    final snapshot = BtcSnapshot.of(view, txs, _clock());
    _snapshot = snapshot;
    _error = null;
    notifyListeners();
    await store.saveSnapshot(id, snapshot);
    if (api.unlocked) {
      try {
        await store.saveDescriptors(id, await api.descriptors());
      } catch (_) {
        // The descriptors come again at the next refresh while unlocked.
      }
    }
  }

  /// Read the kept snapshot of the current wallet and network, with no network call.
  Future<void> load() async {
    if (!api.settings.loaded) await api.settings.load();
    final id = walletId();
    final key = '$id/${_network.name}';
    if (_read && _for == key) return;
    _for = key;
    _read = true;
    _snapshot = id == null ? null : await store.snapshot(id, _network.name);
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    if (_loading) return;
    await load();
    final id = walletId();
    if (id == null) return;
    _loading = true;
    _lastRefresh = _clock();
    _lastUnlocked = api.unlocked;
    notifyListeners();
    try {
      if (api.unlocked) {
        await api.open();
        final view = await api.sync();
        await remember(view, await api.transactions());
      } else {
        final descriptors = await store.descriptors(id, _network.name);
        if (descriptors != null) {
          final read = await api.watch(descriptors);
          await remember(read.wallet, read.transactions);
        }
      }
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// The poll's share: a refresh when the last one is [refreshEvery] old, or when the
  /// wallet was unlocked since (the read with the key keeps the descriptors).
  Future<void> refreshIfDue() async {
    final last = _lastRefresh;
    final unlockedSince = api.unlocked && !_lastUnlocked;
    if (last != null && !unlockedSince && _clock().difference(last) < refreshEvery) return;
    await refresh();
  }

  /// The network or the wallet changed: the snapshot of the other one is read again.
  Future<void> reload() async {
    _read = false;
    _snapshot = null;
    _error = null;
    _lastRefresh = null;
    _lastUnlocked = false;
    await load();
  }

  Future<bool> _open(BuildContext context) async {
    if (!await api.unlock(context)) return false;
    await api.open();
    return true;
  }

  @override
  Future<void> act(BuildContext context, CoinAction action) async {
    final navigator = Navigator.of(context);
    switch (action) {
      case CoinAction.details:
        await navigator.push<void>(
          MaterialPageRoute(builder: (_) => BitcoinWalletScreen(wallet: api, onRead: remember)),
        );
        await reload();
      case CoinAction.send:
        if (!context.mounted || !await _open(context)) return;
        final txid = await navigator.push<String>(MaterialPageRoute(builder: (_) => BitcoinSendScreen(wallet: api)));
        if (txid != null) await refresh();
      case CoinAction.receive:
        if (!context.mounted || !await _open(context)) return;
        final view = await api.open();
        await navigator.push<void>(
          MaterialPageRoute(builder: (_) => BitcoinReceiveScreen(wallet: api, address: view.receiveAddress)),
        );
    }
  }

  @override
  Future<void> openActivity(BuildContext context, String id) => act(context, CoinAction.details);
}

/// A Bitcoin transaction as the rows of the overview show it, like an Ergo one.
ActivityRowData btcActivityRow(BtcTxView t) {
  final net = t.netSat;
  return ActivityRowData(
    id: t.txid,
    kind: net >= 0 ? ActivityKind.received : ActivityKind.sent,
    time: shortActivityTime(t.time == BigInt.zero ? null : t.time.toInt() * 1000),
    legs: [AmountLeg(amount: BigInt.from(net), decimals: 8, unit: 'BTC')],
    pending: t.confirmations == 0,
  );
}
