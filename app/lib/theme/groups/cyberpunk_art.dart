import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../argus_theme.dart';
import '../scene_art.dart' show paintStars;

// The drawings of the Cyberpunk palettes (lib/theme/groups/cyberpunk.dart). The towers, the
// floor of the grid and the arcology are masses in the colour of a ridge; the windows, the
// neon signs, the rain, the beams and the data are thin, small or faint, so the type of the
// page keeps its contrast.

/// The scenes of the Cyberpunk palettes.
enum CyberScene { nightCity, neonNoir, netrunner, bladeRain }

/// The drawings of the Cyberpunk palettes: Night City a skyline of neon signs under
/// searchlights, Neon Noir an alley of signs in the rain, Netrunner columns of falling data
/// over a grid to the horizon, Blade Rain a stepped arcology and flares behind a low city in
/// the rain.
class CyberArt extends SceneArtwork {
  const CyberArt(this.scene);

  final CyberScene scene;

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
      case CyberScene.nightCity:
        paintStars(canvas, size, spec, dark, strength * 0.4, seed: 53);
      case CyberScene.neonNoir:
        _rain(canvas, size, spec.trim, (dark ? 0.16 : 0.14) * strength, seed: 61, slant: 0.2);
      case CyberScene.netrunner:
        _dataColumns(canvas, size, spec.accent, dark, strength, seed: 67);
      case CyberScene.bladeRain:
        _arcology(canvas, size, spec, dark, strength);
        _flares(canvas, size, spec, dark, strength);
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
      case CyberScene.nightCity:
        _searchlights(canvas, size, spec, dark, horizon, strength);
        _skyline(canvas, size, spec, dark, horizon, strength, seed: 71, signs: 0.55);
        _traffic(canvas, size, spec, dark, strength);
      case CyberScene.neonNoir:
        _skyline(canvas, size, spec, dark, horizon, strength, seed: 73, signs: 0.95, tall: 1.5, alley: true);
        _rain(canvas, size, spec.trim, (dark ? 0.22 : 0.16) * strength, seed: 79, slant: 0.2, density: 0.5);
      case CyberScene.netrunner:
        _gridFloor(canvas, size, spec, dark, horizon, strength);
      case CyberScene.bladeRain:
        _skyline(canvas, size, spec, dark, horizon, strength, seed: 83, signs: 0.3, tall: 0.65, warm: true);
        _rain(canvas, size, spec.trim, (dark ? 0.26 : 0.2) * strength, seed: 89, slant: 0.08, density: 0.8);
    }
  }
}

/// Rain: thin streaks over all of [size], a little slanted.
void _rain(Canvas canvas, Size size, Color colour, double alpha,
    {required int seed, double slant = 0.15, double density = 1}) {
  final w = size.width, h = size.height;
  final random = math.Random(seed);
  final count = (w * h / 1700 * density).clamp(10, 320).round();
  final paint = Paint()
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < count; i++) {
    final x = (random.nextDouble() * 1.1 - 0.05) * w;
    final y = random.nextDouble() * h;
    final length = 7 + random.nextDouble() * 17;
    paint.color = colour.withValues(alpha: alpha * (0.4 + 0.6 * random.nextDouble()));
    canvas.drawLine(Offset(x, y), Offset(x - length * slant, y + length), paint);
  }
}

