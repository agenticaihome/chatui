import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/auto_top_up.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/auto_top_up_screen.dart';
import 'package:argus_wallet/ui/celaut/chats_screen.dart';
import 'package:argus_wallet/ui/celaut/instance_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keep running (Josemi, 2026-10-29): per instance, in time. The app moves credit that it
// already has on a node to an instance (ModifyDeposit), and never pays a node by itself.

InstanceListView _instance(String id, {int? stoppedAt}) => InstanceListView(
      instanceId: id,
      peerId: 'aa' * 32,
      address: 'node.example:53460',
      serviceId: '65' * 32,
      slots: Uint16List.fromList([8080]),
      chatSlots: Uint16List.fromList([8080]),
      cardsSlots: Uint16List(0),
      webSlots: Uint16List(0),
      startedAt: 1,
      startChargeMu: '1000',
      name: 'Echo chat',
      alias: '',
      title: '',
      stoppedAt: stoppedAt,
      refundMu: '',
    );

InstanceStatusView _balance(String mu) =>
    InstanceStatusView(instanceBalanceMu: mu, costSoFarMu: '1', streamsOpened: BigInt.zero);

InstancePlanView _plan({
  bool keep = true,
  String budget = '',
  String spent = '',
  String price = '1000',
  int seconds = 60,
  bool hibernated = false,
  bool diskOnly = false,
  String wakeFee = '',
}) => InstancePlanView(
  keepAlive: keep,
  budgetMu: budget,
  spentMu: spent,
  maintenanceMu: price,
  maintenanceSeconds: price.isEmpty ? 0 : seconds,
  volatility: 0,
  volatilityPeriodSeconds: 0,
  startedAt: 0,
  hibernated: hibernated,
  diskOnly: diskOnly,
  wakeFeeMu: wakeFee,
);

