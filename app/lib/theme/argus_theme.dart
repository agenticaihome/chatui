import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

// The Celaut colours, from the landing page's tokens (app.css). The two
// default palettes are built from them: deep teal with cream type (dark) and
// warm cream with teal type (light).

/// The brand coral. Decorative only: fills, borders, rules, marks. On cream
/// it reads about 1.9:1, so it is never a text colour; text in the accent
/// takes [PaletteSpec.accentText].
const coral = Color(0xFFEF9C82);

/// Coral lifted for text and icons on the dark teal (about 6.6:1).
const coralText = Color(0xFFF2A98F);

/// Deep terracotta for accented text and headings on cream (about 5.5:1).
const terracotta = Color(0xFFA6431F);

/// The landing's second decorative channel: mint cells in the brand mark.
const mint = Color(0xFF6FE3C4);

/// Deep teal: the dark page, and type on light grounds where a fixed dark
/// is needed.
const ink = Color(0xFF12302E);
const watchfulSurface = Color(0xFF173937);

/// The deepest teal: type on a coral fill in the dark palette.
const tealDeep = Color(0xFF0A1F1E);

/// Warm cream: the dark palette's type, and type on rust.
const bone = Color(0xFFF2ECE6);
const watchfulMuted = Color(0xFFBACAC7);

/// Warm cream page of the light palette, its white cards and teal type.
const paper = Color(0xFFFBF5EF);
const ledgerSurface = Color(0xFFFFFFFF);
const ledgerInk = Color(0xFF143331);
const ledgerMuted = Color(0xFF3D5B58);
const bannerTint = Color(0xFFF1E6DA);

/// Error red, held off the coral's hue so a fault never reads as the accent.
const rust = Color(0xFFB42335);
/// Error red brightened for text on dark grounds (about 6.3:1 on the teal,
/// where [rust] manages about 2.2:1).
const rustBright = Color(0xFFFF8A9A);
const moss = Color(0xFF1A7A47);

/// Palette-aware rust for *text*: the brand rust fails WCAG on dark
/// surfaces, so dark mode gets [rustBright]. Icons and borders keep [rust].
Color rustFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? rustBright : rust;

const cardRadius = 20.0;
const buttonRadius = 14.0;

/// Accent colour for the current palette (coral on the Celaut palettes).
/// Decorative: fills, borders, marks. Text and icons take [accentTextOf].
Color accentOf(BuildContext context) => ArgusColors.of(context).accent;

/// The accent as text or an icon, contrast-safe on the current palette.
Color accentTextOf(BuildContext context) => ArgusColors.of(context).accentText;

/// The colours of the scene the home pages open on: a sky that settles
/// into the page, a glow of the accent (an eclipse's rim on the overview, a
/// medallion's rings on a wallet's page), ridges with light along their
/// tops, and the glass that pills and cards are made of.
///
/// The balance is set straight onto the scene, in the page's own type, so
/// everything here is held dark (or, on a light palette, pale) enough for
/// that type to meet WCAG AA on every ground it can fall on: the sky, the
/// haze and the brightest ridge (home_contrast_test.dart). The bright parts,
/// the rim of the eclipse and the light on the ridges, are thin lines that
/// no text sits on.
class SceneSpec {
  const SceneSpec({
    required this.sky,
    required this.haze,
    required this.lit,
    required this.glow,
    required this.rimLight,
    required this.ridges,
    required this.glassFill,
    required this.glassBorder,
    required this.glassSheen,
    required this.ring,
    required this.ringFill,
    required this.sendTop,
    required this.sendBottom,
    required this.sendGlow,
    required this.onSend,
  });

