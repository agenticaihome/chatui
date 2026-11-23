import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../argus_theme.dart';
import 'marvel_art.dart';
import 'marvel_look.dart';

// Four heroes of Marvel (a private project, not for sale): each in a dark and a light
// palette that share the [ComicLook]. A hero is evoked by its colours and generic motifs
// only, no emblem and no face. The hero's main colour is the accent, the second colour is
// the trim; as text the dark palettes take a light shade of either, the light ones a deep
// shade.

/// Iron Man: red and gold, the glow of the reactor, by night.
const ironManNightPalette = PaletteSpec(
  id: 'iron_man_night', name: 'Iron Man Night', hint: 'Marvel · red and gold', brightness: Brightness.dark,
  background: Color(0xFF140A0A), surface: Color(0xFF201211), surfaceHigh: Color(0xFF2B1917), ink: Color(0xFFF6EADB), muted: Color(0xFFC9AE9A),
  outline: Color(0xFF5C3328), cardBorder: Color(0xFF472822), chip: Color(0xFF261413),
  accent: Color(0xFFC8102E), onAccent: Color(0xFFFFF4E0), accentText: Color(0xFFF2C14E), heading: Color(0xFFF2C14E),
  sceneGlow: 0.55, look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.ironMan), trim: Color(0xFFE0A82E),
);

/// Iron Man: red and gold on a warm white.
const ironManDayPalette = PaletteSpec(
  id: 'iron_man_day', name: 'Iron Man Day', hint: 'Marvel · red and gold', brightness: Brightness.light,
  background: Color(0xFFFBF4EC), surface: Color(0xFFFFFCF7), surfaceHigh: Color(0xFFF3E3D3), ink: Color(0xFF2A0F0D), muted: Color(0xFF6B4A42),
  outline: Color(0xFFDCC3B0), cardBorder: Color(0xFFEDDCCB), chip: Color(0xFFF6E5D3),
  accent: Color(0xFFB0122A), onAccent: Color(0xFFFFF4E6), accentText: Color(0xFF9E1024), heading: Color(0xFF7E0C1C),
  look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.ironMan), trim: Color(0xFFC8961E),
);

/// Spider-Man: red and blue over the city, by night.
const spiderManNightPalette = PaletteSpec(
  id: 'spider_man_night', name: 'Spider-Man Night', hint: 'Marvel · red and blue, web', brightness: Brightness.dark,
  background: Color(0xFF0A0E1C), surface: Color(0xFF121830), surfaceHigh: Color(0xFF1A2240), ink: Color(0xFFEAEFF8), muted: Color(0xFFA6B0C8),
  outline: Color(0xFF2E3A60), cardBorder: Color(0xFF232D4C), chip: Color(0xFF151C36),
  accent: Color(0xFFD62B35), onAccent: Color(0xFFFFF5F5), accentText: Color(0xFFFF8E8E), heading: Color(0xFF9DBBFF),
  sceneGlow: 0.55, look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.spiderMan), trim: Color(0xFF4A86E8),
);

/// Spider-Man: red and blue on a cool white.
const spiderManDayPalette = PaletteSpec(
  id: 'spider_man_day', name: 'Spider-Man Day', hint: 'Marvel · red and blue, web', brightness: Brightness.light,
  background: Color(0xFFF3F5FB), surface: Color(0xFFFDFDFF), surfaceHigh: Color(0xFFE3E8F4), ink: Color(0xFF0E1630), muted: Color(0xFF4D5878),
  outline: Color(0xFFBCC5DC), cardBorder: Color(0xFFDCE2EF), chip: Color(0xFFE6EBF6),
  accent: Color(0xFFC4161C), onAccent: Color(0xFFFFF5F5), accentText: Color(0xFFB0141A), heading: Color(0xFF14306E),
  look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.spiderMan), trim: Color(0xFF1F4FB5),
);

/// Hulk: gamma green and purple, by night.
const hulkNightPalette = PaletteSpec(
  id: 'hulk_night', name: 'Hulk Night', hint: 'Marvel · gamma green and purple', brightness: Brightness.dark,
  background: Color(0xFF120C18), surface: Color(0xFF1C1424), surfaceHigh: Color(0xFF261C30), ink: Color(0xFFEEE8F2), muted: Color(0xFFB2A6BE),
  outline: Color(0xFF453656), cardBorder: Color(0xFF342843), chip: Color(0xFF1F1628),
  accent: Color(0xFF5BD14A), onAccent: Color(0xFF0A1606), accentText: Color(0xFF8BE36F), heading: Color(0xFF8BE36F),
  sceneGlow: 0.45, look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.hulk), trim: Color(0xFF9B6BD6),
);

