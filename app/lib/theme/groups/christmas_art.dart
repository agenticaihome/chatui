import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../argus_theme.dart';
import '../scene_art.dart' show paintStars;
import 'christmas_look.dart';

// The drawings of the Christmas palettes over the home scene and the "theme" background of
// a chat ([SceneArtwork]). As in scene_art.dart, what text can fall on is thin, small or
// faint, or a mass in the colour of a ridge ([silhouetteColor]).

/// The scenes of the Christmas palettes.
enum ChristmasScene { village, snow, gingerbread, tree }

/// The drawings of the Christmas palettes: Christmas Eve a village with lit windows under
/// the sleigh that crosses the light, Snow big flakes over snowy pines, Gingerbread a house
/// with icing and gingerbread men under hanging cookies, the Tree a lit tree with its star
/// and strings of lights across the sky.
class ChristmasArt extends SceneArtwork {
  const ChristmasArt(this.scene);

  final ChristmasScene scene;

  @override
  void paintBack(
    Canvas canvas,
    Size size,
    SceneSpec spec, {
    required bool dark,
    required Offset light,
    required double strength,
  }) {
    switch (scene) {
      case ChristmasScene.village:
        paintStars(canvas, size, spec, dark, strength, seed: 53);
        _sleigh(canvas, size, spec, dark, light, strength);
      case ChristmasScene.snow:
        paintStars(canvas, size, spec, dark, strength * 0.7, seed: 61);
        _bigFlakes(canvas, size, spec, dark, strength);
      case ChristmasScene.gingerbread:
        paintStars(canvas, size, spec, dark, strength * 0.6, seed: 67);
        _hangingCookies(canvas, size, spec, dark, strength);
      case ChristmasScene.tree:
        paintStars(canvas, size, spec, dark, strength * 0.8, seed: 71);
        _stringsOfLights(canvas, size, spec, dark, strength);
    }
  }

  @override
  void paintFront(
    Canvas canvas,
    Size size,
    SceneSpec spec, {
    required bool dark,
    required double horizon,
    required double strength,
  }) {
    switch (scene) {
      case ChristmasScene.village:
        _village(canvas, size, spec, dark, horizon, strength);
        _snowfall(canvas, size, spec, dark, strength, count: 46, seed: 3);
      case ChristmasScene.snow:
        _snowyPines(canvas, size, spec, dark, horizon, strength);
        _snowfall(canvas, size, spec, dark, strength, count: 80, seed: 7);
      case ChristmasScene.gingerbread:
        _gingerbread(canvas, size, spec, dark, horizon, strength);
        _snowfall(canvas, size, spec, dark, strength, count: 30, seed: 13);
      case ChristmasScene.tree:
        _litTree(canvas, size, spec, dark, horizon, strength);
    }
  }
}

/// The size of a part of a drawing: a share of a phone's width, held in bounds on a small
/// tile and a wide window.
double _unit(Size size, double base) => (base * size.width / 390).clamp(base * 0.5, base * 1.6);

/// Snow that falls: small dots, white on a dark page and a pale blue-grey on a light one.
void _snowfall(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength,
    {required int count, required int seed}) {
  final random = math.Random(seed);
  final flake = dark ? Colors.white : Color.lerp(spec.glow, const Color(0xFF8FA6BF), 0.6)!;
  final paint = Paint();
  for (var i = 0; i < count; i++) {
    final p = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height * 0.95);
    final r = 0.8 + random.nextDouble() * 1.6;
    final a = (0.3 + random.nextDouble() * 0.4) * strength * (dark ? 1 : 0.6);
    canvas.drawCircle(p, r, paint..color = flake.withValues(alpha: a));
  }
}

