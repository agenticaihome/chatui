import 'dart:async';

import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/auto_top_up.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/chat_client.dart';
import '../../celaut/chat_groups.dart';
import '../../celaut/chat_prefs.dart';
import '../../celaut/conversations.dart';
import '../../celaut/launcher.dart';
import '../../celaut/payers.dart';
import '../../celaut/stopped_filter.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import 'chat_screen.dart';
import 'group_widgets.dart';
import 'instance_actions.dart';
import 'instance_info_screen.dart';
import 'open_web.dart';

/// The conversation screen of an instance. Tests give their own.
typedef ChatPageBuilder = Widget Function(InstanceListView instance, int port, bool starting);

/// The check of one instance on its node: its status, or why the node did not give it.
class _Check {
  const _Check.ok(InstanceStatusView this.status) : error = null;
  const _Check.failed(CelautError this.error) : status = null;

  final InstanceStatusView? status;
  final CelautError? error;
}

/// The instance list of a launch outcome, before the list reads the database again.
InstanceListView instanceOfLaunch(LaunchOutcome outcome, String serviceId, String? name) {
  final i = outcome.instance;
  return InstanceListView(
    instanceId: i.instanceId,
    peerId: i.peerId,
    address: '${outcome.quote.address.host}:${outcome.quote.address.port}',
    serviceId: serviceId.toLowerCase(),
    slots: i.slots,
    chatSlots: i.chatSlots,
    webSlots: i.webSlots,
    startedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    startChargeMu: '',
    name: name ?? '',
    alias: '',
    refundMu: '',
  );
}

/// The pane next to the list where a conversation and the info of an instance open, on a
/// wide window (`ChatsScreen`). With no pane, or a null [navigator], they open over the
/// list.
class ChatPane extends InheritedWidget {
  const ChatPane({super.key, required this.navigator, required super.child});

  final GlobalKey<NavigatorState>? navigator;

  static GlobalKey<NavigatorState>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatPane>()?.navigator;

  @override
  bool updateShouldNotify(ChatPane oldWidget) => oldWidget.navigator != navigator;
}

/// The rows of the instances of the app, as the chat list of a messenger
/// (`docs/celaut/ui-chat-first.md`): the instances whose interface has a chat slot
/// ([chats] true, the home screen: all of them), or only those with no chat and no web
/// slot ([chats] false: no screen shows this list now).
///
/// The rows come from the database at once ([load]): the instances that run and the
/// stopped ones that the user did not delete. The list asks each node for its running
/// instances when it opens, when the user comes back to it, and on a pull; it does not
/// poll. The answer gives the state (running or not answering) and the cost so far.
///
/// A tap opens the conversation, or the info page of an instance without a chat slot or
/// that stopped. A long press gives the actions: info and stop, or info and delete for
/// a stopped instance. An instance whose node does not answer stays in the list: only
/// a stopped instance can be deleted, and only by the user.
class InstanceList extends StatefulWidget {
  const InstanceList({
    super.key,
    required this.chats,
    this.empty,
    this.wallets = const AppFullWallets(),
    this.notes,
    this.load,
    this.loadStatus,
    this.stop,
    this.forget,
    this.rename,
    this.openTunnel,
    this.chatPage,
    this.bottomPadding = 0,
    this.filter,
    this.topUp,
    this.groups,
  });

  /// The groups of the conversations. Tests give their own.
  final ChatGroups? groups;

  /// The automatic top-up, which sees each balance that the list reads. Tests give their
  /// own.
  final AutoTopUp? topUp;

  /// The filter that hides the stopped instances. Tests give their own.
  final StoppedFilter? filter;

  /// Every instance, or only those that have no chat and no web slot.
  final bool chats;

  /// What the list shows with no row.
  final Widget? empty;

  final FullWallets wallets;
  final ConversationNotes? notes;

  /// The instances of the database. Tests give their own.
  final List<InstanceListView> Function()? load;

