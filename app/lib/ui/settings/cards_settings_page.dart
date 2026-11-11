import 'dart:async';

import 'package:flutter/material.dart';

import '../../celaut/cards_effects.dart';
import '../../l10n/l10n.dart';
import 'settings_shared.dart';

/// The group "Cards" (`docs/celaut/cards.md`, section 13): one item for each effect of the
/// deck. A phone with no vibration motor shows no vibration item; one with no gyroscope
/// shows no motion gestures (the reflection then follows the finger).
class CardsSettingsPage extends StatelessWidget {
  const CardsSettingsPage({super.key, this.settings, this.sensors});

  final CardsSettings? settings;
  final CardsSensors? sensors;

  static String strengthName(AppLocalizations l, CardsStrength s) => switch (s) {
        CardsStrength.low => l.cardsStrengthLow,
        CardsStrength.medium => l.cardsStrengthMedium,
        CardsStrength.high => l.cardsStrengthHigh,
      };

  @override
  Widget build(BuildContext context) {
    final s = settings ?? cardsSettings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final l = context.l10n;
        final reduce = MediaQuery.disableAnimationsOf(context);
        final device = s.device;
        final reflections = s.reflectionsWith(reduceMotion: reduce);
        final transitions = s.transitionsWith(reduceMotion: reduce);
        Widget strengths(Key key, CardsStrength value, void Function(CardsStrength) set) => _Choice<CardsStrength>(
              key: key,
              title: key == const Key('cards-set-sensitivity') ? l.cardsSettingsSensitivity : l.cardsSettingsStrength,
              value: value,
              options: {for (final v in CardsStrength.values) v: strengthName(l, v)},
              onChanged: set,
            );
        return SettingsPage(
          title: l.cardsSettingsTitle,
          children: [
            if (reduce) SettingsNote(l.cardsSettingsReduceMotion),
            SettingsGroup(
              title: l.cardsSettingsGroup,
              scope: l.settingsScopeAppWide,
              children: [
                SettingsRow(
                  icon: Icons.auto_awesome_outlined,
                  title: l.cardsSettingsReflections,
                  subtitle: device.hasGyroscope ? l.cardsSettingsReflectionsSubtitle : l.cardsSettingsReflectionsPointer,
                  trailing: Switch(
                    key: const Key('cards-set-reflections'),
                    value: reflections,
                    onChanged: s.setReflections,
                  ),
                ),
                if (reflections)
                  strengths(const Key('cards-set-reflection-strength'), s.reflectionStrength, s.setReflectionStrength),
                if (device.hasVibrator) ...[
                  SettingsRow(
                    icon: Icons.vibration,
                    title: l.cardsSettingsVibration,
                    subtitle: l.cardsSettingsVibrationSubtitle,
                    trailing: Switch(
                      key: const Key('cards-set-vibration'),
                      value: s.vibration,
                      onChanged: s.setVibration,
                    ),
                  ),
                  if (s.vibration)
                    strengths(const Key('cards-set-vibration-strength'), s.vibrationStrength, s.setVibrationStrength),
                ],
                _Choice<CardsTransitions>(
                  key: const Key('cards-set-transitions'),
                  title: l.cardsSettingsTransitions,
                  value: transitions,
                  options: {
                    CardsTransitions.off: l.cardsTransitionsOff,
                    CardsTransitions.simple: l.cardsTransitionsSimple,
                    CardsTransitions.full: l.cardsTransitionsFull,
                  },
                  onChanged: s.setTransitions,
                ),
                if (transitions == CardsTransitions.full)
                  _Choice<CardsTransitionStyle>(
                    key: const Key('cards-set-style'),
                    title: l.cardsSettingsStyle,
                    value: s.style,
                    options: {
                      CardsTransitionStyle.toss: l.cardsStyleToss,
                      CardsTransitionStyle.slide: l.cardsStyleSlide,
                      CardsTransitionStyle.fade: l.cardsStyleFade,
                    },
                    onChanged: s.setStyle,
                  ),
                if (reduce && (s.reflections != null || s.transitions != null))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextButton(
                        key: const Key('cards-set-follow-system'),
                        onPressed: () {
                          s.setReflections(null);
                          s.setTransitions(null);
                        },
                        child: Text(l.cardsSettingsFollowSystem),
                      ),
                    ),
                  ),
                _Choice<CardsFrames>(
                  key: const Key('cards-set-frames'),
                  title: l.cardsSettingsFrames,
                  value: s.frames,
                  options: {CardsFrames.theme: l.cardsFramesTheme, CardsFrames.none: l.cardsFramesNone},
                  onChanged: s.setFrames,
                ),
                if (device.hasGyroscope) ...[
                  SettingsRow(
                    icon: Icons.screen_rotation_alt_outlined,
                    title: l.cardsSettingsGestures,
                    subtitle: l.cardsSettingsGesturesSubtitle,
                    trailing: Switch(
                      key: const Key('cards-set-gestures'),
                      value: s.gestures,
                      onChanged: s.setGestures,
                    ),
                  ),
                  if (s.gestures) ...[
                    strengths(const Key('cards-set-sensitivity'), s.sensitivity, s.setSensitivity),
                    SettingsRow(
                      icon: Icons.swap_horiz,
                      title: l.cardsSettingsSwapSides,
                      subtitle: l.cardsSettingsSwapSidesSubtitle,
                      trailing: Switch(
                        key: const Key('cards-set-swap'),
                        value: s.swapSides,
                        onChanged: s.setSwapSides,
                      ),
                    ),
                    GestureTest(
                      threshold: WristGestureDetector.thresholdOf(s.sensitivity),
                      swapSides: s.swapSides,
                      sensors: sensors ?? const PlatformCardsSensors(),
                    ),
                  ],
                ],
              ],
            ),
            SettingsNote(l.cardsSettingsNote),
          ],
        );
      },
    );
  }
}

