import 'dart:async';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/celaut/service_strings.dart';
import 'package:argus_wallet/ui/celaut/skill_picker.dart';
import 'package:flutter/material.dart';
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
);
const _summary = SkillView(boxId: 'skill-md', name: 'Markdown Summarization', prose: '', tags: [], domain: 'nlp');

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

  testWidgets('lists the skills with their field, text and tags', (tester) async {
    await open(tester);
    expect(find.text('Boolean SAT Solver'), findsOneWidget);
    expect(find.text('algorithms'), findsOneWidget);
    expect(find.text('Decides if a formula can be satisfied.'), findsOneWidget);
    expect(find.text('logic'), findsOneWidget);
    expect(find.text('np-complete'), findsOneWidget);
    expect(find.text('Markdown Summarization'), findsOneWidget);
    expect(find.byKey(const Key('picker-loading')), findsNothing);
  });

  testWidgets('a skill shows its services best first, and the best is chosen', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('picker-skill-skill-sat')));
    await tester.pumpAndSettle();

    expect(asked, ['skill-sat']);
    expect(find.byKey(const Key('picker-skill-name')), findsOneWidget);
    expect(find.text(ServiceStrings.servicesTitle.toUpperCase()), findsOneWidget);
    final first = tester.getTopLeft(find.byKey(Key('picker-service-$_best')));
    final second = tester.getTopLeft(find.byKey(Key('picker-service-$_other')));
    final third = tester.getTopLeft(find.byKey(Key('picker-service-$_found')));
    expect(first.dy, lessThan(second.dy));
    expect(second.dy, lessThan(third.dy));
    expect(find.text(ServiceStrings.serviceScore('0.85')), findsOneWidget);
    expect(find.text(ServiceStrings.serviceScore('0.52')), findsOneWidget);
    expect(find.byKey(const Key('picker-best')), findsOneWidget);
    expect(find.text(ServiceStrings.serviceDeclared), findsNWidgets(2));
    expect(find.text(ServiceStrings.serviceFromResults), findsOneWidget);
    // One is chosen, and it is the first.
    expect(find.byKey(const Key('picker-chosen')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(Key('picker-service-$_best')),
        matching: find.byKey(const Key('picker-chosen')),
      ),
      findsOneWidget,
    );
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
    await tester.tap(find.byKey(Key('picker-service-$_found')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(Key('picker-service-$_found')),
        matching: find.byKey(const Key('picker-chosen')),
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
