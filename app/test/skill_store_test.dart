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

  group('the sections of the store', () {
    final a = _skill('A', domain: 'finance', height: 10, services: ['s1', 's2'], reputation: 5);
    final b = _skill('B', domain: 'Finance', height: 30, services: ['s3'], reputation: 5);
    final c = _skill('C', domain: 'nlp', height: 20, services: ['s4', 's5', 's6'], reputation: 1);
    final d = _skill('D', domain: 'nlp', height: 40, services: const [], reputation: 9);
    final e = _skill('E', domain: 'chat', height: 0, services: ['s7'], reputation: 0);
    final all = [a, b, c, d, e];
    List<String> names(List<SkillView> skills) => [for (final s in skills) s.name];

    test('featured: the most backed skill of each field, with a service', () {
      // finance: A (5, 2 services) over B (5, 1); nlp: C, as D has no service; chat: E.
      expect(names(featuredSkills(all)), ['A', 'C', 'E']);
      expect(featuredSkills([d]), isEmpty);
    });

    test('featured: at most $featuredSize, and the skills with no field are one field', () {
      final many = [
        for (var i = 0; i < 9; i++) _skill('F$i', domain: 'f$i', services: ['x$i'], reputation: i.toDouble()),
        _skill('N1', services: ['n1'], reputation: 100),
        _skill('N2', services: ['n2'], reputation: 99),
      ];
      expect(names(featuredSkills(many)), ['N1', 'F8', 'F7', 'F6', 'F5']);
    });

    test('new: the highest block first; a skill with no height is not there', () {
      expect(names(newSkills(all)), ['D', 'B', 'C', 'A']);
    });

    test('popular: the most services first, then the backing; no skill with no service', () {
      expect(names(popularSkills(all)), ['C', 'A', 'B', 'E']);
    });

    test('the order of a tie is the name, on every phone', () {
      final x = _skill('beta', domain: 'z', height: 5, services: ['1'], reputation: 1);
      final y = _skill('Alpha', domain: 'y', height: 5, services: ['2'], reputation: 1);
      expect(names(newSkills([x, y])), ['Alpha', 'beta']);
      expect(names(popularSkills([x, y])), ['Alpha', 'beta']);
      expect(names(featuredSkills([x, y])), ['Alpha', 'beta']);
    });

    test('the rows have at most $storeRowSize skills', () {
      final many = [for (var i = 0; i < 20; i++) _skill('S$i', domain: 'd', height: i + 1, services: ['s$i'])];
      expect(newSkills(many), hasLength(storeRowSize));
      expect(popularSkills(many), hasLength(storeRowSize));
      expect(suggestedSkills(many, [(serviceId: 's0', name: '')]), hasLength(storeRowSize));
    });

    test('a skill was run if an instance has one of its services or its name', () {
      expect(skillWasRun(a, [(serviceId: 'S2', name: '')]), isTrue);
      expect(skillWasRun(a, [(serviceId: 'zz', name: ' a ')]), isTrue);
      expect(skillWasRun(a, [(serviceId: 's3', name: 'B')]), isFalse);
      expect(skillWasRun(_skill(''), [(serviceId: 'zz', name: '')]), isFalse);
    });

    test('suggested: the other skills of the fields that the user ran, the most backed first', () {
      expect(suggestedSkills(all, const []), isEmpty);
      // Ran A (finance): B. Ran C (nlp): D, which has no service but is in the field.
      expect(names(suggestedSkills(all, [(serviceId: 's1', name: '')])), ['B']);
      expect(names(suggestedSkills(all, [(serviceId: 's1', name: ''), (serviceId: 's5', name: '')])), ['D', 'B']);
      // A service that is no skill's: no suggestion.
      expect(suggestedSkills(all, [(serviceId: 'other', name: 'echo')]), isEmpty);
      // A skill with no field gives no suggestion.
      final lone = _skill('L', services: ['l1']);
      expect(suggestedSkills([lone, _skill('M')], [(serviceId: 'l1', name: '')]), isEmpty);
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
      // Three tags at most; the field is not a tag again.
      expect(find.text('ergoscript'), findsOneWidget);
      expect(find.text('audit'), findsNothing);
    });
  }
}
