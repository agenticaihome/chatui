import 'dart:convert';
import 'dart:io';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/closing.dart';
import 'package:argus_wallet/celaut/launch_problems.dart';
import 'package:argus_wallet/celaut/launcher.dart';
import 'package:argus_wallet/celaut/maintenance_price.dart';
import 'package:argus_wallet/ui/celaut/closing_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The activity window of nodo#344 and the funding sum of nodo#636 (chatui#129).

QuoteView _quote({
  String cost = '500',
  String init = '1000',
  int loop = 60,
  String credit = '',
  int closesAt = 0,
  OnCloseView onClose = OnCloseView.refuse,
}) =>
    QuoteView(
      address: const NodeAddress(host: 'node.example', port: 1),
      peerId: 'p',
      costMu: cost,
      initMaintenanceMu: init,
      maxMaintenanceMu: init,
      maintenanceSecondsLoop: loop,
      priceBounded: true,
      priceVolatility: 0.1,
      volatilityPeriodSeconds: 3600,
      closesAt: closesAt,
      onClose: onClose,
      clientBalanceMu: credit,
    );

void main() {
  group('the funding sum against the nodo code', () {
    // The vectors of celaut-balancer, made with nodo's price_bound.funding_sum_mu
    // (rust/crates/celaut-balancer/tests/vectors/generate.py).
    final vectors = jsonDecode(
      File('../rust/crates/celaut-balancer/tests/vectors/funding.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('MaintenancePrice sums n periods as nodo does', () {
      var checked = 0;
      for (final c in (vectors['funding'] as List).cast<Map<String, dynamic>>()) {
        final n = c['n'] as int;
        final price = MaintenancePrice.of(
          perPeriodMu: '${c['init']}',
          periodSeconds: c['loop'] as int,
          volatility: (c['v'] as num).toDouble(),
          volatilityPeriodSeconds: c['T'] as int,
        );
        if (price == null || n == 0) continue;
        // balanceFor(time) funds the periods in time plus one: n - 1 periods of time.
        final ours = price.balanceFor(Duration(seconds: (n - 1) * (c['loop'] as int)));
        final nodo = c['sum'] == null ? null : BigInt.parse(c['sum'] as String);
        if (nodo == null) {
          expect(ours, isNull, reason: '$c');
        } else if (nodo < BigInt.from(1) << 53) {
          expect(ours, nodo, reason: '$c');
        } else {
          final diff = (ours! - nodo).abs().toDouble();
          expect(diff <= nodo.toDouble() * 1e-12, isTrue, reason: '$c: $ours');
        }
        checked++;
      }
      expect(checked, greaterThanOrEqualTo(10));
    });
  });

  group('closing', () {
    final now = DateTime(2026, 11, 10, 12);
    int unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

    test('a close touches an instance only with STOP or HIBERNATE', () {
      final at = unix(now.add(const Duration(hours: 1)));
      expect(closingTime(at, OnCloseView.refuse), isNull);
      expect(closingTime(0, OnCloseView.stop), isNull);
      expect(closingTime(at, OnCloseView.stop), now.add(const Duration(hours: 1)));
      expect(closingTime(at, OnCloseView.hibernate), now.add(const Duration(hours: 1)));
    });

    test('closesBefore compares the close with the life of the instance', () {
      final at = unix(now.add(const Duration(hours: 1)));
      expect(closesBefore(at, const Duration(minutes: 30), now), isFalse);
      expect(closesBefore(at, const Duration(hours: 2), now), isTrue);
      // Until the user stops it: every close comes before.
      expect(closesBefore(at, null, now), isTrue);
    });

    test('openingTime is null when the app does not know it', () {
      expect(openingTime(0), isNull);
      expect(openingTime(unix(now)), now);
    });
  });

  group('wouldAskToStart with the balance of the node', () {
    test('it needs the cost plus one maintenance period', () {
      // cost 500 + ceil(1000 * 1.1) = 1600: the least start of a node (nodo#636).
      expect(wouldAskToStart(_quote(credit: '1599')), isFalse);
      expect(wouldAskToStart(_quote(credit: '1600')), isTrue);
      // A quote with no maintenance price: the cost alone.
      expect(wouldAskToStart(_quote(init: '0', credit: '500')), isTrue);
      // A start balance that the app chose wins.
      expect(wouldAskToStart(_quote(credit: '1600'), startMu: BigInt.from(1601)), isFalse);
      // An unknown credit never stops a start.
      expect(wouldAskToStart(_quote()), isTrue);
    });
  });

  group('a closed node says when it opens', () {
    const node = NodeAddress(host: 'node.example', port: 1);
    test('problemsOf carries opens_at of a quote failure and of a refused start', () {
      final failure = LaunchFailure(
        LaunchFailureKind.allFailed,
        quoteFailures: const [
          QuoteFailureView(address: node, kind: CelautErrorKind.nodeClosed, message: '', opensAt: 1800000000),
          QuoteFailureView(address: node, kind: CelautErrorKind.timeout, message: '', opensAt: 1800000000),
        ],
        skipped: [
          LaunchSkip(_quote(), const CelautError(kind: CelautErrorKind.nodeClosed, message: 'closed'), opensAt: 1800003600),
          LaunchSkip(_quote(), const CelautError(kind: CelautErrorKind.noRoom, message: 'full')),
        ],
      );
      final problems = problemsOf(failure);
      expect(problems.map((p) => p.opensAt), [1800000000, 0, 1800003600, 0]);
    });

    test('a start that a closed node refuses reads when it opens; a failure of that is 0', () async {
      Future<LaunchOutcome> launch(OpensAtCall opensAt) => launchService(
            serviceIdHex: 'ab' * 32,
            nodes: const [node],
            health: () => const [],
            quote: ({required nodes, required serviceIdHex, initialMu}) async =>
                QuotesView(quotes: [_quote()], failures: const []),
            start: ({required node, required serviceIdHex, initialMu, required environment}) async =>
                throw const CelautError(kind: CelautErrorKind.nodeClosed, message: 'outside its activity window'),
            opensAt: opensAt,
          );
      Future<int> opensOf(OpensAtCall opensAt) async {
        try {
          await launch(opensAt);
        } on LaunchFailure catch (f) {
          return f.skipped.single.opensAt;
        }
        fail('the launch must fail');
      }
      expect(await opensOf(({required node}) async => 1800007200), 1800007200);
      expect(await opensOf(({required node}) async => throw StateError('no bridge')), 0);
    });
  });

  group('texts', () {
    Future<BuildContext> contextOf(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        captured = c;
        return const SizedBox();
      })));
      return captured;
    }

    testWidgets('the notes name the time and what the node does', (tester) async {
      final context = await contextOf(tester);
      final now = DateTime(2026, 11, 10, 12);
      final later = now.add(const Duration(hours: 3));
      final at = later.millisecondsSinceEpoch ~/ 1000;
      expect(closingNote(context, at, OnCloseView.refuse, now: now), isNull);
      expect(closingNote(context, at, OnCloseView.stop, now: now), contains('stops the instance'));
      expect(closingNote(context, at, OnCloseView.hibernate, now: now), contains('hibernates'));
      expect(closingNote(context, at, OnCloseView.stop, now: now), contains('3:00'));
      expect(keepStopNote(context, at, OnCloseView.hibernate, now: now), isNull);
      expect(keepStopNote(context, at, OnCloseView.stop, now: now), contains('Keep running'));
      // A close in the past says nothing more.
      expect(keepStopNote(context, at, OnCloseView.stop, now: later.add(const Duration(minutes: 1))), isNull);
      expect(openingNote(context, 0), isNull);
      expect(openingNote(context, at, now: now), contains('opens again'));
      // Another day: the day is in the text too.
      expect(clockText(context, later.add(const Duration(days: 1)), now: now), contains('Nov'));
    });
  });
}
