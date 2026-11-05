import 'package:argus_wallet/bitcoin/bitcoin_coin_wallet.dart';
import 'package:argus_wallet/bitcoin/btc_format.dart';
import 'package:argus_wallet/bitcoin/btc_snapshot.dart';
import 'package:argus_wallet/bridge/api/btc.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/services/privacy_service.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/bitcoin/bitcoin_receive_screen.dart';
import 'package:argus_wallet/ui/bitcoin/bitcoin_send_screen.dart';
import 'package:argus_wallet/ui/bitcoin/bitcoin_wallet_screen.dart';
import 'package:argus_wallet/ui/bitcoin/btc_lists_screen.dart';
import 'package:argus_wallet/ui/bitcoin/btc_tx_screen.dart';
import 'package:argus_wallet/ui/home/home_models.dart';
import 'package:argus_wallet/ui/home/overview_model.dart';
import 'package:argus_wallet/ui/home/wallet_summary.dart';
import 'package:argus_wallet/wallets/coin_wallet.dart';
import 'package:argus_wallet/wallets/coin_wallet_card.dart';
import 'package:argus_wallet/wallets/ergo_coin_wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_bitcoin.dart';

// The shared wallet interface of issue #103: each coin behind [CoinWallet], the same card
// for each on the Wallet tab, and the Bitcoin screens that bring it to the level of Ergo.

/// A coin for the shared widgets: fixed figures, and the actions it was asked for.
class _FakeCoin extends ChangeNotifier implements CoinWallet {
  _FakeCoin(this.coin, this.figures);

  @override
  final Coin coin;

  @override
  CoinFigures figures;

  final acted = <CoinAction>[];
  final opened = <String>[];
  int refreshed = 0;

  @override
  String get name => coin == Coin.ergo ? 'Ergo' : 'Bitcoin';

  @override
  Set<WalletFeature> get features => WalletFeature.values.toSet();

  @override
  Future<void> refresh() async => refreshed++;

  @override
  Future<void> act(BuildContext context, CoinAction action) async => acted.add(action);

  @override
  Future<void> openActivity(BuildContext context, String id) async => opened.add(id);
}

ActivityRowData _row(String id, int amount, int decimals, String unit) => ActivityRowData(
      id: id,
      kind: amount >= 0 ? ActivityKind.received : ActivityKind.sent,
      time: '',
      legs: [AmountLeg(amount: BigInt.from(amount), decimals: decimals, unit: unit)],
    );

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: argusTheme(watchful: false), home: home));
  await tester.pumpAndSettle();
}