/// A neon tube: a soft glow under a bright core (the glow only on a dark page).
void _neon(Canvas canvas, Rect rect, Color colour, bool dark, double strength, {bool hollow = false}) {
  if (dark) {
    canvas.drawRect(
      rect.inflate(2),
      Paint()
        ..color = colour.withValues(alpha: 0.35 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
  final core = Paint()..color = colour.withValues(alpha: (dark ? 0.9 : 0.6) * strength);
  if (hollow) {
    core
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
  }
  canvas.drawRect(rect, core);
}

/// A skyline along the horizon: towers taller to the sides, each with a few lit windows, a
/// setback or a mast with a beacon, and on some ([signs] the share) a neon sign: a tall bar
/// or a framed block of bars, in the accent or the trim. An [alley] keeps the middle open.
/// [warm] lights the windows in the accent rather than the trim.
void _skyline(
  Canvas canvas,
  Size size,
  SceneSpec spec,
  bool dark,
  double horizon,
  double strength, {
  required int seed,
  required double signs,
  double tall = 1,
  bool alley = false,
  bool warm = false,
}) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final random = math.Random(seed);
  final unit = (w / 26).clamp(6.0, 20.0);
  final body = Paint()..color = silhouetteColor(spec, dark);
  final mast = Paint()
    ..color = body.color
    ..strokeWidth = 1.2;
  final windows = Paint()
    ..color = (warm ? spec.accent : spec.trim).withValues(alpha: (dark ? 0.5 : 0.35) * strength);
  final beacon = Paint()..color = spec.accent.withValues(alpha: (dark ? 0.85 : 0.6) * strength);
  final boards = <(Rect, Color, bool)>[];
  var x = -unit * 0.6;
  while (x < w + unit) {
    final width = unit * (1.2 + random.nextDouble() * 1.8);
    // 0 in the middle, 1 at the sides.
    final edge = ((x + width / 2) / w - 0.5).abs() * 2;
    if (alley && edge < 0.6) {
      x += width;
      continue;
    }
    final height = unit * tall * (1.4 + 4.6 * edge * edge + random.nextDouble() * 2.2);
    final top = base - height;
    canvas.drawRect(Rect.fromLTRB(x, top, x + width, h), body);
    final roof = random.nextDouble();
    if (roof < 0.3) {
      canvas.drawRect(Rect.fromLTRB(x + width * 0.22, top - unit * 0.7, x + width * 0.78, top + 1), body);
    } else if (roof < 0.55) {
      final mx = x + width * (0.3 + random.nextDouble() * 0.4);
      final tip = Offset(mx, top - unit * (1 + random.nextDouble()));
      canvas.drawLine(Offset(mx, top), tip, mast);
      canvas.drawCircle(tip, 1.3, beacon);
    }
    // A sparse grid of lit windows, down to the horizon.
    for (var wy = top + unit * 0.5; wy < base - unit * 0.3; wy += unit * 0.55) {
      for (var wx = x + unit * 0.3; wx < x + width - unit * 0.3; wx += unit * 0.45) {
        if (random.nextDouble() < 0.2) canvas.drawRect(Rect.fromLTWH(wx, wy, unit * 0.15, unit * 0.2), windows);
      }
    }
    if (random.nextDouble() < signs && height > unit * 2.4) {
      final colour = boards.length.isEven ? spec.accent : spec.trim;
      if (random.nextBool()) {
        // A tall bar down the face of the tower, by one of its sides.
        final sx = random.nextBool() ? x + unit * 0.25 : x + width - unit * 0.25 - 3;
        final long = math.min(height - unit * 1.2, unit * (1.6 + random.nextDouble() * 1.6));
        boards.add((Rect.fromLTWH(sx, top + unit * 0.6, 3, long), colour, false));
      } else {
        // A framed block that sticks out of the face.
        final bw = unit * (1.1 + random.nextDouble() * 0.6);
        final bx = x + (width - bw) * random.nextDouble();
        boards.add((Rect.fromLTWH(bx, top + unit * (0.5 + random.nextDouble()), bw, unit * 0.75), colour, true));
      }
    }
    x += width + (random.nextDouble() < 0.3 ? unit * 0.3 : 0);
  }
  // The signs over the towers, so a block can overhang the next one.
  for (final (rect, colour, framed) in boards) {
    _neon(canvas, rect, colour, dark, strength, hollow: framed);
    if (framed) {
      // Two bars of light inside the frame, of different lengths: a sign, but no letters.
      final bar = Paint()..color = colour.withValues(alpha: (dark ? 0.85 : 0.55) * strength);
      final inner = rect.deflate(rect.height * 0.28);
      canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width * 0.7, 1.6), bar);
      canvas.drawRect(Rect.fromLTWH(inner.left, inner.bottom - 1.6, inner.width * 0.45, 1.6), bar);
    }
  }
}

