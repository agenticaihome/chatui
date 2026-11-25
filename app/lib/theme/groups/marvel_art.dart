import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../arcane.dart' show paintSpark;
import '../argus_theme.dart';
import '../scene_art.dart';

// The drawings of the Marvel palettes ([MarvelArt]): each hero by colours and generic
// motifs only, no emblem and no face. Everything that text can fall on is thin, small or
// faint, or a mass in the colour of a ridge ([silhouetteColor]).

/// The scenes of the Marvel palettes.
enum MarvelScene { ironMan, spiderMan, hulk, thor }

/// The drawings of the Marvel palettes: Iron Man the glowing rings of a reactor round the
/// light, a skyline and the trails of a flight; Spider-Man a web in the corner and strands
/// over a skyline; Hulk gamma rays from the light and rock flung up from a cracked ground;
/// Thor storm clouds, lightning bolts and rain. Halftone dots shade a part of the sky of the
/// first three.
class MarvelArt extends SceneArtwork {
  const MarvelArt(this.scene);

  final MarvelScene scene;

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
      case MarvelScene.ironMan:
        paintStars(canvas, size, spec, dark, strength * 0.7, seed: 51);
        _halftone(canvas, size, spec, dark, strength, Offset.zero);
        _reactor(canvas, size, spec, dark, light, strength);
      case MarvelScene.spiderMan:
        paintStars(canvas, size, spec, dark, strength * 0.7, seed: 53);
        _halftone(canvas, size, spec, dark, strength, Offset(size.width, size.height * 0.55));
        _web(canvas, size, spec, dark, strength);
      case MarvelScene.hulk:
        _gammaRays(canvas, size, spec, dark, light, strength);
        _halftone(canvas, size, spec, dark, strength, Offset.zero);
      case MarvelScene.thor:
        paintStars(canvas, size, spec, dark, strength * 0.5, seed: 57);
        _clouds(canvas, size, spec, dark, strength);
        _lightning(canvas, size, spec, dark, strength);
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
      case MarvelScene.ironMan:
        _flightTrails(canvas, size, spec, dark, horizon, strength);
        _skyline(canvas, size, spec, dark, horizon, strength, seed: 7, from: 0, to: 0.42, lit: spec.trim);
      case MarvelScene.spiderMan:
        final roofs = _skyline(canvas, size, spec, dark, horizon, strength, seed: 3, from: 0, to: 1, lit: spec.accent);
        _strands(canvas, size, spec, dark, strength, roofs);
      case MarvelScene.hulk:
        _rubble(canvas, size, spec, dark, horizon, strength);
        paintMotes(canvas, size, spec.accent, dark, strength, count: 14, seed: 61, glow: true);
      case MarvelScene.thor:
        _rain(canvas, size, spec, dark, strength);
        final random = math.Random(67);
        for (var i = 0; i < 6; i++) {
          final c = Offset(random.nextDouble() * size.width, size.height * (0.3 + random.nextDouble() * 0.5));
          paintSpark(
            canvas,
            c,
            2 + random.nextDouble() * 2.5,
            Paint()..color = spec.trim.withValues(alpha: (dark ? 0.55 : 0.45) * strength),
          );
        }
    }
  }
}

/// Halftone dots round [centre], larger near it and none past its reach: the shade of a
/// printed comic. Drawn as a few batches of points, one per size of dot.
void _halftone(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength, Offset centre) {
  final w = size.width, h = size.height;
  final reach = math.max(w, h) * 0.5;
  final step = (reach / 22).clamp(5.0, 11.0);
  const bands = 4;
  final points = [for (var i = 0; i < bands; i++) <Offset>[]];
  for (var y = step / 2; y < h; y += step) {
    // Every other row shifts by half a step, as a printed screen.
    final shift = ((y / step).floor().isOdd) ? step / 2 : 0.0;
    for (var x = step / 2 + shift; x < w; x += step) {
      final near = 1 - (Offset(x, y) - centre).distance / reach;
      if (near <= 0.08) continue;
      points[(near * bands).floor().clamp(0, bands - 1)].add(Offset(x, y));
    }
  }
  final colour = (dark ? spec.trim : spec.accent).withValues(alpha: (dark ? 0.13 : 0.09) * strength);
  for (var i = 0; i < bands; i++) {
    if (points[i].isEmpty) continue;
    canvas.drawPoints(
      ui.PointMode.points,
      points[i],
      Paint()
        ..color = colour
        ..strokeCap = StrokeCap.round
        ..strokeWidth = step * (0.18 + 0.16 * i),
    );
  }
}

