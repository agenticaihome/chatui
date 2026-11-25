import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/argus_theme.dart' show SceneSpec;
import '../theme/scene_art.dart';

/// One selectable chat background. [paint] draws it on [size]; [dark] is
/// the brightness of the app theme. 'none' paints nothing, so the theme
/// background shows.
class ChatBackground {
  const ChatBackground(this.id, this.labelKey, this.paint);
  final String id;

  /// Key of the label in the l10n file, resolved by [chatBackgroundLabel].
  final String labelKey;
  final void Function(Canvas canvas, Size size, bool dark) paint;
}

void _gradient(Canvas c, Size s, List<Color> colors, {Alignment from = Alignment.topLeft, Alignment to = Alignment.bottomRight}) {
  final rect = Offset.zero & s;
  c.drawRect(rect, Paint()..shader = LinearGradient(begin: from, end: to, colors: colors).createShader(rect));
}

void _pattern(Canvas c, Size s, bool dark, void Function(Canvas c, Offset at, Paint p) tile, {double step = 44}) {
  final p = Paint()
    ..color = (dark ? Colors.white : Colors.black).withValues(alpha: dark ? 0.05 : 0.045)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  var row = 0;
  for (var y = 0.0; y < s.height + step; y += step, row++) {
    for (var x = row.isOdd ? step / 2 : 0.0; x < s.width + step; x += step) {
      tile(c, Offset(x, y), p);
    }
  }
}

final List<ChatBackground> chatBackgrounds = [
  ChatBackground('none', 'none', (c, s, d) {}),
  // The scene of the app's theme, with its drawing in a Harry Potter palette. It needs the
  // theme: [ChatBackgroundPainter] paints it from its scene; without one it paints nothing.
  ChatBackground('theme', 'theme', (c, s, d) {}),
  ChatBackground('dawn', 'dawn', (c, s, d) => _gradient(
      c, s, d ? const [Color(0xFF1B1F3A), Color(0xFF3A2540)] : const [Color(0xFFFCE9E0), Color(0xFFE6E4FA)])),
  ChatBackground('ocean', 'ocean', (c, s, d) => _gradient(
      c, s, d ? const [Color(0xFF0B2530), Color(0xFF123B3A)] : const [Color(0xFFDDF1F5), Color(0xFFDFF5E8)],
      from: Alignment.topCenter, to: Alignment.bottomCenter)),
  ChatBackground('forest', 'forest', (c, s, d) => _gradient(
      c, s, d ? const [Color(0xFF14231A), Color(0xFF1F2E1B)] : const [Color(0xFFE5F1DD), Color(0xFFF3F1D8)],
      from: Alignment.bottomLeft, to: Alignment.topRight)),
  ChatBackground('dusk', 'dusk', (c, s, d) => _gradient(
      c, s, d ? const [Color(0xFF241A33), Color(0xFF3A2431)] : const [Color(0xFFEBDDF5), Color(0xFFF8DDE2)],
      from: Alignment.topRight, to: Alignment.bottomLeft)),
  ChatBackground('dots', 'dots', (c, s, d) {
    c.drawRect(Offset.zero & s, Paint()..color = d ? const Color(0xFF14161A) : const Color(0xFFF4F2EE));
    _pattern(c, s, d, (c, at, p) => c.drawCircle(at, 2.2, p..style = PaintingStyle.fill), step: 28);
  }),
  ChatBackground('waves', 'waves', (c, s, d) {
    c.drawRect(Offset.zero & s, Paint()..color = d ? const Color(0xFF111A20) : const Color(0xFFEFF4F6));
    _pattern(c, s, d, (c, at, p) {
      final path = Path()..moveTo(at.dx - 14, at.dy);
      path.quadraticBezierTo(at.dx - 7, at.dy - 9, at.dx, at.dy);
      path.quadraticBezierTo(at.dx + 7, at.dy + 9, at.dx + 14, at.dy);
      c.drawPath(path, p);
    });
  }),
  ChatBackground('diamonds', 'diamonds', (c, s, d) {
    c.drawRect(Offset.zero & s, Paint()..color = d ? const Color(0xFF17151C) : const Color(0xFFF6F1EA));
    _pattern(c, s, d, (c, at, p) {
      final r = 9 * math.sqrt2 / 1.2;
      c.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - r)
          ..lineTo(at.dx + r, at.dy)
          ..lineTo(at.dx, at.dy + r)
          ..lineTo(at.dx - r, at.dy)
          ..close(),
        p,
      );
    });
  }),
];

ChatBackground chatBackgroundById(String id) =>
    chatBackgrounds.firstWhere((b) => b.id == id, orElse: () => chatBackgrounds.first);

/// Paints the background [id] behind its child. [scene] is the scene of the theme, for the
/// 'theme' background.
class ChatBackgroundPainter extends CustomPainter {
  const ChatBackgroundPainter(this.id, this.dark, {this.scene});
  final String id;
  final bool dark;
  final SceneSpec? scene;

  @override
  void paint(Canvas canvas, Size size) {
    final theme = scene;
    if (id == 'theme') {
      if (theme != null) paintChatThemeBackground(canvas, size, theme, dark: dark);
      return;
    }
    chatBackgroundById(id).paint(canvas, size, dark);
  }

  @override
  bool shouldRepaint(ChatBackgroundPainter old) => old.id != id || old.dark != dark || old.scene != scene;
}

/// Localised name of the background [id].
String chatBackgroundLabel(AppLocalizations t, String id) => switch (id) {
      'dawn' => t.chatBgDawn,
      'ocean' => t.chatBgOcean,
      'forest' => t.chatBgForest,
      'dusk' => t.chatBgDusk,
      'dots' => t.chatBgDots,
      'waves' => t.chatBgWaves,
      'diamonds' => t.chatBgDiamonds,
      'theme' => t.chatBgTheme,
      _ => t.chatBgNone,
    };
