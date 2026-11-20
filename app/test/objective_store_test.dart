import 'dart:math' as math;

import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/objective_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

ObjectiveView _objective(
  String name, {
  String domain = '',
  List<String> tags = const [],
  String prose = '',
  int height = 0,
  List<String> services = const [],
  double reputation = 0,
}) => ObjectiveView(
  boxId: 'box-$name',
  name: name,
  prose: prose,
  tags: tags,
  domain: domain,
  height: height,
  serviceIds: services,
  publisherReputation: reputation,
);

void main() {
  test('the search looks in the name, the text, the tags and the field', () {
    final s = _objective('Proof of reserves', domain: 'finance', tags: ['merkle-sum'], prose: 'Solvency of an exchange.');
    for (final q in ['proof', 'solvency', 'merkle', 'finance', '']) {
      expect(objectiveMatches(s, q), isTrue, reason: q);
    }
    expect(objectiveMatches(s, 'chat'), isFalse);
  });

  group('the list of the store (#122)', () {
    final a = _objective('A', domain: 'finance', height: 10, services: ['s1', 's2'], reputation: 5);
    final b = _objective('B', domain: 'Finance', height: 30, services: ['s3'], reputation: 5);
    final c = _objective('C', domain: 'nlp', height: 20, services: ['s4', 's5', 's6'], reputation: 1);
    final d = _objective('D', domain: 'nlp', height: 40, services: const [], reputation: 9);
    final e = _objective('E', height: 0, services: ['s7'], reputation: 0);
    List<String> names(List<ObjectiveView> objectives) => [for (final s in objectives) s.name];

    test('the most backed first: reputation, then services, then the newest, then the name', () {
      expect(names(rankObjectives([a, b, c, d, e])), ['D', 'A', 'B', 'C', 'E']);
      final x = _objective('beta', height: 5, services: ['1'], reputation: 1);
      final y = _objective('Alpha', height: 5, services: ['2'], reputation: 1);
      expect(names(rankObjectives([x, y])), ['Alpha', 'beta']);
    });

    test('the groups are the fields, in the order of their first objective; no field is one group', () {
      final groups = objectiveGroups(rankObjectives([a, b, c, d, e]));
      expect([for (final g in groups) g.key], ['nlp', 'finance', '']);
      expect([for (final g in groups) g.title], ['nlp', 'finance', '']);
      expect([for (final g in groups) names(g.objectives)], [
        ['D', 'C'],
        ['A', 'B'],
        ['E'],
      ]);
    });

    test('the short list has $storeShortList objectives', () {
      expect(storeShortList, 6);
    });
  });

  test('a field gives one hue to all its objectives', () {
    final a = objectiveMarkColors(_objective('Alpha', domain: 'finance'), Brightness.dark);
    final b = objectiveMarkColors(_objective('Beta', domain: 'Finance'), Brightness.dark);
    expect(a, b);
  });

  for (final brightness in Brightness.values) {
    test('the letter of a mark meets 4.5:1 on its tile, in each hue ($brightness)', () {
      for (var i = 0; i < 64; i++) {
        final colors = objectiveMarkColors(_objective('objective $i', domain: 'field $i'), brightness);
        expect(_contrast(colors.letter, colors.tile), greaterThanOrEqualTo(4.5), reason: 'field $i');
      }
    });
  }

  for (final palette in allPalettes) {
    test('${palette.name}: the text of a card meets WCAG AA', () {
      final colors = ArgusColors.fromSpec(palette);
      final card = palette.surface;
      expect(_contrast(palette.ink, card), greaterThanOrEqualTo(4.5), reason: 'name');
      expect(_contrast(colors.muted, card), greaterThanOrEqualTo(4.5), reason: 'text');
      expect(_contrast(colors.accentText, card), greaterThanOrEqualTo(4.5), reason: 'field');
      expect(_contrast(palette.ink, colors.chip), greaterThanOrEqualTo(4.5), reason: 'tag');
    });
  }

  group('the shelves of the store home', () {
    List<String> names(List<ObjectiveView> objectives) => [for (final s in objectives) s.name];

    test('one shelf per field of two objectives or more; the fields of one objective share the last', () {
      final ranked = rankObjectives([
        _objective('Market', domain: 'finance', reputation: 9),
        _objective('SAT', domain: 'algorithms', reputation: 8),
        _objective('Reserves', domain: 'Finance', reputation: 7),
        _objective('Summary', domain: 'nlp', reputation: 6),
        _objective('Loose', reputation: 5),
      ]);
      final shelves = storeShelves(ranked);
      expect([for (final s in shelves) s.key], ['finance', mixedShelfKey]);
      expect(shelves.first.title, 'finance');
      expect(names(shelves.first.objectives), ['Market', 'Reserves']);
      // The mixed shelf keeps the ranking.
      expect(names(shelves.last.objectives), ['SAT', 'Summary', 'Loose']);
      // Every objective is on one shelf, once.
      expect(shelves.expand((s) => s.objectives).length, ranked.length);
    });

    test('with no field of two objectives, one shelf holds them all; with none at all, nothing', () {
      final ranked = rankObjectives([_objective('A', domain: 'x'), _objective('B', domain: 'y'), _objective('C')]);
      final shelves = storeShelves(ranked);
      expect([for (final s in shelves) s.key], [mixedShelfKey]);
      expect(names(shelves.single.objectives), names(ranked));
      expect(storeShelves(const []), isEmpty);
    });

    test('two objectives with no field are not a field shelf', () {
      final shelves = storeShelves([_objective('A'), _objective('B')]);
      expect([for (final s in shelves) s.key], [mixedShelfKey]);
    });
  });

  test('the backing of a publisher is in ERG, and left out when unknown', () {
    expect(objectiveBackingText(_objective('A', reputation: 96000000)), contains('0.096'));
    expect(objectiveBackingText(_objective('A', reputation: 96000000)), contains('ERG'));
    expect(objectiveBackingText(_objective('A')), isNull);
  });

  test('the heroes of one objective in two places of the store have two tags', () {
    final s = _objective('A');
    expect(objectiveHeroTag('top', s), isNot(objectiveHeroTag('featured', s)));
    expect(objectiveHeroTag('top', s), objectiveHeroTag('top', _objective('A')));
  });

  for (final watchful in [true, false]) {
    testWidgets('the cards of the store fit a phone of 360 dp with large fonts (watchful: $watchful)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final objective = _objective(
        'ErgoScript Contract Audit with a long name',
        domain: 'blockchain-security',
        tags: ['ergoscript', 'smart-contract', 'static-analysis', 'audit'],
        prose: 'Compile ErgoScript to ErgoTree and statically audit it for risky patterns.',
        services: ['s1', 's2'],
        reputation: 96000000,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: watchful),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ObjectiveFeatureCard(objective: objective, onTap: () {}, onRun: () {}),
                    SizedBox(height: 260, child: Row(children: [ObjectiveTile(objective: objective, showField: true, onTap: () {})])),
                    ObjectiveRow(objective: objective, rank: 12, showField: true, onTap: () {}, onRun: () {}),
                    ObjectiveRow(objective: objective, onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ObjectiveMark), findsNWidgets(4));
      // The rows: the name and one line, the field only when asked; no tag anywhere.
      expect(find.text('ergoscript'), findsNothing);
      expect(find.descendant(of: find.byType(ObjectiveRow).first, matching: find.text('BLOCKCHAIN-SECURITY')), findsOneWidget);
      expect(find.descendant(of: find.byType(ObjectiveRow).last, matching: find.text('BLOCKCHAIN-SECURITY')), findsNothing);
      expect(find.descendant(of: find.byType(ObjectiveRow).first, matching: find.text('12')), findsOneWidget);
      final rowTexts = tester.widgetList<Text>(find.descendant(of: find.byType(ObjectiveRow).last, matching: find.byType(Text)));
      expect([for (final t in rowTexts) if (t.data != 'E') t].every((t) => t.maxLines == 1), isTrue);
      // The featured card has the ring and the badge of the top objective.
      expect(find.descendant(of: find.byType(ObjectiveFeatureCard), matching: find.text('#1')), findsOneWidget);
    });
  }

  testWidgets('a Run pill says which objective it runs, and is off while busy', (tester) async {
    var runs = 0;
    final objective = _objective('Proof of reserves');
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: Scaffold(body: ObjectiveRow(objective: objective, onTap: () {}, onRun: () => runs++, runKey: const Key('pill'))),
      ),
    );
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Run Proof of reserves'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pill')));
    expect(runs, 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: Scaffold(body: ObjectiveRow(objective: objective, onTap: () {}, onRun: () => runs++, busy: true, runKey: const Key('pill'))),
      ),
    );
    await tester.tap(find.byKey(const Key('pill')), warnIfMissed: false);
    expect(runs, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    handle.dispose();
  });
}
