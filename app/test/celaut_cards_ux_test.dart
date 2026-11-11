import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/celaut/cards_client.dart';
import 'package:argus_wallet/celaut/cards_effects.dart';
import 'package:argus_wallet/celaut/chat/gen/cards.pb.dart' as cpb;
import 'package:argus_wallet/celaut/chat/gen/chat.pb.dart' as pb;
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/cards_screen.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The UX of the deck (`docs/celaut/cards.md`, section 13) with a fake gyroscope and a
/// recorder of vibrations: each test is deterministic.

final _imageRef = pb.ImageContent(
  file: pb.FileReference(
    hashes: [pb.Hash(type: ChatClient.sha3Type, value: List.filled(32, 7))],
    mimeType: 'image/png',
    sizeBytes: Int64(100),
  ),
);

cpb.Deck _deck() => cpb.Deck(
      deckId: 'shopping-list',
      title: 'Shopping list',
      showProgress: true,
      actions: [
        cpb.DeckAction(actionId: 'later', label: 'Not yet', direction: cpb.Direction.DIRECTION_LEFT),
        cpb.DeckAction(actionId: 'basket', label: 'In the basket', direction: cpb.Direction.DIRECTION_RIGHT),
      ],
      cards: [
        cpb.Card(itemId: 'milk', title: 'Milk', image: _imageRef),
        cpb.Card(itemId: 'bread', title: 'Bread', image: _imageRef),
        cpb.Card(itemId: 'eggs', title: 'Eggs'),
      ],
    );

/// A client with no network for the images.
class _Client extends CardsClient {
  _Client({super.watchOverride, super.sendOverride}) : super(port: 0);

  @override
  Future<Uint8List?> image(DeckCard card) async => null;

  @override
  Uint8List? cachedImage(DeckCard card) => null;
}

class FakeSensors implements CardsSensors {
  StreamController<GyroSample>? _ctrl;
  int listens = 0;
  bool active = false;

  @override
  Stream<GyroSample> gyro() {
    listens++;
    _ctrl = StreamController<GyroSample>(
      onListen: () => active = true,
      onCancel: () => active = false,
    );
    return _ctrl!.stream;
  }

  double _t = 0;

  /// A sharp turn of the wrist to the left (the screen turns to face the left) and back.
  void wristLeft() => _samples([-1, -5, -6, -3, 1, 3.5, 0.5]);
  void wristRight() => _samples([1, 5, 6, 3, -1, -3.5, -0.5]);

  void _samples(List<double> wy) {
    for (final w in wy) {
      _ctrl?.add(GyroSample(0, w, 0, _t));
      _t += 0.02;
    }
    _t += 2; // after the pause
  }

  void tilt(double wy, int n) {
    for (var i = 0; i < n; i++) {
      _ctrl?.add(GyroSample(0, wy, 0, _t));
      _t += 0.02;
    }
  }
}

class _Harness {
  _Harness({CardsDevice device = const CardsDevice(hasGyroscope: true, hasVibrator: true)})
      : settings = CardsSettings(device: device);

  final CardsSettings settings;
  final sensors = FakeSensors();
  final buzz = <HapticLevel>[];
  final events = StreamController<cpb.DeckEvent>();
  final sent = <cpb.SendActionRequest>[];
  late final CardsClient client = _Client(
    watchOverride: () => events.stream,
    sendOverride: (r) async => sent.add(r),
  );

  List<String> get moves => [for (final r in sent) '${r.undo ? 'undo ' : ''}${r.itemId}:${r.actionId}'];

  Future<void> open(WidgetTester tester, {bool reduceMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
      home: CardsScreen(
        title: 'Echo',
        client: client,
        settings: settings,
        sensors: sensors,
        haptics: buzz.add,
        armTimeout: const Duration(seconds: 30),
      ),
    ));
    await tester.pump();
    events.add(cpb.DeckEvent(version: Int64(1), deckId: 'shopping-list', deck: _deck()));
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await client.close();
    await events.close();
  }
}

Finder _card(String id) => find.byKey(Key('cards-card-$id'));

