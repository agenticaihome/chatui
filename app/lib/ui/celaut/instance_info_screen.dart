import 'package:flutter/material.dart';

import '../../bridge/api/celaut_receipts.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/host_port.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/chat_backgrounds.dart';
import '../../celaut/chat_groups.dart';
import '../../celaut/chat_prefs.dart';
import '../../celaut/conversations.dart';
import '../../celaut/payers.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_scene.dart';
import '../home/home_style.dart';
import '../layout.dart';
import 'instance_actions.dart';
import 'instance_receipts.dart';
import 'instance_time_section.dart';
import 'robot_avatar.dart';
import 'service_info_screen.dart';

/// The page of one instance, as the info page of a chat in a messenger: the service,
/// the node, the chat slot, the cost so far, the start time, and Stop; for a stopped
/// instance, the refund and Delete (`docs/celaut/ui-chat-first.md`). It opens from the title of the conversation, from
/// its ⋮ menu, and from a long press in the list.
class InstanceInfoScreen extends StatefulWidget {
  const InstanceInfoScreen({
    super.key,
    required this.instance,
    required this.state,
    this.costMu,
    this.reason,
    this.wallets = const AppFullWallets(),
    this.stop,
    this.hibernate,
    this.wake,
    this.forget,
    this.notes,
    this.loadInfo = readServiceInfo,
    this.rename,
    this.onRenamed,
    this.loadReceipts = readReceipts,
    this.exportReceipts = shareReceipts,
  });

  /// Read the execution receipts of an instance; null if the app cannot. Tests give
  /// their own.
  final ReceiptsView? Function(String instanceId) loadReceipts;

  /// Share the receipts file of an instance; false if it has no receipt. Tests give
  /// their own.
  final Future<bool> Function(String instanceId) exportReceipts;

  /// Keep a new name of the instance. Tests give their own.
  final void Function(String instanceId, String alias)? rename;

  /// The user gave the instance a new name here.
  final ValueChanged<InstanceListView>? onRenamed;

  /// Read what the service says about itself. Tests give their own.
  final ServiceInfoLoader loadInfo;

  final InstanceListView instance;
  final InstanceState state;

  /// What the instance cost so far, in MU (empty or null if unknown).
  final String? costMu;

  /// Why the node does not report the instance, for [InstanceState.unreachable].
  final String? reason;

  final FullWallets wallets;

  /// Stop the instance. Tests give their own.
  final Future<StopView> Function(String instanceId)? stop;

  /// Hibernate the instance. Tests give their own.
  final Future<HibernationView> Function(String instanceId)? hibernate;

  /// Wake the hibernated instance. Tests give their own.
  final Future<HibernationView> Function(String instanceId)? wake;

  /// Delete the stopped instance. Tests give their own.
  final void Function(String instanceId)? forget;

  final ConversationNotes? notes;

  @override
  State<InstanceInfoScreen> createState() => _InstanceInfoScreenState();
}

class _InstanceInfoScreenState extends State<InstanceInfoScreen> {
  bool _stopping = false;
  bool _changing = false;
  late InstanceListView _instance = widget.instance;
  late ReceiptsView? _receipts = widget.loadReceipts(widget.instance.instanceId);

  /// Read the receipts again. The numbers change while a chat runs.
  Future<void> _reloadReceipts() async {
    final fresh = widget.loadReceipts(_instance.instanceId);
    if (!mounted) return;
    setState(() => _receipts = fresh);
  }