  /// The scene for [p]: everything is mixed from its page and accent, so a
  /// palette needs no art of its own.
  factory SceneSpec.of(PaletteSpec p) {
    final bg = p.background;
    final a = p.accent;
    final k = p.sceneGlow;
    Color mix(Color x, Color y, double t) => Color.lerp(x, y, t)!;
    // A light mark on Send (Parchment's sage) needs the accent darkened, not
    // lifted, under it.
    final lightMark = p.onAccent.computeLuminance() > a.computeLuminance();
    final sendTop = lightMark ? a : mix(a, Colors.white, p.isDark ? 0.22 : 0.18);
    final sendBottom = mix(a, Colors.black, lightMark ? 0.22 : (p.isDark ? 0.22 : 0.12));
    if (p.isDark) {
      return SceneSpec(
        // The far crests catch the light, a shade above the sky; the main
        // range and the near ridge are darker than the page, masses against
        // the haze.
        sky: mix(bg, a, 0.075 * k),
        haze: a.withValues(alpha: 0.12 * k),
        lit: a.withValues(alpha: 0.18 * k),
        glow: a,
        rimLight: mix(a, Colors.white, 0.35),
        ridges: [mix(bg, a, 0.10 * k), mix(bg, Colors.black, 0.25), mix(bg, Colors.black, 0.4)],
        glassFill: Colors.white.withValues(alpha: 0.05),
        glassBorder: Colors.white.withValues(alpha: 0.11),
        glassSheen: Colors.white.withValues(alpha: 0.035),
        ring: p.ink.withValues(alpha: 0.18),
        ringFill: p.ink.withValues(alpha: 0.05),
        sendTop: sendTop,
        sendBottom: sendBottom,
        sendGlow: a.withValues(alpha: 0.45),
        onSend: p.onAccent,
      );
    }
    return SceneSpec(
      // On a light page the scene is luminous rather than dark: a sky paler
      // than the page, the light a white haze, the ridges barely tinted.
      // Darkening it would cost the page's type its contrast.
      sky: mix(p.surface, a, 0.03 * k),
      haze: Colors.white.withValues(alpha: 0.55),
      lit: Colors.white.withValues(alpha: 0.6),
      glow: mix(a, Colors.black, 0.1),
      rimLight: Colors.white,
      ridges: [mix(p.surface, a, 0.07 * k), mix(p.surface, a, 0.045 * k), mix(p.surface, a, 0.02 * k)],
      glassFill: Colors.white.withValues(alpha: 0.62),
      glassBorder: p.ink.withValues(alpha: 0.08),
      glassSheen: Colors.white.withValues(alpha: 0.55),
      ring: p.ink.withValues(alpha: 0.2),
      ringFill: Colors.white.withValues(alpha: 0.42),
      sendTop: sendTop,
      sendBottom: sendBottom,
      sendGlow: a.withValues(alpha: 0.4),
      onSend: p.onAccent,
    );
  }

  /// The top of the scene; it settles into the page's own colour.
  final Color sky;

  /// The accent's haze around the glow, translucent.
  final Color haze;

  /// Light laid on the ridges' slopes nearest the glow, translucent.
  final Color lit;

  /// The eclipse's rim and the medallion's rings.
  final Color glow;

  /// The light along the ridges' tops, translucent on a light palette.
  final Color rimLight;

  /// The ridges, far to near, each fading into the page at its foot.
  final List<Color> ridges;

  /// Glass: the pills and cards, translucent, with a hairline edge and a
  /// sheen across their top.
  final Color glassFill;
  final Color glassBorder;
  final Color glassSheen;

  /// The round actions' thin rings and faint fill.
  final Color ring;
  final Color ringFill;

  /// Send: a glowing gradient of the accent, and the mark on it.
  final Color sendTop;
  final Color sendBottom;
  final Color sendGlow;
  final Color onSend;
}

/// One complete palette. Two ship as the defaults, the Celaut palettes (ids
/// 'watchful' and 'ledger', kept so stored choices still resolve); the rest
/// are alternatives the user can pick per brightness.
class PaletteSpec {
  const PaletteSpec({
    required this.id,
    required String name,
    required String hint,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.ink,
    required this.muted,
    required this.outline,
    required this.cardBorder,
    required this.chip,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    Color? heading,
    this.sceneGlow = 1,
  })  : _name = name,
        _hint = hint,
        _heading = heading;

  final String id;
  final String _name;
  final String _hint;

  /// The palette's name in the language of the app.
  String get name => switch (id) {
        'watchful' => appL10n.themeTealName,
        'ledger' => appL10n.themeCreamName,
        'obsidian' => appL10n.themeObsidianName,
        'harbor' => appL10n.themeHarborName,
        'ember' => appL10n.themeEmberName,
        'parchment' => appL10n.themeParchmentName,
        'frost' => appL10n.themeFrostName,
        'cyberpunk' => appL10n.themeCyberpunkName,
        'apple_light' => appL10n.themeAppleLightName,
        'apple_dark' => appL10n.themeAppleDarkName,
        'material_light' => appL10n.themeMaterialLightName,
        'material_dark' => appL10n.themeMaterialDarkName,
        'nord' => appL10n.themeNordName,
        'solarized' => appL10n.themeSolarizedName,
        'dracula' => appL10n.themeDraculaName,
        _ => _name,
      };