  /// The state of an instance on its node. Tests give their own.
  final Future<InstanceStatusView> Function(String instanceId)? loadStatus;

  /// Stop an instance. Tests give their own.
  final Future<StopView> Function(String instanceId)? stop;

  /// Delete a stopped instance from the database. Tests give their own.
  final void Function(String instanceId)? forget;

  /// Keep a name that the user gave an instance. Tests give their own.
  final void Function(String instanceId, String alias)? rename;

  /// A local port for the chat slot. Tests give their own.
  final Future<int> Function(String instanceId, int slot)? openTunnel;

  final ChatPageBuilder? chatPage;

  /// Room under the last row, for a floating button.
  final double bottomPadding;

  @override
  State<InstanceList> createState() => InstanceListState();
}

class InstanceListState extends State<InstanceList> {
  late final ConversationNotes _notes = widget.notes ?? conversationNotes;
  List<InstanceListView> _instances = const [];
  final Map<String, _Check> _checks = {};
  bool _failed = false;
  late final StoppedFilter _filter = widget.filter ?? stoppedFilter;
  late final ChatGroups _groups = widget.groups ?? chatGroups;

  /// The pane where conversations open ([ChatPane]), and the instance whose conversation
  /// or info it shows, if any.
  GlobalKey<NavigatorState>? _pane;
  InstanceListView? _inPane;

  @override
  void initState() {
    super.initState();
    _notes.addListener(_onNotes);
    _filter.addListener(_onNotes);
    _groups.addListener(_onNotes);
    unawaited(_filter.load());
    unawaited(refresh());
  }

