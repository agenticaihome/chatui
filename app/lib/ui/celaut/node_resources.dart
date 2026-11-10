import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_home.dart';
import '../../celaut/celaut_strings.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import 'id_row.dart';

/// The resources of the nodes in more than one view, with little to read at each step
/// (issue #123): the home shows one total; a tap opens [NodeResourcesScreen] with one view at
/// a time. The data is what the nodes offer (their advertisement), not what is free. A
/// value that a node does not give is "unknown", never 0 (`docs/celaut/ui.md`, section 2),
/// and the nodes that did not answer are counted apart from the total.

/// The resources, always in this order: CPU, memory, disk.
enum NodeResource { cpu, memory, disk }

/// The label of [r] ("CPU", "Memory", "Disk").
String resourceLabel(NodeResource r) => switch (r) {
      NodeResource.cpu => CelautStrings.cpuLabel,
      NodeResource.memory => CelautStrings.memoryLabel,
      NodeResource.disk => CelautStrings.diskLabel,
    };

/// [value] of [r] with its unit, or "unknown" for null: never 0 for a value that the node
/// does not give.
String resourceText(NodeResource r, num? value) {
  if (value == null) return appL10n.celautUnknown;
  return r == NodeResource.cpu ? CelautStrings.cores(value.toDouble()) : CelautStrings.bytes(value.toInt());
}

/// The value of [r] in what [n] offers; null if the node does not give it.
num? resourceOf(NodeComputeView n, NodeResource r) => switch (r) {
      NodeResource.cpu => n.cpuCores,
      NodeResource.memory => n.memBytes?.toInt(),
      NodeResource.disk => n.diskBytes?.toInt(),
    };

/// The values of [r] in one architecture entry; null if the node does not give it.
num? entryResource(NodeResourcesView e, NodeResource r) => switch (r) {
      NodeResource.cpu => e.cpuCores,
      NodeResource.memory => e.memLimitBytes?.toInt(),
      NodeResource.disk => e.diskSpaceBytes?.toInt(),
    };

/// The entry that a node counts with: the largest (more memory, then more cores, then more
/// disk; a known value is larger than an unknown one; the first of two equal entries), as
/// the sums of the home screen count it (`celaut-client`, `overview.rs`). Null for none.
NodeResourcesView? largestEntry(List<NodeResourcesView> entries) {
  int known(num? a, num? b) => a != null && b != null
      ? a.compareTo(b)
      : a != null
          ? 1
          : b != null
              ? -1
              : 0;
  NodeResourcesView? best;
  for (final e in entries) {
    if (best == null) {
      best = e;
      continue;
    }
    var c = known(e.memLimitBytes?.toInt(), best.memLimitBytes?.toInt());
    if (c == 0) c = known(e.cpuCores, best.cpuCores);
    if (c == 0) c = known(e.diskSpaceBytes?.toInt(), best.diskSpaceBytes?.toInt());
    if (c > 0) best = e;
  }
  return best;
}

/// The one summary line of the resources of a node: CPU, memory and disk with their units.
String resourcesSummary(num? cpu, num? memory, num? disk) => [
      '${CelautStrings.cpuLabel} ${resourceText(NodeResource.cpu, cpu)}',
      '${CelautStrings.memoryLabel} ${resourceText(NodeResource.memory, memory)}',
      '${CelautStrings.diskLabel} ${resourceText(NodeResource.disk, disk)}',
    ].join(' · ');

/// The nodes of [o] that answered (each once), in the sums.
List<NodeComputeView> answeredNodes(ComputeOverviewView o) {
  final seen = <String>{};
  return [for (final n in o.nodes) if (n.reachable && seen.add(n.peerId)) n];
}

/// The colour of the [i]-th node in a bar: the primary colour of the theme, turned by the
/// golden angle for each next node, so two neighbours never look alike (some palettes have
/// the same primary and tertiary). The same node keeps its colour in every view.
Color nodeColor(BuildContext context, int i) {
  final primary = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
  return primary.withHue((primary.hue + i * 137.5) % 360).withSaturation(primary.saturation.clamp(0.45, 0.8)).toColor();
}