  /// What the palette looks like, in the language of the app.
  String get hint => switch (id) {
        'watchful' => appL10n.themeTealHint,
        'ledger' => appL10n.themeCreamHint,
        'obsidian' => appL10n.themeObsidianHint,
        'harbor' => appL10n.themeHarborHint,
        'ember' => appL10n.themeEmberHint,
        'parchment' => appL10n.themeParchmentHint,
        'frost' => appL10n.themeFrostHint,
        'cyberpunk' => appL10n.themeCyberpunkHint,
        'apple_light' => appL10n.themeAppleLightHint,
        'apple_dark' => appL10n.themeAppleDarkHint,
        'material_light' => appL10n.themeMaterialLightHint,
        'material_dark' => appL10n.themeMaterialDarkHint,
        'nord' => appL10n.themeNordHint,
        'solarized' => appL10n.themeSolarizedHint,
        'dracula' => appL10n.themeDraculaHint,
        _ => _hint,
      };
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color ink;
  final Color muted;
  final Color outline;
  final Color cardBorder;
  final Color chip;
  final Color accent;
  final Color onAccent;

  /// Accent as text on this background, contrast-safe.
  final Color accentText;

  /// Serif headings (page and dialog titles); the ink unless the palette
  /// sets its own, as Celaut's light palette does with terracotta.
  Color get heading => _heading ?? ink;
  final Color? _heading;

  /// How strongly the accent tints the home scene's sky, haze and ridges.
  /// The scene was tuned on near-black pages; a lighter dark page (Celaut's
  /// teal) takes less, so the balance and its lines keep WCAG AA on it.
  final double sceneGlow;

  /// The scene the home pages open on.
  SceneSpec get scene => SceneSpec.of(this);

  bool get isDark => brightness == Brightness.dark;
}

/// Celaut, dark: the landing page's deep teal, cream type, coral accent.
const watchfulPalette = PaletteSpec(
  id: 'watchful', name: 'Celaut Teal', hint: 'Teal, cream type, coral', brightness: Brightness.dark,
  background: ink, surface: watchfulSurface, surfaceHigh: Color(0xFF1C4442),
  ink: bone, muted: watchfulMuted,
  // Cream at 28% and 14% over the page: the landing's border-strong and border.
  outline: Color(0xFF3F5C59), cardBorder: Color(0xFF334F4C), chip: watchfulSurface,
  accent: coral, onAccent: tealDeep, accentText: coralText, sceneGlow: 0.5,
);

/// Celaut, light: warm cream, teal type, terracotta headings and accented
/// text over the same decorative coral.
const ledgerPalette = PaletteSpec(
  id: 'ledger', name: 'Celaut Cream', hint: 'Cream, teal type, coral', brightness: Brightness.light,
  background: paper, surface: ledgerSurface, surfaceHigh: Color(0xFFF3E9DF), ink: ledgerInk, muted: ledgerMuted,
  outline: Color(0xFFBCC0B9), cardBorder: Color(0xFFDCDCD5), chip: bannerTint,
  accent: coral, onAccent: Color(0xFF14322F), accentText: terracotta, heading: terracotta,
);

const obsidianPalette = PaletteSpec(
  id: 'obsidian', name: 'Obsidian', hint: 'True black, steel accent', brightness: Brightness.dark,
  background: Color(0xFF000000), surface: Color(0xFF111214), surfaceHigh: Color(0xFF1A1C1F), ink: Color(0xFFE9EAEC), muted: Color(0xFF969BA2),
  outline: Color(0xFF2A2D31), cardBorder: Color(0xFF232629), chip: Color(0xFF17191C),
  accent: Color(0xFF9DB8CC), onAccent: Color(0xFF0B1216), accentText: Color(0xFF9DB8CC),
);

const harborPalette = PaletteSpec(
  id: 'harbor', name: 'Harbor', hint: 'Deep navy, teal accent', brightness: Brightness.dark,
  background: Color(0xFF0B1220), surface: Color(0xFF141D2E), surfaceHigh: Color(0xFF1B2638), ink: Color(0xFFE3E8F0), muted: Color(0xFF97A3B5),
  outline: Color(0xFF283449), cardBorder: Color(0xFF222D40), chip: Color(0xFF182233),
  accent: Color(0xFF5FB3A4), onAccent: Color(0xFF06201C), accentText: Color(0xFF7CC9BB),
);

