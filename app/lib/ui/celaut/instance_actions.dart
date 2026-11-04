import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/chat_done_watcher.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/conversations.dart';
import '../../celaut/payers.dart';
import '../../l10n/l10n.dart';

/// Where an instance of the list of conversations is.
enum InstanceState {
  /// The app asks the node.
  checking,

  /// The instance started in this run of the app, and its service did not answer yet.
  starting,

  /// The node reports the instance.
  running,

  /// The node does not answer, or does not report the instance.
  unreachable,

  /// The instance stopped. It stays in the list until the user deletes it.
  stopped,
}

String instanceStateText(BuildContext context, InstanceState state) {
  final l = context.l10n;
  return switch (state) {
    InstanceState.checking => l.chatsStateChecking,
    InstanceState.starting => l.chatsStateStarting,
    InstanceState.running => l.chatsStateRunning,
    InstanceState.unreachable => l.chatsStateUnreachable,
    InstanceState.stopped => l.chatsStateStopped,
  };
}

/// Stop [instance] after the user confirms it. Stopping needs the wallet open
/// (`docs/celaut/ui.md`, section 1). The stopped instance stays in the database, and in
/// the list, until the user deletes it. If the node does not answer, the user sees why
/// and the instance stays as it was. Gives the answer of the node, or null if nothing
/// was stopped.
Future<StopView?> confirmAndStopInstance(
  BuildContext context,
  InstanceListView instance, {
  FullWallets wallets = const AppFullWallets(),
  Future<StopView> Function(String instanceId)? stop,
  ConversationNotes? notes,
}) async {
  final l = context.l10n;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('stop-confirm'),
      title: Text(l.chatsStopTitle(instanceTitle(instance))),
      content: Text(l.chatsStopBody),
      actions: [
        TextButton(
          key: const Key('stop-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('stop-ok'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.chatStop),
        ),
      ],
    ),
  );
  if (sure != true || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  if (!await ensureOpenFullWallet(context, wallets)) {
    messenger.showSnackBar(SnackBar(content: Text(l.celautOpenFullWalletNeeded)));
    return null;
  }
  try {
    final done = await (stop ?? (id) => celautStopService(instanceId: id))(instance.instanceId);
    (notes ?? conversationNotes).stopped(instance.instanceId);
    chatDoneWatcher.release(instance.instanceId);
    messenger.showSnackBar(SnackBar(content: Text(l.chatStopped(muOrUnknown(done.refundMu)))));
    return done;
  } on CelautError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(CelautStrings.errorText(e.kind))));
    return null;
  }
}

/// Delete a stopped [instance] after the user confirms it: it leaves the database and
/// the list. Only a stopped instance can be deleted; the app never forgets an instance
/// that was not stopped (`docs/celaut/decisions.md`). Gives true if it left the list.
Future<bool> confirmAndDeleteInstance(
  BuildContext context,
  InstanceListView instance, {
  void Function(String instanceId)? forget,
  ConversationNotes? notes,
}) async {
  if (instance.stoppedAt == null) return false;
  final l = context.l10n;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('delete-confirm'),
      title: Text(l.chatsDeleteTitle(instanceTitle(instance))),
      content: Text(l.chatsDeleteBody),
      actions: [
        TextButton(
          key: const Key('delete-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('delete-ok'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.chatsDelete),
        ),
      ],
    ),
  );
  if (sure != true || !context.mounted) return false;
  try {
    (forget ?? (id) => celautForgetInstance(instanceId: id))(instance.instanceId);
  } on CelautError catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(CelautStrings.errorText(e.kind))),
    );
    return false;
  }
  (notes ?? conversationNotes).remove(instance.instanceId);
  return true;
}

/// The longest name that the user can give an instance (`celaut_rename_instance`).
const instanceAliasMaxChars = 60;

/// Ask the user for a new name of [instance], and keep it in the Celaut database of the
/// app. The name is local: the node never gets it. An empty name removes it, and the
/// name of the skill or the service file shows again. Gives the instance with its new
/// name, or null if nothing changed.
Future<InstanceListView?> renameInstance(
  BuildContext context,
  InstanceListView instance, {
  void Function(String instanceId, String alias)? rename,
}) async {
  final alias = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(instance: instance),
  );
  if (alias == null || alias == instance.alias.trim() || !context.mounted) return null;
  try {
    (rename ?? (id, a) => celautRenameInstance(instanceId: id, alias: a))(
      instance.instanceId,
      alias,
    );
  } on CelautError catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(CelautStrings.errorText(e.kind))),
    );
    return null;
  }
  return withAlias(instance, alias);
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.instance});

  final InstanceListView instance;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _field = TextEditingController(text: instanceTitle(widget.instance));

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final alias = _field.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    // The field starts with the name that shows. With no name of the user, that is the
    // title of the service or the name of the start: keeping it is no new name, so a
    // later title of the service can still show.
    final i = widget.instance;
    if (i.alias.trim().isEmpty && alias == instanceTitle(i)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, alias);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // What shows with no name of the user: the title of the service, else the name of the
    // start.
    final title = widget.instance.title.trim();
    final original = title.isNotEmpty ? title : widget.instance.name.trim();
    return AlertDialog(
      key: const Key('rename-dialog'),
      title: Text(l.chatsRenameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('rename-field'),
            controller: _field,
            autofocus: true,
            maxLength: instanceAliasMaxChars,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
          ),
          Text(
            original.isEmpty ? l.chatsRenameNote : l.chatsRenameNoteOriginal(original),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('rename-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('rename-ok'),
          onPressed: _save,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
