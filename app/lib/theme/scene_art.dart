import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'arcane.dart' show paintSpark;
import 'argus_theme.dart';

// The art of the Harry Potter palettes ([SceneArt]), drawn with paths over the home scene and
// as the "theme" background of a chat: no image. Everything that text can fall on is thin,
// small or faint, or is a mass in the colour of a ridge that the contrast tests already
// check, so the type of the page keeps its contrast.

/// The part of the art behind the ridges of the home scene: the sky's stars, the candles,
/// the wisps and the feathers. [light] is where the light of the scene is.
void paintSceneArtBack(
  Canvas canvas,
  Size size,
  SceneSpec spec, {
  required bool dark,
  required Offset light,
  double strength = 1,
}) {
  if (spec.art == SceneArt.none || size.isEmpty) return;
  switch (spec.art) {
    case SceneArt.none:
      return;
    case SceneArt.greatHall:
      _stars(canvas, size, spec, dark, strength, seed: 11);
      _candles(canvas, size, spec, dark, strength);
    case SceneArt.castle:
      _stars(canvas, size, spec, dark, strength, seed: 23);
    case SceneArt.forest:
      _stars(canvas, size, spec, dark, strength * 0.6, seed: 37);
    case SceneArt.patronus:
      _stars(canvas, size, spec, dark, strength, seed: 41);
      _wisps(canvas, size, spec, dark, light, strength);
    case SceneArt.phoenix:
      _feathers(canvas, size, spec, dark, light, strength);
  }
}

/// The part of the art over the ridges: the castle and the pines, which stand against the
/// lit crests with their foot at [horizon] (a share of the height), and the fireflies,
/// sparks and embers that float in the air.
void paintSceneArtFront(
  Canvas canvas,
  Size size,
  SceneSpec spec, {
  required bool dark,
  double horizon = 0.62,
  double strength = 1,
}) {
  if (size.isEmpty) return;
  switch (spec.art) {
    case SceneArt.castle:
      _castle(canvas, size, spec, dark, horizon, strength);
    case SceneArt.forest:
      _treeline(canvas, size, spec, dark, horizon, strength);
      _motes(canvas, size, spec.trim, dark, strength, count: 14, seed: 5, glow: true);
    case SceneArt.patronus:
      final random = math.Random(9);
      for (var i = 0; i < 10; i++) {
        final c = Offset(random.nextDouble() * size.width, size.height * (0.2 + random.nextDouble() * 0.6));
        paintSpark(
          canvas,
          c,
          2 + random.nextDouble() * 3,
          Paint()..color = spec.trim.withValues(alpha: (dark ? 0.55 : 0.4) * strength),
        );
      }
    case SceneArt.phoenix:
      _motes(canvas, size, spec.accent, dark, strength, count: 16, seed: 17, glow: true);
      _motes(canvas, size, spec.trim, dark, strength, count: 10, seed: 19, glow: false);
    case SceneArt.none || SceneArt.greatHall:
      return;
  }
}

/// The whole art as the background of a chat ("theme"): the sky settling into the page,
/// the accent's haze round a light in the upper right, and the art, its silhouettes low.
/// A palette without art shows the sky and the haze only.
void paintChatThemeBackground(Canvas canvas, Size size, SceneSpec spec, {required bool dark}) {
  if (size.isEmpty) return;
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [spec.sky, Color.lerp(spec.sky, spec.page, 0.6)!, spec.page],
        stops: const [0, 0.55, 1],
      ).createShader(rect),
  );
  final light = Offset(size.width * 0.82, size.height * 0.12);
  final glow = Rect.fromCircle(center: light, radius: size.longestSide * 0.7);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        colors: [spec.haze, spec.haze.withValues(alpha: 0)],
      ).createShader(glow),
  );
  // Fainter than on the home page: the bubbles lie over all of it.
  paintSceneArtBack(canvas, size, spec, dark: dark, light: light, strength: 0.75);
  paintSceneArtFront(canvas, size, spec, dark: dark, horizon: 0.9, strength: 0.75);
}

