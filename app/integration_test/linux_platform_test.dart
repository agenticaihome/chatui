// The Linux side of the platform channels (app/linux/runner, issue #153) and the plugins
// that the Linux app uses, in the real runner. Run it in a desktop session that has a
// Secret Service and a sound server; scripts/test_linux.sh makes one with no display:
//
//   scripts/test_linux.sh            (from the root of the repository, on Linux)
//
// It writes and then deletes its own items in the keyring of the session, and puts the
// fail count of the PIN back as it was. The Tor test needs the Internet and a minute or
// more: it runs only with `--dart-define=SUPERAPP_TEST_TOR=true`.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:argus_wallet/bridge/api/celaut_db.dart';
import 'package:argus_wallet/bridge/api/celaut_network.dart';
import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/celaut/audio_recorder.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:argus_wallet/services/linux_app.dart';
import 'package:argus_wallet/services/secure_storage.dart';
import 'package:argus_wallet/ui/scan_screen.dart';
import 'package:argus_wallet/ui/settings/security_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('superapp-linux-test');
    // From the lib folder of the bundle (main.cc gives it to flutter_rust_bridge).
    await RustLib.init();
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  testWidgets('the Rust core loads from the lib folder of the bundle', (tester) async {
    expect(celautNewDatabaseKey(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  testWidgets('secure storage keeps a wallet in the Secret Service', (tester) async {
    final id = 'linux-test-${DateTime.now().microsecondsSinceEpoch}';
    final gate = await SecureStorageService.loadPinGate();
    try {
      await SecureStorageService.saveWallet(walletId: id, encryptedSeedJson: '{"sealed":1}', wrapKey: 'wrap-$id');
      expect(await SecureStorageService.loadEncryptedSeed(walletId: id), '{"sealed":1}');
      expect(await SecureStorageService.hasWrapKey(walletId: id), isTrue);
      expect(await SecureStorageService.listWalletIds(), contains(id));
      // No fingerprint or screen lock on the desktop: the key comes with no prompt.
      expect(await SecureStorageService.hasBiometric(), isFalse);
      expect(await SecureStorageService.authenticateBiometric(walletId: id), 'wrap-$id');
      // No FLAG_SECURE on Linux.
      expect(await SecureStorageService.setSecureFlag(true), isFalse);

      await SecureStorageService.savePinWrap('{"pin":1}', walletId: id);
      expect(await SecureStorageService.loadPinWrap(walletId: id), '{"pin":1}');
      await SecureStorageService.deletePinWrap(walletId: id);
      expect(await SecureStorageService.hasPinWrap(walletId: id), isFalse);

      await SecureStorageService.savePinGate(count: 3, until: 1 << 40);
      final saved = await SecureStorageService.loadPinGate();
      expect((saved.count, saved.until), (3, 1 << 40));
    } finally {
      await SecureStorageService.savePinGate(count: gate.count, until: gate.until);
      await SecureStorageService.deleteWallet(id);
    }
    expect(await SecureStorageService.hasEncryptedSeed(walletId: id), isFalse);
    expect(await SecureStorageService.loadWrapKey(walletId: id), isNull);
    expect(await SecureStorageService.listWalletIds(), isNot(contains(id)));

    final db = await SecureStorageService.celautDbPath();
    expect(db, endsWith('/org.celaut.superapp/celaut/celaut.db'));
    expect(File(db!).parent.existsSync(), isTrue);
  });

  testWidgets('the package channel copies a file and gives its descriptor', (tester) async {
    final bytes = List<int>.generate(3 << 20, (i) => i * 7 & 255);
    final source = File('${dir.path}/service.celaut.bee')..writeAsBytesSync(bytes);
    const channel = AndroidPackageChannel(android: true);
    final file = ChosenFile(uri: source.path, name: 'service.celaut.bee');

    final picked = await channel.copy(file);
    expect(picked.bytes, bytes.length);
    expect(picked.path, contains('/org.celaut.superapp/celaut/packages/incoming/'));
    expect(File(picked.path).readAsBytesSync(), bytes);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(channel.copied, bytes.length);
    File(picked.path).deleteSync();

    final opened = await channel.open(file);
    expect(opened, isNotNull);
    expect(opened!.bytes, bytes.length);
    expect(opened.fd, greaterThan(2));

    await expectLater(
      channel.copy(ChosenFile(uri: '${dir.path}/missing.celaut.bee', name: 'missing')),
      throwsA(isA<CopyFailed>()),
    );
  });

  testWidgets('zxing reads a QR code from an image file', (tester) async {
    const text = 'celaut://node?addr=203.0.113.7:58526';
    final path = await _qrImage(text, '${dir.path}/qr.png');
    // The read of the scan screen (ScanScreen._fromImage).
    final code = await readQrImage(path);
    expect(code.isValid, isTrue);
    expect(code.text, text);

    final blank = await _qrImage(null, '${dir.path}/blank.png');
    final none = await readQrImage(blank);
    expect(none.isValid, isFalse);
  });

  testWidgets('record captures the microphone with parecord', (tester) async {
    final recorder = RecordAudioRecorder();
    try {
      expect(await recorder.start(), isTrue);
      await Future<void>.delayed(const Duration(seconds: 2));
      final voice = await recorder.stop();
      expect(voice, isNotNull);
      // 16 kHz, 16-bit mono: more than one second of the two.
      expect(voice!.bytes.length, greaterThan(44 + audioSampleRate * 2));
    } finally {
      await recorder.dispose();
    }
  });

  testWidgets('the Linux screens: no "Block screenshots", and the .deb of this machine', (tester) async {
    // The real runner is the Linux app, whatever `flutter test` puts in the environment.
    expect(isLinuxApp, isTrue);
    final machine = (await Process.run('uname', ['-m'])).stdout.toString().trim();
    expect(linuxDebArch, machine == 'aarch64' ? 'arm64' : 'amd64', reason: 'uname -m: $machine');

    tester.view.physicalSize = const Size(480, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SecuritySettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Login keyring of the desktop'), findsOneWidget);
    expect(find.text('Block screenshots'), findsNothing);
    expect(find.text('Spend unconfirmed funds'), findsOneWidget, reason: 'the page is there');
  });

  testWidgets(
    'the Tor client inside the app (arti) bootstraps',
    (tester) async {
      final data = Directory('${dir.path}/tor')..createSync();
      final clock = Stopwatch()..start();
      await celautSetNetwork(choice: NetworkChoice.embedded, dataDir: data.path);
      try {
        var status = celautNetworkStatus();
        var percent = -1;
        while (status.state != NetworkState.ready) {
          expect(status.state, isNot(NetworkState.failed), reason: status.error);
          expect(clock.elapsed, lessThan(const Duration(minutes: 5)), reason: 'bootstrap ${status.percent}%');
          if (status.percent != percent) {
            percent = status.percent;
            debugPrint('arti: bootstrap $percent% after ${clock.elapsed}');
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
          status = celautNetworkStatus();
        }
        debugPrint('arti: ready after ${clock.elapsed} (${Platform.version.split(' on ').last})');
      } finally {
        await celautSetNetwork(choice: NetworkChoice.off, dataDir: data.path);
      }
    },
    skip: !const bool.fromEnvironment('SUPERAPP_TEST_TOR'),
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// A PNG of a QR code of [text], dark on white with a quiet zone, as a screenshot has it.
/// With no text, the image is white.
Future<String> _qrImage(String? text, String path) async {
  const size = 400.0;
  const margin = 40.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, size + 2 * margin, size + 2 * margin), Paint()..color = Colors.white);
  canvas.translate(margin, margin);
  if (text != null) {
    QrPainter(data: text, version: QrVersions.auto, gapless: true).paint(canvas, const Size(size, size));
  }
  final image = await recorder.endRecording().toImage((size + 2 * margin).toInt(), (size + 2 * margin).toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
  return path;
}
