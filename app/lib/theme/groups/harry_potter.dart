import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../arcane.dart';
import '../argus_theme.dart';
import '../scene_art.dart';

// The four houses of Hogwarts, from Harry Potter (a private project, not for sale): each in
// a dark and a light palette that share the [ArcaneLook]. The ids keep the
// animal of each house (lion, serpent, raven, badger), so stored choices still resolve if
// the names change. The house colour is the accent,
// the metal is the trim; as text the dark palettes take the metal, which reads on the
// night page, and the light ones a deep shade of the house colour.

/// Gryffindor, the lion: scarlet and gold, by night.
const lionNightPalette = PaletteSpec(
  id: 'lion_night', name: 'Gryffindor Night', hint: 'Harry Potter · scarlet and gold', brightness: Brightness.dark,
  background: Color(0xFF1A0E0E), surface: Color(0xFF261515), surfaceHigh: Color(0xFF311C1B), ink: Color(0xFFF4E8D4), muted: Color(0xFFC4AE98),
  outline: Color(0xFF5A3A30), cardBorder: Color(0xFF452B26), chip: Color(0xFF2C1918),
  accent: Color(0xFFC0392B), onAccent: Color(0xFFFFF4E0), accentText: Color(0xFFF0C766), heading: Color(0xFFF0C766),
  sceneGlow: 0.5, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFFD4A537),
);

/// Gryffindor, the lion: scarlet and gold, on parchment.
const lionDayPalette = PaletteSpec(
  id: 'lion_day', name: 'Gryffindor Day', hint: 'Harry Potter · scarlet and gold', brightness: Brightness.light,
  background: Color(0xFFFBF3E6), surface: Color(0xFFFFFBF4), surfaceHigh: Color(0xFFF3E4CF), ink: Color(0xFF2B1210), muted: Color(0xFF6B4A40),
  outline: Color(0xFFD8C2A6), cardBorder: Color(0xFFEADBC4), chip: Color(0xFFF5E6D0),
  accent: Color(0xFF9E1B22), onAccent: Color(0xFFFFF3DC), accentText: Color(0xFF8C1A1F), heading: Color(0xFF7A1418),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFFC99A2E),
);

/// Slytherin, the serpent: emerald and silver, by night.
const serpentNightPalette = PaletteSpec(
  id: 'serpent_night', name: 'Slytherin Night', hint: 'Harry Potter · emerald and silver', brightness: Brightness.dark,
  background: Color(0xFF0A1511), surface: Color(0xFF12201A), surfaceHigh: Color(0xFF1A2B23), ink: Color(0xFFE6EEE9), muted: Color(0xFFA4B5AB),
  outline: Color(0xFF2F4A3C), cardBorder: Color(0xFF243A2F), chip: Color(0xFF15251E),
  accent: Color(0xFF34A065), onAccent: Color(0xFF04140C), accentText: Color(0xFFC9D3D8), heading: Color(0xFFC9D3D8),
  sceneGlow: 0.6, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFFB8C2C8),
);

/// Slytherin, the serpent: emerald and silver, on a pale green-grey.
const serpentDayPalette = PaletteSpec(
  id: 'serpent_day', name: 'Slytherin Day', hint: 'Harry Potter · emerald and silver', brightness: Brightness.light,
  background: Color(0xFFF2F5F0), surface: Color(0xFFFBFDFA), surfaceHigh: Color(0xFFE3EBE4), ink: Color(0xFF0F241A), muted: Color(0xFF4E6357),
  outline: Color(0xFFB9C7BD), cardBorder: Color(0xFFD9E2DB), chip: Color(0xFFE6EEE8),
  accent: Color(0xFF1A5E3A), onAccent: Color(0xFFF1F5F2), accentText: Color(0xFF16512F), heading: Color(0xFF124A2C),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFF8A949A),
);

