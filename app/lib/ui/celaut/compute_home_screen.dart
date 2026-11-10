import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_home.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/host_port.dart';
import '../../celaut/overview_cache.dart';
import '../../celaut/wallet_money.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_scene.dart';
import '../home/home_style.dart';
import '../layout.dart';
import 'client_unknown_dialog.dart';
import 'node_resources.dart';

/// The compute view (`docs/celaut/ui.md`, section 2), in the look of the Celaut landing
/// page: the Compute tab of the home screen (`docs/celaut/ui-chat-first.md`). It shows
/// only what the user acts on:
///
/// 1. one card of state: the nodes in one line (how many are ready, the compute that they
///    offer), the credit on the nodes, and the ERG of the full wallets. Each line opens
///    its detail: the Nodes screen, or the wallets list. A node that forgot the client of
///    the app shows its action here, because the user must choose;
/// 2. under it, the pages of the tab (Nodes, Services).
///
/// The instances are in the conversations (Chats tab): the page of an instance has its
/// Stop. The detail of each node (availability, reasons, credit) is on the Nodes screen. The
/// screen shows the last overview at once when it opens again, and asks the nodes in the
/// background.
class ComputeHomeScreen extends StatefulWidget {
  const ComputeHomeScreen({
    super.key,
    required this.money,
    required this.usdPerErg,
    required this.onWallets,
    this.onNodes,
    this.onSettings,
    this.load,
    this.newClient,
    this.refreshPrice,
    this.sections = const [],
  });

  /// The rows under the state: the pages of the Compute tab (Nodes, Services).
  final List<Widget> sections;

  /// Ask the oracle pool price again (it is cached for some minutes).
  final Future<void> Function()? refreshPrice;

  /// The ERG of the wallet, and the wallet gate.
  final WalletMoney money;

  /// The USD price of one ERG from the oracle pool; null if it is not known.
  final double? usdPerErg;

  /// Open the wallets list (the second level).
  final VoidCallback onWallets;

  /// Open the node list.
  final VoidCallback? onNodes;
  final VoidCallback? onSettings;

  /// The data of the overview. Tests give their own.
  final Future<ComputeOverviewView> Function()? load;

  /// Make a new client on a node that forgot the client id. Tests give their own.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  @override
  State<ComputeHomeScreen> createState() => ComputeHomeScreenState();
}

class ComputeHomeScreenState extends State<ComputeHomeScreen> {
  /// The last overview: the one of the last open of this screen at first.
  ComputeOverviewView? _data = overviewCache.value;
  bool _loading = false;
  CelautError? _error;

