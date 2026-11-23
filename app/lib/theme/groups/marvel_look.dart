import 'dart:math';

import 'package:flutter/material.dart';

import '../argus_theme.dart';

/// The look of the Marvel palettes (lib/theme/groups/marvel.dart): a comic panel. Two
/// opposite corners cut deep and two cut a little, a thick ink edge round cards and buttons,
/// the labels of the buttons slanted, halftone dots and a small starburst in the corners of
/// the cards, and a rocket that leaves speed lines and goes off in a starburst. Drawn with a
/// few paths: no image, no shader, no blur.
class ComicLook extends PaletteLook {
  const ComicLook();

  @override
  OutlinedBorder shape(double radius, {BorderSide side = BorderSide.none}) => BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius * 0.55),
          topRight: Radius.circular(radius * 0.12),
          bottomLeft: Radius.circular(radius * 0.12),
          bottomRight: Radius.circular(radius * 0.55),
        ),
        side: side,
      );

  @override
  OutlinedBorder sheetShape(double radius, {BorderSide side = BorderSide.none}) => BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius * 0.55),
          topRight: Radius.circular(radius * 0.12),
        ),
        side: side,
      );

  /// Bold and slanted, a little spaced: the lettering of a comic.
  @override
  TextStyle? get buttonText => const TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.8,
      );

  /// The ink of a panel: on a light page the ink itself, on a dark page the trim, which
  /// shows on the night.
  @override
  BorderSide edge(PaletteSpec p) =>
      BorderSide(color: (p.isDark ? p.trim : p.ink).withValues(alpha: p.isDark ? 0.75 : 0.8), width: 2);

  @override
  BorderSide buttonEdge(PaletteSpec p) => BorderSide(color: p.isDark ? p.trim : p.ink, width: 2);

  /// Halftone dots in the upper left and the lower right corners, the dots smaller away
  /// from the corner, and a small starburst in the upper right corner.
  @override
  void paintOrnaments(Canvas canvas, Size size, Color trim) {
    const inset = 8.0;
    if (size.shortestSide < 64) return;
    final fill = Paint()..color = trim;
    for (final (sx, sy) in const [(1.0, 1.0), (-1.0, -1.0)]) {
      final corner = Offset(sx > 0 ? inset : size.width - inset, sy > 0 ? inset : size.height - inset);
      for (var i = 0; i < 6; i++) {
        for (var j = 0; i + j < 6; j++) {
          final r = 2.6 * (1 - (i + j) / 6.5);
          canvas.drawCircle(corner + Offset(sx * i * 6, sy * j * 6), r, fill);
        }
      }
    }
    canvas.drawPath(starburstPath(Offset(size.width - 14, 14), 8, points: 9), fill);
  }

  /// A thick ring round the window, a chevron across the hull above the fins, three
  /// halftone dots on the nose and a spark on its tip.
  @override
  void paintRocketDetails(Canvas canvas, {required Color trim, required Color accent}) {
    final fill = Paint()..color = trim;
    canvas.drawCircle(
      const Offset(0, -8),
      8,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-15.3, 5)
        ..lineTo(0, 12.5)
        ..lineTo(15.3, 5)
        ..lineTo(15.1, 10)
        ..lineTo(0, 17.5)
        ..lineTo(-15.1, 10)
        ..close(),
      fill,
    );
    for (final (x, y, r) in const [(0.0, -27.0, 1.8), (-4.0, -23.0, 1.3), (4.0, -23.0, 1.3)]) {
      canvas.drawCircle(Offset(x, y), r, fill);
    }
    canvas.drawPath(starburstPath(const Offset(0, -48), 4.5, points: 6), fill);
  }

  /// Speed lines that stream down under the hovering rocket, the middle ones longest, and
  /// a halftone dot at the end of each, as in a comic.
  @override
  void paintRocketTrail(Canvas canvas, Offset tail, double phase, {required Color trim, required Color flame}) {
    final line = Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final p = (phase + i * 0.37) % 1;
      final x = tail.dx + (i - 2) * 6.5;
      final top = tail.dy - 8 + p * 16;
      final length = 4 + 8 * (1 - (i - 2).abs() / 3) * (1 - p * 0.5);
      final colour = (i.isEven ? trim : flame).withValues(alpha: 0.9 * (1 - p));
      canvas.drawLine(Offset(x, top), Offset(x, top + length), line..color = colour);
      canvas.drawCircle(Offset(x, top + length + 3.5), 1.1, Paint()..color = colour);
    }
  }

  /// A comic starburst, the "POW" of a panel without the word: a jagged star in the
  /// accent with an edge of the trim, a smaller star of the trim inside, and action lines
  /// round it. It swells, then fades.
  @override
  void paintRocketBurst(Canvas canvas, Offset at, double t, {required Color trim, required Color accent}) {
    final grow = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    final alpha = t < 0.55 ? 1.0 : ((1 - t) / 0.45).clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final r = 8 + 16 * grow;
    final outer = starburstPath(at, r, points: 11, spin: t * 0.4);
    canvas.drawPath(outer, Paint()..color = accent.withValues(alpha: 0.92 * alpha));
    canvas.drawPath(
      outer,
      Paint()
        ..color = trim.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.miter,
    );
    final inner = starburstPath(at, r * 0.5, points: 7, spin: -t * 0.5);
    canvas.drawPath(inner, Paint()..color = trim.withValues(alpha: alpha));
    final lines = Paint()
      ..color = trim.withValues(alpha: 0.85 * alpha)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = 2 * pi * i / 8 + 0.2;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(at + d * (r * 1.15), at + d * (r * 1.15 + 5 + 4 * grow), lines);
    }
  }

  /// Speed lines that run along the rocket, either side of it, as the pad raises it.
  @override
  void paintRocketRise(Canvas canvas, Offset from, Offset to, double t, {required Color trim}) {
    final axis = to - from;
    if (axis.distance == 0) return;
    final normal = Offset(-axis.dy, axis.dx) / axis.distance;
    final line = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final along = (t * 2.5 + i / 4) % 1;
      final side = (i.isEven ? 1 : -1) * (13.0 + (i ~/ 2) * 7);
      final a = Offset.lerp(from, to, along)! + normal * side;
      final b = Offset.lerp(from, to, (along - 0.22).clamp(0.0, 1.0))! + normal * side;
      canvas.drawLine(a, b, line..color = trim.withValues(alpha: 0.3 + 0.55 * sin(along * pi)));
    }
  }
}

const comicLook = ComicLook();

/// A comic starburst round [c]: [points] spikes of [r], the notches between them at a
/// little over half of it, a little uneven, as drawn by hand. [spin] turns it.
Path starburstPath(Offset c, double r, {int points = 10, double spin = 0}) {
  final path = Path();
  final n = points * 2;
  for (var i = 0; i < n; i++) {
    final a = spin - pi / 2 + 2 * pi * i / n;
    final d = i.isEven ? r * (i % 4 == 0 ? 1 : 0.86) : r * 0.52;
    final p = c + Offset(cos(a) * d, sin(a) * d);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}