const emberPalette = PaletteSpec(
  id: 'ember', name: 'Ember', hint: 'Warm charcoal, copper accent', brightness: Brightness.dark,
  background: Color(0xFF151210), surface: Color(0xFF201B18), surfaceHigh: Color(0xFF29221E), ink: Color(0xFFEDE3D9), muted: Color(0xFFAEA195),
  outline: Color(0xFF3A312C), cardBorder: Color(0xFF302925), chip: Color(0xFF261F1B),
  accent: Color(0xFFD48A5A), onAccent: Color(0xFF1E120A), accentText: Color(0xFFE0A07A),
);

const parchmentPalette = PaletteSpec(
  id: 'parchment', name: 'Parchment', hint: 'Cream, sage accent', brightness: Brightness.light,
  background: Color(0xFFFAF6EC), surface: Color(0xFFFFFDF8), surfaceHigh: Color(0xFFF0EADA), ink: Color(0xFF2A2318), muted: Color(0xFF6F675A),
  outline: Color(0xFFD9D0BC), cardBorder: Color(0xFFEAE3D2), chip: Color(0xFFF1EBDC),
  accent: Color(0xFF5E8A6A), onAccent: Color(0xFFF6FBF6), accentText: Color(0xFF3F6B4C),
);

// Muted is #687080 rather than #6B7380: on Frost's page and recessed wells
// the lighter grey read 4.38:1, short of WCAG AA; this reads 4.56:1.
const frostPalette = PaletteSpec(
  id: 'frost', name: 'Frost', hint: 'Cool white, slate-blue accent', brightness: Brightness.light,
  background: Color(0xFFF3F5F8), surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFE8ECF2), ink: Color(0xFF1B1F26), muted: Color(0xFF687080),
  outline: Color(0xFFCFD6E0), cardBorder: Color(0xFFE2E7EE), chip: Color(0xFFEDF0F5),
  accent: Color(0xFF4A6FA5), onAccent: Color(0xFFF7F9FD), accentText: Color(0xFF3C5D8C),
);

/// Cyberpunk: night violet under neon pink, with a cold white-blue type.
const cyberpunkPalette = PaletteSpec(
  id: 'cyberpunk', name: 'Cyberpunk', hint: 'Night violet, neon pink', brightness: Brightness.dark,
  background: Color(0xFF0B0714), surface: Color(0xFF150E26), surfaceHigh: Color(0xFF1F1636), ink: Color(0xFFE8F4FF), muted: Color(0xFFA79BC9),
  outline: Color(0xFF3A2A5E), cardBorder: Color(0xFF2B1F47), chip: Color(0xFF1A1230),
  accent: Color(0xFFFF2E97), onAccent: Color(0xFF1A0010), accentText: Color(0xFFFF5CB0),
);

/// Apple: the grouped grey page and white cards of iOS, in its system blue. The blue as text
/// is darker (#0062CC) than the system's (#007AFF), which reads 4.0:1 on white.
const appleLightPalette = PaletteSpec(
  id: 'apple_light', name: 'Apple Light', hint: 'Clean white, system blue', brightness: Brightness.light,
  background: Color(0xFFF2F2F7), surface: Color(0xFFFFFFFF), surfaceHigh: Color(0xFFE5E5EA), ink: Color(0xFF1C1C1E), muted: Color(0xFF636366),
  outline: Color(0xFFC6C6C8), cardBorder: Color(0xFFE5E5EA), chip: Color(0xFFE9E9EE),
  accent: Color(0xFF007AFF), onAccent: Color(0xFFFFFFFF), accentText: Color(0xFF0062CC),
);

const appleDarkPalette = PaletteSpec(
  id: 'apple_dark', name: 'Apple Dark', hint: 'True black, system blue', brightness: Brightness.dark,
  background: Color(0xFF000000), surface: Color(0xFF1C1C1E), surfaceHigh: Color(0xFF2C2C2E), ink: Color(0xFFF2F2F7), muted: Color(0xFF98989F),
  outline: Color(0xFF38383A), cardBorder: Color(0xFF2C2C2E), chip: Color(0xFF242426),
  accent: Color(0xFF0A84FF), onAccent: Color(0xFF00152B), accentText: Color(0xFF4DA3FF),
);

