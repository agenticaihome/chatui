import 'dart:math';

import 'package:flutter/material.dart';

import '../argus_theme.dart';

/// The look of the Grand Theft Auto palettes (lib/theme/groups/gta.dart): hard corners with
/// one corner cut, as a street poster; a thick edge of the trim; heavy, spaced labels on the
/// buttons; a strip of tape and a row of "wanted" stars on the cards; and a rocket with a
/// racing stripe that leaves banknotes and exhaust behind it and goes off in a burst of
/// stars. Drawn with a few paths: no image, no blur, no shader.
class StreetLook extends PaletteLook {
  const StreetLook();

  /// The cut of the corner: a share of the radius, the other corners all but square.
  static const _cut = 0.6;
  static const _square = Radius.circular(3);

  @override
  OutlinedBorder shape(double radius, {BorderSide side = BorderSide.none}) => BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: _square,
          topRight: Radius.circular(radius * _cut),
          bottomLeft: _square,
          bottomRight: _square,
        ),
        side: side,
      );

  @override
  OutlinedBorder sheetShape(double radius, {BorderSide side = BorderSide.none}) => BeveledRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: _square, topRight: Radius.circular(radius * _cut)),
        side: side,
      );

  @override
  TextStyle? get buttonText =>
      const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w900, letterSpacing: 1.8);

  @override
  BorderSide edge(PaletteSpec p) => BorderSide(color: p.trim.withValues(alpha: 0.8), width: 2);

  @override
  BorderSide buttonEdge(PaletteSpec p) => BorderSide(color: p.trim, width: 2.4);

  /// A strip of tape over the top left and the bottom right corners, a row of wanted stars
  /// in the top right (three of five lit), and a thick bracket in the bottom left corner.
  @override
  void paintOrnaments(Canvas canvas, Size size, Color trim) {
    if (size.shortestSide < 40) return;
    final s = (size.shortestSide / 220).clamp(0.6, 1.15);
    final tape = Paint()..color = trim.withValues(alpha: 0.55);
    _tape(canvas, Offset(16 * s, 16 * s), -pi / 4, 46 * s, 13 * s, tape);
    _tape(canvas, Offset(size.width - 16 * s, size.height - 16 * s), -pi / 4, 46 * s, 13 * s, tape);

    // The stars stop short of the cut corner.
    final count = size.width < 160 ? 3 : 5;
    final r = 5.2 * s;
    final step = r * 2.4;
    final fill = Paint()..color = trim;
    final ring = Paint()
      ..color = trim
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.2;
    for (var i = 0; i < count; i++) {
      final c = Offset(size.width - 18 * s - r - (count - 1 - i) * step, 12 * s);
      canvas.drawPath(starPath(c, r), i < (count + 1) ~/ 2 ? fill : ring);
    }

    final bracket = Paint()
      ..color = trim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.square;
    final corner = Offset(9 * s, size.height - 9 * s);
    canvas.drawPath(
      Path()
        ..moveTo(corner.dx, corner.dy - 16 * s)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(corner.dx + 16 * s, corner.dy),
      bracket,
    );
  }

  /// Two racing stripes from the nose to the tail under a ring of the trim round the window,
  /// and a star on the hull in the colour of the window.
  @override
  void paintRocketDetails(Canvas canvas, {required Color trim, required Color accent}) {
    canvas.save();
    canvas.clipPath(_hull);
    final stripe = Paint()..color = trim;
    canvas.drawRect(const Rect.fromLTRB(-5.5, -46, -2, 32), stripe);
    canvas.drawRect(const Rect.fromLTRB(2, -46, 5.5, 32), stripe);
    canvas.restore();
    canvas.drawCircle(const Offset(0, -8), 7, Paint()..color = accent);
    canvas.drawCircle(
      const Offset(0, -8),
      7.5,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawPath(starPath(const Offset(0, 17), 5.5), Paint()..color = accent);
  }

  /// Banknotes that flutter down under the hovering rocket, and puffs of exhaust.
  @override
  void paintRocketTrail(Canvas canvas, Offset tail, double phase, {required Color trim, required Color flame}) {
    for (var i = 0; i < 2; i++) {
      final p = (phase + i / 2) % 1;
      canvas.drawCircle(
        Offset(tail.dx + (i == 0 ? -5 : 5) * (1 + p), tail.dy + 4 + p * 16),
        3 + 6 * p,
        Paint()..color = flame.withValues(alpha: 0.35 * (1 - p)),
      );
    }
    for (var i = 0; i < 3; i++) {
      final p = (phase + i / 3) % 1;
      final at = Offset(tail.dx + (i - 1) * 10 + sin(p * 2 * pi + i * 2) * 5, tail.dy + 2 + p * 30);
      final alpha = (1 - p) * 0.95;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(sin(p * 3 * pi + i) * 0.9);
      canvas.drawRect(const Rect.fromLTWH(-5, -2.8, 10, 5.6), Paint()..color = trim.withValues(alpha: alpha));
      canvas.drawCircle(Offset.zero, 1.5, Paint()..color = flame.withValues(alpha: alpha));
      canvas.restore();
    }
  }

  /// Wanted stars that fly out and fade.
  @override
  void paintRocketBurst(Canvas canvas, Offset at, double t, {required Color trim, required Color accent}) {
    const count = 6;
    final alpha = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      final angle = -pi / 2 + 2 * pi * i / count + 0.3;
      final dist = 12 + 26 * t + (i.isEven ? 4 : 0);
      final r = (6 - (i % 3) * 1.2) * (1 - t * 0.5);
      canvas.drawPath(
        starPath(at + Offset(cos(angle) * dist, sin(angle) * dist), r, turn: t * 1.5 + i),
        Paint()..color = (i.isEven ? trim : accent).withValues(alpha: alpha),
      );
    }
  }

  /// Puffs of exhaust along the rocket as the pad raises it.
  @override
  void paintRocketRise(Canvas canvas, Offset from, Offset to, double t, {required Color trim}) {
    for (var i = 0; i < 3; i++) {
      final along = (t * 2 + i / 3) % 1;
      canvas.drawCircle(
        Offset.lerp(from, to, along * 0.6)! + Offset(-8 - 6 * along, 4 * i - 4),
        2.5 + 4 * along,
        Paint()..color = trim.withValues(alpha: 0.45 * (1 - along)),
      );
    }
  }
}

