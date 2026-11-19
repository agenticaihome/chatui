import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/celaut/catalog_types.dart';
import 'package:argus_wallet/l10n/app_localizations.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/objective_picker.dart';
import 'package:argus_wallet/ui/celaut/run_service_section.dart';
import 'package:argus_wallet/ui/settings/registry_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The type ids of the Celaut Registry: the Objective id is empty by default, the other three
// have a default, and the user can change all of them in Settings, Compute, "Celaut Registry".

final _id = 'ab' * 32;
final _id2 = 'cd' * 32;

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: argusTheme(watchful: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CatalogTypes', () {
    test('the Objective id is empty, the others have their default', () {
      final types = CatalogTypes();
      expect(types.objective, '');
      expect(types.hasObjective, isFalse);
      final ids = types.ids;
      expect(ids.objective, '');
      expect(ids.coverage, defaultCoverageTypeId);
      expect(ids.benchmark, defaultBenchmarkTypeId);
      expect(ids.result, defaultResultTypeId);
      expect(isCatalogTypeId(ids.coverage), isTrue);
      expect(isCatalogTypeId(ids.benchmark), isTrue);
      expect(isCatalogTypeId(ids.result), isTrue);
    });

    test('the ids are checked: 64 hexadecimal characters, or empty for the Objective', () {
      expect(CatalogTypeKind.objective.accepts(''), isTrue);
      expect(CatalogTypeKind.objective.accepts('   '), isTrue);
      expect(CatalogTypeKind.objective.accepts(_id), isTrue);
      expect(CatalogTypeKind.objective.accepts(' $_id '), isTrue);
      expect(CatalogTypeKind.objective.accepts(_id.toUpperCase()), isTrue);
      for (final kind in CatalogTypeKind.values) {
        expect(kind.accepts('abc'), isFalse, reason: kind.name);
        expect(kind.accepts('g' * 64), isFalse, reason: kind.name);
        expect(kind.accepts('a' * 63), isFalse, reason: kind.name);
        expect(kind.accepts('a' * 65), isFalse, reason: kind.name);
      }
      expect(CatalogTypeKind.coverage.accepts(''), isFalse);
      expect(CatalogTypeKind.benchmark.accepts(''), isFalse);
      expect(CatalogTypeKind.result.accepts(''), isFalse);
    });

    test('a saved id is kept in lower case, and is read again after a restart', () async {
      final types = CatalogTypes();
      await types.save({CatalogTypeKind.objective: ' ${_id.toUpperCase()} ', CatalogTypeKind.result: _id2});
      expect(types.objective, _id);
      expect(types.hasObjective, isTrue);
      expect(types.ids.result, _id2);
      expect(types.ids.coverage, defaultCoverageTypeId);

      final again = CatalogTypes();
      await again.load();
      expect(again.objective, _id);
      expect(again.ids.result, _id2);
    });

    test('an id that is not valid is refused and nothing changes', () async {
      final types = CatalogTypes();
      await expectLater(
        types.save({CatalogTypeKind.objective: _id, CatalogTypeKind.coverage: 'nope'}),
        throwsArgumentError,
      );
      expect(types.objective, '');
      expect(types.ids.coverage, defaultCoverageTypeId);
      final again = CatalogTypes();
      await again.load();
      expect(again.objective, '');
    });

    test('a saved id that is not valid is ignored when it is read', () async {
      SharedPreferences.setMockInitialValues({
        'celaut_registry_type_objective': 'not an id',
        'celaut_registry_type_coverage': '',
        'celaut_registry_type_benchmark': _id,
      });
      final types = CatalogTypes();
      await types.load();
      expect(types.objective, '');
      expect(types.ids.coverage, defaultCoverageTypeId);
      expect(types.ids.benchmark, _id);
    });

    test('restore default sets the default and saves it', () async {
      final types = CatalogTypes();
      await types.save({CatalogTypeKind.objective: _id, CatalogTypeKind.benchmark: _id2});
      await types.restoreDefault(CatalogTypeKind.objective);
      await types.restoreDefault(CatalogTypeKind.benchmark);
      expect(types.objective, '');
      expect(types.ids.benchmark, defaultBenchmarkTypeId);
      final again = CatalogTypes();
      await again.load();
      expect(again.objective, '');
      expect(again.ids.benchmark, defaultBenchmarkTypeId);
    });
  });

  group('the settings page', () {
    testWidgets('it shows the ids: the Objective is empty, the others have the default', (tester) async {
      await _pump(tester, RegistrySettingsPage(types: CatalogTypes()));
      expect(find.text('Celaut Registry'), findsOneWidget);
      expect(find.byKey(const Key('registry-intro')), findsOneWidget);
      expect(_text(tester, 'registry-type-objective'), '');
      expect(_text(tester, 'registry-type-benchmark'), defaultBenchmarkTypeId);
      expect(_text(tester, 'registry-type-coverage'), defaultCoverageTypeId);
      expect(_text(tester, 'registry-type-result'), defaultResultTypeId);
      expect(find.text('Empty by default. With no id, the catalog is empty.'), findsOneWidget);
    });

    testWidgets('an id that is not valid shows an error and is not saved', (tester) async {
      final types = CatalogTypes();
      await _pump(tester, RegistrySettingsPage(types: types));
      await tester.enterText(find.byKey(const Key('registry-type-objective')), 'abc');
      await tester.enterText(find.byKey(const Key('registry-type-result')), '');
      await tester.pump();
      expect(find.text('Enter 64 hexadecimal characters, or leave it empty.'), findsOneWidget);
      expect(find.text('Enter 64 hexadecimal characters.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('registry-save')));
      await tester.pumpAndSettle();
      expect(types.objective, '');
      expect(types.ids.result, defaultResultTypeId);
      expect(find.text('Type ids saved.'), findsNothing);
    });

    testWidgets('a valid id is saved, in lower case', (tester) async {
      final types = CatalogTypes();
      await _pump(tester, RegistrySettingsPage(types: types));
      await tester.enterText(find.byKey(const Key('registry-type-objective')), ' ${_id.toUpperCase()} ');
      await tester.pump();
      expect(find.text('Enter 64 hexadecimal characters, or leave it empty.'), findsNothing);
      await tester.tap(find.byKey(const Key('registry-save')));
      await tester.pumpAndSettle();
      expect(types.objective, _id);
      expect(_text(tester, 'registry-type-objective'), _id);
      expect(find.text('Type ids saved.'), findsOneWidget);
    });

    testWidgets('Restore default puts the default back in the field and in the saved value', (tester) async {
      final types = CatalogTypes();
      await types.save({CatalogTypeKind.objective: _id, CatalogTypeKind.coverage: _id2});
      await _pump(tester, RegistrySettingsPage(types: types));
      expect(_text(tester, 'registry-type-objective'), _id);
      await tester.tap(find.byKey(const Key('registry-restore-objective')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'registry-type-objective'), '');
      expect(types.objective, '');
      await tester.tap(find.byKey(const Key('registry-restore-coverage')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'registry-type-coverage'), defaultCoverageTypeId);
      expect(types.ids.coverage, defaultCoverageTypeId);
    });
  });

  group('the empty state', () {
    testWidgets('the picker says that the objective type id is not set, and reads nothing', (tester) async {
      await _pump(tester, ObjectivePickerScreen(types: CatalogTypes()));
      expect(find.byKey(const Key('objective-type-missing')), findsOneWidget);
      expect(find.text('No objective type id'), findsOneWidget);
      expect(find.byKey(const Key('picker-error')), findsNothing);
      expect(find.byKey(const Key('picker-loading')), findsNothing);
    });

    testWidgets('the store of the Run screen shows the same state', (tester) async {
      await _pump(tester, Scaffold(body: RunServiceSection(types: CatalogTypes(), showTitle: false)));
      expect(find.byKey(const Key('objective-type-missing')), findsOneWidget);
      expect(find.text('No objective type id'), findsOneWidget);
      expect(find.byKey(const Key('run-error')), findsNothing);
      expect(find.byKey(const Key('run-empty')), findsNothing);
    });

    testWidgets('the button opens the settings of the registry', (tester) async {
      await _pump(tester, Scaffold(body: RunServiceSection(types: CatalogTypes(), showTitle: false)));
      await tester.tap(find.byKey(const Key('objective-type-open-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrySettingsPage), findsOneWidget);
    });

    testWidgets('with an objective id the store reads the catalog', (tester) async {
      final types = CatalogTypes();
      await types.save({CatalogTypeKind.objective: _id});
      var asked = 0;
      await _pump(
        tester,
        Scaffold(
          body: RunServiceSection(
            types: types,
            showTitle: false,
            loadObjectives: () async {
              asked++;
              return const <ObjectiveView>[];
            },
          ),
        ),
      );
      expect(asked, 1);
      expect(find.byKey(const Key('objective-type-missing')), findsNothing);
      expect(find.byKey(const Key('run-empty')), findsOneWidget);
    });
  });
}
