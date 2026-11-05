import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/argus_theme.dart';
import 'launch_rocket.dart';

/// The rocket of an import: the same rocket as the launch, lying on its pad, which the pad
/// raises from horizontal to vertical while the app reads the file (Josemi, 2026-10-24).
/// The angle follows the bytes read: flat at none, upright at all. Without a total it
/// raises slowly toward almost upright and stops there until the work ends. When the work
/// ends, [RaiseStageState.finish] raises it the rest of the way, and the flame shows. It
/// does not take off: that is the launch's.
///
/// Drawn with paths, as [RocketPainter] is: no image, no blur, no shader. With "remove
/// animations" on in Android, the rocket jumps to each angle.
class RaiseStage extends StatefulWidget {
  const RaiseStage({super.key});

  @override
  State<RaiseStage> createState() => RaiseStageState();
}

class RaiseStageState extends State<RaiseStage> with SingleTickerProviderStateMixin {
  /// How raised the rocket is: 0 lies flat, 1 stands.
  late final _raise = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  bool _still = false;
  bool _indeterminate = false;

  /// The highest that the rocket goes while the total is not known.
  static const _waiting = 0.9;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
  }

  /// The share of the file that the app read, from 0 to 1, or null if the total is not
  /// known (the rocket then rises slowly by itself).
  void setProgress(double? fraction) {
    if (!mounted) return;
    if (fraction == null) {
      if (_indeterminate) return;
      _indeterminate = true;
      _go(_waiting, const Duration(seconds: 12), Curves.easeOut);
      return;
    }
    _indeterminate = false;
    // The rocket does not go down: the slow rise without a total can be higher than the
    // first count.
    _go(max(fraction.clamp(0.0, 1.0).toDouble(), _raise.value), const Duration(milliseconds: 250),
        Curves.linear);
  }

  void _go(double to, Duration time, Curve curve) {
    if (_still) {
      _raise.value = to;
    } else {
      unawaited(_raise.animateTo(to, duration: time, curve: curve));
    }
  }

  /// The work ended: raise the rocket the rest of the way, so it stands before the card goes.
  Future<void> finish() async {
    if (!mounted) return;
    _indeterminate = false;
    if (_still) {
      _raise.value = 1;
      return;
    }
    await _raise
        .animateTo(1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut)
        .orCancel
        .catchError((_) {});
  }

  @override
  void dispose() {
    _raise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      height: 132,
      child: ClipRect(
        child: RepaintBoundary(
          child: CustomPaint(
            key: const Key('raise-rocket'),
            painter: RaisePainter(
              raise: _raise,
              body: scheme.onSurface,
              window: accentOf(context),
              flame: rustFor(context),
              pad: scheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the pad and the rocket on it. The rocket turns about the middle of its tail, which
/// sits on the pad's table; [raise] is 0 flat (nose to the right) and 1 upright.
class RaisePainter extends CustomPainter {
  RaisePainter({
    required this.raise,
    required this.body,
    required this.window,
    required this.flame,
    required this.pad,
  }) : super(repaint: raise);

  final Animation<double> raise;
  final Color body;
  final Color window;
  final Color flame;
  final Color pad;

  /// The rocket is drawn at this scale, so that it fits the stage flat as well as upright.
  static const _scale = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = raise.value.clamp(0.0, 1.0);
    // The hinge: the middle of the tail. The pad's ground is under the flat rocket's hull.
    final pivot = Offset(w * 0.2, h * 0.78);
    final ground = pivot.dy + 15 * _scale;

    final line = Paint()
      ..color = pad
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(6, ground), Offset(w - 6, ground), line);
    // The table under the tail, and its arm that the rocket rests on while it is flat.
    canvas.drawRect(
      Rect.fromLTRB(pivot.dx - 16, pivot.dy + 6, pivot.dx + 16, ground),
      Paint()..color = pad,
    );
    canvas.drawCircle(pivot, 3, Paint()..color = pad);

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    // Flat is a quarter turn clockwise from upright.
    canvas.rotate((1 - t) * pi / 2);
    canvas.scale(_scale);
    // The tail (30 in the shape) is at the hinge.
    canvas.translate(0, -30);
    paintRocketShape(
      canvas,
      body: body,
      window: window,
      flame: flame,
      // The flame shows when it stands, at its full length.
      flicker: t >= 0.999 ? 1.0 : null,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaisePainter old) =>
      old.body != body || old.window != window || old.flame != flame || old.pad != pad;
}
