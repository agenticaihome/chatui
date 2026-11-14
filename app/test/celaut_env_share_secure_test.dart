import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/celaut/env_share.dart';
import 'package:argus_wallet/celaut/env_store.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/services/privacy_service.dart';
import 'package:argus_wallet/ui/celaut/env_questions_screen.dart';
import 'package:argus_wallet/ui/celaut/env_variables_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #141: the screen that shows the QR code of a variable is secure (FLAG_SECURE)
/// while it is open, whatever the setting "Block screenshots" says. So is a sensitive value
/// shown in clear with the eye (the add/edit form, "Type a value", a scanned value).

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

  /// The values of `setSecureFlag`, in order, and whether the code (or the value 'secret' in
  /// clear) was on screen at each call.
  late List<bool> flags;
  late List<bool> codeShown;
  late List<bool> valueShown;
  late bool phoneCanSecure;

  bool secretInClear() => find.byType(EditableText).evaluate().any((e) {
        final w = e.widget as EditableText;
        return !w.obscureText && w.controller.text == 'secret';
      });

  setUp(() {
    flags = [];
    codeShown = [];
    valueShown = [];
    phoneCanSecure = true;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method != 'setSecureFlag') return null;
      flags.add((call.arguments as Map)['enable'] as bool);
      codeShown.add(find.byKey(const Key('env-share-qr')).evaluate().isNotEmpty);
      valueShown.add(secretInClear());
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
  group('a sensitive value shown in clear', () {
    Future<void> tap(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    bool obscured(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).obscureText;

    testWidgets('the edit form: the eye sets the flag before the value is drawn, hiding gives it back', (tester) async {
      privacyService.blockScreenshots = false;
      await tester.pumpWidget(_app(EnvVariablesScreen(store: _store({'KEY': 'secret'}))));
      await tap(tester, 'env-row-KEY');
      expect(flags, isEmpty, reason: 'a hidden value does not touch the flag');
      await tap(tester, 'env-eye');
      expect(obscured(tester, 'env-value'), isFalse);
      expect(flags, [true]);
      expect(valueShown, [false], reason: 'secure before the value is drawn');
      expect(find.byKey(const Key('env-value-not-secure')), findsNothing);
      await tap(tester, 'env-eye');
      expect(obscured(tester, 'env-value'), isTrue);
      expect(flags, [true, false]);
    });

    testWidgets('the edit form: closing it with the value shown gives the flag back', (tester) async {
      privacyService.blockScreenshots = false;
      await tester.pumpWidget(_app(EnvVariablesScreen(store: _store({'KEY': 'secret'}))));
      await tap(tester, 'env-row-KEY');
      await tap(tester, 'env-eye');
      await tap(tester, 'env-save');
      expect(find.byKey(const Key('env-edit')), findsNothing);
      expect(flags, [true, false]);
    });

    testWidgets('the edit form with screenshots blocked: the window stays secure', (tester) async {
      privacyService.blockScreenshots = true;
      await tester.pumpWidget(_app(EnvVariablesScreen(store: _store({'KEY': 'secret'}))));
      await tap(tester, 'env-row-KEY');
      await tap(tester, 'env-eye');
      await tap(tester, 'env-eye');
      expect(flags, [true, true]);
    });

    testWidgets('a value that is not sensitive follows the setting; the mark turns the hold on and off', (tester) async {
      privacyService.blockScreenshots = false;
      await tester.pumpWidget(_app(EnvVariablesScreen(store: _store({}))));
      await tap(tester, 'env-add');
      await tester.enterText(find.byKey(const Key('env-name')), 'MODE');
      await tester.enterText(find.byKey(const Key('env-value')), 'secret');
      // A new variable is sensitive: turn the mark off, then show the value.
      await tap(tester, 'env-edit-sensitive');
      await tap(tester, 'env-eye');
      expect(obscured(tester, 'env-value'), isFalse);
      expect(flags, isEmpty);
      // Marked sensitive while it is shown: the window becomes secure.
      await tap(tester, 'env-edit-sensitive');
      expect(flags, [true]);
      // Not sensitive again: back to the setting, the value stays shown.
      await tap(tester, 'env-edit-sensitive');
      expect(flags, [true, false]);
      expect(obscured(tester, 'env-value'), isFalse);
    });

    testWidgets('a scanned value in the form of the container holds the flag when shown', (tester) async {
      privacyService.blockScreenshots = false;
      await tester.pumpWidget(_app(EnvVariablesScreen(
        store: _store({}),
        scanner: (_) async => const EnvShare(name: 'TOKEN', value: 'secret', sensitive: true),
      )));
      await tap(tester, 'env-scan');
      expect(obscured(tester, 'env-value'), isTrue);
      expect(flags, isEmpty);
      await tap(tester, 'env-eye');
      expect(flags, [true]);
      expect(valueShown, [false]);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(flags, [true, false]);
    });

    Widget questions({Future<EnvShare?> Function(BuildContext)? scanner}) => EnvQuestionsScreen(
          declared: const [
            DeclaredVariableView(name: 'API_KEY', tags: [], prose: ''),
            DeclaredVariableView(name: 'MODE', tags: [], prose: ''),
          ],
          store: _store({}),
          scanner: scanner,
        );

    testWidgets('"Type a value": sensitive and shown holds the flag; the next variable gives it back', (tester) async {
      privacyService.blockScreenshots = false;
      await tester.pumpWidget(_app(questions()));
      await tap(tester, 'env-ask-type');
      await tester.enterText(find.byKey(const Key('env-typed')), 'secret');
      // A typed value is not sensitive by default: the eye does not touch the flag.
      await tap(tester, 'env-typed-eye');
      expect(obscured(tester, 'env-typed'), isFalse);
      expect(flags, isEmpty);
      await tap(tester, 'env-typed-eye');
      await tap(tester, 'env-typed-sensitive');
      expect(flags, isEmpty, reason: 'hidden');
      await tap(tester, 'env-typed-eye');
      expect(flags, [true]);
      expect(valueShown, [false]);
      await tap(tester, 'env-typed-use');
      expect(find.text('Variable 2 of 2'), findsOneWidget);
      expect(flags, [true, false]);
    });

    testWidgets('a scanned sensitive value in a launch: shown only once secure, cancel gives it back', (tester) async {
      privacyService.blockScreenshots = false;
      await tester.pumpWidget(_app(questions(
        scanner: (_) async => const EnvShare(name: 'API_KEY', value: 'secret', sensitive: true),
      )));
      await tap(tester, 'env-ask-scan');
      expect(obscured(tester, 'env-typed'), isTrue);
      await tap(tester, 'env-typed-eye');
      expect(flags, [true]);
      expect(valueShown, [false]);
      await tap(tester, 'env-cancel');
      expect(find.byType(EnvQuestionsScreen), findsNothing);
      expect(flags, [true, false]);
    });

    testWidgets('a phone that cannot block screenshots: the value is shown with the red line', (tester) async {
      privacyService.blockScreenshots = false;
      phoneCanSecure = false;
      await tester.pumpWidget(_app(EnvVariablesScreen(store: _store({'KEY': 'secret'}))));
      await tap(tester, 'env-row-KEY');
      await tap(tester, 'env-eye');
      expect(obscured(tester, 'env-value'), isFalse);
      expect(find.byKey(const Key('env-value-not-secure')), findsOneWidget);
      await tap(tester, 'env-eye');
      expect(find.byKey(const Key('env-value-not-secure')), findsNothing);
    });

    testWidgets('"Type a value" on a phone that cannot block screenshots shows the red line too', (tester) async {
      privacyService.blockScreenshots = false;
      phoneCanSecure = false;
      await tester.pumpWidget(_app(questions(
        scanner: (_) async => const EnvShare(name: 'API_KEY', value: 'secret', sensitive: true),
      )));
      await tap(tester, 'env-ask-scan');
      await tap(tester, 'env-typed-eye');
      expect(obscured(tester, 'env-typed'), isFalse);
      expect(find.byKey(const Key('env-typed-not-secure')), findsOneWidget);
    });

    test('SecureHold takes one hold at a time and gives it back on dispose', () async {
      final svc = PrivacyService()..blockScreenshots = false;
      final a = SecureHold(svc);
      final b = SecureHold(svc);
      await a.set(true);
      await a.set(true);
      await b.set(true);
      await a.set(false);
      expect(flags.last, isTrue, reason: 'b still holds');
      b.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(flags.last, isFalse);
      expect(flags, [true, true, true, false]);
    });
  });
}
