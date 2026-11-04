import 'dart:async';

import 'package:flutter/material.dart';

import '../../bridge/api/celaut_service.dart';
import '../../celaut/auto_top_up.dart';
import '../../celaut/chat_groups.dart';
import '../../celaut/conversations.dart';
import '../../celaut/launcher.dart';
import '../../celaut/payers.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_scene.dart';
import '../home/home_style.dart';
import '../layout.dart';
import 'deposit_screen.dart';
import 'group_widgets.dart';
import 'instance_list.dart';
import 'run_service_screen.dart';
import 'run_service_section.dart' show StartedCall;

/// The Chats tab of the home screen, chat first, as Telegram and WhatsApp
/// (`docs/celaut/ui-chat-first.md`):
///
/// - the list of conversations: each row is an instance whose interface has a chat slot
///   (`docs/celaut/chat.md`, section 3);
/// - the pencil button opens "New conversation": the skills of the catalog and the
///   service files, then the confirmation, the wallet, the launch, and the conversation.
///
/// The other tabs of the bottom bar ([HomeTabs]) hold the rest of the app.
///
/// On a wide window ([AppLayout.twoPane]) the list and the open conversation show side by
/// side, as a messenger on a tablet or a desktop: a conversation, and the info page of a
/// stopped instance, open in the pane next to the list, which keeps them as a page stack
/// of its own.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    this.wallets = const AppFullWallets(),
    this.notes,
    this.newClient,
    this.list,
    this.runPage,
    this.onConversation,
    this.topUp,
    this.openDeposit,
    this.groups,
    this.active = true,
  });

  /// The tab shows. On a wide window, Back closes the conversation of the pane only while
  /// the tab shows.
  final bool active;

  /// The groups of the conversations. Tests give their own.
  final ChatGroups? groups;

  /// The automatic top-up: a top-up that needs a deposit shows as a banner on the list.
  /// Tests give their own.
  final AutoTopUp? topUp;

  /// Open the deposit screen. Tests give their own.
  final VoidCallback? openDeposit;

  final FullWallets wallets;
  final ConversationNotes? notes;

  /// Make a new client on a node that forgot the client id.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  /// The list. Tests give their own, with fake calls.
  final InstanceList Function(GlobalKey<InstanceListState> key, Widget empty)? list;

  /// The picker of "New conversation" and "Services". Tests give their own; it gets the
  /// title and what to do after a start.
  final Widget Function(String title, StartedCall onStarted)? runPage;

  /// A conversation opens after a start: the home screen shows this tab under it.
  final VoidCallback? onConversation;

  @override
  State<ChatsScreen> createState() => ChatsScreenState();
}

class ChatsScreenState extends State<ChatsScreen> {
  final _list = GlobalKey<InstanceListState>();
  final _pane = GlobalKey<NavigatorState>();
  late final ConversationNotes _notes = widget.notes ?? conversationNotes;
  late final ChatGroups _groups = widget.groups ?? chatGroups;

  /// Read the list again (after a change on another screen).
  Future<void> refresh() async => _list.currentState?.refresh();

  /// Open the conversation of the instance [instanceId], if it runs.
  Future<void> openChat(String instanceId) async => _list.currentState?.openChatOf(instanceId);

  /// The picker of services, for "New conversation", "Services" and the Run button of
  /// the Compute tab.
  Widget runPage(String title) =>
      widget.runPage?.call(title, _started) ??
      RunServiceScreen(
        title: title,
        wallets: widget.wallets,
        newClient: widget.newClient,
        onStarted: _started,
      );

