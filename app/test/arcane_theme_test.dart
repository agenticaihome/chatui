import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:argus_wallet/celaut/cards_effects.dart';
import 'package:argus_wallet/celaut/chat_backgrounds.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/arcane.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/theme/scene_art.dart';
import 'package:argus_wallet/ui/celaut/cards_look.dart';
import 'package:argus_wallet/ui/celaut/launch_rocket.dart';
import 'package:argus_wallet/ui/celaut/raise_rocket.dart';
import 'package:argus_wallet/ui/home/home_scene.dart';
import 'package:argus_wallet/ui/settings/display_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The four house palettes: each house in a dark and a light palette, all in the one
/// arcane look (buttons, cards, the deck's frame and the rocket).
void main() {
  final houses = allPalettes.where((p) => p.isArcane).toList();

  test('the four houses and four more of Harry Potter, each in a dark and a light palette', () {
    expect(houses, hasLength(16));
    expect(houses.where((p) => p.isDark), hasLength(8));
    for (final animal in ['lion', 'serpent', 'raven', 'badger', 'hogwarts', 'patronus', 'forest', 'phoenix']) {
      expect(paletteById('${animal}_night', fallback: Brightness.light).isDark, isTrue);
      expect(paletteById('${animal}_day', fallback: Brightness.dark).isDark, isFalse);
    }
    // The other palettes keep the standard look and folder.
    expect(allPalettes.where((p) => !p.isArcane), hasLength(15));
    for (final p in allPalettes) {
      expect(p.group, p.isArcane ? PaletteGroup.harryPotter : PaletteGroup.standard, reason: p.id);
    }
  });

  for (final p in houses) {
    test('${p.id}: the shared look in the theme, and labels that read on the buttons', () {
      final theme = argusThemeFor(p);
      final colors = theme.extension<ArgusColors>()!;
      expect(colors.isArcane, isTrue);
      expect(colors.trim, p.trim);
      expect(theme.cardTheme.shape, isA<BeveledRectangleBorder>());
      expect(theme.dialogTheme.shape, isA<BeveledRectangleBorder>());
      final filled = theme.filledButtonTheme.style!.shape!.resolve({})!;
      expect(filled, isA<BeveledRectangleBorder>());
      expect(filled.side.color, p.trim);
      expect(theme.outlinedButtonTheme.style!.side!.resolve({})!.color, p.trim);
      // The label of a filled button, and the accent as text on the page and the cards.
      expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5), reason: 'label on a button');
      expect(contrast(p.accentText, p.background), greaterThanOrEqualTo(4.5));
      expect(contrast(p.accentText, p.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(p.heading, p.background), greaterThanOrEqualTo(4.5));
      // The trim shows on the page.
      expect(contrast(p.trim, p.background), greaterThanOrEqualTo(1.8), reason: 'the trim on the page');
    });

    test('${p.id}: the deck\'s card has a frame of the metal and ornaments', () {
      final frame = cardFrameOf(argusThemeFor(p), null, CardsFrames.theme);
      expect(frame.side.color, p.trim);
      expect(frame.ornament, p.trim);
      expect(cardFrameOf(argusThemeFor(p), null, CardsFrames.none).ornament, isNull);
    });
  }

  test('a standard palette keeps the rounded look, no ornaments', () {
    final theme = argusThemeFor(watchfulPalette);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
    expect(cardFrameOf(theme, null, CardsFrames.theme).ornament, isNull);
  });

  Widget host(PaletteSpec p, Widget child) =>
      MaterialApp(theme: argusThemeFor(p), home: Scaffold(body: Center(child: child)));

  testWidgets('the rocket of a house wears its metal and leaves sparks', (tester) async {
    await tester.pumpWidget(host(lionNightPalette, const RocketStage()));
    final painter = tester.widget<CustomPaint>(find.byKey(const Key('launch-rocket'))).painter! as RocketPainter;
    expect(painter.trim, lionNightPalette.trim);
    expect(painter.flame, lionNightPalette.accent);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(host(watchfulPalette, const RocketStage()));
    // The theme changes with an animation of its own.
    await tester.pump(const Duration(seconds: 1));
    final plain = tester.widget<CustomPaint>(find.byKey(const Key('launch-rocket'))).painter! as RocketPainter;
    expect(plain.trim, isNull);
  });

  testWidgets('the raised rocket of an import wears the metal too', (tester) async {
    final stage = GlobalKey<RaiseStageState>();
    await tester.pumpWidget(host(ravenDayPalette, RaiseStage(key: stage)));
    final painter = tester.widget<CustomPaint>(find.byKey(const Key('raise-rocket'))).painter! as RaisePainter;
    expect(painter.trim, ravenDayPalette.trim);
    stage.currentState!.setProgress(0.5);
    await tester.pump(const Duration(milliseconds: 300));
    final done = stage.currentState!.finish();
    await tester.pumpAndSettle();
    await done;
  });

  testWidgets('the launch card of a house is a plaque with ornaments', (tester) async {
    late LaunchRocket rocket;
    await tester.pumpWidget(host(
      badgerNightPalette,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => rocket = LaunchRocket.show(context, name: 'svc'),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final card = tester.widget<Material>(find.byKey(const Key('run-progress')));
    expect(card.shape, isA<BeveledRectangleBorder>());
    expect(find.byType(ArcaneCorners), findsOneWidget);
    rocket.dismiss();
    await tester.pump();
  });

  testWidgets('Display: the palettes in two folders, Standard and Harry Potter', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The palette cards have a fixed height that the font of the tests overflows.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.toString().contains('overflowed')) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DisplaySettingsPage(),
    ));
    await tester.pumpAndSettle();
    // One folder of each kind in the dark section and in the light one.
    expect(find.byKey(const Key('palette-group-standard')), findsNWidgets(2));
    expect(find.byKey(const Key('palette-group-harryPotter')), findsNWidgets(2));
    expect(find.text('Standard'), findsNWidgets(2));
    expect(find.text('Harry Potter'), findsNWidgets(2));
  });

  group('the art of the scene', () {
    test('every Harry Potter palette has its own drawing, the others none', () {
      for (final p in allPalettes) {
        expect(p.art == SceneArt.none, p.group == PaletteGroup.standard, reason: p.id);
        expect(p.scene.art, p.art);
      }
      expect({for (final p in houses) p.art}, SceneArt.values.toSet()..remove(SceneArt.none));
    });

    for (final p in allPalettes) {
      test('${p.id}: the home scene and the chat background paint', () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        ScenePainter(
          spec: p.scene,
          page: p.background,
          light: SceneLight.eclipse,
          lightAt: const Offset(90, 110),
          lightRadius: 70,
          dark: p.isDark,
        ).paint(canvas, const Size(390, 420));
        paintChatThemeBackground(canvas, const Size(390, 700), p.scene, dark: p.isDark);
        ChatBackgroundPainter('theme', p.isDark, scene: p.scene).paint(canvas, const Size(72, 96));
        // An empty size paints nothing and does not throw.
        paintSceneArtBack(canvas, Size.zero, p.scene, dark: p.isDark, light: Offset.zero);
        paintSceneArtFront(canvas, Size.zero, p.scene, dark: p.isDark);
        recorder.endRecording().dispose();
      });
    }

    test('the chat offers the theme\'s background, with its name', () {
      expect(chatBackgrounds.map((b) => b.id), contains('theme'));
      // Without a theme it paints nothing.
      const ChatBackgroundPainter('theme', true).paint(Canvas(ui.PictureRecorder()), const Size(10, 10));
    });
  });
}
