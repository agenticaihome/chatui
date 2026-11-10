import 'dart:async';

import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/celaut_format.dart';
import 'package:argus_wallet/celaut/celaut_strings.dart';
import 'package:argus_wallet/celaut/compute_home_flag.dart';
import 'package:argus_wallet/celaut/overview_cache.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/celaut/wallet_money.dart';
import 'package:argus_wallet/format.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/compute_home_screen.dart';
import 'package:argus_wallet/ui/celaut/node_resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _a = 'aa' * 32;
final _b = 'bb' * 32;
final _c = 'cc' * 32;

ComputeOverviewView _overview() => ComputeOverviewView(
  nodesCounted: 2,
  nodesUnreachable: 1,
  // One counted node gives no CPU: "at least 6 cores (1 node unknown)".
  cpuCores: const CoresTotalView(total: null, known: 6, unknownNodes: 1, atLeast: true),
  memBytes: const BytesTotalView(
    total: 8589934592,
    known: 8589934592,
    unknownNodes: 0,
    atLeast: false,
  ),
  // No node gives the disk: unknown, not "at least 0".
  diskBytes: const BytesTotalView(total: null, known: 0, unknownNodes: 2, atLeast: false),
  creditNanoErg: const NanoErgTotalView(
    total: null,
    known: '14500000',
    unknownNodes: 1,
    atLeast: true,
  ),
  paidNanoErg: const NanoErgTotalView(
    total: null,
    known: '10000000',
    unknownNodes: 1,
    atLeast: true,
  ),
  freeNanoErg: const NanoErgTotalView(
    total: null,
    known: '4500000',
    unknownNodes: 1,
    atLeast: true,
  ),
  nodes: [
    NodeComputeView(
      peerId: _a,
      address: 'a.example:1',
      reachable: true,
      cpuCores: 6,
      memBytes: 8589934592,
      creditMu: '14500000',
      muPerNanoErg: '1',
      creditNanoErg: '14500000',
      paidMu: '10000000',
      paidNanoErg: '10000000',
      freeMu: '4500000',
      freeNanoErg: '4500000',
      clientUnknown: false,
    ),
    NodeComputeView(
      peerId: _b,
      address: 'b.example:2',
      reachable: false,
      error: 'This RPC requires a client_id minted by GenerateClient first.',
      clientUnknown: true,
    ),
    NodeComputeView(
      peerId: _c,
      address: 'c.example:3',
      reachable: false,
      error: 'refused',
      clientUnknown: false,
    ),
  ],
  instances: [
    RunningInstanceView(
      instanceId: 'i1',
      peerId: _a,
      serviceId: 'dd' * 32,
      startedAt: 1,
      balanceMu: '900000',
      costSoFarMu: '100000',
      costSoFarNanoErg: '100000',
    ),
    RunningInstanceView(instanceId: 'i2', peerId: _c, serviceId: 'ee' * 32, startedAt: 2),
  ],
);

extension on ComputeOverviewView {
  ComputeOverviewView copyWithNoNodes() => ComputeOverviewView(
    nodesCounted: 0,
    nodesUnreachable: 0,
    cpuCores: cpuCores,
    memBytes: memBytes,
    diskBytes: diskBytes,
    creditNanoErg: creditNanoErg,
    paidNanoErg: paidNanoErg,
    freeNanoErg: freeNanoErg,
    nodes: const [],
    instances: const [],
  );
}

const _full = WalletSum(count: 1, unknown: 0, knownNano: 250000000);

class _Run {
  final newClients = <String>[];
  var loads = 0;
  var nodesOpened = 0;
  var walletsOpened = 0;
}

