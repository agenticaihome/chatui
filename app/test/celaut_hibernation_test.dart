import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
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

final _service = '65' * 32;

AwakeResourcesView _resources({ResourcesSourceView source = ResourcesSourceView.readFromNode}) =>
    AwakeResourcesView(
      cpuQuota: BigInt.from(150000),
      cpuPeriod: BigInt.from(100000),
      memLimit: BigInt.from(512 * 1024 * 1024),
      source: source,
    );

InstanceListView _instance(
  String id, {
  int? stoppedAt,
  int? hibernatedAt,
  AwakeResourcesView? resources,
}) => InstanceListView(
  instanceId: id,
  peerId: 'aa' * 32,
  address: 'node.example:53460',
  serviceId: _service,
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
  awakeResources: resources,
);

class _Wallets implements FullWallets {
  _Wallets({this.full = true});

  final bool full;

  @override
  Future<List<PayerWallet>> payers() async =>
      full ? [const PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: true)] : const [];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async => true;
}

HibernationView _view(
  InstanceStateView state, {
  ResourceRefusalView? refusal,
  String message = '',
  AwakeResourcesView? resources,
}) => HibernationView(
  state: state,
  instanceBalanceMu: refusal == null ? '800' : '',
  resources: resources,
  refusal: refusal,
  message: message,
);

/// The database and the calls of the bridge, in memory.
class _Node {
  List<InstanceListView> db = [];
  final hibernated = <String>[];
  final woken = <String>[];
  HibernationView? hibernateAnswer;
  HibernationView? wakeAnswer;

  List<InstanceListView> load() => List.of(db);

  Future<InstanceStatusView> status(String id) async =>
      InstanceStatusView(instanceBalanceMu: '900', costSoFarMu: '5', streamsOpened: BigInt.one);

  Future<HibernationView> hibernate(String id) async {
    hibernated.add(id);
    final answer = hibernateAnswer ?? _view(InstanceStateView.hibernated, resources: _resources());
    if (answer.refusal == null) {
      db = [
        for (final i in db)
          i.instanceId == id ? _instance(id, hibernatedAt: 700, resources: _resources()) : i,
      ];
    }
    return answer;
  }

  Future<HibernationView> wake(String id) async {
    woken.add(id);
    final answer = wakeAnswer ?? _view(InstanceStateView.running, resources: _resources());
    if (answer.refusal == null) {
      db = [for (final i in db) i.instanceId == id ? _instance(id, resources: _resources()) : i];
    }
    return answer;
  }
}