void main() {
  late List<String> topUps;
  late List<String> asked;
  late List<InstanceListView> db;
  late Map<String, String> balances;
  late Map<String, InstancePlanView> plans;
  late List<String> keepCalls;
  late Object? topUpError;
  late DateTime clock;

  AutoTopUp engine() => AutoTopUp(
        topUp: (id, mu) async {
          topUps.add('$id $mu');
          final e = topUpError;
          if (e != null) throw e;
          return const TopUpView(instanceBalanceMu: '1200000', clientBalanceMu: '3000000');
        },
        instances: () => db,
        status: (id) async {
          asked.add(id);
          return _balance(balances[id]!);
        },
        plan: (id) => plans[id] ?? (throw StateError('unknown')),
        setKeepAlive: (id, enabled, budget) => keepCalls.add('$id $enabled $budget'),
        now: () => clock,
        periodic: false,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    topUps = [];
    asked = [];
    db = [];
    balances = {};
    plans = {};
    keepCalls = [];
    topUpError = null;
    clock = DateTime(2026, 10, 29, 12);
  });

  group('the engine', () {
    test('only an instance that the user keeps is asked and topped up', () async {
      final e = engine();
      await e.load();
      expect((e.threshold, e.chunk), (AutoTopUp.defaultThreshold, AutoTopUp.defaultChunk));
      db = [_instance('off'), _instance('unknown')];
      balances.addAll({'off': '1', 'unknown': '1'});
      plans['off'] = _plan(keep: false);
      await e.check();
      expect(asked, isEmpty);
      expect(topUps, isEmpty);
    });

    test('a kept instance gets a chunk of time when it would last less than the threshold', () async {
      final e = engine();
      // 1000 MU each 60 s: 15 minutes need 16 periods of balance.
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 30));
      db = [_instance('low'), _instance('ok'), _instance('old', stoppedAt: 5)];
      balances.addAll({'low': '15999', 'ok': '16000', 'old': '0'});
      plans.addAll({'low': _plan(), 'ok': _plan(), 'old': _plan()});
      await e.check();
      expect(topUps, ['low 30000']);
      // Still low a moment later: it waits a minute.
      await e.check();
      expect(topUps, hasLength(1));
      clock = clock.add(const Duration(minutes: 1, seconds: 1));
      await e.check();
      expect(topUps, hasLength(2));
    });

    test('an instance whose status cannot be read is asked again after ten minutes, not each minute', () async {
      final e = engine();
      db = [_instance('gone')];
      // No balance for it: the fake status throws, as a node that does not answer.
      plans['gone'] = _plan();
      await e.check();
      expect(asked, ['gone']);
      clock = clock.add(const Duration(minutes: 1, seconds: 1));
      await e.check();
      expect(asked, hasLength(1));
      clock = clock.add(const Duration(minutes: 9));
      await e.check();
      expect(asked, hasLength(2));
      expect(topUps, isEmpty);
    });

    test('the margin of the node is in the amount', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 10));
      db = [_instance('i')];
      balances['i'] = '1';
      plans['i'] = const InstancePlanView(
        keepAlive: true,
        budgetMu: '',
        spentMu: '',
        maintenanceMu: '1000',
        maintenanceSeconds: 60,
        volatility: 0.5,
        volatilityPeriodSeconds: 0,
        startedAt: 0,
        hibernated: false,
        diskOnly: false,
        wakeFeeMu: '',
      );
      await e.check();
      // 10 periods of 1500 MU.
      expect(topUps, ['i 15000']);
    });

    test('an instance without a price uses the fixed amounts', () async {
      final e = engine();
      db = [_instance('i'), _instance('j')];
      balances.addAll({'i': '199999', 'j': '200000'});
      plans.addAll({'i': _plan(price: ''), 'j': _plan(price: '')});
      await e.check();
      expect(topUps, ['i 1000000']);
    });

    test('the limit cuts the top-up, and at the limit it moves nothing and says so', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(hours: 1));
      db = [_instance('i')];
      balances['i'] = '1';
      plans['i'] = _plan(budget: '100000', spent: '70000');
      await e.check();
      // 60000 would pass the limit: only the 30000 that are left.
      expect(topUps, ['i 30000']);
      plans['i'] = _plan(budget: '100000', spent: '100000');
      clock = clock.add(const Duration(minutes: 2));
      await e.check();
      expect(topUps, hasLength(1));
      expect(e.need?.budget, isTrue);
      expect(e.need?.instanceId, 'i');
      // Turning it off and on again clears the notice.
      e.setKeepAlive('i', enabled: true, budgetMu: '500000');
      expect(e.need, isNull);
      expect(keepCalls, ['i true 500000']);
    });

    test('with too little credit on the node it pays nothing and asks the user', () async {
      final e = engine();
      topUpError = const CelautError(
        kind: CelautErrorKind.insufficientCredit,
        message: 'credit 100 MU, top-up 500000 MU',
      );
      db = [_instance('low')];
      balances['low'] = '5';
      plans['low'] = _plan();
      await e.check();
      expect(e.need?.instanceId, 'low');
      expect(e.need?.budget, isFalse);
      expect(e.need?.address, 'node.example:53460');
      // It waits ten minutes before it tries again.
      clock = clock.add(const Duration(minutes: 5));
      await e.check();
      expect(topUps, hasLength(1));
      e.dismissNeed();
      expect(e.need, isNull);
    });

    test('adding time moves the cost of that time, in as many calls as the core needs', () async {
      final e = engine();
      plans['i'] = _plan(price: '1000000');
      // 3000 minutes of 60-second periods at 1,000,000 MU: 3,000,000,000 MU, 30 calls.
      await e.addTime('i', const Duration(minutes: 3000));
      expect(topUps, hasLength(30));
      expect(topUps.toSet(), {'i 100000000'});
      topUps.clear();
      await e.addTime('i', const Duration(minutes: 30));
      expect(topUps, ['i 30000000']);
      // No price, nothing to add.
      plans['j'] = _plan(price: '');
      expect(await e.addTime('j', const Duration(minutes: 5)), isNull);
      expect(topUps, hasLength(1));
    });

    test('adding time with too little credit throws what the core says', () async {
      final e = engine();
      plans['i'] = _plan();
      topUpError = const CelautError(kind: CelautErrorKind.insufficientCredit, message: 'credit 1 MU');
      await expectLater(
        e.addTime('i', const Duration(hours: 1)),
        throwsA(isA<CelautError>().having((x) => x.kind, 'kind', CelautErrorKind.insufficientCredit)),
      );
    });

    test('the settings are kept, and bad kept values give the defaults', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 20), chunk: const Duration(hours: 3));
      final again = engine();
      await again.load();
      expect((again.threshold, again.chunk), (const Duration(minutes: 20), const Duration(hours: 3)));
      SharedPreferences.setMockInitialValues({AutoTopUp.keyThreshold: 0, AutoTopUp.keyChunk: 99999999});
      final bad = engine();
      await bad.load();
      expect((bad.threshold, bad.chunk), (AutoTopUp.defaultThreshold, AutoTopUp.defaultChunk));
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester, AutoTopUp e) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: argusTheme(watchful: false), home: AutoTopUpScreen(topUp: e)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the threshold and the time of a top-up, in minutes', (tester) async {
      final e = engine();
      await pump(tester, e);
      expect(find.text(appL10n.celautTopUpNote), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('top-up-threshold'))).controller!.text, '15');
      await tester.enterText(find.byKey(const Key('top-up-threshold')), '30');
      await tester.enterText(find.byKey(const Key('top-up-amount')), '120');
      await tester.tap(find.byKey(const Key('top-up-save')));
      await tester.pumpAndSettle();
      expect((e.threshold, e.chunk), (const Duration(minutes: 30), const Duration(hours: 2)));
      // A value out of its limits is refused and kept out.
      await tester.enterText(find.byKey(const Key('top-up-amount')), '99999');
      await tester.pump();
      expect(find.text(appL10n.celautTopUpRange('1', '43200')), findsOneWidget);
      await tester.tap(find.byKey(const Key('top-up-save')));
      await tester.pumpAndSettle();
      expect(e.chunk, const Duration(hours: 2));
    });
  });

  group('the list', () {
    Future<void> pump(WidgetTester tester, AutoTopUp e, {required VoidCallback openDeposit}) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.argus.wallet/secure_storage'),
        (call) async => null,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: ChatsScreen(
            topUp: e,
            openDeposit: openDeposit,
            list: (key, empty) => InstanceList(
              key: key,
              chats: true,
              load: () => db,
              loadStatus: (id) async => _balance(balances[id]!),
              topUp: e,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a top-up that needs a deposit shows, and Deposit opens the deposit', (tester) async {
      final e = engine();
      topUpError = const CelautError(kind: CelautErrorKind.insufficientCredit, message: 'credit 1 MU');
      db = [_instance('low')];
      balances['low'] = '5';
      plans['low'] = _plan();
      var deposits = 0;
      await pump(tester, e, openDeposit: () => deposits++);
      // The list read the balance: it runs low, and the credit is too low.
      expect(topUps, hasLength(1));
      expect(find.byKey(const Key('chats-keep-low')), findsOneWidget);
      expect(find.byKey(const Key('top-up-need')), findsOneWidget);
      expect(find.text(appL10n.celautKeepNeed('node.example:53460')), findsOneWidget);
      await tester.tap(find.byKey(const Key('top-up-need-deposit')));
      await tester.pumpAndSettle();
      expect(deposits, 1);
      expect(find.byKey(const Key('top-up-need')), findsNothing);
    });

    testWidgets('an instance at its limit shows a notice without a deposit', (tester) async {
      final e = engine();
      db = [_instance('i'), _instance('plain')];
      balances.addAll({'i': '5', 'plain': '5'});
      plans['i'] = _plan(budget: '10', spent: '10');
      plans['plain'] = _plan(keep: false);
      await pump(tester, e, openDeposit: () {});
      expect(topUps, isEmpty);
      expect(find.text(appL10n.celautKeepNeedBudget('node.example:53460')), findsOneWidget);
      expect(find.byKey(const Key('top-up-need-deposit')), findsNothing);
      // Only the kept instance has the mark.
      expect(find.byKey(const Key('chats-keep-i')), findsOneWidget);
      expect(find.byKey(const Key('chats-keep-plain')), findsNothing);
    });
  });
}
