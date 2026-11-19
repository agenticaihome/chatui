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

  for (final watchful in [true, false]) {
    testWidgets('a card fits a phone of 360 dp with large fonts (watchful: $watchful)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final skill = _skill(
        'ErgoScript Contract Audit with a long name',
        domain: 'blockchain-security',
        tags: ['ergoscript', 'smart-contract', 'static-analysis', 'audit'],
        prose: 'Compile ErgoScript to ErgoTree and statically audit it for risky patterns.',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: watchful),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [SkillCard(skill: skill, onTap: () {})]),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SkillMark), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      // The name and one line of text: no field and no tag on the card (they are in the
      // search and in the details of the skill).
      expect(find.text('blockchain-security'), findsNothing);
      expect(find.text('ergoscript'), findsNothing);
      final texts = tester.widgetList<Text>(find.descendant(of: find.byType(SkillCard), matching: find.byType(Text)));
      final lines = [for (final t in texts) if (t.data != 'E') t];
      expect(lines, hasLength(2));
      expect(lines.every((t) => t.maxLines == 1), isTrue);
    });
  }
}
