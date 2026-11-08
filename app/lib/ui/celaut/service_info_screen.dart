import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../bridge/api/celaut_service_info.dart';
import '../../celaut/celaut_strings.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../layout.dart';
import '../widgets/soft_card.dart';

/// Read what a service says about itself: from its file in the library, or from [node].
/// The app never loads its filesystem (`docs/celaut/service-info.md`).
typedef ServiceInfoLoader = Future<ServiceInfoView> Function(String serviceIdHex, NodeAddress? node);

Future<ServiceInfoView> readServiceInfo(String serviceIdHex, NodeAddress? node) =>
    celautServiceInfo(serviceIdHex: serviceIdHex, node: node);

/// The details of a service (`docs/celaut/service-info.md`): the prose, the resources that
/// it needs, its interface, the networks that it declares, its environment variables, and
/// whether its interface is the chat convention of Chatui. A banner at the top says so.
///
/// The info comes from [info] if the caller has read it already (the launch does, and does
/// not read a large service twice), or else it is read with [load] from the library file or
/// from [node].
class ServiceInfoScreen extends StatefulWidget {
  const ServiceInfoScreen({
    super.key,
    required this.serviceIdHex,
    this.name,
    this.node,
    this.info,
    this.load = readServiceInfo,
  });

  final String serviceIdHex;

  /// The name to show in the bar, if the caller knows it.
  final String? name;

  /// A node that has the service, to read it from if the library has no file.
  final NodeAddress? node;

  /// What the caller read already.
  final ServiceInfoView? info;

  final ServiceInfoLoader load;

  @override
  State<ServiceInfoScreen> createState() => _ServiceInfoScreenState();
}

class _ServiceInfoScreenState extends State<ServiceInfoScreen> {
  late Future<ServiceInfoView> _future = _read();

  Future<ServiceInfoView> _read() {
    final known = widget.info;
    if (known != null) return Future.value(known);
    return widget.load(widget.serviceIdHex, widget.node);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name ?? l.serviceInfoTitle)),
      body: ReadableWidth(
        child: FutureBuilder<ServiceInfoView>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                key: const Key('service-info-loading'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(l.serviceInfoLoading),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              final e = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e is CelautError ? CelautStrings.errorText(e.kind) : l.serviceInfoReadFailed,
                        key: const Key('service-info-error'),
                        textAlign: TextAlign.center,
                      ),
                      if (e is CelautError) ...[
                        const SizedBox(height: 8),
                        Text(
                          e.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: ArgusColors.of(context).muted),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        key: const Key('service-info-retry'),
                        onPressed: () {
                          // The callback must not return the Future, so it is not an arrow.
                          setState(() {
                            _future = _read();
                          });
                        },
                        child: Text(l.commonRetry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ServiceInfoBody(info: snapshot.data!);
          },
        ),
      ),
    );
  }
}

/// The sections of the details of a service.
class ServiceInfoBody extends StatelessWidget {
  const ServiceInfoBody({super.key, required this.info});