/// One choice of a short list, as a segmented button with its title.
class _Choice<T> extends StatelessWidget {
  const _Choice({super.key, required this.title, required this.value, required this.options, required this.onChanged});

  final String title;
  final T value;
  final Map<T, String> options;
  final void Function(T value) onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final e in options.entries)
                ButtonSegment<T>(value: e.key, label: Text(e.value, key: ValueKey('$title-${e.key}'))),
            ],
            selected: {value},
            onSelectionChanged: (v) => onChanged(v.single),
          ),
        ]),
      );
}

/// The test of the motion gestures: the user turns the wrist and sees the turn rate and the
/// side that the deck would take. The sensor runs only during the test (at most
/// [maxTime]), and stops when the page goes away or the app goes to the background.
class GestureTest extends StatefulWidget {
  const GestureTest({
    super.key,
    required this.threshold,
    required this.swapSides,
    required this.sensors,
    this.maxTime = const Duration(seconds: 20),
  });

  final double threshold;
  final bool swapSides;
  final CardsSensors sensors;
  final Duration maxTime;

  @override
  State<GestureTest> createState() => _GestureTestState();
}

class _GestureTestState extends State<GestureTest> with WidgetsBindingObserver {
  StreamSubscription<GyroSample>? _sub;
  Timer? _stop;
  WristGestureDetector? _detector;
  double _peak = 0;

  /// -1 left, 1 right (after the swap), 0 none yet.
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _end();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _start() {
    final d = WristGestureDetector(threshold: widget.threshold);
    setState(() {
      _detector = d;
      _peak = 0;
      _seen = 0;
    });
    _sub = widget.sensors.gyro().listen((s) {
      final turn = d.add(s);
      if (!mounted) return;
      setState(() {
        _peak = d.peak > _peak ? d.peak : _peak;
        if (s.y.abs() > _peak) _peak = s.y.abs();
        if (turn != 0) _seen = (widget.swapSides ? -turn : turn);
      });
    }, onError: (Object _) => _end());
    _stop = Timer(widget.maxTime, _end);
  }

  void _end() {
    _stop?.cancel();
    _stop = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (mounted && _detector != null) setState(() => _detector = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final running = _detector != null;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OutlinedButton.icon(
          key: const Key('cards-test'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: running ? _end : _start,
          icon: Icon(running ? Icons.stop_circle_outlined : Icons.play_circle_outline),
          label: Text(running ? l.cardsSettingsTestStop : l.cardsSettingsTest),
        ),
        if (running || _peak > 0) ...[
          const SizedBox(height: 8),
          Text(
            l.cardsSettingsTestValue(_peak.toStringAsFixed(1), widget.threshold.toStringAsFixed(1)),
            key: const Key('cards-test-value'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            switch (_seen) {
              -1 => l.cardsSettingsTestLeft,
              1 => l.cardsSettingsTestRight,
              _ => l.cardsSettingsTestIdle,
            },
            key: const Key('cards-test-result'),
            style: theme.textTheme.titleSmall?.copyWith(color: _seen == 0 ? null : theme.colorScheme.primary),
          ),
        ],
      ]),
    );
  }
}
