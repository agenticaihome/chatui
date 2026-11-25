import 'package:argus_wallet/celaut/app_suspension.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('off iOS: nothing is registered and nothing runs', () async {
    final s = AppSuspension(enabled: false);
    var calls = 0;
    final remove = s.register(suspend: () async => calls++, resume: (_) async => calls++);
    await s.suspendAll();
    await s.resumeAll();
    remove();
    expect(calls, 0);
  });

  test('suspend closes every session; the return to the front resumes them with the time away', () async {
    var now = DateTime(2026, 11, 17, 10);
    final s = AppSuspension(enabled: true, now: () => now);
    final log = <String>[];
    s.register(suspend: () async => log.add('a suspend'), resume: (away) async => log.add('a resume ${away.inSeconds}'));
    final removeB = s.register(suspend: () async => log.add('b suspend'), resume: (_) async => log.add('b resume'));
    s.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 2));
    await s.suspendAll();
    expect(s.suspended, isTrue);
    expect(log, ['a suspend', 'b suspend']);
    removeB();
    now = now.add(const Duration(seconds: 40));
    s.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    // Away since the pause, not since the suspend.
    expect(log, ['a suspend', 'b suspend', 'a resume 42']);
    expect(s.suspended, isFalse);
  });

  test('a pause with no suspend does not resume the sessions', () async {
    final s = AppSuspension(enabled: true);
    var resumes = 0;
    s.register(suspend: () async {}, resume: (_) async => resumes++);
    s.didChangeAppLifecycleState(AppLifecycleState.inactive);
    s.didChangeAppLifecycleState(AppLifecycleState.paused);
    s.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(resumes, 0);
  });

  test('a session that does not end in time does not hold the others', () async {
    final s = AppSuspension(enabled: true);
    var other = false;
    s.register(suspend: () => Future<void>.delayed(const Duration(minutes: 1)), resume: (_) async {});
    s.register(suspend: () async => other = true, resume: (_) async {});
    s.register(suspend: () async => throw StateError('broken'), resume: (_) async {});
    await s.suspendAll().timeout(AppSuspension.suspendLimit + const Duration(seconds: 1));
    expect(other, isTrue);
  });

  test('the iOS side calls suspend on the channel and gets its answer after the sessions closed', () async {
    const channel = MethodChannel('test/lifecycle');
    final s = AppSuspension(channel: channel, enabled: true);
    var closed = false;
    s.register(suspend: () async => closed = true, resume: (_) async {});
    s.start();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final answer = await messenger.handlePlatformMessage(
      'test/lifecycle',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('suspend')),
      (_) {},
    );
    expect(closed, isTrue);
    expect(answer, isNotNull);
    expect(s.suspended, isTrue);
  });
}
