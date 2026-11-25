import 'package:argus_wallet/celaut/auto_top_up.dart';
import 'package:argus_wallet/l10n/app_localizations.dart';
import 'package:argus_wallet/services/linux_app.dart';
import 'package:argus_wallet/ui/celaut/auto_top_up_screen.dart';
import 'package:argus_wallet/ui/ios_limits.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

/// A button that shows the warnings once, as the start of the app does.
class _Starter extends StatelessWidget {
  const _Starter();

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: TextButton(onPressed: () => showIosLimitsOnce(context), child: const Text('start')));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('iOS: the full set of warnings shows at the first start only', (tester) async {
    await tester.pumpWidget(_app(const _Starter()));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ios-limits')), findsOneWidget);
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.iosLimitsConversations), findsOneWidget);
    expect(find.text(l.iosLimitsNotifications), findsOneWidget);
    expect(find.text(l.iosLimitsTopUp), findsOneWidget);
    await tester.tap(find.byKey(const Key('ios-limits-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ios-limits')), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool(iosLimitsSeenKey), isTrue);

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ios-limits')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: no warning', (tester) async {
    await tester.pumpWidget(_app(const _Starter()));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ios-limits')), findsNothing);
    await tester.pumpWidget(_app(const Scaffold(body: TopUpWarning())));
    expect(find.byKey(const Key('ios-top-up-warning')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Spanish texts', (tester) async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    expect(es.iosLimitsTopUp, contains('Mantener en marcha'));
    expect(es.iosLimitsOk, 'Entendido');
  });

  testWidgets('Keep running settings: the top-up warning on iOS and on macOS, each with its text', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(AutoTopUpScreen(topUp: AutoTopUp(periodic: false))));
    await tester.pumpAndSettle();
    final platform = defaultTargetPlatform;
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const Key('ios-top-up-warning')), platform == TargetPlatform.iOS ? findsOneWidget : findsNothing);
    expect(find.byKey(const Key('mac-top-up-warning')), platform == TargetPlatform.macOS ? findsOneWidget : findsNothing);
    expect(find.text(l.iosLimitsTopUp), platform == TargetPlatform.iOS ? findsOneWidget : findsNothing);
    expect(find.text(l.celautKeepMacNote), platform == TargetPlatform.macOS ? findsOneWidget : findsNothing);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.android}));

  testWidgets('Keep running settings: the Linux app shows its own top-up warning', (tester) async {
    debugLinuxAppOverride = true;
    addTearDown(() => debugLinuxAppOverride = null);
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(AutoTopUpScreen(topUp: AutoTopUp(periodic: false))));
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const Key('linux-top-up-warning')), findsOneWidget);
    expect(find.text(l.celautKeepLinuxNote), findsOneWidget);
    expect(find.text(l.celautKeepMacNote), findsNothing);
    expect(find.text(l.iosLimitsTopUp), findsNothing);
  });
}
