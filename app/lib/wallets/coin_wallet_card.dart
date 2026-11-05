import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../ui/home/home_glass.dart';
import '../ui/home/home_hero.dart';
import '../ui/home/home_models.dart' show WalletAction;
import '../ui/home/home_rows.dart';
import '../ui/home/home_style.dart';
import '../ui/home/home_widgets.dart';
import '../ui/home/wallet_actions.dart';
import 'coin_wallet.dart';

/// The overview's actions, in the shapes of the wallet page's round actions: Send, Receive,
/// and More, which opens the page of the coin (the details).
const _actions = {
  WalletAction.send: CoinAction.send,
  WalletAction.receive: CoinAction.receive,
  WalletAction.more: CoinAction.details,
};

/// One coin of the overview (issue #103): the balance, the round actions and the latest
/// transactions. Every coin has this same card, at the same size, in the same order of
/// parts: no coin is the main one.
class CoinWalletCard extends StatelessWidget {
  const CoinWalletCard({super.key, required this.wallet, required this.hidden, this.onToggleHidden});

  final CoinWallet wallet;
  final bool hidden;
  final VoidCallback? onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final l = context.l10n;
    final coin = wallet.coin;
    final f = wallet.figures;
    final name = coin.name;
    return Column(
      key: Key('coin-$name'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: homeGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeBalance(
                label: wallet.name,
                labelExtra: f.testNetwork == null ? null : l.coinTestNetwork(f.testNetwork!),
                figureKey: Key('coin-$name-balance'),
                pendingKey: Key('coin-$name-pending'),
                nanoErg: f.total,
                unit: coin.unit,
                decimals: coin.decimals,
                loading: f.loading,
                asOf: f.asOf,
                pending: f.pending,
                hidden: hidden,
                onToggleHidden: onToggleHidden,
              ),
              if (f.note case final note?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(note, key: Key('coin-$name-note'), style: t.secondary),
                ),
              const SizedBox(height: 16),
              HomeActionCircles(
                keyPrefix: 'coin-$name',
                actions: _actions.keys.toList(),
                onAction: (a) => wallet.act(context, _actions[a]!),
              ),
            ],
          ),
        ),
        HomeHeading(
          title: l.walletSummaryLatest,
          action: l.homeViewAll,
          actionKey: Key('coin-$name-all'),
          onAction: () => wallet.act(context, CoinAction.details),
        ),
        GlassCard(
          key: Key('coin-$name-activity'),
          dividers: true,
          children: [
            if (f.recent.isEmpty)
              HomeLineRow(
                inkKey: Key('coin-$name-empty'),
                semanticLabel: l.walletSummaryNoTransactions,
                leading: Icon(Icons.inbox_outlined, size: 18, color: t.muted),
                text: TextSpan(text: l.walletSummaryNoTransactions),
              )
            else
              for (final row in f.recent)
                HomeActivityRow(item: row, hidden: hidden, onTap: () => wallet.openActivity(context, row.id)),
          ],
        ),
      ],
    );
  }
}
