import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/auto_top_up.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/instance_time_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Time and credit on the info page of an instance (Josemi, 2026-10-29): the balance, the
// credit on the node, the switch "keep it running until I stop it", and Add time.

class _Wallets implements FullWallets {
  _Wallets({required this.unlocks});

  final bool unlocks;
  int asked = 0;

  @override
  Future<List<PayerWallet>> payers() async =>
      [const PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: false)];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async {
    asked++;
    return unlocks;
  }
}

InstancePlanView _plan({
  bool keep = false,
  String budget = '',
  String spent = '',
  String price = '100',
  int closesAt = 0,
  OnCloseView onClose = OnCloseView.refuse,
}) => InstancePlanView(
  closesAt: closesAt,
  onClose: onClose,
  keepAlive: keep,
  budgetMu: budget,
  spentMu: spent,
  maintenanceMu: price,
  maintenanceSeconds: price.isEmpty ? 0 : 60,
  volatility: 0,
  volatilityPeriodSeconds: 0,
  startedAt: 0,
  hibernated: false,
  diskOnly: false,
  wakeFeeMu: '',
);

void main() {
  late InstancePlanView plan;
  late List<String> topUps;
  late List<String> keepCalls;
  late String credit;
  late Object? topUpError;
  var deposits = 0;

  AutoTopUp engine() => AutoTopUp(
        topUp: (id, mu) async {
          topUps.add('$id $mu');
          final e = topUpError;
          if (e != null) throw e;
          return const TopUpView(instanceBalanceMu: '0', clientBalanceMu: '0');
        },
        instances: () => const [],
        plan: (id) => plan,
        setKeepAlive: (id, enabled, budget) {
          keepCalls.add('$id $enabled $budget');
          plan = _plan(keep: enabled, budget: budget ?? '', spent: '0');
        },
        periodic: false,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    plan = _plan();
    topUps = [];
    keepCalls = [];
    credit = '50000';
    topUpError = null;
    deposits = 0;
  });

  Future<void> pump(WidgetTester tester, {_Wallets? wallets, AutoTopUp? e}) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: InstanceTimeSection(
              instanceId: 'i',
              topUp: e ?? engine(),
              wallets: wallets ?? _Wallets(unlocks: true),
              loadStatus: (id) async =>
                  InstanceStatusView(instanceBalanceMu: '3100', costSoFarMu: '1', streamsOpened: BigInt.zero),
              loadCredit: (id) async => credit,
              openDeposit: () => deposits++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the balance and the credit, each with its time', (tester) async {
    await pump(tester);
    // 3,100 MU at 100 MU a minute: 30 periods, and 50,000 MU: 499.
    expect(
      tester.widget<SelectableText>(find.byKey(const Key('info-time-balance'))).data,
      '3,100 MU (${appL10n.celautTimeAbout('30 min')})',
    );
    expect(
      tester.widget<SelectableText>(find.byKey(const Key('info-time-credit'))).data,
      '50,000 MU (${appL10n.celautTimeAbout('8 h 19 min')})',
    );
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('info-keep-switch'))).value, isFalse);
    expect(find.text(appL10n.celautKeepOff), findsOneWidget);
    expect(find.byKey(const Key('info-add-time')), findsOneWidget);
  });

  int inTwoHours() => DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;

  testWidgets('says what the node does at its next close (nodo#344)', (tester) async {
    plan = _plan(closesAt: inTwoHours(), onClose: OnCloseView.hibernate);
    await pump(tester);
    expect(find.byKey(const Key('info-closing')), findsOneWidget);
    expect(find.byKey(const Key('info-keep-stop')), findsNothing);
  });

  testWidgets('warns that keep-alive ends at a close that stops the instance', (tester) async {
    plan = _plan(keep: true, closesAt: inTwoHours(), onClose: OnCloseView.stop);
    await pump(tester);
    expect(find.byKey(const Key('info-keep-stop')), findsOneWidget);
    expect(find.byKey(const Key('info-closing')), findsNothing);
  });

  testWidgets('says nothing of a node that leaves running instances alone', (tester) async {
    plan = _plan(keep: true, closesAt: inTwoHours());
    await pump(tester);
    expect(find.byKey(const Key('info-keep-stop')), findsNothing);
    expect(find.byKey(const Key('info-closing')), findsNothing);
  });

  testWidgets('shows nothing for an instance that the app does not know', (tester) async {
    final unknown = AutoTopUp(plan: (id) => throw StateError('unknown'), periodic: false);
    await pump(tester, e: unknown);
    expect(find.byKey(const Key('info-time')), findsNothing);
  });

  group('the switch', () {
    testWidgets('warns first; with the wallet open and no limit, it turns on', (tester) async {
      final wallets = _Wallets(unlocks: true);
      await pump(tester, wallets: wallets);
      await tester.tap(find.byKey(const Key('info-keep-switch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('keep-dialog-warning')), findsOneWidget);
      expect(find.text(appL10n.celautKeepWarning), findsOneWidget);
      expect(keepCalls, isEmpty, reason: 'nothing changes before the user confirms');
      await tester.tap(find.byKey(const Key('keep-dialog-ok')));
      await tester.pumpAndSettle();
      expect(wallets.asked, 1);
      expect(keepCalls, ['i true null']);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('info-keep-switch'))).value, isTrue);
      expect(find.text(appL10n.celautKeepOnNoLimit('0 MU')), findsOneWidget);
      // Add time is for an instance that is not kept.
      expect(find.byKey(const Key('info-add-time')), findsNothing);
    });

    testWidgets('a limit goes with it, and a zero limit is refused', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('info-keep-switch')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('keep-dialog-limit')), '0');
      await tester.pump();
      expect(find.text(appL10n.celautKeepLimitWrong), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('keep-dialog-ok'))).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('keep-dialog-limit')), '90000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('keep-dialog-ok')));
      await tester.pumpAndSettle();
      expect(keepCalls, ['i true 90000']);
      expect(find.text(appL10n.celautKeepOnLimit('0 MU', '90,000 MU')), findsOneWidget);
    });

    testWidgets('cancelling the warning, or a locked wallet, leaves it off', (tester) async {
      final wallets = _Wallets(unlocks: false);
      await pump(tester, wallets: wallets);
      await tester.tap(find.byKey(const Key('info-keep-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keep-dialog-cancel')));
      await tester.pumpAndSettle();
      expect(wallets.asked, 0);
      await tester.tap(find.byKey(const Key('info-keep-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keep-dialog-ok')));
      await tester.pumpAndSettle();
      expect(wallets.asked, 1);
      expect(keepCalls, isEmpty);
      expect(find.text(appL10n.celautOpenFullWalletNeeded), findsOneWidget);
    });

    testWidgets('turning it off asks nothing and moves no credit', (tester) async {
      plan = _plan(keep: true, spent: '500');
      final wallets = _Wallets(unlocks: false);
      await pump(tester, wallets: wallets);
      await tester.tap(find.byKey(const Key('info-keep-switch')));
      await tester.pumpAndSettle();
      expect(keepCalls, ['i false null']);
      expect(wallets.asked, 0);
      expect(topUps, isEmpty);
      expect(find.byKey(const Key('info-add-time')), findsOneWidget);
    });
  });

  group('add time', () {
    Future<void> open(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('info-add-time')));
      await tester.pumpAndSettle();
    }

    testWidgets('a chip sets the time, the note says the cost and what is left, and Add moves it', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('add-time-chip-60')));
      await tester.pump();
      // 60 periods of 100 MU: 6,000 MU of the 50,000: 44,000 left, 439 minutes more.
      expect(
        tester.widget<Text>(find.byKey(const Key('add-time-note'))).data,
        appL10n.celautAddTimeCost('6,000 MU', '44,000 MU', '7 h 19 min'),
      );
      await tester.tap(find.byKey(const Key('add-time-ok')));
      await tester.pumpAndSettle();
      expect(topUps, ['i 6000']);
      expect(find.byKey(const Key('add-time-sheet')), findsNothing);
      expect(find.text(appL10n.celautAddTimeDone), findsOneWidget);
    });

    testWidgets('a time that the credit does not cover offers a deposit and does not add', (tester) async {
      credit = '1000';
      await open(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('add-time-note'))).data,
        appL10n.celautAddTimeNoCredit('6,000 MU', '1,000 MU'),
      );
      expect(tester.widget<FilledButton>(find.byKey(const Key('add-time-ok'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('add-time-deposit')));
      await tester.pumpAndSettle();
      expect(deposits, 1);
      expect(topUps, isEmpty);
    });

    testWidgets('the node can still refuse for credit when the credit was not known', (tester) async {
      topUpError = const CelautError(kind: CelautErrorKind.insufficientCredit, message: 'credit 1 MU');
      await open(tester);
      await tester.tap(find.byKey(const Key('add-time-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-time-sheet')), findsOneWidget);
      expect(find.byKey(const Key('add-time-deposit')), findsOneWidget);
    });

    testWidgets('a wrong time is refused', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('add-time-minutes')), '50000');
      await tester.pump();
      expect(find.text(appL10n.celautRunSurvivalWrong), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('add-time-ok'))).onPressed, isNull);
    });
  });
}
