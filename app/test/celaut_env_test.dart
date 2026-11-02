import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/bridge/api/celaut_service_info.dart';
import 'package:argus_wallet/celaut/egress.dart';
import 'package:argus_wallet/celaut/env_store.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart' show rust;
import 'package:argus_wallet/ui/celaut/env_questions_screen.dart';
import 'package:argus_wallet/ui/celaut/env_variables_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The container in memory, with the calls that the screens make.
class _Container {
  final values = <String, String>{};
  final calls = <String>[];

  /// The variables that are not sensitive. The others are.
  final notSensitive = <String>{};
  Object? setError;

  EnvStore get store => EnvStore(
    names: () => [
      for (final n in values.keys.toList()..sort())
        EnvNameView(name: n, changedAt: 1, sensitive: !notSensitive.contains(n)),
    ],
    get: (n) {
      calls.add('get $n');
      return values[n];
    },
    set: (n, v, sensitive) {
      if (setError != null) throw setError!;
      calls.add('set $n ${sensitive ? 'sensitive' : 'plain'}');
      values[n] = v;
      sensitive ? notSensitive.remove(n) : notSensitive.add(n);
    },
    setSensitive: (n, sensitive) {
      calls.add('mark $n ${sensitive ? 'sensitive' : 'plain'}');
      sensitive ? notSensitive.remove(n) : notSensitive.add(n);
    },
    delete: (n) {
      calls.add('delete $n');
      values.remove(n);
    },
  );
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

const _declared = [
  DeclaredVariableView(name: 'API_KEY', tags: ['text'], prose: 'The key of the API'),
  DeclaredVariableView(name: 'MODE', tags: ['text'], prose: ''),
  DeclaredVariableView(name: 'TOKEN', tags: [], prose: ''),
];

/// Open the questions for [variables], give the [answers], and return what the screen gave.
Future<List<EnvChoice>?> ask(
  WidgetTester tester,
  Future<void> Function() answers, {
  _Container? c,
  List<DeclaredVariableView> variables = _declared,
  List<NetworkView> networks = const [],
  List<EnvTargetNode> nodes = const [],
}) async {
  List<EnvChoice>? result = const [EnvChoice(name: 'not-set')];
  var done = false;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => TextButton(
          key: const Key('open'),
          onPressed: () async {
            result = await Navigator.of(context).push<List<EnvChoice>>(
              MaterialPageRoute(
                builder: (_) => EnvQuestionsScreen(
                  declared: variables,
                  networks: networks,
                  nodes: nodes,
                  store: (c ?? _Container()).store,
                ),
              ),
            );
            done = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await answers();
  expect(done, isTrue, reason: 'the screen closed');
  return result;
}

void main() {
  group('the rules of a name and a value', () {
    test('a name is a C identifier that is not reserved', () {
      for (final ok in ['A', '_', 'API_KEY', '_x1']) {
        expect(envNameProblem(ok), isNull, reason: ok);
      }
      expect(envNameProblem(''), EnvProblem.nameEmpty);
      for (final bad in ['1A', 'A-B', 'A B', 'ñ', 'A.B', 'A=B']) {
        expect(envNameProblem(bad), EnvProblem.nameBad, reason: bad);
      }
      expect(envNameProblem(envReservedName), EnvProblem.nameReserved);
      expect(envNameProblem('A' * 257), EnvProblem.nameBad);
    });

    test('a value is text with no NUL and at most 8192 bytes', () {
      expect(envValueProblem('sk-1 ñ'), isNull);
      expect(envValueProblem(''), EnvProblem.valueEmpty);
      expect(envValueProblem('a\u0000b'), EnvProblem.valueNul);
      expect(envValueProblem('a' * 8192), isNull);
      expect(envValueProblem('a' * 8193), EnvProblem.valueLong);
      // The limit counts bytes: 4097 characters of 2 bytes are too long.
      expect(envValueProblem('ñ' * 4097), EnvProblem.valueLong);
    });
  });

  group('the container screen', () {
    testWidgets('an empty container says so', (tester) async {
      await tester.pumpWidget(_app(EnvVariablesScreen(store: _Container().store)));
      expect(find.byKey(const Key('env-empty')), findsOneWidget);
    });

    testWidgets('a variable is added, listed with its value hidden, edited and deleted', (tester) async {
      final c = _Container();
      await tester.pumpWidget(_app(EnvVariablesScreen(store: c.store)));
      await tester.tap(find.byKey(const Key('env-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-name')), 'API_KEY');
      await tester.enterText(find.byKey(const Key('env-value')), 'sk-1');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pumpAndSettle();
      expect(c.values, {'API_KEY': 'sk-1'});
      expect(find.byKey(const Key('env-row-API_KEY')), findsOneWidget);
      expect(find.text('sk-1'), findsNothing);

      // The edit form hides the value until the eye is tapped.
      await tester.tap(find.byKey(const Key('env-row-API_KEY')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('env-value'))).obscureText, isTrue);
      await tester.tap(find.byKey(const Key('env-eye')));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('env-value'))).obscureText, isFalse);
      expect(find.text('sk-1'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('env-value')), 'sk-2');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pumpAndSettle();
      expect(c.values, {'API_KEY': 'sk-2'});

      await tester.tap(find.byKey(const Key('env-delete-API_KEY')));
      await tester.pumpAndSettle();
      expect(c.values, isNotEmpty, reason: 'the delete asks first');
      await tester.tap(find.byKey(const Key('env-delete-yes')));
      await tester.pumpAndSettle();
      expect(c.values, isEmpty);
      expect(find.byKey(const Key('env-empty')), findsOneWidget);
    });

    testWidgets('the name has the focus, Next goes to the value, and Done saves', (tester) async {
      final c = _Container();
      await tester.pumpWidget(_app(EnvVariablesScreen(store: c.store)));
      await tester.tap(find.byKey(const Key('env-add')));
      await tester.pumpAndSettle();
      final name = tester.widget<TextField>(find.byKey(const Key('env-name')));
      expect(name.autofocus, isTrue);
      expect(name.textInputAction, TextInputAction.next);
      // A hidden value has one line, and its action key saves.
      expect(tester.widget<TextField>(find.byKey(const Key('env-value'))).textInputAction, TextInputAction.done);
      await tester.enterText(find.byKey(const Key('env-name')), 'API_KEY');
      await tester.enterText(find.byKey(const Key('env-value')), 'sk-1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(c.values, {'API_KEY': 'sk-1'});
    });

    testWidgets('a bad name or value is refused with its reason and nothing is stored', (tester) async {
      final c = _Container();
      await tester.pumpWidget(_app(EnvVariablesScreen(store: c.store)));
      await tester.tap(find.byKey(const Key('env-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-name')), '1A');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pump();
      expect(find.textContaining('start with a letter'), findsOneWidget);
      expect(find.text('Write a value.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('env-name')), '__nodo_instance_name');
      await tester.enterText(find.byKey(const Key('env-value')), 'x');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pump();
      expect(find.textContaining('reserved'), findsOneWidget);
      expect(c.values, isEmpty);
      expect(c.calls, isEmpty);
    });

    testWidgets('a name that exists is not added a second time', (tester) async {
      final c = _Container()..values['A'] = '1';
      await tester.pumpWidget(_app(EnvVariablesScreen(store: c.store)));
      await tester.tap(find.byKey(const Key('env-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-name')), 'A');
      await tester.enterText(find.byKey(const Key('env-value')), '2');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pump();
      expect(find.textContaining('exists'), findsOneWidget);
      expect(c.values, {'A': '1'});
    });

    testWidgets('an error of Rust shows its text and keeps the form open', (tester) async {
      final c = _Container()..setError = const CelautError(kind: CelautErrorKind.storage, message: 'disk full');
      await tester.pumpWidget(_app(EnvVariablesScreen(store: c.store)));
      await tester.tap(find.byKey(const Key('env-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-name')), 'A');
      await tester.enterText(find.byKey(const Key('env-value')), '1');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pump();
      expect(find.text('disk full'), findsOneWidget);
      expect(find.byKey(const Key('env-edit')), findsOneWidget);
    });
  });

  group('the questions of a launch', () {
    const declared = [
      DeclaredVariableView(name: 'API_KEY', tags: ['text'], prose: 'The key of the API'),
      DeclaredVariableView(name: 'MODE', tags: ['text'], prose: ''),
      DeclaredVariableView(name: 'TOKEN', tags: [], prose: ''),
    ];

    testWidgets('one variable at a time, each a container variable, a typed value or a skip', (tester) async {
      final c = _Container()..values['OPENAI_KEY'] = 'sk-secret';
      final result = await ask(tester, () async {
        expect(find.text('Variable 1 of 3'), findsOneWidget);
        expect(find.text('API_KEY'), findsOneWidget);
        expect(find.text('The key of the API'), findsOneWidget);
        await tester.tap(find.byKey(const Key('env-ask-pick')));
        await tester.pumpAndSettle();
        // The values of the container are not shown.
        expect(find.text('sk-secret'), findsNothing);
        await tester.tap(find.byKey(const Key('env-pick-OPENAI_KEY')));
        await tester.pumpAndSettle();

        expect(find.text('Variable 2 of 3'), findsOneWidget);
        // With no prose, the tags of the format.
        expect(find.byKey(const Key('env-var-text')), findsOneWidget);
        expect(find.text('text'), findsOneWidget);
        await tester.tap(find.byKey(const Key('env-ask-type')));
        await tester.pump();
        await tester.enterText(find.byKey(const Key('env-typed')), 'fast ñ');
        await tester.tap(find.byKey(const Key('env-typed-use')));
        await tester.pumpAndSettle();

        expect(find.text('Variable 3 of 3'), findsOneWidget);
        await tester.tap(find.byKey(const Key('env-ask-skip')));
        await tester.pumpAndSettle();

        // The review shows where each value comes from, and no value.
        expect(find.text('My variable OPENAI_KEY · Sensitive'), findsOneWidget);
        expect(find.text('Typed value'), findsOneWidget);
        expect(find.text('Skipped'), findsOneWidget);
        expect(find.text('fast ñ'), findsNothing);
        expect(find.text('sk-secret'), findsNothing);
        expect(find.byKey(const Key('env-review-note')), findsOneWidget);
        await tester.tap(find.byKey(const Key('env-run')));
        await tester.pumpAndSettle();
      }, c: c);
      expect(result!.map((e) => (e.name, e.container, e.text)), [
        ('API_KEY', 'OPENAI_KEY', null),
        ('MODE', null, 'fast ñ'),
      ]);
      // Reading the values is the job of Rust: the screen never asked for one.
      expect(c.calls, isEmpty);
    });

    testWidgets('skipping every variable runs with none', (tester) async {
      final result = await ask(tester, () async {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const Key('env-ask-skip')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('env-run')));
        await tester.pumpAndSettle();
      });
      expect(result, isEmpty);
    });

    testWidgets('the variables of the container with the same name come first', (tester) async {
      final c = _Container()
        ..values['AAA'] = '1'
        ..values['MODE'] = '2';
      await ask(tester, () async {
        await tester.tap(find.byKey(const Key('env-ask-skip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('env-ask-pick')));
        await tester.pumpAndSettle();
        final same = tester.getTopLeft(find.byKey(const Key('env-pick-MODE')));
        final other = tester.getTopLeft(find.byKey(const Key('env-pick-AAA')));
        expect(same.dy, lessThan(other.dy));
        await tester.tap(find.byKey(const Key('env-pick-AAA')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('env-cancel')));
        await tester.pumpAndSettle();
      }, c: c);
    });

    testWidgets('an empty container says where to add variables', (tester) async {
      await ask(tester, () async {
        await tester.tap(find.byKey(const Key('env-ask-pick')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('env-pick-empty')), findsOneWidget);
        expect(find.textContaining('Environment variables'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('env-cancel')));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('a typed value that the node cannot use is refused with its reason', (tester) async {
      await ask(tester, () async {
        await tester.tap(find.byKey(const Key('env-ask-type')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('env-typed-use')));
        await tester.pump();
        expect(find.text('Write a value.'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('env-typed')), 'a\u0000b');
        await tester.tap(find.byKey(const Key('env-typed-use')));
        await tester.pump();
        expect(find.textContaining('NUL'), findsOneWidget);
        expect(find.text('Variable 1 of 3'), findsOneWidget, reason: 'it stays on the variable');
        await tester.tap(find.byKey(const Key('env-cancel')));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('a typed value is hidden until the eye is tapped', (tester) async {
      await ask(tester, () async {
        await tester.tap(find.byKey(const Key('env-ask-type')));
        await tester.pump();
        expect(tester.widget<TextField>(find.byKey(const Key('env-typed'))).obscureText, isTrue);
        await tester.tap(find.byKey(const Key('env-typed-eye')));
        await tester.pump();
        expect(tester.widget<TextField>(find.byKey(const Key('env-typed'))).obscureText, isFalse);
        await tester.tap(find.byKey(const Key('env-cancel')));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('Back returns to the earlier variable and keeps its answer; Cancel gives null', (tester) async {
      final result = await ask(tester, () async {
        await tester.tap(find.byKey(const Key('env-ask-skip')));
        await tester.pumpAndSettle();
        expect(find.text('Variable 2 of 3'), findsOneWidget);
        await tester.tap(find.byKey(const Key('env-back')));
        await tester.pumpAndSettle();
        expect(find.text('Variable 1 of 3'), findsOneWidget);
        expect(find.textContaining('Chosen: Skipped'), findsOneWidget);
        await tester.tap(find.byKey(const Key('env-cancel')));
        await tester.pumpAndSettle();
      });
      expect(result, isNull);
    });

    testWidgets('the system back goes to the earlier variable, and on the first one it cancels', (tester) async {
      final result = await ask(tester, () async {
        await tester.tap(find.byKey(const Key('env-ask-skip')));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Variable 1 of 3'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      });
      expect(result, isNull);
    });

    testWidgets('a declared name that the node cannot give can only be skipped', (tester) async {
      final result = await ask(
        tester,
        () async {
          expect(find.byKey(const Key('env-bad-name')), findsOneWidget);
          expect(find.byKey(const Key('env-ask-pick')), findsNothing);
          expect(find.byKey(const Key('env-ask-type')), findsNothing);
          await tester.tap(find.byKey(const Key('env-ask-skip')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('env-run')));
          await tester.pumpAndSettle();
        },
        variables: const [DeclaredVariableView(name: '1-bad', tags: [], prose: '')],
      );
      expect(result, isEmpty);
    });

    test('the choices keep the order of the declaration and leave out what was skipped', () {
      final out = envChoices(declared, [const EnvTyped('x'), const EnvSkipped(), const EnvFromContainer('K')]);
      expect(out.map((e) => (e.name, e.container, e.text)), [('API_KEY', null, 'x'), ('TOKEN', 'K', null)]);
      expect(envChoices(declared, [null, null, null]), isEmpty);
    });
  });

  group('sensitive variables in the container', () {
    testWidgets('a new variable is sensitive unless the switch is off', (tester) async {
      final c = _Container();
      await tester.pumpWidget(_app(EnvVariablesScreen(store: c.store)));
      await tester.tap(find.byKey(const Key('env-add')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('env-edit-sensitive'))).value, isTrue);
      await tester.enterText(find.byKey(const Key('env-name')), 'API_KEY');
      await tester.enterText(find.byKey(const Key('env-value')), 'sk-1');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-name')), 'MODE');
      await tester.enterText(find.byKey(const Key('env-value')), 'fast');
      await tester.tap(find.byKey(const Key('env-edit-sensitive')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pumpAndSettle();
      expect(c.calls, ['set API_KEY sensitive', 'set MODE plain']);
      expect(find.text('••••••••  ·  Sensitive'), findsOneWidget);
      expect(find.text('••••••••  ·  Not sensitive'), findsOneWidget);
    });

    testWidgets('the lock of a row changes the mark and keeps the value', (tester) async {
      final c = _Container()..values['API_KEY'] = 'sk-1';
      await tester.pumpWidget(_app(EnvVariablesScreen(store: c.store)));
      await tester.tap(find.byKey(const Key('env-sensitive-API_KEY')));
      await tester.pump();
      expect(c.notSensitive, {'API_KEY'});
      expect(find.text('••••••••  ·  Not sensitive'), findsOneWidget);
      // The edit form opens with the mark of the variable and keeps it.
      await tester.tap(find.byKey(const Key('env-row-API_KEY')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('env-edit-sensitive'))).value, isFalse);
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pumpAndSettle();
      expect(c.calls.last, 'set API_KEY plain');
      expect(c.values, {'API_KEY': 'sk-1'});
    });
  });

  group('the warnings of a launch', () {
    const declared = [
      DeclaredVariableView(name: 'API_KEY', tags: ['text'], prose: 'The key of the API'),
    ];
    const egress = [
      NetworkView(tags: ['*'], prose: '', formal: '', protocolStack: []),
      NetworkView(tags: ['api.example.com'], prose: '', formal: 'port=443', protocolStack: []),
    ];
    const local = [NetworkView(tags: ['postgres'], prose: '', formal: '', protocolStack: [])];
    const untrusted = [EnvTargetNode(peerId: 'aa', address: 'other.example:1', trusted: false)];
    const trusted = [EnvTargetNode(peerId: 'bb', address: 'mine.example:1', trusted: true)];

    /// Answer the one variable from the container, and stop on the review.
    Future<void> pickContainer(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('env-ask-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-pick-OPENAI_KEY')));
      await tester.pumpAndSettle();
    }

    /// Answer the one variable with a typed value, sensitive or not.
    Future<void> type(WidgetTester tester, {required bool sensitive}) async {
      await tester.tap(find.byKey(const Key('env-ask-type')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-typed')), 'x');
      if (sensitive) {
        await tester.tap(find.byKey(const Key('env-typed-sensitive')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('env-typed-use')));
      await tester.pumpAndSettle();
    }

    Future<void> run(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
    }

    testWidgets('a value that is not sensitive warns of nothing, with egress and an untrusted node', (tester) async {
      final c = _Container()
        ..values['OPENAI_KEY'] = 'sk'
        ..notSensitive.add('OPENAI_KEY');
      final result = await ask(tester, () async {
        await pickContainer(tester);
        expect(find.byKey(const Key('env-warning-egress')), findsNothing);
        expect(find.byKey(const Key('env-warning')), findsNothing);
        expect(find.byKey(const Key('env-deny')), findsNothing);
        await run(tester);
      }, c: c, variables: declared, networks: egress, nodes: untrusted);
      expect(result!.single.container, 'OPENAI_KEY');
    });

    testWidgets('a typed value is not sensitive unless the user says so', (tester) async {
      final result = await ask(tester, () async {
        await tester.tap(find.byKey(const Key('env-ask-type')));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(find.byKey(const Key('env-typed-sensitive'))).value, isFalse);
        await tester.enterText(find.byKey(const Key('env-typed')), 'x');
        await tester.tap(find.byKey(const Key('env-typed-use')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('env-warning-egress')), findsNothing);
        expect(find.byKey(const Key('env-warning')), findsNothing);
        await run(tester);
      }, variables: declared, networks: egress, nodes: untrusted);
      expect(result!.single.text, 'x');
    });

    testWidgets('egress: the review is red, lists where the values can go, and Deny is the default', (tester) async {
      final c = _Container()..values['OPENAI_KEY'] = 'sk';
      final result = await ask(tester, () async {
        await pickContainer(tester);
        final card = find.byKey(const Key('env-warning-egress'));
        expect(card, findsOneWidget);
        final box = tester.widget<Container>(card).decoration! as BoxDecoration;
        expect((box.border! as Border).top.color, rust);
        expect(find.text('This service can connect outside the node, to: any address, api.example.com. It can send your sensitive values there.'), findsOneWidget);
        // Deny is the filled, focused button; running is the second, red choice.
        final deny = tester.widget<FilledButton>(find.byKey(const Key('env-deny')));
        expect(deny.autofocus, isTrue);
        expect(find.byKey(const Key('env-run')), findsOneWidget);
        expect(tester.widget(find.byKey(const Key('env-run'))), isA<TextButton>());
        expect(Focus.of(tester.element(find.text('Deny'))).hasFocus, isTrue);
        await tester.tap(find.byKey(const Key('env-deny')));
        await tester.pumpAndSettle();
      }, c: c, variables: declared, networks: egress, nodes: trusted);
      expect(result, isNull, reason: 'Deny cancels the launch: nothing is sent');
    });

    testWidgets('egress: the user can still send the values', (tester) async {
      final result = await ask(tester, () async {
        await type(tester, sensitive: true);
        expect(find.byKey(const Key('env-warning-egress')), findsOneWidget);
        expect(find.text('API_KEY'), findsOneWidget);
        expect(find.text('Typed value · Sensitive'), findsOneWidget);
        await run(tester);
      }, variables: declared, networks: egress, nodes: trusted);
      expect(result!.single.text, 'x');
    });

    testWidgets('networks on the node only: a normal warning that names them, and Run as usual', (tester) async {
      final c = _Container()..values['OPENAI_KEY'] = 'sk';
      await ask(tester, () async {
        await pickContainer(tester);
        expect(find.byKey(const Key('env-warning-egress')), findsNothing);
        expect(find.byKey(const Key('env-warning')), findsOneWidget);
        final box = tester.widget<Container>(find.byKey(const Key('env-warning'))).decoration! as BoxDecoration;
        expect((box.border! as Border).top.color, isNot(rust), reason: 'only egress is red');
        expect(find.byKey(const Key('env-warn-networks')), findsOneWidget);
        expect(find.textContaining('in the networks: postgres.'), findsOneWidget);
        expect(find.byKey(const Key('env-warn-nodes')), findsNothing, reason: 'the node is trusted');
        expect(find.byKey(const Key('env-deny')), findsNothing);
        expect(tester.widget(find.byKey(const Key('env-run'))), isA<FilledButton>());
        await run(tester);
      }, c: c, variables: declared, networks: local, nodes: trusted);
    });

    testWidgets('an untrusted node: a warning that names it; a trusted node gets none', (tester) async {
      final c = _Container()..values['OPENAI_KEY'] = 'sk';
      await ask(tester, () async {
        await pickContainer(tester);
        expect(find.byKey(const Key('env-warn-nodes')), findsOneWidget);
        expect(find.textContaining('other.example:1'), findsOneWidget);
        expect(find.textContaining('mine.example:1'), findsNothing);
        expect(find.byKey(const Key('env-deny')), findsNothing);
        await run(tester);
      }, c: c, variables: declared, nodes: [...trusted, ...untrusted]);
      await ask(tester, () async {
        await pickContainer(tester);
        expect(find.byKey(const Key('env-warning')), findsNothing);
        expect(find.byKey(const Key('env-warn-nodes')), findsNothing);
        await run(tester);
      }, c: c, variables: declared, nodes: trusted);
    });

    testWidgets('every condition at once is one review, not a chain of dialogs', (tester) async {
      final c = _Container()..values['OPENAI_KEY'] = 'sk';
      await ask(tester, () async {
        await pickContainer(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const Key('env-warn-egress')), findsOneWidget);
        expect(find.byKey(const Key('env-warn-networks')), findsOneWidget);
        expect(find.byKey(const Key('env-warn-nodes')), findsOneWidget);
        // Three warnings make a long page: the button can be under the fold.
        await tester.ensureVisible(find.byKey(const Key('env-deny')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('env-deny')));
        await tester.pumpAndSettle();
      }, c: c, variables: declared, networks: [...egress, ...local], nodes: untrusted);
    });

    testWidgets('a variable that a network takes by name says that it sets where the service connects', (tester) async {
      await ask(tester, () async {
        expect(find.byKey(const Key('env-egress-steers')), findsOneWidget);
        await tester.tap(find.byKey(const Key('env-ask-skip')));
        await tester.pumpAndSettle();
        // Skipped: nothing is given, so nothing warns.
        expect(find.byKey(const Key('env-warning-egress')), findsNothing);
        await run(tester);
      }, variables: declared, networks: const [
        NetworkView(tags: ['api.example.com'], prose: '', formal: 'host=\${API_KEY}', protocolStack: []),
      ]);
    });
  });
}
