import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../argus_theme.dart';
import 'gta_art.dart';
import 'gta_look.dart';

// The cities and the police of Grand Theft Auto (a private project, not for sale): each in
// a night and a day palette that share the [StreetLook]. Only colour and generic street
// motifs evoke the games: no logo, no art, no font of theirs. The ids start with "gta_",
// so they stay apart from the ids of the other groups. The main colour of each concept is
// the accent, the second the trim.

/// Vice City: neon pink and teal over an 80s sunset, by night.
const gtaViceNightPalette = PaletteSpec(
  id: 'gta_vice_night', name: 'Vice City Night', hint: 'GTA · neon pink and teal', brightness: Brightness.dark,
  background: Color(0xFF140A22), surface: Color(0xFF1E1030), surfaceHigh: Color(0xFF29173F), ink: Color(0xFFF8E9F4), muted: Color(0xFFC6AACB),
  outline: Color(0xFF4A2E5E), cardBorder: Color(0xFF382349), chip: Color(0xFF22132F),
  accent: Color(0xFFFF4FA3), onAccent: Color(0xFF1A0612), accentText: Color(0xFFFF8CC4), heading: Color(0xFF5EE6D8),
  sceneGlow: 0.55, look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.vice), trim: Color(0xFF2EC4B6),
);

/// Vice City: neon pink and teal on a pastel pink, by day.
const gtaViceDayPalette = PaletteSpec(
  id: 'gta_vice_day', name: 'Vice City Day', hint: 'GTA · neon pink and teal', brightness: Brightness.light,
  background: Color(0xFFFFF2F6), surface: Color(0xFFFFFAFC), surfaceHigh: Color(0xFFFBE2EC), ink: Color(0xFF2A0F24), muted: Color(0xFF6E4763),
  outline: Color(0xFFE7C3D4), cardBorder: Color(0xFFF3D9E4), chip: Color(0xFFFCE5EE),
  accent: Color(0xFFC2186E), onAccent: Color(0xFFFFF3F8), accentText: Color(0xFFAD145F), heading: Color(0xFF0B6A64),
  look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.vice), trim: Color(0xFF1FA89B),
);

/// Los Santos: an orange sunset in a purple haze, by night.
const gtaSantosNightPalette = PaletteSpec(
  id: 'gta_santos_night', name: 'Los Santos Night', hint: 'GTA · orange and purple sunset', brightness: Brightness.dark,
  background: Color(0xFF1A0F1F), surface: Color(0xFF25162B), surfaceHigh: Color(0xFF301D37), ink: Color(0xFFFBEBDD), muted: Color(0xFFCBB0A8),
  outline: Color(0xFF53354F), cardBorder: Color(0xFF3F283F), chip: Color(0xFF2A1830),
  accent: Color(0xFFFF8A2B), onAccent: Color(0xFF1F0C02), accentText: Color(0xFFFFA65A), heading: Color(0xFFFFB870),
  sceneGlow: 0.5, look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.santos), trim: Color(0xFFA77BE8),
);

/// Los Santos: an orange sunset in a purple haze, on a warm sand.
const gtaSantosDayPalette = PaletteSpec(
  id: 'gta_santos_day', name: 'Los Santos Day', hint: 'GTA · orange and purple sunset', brightness: Brightness.light,
  background: Color(0xFFFFF4EA), surface: Color(0xFFFFFBF6), surfaceHigh: Color(0xFFF8E6D6), ink: Color(0xFF2A1420), muted: Color(0xFF6C4C55),
  outline: Color(0xFFE5CBB8), cardBorder: Color(0xFFF1DECE), chip: Color(0xFFFAE8D8),
  accent: Color(0xFFB4470B), onAccent: Color(0xFFFFF6EE), accentText: Color(0xFFA8440C), heading: Color(0xFF5B2A7A),
  look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.santos), trim: Color(0xFF7E4BB8),
);

/// Liberty City: steel grey and taxi yellow, by night.
const gtaLibertyNightPalette = PaletteSpec(
  id: 'gta_liberty_night', name: 'Liberty City Night', hint: 'GTA · steel and taxi yellow', brightness: Brightness.dark,
  background: Color(0xFF101317), surface: Color(0xFF191D23), surfaceHigh: Color(0xFF22272F), ink: Color(0xFFECEFF2), muted: Color(0xFFA9B1BA),
  outline: Color(0xFF39414C), cardBorder: Color(0xFF2B323B), chip: Color(0xFF1C2128),
  accent: Color(0xFFF7C600), onAccent: Color(0xFF141100), accentText: Color(0xFFFFD43B), heading: Color(0xFFFFD43B),
  sceneGlow: 0.3, look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.liberty), trim: Color(0xFFAEB8C2),
);