void main() {
  Future<_Run> pump(
    WidgetTester tester, {
    WalletMoney? money,
    double? usdPerErg = 2.0,
    Future<ComputeOverviewView> Function()? load,
  }) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final run = _Run();
    await tester.pumpWidget(
      MaterialApp(
        home: ComputeHomeScreen(
          money:
              money ??
              const WalletMoney(full: _full, gate: FullWalletGate.open),
          usdPerErg: usdPerErg,
          onWallets: () => run.walletsOpened++,
          onNodes: () => run.nodesOpened++,
          load: () async {
            run.loads++;
            return load == null ? _overview() : load();
          },
          newClient: (node) async {
            run.newClients.add('${node.host}:${node.port}');
            return NewClientView(peerId: _b, freeCreditMu: '4500000', earlierClients: 1);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return run;
  }

  String rowTexts(WidgetTester tester, String key) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
      .map((t) => t.data)
      .join(' | ');

  setUp(() => overviewCache.value = null);

  testWidgets('the card of state: nodes, then credit, then wallets', (tester) async {
    await pump(tester);
    final nodes = tester.getTopLeft(find.byKey(const Key('compute-home-nodes'))).dy;
    final credit = tester.getTopLeft(find.byKey(const Key('compute-home-credit'))).dy;
    final wallets = tester.getTopLeft(find.byKey(const Key('compute-home-wallets'))).dy;
    expect(nodes, lessThan(credit));
    expect(credit, lessThan(wallets));
    expect(find.text('Chatui', findRichText: true), findsOneWidget);
  });

  testWidgets('the detail of each node and of the money is not on the home screen', (tester) async {
    await pump(tester);
    final l = appL10n;
    for (final gone in [
      l.celautHomeOfferedNote,
      l.celautHomePaidCredit,
      l.celautHomeFreeCredit,
      l.celautHomeUsdSource,
      l.celautNodesCheckNow,
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    // No address, no rate in MU, no node card.
    expect(find.textContaining('a.example:1'), findsNothing);
    expect(find.byKey(Key('compute-home-credit-$_a')), findsNothing);
  });

  testWidgets('the nodes: one line with the ready ones, the cores and the memory', (tester) async {
    final run = await pump(tester);
    final l = appL10n;
    final line = rowTexts(tester, 'compute-home-nodes');
    expect(line, contains(l.celautHomeNodesReady('2', '3')));
    expect(line, contains(l.celautAtLeast(CelautStrings.cores(6), 1)));
    expect(line, contains(CelautStrings.bytes(8589934592)));
    // A tap shows how the nodes split the total (#123), not the node list.
    await tester.tap(find.byKey(const Key('compute-home-nodes')));
    await tester.pumpAndSettle();
    expect(find.byType(NodeResourcesScreen), findsOneWidget);
    expect(find.byKey(const Key('resources-unreachable')), findsOneWidget);
    expect(run.nodesOpened, 0);
  });

  testWidgets('the credit on the nodes and the full wallets are one line each, with USD', (tester) async {
    final run = await pump(tester);
    final l = appL10n;
    final credit = rowTexts(tester, 'compute-home-credit');
    expect(credit, contains(l.celautHomeCreditOnNodes));
    expect(credit, contains(l.celautAtLeast(formatNanoErg(BigInt.from(14500000)), 1)));
    final wallets = rowTexts(tester, 'compute-home-wallets');
    expect(wallets, contains(l.celautHomeWallets));
    expect(wallets, contains(formatErg(250000000)));
    expect(wallets, contains(l.celautHomeUsd('\$0.50')));
    await tester.tap(find.byKey(const Key('compute-home-wallets')));
    expect(run.walletsOpened, 1);
    await tester.tap(find.byKey(const Key('compute-home-credit')));
    expect(run.nodesOpened, 1);
  });

  testWidgets('without the oracle price the USD is unknown, not \$0', (tester) async {
    await pump(tester, usdPerErg: null);
    expect(rowTexts(tester, 'compute-home-wallets'), contains(appL10n.celautHomeUsdUnknown));
    expect(find.textContaining('\$0'), findsNothing);
  });

  testWidgets('the running instances and Run a service are not on the home screen', (tester) async {
    // The overview has two running instances: they are in the conversations, not here.
    await pump(tester);
    expect(find.text(appL10n.celautHomeInstancesTitle.toUpperCase()), findsNothing);
    expect(find.byKey(const Key('compute-home-instance-i1')), findsNothing);
    expect(find.byKey(const Key('compute-home-stop-i1')), findsNothing);
    expect(find.byKey(const Key('compute-home-run')), findsNothing);
    expect(find.text(appL10n.celautRunTitle), findsNothing);
  });

  testWidgets('with no node, the nodes line says how to add one', (tester) async {
    await pump(tester, load: () async => _overview().copyWithNoNodes());
    expect(rowTexts(tester, 'compute-home-nodes'), contains(appL10n.celautHomeNoNodes));
    expect(find.byKey(const Key('compute-home-credit')), findsNothing);
  });

  testWidgets('the last overview shows at once when the screen opens again', (tester) async {
    await pump(tester);
    expect(overviewCache.value, isNotNull);
    // The next open: the nodes do not answer yet, and the last state is there.
    final never = Completer<ComputeOverviewView>();
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: ComputeHomeScreen(
          money: const WalletMoney(full: _full, gate: FullWalletGate.open),
          usdPerErg: 2.0,
          onWallets: () {},
          load: () => never.future,
        ),
      ),
    );
    await tester.pump();
    expect(rowTexts(tester, 'compute-home-nodes'), contains(appL10n.celautHomeNodesReady('2', '3')));
    expect(find.byKey(const Key('compute-home-updating')), findsOneWidget);
    expect(find.text(appL10n.celautHomeLoading), findsNothing);
    never.complete(_overview());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('compute-home-updating')), findsNothing);
  });

  testWidgets('the first open, with no last overview, says that it loads', (tester) async {
    final never = Completer<ComputeOverviewView>();
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ComputeHomeScreen(
          money: const WalletMoney(full: _full, gate: FullWalletGate.open),
          usdPerErg: 2.0,
          onWallets: () {},
          load: () => never.future,
        ),
      ),
    );
    await tester.pump();
    expect(rowTexts(tester, 'compute-home-nodes'), contains(appL10n.celautHomeLoading));
    // The wallets do not wait for the nodes.
    expect(rowTexts(tester, 'compute-home-wallets'), contains(formatErg(250000000)));
    never.complete(_overview());
    await tester.pumpAndSettle();
  });

  testWidgets('a forgotten client: the user chooses a new client', (tester) async {
    final run = await pump(tester);
    expect(find.byKey(Key('compute-home-client-unknown-$_c')), findsNothing);
    await tester.tap(find.byKey(Key('compute-home-client-unknown-$_b')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('client-unknown-dialog')), findsOneWidget);
    expect(find.byKey(const Key('client-unknown-warning')), findsOneWidget);
    expect(run.newClients, isEmpty);
    await tester.tap(find.byKey(const Key('client-unknown-new')));
    await tester.pumpAndSettle();
    expect(run.newClients, ['b.example:2']);
    expect(run.loads, 2);
  });

  testWidgets('a forgotten client: "Retry later" changes nothing', (tester) async {
    final run = await pump(tester);
    await tester.tap(find.byKey(Key('compute-home-client-unknown-$_b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('client-unknown-retry')));
    await tester.pumpAndSettle();
    expect(run.newClients, isEmpty);
    expect(run.loads, 1);
  });

  test('the compute home is the default home screen; the setting turns it off', () async {
    SharedPreferences.setMockInitialValues({});
    final flag = ComputeHomeFlag();
    expect(flag.value, isTrue);
    await flag.load();
    expect(flag.value, isTrue);
    await flag.set(false);
    final again = ComputeHomeFlag();
    await again.load();
    expect(again.value, isFalse);
  });

  group('sums and USD', () {
    test('a sum over nodes is exact, "at least", or unknown', () {
      final l = appL10n;
      String cores(double? total, double known, int unknown, bool atLeast) => partialSum<double>(
        total: total,
        known: known,
        unknownNodes: unknown,
        atLeast: atLeast,
        format: CelautStrings.cores,
      );
      expect(cores(6, 6, 0, false), CelautStrings.cores(6));
      expect(cores(null, 6, 2, true), l.celautAtLeast(CelautStrings.cores(6), 2));
      expect(cores(null, 6, 2, true), contains('2 nodes unknown'));
      expect(cores(null, 0, 3, false), l.celautUnknown);
    });

    test('USD from the oracle price, unknown without it', () {
      expect(usdOf(BigInt.from(1000000000), 1.5), '\$1.50');
      expect(usdOf(BigInt.from(1234567000000000), 1.0), '\$1,234,567.00');
      expect(usdOf(BigInt.from(1000), 1.0), '\$0.0000010');
      expect(usdOf(BigInt.from(8900000), 0.6), '\$0.0053');
      expect(usdOf(BigInt.zero, 1.0), '\$0.00');
      expect(usdOf(BigInt.from(1000000000), null), isNull);
      expect(usdOf(BigInt.from(1000000000), 0), isNull);
      expect(usdOf(BigInt.from(1000000000), double.nan), isNull);
      expect(usdOf(null, 1.0), isNull);
      expect(usdTextOf(null, 1.0), appL10n.celautHomeUsdUnknown);
      expect(usdTextOf(BigInt.from(2000000000), 0.5), appL10n.celautHomeUsd('\$1.00'));
    });
  });
}
