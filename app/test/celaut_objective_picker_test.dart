import 'dart:async';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/celaut/service_strings.dart';
import 'package:argus_wallet/l10n/app_localizations.dart';
import 'package:argus_wallet/ui/celaut/skill_picker.dart';
import 'package:argus_wallet/ui/celaut/skill_service_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _best = 'aa' * 32;
final _other = 'bb' * 32;
final _found = 'cc' * 32;

const _sat = SkillView(
  boxId: 'skill-sat',
  name: 'Boolean SAT Solver',
  prose: 'Decides if a formula can be satisfied.',
  tags: ['logic', 'np-complete'],
  domain: 'algorithms',
  height: 0,
  serviceIds: [],
  publisherReputation: 0,
);
const _summary = SkillView(boxId: 'skill-md', name: 'Markdown Summarization', prose: '', tags: [], domain: 'nlp', height: 0, serviceIds: [], publisherReputation: 0);

List<SkillServiceView> _ranked() => [
  SkillServiceView(serviceId: _best, score: 0.8455, direct: true),
  SkillServiceView(serviceId: _other, score: 0.7, direct: true),
  SkillServiceView(serviceId: _found, score: 0.52, direct: false),
];

void main() {
  late List<String> asked;
  late String? result;
  var returned = false;

  Future<void> open(
    WidgetTester tester, {
    Future<List<SkillView>> Function()? skills,
    Future<List<SkillServiceView>> Function(String id)? services,
  }) async {
    // A phone: the default test view is 800 x 600, and the list is longer than 600.
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    asked = [];
    result = null;
    returned = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => SkillPickerScreen(
                      loadSkills: skills ?? () async => [_sat, _summary],
                      loadServices: (id) {
                        asked.add(id);
                        return (services ?? (_) async => _ranked())(id);
                      },
                    ),
                  ),
                );
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the skills in groups by field, each with its name and one line (#122)', (tester) async {
    await open(tester);
    expect(find.text('Pick a skill to see the services that do it.'), findsOneWidget);
    expect(find.text('ALGORITHMS'), findsOneWidget);
    expect(find.text('NLP'), findsOneWidget);
    expect(find.text('Boolean SAT Solver'), findsOneWidget);
    expect(find.text('Decides if a formula can be satisfied.'), findsOneWidget);
    // The field is the title of the group, not a line of the card; the tags are not on it.
    expect(find.text('algorithms'), findsNothing);
    expect(find.text('logic'), findsNothing);
    expect(find.text('Markdown Summarization'), findsOneWidget);
    expect(find.byKey(const Key('picker-loading')), findsNothing);
    expect(find.byKey(const Key('picker-more')), findsNothing);
  });

  testWidgets('more than six skills: a short list first, and "Show more"', (tester) async {
    final many = [
      for (var i = 0; i < 9; i++)
        SkillView(
          boxId: 'k$i',
          name: 'Skill $i',
          prose: '',
          tags: const [],
          domain: 'd',
          height: 0,
          serviceIds: const [],
          publisherReputation: 9.0 - i,
        ),
    ];
    await open(tester, skills: () async => many);
    expect(find.byKey(const Key('picker-skill-k5')), findsOneWidget);
    expect(find.byKey(const Key('picker-skill-k6')), findsNothing);
    expect(find.text('Show more (3)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('picker-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker-skill-k8')), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
  });

  testWidgets('a skill shows one recommended service and one main action; the rest is one tap away (#122)', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();

    expect(asked, ['skill-sat']);
    expect(find.byKey(const Key('picker-skill-name')), findsOneWidget);
    // One warning about test data, at the top.
    expect(find.byKey(const Key('skill-test-banner')), findsOneWidget);
    expect(find.text('Most results are tests. Check before you trust them.'), findsOneWidget);
    // The best of the ranking is the one card, recommended and chosen.
    expect(find.byKey(Key('picker-service-$_best')), findsOneWidget);
    expect(find.byKey(Key('picker-service-$_other')), findsNothing);
    expect(find.byKey(Key('picker-service-$_found')), findsNothing);
    expect(
      find.descendant(of: find.byKey(Key('picker-service-$_best')), matching: find.byKey(const Key('picker-service-recommended'))),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(Key('picker-service-$_best')), matching: find.byKey(const Key('picker-service-chosen'))),
      findsOneWidget,
    );
    expect(find.text('Rating: High'), findsOneWidget);
    expect(find.text('Other options (2)'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    // No hexadecimal id and no raw score before "Details".
    expect(find.textContaining('aaaaaa'), findsNothing);
    expect(find.textContaining('0.85'), findsNothing);
    expect(find.textContaining('benchmark'), findsNothing);

    await tester.tap(find.byKey(Key('picker-service-details-$_best')));
    await tester.pumpAndSettle();
    expect(find.text('Service id aaaaaa…aaaa'), findsOneWidget);
    expect(find.text('Exact rating: 0.85 of 1'), findsOneWidget);
    expect(find.text('Declared by the publisher'), findsOneWidget);
    expect(find.textContaining(_best), findsNothing);

    // Copy puts the full id on the clipboard.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(Key('picker-service-copy-$_best')));
    await tester.pumpAndSettle();
    expect(copied, _best);
  });

  testWidgets('the other options keep the order of the ranking; a service from results only is unverified', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-service-others')));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.byKey(Key('picker-service-$_best')));
    final second = tester.getTopLeft(find.byKey(Key('picker-service-$_other')));
    final third = tester.getTopLeft(find.byKey(Key('picker-service-$_found')));
    expect(first.dy, lessThan(second.dy));
    expect(second.dy, lessThan(third.dy));
    expect(find.text('Rating: Medium'), findsOneWidget);
    expect(find.byKey(Key('picker-service-unverified-$_found')), findsOneWidget);
    expect(find.byKey(Key('picker-service-unverified-$_best')), findsNothing);
    expect(find.byKey(const Key('picker-service-recommended')), findsOneWidget);
    expect(find.byKey(const Key('skill-test-banner')), findsOneWidget);
  });

  test('the levels of a rating', () {
    expect(serviceRatingOf(0.7), ServiceRating.high);
    expect(serviceRatingOf(0.69), ServiceRating.medium);
    expect(serviceRatingOf(0.5), ServiceRating.medium);
    expect(serviceRatingOf(0.39), ServiceRating.low);
    expect(shortServiceId('0123456789abcdef'), '012345…cdef');
  });

  testWidgets('"Use this service" returns the best one', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-use')));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, _best);
  });

  testWidgets('the user can choose another service', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-service-others')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('picker-service-$_found')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(Key('picker-service-$_found')),
        matching: find.byKey(const Key('picker-service-chosen')),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('picker-use')));
    await tester.pumpAndSettle();
    expect(result, _found);
  });

  testWidgets('a skill with no service says so and offers no service to use', (tester) async {
    await open(tester, services: (_) async => []);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker-no-services')), findsOneWidget);
    expect(find.byKey(const Key('picker-use')), findsNothing);
  });

  testWidgets('an empty catalog says so', (tester) async {
    await open(tester, skills: () async => []);
    expect(find.text(ServiceStrings.skillsEmpty), findsOneWidget);
  });

  testWidgets('a catalog that fails shows the error, and "Try again" reads it again', (tester) async {
    var calls = 0;
    await open(
      tester,
      skills: () async {
        if (calls++ == 0) {
          throw const CelautError(kind: CelautErrorKind.unreachable, message: 'HTTP 500');
        }
        return [_sat];
      },
    );
    expect(find.byKey(const Key('picker-error')), findsOneWidget);
    expect(find.text('Detail: HTTP 500'), findsOneWidget);
    await tester.tap(find.byKey(const Key('picker-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker-error')), findsNothing);
    expect(find.text('Boolean SAT Solver'), findsOneWidget);
  });

  testWidgets('services that fail show the error, and "Try again" reads that skill again', (tester) async {
    var calls = 0;
    await open(
      tester,
      services: (_) async {
        if (calls++ == 0) {
          throw const CelautError(kind: CelautErrorKind.timeout, message: 'slow');
        }
        return _ranked();
      },
    );
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker-error')), findsOneWidget);
    expect(find.byKey(const Key('picker-use')), findsNothing);
    await tester.tap(find.byKey(const Key('picker-retry')));
    await tester.pumpAndSettle();
    expect(asked, ['skill-sat', 'skill-sat']);
    expect(find.byKey(const Key('picker-use')), findsOneWidget);
  });

  testWidgets('back from the services goes to the skills, and back again closes with nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returned, isFalse);
    expect(find.text('Markdown Summarization'), findsOneWidget);
    expect(find.byKey(const Key('picker-use')), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
  });

  testWidgets('"Other skills" goes back to the list', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-other-skill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker-skill-skill-md')), findsOneWidget);
  });

  testWidgets('the services of a skill that the user left are not shown for the next one', (tester) async {
    final slow = Completer<List<SkillServiceView>>();
    await open(
      tester,
      services: (id) => id == 'skill-sat'
          ? slow.future
          : Future.value([SkillServiceView(serviceId: _other, score: 0.6, direct: true)]),
    );
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('picker-other-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-skill-skill-md')));
    await tester.pumpAndSettle();
    slow.complete(_ranked());
    await tester.pumpAndSettle();
    expect(find.byKey(Key('picker-service-$_best')), findsNothing);
    expect(find.byKey(Key('picker-service-$_other')), findsOneWidget);
  });
}