/// Material 3, from Google's baseline scheme: the lilac surfaces and the purple primary.
const materialLightPalette = PaletteSpec(
  id: 'material_light', name: 'Material Light', hint: 'Soft lilac, Material purple', brightness: Brightness.light,
  background: Color(0xFFFEF7FF), surface: Color(0xFFF3EDF7), surfaceHigh: Color(0xFFECE6F0), ink: Color(0xFF1D1B20), muted: Color(0xFF49454F),
  outline: Color(0xFFCAC4D0), cardBorder: Color(0xFFE7E0EC), chip: Color(0xFFE8DEF8),
  accent: Color(0xFF6750A4), onAccent: Color(0xFFFFFFFF), accentText: Color(0xFF5A4398), sceneGlow: 0.3,
);

const materialDarkPalette = PaletteSpec(
  id: 'material_dark', name: 'Material Dark', hint: 'Dark grey, lilac accent', brightness: Brightness.dark,
  background: Color(0xFF141218), surface: Color(0xFF211F26), surfaceHigh: Color(0xFF2B2930), ink: Color(0xFFE6E0E9), muted: Color(0xFFCAC4D0),
  outline: Color(0xFF49454F), cardBorder: Color(0xFF36343B), chip: Color(0xFF332D41),
  accent: Color(0xFFD0BCFF), onAccent: Color(0xFF381E72), accentText: Color(0xFFD0BCFF), sceneGlow: 0.7,
);

// Nord, Solarized and Dracula take less of the scene's glow, and Nord's page is darker than
// the original #2E3440, so the balance and the colours of the states keep WCAG AA on them.
const nordPalette = PaletteSpec(
  id: 'nord', name: 'Nord', hint: 'Arctic slate, ice blue', brightness: Brightness.dark,
  background: Color(0xFF242933), surface: Color(0xFF2F3542), surfaceHigh: Color(0xFF383F4F), ink: Color(0xFFECEFF4), muted: Color(0xFFAAB4C6),
  outline: Color(0xFF4C566A), cardBorder: Color(0xFF434C5E), chip: Color(0xFF3B4252),
  accent: Color(0xFF88C0D0), onAccent: Color(0xFF1F2733), accentText: Color(0xFF88C0D0), sceneGlow: 0.3,
);

const solarizedPalette = PaletteSpec(
  id: 'solarized', name: 'Solarized', hint: 'Warm paper, blue accent', brightness: Brightness.light,
  background: Color(0xFFFDF6E3), surface: Color(0xFFFEFBF0), surfaceHigh: Color(0xFFEEE8D5), ink: Color(0xFF073642), muted: Color(0xFF586E75),
  outline: Color(0xFF93A1A1), cardBorder: Color(0xFFE4DDC8), chip: Color(0xFFEEE8D5),
  accent: Color(0xFF268BD2), onAccent: Color(0xFF002B36), accentText: Color(0xFF1A6AA3),
);

const draculaPalette = PaletteSpec(
  id: 'dracula', name: 'Dracula', hint: 'Deep indigo, purple accent', brightness: Brightness.dark,
  background: Color(0xFF282A36), surface: Color(0xFF343746), surfaceHigh: Color(0xFF3E4154), ink: Color(0xFFF8F8F2), muted: Color(0xFFA6ACCD),
  outline: Color(0xFF535770), cardBorder: Color(0xFF44475A), chip: Color(0xFF303243),
  accent: Color(0xFFBD93F9), onAccent: Color(0xFF21222C), accentText: Color(0xFFBD93F9), sceneGlow: 0.3,
);

/// The Ergo part of the app (the wallet and what hangs from it): Ergo's black and orange.
/// It is not in [allPalettes]: the user does not pick it, the app shows it whenever the
/// wallet page is open, so the user can tell that this is Ergo and not Celaut.
const ergoPalette = PaletteSpec(
  id: 'ergo', name: 'Ergo', hint: 'Black, Ergo orange', brightness: Brightness.dark,
  background: Color(0xFF0B0B0C), surface: Color(0xFF161514), surfaceHigh: Color(0xFF211E1C), ink: Color(0xFFF2EFEC), muted: Color(0xFFA7A09A),
  outline: Color(0xFF3A302A), cardBorder: Color(0xFF2B2420), chip: Color(0xFF1B1816),
  accent: Color(0xFFFF5E18), onAccent: Color(0xFF1A0A02), accentText: Color(0xFFFF8A55),
);

