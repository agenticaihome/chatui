import 'package:flutter/material.dart';

import '../../bridge/api/celaut_service.dart';
import '../../celaut/service_presets.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import 'robot_avatar.dart';

/// Ask for the name of a preset. Null if the user cancels or leaves it blank. [body] is
/// shown over the field.
Future<String?> askPresetName(
  BuildContext context, {
  required String title,
  required String initial,
  required String action,
  List<String> body = const [],
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PresetNameDialog(title: title, initial: initial, action: action, body: body),
  );
}

class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog({required this.title, required this.initial, required this.action, required this.body});

  final String title;
  final String initial;
  final String action;
  final List<String> body;

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  late final _field = TextEditingController(text: ServicePresets.cleanName(widget.initial));

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final name = ServicePresets.cleanName(_field.text);
    Navigator.pop(context, name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return AlertDialog(
      key: const Key('preset-name-dialog'),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, text) in widget.body.indexed) ...[
              Text(
                text,
                key: Key('preset-name-body-$i'),
                style: i == 0 ? null : TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              key: const Key('preset-name-field'),
              controller: _field,
              autofocus: widget.body.isEmpty,
              maxLength: ServicePresets.maxNameChars,
              decoration: InputDecoration(labelText: l.presetNameLabel),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('preset-name-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('preset-name-ok'),
          onPressed: _save,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// "Pin as preset" on the info page of an instance (`docs/celaut/presets.md`, section 2):
/// a button and the line that says what it does; once pinned, "Pinned" and Unpin.
class PresetPinSection extends StatelessWidget {
  const PresetPinSection({super.key, required this.instance, required this.title, required this.presets});

  final InstanceListView instance;

  /// The name of the instance, as the page shows it: the default name of the preset.
  final String title;
  final ServicePresets presets;

  Future<void> _pin(BuildContext context) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (presets.full) {
      messenger.showSnackBar(SnackBar(content: Text(l.presetFull(ServicePresets.maxPresets))));
      return;
    }
    final launched = presets.launchedWith(instance.instanceId);
    final asked = launched?.where((v) => v.kind == PresetValueKind.ask).length ?? 0;
    final name = await askPresetName(
      context,
      title: l.presetPin,
      initial: title,
      action: l.presetPinAction,
      body: [
        l.presetPinBody,
        if (launched == null) l.presetPinUnknown else if (asked > 0) l.presetPinAsks(asked),
      ],
    );
    if (name == null) return;
    final pinned = await presets.pin(instanceId: instance.instanceId, serviceId: instance.serviceId, name: name);
    messenger.showSnackBar(
      SnackBar(content: Text(pinned == null ? l.presetFull(ServicePresets.maxPresets) : l.presetPinnedDone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    return ListenableBuilder(
      listenable: presets,
      builder: (context, _) {
        final pinned = presets.pinnedFrom(instance.instanceId);
        if (pinned == null) {
          return Column(
            key: const Key('info-preset'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                key: const Key('info-pin'),
                onPressed: () => _pin(context),
                icon: const Icon(Icons.push_pin_outlined),
                label: Text(l.presetPin),
              ),
              const SizedBox(height: 8),
              Text(l.presetPinNote, key: const Key('info-pin-note'), style: t.secondary),
            ],
          );
        }
        return Column(
          key: const Key('info-preset'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.presetPinned(pinned.name), key: const Key('info-pinned'), style: t.primary),
                ),
                TextButton(
                  key: const Key('info-unpin'),
                  onPressed: () => presets.remove(pinned.id),
                  child: Text(l.presetUnpin),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.presetPinNote, style: t.secondary),
          ],
        );
      },
    );
  }
}

/// Rename or remove a preset: the sheet of a long press on its slot of the wheel.
Future<void> showPresetEditSheet(BuildContext context, ServicePresets presets, ServicePreset preset) async {
  final l = context.l10n;
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        key: const Key('preset-edit-sheet'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: RobotAvatar(seed: preset.fromInstance, size: 40),
            title: Text(preset.name, style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            key: const Key('preset-edit-rename'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.chatsRename),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            key: const Key('preset-edit-remove'),
            leading: const Icon(Icons.remove_circle_outline),
            title: Text(l.presetRemove),
            onTap: () => Navigator.pop(context, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'rename':
      final name = await askPresetName(context, title: l.chatsRename, initial: preset.name, action: l.commonSave);
      if (name != null) await presets.rename(preset.id, name);
    case 'remove':
      final messenger = ScaffoldMessenger.of(context);
      await presets.remove(preset.id);
      messenger.showSnackBar(SnackBar(content: Text(l.presetRemoved(preset.name))));
  }
}
