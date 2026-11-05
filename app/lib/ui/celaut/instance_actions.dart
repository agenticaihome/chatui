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

  /// The user hibernated the instance: it has no CPU and RAM, and the node charges only
  /// for its disk. The app keeps this state itself, because the node does not report it.
  /// Its service does not answer, and that is no fault.
  hibernated,
}

String instanceStateText(BuildContext context, InstanceState state) {
  final l = context.l10n;
  return switch (state) {
    InstanceState.checking => l.chatsStateChecking,
    InstanceState.starting => l.chatsStateStarting,
    InstanceState.running => l.chatsStateRunning,
    InstanceState.unreachable => l.chatsStateUnreachable,
    InstanceState.stopped => l.chatsStateStopped,
    InstanceState.hibernated => l.chatsStateHibernated,
  };
}

/// The CPU of [r] as a number of cores, for the user ("1.5 CPU cores").
String resourcesCpuText(BuildContext context, AwakeResourcesView r) {
  final cores = r.cpuPeriod == BigInt.zero ? 0.0 : r.cpuQuota.toDouble() / r.cpuPeriod.toDouble();
  final text = cores == cores.roundToDouble() ? cores.toStringAsFixed(0) : cores.toStringAsFixed(2);
  return context.l10n.chatsResourcesCpu(text);
}

/// The CPU and the RAM of [r], for the user.
String resourcesText(BuildContext context, AwakeResourcesView r) =>
    '${resourcesCpuText(context, r)}, ${CelautStrings.bytes(r.memLimit.toInt())}';

/// The nodes that do not support hibernation (a node older than the `service_token` of
/// `ModifyServiceSystemResources`), by address. The app finds out at the first call, as
/// nothing else says it (the node has no version call), and then hides the hibernate and
/// wake actions of that node. It is not kept on disk: after a restart the first call asks
/// again, which costs nothing, because the node refuses before it charges.
class HibernationSupport {
  final Set<String> _unsupported = {};

  /// True if a call to the node at [address] showed that it does not support hibernation.
  bool isUnsupported(String address) => _unsupported.contains(address);

  /// The node at [address] refused hibernation as unsupported. Gives true the first time.
  bool markUnsupported(String address) => _unsupported.add(address);

  @visibleForTesting
  void reset() => _unsupported.clear();
}

/// What the app knows about the support of hibernation on each node.
final hibernationSupport = HibernationSupport();

/// The words for a call of hibernate or wake that the node or the app refused.
String resourceRefusalText(BuildContext context, ResourceRefusalView refusal, String message) {
  final l = context.l10n;
  return switch (refusal) {
    ResourceRefusalView.sharedFilesystem => l.chatsRefusalSharedFilesystem,
    ResourceRefusalView.notRevivable => l.chatsRefusalNotRevivable,
    ResourceRefusalView.instanceBalance => l.chatsRefusalInstanceBalance,
    ResourceRefusalView.doesNotFit => l.chatsRefusalDoesNotFit,
    ResourceRefusalView.noLocalInstance => l.chatsRefusalNoLocalInstance,
    ResourceRefusalView.notTheFather => l.chatsRefusalNotTheFather,
    ResourceRefusalView.noResources => l.chatsRefusalNoResources,
    ResourceRefusalView.notConfirmed => l.chatsRefusalNotConfirmed,
    ResourceRefusalView.unsupported => l.chatsRefusalUnsupported,
    ResourceRefusalView.other => l.chatsRefusalOther(message),
  };
}

/// Hibernate [instance] after the user confirms it. The app reads the CPU and RAM that the
/// instance has at this moment, keeps them, and then asks the node to hibernate it. Needs
/// the wallet open, as a stop does. Gives the answer if the instance is hibernated now,
/// and null if nothing changed (the user said no, the wallet did not open, the node or the
/// app refused, or the node did not answer: the snack bar says why).
Future<HibernationView?> confirmAndHibernateInstance(
  BuildContext context,
  InstanceListView instance, {
  FullWallets wallets = const AppFullWallets(),
  Future<HibernationView> Function(String instanceId)? hibernate,
}) async {
  if (instance.stoppedAt != null || instance.hibernatedAt != null) return null;
  if (hibernationSupport.isUnsupported(instance.address)) return null;
  final l = context.l10n;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('hibernate-confirm'),
      title: Text(l.chatsHibernateTitle(instanceTitle(instance))),
      content: Text(l.chatsHibernateBody),
      actions: [
        TextButton(
          key: const Key('hibernate-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('hibernate-ok'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.chatsHibernate),
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
  if (!context.mounted) return null;
  return _resourceCall(
    context,
    messenger,
    () => (hibernate ?? (id) => celautHibernateInstance(instanceId: id))(instance.instanceId),
    address: instance.address,
    done: InstanceStateView.hibernated,
    doneText: l.chatsHibernated,
  );
}

/// Wake the hibernated [instance] after the user confirms it. The dialog shows the CPU
/// and RAM that the instance will use: the ones that the app kept. If the app has no
/// values, it says so and calls nothing. Needs the wallet open. Gives the answer if the
/// instance is awake now, and null if nothing changed.
Future<HibernationView?> confirmAndWakeInstance(
  BuildContext context,
  InstanceListView instance, {
  FullWallets wallets = const AppFullWallets(),
  Future<HibernationView> Function(String instanceId)? wake,
}) async {
  if (instance.stoppedAt != null || instance.hibernatedAt == null) return null;
  if (hibernationSupport.isUnsupported(instance.address)) return null;
  final l = context.l10n;
  final resources = instance.awakeResources;
  if (resources == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatsWakeUnknown)));
    return null;
  }
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('wake-confirm'),
      title: Text(l.chatsWakeTitle(instanceTitle(instance))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.chatsWakeBody(
              resourcesCpuText(context, resources),
              CelautStrings.bytes(resources.memLimit.toInt()),
            ),
            key: const Key('wake-body'),
          ),
          if (resources.source == ResourcesSourceView.lastKnown) ...[
            const SizedBox(height: 12),
            Text(l.chatsWakeLastKnown, key: const Key('wake-last-known')),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('wake-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('wake-ok'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.chatsWake),
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
  if (!context.mounted) return null;
  return _resourceCall(
    context,
    messenger,
    () => (wake ?? (id) => celautWakeInstance(instanceId: id))(instance.instanceId),
    address: instance.address,
    done: InstanceStateView.running,
    doneText: l.chatsWoken,
  );
}

/// Run a hibernate or wake call and tell the user the result with a snack bar. Gives the
/// answer if the state is [done], else null.
Future<HibernationView?> _resourceCall(
  BuildContext context,
  ScaffoldMessengerState messenger,
  Future<HibernationView> Function() call, {
  required String address,
  required InstanceStateView done,
  required String doneText,
}) async {
  try {
    final view = await call();
    final refusal = view.refusal;
    if (refusal != null) {
      // The node says once that it cannot do this. From now on its instances show no
      // hibernate or wake action.
      if (refusal == ResourceRefusalView.unsupported) hibernationSupport.markUnsupported(address);
      // A refusal changes nothing: the instance has the state that it had.
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(resourceRefusalText(context, refusal, view.message))),
        );
      }
      return null;
    }
    messenger.showSnackBar(SnackBar(content: Text(doneText)));
    return view.state == done ? view : null;
  } on CelautError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(CelautStrings.errorText(e.kind))));
    return null;
  }
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
