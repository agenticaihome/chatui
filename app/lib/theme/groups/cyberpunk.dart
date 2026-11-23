import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../argus_theme.dart';
import 'cyberpunk_art.dart';
import 'cyberpunk_look.dart';

// The Cyberpunk palettes: neon, rain, high tech and low life, each concept in a dark and a
// light palette that share the [NeonLook]. The ids start with "cyber_", apart from the
// standard palette 'cyberpunk', which stays in the Standard folder. The neon is the accent,
// the second neon the trim; as text the dark palettes take a bright neon, which reads on the
// night page, and the light ones a deep shade of it.

/// Night City: acid yellow and teal on a black street.
const cyberCityNightPalette = PaletteSpec(
  id: 'cyber_city_night', name: 'Night City by Night', hint: 'Cyberpunk · acid yellow and teal', brightness: Brightness.dark,
  background: Color(0xFF0A0D10), surface: Color(0xFF121A1E), surfaceHigh: Color(0xFF1A252A), ink: Color(0xFFEEF6F0), muted: Color(0xFFA2B4B0),
  outline: Color(0xFF2C3C40), cardBorder: Color(0xFF203034), chip: Color(0xFF142024),
  accent: Color(0xFFFCEE0A), onAccent: Color(0xFF0A0D10), accentText: Color(0xFFF7EA3A), heading: Color(0xFFFCEE0A),
  sceneGlow: 0.6, look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.nightCity), trim: Color(0xFF00E0D0),
);

/// Night City: the page in a pale acid yellow, teal for the accent and the trim.
const cyberCityDayPalette = PaletteSpec(
  id: 'cyber_city_day', name: 'Night City by Day', hint: 'Cyberpunk · acid yellow and teal', brightness: Brightness.light,
  background: Color(0xFFFBF6C8), surface: Color(0xFFFFFDEA), surfaceHigh: Color(0xFFF2ECB4), ink: Color(0xFF0E1416), muted: Color(0xFF454E50),
  outline: Color(0xFFD6CF92), cardBorder: Color(0xFFEAE3AE), chip: Color(0xFFF4EDB8),
  accent: Color(0xFF00666C), onAccent: Color(0xFFFFFDEA), accentText: Color(0xFF005A60), heading: Color(0xFF0E1416),
  look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.nightCity), trim: Color(0xFF00A3A3),
);

/// Neon Noir: magenta and cyan signs on a violet black.
const cyberNoirNightPalette = PaletteSpec(
  id: 'cyber_noir_night', name: 'Neon Noir Night', hint: 'Cyberpunk · magenta and cyan', brightness: Brightness.dark,
  background: Color(0xFF0C0812), surface: Color(0xFF160F21), surfaceHigh: Color(0xFF20172F), ink: Color(0xFFF4ECF8), muted: Color(0xFFB4A6C4),
  outline: Color(0xFF3A2B50), cardBorder: Color(0xFF2B203D), chip: Color(0xFF1A1226),
  accent: Color(0xFFF038FF), onAccent: Color(0xFF12051A), accentText: Color(0xFFFF7AF2), heading: Color(0xFF6FF4FF),
  sceneGlow: 0.8, look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.neonNoir), trim: Color(0xFF22E4FF),
);

/// Neon Noir: a pale lilac page, a deep magenta and a cyan trim.
const cyberNoirDayPalette = PaletteSpec(
  id: 'cyber_noir_day', name: 'Neon Noir Day', hint: 'Cyberpunk · magenta and cyan', brightness: Brightness.light,
  background: Color(0xFFF8F3F9), surface: Color(0xFFFFFCFF), surfaceHigh: Color(0xFFEDE3F0), ink: Color(0xFF17101D), muted: Color(0xFF5A4E64),
  outline: Color(0xFFD3C5DA), cardBorder: Color(0xFFE8DDEC), chip: Color(0xFFF0E7F3),
  accent: Color(0xFFA0007E), onAccent: Color(0xFFFFF4FB), accentText: Color(0xFF92007A), heading: Color(0xFF5C0050),
  look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.neonNoir), trim: Color(0xFF0095AE),
);

/// Netrunner: terminal green on black, an aqua trim.
const cyberNetrunnerNightPalette = PaletteSpec(
  id: 'cyber_netrunner_night', name: 'Netrunner Night', hint: 'Cyberpunk · terminal green on black', brightness: Brightness.dark,
  background: Color(0xFF040A06), surface: Color(0xFF0A140D), surfaceHigh: Color(0xFF112016), ink: Color(0xFFD6FFDF), muted: Color(0xFF8EBF97),
  outline: Color(0xFF1F3C27), cardBorder: Color(0xFF172E1E), chip: Color(0xFF0D1A11),
  accent: Color(0xFF39FF6A), onAccent: Color(0xFF03100A), accentText: Color(0xFF5CFF85), heading: Color(0xFF7CFF9C),
  sceneGlow: 0.6, look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.netrunner), trim: Color(0xFF1FD7A8),
);

