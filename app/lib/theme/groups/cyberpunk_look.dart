import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../argus_theme.dart';

/// The look of the Cyberpunk palettes (lib/theme/groups/cyberpunk.dart): panels cut like a
/// HUD (the top left and the bottom right corners chamfered), a neon edge of the trim, the
/// labels of the buttons in the mono font spaced like a terminal, brackets and scan ticks in
/// the corners of the cards, and a rocket with a neon stripe that leaves glitchy pixels and
/// light streaks. Drawn with a few paths and rectangles: no image, no blur, no shader. A
/// glow is a wide faint stroke under a thin bright one.
class NeonLook extends PaletteLook {
  const NeonLook();

  /// The cut of the two chamfered corners, as a share of the radius; the other two are all
  /// but square.
  static const _cut = 0.7;
  static const _nick = 0.12;

  @override
  OutlinedBorder shape(double radius, {BorderSide side = BorderSide.none}) => BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius * _cut),
          topRight: Radius.circular(radius * _nick),
          bottomLeft: Radius.circular(radius * _nick),
          bottomRight: Radius.circular(radius * _cut),
        ),
        side: side,
      );

  @override
  OutlinedBorder sheetShape(double radius, {BorderSide side = BorderSide.none}) => BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius * _cut),
          topRight: Radius.circular(radius * _nick),
        ),
        side: side,
      );

  @override
  TextStyle? get buttonText =>
      const TextStyle(fontFamily: 'IBMPlexMono', fontWeight: FontWeight.w600, letterSpacing: 1.8);

  /// A brighter hairline than the default: the neon tube round a panel.
  @override
  BorderSide edge(PaletteSpec p) => BorderSide(color: p.trim.withValues(alpha: 0.8), width: 1.2);

  /// HUD brackets in the corners (cut ones at the chamfered corners), a row of scan ticks by
  /// the top right one and three data blocks by the bottom left one.
  @override
  void paintOrnaments(Canvas canvas, Size size, Color trim) {
    const inset = 7.0;
    if (size.shortestSide < inset * 2 + 16) return;
    final arm = math.min(24.0, size.shortestSide * 0.22);
    // The cut of a bracket at a chamfered corner, short of the corner of the card.
    final cut = math.min(9.0, arm * 0.4);
    final w = size.width, h = size.height;
    final brackets = Path()
      // Top left, cut.
      ..moveTo(inset, inset + arm)
      ..lineTo(inset, inset + cut)
      ..lineTo(inset + cut, inset)
      ..lineTo(inset + arm, inset)
      // Bottom right, cut.
      ..moveTo(w - inset, h - inset - arm)
      ..lineTo(w - inset, h - inset - cut)
      ..lineTo(w - inset - cut, h - inset)
      ..lineTo(w - inset - arm, h - inset)
      // Top right and bottom left, square.
      ..moveTo(w - inset - arm, inset)
      ..lineTo(w - inset, inset)
      ..lineTo(w - inset, inset + arm)
      ..moveTo(inset, h - inset - arm)
      ..lineTo(inset, h - inset)
      ..lineTo(inset + arm, h - inset);
    canvas.drawPath(
      brackets,
      Paint()
        ..color = trim.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.drawPath(
      brackets,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.miter,
    );
    if (w < 150) return;
    // Scan ticks: five short marks along the top, the last one longer.
    final tick = Paint()
      ..color = trim.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final x = w - inset - arm - 8 - i * 5.0;
      canvas.drawLine(Offset(x, inset), Offset(x, inset + (i == 4 ? 6 : 3.5)), tick);
    }
    // Data blocks: three small squares, the middle one hollow.
    final block = Paint()..color = trim.withValues(alpha: 0.8);
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(inset + arm + 6 + i * 6.0, h - inset - 3.5, 3.5, 3.5);
      if (i == 1) {
        canvas.drawRect(
          r.deflate(0.4),
          Paint()
            ..color = block.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      } else {
        canvas.drawRect(r, block);
      }
    }
  }

  /// A neon ring round the window, a stripe down the hull above and below it, and a band
  /// above the fins with two status lights.
  @override
  void paintRocketDetails(Canvas canvas, {required Color trim, required Color accent}) {
    final stripe = Path()
      ..moveTo(0, -34)
      ..lineTo(0, -17)
      ..moveTo(0, 1)
      ..lineTo(0, 24)
      ..moveTo(-14.6, 14)
      ..lineTo(14.6, 14);
    canvas.drawPath(
      stripe,
      Paint()
        ..color = trim.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawPath(
      stripe,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawCircle(
      const Offset(0, -8),
      7.5,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final light = Paint()..color = accent;
    canvas.drawRect(const Rect.fromLTWH(-9, 18, 3, 3), light);
    canvas.drawRect(const Rect.fromLTWH(6, 18, 3, 3), light);
  }

  /// Pixels that fall from the flame and jump sideways on a grid, as a glitch, and two thin
  /// streaks of light that flicker under the tail.
  @override
  void paintRocketTrail(Canvas canvas, Offset tail, double phase, {required Color trim, required Color flame}) {
    // The glitch: three jumps in a loop.
    final jump = (phase * 3).floor();
    for (var i = 0; i < 6; i++) {
      final p = (phase + i / 6) % 1;
      final shift = ((jump + i * 2) % 5 - 2) * 2.0;
      final x = tail.dx + ((i % 3) - 1) * 6 + shift;
      final y = tail.dy + 4 + p * 30;
      final s = 2 + 2.5 * (1 - p);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: s, height: s),
        Paint()..color = (i.isEven ? trim : flame).withValues(alpha: 0.9 * (1 - p)),
      );
    }
    final streak = Paint()
      ..strokeWidth = 1
      ..color = trim.withValues(alpha: 0.55);
    for (var k = 0; k < 2; k++) {
      final reach = 8 + 14 * math.sin((phase + k * 0.37) * 2 * math.pi).abs();
      final x = tail.dx + (k == 0 ? -10 : 10);
      canvas.drawLine(Offset(x, tail.dy + 2), Offset(x, tail.dy + 2 + reach), streak);
    }
  }

  /// A burst of pixels that fly out and fade, and four streaks of light along the axes.
  @override
  void paintRocketBurst(Canvas canvas, Offset at, double t, {required Color trim, required Color accent}) {
    final fade = (1 - t).clamp(0.0, 1.0);
    const count = 10;
    for (var i = 0; i < count; i++) {
      final angle = 2 * math.pi * i / count + (i.isEven ? 0.15 : -0.1);
      // Out in steps of 3 px, as pixels move.
      final dist = ((10 + 30 * t + (i % 3) * 4) / 3).floor() * 3.0;
      final s = (2.5 + (i % 2) * 1.5) * (1 - t * 0.5);
      canvas.drawRect(
        Rect.fromCenter(center: at + Offset(math.cos(angle) * dist, math.sin(angle) * dist), width: s, height: s),
        Paint()..color = (i.isEven ? trim : accent).withValues(alpha: fade),
      );
    }
    final streak = Paint()
      ..strokeWidth = 1.2
      ..color = trim.withValues(alpha: 0.8 * fade);
    for (final d in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)]) {
      canvas.drawLine(at + d * (6 + 18 * t), at + d * (14 + 32 * t), streak);
    }
  }

  /// Pixels that scan up and down the rocket as the pad raises it, off to either side.
  @override
  void paintRocketRise(Canvas canvas, Offset from, Offset to, double t, {required Color trim}) {
    final along = to - from;
    if (along.distance == 0) return;
    final side = Offset(-along.dy, along.dx) / along.distance;
    for (var i = 0; i < 4; i++) {
      final k = (t * 3 + i / 4) % 1;
      final glow = math.sin(k * math.pi);
      final c = Offset.lerp(from, to, k)! + side * (i.isEven ? 9.0 : -9.0);
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 3, height: 3),
        Paint()..color = trim.withValues(alpha: 0.35 + 0.55 * glow),
      );
    }
  }
}

const neonLook = NeonLook();
