import 'package:argus_wallet/celaut/chat_corrector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue at(String text, [int? cursor]) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length));

void main() {
  group('the word at the cursor', () {
    test('the word that ends at the cursor, or none after a space', () {
      expect(wordAtCursor(at('hello wor')).word, 'wor');
      expect(wordAtCursor(at('hello ')).word, '');
      expect(wordAtCursor(at('')).word, '');
      // In the middle of a word: the whole word.
      expect(wordAtCursor(at('hello world', 8)), (start: 6, end: 11, word: 'world'));
      expect(wordAtCursor(at("I don't")).word, "don't");
      expect(wordAtCursor(at('niño')).word, 'niño');
      // A selection is no word.
      expect(
        wordAtCursor(const TextEditingValue(text: 'abc', selection: TextSelection(baseOffset: 0, extentOffset: 2)))
            .word,
        '',
      );
    });

    test('replace the word: a space after it, and the cursor after the space', () {
      expect(replaceWordAtCursor(at('hello wor'), 'world'), at('hello world '));
      // The rest of the text stays, and no second space comes.
      final v = replaceWordAtCursor(at('teh cat', 3), 'the');
      expect(v.text, 'the cat');
      expect(v.selection.baseOffset, 4);
    });
  });

  group('candidates', () {
    late ChatCorrector c;
    setUp(() {
      c = ChatCorrector()
        ..learn('The keyboard of the app. The keys of the keyboard, keep them.')
        ..learn('Lisbon is a city. Lisbon in May.');
    });

    test('the words that start with it come first, the most seen first', () {
      expect(c.candidates('ke'), ['keyboard', 'keep', 'keys']);
      expect(c.candidates('ke', max: 1), ['keyboard']);
    });

    test('then the words that are close: one change, two for a long word', () {
      // "teh": a swap of two letters.
      expect(c.candidates('teh'), contains('the'));
      // "keybaord": two changes in a long word.
      expect(c.candidates('keybaord'), ['keyboard']);
      // Far words are not proposed.
      expect(c.candidates('zzz'), isEmpty);
    });

    test('not the word itself, and the case follows what the user wrote', () {
      expect(c.candidates('the'), isNot(contains('the')));
      expect(c.candidates('Ke').first, 'Keyboard');
      expect(c.candidates('KE').first, 'KEYBOARD');
      // A word that the conversation has only with a capital keeps it.
      expect(c.candidates('lis').first, 'Lisbon');
    });

    test('the limits: no word of one letter, of more than 64, or past the most words', () {
      final small = ChatCorrector()..learn('a b ${'x' * 65} ok');
      expect(small.size, 1);
      final full = ChatCorrector();
      for (var i = 0; i < ChatCorrector.maxWords + 10; i++) {
        full.learn('w$i');
      }
      expect(full.size, ChatCorrector.maxWords);
      expect(c.candidates(''), isEmpty);
    });
  });

  group('the corrections of a message', () {
    test('a correction, not a completion; only the ones still in the text', () {
      final log = CorrectionLog()
        ..tapped('teh', 'the')
        // The end of the word only: no correction.
        ..tapped('key', 'keyboard')
        ..tapped('Lisbn', 'Lisbon')
        ..tapped('wrold', 'world');
      expect(log.inText('the keyboard of Lisbon'), const [Correction('teh', 'the'), Correction('Lisbn', 'Lisbon')]);
      // The user wrote the word again by hand: the correction is gone with it.
      expect(log.inText('a keyboard of Lisbon'), const [Correction('Lisbn', 'Lisbon')]);
      // One word in the text, two taps that gave it: one correction.
      final twice = CorrectionLog()
        ..tapped('teh', 'the')
        ..tapped('hte', 'the');
      expect(twice.inText('the end'), const [Correction('teh', 'the')]);
      log.clear();
      expect(log.inText('the keyboard of Lisbon'), isEmpty);
    });

    test('at most 32', () {
      final log = CorrectionLog();
      for (var i = 0; i < 40; i++) {
        log.tapped('teh', 'the');
      }
      expect(log.inText(List.filled(40, 'the').join(' ')), hasLength(correctorMaxCorrections));
    });
  });
}
