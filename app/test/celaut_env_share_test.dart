import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/celaut/env_share.dart';
import 'package:argus_wallet/celaut/env_store.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/env_questions_screen.dart';
import 'package:argus_wallet/ui/celaut/env_variables_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A container in memory.
class _Box {
  final values = <String, String>{};
  final sensitive = <String, bool>{};

  late final EnvStore store = EnvStore(
        names: () => [
          for (final n in values.keys.toList()..sort())
            EnvNameView(name: n, changedAt: 1, sensitive: sensitive[n] ?? true),
        ],
        get: (n) => values[n],
        set: (n, v, s) {
          values[n] = v;
          sensitive[n] = s;
        },
        setSensitive: (n, s) => sensitive[n] = s,
        delete: (n) => values.remove(n),
      );
}

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  group('the text of the QR code', () {
    test('a variable goes through the code and comes back the same', () {
      const v = EnvShare(name: 'API_KEY', value: 'sk-1 ñ "q"', sensitive: true);
      final back = EnvShare.tryParse(v.encode())!;
      expect(back.name, 'API_KEY');
      expect(back.value, 'sk-1 ñ "q"');
      expect(back.sensitive, isTrue);
    });

    test('a code that is not a variable gives null', () {
      for (final bad in [
        null,
        '',
        'ergo:9f...',
        '{"a":1}',
        '{"chatui_env":1,',
        '{"chatui_env":1,"n":"A","v":"x"}', // no mark
        '{"chatui_env":1,"n":"A","v":1,"s":true}', // value is not text
        '{"chatui_env":1,"n":"1A","v":"x","s":true}', // bad name
        '{"chatui_env":1,"n":"__nodo_instance_name","v":"x","s":true}', // reserved
        '{"chatui_env":1,"n":"A","v":"","s":true}', // empty value
        '{"chatui_env":1,"n":"A","v":"a\\u0000b","s":true}', // NUL
      ]) {
        expect(EnvShare.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('a value that does not fit in a QR code is not shared', () {
      expect(const EnvShare(name: 'A', value: 'x', sensitive: false).fits, isTrue);
      expect(EnvShare(name: 'A', value: 'x' * 3000, sensitive: false).fits, isFalse);
      // A code of that size is not read either.
      expect(EnvShare.tryParse(EnvShare(name: 'A', value: 'x' * 3000, sensitive: false).encode()), isNull);
    });

  });

  group('the screens', () {
    testWidgets('a scanned variable fills the form, and the user can rename it', (tester) async {
      final box = _Box();
      await tester.pumpWidget(_app(EnvVariablesScreen(
        store: box.store,
        scanner: (_) async => const EnvShare(name: 'TOKEN_DE_GITHUB', value: 'abc', sensitive: false),
      )));
      await tester.tap(find.byKey(const Key('env-scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('env-edit')), findsOneWidget);
      expect(find.widgetWithText(TextField, 'TOKEN_DE_GITHUB'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('env-name')), 'GH_TOKEN');
      await tester.tap(find.byKey(const Key('env-save')));
      await tester.pumpAndSettle();
      expect(box.values, {'GH_TOKEN': 'abc'});
      // The mark of the code is the mark of the form.
      expect(box.sensitive['GH_TOKEN'], isFalse);
    });

    testWidgets('a cancelled form saves nothing', (tester) async {
      final box = _Box();
      await tester.pumpWidget(_app(EnvVariablesScreen(
        store: box.store,
        scanner: (_) async => const EnvShare(name: 'TOKEN', value: 'abc', sensitive: true),
      )));
      await tester.tap(find.byKey(const Key('env-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(box.values, isEmpty);
    });

    testWidgets('a row shares its variable by a QR code', (tester) async {
      final box = _Box()..values['KEY'] = 'v1';
      await tester.pumpWidget(_app(EnvVariablesScreen(store: box.store)));
      await tester.tap(find.byKey(const Key('env-share-KEY')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('env-share')), findsOneWidget);
      expect(find.byKey(const Key('env-share-warning')), findsOneWidget);
    });

    Future<List<EnvChoice>?> launch(WidgetTester tester, _Box box, Future<void> Function() steps) async {
      List<EnvChoice>? result;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          key: const Key('open'),
          onPressed: () async {
            result = await Navigator.of(context).push<List<EnvChoice>>(MaterialPageRoute(
              builder: (_) => EnvQuestionsScreen(
                declared: const [DeclaredVariableView(name: 'API_KEY', tags: [], prose: '')],
                store: box.store,
                scanner: (_) async => const EnvShare(name: 'FRIEND_KEY', value: 'sk-9', sensitive: true),
              ),
            ));
          },
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-ask-scan')));
      await tester.pumpAndSettle();
      await steps();
      await tester.tap(find.byKey(const Key('env-typed-use')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a value scanned in a launch is used and not saved unless the user says so', (tester) async {
      final box = _Box();
      final result = await launch(tester, box, () async {});
      expect(result, hasLength(1));
      expect(result!.single.name, 'API_KEY');
      expect(result.single.text, 'sk-9');
      expect(box.values, isEmpty);
    });

    testWidgets('a scanned value is saved under the name of the code, or the one the user types', (tester) async {
      final box = _Box();
      final result = await launch(tester, box, () async {
        await tester.tap(find.byKey(const Key('env-typed-save')));
        await tester.pumpAndSettle();
        // The name of the code is the suggestion.
        expect(find.widgetWithText(TextField, 'FRIEND_KEY'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('env-typed-save-name')), 'MY_KEY');
        await tester.pump();
      });
      expect(result!.single.name, 'API_KEY');
      expect(box.values, {'MY_KEY': 'sk-9'});
      // The mark of the code (sensitive) is kept.
      expect(box.sensitive['MY_KEY'], isTrue);
    });
  });
}
