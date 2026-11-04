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

SkillView _skill(String name, {String domain = '', List<String> tags = const [], String prose = ''}) =>
    SkillView(boxId: 'box-$name', name: name, prose: prose, tags: tags, domain: domain);

void main() {
  test('the fields: the most used first, then by name, with no case and no empty field', () {
    final skills = [
      _skill('a', domain: 'nlp'),
      _skill('b', domain: 'Finance'),
      _skill('c', domain: 'finance '),
      _skill('d', domain: 'blockchain'),
      _skill('e'),
    ];
    expect(skillCategories(skills), [
      (key: 'finance', label: 'Finance'),
      (key: 'blockchain', label: 'blockchain'),
      (key: 'nlp', label: 'nlp'),
    ]);
  });

  test('the search looks in the name, the text, the tags and the field', () {
    final s = _skill('Proof of reserves', domain: 'finance', tags: ['merkle-sum'], prose: 'Solvency of an exchange.');
    for (final q in ['proof', 'solvency', 'merkle', 'finance', '']) {
      expect(skillMatches(s, q), isTrue, reason: q);
    }
    expect(skillMatches(s, 'chat'), isFalse);
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
      // Three tags at most; the field is not a tag again.
      expect(find.text('ergoscript'), findsOneWidget);
      expect(find.text('audit'), findsNothing);
    });
  }
}
