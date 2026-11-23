import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../argus_theme.dart';
import '../scene_art.dart' show paintStars;
import 'gta_look.dart' show starPath;

/// The scenes of the Grand Theft Auto palettes.
enum GtaScene { vice, santos, liberty, wanted }

/// The drawings of the Grand Theft Auto palettes: Vice City a striped 80s sun with neon
/// streaks and palms, Los Santos a low sunset sun behind a downtown of lit windows and
/// palms, Liberty City a suspension bridge and a skyline of lit windows, Wanted the red and
/// blue glow of the police, a helicopter with its searchlight and a row of wanted stars.
/// The masses are in the colour of a ridge ([silhouetteColor]); the rest is thin or faint.
class GtaArt extends SceneArtwork {
  const GtaArt(this.scene);

  final GtaScene scene;

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
      case GtaScene.vice:
        paintStars(canvas, size, spec, dark, strength * 0.6, seed: 53);
        _sun(canvas, size, spec, dark, light, strength, stripes: true);
        _streaks(canvas, size, spec.trim, dark, light, strength, count: 3);
      case GtaScene.santos:
        paintStars(canvas, size, spec, dark, strength * 0.5, seed: 61);
        _sun(canvas, size, spec, dark, light, strength, stripes: false);
        _streaks(canvas, size, spec.trim, dark, light, strength, count: 4, thick: true);
      case GtaScene.liberty:
        paintStars(canvas, size, spec, dark, strength * 0.5, seed: 67);
      case GtaScene.wanted:
        _policeGlow(canvas, size, spec, dark, strength);
        _helicopter(canvas, size, spec, dark, strength);
        _wantedStars(canvas, size, spec, dark, strength);
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
    final w = size.width, h = size.height;
    final base = h * horizon;
    final body = Paint()..color = silhouetteColor(spec, dark);
    final unit = (w / 34).clamp(4.0, 22.0);
    // A palm [above] the horizon at [fx] of the width; its foot reaches down to where the
    // page covers the scene.
    void palm(double fx, double above, double lean) {
      final foot = math.max(base + 4, h + 2);
      _palm(canvas, Offset(w * fx, foot), above + foot - base, lean, body, size: above);
    }

    switch (scene) {
      case GtaScene.vice:
        final tall = (h * 0.3).clamp(20.0, 220.0);
        palm(0.06, tall, 0.5);
        palm(0.17, tall * 0.72, 0.85);
        palm(0.95, tall * 0.86, -0.6);
      case GtaScene.santos:
        final lit = Paint()..color = spec.accent.withValues(alpha: (dark ? 0.75 : 0.5) * strength);
        _skyline(canvas, size, base, w * 0.34, w * 0.8, h * 0.24, unit, 7, body, lit, spire: false);
        final tall = (h * 0.26).clamp(18.0, 190.0);
        palm(0.08, tall, 0.45);
        palm(0.2, tall * 0.8, 0.7);
        palm(0.9, tall * 0.9, -0.5);
      case GtaScene.liberty:
        final lit = Paint()..color = spec.accent.withValues(alpha: (dark ? 0.8 : 0.6) * strength);
        _bridge(canvas, size, spec, dark, base, -w * 0.02, w * 0.56, unit, body, strength);
        _skyline(canvas, size, base, w * 0.52, w * 1.02, h * 0.34, unit, 13, body, lit, spire: true);
      case GtaScene.wanted:
        final red = Paint()..color = spec.accent.withValues(alpha: (dark ? 0.7 : 0.5) * strength);
        final blue = Paint()..color = spec.trim.withValues(alpha: (dark ? 0.7 : 0.5) * strength);
        _skyline(canvas, size, base, -w * 0.02, w * 0.46, h * 0.16, unit, 21, body, red, spire: false);
        _skyline(canvas, size, base, w * 0.46, w * 1.02, h * 0.13, unit, 23, body, blue, spire: false);
        _lightBar(canvas, Offset(w * 0.3, base - 2), unit, spec, dark, strength);
        _lightBar(canvas, Offset(w * 0.66, base - 2), unit, spec, dark, strength);
    }
  }
}

