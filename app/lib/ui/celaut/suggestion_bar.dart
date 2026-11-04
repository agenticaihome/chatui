import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../celaut/chat_corrector.dart';
import '../../l10n/l10n.dart';

/// The three chips above the keyboard (`docs/celaut/chat.md`, section 5.7). While the
/// input is empty, or the cursor is after a space, they are the [suggestions] of the
/// service. While the user writes a word, they are the words of the [corrector] for it
/// (none if [corrector] is null). The bar has the same height while it shows, whatever it
/// holds, so the chat does not move at each key.
class SuggestionBar extends StatelessWidget {
  const SuggestionBar({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.corrector,
    required this.onSuggestion,
    required this.onWord,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final ChatCorrector? corrector;

  /// A tap on a suggestion of the service.
  final ValueChanged<String> onSuggestion;

  /// A tap on a word of the corrector: [original] is the word at the cursor.
  final void Function(String original, String replacement) onWord;

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: context.l10n.chatSuggestionsLabel,
      child: SizedBox(
        key: const Key('chat-suggestions'),
        height: height,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final word = wordAtCursor(controller.value).word;
            final words = word.isEmpty ? null : corrector?.candidates(word);
            final items = word.isEmpty ? suggestions : (words ?? const <String>[]);
            return Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0)
                    SizedBox(
                      height: 20,
                      child: VerticalDivider(width: 1, color: scheme.outlineVariant),
                    ),
                  Expanded(
                    child: i < items.length
                        ? _Chip(
                            key: Key(word.isEmpty ? 'chat-suggestion-$i' : 'chat-word-$i'),
                            text: items[i],
                            onTap: () => word.isEmpty ? onSuggestion(items[i]) : onWord(word, items[i]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      canRequestFocus: false,
      // One frame for the tap, not the frames of a splash (`docs/performance.md`, section 5).
      splashFactory: NoSplash.splashFactory,
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