  /// A failure that is not a Celaut error (for example, the bridge is not ready).
  String? _failure;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// Ask the nodes again.
  Future<void> refresh() async {
    widget.refreshPrice?.call().ignore();
    setState(() {
      _loading = true;
      _error = null;
      _failure = null;
    });
    try {
      final data = await (widget.load ?? celautComputeOverview)();
      overviewCache.value = data;
      if (mounted) setState(() => _data = data);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (e) {
      if (mounted) setState(() => _failure = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clientUnknown(NodeComputeView n) async {
    final parsed = parseHostPort(n.address).value;
    if (parsed == null) return;
    final choice = await showClientUnknownChoice(
      context,
      node: NodeAddress(host: parsed.host, port: parsed.port),
      error: n.error ?? '',
      newClient: widget.newClient,
    );
    if (choice == ClientUnknownChoice.newClient && mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final page = Theme.of(context).scaffoldBackgroundColor;
    final data = _data;
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: sceneBarColor(page),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleSpacing: homeGutter,
        title: Semantics(
          header: true,
          label: CelautWordmark.name,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CellMark(size: 40),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CelautWordmark(size: 24),
                    Text(
                      l.celautHomeTagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.secondary.copyWith(fontSize: 14, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.onSettings != null)
            IconButton(
              key: const Key('compute-home-settings'),
              tooltip: l.commonSettings,
              onPressed: widget.onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ReadableWidth(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              // A thin line while the nodes are asked: the last overview stays readable.
              SizedBox(
                height: 2,
                child: _loading && data != null
                    ? const LinearProgressIndicator(key: Key('compute-home-updating'))
                    : null,
              ),
              if (_error != null)
                _Pad(
                  child: Text(
                    CelautStrings.errorText(_error!.kind),
                    key: const Key('compute-home-error'),
                    style: t.secondary.copyWith(color: rustFor(context)),
                  ),
                ),
              if (_failure != null)
                _Pad(
                  child: Text(
                    _failure!,
                    key: const Key('compute-home-failure'),
                    style: t.secondary.copyWith(color: rustFor(context)),
                  ),
                ),
              const SizedBox(height: 16),
              ..._state(context, data),
              if (widget.sections.isNotEmpty) ...[
                const SizedBox(height: 12),
                const HomeRule(),
                const SizedBox(height: 4),
                ...widget.sections,
              ],
            ],
          ),
        ),
      ),
    );
    final top = MediaQuery.paddingOf(context).top + 72;
    return ColoredBox(
      color: page,
      child: HomeScene(
        light: SceneLight.eclipse,
        lightAt: Offset(96, top + 66),
        lightRadius: 80,
        height: top + 460,
        child: scaffold,
      ),
    );
  }

  String _bytes(BytesTotalView b) => partialSum<int>(
    total: b.total,
    known: b.known,
    unknownNodes: b.unknownNodes,
    atLeast: b.atLeast,
    format: CelautStrings.bytes,
  );

  String _erg(NanoErgTotalView v) => partialSum<String>(
    total: v.total,
    known: v.known,
    unknownNodes: v.unknownNodes,
    atLeast: v.atLeast,
    format: ergTextOrUnknown,
  );

  /// The card of state: the nodes, the credit on them, and the full wallets.
  List<Widget> _state(BuildContext context, ComputeOverviewView? d) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final tones = HomeTones.of(context);
    final usd = widget.usdPerErg;
    final String nodesText;
    final Color dot;
    if (d == null) {
      nodesText = l.celautHomeLoading;
      dot = tones.muted;
    } else if (d.nodes.isEmpty) {
      nodesText = l.celautHomeNoNodes;
      dot = tones.muted;
    } else {
      final total = d.nodesCounted + d.nodesUnreachable;
      final cores = d.cpuCores;
      final parts = [
        l.celautHomeNodesReady('${d.nodesCounted}', '$total'),
        if (d.nodesCounted > 0)
          partialSum<double>(
            total: cores.total,
            known: cores.known,
            unknownNodes: cores.unknownNodes,
            atLeast: cores.atLeast,
            format: CelautStrings.cores,
          ),
        if (d.nodesCounted > 0) _bytes(d.memBytes),
      ];
      nodesText = parts.join(' · ');
      dot = d.nodesUnreachable == 0
          ? tones.positive
          : d.nodesCounted == 0
              ? tones.negative
              : rustFor(context);
    }
    final forgot = [
      for (final n in d?.nodes ?? const <NodeComputeView>[])
        if (n.clientUnknown) n,
    ];
    return [
      // The one total of the home; a tap shows how the nodes split it (issue #123).
      _Line(
        key: const Key('compute-home-nodes'),
        onTap: d == null || d.nodes.isEmpty
            ? widget.onNodes
            : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => NodeResourcesScreen(overview: d)),
                ),
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        title: nodesText,
      ),
      for (final n in forgot)
        _Pad(
          child: Row(
            key: Key('compute-home-client-unknown-row-${n.peerId}'),
            children: [
              Expanded(
                child: Text(
                  '${shorten(n.peerId, head: 8, tail: 6)}: '
                  '${CelautStrings.errorText(CelautErrorKind.clientUnknown)}',
                  style: t.secondary.copyWith(color: rustFor(context)),
                ),
              ),
              TextButton(
                key: Key('compute-home-client-unknown-${n.peerId}'),
                onPressed: () => _clientUnknown(n),
                child: Text(l.celautHomeClientUnknownAction, style: t.link),
              ),
            ],
          ),
        ),
      if (d != null && d.nodes.isNotEmpty)
        _Line(
          key: const Key('compute-home-credit'),
          onTap: widget.onNodes,
          title: l.celautHomeCreditOnNodes,
          value: _erg(d.creditNanoErg),
          detail: usdTextOf(nanoOf(d.creditNanoErg.total), usd),
        ),
      _Line(
        key: const Key('compute-home-wallets'),
        onTap: widget.onWallets,
        title: l.celautHomeWallets,
        value: widget.money.full.text,
        detail: usdTextOf(widget.money.full.exactNano, usd),
      ),
    ];
  }
}

/// Content at the side margin of the page.
class _Pad extends StatelessWidget {
  const _Pad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: homeGutter),
    child: child,
  );
}

/// One line of the card of state: a title on the left, a value and a detail on the right,
/// and an arrow when it opens something.
class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.title,
    this.value,
    this.detail,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? value;
  final String? detail;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    return InkWell(
      onTap: onTap,
      child: _Pad(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(child: Text(title, style: t.primary)),
              if (value != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(value!, textAlign: TextAlign.end, style: t.primary),
                      if (detail != null)
                        Text(detail!, textAlign: TextAlign.end, style: t.secondary),
                    ],
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 20, color: t.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
