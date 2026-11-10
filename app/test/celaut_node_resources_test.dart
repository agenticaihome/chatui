import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/celaut/celaut_strings.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/node_resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _big = 'aa' * 32;
final _small = 'bb' * 32;
final _blind = 'cc' * 32;
final _down = 'dd' * 32;

const _gib = 1024 * 1024 * 1024;

NodeComputeView _node(String peer, String address, {double? cpu, int? mem, int? disk, bool reachable = true}) =>
    NodeComputeView(
      peerId: peer,
      address: address,
      reachable: reachable,
      cpuCores: cpu,
      memBytes: mem,
      diskBytes: disk,
      clientUnknown: false,
    );

/// Three nodes answered (one gives no memory and no disk), one did not.
ComputeOverviewView _overview() => ComputeOverviewView(
      nodesCounted: 3,
      nodesUnreachable: 1,
      cpuCores: const CoresTotalView(total: 14, known: 14, unknownNodes: 0, atLeast: false),
      memBytes: const BytesTotalView(total: null, known: 24 * _gib, unknownNodes: 1, atLeast: true),
      diskBytes: const BytesTotalView(total: null, known: 300 * _gib, unknownNodes: 1, atLeast: true),
      creditNanoErg: const NanoErgTotalView(total: '0', known: '0', unknownNodes: 0, atLeast: false),
      paidNanoErg: const NanoErgTotalView(total: '0', known: '0', unknownNodes: 0, atLeast: false),
      freeNanoErg: const NanoErgTotalView(total: '0', known: '0', unknownNodes: 0, atLeast: false),
      nodes: [
        _node(_small, 'small.example:1', cpu: 2, mem: 8 * _gib, disk: 100 * _gib),
        _node(_big, 'big.example:2', cpu: 8, mem: 16 * _gib, disk: 200 * _gib),
        _node(_blind, 'blind.example:3', cpu: 4),
        _node(_down, 'down.example:4', reachable: false),
      ],
      instances: const [],
    );

void main() {
  Future<void> pump(WidgetTester tester, {ThemeData? theme, double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(theme: theme, home: NodeResourcesScreen(overview: _overview())));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('by resource is the default: the total of the CPU and how the nodes split it', (tester) async {
    await pump(tester);
    final l = appL10n;
    expect(textOf(tester, 'resources-total'), l.celautResourcesTotal(CelautStrings.cpuLabel, CelautStrings.cores(14), 3));
    expect(find.byKey(const Key('resources-bar')), findsOneWidget);
    // The largest part first, each node with its value; no full id.
    final big = tester.getTopLeft(find.byKey(Key('resources-part-$_big'))).dy;
    final small = tester.getTopLeft(find.byKey(Key('resources-part-$_small'))).dy;
    expect(big, lessThan(small));
    expect(find.text(CelautStrings.cores(8)), findsOneWidget);
    expect(find.textContaining(_big), findsNothing);
    // The node that did not answer is counted apart; one note about the data.
    expect(textOf(tester, 'resources-unreachable'), l.celautResourcesUnreachable(1));
    expect(find.byKey(Key('resources-part-$_down')), findsNothing);
    expect(find.text(l.celautResourcesNote), findsOneWidget);
  });

  testWidgets('a value that a node does not give is unknown, never 0, and the total says "at least"', (tester) async {
    await pump(tester);
    final l = appL10n;
    await tester.tap(find.byKey(const Key('resources-pick-memory')));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'resources-total'),
      l.celautResourcesTotal(CelautStrings.memoryLabel, l.celautAtLeast(CelautStrings.bytes(24 * _gib), 1), 3),
    );
    final blind = find.byKey(Key('resources-part-$_blind'));
    expect(find.descendant(of: blind, matching: find.text(l.celautUnknown)), findsOneWidget);
    expect(find.descendant(of: blind, matching: find.text(CelautStrings.bytes(0))), findsNothing);
    expect(find.text(CelautStrings.bytes(0)), findsNothing);
    // The unknown part has its own pattern in the bar.
    expect(find.descendant(of: find.byKey(const Key('resources-bar')), matching: find.byKey(const Key('share-unknown'))), findsOneWidget);
  });

  testWidgets('by node: a card for each node, the largest first, with its three resources', (tester) async {
    await pump(tester);
    await tester.tap(find.text(appL10n.celautResourcesByNode));
    await tester.pumpAndSettle();
    final tops = [
      for (final p in [_big, _small, _blind]) tester.getTopLeft(find.byKey(Key('resources-node-$p'))).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(textOf(tester, 'resources-node-$_big-memory'), CelautStrings.bytes(16 * _gib));
    expect(textOf(tester, 'resources-node-$_blind-memory'), appL10n.celautUnknown);
    expect(textOf(tester, 'resources-node-$_blind-disk'), appL10n.celautUnknown);
    expect(find.byKey(Key('resources-node-$_down')), findsNothing);
  });

  for (final palette in [argusTheme(watchful: true), argusTheme(watchful: false)]) {
    testWidgets('fits a phone of 360 dp with large fonts (${palette.brightness.name})', (tester) async {
      await pump(tester, theme: palette, scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(appL10n.celautResourcesByNode));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('a node counts with its largest entry: memory, then cores, then disk; known over unknown', () {
    NodeResourcesView e(String a, {double? cpu, int? mem, int? disk}) =>
        NodeResourcesView(architecture: a, cpuCores: cpu, memLimitBytes: mem, diskSpaceBytes: disk, benchmark: const []);
    expect(largestEntry(const []), isNull);
    expect(largestEntry([e('x', cpu: 8), e('y', cpu: 1, mem: 1)])!.architecture, 'y');
    expect(largestEntry([e('x', cpu: 2, mem: 4), e('y', cpu: 4, mem: 4)])!.architecture, 'y');
    expect(largestEntry([e('x', mem: 4), e('y', mem: 4)])!.architecture, 'x');
    expect(resourcesSummary(2, null, null), 'CPU 2 cores · Memory unknown · Disk unknown');
  });
}
