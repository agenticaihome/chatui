import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/auto_top_up.dart';
import 'package:argus_wallet/celaut/chat_done_watcher.dart';
import 'package:argus_wallet/celaut/chat_notifier.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:argus_wallet/celaut/conversations.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/celaut/stopped_filter.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/instance_actions.dart';
import 'package:argus_wallet/ui/celaut/instance_info_screen.dart';
import 'package:argus_wallet/ui/celaut/instance_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Hibernation and the rest of the app (phase 5): the keep-alive of a hibernated instance,
// the reachability and the notices, an instance that the node stopped, and a node that
// does not support hibernation.

InstanceListView _instance(String id, {int? stoppedAt, int? hibernatedAt}) => InstanceListView(
  instanceId: id,
  peerId: 'aa' * 32,
  address: 'node.example:53460',
  serviceId: '65' * 32,
  slots: Uint16List.fromList([8080]),
  chatSlots: Uint16List.fromList([8080]),
  webSlots: Uint16List(0),
  startedAt: 100,
  startChargeMu: '1000',
  name: 'Echo chat',
  alias: '',
  title: '',
  stoppedAt: stoppedAt,
  refundMu: '',
  hibernatedAt: hibernatedAt,
);

InstancePlanView _plan({
  String price = '1000',
  bool hibernated = false,
  bool diskOnly = false,
  String wakeFee = '',
  String budget = '',
  String spent = '',
}) => InstancePlanView(
  keepAlive: true,
  budgetMu: budget,
  spentMu: spent,
  maintenanceMu: price,
  maintenanceSeconds: 60,
  variance: 0,
  hibernated: hibernated,
  diskOnly: diskOnly,
  wakeFeeMu: wakeFee,
);

