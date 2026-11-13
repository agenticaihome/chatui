import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_home.dart';
import '../../bridge/api/celaut_service.dart';
import '../../bridge/api/celaut_spending.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/conversations.dart';
import '../../celaut/host_port.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';
import 'node_connect_screen.dart';

/// The calls of the balance and the spending (issue #136). Tests give their own.
class SpendingApi {
  const SpendingApi();

  NodeSpendingView spending(String peerId) => celautNodeSpending(peerId: peerId);
  List<NodeSpendingView> overview() => celautSpendingOverview();
  List<InstanceListView> instances() => celautInstances();
  Future<String> credit(NodeAddress node) => celautNodeCredit(node: node);
  Future<SpendingQuoteView> quoteNode(NodeAddress node) => celautQuoteNodeStatement(node: node);
  Future<NodeSpendingView> readNode(NodeAddress node, String maxMu) =>
      celautReadNodeStatement(node: node, maxMu: maxMu);
  Future<SpendingQuoteView> quoteInstance(String instanceId) =>
      celautQuoteInstanceStatement(instanceId: instanceId);
  Future<AccountSpendingView> readInstance(String instanceId, String maxMu) =>
      celautReadInstanceStatement(instanceId: instanceId, maxMu: maxMu);
}

/// The date of a Unix time in seconds, or "unknown" for 0.
String _date(int seconds) =>
    seconds <= 0 ? appL10n.celautUnknown : formatTxTime(seconds * 1000);

/// The name of a kind of movement, for a person; the kind as the node wrote it if the app
/// does not know it.
String spendKindLabel(AppLocalizations l, String kind) => switch (kind) {
      'maintenance' => l.celautSpendKindMaintenance,
      'tunnel' => l.celautSpendKindTunnel,
      'build' => l.celautSpendKindBuild,
      'resource_change' => l.celautSpendKindResourceChange,
      'statement_query' => l.celautSpendKindStatement,
      'child_start' => l.celautSpendKindChildStart,
      'start' => l.celautSpendKindStart,
      'top_up' => l.celautSpendKindTopUp,
      'withdrawal' => l.celautSpendKindWithdrawal,
      'refund' => l.celautSpendKindRefund,
      'deposit' => l.celautSpendKindDeposit,
      'credit' => l.celautSpendKindCredit,
      'debit' => l.celautSpendKindDebit,
      _ => kind,
    };

/// One flow of a kind: "−X" for what left, "+Y" for what came in, or both.
String _flowText(KindFlowView k) {
  final parts = [
    if (k.outMu != '0') '−${muOrUnknown(k.outMu)}',
    if (k.inMu != '0') '+${muOrUnknown(k.inMu)}',
  ];
  return parts.join(' · ');
}

/// "X, since <date>" for a sum that starts after the first movement of the account.
String spentText(AccountSpendingView a) {
  final value = muOrUnknown(a.spentMu);
  if (a.spentMu.isEmpty || !a.partial) return value;
  return appL10n.celautSpendSince(value, _date(a.since.toInt()));
}

/// Ask the user before a paid read: the node and the most that it can cost.
Future<bool> confirmStatementRead(
  BuildContext context, {
  required String node,
  required String maxMu,
  String? title,
}) async {
  final l = context.l10n;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('spend-read-confirm'),
      title: Text(title ?? l.celautSpendReadTitle),
      content: Text(l.celautSpendReadBody(node, muOrUnknown(maxMu))),
      actions: [
        TextButton(
          key: const Key('spend-read-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.celautSendCancel),
        ),
        FilledButton(
          key: const Key('spend-read-ok'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.celautSpendReadConfirm),
        ),
      ],
    ),
  );
  return yes == true;
}

/// "Balance and spending" on the detail of a node (issue #136): the balance of the client
/// now (free), and what the last statement read says: the balance then, what was spent and
/// what the reads cost. The split by instance is one tap away (closed). A read costs MU:
/// it happens only on a tap, after a question with the most that it can cost.
class NodeSpendingSection extends StatefulWidget {
  const NodeSpendingSection({
    super.key,
    required this.peerId,
    required this.address,
    this.api = const SpendingApi(),
  });

  final String peerId;

  /// The address that the user opened (`host:port`).
  final String address;
  final SpendingApi api;

  @override
  State<NodeSpendingSection> createState() => _NodeSpendingSectionState();
}

