import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/privacy_service.dart';
import '../../services/wallet_service.dart';
import '../../wallets/coin_wallet.dart';
import '../../wallets/coin_wallet_card.dart';
import '../layout.dart';
import 'home_scene.dart';

/// The Wallet tab (issue #103): every coin of the wallet the same way, one
/// [CoinWalletCard] each, Ergo and Bitcoin, in the same layout, the same size and with
/// the same actions. Neither is the main wallet. Send, Receive and More (the page of the
/// coin) are on each card; the rest of a coin is on its page, which has its own look.
///
/// Nothing here needs an unlock: a locked wallet shows its last figures, and reads them
/// again with no key when it can.
class WalletSummaryScreen extends StatelessWidget {
  const WalletSummaryScreen({super.key, required this.coins});

  /// The coins, in the order of [Coin].
  final List<CoinWallet> coins;

  Future<void> _refresh() async {
    await Future.wait([for (final c in coins) c.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ordered = inCoinOrder(coins);
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.chatsTabWallet)),
      body: ReadableWidth(
        child: ListenableBuilder(
          listenable: Listenable.merge([...ordered, privacyService, walletService.metadataChanges]),
          builder: (context, _) {
            final hidden = privacyService.hideBalances;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const Key('wallet-summary'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 8, bottom: 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  for (final (i, coin) in ordered.indexed) ...[
                    if (i > 0) const SizedBox(height: 32),
                    CoinWalletCard(
                      wallet: coin,
                      hidden: hidden,
                      onToggleHidden: () => privacyService.setHideBalances(!hidden),
                    ),
                  ],
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
