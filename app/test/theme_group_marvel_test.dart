import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/theme/groups/marvel_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the Marvel palettes hold beyond what every group holds (theme_groups_test.dart):
/// four heroes, each by night and by day, in the comic look.
void main() {
  final palettes = allPalettes.where((p) => p.group == PaletteGroup.marvel).toList();

  test('four heroes, each by night and then by day', () {
    expect(palettes.map((p) => p.id), [
      'iron_man_night', 'iron_man_day', 'spider_man_night', 'spider_man_day',
      'hulk_night', 'hulk_day', 'thor_night', 'thor_day',
    ]);
    for (var i = 0; i < palettes.length; i += 2) {
      expect(palettes[i].isDark, isTrue, reason: palettes[i].id);
      expect(palettes[i + 1].isDark, isFalse, reason: palettes[i + 1].id);
      expect(palettes[i].art.runtimeType, palettes[i + 1].art.runtimeType);
    }
  });

  test('a panel of the comic: two corners cut deep, two a little, and an ink edge', () {
    const look = comicLook;
    final shape = look.shape(20) as BeveledRectangleBorder;
    final corners = shape.borderRadius as BorderRadius;
    expect(corners.topLeft.x, greaterThan(corners.topRight.x));
    expect(corners.bottomRight.x, greaterThan(corners.bottomLeft.x));
    for (final p in palettes) {
      final edge = look.edge(p);
      expect(edge.width, 2);
      // On a light page the edge is the ink; on a dark one the trim, which shows on it.
      expect(edge.color.withValues(alpha: 1), p.isDark ? p.trim : p.ink, reason: p.id);
    }
    expect(look.buttonText?.fontStyle, FontStyle.italic);
  });

  test('a starburst keeps within its radius', () {
    const c = Offset(50, 50);
    final bounds = starburstPath(c, 20, points: 11, spin: 0.3).getBounds();
    expect(bounds.left, greaterThanOrEqualTo(30 - 0.001));
    expect(bounds.right, lessThanOrEqualTo(70 + 0.001));
    expect(bounds.top, greaterThanOrEqualTo(30 - 0.001));
    expect(bounds.bottom, lessThanOrEqualTo(70 + 0.001));
  });
}
