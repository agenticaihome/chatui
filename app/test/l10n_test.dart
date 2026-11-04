import 'dart:convert';
import 'dart:io';

import 'package:argus_wallet/format.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// The placeholder names of an ICU message: "{name}", and the variable of
/// "{count, plural, …}" or "{kind, select, …}".
Set<String> _placeholders(String message) {
  final names = <String>{};
  var depth = 0;
  for (var i = 0; i < message.length; i++) {
    final c = message[i];
    if (c == '{') {
      depth++;
      // A plural or select branch, as in "=1{…}" or "other{…}".
      if (i > 0 && RegExp(r'[\w=]').hasMatch(message[i - 1])) continue;
      final m = RegExp(r'^\{\s*(\w+)\s*[,}]').firstMatch(message.substring(i));
      if (m != null) names.add(m.group(1)!);
    } else if (c == '}') {
      depth--;
    }
  }
  expect(depth, 0, reason: 'unbalanced braces in "$message"');
  return names;
}

void main() {
  final en = _arb('en');
  final es = _arb('es');

  test('Spanish has every English key and no other', () {
    final enKeys = _messageKeys(en);
    final esKeys = _messageKeys(es);
    expect(enKeys.difference(esKeys), isEmpty, reason: 'missing in app_es.arb');
    expect(esKeys.difference(enKeys), isEmpty, reason: 'not in app_en.arb');
  });

  test('no message is empty', () {
    for (final arb in [en, es]) {
      for (final k in _messageKeys(arb)) {
        expect((arb[k] as String).trim(), isNotEmpty, reason: k);
      }
    }
  });

  test('Spanish is not English copied over', () {
    // Names, units and figures that read the same in both languages.
    const same = {
      'appTitle', 'commonToken', 'commonTokens', 'dateDayMonthYear',
      'celautCpuLabel', 'settingsErgoGroup', 'settingsGeneralGroup', 'updateCardVersion',
      'updateCardVersionDate', 'utxoTokenCount', 'rentWhenMonthYear',
      'priceAgeMinutes', 'priceAgeHours', 'nftKindAudio', 'nftKindVideo',
      'dashboardStartupError', 'homeTokenCount', 'homeSpokenIncl', 'txIdLabel',
      'holdingsTokenCount', 'sendTokenFallback', 'sendPlusTokens',
      'sendBoxTokens', 'utxoTokensN', 'utxoValueTokens', 'utxoFilterTokens',
      'separateSourceItem', 'homePartsWhere', 'homeInclPartsWhere',
      'celautHomeUsd', 'celautAgoSeconds', 'celautAgoMinutes', 'celautAgoHours',
      'celautAgoDays', 'chatsTabChats', 'chatsPreviewAudio', 'chatsPreviewNamed',
      'chatSettingsTitle', 'chatFontLato', 'chatFontSerif', 'chatSettingsWidgetsGroup',
      'themeCyberpunkName', 'themeNordName', 'themeSolarizedName',
      'btcTitle', 'btcRowTotal', 'btcErrOther',
    };
    final copied = [
      for (final k in _messageKeys(en))
        if (es[k] == en[k] && !same.contains(k)) k,
    ];
    expect(copied, isEmpty, reason: 'translate these in app_es.arb');
  });

  test('every placeholder is declared, and Spanish uses no other', () {
    for (final k in _messageKeys(en)) {
      final declared = ((en['@$k'] as Map<String, dynamic>?)?['placeholders']
                  as Map<String, dynamic>?)
              ?.keys
              .toSet() ??
          <String>{};
      final inEn = _placeholders(en[k] as String);
      final inEs = _placeholders(es[k] as String);
      expect(inEn.difference(declared), isEmpty, reason: '$k (en)');
      expect(inEs.difference(declared), isEmpty, reason: '$k (es)');
    }
  });

  test('the app has English and Spanish', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      containsAll(['en', 'es']),
    );
  });

  group('appL10n', () {
    tearDown(() => setAppLocale(const Locale('en')));

    test('follows the locale, and falls back to English', () {
      setAppLocale(const Locale('es'));
      expect(appL10n.localeName, 'es');
      setAppLocale(const Locale('es', 'MX'));
      expect(appL10n.localeName, 'es');
      setAppLocale(const Locale('fr'));
      expect(appL10n.localeName, 'en');
    });

    test('formats times and dates in Spanish', () {
      setAppLocale(const Locale('es'));
      final now = DateTime(2026, 10, 12, 15);
      expect(clockTime(DateTime(2026, 10, 12, 22, 8)), '22:08');
      expect(monthShort(10), 'oct');
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        'hace 5 min',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 1)), now: now),
        'Ayer',
      );
      expect(formatRelativeTime(DateTime(2026, 9, 1), now: now), '1/9/2026');
    });
  });
}
