import 'dart:async';

import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/services/motion_cues.dart';
import 'package:argus_wallet/ui/settings/display_settings_page.dart';
import 'package:argus_wallet/ui/widgets/motion_cues_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const g = 9.81;

/// A sample for a phone lying flat on the lap, its top towards the front of the car.
List<double> flat(double right, double forward) => [right, forward, 0, 0, 0, g];

/// A sample for a phone held upright, its back towards the front of the car.
List<double> upright(double right, double forward) => [right, 0, -forward, 0, g, 0];

void main() {
  group('cueShift', () {
    test('the dots move back when the vehicle speeds up and forward when it brakes', () {
      for (final pose in [flat, upright]) {
        expect(MotionCues.cueShift(pose(0, 2))!.dy, closeTo(2 * MotionCues.pixelsPerMs2, 1e-9));
        expect(MotionCues.cueShift(pose(0, -2))!.dy, closeTo(-2 * MotionCues.pixelsPerMs2, 1e-9));
        expect(MotionCues.cueShift(pose(0, 2))!.dx, closeTo(0, 1e-9));
      }
    });

    test('the dots move to the right in a turn to the left', () {
      for (final pose in [flat, upright]) {
        // The pull of a turn to the left points left.
        final s = MotionCues.cueShift(pose(-1.5, 0))!;
        expect(s.dx, closeTo(1.5 * MotionCues.pixelsPerMs2, 1e-9));
        expect(s.dy, closeTo(0, 1e-9));
      }
    });

    test('a phone tilted halfway reads the same as flat or upright', () {
      const c = 0.7071067811865476;
      // Tilted 45° back: forward is +y and -z in equal parts, gravity +y and +z.
      final s = MotionCues.cueShift([0, 2 * c, -2 * c, 0, g * c, g * c])!;
      expect(s.dy, closeTo(2 * MotionCues.pixelsPerMs2, 1e-9));
      expect(s.dx, closeTo(0, 1e-9));
    });

    test('the up-and-down shakes of the road do not move the dots', () {
      final s = MotionCues.cueShift([0, 0, 3, 0, 0, g])!;
      expect(s.distance, closeTo(0, 1e-9));
    });

    test('the shift has a limit', () {
      expect(MotionCues.cueShift(flat(0, 40))!.distance, closeTo(MotionCues.maxShift, 1e-9));
    });

    test('no shift without gravity or without a forward direction', () {
      expect(MotionCues.cueShift([1, 1, 1, 0, 0, 0]), isNull);
      expect(MotionCues.cueShift([1, 1, 1]), isNull);
      // The top of the phone up and the screen facing the floor halfway: no way is forward.
      expect(MotionCues.cueShift([1, 1, 1, 0, g * 0.7071, -g * 0.7071]), isNull);
    });
  });

  group('MotionCues', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('off by default, and the choices are kept', () async {
      final a = MotionCues(samples: () => const Stream.empty(), requestLocation: () async => true);
      await a.load();
      expect(a.mode, MotionCuesMode.off);
      expect(a.useGps, isFalse);
      await a.setMode(MotionCuesMode.automatic);
      expect(await a.setUseGps(true), isTrue);
      final b = MotionCues(samples: () => const Stream.empty());
      await b.load();
      expect(b.mode, MotionCuesMode.automatic);
      expect(b.useGps, isTrue);
    });

    test('without the precise location the GPS stays off', () async {
      final cues = MotionCues(samples: () => const Stream.empty(), requestLocation: () async => false);
      await cues.setMode(MotionCuesMode.automatic);
      expect(await cues.setUseGps(true), isFalse);
      expect(cues.useGps, isFalse);
    });

    test('the sensors run only while on and asked for, and the dots follow them', () async {
      final ctrl = StreamController<List<double>>.broadcast();
      final cues = MotionCues(samples: () => ctrl.stream);
      cues.listen(true);
      expect(cues.listening, isFalse, reason: 'off');
      await cues.setMode(MotionCuesMode.always);
      expect(cues.listening, isTrue);
      for (var i = 0; i < 60; i++) {
        ctrl.add(flat(0, 2));
      }
      await Future<void>.delayed(Duration.zero);
      expect(cues.shift.value.dy, closeTo(2 * MotionCues.pixelsPerMs2, 0.01));
      cues.listen(false);
      expect(cues.listening, isFalse);
      expect(cues.shift.value, Offset.zero);
      cues.listen(true);
      await cues.setMode(MotionCuesMode.off);
      expect(cues.listening, isFalse);
      await ctrl.close();
    });

    test('automatic: the dots show in a vehicle, still elsewhere, and the GPS runs only then', () async {
      final samples = StreamController<List<double>>.broadcast();
      final speeds = StreamController<double>.broadcast();
      final cues = MotionCues(
        samples: () => samples.stream,
        speeds: () => speeds.stream,
        requestLocation: () async => true,
      );
      await cues.setMode(MotionCuesMode.automatic);
      cues.listen(true);
      expect(cues.listening, isTrue);
      expect(cues.listeningToGps, isFalse);
      await cues.setUseGps(true);
      expect(cues.listeningToGps, isTrue);

      var t = 0.0;
      Future<void> brake(int n) async {
        for (var i = 0; i < n; i++) {
          samples.add([0, 0, 2, 0, g, 0, t += 0.02]);
        }
        await Future<void>.delayed(Duration.zero);
      }

      await brake(10);
      expect(cues.showing, isFalse);
      expect(cues.shift.value, Offset.zero, reason: 'hidden dots stay still');
      for (var i = 0; i < 3; i++) {
        speeds.add(9);
      }
      await brake(60);
      expect(cues.showing, isTrue);
      expect(cues.shift.value.dy, lessThan(-5), reason: 'braking moves the dots forward');

      cues.listen(false);
      expect(cues.listeningToGps, isFalse);
      await cues.setMode(MotionCuesMode.always);
      cues.listen(true);
      expect(cues.listeningToGps, isFalse, reason: 'only automatic reads the GPS');
      await samples.close();
      await speeds.close();
    });

    test('a GPS taken back turns the switch off', () async {
      final cues = MotionCues(
        samples: () => const Stream.empty(),
        speeds: () => Stream.error(StateError('no permission')),
        requestLocation: () async => true,
      );
      await cues.setMode(MotionCuesMode.automatic);
      await cues.setUseGps(true);
      cues.listen(true);
      await Future<void>.delayed(Duration.zero);
      expect(cues.listeningToGps, isFalse);
      expect(cues.useGps, isFalse);
    });

    test('a phone without the sensor stops listening', () async {
      final cues = MotionCues(samples: () => Stream.error(StateError('no sensor')));
      await cues.setMode(MotionCuesMode.always);
      cues.listen(true);
      await Future<void>.delayed(Duration.zero);
      expect(cues.listening, isFalse);
    });
  });

  group('MotionCuesOverlay', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('shows the dots only when not off, lets touches through, and stops in the background', (
      tester,
    ) async {
      final ctrl = StreamController<List<double>>.broadcast();
      final cues = MotionCues(samples: () => ctrl.stream);
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: MotionCuesOverlay(
          cues: cues,
          child: Scaffold(body: Center(child: TextButton(onPressed: () => taps++, child: const Text('tap')))),
        ),
      ));
      final dots = find.descendant(of: find.byType(MotionCuesOverlay), matching: find.byType(IgnorePointer));
      expect(dots, findsNothing);
      expect(cues.listening, isFalse);

      await cues.setMode(MotionCuesMode.always);
      await tester.pump();
      expect(dots, findsOneWidget);
      expect(cues.listening, isTrue);
      await tester.tap(find.text('tap'));
      expect(taps, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(cues.listening, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(cues.listening, isTrue);

      await cues.setMode(MotionCuesMode.off);
      await tester.pump();
      expect(dots, findsNothing);
      expect(cues.listening, isFalse);
      await ctrl.close();
    });
  });

  testWidgets('Display: the three modes, and the GPS only for automatic', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The palette cards have a fixed height that the font of the tests overflows.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.toString().contains('overflowed')) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    SharedPreferences.setMockInitialValues({});
    await motionCues.load();
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DisplaySettingsPage(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Use the speed of the GPS'), findsNothing);
    await tester.tap(find.text('Automatic'));
    await tester.pumpAndSettle();
    expect(motionCues.mode, MotionCuesMode.automatic);
    expect(find.text('Use the speed of the GPS'), findsOneWidget);
    await tester.tap(find.text('Always'));
    await tester.pumpAndSettle();
    expect(motionCues.mode, MotionCuesMode.always);
    expect(find.text('Use the speed of the GPS'), findsNothing);
    await motionCues.setMode(MotionCuesMode.off);
  });
}
