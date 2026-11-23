import 'package:argus_wallet/celaut/chat_backgrounds.dart';
import 'package:argus_wallet/celaut/chat_groups.dart';
import 'package:argus_wallet/celaut/chat_prefs.dart';
import 'package:argus_wallet/ui/settings/chat_settings_page.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:argus_wallet/l10n/l10n.dart';

void main() {
  test('defaults and persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final p = ChatPrefs();
    await p.load();
    expect(p.fontSize, 17);
    expect(p.pinnedMaxFraction, 0.25);
    expect(p.htmlWidgets, isTrue);
    expect(p.systemKeyboard, isFalse);
    expect(p.background('a'), 'none');
    await p.setFontSize(21);
    await p.setPinnedMaxFraction(0.9);
    await p.setMuted('a', true);
    await p.setBackground('a', 'dawn');
    await p.setHtmlWidgets(false);
    await p.setSystemKeyboard(true);
    final q = ChatPrefs();
    await q.load();
    expect(q.fontSize, 21);
    expect(q.pinnedMaxFraction, 0.5);
    expect(q.isMuted('a'), isTrue);
    expect(q.isMuted('b'), isFalse);
    expect(q.background('a'), 'dawn');
    expect(q.htmlWidgets, isFalse);
    expect(q.systemKeyboard, isTrue);
    await q.setBackground('a', 'none');
    expect(q.background('a'), 'none');
  });

  test('every background has a unique id and paints', () {
    final ids = chatBackgrounds.map((b) => b.id).toSet();
    expect(ids.length, chatBackgrounds.length);
    expect(chatBackgrounds.length, inInclusiveRange(6, 9));
    for (final b in chatBackgrounds) {
      for (final dark in [false, true]) {
        b.paint(Canvas(PictureRecorder()), const Size(200, 300), dark);
      }
    }
  });

  testWidgets('settings page changes the prefs', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await chatPrefs.load();
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChatSettingsPage(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-settings-html')));
    await tester.pumpAndSettle();
    expect(chatPrefs.htmlWidgets, isFalse);
    await tester.tap(find.byKey(const Key('chat-settings-system-keyboard')));
    await tester.pumpAndSettle();
    expect(chatPrefs.systemKeyboard, isTrue);
    await tester.tap(find.text('Serif'));
    await tester.pumpAndSettle();
    expect(chatPrefs.fontFamily, 'serif');
    expect(chatGroups.grouped, isFalse);
    await tester.tap(find.byKey(const Key('chat-settings-grouped')));
    await tester.pumpAndSettle();
    expect(chatGroups.grouped, isTrue);
    await chatGroups.setGrouped(false);
  });
}
