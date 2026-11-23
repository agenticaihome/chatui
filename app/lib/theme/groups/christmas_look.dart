import 'dart:math';

import 'package:flutter/material.dart';

import '../argus_theme.dart';

/// The look of the Christmas palettes (lib/theme/groups/christmas.dart): soft rounded
/// outlines, a broad edge of the trim like a ribbon round buttons and cards, the labels of
/// the buttons in the serif, sprigs of holly in the corners of a card with a bow on its top,
/// and a rocket like a little sleigh: a red nose, a band like a candy cane, a star on the
/// tip, and snowflakes under it. Drawn with a few paths: no image, no shader.
class ChristmasLook extends PaletteLook {
  const ChristmasLook();

  @override
  OutlinedBorder shape(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius * 1.3), side: side);

  @override
  OutlinedBorder sheetShape(double radius, {BorderSide side = BorderSide.none}) => RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius * 1.3)),
        side: side,
      );

  @override
  TextStyle? get buttonText =>
      const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w800, letterSpacing: 0.8);

  /// A ribbon: broader than a hairline.
  @override
  BorderSide edge(PaletteSpec p) => BorderSide(color: p.trim.withValues(alpha: 0.7), width: 1.8);

  @override
  BorderSide buttonEdge(PaletteSpec p) => BorderSide(color: p.trim, width: 2);

  /// In each corner a sprig of holly: two leaves along the edges and three berries at the
  /// corner. On a card wide enough, a small bow in the middle of the top edge.
  @override
  void paintOrnaments(Canvas canvas, Size size, Color trim) {
    // Off the corner, so that the berries stand clear of the round of the edge.
    const inset = 13.0;
    final leaf = (size.shortestSide * 0.12).clamp(11.0, 18.0);
    if (size.shortestSide < inset * 2 + leaf * 2) return;
    final line = Paint()
      ..color = trim
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = trim;
    final shade = Paint()..color = trim.withValues(alpha: 0.32);
    for (final (sx, sy) in const [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)]) {
      final corner = Offset(sx > 0 ? inset : size.width - inset, sy > 0 ? inset : size.height - inset);
      // One leaf along the top or bottom edge, one along the side, from beside the berries.
      for (final angle in [sx > 0 ? 0.0 : pi, sy > 0 ? pi / 2 : -pi / 2]) {
        final dir = Offset(cos(angle), sin(angle));
        final base = corner + dir * 4;
        final path = hollyLeaf(base, angle, leaf);
        canvas.drawPath(path, shade);
        canvas.drawPath(path, line);
        canvas.drawLine(base, base + dir * leaf * 0.85, line);
      }
      // The berries, a small cluster on the corner.
      canvas.drawCircle(corner + Offset(sx * 1.4, sy * 1.4), 2.8, fill);
      canvas.drawCircle(corner + Offset(sx * 6, sy * 0.4), 2.2, fill);
      canvas.drawCircle(corner + Offset(sx * 0.4, sy * 6), 2.2, fill);
    }
    if (size.width >= 150) paintBow(canvas, Offset(size.width / 2, 11), 1, trim);
  }

  /// The rocket as a little sleigh-red rocket: the nose in the accent with a seam of the
  /// trim, a ring of the trim round the window, a band like a candy cane above the fins
  /// and a star on the tip.
  @override
  void paintRocketDetails(Canvas canvas, {required Color trim, required Color accent}) {
    final hull = Path()
      ..moveTo(0, -44)
      ..quadraticBezierTo(18, -24, 15, 10)
      ..lineTo(13, 30)
      ..lineTo(-13, 30)
      ..lineTo(-15, 10)
      ..quadraticBezierTo(-18, -24, 0, -44)
      ..close();
    canvas.save();
    canvas.clipPath(hull);
    canvas.drawRect(const Rect.fromLTRB(-20, -46, 20, -27), Paint()..color = accent);
    canvas.drawRect(const Rect.fromLTRB(-20, -27, 20, -25), Paint()..color = trim);
    // The band: the trim, and stripes of the accent across it, aslant.
    canvas.drawRect(const Rect.fromLTRB(-20, 6, 20, 14), Paint()..color = trim);
    final stripes = Path();
    for (var x = -22.0; x < 20; x += 7) {
      stripes
        ..moveTo(x, 14)
        ..lineTo(x + 3.2, 14)
        ..lineTo(x + 7.2, 6)
        ..lineTo(x + 4, 6)
        ..close();
    }
    canvas.drawPath(stripes, Paint()..color = accent);
    canvas.restore();
    canvas.drawCircle(
      const Offset(0, -8),
      7,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(starPath(const Offset(0, -48), 5.5), Paint()..color = trim);
  }

  /// Snowflakes that fall and turn under the hovering rocket.
  @override
  void paintRocketTrail(Canvas canvas, Offset tail, double phase, {required Color trim, required Color flame}) {
    for (var i = 0; i < 4; i++) {
      final p = (phase + i / 4) % 1;
      paintSnowflake(
        canvas,
        Offset(tail.dx + (i - 1.5) * 8 + sin(p * 2 * pi + i) * 4, tail.dy + p * 28),
        2.5 + 2.5 * (1 - p),
        Paint()
          ..color = (i.isEven ? trim : flame).withValues(alpha: 0.9 * (1 - p))
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
        turn: p * pi / 3 + i,
      );
    }
  }

  /// A burst of stars and snow.
  @override
  void paintRocketBurst(Canvas canvas, Offset at, double t, {required Color trim, required Color accent}) {
    final rnd = Random(5);
    final alpha = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < 8; i++) {
      final angle = 2 * pi * i / 8 + rnd.nextDouble() * 0.5;
      final dist = 10 + 26 * t + rnd.nextDouble() * 8;
      final r = (3 + rnd.nextDouble() * 2.5) * (1 - t * 0.6);
      final c = at + Offset(cos(angle) * dist, sin(angle) * dist);
      if (i.isEven) {
        canvas.drawPath(starPath(c, r, turn: t * 1.5 + i), Paint()..color = trim.withValues(alpha: alpha));
      } else {
        paintSnowflake(
          canvas,
          c,
          r,
          Paint()
            ..color = accent.withValues(alpha: alpha)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
          turn: t * 2,
        );
      }
    }
  }

  /// Snowflakes that drift along the rocket as the pad raises it.
  @override
  void paintRocketRise(Canvas canvas, Offset from, Offset to, double t, {required Color trim}) {
    for (var i = 0; i < 3; i++) {
      final along = (t * 3 + i / 3) % 1;
      paintSnowflake(
        canvas,
        Offset.lerp(from, to, along)! + Offset(10 * sin(along * pi * 2 + i), -6),
        2.5 + 2 * sin(along * pi),
        Paint()
          ..color = trim.withValues(alpha: 0.4 + 0.5 * sin(along * pi))
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
        turn: along * pi,
      );
    }
  }
}

