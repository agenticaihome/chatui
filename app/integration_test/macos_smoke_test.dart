// The checks of the macOS app (issue #154) that need the real app: the Rust core linked
// into it, the Swift channels, the plugins and the system (keychain, Launch Services, App
// Nap, Tor). CI runs it on an Apple Silicon runner:
//
//   cd app && flutter test integration_test/macos_smoke_test.dart -d macos
//
// It touches only what it makes: a test wallet in the keychain (deleted at the end), files in
// a temporary folder, and the Tor state in the private folder of the app. Each check prints
// one line `MACOS_SMOKE <name> <result>` for the log of the run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:argus_wallet/bridge/api/celaut_network.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:argus_wallet/celaut/incoming_package.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:argus_wallet/celaut/routed_http.dart';
import 'package:argus_wallet/services/deep_link_channel.dart';
import 'package:argus_wallet/services/deep_link_controller.dart';
import 'package:argus_wallet/services/rust_library.dart';
import 'package:argus_wallet/services/secure_storage.dart';
import 'package:argus_wallet/ui/scan_screen.dart' show readQrImage;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';

void say(String name, Object? result) => debugPrint('MACOS_SMOKE $name $result');

/// The .app of this run: …/Chatui.app/Contents/MacOS/Chatui.
String appBundle() => File(Platform.resolvedExecutable).parent.parent.parent.path;

