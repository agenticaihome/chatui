import 'dart:math' as math;

/// Tells whether the user rides a car, a bus or a train, for the automatic vehicle
/// motion cues ([MotionCues]), without the activity recognition of Google:
///
/// - **Pushes.** A vehicle pushes the phone sideways or along the road for a while
///   (it speeds up, brakes, takes a turn). Three pushes of at least
///   [pushAcceleration] for [pushTime] within [pushWindow] mean a vehicle. The
///   moves of a hand are short and go back and forth, and a phone turned in the
///   hand counts for nothing.
/// - **Steps.** Walking shakes the phone up and down about twice a second, with the
///   steady beat of a walk that the holes of a road do not have: a walk ends the
///   vehicle at once.
/// - **The GPS**, when the user allows it: [vehicleSpeed] or more for three fixes in
///   a row is a vehicle, whatever the pushes say. Without a fix (a tunnel) the
///   pushes still count.
///
/// A vehicle stays a vehicle for [hold] after the last sign of one, so the dots do
/// not come and go at a traffic light.
///
/// Times are in seconds on the clock of the samples.
class VehicleDetector {
  static const pushAcceleration = 0.8;
  static const pushTime = 0.7;
  static const pushWindow = 90.0;
  static const pushesForVehicle = 3;
  static const hold = 120.0;

  /// About 22 km/h: faster than running, slower than any road with traffic.
  static const vehicleSpeed = 6.0;
  static const fastFixesForVehicle = 3;

  /// An up-and-down jolt of a step, and the steps in [stepWindow] that make a walk.
  static const stepAcceleration = 1.8;
  static const stepWindow = 5.0;
  static const stepsForWalk = 5;

  /// Turning the phone faster than this (radians a second) is handling, not a road.
  static const handlingTurnRate = 1.0;

  double? _lastT;
  List<double>? _lastUp;
  double _handledUntil = -double.infinity;

  /// The horizontal acceleration, smoothed over ~0.4 s.
  List<double> _horizontal = const [0, 0, 0];
  double? _pushSince;
  List<double>? _pushDir;
  bool _pushCounted = false;
  final List<double> _pushes = [];

  bool _stepArmed = true;
  final List<double> _steps = [];

  int _fastFixes = 0;
  double _vehicleUntil = -double.infinity;

  /// The time of the last sample.
  double? get now => _lastT;

  /// Whether the user rides a vehicle at the time of the last sample.
  bool get inVehicle => _lastT != null && _lastT! < _vehicleUntil;

  /// One sample `[ax, ay, az, gx, gy, gz, t]` of `argus/motion`.
  void addSample(List<double> s) {
    if (s.length < 7) return;
    final t = s[6];
    final g = math.sqrt(s[3] * s[3] + s[4] * s[4] + s[5] * s[5]);
    if (g < 1) return;
    final up = [s[3] / g, s[4] / g, s[5] / g];
    final last = _lastT;
    final dt = last == null ? 0.0 : t - last;
    if (last != null && (dt <= 0 || dt > 1)) {
      // A gap (the app was away) or a clock that went back: start over, keep the verdict.
      _restart(t, up);
      return;
    }
    _lastT = t;

    if (_lastUp != null && dt > 0) {
      final cos = (up[0] * _lastUp![0] + up[1] * _lastUp![1] + up[2] * _lastUp![2]).clamp(-1.0, 1.0);
      if (math.acos(cos) / dt > handlingTurnRate) _handledUntil = t + 1;
    }
    _lastUp = up;

    final vertical = s[0] * up[0] + s[1] * up[1] + s[2] * up[2];
    _step(vertical, t);

    final h = [s[0] - up[0] * vertical, s[1] - up[1] * vertical, s[2] - up[2] * vertical];
    final k = dt / (0.4 + dt);
    _horizontal = [for (var i = 0; i < 3; i++) _horizontal[i] + (h[i] - _horizontal[i]) * k];
    _push(t);
  }

  /// One speed of `argus/speed`, in m/s, at the time of the last sample.
  void addSpeed(double speed) {
    final t = _lastT;
    if (t == null) return;
    if (speed >= vehicleSpeed) {
      _fastFixes++;
      if (_fastFixes >= fastFixesForVehicle) _vehicleUntil = t + hold;
    } else {
      _fastFixes = 0;
    }
  }

  /// Forgets everything: the cues were turned off or the app went away.
  void reset() {
    _lastT = null;
    _lastUp = null;
    _handledUntil = -double.infinity;
    _horizontal = const [0, 0, 0];
    _pushSince = null;
    _pushDir = null;
    _pushCounted = false;
    _pushes.clear();
    _stepArmed = true;
    _steps.clear();
    _fastFixes = 0;
    _vehicleUntil = -double.infinity;
  }

  void _restart(double t, List<double> up) {
    final until = _vehicleUntil;
    final pushes = [..._pushes];
    reset();
    _vehicleUntil = until;
    _pushes.addAll(pushes);
    _lastT = t;
    _lastUp = up;
  }

  void _step(double vertical, double t) {
    if (_stepArmed && vertical > stepAcceleration) {
      _stepArmed = false;
      if (_steps.isEmpty || t - _steps.last > 0.3) _steps.add(t);
      _steps.removeWhere((x) => t - x > stepWindow);
      if (_walking) {
        // A walk: no vehicle, and the pushes so far were the walk.
        _vehicleUntil = -double.infinity;
        _pushes.clear();
        _fastFixes = 0;
      }
    } else if (vertical < 0.5) {
      _stepArmed = true;
    }
  }

  /// The last [stepsForWalk] steps keep a beat of 0.35 to 0.9 s, and keep it steady.
  bool get _walking {
    final t = _lastT;
    if (t == null || _steps.length < stepsForWalk || t - _steps.last > 1) return false;
    final last = _steps.sublist(_steps.length - stepsForWalk);
    final beats = [for (var i = 1; i < last.length; i++) last[i] - last[i - 1]];
    if (beats.any((b) => b < 0.35 || b > 0.9)) return false;
    return beats.reduce(math.max) - beats.reduce(math.min) < 0.25;
  }

  void _push(double t) {
    final m = math.sqrt(_horizontal.fold(0.0, (sum, x) => sum + x * x));
    if (m < pushAcceleration / 2 || t < _handledUntil || _walking) {
      _pushSince = null;
      _pushDir = null;
      _pushCounted = false;
      return;
    }
    if (m < pushAcceleration) return;
    final dir = [for (final x in _horizontal) x / m];
    // A push that turns round (a turn one way, then the other) is a new push.
    if (_pushDir != null && dir[0] * _pushDir![0] + dir[1] * _pushDir![1] + dir[2] * _pushDir![2] < 0) {
      _pushSince = null;
      _pushCounted = false;
    }
    if (_pushSince == null) {
      _pushSince = t;
      _pushDir = dir;
    }
    if (_pushCounted || t - _pushSince! < pushTime) return;
    _pushCounted = true;
    _pushes.add(t);
    _pushes.removeWhere((x) => t - x > pushWindow);
    if (_pushes.length >= pushesForVehicle) _vehicleUntil = t + hold;
  }
}
