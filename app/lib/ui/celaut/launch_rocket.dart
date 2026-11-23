import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/arcane.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';

/// The steps of a launch, in order, as the card of the rocket shows them.
enum LaunchStep { askingNodes, readingService, starting }

/// The rocket of a launch (Josemi, 2026-10-23): a card over the screen while the app asks
/// the nodes and starts the service. The rocket hovers on its flame; when the service
/// starts, it lifts off and the card goes. With "remove animations" on in Android, the
/// rocket stands still and the card goes at once.
///
/// It is drawn with a few paths ([RocketPainter]): no image, no blur, no shader, so it
/// adds almost nothing to the raster work of a frame (`docs/performance.md`).
class LaunchRocket {
  LaunchRocket._(this._navigator, this._route, this._stage, this.step);

  final NavigatorState _navigator;
  final Route<void> _route;
  final GlobalKey<RocketStageState> _stage;

  /// The step that the card shows. Set it as the launch goes on.
  final ValueNotifier<LaunchStep> step;

  /// False once the card is gone.
  bool get isActive => _route.isActive;

  /// Show the rocket over [context], for the launch of [name].
  static LaunchRocket show(
    BuildContext context, {
    required String name,
    LaunchStep step = LaunchStep.askingNodes,
  }) {
    final navigator = Navigator.of(context);
    final stage = GlobalKey<RocketStageState>();
    final current = ValueNotifier<LaunchStep>(step);
    final route = RawDialogRoute<void>(
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondary) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _RocketCard(name: name, stage: stage, step: current),
        ),
      ),
    );
    unawaited(navigator.push(route));
    return LaunchRocket._(navigator, route, stage, current);
  }

  /// The service started: the rocket lifts off, then the card goes.
  Future<void> liftOff() async {
    await _stage.currentState?.liftOff();
    dismiss();
  }

  /// Take the card away, at once. Nothing happens if it is gone already (the user went
  /// back, or a page closed it).
  void dismiss() {
    if (_route.isActive) _navigator.removeRoute(_route);
  }
}

class _RocketCard extends StatelessWidget {
  const _RocketCard({required this.name, required this.stage, required this.step});

