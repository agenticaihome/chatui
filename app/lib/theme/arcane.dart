import 'dart:math';

import 'package:flutter/material.dart';

import 'argus_theme.dart';

/// The look of the Harry Potter palettes (lib/theme/groups/harry_potter.dart): cut corners
/// like a plaque, an edge of the metal ([PaletteSpec.trim]) round buttons and cards, the
/// labels of the buttons in the serif, ornaments in the corners of the cards, and a rocket
/// with fins of the metal that leaves sparks. Drawn with a few paths: no image, no shader.
class ArcaneLook extends PaletteLook {
  const ArcaneLook();

  @override
  OutlinedBorder shape(double radius, {BorderSide side = BorderSide.none}) =>
      BeveledRectangleBorder(borderRadius: BorderRadius.circular(radius * 0.5), side: side);

  @override
  OutlinedBorder sheetShape(double radius, {BorderSide side = BorderSide.none}) => BeveledRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius * 0.5)),
        side: side,
      );

  @override
  TextStyle? get buttonText =>
      const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, letterSpacing: 1.2);

  /// In each corner: two short rules along the edges that end in a dot, a small diamond at
  /// the corner and a curl between the rules.
  @override
  void paintOrnaments(Canvas canvas, Size size, Color trim) {
    const inset = 10.0;
    const length = 22.0;
    if (size.shortestSide < inset * 2 + length) return;
    final line = Paint()
      ..color = trim
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = trim;
    for (final (sx, sy) in const [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)]) {
      final corner = Offset(sx > 0 ? inset : size.width - inset, sy > 0 ? inset : size.height - inset);
      // The rules start a little off the corner, so the diamond stands free.
      canvas.drawLine(corner + Offset(sx * 6, 0), corner + Offset(sx * length, 0), line);
      canvas.drawLine(corner + Offset(0, sy * 6), corner + Offset(0, sy * length), line);
      canvas.drawCircle(corner + Offset(sx * (length + 3), 0), 1.6, fill);
      canvas.drawCircle(corner + Offset(0, sy * (length + 3)), 1.6, fill);
      const d = 3.2;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy - d)
          ..lineTo(corner.dx + d, corner.dy)
          ..lineTo(corner.dx, corner.dy + d)
          ..lineTo(corner.dx - d, corner.dy)
          ..close(),
        fill,
      );
      canvas.drawArc(
        Rect.fromCircle(center: corner + Offset(sx * 9, sy * 9), radius: 4),
        sx > 0 ? (sy > 0 ? pi : pi / 2) : (sy > 0 ? -pi / 2 : 0),
        pi / 2,
        false,
        line,
      );
    }
  }

  /// A ring of the metal round the window, a band round the hull above the fins and a spark
  /// on the nose.
  @override
  void paintRocketDetails(Canvas canvas, {required Color trim, required Color accent}) {
    canvas.drawCircle(
      const Offset(0, -8),
      7,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-15.5, 8)
        ..lineTo(15.5, 8)
        ..lineTo(15.2, 12)
        ..lineTo(-15.2, 12)
        ..close(),
      Paint()..color = trim,
    );
    paintSpark(canvas, const Offset(0, -48), 4.5, Paint()..color = trim);
  }

  /// Sparks that fall away and twinkle under the hovering rocket.
  @override
  void paintRocketTrail(Canvas canvas, Offset tail, double phase, {required Color trim, required Color flame}) {
    for (var i = 0; i < 4; i++) {
      final p = (phase + i / 4) % 1;
      final twinkle = 0.6 + 0.4 * sin((p * 3 + i) * 2 * pi).abs();
      paintSpark(
        canvas,
        Offset(tail.dx + (i - 1.5) * 7 + sin(p * 2 * pi + i) * 3, tail.dy + p * 28),
        (2 + 2.5 * (1 - p)) * twinkle,
        Paint()..color = (i.isEven ? trim : flame).withValues(alpha: 0.9 * (1 - p)),
      );
    }
  }

  @override
  void paintRocketBurst(Canvas canvas, Offset at, double t, {required Color trim, required Color accent}) =>
      paintSparkBurst(canvas, at, t, a: trim, b: accent);

  /// Sparks that twinkle along the rocket as the pad raises it.
  @override
  void paintRocketRise(Canvas canvas, Offset from, Offset to, double t, {required Color trim}) {
    for (var i = 0; i < 3; i++) {
      final along = (t * 3 + i / 3) % 1;
      paintSpark(
        canvas,
        Offset.lerp(from, to, along)! + Offset(10 * sin(along * pi * 2 + i), -6),
        2 + 2 * sin(along * pi),
        Paint()..color = trim.withValues(alpha: 0.4 + 0.5 * sin(along * pi)),
      );
    }
  }
}

const arcaneLook = ArcaneLook();

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