  /// Give the receipts of the instance to another app, as a file.
  Future<void> _exportReceipts() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shared = await widget.exportReceipts(_instance.instanceId);
      if (!shared) messenger.showSnackBar(SnackBar(content: Text(l.chatsReceiptsExportNone)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.chatsReceiptsExportFailed('$e'))));
    }
    if (mounted) await _reloadReceipts();
  }

  Future<void> _rename() async {
    final renamed = await renameInstance(context, _instance, rename: widget.rename);
    if (renamed == null || !mounted) return;
    setState(() => _instance = renamed);
    widget.onRenamed?.call(renamed);
  }

  /// Choose the background of the chat of this instance. Only this phone keeps the choice.
  Future<void> _background() async {
    final l = context.l10n;
    final id = _instance.instanceId;
    final dark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            key: const Key('info-backgrounds'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.chatsBackground, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: chatPrefs,
                builder: (context, _) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final bg in chatBackgrounds)
                      Semantics(
                        button: true,
                        selected: chatPrefs.background(id) == bg.id,
                        label: chatBackgroundLabel(l, bg.id),
                        excludeSemantics: true,
                        child: InkWell(
                          key: Key('info-background-${bg.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => chatPrefs.setBackground(id, bg.id),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 96,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    width: 2,
                                    color: chatPrefs.background(id) == bg.id
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CustomPaint(painter: ChatBackgroundPainter(bg.id, dark)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                chatBackgroundLabel(l, bg.id),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _stop() async {
    setState(() => _stopping = true);
    final done = await confirmAndStopInstance(
      context,
      _instance,
      wallets: widget.wallets,
      stop: widget.stop,
      notes: widget.notes,
    );
    if (!mounted) return;
    setState(() => _stopping = false);
    await _reloadReceipts();
    if (!mounted) return;
    // The caller reads the list again: the instance stopped.
    if (done != null) Navigator.of(context).pop(true);
  }

  /// Hibernate or wake the instance. When the state changed, the page closes with true and
  /// the caller reads the list again.
  Future<void> _hibernateOrWake({required bool wakeUp}) async {
    setState(() => _changing = true);
    final wallets = widget.wallets;
    final done = wakeUp
        ? await confirmAndWakeInstance(context, _instance, wallets: wallets, wake: widget.wake)
        : await confirmAndHibernateInstance(
            context,
            _instance,
            wallets: wallets,
            hibernate: widget.hibernate,
          );
    if (!mounted) return;
    setState(() => _changing = false);
    if (done != null) Navigator.of(context).pop(true);
  }

  /// The details of the service: from the library file, or from the node of the instance,
  /// which has the service.
  void _details() {
    final i = _instance;
    final parsed = parseHostPort(i.address).value;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ServiceInfoScreen(
          serviceIdHex: i.serviceId,
          name: instanceTitle(i),
          node: parsed == null ? null : NodeAddress(host: parsed.host, port: parsed.port),
          load: widget.loadInfo,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final deleted = await confirmAndDeleteInstance(
      context,
      _instance,
      forget: widget.forget,
      notes: widget.notes,
    );
    if (deleted) await chatGroups.forget(_instance.instanceId);
    // The caller reads the list again: the instance left it.
    if (deleted && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final i = _instance;
    final title = instanceTitle(i);
    final slot = i.chatSlots.isNotEmpty ? i.chatSlots.first : null;
    final started = formatTxTime(i.startedAt.toInt() * 1000);
    final hibernated = widget.state == InstanceState.hibernated;
    final resources = i.awakeResources;
    final hibernatedSince = i.hibernatedAt == null ? '' : formatTxTime(i.hibernatedAt!.toInt() * 1000);
    final rows = <(String, String, Key)>[
      (l.chatsInfoStatus, instanceStateText(context, widget.state), const Key('info-status')),
      if (hibernated)
        (
          l.chatsInfoHibernatedSince,
          hibernatedSince.isEmpty ? l.celautUnknown : hibernatedSince,
          const Key('info-hibernated-since'),
        ),
      if (hibernated || resources != null)
        (
          l.chatsInfoResources,
          resources == null
              ? l.chatsInfoResourcesNone
              : resources.source == ResourcesSourceView.lastKnown
              ? l.chatsInfoResourcesLastKnown(resourcesText(context, resources))
              : resourcesText(context, resources),
          const Key('info-resources'),
        ),
      (l.chatsInfoNode, i.address, const Key('info-node')),
      (l.chatsInfoPeer, i.peerId, const Key('info-peer')),
      (l.chatsInfoServiceId, i.serviceId, const Key('info-service')),
      (l.chatsInfoInstanceId, i.instanceId, const Key('info-instance')),
      (
        l.chatsInfoSlot,
        slot == null ? l.chatsInfoNoChatSlot : l.chatsInfoChatSlot,
        const Key('info-slot'),
      ),
      (l.chatsInfoStarted, started.isEmpty ? l.celautUnknown : started, const Key('info-started')),
      if (widget.state == InstanceState.stopped)
        (l.chatsInfoRefund, muOrUnknown(i.refundMu), const Key('info-refund'))
      else
        (l.chatsInfoCost, muOrUnknown(widget.costMu), const Key('info-cost')),
    ];
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l.chatsInfoTitle),
        actions: [
          IconButton(
            key: const Key('info-rename'),
            tooltip: l.chatsRename,
            onPressed: _rename,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (_instance.chatSlots.isNotEmpty)
            IconButton(
              key: const Key('info-background'),
              tooltip: l.chatsBackground,
              onPressed: _background,
              icon: const Icon(Icons.wallpaper_outlined),
            ),
          IconButton(
            key: const Key('info-service-details'),
            tooltip: l.chatsInfoServiceDetails,
            onPressed: _details,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: ReadableWidth(
        child: RefreshIndicator(
          onRefresh: _reloadReceipts,
          child: ListView(
          padding: EdgeInsets.fromLTRB(
            homeGutter,
            16,
            homeGutter,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                InstanceAvatar(instanceId: _instance.instanceId, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    key: const Key('info-name'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final (label, value, key) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(), style: t.label),
                    const SizedBox(height: 2),
                    SelectableText(value, key: key, style: t.primary),
                  ],
                ),
              ),
            if (widget.state == InstanceState.unreachable && (widget.reason ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.reason!,
                  key: const Key('info-reason'),
                  style: t.secondary.copyWith(color: rustFor(context)),
                ),
              ),
              if (widget.state != InstanceState.stopped && !hibernated) ...[
              const SizedBox(height: 16),
              InstanceTimeSection(instanceId: _instance.instanceId, wallets: widget.wallets),
            ],
            if (_receipts case final receipts?) ...[
              const SizedBox(height: 16),
              InstanceReceiptsSection(view: receipts, onExport: _exportReceipts),
            ],
            if (widget.state != InstanceState.stopped) ...[
              const SizedBox(height: 24),
                if (hibernationSupport.isUnsupported(i.address)) ...[
                  Text(
                    l.chatsRefusalUnsupported,
                    key: const Key('info-hibernation-unsupported'),
                    style: t.secondary,
                  ),
                ] else if (hibernated) ...[
                  FilledButton.icon(
                    key: const Key('info-wake'),
                    onPressed: _changing || _stopping ? null : () => _hibernateOrWake(wakeUp: true),
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: Text(l.chatsWake),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.chatsInfoHibernatedNote,
                    key: const Key('info-hibernated-note'),
                    style: t.secondary,
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    key: const Key('info-hibernate'),
                    onPressed: _changing || _stopping ? null : () => _hibernateOrWake(wakeUp: false),
                    icon: const Icon(Icons.bedtime_outlined),
                    label: Text(l.chatsHibernate),
                  ),
                  const SizedBox(height: 8),
                  Text(l.chatsInfoHibernateNote, style: t.secondary),
                ],
                const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('info-stop'),
                onPressed: _stopping ? null : _stop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l.chatStop),
              ),
              const SizedBox(height: 8),
              Text(l.chatsInfoStopNote, style: t.secondary),
            ] else ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('info-delete'),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.chatsDelete),
              ),
              const SizedBox(height: 8),
              Text(l.chatsInfoDeleteNote, style: t.secondary),
            ],
          ],
        ),
        ),
      ),
    );
    return SceneBackdrop(child: scaffold);
  }
}

/// The round mark of a conversation: the robot of the instance ([RobotAvatar]), from its
/// id, as a messenger shows a picture for a contact. Services have no picture of their
/// own.
class InstanceAvatar extends StatelessWidget {
  const InstanceAvatar({super.key, required this.instanceId, this.size = homeMarkSize + 8});

  final String instanceId;
  final double size;

  @override
  Widget build(BuildContext context) => RobotAvatar(seed: instanceId, size: size);
}
