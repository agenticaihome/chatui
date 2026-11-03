import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/balancer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _defaults = BalancerWeightsView(price: 1, reputation: 2, onchain: 0.3, donation: 0.3, priority: 2);

class _Store implements BalancerWeights {
  BalancerWeightsView now = _defaults;
  final saved = <BalancerWeightsView>[];

  @override
  BalancerWeightsView current() => now;

  @override
  BalancerWeightsView defaults() => _defaults;

  @override
  void save(BalancerWeightsView weights) {
    saved.add(weights);
    now = weights;
  }
}

Future<void> _open(WidgetTester tester, _Store store) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: BalancerScreen(weights: store)));
  await tester.pumpAndSettle();
}

Finder _slider(String term) =>
    find.descendant(of: find.byKey(Key('balancer-term-$term')), matching: find.byType(Slider));

void main() {
  testWidgets('shows the two main weights, the sentence and the example', (tester) async {
    await _open(tester, _Store());
    expect(find.text(appL10n.balancerPriceName), findsOneWidget);
    expect(find.text(appL10n.balancerPriorityName), findsOneWidget);
    expect(find.text(appL10n.balancerReadingTradeoff('7.4')), findsOneWidget);
    expect(find.text(appL10n.balancerExampleFirst(appL10n.balancerExampleTrusted)), findsOneWidget);
    // The balanced setup is the selected one; nothing to restore.
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('balancer-preset-balanced'))).selected, isTrue);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('balancer-reset'))).onPressed, isNull);
  });

  testWidgets('the terms without data are in a closed section', (tester) async {
    await _open(tester, _Store());
    expect(find.byKey(const Key('balancer-term-reputation')), findsNothing);
    await tester.tap(find.byKey(const Key('balancer-advanced')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('balancer-term-reputation')), findsOneWidget);
    expect(find.byKey(const Key('balancer-term-onchain')), findsOneWidget);
    expect(find.byKey(const Key('balancer-term-donation')), findsOneWidget);
  });

  testWidgets('a quick setup saves its weights and changes the example', (tester) async {
    final store = _Store();
    await _open(tester, store);
    await tester.tap(find.byKey(const Key('balancer-preset-cheapest')));
    await tester.pumpAndSettle();
    expect(store.saved.single.priority, 0);
    expect(store.saved.single.price, 1);
    expect(find.text(appL10n.balancerExampleFirst(appL10n.balancerExampleRisky)), findsOneWidget);
    expect(find.text(appL10n.balancerReadingPriorityIgnored), findsOneWidget);

    await tester.tap(find.byKey(const Key('balancer-preset-trusted')));
    await tester.pumpAndSettle();
    expect(store.saved.last.priority, 6);
    expect(find.text(appL10n.balancerReadingTradeoff('403')), findsOneWidget);
  });

  testWidgets('a slider saves when the finger lifts; the example moves while it is dragged', (tester) async {
    final store = _Store();
    await _open(tester, store);
    await tester.drag(_slider('price'), const Offset(-2000, 0)); // price to 0
    await tester.pumpAndSettle();
    expect(store.saved, hasLength(1));
    expect(store.saved.single.price, 0);
    expect(store.saved.single.priority, 2); // the others stay
    expect(find.text(appL10n.balancerOffLabel), findsOneWidget);
    expect(find.text(appL10n.balancerReadingPriceIgnored), findsOneWidget);
    // A mix that is no setup shows as custom.
    expect(find.byKey(const Key('balancer-preset-custom')), findsOneWidget);

    await tester.tap(find.byKey(const Key('balancer-reset')));
    await tester.pumpAndSettle();
    expect(store.now, _defaults);
    expect(find.text(appL10n.balancerOffLabel), findsNothing);
  });

  testWidgets('a term can be restored by itself', (tester) async {
    final store = _Store();
    await _open(tester, store);
    expect(find.byKey(const Key('balancer-restore-term')), findsNothing);
    await tester.drag(_slider('priority'), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('balancer-restore-term')));
    await tester.pumpAndSettle();
    expect(store.now.priority, 2);
  });
}