/// Stars, or on a light page a few pale sparks of the trim, in the upper part of the sky.
void _stars(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength, {required int seed}) {
  final random = math.Random(seed);
  final w = size.width, h = size.height;
  if (dark) {
    final count = (w * h / 2600).clamp(20, 140).round();
    for (var i = 0; i < count; i++) {
      final p = Offset(random.nextDouble() * w, random.nextDouble() * h * 0.6);
      final r = 0.5 + random.nextDouble() * 0.8;
      final alpha = (0.25 + random.nextDouble() * 0.4) * strength;
      canvas.drawCircle(p, r, Paint()..color = Colors.white.withValues(alpha: alpha));
    }
  }
  for (var i = 0; i < 4; i++) {
    final p = Offset(random.nextDouble() * w, h * (0.05 + random.nextDouble() * 0.4));
    paintSpark(
      canvas,
      p,
      3 + random.nextDouble() * 2.5,
      Paint()..color = spec.trim.withValues(alpha: (dark ? 0.6 : 0.35) * strength),
    );
  }
}

/// Candles that float in the air, a little flame and its glow on each.
void _candles(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  const spots = [(0.08, 0.30), (0.22, 0.12), (0.38, 0.26), (0.55, 0.09), (0.68, 0.24), (0.83, 0.13), (0.94, 0.33)];
  final wax = (dark ? const Color(0xFFEDE3CF) : spec.trim).withValues(alpha: (dark ? 0.5 : 0.4) * strength);
  final flame = Paint()..color = spec.trim.withValues(alpha: 0.9 * strength);
  final glow = Paint()
    ..color = spec.glow.withValues(alpha: (dark ? 0.35 : 0.25) * strength)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  for (final (i, (fx, fy)) in spots.indexed) {
    final x = size.width * fx;
    final y = size.height * fy;
    final tall = 10 + (i * 7 % 9).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.8, y, 3.6, tall), const Radius.circular(1)),
      Paint()..color = wax,
    );
    canvas.drawCircle(Offset(x, y - 3), 6, glow);
    canvas.drawPath(
      Path()
        ..moveTo(x, y - 7)
        ..quadraticBezierTo(x + 2.4, y - 2.5, x, y - 0.5)
        ..quadraticBezierTo(x - 2.4, y - 2.5, x, y - 7)
        ..close(),
      flame,
    );
  }
}

/// The colour of a silhouette that stands against the ridges: on a dark page the main
/// range's, darker than the sky; on a light page the far ridge's with a breath of the ink of
/// the ring, so it shows on the pale sky.
Color _silhouette(SceneSpec spec, bool dark) =>
    dark ? spec.ridges[1] : Color.alphaBlend(spec.ring.withValues(alpha: 0.12), spec.ridges.first);

/// A castle on the right of the scene: a hall, towers with pointed roofs, a tall spire and
/// lit windows in the trim.
void _castle(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final x0 = w * 0.5;
  final span = w * 0.48;
  final unit = (span / 10).clamp(10.0, 30.0);
  final body = Paint()..color = _silhouette(spec, dark);
  final window = Paint()..color = spec.trim.withValues(alpha: (dark ? 0.85 : 0.55) * strength);
  // The hall, low and wide, down to the foot of the scene, where the page covers it.
  canvas.drawRect(Rect.fromLTRB(x0 + span * 0.08, base - unit * 2.2, x0 + span * 0.92, h), body);
  // Battlements on the hall.
  for (var x = x0 + span * 0.1; x < x0 + span * 0.9; x += unit * 0.7) {
    canvas.drawRect(Rect.fromLTWH(x, base - unit * 2.6, unit * 0.35, unit * 0.45), body);
  }
  // The towers: where along the span, how wide and how tall, in units.
  const towers = [(0.06, 1.1, 4.2), (0.3, 1.3, 5.6), (0.52, 1.6, 8.2), (0.72, 1.2, 5.0), (0.93, 1.0, 3.8)];
  for (final (fx, tw, th) in towers) {
    final cx = x0 + span * fx;
    final half = unit * tw / 2;
    final top = base - unit * th;
    canvas.drawRect(Rect.fromLTRB(cx - half, top, cx + half, h), body);
    // The pointed roof; the tallest tower takes a spire.
    final roof = unit * (th > 7 ? 3.2 : 1.8);
    canvas.drawPath(
      Path()
        ..moveTo(cx - half * 1.25, top)
        ..lineTo(cx, top - roof)
        ..lineTo(cx + half * 1.25, top)
        ..close(),
      body,
    );
    // Two lit windows, one above the other.
    for (var k = 0; k < 2; k++) {
      final wy = top + unit * (0.9 + k * 1.4);
      if (wy > base - unit * 0.5) break;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(center: Offset(cx, wy), width: unit * 0.28, height: unit * 0.5),
          topLeft: Radius.circular(unit * 0.14),
          topRight: Radius.circular(unit * 0.14),
        ),
        window,
      );
    }
  }
  // A row of windows along the hall.
  for (var x = x0 + span * 0.16; x < x0 + span * 0.86; x += unit * 1.3) {
    final pane = Rect.fromCenter(center: Offset(x, base - unit * 1.2), width: unit * 0.22, height: unit * 0.42);
    canvas.drawRect(pane, window);
  }
}

