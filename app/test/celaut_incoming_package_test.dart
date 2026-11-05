import 'package:argus_wallet/celaut/incoming_package.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _echo = ChosenFile(uri: 'content://downloads/1', name: 'echo.celaut.bee', bytes: 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the files that the user opened', () {
    test('a file waits until the home screen takes it, once', () {
      final incoming = IncomingPackages();
      var told = 0;
      incoming.addListener(() => told++);
      incoming.push(_echo);
      expect(told, 1);
      expect(incoming.pending?.uri, _echo.uri);
      // The cold start can give the same file twice.
      incoming.push(_echo);
      expect(told, 1);
      expect(incoming.take()?.name, 'echo.celaut.bee');
      expect(incoming.take(), isNull);
      expect(incoming.pending, isNull);
    });

    test('while an import runs, the next file waits, and is told when the import ends', () {
      final incoming = IncomingPackages();
      var told = 0;
      incoming.addListener(() => told++);
      incoming.setBusy(true);
      incoming.push(_echo);
      expect(incoming.take(), isNull);
      expect(incoming.pending, isNotNull);
      incoming.setBusy(false);
      expect(told, 2, reason: 'the push, then the end of the import');
      expect(incoming.take()?.uri, _echo.uri);
    });

    test('the file that the app imports now is not taken again', () {
      final incoming = IncomingPackages();
      incoming.push(_echo);
      expect(incoming.take(), isNotNull);
      incoming.setBusy(true);
      incoming.push(_echo);
      expect(incoming.pending, isNull);
      incoming.setBusy(false);
      incoming.push(_echo);
      expect(incoming.pending, isNotNull, reason: 'after the import, the same file can come again');
    });

    test('the message of the Android side: a uri is needed, the size only if known', () {
      expect(chosenFileOf(null), isNull);
      expect(chosenFileOf({'name': 'a.celaut.bee'}), isNull);
      expect(chosenFileOf({'uri': ''}), isNull);
      final file = chosenFileOf({'uri': 'content://x/2', 'name': 'a.celaut.bee', 'bytes': -1})!;
      expect(file.uri, 'content://x/2');
      expect(file.name, 'a.celaut.bee');
      expect(file.bytes, isNull);
      expect(chosenFileOf({'uri': 'content://x/3', 'bytes': 7})!.name, 'content://x/3');
    });
  });

  group('the channel', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<String> methods;

    setUp(() {
      methods = [];
      IncomingPackageChannel.reset();
    });
    tearDown(() => messenger.setMockMethodCallHandler(IncomingPackageChannel.channel, null));

    test('the file of a cold start comes from takeIncoming', () async {
      messenger.setMockMethodCallHandler(IncomingPackageChannel.channel, (call) async {
        methods.add(call.method);
        return {'uri': 'content://downloads/1', 'name': 'echo.celaut.bee', 'bytes': 10};
      });
      final incoming = IncomingPackages();
      await IncomingPackageChannel.start(into: incoming);
      expect(methods, ['takeIncoming']);
      expect(incoming.pending?.uri, 'content://downloads/1');
    });

    test('a file that comes while the app runs is pushed by the Android side', () async {
      messenger.setMockMethodCallHandler(IncomingPackageChannel.channel, (call) async => null);
      final incoming = IncomingPackages();
      await IncomingPackageChannel.start(into: incoming);
      expect(incoming.pending, isNull);
      ByteData? reply;
      await messenger.handlePlatformMessage(
        IncomingPackageChannel.channel.name,
        IncomingPackageChannel.channel.codec.encodeMethodCall(
          const MethodCall('incoming', {'uri': 'content://downloads/2', 'name': 'b.celaut.bee', 'bytes': 5}),
        ),
        (data) => reply = data,
      );
      expect(incoming.pending?.name, 'b.celaut.bee');
      // The Android side forgets the file only when Flutter answered.
      expect(IncomingPackageChannel.channel.codec.decodeEnvelope(reply!), isTrue);
    });

    test('without the Android side nothing comes and nothing throws', () async {
      final incoming = IncomingPackages();
      await IncomingPackageChannel.start(into: incoming);
      expect(incoming.pending, isNull);
    });
  });
}
