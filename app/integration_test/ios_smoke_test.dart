// The app on the iOS simulator (CI job `ios-simulator`, docs/ios.md): it starts, the home
// screen and the iOS warnings show at the first start, and the Rust core loads (the bridge
// finds its functions in the process) and opens the Celaut database with its key in the
// Keychain.
//
//   cd app && flutter test integration_test/ios_smoke_test.dart -d <simulator id>

import 'dart:io';

import 'package:argus_wallet/bridge/api/celaut_network.dart';
import 'package:argus_wallet/main.dart' as app;
import 'package:argus_wallet/services/secure_storage.dart';
import 'package:argus_wallet/ui/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('starts on iOS with its warnings and its Rust core', (tester) async {
    expect(Platform.isIOS, isTrue);

    Future<void> waitFor(String what, bool Function() done, {Duration timeout = const Duration(seconds: 90)}) async {
      final end = DateTime.now().add(timeout);
      while (!done()) {
        if (DateTime.now().isAfter(end)) throw TestFailure('Not seen in $timeout: $what');
        await tester.pump(const Duration(milliseconds: 200));
      }
      debugPrint('IOS_SMOKE seen: $what');
    }

    await app.main();
    await waitFor('the home screen', () => find.byType(DashboardScreen).evaluate().isNotEmpty);
    await waitFor('the iOS warnings', () => find.byKey(const Key('ios-limits')).evaluate().isNotEmpty);
    await tester.tap(find.byKey(const Key('ios-limits-ok')));
    await waitFor('the warnings closed', () => find.byKey(const Key('ios-limits')).evaluate().isEmpty);

    // The home screen starts the wallet service: initRustLib (the bridge in the process),
    // then the Celaut database.
    Object? rustError;
    bool rustReady() {
      try {
        celautNetworkStatus();
        return true;
      } on Object catch (e) {
        rustError = e;
        return false;
      }
    }

    try {
      await waitFor('the Rust core', rustReady);
    } on TestFailure catch (e) {
      throw TestFailure('${e.message} (the last error: $rustError)');
    }
    debugPrint('IOS_SMOKE network route: ${celautNetworkStatus().state.name}');

    final path = await SecureStorageService.celautDbPath();
    expect(path, isNotNull);
    await waitFor('the Celaut database file', () => File(path!).existsSync());
    final key = await SecureStorageService.loadCelautDbKey();
    expect(key, isNotNull, reason: 'the key of the database is in the Keychain');
    debugPrint('IOS_SMOKE Celaut database: ${File(path!).lengthSync()} bytes, key ${key!.length} chars');
  });
}
