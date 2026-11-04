import 'package:flutter/material.dart';

import '../../celaut/chat_groups.dart';
import '../../celaut/chat_prefs.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import 'settings_shared.dart';

/// Chat text size and font, pinned message height and HTML widgets.
class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

  static String _familyLabel(BuildContext context, String id) => switch (id) {
        'lato' => context.l10n.chatFontLato,
        'serif' => context.l10n.chatFontSerif,
        'mono' => context.l10n.chatFontMono,
        _ => context.l10n.chatFontSystem,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([chatPrefs, chatGroups]),
      builder: (context, _) {
        return SettingsPage(
          title: context.l10n.chatSettingsTitle,
          children: [
            SettingsGroup(
              title: context.l10n.chatSettingsTextGroup,
              scope: context.l10n.settingsScopeAppWide,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.chatSettingsPreview,
                    key: const Key('chat-settings-preview'),
                    style: chatPrefs.textStyle,
                  ),
                ),
                _SliderRow(
                  title: context.l10n.chatSettingsFontSize,
                  valueLabel: chatPrefs.fontSize.round().toString(),
                  slider: Slider(
                    key: const Key('chat-settings-font-size'),
                    value: chatPrefs.fontSize,
                    min: ChatPrefs.minFontSize,
                    max: ChatPrefs.maxFontSize,
                    divisions: (ChatPrefs.maxFontSize - ChatPrefs.minFontSize).round(),
                    onChanged: chatPrefs.setFontSize,
                  ),
                ),
                for (final f in ChatPrefs.fontFamilies)
                  SettingsRow(
                    icon: Icons.text_fields,
                    title: _familyLabel(context, f),
                    trailing: Icon(
                      chatPrefs.fontFamily == f ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                      color: accentOf(context),
                    ),
                    onTap: () => chatPrefs.setFontFamily(f),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsGroup(
              title: context.l10n.chatSettingsPinnedGroup,
              scope: context.l10n.settingsScopeAppWide,
              children: [
                _SliderRow(
                  title: context.l10n.chatSettingsPinnedMax,
                  valueLabel: '${(chatPrefs.pinnedMaxFraction * 100).round()}%',
                  slider: Slider(
                    key: const Key('chat-settings-pinned-max'),
                    value: chatPrefs.pinnedMaxFraction,
                    min: ChatPrefs.minPinnedMaxFraction,
                    max: ChatPrefs.maxPinnedMaxFraction,
                    divisions: 8,
                    onChanged: chatPrefs.setPinnedMaxFraction,
                  ),
                ),
              ],
            ),
            SettingsNote(context.l10n.chatSettingsPinnedNote),
            const SizedBox(height: 24),
            SettingsGroup(
              title: context.l10n.chatSettingsWidgetsGroup,
              scope: context.l10n.settingsScopeAppWide,
              children: [
                SettingsRow(
                  icon: Icons.widgets_outlined,
                  title: context.l10n.chatSettingsHtmlWidgets,
                  subtitle: context.l10n.chatSettingsHtmlWidgetsSubtitle,
                  trailing: Switch(
                    key: const Key('chat-settings-html'),
                    value: chatPrefs.htmlWidgets,
                    onChanged: chatPrefs.setHtmlWidgets,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsGroup(
              title: context.l10n.chatSettingsKeyboardGroup,
              scope: context.l10n.settingsScopeAppWide,
              children: [
                SettingsRow(
                  icon: Icons.keyboard_outlined,
                  title: context.l10n.chatSettingsSystemKeyboard,
                  subtitle: context.l10n.chatSettingsSystemKeyboardSubtitle,
                  trailing: Switch(
                    key: const Key('chat-settings-system-keyboard'),
                    value: chatPrefs.systemKeyboard,
                    onChanged: chatPrefs.setSystemKeyboard,
                  ),
                ),
                SettingsRow(
                  icon: Icons.spellcheck,
                  title: context.l10n.chatSettingsWordSuggestions,
                  subtitle: context.l10n.chatSettingsWordSuggestionsSubtitle,
                  trailing: Switch(
                    key: const Key('chat-settings-word-suggestions'),
                    value: chatPrefs.wordSuggestions,
                    onChanged: chatPrefs.setWordSuggestions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SettingsGroup(
              title: context.l10n.chatSettingsListGroup,
              scope: context.l10n.settingsScopeAppWide,
              children: [
                SettingsRow(
                  icon: Icons.folder_outlined,
                  title: context.l10n.chatSettingsGroupedView,
                  subtitle: context.l10n.chatSettingsGroupedViewSubtitle,
                  trailing: Switch(
                    key: const Key('chat-settings-grouped'),
                    value: chatGroups.grouped,
                    onChanged: chatGroups.setGrouped,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.title, required this.valueLabel, required this.slider});
  final String title;
  final String valueLabel;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              Text(valueLabel, style: TextStyle(fontSize: 13, color: ArgusColors.of(context).muted)),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}