  /// A service started from the picker: back to the list, and into the conversation,
  /// as a messenger does after "New chat". An instance without a chat slot is in
  /// Compute, under Services, in the page of the service.
  Future<void> _started(LaunchOutcome outcome, String serviceId, String? name) async {
    final instance = outcome.instance;
    final chat = instance.chatSlots.isNotEmpty;
    if (chat) _notes.markStarting(instance.instanceId);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await refresh();
    if (!mounted) return;
    if (!chat) {
      final quote = outcome.quote;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.chatsStartedOther(
              '${quote.address.host}:${quote.address.port}',
            ),
          ),
        ),
      );
      return;
    }
    widget.onConversation?.call();
    await _list.currentState?.openChat(
      instanceOfLaunch(outcome, serviceId, name),
      starting: true,
    );
  }

  Future<void> _newChat() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => runPage(context.l10n.chatsNewTitle)),
    );
    if (mounted) await refresh();
  }

  Future<void> _newGroup() async {
    final name = await askGroupName(context, title: context.l10n.chatsGroupsNew);
    if (name != null) await _groups.create(name);
  }

  /// The menu of the list: show the groups or one flat list, and make a group.
  Widget _groupsMenu() {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: _groups,
      builder: (context, _) => PopupMenuButton<String>(
        key: const Key('chats-groups-menu'),
        tooltip: l.chatsGroupsMenu,
        icon: const Icon(Icons.folder_open_outlined),
        onSelected: (v) => v == 'view' ? _groups.setGrouped(!_groups.grouped) : _newGroup(),
        itemBuilder: (_) => [
          PopupMenuItem(
            key: const Key('chats-groups-view'),
            value: 'view',
            child: Text(_groups.grouped ? l.chatsGroupsViewFlat : l.chatsGroupsViewGrouped),
          ),
          PopupMenuItem(
            key: const Key('chats-groups-new'),
            value: 'new',
            child: Text(l.chatsGroupsNew),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final empty = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 56, color: t.muted),
          const SizedBox(height: 16),
          Text(l.chatsEmptyTitle, style: t.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(l.chatsEmptyBody, style: t.secondary, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('chats-empty-new'),
            onPressed: _newChat,
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.chatsNewTitle),
          ),
        ],
      ),
    );
    final twoPane = AppLayout.twoPane(context);
    final list = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 16,
        actions: [_groupsMenu()],
        title: Semantics(
          header: true,
          label: CelautWordmark.name,
          excludeSemantics: true,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CellMark(size: 28),
              SizedBox(width: 10),
              CelautWordmark(size: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('chats-new'),
        tooltip: l.chatsNewTitle,
        onPressed: _newChat,
        child: const Icon(Icons.edit_outlined),
      ),
      body: Column(
        children: [
          _TopUpBanner(topUp: widget.topUp ?? autoTopUp, openDeposit: widget.openDeposit),
          Expanded(
            child: widget.list?.call(_list, empty) ??
                InstanceList(
                  key: _list,
                  chats: true,
                  empty: empty,
                  wallets: widget.wallets,
                  notes: _notes,
                  groups: _groups,
                  bottomPadding: 88,
                ),
          ),
        ],
      ),
    );
    return ChatPane(
      navigator: twoPane ? _pane : null,
      child: twoPane ? _twoPanes(SceneBackdrop(child: list)) : SceneBackdrop(child: list),
    );
  }

  /// The list and, next to it, the pane where the conversations open.
  Widget _twoPanes(Widget list) {
    return Row(
      children: [
        SizedBox(
          width: AppLayout.listPaneWidth,
          child: MediaQuery.removePadding(context: context, removeRight: true, child: list),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            // Back closes what the pane shows before it leaves the app.
            child: NavigatorPopHandler<Object?>(
              enabled: widget.active,
              // The callback runs on a Back that another scope of the page held too (the
              // tabs, on another tab): only the shown tab closes its pane.
              onPopWithResult: (_) {
                if (widget.active) _pane.currentState?.maybePop();
              },
              child: Navigator(
                key: _pane,
                onGenerateRoute: (settings) => MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const _NoConversation(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pane next to the list while no conversation is open in it.
class _NoConversation extends StatelessWidget {
  const _NoConversation();

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    return Scaffold(
      key: const Key('chats-pane-empty'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 56, color: t.muted),
              const SizedBox(height: 16),
              Text(context.l10n.chatsPaneEmpty, style: t.secondary, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// A top-up that the app could not make, for lack of credit on the node ([TopUpNeed]).
/// The app does not pay a node by itself: Deposit opens the deposit screen, where the
/// user chooses the amount and confirms it with the fingerprint or the screen lock.
class _TopUpBanner extends StatelessWidget {
  const _TopUpBanner({required this.topUp, this.openDeposit});

  final AutoTopUp topUp;
  final VoidCallback? openDeposit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: topUp,
      builder: (context, _) {
        final need = topUp.need;
        if (need == null) return const SizedBox.shrink();
        final l = context.l10n;
        return MaterialBanner(
          key: const Key('top-up-need'),
          leading: const Icon(Icons.savings_outlined),
          content: Text(need.budget ? l.celautKeepNeedBudget(need.address) : l.celautKeepNeed(need.address)),
          actions: [
            TextButton(
              key: const Key('top-up-need-dismiss'),
              onPressed: topUp.dismissNeed,
              child: Text(l.celautTopUpNeedLater),
            ),
            if (!need.budget)
              TextButton(
                key: const Key('top-up-need-deposit'),
                onPressed: () {
                  topUp.dismissNeed();
                  final open = openDeposit;
                  if (open != null) {
                    open();
                  } else {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const DepositScreen()),
                    );
                  }
                },
                child: Text(l.celautTopUpNeedDeposit),
              ),
          ],
        );
      },
    );
  }
}