/// The Bitcoin wallet (issue #92): a blue-black page under Bitcoin orange (#F7931A), so it
/// reads as Bitcoin and not as the Ergo part (black and Ergo's red-orange). Like
/// [ergoPalette], it is not in [allPalettes]: the app shows it while the Bitcoin wallet
/// is open.
const bitcoinPalette = PaletteSpec(
  id: 'bitcoin', name: 'Bitcoin', hint: 'Blue-black, Bitcoin orange', brightness: Brightness.dark,
  background: Color(0xFF0D1117), surface: Color(0xFF161B24), surfaceHigh: Color(0xFF1F2632), ink: Color(0xFFF3F1EC), muted: Color(0xFFA2A8B3),
  outline: Color(0xFF333B48), cardBorder: Color(0xFF262D39), chip: Color(0xFF1A202B),
  accent: Color(0xFFF7931A), onAccent: Color(0xFF1C1003), accentText: Color(0xFFFFAD4D),
);

const allPalettes = [
  watchfulPalette,
  ledgerPalette,
  obsidianPalette,
  harborPalette,
  emberPalette,
  parchmentPalette,
  frostPalette,
  cyberpunkPalette,
  appleLightPalette,
  appleDarkPalette,
  materialLightPalette,
  materialDarkPalette,
  nordPalette,
  solarizedPalette,
  draculaPalette,
];

PaletteSpec paletteById(String? id, {required Brightness fallback}) {
  for (final p in allPalettes) {
    if (p.id == id) return p;
  }
  return fallback == Brightness.dark ? watchfulPalette : ledgerPalette;
}

/// Palette-dependent colours that screens used to re-derive by hand from
/// `Theme.of(context).brightness`.
class ArgusColors extends ThemeExtension<ArgusColors> {
  const ArgusColors({
    required this.muted,
    required this.cardBorder,
    required this.inset,
    required this.chip,
    this.accent = coral,
    this.onAccent = tealDeep,
    this.accentText = coralText,
    this.scene,
  });

  factory ArgusColors.fromSpec(PaletteSpec p) => ArgusColors(
        muted: p.muted,
        cardBorder: p.cardBorder,
        inset: p.background,
        chip: p.chip,
        accent: p.accent,
        onAccent: p.onAccent,
        accentText: p.accentText,
        scene: p.scene,
      );

  /// The scene the home pages open on; null outside a palette's theme,
  /// where [sceneOf] falls back to the default palette's.
  final SceneSpec? scene;

  /// The scene for [context]'s theme.
  static SceneSpec sceneOf(BuildContext context) =>
      of(context).scene ?? (Theme.of(context).brightness == Brightness.dark ? watchfulPalette : ledgerPalette).scene;

  /// Primary accent (buttons, links, selected states).
  final Color accent;
  final Color onAccent;

  /// Accent used as text on the page background.
  final Color accentText;

  /// Secondary text.
  final Color muted;

  /// Hairline around soft cards.
  final Color cardBorder;

  /// Recessed panel inside a card (status strip, address box).
  final Color inset;

  /// Small tinted container (icon wells, badges).
  final Color chip;

  /// The default palettes' colours, for a theme without the extension.
  static const light = ArgusColors(
    muted: ledgerMuted,
    cardBorder: Color(0xFFDCDCD5),
    inset: paper,
    chip: bannerTint,
    onAccent: Color(0xFF14322F),
    accentText: terracotta,
  );

  static const dark = ArgusColors(
    muted: watchfulMuted,
    cardBorder: Color(0xFF334F4C),
    inset: ink,
    chip: watchfulSurface,
  );

  static ArgusColors of(BuildContext context) =>
      Theme.of(context).extension<ArgusColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  ArgusColors copyWith({
    Color? muted,
    Color? cardBorder,
    Color? inset,
    Color? chip,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    SceneSpec? scene,
  }) =>
      ArgusColors(
        muted: muted ?? this.muted,
        cardBorder: cardBorder ?? this.cardBorder,
        inset: inset ?? this.inset,
        chip: chip ?? this.chip,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        accentText: accentText ?? this.accentText,
        scene: scene ?? this.scene,
      );