  @override
  void dispose() {
    _notes.removeListener(_onNotes);
    _filter.removeListener(_onNotes);
    _groups.removeListener(_onNotes);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pane = ChatPane.of(context);
    // The window got narrow (a tablet turned upright): the pane is gone, with the
    // conversation in it. The conversation opens again over the list.
    final open = _inPane;
    if (_pane != null && pane == null && open != null) {
      _inPane = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && open.stoppedAt == null && open.chatSlots.isNotEmpty) unawaited(openChat(open));
      });
    }
    _pane = pane;
  }

  void _onNotes() {
    if (mounted) setState(() {});
  }

  /// Push [route] in the pane, in place of what it shows, or over the list if there is no
  /// pane. The row of [instance] shows as chosen while its page is in the pane.
  Future<T?> _push<T>(InstanceListView instance, Route<T> route) async {
    final pane = _pane?.currentState;
    if (pane == null) return Navigator.of(context).push<T>(route);
    pane.popUntil((r) => r.isFirst);
    setState(() => _inPane = instance);
    final result = await pane.push<T>(route);
    if (mounted && identical(_inPane, instance)) setState(() => _inPane = null);
    return result;
  }

  /// The home list has every instance: all of them are a conversation, and one that has
  /// only a web slot opens in the browser. The others have no interface to use, and
  /// the list with [chats] false keeps them.
  bool _wanted(InstanceListView i) =>
      widget.chats || (i.chatSlots.isEmpty && i.webSlots.isEmpty);

  /// Read the database, then ask the nodes.
  Future<void> refresh() async {
    List<InstanceListView> all;
    try {
      all = (widget.load ?? celautInstances)();
      _failed = false;
    } catch (_) {
      // No database yet (the bridge is not ready): the list is empty.
      all = const [];
      _failed = true;
    }
    // The running ones by start, the newest first; then the stopped ones, the last stop
    // first.
    final mine = [
      for (final i in all)
        if (_wanted(i)) i,
    ]..sort((a, b) {
        final sa = a.stoppedAt, sb = b.stoppedAt;
        if ((sa == null) != (sb == null)) return sa == null ? -1 : 1;
        if (sa != null && sb != null && sa != sb) return sb.compareTo(sa);
        return b.startedAt.compareTo(a.startedAt);
      });
    if (!mounted) return;
    setState(() {
      _instances = mine;
      _checks.removeWhere(
        (id, _) => !mine.any((i) => i.instanceId == id && i.stoppedAt == null),
      );
    });
    final load = widget.loadStatus ?? (id) => celautInstanceStatus(instanceId: id);
    await Future.wait([
      for (final i in mine)
        if (i.stoppedAt == null)
          load(i.instanceId).then(
            (s) {
              _set(i.instanceId, _Check.ok(s));
              unawaited((widget.topUp ?? autoTopUp).observe(i, s));
            },
            onError: (Object e) => _set(
              i.instanceId,
              _Check.failed(
                e is CelautError ? e : CelautError(kind: CelautErrorKind.protocol, message: '$e'),
              ),
            ),
          ),
    ]);
  }

  void _set(String id, _Check check) {
    if (mounted) setState(() => _checks[id] = check);
  }

  InstanceState _stateOf(InstanceListView i) {
    if (i.stoppedAt != null) return InstanceState.stopped;
    if (_notes.isStarting(i.instanceId)) return InstanceState.starting;
    final check = _checks[i.instanceId];
    if (check == null) return InstanceState.checking;
    return check.status != null ? InstanceState.running : InstanceState.unreachable;
  }

  String? _costOf(String id) => _checks[id]?.status?.costSoFarMu;

  String? _reasonOf(String id) {
    final e = _checks[id]?.error;
    return e == null ? null : CelautStrings.errorText(e.kind);
  }

  /// Open the conversation of the instance [instanceId], if it runs and has a chat slot.
  /// Else nothing opens: the list stays. The list is read from the database, so the node
  /// is not asked first.
  Future<void> openChatOf(String instanceId) async {
    List<InstanceListView> all;
    try {
      all = (widget.load ?? celautInstances)();
    } catch (_) {
      return;
    }
    for (final i in all) {
      if (i.instanceId == instanceId && i.stoppedAt == null && i.chatSlots.isNotEmpty) {
        if (mounted) await openChat(i);
        return;
      }
    }
  }

  /// Open the conversation of [instance]. [starting]: the instance has just started, and
  /// the screen waits for its service.
  ///
  /// The page shows at once and the tunnel to the chat slot opens under it: a tunnel to a
  /// far node, or over Tor, can take seconds. If the tunnel fails, the page closes and
  /// the list says why.
  Future<void> openChat(InstanceListView instance, {bool starting = false}) async {
    final slot = instance.chatSlots.first;
    final tunnel = (widget.openTunnel ?? (id, s) => celautOpenTunnel(instanceId: id, slot: s))(
            instance.instanceId, slot)
        .then<_Tunnel>(
      (port) => (port: port, error: null),
      onError: (Object e) => (
        port: null,
        error: e is CelautError ? e : CelautError(kind: CelautErrorKind.protocol, message: '$e'),
      ),
    );
    final failed = await _push<CelautError>(
      instance,
      MaterialPageRoute(
        builder: (_) => _TunnelPage(
          title: instanceTitle(instance),
          tunnel: tunnel,
          chat: (port) =>
              widget.chatPage?.call(instance, port, starting) ??
              ChatScreen(
                instance: instance,
                port: port,
                starting: starting,
                wallets: widget.wallets,
                notes: _notes,
                stopInstance: widget.stop,
              ),
        ),
      ),
    );
    if (failed != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CelautStrings.errorText(failed.kind))),
      );
    }
    if (mounted) await refresh();
  }

  Future<void> _openInfo(InstanceListView i, InstanceState state) async {
    await _push<bool>(
      i,
      MaterialPageRoute(
        builder: (_) => InstanceInfoScreen(
          instance: i,
          state: state,
          costMu: _costOf(i.instanceId),
          reason: _reasonOf(i.instanceId),
          wallets: widget.wallets,
          stop: widget.stop,
          forget: widget.forget,
          rename: widget.rename,
          notes: _notes,
        ),
      ),
    );
    // The instance may have stopped, or have a new name.
    if (mounted) await refresh();
  }

  Future<void> _tap(InstanceListView i, InstanceState state) async {
    final noInterface = i.chatSlots.isEmpty && i.webSlots.isEmpty;
    // The list with [chats] false has the ones with no interface: a tap opens their info.
    if (state == InstanceState.stopped || (noInterface && !widget.chats)) {
      await _openInfo(i, state);
    } else if (i.chatSlots.isNotEmpty) {
      await openChat(i);
    } else {
      // A web slot opens in the browser; with no slot the snack bar says that there is no
      // interface.
      await openWebInBrowser(context, i, openTunnel: widget.openTunnel);
    }
  }

  Future<void> _actions(InstanceListView i, InstanceState state) async {
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          key: const Key('chats-actions'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('chats-action-info'),
              leading: const Icon(Icons.info_outline),
              title: Text(l.chatsActionInfo),
              onTap: () => Navigator.pop(context, 'info'),
            ),
            ListTile(
              key: const Key('chats-action-rename'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.chatsRename),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              key: const Key('chats-action-move'),
              leading: const Icon(Icons.folder_outlined),
              title: Text(l.chatsGroupsMove),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            if (i.chatSlots.isNotEmpty)
              ListTile(
                key: const Key('chats-action-mute'),
                leading: Icon(
                  chatPrefs.isMuted(i.instanceId)
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(chatPrefs.isMuted(i.instanceId) ? l.chatUnmute : l.chatMute),
                onTap: () => Navigator.pop(context, 'mute'),
              ),
            if (state != InstanceState.stopped)
              ListTile(
                key: const Key('chats-action-stop'),
                leading: const Icon(Icons.stop_circle_outlined),
                title: Text(l.chatStop),
                onTap: () => Navigator.pop(context, 'stop'),
              ),
            if (state == InstanceState.stopped)
              ListTile(
                key: const Key('chats-action-delete'),
                leading: const Icon(Icons.delete_outline),
                title: Text(l.chatsDelete),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'info':
        await _openInfo(i, state);
      case 'rename':
        final renamed = await renameInstance(context, i, rename: widget.rename);
        if (renamed != null && mounted) await refresh();
      case 'move':
        await _moveToGroup(i);
      case 'mute':
        await chatPrefs.setMuted(i.instanceId, !chatPrefs.isMuted(i.instanceId));
        if (mounted) setState(() {});
      case 'stop':
        final done = await confirmAndStopInstance(
          context,
          i,
          wallets: widget.wallets,
          stop: widget.stop,
          notes: _notes,
        );
        if (done != null && mounted) await refresh();
      case 'delete':
        final deleted = await confirmAndDeleteInstance(
          context,
          i,
          forget: widget.forget,
          notes: _notes,
        );
        if (deleted) {
          await _groups.forget(i.instanceId);
          if (mounted) await refresh();
        }
    }
  }

  /// Ask for a group for [i]: one of the groups, none, or a new group.
  Future<void> _moveToGroup(InstanceListView i) async {
    final l = context.l10n;
    final current = _groups.groupOf(i.instanceId);
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            key: const Key('chats-move-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final g in _groups.groups)
                ListTile(
                  key: Key('chats-move-to-${g.id}'),
                  leading: Icon(g.id == current?.id ? Icons.folder : Icons.folder_outlined),
                  title: Text(g.name),
                  selected: g.id == current?.id,
                  onTap: () => Navigator.pop(context, g.id),
                ),
              if (current != null)
                ListTile(
                  key: const Key('chats-move-none'),
                  leading: const Icon(Icons.folder_off_outlined),
                  title: Text(l.chatsGroupsNone),
                  onTap: () => Navigator.pop(context, ''),
                ),
              ListTile(
                key: const Key('chats-move-new'),
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(l.chatsGroupsNew),
                onTap: () => Navigator.pop(context, '+'),
              ),
            ],
          ),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == '') {
      await _groups.move(i.instanceId, null);
    } else if (pick == '+') {
      final made = await askGroupName(context, title: l.chatsGroupsNew);
      if (made == null) return;
      final g = await _groups.create(made);
      if (g != null) await _groups.move(i.instanceId, g.id);
    } else {
      await _groups.move(i.instanceId, pick);
    }
  }

  Future<void> _renameGroup(ChatGroup g) async {
    final name = await askGroupName(context, title: context.l10n.chatsGroupsRename, initial: g.name);
    if (name != null) await _groups.rename(g.id, name);
  }

  Future<void> _deleteGroup(ChatGroup g) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('group-delete-dialog'),
        title: Text(l.chatsGroupsDeleteTitle(g.name)),
        content: Text(l.chatsGroupsDeleteBody),
        actions: [
          TextButton(
            key: const Key('group-delete-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('group-delete-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.chatsGroupsDelete),
          ),
        ],
      ),
    );
    if (ok == true) await _groups.delete(g.id);
  }

  /// The rows of the instances in [shown], in the flat list or in groups. In groups: each
  /// group with a header (tap to collapse, menu to rename or delete) and its rows, then
  /// the conversations in no group.
  List<Widget> _rowsOf(Iterable<InstanceListView> shown) {
    Widget row(InstanceListView i) => _InstanceRow(
          instance: i,
          state: _stateOf(i),
          costMu: _costOf(i.instanceId),
          last: _notes.lastMessage(i.instanceId),
          keepAlive: i.stoppedAt == null &&
              (widget.topUp ?? autoTopUp).planOf(i.instanceId)?.keepAlive == true,
          selected: _inPane?.instanceId == i.instanceId,
          onTap: () => _tap(i, _stateOf(i)),
          onLongPress: () => _actions(i, _stateOf(i)),
        );
    if (!_groups.grouped || _groups.groups.isEmpty) return [for (final i in shown) row(i)];
    final l = context.l10n;
    final out = <Widget>[];
    for (final g in _groups.groups) {
      final mine = [
        for (final i in shown)
          if (_groups.groupOf(i.instanceId)?.id == g.id) i,
      ];
      final collapsed = _groups.isCollapsed(g.id);
      out.add(
        GroupHeader(
          group: g,
          count: mine.length,
          collapsed: collapsed,
          onToggle: () => _groups.setCollapsed(g.id, !collapsed),
          onRename: () => _renameGroup(g),
          onDelete: () => _deleteGroup(g),
        ),
      );
      if (!collapsed) out.addAll(mine.map(row));
    }
    final rest = [
      for (final i in shown)
        if (_groups.groupOf(i.instanceId) == null) i,
    ];
    if (rest.isNotEmpty) {
      out.add(GroupHeader.plain(key: const Key('group-ungrouped'), title: l.chatsGroupsUngrouped));
      out.addAll(rest.map(row));
    }
    return out;
  }

  /// The button that shows the [hidden] stopped instances, or hides the shown ones.
  Widget? _filterButton(int hidden, int stopped) {
    final l = context.l10n;
    if (hidden > 0) {
      return TextButton.icon(
        key: const Key('chats-show-stopped'),
        onPressed: () => _filter.set(false),
        icon: const Icon(Icons.visibility_outlined, size: 18),
        label: Text(l.chatsShowStopped(hidden)),
      );
    }
    if (stopped > 0) {
      return TextButton.icon(
        key: const Key('chats-hide-stopped'),
        onPressed: () => _filter.set(true),
        icon: const Icon(Icons.visibility_off_outlined, size: 18),
        label: Text(l.chatsHideStopped),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hide = _filter.value;
    final stopped = _instances.where((i) => i.stoppedAt != null).length;
    final shown = hide ? _instances.where((i) => i.stoppedAt == null) : _instances;
    final toggle = _filterButton(hide ? stopped : 0, hide ? 0 : stopped);
    final rows = <Widget>[
      ..._rowsOf(shown),
      if (toggle != null) Center(child: Padding(padding: const EdgeInsets.all(8), child: toggle)),
    ];
    return RefreshIndicator(
      onRefresh: refresh,
      child: shown.isEmpty
          ? LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(
                    key: Key(_failed ? 'chats-empty-no-db' : 'chats-empty'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        widget.empty ?? const SizedBox.shrink(),
                        if (toggle != null) ...[const SizedBox(height: 12), toggle],
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView(
              key: const Key('chats-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              children: rows,
            ),
    );
  }
}

/// One row of the list, as a chat in a messenger: the initial of the service, its name
/// and the cost so far, the last message of this run, and the state with the node.
class _InstanceRow extends StatelessWidget {
  const _InstanceRow({
    required this.instance,
    required this.state,
    required this.costMu,
    required this.last,
    required this.onTap,
    required this.onLongPress,
    this.keepAlive = false,
    this.selected = false,
  });

  /// Its conversation is open in the pane next to the list.
  final bool selected;

  /// The instance runs until the user stops it ([AutoTopUp]).
  final bool keepAlive;

  final InstanceListView instance;
  final InstanceState state;
  final String? costMu;
  final ChatMessage? last;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final tones = HomeTones.of(context);
    final id = instance.instanceId;
    final title = instanceTitle(instance);
    final dot = switch (state) {
      InstanceState.running => tones.positive,
      InstanceState.starting => accentOf(context),
      InstanceState.unreachable => tones.negative,
      InstanceState.checking || InstanceState.stopped => tones.muted,
    };
    final preview = last == null
        ? (instance.chatSlots.isNotEmpty
            ? l.chatsNoPreview
            : instance.webSlots.isNotEmpty
                ? l.chatsWebPreview
                : l.chatsNoInterface)
        : last!.fromUser
            ? l.chatsPreviewYou(messagePreview(last!, l))
            : messagePreview(last!, l);
    final row = InkWell(
      key: Key('chats-row-$id'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            InstanceAvatar(instanceId: id),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          key: Key('chats-name-$id'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.title,
                        ),
                      ),
                      if (instance.chatSlots.isNotEmpty && chatPrefs.isMuted(id)) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.notifications_off_outlined,
                          key: Key('chats-muted-$id'),
                          size: 16,
                          color: t.muted,
                        ),
                      ],
                      if (keepAlive && state != InstanceState.stopped) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: l.celautKeepBadge,
                          child: Icon(
                            Icons.all_inclusive,
                            key: Key('chats-keep-$id'),
                            size: 16,
                            color: t.muted,
                          ),
                        ),
                      ],
                      if (state != InstanceState.stopped && (costMu ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          muOrUnknown(costMu),
                          key: Key('chats-cost-$id'),
                          style: t.secondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    key: Key('chats-preview-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.primary.copyWith(color: last == null ? t.muted : t.ink),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${instanceStateText(context, state)} · ${instance.address}',
                          key: Key('chats-state-$id'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!selected) return row;
    return Semantics(
      selected: true,
      child: ColoredBox(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07), child: row),
    );
  }
}

/// The local port of a tunnel, or why it did not open.
typedef _Tunnel = ({int? port, CelautError? error});

/// The conversation while the tunnel to its chat slot opens: the name of the instance
/// and a spinner, then the conversation in place. A failed tunnel closes the page with
/// its error.
class _TunnelPage extends StatefulWidget {
  const _TunnelPage({required this.title, required this.tunnel, required this.chat});

  final String title;
  final Future<_Tunnel> tunnel;
  final Widget Function(int port) chat;

  @override
  State<_TunnelPage> createState() => _TunnelPageState();
}

class _TunnelPageState extends State<_TunnelPage> {
  int? _port;

  @override
  void initState() {
    super.initState();
    widget.tunnel.then((tunnel) {
      if (!mounted) return;
      final error = tunnel.error;
      if (error != null) {
        Navigator.of(context).pop(error);
      } else {
        setState(() => _port = tunnel.port);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final port = _port;
    if (port != null) return widget.chat(port);
    return Scaffold(
      key: const Key('chat-connecting'),
      appBar: AppBar(titleSpacing: 0, title: Text(widget.title)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
