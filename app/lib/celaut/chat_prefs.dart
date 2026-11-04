import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/argus_theme.dart';

/// Chat display preferences. App-wide values (text size and font, pinned
/// height, HTML widgets, keyboard) and per-instance values (mute, background).
/// Stored in SharedPreferences. A failed read or write keeps the value in
/// memory only.
class ChatPrefs extends ChangeNotifier {
  static const _sizeKey = 'chat_font_size';
  static const _familyKey = 'chat_font_family';
  static const _pinnedKey = 'chat_pinned_max_fraction';
  static const _htmlKey = 'chat_html_widgets';
  static const _systemKeyboardKey = 'chat_system_keyboard';
  static const _suggestionsKey = 'chat_word_suggestions';
  static const _mutedKey = 'chat_muted_instances';
  static const _bgPrefix = 'chat_background_';

  static const double defaultFontSize = 17;
  static const double minFontSize = 13;
  static const double maxFontSize = 26;
  static const double defaultPinnedMaxFraction = 0.25;
  static const double minPinnedMaxFraction = 0.1;
  static const double maxPinnedMaxFraction = 0.5;
  static const fontFamilies = ['system', 'lato', 'serif', 'mono'];

  double fontSize = defaultFontSize;
  String fontFamily = 'system';
  double pinnedMaxFraction = defaultPinnedMaxFraction;
  bool htmlWidgets = true;

  /// The chat types with the keyboard of the system. Off: with the keyboard of the app.
  bool systemKeyboard = false;

  /// The keyboard of the app proposes words while the user writes (the corrector,
  /// `docs/celaut/chat.md`, section 5.7). The suggestions of the service show either way.
  bool wordSuggestions = true;
  final Set<String> _muted = {};
  final Map<String, String> _backgrounds = {};

  /// Text scale relative to the default size.
  double get fontScale => fontSize / defaultFontSize;

  /// The Flutter family name for [fontFamily]; null means the theme default.
  String? get fontFamilyName => switch (fontFamily) {
        'lato' => bodyFont,
        'serif' => 'serif',
        'mono' => 'IBMPlexMono',
        _ => null,
      };

  /// Base style for chat text, from the size and the font.
  TextStyle get textStyle => TextStyle(fontSize: fontSize, fontFamily: fontFamilyName, height: 1.4);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      fontSize = (p.getDouble(_sizeKey) ?? defaultFontSize).clamp(minFontSize, maxFontSize).toDouble();
      final f = p.getString(_familyKey);
      fontFamily = fontFamilies.contains(f) ? f! : 'system';
      pinnedMaxFraction = (p.getDouble(_pinnedKey) ?? defaultPinnedMaxFraction)
          .clamp(minPinnedMaxFraction, maxPinnedMaxFraction)
          .toDouble();
      htmlWidgets = p.getBool(_htmlKey) ?? true;
      systemKeyboard = p.getBool(_systemKeyboardKey) ?? false;
      wordSuggestions = p.getBool(_suggestionsKey) ?? true;
      _muted
        ..clear()
        ..addAll(p.getStringList(_mutedKey) ?? const []);
      _backgrounds.clear();
      for (final k in p.getKeys()) {
        if (!k.startsWith(_bgPrefix)) continue;
        final v = p.getString(k);
        if (v != null) _backgrounds[k.substring(_bgPrefix.length)] = v;
      }
    } catch (_) {
      // Keep the defaults.
    }
    notifyListeners();
  }

  Future<void> _save(Future<void> Function(SharedPreferences p) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Memory-only for this run.
    }
  }

  Future<void> setFontSize(double v) async {
    fontSize = v.clamp(minFontSize, maxFontSize).toDouble();
    notifyListeners();
    await _save((p) => p.setDouble(_sizeKey, fontSize));
  }

  Future<void> setFontFamily(String v) async {
    if (!fontFamilies.contains(v)) return;
    fontFamily = v;
    notifyListeners();
    await _save((p) => p.setString(_familyKey, v));
  }

  Future<void> setPinnedMaxFraction(double v) async {
    pinnedMaxFraction = v.clamp(minPinnedMaxFraction, maxPinnedMaxFraction).toDouble();
    notifyListeners();
    await _save((p) => p.setDouble(_pinnedKey, pinnedMaxFraction));
  }

  Future<void> setHtmlWidgets(bool v) async {
    htmlWidgets = v;
    notifyListeners();
    await _save((p) => p.setBool(_htmlKey, v));
  }

  Future<void> setSystemKeyboard(bool v) async {
    systemKeyboard = v;
    notifyListeners();
    await _save((p) => p.setBool(_systemKeyboardKey, v));
  }

  Future<void> setWordSuggestions(bool v) async {
    wordSuggestions = v;
    notifyListeners();
    await _save((p) => p.setBool(_suggestionsKey, v));
  }

  bool isMuted(String instanceId) => _muted.contains(instanceId);

  Future<void> setMuted(String instanceId, bool muted) async {
    if (!(muted ? _muted.add(instanceId) : _muted.remove(instanceId))) return;
    notifyListeners();
    await _save((p) => p.setStringList(_mutedKey, _muted.toList()));
  }

  /// Id of the background of [instanceId]; 'none' if never set.
  String background(String instanceId) => _backgrounds[instanceId] ?? 'none';

  Future<void> setBackground(String instanceId, String bg) async {
    if (bg == 'none') {
      _backgrounds.remove(instanceId);
    } else {
      _backgrounds[instanceId] = bg;
    }
    notifyListeners();
    await _save((p) => bg == 'none' ? p.remove('$_bgPrefix$instanceId') : p.setString('$_bgPrefix$instanceId', bg));
  }
}

final ChatPrefs chatPrefs = ChatPrefs();
