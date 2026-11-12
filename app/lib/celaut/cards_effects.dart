import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The effects of the cards deck: the last phase of `docs/celaut/cards.md`, section 13.
///
/// Each effect is a feature of the client only: it never changes what the deck does, the
/// service never sees it, and with every effect off the deck works the same.

/// A strength: of the reflection, of the vibration, or the sensitivity of the motion
/// gestures.
enum CardsStrength { low, medium, high }

/// How much the deck animates a move, the end of the deck and a refresh.
enum CardsTransitions { off, simple, full }

/// The style of a full transition: the card is thrown with a turn, slides out, or fades.
enum CardsTransitionStyle { toss, slide, fade }

/// The frame of a card: from the theme of the app, or none.
enum CardsFrames { theme, none }

/// The moments that vibrate (section 13): the card passes the decision point of a swipe,
/// the card is released and leaves, the card comes back, and an undo.
enum CardsHapticEvent { threshold, release, cancel, undo }

/// The four strengths of vibration that Flutter gives (they follow the haptics setting of
/// the system on Android).
enum HapticLevel { selection, light, medium, heavy }

/// What the phone has. Unknown (no answer of the platform: a test, a desktop) is nothing.
@immutable
class CardsDevice {
  const CardsDevice({this.hasGyroscope = false, this.hasVibrator = false});

  static const none = CardsDevice();
  static const _channel = MethodChannel('argus/cards_device');

  final bool hasGyroscope;
  final bool hasVibrator;

  static Future<CardsDevice> probe() async {
    try {
      final caps = await _channel.invokeMapMethod<String, Object?>('caps');
      return CardsDevice(
        hasGyroscope: caps?['gyroscope'] == true,
        hasVibrator: caps?['vibrator'] == true,
      );
    } on MissingPluginException {
      return none;
    } on PlatformException {
      return none;
    }
  }
}

/// The effects as they apply now: the settings of the user, the defaults for "reduce
/// motion", what the phone has, and the steps down of [FrameRateGuard].
@immutable
class CardsEffects {
  const CardsEffects({
    this.reflections = false,
    this.reflectionStrength = CardsStrength.medium,
    this.gyroReflections = false,
    this.haptics = false,
    this.hapticStrength = CardsStrength.medium,
    this.transitions = CardsTransitions.off,
    this.style = CardsTransitionStyle.toss,
    this.frames = CardsFrames.none,
    this.gestures = false,
    this.sensitivity = CardsStrength.medium,
    this.swapSides = false,
  });

  /// Every effect off: the base widget of revision 1.
  static const none = CardsEffects();

  final bool reflections;
  final CardsStrength reflectionStrength;

  /// The reflection follows the gyroscope (else only the finger or the pointer).
  final bool gyroReflections;
  final bool haptics;
  final CardsStrength hapticStrength;
  final CardsTransitions transitions;
  final CardsTransitionStyle style;
  final CardsFrames frames;

  /// The user can arm the motion gestures in the deck.
  final bool gestures;
  final CardsStrength sensitivity;
  final bool swapSides;

  /// The deck needs the gyroscope while it is on screen (the gestures need it only when
  /// they are armed).
  bool get wantsGyro => gyroReflections;
}

/// The settings of the group "Cards" (Settings, Cards), app-wide, kept on the phone.
///
/// The reflections and the transitions are null until the user chooses: then the system
/// setting "reduce motion" decides (it turns them down). The other defaults are on and
/// medium, except the motion gestures: off.
class CardsSettings extends ChangeNotifier {
  CardsSettings({CardsDevice? device}) : _device = device;

  static const _reflectionsKey = 'argus_cards_reflections';
  static const _reflectionStrengthKey = 'argus_cards_reflection_strength';
  static const _vibrationKey = 'argus_cards_vibration';
  static const _vibrationStrengthKey = 'argus_cards_vibration_strength';
  static const _transitionsKey = 'argus_cards_transitions';
  static const _styleKey = 'argus_cards_transition_style';
  static const _framesKey = 'argus_cards_frames';
  static const _gesturesKey = 'argus_cards_gestures';
  static const _sensitivityKey = 'argus_cards_gesture_sensitivity';
  static const _swapKey = 'argus_cards_gesture_swap';

