import 'dart:math';

import 'package:flutter/material.dart';

import 'argus_theme.dart';

// The shared look of the four house palettes ([PaletteStyle.arcane]): the ornaments in the
// corners of a card, the sparks of the rocket and the shape of a panel. Each is drawn with
// a few paths in the trim of the palette: no image, no blur, no shader.

/// True when the theme of [context] is one of the house palettes.
bool isArcaneOf(BuildContext context) => ArgusColors.of(context).isArcane;

/// The outline of a floating panel (the card of the rocket, of an import) in the theme of
/// [context]: rounded, or a plaque with cut corners and a hairline of the trim.
ShapeBorder panelShapeOf(BuildContext context, {double radius = cardRadius}) {
  final colors = ArgusColors.of(context);
  if (!colors.isArcane) return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  return BeveledRectangleBorder(
    borderRadius: BorderRadius.circular(radius * 0.5),
    side: BorderSide(color: colors.trim.withValues(alpha: 0.7), width: 1.2),
  );
}

/// A four-pointed spark with its centre at [c], [r] from the centre to a point.
void paintSpark(Canvas canvas, Offset c, double r, Paint paint) {
  final w = r * 0.28;
  canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy - w * 0.4, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy + w * 0.4, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy + w * 0.4, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy - w * 0.4, c.dx, c.dy - r)
      ..close(),
    paint,
  );
}

/// The ornaments of a card in a house palette: in each corner, two short rules along the
/// edges that end in a dot, and a small diamond at the corner. It only paints; put it over
/// the card in a [Stack] with [Positioned.fill]. [inset] keeps it off a cut or rounded edge.
class ArcaneCorners extends StatelessWidget {
  const ArcaneCorners({super.key, required this.color, this.inset = 10, this.length = 22});

  final Color color;
  final double inset;
  final double length;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(
            key: const Key('arcane-corners'),
            painter: ArcaneCornersPainter(color: color, inset: inset, length: length),
            size: Size.infinite,
          ),
        ),
      );
}

class ArcaneCornersPainter extends CustomPainter {
  const ArcaneCornersPainter({required this.color, required this.inset, required this.length});

  final Color color;
  final double inset;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < inset * 2 + length) return;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    for (final (sx, sy) in const [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)]) {
      final corner = Offset(sx > 0 ? inset : size.width - inset, sy > 0 ? inset : size.height - inset);
      // The rules start a little off the corner, so the diamond stands free.
      final a = corner + Offset(sx * 6, 0);
      final b = corner + Offset(0, sy * 6);
      canvas.drawLine(a, corner + Offset(sx * length, 0), line);
      canvas.drawLine(b, corner + Offset(0, sy * length), line);
      canvas.drawCircle(corner + Offset(sx * (length + 3), 0), 1.6, fill);
      canvas.drawCircle(corner + Offset(0, sy * (length + 3)), 1.6, fill);
      final d = 3.2;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy - d)
          ..lineTo(corner.dx + d, corner.dy)
          ..lineTo(corner.dx, corner.dy + d)
          ..lineTo(corner.dx - d, corner.dy)
          ..close(),
        fill,
      );
      // An inner curl between the rules.
      canvas.drawArc(
        Rect.fromCircle(center: corner + Offset(sx * 9, sy * 9), radius: 4),
        sx > 0 ? (sy > 0 ? pi : pi / 2) : (sy > 0 ? -pi / 2 : 0),
        pi / 2,
        false,
        line,
      );
    }
  }

  @override
  bool shouldRepaint(ArcaneCornersPainter old) => old.color != color || old.inset != inset || old.length != length;
}

/// Sparks that twinkle round a point, for a moment of success (the rocket that stands or
/// lifts off). [t] runs from 0 to 1 and the sparks drift out and fade; [seed] places them.
void paintSparkBurst(
  Canvas canvas,
  Offset centre,
  double t, {
  required Color a,
  required Color b,
  int count = 7,
  int seed = 3,
}) {
  final rnd = Random(seed);
  for (var i = 0; i < count; i++) {
    final angle = 2 * pi * i / count + rnd.nextDouble() * 0.6;
    final dist = 10 + 26 * t + rnd.nextDouble() * 8;
    final r = (2.5 + rnd.nextDouble() * 2.5) * (1 - t * 0.6);
    final alpha = (1 - t).clamp(0.0, 1.0);
    final c = centre + Offset(cos(angle) * dist, sin(angle) * dist);
    paintSpark(canvas, c, r, Paint()..color = (i.isEven ? a : b).withValues(alpha: alpha));
  }
}