/// The rings of a reactor round the light: two thin rings of the trim, a ring of glowing
/// segments between them and a faint glow.
void _reactor(Canvas canvas, Size size, SceneSpec spec, bool dark, Offset light, double strength) {
  final r = size.shortestSide * 0.2;
  if (r < 6) return;
  // The glow of the core: the cold blue-white of a reactor by night, the accent by day.
  final core = dark ? const Color(0xFFBDEFFF) : spec.glow;
  canvas.drawCircle(
    light,
    r * 1.3,
    Paint()
      ..color = core.withValues(alpha: (dark ? 0.08 : 0.06) * strength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
  );
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = spec.trim.withValues(alpha: (dark ? 0.45 : 0.4) * strength);
  canvas.drawCircle(light, r * 1.12, ring);
  canvas.drawCircle(light, r * 1.62, ring);
  final segment = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.1
    ..color = core.withValues(alpha: (dark ? 0.3 : 0.22) * strength);
  const count = 10;
  for (var i = 0; i < count; i++) {
    final start = 2 * math.pi * i / count;
    canvas.drawArc(Rect.fromCircle(center: light, radius: r * 1.37), start, 2 * math.pi / count * 0.7, false, segment);
  }
  // Short ticks outside, as on a dial.
  final tick = Paint()
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round
    ..color = spec.trim.withValues(alpha: (dark ? 0.35 : 0.3) * strength);
  for (var i = 0; i < 24; i++) {
    final a = 2 * math.pi * i / 24;
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(light + d * (r * 1.72), light + d * (r * (i.isEven ? 1.86 : 1.8)), tick);
  }
}

/// Two trails of a flight that sweep up across the sky, each a thin line in the trim with
/// a bright head.
void _flightTrails(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  for (var i = 0; i < 2; i++) {
    final start = Offset(w * (0.18 + i * 0.12), h * horizon * (0.95 - i * 0.1));
    final end = Offset(w * (0.62 + i * 0.16), h * (0.16 + i * 0.12));
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(w * (0.3 + i * 0.1), h * (0.2 + i * 0.1), end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = (i.isEven ? spec.trim : spec.accent).withValues(alpha: (dark ? 0.4 : 0.3) * strength),
    );
    canvas.drawCircle(
      end,
      5,
      Paint()
        ..color = spec.trim.withValues(alpha: (dark ? 0.3 : 0.2) * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(end, 1.8, Paint()..color = spec.trim.withValues(alpha: (dark ? 0.9 : 0.7) * strength));
  }
}

/// A skyline between [from] and [to] (shares of the width) with its foot at [horizon]:
/// towers of the colour of a ridge, a few lit windows in [lit], an antenna or a water tank
/// on some roofs. Returns the tops of the roofs, for what hangs from them.
List<Offset> _skyline(
  Canvas canvas,
  Size size,
  SceneSpec spec,
  bool dark,
  double horizon,
  double strength, {
  required int seed,
  required double from,
  required double to,
  required Color lit,
}) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final unit = (w / 22).clamp(4.0, 28.0);
  final random = math.Random(seed);
  final body = Paint()..color = silhouetteColor(spec, dark);
  final window = Paint()..color = lit.withValues(alpha: (dark ? 0.7 : 0.45) * strength);
  final line = Paint()
    ..color = silhouetteColor(spec, dark)
    ..strokeWidth = 1.2;
  final roofs = <Offset>[];
  var x = w * from - unit * 0.3;
  while (x < w * to) {
    final width = unit * (1.2 + random.nextDouble() * 1.4);
    // Taller to the sides, so the middle of the scene stays open.
    final edge = ((x + width / 2) / w - 0.5).abs() * 2;
    final tall = unit * (0.9 + 2.6 * edge * edge + random.nextDouble() * 1.5);
    final top = base - tall;
    canvas.drawRect(Rect.fromLTRB(x, top, x + width, h), body);
    roofs.add(Offset(x + width / 2, top));
    final kind = random.nextInt(4);
    if (kind == 0) {
      // A stepped top and an antenna.
      canvas.drawRect(Rect.fromLTRB(x + width * 0.25, top - unit * 0.5, x + width * 0.75, top), body);
      canvas.drawLine(Offset(x + width / 2, top - unit * 0.5), Offset(x + width / 2, top - unit * 1.5), line);
    } else if (kind == 1) {
      // A water tank on legs.
      final cx = x + width * 0.35;
      canvas.drawRect(Rect.fromLTRB(cx - unit * 0.25, top - unit * 0.75, cx + unit * 0.25, top - unit * 0.3), body);
      canvas.drawPath(
        Path()
          ..moveTo(cx - unit * 0.3, top - unit * 0.75)
          ..lineTo(cx, top - unit * 0.98)
          ..lineTo(cx + unit * 0.3, top - unit * 0.75)
          ..close(),
        body,
      );
      canvas.drawLine(Offset(cx - unit * 0.2, top - unit * 0.3), Offset(cx - unit * 0.2, top), line);
      canvas.drawLine(Offset(cx + unit * 0.2, top - unit * 0.3), Offset(cx + unit * 0.2, top), line);
    }
    // A few lit windows in a grid.
    final pane = unit * 0.18;
    for (var wy = top + unit * 0.45; wy < base - unit * 0.3; wy += unit * 0.55) {
      for (var wx = x + unit * 0.3; wx < x + width - unit * 0.25; wx += unit * 0.45) {
        if (random.nextDouble() > 0.28) continue;
        canvas.drawRect(Rect.fromLTWH(wx, wy, pane, pane * 1.3), window);
      }
    }
    x += width + unit * (0.05 + random.nextDouble() * 0.2);
  }
  return roofs;
}

/// A web in the upper left corner: threads that fan out from the corner and rings that
/// sag between them.
void _web(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final reach = math.min(size.width * 0.55, size.height * 0.7);
  if (reach < 12) return;
  const corner = Offset(-4, -4);
  const spokes = 7;
  final thread = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round
    ..color = (dark ? Colors.white : spec.ring).withValues(alpha: (dark ? 0.22 : 0.24) * strength);
  final ends = <double>[];
  for (var i = 0; i < spokes; i++) {
    final a = (math.pi / 2) * (i + 0.15) / (spokes - 0.7);
    ends.add(a);
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(corner, corner + d * reach * (i.isEven ? 1 : 0.92), thread);
  }
  for (var k = 1; k <= 5; k++) {
    final r = reach * k / 5.4;
    final path = Path();
    for (var i = 0; i < spokes - 1; i++) {
      final a = corner + Offset(math.cos(ends[i]), math.sin(ends[i])) * r;
      final b = corner + Offset(math.cos(ends[i + 1]), math.sin(ends[i + 1])) * r;
      // Each span sags toward the corner, as a thread under its weight.
      final half = (ends[i] + ends[i + 1]) / 2;
      final mid = corner + Offset(math.cos(half), math.sin(half)) * r * 0.86;
      if (i == 0) path.moveTo(a.dx, a.dy);
      path.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(path, thread);
  }
}

/// Strands of web that drop from the top of the scene to some of the roofs, and one that
/// swings out over the street.
void _strands(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength, List<Offset> roofs) {
  if (roofs.isEmpty) return;
  final strand = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round
    ..color = (dark ? Colors.white : spec.ring).withValues(alpha: (dark ? 0.32 : 0.35) * strength);
  for (var i = 1; i < roofs.length; i += 3) {
    final roof = roofs[i];
    final top = Offset(roof.dx + (i.isEven ? 18 : -18), 0);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo((top.dx + roof.dx) / 2 + 6, roof.dy * 0.6, roof.dx, roof.dy),
      strand,
    );
  }
  // A strand between two roofs, sagging.
  if (roofs.length > 3) {
    final a = roofs[1], b = roofs[3];
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + 18, b.dx, b.dy),
      strand,
    );
  }
  // One that swings from high up, with a small knot at its end.
  final anchor = Offset(size.width * 0.58, 0);
  final end = Offset(size.width * 0.42, size.height * 0.4);
  canvas.drawLine(anchor, end, strand);
  canvas.drawCircle(end, 2.2, Paint()..color = spec.accent.withValues(alpha: (dark ? 0.8 : 0.6) * strength));
}