/// Two searchlight beams that sweep up from behind the towers, faint wedges with a brighter
/// middle.
void _searchlights(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  for (final (fx, lean, colour) in [(0.22, -0.35, spec.trim), (0.66, 0.28, spec.accent)]) {
    final foot = Offset(w * fx, h * horizon);
    final reach = h * 0.75;
    final dir = Offset(math.sin(lean), -math.cos(lean));
    final across = Offset(-dir.dy, dir.dx);
    final tip = foot + dir * reach;
    canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy)
        ..lineTo(tip.dx + across.dx * reach * 0.09, tip.dy + across.dy * reach * 0.09)
        ..lineTo(tip.dx - across.dx * reach * 0.09, tip.dy - across.dy * reach * 0.09)
        ..close(),
      Paint()..color = colour.withValues(alpha: (dark ? 0.06 : 0.05) * strength),
    );
    canvas.drawLine(
      foot,
      tip,
      Paint()
        ..strokeWidth = 1
        ..color = colour.withValues(alpha: (dark ? 0.16 : 0.12) * strength),
    );
  }
}

/// Flying cars across the sky: short streaks of light, each with a bright head.
void _traffic(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  const lanes = [(0.12, 0.2, 1.0), (0.46, 0.13, -1.0), (0.7, 0.3, 1.0), (0.3, 0.36, -1.0)];
  for (final (i, (fx, fy, way)) in lanes.indexed) {
    final head = Offset(w * fx, h * fy);
    final colour = i.isEven ? spec.trim : spec.accent;
    canvas.drawLine(
      head,
      head - Offset(way * 16, 0),
      Paint()
        ..strokeWidth = 1
        ..color = colour.withValues(alpha: (dark ? 0.35 : 0.3) * strength),
    );
    canvas.drawRect(
      Rect.fromCenter(center: head, width: 2.4, height: 1.6),
      Paint()..color = colour.withValues(alpha: (dark ? 0.9 : 0.6) * strength),
    );
  }
}

/// Columns of data that fall down the sky: blocks and bars like glyphs, brightest at the
/// head of each column and fading up its tail.
void _dataColumns(Canvas canvas, Size size, Color colour, bool dark, double strength, {required int seed}) {
  final w = size.width, h = size.height;
  final random = math.Random(seed);
  const cell = 6.0;
  final alpha = (dark ? 0.32 : 0.22) * strength;
  final paint = Paint();
  final head = dark ? Color.lerp(colour, Colors.white, 0.55)! : colour;
  for (var x = cell * 0.6; x < w; x += cell * 1.7) {
    if (random.nextDouble() < 0.45) continue;
    final length = 4 + random.nextInt(14);
    final bottom = h * (0.06 + random.nextDouble() * 0.7);
    for (var k = 0; k < length; k++) {
      final y = bottom - k * cell * 1.35;
      if (y < -cell) break;
      final fade = 1 - k / length;
      paint.color = (k == 0 ? head : colour).withValues(alpha: (alpha * fade * (k == 0 ? 2.2 : 1)).clamp(0.0, 1.0));
      // The shape of a cell: a block, a bar, two bars or a dot over a bar.
      switch (random.nextInt(4)) {
        case 0:
          canvas.drawRect(Rect.fromLTWH(x, y, cell * 0.8, cell), paint);
        case 1:
          canvas.drawRect(Rect.fromLTWH(x + cell * 0.3, y, cell * 0.25, cell), paint);
        case 2:
          canvas.drawRect(Rect.fromLTWH(x, y + cell * 0.1, cell * 0.8, cell * 0.22), paint);
          canvas.drawRect(Rect.fromLTWH(x, y + cell * 0.65, cell * 0.8, cell * 0.22), paint);
        default:
          canvas.drawRect(Rect.fromLTWH(x + cell * 0.25, y, cell * 0.3, cell * 0.3), paint);
          canvas.drawRect(Rect.fromLTWH(x, y + cell * 0.6, cell * 0.8, cell * 0.25), paint);
      }
    }
  }
}