/// A screen with a button that pushes [page], and what it popped with.
Future<List<Object?>> _pushFrom(WidgetTester tester, Widget page) async {
  final popped = <Object?>[];
  await _pump(
    tester,
    Builder(
      builder: (ctx) => TextButton(
        onPressed: () async => popped.add(await Navigator.of(ctx).push<Object?>(MaterialPageRoute(builder: (_) => page))),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the interface', () {
    test('each coin has its unit and decimals', () {
      expect((Coin.ergo.unit, Coin.ergo.decimals), ('ERG', 9));
      expect((Coin.bitcoin.unit, Coin.bitcoin.decimals), ('BTC', 8));
    });

    test('each action of Ergo also exists for Bitcoin, except the documented ones', () {
      final ergo = ErgoCoinWallet(model: WalletsOverviewModel(), onAction: (_) async {}).features;
      final bitcoin = BitcoinCoinWallet(walletId: () => 'w', api: FakeBitcoin()).features;
      // The core of a wallet is on both.
      for (final f in [
        WalletFeature.balance,
        WalletFeature.pending,
        WalletFeature.lockedFigures,
        WalletFeature.receive,
        WalletFeature.receiveAmount,
        WalletFeature.send,
        WalletFeature.sendAll,
        WalletFeature.scanToSend,
        WalletFeature.addressBook,
        WalletFeature.feeChoice,
        WalletFeature.history,
        WalletFeature.transactionDetail,
        WalletFeature.addresses,
        WalletFeature.utxos,
        WalletFeature.depositToNode,
        WalletFeature.backupRestore,
        WalletFeature.lock,
        WalletFeature.networkSettings,
      ]) {
        expect(ergo, contains(f), reason: '$f on Ergo');
        expect(bitcoin, contains(f), reason: '$f on Bitcoin');
      }
      // What only one coin has is a decision, with its reason.
      expect(ergo.difference(bitcoin), coinOnlyFeatures[Coin.ergo]!.keys.toSet());
      expect(bitcoin.difference(ergo), coinOnlyFeatures[Coin.bitcoin]!.keys.toSet());
      for (final reasons in coinOnlyFeatures.values) {
        for (final reason in reasons.values) {
          expect(reason, isNotEmpty);
        }
      }
      // Every feature is on at least one coin.
      expect(ergo.union(bitcoin), WalletFeature.values.toSet());
    });

    test('the overview lists the coins in the order of Coin', () {
      final b = _FakeCoin(Coin.bitcoin, CoinFigures.unknown);
      final e = _FakeCoin(Coin.ergo, CoinFigures.unknown);
      expect(inCoinOrder([b, e]), [e, b]);
    });
  });

  group('the Ergo adapter', () {
    testWidgets('Send, Receive and More go to the wallet page; a row opens it too', (tester) async {
      final asked = <CoinAction>[];
      final ergo = ErgoCoinWallet(model: WalletsOverviewModel(), onAction: (a) async => asked.add(a));
      expect(ergo.coin, Coin.ergo);
      expect(ergo.name, appL10n.coinErgo);
      await _pump(tester, const SizedBox(key: Key('here')));
      final context = tester.element(find.byKey(const Key('here')));
      for (final a in CoinAction.values) {
        await ergo.act(context, a);
      }
      await ergo.openActivity(context, 'tx1');
      expect(asked, [...CoinAction.values, CoinAction.details]);
      // No wallet: no figures, not zero.
      expect(ergo.figures.total, isNull);
      expect(ergo.figures.recent, isEmpty);
    });
  });

  group('the Bitcoin adapter', () {
    test('before the first unlock: no figures, and why', () async {
      final api = FakeBitcoin(unlocked: false);
      final btc = BitcoinCoinWallet(walletId: () => 'w1', api: api);
      await btc.refresh();
      expect(btc.figures.total, isNull);
      expect(btc.figures.note, appL10n.btcOverviewUnlockOnce);
      expect(btc.figures.testNetwork, 'signet');
      expect(api.calls, isEmpty);
    });

    test('unlocked: it reads with the key and keeps the snapshot and the descriptors', () async {
      final api = FakeBitcoin();
      var now = DateTime(2026, 11, 5, 12);
      final btc = BitcoinCoinWallet(walletId: () => 'w1', api: api, clock: () => now);
      await btc.refresh();
      expect(api.calls, ['open', 'sync', 'descriptors']);
      final f = btc.figures;
      expect(f.total, 155000);
      expect(f.pending!.pendingDeltaNano, 5000);
      expect(f.pending!.confirmedNano, 150000);
      expect(f.asOf, isNull);
      expect(f.recent.single.id, fakeBtcTxid);
      expect(f.recent.single.legs.single.unit, 'BTC');
      const store = BtcSnapshotStore();
      expect((await store.snapshot('w1', 'signet'))!.totalSat, 155000);
      expect((await store.descriptors('w1', 'signet'))!.receive, fakeDescriptors.receive);
      expect(await store.snapshot('w2', 'signet'), isNull);

      // Within five minutes the poll does not read again.
      now = now.add(const Duration(minutes: 4));
      await btc.refreshIfDue();
      expect(api.calls.where((c) => c == 'sync'), hasLength(1));
      now = now.add(const Duration(minutes: 2));
      await btc.refreshIfDue();
      expect(api.calls.where((c) => c == 'sync'), hasLength(2));
    });

    test('locked: the snapshot shows at once, then a read with the descriptors and no key', () async {
      final api = FakeBitcoin();
      var now = DateTime(2026, 11, 5, 12);
      await BitcoinCoinWallet(walletId: () => 'w1', api: api, clock: () => now).refresh();

      now = now.add(const Duration(hours: 3));
      final locked = FakeBitcoin(unlocked: false);
      final btc = BitcoinCoinWallet(walletId: () => 'w1', api: locked, clock: () => now);
      await btc.load();
      expect(btc.figures.total, 155000);
      expect(btc.figures.asOf, isNotNull);
      await btc.refresh();
      expect(locked.calls, ['watch signet']);
      expect(btc.figures.total, 90000);

      // An unlock makes the next poll read with the key, also within five minutes.
      locked.unlocked = true;
      await btc.refreshIfDue();
      expect(locked.calls.last, 'descriptors');
    });

    test('the server does not answer: the last figures stay, with a note', () async {
      final api = FakeBitcoin();
      final btc = BitcoinCoinWallet(walletId: () => 'w1', api: api);
      await btc.refresh();
      api.failWith = const BtcError(kind: BtcErrorKind.unreachable, message: 'no route');
      await btc.refresh();
      expect(btc.figures.total, 155000);
      expect(btc.figures.note, appL10n.btcOverviewUnreachable);
    });

    test('a transaction as a row of the overview', () {
      final sent = btcActivityRow(
        BtcTxView(txid: 't', netSat: -30282, feeSat: BigInt.from(282), feeKnown: true, confirmations: 0, time: BigInt.zero),
      );
      expect(sent.kind, ActivityKind.sent);
      expect(sent.pending, isTrue);
      expect(sent.time, '');
      expect(sent.legs.single.amount, BigInt.from(-30282));
      expect(sent.legs.single.decimals, 8);
    });

    test('the snapshot is read back as it was saved', () {
      final s = BtcSnapshot(
        network: 'regtest',
        confirmedSat: 1,
        pendingSat: 2,
        immatureSat: 3,
        receiveAddress: fakeBtcAddress,
        at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        transactions: [
          BtcTxView(txid: 'a', netSat: -5, feeSat: BigInt.from(2), feeKnown: true, confirmations: 4, time: BigInt.from(9)),
        ],
      );
      final back = BtcSnapshot.fromJson(s.toJson())!;
      expect((back.network, back.totalSat, back.receiveAddress, back.at), ('regtest', 6, fakeBtcAddress, s.at));
      expect(back.transactions.single, s.transactions.single);
      expect(BtcSnapshot.fromJson('junk'), isNull);
    });
  });

  group('the same card for each coin', () {
    testWidgets('Ergo and Bitcoin have the same parts, and the actions of their own coin', (tester) async {
      final ergo = _FakeCoin(
        Coin.ergo,
        CoinFigures(total: 2500000000, recent: [_row('e1', 2500000000, 9, 'ERG')]),
      );
      final btc = _FakeCoin(
        Coin.bitcoin,
        CoinFigures(
          total: 155000,
          pending: const PendingBalance(confirmedNano: 150000, pendingInNano: 5000, transactions: 1),
          testNetwork: 'signet',
          recent: [_row('b1', 150000, 8, 'BTC')],
        ),
      );
      await _pump(tester, WalletSummaryScreen(coins: [btc, ergo]));
      for (final coin in ['ergo', 'bitcoin']) {
        for (final part in ['balance', 'send', 'receive', 'more', 'activity', 'all']) {
          expect(find.byKey(Key('coin-$coin-$part')), findsOneWidget, reason: '$coin $part');
        }
      }
      // Ergo first, at the same size as Bitcoin.
      final ergoCard = tester.getRect(find.byKey(const Key('coin-ergo')));
      final btcCard = tester.getRect(find.byKey(const Key('coin-bitcoin')));
      expect(ergoCard.top, lessThan(btcCard.top));
      expect(ergoCard.width, btcCard.width);
      expect(find.textContaining('BTC'), findsWidgets);
      expect(find.textContaining('ERG'), findsWidgets);
      expect(find.byKey(const Key('coin-bitcoin-pending')), findsOneWidget);
      expect(find.textContaining(appL10n.coinTestNetwork('signet').toUpperCase(), findRichText: true), findsOneWidget);

      await tester.tap(find.byKey(const Key('coin-bitcoin-send')));
      await tester.tap(find.byKey(const Key('coin-ergo-receive')));
      await tester.tap(find.byKey(const Key('coin-bitcoin-more')));
      await tester.tap(find.byKey(const Key('home-activity-b1')));
      await tester.pump();
      expect(btc.acted, [CoinAction.send, CoinAction.details]);
      expect(ergo.acted, [CoinAction.receive]);
      expect(btc.opened, ['b1']);
    });

    testWidgets('hidden balances hide both coins; a pull reads both', (tester) async {
      final ergo = _FakeCoin(Coin.ergo, const CoinFigures(total: 1000000000));
      final btc = _FakeCoin(Coin.bitcoin, const CoinFigures(note: 'Unlock'));
      await privacyService.setHideBalances(true);
      addTearDown(() => privacyService.setHideBalances(false));
      await _pump(tester, WalletSummaryScreen(coins: [ergo, btc]));
      expect(find.textContaining('1.00'), findsNothing);
      expect(find.byKey(const Key('coin-bitcoin-note')), findsOneWidget);
      expect(find.byKey(const Key('coin-bitcoin-empty')), findsOneWidget);
      await tester.fling(find.byKey(const Key('wallet-summary')), const Offset(0, 800), 1000);
      await tester.pumpAndSettle();
      expect((ergo.refreshed, btc.refreshed), (1, 1));
    });

    testWidgets('a card is the same widget for any coin', (tester) async {
      await _pump(
        tester,
        Material(child: CoinWalletCard(wallet: _FakeCoin(Coin.bitcoin, CoinFigures.unknown), hidden: false)),
      );
      expect(find.byKey(const Key('coin-bitcoin-balance')), findsOneWidget);
      expect(find.byKey(const Key('coin-bitcoin-empty')), findsOneWidget);
    });
  });

  group('Bitcoin at the level of Ergo', () {
    testWidgets('receive: the QR code asks for an amount, and the address gets a label', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final w = FakeBitcoin();
      await _pump(tester, BitcoinReceiveScreen(wallet: w, address: fakeBtcAddress));
      expect(find.byKey(const Key('btc-receive-qr')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btc-copy-address')));
      await tester.enterText(find.byKey(const Key('btc-receive-amount')), '0.0015');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btc-copy-address')));
      // The address alone, then the request with its amount (BIP-21).
      expect(copied, [fakeBtcAddress, 'bitcoin:$fakeBtcAddress?amount=0.0015']);
      await tester.enterText(find.byKey(const Key('btc-receive-amount')), '0.1x');
      await tester.pump();
      expect(find.text(appL10n.btcSendAmountInvalid), findsOneWidget);
      expect(find.byKey(const Key('btc-share-address')), findsOneWidget);
      expect(find.byKey(const Key('btc-label-address')), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a transaction: amounts, fee, inputs and outputs, ID and explorer', (tester) async {
      final w = FakeBitcoin();
      await _pump(tester, BtcTxScreen(wallet: w, txid: fakeBtcTxid));
      expect(find.text('+0.0015 BTC'), findsOneWidget);
      expect(find.text(appL10n.btcConfirmations('3')), findsOneWidget);
      expect(find.text('282 sat'), findsOneWidget);
      expect(find.textContaining(appL10n.btcTxData), findsOneWidget);
      expect(find.textContaining(appL10n.btcTxYours), findsOneWidget);
      expect(find.byKey(const Key('btc-tx-explorer')), findsOneWidget);
      // Confirmed: no fee bump.
      expect(find.byKey(const Key('btc-tx-bump')), findsNothing);
    });

    testWidgets('a payment that waits gets a higher fee: rate, confirm, consent, send', (tester) async {
      final w = FakeBitcoin();
      final popped = await _pushFrom(tester, BtcTxScreen(wallet: w, txid: fakeBtcWaiting));
      await tester.tap(find.byKey(const Key('btc-tx-bump')));
      await tester.pumpAndSettle();
      // The rate must be 1 sat/vB above the rate of now (2).
      expect(find.text(appL10n.btcBumpNow('2', '3')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btc-fee-custom')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('btc-fee-rate')), '2.5');
      await tester.pump();
      expect(find.byKey(const Key('btc-bump-low')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('btc-fee-rate')), '6');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btc-bump-review')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'bump $fakeBtcWaiting 6.0');
      expect(find.text(appL10n.btcBumpConfirmTitle), findsOneWidget);
      await tester.tap(find.text(appL10n.btcSendLabel));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'consent');
      expect(w.sentIds, [BigInt.from(9)]);
      expect(popped, [fakeBtcBumped]);
    });

    testWidgets('addresses with what they hold, and the unspent outputs', (tester) async {
      final w = FakeBitcoin();
      await _pump(tester, BtcAddressesScreen(wallet: w));
      expect(find.byKey(const Key('btc-address-$fakeBtcAddress')), findsOneWidget);
      expect(find.text('0.0015 BTC'), findsOneWidget);
      expect(find.textContaining(appL10n.btcAddressUnused), findsOneWidget);
      await _pump(tester, BtcUtxosScreen(wallet: w));
      expect(find.byKey(const Key('btc-utxo-$fakeBtcTxid:0')), findsOneWidget);
    });

    testWidgets('send: a typed fee rate, and a rate out of range is refused', (tester) async {
      final w = FakeBitcoin();
      await _pump(tester, BitcoinSendScreen(wallet: w, initialTo: fakeBtcAddress, initialSat: 150000));
      expect(find.text('0.0015'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btc-fee-custom')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('btc-fee-rate')), '0.5');
      await tester.pump();
      expect(find.text(appL10n.btcFeeCustomInvalid), findsOneWidget);
      await tester.tap(find.byKey(const Key('btc-send-review')));
      await tester.pumpAndSettle();
      expect(w.calls.where((c) => c.startsWith('prepare')), isEmpty);
      await tester.enterText(find.byKey(const Key('btc-fee-rate')), '3.5');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btc-send-review')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'prepare 150000 false 3.5');
      expect(find.byKey(const Key('btc-send-scan')), findsOneWidget);
      expect(find.byKey(const Key('btc-send-contacts')), findsOneWidget);
    });

    testWidgets('More: Lock locks the wallet and closes the page once', (tester) async {
      final w = FakeBitcoin();
      await _pushFrom(tester, BitcoinWalletScreen(wallet: w));
      await tester.tap(find.byKey(const Key('btc-more')));
      await tester.pumpAndSettle();
      for (final tool in ['addresses', 'utxos', 'deposit', 'network', 'backup', 'lock']) {
        expect(find.byKey(Key('btc-tool-$tool')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('btc-tool-lock')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'lock');
      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('custom fee rates, explorer links, address forms', () {
      const rates = BtcFeeRates(fast: 12, normal: 5.5, slow: 1, estimated: true);
      expect(btcRateOfChoice(rates, BtcFeeChoice.slow, ''), 1);
      expect(btcRateOfChoice(rates, BtcFeeChoice.custom, '2,5'), 2.5);
      expect(btcRateOfChoice(rates, BtcFeeChoice.custom, '0.9'), isNull);
      expect(btcRateOfChoice(rates, BtcFeeChoice.custom, '1001'), isNull);
      expect(btcExplorerTx('signet', 'ab'), 'https://mempool.space/signet/tx/ab');
      expect(btcExplorerTx('mainnet', 'ab'), 'https://mempool.space/tx/ab');
      expect(btcExplorerTx('regtest', 'ab'), isNull);
      expect(formatFeeRate(5), '5');
      expect(formatFeeRate(5.5), '5.5');
      expect(looksLikeBitcoinAddress(fakeBtcAddress), isTrue);
      expect(looksLikeBitcoinAddress('bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu'), isTrue);
      expect(looksLikeBitcoinAddress('bcrt1qcr8te4kr609gcawutmrza0j4xv80jy8zqwer2s'), isTrue);
      expect(looksLikeBitcoinAddress('1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2'), isTrue);
      expect(looksLikeBitcoinAddress('9fRAWhdxEsTcdb8PhGNrZfwqa65zfkuYHAMmkQLcic1gdLSV5vA'), isFalse);
      expect(looksLikeBitcoinAddress('tb1QCR8te4kr609gcawutmrza0j4xv80jy8zeqchgx'), isFalse);
    });
  });
}