/// A part of a [ShareBar]: a known value, or a node whose value is unknown ([value] null).
typedef SharePart = ({String key, num? value, Color color});

/// A stacked bar that splits a total between parts. A part whose value is unknown shows as
/// a striped piece of a fixed width (it has no size), so it is never drawn as 0.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.parts, this.height = 12});

  final List<SharePart> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final known = [for (final p in parts) if (p.value != null && p.value! > 0) p];
    final unknown = parts.where((p) => p.value == null).length;
    final sum = known.fold<double>(0, (a, p) => a + p.value!.toDouble());
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              if (sum > 0)
                for (final p in known)
                  Expanded(
                    // Flex needs integers: 1000 steps are finer than a pixel.
                    flex: (p.value!.toDouble() / sum * 1000 * (unknown == 0 ? 1 : 0.85)).round().clamp(1, 1000),
                    child: Container(key: Key('share-${p.key}'), color: p.color),
                  ),
              if (unknown > 0)
                Expanded(
                  flex: sum > 0 ? 150 : 1000,
                  child: CustomPaint(
                    key: const Key('share-unknown'),
                    painter: _StripesPainter(Theme.of(context).colorScheme.outline, track),
                  ),
                ),
              if (sum == 0 && unknown == 0) Expanded(child: Container(color: track)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diagonal stripes: the pattern of an unknown part.
class _StripesPainter extends CustomPainter {
  _StripesPainter(this.stripe, this.background);

  final Color stripe;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) => old.stripe != stripe || old.background != background;
}

/// The bar of one node for one resource: the part of the total of the nodes that this node
/// has. Unknown when the node does not give the value.
class NodeShareRow extends StatelessWidget {
  const NodeShareRow({super.key, required this.resource, required this.value, required this.total});

  final NodeResource resource;
  final num? value;