  final String name;
  final GlobalKey<RocketStageState> stage;
  final ValueListenable<LaunchStep> step;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final colors = ArgusColors.of(context);
    return Material(
      key: const Key('run-progress'),
      color: Theme.of(context).colorScheme.surface,
      shape: panelShapeOf(context, radius: 20),
      child: Stack(
        children: [
          if (colors.isArcane) Positioned.fill(child: ArcaneCorners(color: colors.trim)),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RocketStage(key: stage),
                const SizedBox(height: 12),
                Text(
                  l.celautRunLaunching(name),
                  style: t.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<LaunchStep>(
                  valueListenable: step,
                  builder: (context, current, _) => Column(
                    key: const Key('launch-steps'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StepRow(
                        label: l.celautRunStepNodes,
                        state: _stateOf(LaunchStep.askingNodes, current),
                      ),
                      _StepRow(
                        label: l.celautRunStepReading,
                        state: _stateOf(LaunchStep.readingService, current),
                      ),
                      _StepRow(
                        label: l.celautRunStepStarting,
                        state: _stateOf(LaunchStep.starting, current),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, waiting }

_StepState _stateOf(LaunchStep row, LaunchStep current) => row.index < current.index
    ? _StepState.done
    : row == current
        ? _StepState.current
        : _StepState.waiting;

/// One line of the steps of the launch: a check when it is done, a small spinner while it
/// goes on, and a dim circle while it waits.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final scheme = Theme.of(context).colorScheme;
    final Widget icon = switch (state) {
      _StepState.done => Icon(Icons.check_circle, size: 18, color: accentOf(context)),
      // Still under "remove animations": a spinner that does not turn is a ring.
      _StepState.current => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
          ),
        ),
      _StepState.waiting => Icon(Icons.circle_outlined, size: 18, color: scheme.outline),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: state == _StepState.current
                  ? t.secondary.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface)
                  : t.secondary.copyWith(
                      color: state == _StepState.waiting ? scheme.outline : null,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rocket itself, with its animations: it hovers on its flame until [RocketStageState.liftOff]
/// takes it up and out of its box. The launch card and the import card both hold one.
class RocketStage extends StatefulWidget {
  const RocketStage({super.key});

  @override
  State<RocketStage> createState() => RocketStageState();
}

class RocketStageState extends State<RocketStage>
    with TickerProviderStateMixin {
  late final _hover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _hover.stop();
    } else if (!_hover.isAnimating && !_lift.isAnimating) {
      _hover.repeat();
    }
  }

  Future<void> liftOff() async {
    if (_still || !mounted) return;
    _hover.stop();
    await _lift.forward().orCancel.catchError((_) {});
  }

  @override
  void dispose() {
    _hover.dispose();
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = ArgusColors.of(context);
    return SizedBox(
      width: 96,
      height: 132,
      child: ClipRect(
        child: RepaintBoundary(
          child: CustomPaint(
            key: const Key('launch-rocket'),
            painter: RocketPainter(
              hover: _hover,
              lift: _lift,
              body: scheme.onSurface,
              window: accentOf(context),
              // A house palette: the flame in the house colour, the fins and the sparks in
              // its metal.
              flame: colors.isArcane ? colors.accent : rustFor(context),
              trim: colors.isArcane ? colors.trim : null,
              still: _still,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the rocket: the body, its window, two fins, and the flame under it, which
/// flickers. [hover] moves it a little up and down; [lift] takes it up and out of the box.
class RocketPainter extends CustomPainter {
  RocketPainter({
    required this.hover,
    required this.lift,
    required this.body,
    required this.window,
    required this.flame,
    required this.still,
    this.trim,
  }) : super(repaint: Listenable.merge([hover, lift]));

  final Animation<double> hover;
  final Animation<double> lift;
  final Color body;
  final Color window;
  final Color flame;
  final bool still;

  /// The metal of a house palette, or null. With it the rocket wears the arcane look
  /// ([paintRocketShape]) and leaves sparks, not smoke.
  final Color? trim;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final phase = still ? 0.0 : hover.value * 2 * pi;
    final up = Curves.easeIn.transform(lift.value) * h;
    final dy = sin(phase) * 3 - up;
    canvas.save();
    canvas.translate(w / 2, h * 0.42 + dy);

    // The flame flickers: longer and shorter.
    final flicker = still ? 1.0 : 0.75 + 0.25 * sin(phase * 3).abs();
    paintRocketShape(canvas, body: body, window: window, flame: flame, flicker: flicker, trim: trim);
    canvas.restore();

    final metal = trim;
    if (metal != null) {
      if (!still && lift.value == 0) {
        // Sparks that fall away and twinkle under the rocket while it hovers.
        for (var i = 0; i < 4; i++) {
          final p = (hover.value + i / 4) % 1;
          final twinkle = 0.6 + 0.4 * sin((p * 3 + i) * 2 * pi).abs();
          paintSpark(
            canvas,
            Offset(w / 2 + (i - 1.5) * 7 + sin(p * 2 * pi + i) * 3, h * 0.42 + 62 + p * 28),
            (2 + 2.5 * (1 - p)) * twinkle,
            Paint()..color = (i.isEven ? metal : flame).withValues(alpha: 0.9 * (1 - p)),
          );
        }
      } else if (lift.value > 0) {
        // A burst of sparks where it left.
        paintSparkBurst(canvas, Offset(w / 2, h * 0.86), lift.value, a: metal, b: window);
      }
      return;
    }

    // Three puffs of smoke that fall away under the rocket while it hovers.
    if (!still && lift.value == 0) {
      for (var i = 0; i < 3; i++) {
        final p = (hover.value + i / 3) % 1;
        canvas.drawCircle(
          Offset(w / 2 + (i - 1) * 6, h * 0.42 + 64 + p * 26),
          2.5 + p * 2,
          Paint()..color = body.withValues(alpha: 0.25 * (1 - p)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(RocketPainter old) =>
      old.body != body ||
      old.window != window ||
      old.flame != flame ||
      old.trim != trim ||
      old.still != still;
}

/// The rocket itself, around the origin and pointing up: the nose at -44, the tail at 30.
/// The flame is under the tail, [flicker] long (1 is its full length); a null [flicker]
/// draws no flame. The launch rocket and the raised rocket of an import draw the same shape.
///
/// With a [trim] (a house palette) the rocket wears the arcane look: fins of the metal, a
/// ring of it round the window and a band round the hull, a spark on the nose, and the
/// flame's core in the metal.
void paintRocketShape(
  Canvas canvas, {
  required Color body,
  required Color window,
  required Color flame,
  double? flicker,
  Color? trim,
}) {
  if (flicker != null) {
    final flamePath = Path()
      ..moveTo(-9, 30)
      ..quadraticBezierTo(0, 30 + 34 * flicker, 9, 30)
      ..close();
    canvas.drawPath(flamePath, Paint()..color = flame);
    final core = Path()
      ..moveTo(-4, 30)
      ..quadraticBezierTo(0, 30 + 18 * flicker, 4, 30)
      ..close();
    canvas.drawPath(core, Paint()..color = trim ?? window);
  }

  // The fins.
  final fin = Paint()..color = trim ?? flame;
  canvas.drawPath(
    Path()
      ..moveTo(-14, 10)
      ..lineTo(-24, 32)
      ..lineTo(-14, 28)
      ..close(),
    fin,
  );
  canvas.drawPath(
    Path()
      ..moveTo(14, 10)
      ..lineTo(24, 32)
      ..lineTo(14, 28)
      ..close(),
    fin,
  );

  // The body: a nose cone on a rounded hull.
  final hull = Path()
    ..moveTo(0, -44)
    ..quadraticBezierTo(18, -24, 15, 10)
    ..lineTo(13, 30)
    ..lineTo(-13, 30)
    ..lineTo(-15, 10)
    ..quadraticBezierTo(-18, -24, 0, -44)
    ..close();
  canvas.drawPath(hull, Paint()..color = body);
  canvas.drawCircle(const Offset(0, -8), 7, Paint()..color = window);
  if (trim != null) {
    final ring = Paint()
      ..color = trim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(0, -8), 7, ring);
    // A band of the metal round the hull, above the fins.
    canvas.drawPath(
      Path()
        ..moveTo(-15.5, 8)
        ..lineTo(15.5, 8)
        ..lineTo(15.2, 12)
        ..lineTo(-15.2, 12)
        ..close(),
      Paint()..color = trim,
    );
    paintSpark(canvas, const Offset(0, -48), 4.5, Paint()..color = trim);
  }
}
