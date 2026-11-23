import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/theme/groups/christmas_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Christmas palettes: four scenes, each in a dark and a light palette, in the one
/// Christmas look (soft round outlines and a ribbon of the trim).
void main() {
  final palettes = allPalettes.where((p) => p.group == PaletteGroup.christmas).toList();

  test('four scenes of Christmas, each in a dark and a light palette', () {
    expect(palettes, hasLength(8));
    for (final scene in ['eve', 'snow', 'ginger', 'tree']) {
      expect(paletteById('xmas_${scene}_night', fallback: Brightness.light).isDark, isTrue);
      expect(paletteById('xmas_${scene}_day', fallback: Brightness.dark).isDark, isFalse);
    }
    for (final p in palettes) {
      expect(p.look, isA<ChristmasLook>(), reason: p.id);
    }
  });

  for (final p in palettes) {
    test('${p.id}: round outlines with a ribbon of the trim', () {
      final theme = argusThemeFor(p);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      final filled = theme.filledButtonTheme.style!.shape!.resolve({})!;
      expect(filled, isA<RoundedRectangleBorder>());
      expect(filled.side.color, p.trim);
      expect(filled.side.width, greaterThan(1.6));
    });
  }
}