/// A treeline of pines along the horizon, taller to the sides.
void _treeline(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final random = math.Random(29);
  final paint = Paint()..color = _silhouette(spec, dark);
  var x = -10.0;
  while (x < w + 20) {
    final edge = ((x / w) - 0.5).abs() * 2; // 0 in the middle, 1 at the sides
    final tall = 18 + 26 * edge + random.nextDouble() * 18;
    _pine(canvas, Offset(x, base), tall, paint);
    x += tall * (0.32 + random.nextDouble() * 0.2);
  }
  // The ground under them, down to the foot, where the page covers it.
  canvas.drawRect(Rect.fromLTRB(0, base - 2, w, h), paint);
}

void _pine(Canvas canvas, Offset foot, double tall, Paint paint) {
  final width = tall * 0.42;
  final path = Path();
  // Three tiers, each narrower and higher.
  for (var k = 0; k < 3; k++) {
    final bottom = foot.dy - tall * (0.1 + k * 0.27);
    final top = bottom - tall * 0.42;
    final half = width * (1 - k * 0.25) / 2;
    path
      ..moveTo(foot.dx - half, bottom)
      ..lineTo(foot.dx, top)
      ..lineTo(foot.dx + half, bottom)
      ..close();
  }
  path.addRect(Rect.fromLTRB(foot.dx - tall * 0.04, foot.dy - tall * 0.12, foot.dx + tall * 0.04, foot.dy + 2));
  canvas.drawPath(path, paint);
}

/// Silver wisps that sweep up toward the light, each a soft glow and a thin line.
void _wisps(Canvas canvas, Size size, SceneSpec spec, bool dark, Offset light, double strength) {
  final w = size.width, h = size.height;
  final colour = dark ? spec.trim : spec.glow;
  for (var i = 0; i < 4; i++) {
    final start = Offset(-20, h * (0.45 + i * 0.1));
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        w * 0.3,
        h * (0.2 + i * 0.12),
        w * 0.55,
        h * (0.65 - i * 0.08),
        light.dx + (i - 1.5) * 14,
        light.dy + i * 6,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = colour.withValues(alpha: (dark ? 0.08 : 0.06) * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = colour.withValues(alpha: (dark ? 0.3 : 0.22) * strength),
    );
  }
}

/// A fan of long feathers that spreads from the light, as a wing.
void _feathers(Canvas canvas, Size size, SceneSpec spec, bool dark, Offset light, double strength) {
  final reach = size.width * 0.45;
  for (var i = 0; i < 9; i++) {
    // From the upper left round to the lower left of the light.
    final angle = math.pi * (0.95 + i * 0.07);
    final tip = light + Offset(math.cos(angle) * reach, math.sin(angle) * reach * 0.8);
    final bend = light + Offset(math.cos(angle - 0.25) * reach * 0.55, math.sin(angle - 0.25) * reach * 0.45);
    final quill = Path()
      ..moveTo(light.dx, light.dy)
      ..quadraticBezierTo(bend.dx, bend.dy, tip.dx, tip.dy);
    final colour = i.isEven ? spec.accent : spec.trim;
    canvas.drawPath(
      quill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = colour.withValues(alpha: (dark ? 0.07 : 0.06) * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      quill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = colour.withValues(alpha: (dark ? 0.28 : 0.2) * strength),
    );
  }
}

/// Small motes that float in the air: fireflies or embers.
void _motes(Canvas canvas, Size size, Color colour, bool dark, double strength,
    {required int count, required int seed, required bool glow}) {
  final random = math.Random(seed);
  for (var i = 0; i < count; i++) {
    final p = Offset(random.nextDouble() * size.width, size.height * (0.25 + random.nextDouble() * 0.7));
    final r = 0.9 + random.nextDouble() * 1.3;
    final a = (0.4 + random.nextDouble() * 0.4) * strength * (dark ? 1 : 0.75);
    if (glow) {
      canvas.drawCircle(
        p,
        r * 3,
        Paint()
          ..color = colour.withValues(alpha: a * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawCircle(p, r, Paint()..color = colour.withValues(alpha: a));
  }
}
