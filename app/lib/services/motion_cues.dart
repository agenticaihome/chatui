import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vehicle_detector.dart';

/// When the dots of the vehicle motion cues show.
enum MotionCuesMode {
  off,

  /// While the phone feels a vehicle ([VehicleDetector]).
  automatic,
  always,
}

/// Vehicle motion cues: dots at the sides of the screen that move with the
/// acceleration of the car, bus or train, so what the eyes see agrees with what
/// the body feels and reading on the road makes the user less sick. The dots move
/// as loose things in the vehicle would: back when it speeds up, forward when it
/// brakes, to the right in a turn to the left.
///
/// App-wide and off by default (Settings, Display). The sensors run only while the
/// cues are not off and the app is in front (`MotionCuesOverlay`); the GPS only
/// when, besides, they are automatic and the user turned on [useGps].
class MotionCues extends ChangeNotifier {
  MotionCues({
    Stream<List<double>> Function()? samples,
    Stream<double> Function()? speeds,
    Future<bool> Function()? requestLocation,
  }) : _samples = samples ?? _platformSamples,
       _speeds = speeds ?? _platformSpeeds,
       _requestLocation = requestLocation ?? _platformRequestLocation;

  static const _modeKey = 'argus_vehicle_motion_cues_mode';
  static const _gpsKey = 'argus_vehicle_motion_cues_gps';
  static const _motion = EventChannel('argus/motion');
  static const _speed = EventChannel('argus/speed');
  static const _permission = MethodChannel('argus/motion_permission');

  /// Pixels of shift per m/s² of acceleration, and the most the dots move: a car
  /// that brakes hard (~6 m/s²) takes them nearly to the end.
  static const pixelsPerMs2 = 6.0;
  static const maxShift = 32.0;

  /// The part of each sample that the shift keeps: about 0.15 s at ~50 samples a
  /// second, so the dots follow the road and not the shakes of the hand.
  static const smoothing = 0.12;

  final Stream<List<double>> Function() _samples;
  final Stream<double> Function() _speeds;
  final Future<bool> Function() _requestLocation;
  StreamSubscription<List<double>>? _sampleSub;
  StreamSubscription<double>? _speedSub;
  bool _wanted = false;
  final VehicleDetector _detector = VehicleDetector();

  MotionCuesMode mode = MotionCuesMode.off;

  /// Automatic mode also reads the speed of the GPS: it tells a vehicle from a walk
  /// better, and needs the precise location.
  bool useGps = false;

  /// Whether the user rides a vehicle, as far as the phone can tell.
  bool get inVehicle => _detector.inVehicle;

  /// Whether the dots show now.
  bool get showing => switch (mode) {
    MotionCuesMode.off => false,
    MotionCuesMode.automatic => inVehicle,
    MotionCuesMode.always => true,
  };

  /// The shift of the dots in logical pixels, y down as on the screen.
  final ValueNotifier<Offset> shift = ValueNotifier<Offset>(Offset.zero);

  static Stream<List<double>> _platformSamples() =>
      _motion.receiveBroadcastStream().map((e) => [for (final v in e as List) (v as num).toDouble()]);

  static Stream<double> _platformSpeeds() => _speed.receiveBroadcastStream().map((e) => (e as num).toDouble());

  static Future<bool> _platformRequestLocation() async {
    try {
      return await _permission.invokeMethod<bool>('requestLocation') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modeKey);
    mode = MotionCuesMode.values.firstWhere((m) => m.name == raw, orElse: () => MotionCuesMode.off);
    useGps = prefs.getBool(_gpsKey) ?? false;
    notifyListeners();
  }

  Future<void> setMode(MotionCuesMode value) async {
    if (value == mode) return;
    mode = value;
    _apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, value.name);
  }

  /// Turns the GPS on or off. On asks for the precise location first; without it
  /// the GPS stays off and this returns false.
  Future<bool> setUseGps(bool value) async {
    if (value == useGps) return true;
    if (value && !await _requestLocation()) return false;
    useGps = value;
    _apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gpsKey, value);
    return true;
  }

  /// Starts or stops the sensors. The overlay asks for them while the app is in
  /// front; they run only if the mode needs them.
  void listen(bool on) {
    _wanted = on;
    _apply();
  }

  bool get listening => _sampleSub != null;
  bool get listeningToGps => _speedSub != null;

  void _apply() {
    final sensors = _wanted && mode != MotionCuesMode.off;
    final gps = sensors && mode == MotionCuesMode.automatic && useGps;
    if (sensors) {
      _sampleSub ??= _samples().listen(_onSample, onError: (Object _) => _stopSamples());
    } else {
      _stopSamples();
    }
    // A trip goes on while the app is away for a moment; it ends when the cues do.
    if (mode == MotionCuesMode.off) _detector.reset();
    if (gps) {
      _speedSub ??= _speeds().listen(_detector.addSpeed, onError: (Object _) => _gpsFailed());
    } else {
      _speedSub?.cancel();
      _speedSub = null;
    }
  }

  void _stopSamples() {
    _sampleSub?.cancel();
    _sampleSub = null;
    _speedSub?.cancel();
    _speedSub = null;
    shift.value = Offset.zero;
  }

  /// The location was taken back in the settings of Android, or there is no GPS:
  /// the switch goes off so that it says what happens.
  void _gpsFailed() {
    _speedSub?.cancel();
    _speedSub = null;
    useGps = false;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool(_gpsKey, false)).catchError((_) => false);
  }

  void _onSample(List<double> sample) {
    final was = showing;
    _detector.addSample(sample);
    if (showing != was) notifyListeners();
    // Hidden dots stay still, so they ask for no frames.
    if (!showing) {
      shift.value = Offset.zero;
      return;
    }
    final target = cueShift(sample);
    if (target == null) return;
    final now = shift.value;
    shift.value = now + (target - now) * smoothing;
  }

  /// Where the dots should be for one sample `[ax, ay, az, gx, gy, gz, ...]`
  /// (screen axes: x right, y up, z out of the glass; gravity points up, as the
  /// accelerometer reads it at rest), or null when the phone's pose gives no
  /// forward direction.
  ///
  /// Forward is the way the top of the phone and the back of the phone point, laid
  /// flat on the ground: on the lap it is the top, held upright it is the back, and
  /// the user faces the way the vehicle goes.
  static Offset? cueShift(List<double> sample) {
    if (sample.length < 6) return null;
    final a = _V(sample[0], sample[1], sample[2]);
    final g = _V(sample[3], sample[4], sample[5]);
    if (g.length < 1) return null;
    final up = g / g.length;
    const away = _V(0, 1, -1);
    final level = away - up * away.dot(up);
    if (level.length < 0.1) return null;
    final forward = level / level.length;
    final right = forward.cross(up);
    final dx = -a.dot(right) * pixelsPerMs2;
    final dy = a.dot(forward) * pixelsPerMs2;
    final shift = Offset(dx, dy);
    return shift.distance > maxShift ? shift * (maxShift / shift.distance) : shift;
  }
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;

  _V operator -(_V o) => _V(x - o.x, y - o.y, z - o.z);
  _V operator *(double k) => _V(x * k, y * k, z * k);
  _V operator /(double k) => _V(x / k, y / k, z / k);
  double dot(_V o) => x * o.x + y * o.y + z * o.z;
  _V cross(_V o) => _V(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));
}

final motionCues = MotionCues();
