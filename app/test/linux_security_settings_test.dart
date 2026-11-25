import 'package:argus_wallet/services/linux_app.dart';
import 'package:argus_wallet/ui/settings/security_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Security settings on Linux (#156): X11 and Wayland cannot keep a window out of a
/// screenshot, so "Block screenshots" is not offered there, and the wallet unlocks with
/// the login keyring instead of a fingerprint or a screen lock.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugLinuxAppOverride = null);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SecuritySettingsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('Android shows "Block screenshots" and the screen lock', (tester) async {
    debugLinuxAppOverride = false;
    await open(tester);
    expect(find.text('Block screenshots'), findsOneWidget);
    expect(find.textContaining('always block capture'), findsOneWidget);
    expect(find.text('Fingerprint or screen lock'), findsOneWidget);
    expect(find.textContaining('login keyring'), findsNothing);
  });

  testWidgets('Linux hides "Block screenshots" and names the login keyring', (tester) async {
    debugLinuxAppOverride = true;
    await open(tester);
    expect(find.text('Block screenshots'), findsNothing);
    expect(find.text('Screen'), findsNothing);
    expect(find.textContaining('always block capture'), findsNothing);
    expect(find.byType(Switch), findsOneWidget, reason: 'only "Spend unconfirmed funds" is left');
    expect(find.text('Login keyring of the desktop'), findsOneWidget);
    expect(find.textContaining('which the desktop unlocks when you log in'), findsOneWidget);
    expect(find.text('Fingerprint or screen lock'), findsNothing);
  });
}