  bool? reflections;
  CardsStrength reflectionStrength = CardsStrength.medium;
  bool vibration = true;
  CardsStrength vibrationStrength = CardsStrength.medium;
  CardsTransitions? transitions;
  CardsTransitionStyle style = CardsTransitionStyle.toss;
  CardsFrames frames = CardsFrames.theme;
  bool gestures = false;
  CardsStrength sensitivity = CardsStrength.medium;
  bool swapSides = false;

  CardsDevice? _device;

  /// What the phone has; [CardsDevice.none] until [load] asked the platform.
  CardsDevice get device => _device ?? CardsDevice.none;
  set device(CardsDevice value) {
    _device = value;
    notifyListeners();
  }

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    reflections = p.getBool(_reflectionsKey);
    reflectionStrength = _enum(CardsStrength.values, p.getString(_reflectionStrengthKey), CardsStrength.medium);
    vibration = p.getBool(_vibrationKey) ?? true;
    vibrationStrength = _enum(CardsStrength.values, p.getString(_vibrationStrengthKey), CardsStrength.medium);
    final t = p.getString(_transitionsKey);
    transitions = t == null ? null : _enum(CardsTransitions.values, t, CardsTransitions.full);
    style = _enum(CardsTransitionStyle.values, p.getString(_styleKey), CardsTransitionStyle.toss);
    frames = _enum(CardsFrames.values, p.getString(_framesKey), CardsFrames.theme);
    gestures = p.getBool(_gesturesKey) ?? false;
    sensitivity = _enum(CardsStrength.values, p.getString(_sensitivityKey), CardsStrength.medium);
    swapSides = p.getBool(_swapKey) ?? false;
    _device ??= await CardsDevice.probe();
    notifyListeners();
  }

  Future<void> _save(void Function(SharedPreferences p) write) async {
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    write(p);
  }

  /// [value] null: follow the system ("reduce motion") again.
  Future<void> setReflections(bool? value) {
    reflections = value;
    return _save((p) => value == null ? p.remove(_reflectionsKey) : p.setBool(_reflectionsKey, value));
  }

  Future<void> setReflectionStrength(CardsStrength value) {
    reflectionStrength = value;
    return _save((p) => p.setString(_reflectionStrengthKey, value.name));
  }

  Future<void> setVibration(bool value) {
    vibration = value;
    return _save((p) => p.setBool(_vibrationKey, value));
  }

  Future<void> setVibrationStrength(CardsStrength value) {
    vibrationStrength = value;
    return _save((p) => p.setString(_vibrationStrengthKey, value.name));
  }

  /// [value] null: follow the system ("reduce motion") again.
  Future<void> setTransitions(CardsTransitions? value) {
    transitions = value;
    return _save((p) => value == null ? p.remove(_transitionsKey) : p.setString(_transitionsKey, value.name));
  }

  Future<void> setStyle(CardsTransitionStyle value) {
    style = value;
    return _save((p) => p.setString(_styleKey, value.name));
  }

  Future<void> setFrames(CardsFrames value) {
    frames = value;
    return _save((p) => p.setString(_framesKey, value.name));
  }

  Future<void> setGestures(bool value) {
    gestures = value;
    return _save((p) => p.setBool(_gesturesKey, value));
  }

  Future<void> setSensitivity(CardsStrength value) {
    sensitivity = value;
    return _save((p) => p.setString(_sensitivityKey, value.name));
  }

  Future<void> setSwapSides(bool value) {
    swapSides = value;
    return _save((p) => p.setBool(_swapKey, value));
  }

  /// The reflections as they apply with [reduceMotion] (the user's choice wins).
  bool reflectionsWith({required bool reduceMotion}) => reflections ?? !reduceMotion;

  /// The transitions as they apply with [reduceMotion] (the user's choice wins).
  CardsTransitions transitionsWith({required bool reduceMotion}) =>
      transitions ?? (reduceMotion ? CardsTransitions.simple : CardsTransitions.full);

  /// The effects now. [stepDown] comes from [FrameRateGuard]: 1 turns the reflections off,
  /// 2 also makes the full transitions simple.
  CardsEffects resolve({required bool reduceMotion, int stepDown = 0}) {
    final reflect = reflectionsWith(reduceMotion: reduceMotion) && stepDown < 1;
    var trans = transitionsWith(reduceMotion: reduceMotion);
    if (stepDown >= 2 && trans == CardsTransitions.full) trans = CardsTransitions.simple;
    return CardsEffects(
      reflections: reflect,
      reflectionStrength: reflectionStrength,
      gyroReflections: reflect && device.hasGyroscope,
      haptics: vibration && device.hasVibrator,
      hapticStrength: vibrationStrength,
      transitions: trans,
      style: style,
      frames: frames,
      gestures: gestures && device.hasGyroscope,
      sensitivity: sensitivity,
      swapSides: swapSides,
    );
  }
}