/// Netrunner: a printout in green on a pale page.
const cyberNetrunnerDayPalette = PaletteSpec(
  id: 'cyber_netrunner_day', name: 'Netrunner Day', hint: 'Cyberpunk · terminal green on black', brightness: Brightness.light,
  background: Color(0xFFF0F7F1), surface: Color(0xFFFBFEFB), surfaceHigh: Color(0xFFE0EDE2), ink: Color(0xFF07160B), muted: Color(0xFF46584A),
  outline: Color(0xFFBCCFC0), cardBorder: Color(0xFFDAE7DC), chip: Color(0xFFE3EFE5),
  accent: Color(0xFF0B7A32), onAccent: Color(0xFFF1FFF4), accentText: Color(0xFF0A6B2C), heading: Color(0xFF064D1F),
  look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.netrunner), trim: Color(0xFF22A85A),
);

/// Blade Rain: orange flares and teal rain on a deep teal black.
const cyberRainNightPalette = PaletteSpec(
  id: 'cyber_rain_night', name: 'Blade Rain Night', hint: 'Cyberpunk · teal and orange in the rain', brightness: Brightness.dark,
  background: Color(0xFF071114), surface: Color(0xFF0E1B1F), surfaceHigh: Color(0xFF15262B), ink: Color(0xFFE6F2F2), muted: Color(0xFF9AB2B4),
  outline: Color(0xFF2A4247), cardBorder: Color(0xFF1E3338), chip: Color(0xFF112024),
  accent: Color(0xFFFF7A1A), onAccent: Color(0xFF140800), accentText: Color(0xFFFF9A4A), heading: Color(0xFFFFB070),
  sceneGlow: 0.7, look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.bladeRain), trim: Color(0xFF2EC4C4),
);

/// Blade Rain: a grey teal morning in the rain, a burnt orange.
const cyberRainDayPalette = PaletteSpec(
  id: 'cyber_rain_day', name: 'Blade Rain Day', hint: 'Cyberpunk · teal and orange in the rain', brightness: Brightness.light,
  background: Color(0xFFEEF3F3), surface: Color(0xFFFAFCFC), surfaceHigh: Color(0xFFDEE8E8), ink: Color(0xFF0C1A1D), muted: Color(0xFF4A5C60),
  outline: Color(0xFFBCCBCC), cardBorder: Color(0xFFD9E3E4), chip: Color(0xFFE2EBEB),
  accent: Color(0xFFB34700), onAccent: Color(0xFFFFF6EE), accentText: Color(0xFFA34100), heading: Color(0xFF0E3B42),
  look: neonLook, group: PaletteGroup.cyberpunk, art: CyberArt(CyberScene.bladeRain), trim: Color(0xFF2A9A9E),
);

/// The Cyberpunk palettes, in the order of the picker.
const cyberpunkPalettes = [
  cyberCityNightPalette,
  cyberCityDayPalette,
  cyberNoirNightPalette,
  cyberNoirDayPalette,
  cyberNetrunnerNightPalette,
  cyberNetrunnerDayPalette,
  cyberRainNightPalette,
  cyberRainDayPalette,
];

/// The name of a Cyberpunk palette in the language of the app, or null for another id.
String? cyberpunkName(AppLocalizations l, String id) => switch (id) {
      'cyber_city_night' => l.themeCyberCityNightName,
      'cyber_city_day' => l.themeCyberCityDayName,
      'cyber_noir_night' => l.themeCyberNoirNightName,
      'cyber_noir_day' => l.themeCyberNoirDayName,
      'cyber_netrunner_night' => l.themeCyberNetrunnerNightName,
      'cyber_netrunner_day' => l.themeCyberNetrunnerDayName,
      'cyber_rain_night' => l.themeCyberRainNightName,
      'cyber_rain_day' => l.themeCyberRainDayName,
      _ => null,
    };

/// What a Cyberpunk palette looks like, in the language of the app, or null.
String? cyberpunkHint(AppLocalizations l, String id) => switch (id) {
      'cyber_city_night' || 'cyber_city_day' => l.themeCyberCityHint,
      'cyber_noir_night' || 'cyber_noir_day' => l.themeCyberNoirHint,
      'cyber_netrunner_night' || 'cyber_netrunner_day' => l.themeCyberNetrunnerHint,
      'cyber_rain_night' || 'cyber_rain_day' => l.themeCyberRainHint,
      _ => null,
    };