  /// The known total of all the nodes that answered.
  final num total;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final v = value;
    final share = v == null || total <= 0 ? null : (v / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(resourceLabel(resource), style: t.secondary)),
          Expanded(
            child: share == null
                ? ShareBar(height: 8, parts: [(key: resource.name, value: null, color: t.muted)])
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: Key('node-share-${resource.name}'),
                      value: share.toDouble(),
                      minHeight: 8,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              share == null ? appL10n.celautUnknown : '${(share * 100).round()} %',
              textAlign: TextAlign.end,
              style: t.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The views of [NodeResourcesScreen].
enum ResourcesView { byResource, byNode }

/// The resources of all the nodes, behind the total of the home screen (issue #123). One
/// view at a time, with a switch: "By resource" (the default: one resource, its total and a
/// bar that splits it between the nodes) and "By node" (a card for each node with its three
/// resources, the largest node first). One note says that this is what the nodes offer.
class NodeResourcesScreen extends StatefulWidget {
  const NodeResourcesScreen({super.key, required this.overview});

  final ComputeOverviewView overview;

  @override
  State<NodeResourcesScreen> createState() => _NodeResourcesScreenState();
}

class _NodeResourcesScreenState extends State<NodeResourcesScreen> {
  ResourcesView _view = ResourcesView.byResource;
  NodeResource _resource = NodeResource.cpu;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final o = widget.overview;
    final nodes = answeredNodes(o);
    return Scaffold(
      appBar: AppBar(title: Text(l.celautResourcesScreenTitle)),
      body: ListView(
        key: const Key('resources-list'),
        padding: const EdgeInsets.fromLTRB(homeGutter, 8, homeGutter, 32),
        children: [
          SegmentedButton<ResourcesView>(
            key: const Key('resources-view'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ResourcesView.byResource, label: Text(l.celautResourcesByResource)),
              ButtonSegment(value: ResourcesView.byNode, label: Text(l.celautResourcesByNode)),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 12),
          Text(l.celautResourcesNote, key: const Key('resources-note'), style: t.secondary),
          if (o.nodesUnreachable > 0) ...[
            const SizedBox(height: 4),
            Text(
              l.celautResourcesUnreachable(o.nodesUnreachable),
              key: const Key('resources-unreachable'),
              style: t.secondary.copyWith(color: rustFor(context)),
            ),
          ],
          const SizedBox(height: 16),
          if (nodes.isEmpty)
            Text(l.celautResourcesNoNode, key: const Key('resources-empty'), style: t.secondary)
          else if (_view == ResourcesView.byResource)
            ..._byResource(context, nodes)
          else
            ..._byNode(context, nodes),
        ],
      ),
    );
  }

  /// The known total of [r] over [nodes], and how many nodes do not give it.
  ({num known, int unknown}) _total(List<NodeComputeView> nodes, NodeResource r) {
    num known = 0;
    var unknown = 0;
    for (final n in nodes) {
      final v = resourceOf(n, r);
      if (v == null) {
        unknown++;
      } else {
        known += v;
      }
    }
    return (known: known, unknown: unknown);
  }

  String _totalText(NodeResource r, ({num known, int unknown}) total) {
    final l = context.l10n;
    final text = total.known == 0 && total.unknown > 0 ? l.celautUnknown : resourceText(r, total.known);
    return total.unknown == 0 || total.known == 0 ? text : l.celautAtLeast(text, total.unknown);
  }

  List<Widget> _byResource(BuildContext context, List<NodeComputeView> nodes) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final r = _resource;
    final total = _total(nodes, r);
    final sorted = [...nodes]..sort((a, b) => (resourceOf(b, r) ?? -1).compareTo(resourceOf(a, r) ?? -1));
    return [
      Wrap(
        spacing: 8,
        children: [
          for (final each in NodeResource.values)
            ChoiceChip(
              key: Key('resources-pick-${each.name}'),
              label: Text(resourceLabel(each)),
              selected: each == r,
              onSelected: (_) => setState(() => _resource = each),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        l.celautResourcesTotal(resourceLabel(r), _totalText(r, total), nodes.length),
        key: const Key('resources-total'),
        style: t.primary.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      ShareBar(
        key: const Key('resources-bar'),
        parts: [
          for (final n in sorted)
            (key: n.peerId, value: resourceOf(n, r), color: nodeColor(context, nodes.indexOf(n))),
        ],
      ),
      const SizedBox(height: 12),
      for (final n in sorted)
        Padding(
          key: Key('resources-part-${n.peerId}'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              resourceOf(n, r) == null
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: ShareBar(height: 12, parts: [(key: 'legend-${n.peerId}', value: null, color: t.muted)]),
                    )
                  : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: nodeColor(context, nodes.indexOf(n)), shape: BoxShape.circle),
                    ),
              const SizedBox(width: 10),
              Expanded(child: Text(_nodeName(n), style: t.secondary, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(resourceText(r, resourceOf(n, r)), style: t.primary),
            ],
          ),
        ),
    ];
  }

  List<Widget> _byNode(BuildContext context, List<NodeComputeView> nodes) {
    final t = HomeText.of(context);
    // The largest node first: memory, then cores, then disk (unknown is the smallest).
    int cmp(num? a, num? b) => (b ?? -1).compareTo(a ?? -1);
    final sorted = [...nodes]
      ..sort((a, b) {
        var c = cmp(a.memBytes?.toInt(), b.memBytes?.toInt());
        if (c == 0) c = cmp(a.cpuCores, b.cpuCores);
        if (c == 0) c = cmp(a.diskBytes?.toInt(), b.diskBytes?.toInt());
        return c;
      });
    final totals = {for (final r in NodeResource.values) r: _total(nodes, r).known};
    return [
      for (final n in sorted)
        Card(
          key: Key('resources-node-${n.peerId}'),
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nodeName(n), style: t.primary.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                // At most three numbers in a row: one row for each resource.
                for (final r in NodeResource.values)
                  Row(
                    children: [
                      Expanded(
                        child: NodeShareRow(resource: r, value: resourceOf(n, r), total: totals[r]!),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 84,
                        child: Text(
                          resourceText(r, resourceOf(n, r)),
                          key: Key('resources-node-${n.peerId}-${r.name}'),
                          textAlign: TextAlign.end,
                          style: t.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  /// A node by its address, with its peer id in short form: never a full id here.
  String _nodeName(NodeComputeView n) => n.address.isEmpty ? shortId(n.peerId) : '${n.address} · ${shortId(n.peerId)}';
}