  final ServiceInfoView info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        _ChatBanner(info: info),
        if (info.truncated) ...[
          const SizedBox(height: 12),
          _Note(l.serviceInfoTruncated, key: const Key('service-info-truncated')),
        ],
        const SizedBox(height: 12),
        _about(context),
        if (info.partsSkipped > 0 && !info.truncated) ...[
          const SizedBox(height: 12),
          _Note(l.serviceInfoPartsSkipped(info.partsSkipped), key: const Key('service-info-parts-skipped')),
        ],
        // What is after the filesystem is unknown when the service was cut: say nothing
        // about it instead of "none". The same for an interface that was too large.
        if (!info.truncated) ...[
          const SizedBox(height: 12),
          _resources(context),
          if (!info.apiSkipped) ...[const SizedBox(height: 12), _interface(context)],
          const SizedBox(height: 12),
          _networks(context),
          const SizedBox(height: 12),
          _environment(context),
          if (_hasMore) ...[const SizedBox(height: 12), _more(context)],
        ],
      ],
    );
  }

  bool get _hasMore =>
      info.nodeProtocols.isNotEmpty || info.workloads.isNotEmpty || info.workloadsSkipped > 0;

  Widget _about(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return _Section(
      key: const Key('service-info-about'),
      title: l.serviceInfoAbout,
      children: [
        Text(
          info.prose.trim().isEmpty ? l.serviceInfoNoProse : info.prose.trim(),
          key: const Key('service-info-prose'),
          style: info.prose.trim().isEmpty ? TextStyle(color: muted) : null,
        ),
        if (info.architecture.isNotEmpty) _Line(l.serviceInfoArchitecture, info.architecture.join(', ')),
        if (info.entryPath.isNotEmpty) _Line(l.serviceInfoEntry, '/${info.entryPath.join('/')}'),
        if (info.configPath.isNotEmpty) _Line(l.serviceInfoConfigFile, '/${info.configPath.join('/')}'),
        _Line(l.serviceInfoFilesystem, CelautStrings.bytes(info.filesystemBytes.toInt())),
      ],
    );
  }

  Widget _resources(BuildContext context) {
    final l = context.l10n;
    final start = info.resourcesAtInit;
    final most = info.resourcesAtMost;
    return _Section(
      key: const Key('service-info-resources'),
      title: l.serviceInfoResources,
      children: [
        if (start == null && most == null)
          Text(l.serviceInfoNoResources, style: TextStyle(color: ArgusColors.of(context).muted)),
        if (start != null) ..._resourceLines(context, l.serviceInfoAtStart, start),
        if (most != null) ..._resourceLines(context, l.serviceInfoAtMost, most),
      ],
    );
  }

  List<Widget> _resourceLines(BuildContext context, String title, SysresourcesView r) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      if (r.cpuCores != null) _Line(CelautStrings.cpuLabel, CelautStrings.cores(r.cpuCores!)),
      if (r.memBytes != null) _Line(CelautStrings.memoryLabel, CelautStrings.bytes(r.memBytes!.toInt())),
      if (r.diskBytes != null) _Line(CelautStrings.diskLabel, CelautStrings.bytes(r.diskBytes!.toInt())),
      for (final b in r.benchmark)
        _Line(l.serviceInfoCoreSpeed, '${b.key}: ${b.value}', valueStyle: TextStyle(fontSize: 12.5, color: muted)),
    ];
  }

  Widget _interface(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return _Section(
      key: const Key('service-info-interface'),
      title: l.serviceInfoInterface,
      children: [
        if (info.slots.isEmpty) Text(l.serviceInfoNoInterface, style: TextStyle(color: muted)),
        for (final (index, s) in info.slots.indexed)
          Padding(
            key: Key('service-info-slot-${s.port}'),
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l.serviceInfoSlot(index + 1), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (s.chat) ...[
                      const SizedBox(width: 8),
                      _Badge(l.serviceInfoChatReady, key: Key('service-info-chat-${s.port}')),
                    ],
                  ],
                ),
                Text(
                  _stack([s.transport.join('/'), for (final p in s.protocolStack) p.tags.join('/')]),
                  style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13),
                ),
                for (final p in s.protocolStack)
                  if (p.prose.trim().isNotEmpty)
                    Text(p.prose.trim(), style: TextStyle(fontSize: 12.5, color: muted)),
                for (final m in s.muPerCall)
                  Text('${l.serviceInfoPricePerCall}: ${m.key} = ${m.value}',
                      style: TextStyle(fontSize: 12.5, color: muted)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _networks(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return _Section(
      key: const Key('service-info-networks'),
      title: l.serviceInfoNetworks,
      children: [
        if (info.networks.isEmpty) Text(l.serviceInfoNoNetworks, style: TextStyle(color: muted)),
        for (final (i, n) in info.networks.indexed)
          Padding(
            key: Key('service-info-network-$i'),
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.tags.map((t) => t == '*' ? l.serviceInfoAnyAddress : t).join(', '),
                  style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 14),
                ),
                if (n.prose.trim().isNotEmpty) Text(n.prose.trim()),
                if (n.formal.isNotEmpty)
                  Text(n.formal, style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 12.5, color: muted)),
                if (n.protocolStack.isNotEmpty)
                  Text(
                    l.serviceInfoPeersSpeak(_stack([for (final p in n.protocolStack) p.tags.join('/')])),
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _environment(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return _Section(
      key: const Key('service-info-environment'),
      title: l.serviceInfoEnvironment,
      children: [
        if (info.environment.isEmpty) Text(l.serviceInfoNoEnvironment, style: TextStyle(color: muted)),
        for (final v in info.environment)
          Padding(
            key: Key('service-info-env-${v.name}'),
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 14)),
                if (v.prose.trim().isNotEmpty || v.tags.isNotEmpty)
                  Text(
                    v.prose.trim().isNotEmpty ? v.prose.trim() : v.tags.join(', '),
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _more(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    return _Section(
      key: const Key('service-info-more'),
      title: l.serviceInfoMore,
      children: [
        if (info.nodeProtocols.isNotEmpty)
          _Line(l.serviceInfoNodeProtocols, _stack([for (final p in info.nodeProtocols) p.tags.join('/')])),
        // nodo#538: the first instances (the start pays them), then the ones that it can
        // start later. The service needs each clause and uses one group of a clause.
        for (final initial in [true, false])
          if (info.workloads.any((w) => w.initial == initial)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                initial ? l.serviceInfoWorkloadsInitial : l.serviceInfoWorkloads,
                key: Key(initial ? 'service-info-workloads-initial' : 'service-info-workloads'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final (i, w) in info.workloads.indexed)
              if (w.initial == initial)
                Text(
                  [
                    // The first workload of a group after the first: one group or the other.
                    if (w.group > 0 && (i == 0 || !_sameGroup(info.workloads[i - 1], w)))
                      '${l.serviceInfoWorkloadOr} ${l.serviceInfoWorkload(w.count)}'
                    else
                      l.serviceInfoWorkload(w.count),
                    if (w.hasDependency) l.serviceInfoWorkloadService,
                    if (w.resources?.cpuCores != null) CelautStrings.cores(w.resources!.cpuCores!),
                    if (w.resources?.memBytes != null) CelautStrings.bytes(w.resources!.memBytes!.toInt()),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
          ],
        if (info.workloads.isEmpty && info.workloadsSkipped > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.serviceInfoWorkloads, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        if (info.workloadsSkipped > 0)
          Text(l.serviceInfoWorkloadsSkipped(info.workloadsSkipped), style: TextStyle(fontSize: 12.5, color: muted)),
      ],
    );
  }
}

/// True if [a] and [b] are in the same group of the same clause of the same field.
bool _sameGroup(WorkloadView a, WorkloadView b) => a.initial == b.initial && a.clause == b.clause && a.group == b.group;

/// A protocol stack, bottom to top, as `tcp → http → chat`.
String _stack(List<String> layers) => layers.where((s) => s.isNotEmpty).join(' → ');

/// Says if the interface of the service is the chat convention of Chatui.
class _ChatBanner extends StatelessWidget {
  const _ChatBanner({required this.info});

  final ServiceInfoView info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, color, text, key) = switch (info.chat) {
      ChatSupportView.supported => (
        Icons.chat_bubble_outline,
        accentTextOf(context),
        l.serviceInfoChatSupported,
        'service-info-chat-supported',
      ),
      ChatSupportView.unsupported => (
        Icons.warning_amber_rounded,
        rustFor(context),
        l.serviceInfoChatUnsupported,
        'service-info-chat-unsupported',
      ),
      ChatSupportView.unknown => (
        Icons.help_outline,
        ArgusColors.of(context).muted,
        l.serviceInfoChatUnknown,
        'service-info-chat-unknown',
      ),
    };
    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, key: Key(key))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final muted = ArgusColors.of(context).muted;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          SelectableText(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Text(text, style: TextStyle(color: ArgusColors.of(context).muted)),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = accentTextOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(fontSize: 11.5, color: color)),
    );
  }
}