/// Santa's sleigh and three reindeer that cross the light, small and dark against it, and a
/// trail of sparks behind.
void _sleigh(Canvas canvas, Size size, SceneSpec spec, bool dark, Offset light, double strength) {
  final u = _unit(size, 1.2);
  final body = Paint()..color = dark ? spec.ridges[1] : Color.alphaBlend(spec.ring.withValues(alpha: 0.5), spec.sky);
  final legs = Paint()
    ..color = body.color
    ..strokeWidth = 1.3 * u
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final sleigh = light + Offset(-6 * u, 18 * u);
  // The sleigh: a box with a high back and a runner that curls up in front.
  canvas.drawPath(
    Path()
      ..moveTo(sleigh.dx - 12 * u, sleigh.dy - 2 * u)
      ..lineTo(sleigh.dx + 9 * u, sleigh.dy - 2 * u)
      ..quadraticBezierTo(sleigh.dx + 13 * u, sleigh.dy - 12 * u, sleigh.dx + 16 * u, sleigh.dy - 11 * u)
      ..lineTo(sleigh.dx + 14 * u, sleigh.dy + 5 * u)
      ..lineTo(sleigh.dx - 9 * u, sleigh.dy + 5 * u)
      ..quadraticBezierTo(sleigh.dx - 13 * u, sleigh.dy + 3 * u, sleigh.dx - 12 * u, sleigh.dy - 2 * u)
      ..close(),
    body,
  );
  // Santa, a round back and a head over the sleigh, and his sack.
  canvas.drawCircle(sleigh + Offset(4 * u, -5 * u), 4.5 * u, body);
  canvas.drawCircle(sleigh + Offset(2 * u, -11 * u), 2.8 * u, body);
  canvas.drawCircle(sleigh + Offset(10 * u, -6 * u), 4 * u, body);
  canvas.drawPath(
    Path()
      ..moveTo(sleigh.dx - 13 * u, sleigh.dy + 8 * u)
      ..lineTo(sleigh.dx + 13 * u, sleigh.dy + 8 * u)
      ..quadraticBezierTo(sleigh.dx + 19 * u, sleigh.dy + 8 * u, sleigh.dx + 19 * u, sleigh.dy + 3 * u),
    legs,
  );
  // The reindeer, ahead and a little higher, on a rein.
  final reins = Path()..moveTo(sleigh.dx - 12 * u, sleigh.dy - 1 * u);
  for (var i = 0; i < 3; i++) {
    final deer = sleigh + Offset(-(30 + i * 22) * u, -(6 + i * 6) * u);
    _reindeer(canvas, deer, u, body, legs, i);
    reins.lineTo(deer.dx + 4 * u, deer.dy - 1 * u);
  }
  canvas.drawPath(
    reins,
    Paint()
      ..color = body.color
      ..strokeWidth = 0.8 * u
      ..style = PaintingStyle.stroke,
  );
  // The sparks it leaves, back toward the light.
  final random = math.Random(19);
  for (var i = 0; i < 7; i++) {
    final c = sleigh + Offset((22 + i * 11) * u, (6 + i * 2 + random.nextDouble() * 6) * u);
    canvas.drawPath(
      starPath(c, (1.6 + random.nextDouble() * 1.8) * u),
      Paint()..color = spec.trim.withValues(alpha: (dark ? 0.7 : 0.5) * strength * (1 - i / 9)),
    );
  }
}

/// A reindeer in flight facing left: a body, a neck and head, antlers and the legs tucked.
void _reindeer(Canvas canvas, Offset c, double u, Paint body, Paint legs, int stride) {
  canvas.drawOval(Rect.fromCenter(center: c, width: 15 * u, height: 6.5 * u), body);
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - 5 * u, c.dy - 1 * u)
      ..lineTo(c.dx - 9 * u, c.dy - 6 * u)
      ..lineTo(c.dx - 12.5 * u, c.dy - 5.5 * u)
      ..lineTo(c.dx - 12.5 * u, c.dy - 3.5 * u)
      ..lineTo(c.dx - 8.5 * u, c.dy - 3 * u)
      ..lineTo(c.dx - 4 * u, c.dy + 2 * u)
      ..close(),
    body,
  );
  final kick = stride.isEven ? 1.0 : -1.0;
  canvas.drawPath(
    Path()
      // The antlers.
      ..moveTo(c.dx - 9 * u, c.dy - 6 * u)
      ..lineTo(c.dx - 7 * u, c.dy - 10.5 * u)
      ..moveTo(c.dx - 8 * u, c.dy - 8 * u)
      ..lineTo(c.dx - 5.5 * u, c.dy - 9 * u)
      ..moveTo(c.dx - 9.5 * u, c.dy - 6 * u)
      ..lineTo(c.dx - 11 * u, c.dy - 10 * u)
      // The legs: the fore pair reach out, the hind pair kick back.
      ..moveTo(c.dx - 4 * u, c.dy + 2 * u)
      ..lineTo(c.dx - 9 * u, c.dy + (4 + kick) * u)
      ..moveTo(c.dx - 2 * u, c.dy + 2.5 * u)
      ..lineTo(c.dx - 6 * u, c.dy + 6 * u)
      ..moveTo(c.dx + 5 * u, c.dy + 2 * u)
      ..lineTo(c.dx + 10 * u, c.dy + (4 - kick) * u)
      ..moveTo(c.dx + 4 * u, c.dy + 2.5 * u)
      ..lineTo(c.dx + 7 * u, c.dy + 6.5 * u)
      // The tail.
      ..moveTo(c.dx + 7 * u, c.dy - 1 * u)
      ..lineTo(c.dx + 9 * u, c.dy - 3 * u),
    legs,
  );
}

