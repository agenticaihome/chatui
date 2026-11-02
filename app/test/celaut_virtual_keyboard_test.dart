import 'package:argus_wallet/l10n/app_localizations.dart';
import 'package:argus_wallet/ui/celaut/virtual_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _v(String text, int start, [int? end]) =>
    TextEditingValue(text: text, selection: TextSelection(baseOffset: start, extentOffset: end ?? start));

void main() {
  group('editing', () {
    test('insertAtSelection puts the text at the cursor and moves the cursor', () {
      final r = insertAtSelection(_v('ac', 1), 'b');
      expect((r.text, r.selection.baseOffset), ('abc', 2));
    });

    test('insertAtSelection replaces the selection', () {
      expect(insertAtSelection(_v('abc', 0, 2), 'x').text, 'xc');
    });

    test('with no valid selection the text goes at the end', () {
      expect(insertAtSelection(const TextEditingValue(text: 'ab'), 'c').text, 'abc');
    });

    test('deleteBackward deletes the selection, or the character before the cursor', () {
      expect(deleteBackward(_v('abc', 0, 2)).text, 'c');
      final r = deleteBackward(_v('abc', 2));
      expect((r.text, r.selection.baseOffset), ('ac', 1));
      expect(deleteBackward(_v('abc', 0)).text, 'abc');
    });

    test('deleteBackward deletes a whole emoji', () {
      expect(deleteBackward(_v('a😀', 3)).text, 'a');
    });
  });

  group('widget', () {
    late TextEditingController controller;

    Future<void> pump(WidgetTester t, {int? maxLength, bool autoCapitalize = false}) async {
      controller = TextEditingController();
      addTearDown(controller.dispose);
      await t.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ChatVirtualKeyboard(controller: controller, maxLength: maxLength, autoCapitalize: autoCapitalize),
        ),
      ));
    }

    testWidgets('letters, space, shift for one letter, and backspace', (t) async {
      await pump(t);
      await t.tap(find.byKey(const Key('vk-char-h')));
      await t.tap(find.byKey(const Key('vk-shift')));
      await t.pump();
      await t.tap(find.byKey(const Key('vk-char-i')));
      await t.tap(find.byKey(const Key('vk-char-j')));
      await t.tap(find.byKey(const Key('vk-space')));
      await t.tap(find.byKey(const Key('vk-char-ñ')));
      expect(controller.text, 'hIj ñ');
      await t.tap(find.byKey(const Key('vk-backspace')));
      expect(controller.text, 'hIj ');
    });

    testWidgets('on a short window (a phone on its side) the keys are lower', (t) async {
      addTearDown(t.view.reset);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      await pump(t);
      final tall = t.getSize(find.byKey(const Key('chat-virtual-keyboard'))).height;
      expect(t.getSize(find.byKey(const Key('vk-char-a'))).height, 48);
      t.view.physicalSize = const Size(844, 390);
      await t.pump();
      expect(t.getSize(find.byKey(const Key('vk-char-a'))).height, 36);
      expect(t.getSize(find.byKey(const Key('chat-virtual-keyboard'))).height, tall - 4 * 12);
    });

    testWidgets('the symbols layer has digits, and ABC goes back', (t) async {
      await pump(t);
      expect(find.byKey(const Key('vk-char-1')), findsNothing);
      await t.tap(find.byKey(const Key('vk-symbols')));
      await t.pump();
      await t.tap(find.byKey(const Key('vk-char-1')));
      expect(controller.text, '1');
      await t.tap(find.byKey(const Key('vk-symbols')));
      await t.pump();
      expect(find.byKey(const Key('vk-char-q')), findsOneWidget);
    });

    testWidgets('enter writes a new line', (t) async {
      await pump(t);
      await t.tap(find.byKey(const Key('vk-enter')));
      expect(controller.text, '\n');
    });

    testWidgets('two quick taps on shift lock the capitals, and a third unlocks them', (t) async {
      await pump(t);
      await t.tap(find.byKey(const Key('vk-shift')));
      await t.tap(find.byKey(const Key('vk-shift')));
      await t.pump();
      await t.tap(find.byKey(const Key('vk-char-a')));
      await t.tap(find.byKey(const Key('vk-char-b')));
      expect(controller.text, 'AB');
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byKey(const Key('vk-shift')));
      await t.pump();
      await t.tap(find.byKey(const Key('vk-char-c')));
      expect(controller.text, 'ABc');
    });

    testWidgets('with automatic capitals a sentence starts with a capital', (t) async {
      await pump(t, autoCapitalize: true);
      await t.tap(find.byKey(const Key('vk-char-h')));
      await t.tap(find.byKey(const Key('vk-char-i')));
      await t.tap(find.byKey(const Key('vk-char-.')));
      await t.tap(find.byKey(const Key('vk-space')));
      await t.tap(find.byKey(const Key('vk-char-o')));
      await t.tap(find.byKey(const Key('vk-char-k')));
      expect(controller.text, 'Hi. Ok');
    });

    testWidgets('backspace repeats while it is held, and stops when it is released', (t) async {
      await pump(t);
      controller.text = 'abcdefghij';
      final g = await t.startGesture(t.getCenter(find.byKey(const Key('vk-backspace'))));
      await t.pump();
      expect(controller.text, 'abcdefghi');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 180));
      expect(controller.text.length, lessThan(9));
      await g.up();
      final left = controller.text;
      await t.pump(const Duration(milliseconds: 300));
      expect(controller.text, left);
    });

    test('atSentenceStart', () {
      expect(atSentenceStart(_v('', 0)), isTrue);
      expect(atSentenceStart(_v('Hi. ', 4)), isTrue);
      expect(atSentenceStart(_v('Hi\n', 3)), isTrue);
      expect(atSentenceStart(_v('Hi', 2)), isFalse);
      expect(atSentenceStart(_v('Hi.', 3)), isFalse);
      expect(atSentenceStart(_v('Hi, ', 4)), isFalse);
    });

    testWidgets('maxLength stops the text, but backspace still works', (t) async {
      await pump(t, maxLength: 2);
      for (final c in ['a', 'b', 'c']) {
        await t.tap(find.byKey(Key('vk-char-$c')));
      }
      expect(controller.text, 'ab');
      await t.tap(find.byKey(const Key('vk-backspace')));
      expect(controller.text, 'a');
    });
  });
}