/// The settings of the app (loaded in `main`).
final CardsSettings cardsSettings = CardsSettings();

/// The vibration of [event] at [strength]: the decision events are stronger than the
/// point of decision and the cancel; the strength moves it one step (section 13).
HapticLevel hapticLevelOf(CardsHapticEvent event, CardsStrength strength) {
  final base = switch (event) {
    CardsHapticEvent.threshold || CardsHapticEvent.cancel => 0,
    CardsHapticEvent.undo => 1,
    CardsHapticEvent.release => 2,
  };
  final step = switch (strength) {
    CardsStrength.low => -1,
    CardsStrength.medium => 0,
    CardsStrength.high => 1,
  };
  return HapticLevel.values[(base + step).clamp(0, 3)];
}

/// Plays a vibration. The default uses the haptics of Flutter (on Android, the haptic
/// feedback of the view: it follows the system setting and needs no permission).
typedef CardsHapticPlayer = void Function(HapticLevel level);

void playSystemHaptic(HapticLevel level) {
  unawaited(switch (level) {
    HapticLevel.selection => HapticFeedback.selectionClick(),
    HapticLevel.light => HapticFeedback.lightImpact(),
    HapticLevel.medium => HapticFeedback.mediumImpact(),
    HapticLevel.heavy => HapticFeedback.heavyImpact(),
  });
}

/// One sample of the gyroscope: the turn rate in rad/s on the axes of the screen (x to
/// the right, y up, z out of the screen) at [t] seconds.
@immutable
class GyroSample {
  const GyroSample(this.x, this.y, this.z, this.t);

  final double x, y, z, t;
}

/// Where the gyroscope comes from. The deck and the test of the settings listen only
/// while they are on screen; a cancel stops the sensor (section 13: the data stays in the
/// phone and is not kept).
abstract class CardsSensors {
  Stream<GyroSample> gyro();
}

class PlatformCardsSensors implements CardsSensors {
  const PlatformCardsSensors();

  static const _gyro = EventChannel('argus/cards_gyro');

  @override
  Stream<GyroSample> gyro() => _gyro.receiveBroadcastStream().map((e) {
        final v = (e as List).cast<num>();
        return GyroSample(v[0].toDouble(), v[1].toDouble(), v[2].toDouble(), v[3].toDouble());
      });
}

/// The tilt of the reflection from the gyroscope: the turn is summed, pulled back to the
/// centre (so that the reflection follows a change and not the pose), smoothed (low-pass)
/// and limited to [maxAngle] radians.
class TiltFilter {
  TiltFilter({this.maxAngle = 0.35, this.recentre = 1.5, this.smoothing = 0.25});

  final double maxAngle;

  /// The time constant in seconds that pulls the tilt back to the centre.
  final double recentre;

  /// The part of the distance to the target that the output moves per sample.
  final double smoothing;

  double _ax = 0, _ay = 0, _ox = 0, _oy = 0;
  double? _t;

  /// The tilt in -1..1 on each axis: x from a turn around the long axis (left/right),
  /// y from a turn around the short axis (forward/back).
  Offset get value => Offset(_ox / maxAngle, _oy / maxAngle);

  Offset add(GyroSample s) {
    final last = _t;
    _t = s.t;
    if (last == null) return value;
    final dt = (s.t - last).clamp(0.0, 0.1);
    final keep = math.exp(-dt / recentre);
    _ax = ((_ax + s.y * dt) * keep).clamp(-maxAngle, maxAngle);
    _ay = ((_ay + s.x * dt) * keep).clamp(-maxAngle, maxAngle);
    _ox += (_ax - _ox) * smoothing;
    _oy += (_ay - _oy) * smoothing;
    return value;
  }

