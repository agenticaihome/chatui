import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_home.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_strings.dart';
import '../../l10n/l10n.dart';
import '../../celaut/host_port.dart';
import '../../theme/argus_theme.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';
import 'client_unknown_dialog.dart';
import 'id_row.dart';
import 'node_resources.dart';

/// Connect to a Celaut node and show its advertisement, after the identity and signature
/// checks. From the node list it is the detail of a node ([address] given: it connects at
/// once). The ids show in short form, with Copy and "Show full id"; the client id of the app
/// shows only here, never in the node list (issue #123). The resources show as one summary
/// line, with a bar for each resource when [overview] gives the other nodes; the
/// architectures and the benchmark are in a closed "Details" part.
class NodeConnectScreen extends StatefulWidget {
  const NodeConnectScreen({
    super.key,
    this.address,
    this.expectedPeerId,
    this.overview,
    this.clientIdOf,
    this.newClient,
  });

  /// The node to show at once (`host:port`); null for an empty form.
  final String? address;

  /// The identity that the node must prove, if known.
  final String? expectedPeerId;

  /// The last overview of the home screen: the bars compare this node with the others.
  final ComputeOverviewView? overview;

  /// Read the client id of the app on a node (null: no client yet). Tests give their own.
  final String? Function(String peerId)? clientIdOf;

  /// Make a new client on a node that forgot the client id. Tests give their own.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  @override
  State<NodeConnectScreen> createState() => _NodeConnectScreenState();
}

class _NodeConnectScreenState extends State<NodeConnectScreen> {
  final _addressCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  bool _busy = false;
  PeerInfoView? _info;
  CelautErrorKind? _errorKind;
  String? _errorDetail;
  String? _inputError;

