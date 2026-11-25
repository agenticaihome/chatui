import 'package:argus_wallet/services/linux_app.dart';
import 'package:argus_wallet/services/wallet_service.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.argus.wallet/secure_storage');

// The settings are in three sections: Ergo, Compute and General (Josemi, 2026-10-23).

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void listWallets(WidgetTester tester, List<String> ids) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => call.method == 'listWalletIds' ? ids : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null),
    );
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: argusTheme(watchful: false), home: home));
    await tester.pumpAndSettle();
  }

  /// The titles of the rows of a section, in order.
  List<String> rowsOf(WidgetTester tester, String section) => [
        for (final row in tester.widgetList<Text>(
          find.descendant(of: find.byKey(Key('settings-section-$section')), matching: find.byType(Text)),
        ))
          ?row.data,
      ];

  testWidgets('the sections are Ergo, Compute and General, in this order', (tester) async {
    listWallets(tester, const []);
    await pump(tester, const SettingsScreen());
    final ergo = tester.getTopLeft(find.byKey(const Key('settings-section-ergo'))).dy;
    final compute = tester.getTopLeft(find.byKey(const Key('settings-section-compute'))).dy;
    final general = tester.getTopLeft(find.byKey(const Key('settings-section-general'))).dy;
    expect(ergo, lessThan(compute));
    expect(compute, lessThan(general));
    expect(find.text('ERGO'), findsOneWidget);
    expect(find.text('COMPUTE'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    // No other group: everything is in one of the three.
    expect(find.text('DEVELOPER'), findsNothing);
    expect(find.text('APP'), findsNothing);
  });

  testWidgets('each setting is in its section', (tester) async {
    listWallets(tester, const ['hub-wallet']);
    await tester.runAsync(
      () => walletService.saveWalletInfo('hub-wallet', name: 'Savings', createdAt: DateTime(2026)),
    );
    await pump(tester, const SettingsScreen());
    final ergo = rowsOf(tester, 'ergo');
    for (final text in ['Addresses and backup', 'Network', 'Address book', 'Remote previews']) {
      expect(ergo, contains(text), reason: text);
    }
    final compute = rowsOf(tester, 'compute');
    for (final text in ['Nodes', 'Celaut deposit', 'Tor', 'Environment variables', 'Celaut Registry', 'Celaut node', 'Celaut service']) {
      expect(compute, contains(text), reason: text);
    }
    final general = rowsOf(tester, 'general');
    for (final text in ['Security', 'Display', 'Chats home', 'About Celaut']) {
      expect(general, contains(text), reason: text);
    }
    // The one wallet has no name.
    expect(find.text('Savings'), findsNothing);
  });

  testWidgets('without a wallet, Ergo has no wallet row and Security is app-wide', (tester) async {
    listWallets(tester, const []);
    await pump(tester, const SettingsScreen());
    expect(find.byKey(const Key('settings-wallet')), findsNothing);
    expect(find.text('Auto-lock, screenshots, unconfirmed funds'), findsOneWidget);
    for (final text in ['Manage', 'Watch-only', 'No wallet selected', 'Offline signing', 'All wallets']) {
      expect(find.text(text), findsNothing, reason: text);
    }
  });

  testWidgets('on Linux, the Security row does not promise screenshot blocking', (tester) async {
    debugLinuxAppOverride = true;
    addTearDown(() => debugLinuxAppOverride = null);
    listWallets(tester, const []);
    await pump(tester, const SettingsScreen());
    expect(find.text('Auto-lock, unconfirmed funds'), findsOneWidget);
    expect(find.textContaining('screenshots'), findsNothing);
  });

  testWidgets('the page of the wallet shows the same sections', (tester) async {
    listWallets(tester, const ['hub-wallet']);
    await tester.runAsync(
      () => walletService.saveWalletInfo('hub-wallet', name: 'Savings', createdAt: DateTime(2026)),
    );
    await pump(tester, const SettingsScreen(walletId: 'hub-wallet', embedded: true));
    expect(find.byKey(const Key('settings-wallet')), findsOneWidget);
    expect(find.byKey(const Key('settings-section-compute')), findsOneWidget);
    expect(find.text('Device unlock, auto-lock'), findsOneWidget);
    expect(find.textContaining('on this device'), findsNothing);
  });
}
