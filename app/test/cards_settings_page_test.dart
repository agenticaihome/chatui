import 'dart:async';

import 'package:argus_wallet/celaut/cards_effects.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/settings/cards_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sensors implements CardsSensors {
  StreamController<GyroSample>? ctrl;
  bool active = false;

  @override
  Stream<GyroSample> gyro() {
    ctrl = StreamController<GyroSample>(onListen: () => active = true, onCancel: () => active = false);
    return ctrl!.stream;
  }
}

/// A snapshot of every setting, to check that one change moves only its own item (U2).
Map<String, Object?> _snap(CardsSettings s) => {
      'reflections': s.reflections,
      'reflectionStrength': s.reflectionStrength,
      'vibration': s.vibration,
      'vibrationStrength': s.vibrationStrength,
      'transitions': s.transitions,
      'style': s.style,
      'frames': s.frames,
      'gestures': s.gestures,
      'sensitivity': s.sensitivity,
      'swapSides': s.swapSides,
    };

Future<void> _open(WidgetTester tester, CardsSettings s, {CardsSensors? sensors, bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
    home: CardsSettingsPage(settings: s, sensors: sensors),
  ));
  await tester.pump();
}

Future<void> _tapIn(WidgetTester tester, String group, String label) async {
  await tester.tap(find.descendant(of: find.byKey(Key(group)), matching: find.text(label)));
  await tester.pump();
}

void main() {
  const both = CardsDevice(hasGyroscope: true, hasVibrator: true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('each item changes only its own setting (U2), and is kept on the phone', (tester) async {
    final s = CardsSettings(device: both)..gestures = true;
    await _open(tester, s);
    Future<void> step(String field, Future<void> Function() act, Object? want) async {
      final before = _snap(s);
      await act();
      final after = _snap(s);
      expect(after[field], want, reason: field);
      for (final k in before.keys) {
        if (k != field) expect(after[k], before[k], reason: '$field changed $k');
      }
    }

    await step('reflections', () async {
      await tester.tap(find.byKey(const Key('cards-set-reflections')));
      await tester.pump();
    }, false);
    await step('reflections', () async {
      await tester.tap(find.byKey(const Key('cards-set-reflections')));
      await tester.pump();
    }, true);
    await step('reflectionStrength', () => _tapIn(tester, 'cards-set-reflection-strength', 'High'), CardsStrength.high);
    await step('vibrationStrength', () => _tapIn(tester, 'cards-set-vibration-strength', 'Low'), CardsStrength.low);
    await step('vibration', () async {
      await tester.tap(find.byKey(const Key('cards-set-vibration')));
      await tester.pump();
    }, false);
    await step('style', () => _tapIn(tester, 'cards-set-style', 'Slide'), CardsTransitionStyle.slide);
    await step('transitions', () => _tapIn(tester, 'cards-set-transitions', 'Simple'), CardsTransitions.simple);
    // The style is only for the full transitions.
    expect(find.byKey(const Key('cards-set-style')), findsNothing);
    await step('frames', () => _tapIn(tester, 'cards-set-frames', 'None'), CardsFrames.none);
    await step('sensitivity', () => _tapIn(tester, 'cards-set-sensitivity', 'High'), CardsStrength.high);
    await step('swapSides', () async {
      await tester.tap(find.byKey(const Key('cards-set-swap')));
      await tester.pump();
    }, true);
    await step('gestures', () async {
      await tester.tap(find.byKey(const Key('cards-set-gestures')));
      await tester.pump();
    }, false);
    expect(find.byKey(const Key('cards-set-sensitivity')), findsNothing);
    await tester.pump();

    final again = CardsSettings(device: both);
    await again.load();
    expect(_snap(again), _snap(s));
  });

  testWidgets('no vibration motor: no vibration item; no gyroscope: no motion gestures (U3)', (tester) async {
    await _open(tester, CardsSettings(device: CardsDevice.none));
    expect(find.byKey(const Key('cards-set-vibration')), findsNothing);
    expect(find.byKey(const Key('cards-set-gestures')), findsNothing);
    // The reflection stays: it follows the finger.
    expect(find.byKey(const Key('cards-set-reflections')), findsOneWidget);
    expect(find.text('A light on the image that follows your finger'), findsOneWidget);

    await _open(tester, CardsSettings(device: both));
    expect(find.byKey(const Key('cards-set-vibration')), findsOneWidget);
    expect(find.byKey(const Key('cards-set-gestures')), findsOneWidget);
    // Off by default: no sensitivity, no test.
    expect(tester.widget<Switch>(find.byKey(const Key('cards-set-gestures'))).value, isFalse);
    expect(find.byKey(const Key('cards-test')), findsNothing);
  });

  testWidgets('"reduce motion": reflections off and simple transitions until the user chooses (U4)', (tester) async {
    final s = CardsSettings(device: both);
    await _open(tester, s, reduceMotion: true);
    expect(tester.widget<Switch>(find.byKey(const Key('cards-set-reflections'))).value, isFalse);
    expect(
      tester.widget<SegmentedButton<CardsTransitions>>(
        find.descendant(
          of: find.byKey(const Key('cards-set-transitions')),
          matching: find.byType(SegmentedButton<CardsTransitions>),
        ),
      ).selected,
      {CardsTransitions.simple},
    );
    expect(find.byKey(const Key('cards-set-follow-system')), findsNothing);
    await tester.tap(find.byKey(const Key('cards-set-reflections')));
    await tester.pump();
    expect(s.reflections, isTrue);
    await tester.tap(find.byKey(const Key('cards-set-follow-system')));
    await tester.pump();
    expect(s.reflections, isNull);
    expect(tester.widget<Switch>(find.byKey(const Key('cards-set-reflections'))).value, isFalse);
  });

  testWidgets('the test of the gesture shows the turn and the side, and stops the sensor', (tester) async {
    final s = CardsSettings(device: both)..gestures = true;
    final sensors = _Sensors();
    await _open(tester, s, sensors: sensors);
    expect(sensors.active, isFalse);
    await tester.tap(find.byKey(const Key('cards-test')));
    await tester.pump();
    expect(sensors.active, isTrue);
    var t = 0.0;
    for (final w in [-1.0, -4.0, -5.0, -2.0, 1.0, 2.0]) {
      sensors.ctrl!.add(GyroSample(0, w, 0, t));
      t += 0.02;
    }
    await tester.pump();
    expect(find.text('Turn: 5.0 rad/s (a gesture needs 3.0)'), findsOneWidget);
    expect(find.text('Detected: a swipe to the left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cards-test')));
    await tester.pump();
    expect(sensors.active, isFalse);
    // It also stops by itself.
    await tester.tap(find.byKey(const Key('cards-test')));
    await tester.pump();
    expect(sensors.active, isTrue);
    await tester.pump(const Duration(seconds: 21));
    expect(sensors.active, isFalse);
  });
}
