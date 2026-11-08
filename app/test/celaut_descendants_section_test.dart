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
  bool relayed = false,
  bool unreadRows = false,
}) => DescendantView(
  instanceRef: ref,
  serviceId: service,
  depth: depth,
  state: state,
  lastCheckedAt: checked,
  stopReason: leftover == null ? null : 'out_of_balance',
  leftoverMu: leftover,
  fatherGone: false,
  relayed: relayed,
  unreadRows: unreadRows,
);

class _Calls {
  int quotes = 0;
  int checks = 0;
  String? lastBudget;
  int opens = 0;
  int tunnelQuotes = 0;
  String? openBudget;
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
  quoteTunnel: (id, ref) async {
    calls.tunnelQuotes++;
    return TunnelQuoteView(
      instanceRef: ref,
      node: 'node.example:1',
      remainingHops: 2,
      openMu: '10000',
      maxMuPerStream: '20000',
    );
  },
  openTunnel: (_, _, _, budget) async {
    calls.opens++;
    calls.openBudget = budget;
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
    // The dialog comes first: nothing opened yet.
    expect(find.byKey(const Key('descendant-open-dialog')), findsOneWidget);
    expect(calls.opens, 0);
    await tester.tap(find.byKey(const Key('descendant-open-confirm')));
    await tester.pumpAndSettle();
    expect(calls.opens, 1);
    expect(calls.openBudget, '20000');
  });

  testWidgets('Open shows the cost of one stream, and a cancel opens nothing', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _api(calls, view: _view([_d(_ref, state: DescendantStateView.alive)])),
    );
    await tester.tap(find.byKey(Key('descendant-open-$_ref')));
    await tester.pumpAndSettle();
    expect(calls.tunnelQuotes, 1);
    expect(tester.widget<TextField>(find.byKey(const Key('descendant-open-max'))).controller!.text, '20000');
    expect(find.textContaining('20000 MU'), findsWidgets);
    await tester.tap(find.byKey(const Key('descendant-open-cancel')));
    await tester.pumpAndSettle();
    expect(calls.opens, 0);
    // A tap outside the dialog opens nothing either.
    await tester.tap(find.byKey(Key('descendant-open-$_ref')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(calls.opens, 0);
  });

  testWidgets('a budget that pays for no stream cannot be confirmed, and the field is used', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _api(calls, view: _view([_d(_ref, state: DescendantStateView.alive)])),
    );
    await tester.tap(find.byKey(Key('descendant-open-$_ref')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('descendant-open-max')), '19999');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('descendant-open-confirm'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('descendant-open-max')), '60000');
    await tester.pump();
    final l = AppLocalizations.of(tester.element(find.byKey(const Key('descendant-open-dialog'))));
    expect(find.text(l.descendantsOpenStreams('3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('descendant-open-confirm')));
    await tester.pumpAndSettle();
    expect((calls.opens, calls.openBudget), (1, '60000'));
  });

  testWidgets('each Open asks again', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _api(calls, view: _view([_d(_ref, state: DescendantStateView.alive)])),
    );
    for (var i = 1; i <= 2; i++) {
      await tester.tap(find.byKey(Key('descendant-open-$_ref')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('descendant-open-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('descendant-open-confirm')));
      await tester.pumpAndSettle();
      expect(calls.opens, i);
    }
    expect(calls.tunnelQuotes, 2);
  });

  testWidgets('a tunnel quote that fails opens no dialog and no port', (tester) async {
    final calls = _Calls();
    final api = DescendantsApi(
      list: (_) => _view([_d(_ref, state: DescendantStateView.alive)]),
      receipts: (_, _) => null,
      slots: (_, _) async =>
          DescendantSlotsView(known: true, chatSlots: Uint16List(0), webSlots: Uint16List.fromList([80])),
      quoteTunnel: (_, _) async => throw StateError('no rates'),
      openTunnel: (_, _, _, _) async {
        calls.opens++;
        return 1;
      },
    );
    await _pump(tester, api);
    await tester.tap(find.byKey(Key('descendant-open-$_ref')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('descendant-open-dialog')), findsNothing);
    expect(calls.opens, 0);
  });

  testWidgets('a relayed statement is shown as relayed, and a direct one is not', (tester) async {
    await _pump(
      tester,
      _api(
        _Calls(),
        view: _view([
          _d(_ref, state: DescendantStateView.alive, relayed: true),
          _d(_ref2, depth: 2, state: DescendantStateView.alive),
        ]),
      ),
    );
    final l = AppLocalizations.of(tester.element(find.byKey(const Key('info-descendants'))));
    expect(find.byKey(Key('descendant-relayed-$_ref')), findsOneWidget);
    expect(find.byKey(Key('descendant-relayed-$_ref2')), findsNothing);
    expect(find.text(l.descendantsRelayed), findsOneWidget);
  });

  testWidgets('a check that did not reach the end is not shown as alive without a note', (tester) async {
    await _pump(
      tester,
      _api(
        _Calls(),
        view: _view([_d(_ref, state: DescendantStateView.notChecked, unreadRows: true, checked: 1700000000)]),
      ),
    );
    final l = AppLocalizations.of(tester.element(find.byKey(const Key('info-descendants'))));
    expect(find.byKey(Key('descendant-unread-$_ref')), findsOneWidget);
    expect(find.text(l.descendantsUnreadRows), findsOneWidget);
    expect(find.text(l.descendantsStateAlive), findsNothing);
    // It can be checked again, and it cannot be opened.
    expect(find.byKey(Key('descendant-check-$_ref')), findsOneWidget);
    expect(find.byKey(Key('descendant-open-$_ref')), findsNothing);
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
