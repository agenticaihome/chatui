import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_home.dart';
import '../../bridge/api/celaut_invite.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/host_port.dart';
import '../../celaut/invite_scan.dart';
import '../../celaut/node_health_monitor.dart';
import '../../celaut/overview_cache.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../scan_screen.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';
import 'client_unknown_dialog.dart';
import 'node_connect_screen.dart';
import 'node_status.dart';
import 'support_chat_screen.dart';

/// What the node list screen needs. The app uses [AppKnownNodes]; tests give their own.
abstract class KnownNodes {
  List<KnownNodeView> list();
  Future<KnownNodeView> add(NodeAddress node);
  void remove(String peerId);

  /// Mark a node as fully trusted, or not (`docs/celaut/env-variables.md`, section 3.2).
  void setTrusted(String peerId, bool trusted);

  /// Give a node a reputation from 0 to 100 (50 is neutral). The balancer weighs it in the
  /// order of the quotes (`docs/celaut/balancer.md`). Full trust counts as 100.
  void setPriority(String peerId, int priority);

  /// Connect from the bytes of a peer invitation (`docs/celaut/invite.md`).
  Future<InviteConnectView> connectInvite(Uint8List invite);
}

class AppKnownNodes implements KnownNodes {
  const AppKnownNodes();

  @override
  List<KnownNodeView> list() => celautKnownNodes();

  @override
  Future<KnownNodeView> add(NodeAddress node) => celautAddNode(node: node);

  @override
  void remove(String peerId) => celautRemoveNode(peerId: peerId);

  @override
  void setTrusted(String peerId, bool trusted) => celautSetNodeTrusted(peerId: peerId, trusted: trusted);

  @override
  void setPriority(String peerId, int priority) => celautSetNodePriority(peerId: peerId, priority: priority);

  @override
  Future<InviteConnectView> connectInvite(Uint8List invite) => celautConnectInvite(invite: invite);
}

/// The node list of the app (`docs/celaut/ui.md`, section 4): add a node by its address
/// or by a QR code (`docs/celaut/wire.md`, section 6), remove a node. Only these nodes are in the sums of the home screen. A removed node
/// keeps its client id and its deposits in the database, so adding it again restores
/// them.
///
/// The switch "Fully trusted" of a card marks a node of the user, or of family, friends or
/// the company: a launch with sensitive environment variables warns of the other nodes
/// (`docs/celaut/env-variables.md`, section 3.2). It also gives the node the highest
/// priority. The slider "Priority" gives each node a reputation from 0 to 100 that the
/// balancer weighs with the price; it is disabled, at 100, while the node is fully trusted.
class KnownNodesScreen extends StatefulWidget {
  const KnownNodesScreen({
    super.key,
    this.nodes = const AppKnownNodes(),
    this.newClient,
    this.scan,
    this.healthMonitor,
  });

  /// Keeps the availability of the nodes up to date while this screen is open. Tests give
  /// their own; without one the screen makes its own and stops it when it closes.
  final NodeHealthMonitor? healthMonitor;

  final KnownNodes nodes;

  /// Read a QR code: its text and its bytes, or null when the user goes back. The app
  /// opens the camera ([ScanScreen]); tests give their own.
  final Future<ScannedCode?> Function(BuildContext context)? scan;

  /// Make a new client on a node that forgot the client id. Tests give their own.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  @override
  State<KnownNodesScreen> createState() => _KnownNodesScreenState();
}

class _KnownNodesScreenState extends State<KnownNodesScreen> {
  final _addressCtrl = TextEditingController();
  late List<KnownNodeView> _list = widget.nodes.list();
  late final NodeHealthMonitor _health = widget.healthMonitor ?? NodeHealthMonitor();

  @override
  void initState() {
    super.initState();
    _health.addListener(_onHealth);
    overviewCache.addListener(_onHealth);
    _health.start();
  }

  void _onHealth() {
    if (mounted) setState(() {});
  }

