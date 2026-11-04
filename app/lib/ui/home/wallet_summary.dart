import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/privacy_service.dart';
import '../../services/wallet_service.dart';
import '../wallets_overview_screen.dart' show overviewData;
import '../layout.dart';
import 'home_data.dart';
import 'home_glass.dart';
import 'home_hero.dart';
import 'home_rows.dart';
import 'home_scene.dart';
import 'home_style.dart';
import 'overview_model.dart';

/// The Wallet tab, as little as it can be: the ERG that the wallet holds and its latest
/// transactions. Send, Receive, the tokens, the addresses, "Deposit to a node" and the
/// rest are in the details, which is the page of the wallet and has its own look (Ergo's
/// black and orange).
///
/// Nothing here needs an unlock: a locked wallet shows the figures of its public snapshot,
/// and its latest transactions come from the same refresh.
class WalletSummaryScreen extends StatelessWidget {
  const WalletSummaryScreen({super.key, required this.model, required this.onDetails, this.onBitcoin});

  final WalletsOverviewModel model;

  /// Opens the page of the wallet, the details. A locked wallet asks the phone to unlock
  /// first, as it does from anywhere.
  final VoidCallback onDetails;

  /// Opens the Bitcoin wallet of the same words (issue #92). Null: no button.
  final VoidCallback? onBitcoin;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.chatsTabWallet)),
      body: ReadableWidth(
        child: ListenableBuilder(
          listenable: Listenable.merge([model, privacyService, walletService.metadataChanges]),
          builder: (context, _) {
            final hidden = privacyService.hideBalances;
            final data = overviewData(model, hidden: hidden);
            final wallet = data.wallets.isEmpty ? null : data.wallets.first;
            final id = model.wallets.isEmpty ? null : model.wallets.first.walletId;
            final rows = [
              if (id != null)
                for (final (i, tx) in model.recentTransactions(id).indexed)
                  activityRow(tx, id: activityRowId(tx, i)),
            ];
            return RefreshIndicator(
              onRefresh: model.refresh,
              child: ListView(
                key: const Key('wallet-summary'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(homeGutter, 8, homeGutter, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HomeBalance(
                          label: l.homeBalanceLabel,
                          figureKey: const Key('summary-balance'),
                          pendingKey: const Key('summary-balance-pending'),
                          nanoErg: data.totalNano,
                          loading: data.loading,
                          notLoaded: data.notLoaded,
                          asOf: wallet?.asOf,
                          pending: data.pending,
                          hidden: hidden,
                          onToggleHidden: () => privacyService.setHideBalances(!hidden),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          key: const Key('wallet-details'),
                          onPressed: onDetails,
                          icon: const Icon(Icons.chevron_right),
                          iconAlignment: IconAlignment.end,
                          label: Text(l.walletSummaryDetails),
                        ),
                        if (onBitcoin != null) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const Key('wallet-bitcoin'),
                            onPressed: onBitcoin,
                            icon: const Icon(Icons.currency_bitcoin),
                            label: Text(l.btcWalletButton),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(l.walletSummaryLatest.toUpperCase(), style: t.label),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: homeGutter, vertical: 16),
                      child: Text(
                        l.walletSummaryNoTransactions,
                        key: const Key('wallet-summary-empty'),
                        style: t.secondary,
                      ),
                    )
                  else
                    GlassCard(
                      dividers: true,
                      children: [
                        for (final row in rows)
                          HomeActivityRow(item: row, hidden: hidden, onTap: onDetails),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    return SceneBackdrop(child: scaffold);
  }
}