  @override
  ArgusColors lerp(ThemeExtension<ArgusColors>? other, double t) {
    if (other is! ArgusColors) return this;
    return ArgusColors(
      muted: Color.lerp(muted, other.muted, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      inset: Color.lerp(inset, other.inset, t)!,
      chip: Color.lerp(chip, other.chip, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      scene: t < 0.5 ? scene : other.scene,
    );
  }
}

/// The heading face: Playfair Display, 500, 700 and 800.
const headingFont = 'Playfair Display';

/// The body face: Lato, 400 and 700.
const bodyFont = 'Lato';

ThemeData argusTheme({required bool watchful}) =>
    argusThemeFor(watchful ? watchfulPalette : ledgerPalette);

ThemeData argusThemeFor(PaletteSpec p) {
  final watchful = p.isDark;
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: rust,
    onError: bone,
    surface: p.surface,
    onSurface: p.ink,
    surfaceContainerHighest: p.surfaceHigh,
    outline: p.outline,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    fontFamily: bodyFont,
  );

  // Headings in Playfair Display, the rest in Lato, as on the landing page.
  // Lato ships 400 and 700 only, so emphasis is 700.
  final applied = base.textTheme.copyWith(
    displayLarge: const TextStyle(
      fontFamily: headingFont,
      fontWeight: FontWeight.w700,
      fontSize: 56,
      height: 0.95,
      letterSpacing: -1.2,
    ),
    headlineSmall: const TextStyle(
      fontFamily: headingFont,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 1.15,
    ),
    titleLarge: const TextStyle(
      fontFamily: headingFont,
      fontWeight: FontWeight.w700,
      fontSize: 22,
    ),
    titleMedium: const TextStyle(
      fontFamily: bodyFont,
      fontWeight: FontWeight.w700,
      fontSize: 16,
      letterSpacing: 0.1,
    ),
    titleSmall: const TextStyle(
      fontFamily: bodyFont,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      letterSpacing: 1.4,
    ),
    bodyLarge: const TextStyle(fontFamily: bodyFont, fontSize: 16, height: 1.45),
    bodyMedium: const TextStyle(fontFamily: bodyFont, fontSize: 14, height: 1.45),
    bodySmall: const TextStyle(fontFamily: bodyFont, fontSize: 12, height: 1.4),
    labelLarge: const TextStyle(
      fontFamily: bodyFont,
      fontWeight: FontWeight.w700,
      fontSize: 14,
      letterSpacing: 0.4,
    ),
  ).apply(
    bodyColor: p.ink,
    displayColor: p.ink,
  );
  // The serif headings take the palette's heading colour.
  final text = applied.copyWith(
    displayLarge: applied.displayLarge?.copyWith(color: p.heading),
    headlineSmall: applied.headlineSmall?.copyWith(color: p.heading),
    titleLarge: applied.titleLarge?.copyWith(color: p.heading),
  );

  return base.copyWith(
    extensions: [ArgusColors.fromSpec(p)],
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: watchful ? p.outline : p.cardBorder,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: BorderSide(color: p.accent, width: 1.2),
      ),
      // The error colour of the scheme is a dark red, about 2:1 on a dark page: the
      // message and the border of a field with an error take the red of the palette
      // (rustFor), which is 4.5:1 or more on each page.
      errorStyle: TextStyle(color: watchful ? rustBright : rust),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: BorderSide(color: watchful ? rustBright : rust),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
        borderSide: BorderSide(color: watchful ? rustBright : rust, width: 1.2),
      ),
      labelStyle: TextStyle(color: p.muted),
      // Left to the scheme, a focused field's label took the decorative
      // accent; as text it takes the accent's text colour.
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(color: states.contains(WidgetState.focused) ? p.accentText : p.muted),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accentText,
      selectionHandleColor: p.accentText,
      selectionColor: p.accent.withValues(alpha: 0.35),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.accentText,
      unselectedLabelColor: p.muted,
      indicatorColor: p.accent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: p.accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accentText,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.background,
      indicatorColor: p.accent.withValues(alpha: 0.18),
      elevation: 0,
      height: 68,
      // Left to the scheme, the selected icon took onSecondaryContainer,
      // which falls back to the ink-on-accent colour: dark ink on the gold
      // indicator in every dark palette. The current tab draws in the
      // accent and the others step back, so only one tab speaks.
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? p.accentText : p.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.bodySmall?.copyWith(
          letterSpacing: 0.6,
          color: states.contains(WidgetState.selected) ? p.ink : p.muted,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: watchful ? p.surface : p.ink,
      contentTextStyle: TextStyle(fontFamily: bodyFont, color: watchful ? p.ink : p.background),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
    ),
  );
}