/// A floor in the colour of a ridge from the horizon down, ruled with a grid in perspective
/// toward a point on the horizon, the horizon itself a line of the accent.
void _gridFloor(Canvas canvas, Size size, SceneSpec spec, bool dark, double horizon, double strength) {
  final w = size.width, h = size.height;
  final base = h * horizon;
  final floor = Rect.fromLTRB(0, base, w, h);
  canvas.drawRect(floor, Paint()..color = silhouetteColor(spec, dark));
  final line = Paint()
    ..strokeWidth = 0.9
    ..color = spec.trim.withValues(alpha: (dark ? 0.45 : 0.4) * strength);
  canvas.save();
  canvas.clipRect(floor);
  final depth = math.max(h - base, 1.0);
  final vanish = Offset(w / 2, base);
  // The rails, fanning out from the vanishing point.
  for (var j = -14; j <= 14; j++) {
    canvas.drawLine(vanish, Offset(w / 2 + j * w * 0.22, base + depth * 2.4), line);
  }
  // The rungs, closer together toward the horizon.
  for (var i = 1; i <= 9; i++) {
    final y = base + depth * math.pow(i / 9, 2.2);
    canvas.drawLine(Offset(0, y), Offset(w, y), line);
  }
  canvas.restore();
  if (dark) {
    canvas.drawLine(
      Offset(0, base),
      Offset(w, base),
      Paint()
        ..strokeWidth = 4
        ..color = spec.accent.withValues(alpha: 0.25 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
  canvas.drawLine(
    Offset(0, base),
    Offset(w, base),
    Paint()
      ..strokeWidth = 1.2
      ..color = spec.accent.withValues(alpha: (dark ? 0.85 : 0.55) * strength),
  );
}

/// A stepped arcology on the right, a mass in the colour of a ridge down to the foot of the
/// scene, with bands of lit floors in the accent along each step. Its height follows the
/// width, so on a tall chat it stands low.
void _arcology(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final cx = w * 0.74;
  final half = math.min(w * 0.24, h * 0.4);
  final top = math.max(h * 0.24, h - w * 0.9);
  final foot = top + (h - top) * 0.6;
  const steps = 6;
  final body = Paint()..color = silhouetteColor(spec, dark);
  final band = Paint()
    ..strokeWidth = 1
    ..color = spec.accent.withValues(alpha: (dark ? 0.55 : 0.4) * strength);
  final stepHeight = (foot - top) / steps;
  for (var i = 0; i < steps; i++) {
    final y = top + i * stepHeight;
    final reach = half * (0.25 + 0.75 * (i + 1) / steps);
    canvas.drawRect(Rect.fromLTRB(cx - reach, y, cx + reach, foot), body);
    // A band of lit floors under the edge of each step.
    final by = y + stepHeight * 0.45;
    canvas.drawLine(Offset(cx - reach + 3, by), Offset(cx + reach - 3, by), band);
  }
  // The widest step goes on down to the foot of the scene.
  canvas.drawRect(Rect.fromLTRB(cx - half, foot - 1, cx + half, h), body);
}

/// Flares of gas that burn on stacks on the left, each a small flame and, on a dark page, its
/// glow. The stacks, wider at the foot, go down to the foot of the scene; their height
/// follows the width.
void _flares(Canvas canvas, Size size, SceneSpec spec, bool dark, double strength) {
  final w = size.width, h = size.height;
  final stack = Paint()..color = silhouetteColor(spec, dark);
  for (final (fx, fy, tall) in const [(0.08, 0.5, 0.52), (0.2, 0.44, 0.6), (0.33, 0.52, 0.48)]) {
    final top = Offset(w * fx, math.max(h * fy, h - w * tall));
    canvas.drawPath(
      Path()
        ..moveTo(top.dx - 2.5, top.dy)
        ..lineTo(top.dx + 2.5, top.dy)
        ..lineTo(top.dx + 5, h)
        ..lineTo(top.dx - 5, h)
        ..close(),
      stack,
    );
    // The cap of the stack.
    canvas.drawRect(Rect.fromLTRB(top.dx - 3.5, top.dy, top.dx + 3.5, top.dy + 2.5), stack);
    if (dark) {
      canvas.drawCircle(
        top - const Offset(0, 6),
        9,
        Paint()
          ..color = spec.accent.withValues(alpha: 0.3 * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy - 13)
        ..quadraticBezierTo(top.dx + 4, top.dy - 4, top.dx, top.dy)
        ..quadraticBezierTo(top.dx - 4, top.dy - 4, top.dx, top.dy - 13)
        ..close(),
      Paint()..color = spec.accent.withValues(alpha: (dark ? 0.9 : 0.6) * strength),
    );
  }
}
