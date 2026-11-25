import 'package:flutter/material.dart';

import 'argus_theme.dart';

/// The look that a group of palettes shares beyond its colours (lib/theme/groups/): the
/// outline of buttons, cards, dialogs and sheets, the face of the labels of the buttons, the
/// edge of [PaletteSpec.trim] round them, the ornaments on a card, and the dress of the
/// rocket of a launch or an import with what it leaves behind. A palette without a look
/// ([PaletteSpec.look] null) has the rounded look of the app.
///
/// A group writes one const subclass and overrides what it changes. Everything is drawn
/// with paths: no image, no blur on a frame that animates, no shader.
abstract class PaletteLook {
  const PaletteLook();

  /// The outline of a panel, a card, a dialog or a button with a corner of [radius].
  OutlinedBorder shape(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);

  /// The outline of a bottom sheet: only its top corners show.
  OutlinedBorder sheetShape(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radius)), side: side);

  /// The labels of the buttons, or null for the app's (Lato 700).
  TextStyle? get buttonText => null;

  /// The hairline round cards, dialogs and sheets; [BorderSide.none] for none.
  BorderSide edge(PaletteSpec p) => BorderSide(color: p.trim.withValues(alpha: 0.6), width: 1.2);

  /// The edge of a filled button and of the floating button.
  BorderSide buttonEdge(PaletteSpec p) => BorderSide(color: p.trim, width: 1.6);

  /// Ornaments over a card (a card of the deck, the card of the rocket), in [trim]. They
  /// keep to the edge and the corners: the texts of the card lie inside 20 px from it.
  void paintOrnaments(Canvas canvas, Size size, Color trim) {}

  /// Details on the rocket, in its own frame ([paintRocketShape]: the nose at (0, -44), the
  /// tail at y 30, the window a circle of 7 at (0, -8)), over the hull. The fins and the
  /// core of the flame are in [trim] already.
  void paintRocketDetails(Canvas canvas, {required Color trim, required Color accent}) {}

  /// What the hovering rocket leaves under it, in place of the smoke: [tail] is under the
  /// flame, [phase] runs from 0 to 1 and loops (900 ms).
  void paintRocketTrail(Canvas canvas, Offset tail, double phase, {required Color trim, required Color flame}) {}

  /// The moment that the rocket goes, or stands at the end of an import, at [at]: [t] runs
  /// from 0 to 1 with the lift-off (the import's rocket holds it at 0.35).
  void paintRocketBurst(Canvas canvas, Offset at, double t, {required Color trim, required Color accent}) {}

  /// What the rocket of an import leaves along its way up while the pad raises it, from the
  /// hinge [from] to the nose [to]; [t] is how raised it is, 0 flat to 1 upright.
  void paintRocketRise(Canvas canvas, Offset from, Offset to, double t, {required Color trim}) {}
}

/// The drawing of a palette over its home scene and as the "theme" background of a chat
/// (lib/theme/scene_art.dart). [paintBack] draws behind the ridges, [paintFront] over them.
///
/// Text falls on the scene: keep what it can fall on thin, small or faint, or a mass in the
/// colour of a ridge (see [silhouetteColor]), which the contrast tests check.
abstract class SceneArtwork {
  const SceneArtwork();

  /// Behind the ridges: sky, stars, far shapes. [light] is where the light of the scene is.
  void paintBack(
    Canvas canvas,
    Size size,
    SceneSpec spec, {
    required bool dark,
    required Offset light,
    required double strength,
  }) {}

  /// Over the ridges: silhouettes that stand with their foot at [horizon] (a share of the
  /// height), and what floats in the air.
  void paintFront(
    Canvas canvas,
    Size size,
    SceneSpec spec, {
    required bool dark,
    required double horizon,
    required double strength,
  }) {}
}

/// The colour of a silhouette that stands against the ridges: on a dark page the main
/// range's, darker than the sky; on a light page the far ridge's with a breath of the ink of
/// the ring, so it shows on the pale sky.
Color silhouetteColor(SceneSpec spec, bool dark) =>
    dark ? spec.ridges[1] : Color.alphaBlend(spec.ring.withValues(alpha: 0.12), spec.ridges.first);

/// The ornaments of [look] over a card: put it over the card in a [Stack] with
/// [Positioned.fill]. It only paints.
class LookOrnaments extends StatelessWidget {
  const LookOrnaments({super.key, required this.look, required this.color});

  final PaletteLook look;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(
            key: const Key('look-ornaments'),
            painter: _OrnamentsPainter(look, color),
            size: Size.infinite,
          ),
        ),
      );
}

class _OrnamentsPainter extends CustomPainter {
  const _OrnamentsPainter(this.look, this.color);

  final PaletteLook look;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => look.paintOrnaments(canvas, size, color);

  @override
  bool shouldRepaint(_OrnamentsPainter old) => old.look != look || old.color != color;
}

/// The outline of a floating panel (the card of the rocket, of an import) in the theme of
/// [context]: rounded, or the look's own with a hairline of the trim.
ShapeBorder panelShapeOf(BuildContext context, {double radius = cardRadius}) {
  final colors = ArgusColors.of(context);
  final look = colors.look;
  if (look == null) return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  return look.shape(radius, side: BorderSide(color: colors.trim.withValues(alpha: 0.7), width: 1.2));
}