  void reset() {
    _ax = _ay = _ox = _oy = 0;
    _t = null;
  }
}

/// The side of a motion gesture: where the screen turns to face.
enum WristTurn { none, left, right, up, down }

/// A motion gesture: a sharp turn of the wrist to one side, then the return (section 13).
/// A turn around the long axis of the screen is left or right; a turn around the short axis
/// is up or down. A slow tilt (the reflections) and a walk stay under the threshold or do
/// not come back in time. While one turn waits for its return, the other axis does not
/// count; after a gesture, nothing counts for [cooldown].
class WristGestureDetector {
  WristGestureDetector({
    required this.threshold,
    this.window = 0.6,
    this.cooldown = 0.8,
    this.returnPart = 0.5,
  });

  /// The turn rate (rad/s) of each sensitivity.
  static double thresholdOf(CardsStrength sensitivity) => switch (sensitivity) {
        CardsStrength.low => 4.5,
        CardsStrength.medium => 3.0,
        CardsStrength.high => 2.0,
      };

  /// rad/s around an axis of the screen for the first turn.
  final double threshold;

  /// Seconds for the return after the first turn.
  final double window;

  /// Seconds with no gesture after one.
  final double cooldown;

  /// The return needs this part of [threshold], on the other side.
  final double returnPart;

  /// 0 for no turn yet; else the axis of the first turn (1 long axis, 2 short axis).
  int _axis = 0;
  int _side = 0;
  double _since = 0;
  double _quietUntil = -double.infinity;
  double _peak = 0;

  /// The largest turn rate (rad/s) of the last turn: the test of the settings shows it.
  double get peak => _peak;

  /// The side of a finished gesture, [WristTurn.none] for no gesture yet. A turn around the
  /// long axis to the left (the screen turns to face the left) is [WristTurn.left]; around
  /// the short axis, the screen turning to face down is [WristTurn.down].
  WristTurn add(GyroSample s) {
    if (s.t < _quietUntil) return WristTurn.none;
    if (_axis == 0) {
      final horizontal = s.y.abs() >= s.x.abs();
      final w = horizontal ? s.y : s.x;
      if (w.abs() >= threshold) {
        _axis = horizontal ? 1 : 2;
        _side = w < 0 ? -1 : 1;
        _since = s.t;
        _peak = w.abs();
      }
      return WristTurn.none;
    }
    if (s.t - _since > window) {
      _axis = 0;
      _side = 0;
      return add(s);
    }
    final w = _axis == 1 ? s.y : s.x;
    if (w * _side > 0) {
      _peak = math.max(_peak, w.abs());
      return WristTurn.none;
    }
    if (-w * _side >= threshold * returnPart) {
      final turn = _axis == 1
          ? (_side < 0 ? WristTurn.left : WristTurn.right)
          : (_side < 0 ? WristTurn.up : WristTurn.down);
      _axis = 0;
      _side = 0;
      _quietUntil = s.t + cooldown;
      return turn;
    }
    return WristTurn.none;
  }

  /// Notes the turn rate of [s] for the test of the settings (no gesture logic).
  double observe(GyroSample s) => _peak = math.max(_peak * 0.9, math.max(s.y.abs(), s.x.abs()));

  void reset() {
    _axis = 0;
    _side = 0;
    _peak = 0;
    _quietUntil = -double.infinity;
  }
}

/// Keeps the effects at 60 frames per second (section 13, U7): it reads the time of each
/// frame while the deck is on screen and steps the effects down when too many frames are
/// late: 1 = no reflections, 2 = simple transitions too. It never steps up in a session.
class FrameRateGuard {
  FrameRateGuard({this.budget = const Duration(microseconds: 20000), this.window = 60, this.latePart = 0.25});

  /// A frame longer than this is late (1/60 s plus a margin).
  final Duration budget;

  /// The frames of one measure.
  final int window;

  /// The part of late frames that steps down.
  final double latePart;

  int _frames = 0, _late = 0;
  int stepDown = 0;

  /// Adds the time of one frame; true when [stepDown] changed.
  bool add(Duration frame) {
    _frames++;
    if (frame > budget) _late++;
    if (_frames < window) return false;
    final down = _late / _frames > latePart && stepDown < 2;
    _frames = _late = 0;
    if (down) stepDown++;
    return down;
  }
}
