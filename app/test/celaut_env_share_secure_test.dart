import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/celaut/env_store.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/services/privacy_service.dart';
import 'package:argus_wallet/ui/celaut/env_questions_screen.dart';
import 'package:argus_wallet/ui/celaut/env_variables_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #141: the screen that shows the QR code of a variable is secure (FLAG_SECURE)
/// while it is open, whatever the setting "Block screenshots" says.

const _channel = MethodChannel('com.argus.wallet/secure_storage');

EnvStore _store(Map<String, String> values) => EnvStore(
      names: () => [
        for (final n in values.keys.toList()..sort()) EnvNameView(name: n, changedAt: 1, sensitive: true),
      ],
      get: (n) => values[n],
      set: (n, v, s) => values[n] = v,
      setSensitive: (n, s) {},
      delete: (n) => values.remove(n),
    );

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// The values of `setSecureFlag`, in order, and whether the code was on screen at each call.
  late List<bool> flags;
  late List<bool> codeShown;
  late bool phoneCanSecure;

  setUp(() {
    flags = [];
    codeShown = [];
    phoneCanSecure = true;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method != 'setSecureFlag') return null;
      flags.add((call.arguments as Map)['enable'] as bool);
      codeShown.add(find.byKey(const Key('env-share-qr')).evaluate().isNotEmpty);
      return phoneCanSecure;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    privacyService.blockScreenshots = true;
  });

  Future<void> openAndClose(WidgetTester tester, Widget screen, List<Key> taps) async {
    await tester.pumpWidget(_app(screen));
    for (final key in taps) {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('env-share-qr')), findsOneWidget);
    // Secure before the code is drawn, and still secure while it is open.
    expect(flags, [true]);
    expect(codeShown, [false]);
    await tester.tap(find.byKey(const Key('env-share-done')));
    await tester.pumpAndSettle();
  }

  testWidgets('screenshots allowed: the code screen is secure, then the setting comes back', (tester) async {
    privacyService.blockScreenshots = false;
    await openAndClose(tester, EnvVariablesScreen(store: _store({'KEY': 'secret'})), const [Key('env-share-KEY')]);
    expect(find.byKey(const Key('env-share-not-secure')), findsNothing);
    expect(flags, [true, false]);
  });

  testWidgets('screenshots blocked: the window stays secure after the code screen', (tester) async {
    privacyService.blockScreenshots = true;
    await openAndClose(tester, EnvVariablesScreen(store: _store({'KEY': 'secret'})), const [Key('env-share-KEY')]);
    expect(flags, [true, true]);
  });

  testWidgets('the share in the questions of a launch is secure too', (tester) async {
    privacyService.blockScreenshots = false;
    await openAndClose(
      tester,
      EnvQuestionsScreen(
        declared: const [DeclaredVariableView(name: 'API_KEY', tags: [], prose: '')],
        store: _store({'API_KEY': 'secret'}),
      ),
      const [Key('env-ask-pick'), Key('env-pick-share-API_KEY')],
    );
    expect(flags, [true, false]);
  });

  testWidgets('a phone that cannot block screenshots: the dialog says so', (tester) async {
    privacyService.blockScreenshots = false;
    phoneCanSecure = false;
    await tester.pumpWidget(_app(EnvVariablesScreen(store: _store({'KEY': 'secret'}))));
    await tester.tap(find.byKey(const Key('env-share-KEY')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('env-share-not-secure')), findsOneWidget);
    await tester.tap(find.byKey(const Key('env-share-done')));
    await tester.pumpAndSettle();
    expect(flags.last, isFalse);
  });

  testWidgets('closed by the back button: the setting comes back', (tester) async {
    privacyService.blockScreenshots = false;
    await tester.pumpWidget(_app(EnvVariablesScreen(store: _store({'KEY': 'secret'}))));
    await tester.tap(find.byKey(const Key('env-share-KEY')));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('env-share')), findsNothing);
    expect(flags, [true, false]);
  });

  group('holds', () {
    test('the window stays secure until the last hold ends', () async {
      final svc = PrivacyService()..blockScreenshots = false;
      expect(await svc.holdSecure(), isTrue);
      expect(await svc.holdSecure(), isTrue);
      await svc.releaseSecure();
      expect(flags.last, isTrue);
      await svc.releaseSecure();
      expect(flags.last, isFalse);
      // An extra release does nothing wrong.
      await svc.releaseSecure();
      expect(flags.last, isFalse);
    });

    test('turning the setting off while a code is shown keeps the window secure', () async {
      final svc = PrivacyService()..blockScreenshots = true;
      await svc.holdSecure();
      await svc.applyScreenshotPolicy();
      expect(flags.last, isTrue);
      svc.blockScreenshots = false;
      await svc.applyScreenshotPolicy();
      expect(flags.last, isTrue);
      await svc.releaseSecure();
      expect(flags.last, isFalse);
    });
  });
}
