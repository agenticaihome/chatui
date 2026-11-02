import 'dart:math' as math;

import 'package:argus_wallet/services/vehicle_detector.dart';
import 'package:flutter_test/flutter_test.dart';

const g = 9.81;
const rate = 50.0;

/// Feeds [seconds] of samples from [at]: the phone upright, its back towards the
/// front; [accel] gives (right, forward, up) in m/s² at a time.
double feed(
  VehicleDetector d,
  double at,
  double seconds,
  (double, double, double) Function(double t) accel,
) {
  final n = (seconds * rate).round();
  for (var i = 0; i < n; i++) {
    final t = at + i / rate;
    final (right, forward, up) = accel(t);
    d.addSample([right, up, -forward, 0, g, 0, t]);
  }
  return at + n / rate;
}

/// A little hum of the engine and the road.
(double, double, double) hum(double t) => (0.05 * math.sin(t * 90), 0.05 * math.sin(t * 70), 0.08 * math.sin(t * 110));

/// A drive: a push of [push] m/s² along the road for 2 s every 15 s.
(double, double, double) Function(double) drive(double from, {double push = 1.5}) => (t) {
      final (r, f, u) = hum(t);
      final inCycle = (t - from) % 15;
      return (r, f + (inCycle < 2 ? push : 0), u);
    };

/// A walk: a step about every 0.55 s, a jolt up and a sway to the sides.
(double, double, double) walk(double t) =>
    (0.6 * math.sin(t * math.pi / 0.55), 0.3 * math.sin(t * 7), 3.0 * math.sin(t * 2 * math.pi / 0.55));

void main() {
  test('a drive is a vehicle after three pushes, and stays one through a stop', () {
    final d = VehicleDetector();
    var t = feed(d, 0, 20, drive(0));
    expect(d.inVehicle, isFalse, reason: 'two pushes are not enough');
    t = feed(d, t, 15, drive(0));
    expect(d.inVehicle, isTrue);
    // A red light: still, with the engine on.
    t = feed(d, t, 60, hum);
    expect(d.inVehicle, isTrue);
    // Parked long enough: the vehicle ends.
    feed(d, t, 90, (_) => (0, 0, 0));
    expect(d.inVehicle, isFalse);
  });

  test('turns one way and the other, with no pause between, are pushes each', () {
    final d = VehicleDetector();
    feed(d, 0, 8, (t) {
      final (r, f, u) = hum(t);
      return (r + ((t ~/ 2).isEven ? 1.5 : -1.5), f, u);
    });
    expect(d.inVehicle, isTrue);
  });

  test('a soft drive under the push threshold is no vehicle', () {
    final d = VehicleDetector();
    feed(d, 0, 90, drive(0, push: 0.5));
    expect(d.inVehicle, isFalse);
  });

  test('a phone on a table is no vehicle', () {
    final d = VehicleDetector();
    feed(d, 0, 120, (_) => (0, 0, 0));
    expect(d.inVehicle, isFalse);
  });

  test('a walk is no vehicle, and a walk ends one', () {
    final d = VehicleDetector();
    var t = feed(d, 0, 90, walk);
    expect(d.inVehicle, isFalse);
    t = feed(d, t, 50, drive(t));
    expect(d.inVehicle, isTrue);
    feed(d, t, 6, walk);
    expect(d.inVehicle, isFalse);
  });

  test('the holes of the road do not look like a walk', () {
    final d = VehicleDetector();
    var t = feed(d, 0, 50, drive(0));
    expect(d.inVehicle, isTrue);
    // Jolts up at uneven times.
    final holes = [0.2, 0.5, 1.3, 1.5, 2.6, 2.8, 3.9, 4.0, 4.9];
    t = feed(d, t, 6, (x) {
      final s = x - t;
      final jolt = holes.any((h) => s >= h && s < h + 0.06);
      final (r, f, u) = hum(x);
      return (r, f, u + (jolt ? 4.0 : 0));
    });
    expect(d.inVehicle, isTrue);
  });

  test('moves of a hand that turn the phone count for nothing', () {
    final d = VehicleDetector();
    final n = (90 * rate).round();
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      // The phone swings between flat and upright, pushed hard one way and the other.
      final angle = (math.pi / 4) * (1 + math.sin(t * 2.0));
      final gy = g * math.sin(angle), gz = g * math.cos(angle);
      final push = 3.0 * math.sin(t * 2.0);
      d.addSample([push, push * math.cos(angle), -push * math.sin(angle), 0, gy, gz, t]);
    }
    expect(d.inVehicle, isFalse);
  });

  test('the GPS: three fast fixes in a row are a vehicle', () {
    final d = VehicleDetector();
    var t = feed(d, 0, 1, (_) => (0, 0, 0));
    for (final speed in [7.0, 8.0, 3.0, 9.0, 9.0]) {
      d.addSpeed(speed);
      t = feed(d, t, 1, (_) => (0, 0, 0));
    }
    expect(d.inVehicle, isFalse, reason: 'a slow fix breaks the row');
    d.addSpeed(9);
    expect(d.inVehicle, isTrue);
    // A stop at a light keeps it.
    for (var i = 0; i < 60; i++) {
      d.addSpeed(0);
      t = feed(d, t, 1, hum);
    }
    expect(d.inVehicle, isTrue);
    feed(d, t, 61, hum);
    expect(d.inVehicle, isFalse);
  });

  test('a speed before any sample is ignored', () {
    final d = VehicleDetector();
    for (var i = 0; i < 5; i++) {
      d.addSpeed(20);
    }
    expect(d.inVehicle, isFalse);
  });

  test('a short time away keeps the trip, and reset forgets it', () {
    final d = VehicleDetector();
    var t = feed(d, 0, 50, drive(0));
    expect(d.inVehicle, isTrue);
    // The app goes away for 30 s.
    t = feed(d, t + 30, 1, hum);
    expect(d.inVehicle, isTrue);
    d.reset();
    expect(d.inVehicle, isFalse);
  });
}
