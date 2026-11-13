import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/api/celaut_spending.dart';
import 'package:argus_wallet/format.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/node_spending.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_spending.dart';

// Issue #136: the balance and the spending of the client on each node, from the signed
// statements of the node. A read costs MU: only on a tap, after a question with the most
// that it can cost. A value that the app did not read is "unknown", never 0.

final _peer = 'ab' * 32;
final _refA = 'a1' * 32;
final _refGone = 'f0' * 32;

InstanceListView _instance(String id, String name) => InstanceListView(
      instanceId: id,
      peerId: _peer,
      address: 'node.example:8090',
      serviceId: 'cd' * 32,
      slots: Uint16List(0),
      chatSlots: Uint16List(0),
      cardsSlots: Uint16List(0),
      webSlots: Uint16List(0),
      startedAt: 1,
      startChargeMu: '1000',
      name: name,
      alias: '',
      title: '',
      refundMu: '',
    );

NodeSpendingView _read() => nodeSpending(
      peerId: _peer,
      account: readAccount(balance: '7447895', spent: '1552105', received: '9000000'),
      statements: '2105',
      instances: [
        InstanceSpendingView(
          instanceRef: _refA,
          instanceId: 'i1',
          running: true,
          movedMu: '850000',
          costs: null,
        ),
        InstanceSpendingView(
          instanceRef: _refGone,
          instanceId: '',
          running: false,
          movedMu: '700000',
          costs: null,
        ),
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('never read: the balance now, and the spending is unknown, not 0', (tester) async {
    final api = FakeSpendingApi();
    await pump(tester, NodeSpendingSection(peerId: _peer, address: 'node.example:8090', api: api));
    final l = appL10n;
    expect(text(tester, 'node-spending-credit'), '1,000,000 MU');
    expect(text(tester, 'node-spending-spent'), l.celautUnknown);
    expect(find.byKey(const Key('node-spending-never')), findsOneWidget);
    expect(find.byKey(const Key('node-spending-balance')), findsNothing);
    // Nothing was read: the screen did not pay.
    expect(api.nodeReads, isEmpty);
  });

  testWidgets('a balance that the node does not give is unknown', (tester) async {
    final api = FakeSpendingApi(creditAnswer: null);
    await pump(tester, NodeSpendingSection(peerId: _peer, address: 'node.example:8090', api: api));
    expect(text(tester, 'node-spending-credit'), appL10n.celautUnknown);
  });

  testWidgets('a read asks first, with the most that it costs; Cancel reads nothing', (tester) async {
    final api = FakeSpendingApi(list: [_instance('i1', 'echo')])..afterNodeRead = _read();
    await pump(tester, NodeSpendingSection(peerId: _peer, address: 'node.example:8090', api: api));
    final l = appL10n;
    await tester.tap(find.byKey(const Key('node-spending-read')));
    await tester.pumpAndSettle();
    expect(find.text(l.celautSpendReadBody('node.example:8090', '2,000 MU')), findsOneWidget);
    await tester.tap(find.byKey(const Key('spend-read-cancel')));
    await tester.pumpAndSettle();
    expect(api.nodeReads, isEmpty);

    await tester.tap(find.byKey(const Key('node-spending-read')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spend-read-ok')));
    await tester.pumpAndSettle();
    // The budget of the read is the quote that the user saw.
    expect(api.nodeReads, ['node.example:8090 2000']);
    expect(text(tester, 'node-spending-spent'), '1,552,105 MU');
    expect(text(tester, 'node-spending-balance'), '7,447,895 MU');
    expect(text(tester, 'node-spending-reads'), '2,105 MU');
    expect(text(tester, 'node-spending-read-at'), formatTxTime(1790000000 * 1000));
    expect(find.text(l.celautSpendReadDone), findsOneWidget);
    // The balance now is asked again: the read was a movement.
    expect(api.credits, 2);

    // The split by instance is one tap away.
    expect(find.text('echo'), findsNothing);
    await tester.tap(find.byKey(const Key('node-spending-instances')));
    await tester.pumpAndSettle();
    expect(find.text(l.celautSpendInstances(2)), findsOneWidget);
    expect(find.text('echo'), findsOneWidget);
    expect(find.text(l.celautSpendRunning), findsOneWidget);
    expect(find.text('850,000 MU'), findsOneWidget);
    // An instance that the app deleted keeps its line, by its short instance_ref.
    expect(find.text(shorten(_refGone, head: 6, tail: 4)), findsOneWidget);
    expect(find.text(l.celautSpendDeleted), findsOneWidget);
  });

  testWidgets('a node that does not price statements is not read', (tester) async {
    final api = FakeSpendingApi(quote: SpendingQuoteView(maxMu: null, fromSeq: BigInt.zero));
    await pump(tester, NodeSpendingSection(peerId: _peer, address: 'node.example:8090', api: api));
    expect(find.byKey(const Key('node-spending-no-rates')), findsOneWidget);
    expect(find.byKey(const Key('node-spending-read')), findsNothing);
  });

  testWidgets('a statement that does not verify is an error, and the sums stay', (tester) async {
    final api = FakeSpendingApi()
      ..readError = const CelautError(
        kind: CelautErrorKind.protocol,
        message: 'the statement is not valid: the signature is not valid for the node of the connection',
      );
    await pump(tester, NodeSpendingSection(peerId: _peer, address: 'node.example:8090', api: api));
    await tester.tap(find.byKey(const Key('node-spending-read')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spend-read-ok')));
    await tester.pumpAndSettle();
    expect(
      text(tester, 'node-spending-error'),
      appL10n.celautSpendReadFailed(
          'the statement is not valid: the signature is not valid for the node of the connection'),
    );
    expect(text(tester, 'node-spending-spent'), appL10n.celautUnknown);
  });

  testWidgets('a partial or incomplete read says so; the button reads the rest', (tester) async {
    final api = FakeSpendingApi(views: {
      _peer: nodeSpending(
        peerId: _peer,
        account: readAccount(spent: '10', partial: true, incomplete: true, since: 1789990000),
      ),
    });
    await pump(tester, NodeSpendingSection(peerId: _peer, address: 'node.example:8090', api: api));
    final l = appL10n;
    expect(text(tester, 'node-spending-spent'), l.celautSpendSince('10 MU', formatTxTime(1789990000 * 1000)));
    expect(find.byKey(const Key('node-spending-partial')), findsOneWidget);
    expect(find.byKey(const Key('node-spending-incomplete')), findsOneWidget);
    expect(find.text(l.celautSpendReadMore), findsOneWidget);
  });

  testWidgets('the costs of an instance: a paid read gives each kind of charge', (tester) async {
    final api = FakeSpendingApi(list: [_instance('i1', 'echo')])
      ..afterInstanceRead = readAccount(
        balance: '938000',
        spent: '212000',
        kinds: const [
          KindFlowView(kind: 'build', outMu: '100000', inMu: '0'),
          KindFlowView(kind: 'maintenance', outMu: '100000', inMu: '0'),
          KindFlowView(kind: 'tunnel', outMu: '10000', inMu: '0'),
          KindFlowView(kind: 'start', outMu: '0', inMu: '1000000'),
          KindFlowView(kind: 'odd_kind', outMu: '2000', inMu: '0'),
        ],
      );
    await pump(
      tester,
      InstanceCostsSheet(
        instance: InstanceSpendingView(
          instanceRef: _refA,
          instanceId: 'i1',
          running: true,
          movedMu: '850000',
          costs: null,
        ),
        name: 'echo',
        node: 'node.example:8090',
        api: api,
      ),
    );
    final l = appL10n;
    expect(text(tester, 'instance-costs-moved'), '850,000 MU');
    expect(find.text(l.celautSpendCostsNote), findsOneWidget);
    await tester.tap(find.byKey(const Key('instance-costs-read')));
    await tester.pumpAndSettle();
    expect(find.text(l.celautSpendReadCostsTitle), findsOneWidget);
    await tester.tap(find.byKey(const Key('spend-read-ok')));
    await tester.pumpAndSettle();
    expect(api.instanceReads, ['i1 2000']);
    expect(text(tester, 'instance-costs-spent'), '212,000 MU');
    expect(find.text(l.celautSpendKindMaintenance), findsOneWidget);
    expect(find.text(l.celautSpendKindTunnel), findsOneWidget);
    expect(text(tester, 'instance-costs-kind-tunnel'), '−10,000 MU');
    expect(text(tester, 'instance-costs-kind-start'), '+1,000,000 MU');
    // A kind that the app does not know shows as the node wrote it.
    expect(find.text('odd_kind'), findsOneWidget);
  });

  testWidgets('a deleted instance has no read of its own', (tester) async {
    await pump(
      tester,
      InstanceCostsSheet(
        instance: InstanceSpendingView(
          instanceRef: _refGone,
          instanceId: '',
          running: false,
          movedMu: '700000',
          costs: null,
        ),
        name: 'f0f0f0…f0f0',
        node: 'node.example:8090',
        api: FakeSpendingApi(),
      ),
    );
    expect(find.byKey(const Key('instance-costs-read')), findsNothing);
  });

  group('the home summary', () {
    NodeComputeView node(String peer, {String? rate = '1', String? credit = '5000000'}) => NodeComputeView(
          peerId: peer,
          address: '$peer.example:1',
          reachable: rate != null,
          creditMu: credit,
          muPerNanoErg: rate,
          clientUnknown: false,
        );

    ComputeOverviewView overview(List<NodeComputeView> nodes) => ComputeOverviewView(
          nodesCounted: nodes.length,
          nodesUnreachable: 0,
          cpuCores: const CoresTotalView(total: 1, known: 1, unknownNodes: 0, atLeast: false),
          memBytes: const BytesTotalView(total: 1, known: 1, unknownNodes: 0, atLeast: false),
          diskBytes: const BytesTotalView(total: 1, known: 1, unknownNodes: 0, atLeast: false),
          creditNanoErg: const NanoErgTotalView(total: '1', known: '1', unknownNodes: 0, atLeast: false),
          paidNanoErg: const NanoErgTotalView(total: '1', known: '1', unknownNodes: 0, atLeast: false),
          freeNanoErg: const NanoErgTotalView(total: '1', known: '1', unknownNodes: 0, atLeast: false),
          nodes: nodes,
          instances: const [],
        );

    test('the spending in nanoERG: the sum, at least the known part, or unknown', () {
      final o = overview([node('a'), node('b', rate: '2')]);
      final read = [
        nodeSpending(peerId: 'a', account: readAccount(spent: '1000')),
        nodeSpending(peerId: 'b', account: readAccount(spent: '1000')),
      ];
      expect(spentNanoErg(o, read), (total: BigInt.from(1500), known: BigInt.from(1500), unknown: 0));
      // One node never read: at least the known part.
      final half = [read.first, nodeSpending(peerId: 'b')];
      expect(spentNanoErg(o, half), (total: null, known: BigInt.from(1000), unknown: 1));
      // No rate (unreachable node): unknown too.
      expect(spentNanoErg(overview([node('a', rate: null)]), [read.first]).total, isNull);
      // Nothing read at all.
      expect(spentNanoErg(o, const []), (total: null, known: BigInt.zero, unknown: 2));
    });

    testWidgets('the split by node: the balance now and the spending of the last read', (tester) async {
      final api = FakeSpendingApi(views: {'a': nodeSpending(peerId: 'a', account: readAccount(spent: '1000'))});
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: argusTheme(watchful: false),
        home: NodeBalancesScreen(overview: overview([node('a'), node('b', credit: null)]), api: api),
      ));
      await tester.pumpAndSettle();
      final l = appL10n;
      expect(text(tester, 'node-balance-credit-a'), '5,000,000 MU');
      expect(text(tester, 'node-balance-spent-a'), l.celautHomeSpent('1,000 MU'));
      expect(text(tester, 'node-balance-credit-b'), l.celautUnknown);
      expect(text(tester, 'node-balance-spent-b'), l.celautHomeSpent(l.celautUnknown));
    });
  });
}