/// Ravenclaw, the raven: sapphire and bronze, by night.
const ravenNightPalette = PaletteSpec(
  id: 'raven_night', name: 'Ravenclaw Night', hint: 'Harry Potter · blue and bronze', brightness: Brightness.dark,
  background: Color(0xFF0B1020), surface: Color(0xFF141B30), surfaceHigh: Color(0xFF1C2540), ink: Color(0xFFE6EAF4), muted: Color(0xFFA3ADC6),
  outline: Color(0xFF2E3A5C), cardBorder: Color(0xFF242F4C), chip: Color(0xFF172038),
  accent: Color(0xFF5A82D4), onAccent: Color(0xFF050B1A), accentText: Color(0xFFD9A066), heading: Color(0xFFD9A066),
  sceneGlow: 0.5, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFFCD8A4E),
);

/// Ravenclaw, the raven: sapphire and bronze, on a cool white.
const ravenDayPalette = PaletteSpec(
  id: 'raven_day', name: 'Ravenclaw Day', hint: 'Harry Potter · blue and bronze', brightness: Brightness.light,
  background: Color(0xFFF1F4FA), surface: Color(0xFFFCFDFF), surfaceHigh: Color(0xFFE1E7F2), ink: Color(0xFF0E1A33), muted: Color(0xFF4E5B75),
  outline: Color(0xFFBCC6D8), cardBorder: Color(0xFFDCE2EE), chip: Color(0xFFE5EBF5),
  accent: Color(0xFF1E3F7A), onAccent: Color(0xFFF2F5FB), accentText: Color(0xFF1E3F7A), heading: Color(0xFF1A356A),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFFA8703A),
);

/// Hufflepuff, the badger: honey yellow and black, by night. The page is the black; the trim is a pale
/// honey, as a black edge does not show on it.
const badgerNightPalette = PaletteSpec(
  id: 'badger_night', name: 'Hufflepuff Night', hint: 'Harry Potter · yellow and black', brightness: Brightness.dark,
  background: Color(0xFF12100B), surface: Color(0xFF1D1A12), surfaceHigh: Color(0xFF27231A), ink: Color(0xFFF4EEDC), muted: Color(0xFFB5AC94),
  outline: Color(0xFF453D2A), cardBorder: Color(0xFF332D1F), chip: Color(0xFF221E15),
  accent: Color(0xFFEDB82F), onAccent: Color(0xFF14110A), accentText: Color(0xFFF2C653), heading: Color(0xFFF2C653),
  sceneGlow: 0.4, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFFE8D29A),
);

/// Hufflepuff, the badger: honey yellow and black, on a warm cream.
const badgerDayPalette = PaletteSpec(
  id: 'badger_day', name: 'Hufflepuff Day', hint: 'Harry Potter · yellow and black', brightness: Brightness.light,
  background: Color(0xFFFCF7E6), surface: Color(0xFFFFFDF5), surfaceHigh: Color(0xFFF4EACB), ink: Color(0xFF1E1A12), muted: Color(0xFF5E5440),
  outline: Color(0xFFD9CCA2), cardBorder: Color(0xFFEDE3C4), chip: Color(0xFFF6EBC6),
  accent: Color(0xFFE0A526), onAccent: Color(0xFF1E1A12), accentText: Color(0xFF7A5300), heading: Color(0xFF1E1A12),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.greatHall), trim: Color(0xFF2A241A),
);

// More of Harry Potter, in the same arcane look and folder as the houses: the castle, the
// Patronus charm, the Forbidden Forest and the Order of the Phoenix.

/// Hogwarts: the castle's stone by night under candle gold.
const hogwartsNightPalette = PaletteSpec(
  id: 'hogwarts_night', name: 'Hogwarts Night', hint: 'Harry Potter · stone and candlelight', brightness: Brightness.dark,
  background: Color(0xFF10121A), surface: Color(0xFF1A1D28), surfaceHigh: Color(0xFF232735), ink: Color(0xFFEDE6D6), muted: Color(0xFFADA896),
  outline: Color(0xFF3A3D4C), cardBorder: Color(0xFF2C2F3D), chip: Color(0xFF1D2030),
  accent: Color(0xFFE0B252), onAccent: Color(0xFF1A1408), accentText: Color(0xFFE9C377), heading: Color(0xFFE9C377),
  sceneGlow: 0.45, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.castle), trim: Color(0xFFC9B48A),
);

