import 'dart:convert';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/service_presets.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/env_questions_screen.dart';
import 'package:argus_wallet/ui/celaut/preset_pin.dart';
import 'package:argus_wallet/ui/celaut/preset_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _svc = 'ab' * 32;

const _declared = [
  DeclaredVariableView(name: 'API_KEY', tags: [], prose: ''),
  DeclaredVariableView(name: 'MODEL', tags: [], prose: ''),
  DeclaredVariableView(name: 'TOKEN', tags: [], prose: ''),
  DeclaredVariableView(name: 'LANG', tags: [], prose: ''),
  DeclaredVariableView(name: 'WORKERS', tags: [], prose: ''),
];

InstanceListView _instance(String id) => InstanceListView(
      instanceId: id,
      peerId: 'aa' * 32,
      address: 'node.example:53460',
      serviceId: _svc,
      slots: Uint16List.fromList([8080]),
      chatSlots: Uint16List.fromList([8080]),
      cardsSlots: Uint16List(0),
      webSlots: Uint16List(0),
      startedAt: 100,
      startChargeMu: '1000',
      name: 'Echo chat',
      alias: '',
      title: '',
      stoppedAt: null,
      refundMu: '',
    );

Future<String> _stored() async => (await SharedPreferences.getInstance()).getString('celaut_presets_v1') ?? '';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what a launch keeps of the answers', () {
    test('container by name, saved typed values by the saved name, secrets not at all', () {
      final kept = presetVariablesOf(_declared, const [
        EnvFromContainer('OPENAI_KEY'),
        EnvTyped('llama-70b'),
        EnvTyped('tok-123', sensitive: true),
        EnvTyped('es', save: true, saveAs: 'MY_LANG'),
        EnvSkipped(),
      ]);
      expect(kept, const [
        PresetVariable.container('API_KEY', 'OPENAI_KEY'),
        PresetVariable.text('MODEL', 'llama-70b'),
        PresetVariable.ask('TOKEN'),
        PresetVariable.container('LANG', 'MY_LANG'),
        PresetVariable.skip('WORKERS'),
      ]);
      expect(kept.map((v) => v.value), isNot(contains('tok-123')));
      // A sensitive value that the user saved lives in the container: the preset keeps its
      // name only.
      expect(
        presetVariablesOf(const [DeclaredVariableView(name: 'K', tags: [], prose: '')], const [
          EnvTyped('s3cret', sensitive: true, save: true),
        ]),
        const [PresetVariable.container('K', 'K')],
      );
    });

    test('the answers of a preset: a gone container variable, a secret and an unknown one are asked', () {
      final answers = envAnswersOfPreset(
        _declared,
        const [
          PresetVariable.container('API_KEY', 'OPENAI_KEY'),
          PresetVariable.text('MODEL', 'llama-70b'),
          PresetVariable.ask('TOKEN'),
          PresetVariable.container('LANG', 'GONE'),
          PresetVariable.skip('OTHER'),
        ],
        {'OPENAI_KEY'},
      );
      expect(answers[0], isA<EnvFromContainer>().having((a) => a.name, 'name', 'OPENAI_KEY'));
      expect(answers[1], isA<EnvTyped>().having((a) => a.text, 'text', 'llama-70b').having((a) => a.sensitive, 's', false));
      expect(answers.sublist(2), [null, null, null]);
      expect(
        envAnswersOfPreset(const [DeclaredVariableView(name: 'WORKERS', tags: [], prose: '')], const [
          PresetVariable.skip('WORKERS'),
        ], const {}).single,
        isA<EnvSkipped>(),
      );
    });
  });

  group('the store of presets', () {
    test('a pin takes the variables that the instance was started with; no secret is stored', () async {
      final presets = ServicePresets();
      await presets.recordLaunch('i1', const [
        PresetVariable.container('API_KEY', 'OPENAI_KEY'),
        PresetVariable.ask('TOKEN'),
        PresetVariable.text('MODEL', 'llama-70b'),
      ]);
      final p = await presets.pin(instanceId: 'i1', serviceId: _svc.toUpperCase(), name: '  LLM   70B ');
      expect(p!.name, 'LLM 70B');
      expect(p.serviceId, _svc);
      expect(p.known, isTrue);
      expect(p.asked, 1);
      expect(presets.pinnedFrom('i1'), same(p));
      expect(await _stored(), contains('OPENAI_KEY'));
      // Pinned once only.
      expect(await presets.pin(instanceId: 'i1', serviceId: _svc, name: 'again'), isNull);
    });

    test('an instance that this phone did not start is pinned without its variables', () async {
      final presets = ServicePresets();
      final p = await presets.pin(instanceId: 'other', serviceId: _svc, name: 'Other');
      expect(p!.known, isFalse);
      expect(p.variables, isEmpty);
    });

    test('at most eight presets; a blank name is refused', () async {
      final presets = ServicePresets();
      expect(await presets.pin(instanceId: 'x', serviceId: _svc, name: '   '), isNull);
      for (var i = 0; i < ServicePresets.maxPresets; i++) {
        expect(await presets.pin(instanceId: 'i$i', serviceId: _svc, name: 'P$i'), isNotNull);
      }
      expect(presets.full, isTrue);
      expect(await presets.pin(instanceId: 'i9', serviceId: _svc, name: 'P9'), isNull);
      expect(presets.presets, hasLength(8));
    });

    test('rename, remove and forget; a load reads it all back', () async {
      final presets = ServicePresets();
      await presets.recordLaunch('i1', const [PresetVariable.text('MODEL', 'm')]);
      final p = (await presets.pin(instanceId: 'i1', serviceId: _svc, name: 'One'))!;
      await presets.pin(instanceId: 'i2', serviceId: _svc, name: 'Two');
      await presets.rename(p.id, 'Uno');
      await presets.rename(p.id, '   ');
      expect(presets.byId(p.id)!.name, 'Uno');
      await presets.forget('i1');
      expect(presets.launchedWith('i1'), isNull);
      // The preset stays when its instance is deleted.
      expect(presets.byId(p.id)!.variables, const [PresetVariable.text('MODEL', 'm')]);

      final again = ServicePresets();
      await again.load();
      expect(again.presets.map((p) => p.name), ['Uno', 'Two']);
      expect(again.presets.first.variables, const [PresetVariable.text('MODEL', 'm')]);
      await again.remove(p.id);
      expect(again.presets.map((p) => p.name), ['Two']);
    });

    test('a stored text that is not valid is left out', () async {
      SharedPreferences.setMockInitialValues({
        'celaut_presets_v1': jsonEncode({
          'presets': [
            {'id': 'a', 's': 'not-hex', 'name': 'Bad id', 'from': 'i', 'known': true, 'env': []},
            {
              'id': 'b',
              's': _svc,
              'name': 'Good',
              'from': 'i',
              'known': true,
              'env': [
                {'n': 'OK', 't': 'v'},
                {'n': 'bad name', 't': 'v'},
                {'n': 'NUL', 't': 'a\u0000b'},
                {'n': 'WHAT', 'k': 'other'},
              ],
            },
            'junk',
          ],
          'launched': {'i1': 'junk', 'i2': [{'n': 'A', 'k': 'ask'}]},
        }),
      });
      final presets = ServicePresets();
      await presets.load();
      expect(presets.presets.single.name, 'Good');
      expect(presets.presets.single.variables, const [PresetVariable.text('OK', 'v')]);
      expect(presets.launchedWith('i2'), const [PresetVariable.ask('A')]);
      expect(presets.launchedWith('i1'), isNull);
    });

    test('only the last 200 launches are kept', () async {
      final presets = ServicePresets();
      for (var i = 0; i < ServicePresets.maxLaunches + 5; i++) {
        await presets.recordLaunch('i$i', const []);
      }
      expect(presets.launchedWith('i0'), isNull);
      expect(presets.launchedWith('i204'), isEmpty);
    });
  });

  group('the questions filled from a preset', () {
    Future<List<EnvAnswer?>?> pump(WidgetTester tester, List<EnvAnswer?> initial, {required void Function(List<EnvAnswer?>) seen}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EnvQuestionsScreen(
            declared: _declared.sublist(0, 2),
            initial: initial,
            onConfirmed: seen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return null;
    }

    testWidgets('all answered: the review first; Run gives the answers to the launch', (tester) async {
      List<EnvAnswer?>? got;
      await pump(tester, const [EnvTyped('a'), EnvSkipped()], seen: (a) => got = a);
      expect(find.byKey(const Key('env-step')), findsNothing);
      expect(find.byKey(const Key('env-run')), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(got, hasLength(2));
      expect(got![1], isA<EnvSkipped>());
    });

    testWidgets('one missing: it opens on that variable', (tester) async {
      await pump(tester, const [EnvTyped('a'), null], seen: (_) {});
      expect(find.text('Variable 2 of 2'), findsOneWidget);
      // The name to save under is the one of this variable.
      await tester.tap(find.byKey(const Key('env-ask-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-typed-save')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('env-typed-save-name'))).controller!.text, 'MODEL');
    });
  });

  group('Pin as preset', () {
    Future<ServicePresets> pump(WidgetTester tester, {ThemeData? theme, ServicePresets? presets}) async {
      final p = presets ?? ServicePresets();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? argusTheme(watchful: false),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PresetPinSection(instance: _instance('i1'), title: 'Echo chat', presets: p),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return p;
    }

    testWidgets('it says what it does; pin asks for the name, then it shows Pinned and Unpin', (tester) async {
      final presets = ServicePresets();
      await presets.recordLaunch('i1', const [PresetVariable.ask('TOKEN'), PresetVariable.text('A', 'b')]);
      await pump(tester, presets: presets);
      expect(find.text(appL10n.presetPin), findsOneWidget);
      expect(find.text(appL10n.presetPinNote), findsOneWidget);
      await tester.tap(find.byKey(const Key('info-pin')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.presetPinBody), findsOneWidget);
      expect(find.text(appL10n.presetPinAsks(1)), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('preset-name-field'))).controller!.text, 'Echo chat');
      await tester.enterText(find.byKey(const Key('preset-name-field')), 'Echo ES');
      await tester.tap(find.byKey(const Key('preset-name-ok')));
      await tester.pumpAndSettle();
      expect(presets.pinnedFrom('i1')!.name, 'Echo ES');
      expect(find.text(appL10n.presetPinned('Echo ES')), findsOneWidget);
      expect(find.text(appL10n.presetPinnedDone), findsOneWidget);
      await tester.tap(find.byKey(const Key('info-unpin')));
      await tester.pumpAndSettle();
      expect(presets.presets, isEmpty);
      expect(find.byKey(const Key('info-pin')), findsOneWidget);
    });

    testWidgets('an instance with unknown variables says that the launch asks for them; Cancel pins nothing', (tester) async {
      final presets = await pump(tester);
      await tester.tap(find.byKey(const Key('info-pin')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.presetPinUnknown), findsOneWidget);
      await tester.tap(find.byKey(const Key('preset-name-cancel')));
      await tester.pumpAndSettle();
      expect(presets.presets, isEmpty);
    });

    testWidgets('a full wheel says so and asks nothing', (tester) async {
      final presets = ServicePresets();
      for (var i = 0; i < ServicePresets.maxPresets; i++) {
        await presets.pin(instanceId: 'o$i', serviceId: _svc, name: 'P$i');
      }
      await pump(tester, presets: presets);
      await tester.tap(find.byKey(const Key('info-pin')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('preset-name-dialog')), findsNothing);
      expect(find.text(appL10n.presetFull(8)), findsOneWidget);
    });

    testWidgets('Spanish', (tester) async {
      setAppLocale(const Locale('es'));
      addTearDown(() => setAppLocale(const Locale('en')));
      await pump(tester);
      expect(find.text('Anclar como preconfigurado'), findsOneWidget);
    });
  });

  group('the wheel', () {
    test('the slots fan out up and to the left of a button at the bottom right, apart and on the screen', () {
      const screen = Size(360, 740);
      const center = Offset(360 - 16 - 28, 740 - 80 - 16 - 28);
      for (final count in [1, 2, 5, 9]) {
        final offsets = presetWheelOffsets(count, center: center, screen: screen, padding: const EdgeInsets.only(top: 24));
        expect(offsets, hasLength(count));
        for (final o in offsets) {
          final p = center + o;
          expect(o.dx, lessThan(0));
          expect(o.dy, lessThan(0));
          expect(o.distance, greaterThan(presetSlotSize));
          expect(p.dx - presetLabelWidth / 2, greaterThanOrEqualTo(0));
          expect(p.dy - presetSlotSize / 2, greaterThanOrEqualTo(24));
        }
        for (var i = 0; i < offsets.length; i++) {
          for (var j = i + 1; j < offsets.length; j++) {
            expect((offsets[i] - offsets[j]).distance, greaterThan(60), reason: '$count: $i-$j');
          }
        }
      }
      // A button at the bottom left (a right-to-left layout): to the right.
      expect(presetWheelOffsets(3, center: const Offset(44, 600), screen: screen).every((o) => o.dx > 0), isTrue);
    });

    test('on a phone on its side the rings come closer', () {
      const screen = Size(740, 360);
      const center = Offset(740 - 44, 360 - 44);
      final offsets = presetWheelOffsets(9, center: center, screen: screen);
      for (final o in offsets) {
        expect((center + o).dy - presetSlotSize / 2, greaterThanOrEqualTo(0));
      }
    });

    for (final dark in [false, true]) {
      testWidgets('it opens over the page in the ${dark ? 'dark' : 'light'} theme', (tester) async {
        final presets = ServicePresets();
        await presets.pin(instanceId: 'i1', serviceId: _svc, name: 'A very long preset name for a slot');
        final picks = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
            home: Scaffold(
              floatingActionButton: PresetWheelButton(
                presets: presets,
                tooltip: 'New',
                onObjectives: () => picks.add('objectives'),
                onPreset: (p) => picks.add(p.name),
                onEdit: (p) => picks.add('edit'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('chats-new')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final slot = find.byKey(Key('preset-slot-${presets.presets.single.id}'));
        expect(slot, findsOneWidget);
        await tester.tap(slot);
        await tester.pumpAndSettle();
        expect(picks, ['A very long preset name for a slot']);
      });
    }
  });
}