/// A sun at the light: the accent warming to a sunset yellow, as a ring of soft light round
/// a disc; with [stripes] its lower half cut by bands that widen to its foot.
void _sun(Canvas canvas, Size size, SceneSpec spec, bool dark, Offset light, double strength, {required bool stripes}) {
  final r = (size.shortestSide * 0.2).clamp(8.0, 110.0);
  final disc = Rect.fromCircle(center: light, radius: r);
  final warm = Color.lerp(spec.accent, const Color(0xFFFFC857), 0.75)!;
  final alpha = (dark ? 0.55 : 0.4) * strength;
  canvas.drawCircle(
    light,
    r * 1.5,
    Paint()
      ..color = warm.withValues(alpha: alpha * 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
  );
  canvas.save();
  if (stripes) {
    final keep = Path()..addRect(Rect.fromLTRB(disc.left, disc.top, disc.right, light.dy + r * 0.12));
    var y = light.dy + r * 0.12;
    var gap = r * 0.05;
    while (y < disc.bottom) {
      final band = r * 0.16;
      y += gap;
      keep.addRect(Rect.fromLTRB(disc.left, y, disc.right, y + band));
      y += band;
      gap *= 1.45;
    }
    canvas.clipPath(keep);
  }
  canvas.drawCircle(
    light,
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [warm.withValues(alpha: alpha), spec.accent.withValues(alpha: alpha)],
      ).createShader(disc),
  );
  canvas.restore();
}

/// Long thin streaks of cloud across the sun, in [colour]; [thick] makes them bands.
void _streaks(Canvas canvas, Size size, Color colour, bool dark, Offset light, double strength,
    {required int count, bool thick = false}) {
  final r = (size.shortestSide * 0.2).clamp(8.0, 110.0);
  for (var i = 0; i < count; i++) {
    final y = light.dy - r * 0.35 + i * r * 0.42;
    final span = r * (2.6 - i * 0.35);
    final x = light.dx - span * (0.65 + 0.1 * (i % 2));
    final height = thick ? r * 0.05 : math.max(1.2, r * 0.025);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, span, height), Radius.circular(height / 2)),
      Paint()..color = colour.withValues(alpha: (dark ? 0.5 : 0.4) * strength * (thick ? 0.6 : 1)),
    );
  }
}

/// A palm tree with its foot at [foot], [tall] high: a curved trunk that leans by [lean]
/// and a crown of arched fronds, both as for a palm [size] high (its height by default).
void _palm(Canvas canvas, Offset foot, double tall, double lean, Paint paint, {double? size}) {
  final s = size ?? tall;
  final top = foot + Offset(lean * s * 0.3, -tall);
  final bend = foot + Offset(lean * s * 0.02, -tall * 0.55);
  final w0 = s * 0.04, w1 = s * 0.022;
  final path = Path()
    ..moveTo(foot.dx - w0, foot.dy)
    ..quadraticBezierTo(bend.dx - w0, bend.dy, top.dx - w1, top.dy)
    ..lineTo(top.dx + w1, top.dy)
    ..quadraticBezierTo(bend.dx + w0, bend.dy, foot.dx + w0, foot.dy)
    ..close();
  final len = s * 0.42;
  const angles = [-3.0, -2.55, -2.05, -1.6, -1.1, -0.6, -0.15];
  for (final (i, a) in angles.indexed) {
    final l = len * (i.isEven ? 1.0 : 0.82);
    final tip = top + Offset(math.cos(a) * l, math.sin(a) * l + l * 0.38);
    final mid = Offset.lerp(top, tip, 0.5)!;
    final dir = (tip - top) / (tip - top).distance;
    // The side of the frond that faces up.
    var normal = Offset(dir.dy, -dir.dx);
    if (normal.dy > 0) normal = -normal;
    path
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(mid.dx + normal.dx * l * 0.3, mid.dy + normal.dy * l * 0.3, tip.dx, tip.dy)
      ..quadraticBezierTo(mid.dx + normal.dx * l * 0.12, mid.dy + normal.dy * l * 0.12, top.dx, top.dy)
      ..close();
  }
  path.addOval(Rect.fromCircle(center: top + Offset(-s * 0.02, s * 0.03), radius: s * 0.025));
  path.addOval(Rect.fromCircle(center: top + Offset(s * 0.025, s * 0.035), radius: s * 0.025));
  canvas.drawPath(path, paint);
}

