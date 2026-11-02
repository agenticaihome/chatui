import 'package:flutter/material.dart';

import '../../services/motion_cues.dart';

/// The dots of the vehicle motion cues ([MotionCues]) over every page. They let
/// every touch through, and only they repaint when the phone moves. The sensors run
/// while the app is in front.
class MotionCuesOverlay extends StatefulWidget {
  const MotionCuesOverlay({super.key, required this.child, MotionCues? cues}) : _cues = cues;

  final Widget child;
  final MotionCues? _cues;

  @override
  State<MotionCuesOverlay> createState() => _MotionCuesOverlayState();
}

class _MotionCuesOverlayState extends State<MotionCuesOverlay> with WidgetsBindingObserver {
  MotionCues get _cues => widget._cues ?? motionCues;
  bool _inFront = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cues.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    _cues.removeListener(_sync);
    _cues.listen(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inFront = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    _cues.listen(_inFront);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_cues.mode == MotionCuesMode.off) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            // Automatic cues fade in when a vehicle starts and out when it ends.
            child: AnimatedOpacity(
              opacity: _cues.showing ? 1 : 0,
              duration: const Duration(milliseconds: 800),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _DotsPainter(_cues.shift, dot: scheme.onSurface, halo: scheme.surface),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Two staggered columns of dots at each side of the screen, moved by [shift].
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.shift, {required this.dot, required this.halo}) : super(repaint: shift);

  final ValueNotifier<Offset> shift;
  final Color dot;
  final Color halo;

  static const _spacing = 52.0;
  static const _columns = [9.0, 23.0];
  static const _radius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final s = shift.value;
    final dotPaint = Paint()..color = dot.withValues(alpha: 0.5);
    final haloPaint = Paint()..color = halo.withValues(alpha: 0.6);
    for (var c = 0; c < _columns.length; c++) {
      final inset = _columns[c];
      // The inner column sits between the dots of the outer one.
      for (var y = _spacing / 2 * c - _spacing; y < size.height + _spacing; y += _spacing) {
        for (final x in [inset, size.width - inset]) {
          final p = Offset(x, y) + s;
          canvas.drawCircle(p, _radius + 1, haloPaint);
          canvas.drawCircle(p, _radius, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.dot != dot || old.halo != halo || old.shift != shift;
}
