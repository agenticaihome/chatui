import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../ui/home/home_data.dart';
import '../ui/home/home_format.dart' show groupThousands;
import '../ui/home/overview_model.dart';
import '../ui/wallets_overview_screen.dart' show overviewData;
import 'coin_wallet.dart';

/// The Ergo wallet behind [CoinWallet]: the figures of the overview model (the public
/// snapshot while the wallet is locked), and the actions of the wallet's page, which the
/// dashboard gives ([onAction], [onActivity]). Nothing here changes how the Ergo wallet
/// works; it only reads it.
class ErgoCoinWallet implements CoinWallet {
  ErgoCoinWallet({required this.model, required this.onAction, this.onActivity});

  final WalletsOverviewModel model;

  /// Send, Receive or the page of the wallet (the details), as the dashboard opens them:
  /// the unlock first, then the action.
  final Future<void> Function(CoinAction action) onAction;

  /// A row of the latest transactions. Null: the page of the wallet.
  final Future<void> Function(String id)? onActivity;

  /// The latest transactions that the overview shows for each coin.
  static const recentLimit = 3;

  @override
  Coin get coin => Coin.ergo;

  @override
  String get name => appL10n.coinErgo;

  @override
  Set<WalletFeature> get features => {
        ...WalletFeature.values.where((f) => !(coinOnlyFeatures[Coin.bitcoin]?.containsKey(f) ?? false)),
      };

  @override
  CoinFigures get figures {
    final data = overviewData(model, hidden: false);
    final wallet = data.wallets.isEmpty ? null : data.wallets.first;
    final id = model.wallets.isEmpty ? null : model.wallets.first.walletId;
    final txs = id == null ? const <Map<String, dynamic>>[] : model.recentTransactions(id);
    return CoinFigures(
      total: data.totalNano,
      pending: data.pending,
      loading: data.loading,
      asOf: wallet?.asOf,
      recent: [for (final (i, tx) in txs.take(recentLimit).indexed) activityRow(tx, id: activityRowId(tx, i))],
      note: data.notLoaded > 0 ? appL10n.homeWalletsNotLoaded(data.notLoaded, groupThousands('${data.notLoaded}')) : null,
    );
  }

  @override
  Future<void> refresh() => model.refresh();

  @override
  Future<void> act(BuildContext context, CoinAction action) => onAction(action);

  @override
  Future<void> openActivity(BuildContext context, String id) =>
      onActivity == null ? onAction(CoinAction.details) : onActivity!(id);

  @override
  void addListener(VoidCallback listener) => model.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => model.removeListener(listener);
}
