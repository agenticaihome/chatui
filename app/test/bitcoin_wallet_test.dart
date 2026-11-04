import 'package:argus_wallet/bitcoin/bitcoin_settings.dart';
import 'package:argus_wallet/bitcoin/btc_format.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/theme/theme_controller.dart';
import 'package:argus_wallet/ui/bitcoin/bitcoin_send_screen.dart';
import 'package:argus_wallet/ui/bitcoin/bitcoin_settings_screen.dart';
import 'package:argus_wallet/ui/bitcoin/bitcoin_wallet_screen.dart';
import 'package:argus_wallet/ui/bitcoin/btc_deposit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_bitcoin.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: argusTheme(watchful: false), home: home));
  await tester.pumpAndSettle();
}

void main() {
  group('amounts', () {
    test('BTC and sat', () {
      expect(formatBtc(150000), '0.0015');
      expect(formatBtc(100000000), '1.00');
      expect(formatBtc(546), '0.00000546');
      expect(formatBtc(-10282), '-0.00010282');
      expect(formatSat(1234567), '1 234 567 sat');
      expect(parseBtc('0.001'), 100000);
      expect(parseBtc('0,5'), 50000000);
      expect(parseBtc('.00000001'), 1);
      expect(parseBtc('1.123456789'), isNull);
      expect(parseBtc('abc'), isNull);
      expect(parseBtc(''), isNull);
      expect(parseBtc('21000001'), isNull);
    });
  });

  group('settings', () {
    test('signet by default, kept per network', () async {
      SharedPreferences.setMockInitialValues({});
      final s = BitcoinSettings();
      await s.load();
      expect(s.network, BtcNetworkName.signet);
      expect(s.server, '');
      await s.setNetwork(BtcNetworkName.regtest);
      await s.setServer(BtcNetworkName.regtest, ' http://10.0.2.2:18094/regtest/api ');
      final again = BitcoinSettings();
      await again.load();
      expect(again.network, BtcNetworkName.regtest);
      expect(again.server, 'http://10.0.2.2:18094/regtest/api');
      await again.setServer(BtcNetworkName.regtest, '');
      expect(again.server, '');
      expect(BtcNetworkName.mainnet.real, isTrue);
      expect(BtcNetworkName.signet.real, isFalse);
    });

    testWidgets('mainnet asks first; regtest needs a server', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final s = BitcoinSettings()..loaded = true;
      bool? changed;
      await _pump(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => changed = await Navigator.of(ctx).push<bool>(
              MaterialPageRoute(
                builder: (_) => BitcoinSettingsScreen(
                  settings: s,
                  defaultServer: (n) => n == BtcNetworkName.regtest ? '' : 'https://example/${n.name}/api',
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l = appL10n;

      await tester.tap(find.byKey(const Key('btc-net-mainnet')));
      await tester.pumpAndSettle();
      expect(find.text(l.btcMainnetWarnTitle), findsOneWidget);
      await tester.tap(find.text(l.commonCancel));
      await tester.pumpAndSettle();
      expect(s.network, BtcNetworkName.signet);

      await tester.tap(find.byKey(const Key('btc-net-regtest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btc-settings-save')));
      await tester.pumpAndSettle();
      expect(find.text(l.btcServerNoDefault), findsWidgets);
      expect(changed, isNull);

      await tester.enterText(find.byKey(const Key('btc-server')), 'http://10.0.2.2:18094/regtest/api');
      await tester.tap(find.byKey(const Key('btc-settings-save')));
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(s.network, BtcNetworkName.regtest);
      expect(s.server, 'http://10.0.2.2:18094/regtest/api');
    });
  });

  group('wallet screen', () {
    testWidgets('balance, pending, history and receive', (tester) async {
      final w = FakeBitcoin();
      await _pump(tester, BitcoinWalletScreen(wallet: w));
      expect(w.calls, ['unlock', 'open', 'sync']);
      expect(find.text('0.0015 BTC'), findsOneWidget);
      expect(find.text(appL10n.btcPending('0.00005')), findsOneWidget);
      expect(find.text(appL10n.btcTestNetwork('signet')), findsOneWidget);
      expect(find.byKey(const Key('btc-tx-$fakeBtcTxid')), findsOneWidget);
      expect(find.text('+0.0015 BTC'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btc-receive')));
      await tester.pumpAndSettle();
      expect(find.text(fakeBtcAddress), findsOneWidget);
      expect(find.text(appL10n.btcReceiveNote('signet')), findsOneWidget);
    });

    testWidgets('locked: nothing opens', (tester) async {
      final w = FakeBitcoin(unlocks: false);
      await _pump(tester, BitcoinWalletScreen(wallet: w));
      expect(w.calls, ['unlock']);
      expect(find.byKey(const Key('btc-locked')), findsOneWidget);
      expect(find.byKey(const Key('btc-balance')), findsNothing);
    });

    testWidgets('the Bitcoin look while the screen is open', (tester) async {
      bitcoinThemeActive.value = false;
      await _pump(tester, BitcoinWalletScreen(wallet: FakeBitcoin()));
      expect(bitcoinThemeActive.value, isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(bitcoinThemeActive.value, isFalse);
    });

    test('the Bitcoin palette is orange and not the Ergo one', () {
      expect(bitcoinPalette.accent, const Color(0xFFF7931A));
      expect(bitcoinPalette.background, isNot(ergoPalette.background));
      expect(allPalettes, isNot(contains(bitcoinPalette)));
    });
  });

  group('send', () {
    testWidgets('checks the address and the amount, then confirms and sends', (tester) async {
      final w = FakeBitcoin();
      String? txid;
      await _pump(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => txid = await Navigator.of(ctx).push<String>(
              MaterialPageRoute(builder: (_) => BitcoinSendScreen(wallet: w)),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l = appL10n;

      await tester.enterText(find.byKey(const Key('btc-send-to')), 'bc1qnotsignet');
      await tester.enterText(find.byKey(const Key('btc-send-amount')), '0.0001x');
      await tester.tap(find.byKey(const Key('btc-send-review')));
      await tester.pumpAndSettle();
      expect(find.text(l.btcSendToInvalid('signet')), findsOneWidget);
      expect(find.text(l.btcSendAmountInvalid), findsOneWidget);
      expect(w.calls.where((c) => c.startsWith('prepare')), isEmpty);

      await tester.enterText(find.byKey(const Key('btc-send-to')), fakeBtcAddress);
      await tester.enterText(find.byKey(const Key('btc-send-amount')), '0.0001');
      await tester.tap(find.byKey(const Key('btc-fee-fast')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('btc-send-review')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'prepare 10000 false 12.0');
      expect(find.text(l.btcConfirmTitle), findsOneWidget);
      expect(find.text('0.0001 BTC'), findsOneWidget);
      expect(find.text('0.00010282 BTC'), findsOneWidget);

      await tester.tap(find.text(l.btcSendLabel));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'consent');
      expect(w.sentIds, [BigInt.from(7)]);
      expect(txid, fakeBtcTxid);
    });

    testWidgets('no consent: cancelled, nothing sent', (tester) async {
      final w = FakeBitcoin()..consents = false;
      await _pump(tester, BitcoinSendScreen(wallet: w));
      await tester.enterText(find.byKey(const Key('btc-send-to')), fakeBtcAddress);
      await tester.tap(find.byKey(const Key('btc-send-all')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('btc-send-review')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'prepare 0 true 5.5');
      await tester.tap(find.text(appL10n.btcSendLabel));
      await tester.pumpAndSettle();
      expect(w.sentIds, isEmpty);
      expect(w.cancelled, [BigInt.from(7)]);
      expect(find.text(appL10n.btcConsentNeeded), findsOneWidget);
    });
  });

  group('deposit in BTC', () {
    testWidgets('a node without BTC on the network: no offer', (tester) async {
      final w = FakeBitcoin(accepts: false);
      await _pump(tester, BtcDepositScreen(wallet: w, node: const NodeAddress(host: '127.0.0.1', port: 18460)));
      expect(w.calls.first, 'node 127.0.0.1:18460');
      expect(find.byKey(const Key('btc-dep-no-btc')), findsOneWidget);
      expect(find.text(appL10n.btcDepNodeNetworks('mainnet')), findsOneWidget);
      expect(find.byKey(const Key('btc-dep-prepare')), findsNothing);
    });

    testWidgets('prepare, confirm, send, wait for the confirmations, then Payable once', (tester) async {
      final w = FakeBitcoin();
      await _pump(
        tester,
        BtcDepositScreen(
          wallet: w,
          node: const NodeAddress(host: '127.0.0.1', port: 18460),
          poll: const Duration(seconds: 1),
        ),
      );
      expect(find.byKey(const Key('btc-dep-offer')), findsOneWidget);
      expect(find.text(appL10n.btcDepRate('7')), findsOneWidget);
      expect(find.text(appL10n.btcDepWaitsDefault('2')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('btc-dep-amount')), '500');
      await tester.tap(find.byKey(const Key('btc-dep-prepare')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.btcDepAmountInvalid('$minBtcDepositSat')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('btc-dep-amount')), '10000');
      await tester.tap(find.byKey(const Key('btc-dep-prepare')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'prepareDeposit 10000 5.5');
      expect(find.text(appL10n.btcDepConfirmTitle), findsOneWidget);
      expect(find.text('70,000 MU'), findsOneWidget);
      await tester.tap(find.text(appL10n.btcSendLabel));
      await tester.pump();
      await tester.pump();
      expect(w.calls, contains('sendDeposit d1'));
      expect(find.text(appL10n.btcDepWaiting('0', '2')), findsOneWidget);
      expect(w.calls.where((c) => c.startsWith('notify')), isEmpty);

      w.statusConfirmations = 1;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text(appL10n.btcDepWaiting('1', '2')), findsOneWidget);
      expect(w.calls.where((c) => c.startsWith('notify')), isEmpty);

      w.statusConfirmations = 2;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      expect(w.calls.where((c) => c.startsWith('notify')), ['notify d1']);
      expect(find.text(appL10n.btcDepAccepted('4,570,000')), findsOneWidget);

      // No more polling after the end.
      final before = w.calls.length;
      await tester.pump(const Duration(seconds: 3));
      expect(w.calls.length, before);
    });
  });
}
