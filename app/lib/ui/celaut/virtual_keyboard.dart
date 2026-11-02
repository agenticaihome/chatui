import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../layout.dart';

const _lettersRows = ['qwertyuiop', 'asdfghjklñ', 'zxcvbnm'];
const _symbolsRows = ['1234567890', '@#€_&-+()/', '*"\':;!?'];

/// [text] with [insert] in place of the selection. A selection that is not valid (the field
/// never had the focus) puts [insert] at the end. The cursor goes after [insert].
TextEditingValue insertAtSelection(TextEditingValue v, String insert) {
  final sel = v.selection;
  final start = sel.isValid ? sel.start : v.text.length;
  final end = sel.isValid ? sel.end : v.text.length;
  return TextEditingValue(
    text: v.text.replaceRange(start, end, insert),
    selection: TextSelection.collapsed(offset: start + insert.length),
  );
}

/// [v] after Backspace: the selection if there is one, else the character before the
/// cursor (a whole character, not half of an emoji).
TextEditingValue deleteBackward(TextEditingValue v) {
  final sel = v.selection;
  final start = sel.isValid ? sel.start : v.text.length;
  final end = sel.isValid ? sel.end : v.text.length;
  if (start != end) {
    return TextEditingValue(
      text: v.text.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
  }
  if (start == 0) return v;
  final before = v.text.substring(0, start).characters.skipLast(1).toString();
  return TextEditingValue(
    text: before + v.text.substring(start),
    selection: TextSelection.collapsed(offset: before.length),
  );
}

/// The text before the cursor of [v] ends a sentence (or is empty, or ends a line): the
/// next letter starts with a capital.
bool atSentenceStart(TextEditingValue v) {
  final sel = v.selection;
  final before = v.text.substring(0, sel.isValid ? sel.start : v.text.length);
  return before.isEmpty || before.endsWith('\n') || RegExp(r'[.!?]\s+$').hasMatch(before);
}

/// How long a key waits before it repeats, and the pace of the repeat.
const _repeatDelay = Duration(milliseconds: 400);
const _repeatEvery = Duration(milliseconds: 60);

/// Two taps on Shift this close lock the capitals.
const _shiftDoubleTap = Duration(milliseconds: 350);

const _keyHeight = 48.0;

/// The height of a key on a short window (a phone on its side, [AppLayout.short]): four
/// rows of full keys would leave almost no room for the conversation.
const _shortKeyHeight = 36.0;

enum _Shift { off, once, lock }

/// The keyboard of the app: letters, and numbers and symbols. It types in [controller], so
/// the chat never needs the keyboard of the system. A key does not take the focus: the
/// field that has it keeps it, and [focusNode] (if given) takes it when a key is tapped.
/// With [maxLength], a key that would make the text longer does nothing. Shift is for one
/// letter, and two quick taps lock it. Backspace repeats while it is held. With
/// [autoCapitalize], Shift is on where a sentence starts.
class ChatVirtualKeyboard extends StatefulWidget {
  const ChatVirtualKeyboard({
    super.key,
    required this.controller,
    this.focusNode,
    this.maxLength,
    this.autoCapitalize = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int? maxLength;
  final bool autoCapitalize;

  @override
  State<ChatVirtualKeyboard> createState() => _ChatVirtualKeyboardState();
}

class _ChatVirtualKeyboardState extends State<ChatVirtualKeyboard> {
  _Shift _shift = _Shift.off;
  DateTime? _shiftTapAt;
  bool _symbols = false;
  Timer? _repeat;
  late String _lastText;

  bool get _upper => _shift != _Shift.off && !_symbols;

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onText);
    if (widget.autoCapitalize && atSentenceStart(widget.controller.value)) _shift = _Shift.once;
  }

  @override
  void didUpdateWidget(ChatVirtualKeyboard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _lastText = widget.controller.text;
      _shift = widget.autoCapitalize && atSentenceStart(widget.controller.value) ? _Shift.once : _Shift.off;
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  /// A change of the text (not of the cursor) puts Shift on at the start of a sentence, and
  /// takes it away anywhere else. A locked Shift stays.
  void _onText() {
    final text = widget.controller.text;
    if (text == _lastText) return;
    _lastText = text;
    if (!widget.autoCapitalize || _shift == _Shift.lock) return;
    final next = atSentenceStart(widget.controller.value) ? _Shift.once : _Shift.off;
    if (next != _shift) setState(() => _shift = next);
  }

  void _tapShift() {
    final now = DateTime.now();
    final quick = _shiftTapAt != null && now.difference(_shiftTapAt!) < _shiftDoubleTap;
    _shiftTapAt = now;
    setState(() {
      if (quick && _shift != _Shift.lock) {
        _shift = _Shift.lock;
      } else {
        _shift = _shift == _Shift.off ? _Shift.once : _Shift.off;
      }
    });
  }

  /// Does [act] now, and again and again while the key stays down.
  void _startRepeat(VoidCallback act) {
    unawaited(HapticFeedback.selectionClick());
    act();
    _repeat?.cancel();
    _repeat = Timer(_repeatDelay, () => _repeat = Timer.periodic(_repeatEvery, (_) => act()));
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _apply(TextEditingValue v) {
    final max = widget.maxLength;
    if (max != null && v.text.length > max && v.text.length > widget.controller.text.length) return;
    widget.controller.value = v;
    widget.focusNode?.requestFocus();
  }

  void _type(String s) {
    final once = _shift == _Shift.once;
    _apply(insertAtSelection(widget.controller.value, s));
    // With automatic capitals the change of the text decides what Shift does next.
    if (once && !widget.autoCapitalize) setState(() => _shift = _Shift.off);
  }

  Widget _key(String id, Widget child, VoidCallback onTap, {double flex = 1, String? label, bool on = false, bool repeat = false}) {
    final scheme = Theme.of(context).colorScheme;
    final ink = InkWell(
      key: Key('vk-$id'),
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(8),
      // A key that repeats acts when it goes down, so the tap has nothing left to do.
      onTap: repeat
          ? () {}
          : () {
              unawaited(HapticFeedback.selectionClick());
              onTap();
            },
      child: SizedBox(
        height: AppLayout.short(context) ? _shortKeyHeight : _keyHeight,
        child: Center(child: child),
      ),
    );
    return Expanded(
      flex: (flex * 10).round(),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: label != null,
          child: Material(
            color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: repeat
                ? Listener(
                    onPointerDown: (_) => _startRepeat(onTap),
                    onPointerUp: (_) => _stopRepeat(),
                    onPointerCancel: (_) => _stopRepeat(),
                    child: ink,
                  )
                : ink,
          ),
        ),
      ),
    );
  }

  Widget _char(String c) {
    final shown = _upper ? c.toUpperCase() : c;
    // The case comes from the state at the tap, not from the last build: a second tap can
    // come before the next frame, and Shift is for one letter only.
    return _key('char-$c', Text(shown, style: const TextStyle(fontSize: 24)),
        () => _type(_upper ? c.toUpperCase() : c));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = _symbols ? _symbolsRows : _lettersRows;
    return Container(
      key: const Key('chat-virtual-keyboard'),
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [for (final c in rows[0].characters) _char(c)]),
          Row(children: [for (final c in rows[1].characters) _char(c)]),
          Row(
            children: [
              if (_symbols)
                const Spacer(flex: 15)
              else
                _key('shift', Icon(_shift == _Shift.lock ? Icons.keyboard_capslock : Icons.arrow_upward, size: 26),
                    _tapShift, flex: 1.5, label: l10n.chatVkShift, on: _shift != _Shift.off),
              for (final c in rows[2].characters) _char(c),
              _key('backspace', const Icon(Icons.backspace_outlined, size: 26), () => _apply(deleteBackward(widget.controller.value)),
                  flex: 1.5, label: l10n.chatVkBackspace, repeat: true),
            ],
          ),
          Row(
            children: [
              _key('symbols', Text(_symbols ? 'ABC' : '?123', style: const TextStyle(fontSize: 18)), () => setState(() => _symbols = !_symbols),
                  flex: 1.5, label: _symbols ? l10n.chatVkLetters : l10n.chatVkSymbols),
              _key('char-,', const Text(',', style: TextStyle(fontSize: 24)), () => _type(',')),
              _key('space', const SizedBox.shrink(), () => _type(' '), flex: 5, label: l10n.chatVkSpace),
              _key('char-.', const Text('.', style: TextStyle(fontSize: 24)), () => _type('.')),
              _key('enter', const Icon(Icons.keyboard_return, size: 26), () => _type('\n'), flex: 1.5, label: l10n.chatVkEnter),
            ],
          ),
        ],
      ),
    );
  }
}
