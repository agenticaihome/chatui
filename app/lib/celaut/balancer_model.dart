import 'dart:math' as math;

import '../bridge/api/celaut_home.dart';

/// The pure logic behind the balancer screen (`docs/celaut/balancer.md`, "Weights of the
/// score"). It mirrors `celaut_balancer::score_with`, so the example on the screen orders
/// nodes the way the real balancer will.

/// The most that a weight can be (`celaut_balancer::WEIGHT_MAX`).
const double balancerWeightMax = 10;

/// The score of a node with a price of `cost` (any positive unit: only the ratio between
/// nodes matters) and a user priority of `priority` (0 to 100). The terms that have no
/// data yet (local and on-chain reputation, donations) are 0, as in the real balancer.
double balancerScore(BalancerWeightsView w, {required double cost, required int priority}) {
  if (cost <= 0) return double.infinity;
  return -w.price * math.log(cost) + w.priority * (priority.clamp(0, 100) - 50) / 50;
}

/// How many times cheaper than a node of full trust (priority 100) another node of neutral
/// priority (50) can be and still lose: `e^(W_priority / W_price)`. `null` when the answer
/// is not a number: the price weight is 0, so the price is ignored. A very large number
/// is returned as is; show it with [factorText].
double? trustedAdvantage(BalancerWeightsView w) {
  if (w.price <= 0) return null;
  return math.exp(w.priority / w.price);
}

/// A factor as text: "7.4", "120", or "1000+" above a thousand.
String factorText(double factor) {
  if (factor >= 1000) return '1000+';
  if (factor >= 100) return factor.round().toString();
  return factor.toStringAsFixed(1);
}

/// What the screen says about the balance of price and priority.
enum BalancerReading { nothingCounts, priceIgnored, priorityIgnored, tradeoff }

BalancerReading readingOf(BalancerWeightsView w) {
  if (w.price <= 0 && w.priority <= 0) return BalancerReading.nothingCounts;
  if (w.price <= 0) return BalancerReading.priceIgnored;
  if (w.priority <= 0) return BalancerReading.priorityIgnored;
  return BalancerReading.tradeoff;
}

/// One of the example nodes of the screen.
class ExampleNode {
  const ExampleNode(this.id, this.cost, this.priority);
  final String id;

  /// The price, relative to the cheap node.
  final double cost;
  final int priority;
}

/// Three nodes that show the trade-off: the cheapest has the lowest trust, the most
/// expensive is the one that the user fully trusts.
const exampleNodes = <ExampleNode>[
  ExampleNode('cheap', 1, 50),
  ExampleNode('trusted', 3, 100),
  ExampleNode('risky', 0.5, 0),
];

/// The example nodes, best first, with their scores. A tie keeps the order of the list.
List<(ExampleNode, double)> rankExamples(BalancerWeightsView w) {
  final scored = [for (final n in exampleNodes) (n, balancerScore(w, cost: n.cost, priority: n.priority))];
  final indexed = scored.asMap().entries.toList()
    ..sort((a, b) {
      final c = b.value.$2.compareTo(a.value.$2);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// A quick setup of the weights.
enum BalancerPreset { balanced, cheapest, trusted }

BalancerWeightsView presetWeights(BalancerPreset p, BalancerWeightsView defaults) => switch (p) {
  BalancerPreset.balanced => defaults,
  // Only the price counts: the cheapest node always goes first.
  BalancerPreset.cheapest => const BalancerWeightsView(price: 1, reputation: 0, onchain: 0, donation: 0, priority: 0),
  // The priority of the user counts three times more than in the defaults: a node of full
  // trust beats one up to e^6 (about 400) times cheaper.
  BalancerPreset.trusted => BalancerWeightsView(
    price: defaults.price,
    reputation: defaults.reputation,
    onchain: defaults.onchain,
    donation: defaults.donation,
    priority: defaults.priority * 3,
  ),
};

/// The preset that the weights are, or `null` if they are a custom mix.
BalancerPreset? presetOf(BalancerWeightsView w, BalancerWeightsView defaults) {
  bool same(BalancerWeightsView a, BalancerWeightsView b) =>
      (a.price - b.price).abs() < 0.05 &&
      (a.reputation - b.reputation).abs() < 0.05 &&
      (a.onchain - b.onchain).abs() < 0.05 &&
      (a.donation - b.donation).abs() < 0.05 &&
      (a.priority - b.priority).abs() < 0.05;
  for (final p in BalancerPreset.values) {
    if (same(w, presetWeights(p, defaults))) return p;
  }
  return null;
}