  /// What the last overview of the home screen says of a node: its credit, and whether it
  /// forgot the client of the app. `null` if the overview has no data of the node yet.
  NodeComputeView? _computed(String peerId) {
    for (final n in overviewCache.value?.nodes ?? const <NodeComputeView>[]) {
      if (n.peerId == peerId) return n;
    }
    return null;
  }

  /// The detail of a node: its ids (the client id of the app is only there), its
  /// advertisement and its resources against the other nodes (issue #123).
  void _detail(KnownNodeView n) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NodeConnectScreen(
          address: n.addresses.first,
          expectedPeerId: n.peerId,
          overview: overviewCache.value,
          newClient: widget.newClient,
        ),
      ),
    );
  }

  Future<void> _clientUnknown(KnownNodeView n) async {
    if (n.addresses.isEmpty) return;
    final parsed = parseHostPort(n.addresses.first).value;
    if (parsed == null) return;
    await showClientUnknownChoice(
      context,
      node: NodeAddress(host: parsed.host, port: parsed.port),
      error: _computed(n.peerId)?.error ?? '',
      newClient: widget.newClient,
    );
  }

  /// Open the support chat with the operator of the node.
  void _support(KnownNodeView n) {
    if (n.addresses.isEmpty) return;
    final parsed = parseHostPort(n.addresses.first).value;
    if (parsed == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(
          node: NodeAddress(host: parsed.host, port: parsed.port),
          peerId: n.peerId,
        ),
      ),
    );
  }

  String? _addressError;
  bool _adding = false;
  String? _note;
  CelautError? _error;

  @override
  void dispose() {
    _health.removeListener(_onHealth);
    overviewCache.removeListener(_onHealth);
    if (widget.healthMonitor == null) {
      _health.dispose();
    } else {
      _health.stop();
    }
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final parsed = parseHostPort(_addressCtrl.text);
    if (parsed.value == null) {
      setState(
        () => _addressError = switch (parsed.error) {
          HostPortError.empty => CelautStrings.addressEmpty,
          HostPortError.port => CelautStrings.portInvalid,
          _ => CelautStrings.addressInvalid,
        },
      );
      return;
    }
    final node = NodeAddress(host: parsed.value!.host, port: parsed.value!.port);
    setState(() {
      _addressError = null;
      _adding = true;
      _error = null;
      _note = null;
    });
    try {
      await widget.nodes.add(node);
      if (!mounted) return;
      setState(() {
        _list = widget.nodes.list();
        _note = context.l10n.celautNodesAdded;
        _addressCtrl.clear();
      });
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
      if (mounted && e.kind == CelautErrorKind.clientUnknown) {
        final choice = await showClientUnknownChoice(
          context,
          node: node,
          error: e.message,
          newClient: widget.newClient,
        );
        if (choice == ClientUnknownChoice.newClient && mounted) {
          setState(() => _adding = false);
          await _add();
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// A QR code is a node address or a peer invitation of nodo (`docs/celaut/invite.md`).
  ///
  /// - An invitation connects by the best address that works on the current route.
  /// - A scanned address goes into the field and then through [_add], the same check as a
  ///   typed address.
  /// - Anything else shows the error of a bad typed address and stores nothing.
  Future<void> _scan() async {
    final scan = widget.scan ??
        (context) => Navigator.push<ScannedCode>(context, fadeRoute(const ScanScreen(binary: true)));
    final code = await scan(context);
    if (!mounted || code == null) return;
    if (looksLikeInvite(code.bytes)) {
      await _connectInvite(code.bytes!);
      return;
    }
    final parsed = parseNodeQr(code.text ?? '');
    if (parsed.value == null) {
      setState(() {
        _addressError = parsed.error == HostPortError.port
            ? CelautStrings.portInvalid
            : CelautStrings.addressInvalid;
        _note = null;
        _error = null;
        _invite = null;
      });
      return;
    }
    _addressCtrl.text = parsed.value.toString();
    await _add();
  }

  /// The result of the last invitation that did not connect, to show why.
  InviteConnectView? _invite;

  Future<void> _connectInvite(Uint8List invite) async {
    setState(() {
      _addressError = null;
      _adding = true;
      _error = null;
      _note = null;
      _invite = null;
    });
    try {
      final view = await widget.nodes.connectInvite(invite);
      if (!mounted) return;
      final node = view.node;
      if (node != null) {
        final used = view.attempts.where((a) => a.kind == InviteAttemptKind.connected);
        setState(() {
          _list = widget.nodes.list();
          _note = context.l10n.celautInviteConnected(used.isEmpty ? '' : used.first.address);
        });
        return;
      }
      setState(() => _invite = view);
      // A node that forgot the client id: the user chooses, as for a typed address.
      final forgot = view.attempts.where((a) => a.error == CelautErrorKind.clientUnknown);
      final address = forgot.isEmpty ? null : parseHostPort(forgot.first.address).value;
      if (address != null && mounted) {
        final choice = await showClientUnknownChoice(
          context,
          node: NodeAddress(host: address.host, port: address.port),
          error: forgot.first.message,
          newClient: widget.newClient,
        );
        if (choice == ClientUnknownChoice.newClient && mounted) {
          setState(() => _adding = false);
          await _connectInvite(invite);
          return;
        }
      }
    } on CelautError catch (e) {
      if (!mounted) return;
      // Bytes that are not an invitation are a bad address, as for any other QR code.
      setState(() {
        if (e.kind == CelautErrorKind.invalidInput) {
          _addressError = CelautStrings.addressInvalid;
        } else {
          _error = e;
        }
      });
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// Why an invitation did not connect: one line for each address that the app knows.
  Widget _inviteFailure(BuildContext context, InviteConnectView view) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return SoftCard(
      child: Column(
        key: const Key('nodes-invite-failed'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.celautInviteFailedTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (view.attempts.isEmpty) Text(l.celautInviteNoAddress),
          // An address that was not needed (another one connected first, #139) has no
          // reason to show; the card shows only when no address worked.
          for (final a in view.attempts.where((a) => a.kind != InviteAttemptKind.notNeeded)) ...[
            Text(a.address, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13)),
            Text(
              switch (a.kind) {
                InviteAttemptKind.onionNeedsProxy => l.celautInviteOnionNeedsProxy,
                InviteAttemptKind.privateOverTor => l.celautInvitePrivateOverTor,
                _ => CelautStrings.errorText(a.error ?? CelautErrorKind.unreachable),
              },
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  void _setTrusted(KnownNodeView n, bool trusted) {
    try {
      widget.nodes.setTrusted(n.peerId, trusted);
      setState(() {
        _list = widget.nodes.list();
        _error = null;
      });
    } on CelautError catch (e) {
      setState(() => _error = e);
    }
  }

  /// The priority that the user is dragging to, by node. It is saved when the drag ends,
  /// not at every step: a write of the database is an encrypted file.
  final _draft = <String, int>{};

  void _setPriority(KnownNodeView n, int priority) {
    try {
      widget.nodes.setPriority(n.peerId, priority);
      setState(() {
        _draft.remove(n.peerId);
        _list = widget.nodes.list();
        _error = null;
      });
    } on CelautError catch (e) {
      setState(() => _error = e);
    }
  }

  void _remove(KnownNodeView n) {
    try {
      widget.nodes.remove(n.peerId);
      setState(() {
        _list = widget.nodes.list();
        _note = context.l10n.celautNodesRemoved;
        _error = null;
      });
    } on CelautError catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return SettingsPage(
      title: l.celautNodesTitle,
      children: [
        SettingsNote(l.celautNodesIntro),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('nodes-address'),
                controller: _addressCtrl,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: CelautStrings.addressLabel,
                  hintText: CelautStrings.addressHint,
                  errorText: _addressError,
                  suffixIcon: IconButton(
                    key: const Key('nodes-scan'),
                    tooltip: l.celautNodesScan,
                    onPressed: _adding ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                ),
                onSubmitted: (_) => _adding ? null : _add(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('nodes-add'),
                onPressed: _adding ? null : _add,
                child: Text(_adding ? CelautStrings.connecting : l.celautNodesAdd),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_note != null) SoftCard(child: Text(_note!, key: const Key('nodes-note'))),
        if (_invite != null) _inviteFailure(context, _invite!),
        if (_error != null)
          SoftCard(
            child: Text(
              '${CelautStrings.errorText(_error!.kind)}\n${_error!.message}',
              key: const Key('nodes-error'),
              style: TextStyle(color: rustFor(context)),
            ),
          ),
        const SizedBox(height: 8),
        if (_list.isEmpty)
          SoftCard(child: Text(l.celautNodesEmpty, style: TextStyle(color: muted))),
        if (_list.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('nodes-check-now'),
              onPressed: _health.checking ? null : _health.checkNow,
              child: Text(_health.checking ? l.celautNodeChecking : l.celautNodesCheckNow),
            ),
          ),
        for (final n in _list)
          SoftCard(
            child: Row(
              key: Key('nodes-row-${n.peerId}'),
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shorten(n.peerId, head: 10, tail: 8)),
                      Text(
                        n.addresses.isEmpty ? l.celautUnknown : n.addresses.join(', '),
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      Text(
                        l.celautNodesDeposited(formatErg(n.depositedNanoErg.toInt())),
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      Text(
                        l.celautNodeCredit(muOrUnknown(_computed(n.peerId)?.creditMu)),
                        key: Key('nodes-credit-${n.peerId}'),
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      ...nodeStatusLines(
                        context,
                        peerId: n.peerId,
                        health: _health.of(n.peerId),
                        checking: _health.checking,
                      ),
                      SwitchListTile(
                        key: Key('nodes-trusted-${n.peerId}'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: n.trusted,
                        onChanged: (v) => _setTrusted(n, v),
                        title: Text(l.celautNodesTrusted),
                        subtitle: Text(l.celautNodesTrustedHint, style: TextStyle(fontSize: 12, color: muted)),
                      ),
                      Text(
                        n.trusted ? l.celautNodesPriorityFullTrust : l.celautNodesPriority(_draft[n.peerId] ?? n.priority),
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                      Slider(
                        key: Key('nodes-priority-${n.peerId}'),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        // A node of full trust shows 100 and cannot be moved.
                        value: (n.trusted ? 100 : _draft[n.peerId] ?? n.priority).clamp(0, 100).toDouble(),
                        label: '${_draft[n.peerId] ?? n.priority}',
                        onChanged: n.trusted ? null : (v) => setState(() => _draft[n.peerId] = v.round()),
                        onChangeEnd: n.trusted ? null : (v) => _setPriority(n, v.round()),
                      ),
                      Text(l.celautNodesPriorityHint, style: TextStyle(fontSize: 12, color: muted)),
                      if (_computed(n.peerId)?.clientUnknown ?? false) ...[
                        Text(
                          CelautStrings.errorText(CelautErrorKind.clientUnknown),
                          style: TextStyle(fontSize: 12.5, color: rustFor(context)),
                        ),
                        TextButton(
                          key: Key('nodes-client-unknown-${n.peerId}'),
                          onPressed: () => _clientUnknown(n),
                          child: Text(l.celautHomeClientUnknownAction),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      key: Key('nodes-detail-${n.peerId}'),
                      tooltip: l.celautNodesDetail,
                      onPressed: n.addresses.isEmpty ? null : () => _detail(n),
                      icon: const Icon(Icons.info_outline),
                    ),
                    IconButton(
                      key: Key('nodes-support-${n.peerId}'),
                      tooltip: l.celautNodesSupport,
                      onPressed: n.addresses.isEmpty ? null : () => _support(n),
                      icon: const Icon(Icons.support_agent),
                    ),
                    TextButton(
                      key: Key('nodes-remove-${n.peerId}'),
                      onPressed: () => _remove(n),
                      child: Text(l.celautNodesRemove),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