/// Liberty City: steel grey and taxi yellow, on a pale concrete.
const gtaLibertyDayPalette = PaletteSpec(
  id: 'gta_liberty_day', name: 'Liberty City Day', hint: 'GTA · steel and taxi yellow', brightness: Brightness.light,
  background: Color(0xFFF2F3F5), surface: Color(0xFFFCFCFD), surfaceHigh: Color(0xFFE3E6EA), ink: Color(0xFF14181D), muted: Color(0xFF4F5862),
  outline: Color(0xFFC3C9D0), cardBorder: Color(0xFFDDE1E6), chip: Color(0xFFE6E9ED),
  accent: Color(0xFFE0A800), onAccent: Color(0xFF14181D), accentText: Color(0xFF7A5C00), heading: Color(0xFF14181D),
  look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.liberty), trim: Color(0xFF5E6874),
);

/// Wanted: the red and blue of the police lights, by night.
const gtaWantedNightPalette = PaletteSpec(
  id: 'gta_wanted_night', name: 'Wanted Night', hint: 'GTA · police red and blue', brightness: Brightness.dark,
  background: Color(0xFF0C0D16), surface: Color(0xFF151724), surfaceHigh: Color(0xFF1E2132), ink: Color(0xFFEEF0F8), muted: Color(0xFFA8ACC2),
  outline: Color(0xFF353A55), cardBorder: Color(0xFF272B40), chip: Color(0xFF181B2A),
  accent: Color(0xFFD42A35), onAccent: Color(0xFFFFF5F5), accentText: Color(0xFFFF6B73), heading: Color(0xFF8DB2FF),
  sceneGlow: 0.5, look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.wanted), trim: Color(0xFF3D7BFF),
);

/// Wanted: the red and blue of the police lights, on a cold white.
const gtaWantedDayPalette = PaletteSpec(
  id: 'gta_wanted_day', name: 'Wanted Day', hint: 'GTA · police red and blue', brightness: Brightness.light,
  background: Color(0xFFF3F4F9), surface: Color(0xFFFCFCFF), surfaceHigh: Color(0xFFE4E7F1), ink: Color(0xFF10132A), muted: Color(0xFF4D5270),
  outline: Color(0xFFC2C7DA), cardBorder: Color(0xFFDDE0EC), chip: Color(0xFFE7EAF4),
  accent: Color(0xFFC4161F), onAccent: Color(0xFFFFF4F4), accentText: Color(0xFFB0141C), heading: Color(0xFF1A3A9E),
  look: streetLook, group: PaletteGroup.gta, art: GtaArt(GtaScene.wanted), trim: Color(0xFF2457D6),
);

/// The Grand Theft Auto palettes, in the order of the picker.
const gtaPalettes = [
  gtaViceNightPalette,
  gtaViceDayPalette,
  gtaSantosNightPalette,
  gtaSantosDayPalette,
  gtaLibertyNightPalette,
  gtaLibertyDayPalette,
  gtaWantedNightPalette,
  gtaWantedDayPalette,
];

/// The name of a Grand Theft Auto palette in the language of the app, or null for another id.
String? gtaName(AppLocalizations l, String id) => switch (id) {
      'gta_vice_night' => l.themeGtaViceNightName,
      'gta_vice_day' => l.themeGtaViceDayName,
      'gta_santos_night' => l.themeGtaSantosNightName,
      'gta_santos_day' => l.themeGtaSantosDayName,
      'gta_liberty_night' => l.themeGtaLibertyNightName,
      'gta_liberty_day' => l.themeGtaLibertyDayName,
      'gta_wanted_night' => l.themeGtaWantedNightName,
      'gta_wanted_day' => l.themeGtaWantedDayName,
      _ => null,
    };

/// What a Grand Theft Auto palette looks like, in the language of the app, or null.
String? gtaHint(AppLocalizations l, String id) => switch (id) {
      'gta_vice_night' || 'gta_vice_day' => l.themeGtaViceHint,
      'gta_santos_night' || 'gta_santos_day' => l.themeGtaSantosHint,
      'gta_liberty_night' || 'gta_liberty_day' => l.themeGtaLibertyHint,
      'gta_wanted_night' || 'gta_wanted_day' => l.themeGtaWantedHint,
      _ => null,
    };
