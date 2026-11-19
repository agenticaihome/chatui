import 'dart:math' as math;

import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/skill_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

SkillView _skill(
  String name, {
  String domain = '',
  List<String> tags = const [],
  String prose = '',
  int height = 0,
  List<String> services = const [],
  double reputation = 0,
}) => SkillView(
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
    final s = _skill('Proof of reserves', domain: 'finance', tags: ['merkle-sum'], prose: 'Solvency of an exchange.');
    for (final q in ['proof', 'solvency', 'merkle', 'finance', '']) {
      expect(skillMatches(s, q), isTrue, reason: q);
    }
    expect(skillMatches(s, 'chat'), isFalse);
  });

  group('the list of the store (#122)', () {
    final a = _skill('A', domain: 'finance', height: 10, services: ['s1', 's2'], reputation: 5);
    final b = _skill('B', domain: 'Finance', height: 30, services: ['s3'], reputation: 5);
    final c = _skill('C', domain: 'nlp', height: 20, services: ['s4', 's5', 's6'], reputation: 1);
    final d = _skill('D', domain: 'nlp', height: 40, services: const [], reputation: 9);
    final e = _skill('E', height: 0, services: ['s7'], reputation: 0);
    List<String> names(List<SkillView> skills) => [for (final s in skills) s.name];

    test('the most backed first: reputation, then services, then the newest, then the name', () {
      expect(names(rankSkills([a, b, c, d, e])), ['D', 'A', 'B', 'C', 'E']);
      final x = _skill('beta', height: 5, services: ['1'], reputation: 1);
      final y = _skill('Alpha', height: 5, services: ['2'], reputation: 1);
      expect(names(rankSkills([x, y])), ['Alpha', 'beta']);
    });

    test('the groups are the fields, in the order of their first skill; no field is one group', () {
      final groups = skillGroups(rankSkills([a, b, c, d, e]));
      expect([for (final g in groups) g.key], ['nlp', 'finance', '']);
      expect([for (final g in groups) g.title], ['nlp', 'finance', '']);
      expect([for (final g in groups) names(g.skills)], [
        ['D', 'C'],
        ['A', 'B'],
        ['E'],
      ]);
    });

    test('the short list has $storeShortList skills', () {
      expect(storeShortList, 6);
    });
  });

  test('a field gives one hue to all its skills', () {
    final a = skillMarkColors(_skill('Alpha', domain: 'finance'), Brightness.dark);
    final b = skillMarkColors(_skill('Beta', domain: 'Finance'), Brightness.dark);
    expect(a, b);
  });

  for (final brightness in Brightness.values) {
    test('the letter of a mark meets 4.5:1 on its tile, in each hue ($brightness)', () {
      for (var i = 0; i < 64; i++) {
        final colors = skillMarkColors(_skill('skill $i', domain: 'field $i'), brightness);
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
    List<String> names(List<SkillView> skills) => [for (final s in skills) s.name];

    test('one shelf per field of two skills or more; the fields of one skill share the last', () {
      final ranked = rankSkills([
        _skill('Market', domain: 'finance', reputation: 9),
        _skill('SAT', domain: 'algorithms', reputation: 8),
        _skill('Reserves', domain: 'Finance', reputation: 7),
        _skill('Summary', domain: 'nlp', reputation: 6),
        _skill('Loose', reputation: 5),
      ]);
      final shelves = storeShelves(ranked);
      expect([for (final s in shelves) s.key], ['finance', mixedShelfKey]);
      expect(shelves.first.title, 'finance');
      expect(names(shelves.first.skills), ['Market', 'Reserves']);
      // The mixed shelf keeps the ranking.
      expect(names(shelves.last.skills), ['SAT', 'Summary', 'Loose']);
      // Every skill is on one shelf, once.
      expect(shelves.expand((s) => s.skills).length, ranked.length);
    });

    test('with no field of two skills, one shelf holds them all; with none at all, nothing', () {
      final ranked = rankSkills([_skill('A', domain: 'x'), _skill('B', domain: 'y'), _skill('C')]);
      final shelves = storeShelves(ranked);
      expect([for (final s in shelves) s.key], [mixedShelfKey]);
      expect(names(shelves.single.skills), names(ranked));
      expect(storeShelves(const []), isEmpty);
    });

    test('two skills with no field are not a field shelf', () {
      final shelves = storeShelves([_skill('A'), _skill('B')]);
      expect([for (final s in shelves) s.key], [mixedShelfKey]);
    });
  });

  test('the backing of a publisher is in ERG, and left out when unknown', () {
    expect(skillBackingText(_skill('A', reputation: 96000000)), contains('0.096'));
    expect(skillBackingText(_skill('A', reputation: 96000000)), contains('ERG'));
    expect(skillBackingText(_skill('A')), isNull);
  });

  test('the heroes of one skill in two places of the store have two tags', () {
    final s = _skill('A');
    expect(skillHeroTag('top', s), isNot(skillHeroTag('featured', s)));
    expect(skillHeroTag('top', s), skillHeroTag('top', _skill('A')));
  });

  for (final watchful in [true, false]) {
    testWidgets('the cards of the store fit a phone of 360 dp with large fonts (watchful: $watchful)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final skill = _skill(
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
                    SkillFeatureCard(skill: skill, onTap: () {}, onRun: () {}),
                    SizedBox(height: 260, child: Row(children: [SkillTile(skill: skill, showField: true, onTap: () {})])),
                    SkillRow(skill: skill, rank: 12, showField: true, onTap: () {}, onRun: () {}),
                    SkillRow(skill: skill, onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SkillMark), findsNWidgets(4));
      // The rows: the name and one line, the field only when asked; no tag anywhere.
      expect(find.text('ergoscript'), findsNothing);
      expect(find.descendant(of: find.byType(SkillRow).first, matching: find.text('BLOCKCHAIN-SECURITY')), findsOneWidget);
      expect(find.descendant(of: find.byType(SkillRow).last, matching: find.text('BLOCKCHAIN-SECURITY')), findsNothing);
      expect(find.descendant(of: find.byType(SkillRow).first, matching: find.text('12')), findsOneWidget);
      final rowTexts = tester.widgetList<Text>(find.descendant(of: find.byType(SkillRow).last, matching: find.byType(Text)));
      expect([for (final t in rowTexts) if (t.data != 'E') t].every((t) => t.maxLines == 1), isTrue);
      // The featured card has the ring and the badge of the top skill.
      expect(find.descendant(of: find.byType(SkillFeatureCard), matching: find.text('#1')), findsOneWidget);
    });
  }

  testWidgets('a Run pill says which skill it runs, and is off while busy', (tester) async {
    var runs = 0;
    final skill = _skill('Proof of reserves');
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: Scaffold(body: SkillRow(skill: skill, onTap: () {}, onRun: () => runs++, runKey: const Key('pill'))),
      ),
    );
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Run Proof of reserves'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pill')));
    expect(runs, 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: Scaffold(body: SkillRow(skill: skill, onTap: () {}, onRun: () => runs++, busy: true, runKey: const Key('pill'))),
      ),
    );
    await tester.tap(find.byKey(const Key('pill')), warnIfMissed: false);
    expect(runs, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    handle.dispose();
  });
}
