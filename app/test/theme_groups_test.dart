import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:argus_wallet/l10n/app_localizations.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/theme/scene_art.dart';
import 'package:argus_wallet/ui/celaut/cards_look.dart';
import 'package:argus_wallet/celaut/cards_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// What every group of themed palettes (lib/theme/groups/) must hold: each group a set of
/// dark and light palettes that share one look, a drawing each, names in both languages,
/// and the contrast of the app. The contrast of the home pages and the chat is checked for
/// every palette in home_contrast_test.dart and celaut_chat_contrast_test.dart.
void main() {
  test('the ids of the palettes are unique', () {
    final ids = allPalettes.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  for (final group in PaletteGroup.values.where((g) => g != PaletteGroup.standard)) {
    final palettes = allPalettes.where((p) => p.group == group).toList();
    if (palettes.isEmpty) continue;

    test('${group.name}: dark and light palettes that share one look', () {
      expect(palettes.where((p) => p.isDark), isNotEmpty);
      expect(palettes.where((p) => !p.isDark), isNotEmpty);
      final looks = {for (final p in palettes) p.look.runtimeType};
      expect(looks, hasLength(1), reason: 'one look for the group');
      expect(palettes.first.look, isNotNull);
      // The palettes of a group are listed together.
      final first = allPalettes.indexOf(palettes.first);
      expect(allPalettes.sublist(first, first + palettes.length), palettes);
    });

    for (final locale in AppLocalizations.supportedLocales) {
      test('${group.name}: a name and a hint for each palette in ${locale.languageCode}', () {
        final l = lookupAppLocalizations(locale);
        for (final p in palettes) {
          expect(groupPaletteName(l, p.id), isNotNull, reason: p.id);
          expect(groupPaletteHint(l, p.id), isNotNull, reason: p.id);
        }
        expect(paletteGroupLabel(l, group), isNotEmpty);
      });
    }

    for (final p in palettes) {
      test('${p.id}: its look in the theme, its contrast, its drawing and its card', () {
        final theme = argusThemeFor(p);
        expect(theme.extension<ArgusColors>()!.look, p.look);
        expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5), reason: 'label on a button');
        expect(contrast(p.ink, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.ink, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.muted, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.muted, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.accentText, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.accentText, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.heading, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.trim, p.background), greaterThanOrEqualTo(1.8), reason: 'the trim on the page');
        expect(p.art, isNotNull, reason: 'a drawing of its own');
        final frame = cardFrameOf(theme, null, CardsFrames.theme);
        expect(frame.look, p.look);

        // The look and the drawing paint at every size the app uses, and at none.
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final look = p.look!;
        for (final size in const [Size.zero, Size(72, 96), Size(390, 420), Size(390, 700), Size(1200, 800)]) {
          paintSceneArtBack(canvas, size, p.scene, dark: p.isDark, light: Offset(size.width * 0.8, 60));
          paintSceneArtFront(canvas, size, p.scene, dark: p.isDark);
          paintChatThemeBackground(canvas, size, p.scene, dark: p.isDark);
          look.paintOrnaments(canvas, size, p.trim);
        }
        for (final t in const [0.0, 0.35, 0.5, 1.0]) {
          look.paintRocketDetails(canvas, trim: p.trim, accent: p.accent);
          look.paintRocketTrail(canvas, const Offset(48, 117), t, trim: p.trim, flame: p.accent);
          look.paintRocketBurst(canvas, const Offset(48, 113), t, trim: p.trim, accent: p.accent);
          look.paintRocketRise(canvas, const Offset(24, 103), const Offset(80, 60), t, trim: p.trim);
        }
        recorder.endRecording().dispose();
      });
    }
  }
}
