import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/theme/groups/cyberpunk_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Cyberpunk palettes: four concepts, each by night and by day, in the neon look. The
/// standard palette 'cyberpunk' stays in the Standard folder.
void main() {
  final palettes = allPalettes.where((p) => p.group == PaletteGroup.cyberpunk).toList();

  test('four concepts, each in a dark and a light palette', () {
    expect(palettes, hasLength(8));
    for (final concept in ['city', 'noir', 'netrunner', 'rain']) {
      expect(paletteById('cyber_${concept}_night', fallback: Brightness.light).isDark, isTrue);
      expect(paletteById('cyber_${concept}_day', fallback: Brightness.dark).isDark, isFalse);
    }
    expect(paletteById('cyberpunk', fallback: Brightness.light).group, PaletteGroup.standard);
    expect(paletteById('cyberpunk', fallback: Brightness.light).look, isNull);
  });

  for (final p in palettes) {
    test('${p.id}: HUD corners, a neon edge and labels in the mono font', () {
      expect(p.look, isA<NeonLook>());
      final theme = argusThemeFor(p);
      final card = theme.cardTheme.shape! as BeveledRectangleBorder;
      final corners = card.borderRadius.resolve(TextDirection.ltr);
      // The top left and the bottom right are cut deeper than the other two.
      expect(corners.topLeft.x, greaterThan(corners.topRight.x));
      expect(corners.bottomRight.x, greaterThan(corners.bottomLeft.x));
      final filled = theme.filledButtonTheme.style!;
      expect(filled.shape!.resolve({})!.side.color, p.trim);
      expect(filled.textStyle!.resolve({})!.fontFamily, 'IBMPlexMono');
    });
  }
}