void main() {
  late _Node node;
  late StoppedFilter filter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    hibernationSupport.reset();
    node = _Node();
    filter = StoppedFilter();
    await filter.set(true);
  });

  Future<void> open(WidgetTester tester, {bool full = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstanceList(
            chats: true,
            wallets: _Wallets(full: full),
            notes: ConversationNotes(),
            load: node.load,
            loadStatus: node.status,
            hibernate: node.hibernate,
            wake: node.wake,
            filter: filter,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> actions(WidgetTester tester, String id) async {
    await tester.longPress(find.byKey(Key('chats-row-$id')));
    await tester.pumpAndSettle();
  }

  String stateText(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('chats-state-$id'))).data!;

  group('the state of a hibernated instance', () {
    testWidgets('shows as hibernated, not as unreachable, and the default filter keeps it', (
      tester,
    ) async {
      expect(filter.value, isTrue);
      // The node does not answer for the hibernated instance: the status call would fail.
      node.db = [_instance('h1', hibernatedAt: 600, resources: _resources())];
      await open(tester);
      expect(find.byKey(const Key('chats-row-h1')), findsOneWidget);
      expect(stateText(tester, 'h1'), startsWith(appL10n.chatsStateHibernated));
      expect(stateText(tester, 'h1'), isNot(contains(appL10n.chatsStateUnreachable)));
    });

    testWidgets('the filter hides the stopped instance and not the hibernated one', (tester) async {
      node.db = [
        _instance('h1', hibernatedAt: 600, resources: _resources()),
        _instance('old', stoppedAt: 400),
      ];
      await open(tester);
      expect(find.byKey(const Key('chats-row-h1')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-old')), findsNothing);
      // Only the stopped one is counted as hidden.
      expect(find.text(appL10n.chatsShowStopped(1)), findsOneWidget);
    });

    testWidgets('a stopped instance that was hibernated shows as stopped', (tester) async {
      node.db = [_instance('s1', stoppedAt: 800, hibernatedAt: 600)];
      await filter.set(false);
      await open(tester);
      expect(stateText(tester, 's1'), startsWith(appL10n.chatsStateStopped));
    });

    testWidgets('a tap opens the info page, not the conversation', (tester) async {
      node.db = [_instance('h1', hibernatedAt: 600, resources: _resources())];
      await open(tester);
      await tester.tap(find.byKey(const Key('chats-row-h1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('info-wake')), findsOneWidget);
      expect(find.byKey(const Key('chat-connecting')), findsNothing);
    });
  });

  group('the actions of the list', () {
    testWidgets('a running instance has Hibernate, Stop, and no Wake or Delete', (tester) async {
      node.db = [_instance('i1')];
      await open(tester);
      await actions(tester, 'i1');
      expect(find.byKey(const Key('chats-action-hibernate')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-stop')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-wake')), findsNothing);
      expect(find.byKey(const Key('chats-action-delete')), findsNothing);
    });

    testWidgets('a hibernated instance has Wake and Stop, and cannot be deleted', (tester) async {
      node.db = [_instance('h1', hibernatedAt: 600, resources: _resources())];
      await open(tester);
      await actions(tester, 'h1');
      expect(find.byKey(const Key('chats-action-wake')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-stop')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-hibernate')), findsNothing);
      expect(find.byKey(const Key('chats-action-delete')), findsNothing);
    });

    testWidgets('a stopped instance has neither Hibernate nor Wake', (tester) async {
      node.db = [_instance('s1', stoppedAt: 800)];
      await filter.set(false);
      await open(tester);
      await actions(tester, 's1');
      expect(find.byKey(const Key('chats-action-hibernate')), findsNothing);
      expect(find.byKey(const Key('chats-action-wake')), findsNothing);
      expect(find.byKey(const Key('chats-action-delete')), findsOneWidget);
    });

    testWidgets('Hibernate warns, asks, calls the bridge, and the row shows hibernated', (tester) async {
      node.db = [_instance('i1')];
      await open(tester);
      await actions(tester, 'i1');
      await tester.tap(find.byKey(const Key('chats-action-hibernate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hibernate-confirm')), findsOneWidget);
      // The warning: the process state is lost, and only the disk is charged.
      expect(find.text(appL10n.chatsHibernateBody), findsOneWidget);
      expect(appL10n.chatsHibernateBody, contains('process state is lost'));
      expect(appL10n.chatsHibernateBody, contains('only for its disk'));
      await tester.tap(find.byKey(const Key('hibernate-cancel')));
      await tester.pumpAndSettle();
      expect(node.hibernated, isEmpty);
      await actions(tester, 'i1');
      await tester.tap(find.byKey(const Key('chats-action-hibernate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hibernate-ok')));
      await tester.pumpAndSettle();
      expect(node.hibernated, ['i1']);
      expect(find.text(appL10n.chatsHibernated), findsOneWidget);
      expect(stateText(tester, 'i1'), startsWith(appL10n.chatsStateHibernated));
    });

    testWidgets('Hibernate with no full wallet calls nothing and says why', (tester) async {
      node.db = [_instance('i1')];
      await open(tester, full: false);
      await actions(tester, 'i1');
      await tester.tap(find.byKey(const Key('chats-action-hibernate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hibernate-ok')));
      await tester.pumpAndSettle();
      expect(node.hibernated, isEmpty);
      expect(find.text(appL10n.celautOpenFullWalletNeeded), findsOneWidget);
    });

    testWidgets('Wake shows the CPU and RAM that it will use, then calls the bridge', (tester) async {
      node.db = [_instance('h1', hibernatedAt: 600, resources: _resources())];
      await open(tester);
      await actions(tester, 'h1');
      await tester.tap(find.byKey(const Key('chats-action-wake')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wake-confirm')), findsOneWidget);
      final body = tester.widget<Text>(find.byKey(const Key('wake-body'))).data!;
      expect(body, contains('1.50 CPU cores'));
      expect(body, contains('512 MiB'));
      expect(find.byKey(const Key('wake-last-known')), findsNothing);
      await tester.tap(find.byKey(const Key('wake-ok')));
      await tester.pumpAndSettle();
      expect(node.woken, ['h1']);
      expect(find.text(appL10n.chatsWoken), findsOneWidget);
      expect(stateText(tester, 'h1'), isNot(contains(appL10n.chatsStateHibernated)));
    });

    testWidgets('Wake says when the values are only the last known', (tester) async {
      node.db = [
        _instance('h1', hibernatedAt: 600, resources: _resources(source: ResourcesSourceView.lastKnown)),
      ];
      await open(tester);
      await actions(tester, 'h1');
      await tester.tap(find.byKey(const Key('chats-action-wake')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wake-last-known')), findsOneWidget);
    });

    testWidgets('Wake with no stored values calls nothing and says so', (tester) async {
      node.db = [_instance('h1', hibernatedAt: 600)];
      await open(tester);
      await actions(tester, 'h1');
      await tester.tap(find.byKey(const Key('chats-action-wake')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wake-confirm')), findsNothing);
      expect(find.text(appL10n.chatsWakeUnknown), findsOneWidget);
      expect(node.woken, isEmpty);
    });
  });

  group('the refusals', () {
    final cases = <ResourceRefusalView, String Function()>{
      ResourceRefusalView.sharedFilesystem: () => appL10n.chatsRefusalSharedFilesystem,
      ResourceRefusalView.notRevivable: () => appL10n.chatsRefusalNotRevivable,
      ResourceRefusalView.instanceBalance: () => appL10n.chatsRefusalInstanceBalance,
      ResourceRefusalView.noLocalInstance: () => appL10n.chatsRefusalNoLocalInstance,
      ResourceRefusalView.notTheFather: () => appL10n.chatsRefusalNotTheFather,
      ResourceRefusalView.noResources: () => appL10n.chatsRefusalNoResources,
      ResourceRefusalView.notConfirmed: () => appL10n.chatsRefusalNotConfirmed,
      ResourceRefusalView.unsupported: () => appL10n.chatsRefusalUnsupported,
      ResourceRefusalView.other: () => appL10n.chatsRefusalOther('the node said so'),
    };
    for (final entry in cases.entries) {
      testWidgets('hibernate: ${entry.key.name} shows its text and changes nothing', (tester) async {
        node.db = [_instance('i1')];
        node.hibernateAnswer = _view(
          InstanceStateView.running,
          refusal: entry.key,
          message: 'the node said so',
        );
        await open(tester);
        await actions(tester, 'i1');
        await tester.tap(find.byKey(const Key('chats-action-hibernate')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('hibernate-ok')));
        await tester.pumpAndSettle();
        expect(node.hibernated, ['i1']);
        expect(find.text(entry.value()), findsOneWidget);
        expect(stateText(tester, 'i1'), isNot(contains(appL10n.chatsStateHibernated)));
      });
    }

    testWidgets('wake: does not fit shows its text, and the instance stays hibernated', (tester) async {
      node.db = [_instance('h1', hibernatedAt: 600, resources: _resources())];
      node.wakeAnswer = _view(
        InstanceStateView.hibernated,
        refusal: ResourceRefusalView.doesNotFit,
        resources: _resources(),
      );
      await open(tester);
      await actions(tester, 'h1');
      await tester.tap(find.byKey(const Key('chats-action-wake')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wake-ok')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatsRefusalDoesNotFit), findsOneWidget);
      expect(stateText(tester, 'h1'), startsWith(appL10n.chatsStateHibernated));
    });

    testWidgets('an error of the bridge shows the text of its kind', (tester) async {
      node.db = [_instance('i1')];
      await open(tester);
      final context = tester.element(find.byKey(const Key('chats-row-i1')));
      final done = confirmAndHibernateInstance(
        context,
        node.db.single,
        wallets: _Wallets(),
        hibernate: (_) async => throw const CelautError(kind: CelautErrorKind.timeout, message: 'slow'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hibernate-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('hibernate-ok')));
      await tester.pumpAndSettle();
      expect(await done, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    test('every refusal has a text', () {
      // The switch is exhaustive: a new refusal of the bridge does not compile without one.
      expect(ResourceRefusalView.values, hasLength(cases.length + 1));
    });
  });

  group('the info page', () {
    Future<void> info(WidgetTester tester, InstanceListView i, InstanceState state) async {
      // A tall window: the list of the page builds all its rows.
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: InstanceInfoScreen(
            instance: i,
            state: state,
            wallets: _Wallets(),
            hibernate: node.hibernate,
            wake: node.wake,
            loadReceipts: (_) => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String value(WidgetTester tester, String key) =>
        tester.widget<SelectableText>(find.byKey(Key(key))).data!;

    testWidgets('a hibernated instance shows its state, its stored CPU and RAM, and Wake', (
      tester,
    ) async {
      node.db = [_instance('h1', hibernatedAt: 600, resources: _resources())];
      await info(tester, node.db.single, InstanceState.hibernated);
      expect(value(tester, 'info-status'), appL10n.chatsStateHibernated);
      expect(value(tester, 'info-resources'), contains('512 MiB'));
      expect(value(tester, 'info-resources'), contains('1.50'));
      expect(find.byKey(const Key('info-hibernated-since')), findsOneWidget);
      expect(find.byKey(const Key('info-wake')), findsOneWidget);
      expect(find.byKey(const Key('info-hibernate')), findsNothing);
      expect(find.byKey(const Key('info-stop')), findsOneWidget);
      expect(find.byKey(const Key('info-delete')), findsNothing);
    });

    testWidgets('the info page marks the last known values', (tester) async {
      node.db = [
        _instance('h1', hibernatedAt: 600, resources: _resources(source: ResourcesSourceView.lastKnown)),
      ];
      await info(tester, node.db.single, InstanceState.hibernated);
      expect(
        value(tester, 'info-resources'),
        appL10n.chatsInfoResourcesLastKnown('1.50 CPU cores, 512 MiB'),
      );
    });

    testWidgets('a hibernated instance with no stored values says so', (tester) async {
      node.db = [_instance('h1', hibernatedAt: 600)];
      await info(tester, node.db.single, InstanceState.hibernated);
      expect(value(tester, 'info-resources'), appL10n.chatsInfoResourcesNone);
    });

    testWidgets('a running instance has Hibernate and Stop, and no Wake', (tester) async {
      node.db = [_instance('i1')];
      await info(tester, node.db.single, InstanceState.running);
      expect(find.byKey(const Key('info-hibernate')), findsOneWidget);
      expect(find.byKey(const Key('info-stop')), findsOneWidget);
      expect(find.byKey(const Key('info-wake')), findsNothing);
      expect(find.byKey(const Key('info-resources')), findsNothing);
    });

    testWidgets('a stopped instance has Delete only', (tester) async {
      node.db = [_instance('s1', stoppedAt: 800)];
      await info(tester, node.db.single, InstanceState.stopped);
      expect(find.byKey(const Key('info-hibernate')), findsNothing);
      expect(find.byKey(const Key('info-wake')), findsNothing);
      expect(find.byKey(const Key('info-delete')), findsOneWidget);
    });

    testWidgets('Hibernate on the info page calls the bridge', (tester) async {
      node.db = [_instance('i1')];
      await info(tester, node.db.single, InstanceState.running);
      await tester.ensureVisible(find.byKey(const Key('info-hibernate')));
      await tester.tap(find.byKey(const Key('info-hibernate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hibernate-ok')));
      await tester.pumpAndSettle();
      expect(node.hibernated, ['i1']);
    });
  });

  test('the copies of an instance keep the hibernation', () {
    final i = _instance('h1', hibernatedAt: 600, resources: _resources());
    final renamed = withAlias(i, 'x');
    expect(renamed.hibernatedAt, 600);
    expect(renamed.awakeResources, i.awakeResources);
    final titled = withTitle(i, 'y');
    expect(titled.hibernatedAt, 600);
    expect(titled.awakeResources, i.awakeResources);
  });
}
