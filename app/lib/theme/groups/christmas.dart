import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../argus_theme.dart';
import 'christmas_art.dart';
import 'christmas_look.dart';

// The Christmas palettes (folder [PaletteGroup.christmas]): four scenes of Christmas, each
// in a dark and a light palette that share the [ChristmasLook]. Christmas Eve is red, pine
// and gold over a village; Snow is ice white and silver blue over snowy pines; Gingerbread
// is ginger, icing and red; the Tree is pine green under warm golden lights. The trim is
// the second colour of each: the gold, the ice, the icing or the lights.

/// Christmas Eve: a wine-dark night, a red accent and gold, over the village.
const christmasEveNightPalette = PaletteSpec(
  id: 'xmas_eve_night', name: 'Christmas Eve', hint: 'Christmas · red, pine and gold', brightness: Brightness.dark,
  background: Color(0xFF1A0B0E), surface: Color(0xFF261317), surfaceHigh: Color(0xFF311A1F), ink: Color(0xFFF7ECDF), muted: Color(0xFFC6AFA3),
  outline: Color(0xFF5A3238), cardBorder: Color(0xFF45262B), chip: Color(0xFF2C161A),
  accent: Color(0xFFC62F2F), onAccent: Color(0xFFFFF4E6), accentText: Color(0xFFEBC46A), heading: Color(0xFFEBC46A),
  sceneGlow: 0.5, look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.village), trim: Color(0xFFD9A93E),
);

/// Christmas morning: a cream page, the red, the pine green as text, and gold.
const christmasEveDayPalette = PaletteSpec(
  id: 'xmas_eve_day', name: 'Christmas Morning', hint: 'Christmas · red, pine and gold', brightness: Brightness.light,
  background: Color(0xFFFBF6EC), surface: Color(0xFFFFFCF6), surfaceHigh: Color(0xFFF2E8D6), ink: Color(0xFF15231B), muted: Color(0xFF4E5A50),
  outline: Color(0xFFD6CCB6), cardBorder: Color(0xFFEAE0CC), chip: Color(0xFFF3EAD8),
  accent: Color(0xFFB3242B), onAccent: Color(0xFFFFF5EA), accentText: Color(0xFF1D5A36), heading: Color(0xFF9A1C22),
  look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.village), trim: Color(0xFFC59A2C),
);

/// Snow: a deep blue night, silver blue and ice white.
const christmasSnowNightPalette = PaletteSpec(
  id: 'xmas_snow_night', name: 'Snowy Night', hint: 'Christmas · ice white and silver blue', brightness: Brightness.dark,
  background: Color(0xFF0C1322), surface: Color(0xFF141D30), surfaceHigh: Color(0xFF1C273D), ink: Color(0xFFEEF4FB), muted: Color(0xFFA6B4C8),
  outline: Color(0xFF2E3B55), cardBorder: Color(0xFF233049), chip: Color(0xFF172136),
  accent: Color(0xFF9CC4E8), onAccent: Color(0xFF0A1424), accentText: Color(0xFFBFDBF3), heading: Color(0xFFE4EFF9),
  sceneGlow: 0.45, look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.snow), trim: Color(0xFFE2ECF5),
);

/// Snow: an ice-white day, a deep silver blue, the trim of frosted silver.
const christmasSnowDayPalette = PaletteSpec(
  id: 'xmas_snow_day', name: 'Snowy Day', hint: 'Christmas · ice white and silver blue', brightness: Brightness.light,
  background: Color(0xFFF3F7FB), surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFE4ECF4), ink: Color(0xFF102033), muted: Color(0xFF4B5B70),
  outline: Color(0xFFC3D0DE), cardBorder: Color(0xFFDDE6EF), chip: Color(0xFFE7EEF5),
  accent: Color(0xFF2F6596), onAccent: Color(0xFFF5F9FD), accentText: Color(0xFF275680), heading: Color(0xFF1A3D5E),
  look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.snow), trim: Color(0xFF8EA4BA),
);

/// Gingerbread: a dark baked brown, a candy red, the icing as the trim.
const christmasGingerNightPalette = PaletteSpec(
  id: 'xmas_ginger_night', name: 'Gingerbread Night', hint: 'Christmas · ginger, icing and red', brightness: Brightness.dark,
  background: Color(0xFF1A110B), surface: Color(0xFF261A11), surfaceHigh: Color(0xFF312217), ink: Color(0xFFF8EDE0), muted: Color(0xFFC7AE96),
  outline: Color(0xFF573D2B), cardBorder: Color(0xFF433022), chip: Color(0xFF2C1E14),
  accent: Color(0xFFE0524A), onAccent: Color(0xFF1C0805), accentText: Color(0xFFE9A86A), heading: Color(0xFFE9A86A),
  sceneGlow: 0.5, look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.gingerbread), trim: Color(0xFFF3E6D6),
);

