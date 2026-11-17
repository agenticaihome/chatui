import 'dart:async';

import 'package:argus_wallet/celaut/background_work.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ForegroundHolds.channelName);
  final calls = <String>[];

  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  String describe(MethodCall call) {
    final reasons = (call.arguments as Map?)?['reasons'];
    return reasons == null ? call.method : '${call.method} ${(reasons as List).join(',')}';
  }

  setUp(() {
    calls.clear();
    answer((call) async {
      calls.add(describe(call));
      return call.method == 'start' ? true : null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  ForegroundHolds holds() => ForegroundHolds(isAndroid: true);

  group('the conversation', () {
    test('start asks for the notification permission, then starts the service', () async {
      await ChannelConversationKeepAlive(holds: holds()).start();
      await pumpEventQueue();
      expect(calls, ['requestNotificationPermission', 'start conversation']);
    });

    test('stop stops the service', () async {
      final keepAlive = ChannelConversationKeepAlive(holds: holds());
      await keepAlive.start();
      await keepAlive.stop();
      await pumpEventQueue();
      expect(calls, ['requestNotificationPermission', 'start conversation', 'stop']);
    });

    test('a refused permission does not stop the start', () async {
      answer((call) async {
        calls.add(describe(call));
        return false;
      });
      await ChannelConversationKeepAlive(holds: holds()).start();
      await pumpEventQueue();
      expect(calls, ['requestNotificationPermission', 'start conversation']);
    });

    test('the wait for a start adds the launch, and its end takes it away', () async {
      final keepAlive = ChannelConversationKeepAlive(holds: holds());
      await keepAlive.start();
      await keepAlive.waiting(true);
      await keepAlive.waiting(false);
      await keepAlive.stop();
      await pumpEventQueue();
      expect(calls, [
        'requestNotificationPermission',
        'start conversation',
        'start conversation,launch',
        'start conversation',
        'stop',
      ]);
    });

    test('on a platform that is not Android it does nothing', () async {
      final keepAlive = ChannelConversationKeepAlive(holds: ForegroundHolds(isAndroid: false));
      await keepAlive.start();
      await keepAlive.stop();
      expect(calls, isEmpty);
    });

    test('a platform error or a missing channel never throws', () async {
      answer((call) async => throw PlatformException(code: 'x'));
      final keepAlive = ChannelConversationKeepAlive(holds: holds());
      await keepAlive.start();
      await keepAlive.stop();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await keepAlive.start();
      await keepAlive.stop();
    });
  });

  group('the holds', () {
    test('the service runs while one hold is taken, and shows every reason', () async {
      final h = holds();
      final conversation = h.hold(KeepAliveReason.conversation);
      final transfer = h.hold(KeepAliveReason.transfer);
      // The end of the conversation does not stop the transfer.
      await conversation();
      expect(h.reasons, {KeepAliveReason.transfer});
      await transfer();
      // A second release does nothing.
      await transfer();
      await pumpEventQueue();
      expect(calls, ['start conversation', 'start conversation,transfer', 'start transfer', 'stop']);
    });
  });

  group('the hold of a pending answer', () {
    test('starts the service with the reason answer, and the last release stops it', () async {
      final h = holds();
      final first = h.hold(KeepAliveReason.answer);
      await pumpEventQueue();
      final second = h.hold(KeepAliveReason.answer);
      await pumpEventQueue();
      await first();
      expect(calls.last, 'start answer');
      await second();
      expect(calls.last, 'stop');
    });
  });

  group('the work of a launch, a transfer, an import', () {
    late List<String> pages;
    late bool locked;
    late GlobalKey<NavigatorState> navigator;

    Future<BuildContext> pumpPages(WidgetTester tester) async {
      navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Text('home')));
      navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('work')));
      await tester.pumpAndSettle();
      return tester.element(find.text('work'));
    }

    setUp(() {
      pages = [];
      locked = false;
    });

    testWidgets('a lock with no work closes every page over home', (tester) async {
      final work = BackgroundWork(holds: holds(), walletLocked: () => locked);
      await pumpPages(tester);
      work.onWalletLocked(navigator.currentState);
      await tester.pumpAndSettle();
      expect(find.text('work'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a lock during a work keeps the page of the work, which goes on', (tester) async {
      final work = BackgroundWork(holds: holds(), walletLocked: () => locked);
      final context = await pumpPages(tester);
      final done = work.run(context, KeepAliveReason.import, () async {
        // The file picker is open; the app goes to the background and the wallet locks.
        locked = true;
        work.onWalletLocked(navigator.currentState);
        // A page that opened over the page of the work while it ran.
        unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('over'))));
        await tester.pumpAndSettle();
        expect(find.text('over'), findsOneWidget, reason: 'the lock closes nothing while the work runs');
        pages.add('picked');
        return 'loaded';
      });
      expect(await done, 'loaded');
      await tester.pumpAndSettle();
      // The work ended: the page of the work stays, the page over it closed.
      expect(find.text('work'), findsOneWidget);
      expect(find.text('over'), findsNothing);
      expect(pages, ['picked']);
      await tester.pump();
      expect(calls, ['start import', 'stop']);
    });

    testWidgets('a work that ends with the wallet unlocked again closes nothing', (tester) async {
      final work = BackgroundWork(holds: holds(), walletLocked: () => locked);
      final context = await pumpPages(tester);
      await work.run(context, KeepAliveReason.launch, () async {
        locked = true;
        work.onWalletLocked(navigator.currentState);
        // The user unlocked the wallet again.
        locked = false;
      });
      await tester.pumpAndSettle();
      expect(find.text('work'), findsOneWidget);
    });
  });

  group('macOS (App Nap)', () {
    ForegroundHolds mac() => ForegroundHolds(isAndroid: false, isMacOS: true);

    test('the holds go to the channel, as on Android', () async {
      final keepAlive = ChannelConversationKeepAlive(holds: mac());
      await keepAlive.start();
      await keepAlive.stop();
      await pumpEventQueue();
      expect(calls, ['requestNotificationPermission', 'start conversation', 'stop']);
    });

    test('automatic top-up holds the activity', () async {
      final holds = mac();
      final release = holds.hold(KeepAliveReason.topUp);
      await pumpEventQueue();
      await release();
      expect(calls, ['start topUp', 'stop']);
    });
  });

  test('on Android automatic top-up does not start the foreground service', () async {
    final holds = holds0();
    final topUp = holds.hold(KeepAliveReason.topUp);
    await pumpEventQueue();
    final talk = holds.hold(KeepAliveReason.conversation);
    await pumpEventQueue();
    await talk();
    await topUp();
    expect(calls, ['start conversation', 'stop']);
  });
}

ForegroundHolds holds0() => ForegroundHolds(isAndroid: true);
