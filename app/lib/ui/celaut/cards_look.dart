import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../celaut/cards_effects.dart';
import '../../theme/argus_theme.dart' show cardRadius;

/// The frame of a card (`docs/celaut/cards.md`, section 13): the border, the corner and
/// the shadow, all from the active theme. The service never draws it; the tone of the card
/// (section 5.4) stays on the border in both modes, because it is part of what the card
/// says.
@immutable
class CardFrame {
  const CardFrame({required this.side, required this.radius, required this.shadows});

  final BorderSide side;
  final double radius;
  final List<BoxShadow> shadows;

  BoxDecoration decoration(Color fill) => BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        boxShadow: shadows,
      );
}

/// The frame of a card of [tone] (its color [toneColor], null for the neutral tone) in
/// [theme]. [CardsFrames.none] keeps only the tone border.
CardFrame cardFrameOf(ThemeData theme, Color? toneColor, CardsFrames frames) {
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  if (frames == CardsFrames.none) {
    return CardFrame(
      side: toneColor == null ? BorderSide.none : BorderSide(color: toneColor, width: 2),
      radius: cardRadius,
      shadows: const [],
    );
  }
  return CardFrame(
    side: toneColor == null
        ? BorderSide(color: dark ? scheme.outline : scheme.outlineVariant, width: 1.5)
        : BorderSide(color: toneColor, width: 2),
    radius: cardRadius,
    shadows: dark
        // A dark theme: a soft light of the accent around the card (a black shadow does
        // not show on a dark background).
        ? [BoxShadow(color: (toneColor ?? scheme.primary).withValues(alpha: 0.16), blurRadius: 18)]
        : [
            BoxShadow(color: scheme.shadow.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 8)),
            BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
          ],
  );
}

/// The opacity of the reflection at each strength.
double reflectionOpacity(CardsStrength s) => switch (s) {
      CardsStrength.low => 0.10,
      CardsStrength.medium => 0.18,
      CardsStrength.high => 0.28,
    };

/// A light on the image of a card that moves with [tilt] (-1..1 on each axis: the
/// gyroscope, the finger, or the pointer). It only paints: no layout, no input, no
/// semantics, and it repaints alone when [tilt] changes.
class CardReflection extends StatelessWidget {
  const CardReflection({super.key, required this.tilt, required this.opacity});

  final ValueListenable<Offset> tilt;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('cards-reflection'),
              painter: _GlarePainter(tilt, opacity),
              size: Size.infinite,
            ),
          ),
        ),
      );
}

class _GlarePainter extends CustomPainter {
  _GlarePainter(this.tilt, this.opacity) : super(repaint: tilt);

  final ValueListenable<Offset> tilt;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tilt.value;
    final rect = Offset.zero & size;
    // The light rests at the top left and moves against the tilt, like a light that
    // stays still while the phone turns.
    final center = Alignment((-0.45 - t.dx * 0.9).clamp(-1.4, 1.4), (-0.55 - t.dy * 0.9).clamp(-1.4, 1.4));
    final glare = Paint()
      ..shader = RadialGradient(
        center: center,
        radius: 0.85,
        colors: [Colors.white.withValues(alpha: opacity), Colors.white.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawRect(rect, glare);
    final band = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 - t.dx * 0.6, -1),
        end: Alignment(1 - t.dx * 0.6, 1),
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: opacity * 0.45),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(rect);
    canvas.drawRect(rect, band);
  }

  @override
  bool shouldRepaint(_GlarePainter old) => old.opacity != opacity || old.tilt != tilt;
}