/// Little houses along the horizon with snow on their roofs and lit windows, a chimney
/// each, and pines between them.
void _village(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final u = _unit(size, 13);
  final body = Paint()..color = silhouetteColor(spec, dark);
  final window = Paint()..color = spec.trim.withValues(alpha: (dark ? 0.85 : 0.6) * strength);
  final snow = Paint()
    ..color = Colors.white.withValues(alpha: (dark ? 0.55 : 0.95) * strength)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  // Small pines first, so the houses stand before them.
  for (final (fx, tall) in const [(0.3, 3.4), (0.36, 2.6), (0.5, 2.2), (0.56, 3.0), (0.71, 3.8)]) {
    _pine(canvas, Offset(w * fx, base), u * tall, body, snow: dark ? null : snow);
  }
  // The houses: where along the width, how wide and how tall the walls, in units.
  const houses = [
    (0.02, 2.4, 1.7), (0.14, 2.0, 2.4), (0.41, 1.7, 1.5), (0.61, 2.2, 1.9), (0.78, 2.8, 2.2), (0.93, 2.0, 1.6),
  ];
  for (final (i, (fx, hw, hh)) in houses.indexed) {
    final left = w * fx;
    final right = left + hw * u;
    final top = base - hh * u;
    final mid = (left + right) / 2;
    final roof = hw * u * 0.42;
    // The chimney first, behind the roof.
    canvas.drawRect(Rect.fromLTWH(right - hw * u * 0.3, top - roof * 0.9, u * 0.32, roof * 0.6), body);
    canvas.drawRect(Rect.fromLTRB(left, top, right, h), body);
    final eaves = Path()
      ..moveTo(left - u * 0.25, top + 1)
      ..lineTo(mid, top - roof)
      ..lineTo(right + u * 0.25, top + 1);
    canvas.drawPath(Path.from(eaves)..close(), body);
    canvas.drawPath(eaves, snow);
    // A window or two, lit, crossed by the bars.
    final panes = hw > 2.1 ? [left + hw * u * 0.28, left + hw * u * 0.72] : [mid];
    for (final x in panes) {
      final pane = Rect.fromCenter(center: Offset(x, top + hh * u * 0.42), width: u * 0.5, height: u * 0.5);
      canvas.drawRect(pane, window);
      canvas.drawLine(pane.topCenter, pane.bottomCenter, Paint()..color = body.color..strokeWidth = 1);
      canvas.drawLine(pane.centerLeft, pane.centerRight, Paint()..color = body.color..strokeWidth = 1);
    }
    // A wreath on the door of every other house.
    if (i.isOdd) {
      canvas.drawCircle(
        Offset(panes.length == 1 ? mid - u * 0.6 : mid, base - u * 0.55),
        u * 0.2,
        Paint()
          ..color = spec.trim.withValues(alpha: 0.7 * strength)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }
  // The snowy ground, down to the foot, where the page covers it.
  canvas.drawRect(Rect.fromLTRB(0, base - 1, w, h), body);
  canvas.drawLine(Offset(0, base - 1), Offset(w, base - 1), snow..strokeWidth = 1.4);
}

/// A pine of three tiers with its foot at [foot]; with [snow], a line of it along the lower
/// edge of each tier.
void _pine(Canvas canvas, Offset foot, double tall, Paint paint, {Paint? snow}) {
  final width = tall * 0.5;
  final path = Path();
  for (var k = 0; k < 3; k++) {
    final bottom = foot.dy - tall * (0.1 + k * 0.27);
    final top = bottom - tall * 0.42;
    final half = width * (1 - k * 0.25) / 2;
    path
      ..moveTo(foot.dx - half, bottom)
      ..lineTo(foot.dx, top)
      ..lineTo(foot.dx + half, bottom)
      ..close();
    if (snow != null) {
      canvas.drawLine(Offset(foot.dx - half * 0.8, bottom - 1), Offset(foot.dx + half * 0.8, bottom - 1), snow);
    }
  }
  path.addRect(Rect.fromLTRB(foot.dx - tall * 0.05, foot.dy - tall * 0.12, foot.dx + tall * 0.05, foot.dy + 2));
  canvas.drawPath(path, paint);
}

/// Large snowflakes, crystals of six branched arms, faint in the sky.
void _bigFlakes(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  const spots = [(0.08, 0.14, 15.0), (0.27, 0.32, 10.0), (0.46, 0.1, 19.0), (0.6, 0.38, 9.0), (0.14, 0.5, 8.0)];
  final colour = dark ? spec.trim : spec.glow;
  final u = _unit(size, 1);
  for (final (i, (fx, fy, r)) in spots.indexed) {
    paintSnowflake(
      canvas,
      Offset(size.width * fx, size.height * fy),
      r * u,
      Paint()
        ..color = colour.withValues(alpha: (dark ? 0.32 : 0.28) * strength)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
      turn: i * 0.3,
      branches: true,
    );
  }
}

/// A treeline of pines with snow on them over a drift of snow, taller to the sides.
void _snowyPines(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final random = math.Random(31);
  final body = Paint()..color = silhouetteColor(spec, dark);
  final snow = Paint()
    ..color = Colors.white.withValues(alpha: (dark ? 0.45 : 0.95) * strength)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  final u = _unit(size, 1);
  var x = -8.0;
  while (x < w + 20) {
    final edge = ((x / w) - 0.5).abs() * 2; // 0 in the middle, 1 at the sides
    final tall = (16 + 34 * edge + random.nextDouble() * 16) * u;
    _pine(canvas, Offset(x, base + 4 * u * (1 - edge)), tall, body, snow: snow);
    x += tall * (0.36 + random.nextDouble() * 0.24);
  }
  // The drifts: a soft swell of snow along the foot of the pines.
  final drift = Path()..moveTo(0, base + 2);
  for (var k = 0; k <= 6; k++) {
    final x0 = w * k / 6;
    drift.quadraticBezierTo(x0 + w / 12, base - (k.isEven ? 6 : 2) * u, x0 + w / 6, base + 2);
  }
  drift
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();
  canvas.drawPath(drift, body);
  canvas.drawPath(
    drift,
    Paint()
      ..color = Colors.white.withValues(alpha: (dark ? 0.22 : 0.9) * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
}

/// Cookies that hang from the top on threads: stars, hearts and a little gingerbread man,
/// in an outline of icing.
void _hangingCookies(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  const hangs = [(0.07, 0.2), (0.2, 0.32), (0.34, 0.16), (0.49, 0.27), (0.62, 0.12)];
  final u = _unit(size, 1);
  final icing = Paint()
    ..color = spec.trim.withValues(alpha: (dark ? 0.5 : 0.42) * strength)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final thread = Paint()
    ..color = spec.trim.withValues(alpha: (dark ? 0.25 : 0.22) * strength)
    ..strokeWidth = 0.8;
  for (final (i, (fx, fy)) in hangs.indexed) {
    final x = size.width * fx;
    final c = Offset(x, size.height * fy);
    final r = 10 * u;
    canvas.drawLine(Offset(x, 0), c - Offset(0, r), thread);
    switch (i % 3) {
      case 0:
        canvas.drawPath(starPath(c, r, turn: 0.1 * i), icing);
      case 1:
        canvas.drawPath(_heart(c, r), icing);
      default:
        _gingerbreadMan(canvas, c + Offset(0, r * 0.1), r * 2, icing);
    }
  }
}

Path _heart(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy + r)
  ..cubicTo(c.dx - r * 1.4, c.dy, c.dx - r * 0.8, c.dy - r * 1.1, c.dx, c.dy - r * 0.45)
  ..cubicTo(c.dx + r * 0.8, c.dy - r * 1.1, c.dx + r * 1.4, c.dy, c.dx, c.dy + r)
  ..close();

/// A gingerbread man [tall] high round [c]: a round head, arms out and legs apart. Filled
/// or in an outline, as [paint] says.
void _gingerbreadMan(Canvas canvas, Offset c, double tall, Paint paint) {
  final s = tall / 20;
  final path = Path()
    ..addOval(Rect.fromCircle(center: c + Offset(0, -6.5 * s), radius: 3.5 * s))
    ..moveTo(c.dx - 2.4 * s, c.dy - 3.4 * s)
    // An arm out to the left, down to the left leg, between the legs and round the right.
    ..lineTo(c.dx - 7.5 * s, c.dy - 2.8 * s)
    ..quadraticBezierTo(c.dx - 9 * s, c.dy - 1 * s, c.dx - 7.5 * s, c.dy + 0.2 * s)
    ..lineTo(c.dx - 3 * s, c.dy + 0.6 * s)
    ..lineTo(c.dx - 5.5 * s, c.dy + 8 * s)
    ..quadraticBezierTo(c.dx - 4 * s, c.dy + 10 * s, c.dx - 2 * s, c.dy + 8.5 * s)
    ..lineTo(c.dx, c.dy + 4.5 * s)
    ..lineTo(c.dx + 2 * s, c.dy + 8.5 * s)
    ..quadraticBezierTo(c.dx + 4 * s, c.dy + 10 * s, c.dx + 5.5 * s, c.dy + 8 * s)
    ..lineTo(c.dx + 3 * s, c.dy + 0.6 * s)
    ..lineTo(c.dx + 7.5 * s, c.dy + 0.2 * s)
    ..quadraticBezierTo(c.dx + 9 * s, c.dy - 1 * s, c.dx + 7.5 * s, c.dy - 2.8 * s)
    ..lineTo(c.dx + 2.4 * s, c.dy - 3.4 * s)
    ..close();
  canvas.drawPath(path, paint);
}

/// A gingerbread house on the right with icing along its roof, gumdrops on the ridge, lit
/// windows and a candy cane by the door; gingerbread men on the left.
void _gingerbread(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final u = _unit(size, 13);
  final body = Paint()..color = silhouetteColor(spec, dark);
  final icing = Paint()
    ..color = (dark ? spec.trim : Colors.white).withValues(alpha: (dark ? 0.7 : 0.95) * strength)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final window = Paint()..color = spec.trim.withValues(alpha: (dark ? 0.8 : 0.55) * strength);

  // The house: walls, a steep roof that overhangs, a chimney.
  final left = w * 0.6, right = w * 0.9;
  final mid = (left + right) / 2;
  final top = base - 3.2 * u;
  final peak = top - (right - left) * 0.48;
  canvas.drawRect(
    Rect.fromLTWH(right - (right - left) * 0.28, peak + (top - peak) * 0.25, u * 0.7, (top - peak) * 0.6),
    body,
  );
  canvas.drawRect(Rect.fromLTRB(left, top, right, h), body);
  canvas.drawPath(
    Path()
      ..moveTo(left - u * 0.6, top + u * 0.3)
      ..lineTo(mid, peak)
      ..lineTo(right + u * 0.6, top + u * 0.3)
      ..close(),
    body,
  );
  // Icing in scallops along both eaves.
  final eaves = Path();
  for (final side in const [-1.0, 1.0]) {
    final from = Offset(mid, peak + 2);
    final to = Offset(mid + side * ((right - left) / 2 + u * 0.6), top + u * 0.3);
    const n = 6;
    eaves.moveTo(from.dx, from.dy);
    for (var k = 0; k < n; k++) {
      final a = Offset.lerp(from, to, k / n)!;
      final b = Offset.lerp(from, to, (k + 1) / n)!;
      final dip = (a + b) / 2 + Offset(0, u * 0.35);
      eaves.quadraticBezierTo(dip.dx, dip.dy, b.dx, b.dy);
    }
  }
  canvas.drawPath(eaves, icing);
  // Gumdrops on the ridge and the corners.
  for (final (p, colour) in [
    (Offset(mid, peak - 1), spec.accent),
    (Offset(left - u * 0.6, top + u * 0.1), spec.trim),
    (Offset(right + u * 0.6, top + u * 0.1), spec.trim),
  ]) {
    canvas.drawCircle(p, u * 0.28, Paint()..color = colour.withValues(alpha: 0.9 * strength));
  }
  // Two round windows, lit, with icing round them, and the door between in an arch.
  for (final fx in const [0.2, 0.8]) {
    final c = Offset(left + (right - left) * fx, top + u * 1.2);
    canvas.drawCircle(c, u * 0.45, window);
    canvas.drawCircle(c, u * 0.62, icing);
  }
  final door = Path()
    ..moveTo(mid - u * 0.6, base)
    ..lineTo(mid - u * 0.6, base - u * 1.3)
    ..arcToPoint(Offset(mid + u * 0.6, base - u * 1.3), radius: Radius.circular(u * 0.6))
    ..lineTo(mid + u * 0.6, base);
  canvas.drawPath(door, icing);
  // A candy cane stuck in the ground by the house, striped.
  _candyCane(canvas, Offset(left - u * 1.1, base), u * 2.4, spec, strength);

  // The gingerbread men, on the left, in a line of icing with buttons.
  final outline = Paint()
    ..color = icing.color.withValues(alpha: icing.color.a * 0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeJoin = StrokeJoin.round;
  for (final (fx, tall) in const [(0.08, 2.6), (0.19, 3.3), (0.3, 2.3)]) {
    final c = Offset(w * fx, base - tall * u * 0.5);
    _gingerbreadMan(canvas, c, tall * u, body);
    _gingerbreadMan(canvas, c, tall * u, outline);
    final s = tall * u / 20;
    final dot = Paint()..color = (dark ? spec.trim : spec.accent).withValues(alpha: 0.75 * strength);
    for (final dy in const [-1.2, 1.4]) {
      canvas.drawCircle(c + Offset(0, dy * s), 0.75 * s, dot);
    }
    canvas.drawLine(
      c + Offset(-6.5 * s, -2.2 * s),
      c + Offset(-6.5 * s, -0.4 * s),
      icing..strokeWidth = 1.1,
    );
    canvas.drawLine(c + Offset(6.5 * s, -2.2 * s), c + Offset(6.5 * s, -0.4 * s), icing);
    icing.strokeWidth = 1.6;
  }
  canvas.drawRect(Rect.fromLTRB(0, base - 1, w, h), body);
  canvas.drawLine(
    Offset(0, base - 1),
    Offset(w, base - 1),
    Paint()
      ..color = Colors.white.withValues(alpha: (dark ? 0.3 : 0.9) * strength)
      ..strokeWidth = 1.4,
  );
}

/// A candy cane [tall] high standing at [foot]: a hook of the trim with stripes of the
/// accent.
void _candyCane(Canvas canvas, Offset foot, double tall, SceneSpec spec, double strength) {
  final hook = tall * 0.22;
  final path = Path()
    ..moveTo(foot.dx, foot.dy)
    ..lineTo(foot.dx, foot.dy - tall + hook)
    ..arcToPoint(Offset(foot.dx + hook * 2, foot.dy - tall + hook), radius: Radius.circular(hook))
    ..lineTo(foot.dx + hook * 2, foot.dy - tall + hook * 1.8);
  final width = tall * 0.1;
  canvas.drawPath(
    path,
    Paint()
      ..color = spec.trim.withValues(alpha: 0.9 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  final stripes = Path();
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += width * 1.8) {
      stripes.addPath(metric.extractPath(d, d + width * 0.8), Offset.zero);
    }
  }
  canvas.drawPath(
    stripes,
    Paint()
      ..color = spec.accent.withValues(alpha: 0.9 * strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width,
  );
}

/// Festive bulbs: the trim, the accent, a red and a blue.
List<Color> _bulbs(SceneSpec spec) => [spec.trim, const Color(0xFFE0474C), spec.accent, const Color(0xFF5B9BE0)];

/// Two strings of lights that swag across the sky, each bulb a dot with a soft glow.
void _stringsOfLights(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final u = _unit(size, 1);
  final wire = Paint()
    ..color = (dark ? Colors.white : spec.ring).withValues(alpha: (dark ? 0.16 : 0.3) * strength)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9;
  final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  final bulb = Paint();
  final colours = _bulbs(spec);
  var n = 0;
  for (final (y, sag, swags) in [(0.05, 0.08, 2), (0.0, 0.05, 3)]) {
    final top = h * y;
    final span = w / swags;
    for (var k = 0; k < swags; k++) {
      final a = Offset(span * k, top);
      final b = Offset(span * (k + 1), top);
      final ctrl = Offset((a.dx + b.dx) / 2, top + h * sag * 2);
      canvas.drawPath(Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy), wire);
      final count = (span / (20 * u)).floor();
      for (var i = 1; i < count; i++) {
        final t = i / count;
        final p = Offset.lerp(Offset.lerp(a, ctrl, t)!, Offset.lerp(ctrl, b, t)!, t)!;
        final colour = colours[n++ % colours.length];
        final halo = colour.withValues(alpha: (dark ? 0.35 : 0.25) * strength);
        canvas.drawCircle(p + Offset(0, 3 * u), 5 * u, glow..color = halo);
        canvas.drawOval(
          Rect.fromCenter(center: p + Offset(0, 3 * u), width: 3.6 * u, height: 5 * u),
          bulb..color = colour.withValues(alpha: (dark ? 0.9 : 0.8) * strength),
        );
      }
    }
  }
}

/// A tall tree on the left with lights, a star on its top and presents at its foot, and
/// small pines with lights on the right.
void _litTree(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final body = Paint()..color = silhouetteColor(spec, dark);
  final u = _unit(size, 1);
  final colours = _bulbs(spec);
  final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final bulb = Paint();
  void light(Offset p, int i, double r) {
    final colour = colours[i % colours.length];
    canvas.drawCircle(p, r * 2.4, glow..color = colour.withValues(alpha: (dark ? 0.4 : 0.25) * strength));
    canvas.drawCircle(p, r, bulb..color = colour.withValues(alpha: (dark ? 0.95 : 0.85) * strength));
  }

  // The small pines on the right, behind the ground.
  for (final (fx, tall) in const [(0.66, 46.0), (0.79, 64.0), (0.92, 52.0)]) {
    final foot = Offset(w * fx, base);
    _pine(canvas, foot, tall * u, body);
    for (var i = 0; i < 5; i++) {
      final along = 0.25 + i * 0.13;
      final half = tall * u * 0.25 * (1 - along) * 1.1;
      final at = Offset(foot.dx + (i.isEven ? -half : half) * 0.6, foot.dy - tall * u * along);
      light(at, i + (fx * 10).round(), 1.4 * u);
    }
  }

  // The big tree: five tiers, wider below, on a trunk.
  final x = w * 0.22;
  final tall = math.min(h * 0.42, w * 0.55);
  final tree = Path();
  const tiers = 5;
  for (var k = 0; k < tiers; k++) {
    final bottom = base - tall * (0.06 + k * 0.17);
    final top = bottom - tall * 0.3;
    final half = tall * 0.36 * (1 - k * 0.17);
    tree
      ..moveTo(x - half, bottom)
      ..quadraticBezierTo(x - half * 0.45, bottom - tall * 0.04, x, top)
      ..quadraticBezierTo(x + half * 0.45, bottom - tall * 0.04, x + half, bottom)
      ..quadraticBezierTo(x, bottom + tall * 0.03, x - half, bottom)
      ..close();
  }
  tree.addRect(Rect.fromLTRB(x - tall * 0.04, base - tall * 0.08, x + tall * 0.04, base + 2));
  canvas.drawPath(tree, body);
  // Garlands of lights across the tree, sloping down to the left.
  var n = 0;
  for (var k = 0; k < 4; k++) {
    final y = base - tall * (0.14 + k * 0.17);
    final half = tall * 0.32 * (1 - k * 0.17);
    for (var i = 0; i <= 5; i++) {
      final t = i / 5;
      final p = Offset(x - half + 2 * half * t, y - tall * 0.05 * t + tall * 0.02 * math.sin(t * math.pi));
      light(p, n++, 1.6 * u);
    }
  }
  // The star on the top, with a glow round it.
  final star = Offset(x, base - tall * (0.06 + (tiers - 1) * 0.17) - tall * 0.3);
  canvas.drawCircle(
    star,
    12 * u,
    Paint()
      ..color = spec.trim.withValues(alpha: (dark ? 0.35 : 0.3) * strength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawPath(starPath(star, 8 * u), Paint()..color = spec.trim.withValues(alpha: strength));

  // Presents at its foot, each tied with a ribbon of the trim.
  final ribbon = Paint()
    ..color = spec.trim.withValues(alpha: 0.8 * strength)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  for (final (dx, bw, bh) in const [(-0.3, 0.16, 0.1), (0.14, 0.2, 0.08), (0.32, 0.12, 0.13)]) {
    final box = Rect.fromLTWH(x + tall * dx, base - tall * bh, tall * bw, tall * bh);
    canvas.drawRect(box, body);
    canvas.drawRect(box, ribbon);
    canvas.drawLine(box.topCenter, box.bottomCenter, ribbon);
    paintBow(canvas, box.topCenter, (tall / 180) * 0.7, spec.trim.withValues(alpha: 0.85 * strength));
  }
  canvas.drawRect(Rect.fromLTRB(0, base - 1, w, h), body);
}
