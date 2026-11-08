import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut_descendants.dart';
import 'package:argus_wallet/bridge/api/celaut_receipts.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/descendants_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _ref = 'ab' * 32;
final _ref2 = 'cd' * 32;

DescendantView _d(
  String ref, {
  int depth = 1,
  DescendantStateView state = DescendantStateView.notChecked,
  String? leftover,
  String? service,
  int? checked,
}) => DescendantView(
  instanceRef: ref,
  serviceId: service,
  depth: depth,
  state: state,
  lastCheckedAt: checked,
  stopReason: leftover == null ? null : 'out_of_balance',
  leftoverMu: leftover,
  fatherGone: false,
  relayed: false,
);

class _Calls {
  int quotes = 0;
  int checks = 0;
  String? lastBudget;
  int opens = 0;
}

DescendantsApi _api(
  _Calls calls, {
  DescendantsView? view,
  String maxMu = '102',
  Future<CheckReportView> Function(String budget)? check,
  DescendantSlotsView? slots,
}) => DescendantsApi(
  list: (_) => view,
  quote: (id, ref) async {
    calls.quotes++;
    return ReadQuoteView(instanceRef: ref, node: 'node.example:1', remainingHops: 2, maxMu: maxMu);
  },
  check: (id, ref, budget) async {
    calls.checks++;
    calls.lastBudget = budget;
    return (check ??
        (_) async => CheckReportView(
          descendant: _d(ref, state: DescendantStateView.alive),
          newDescendants: const [],
          tooDeep: 0,
          tooMany: 0,
          findings: const [],
        ))(budget);
  },
  receipts: (_, _) => null,
  slots: (_, _) async =>
      slots ?? DescendantSlotsView(known: true, chatSlots: Uint16List(0), webSlots: Uint16List.fromList([80])),
  openTunnel: (_, _, _) async {
    calls.opens++;
    return 12345;
  },
  launch: (_) async => true,
);

Future<void> _pump(WidgetTester tester, DescendantsApi api) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: InstanceDescendantsSection(instanceId: 'i1', node: 'node.example:1', api: api),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DescendantsView _view(List<DescendantView> list) =>
    DescendantsView(root: _d(_ref2, depth: 0), descendants: list);