Future<void> until(bool Function() done, Duration limit, {Duration step = const Duration(milliseconds: 200)}) async {
  final end = DateTime.now().add(limit);
  while (!done() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(step);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(Platform.isMacOS, isTrue, reason: 'this test is for the macOS app');
    await initRustLib();
  });

  testWidgets('the Rust core is linked into the app and answers', (tester) async {
    final status = celautNetworkStatus();
    say('rust_core', 'ok choice=${status.choice.name} state=${status.state.name}');
    final proxy = celautNetworkProxy();
    expect(proxy.kind, NetworkProxyKind.direct);
  });

  testWidgets('the arm64 app, and the system libraries it links', (tester) async {
    final file = await Process.run('file', [Platform.resolvedExecutable]);
    say('executable', (file.stdout as String).trim());
    expect(file.stdout as String, contains('arm64'));
    expect(file.stdout as String, isNot(contains('x86_64')));
  });

  testWidgets('the keychain keeps, reads and deletes a wallet', (tester) async {
    final id = 'ci-smoke-$pid';
    await SecureStorageService.saveWallet(walletId: id, encryptedSeedJson: '{"ci":true}', wrapKey: 'wrap-$id');
    expect(await SecureStorageService.hasEncryptedSeed(walletId: id), isTrue);
    expect(await SecureStorageService.loadEncryptedSeed(walletId: id), '{"ci":true}');
    expect(await SecureStorageService.loadWrapKey(walletId: id), 'wrap-$id');
    expect(await SecureStorageService.listWalletIds(), contains(id));
    await SecureStorageService.savePinGate(count: 2, until: 1234);
    expect(await SecureStorageService.loadPinGate(), (count: 2, until: 1234));
    await SecureStorageService.clearPinGate();
    await SecureStorageService.deleteWallet(id);
    expect(await SecureStorageService.hasEncryptedSeed(walletId: id), isFalse);
    expect(await SecureStorageService.listWalletIds(), isNot(contains(id)));
    final dbPath = await SecureStorageService.celautDbPath();
    expect(dbPath, endsWith('Library/Application Support/org.celaut.chatui/celaut/celaut.db'));
    expect(Directory(File(dbPath!).parent.path).existsSync(), isTrue);
    final biometric = await SecureStorageService.hasBiometric();
    final hidden = await SecureStorageService.setSecureFlag(true);
    await SecureStorageService.setSecureFlag(false);
    say('keychain', 'ok db=$dbPath touchIdOrPassword=$biometric secureFlag=$hidden');
  });

  testWidgets('celaut: and ergopay: links open in the app', (tester) async {
    await DeepLinkChannel.start();
    final lsregister =
        '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister';
    await Process.run(lsregister, ['-f', appBundle()]);
    for (final link in ['celaut://node?addr=127.0.0.1:9', 'ergopay://example.org/pay']) {
      deepLinkController.take();
      final open = await Process.run('open', [link]);
      expect(open.exitCode, 0, reason: '${open.stderr}');
      await until(() => deepLinkController.pending != null, const Duration(seconds: 20));
      say('deeplink', '$link -> ${deepLinkController.pending}');
      expect(deepLinkController.take(), link);
    }
  });

  testWidgets('a .celaut.bee file opens in the app, and the package channel reads it', (tester) async {
    final dir = await Directory.systemTemp.createTemp('chatui-smoke');
    final file = File('${dir.path}/smoke.celaut.bee');
    await file.writeAsBytes(List<int>.generate(5 << 20, (i) => i % 251));
    await IncomingPackageChannel.start();
    final open = await Process.run('open', ['-a', appBundle(), file.path]);
    expect(open.exitCode, 0, reason: '${open.stderr}');
    await until(() => incomingPackages.pending != null, const Duration(seconds: 20));
    final pending = incomingPackages.take();
    incomingPackages.setBusy(false);
    say('open_file', '${pending?.name} ${pending?.bytes} ${pending?.uri}');
    expect(pending?.name, 'smoke.celaut.bee');
    expect(pending?.bytes, 5 << 20);

    // The UTI of the type: a .celaut.bee file is ours.
    final mdls = await Process.run('mdls', ['-name', 'kMDItemContentType', file.path]);
    say('uti', (mdls.stdout as String).trim());

    const channel = AndroidPackageChannel();
    final opened = await channel.open(pending!);
    expect(opened, isNotNull);
    expect(opened!.fd, greaterThanOrEqualTo(0));
    expect(opened.bytes, 5 << 20);
    final copy = await channel.copy(pending);
    expect(File(copy.path).lengthSync(), 5 << 20);
    expect(channel.copied, 5 << 20);
    say('package_channel', 'ok fd=${opened.fd} copy=${copy.path}');
    await dir.delete(recursive: true);
  });

  testWidgets('a hold turns App Nap off with a ProcessInfo activity', (tester) async {
    const channel = MethodChannel(ForegroundHolds.channelName);
    Future<Map<Object?, Object?>?> state() => channel.invokeMapMethod<Object?, Object?>('state');
    final holds = ForegroundHolds();
    expect((await state())?['activity'], 'none');

    final talk = holds.hold(KeepAliveReason.conversation);
    await pumpEventQueue();
    expect((await state())?['activity'], 'userInitiatedAllowingIdleSystemSleep');

    final launch = holds.hold(KeepAliveReason.launch);
    await pumpEventQueue();
    expect((await state())?['activity'], 'userInitiated');
    final assertions = await Process.run('pmset', ['-g', 'assertions']);
    final ours = (assertions.stdout as String).split('\n').where((l) => l.contains('Chatui')).join(' | ');
    say('pmset', ours.isEmpty ? '(no assertion line with Chatui)' : ours);

    await launch();
    await talk();
    final topUp = holds.hold(KeepAliveReason.topUp);
    await pumpEventQueue();
    expect((await state())?['activity'], 'userInitiatedAllowingIdleSystemSleep');
    await topUp();
    expect((await state())?['activity'], 'none');
    say('app_nap_activity', 'ok');
  });

  testWidgets('timers of the hidden app, with and without the activity', (tester) async {
    // App Nap slows the timers of an app that is hidden and idle. Measure the largest gap of a
    // 1-s timer for 60 s while the app is hidden, first with no hold, then with a hold. A CI
    // machine may never nap (it is not on battery and nothing covers the app): the line says
    // what happened; only the run with the hold must keep its pace.
    Future<Duration> worstGap() async {
      var last = DateTime.now();
      var worst = Duration.zero;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        if (now.difference(last) > worst) worst = now.difference(last);
        last = now;
      });
      // Not tester.pump: real time passes, as for a hidden app.
      await Future<void>.delayed(const Duration(seconds: 60));
      timer.cancel();
      return worst;
    }

    Future<ProcessResult> hide(bool hidden) => Process.run('osascript', [
          '-e',
          'tell application "System Events" to set visible of (first process whose unix id is $pid) to ${!hidden}',
        ]);

    final hidden = await hide(true);
    say('hide', 'exit=${hidden.exitCode} ${(hidden.stderr as String).trim()}');
    final without = await worstGap();
    final holds = ForegroundHolds();
    final release = holds.hold(KeepAliveReason.conversation);
    final withHold = await worstGap();
    await release();
    await hide(false);
    say('app_nap_timer', 'hidden=${hidden.exitCode == 0} worst gap without hold=${without.inMilliseconds} ms, '
        'with hold=${withHold.inMilliseconds} ms');
    expect(withHold, lessThan(const Duration(milliseconds: 2500)));
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('zxing reads a QR code from an image file', (tester) async {
    const text = 'celaut://node?addr=203.0.113.7:53460';
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 480.0;
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = Colors.white);
    canvas.translate(40, 40);
    QrPainter(data: text, version: QrVersions.auto, gapless: true).paint(canvas, const Size(400, 400));
    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await Directory.systemTemp.createTemp('chatui-qr');
    final file = File('${dir.path}/qr.png');
    await file.writeAsBytes(png!.buffer.asUint8List());
    final code = await readQrImage(file.path);
    say('zxing_image', 'valid=${code.isValid} text=${code.text} error=${code.error}');
    expect(code.isValid, isTrue);
    expect(code.text, text);
    await dir.delete(recursive: true);
  });

  testWidgets('the plugins of the app are the macOS ones', (tester) async {
    final recorder = AudioRecorder();
    final aac = await recorder.isEncoderSupported(AudioEncoder.aacLc);
    await recorder.dispose();
    say('record', 'aacLc=$aac');
    expect(aac, isTrue);

    final notifications = FlutterLocalNotificationsPlugin();
    final ready = await notifications.initialize(
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    say('notifications', 'initialize=$ready');
    expect(ready, isNotNull);

    say('file_picker', FilePicker.platform.runtimeType);
    expect('${FilePicker.platform.runtimeType}', contains('MacOS'));
  });

  testWidgets('arti (Tor) starts without the sandbox and carries a request', (tester) async {
    final dbPath = await SecureStorageService.celautDbPath();
    final dataDir = File(dbPath!).parent.path;
    final started = DateTime.now();
    await celautSetNetwork(choice: NetworkChoice.embedded, dataDir: dataDir);
    var status = celautNetworkStatus();
    await until(() {
      status = celautNetworkStatus();
      return status.state == NetworkState.ready || status.state == NetworkState.failed;
    }, const Duration(minutes: 4), step: const Duration(seconds: 1));
    final took = DateTime.now().difference(started);
    say('tor_bootstrap', '${status.state.name} ${status.percent}% in ${took.inSeconds} s ${status.error}');
    expect(status.state, NetworkState.ready);

    final proxy = celautNetworkProxy();
    expect(proxy.kind, NetworkProxyKind.socks);
    final client = routedHttpClient();
    try {
      final reply = await client
          .get(Uri.parse('https://check.torproject.org/api/ip'))
          .timeout(const Duration(minutes: 2));
      say('tor_request', '${reply.statusCode} ${reply.body.trim()}');
      expect(reply.statusCode, 200);
      expect((jsonDecode(reply.body) as Map)['IsTor'], isTrue);
    } finally {
      client.close();
      await celautSetNetwork(choice: NetworkChoice.off, dataDir: dataDir);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
