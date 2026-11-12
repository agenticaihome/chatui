import 'dart:math' as math;

import 'package:argus_wallet/celaut/cards_effects.dart';
import 'package:argus_wallet/celaut/chat/gen/cards.pbenum.dart' as cpb;
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/cards_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Samples of the long axis of the screen, 20 ms apart, from [t0].
List<GyroSample> turn(List<double> wy, {double t0 = 0}) =>
    [for (var i = 0; i < wy.length; i++) GyroSample(0, wy[i], 0, t0 + i * 0.02)];

/// Samples of the short axis of the screen, 20 ms apart, from [t0].
List<GyroSample> pitch(List<double> wx, {double t0 = 0}) =>
    [for (var i = 0; i < wx.length; i++) GyroSample(wx[i], 0, 0, t0 + i * 0.02)];

WristTurn detect(WristGestureDetector d, List<GyroSample> samples) {
  var out = WristTurn.none;
  for (final s in samples) {
    final r = d.add(s);
    if (r != WristTurn.none) out = r;
  }
  return out;
}

double _luminance(Color c) => c.computeLuminance();
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const both = CardsDevice(hasGyroscope: true, hasVibrator: true);

  group('settings of the group "Cards" (cards.md 13)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults: every effect on and medium, motion gestures off', () async {
      final s = CardsSettings(device: both);
      await s.load();
      final fx = s.resolve(reduceMotion: false);
      expect(fx.reflections, isTrue);
      expect(fx.gyroReflections, isTrue);
      expect(fx.reflectionStrength, CardsStrength.medium);
      expect(fx.haptics, isTrue);
      expect(fx.hapticStrength, CardsStrength.medium);
      expect(fx.transitions, CardsTransitions.full);
      expect(fx.style, CardsTransitionStyle.toss);
      expect(fx.frames, CardsFrames.theme);
      expect(fx.gestures, isFalse);
      expect(fx.sensitivity, CardsStrength.medium);
      expect(fx.sounds, isFalse);
      expect(fx.soundVolume, CardsStrength.medium);
    });

    test('each setting is kept on the phone and read back', () async {
      final s = CardsSettings(device: both);
      await s.load();
      await s.setReflections(false);
      await s.setReflectionStrength(CardsStrength.high);
      await s.setVibration(false);
      await s.setVibrationStrength(CardsStrength.low);
      await s.setTransitions(CardsTransitions.simple);
      await s.setStyle(CardsTransitionStyle.fade);
      await s.setFrames(CardsFrames.none);
      await s.setGestures(true);
      await s.setSensitivity(CardsStrength.high);
      await s.setSwapSides(true);
      await s.setSounds(true);
      await s.setSoundVolume(CardsStrength.low);
      final again = CardsSettings(device: both);
      await again.load();
      expect(again.reflections, isFalse);
      expect(again.reflectionStrength, CardsStrength.high);
      expect(again.vibration, isFalse);
      expect(again.vibrationStrength, CardsStrength.low);
      expect(again.transitions, CardsTransitions.simple);
      expect(again.style, CardsTransitionStyle.fade);
      expect(again.frames, CardsFrames.none);
      expect(again.gestures, isTrue);
      expect(again.sensitivity, CardsStrength.high);
      expect(again.swapSides, isTrue);
      expect(again.sounds, isTrue);
      expect(again.soundVolume, CardsStrength.low);
      expect(again.resolve(reduceMotion: false).sounds, isTrue);
    });

    test('"reduce motion" turns the transitions and the reflections down until the user chooses', () async {
      final s = CardsSettings(device: both);
      await s.load();
      var fx = s.resolve(reduceMotion: true);
      expect(fx.reflections, isFalse);
      expect(fx.transitions, CardsTransitions.simple);
      // The rest does not move.
      expect(fx.haptics, isTrue);
      expect(fx.frames, CardsFrames.theme);
      await s.setReflections(true);
      await s.setTransitions(CardsTransitions.full);
      fx = s.resolve(reduceMotion: true);
      expect(fx.reflections, isTrue);
      expect(fx.transitions, CardsTransitions.full);
      // Back to the system.
      await s.setReflections(null);
      await s.setTransitions(null);
      final again = CardsSettings(device: both);
      await again.load();
      expect(again.reflections, isNull);
      expect(again.resolve(reduceMotion: true).transitions, CardsTransitions.simple);
    });

    test('no gyroscope: the reflection stays (it follows the finger), the gestures cannot be on', () async {
      final s = CardsSettings(device: const CardsDevice(hasVibrator: true));
      await s.load();
      await s.setGestures(true);
      final fx = s.resolve(reduceMotion: false);
      expect(fx.reflections, isTrue);
      expect(fx.gyroReflections, isFalse);
      expect(fx.gestures, isFalse);
      expect(fx.wantsGyro, isFalse);
    });

    test('no vibration motor (or an unknown device): no vibration', () async {
      final s = CardsSettings();
      await s.load(); // no platform in a test → CardsDevice.none
      expect(s.device.hasVibrator, isFalse);
      expect(s.resolve(reduceMotion: false).haptics, isFalse);
    });

    test('the steps down of the frame rate: first the reflections, then the full transitions', () async {
      final s = CardsSettings(device: both);
      await s.load();
      expect(s.resolve(reduceMotion: false, stepDown: 1).reflections, isFalse);
      expect(s.resolve(reduceMotion: false, stepDown: 1).transitions, CardsTransitions.full);
      expect(s.resolve(reduceMotion: false, stepDown: 2).transitions, CardsTransitions.simple);
    });
  });

  group('vibration strength', () {
    test('a decision vibrates more than the decision point or a cancel; the strength moves it one step', () {
      expect(hapticLevelOf(CardsHapticEvent.threshold, CardsStrength.medium), HapticLevel.selection);
      expect(hapticLevelOf(CardsHapticEvent.cancel, CardsStrength.medium), HapticLevel.selection);
      expect(hapticLevelOf(CardsHapticEvent.undo, CardsStrength.medium), HapticLevel.light);
      expect(hapticLevelOf(CardsHapticEvent.release, CardsStrength.medium), HapticLevel.medium);
      expect(hapticLevelOf(CardsHapticEvent.release, CardsStrength.low), HapticLevel.light);
      expect(hapticLevelOf(CardsHapticEvent.release, CardsStrength.high), HapticLevel.heavy);
      expect(hapticLevelOf(CardsHapticEvent.threshold, CardsStrength.low), HapticLevel.selection);
    });
  });

  group('sounds (cards.md 5.5)', () {
    test('the service chooses a group; it wins over the tone', () {
      expect(cardsSoundOf(sound: cpb.Sound.SOUND_CONFIRM, tone: cpb.Tone.TONE_NEGATIVE), CardsSound.confirm);
      expect(cardsSoundOf(sound: cpb.Sound.SOUND_REJECT), CardsSound.reject);
      expect(cardsSoundOf(sound: cpb.Sound.SOUND_LATER, tone: cpb.Tone.TONE_POSITIVE), CardsSound.later);
      expect(cardsSoundOf(sound: cpb.Sound.SOUND_SPECIAL), CardsSound.special);
    });

    test('SOUND_DEFAULT comes from keep, then from the tone', () {
      CardsSound d(cpb.Tone t, {bool keep = false}) => cardsSoundOf(tone: t, keep: keep);
      expect(d(cpb.Tone.TONE_NEUTRAL), CardsSound.confirm);
      expect(d(cpb.Tone.TONE_POSITIVE), CardsSound.confirm);
      expect(d(cpb.Tone.TONE_NEGATIVE), CardsSound.reject);
      expect(d(cpb.Tone.TONE_WARNING), CardsSound.later);
      expect(d(cpb.Tone.TONE_ACCENT), CardsSound.special);
      expect(d(cpb.Tone.TONE_NEGATIVE, keep: true), CardsSound.later);
    });

    test('each group is a short tone, 1 s or less, and the groups differ', () {
      final seen = <int>{};
      for (final g in CardsSound.values) {
        final pcm = CardsSounds.pcm(g);
        expect(CardsSounds.lengthOf(g), lessThanOrEqualTo(1.0));
        expect(pcm.length, (CardsSounds.lengthOf(g) * CardsSounds.sampleRate).ceil() * 2);
        expect(pcm.any((b) => b != 0), isTrue);
        seen.add(Object.hashAll(pcm));
      }
      expect(seen.length, CardsSound.values.length);
    });

    test('the volume moves the gain up one step at a time', () {
      expect(CardsSounds.gainOf(CardsStrength.low), lessThan(CardsSounds.gainOf(CardsStrength.medium)));
      expect(CardsSounds.gainOf(CardsStrength.medium), lessThan(CardsSounds.gainOf(CardsStrength.high)));
    });
  });

  group('motion gestures (wrist turn)', () {
    test('a sharp turn and the return is a gesture to that side', () {
      final d = WristGestureDetector(threshold: 3);
      expect(detect(d, turn([-0.5, -4, -6, -3, 1, 3, 0.5])), WristTurn.left);
      final r = WristGestureDetector(threshold: 3);
      expect(detect(r, turn([0.5, 4, 6, 2, -2, -4, 0])), WristTurn.right);
    });

    test('a slow tilt, a turn with no return and a walk are not gestures', () {
      final d = WristGestureDetector(threshold: 3);
      // Slow tilt: under the threshold.
      expect(detect(d, turn([for (var i = 0; i < 100; i++) 0.6 * math.sin(i / 10)])), WristTurn.none);
      // A sharp turn that stays (no return in the window).
      expect(detect(d, turn([-5, -5, -2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3])),
          WristTurn.none);
      // A walk: about 2 steps per second, ±1.2 rad/s.
      expect(detect(d, turn([for (var i = 0; i < 300; i++) 1.2 * math.sin(i * 0.02 * 2 * math.pi * 2)], t0: 10)), WristTurn.none);
    });

    test('a pause after each gesture', () {
      final d = WristGestureDetector(threshold: 3, cooldown: 0.8);
      expect(detect(d, turn([-5, -5, 3])), WristTurn.left);
      // At once again: inside the pause.
      expect(detect(d, turn([-5, -5, 3], t0: 0.2)), WristTurn.none);
      expect(detect(d, turn([-5, -5, 3], t0: 1.2)), WristTurn.left);
    });

    test('a turn around the short axis is up or down, where the screen turns to face', () {
      expect(detect(WristGestureDetector(threshold: 3), pitch([-0.5, -4, -6, -3, 1, 3, 0.5])), WristTurn.up);
      expect(detect(WristGestureDetector(threshold: 3), pitch([0.5, 4, 6, 2, -2, -4, 0])), WristTurn.down);
    });

    test('a slow pitch, a pitch with no return and a walk are not vertical gestures', () {
      final d = WristGestureDetector(threshold: 3);
      expect(detect(d, pitch([for (var i = 0; i < 100; i++) 0.6 * math.sin(i / 10)])), WristTurn.none);
      expect(detect(d, pitch([-5, -5, -2, ...List.filled(40, 0.0), 3], t0: 5)), WristTurn.none);
      expect(detect(d, pitch([for (var i = 0; i < 300; i++) 1.2 * math.sin(i * 0.02 * 2 * math.pi * 2)], t0: 10)),
          WristTurn.none);
    });

    test('the second axis does not count while a turn waits for its return', () {
      final d = WristGestureDetector(threshold: 3);
      // A turn to the left with a rebound on the other axis: one gesture, to the left.
      final samples = [
        for (final s in turn([-0.5, -4, -6, -3, 1, 3, 0.5])) GyroSample(s.y == -4 ? 3.5 : 0, s.y, 0, s.t),
      ];
      expect(detect(d, samples), WristTurn.left);
    });

    test('the sensitivity sets the threshold', () {
      final weak = turn([-2.5, -2.5, 1.5]);
      expect(detect(WristGestureDetector(threshold: WristGestureDetector.thresholdOf(CardsStrength.low)), weak), WristTurn.none);
      expect(detect(WristGestureDetector(threshold: WristGestureDetector.thresholdOf(CardsStrength.medium)), weak), WristTurn.none);
      expect(detect(WristGestureDetector(threshold: WristGestureDetector.thresholdOf(CardsStrength.high)), weak), WristTurn.left);
    });
  });

  group('reflection tilt and frame rate', () {
    test('the tilt is smooth, limited, and comes back to the centre', () {
      final f = TiltFilter();
      var t = 0.0;
      Offset last = Offset.zero;
      for (var i = 0; i < 100; i++) {
        last = f.add(GyroSample(0, 20, 0, t));
        t += 0.02;
      }
      expect(last.dx, closeTo(1, 0.05)); // limited to the max angle
      for (var i = 0; i < 500; i++) {
        last = f.add(GyroSample(0, 0, 0, t));
        t += 0.02;
      }
      expect(last.dx.abs(), lessThan(0.05)); // back to the centre
      // One sample moves the output only a part of the way (low-pass).
      final g = TiltFilter();
      g.add(const GyroSample(0, 0, 0, 0));
      final one = g.add(const GyroSample(0, 10, 0, 0.02));
      expect(one.dx, greaterThan(0));
      expect(one.dx, lessThan(0.2 / 0.35));
    });

    test('too many late frames step the effects down, never up', () {
      final g = FrameRateGuard(window: 10);
      for (var i = 0; i < 10; i++) {
        g.add(const Duration(milliseconds: 10));
      }
      expect(g.stepDown, 0);
      var changed = false;
      for (var i = 0; i < 10; i++) {
        changed = g.add(Duration(milliseconds: i < 5 ? 40 : 10)) || changed;
      }
      expect(changed, isTrue);
      expect(g.stepDown, 1);
      for (var i = 0; i < 30; i++) {
        g.add(const Duration(milliseconds: 40));
      }
      expect(g.stepDown, 2);
      for (var i = 0; i < 30; i++) {
        g.add(const Duration(milliseconds: 5));
      }
      expect(g.stepDown, 2);
    });
  });

  group('frames from the theme (U8)', () {
    for (final p in allPalettes) {
      test('palette ${p.id}: a frame with the theme, the tone kept, and the text keeps its contrast', () {
        final theme = argusThemeFor(p);
        final scheme = theme.colorScheme;
        final framed = cardFrameOf(theme, null, CardsFrames.theme);
        expect(framed.side.width, greaterThan(0));
        expect(framed.radius, cardRadius);
        expect(framed.shadows, isNotEmpty);
        final bare = cardFrameOf(theme, null, CardsFrames.none);
        expect(bare.side, BorderSide.none);
        expect(bare.shadows, isEmpty);
        // The tone of the card stays on the border in both modes.
        for (final mode in CardsFrames.values) {
          final toned = cardFrameOf(theme, Colors.green, mode);
          expect(toned.side.color, Colors.green);
          expect(toned.side.width, 2);
        }
        // The card face is the same surface with or without a frame: the text keeps its
        // contrast (the frame is only around it).
        final fill = framed.decoration(scheme.surfaceContainerHigh).color!;
        expect(fill, bare.decoration(scheme.surfaceContainerHigh).color);
        expect(contrast(scheme.onSurface, fill), greaterThanOrEqualTo(4.5));
        expect(contrast(scheme.onSurfaceVariant, fill), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