/// Hogwarts: pale stone by day, a burgundy banner and gold.
const hogwartsDayPalette = PaletteSpec(
  id: 'hogwarts_day', name: 'Hogwarts Day', hint: 'Harry Potter · stone and candlelight', brightness: Brightness.light,
  background: Color(0xFFF4F1EA), surface: Color(0xFFFDFBF6), surfaceHigh: Color(0xFFE8E3D7), ink: Color(0xFF1E1C24), muted: Color(0xFF5C5866),
  outline: Color(0xFFCBC5B6), cardBorder: Color(0xFFE2DDD0), chip: Color(0xFFEBE6DA),
  accent: Color(0xFF6E2632), onAccent: Color(0xFFFBF1DE), accentText: Color(0xFF6E2632), heading: Color(0xFF4A1A24),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.castle), trim: Color(0xFFB08A3E),
);

/// Patronus: a silver-blue light in the dark.
const patronusNightPalette = PaletteSpec(
  id: 'patronus_night', name: 'Patronus Night', hint: 'Harry Potter · silver light', brightness: Brightness.dark,
  background: Color(0xFF070D18), surface: Color(0xFF0F1828), surfaceHigh: Color(0xFF162236), ink: Color(0xFFE8F2FA), muted: Color(0xFF9FB3C8),
  outline: Color(0xFF2A3A52), cardBorder: Color(0xFF1F2D42), chip: Color(0xFF121D30),
  accent: Color(0xFF9FD8F0), onAccent: Color(0xFF061220), accentText: Color(0xFFB8E4F5), heading: Color(0xFFDDEFF8),
  sceneGlow: 0.4, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.patronus), trim: Color(0xFFD5E3EC),
);

/// Patronus: a misty blue morning, the light in a deeper blue.
const patronusDayPalette = PaletteSpec(
  id: 'patronus_day', name: 'Patronus Day', hint: 'Harry Potter · silver light', brightness: Brightness.light,
  background: Color(0xFFF0F5FA), surface: Color(0xFFFCFEFF), surfaceHigh: Color(0xFFDFE9F2), ink: Color(0xFF0E1C2A), muted: Color(0xFF4C5E70),
  outline: Color(0xFFBACADA), cardBorder: Color(0xFFDAE4EE), chip: Color(0xFFE3ECF4),
  accent: Color(0xFF2A7299), onAccent: Color(0xFFF4FAFD), accentText: Color(0xFF1F5F82), heading: Color(0xFF16465F),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.patronus), trim: Color(0xFF8FA3B3),
);

/// The Forbidden Forest: deep moss under the moon.
const forestNightPalette = PaletteSpec(
  id: 'forest_night', name: 'Forest Night', hint: 'Harry Potter · Forbidden Forest', brightness: Brightness.dark,
  background: Color(0xFF0B130D), surface: Color(0xFF131E16), surfaceHigh: Color(0xFF1B281E), ink: Color(0xFFE5EDE2), muted: Color(0xFFA2B29E),
  outline: Color(0xFF2E4232), cardBorder: Color(0xFF233427), chip: Color(0xFF162219),
  accent: Color(0xFF7FB069), onAccent: Color(0xFF0A1508), accentText: Color(0xFFB7D49A), heading: Color(0xFFB7D49A),
  sceneGlow: 0.45, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.forest), trim: Color(0xFFD8D2B0),
);

/// The Forbidden Forest: ferns by day, bark for the trim.
const forestDayPalette = PaletteSpec(
  id: 'forest_day', name: 'Forest Day', hint: 'Harry Potter · Forbidden Forest', brightness: Brightness.light,
  background: Color(0xFFF1F4EC), surface: Color(0xFFFBFCF8), surfaceHigh: Color(0xFFE2E9DA), ink: Color(0xFF14201A), muted: Color(0xFF4F5E50),
  outline: Color(0xFFBFCBB8), cardBorder: Color(0xFFDCE4D5), chip: Color(0xFFE5ECDD),
  accent: Color(0xFF3D6B35), onAccent: Color(0xFFF3F8EF), accentText: Color(0xFF335C2C), heading: Color(0xFF284A22),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.forest), trim: Color(0xFF7A6040),
);