/// Gamma rays: wedges of the accent and the trim that spread from the light across the
/// sky, as the rays round a hero on a cover.
void _gammaRays(Canvas canvas, Size size, SceneSpec spec, bool dark, Offset light, double strength) {
  final reach = size.longestSide * 1.1;
  const count = 16;
  for (var i = 0; i < count; i++) {
    final a = 2 * math.pi * i / count + 0.1;
    const spread = 2 * math.pi / count * 0.28;
    final colour = i.isEven ? spec.accent : spec.trim;
    canvas.drawPath(
      Path()
        ..moveTo(light.dx, light.dy)
        ..lineTo(light.dx + math.cos(a - spread) * reach, light.dy + math.sin(a - spread) * reach)
        ..lineTo(light.dx + math.cos(a + spread) * reach, light.dy + math.sin(a + spread) * reach)
        ..close(),
      Paint()..color = colour.withValues(alpha: (dark ? 0.07 : 0.06) * strength),
    );
  }
}

/// The mark of a smash on the ground at the horizon: slabs of rock that jut up and lean
/// away from the point of impact, gamma light in the cracks that run out from it, and
/// shards flung up into the air.
void _rubble(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final unit = (w / 26).clamp(3.0, 24.0);
  final rock = Paint()..color = silhouetteColor(spec, dark);
  final random = math.Random(71);
  final impact = Offset(w * 0.34, base);
  // The ground: low and a little uneven, down to the foot, where the page covers it.
  final ground = Path()..moveTo(0, h);
  for (var x = 0.0; x <= w + unit; x += unit * 1.5) {
    ground.lineTo(x, base - unit * (0.15 + random.nextDouble() * 0.35));
  }
  ground
    ..lineTo(w + unit, h)
    ..close();
  canvas.drawPath(ground, rock);
  // The glow of the impact.
  canvas.drawOval(
    Rect.fromCenter(center: impact, width: unit * 9, height: unit * 2.4),
    Paint()
      ..color = spec.accent.withValues(alpha: (dark ? 0.16 : 0.12) * strength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.8),
  );
  // Slabs either side of the impact, taller near it, leaning away.
  final edgeLight = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round
    ..color = spec.accent.withValues(alpha: (dark ? 0.6 : 0.45) * strength);
  for (final k in const [-3, -2, -1, 1, 2, 3]) {
    final away = k.sign.toDouble();
    final x = impact.dx + k * unit * 1.9 - away * unit * 0.6;
    final width = unit * (1.7 + random.nextDouble() * 0.6);
    final tall = unit * (3.4 - k.abs() * 0.8 + random.nextDouble() * 0.6);
    final lean = away * unit * (0.5 + random.nextDouble() * 0.5);
    final inner = Offset(x - away * width / 2 + lean * 0.6, base - tall);
    final outer = Offset(x + away * width / 2 + lean, base - tall * 0.7);
    canvas.drawPath(
      Path()
        ..moveTo(x - away * width / 2, base + 2)
        ..lineTo(inner.dx, inner.dy)
        ..lineTo(outer.dx, outer.dy)
        ..lineTo(x + away * width / 2, base + 2)
        ..close(),
      rock,
    );
    // The face that turns to the impact, and the broken top, catch its light.
    canvas.drawPath(
      Path()
        ..moveTo(x - away * width / 2, base)
        ..lineTo(inner.dx, inner.dy)
        ..lineTo(outer.dx, outer.dy),
      edgeLight,
    );
  }
  // The cracks that run out along the ground, glowing.
  final crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = spec.accent.withValues(alpha: (dark ? 0.6 : 0.45) * strength);
  for (final angle in const [0.06, 0.2, 0.42, 2.72, 2.94, 3.08]) {
    var p = impact + Offset(0, unit * 0.3);
    final path = Path()..moveTo(p.dx, p.dy);
    for (var k = 0; k < 5; k++) {
      final a = angle + (random.nextDouble() - 0.5) * 0.7;
      p += Offset(math.cos(a), math.sin(a)) * unit * (1 + random.nextDouble() * 0.8);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, crack);
  }
  // Shards flung up from the impact.
  for (var i = 0; i < 9; i++) {
    final a = -math.pi * (0.15 + 0.7 * i / 8) + (random.nextDouble() - 0.5) * 0.2;
    final c = impact + Offset(math.cos(a) * 1.3, math.sin(a)) * unit * (3.2 + random.nextDouble() * 3.5);
    final r = unit * (0.25 + random.nextDouble() * 0.4);
    final turn = random.nextDouble() * math.pi;
    final path = Path();
    for (var k = 0; k < 4; k++) {
      final b = turn + k * math.pi / 2 + (random.nextDouble() - 0.5) * 0.8;
      final p = c + Offset(math.cos(b), math.sin(b)) * r * (0.6 + random.nextDouble() * 0.6);
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path..close(), rock);
  }
}

