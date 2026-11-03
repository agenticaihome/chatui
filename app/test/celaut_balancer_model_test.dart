import 'dart:math' as math;

import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/celaut/balancer_model.dart';
import 'package:flutter_test/flutter_test.dart';

const d = BalancerWeightsView(price: 1, reputation: 2, onchain: 0.3, donation: 0.3, priority: 2);

BalancerWeightsView w({double price = 1, double priority = 2}) =>
    BalancerWeightsView(price: price, reputation: d.reputation, onchain: d.onchain, donation: d.donation, priority: priority);

void main() {
  test('the score is the one of the balancer: -W_price ln(cost) + W_priority (p-50)/50', () {
    expect(balancerScore(d, cost: math.e, priority: 50), closeTo(-1, 1e-12));
    expect(balancerScore(d, cost: 1, priority: 100), closeTo(2, 1e-12));
    expect(balancerScore(d, cost: 1, priority: 0), closeTo(-2, 1e-12));
    expect(balancerScore(w(price: 0), cost: 1000, priority: 50), 0);
  });

  test('a node of full trust beats one e^(W_priority/W_price) times cheaper', () {
    final f = trustedAdvantage(d)!;
    expect(f, closeTo(math.exp(2), 1e-9)); // about 7.4
    // At the limit, a neutral node at price 1 and a trusted one at price f tie.
    expect(balancerScore(d, cost: f, priority: 100), closeTo(balancerScore(d, cost: 1, priority: 50), 1e-9));
    expect(trustedAdvantage(w(price: 0)), isNull);
    expect(factorText(7.389), '7.4');
    expect(factorText(403.4), '403');
    expect(factorText(5000), '1000+');
  });

  test('the reading says what the two weights do', () {
    expect(readingOf(d), BalancerReading.tradeoff);
    expect(readingOf(w(price: 0)), BalancerReading.priceIgnored);
    expect(readingOf(w(priority: 0)), BalancerReading.priorityIgnored);
    expect(readingOf(w(price: 0, priority: 0)), BalancerReading.nothingCounts);
  });

  List<String> order(BalancerWeightsView x) => [for (final r in rankExamples(x)) r.$1.id];

  test('the example orders the nodes as the weights say', () {
    // Default: the trusted node is first even if it costs 3 times more; the cheapest, with
    // no trust, is last.
    expect(order(d), ['trusted', 'cheap', 'risky']);
    // Only the price: the cheapest wins.
    expect(order(w(priority: 0)), ['risky', 'cheap', 'trusted']);
    // Only the priority: the trusted node, then neutral, then none.
    expect(order(w(price: 0)), ['trusted', 'cheap', 'risky']);
    // Nothing counts: a tie keeps the order of the list.
    expect(order(w(price: 0, priority: 0)), ['cheap', 'trusted', 'risky']);
  });

  test('presets are recognised, and a custom mix is not a preset', () {
    for (final p in BalancerPreset.values) {
      expect(presetOf(presetWeights(p, d), d), p);
    }
    expect(presetWeights(BalancerPreset.trusted, d).priority, 6);
    expect(presetOf(w(price: 3.3), d), isNull);
  });
}
