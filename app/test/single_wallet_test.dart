import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/services/public_wallet_sync.dart';
import 'package:argus_wallet/services/single_wallet.dart';
import 'package:argus_wallet/services/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/home_harness.dart';

// The app holds one Ergo wallet and no watched wallets (docs/celaut/ui.md,
// section 1). At each start, the migration removes what an earlier version
// left beyond that.

void main() {
  final api = HomeApi();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    publicWalletSync.setForeground(false);
  });
  tearDown(() => publicWalletSync.setForeground(true));

  group('the migration', () {
    Never noDelete(String id) => fail('no wallet is deleted, but $id was');

    test('the watched wallets and the default payer are removed; the rest stays', () async {
      SharedPreferences.setMockInitialValues({
        'argus_watch_only_addresses': '["9watched"]',
        'argus_watch_only_accounts_v1': '[]',
        'celaut_default_payer_v1': 'w1',
        'argus_token_descriptors_v1_watched:address:9watched': '{}',
        'argus_token_descriptors_v1_watched:account:xpub': '{}',
        'argus_token_descriptors_v1_w1': '{}',
        'argus_address_labels': '[]',
      });
      await enforceSingleWallet(walletIds: () async => ['w1'], deleteWallet: noDelete);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'argus_token_descriptors_v1_w1', 'argus_address_labels'});
    });

    test('the first wallet stays; every other wallet is deleted', () async {
      final deleted = <String>[];
      await enforceSingleWallet(
        walletIds: () async => ['first', 'second', 'third'],
        deleteWallet: (id) async => deleted.add(id),
      );
      expect(deleted, ['second', 'third']);
    });

    test('one wallet, or none: nothing is deleted', () async {
      await enforceSingleWallet(walletIds: () async => ['only'], deleteWallet: noDelete);
      await enforceSingleWallet(walletIds: () async => const [], deleteWallet: noDelete);
    });

    testWidgets('the user order of the wallets decides which one stays', (tester) async {
      FakeKeystore(wallets: ['w-a', 'w-b', 'w-c']).install(tester);
      final deleted = <String>[];
      await tester.runAsync(() async {
        await saveWallet('w-a', name: 'A');
        await saveWallet('w-b', name: 'B');
        await saveWallet('w-c', name: 'C');
        await walletService.setWalletOrder(['w-b', 'w-c', 'w-a']);
        await enforceSingleWallet(deleteWallet: (id) async => deleted.add(id));
      });
      expect(deleted, ['w-c', 'w-a']);
    });
  });

  group('the home screen', () {
    testWidgets('runs the migration before it reads the wallets', (tester) async {
      final keystore = FakeKeystore(wallets: ['w-keep', 'w-gone']);
      keystore.install(tester);
      await tester.runAsync(() async {
        await saveWallet('w-keep', name: 'Keep');
        await saveWallet('w-gone', name: 'Gone');
      });
      var runs = 0;
      await pumpHome(
        tester,
        enforceSingleWallet: () async {
          runs++;
          keystore.wallets = ['w-keep'];
        },
      );
      expect(runs, 1);
      expect(find.byKey(const ValueKey('overview-row-seed-w-keep')), findsOneWidget);
      expect(find.byKey(const ValueKey('overview-row-seed-w-gone')), findsNothing);
      await disposeHome(tester);
    });

    testWidgets('the Wallet tab is the balance and the transactions, and the details open over the bar', (
      tester,
    ) async {
      FakeKeystore(wallets: ['w-only']).install(tester);
      await tester.runAsync(() => saveWallet('w-only', name: 'Only'));
      await pumpHome(tester, computeHome: true);
      expect(find.byKey(const Key('home-tabs')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab-wallet')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wallet-summary')), findsOneWidget);
      // Ergo and Bitcoin, the same card each (issue #103).
      for (final coin in ['ergo', 'bitcoin']) {
        expect(find.byKey(Key('coin-$coin-balance')), findsOneWidget);
        expect(find.byKey(Key('coin-$coin-send')), findsOneWidget);
        expect(find.byKey(Key('coin-$coin-receive')), findsOneWidget);
        expect(find.byKey(Key('coin-$coin-more')), findsOneWidget);
      }
      expect(find.byKey(const Key('coin-ergo-empty')), findsOneWidget);
      // Nothing else is on the tab: no deposit, no list of wallets.
      expect(find.byKey(const Key('place-deposit')), findsNothing);
      expect(find.byKey(const Key('overview-action-send')), findsNothing);
      expect(find.byKey(const ValueKey('overview-row-seed-w-only')), findsNothing);
      await tester.tap(find.byKey(const Key('coin-ergo-more')));
      await tester.pumpAndSettle();
      // The page of the wallet, behind its gate, over the bar.
      expect(find.byKey(const Key('gate-unlock')), findsOneWidget);
      expect(find.byKey(const Key('home-tabs')), findsNothing);
      // Back is the Wallet tab.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-tabs')), findsOneWidget);
      expect(find.byKey(const Key('wallet-summary')), findsOneWidget);
      await disposeHome(tester);
    });

    testWidgets('the Wallets line of the Compute tab shows the Wallet tab', (tester) async {
      FakeKeystore(wallets: ['w-only']).install(tester);
      await tester.runAsync(() => saveWallet('w-only', name: 'Only'));
      await pumpHome(tester, computeHome: true);
      await tester.tap(find.byKey(const Key('tab-compute')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('compute-home-wallets')));
      await tester.tap(find.byKey(const Key('compute-home-wallets')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compute-home-wallets')), findsNothing);
      expect(find.byKey(const Key('wallet-summary')), findsOneWidget);
      await disposeHome(tester);
    });

    testWidgets('the Wallet tab shows no name of the wallet and no list of wallets', (tester) async {
      FakeKeystore(wallets: ['w-only']).install(tester);
      await tester.runAsync(() => saveWallet('w-only', name: 'Savings'));
      await pumpHome(tester, computeHome: true);
      await tester.tap(find.byKey(const Key('tab-wallet')));
      await tester.pumpAndSettle();
      // The coins by their names, never the name of the wallet, and no header of a list.
      expect(find.byKey(const Key('coin-ergo-more')), findsOneWidget);
      expect(find.text('Savings'), findsNothing);
      expect(find.text('WALLET'), findsNothing);
      // The page of the wallet and its gate do not name it either.
      await tester.tap(find.byKey(const Key('coin-ergo-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gate-unlock')), findsOneWidget);
      expect(find.text('Savings'), findsNothing);
      expect(find.text('Wallet'), findsWidgets);
      await disposeHome(tester);
    });

    testWidgets('with no wallet, the Wallet tab offers to create or restore one', (tester) async {
      FakeKeystore(wallets: const []).install(tester);
      await pumpHome(tester, computeHome: true);
      await tester.tap(find.byKey(const Key('tab-wallet')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('overview-create')), findsOneWidget);
      expect(find.byKey(const Key('overview-restore')), findsOneWidget);
      await disposeHome(tester);
    });
  });
}