void main() {
  testWidgets('nothing shows if the app cannot read the descendants', (tester) async {
    await _pump(tester, _api(_Calls()));
    expect(find.byKey(const Key('info-descendants')), findsNothing);
  });

  testWidgets('the list shows the state, the service and the last check', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _api(
        calls,
        view: _view([
          _d(_ref, state: DescendantStateView.alive, service: 'ef' * 32, checked: 1700000000),
          _d(_ref2, depth: 2, state: DescendantStateView.notVerifiable),
        ]),
      ),
    );
    expect(find.byKey(const Key('info-descendants')), findsOneWidget);
    final l = AppLocalizations.of(tester.element(find.byKey(const Key('info-descendants'))));
    expect(find.text(l.descendantsStateAlive), findsOneWidget);
    expect(find.text(l.descendantsStateNotVerifiable), findsOneWidget);
    expect(find.textContaining(l.descendantsServiceUnknown), findsWidgets);
    expect(find.text(l.descendantsNeverChecked), findsWidgets);
    // Showing the list reads nothing from the node.
    expect((calls.quotes, calls.checks), (0, 0));
  });

  testWidgets('Check opens the dialog with the maximum, and a cancel reads nothing', (tester) async {
    final calls = _Calls();
    await _pump(tester, _api(calls, view: _view([_d(_ref)])));
    await tester.tap(find.byKey(Key('descendant-check-$_ref')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('descendant-check-dialog')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('descendant-check-max'))).controller!.text, '102');
    expect(calls.quotes, 1);
    expect(calls.checks, 0);
    await tester.tap(find.byKey(const Key('descendant-check-cancel')));
    await tester.pumpAndSettle();
    expect(calls.checks, 0);
    expect(find.byKey(const Key('descendant-check-dialog')), findsNothing);
  });

  testWidgets('a tap outside the dialog reads nothing', (tester) async {
    final calls = _Calls();
    await _pump(tester, _api(calls, view: _view([_d(_ref)])));
    await tester.tap(find.byKey(Key('descendant-check-$_ref')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(calls.checks, 0);
  });

  testWidgets('a confirm reads once, with the budget of the field', (tester) async {
    final calls = _Calls();
    await _pump(tester, _api(calls, view: _view([_d(_ref)])));
    await tester.tap(find.byKey(Key('descendant-check-$_ref')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('descendant-check-max')), '150');
    await tester.tap(find.byKey(const Key('descendant-check-confirm')));
    await tester.pumpAndSettle();
    expect(calls.checks, 1);
    expect(calls.lastBudget, '150');
  });

  testWidgets('an empty budget cannot be confirmed', (tester) async {
    final calls = _Calls();
    await _pump(tester, _api(calls, view: _view([_d(_ref)])));
    await tester.tap(find.byKey(Key('descendant-check-$_ref')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('descendant-check-max')), '');
    await tester.pump();
    final confirm = tester.widget<FilledButton>(find.byKey(const Key('descendant-check-confirm')));
    expect(confirm.onPressed, isNull);
    expect(calls.checks, 0);
  });

  testWidgets('each check asks again', (tester) async {
    final calls = _Calls();
    await _pump(tester, _api(calls, view: _view([_d(_ref)])));
    for (var i = 1; i <= 2; i++) {
      await tester.tap(find.byKey(Key('descendant-check-$_ref')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('descendant-check-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('descendant-check-confirm')));
      await tester.pumpAndSettle();
      expect(calls.checks, i);
    }
    expect(calls.quotes, 2);
  });

  testWidgets('a quote that fails opens no dialog and reads nothing', (tester) async {
    final calls = _Calls();
    final api = DescendantsApi(
      list: (_) => _view([_d(_ref)]),
      quote: (_, _) async => throw StateError('no rates'),
      check: (_, _, _) async {
        calls.checks++;
        throw StateError('must not run');
      },
      receipts: (_, _) => null,
    );
    await _pump(tester, api);
    await tester.tap(find.byKey(Key('descendant-check-$_ref')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('descendant-check-dialog')), findsNothing);
    expect(calls.checks, 0);
  });

  testWidgets('a death with MU left shows an alert on the row', (tester) async {
    await _pump(
      tester,
      _api(_Calls(), view: _view([_d(_ref, state: DescendantStateView.stopped, leftover: '40')])),
    );
    expect(find.byKey(Key('descendant-alert-$_ref')), findsOneWidget);
    // A stopped account has nothing to check.
    expect(find.byKey(Key('descendant-check-$_ref')), findsNothing);
  });

  testWidgets('a stop with no MU left shows no alert', (tester) async {
    await _pump(
      tester,
      _api(_Calls(), view: _view([_d(_ref, state: DescendantStateView.stopped, leftover: '0')])),
    );
    expect(find.byKey(Key('descendant-alert-$_ref')), findsNothing);
  });

  testWidgets('a check that finds a death with MU shows the alert dialog', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _api(
        calls,
        view: _view([_d(_ref)]),
        check: (_) async => CheckReportView(
          descendant: _d(_ref, state: DescendantStateView.stopped, leftover: '40'),
          newDescendants: const [],
          tooDeep: 0,
          tooMany: 0,
          findings: [
            DescendantFindingView(
              kind: DescendantFindingKind.stoppedWithMu,
              instanceRef: _ref,
              reason: 'out_of_balance',
              leftoverMu: '40',
              fatherGone: false,
              text: '',
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(Key('descendant-check-$_ref')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('descendant-check-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('descendant-findings')), findsOneWidget);
    expect(find.textContaining('40 MU'), findsWidgets);
  });

  testWidgets('Open goes through the tunnel only for an alive descendant with a web slot', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _api(
        calls,
        view: _view([
          _d(_ref, state: DescendantStateView.alive),
          _d(_ref2, state: DescendantStateView.notChecked),
        ]),
      ),
    );
    expect(find.byKey(Key('descendant-open-$_ref2')), findsNothing);
    await tester.tap(find.byKey(Key('descendant-open-$_ref')));
    await tester.pumpAndSettle();
    expect(calls.opens, 1);
  });

  testWidgets('Open does nothing when the service declares no page', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _api(
        calls,
        view: _view([_d(_ref, state: DescendantStateView.alive)]),
        slots: DescendantSlotsView(known: false, chatSlots: Uint16List(0), webSlots: Uint16List(0)),
      ),
    );
    await tester.tap(find.byKey(Key('descendant-open-$_ref')));
    await tester.pumpAndSettle();
    expect(calls.opens, 0);
  });

  testWidgets('descendant receipts show without Export', (tester) async {
    final api = DescendantsApi(
      list: (_) => _view([_d(_ref, state: DescendantStateView.alive)]),
      receipts: (_, _) => ReceiptsView(
        start: StartReceiptState.none,
        checkpoints: BigInt.from(2),
        streams: BigInt.one,
        droppedStreams: BigInt.zero,
        closed: BigInt.one,
        cancelled: BigInt.zero,
        noClose: BigInt.zero,
        faults: const [],
      ),
    );
    await _pump(tester, api);
    expect(find.byKey(const Key('info-receipts')), findsOneWidget);
    expect(find.byKey(const Key('info-receipts-export')), findsNothing);
  });
}