TextStyle monoStyle(BuildContext context, {double size = 13}) {
  return TextStyle(
    fontFamily: 'IBMPlexMono',
    fontSize: size,
    height: 1.4,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.gold = false});

  /// Drawn in the palette's accent rather than the divider colour (the
  /// name is from when the accent was gold).
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: gold ? accentOf(context) : Theme.of(context).dividerColor,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.scope});
  final String text;

  /// Optional scope tag shown next to the label, e.g. 'This wallet' or
  /// 'App-wide', so readers know what a settings section applies to.
  final String? scope;

  @override
  Widget build(BuildContext context) {
    final muted = ArgusColors.of(context).muted;
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: muted),
        ),
        if (scope != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: muted, width: 0.8),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              scope!.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: muted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.total, required this.index});
  final int total;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return Container(
          width: i == index ? 22 : 7,
          height: 7,
          margin: const EdgeInsets.only(right: 6),
          color: i == index ? accentOf(context) : Theme.of(context).dividerColor,
        );
      }),
    );
  }
}

/// For a button that shares a line with something else.
///
/// The theme asks buttons to be as wide as their parent allows, which is
/// what a page's main action wants. A Row or a Wrap offers its children
/// unbounded width, so that minimum becomes infinite there and the line
/// cannot be laid out; this keeps the height and lets the button be as
/// wide as its label.
final inlineButtonStyle = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 52)),
);

Route<T> fadeRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (_, _, _) => page,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// The mint of the mark, the second colour of the brand after the accent. Mint reads on
/// the teal; on a light page it takes the landing's deep viz green so that it keeps its
/// edge. Text and the born cell of [CellMark] use it.
Color mintOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? mint : const Color(0xFF0F6B58);

/// The Celaut mark: a Game-of-Life glider on a faint grid of cells, with
/// the one cell its next generation brings to life in mint. The same
/// drawing as the launcher icon, in the current palette's colours.
class CellMark extends StatelessWidget {
  const CellMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final colors = ArgusColors.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: CellMarkPainter(
          live: colors.accent,
          born: mintOf(context),
          grid: theme.colorScheme.onSurface.withValues(alpha: dark ? 0.10 : 0.08),
        ),
      ),
    );
  }
}

/// Paints [CellMark]: a grid five cells wide and four high, the glider in
/// its middle three columns and the born cell under it. The empty cells
/// are faint and fade toward the corners, as the launcher icon's grid does.
class CellMarkPainter extends CustomPainter {
  const CellMarkPainter({required this.live, required this.born, required this.grid});

  final Color live;
  final Color born;
  final Color grid;

  /// The glider, moving down and to the right, by column and row.
  static const glider = [(2, 0), (3, 1), (1, 2), (2, 2), (3, 2)];

  /// The cell its next generation gives birth to.
  static const bornCell = (2, 3);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final pitch = side / 5;
    final cell = pitch * 0.84;
    final radius = Radius.circular(cell * 0.2);
    // Four rows, centred in the square.
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2 + pitch / 2);
    final livePaint = Paint()..color = live;
    final bornPaint = Paint()..color = born;
    final gridAlpha = grid.a;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * pitch + (pitch - cell) / 2,
          origin.dy + r * pitch + (pitch - cell) / 2,
          cell,
          cell,
        );
        final Paint paint;
        if (glider.contains((c, r))) {
          paint = livePaint;
        } else if ((c, r) == bornCell) {
          paint = bornPaint;
        } else {
          final dx = c - 2.0, dy = r - 1.5;
          final fade = ((2.7 - sqrt(dx * dx + dy * dy)) / 1.2).clamp(0.0, 1.0);
          if (fade == 0) continue;
          paint = Paint()..color = grid.withValues(alpha: gridAlpha * fade);
        }
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CellMarkPainter oldDelegate) =>
      oldDelegate.live != live || oldDelegate.born != born || oldDelegate.grid != grid;
}

/// The wordmark beside [CellMark]: "Chat" in Playfair Display 800, in the accent's text
/// colour, as on the landing page, and then "ui" in mint, the other colour of the mark:
/// Chatui, in lower case except the C.
class CelautWordmark extends StatelessWidget {
  const CelautWordmark({super.key, this.size = 26, this.textAlign});
  final double size;
  final TextAlign? textAlign;

  /// The name of the app, for a screen reader and for a title.
  static const name = 'Chatui';

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: headingFont,
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: 1.1,
      letterSpacing: size * 0.02,
      color: accentTextOf(context),
    );
    return Text.rich(
      TextSpan(
        text: 'Chat',
        children: [
          TextSpan(text: 'ui', style: TextStyle(color: mintOf(context))),
        ],
      ),
      semanticsLabel: name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: base,
    );
  }
}