void main() {
  group('vibration (cards.md 13)', () {
    testWidgets('once at the decision point, at the release, at a cancel and at an undo; none per frame',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      final g = await tester.startGesture(tester.getCenter(_card('milk')));
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(h.buzz, isEmpty);
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(30, 0));
        await tester.pump();
      }
      expect(h.buzz, [HapticLevel.selection]); // the decision point, once
      await g.up();
      await tester.pumpAndSettle();
      expect(h.buzz, [HapticLevel.selection, HapticLevel.medium]); // the release
      expect(h.moves, ['milk:basket']);

      // A drag that comes back: a cancel, nothing sent.
      await tester.timedDrag(_card('bread'), const Offset(60, 0), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(h.buzz.last, HapticLevel.selection);
      expect(h.moves, ['milk:basket']);

      await tester.tap(find.byKey(const Key('cards-undo')));
      await tester.pumpAndSettle();
      expect(h.buzz.last, HapticLevel.light);
      expect(h.moves.last, 'undo milk:basket');
      await h.close(tester);
    });

    testWidgets('the setting off, or no vibration motor: no vibration, the same decisions', (tester) async {
      for (final h in [
        _Harness()..settings.vibration = false,
        _Harness(device: const CardsDevice(hasGyroscope: true)),
      ]) {
        await h.open(tester);
        await tester.drag(_card('milk'), const Offset(500, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cards-undo')));
        await tester.pumpAndSettle();
        expect(h.buzz, isEmpty);
        expect(h.moves, ['milk:basket', 'undo milk:basket']);
        await h.close(tester);
      }
    });
  });

  group('transitions and reduce motion', () {
    testWidgets('full: the card leaves over the next one, then it is gone', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('cards-leaving-milk')), findsOneWidget);
      expect(_card('bread'), findsOneWidget); // the deck is already the new state
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cards-leaving-milk')), findsNothing);
      await h.close(tester);
    });

    testWidgets('off: no leaving card at all, the same decisions', (tester) async {
      final h = _Harness()..settings.transitions = CardsTransitions.off;
      await h.open(tester);
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      expect(find.byKey(const ValueKey('cards-leaving-milk')), findsNothing);
      expect(h.moves, ['milk:basket']);
      await h.close(tester);
    });

    testWidgets('"reduce motion" of the system: no reflection, a fade with no movement', (tester) async {
      final h = _Harness();
      await h.open(tester, reduceMotion: true);
      expect(find.byKey(const Key('cards-reflection')), findsNothing);
      expect(h.sensors.listens, 0); // no reflection → no sensor
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final leaving = find.byKey(const ValueKey('cards-leaving-milk'));
      expect(leaving, findsOneWidget);
      // The leaving card stays where it was (it only fades).
      final at = tester.getCenter(leaving);
      expect(at.dx, closeTo(tester.getCenter(_card('bread')).dx, 1));
      await tester.pumpAndSettle();
      await h.close(tester);
    });

    testWidgets('the user\'s choice wins over "reduce motion"', (tester) async {
      final h = _Harness()
        ..settings.reflections = true
        ..settings.transitions = CardsTransitions.full;
      await h.open(tester, reduceMotion: true);
      expect(find.byKey(const Key('cards-reflection')), findsOneWidget);
      await h.close(tester);
    });
  });

  group('reflections', () {
    testWidgets('the gyroscope moves the reflection; it runs only while the deck shows a card (U6)',
        (tester) async {
      final h = _Harness();
      await h.open(tester);
      expect(find.byKey(const Key('cards-reflection')), findsOneWidget);
      expect(h.sensors.active, isTrue);
      h.sensors.tilt(3, 20);
      await tester.pump();
      // To the background: the sensor stops; back: it runs again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(h.sensors.active, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.sensors.active, isTrue);
      // The deck leaves the screen: the sensor stops.
      await h.close(tester);
      expect(h.sensors.active, isFalse);
    });

    testWidgets('no gyroscope: the reflection is there and follows the finger, no sensor (U3)', (tester) async {
      final h = _Harness(device: const CardsDevice(hasVibrator: true));
      await h.open(tester);
      expect(find.byKey(const Key('cards-reflection')), findsOneWidget);
      expect(h.sensors.listens, 0);
      await tester.drag(_card('milk'), const Offset(40, 0));
      await tester.pump();
      expect(h.moves, isEmpty);
      await h.close(tester);
    });

    testWidgets('the setting off: no reflection, no sensor', (tester) async {
      final h = _Harness()..settings.reflections = false;
      await h.open(tester);
      expect(find.byKey(const Key('cards-reflection')), findsNothing);
      expect(h.sensors.listens, 0);
      await h.close(tester);
    });
  });

  group('motion gestures (U5)', () {
    testWidgets('off by default: no arm button, a wrist turn does nothing', (tester) async {
      final h = _Harness()..settings.reflections = false;
      await h.open(tester);
      expect(find.byKey(const Key('cards-arm')), findsNothing);
      h.sensors.wristLeft();
      await tester.pump();
      expect(h.moves, isEmpty);
      await h.close(tester);
    });

    testWidgets('armed: a turn to each side is the swipe of that side, shown and with vibration; undo on screen',
        (tester) async {
      final h = _Harness()
        ..settings.gestures = true
        ..settings.reflections = false;
      await h.open(tester);
      // Not armed yet: no sensor, nothing happens.
      expect(h.sensors.listens, 0);
      expect(find.byKey(const Key('cards-undo')), findsNothing);
      await tester.tap(find.byKey(const Key('cards-arm')));
      await tester.pump();
      expect(find.byKey(const Key('cards-armed')), findsOneWidget);
      expect(h.sensors.active, isTrue);
      // Undo is on screen while armed, even before a decision.
      expect(find.byKey(const Key('cards-undo')), findsOneWidget);
      h.sensors.wristRight();
      await tester.pump();
      // The move shows on the card: it leaves with the label of the action.
      expect(find.byKey(const ValueKey('cards-leaving-milk')), findsOneWidget);
      expect(h.buzz, [HapticLevel.medium]);
      await tester.pumpAndSettle();
      h.sensors.wristLeft();
      await tester.pumpAndSettle();
      expect(h.moves, ['milk:basket', 'bread:later']);
      await h.close(tester);
    });

    testWidgets('a slow tilt is not a gesture; swap sides maps a left turn to the right swipe', (tester) async {
      final h = _Harness()
        ..settings.gestures = true
        ..settings.swapSides = true
        ..settings.reflections = false;
      await h.open(tester);
      await tester.tap(find.byKey(const Key('cards-arm')));
      await tester.pump();
      h.sensors.tilt(1.0, 50);
      await tester.pump();
      expect(h.moves, isEmpty);
      h.sensors.wristLeft();
      await tester.pumpAndSettle();
      expect(h.moves, ['milk:basket']);
      await h.close(tester);
    });

    testWidgets('the mode ends by itself after a time with no use, and when the app goes away', (tester) async {
      final h = _Harness()
        ..settings.gestures = true
        ..settings.reflections = false;
      await h.open(tester);
      await tester.tap(find.byKey(const Key('cards-arm')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      expect(find.byKey(const Key('cards-armed')), findsNothing);
      expect(h.sensors.active, isFalse);
      h.sensors.wristLeft();
      await tester.pump();
      expect(h.moves, isEmpty);

      await tester.tap(find.byKey(const Key('cards-arm')));
      await tester.pump();
      expect(h.sensors.active, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const Key('cards-armed')), findsNothing);
      expect(h.sensors.active, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await h.close(tester);
    });
  });

  testWidgets('every effect off: the deck works the same (U1)', (tester) async {
    final h = _Harness(device: CardsDevice.none)
      ..settings.reflections = false
      ..settings.vibration = false
      ..settings.transitions = CardsTransitions.off
      ..settings.frames = CardsFrames.none;
    await h.open(tester);
    expect(find.byKey(const Key('cards-reflection')), findsNothing);
    await tester.drag(_card('milk'), const Offset(500, 0));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cards-action-later')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cards-undo')));
    await tester.pump();
    expect(h.moves, ['milk:basket', 'bread:later', 'undo bread:later']);
    expect(_card('bread'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(h.buzz, isEmpty);
    expect(h.sensors.listens, 0);
    await h.close(tester);
  });
}