const christmasLook = ChristmasLook();

/// The outline of a holly leaf from its stalk at [base], [length] long toward [angle]: three
/// points on each side, the edges scalloped between them.
Path hollyLeaf(Offset base, double angle, double length) {
  final c = cos(angle), s = sin(angle);
  Offset at(double along, double across) =>
      base + Offset(c * along * length - s * across * length, s * along * length + c * across * length);
  // Round the leaf from the stalk: the points of one side to the tip, then of the other.
  const outline = [(0.2, -0.27), (0.5, -0.33), (0.78, -0.23), (1.0, 0.0), (0.78, 0.23), (0.5, 0.33), (0.2, 0.27)];
  final path = Path()..moveTo(base.dx, base.dy);
  var last = (0.0, 0.0);
  for (final next in [...outline, (0.0, 0.0)]) {
    // Each edge between two points curves in toward the middle of the leaf.
    final mid = at((last.$1 + next.$1) / 2, (last.$2 + next.$2) / 2 * 0.45);
    final to = at(next.$1, next.$2);
    path.quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    last = next;
  }
  return path..close();
}

/// A bow of ribbon with its knot at [knot]: two loops and two tails; [scale] 1 is about 26
/// px wide.
void paintBow(Canvas canvas, Offset knot, double scale, Color colour) {
  final line = Paint()
    ..color = colour
    ..strokeWidth = 1.2
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final shade = Paint()..color = colour.withValues(alpha: 0.28);
  final k = scale;
  final bow = Path();
  for (final sx in const [-1.0, 1.0]) {
    // A loop out to the side and back to the knot.
    bow
      ..moveTo(knot.dx, knot.dy)
      ..cubicTo(knot.dx + sx * 6 * k, knot.dy - 9 * k, knot.dx + sx * 14 * k, knot.dy - 6 * k, knot.dx + sx * 13 * k,
          knot.dy)
      ..cubicTo(knot.dx + sx * 12 * k, knot.dy + 5 * k, knot.dx + sx * 5 * k, knot.dy + 4 * k, knot.dx, knot.dy)
      ..close();
    // A tail down and out, cut in a notch.
    bow
      ..moveTo(knot.dx + sx * 1.5 * k, knot.dy + 1.5 * k)
      ..lineTo(knot.dx + sx * 7 * k, knot.dy + 10 * k)
      ..lineTo(knot.dx + sx * 5 * k, knot.dy + 9 * k)
      ..lineTo(knot.dx + sx * 4 * k, knot.dy + 11 * k)
      ..lineTo(knot.dx - sx * 0.5 * k, knot.dy + 2 * k)
      ..close();
  }
  canvas.drawPath(bow, shade);
  canvas.drawPath(bow, line);
  canvas.drawCircle(knot, 2.4 * k, Paint()..color = colour);
}

/// A five-pointed star with its centre at [c], [r] from the centre to a point; [turn] turns
/// it (radians).
Path starPath(Offset c, double r, {double turn = 0}) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final angle = -pi / 2 + turn + i * pi / 5;
    final d = i.isEven ? r : r * 0.45;
    final p = c + Offset(cos(angle) * d, sin(angle) * d);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A snowflake of six arms through [c], [r] long, in the stroke of [paint]; with [branches],
/// a small V on each arm. [turn] turns it (radians).
void paintSnowflake(Canvas canvas, Offset c, double r, Paint paint, {double turn = 0, bool branches = false}) {
  for (var i = 0; i < 3; i++) {
    final angle = turn + i * pi / 3;
    final d = Offset(cos(angle), sin(angle)) * r;
    canvas.drawLine(c - d, c + d, paint);
  }
  if (!branches) return;
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final angle = turn + i * pi / 3;
    final along = c + Offset(cos(angle), sin(angle)) * r * 0.55;
    for (final side in const [-1.0, 1.0]) {
      final b = angle + side * pi / 4;
      path
        ..moveTo(along.dx, along.dy)
        ..lineTo(along.dx + cos(b) * r * 0.32, along.dy + sin(b) * r * 0.32);
    }
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );
}