const streetLook = StreetLook();

/// The hull of the rocket (lib/ui/celaut/launch_rocket.dart), to keep the stripes on it.
final _hull = Path()
  ..moveTo(0, -44)
  ..quadraticBezierTo(18, -24, 15, 10)
  ..lineTo(13, 30)
  ..lineTo(-13, 30)
  ..lineTo(-15, 10)
  ..quadraticBezierTo(-18, -24, 0, -44)
  ..close();

/// A five-pointed star with its centre at [c] and its points [r] from it, one point up
/// unless [turn] (radians) turns it.
Path starPath(Offset c, double r, {double turn = 0}) {
  final path = Path();
  for (var k = 0; k < 10; k++) {
    final a = -pi / 2 + turn + k * pi / 5;
    final d = k.isEven ? r : r * 0.42;
    final p = c + Offset(cos(a) * d, sin(a) * d);
    k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// A strip of tape with torn ends, [length] long and [width] wide, at [c] turned by [angle].
void _tape(Canvas canvas, Offset c, double angle, double length, double width, Paint paint) {
  final half = length / 2, w = width / 2;
  final path = Path()..moveTo(-half, -w);
  path.lineTo(half, -w);
  // The torn end: a zigzag across the strip.
  for (var k = 1; k <= 4; k++) {
    path.lineTo(half + (k.isOdd ? 2 : 0), -w + width * k / 4);
  }
  path.lineTo(-half, w);
  for (var k = 1; k <= 4; k++) {
    path.lineTo(-half - (k.isOdd ? 2 : 0), w - width * k / 4);
  }
  path.close();
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  canvas.drawPath(path, paint);
  canvas.restore();
}