InstanceStatusView _balance(String mu) =>
    InstanceStatusView(instanceBalanceMu: mu, costSoFarMu: '1', streamsOpened: BigInt.zero);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hibernationSupport.reset();
  });

  group('1. keep-alive of a hibernated instance', () {
    late List<String> topUps;
    late List<InstanceListView> db;
    late Map<String, InstancePlanView> plans;
    late Map<String, String> balances;
    late DateTime clock;

    AutoTopUp engine() => AutoTopUp(
      topUp: (id, mu) async {
        topUps.add('$id $mu');
        return const TopUpView(instanceBalanceMu: '0', clientBalanceMu: '0');
      },
      instances: () => db,
      status: (id) async => _balance(balances[id]!),
      plan: (id) => plans[id]!,
      setKeepAlive: (id, enabled, budget) {},
      now: () => clock,
      periodic: false,
    );

    setUp(() {
      topUps = [];
      db = [_instance('h', hibernatedAt: 5)];
      plans = {};
      balances = {};
      clock = DateTime(2026, 11, 5, 12);
    });

    test('aims at the disk price, with the fee of the wake call kept apart', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 30));
      // The disk costs 10 MU a minute. 15 minutes need 16 periods = 160 MU, and the wake
      // call costs 10000 MU more.
      plans['h'] = _plan(price: '10', hibernated: true, diskOnly: true, wakeFee: '10000');
      balances['h'] = '10159';
      await e.check();
      expect(topUps, ['h 300']);
    });

    test('an instance that holds the disk and the fee is left alone', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 30));
      plans['h'] = _plan(price: '10', hibernated: true, diskOnly: true, wakeFee: '10000');
      balances['h'] = '10160';
      await e.check();
      expect(topUps, isEmpty);
    });

    test('a balance below the fee gets the missing fee in the top-up', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 30));
      plans['h'] = _plan(price: '10', hibernated: true, diskOnly: true, wakeFee: '10000');
      balances['h'] = '4000';
      await e.check();
      expect(topUps, ['h ${300 + 6000}']);
    });

    test('the same balance is enough for the disk but not for the awake price', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 30));
      db = [_instance('h', hibernatedAt: 5), _instance('r')];
      plans['h'] = _plan(price: '10', hibernated: true, diskOnly: true);
      plans['r'] = _plan(price: '1000');
      balances.addAll({'h': '200', 'r': '200'});
      await e.check();
      expect(topUps, ['r 30000']);
    });

    test('with no disk price it uses the awake price, which only over-funds', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 30));
      plans['h'] = _plan(hibernated: true);
      balances['h'] = '100';
      await e.check();
      expect(topUps, ['h 30000']);
    });

    test('the budget of the user still limits a hibernated instance', () async {
      final e = engine();
      await e.save(threshold: const Duration(minutes: 15), chunk: const Duration(minutes: 30));
      plans['h'] = _plan(price: '10', hibernated: true, diskOnly: true, budget: '100', spent: '40');
      balances['h'] = '0';
      await e.check();
      expect(topUps, ['h 60']);
    });

    test('a top-up is not a wake: the engine has no call to wake an instance', () async {
      final e = engine();
      plans['h'] = _plan(price: '10', hibernated: true, diskOnly: true);
      balances['h'] = '0';
      await e.check();
      expect(topUps, hasLength(1));
      // The record does not change: the plan still says hibernated.
      expect(plans['h']!.hibernated, isTrue);
    });
  });

  group('2. reachability and notices', () {
    late List<String> shown;
    late List<void Function()> timers;
    late Set<String> parked;
    late int connects;
    late ChatDoneWatcher watcher;

    setUp(() {
      shown = [];
      timers = [];
      parked = {};
      connects = 0;
      watcher = ChatDoneWatcher(
        notifier: ChatNotifier(isMuted: (_) => false, show: (id, t, b, p) async => shown.add(p)),
        holds: ForegroundHolds(isAndroid: false),
        isMuted: (_) => false,
        isParked: parked.contains,
        connect: (i) async {
          connects++;
          throw Exception('the tunnel is down');
        },
        timer: (d, f) {
          timers.add(f);
          return Timer(const Duration(days: 1), () {})..cancel();
        },
      );
    });

    test('an instance that the record says is hibernated is not watched', () async {
      parked.add('h');
      watcher.handOver(_instance('h'), const {0: 'done'});
      await pumpEventQueue();
      expect(watcher.watching, isEmpty);
      expect(connects, 0);
      expect(shown, isEmpty);
    });

    test('a watch that runs when the instance is hibernated stops without a notice', () async {
      watcher.handOver(_instance('h'), const {});
      await pumpEventQueue();
      expect(watcher.watching, {'h'});
      expect(connects, 1);
      expect(timers, hasLength(1));
      // The user hibernates the instance. The next read finds it parked, and the watch
      // ends with no new connection and no notice.
      parked.add('h');
      timers.single();
      await pumpEventQueue();
      expect(watcher.watching, isEmpty);
      expect(connects, 1);
      expect(shown, isEmpty);
    });

    testWidgets('a hibernated row is not unreachable even if the node fails', (tester) async {
      var statusCalls = 0;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final filter = StoppedFilter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: ConversationNotes(),
              load: () => [_instance('h', hibernatedAt: 5)],
              loadStatus: (id) async {
                statusCalls++;
                throw const CelautError(kind: CelautErrorKind.unreachable, message: 'down');
              },
              filter: filter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(statusCalls, 1);
      final text = tester.widget<Text>(find.byKey(const Key('chats-state-h'))).data!;
      expect(text, startsWith(appL10n.chatsStateHibernated));
      expect(text, isNot(contains(appL10n.chatsStateUnreachable)));
    });
  });

  group('3. the node stopped a hibernated instance', () {
    testWidgets('the list reads again and shows the stopped record', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var db = [_instance('h', hibernatedAt: 5)];
      final filter = StoppedFilter();
      await filter.set(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: ConversationNotes(),
              load: () => List.of(db),
              loadStatus: (id) async {
                // The core marks the record stopped when the node says "unknown token",
                // and the call fails.
                db = [_instance('h', hibernatedAt: 5, stoppedAt: 900)];
                throw const CelautError(kind: CelautErrorKind.protocol, message: 'Invalid token');
              },
              filter: filter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.byKey(const Key('chats-state-h'))).data!;
      expect(text, startsWith(appL10n.chatsStateStopped));
    });

    testWidgets('a failure that does not stop the record leaves the row hibernated', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: ConversationNotes(),
              load: () {
                loads++;
                return [_instance('h', hibernatedAt: 5)];
              },
              loadStatus: (id) async =>
                  throw const CelautError(kind: CelautErrorKind.timeout, message: 'slow'),
              filter: StoppedFilter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // One read for the list, one to check the record after the failure. No loop.
      expect(loads, 2);
      final text = tester.widget<Text>(find.byKey(const Key('chats-state-h'))).data!;
      expect(text, startsWith(appL10n.chatsStateHibernated));
    });
  });

  group('4. a node that does not support hibernation', () {
    final unsupported = HibernationView(
      state: InstanceStateView.running,
      instanceBalanceMu: '',
      refusal: ResourceRefusalView.unsupported,
      message: 'No local instance is registered at 10.0.0.2',
    );

    Future<void> openList(WidgetTester tester, List<InstanceListView> db, int Function() calls) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstanceList(
              chats: true,
              wallets: _Wallets(),
              notes: ConversationNotes(),
              load: () => db,
              loadStatus: (id) async => _balance('900'),
              hibernate: (id) async {
                calls();
                return unsupported;
              },
              filter: StoppedFilter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('says it once, and then hides Hibernate for the instances of that node', (tester) async {
      var calls = 0;
      await openList(tester, [_instance('a'), _instance('b')], () => ++calls);
      await tester.longPress(find.byKey(const Key('chats-row-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-hibernate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hibernate-ok')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text(appL10n.chatsRefusalUnsupported), findsOneWidget);
      expect(hibernationSupport.isUnsupported('node.example:53460'), isTrue);
      // The other instance of the same node has no Hibernate any more. Stop is still there.
      ScaffoldMessenger.of(tester.element(find.byKey(const Key('chats-row-b')))).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('chats-row-b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-action-hibernate')), findsNothing);
      expect(find.byKey(const Key('chats-action-stop')), findsOneWidget);
    });

    testWidgets('the dialog does not open for such a node, and no call is made', (tester) async {
      var calls = 0;
      hibernationSupport.markUnsupported('node.example:53460');
      await openList(tester, [_instance('a')], () => ++calls);
      final context = tester.element(find.byKey(const Key('chats-row-a')));
      final done = await confirmAndHibernateInstance(
        context,
        _instance('a'),
        wallets: _Wallets(),
        hibernate: (_) async => throw StateError('must not be called'),
      );
      expect(done, isNull);
      expect(find.byKey(const Key('hibernate-confirm')), findsNothing);
      expect(calls, 0);
    });

    testWidgets('the info page explains it, and shows only Stop', (tester) async {
      hibernationSupport.markUnsupported('node.example:53460');
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: InstanceInfoScreen(
            instance: _instance('a'),
            state: InstanceState.running,
            loadReceipts: (_) => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('info-hibernation-unsupported')), findsOneWidget);
      expect(find.byKey(const Key('info-hibernate')), findsNothing);
      expect(find.byKey(const Key('info-stop')), findsOneWidget);
    });

    testWidgets('another node keeps its actions', (tester) async {
      hibernationSupport.markUnsupported('other.example:53460');
      await openList(tester, [_instance('a')], () => 0);
      await tester.longPress(find.byKey(const Key('chats-row-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-action-hibernate')), findsOneWidget);
    });
  });
}

class _Wallets implements FullWallets {
  @override
  Future<List<PayerWallet>> payers() async => [
    const PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: true),
  ];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async => true;
}