/// A row of towers from [left] to [right] with their foot at [base], up to [tall] high and
/// taller in the middle, with some windows lit in [lit]; a [spire] tops the tallest.
void _skyline(Canvas canvas, Size size, double base, double left, double right, double tall, double unit, int seed,
    Paint body, Paint lit,
    {required bool spire}) {
  final random = math.Random(seed);
  final h = size.height;
  final towers = Path();
  final windows = Path();
  var x = left;
  var highest = (x: 0.0, top: double.infinity, width: 0.0);
  while (x < right) {
    final width = unit * (1.1 + random.nextDouble() * 1.3);
    final along = ((x + width / 2 - left) / (right - left)).clamp(0.0, 1.0);
    final hump = 0.45 + 0.55 * math.sin(along * math.pi);
    final top = base - tall * hump * (0.55 + random.nextDouble() * 0.45);
    towers.addRect(Rect.fromLTRB(x, top, x + width - unit * 0.12, h));
    if (top < highest.top) highest = (x: x, top: top, width: width - unit * 0.12);
    // A step on some roofs, a mast on others.
    final roof = random.nextDouble();
    if (roof < 0.3) {
      towers.addRect(Rect.fromLTRB(x + width * 0.25, top - unit * 0.6, x + width * 0.7, top));
    } else if (roof < 0.45) {
      towers.addRect(Rect.fromLTRB(x + width * 0.45, top - unit * 1.2, x + width * 0.45 + unit * 0.12, top));
    }
    // The windows, a grid with a third of them lit.
    final pane = unit * 0.18;
    for (var wy = top + unit * 0.5; wy < base - unit * 0.4; wy += unit * 0.55) {
      for (var wx = x + unit * 0.3; wx < x + width - unit * 0.4; wx += unit * 0.4) {
        if (random.nextDouble() < 0.33) windows.addRect(Rect.fromLTWH(wx, wy, pane, pane * 1.4));
      }
    }
    x += width;
  }
  // The street level under them, down to the foot, where the page covers it.
  towers.addRect(Rect.fromLTRB(left, base - unit * 0.4, x - unit * 0.12, h));
  if (spire && highest.top.isFinite) {
    final cx = highest.x + highest.width / 2;
    final top = highest.top, half = highest.width / 2;
    towers
      ..addRect(Rect.fromLTRB(cx - half * 0.6, top - unit * 0.9, cx + half * 0.6, top))
      ..addRect(Rect.fromLTRB(cx - half * 0.32, top - unit * 1.7, cx + half * 0.32, top))
      ..moveTo(cx - unit * 0.07, top - unit * 1.7)
      ..lineTo(cx, top - unit * 3.4)
      ..lineTo(cx + unit * 0.07, top - unit * 1.7)
      ..close();
  }
  canvas.drawPath(towers, body);
  canvas.drawPath(windows, lit);
}

/// A suspension bridge from [left] to [right]: two towers, the main cables that sag between
/// them, the hangers and a deck with its lamps.
void _bridge(Canvas canvas, Size size, SceneSpec spec, bool dark, double base, double left, double right, double unit,
    Paint body, double strength) {
  final h = size.height;
  final span = right - left;
  final deck = base - h * 0.06;
  final xa = left + span * 0.22, xb = left + span * 0.78;
  final top = deck - h * 0.2;
  final shape = Path();
  for (final x in [xa, xb]) {
    final leg = unit * 0.32;
    final gap = unit * 0.5;
    shape
      ..addRect(Rect.fromLTRB(x - gap - leg, top, x - gap, h))
      ..addRect(Rect.fromLTRB(x + gap, top, x + gap + leg, h))
      ..addRect(Rect.fromLTRB(x - gap - leg, top - unit * 0.15, x + gap + leg, top + unit * 0.3))
      ..addRect(Rect.fromLTRB(x - gap, top + (deck - top) * 0.45, x + gap, top + (deck - top) * 0.45 + unit * 0.25));
  }
  shape.addRect(Rect.fromLTRB(left, deck, right, deck + unit * 0.35));
  canvas.drawPath(shape, body);

  // The main cable: low between the towers, and down to the deck at each end.
  final sag = deck - unit * 0.5;
  final control = 2 * sag - top;
  final cable = Path()
    ..moveTo(left, deck - unit * 0.2)
    ..quadraticBezierTo(left + (xa - left) * 0.6, deck - (deck - top) * 0.25, xa, top)
    ..quadraticBezierTo((xa + xb) / 2, control, xb, top)
    ..quadraticBezierTo(right - (right - xb) * 0.6, deck - (deck - top) * 0.25, right, deck - unit * 0.2);
  final line = Paint()
    ..color = body.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, unit * 0.12);
  canvas.drawPath(cable, line);
  // The hangers between the towers.
  final hanger = Paint()
    ..color = body.color
    ..strokeWidth = math.max(0.6, unit * 0.05);
  for (var k = 1; k < 12; k++) {
    final t = k / 12;
    final x = xa + (xb - xa) * t;
    final y = (1 - t) * (1 - t) * top + 2 * t * (1 - t) * control + t * t * top;
    canvas.drawLine(Offset(x, y), Offset(x, deck), hanger);
  }
  // The lamps along the deck, and one on top of each tower.
  final lamp = Paint()..color = spec.accent.withValues(alpha: (dark ? 0.85 : 0.6) * strength);
  for (var x = left + unit * 0.6; x < right; x += unit * 1.1) {
    canvas.drawCircle(Offset(x, deck - unit * 0.12), math.max(0.8, unit * 0.08), lamp);
  }
  final beacon = Paint()..color = (dark ? const Color(0xFFFF5A4E) : spec.accent).withValues(alpha: 0.8 * strength);
  for (final x in [xa, xb]) {
    canvas.drawCircle(Offset(x, top - unit * 0.35), math.max(1.0, unit * 0.12), beacon);
  }
}