class _NodeSpendingSectionState extends State<NodeSpendingSection> {
  late NodeSpendingView _view = widget.api.spending(widget.peerId);
  String? _credit;
  bool _creditFailed = false;
  bool _busy = false;
  String? _error;

  /// The quote of the next read; null while the app asks for it.
  SpendingQuoteView? _quote;

  NodeAddress? get _node {
    final p = parseHostPort(widget.address).value;
    return p == null ? null : NodeAddress(host: p.host, port: p.port);
  }

  @override
  void initState() {
    super.initState();
    _loadCredit();
    _loadQuote();
  }

  Future<void> _loadCredit() async {
    final node = _node;
    if (node == null) return;
    try {
      final credit = await widget.api.credit(node);
      if (mounted) setState(() => _credit = credit);
    } on Object {
      if (mounted) setState(() => _creditFailed = true);
    }
  }

  Future<void> _loadQuote() async {
    final node = _node;
    if (node == null) return;
    try {
      final q = await widget.api.quoteNode(node);
      if (mounted) setState(() => _quote = q);
    } on Object {
      // No quote: the button stays off.
    }
  }

  Future<void> _read() async {
    final l = context.l10n;
    final node = _node;
    final max = _quote?.maxMu;
    if (node == null || max == null) return;
    if (!await confirmStatementRead(context, node: widget.address, maxMu: max) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final view = await widget.api.readNode(node, max);
      if (!mounted) return;
      setState(() => _view = view);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.celautSpendReadDone)));
    } on CelautError catch (e) {
      if (mounted) {
        setState(() => _error = l.celautSpendReadFailed(
            e.kind == CelautErrorKind.protocol || e.kind == CelautErrorKind.invalidInput
                ? e.message
                : CelautStrings.errorText(e.kind)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // The read is a movement: the balance and the next quote changed.
    await Future.wait([_loadCredit(), _loadQuote()]);
  }

  void _openInstance(InstanceSpendingView i, String name) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InstanceCostsSheet(
        instance: i,
        name: name,
        node: widget.address,
        api: widget.api,
        onRead: () => setState(() => _view = widget.api.spending(widget.peerId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = ArgusColors.of(context);
    final v = _view;
    final a = v.account;
    final read = a.readAt > 0;
    final names = {for (final i in widget.api.instances()) i.instanceId: instanceTitle(i)};
    Widget pair(String label, String value, Key key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  key: key,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 14, color: colors.muted),
                ),
              ),
            ],
          ),
        );
    final quote = _quote;
    return Column(
      key: const Key('node-spending'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.celautSpendTitle),
        const SizedBox(height: 10),
        SoftCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pair(
                  l.celautSpendBalanceNow,
                  _credit != null ? muOrUnknown(_credit) : (_creditFailed ? l.celautUnknown : '…'),
                  const Key('node-spending-credit'),
                ),
                pair(l.celautSpendSpent, read ? spentText(a) : l.celautUnknown, const Key('node-spending-spent')),
                if (read) ...[
                  pair(l.celautSpendBalanceRead, muOrUnknown(a.balanceMu), const Key('node-spending-balance')),
                  pair(l.celautSpendReads, muOrUnknown(v.statementsMu), const Key('node-spending-reads')),
                  if (v.startingMu.isNotEmpty && v.startingMu != '0')
                    Text(l.celautSpendStarting(muOrUnknown(v.startingMu)), style: TextStyle(fontSize: 12.5, color: colors.muted)),
                  pair(l.celautSpendLastRead, _date(a.readAt.toInt()), const Key('node-spending-read-at')),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(l.celautSpendNeverRead,
                        key: const Key('node-spending-never'), style: TextStyle(fontSize: 12.5, color: colors.muted)),
                  ),
                if (a.partial)
                  Text(l.celautSpendPartial, key: const Key('node-spending-partial'),
                      style: TextStyle(fontSize: 12.5, color: colors.muted)),
                if (a.incomplete)
                  Text(l.celautSpendIncomplete, key: const Key('node-spending-incomplete'),
                      style: TextStyle(fontSize: 12.5, color: rustFor(context))),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_error!, key: const Key('node-spending-error'),
                        style: TextStyle(fontSize: 12.5, color: rustFor(context))),
                  ),
                const SizedBox(height: 8),
                if (quote != null && quote.maxMu == null)
                  Text(l.celautSpendNoRates, key: const Key('node-spending-no-rates'),
                      style: TextStyle(fontSize: 12.5, color: colors.muted))
                else
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      key: const Key('node-spending-read'),
                      onPressed: _busy || quote?.maxMu == null || _node == null ? null : _read,
                      icon: _busy
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.receipt_long_outlined),
                      label: Text(a.incomplete ? l.celautSpendReadMore : l.celautSpendRead),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SettingsNote(l.celautSpendNote),
        if (v.instances.isNotEmpty)
          SoftCard(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const Key('node-spending-instances'),
                title: Text(l.celautSpendInstances(v.instances.length),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                children: [
                  for (final i in v.instances)
                    _InstanceRow(
                      instance: i,
                      name: names[i.instanceId] ?? shorten(i.instanceRef, head: 6, tail: 4),
                      onTap: () => _openInstance(i, names[i.instanceId] ?? shorten(i.instanceRef, head: 6, tail: 4)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InstanceRow extends StatelessWidget {
  const _InstanceRow({required this.instance, required this.name, required this.onTap});

  final InstanceSpendingView instance;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = ArgusColors.of(context);
    final i = instance;
    final state = i.instanceId.isEmpty
        ? l.celautSpendDeleted
        : i.running
            ? l.celautSpendRunning
            : l.celautSpendStopped;
    final spent = i.movedMu.isEmpty ? l.celautSpendNotRead : muOrUnknown(i.movedMu);
    return InkWell(
      key: Key('node-spending-instance-${i.instanceRef}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(state, style: TextStyle(fontSize: 12.5, color: colors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(spent, style: TextStyle(fontSize: 14, color: colors.muted)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
}

/// The spending of one instance (issue #136): what moved to it (from the statement of the
/// client), and, after a read of its own statement, the part of each charge: resources,
/// traffic, build and the rest.
class InstanceCostsSheet extends StatefulWidget {
  const InstanceCostsSheet({
    super.key,
    required this.instance,
    required this.name,
    required this.node,
    this.api = const SpendingApi(),
    this.onRead,
  });

  final InstanceSpendingView instance;
  final String name;
  final String node;
  final SpendingApi api;

  /// The app read the statement of the instance.
  final VoidCallback? onRead;

  @override
  State<InstanceCostsSheet> createState() => _InstanceCostsSheetState();
}

class _InstanceCostsSheetState extends State<InstanceCostsSheet> {
  late AccountSpendingView? _costs = widget.instance.costs;
  SpendingQuoteView? _quote;
  bool _busy = false;
  String? _error;

  bool get _known => widget.instance.instanceId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_known) _loadQuote();
  }

  Future<void> _loadQuote() async {
    try {
      final q = await widget.api.quoteInstance(widget.instance.instanceId);
      if (mounted) setState(() => _quote = q);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = CelautStrings.errorText(e.kind));
    } on Object {
      // No quote: no read.
    }
  }

  Future<void> _read() async {
    final l = context.l10n;
    final max = _quote?.maxMu;
    if (max == null) return;
    final yes = await confirmStatementRead(
      context,
      node: widget.node,
      maxMu: max,
      title: l.celautSpendReadCostsTitle,
    );
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final costs = await widget.api.readInstance(widget.instance.instanceId, max);
      if (!mounted) return;
      setState(() => _costs = costs);
      widget.onRead?.call();
    } on CelautError catch (e) {
      if (mounted) {
        setState(() => _error = l.celautSpendReadFailed(
            e.kind == CelautErrorKind.protocol || e.kind == CelautErrorKind.invalidInput
                ? e.message
                : CelautStrings.errorText(e.kind)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _loadQuote();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = ArgusColors.of(context);
    final i = widget.instance;
    final c = _costs;
    Widget pair(String label, String value, {Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
              const SizedBox(width: 12),
              Flexible(
                child: Text(value, key: key, textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 14, color: colors.muted)),
              ),
            ],
          ),
        );
    return Padding(
      key: Key('instance-costs-${i.instanceRef}'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            pair(l.celautSpendMovedRow, i.movedMu.isEmpty ? l.celautUnknown : muOrUnknown(i.movedMu),
                key: const Key('instance-costs-moved')),
            const SizedBox(height: 8),
            Text(l.celautSpendCosts.toUpperCase(),
                style: TextStyle(fontSize: 12, letterSpacing: 1, color: colors.muted)),
            if (c == null || c.readAt == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(l.celautSpendCostsNote, style: TextStyle(fontSize: 12.5, color: colors.muted)),
              )
            else ...[
              pair(l.celautSpendSpent, spentText(c), key: const Key('instance-costs-spent')),
              for (final k in c.kinds)
                if (k.kind != 'stop' && k.kind != 'child_bound')
                  pair(spendKindLabel(l, k.kind), _flowText(k), key: Key('instance-costs-kind-${k.kind}')),
              pair(l.celautSpendBalanceRead, muOrUnknown(c.balanceMu)),
              pair(l.celautSpendLastRead, _date(c.readAt.toInt())),
              if (c.partial) Text(l.celautSpendPartial, style: TextStyle(fontSize: 12.5, color: colors.muted)),
              if (c.incomplete)
                Text(l.celautSpendIncomplete, style: TextStyle(fontSize: 12.5, color: rustFor(context))),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, key: const Key('instance-costs-error'),
                    style: TextStyle(fontSize: 12.5, color: rustFor(context))),
              ),
            if (_known) ...[
              const SizedBox(height: 12),
              if (_quote != null && _quote!.maxMu == null)
                Text(l.celautSpendNoRates, style: TextStyle(fontSize: 12.5, color: colors.muted))
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const Key('instance-costs-read'),
                    onPressed: _busy || _quote?.maxMu == null ? null : _read,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(c != null && c.incomplete ? l.celautSpendReadMore : l.celautSpendReadCosts),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The split of the summary line of the home screen (issue #136): for each node, the
/// balance now and what the last statement read says it spent. A tap opens the detail of
/// the node, where the user can read the statement.
class NodeBalancesScreen extends StatelessWidget {
  const NodeBalancesScreen({super.key, required this.overview, this.api = const SpendingApi()});

  final ComputeOverviewView overview;
  final SpendingApi api;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = ArgusColors.of(context);
    final spending = {for (final s in api.overview()) s.peerId: s};
    return SettingsPage(
      title: l.celautHomeBalancesTitle,
      children: [
        SettingsNote(l.celautHomeBalancesNote),
        SoftCard(
          child: Column(
            children: [
              for (final n in overview.nodes)
                InkWell(
                  key: Key('node-balance-${n.peerId}'),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => NodeConnectScreen(
                        address: n.address,
                        expectedPeerId: n.peerId,
                        overview: overview,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.address.isEmpty ? shorten(n.peerId) : n.address,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                              const SizedBox(height: 2),
                              Text(
                                l.celautHomeSpent(
                                  spending[n.peerId] == null || spending[n.peerId]!.account.readAt == 0
                                      ? l.celautUnknown
                                      : spentText(spending[n.peerId]!.account),
                                ),
                                key: Key('node-balance-spent-${n.peerId}'),
                                style: TextStyle(fontSize: 12.5, color: colors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(muOrUnknown(n.creditMu), key: Key('node-balance-credit-${n.peerId}'),
                            style: TextStyle(fontSize: 14, color: colors.muted)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 18, color: colors.muted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The spending of the app on all the nodes of [overview], in nanoERG at the rate of each
/// node, from the last statement read on each: the sum, or "at least" the known part when a
/// node was never read or has no rate, or null when none is known. Also the number of nodes
/// whose spending is unknown.
({BigInt? total, BigInt known, int unknown}) spentNanoErg(
  ComputeOverviewView overview,
  List<NodeSpendingView> spending,
) {
  final byPeer = {for (final s in spending) s.peerId: s};
  var known = BigInt.zero;
  var unknown = 0;
  var any = false;
  for (final n in overview.nodes) {
    final s = byPeer[n.peerId];
    final mu = s == null || s.account.readAt == 0 ? null : BigInt.tryParse(s.account.spentMu);
    final rate = BigInt.tryParse(n.muPerNanoErg ?? '');
    if (mu == null || rate == null || rate <= BigInt.zero) {
      unknown++;
      continue;
    }
    any = true;
    known += (mu < BigInt.zero ? BigInt.zero : mu) ~/ rate;
  }
  return (total: unknown == 0 && any ? known : null, known: known, unknown: any ? unknown : overview.nodes.length);
}