/// The Order of the Phoenix: flame and gold on embers.
const phoenixNightPalette = PaletteSpec(
  id: 'phoenix_night', name: 'Phoenix Night', hint: 'Harry Potter · Order of the Phoenix', brightness: Brightness.dark,
  background: Color(0xFF160D08), surface: Color(0xFF22140D), surfaceHigh: Color(0xFF2D1B12), ink: Color(0xFFF7E9D8), muted: Color(0xFFC6AC92),
  outline: Color(0xFF55382A), cardBorder: Color(0xFF412A1F), chip: Color(0xFF281810),
  accent: Color(0xFFE8672A), onAccent: Color(0xFF1A0A02), accentText: Color(0xFFF6B04A), heading: Color(0xFFF6B04A),
  sceneGlow: 0.45, look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.phoenix), trim: Color(0xFFF0B843),
);

/// The Order of the Phoenix: a warm page, a deep flame and gold.
const phoenixDayPalette = PaletteSpec(
  id: 'phoenix_day', name: 'Phoenix Day', hint: 'Harry Potter · Order of the Phoenix', brightness: Brightness.light,
  background: Color(0xFFFCF4EA), surface: Color(0xFFFFFBF6), surfaceHigh: Color(0xFFF5E4D2), ink: Color(0xFF2A140A), muted: Color(0xFF6E4E3A),
  outline: Color(0xFFE0C6AC), cardBorder: Color(0xFFEFDCC8), chip: Color(0xFFF7E6D2),
  accent: Color(0xFFB8441A), onAccent: Color(0xFFFFF5EA), accentText: Color(0xFFA03A14), heading: Color(0xFF8A3010),
  look: arcaneLook, group: PaletteGroup.harryPotter, art: HogwartsArt(HogwartsScene.phoenix), trim: Color(0xFFD19A2A),
);

/// The Harry Potter palettes, in the order of the picker.
const harryPotterPalettes = [
  lionNightPalette,
  lionDayPalette,
  serpentNightPalette,
  serpentDayPalette,
  ravenNightPalette,
  ravenDayPalette,
  badgerNightPalette,
  badgerDayPalette,
  hogwartsNightPalette,
  hogwartsDayPalette,
  patronusNightPalette,
  patronusDayPalette,
  forestNightPalette,
  forestDayPalette,
  phoenixNightPalette,
  phoenixDayPalette,
];

/// The name of a Harry Potter palette in the language of the app, or null for another id.
String? harryPotterName(AppLocalizations l, String id) => switch (id) {
      'lion_night' => l.themeLionNightName,
      'lion_day' => l.themeLionDayName,
      'serpent_night' => l.themeSerpentNightName,
      'serpent_day' => l.themeSerpentDayName,
      'raven_night' => l.themeRavenNightName,
      'raven_day' => l.themeRavenDayName,
      'badger_night' => l.themeBadgerNightName,
      'badger_day' => l.themeBadgerDayName,
      'hogwarts_night' => l.themeHogwartsNightName,
      'hogwarts_day' => l.themeHogwartsDayName,
      'patronus_night' => l.themePatronusNightName,
      'patronus_day' => l.themePatronusDayName,
      'forest_night' => l.themeForestNightName,
      'forest_day' => l.themeForestDayName,
      'phoenix_night' => l.themePhoenixNightName,
      'phoenix_day' => l.themePhoenixDayName,
      _ => null,
    };

/// What a Harry Potter palette looks like, in the language of the app, or null.
String? harryPotterHint(AppLocalizations l, String id) => switch (id) {
      'lion_night' || 'lion_day' => l.themeLionHint,
      'serpent_night' || 'serpent_day' => l.themeSerpentHint,
      'raven_night' || 'raven_day' => l.themeRavenHint,
      'badger_night' || 'badger_day' => l.themeBadgerHint,
      'hogwarts_night' || 'hogwarts_day' => l.themeHogwartsHint,
      'patronus_night' || 'patronus_day' => l.themePatronusHint,
      'forest_night' || 'forest_day' => l.themeForestHint,
      'phoenix_night' || 'phoenix_day' => l.themePhoenixHint,
      _ => null,
    };
