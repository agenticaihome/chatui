import 'dart:convert';

import 'env_store.dart';

/// One environment variable that a friend shares by a QR code (`docs/celaut/env-share.md`).
///
/// The code holds the name, the value in plain text and the mark "sensitive". The receiving
/// phone uses it to fill the form of a variable: the name is a suggestion, and the user can
/// keep it or change it before the variable is saved. A QR code is for people who are
/// together, so there is no key: the user is told that whoever reads the code reads the value.
class EnvShare {
  const EnvShare({required this.name, required this.value, required this.sensitive});

  final String name;
  final String value;
  final bool sensitive;

  /// The marker of the format. A code that does not begin so is not a variable.
  static const _prefix = '{"chatui_env":1,';

  /// The most bytes of text that the QR code carries. The largest QR (version 40) holds
  /// 2331 bytes with the medium error correction that the screen uses; the rest is margin.
  static const maxPayloadBytes = 2000;

  /// The text of the QR code.
  String encode() => jsonEncode({'chatui_env': 1, 'n': name, 'v': value, 's': sensitive});

  /// True if the QR code of this variable fits in [maxPayloadBytes].
  bool get fits => utf8.encode(encode()).length <= maxPayloadBytes;

  /// The variable of a scanned [text], or null if the text is not a valid shared variable:
  /// not of this format, a name or a value that the node refuses, or a field of the wrong
  /// type. The text of a code is not trusted.
  static EnvShare? tryParse(String? text) {
    if (text == null || !text.startsWith(_prefix) || utf8.encode(text).length > maxPayloadBytes) return null;
    try {
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic>) return null;
      final name = j['n'];
      final value = j['v'];
      final sensitive = j['s'];
      if (name is! String || value is! String || sensitive is! bool) return null;
      if (envNameProblem(name) != null || envValueProblem(value) != null) return null;
      return EnvShare(name: name, value: value, sensitive: sensitive);
    } catch (_) {
      return null;
    }
  }
}