/// Gingerbread: a page of icing, the ginger as the accent, the candy red as the trim.
const christmasGingerDayPalette = PaletteSpec(
  id: 'xmas_ginger_day', name: 'Gingerbread Day', hint: 'Christmas · ginger, icing and red', brightness: Brightness.light,
  background: Color(0xFFFBF3E8), surface: Color(0xFFFFFAF3), surfaceHigh: Color(0xFFF3E3CF), ink: Color(0xFF2B170B), muted: Color(0xFF6A4B36),
  outline: Color(0xFFDEC5A8), cardBorder: Color(0xFFEEDCC6), chip: Color(0xFFF5E5D1),
  accent: Color(0xFF9C5524), onAccent: Color(0xFFFFF6EC), accentText: Color(0xFF8A4A1E), heading: Color(0xFFA3262A),
  look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.gingerbread), trim: Color(0xFFC9413A),
);

/// The Christmas tree: a pine night under warm golden lights.
const christmasTreeNightPalette = PaletteSpec(
  id: 'xmas_tree_night', name: 'Christmas Tree Night', hint: 'Christmas · pine green and golden lights', brightness: Brightness.dark,
  background: Color(0xFF08140E), surface: Color(0xFF0F1F16), surfaceHigh: Color(0xFF17291E), ink: Color(0xFFF1F3E6), muted: Color(0xFFA9B8A4),
  outline: Color(0xFF2A4232), cardBorder: Color(0xFF1F3326), chip: Color(0xFF122219),
  accent: Color(0xFF3FA162), onAccent: Color(0xFF04140A), accentText: Color(0xFFF2C25A), heading: Color(0xFFF2C25A),
  sceneGlow: 0.5, look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.tree), trim: Color(0xFFF5B942),
);

/// The Christmas tree: a pale pine page by day, the pine as the accent, gold lights.
const christmasTreeDayPalette = PaletteSpec(
  id: 'xmas_tree_day', name: 'Christmas Tree Day', hint: 'Christmas · pine green and golden lights', brightness: Brightness.light,
  background: Color(0xFFF2F7F0), surface: Color(0xFFFBFDFA), surfaceHigh: Color(0xFFE2EDE0), ink: Color(0xFF0F2418), muted: Color(0xFF4A5E50),
  outline: Color(0xFFBCCDBD), cardBorder: Color(0xFFD9E5D8), chip: Color(0xFFE4EEE2),
  accent: Color(0xFF1F6B3E), onAccent: Color(0xFFF3FAF4), accentText: Color(0xFF1B5E36), heading: Color(0xFF15492A),
  look: christmasLook, group: PaletteGroup.christmas, art: ChristmasArt(ChristmasScene.tree), trim: Color(0xFFC8962A),
);

/// The Christmas palettes, in the order of the picker.
const christmasPalettes = [
  christmasEveNightPalette,
  christmasEveDayPalette,
  christmasSnowNightPalette,
  christmasSnowDayPalette,
  christmasGingerNightPalette,
  christmasGingerDayPalette,
  christmasTreeNightPalette,
  christmasTreeDayPalette,
];

/// The name of a Christmas palette in the language of the app, or null for another id.
String? christmasName(AppLocalizations l, String id) => switch (id) {
      'xmas_eve_night' => l.themeXmasEveNightName,
      'xmas_eve_day' => l.themeXmasEveDayName,
      'xmas_snow_night' => l.themeXmasSnowNightName,
      'xmas_snow_day' => l.themeXmasSnowDayName,
      'xmas_ginger_night' => l.themeXmasGingerNightName,
      'xmas_ginger_day' => l.themeXmasGingerDayName,
      'xmas_tree_night' => l.themeXmasTreeNightName,
      'xmas_tree_day' => l.themeXmasTreeDayName,
      _ => null,
    };

/// What a Christmas palette looks like, in the language of the app, or null.
String? christmasHint(AppLocalizations l, String id) => switch (id) {
      'xmas_eve_night' || 'xmas_eve_day' => l.themeXmasEveHint,
      'xmas_snow_night' || 'xmas_snow_day' => l.themeXmasSnowHint,
      'xmas_ginger_night' || 'xmas_ginger_day' => l.themeXmasGingerHint,
      'xmas_tree_night' || 'xmas_tree_day' => l.themeXmasTreeHint,
      _ => null,
    };
