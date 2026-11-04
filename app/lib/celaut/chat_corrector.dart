import 'dart:math' show min;

import 'package:characters/characters.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

/// A word that the corrector changed in the text of a message (`docs/celaut/chat.md`,
/// section 5.7): [original] is what the user wrote, [replacement] what the tap put there.
class Correction {
  const Correction(this.original, this.replacement);

  final String original;
  final String replacement;

  @override
  bool operator ==(Object other) =>
      other is Correction && other.original == original && other.replacement == replacement;

  @override
  int get hashCode => Object.hash(original, replacement);

  @override
  String toString() => '$original→$replacement';
}

/// What a send tells the service of the corrector (`CorrectorState` of `chat.proto`).
class CorrectorReport {
  const CorrectorReport({required this.enabled, this.corrections = const []});

  final bool enabled;
  final List<Correction> corrections;
}

/// The longest word that the corrector knows or proposes, and the most corrections of one
/// send (section 5.7).
const correctorMaxWordChars = 64;
const correctorMaxCorrections = 32;

/// The letters of a word: letters and marks of any script, digits, and the apostrophe
/// inside a word ("don't").
final _wordChar = RegExp(r"[\p{L}\p{M}\p{N}'’]", unicode: true);
final _words = RegExp(r"[\p{L}\p{M}\p{N}]+(?:['’][\p{L}\p{M}\p{N}]+)*", unicode: true);

/// The word that ends at the cursor of [v]: where it starts and ends, and its text. An
/// empty word if the cursor is after a space, at the start, or the selection is not one
/// point.
({int start, int end, String word}) wordAtCursor(TextEditingValue v) {
  final sel = v.selection;
  final at = sel.isValid ? sel.start : v.text.length;
  if (sel.isValid && !sel.isCollapsed) return (start: at, end: at, word: '');
  var start = at;
  while (start > 0 && _wordChar.hasMatch(v.text[start - 1])) {
    start--;
  }
  var end = at;
  while (end < v.text.length && _wordChar.hasMatch(v.text[end])) {
    end++;
  }
  return (start: start, end: end, word: v.text.substring(start, end));
}

/// [v] with the word at its cursor replaced by [word] and a space after it (if the next
/// character is not one already). The cursor goes after the space.
TextEditingValue replaceWordAtCursor(TextEditingValue v, String word) {
  final w = wordAtCursor(v);
  final rest = v.text.substring(w.end);
  final space = rest.startsWith(' ') ? '' : ' ';
  final text = v.text.substring(0, w.start) + word + space + rest;
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: w.start + word.length + 1),
  );
}

/// The corrector of the keyboard of the app (section 5.7, "In chatui"). It knows the words
/// of the conversation and of the suggestions of the service, and for a word that the user
/// writes it proposes words that start with it, then words that are close to it. It has no
/// dictionary, so it never changes a word by itself: the user taps a proposal.
class ChatCorrector {
  /// The most words that it keeps. Past it, a new word is not learned.
  static const maxWords = 5000;

  /// How often each word was seen, by its lower case, and the form that it had the most.
  final Map<String, int> _count = {};
  final Map<String, String> _form = {};

  int get size => _count.length;

  /// Learn the words of [text].
  void learn(String text) {
    for (final m in _words.allMatches(text)) {
      final word = m.group(0)!;
      final n = word.characters.length;
      if (n < 2 || n > correctorMaxWordChars) continue;
      final key = word.toLowerCase();
      final seen = _count[key];
      if (seen == null && _count.length >= maxWords) continue;
      _count[key] = (seen ?? 0) + 1;
      // A word in lower case is the plain form; a capital only if the word never comes
      // without one.
      final form = _form[key];
      if (form == null || (word == key && form != key)) _form[key] = word;
    }
  }

  /// Up to [max] words for [typed]: the words that start with it (the most seen first),
  /// then the words with one change (two for a word of 5 letters or more). Not [typed]
  /// itself. The case follows [typed]: a capital at the start, or all in capitals.
  List<String> candidates(String typed, {int max = 3}) {
    final t = typed.toLowerCase();
    if (t.isEmpty || t.characters.length > correctorMaxWordChars) return const [];
    final starts = <String>[];
    final close = <(String, int)>[];
    final limit = t.length >= 5 ? 2 : 1;
    for (final key in _count.keys) {
      if (key == t) continue;
      if (key.startsWith(t)) {
        starts.add(key);
      } else if ((key.length - t.length).abs() <= limit) {
        final d = _distance(t, key, limit);
        if (d <= limit) close.add((key, d));
      }
    }
    int byCount(String a, String b) {
      final c = _count[b]!.compareTo(_count[a]!);
      if (c != 0) return c;
      final l = a.length.compareTo(b.length);
      return l != 0 ? l : a.compareTo(b);
    }

    starts.sort(byCount);
    close.sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : byCount(a.$1, b.$1));
    return [
      for (final key in [...starts, for (final c in close) c.$1].take(max)) _caseOf(typed, _form[key]!),
    ];
  }

  static String _caseOf(String typed, String word) {
    final chars = typed.characters;
    if (chars.length > 1 && typed == typed.toUpperCase() && typed != typed.toLowerCase()) {
      return word.toUpperCase();
    }
    final first = chars.first;
    if (first != first.toLowerCase()) {
      final w = word.characters;
      return w.first.toUpperCase() + w.skip(1).toString();
    }
    return word;
  }

  /// The edit distance of [a] and [b] with swaps of two letters next to each other, or
  /// [limit] + 1 if it is more than [limit].
  static int _distance(String a, String b, int limit) {
    final n = a.length, m = b.length;
    var prev2 = List<int>.filled(m + 1, 0);
    var prev = List<int>.generate(m + 1, (j) => j);
    for (var i = 1; i <= n; i++) {
      final cur = List<int>.filled(m + 1, 0)..[0] = i;
      var best = cur[0];
      for (var j = 1; j <= m; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = min(min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          v = min(v, prev2[j - 2] + 1);
        }
        cur[j] = v;
        if (v < best) best = v;
      }
      if (best > limit) return limit + 1;
      prev2 = prev;
      prev = cur;
    }
    return prev[m];
  }
}

/// The corrections of the message that the user writes. A tap on a proposal that is not
/// only the end of the word ([original] is not the start of [replacement]) is a
/// correction.
class CorrectionLog {
  final List<Correction> _all = [];

  void tapped(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty || original == replacement) return;
    if (replacement.toLowerCase().startsWith(original.toLowerCase())) return;
    if (original.characters.length > correctorMaxWordChars ||
        replacement.characters.length > correctorMaxWordChars) {
      return;
    }
    _all.add(Correction(original, replacement));
  }

  /// The corrections that are still in [text]: as many of each replacement as the text
  /// has whole words of it, in the order of the taps, and at most
  /// [correctorMaxCorrections].
  List<Correction> inText(String text) {
    final left = <String, int>{};
    for (final m in _words.allMatches(text)) {
      left.update(m.group(0)!, (n) => n + 1, ifAbsent: () => 1);
    }
    final out = <Correction>[];
    for (final c in _all) {
      final n = left[c.replacement] ?? 0;
      if (n == 0) continue;
      left[c.replacement] = n - 1;
      out.add(c);
      if (out.length == correctorMaxCorrections) break;
    }
    return out;
  }

  void clear() => _all.clear();
}