/// The red and blue glow of police lights low in the sky, one at each side of the scene.
void _policeGlow(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final r = size.shortestSide * 0.32;
  final alpha = (dark ? 0.22 : 0.14) * strength;
  for (final (fx, colour) in [(0.12, spec.accent), (0.42, spec.trim), (0.88, spec.accent)]) {
    canvas.drawCircle(
      Offset(w * fx, h * 0.56),
      r * (fx == 0.42 ? 1.1 : 0.85),
      Paint()
        ..color = colour.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
    );
  }
}

/// A police helicopter high in the sky with the faint cone of its searchlight down to the
/// street.
void _helicopter(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final u = (size.shortestSide / 40).clamp(1.5, 14.0);
  final at = Offset(w * 0.3, h * 0.2);
  final beam = Path()
    ..moveTo(at.dx - u * 0.4, at.dy + u * 0.8)
    ..lineTo(at.dx - u * 10, h * 0.66)
    ..lineTo(at.dx + u * 6, h * 0.66)
    ..lineTo(at.dx + u * 0.4, at.dy + u * 0.8)
    ..close();
  final beamColour = dark ? Colors.white : spec.trim;
  canvas.drawPath(beam, Paint()..color = beamColour.withValues(alpha: (dark ? 0.06 : 0.07) * strength));
  final paint = Paint()..color = spec.ring.withValues(alpha: (dark ? 2.2 : 1.8) * spec.ring.a * strength);
  final body = Path()
    ..addOval(Rect.fromCenter(center: at, width: u * 3.2, height: u * 1.7))
    // The tail boom and its fin.
    ..addRect(Rect.fromLTRB(at.dx + u * 1.2, at.dy - u * 0.25, at.dx + u * 4.4, at.dy + u * 0.15))
    ..addRect(Rect.fromLTRB(at.dx + u * 4.1, at.dy - u * 0.9, at.dx + u * 4.5, at.dy + u * 0.3))
    // The rotor and its mast.
    ..addRect(Rect.fromLTRB(at.dx - u * 3.4, at.dy - u * 1.35, at.dx + u * 3.4, at.dy - u * 1.15))
    ..addRect(Rect.fromLTRB(at.dx - u * 0.12, at.dy - u * 1.2, at.dx + u * 0.12, at.dy - u * 0.8))
    // The skids.
    ..addRect(Rect.fromLTRB(at.dx - u * 1.7, at.dy + u * 1.2, at.dx + u * 1.3, at.dy + u * 1.35));
  canvas.drawPath(body, paint);
  final lamp = Paint()..color = beamColour.withValues(alpha: 0.7 * strength);
  canvas.drawCircle(at + Offset(-u * 0.6, u * 0.9), u * 0.3, lamp);
}

/// Five wanted stars across the top of the sky, three of them lit.
void _wantedStars(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final r = (size.shortestSide * 0.028).clamp(2.0, 14.0);
  final lit = Paint()..color = spec.trim.withValues(alpha: (dark ? 0.45 : 0.35) * strength);
  final off = Paint()
    ..color = spec.trim.withValues(alpha: (dark ? 0.35 : 0.28) * strength)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = math.max(0.8, r * 0.14);
  for (var i = 0; i < 5; i++) {
    canvas.drawPath(starPath(Offset(w * 0.5 + (i - 2) * r * 2.8, h * 0.08), r), i < 3 ? lit : off);
  }
}

/// A light bar on the roof of a patrol car at the street, red and blue, each with a glow.
void _lightBar(Canvas canvas, Offset at, double unit, SceneSpec spec, bool dark, double strength) {
  final glow = (dark ? 0.35 : 0.22) * strength;
  for (final (dx, colour) in [(-1.0, spec.accent), (1.0, spec.trim)]) {
    final c = at + Offset(dx * unit * 0.45, 0);
    canvas.drawCircle(
      c,
      unit * 1.4,
      Paint()
        ..color = colour.withValues(alpha: glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.8),
    );
    canvas.drawRect(Rect.fromCenter(center: c, width: unit * 0.8, height: unit * 0.28), Paint()..color = colour);
  }
}