/// Hulk: gamma green and purple on a pale green.
const hulkDayPalette = PaletteSpec(
  id: 'hulk_day', name: 'Hulk Day', hint: 'Marvel · gamma green and purple', brightness: Brightness.light,
  background: Color(0xFFF3F7EE), surface: Color(0xFFFCFDF9), surfaceHigh: Color(0xFFE4ECDA), ink: Color(0xFF17211A), muted: Color(0xFF4F5A52),
  outline: Color(0xFFC0CDB6), cardBorder: Color(0xFFDDE5D3), chip: Color(0xFFE6EEDD),
  accent: Color(0xFF2F7D2A), onAccent: Color(0xFFF4FAF0), accentText: Color(0xFF2A6E25), heading: Color(0xFF4A2A78),
  look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.hulk), trim: Color(0xFF6E44A8),
);

/// Thor: a storm of grey-blue and the silver of lightning, by night.
const thorNightPalette = PaletteSpec(
  id: 'thor_night', name: 'Thor Night', hint: 'Marvel · storm and lightning', brightness: Brightness.dark,
  background: Color(0xFF0B1018), surface: Color(0xFF141B26), surfaceHigh: Color(0xFF1C2532), ink: Color(0xFFE8EEF4), muted: Color(0xFFA4B0BE),
  outline: Color(0xFF35414F), cardBorder: Color(0xFF28323F), chip: Color(0xFF161E2A),
  accent: Color(0xFF5B9CF0), onAccent: Color(0xFF071018), accentText: Color(0xFFB8D0EC), heading: Color(0xFFDDE6F0),
  sceneGlow: 0.5, look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.thor), trim: Color(0xFFC9D3DD),
);

/// Thor: a pale storm sky, a deep blue and steel.
const thorDayPalette = PaletteSpec(
  id: 'thor_day', name: 'Thor Day', hint: 'Marvel · storm and lightning', brightness: Brightness.light,
  background: Color(0xFFEFF2F6), surface: Color(0xFFFBFCFD), surfaceHigh: Color(0xFFDFE5EC), ink: Color(0xFF101822), muted: Color(0xFF4C5866),
  outline: Color(0xFFBAC4D0), cardBorder: Color(0xFFD9E0E8), chip: Color(0xFFE2E8EF),
  accent: Color(0xFF2D5A8C), onAccent: Color(0xFFF2F6FA), accentText: Color(0xFF27507E), heading: Color(0xFF1B3554),
  look: comicLook, group: PaletteGroup.marvel, art: MarvelArt(MarvelScene.thor), trim: Color(0xFF7D8A99),
);

/// The Marvel palettes, in the order of the picker.
const marvelPalettes = <PaletteSpec>[
  ironManNightPalette,
  ironManDayPalette,
  spiderManNightPalette,
  spiderManDayPalette,
  hulkNightPalette,
  hulkDayPalette,
  thorNightPalette,
  thorDayPalette,
];

/// The name of a Marvel palette in the language of the app, or null for another id.
String? marvelName(AppLocalizations l, String id) => switch (id) {
      'iron_man_night' => l.themeIronManNightName,
      'iron_man_day' => l.themeIronManDayName,
      'spider_man_night' => l.themeSpiderManNightName,
      'spider_man_day' => l.themeSpiderManDayName,
      'hulk_night' => l.themeHulkNightName,
      'hulk_day' => l.themeHulkDayName,
      'thor_night' => l.themeThorNightName,
      'thor_day' => l.themeThorDayName,
      _ => null,
    };

/// What a Marvel palette looks like, in the language of the app, or null.
String? marvelHint(AppLocalizations l, String id) => switch (id) {
      'iron_man_night' || 'iron_man_day' => l.themeIronManHint,
      'spider_man_night' || 'spider_man_day' => l.themeSpiderManHint,
      'hulk_night' || 'hulk_day' => l.themeHulkHint,
      'thor_night' || 'thor_day' => l.themeThorHint,
      _ => null,
    };