  /// The client id of the app on the node of [_info]; null if the app has none yet.
  String? _clientId;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _addressCtrl.text = address;
      _expectedCtrl.text = widget.expectedPeerId ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connect();
      });
    }
  }

  String? _readClientId(String peerId) {
    try {
      return (widget.clientIdOf ?? (id) => celautClientId(peerId: id))(peerId);
    } catch (_) {
      return null;
    }
  }

  /// The node forgot the client id: the usual choice, then connect again after a new client.
  Future<void> _forgotten() async {
    final parsed = parseHostPort(_addressCtrl.text).value;
    if (parsed == null) return;
    final choice = await showClientUnknownChoice(
      context,
      node: NodeAddress(host: parsed.host, port: parsed.port),
      error: _errorDetail ?? '',
      newClient: widget.newClient,
    );
    if (choice == ClientUnknownChoice.newClient && mounted) await _connect();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _expectedCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final parsed = parseHostPort(_addressCtrl.text);
    final expected = _expectedCtrl.text.trim().toLowerCase();
    String? inputError;
    if (parsed.error == HostPortError.empty) {
      inputError = CelautStrings.addressEmpty;
    } else if (parsed.error == HostPortError.port) {
      inputError = CelautStrings.portInvalid;
    } else if (parsed.error != null) {
      inputError = CelautStrings.addressInvalid;
    } else if (expected.isNotEmpty && !RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
      inputError = CelautStrings.expectedInvalid;
    }
    if (inputError != null || parsed.value == null) {
      setState(() {
        _inputError = inputError;
        _info = null;
        _errorKind = null;
      });
      return;
    }
    final target = parsed.value!;
    setState(() {
      _busy = true;
      _inputError = null;
      _info = null;
      _errorKind = null;
      _errorDetail = null;
    });
    try {
      // The client id and the advertisement go into the Celaut database of the app.
      final info = await celautPeerInfo(
        host: target.host,
        port: target.port,
        expectedPeerId: expected.isEmpty ? null : expected,
      );
      if (!mounted) return;
      setState(() {
        _info = info;
        _clientId = _readClientId(info.peerId);
      });
    } on CelautError catch (e) {
      if (!mounted) return;
      setState(() {
        _errorKind = e.kind;
        _errorDetail = e.message;
      });
    } catch (e) {
      // Not an error of the node (the bridge, a bug): the screen says it, it does not break.
      if (!mounted) return;
      setState(() {
        _errorKind = CelautErrorKind.protocol;
        _errorDetail = '$e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    // The detail of a node of the list: no form (it would show the full peer id), only the
    // address and "Check now".
    if (widget.address != null) {
      return SettingsPage(
        title: appL10n.celautNodesDetail,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _addressCtrl.text,
                  key: const Key('celaut-detail-address'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                key: const Key('celaut-connect'),
                onPressed: _busy ? null : _connect,
                child: Text(_busy ? CelautStrings.connecting : appL10n.celautNodesCheckNow),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._body(context, info),
        ],
      );
    }
    return SettingsPage(
      title: CelautStrings.screenTitle,
      children: [
        SettingsNote(CelautStrings.intro),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('celaut-address'),
                controller: _addressCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: CelautStrings.addressLabel,
                  hintText: CelautStrings.addressHint,
                  errorText: _inputError,
                  errorMaxLines: 3,
                ),
                onSubmitted: (_) => _busy ? null : _connect(),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('celaut-expected'),
                controller: _expectedCtrl,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: CelautStrings.expectedLabel,
                  hintText: CelautStrings.expectedHint,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('celaut-connect'),
                onPressed: _busy ? null : _connect,
                child: Text(_busy ? CelautStrings.connecting : CelautStrings.connect),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ..._body(context, info),
      ],
    );
  }

  /// The error, or the advertisement of the node.
  List<Widget> _body(BuildContext context, PeerInfoView? info) {
    return [
        if (_errorKind != null) _ErrorCard(kind: _errorKind!, detail: _errorDetail ?? ''),
        // The node forgot the client id: no id shows, only the message and the action.
        if (_errorKind == CelautErrorKind.clientUnknown)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('celaut-client-unknown'),
              onPressed: _forgotten,
              child: Text(appL10n.celautHomeClientUnknownAction),
            ),
          ),
        if (info != null) ..._result(context, info),
    ];
  }

  List<Widget> _result(BuildContext context, PeerInfoView info) {
    return [
      SectionLabel(CelautStrings.identityTitle),
      const SizedBox(height: 10),
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IdRow(
              key: const Key('celaut-peer-id'),
              label: CelautStrings.peerIdLabel,
              id: info.peerId,
              keyPrefix: 'celaut-peer-id',
            ),
            const SizedBox(height: 8),
            if (_clientId != null)
              IdRow(
                key: const Key('celaut-client-id'),
                label: appL10n.celautClientIdLabel,
                id: _clientId!,
                keyPrefix: 'celaut-client-id',
                copiedText: appL10n.celautClientIdCopied,
              )
            else
              _labelled(context, appL10n.celautClientIdLabel, appL10n.celautClientIdNone),
            const SizedBox(height: 12),
            _labelled(context, CelautStrings.advertisedLabel, formatUtc(info.ts)),
            const SizedBox(height: 6),
            _labelled(context, CelautStrings.proofsLabel, '${info.reputationProofs}'),
            const SizedBox(height: 10),
            Text(CelautStrings.verifiedNote, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SectionLabel(CelautStrings.urisTitle),
      const SizedBox(height: 10),
      _listCard(
        context,
        empty: CelautStrings.noUris,
        rows: [for (final u in info.uris) _uriRow(context, u)],
      ),
      const SizedBox(height: 24),
      SectionLabel(CelautStrings.ratesTitle),
      const SizedBox(height: 10),
      _listCard(
        context,
        empty: CelautStrings.noRates,
        rows: [
          for (final r in info.rates)
            _pairRow(context, r.key, r.value.isEmpty ? appL10n.celautUnknown : r.value),
        ],
      ),
      if (info.rates.isNotEmpty) SettingsNote(CelautStrings.ratesNote),
      if (info.rates.isEmpty) const SizedBox(height: 24),
      SectionLabel(CelautStrings.contractsTitle),
      const SizedBox(height: 10),
      _listCard(
        context,
        empty: CelautStrings.noContracts,
        rows: [for (final c in info.paymentContracts) _contractRow(context, c)],
      ),
      const SizedBox(height: 24),
      SectionLabel(CelautStrings.resourcesTitle),
      const SizedBox(height: 10),
      _resources(context, info),
    ];
  }

  /// One summary line (the entry that the node counts with), a bar for each resource
  /// against the other nodes, and the architectures and the benchmark in a closed part.
  Widget _resources(BuildContext context, PeerInfoView info) {
    final entry = largestEntry(info.resources);
    if (entry == null) {
      return _listCard(context, empty: CelautStrings.noResources, rows: const []);
    }
    final o = widget.overview;
    final others = o == null ? const <NodeComputeView>[] : answeredNodes(o);
    final counted = others.any((n) => n.peerId == info.peerId);
    num totalOf(NodeResource r) => others.fold<num>(0, (a, n) => a + (resourceOf(n, r) ?? 0));
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resourcesSummary(
              entryResource(entry, NodeResource.cpu),
              entryResource(entry, NodeResource.memory),
              entryResource(entry, NodeResource.disk),
            ),
            key: const Key('celaut-resources-summary'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (counted && others.length > 1) ...[
            const SizedBox(height: 8),
            Text(appL10n.celautResourcesShareHint(others.length), style: TextStyle(fontSize: 12.5, color: ArgusColors.of(context).muted)),
            for (final r in NodeResource.values)
              NodeShareRow(
                key: Key('celaut-share-${r.name}'),
                resource: r,
                value: entryResource(entry, r),
                total: totalOf(r),
              ),
          ],
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('celaut-resources-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              title: Text(appL10n.celautRunDetails),
              children: [for (final r in info.resources) _resourcesRow(context, r)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelled(BuildContext context, String label, String value) {
    final colors = ArgusColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  ', style: TextStyle(fontSize: 12.5, color: colors.muted)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5))),
      ],
    );
  }

  Widget _listCard(BuildContext context, {required String empty, required List<Widget> rows}) {
    if (rows.isEmpty) {
      return SoftCard(
        child: Text(empty, style: TextStyle(fontSize: 13.5, color: ArgusColors.of(context).muted)),
      );
    }
    return SoftCard(
      padding: EdgeInsets.zero,
      child: DividedColumn(indent: 16, children: rows),
    );
  }

  Widget _row(BuildContext context, String title, List<String> lines) {
    final colors = ArgusColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          for (final line in lines) ...[
            const SizedBox(height: 3),
            SelectableText(line, style: TextStyle(fontSize: 12.5, color: colors.muted)),
          ],
        ],
      ),
    );
  }

  Widget _pairRow(BuildContext context, String key, String value) {
    final colors = ArgusColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(key, style: const TextStyle(fontSize: 14))),
          const SizedBox(width: 12),
          SelectableText(value, style: TextStyle(fontSize: 14, color: colors.muted)),
        ],
      ),
    );
  }

  Widget _uriRow(BuildContext context, NodeUriView uri) {
    final expiry = uri.expiryUnixTimestamp == 0
        ? CelautStrings.noExpiry
        : CelautStrings.expires(formatUtc(uri.expiryUnixTimestamp));
    final stack = [if (uri.transport.isNotEmpty) uri.transport, ...uri.protocols].join(' · ');
    final host = uri.ip.contains(':') ? '[${uri.ip}]' : uri.ip;
    return _row(context, '$host:${uri.port}', [if (stack.isNotEmpty) stack, expiry]);
  }

  Widget _contractRow(BuildContext context, PaymentContractView c) {
    return _row(context, c.ledger.isEmpty ? '?' : c.ledger, [
      CelautStrings.perUnit(c.muPerUnit),
      for (final d in c.details) '${d.key}: ${d.value}',
    ]);
  }

  /// What the node advertises for one architecture. A value that the node does not give
  /// is "unknown", never left out or 0 (`docs/celaut/ui.md`, section 2).
  Widget _resourcesRow(BuildContext context, NodeResourcesView r) {
    final unknown = appL10n.celautUnknown;
    return _row(context, r.architecture.isEmpty ? '?' : r.architecture, [
      '${CelautStrings.cpuLabel}: ${r.cpuCores == null ? unknown : CelautStrings.cores(r.cpuCores!)}',
      '${CelautStrings.memoryLabel}: '
          '${r.memLimitBytes == null ? unknown : CelautStrings.bytes(r.memLimitBytes!)}',
      '${CelautStrings.diskLabel}: '
          '${r.diskSpaceBytes == null ? unknown : CelautStrings.bytes(r.diskSpaceBytes!)}',
      for (final b in r.benchmark)
        '${CelautStrings.benchmarkLabel} ${b.key}: ${b.value.isEmpty ? unknown : b.value}',
    ]);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.kind, required this.detail});

  final CelautErrorKind kind;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = ArgusColors.of(context);
    return SoftCard(
      child: Column(
        key: const Key('celaut-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: rustFor(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  CelautStrings.errorTitle,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: rustFor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(CelautStrings.errorText(kind), style: const TextStyle(fontSize: 14)),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              CelautStrings.detailLabel(detail),
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// `2026-10-12 13:20 UTC` from Unix seconds.
String formatUtc(int seconds) {
  // A node can send any number. DateTime accepts about ±8.64e12 seconds.
  if (seconds.abs() > 8640000000000) return '$seconds';
  final t = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)} UTC';
}