/// A band of storm clouds along the top of the sky, of puffs a shade off it.
void _clouds(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final unit = (w / 9).clamp(8.0, 70.0);
  final random = math.Random(73);
  final colour = dark
      ? Color.lerp(spec.sky, Colors.white, 0.06)!.withValues(alpha: 0.9 * strength)
      : Color.lerp(spec.sky, spec.ring.withValues(alpha: 1), 0.07)!.withValues(alpha: 0.9 * strength);
  final shade = dark
      ? spec.ridges[1].withValues(alpha: 0.5 * strength)
      : Color.lerp(spec.sky, spec.ring.withValues(alpha: 1), 0.12)!.withValues(alpha: 0.6 * strength);
  final puffs = Path();
  final under = Path();
  var x = -unit * 0.5;
  while (x < w + unit) {
    final r = unit * (0.5 + random.nextDouble() * 0.45);
    final y = h * 0.05 + random.nextDouble() * unit * 0.5;
    puffs.addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    under.addOval(Rect.fromCircle(center: Offset(x + r * 0.3, y + r * 0.45), radius: r * 0.7));
    x += r * 1.1;
  }
  canvas.drawPath(under, Paint()..color = shade);
  canvas.drawPath(puffs, Paint()..color = colour);
}

/// Lightning bolts that fork down from the clouds: a faint glow and a bright core each, in
/// the trim.
void _lightning(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final random = math.Random(79);
  for (final (fx, reach) in const [(0.22, 0.5), (0.68, 0.36)]) {
    var p = Offset(w * fx, h * 0.12);
    final bolt = Path()..moveTo(p.dx, p.dy);
    final steps = 6;
    Offset? fork;
    for (var k = 0; k < steps; k++) {
      p += Offset((k.isEven ? 1 : -1) * w * (0.02 + random.nextDouble() * 0.03), h * reach / steps);
      bolt.lineTo(p.dx, p.dy);
      if (k == 2) fork = p;
    }
    if (fork != null) {
      var q = fork;
      bolt.moveTo(q.dx, q.dy);
      for (var k = 0; k < 3; k++) {
        q += Offset(w * 0.03, h * reach / steps * 0.7);
        bolt.lineTo(q.dx, q.dy);
      }
    }
    canvas.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.miter
        ..color = (dark ? spec.trim : spec.glow).withValues(alpha: (dark ? 0.12 : 0.08) * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.miter
        ..color = (dark ? spec.trim : spec.glow).withValues(alpha: (dark ? 0.75 : 0.5) * strength),
    );
  }
}

/// Rain that falls aslant across the scene, in short thin strokes.
void _rain(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final random = math.Random(83);
  final drop = Paint()
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round
    ..color = (dark ? spec.trim : spec.ring.withValues(alpha: 1)).withValues(alpha: (dark ? 0.16 : 0.14) * strength);
  final count = (w * h / 3000).clamp(10, 90).round();
  for (var i = 0; i < count; i++) {
    final p = Offset(random.nextDouble() * w, h * (0.15 + random.nextDouble() * 0.8));
    canvas.drawLine(p, p + const Offset(-4, 11), drop);
  }
}
