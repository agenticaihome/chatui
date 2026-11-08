import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_descendants.dart';
import '../../bridge/api/celaut_receipts.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import 'instance_receipts.dart';

/// The calls of the Descendants section. Tests give their own, so that no test reaches a
/// node. The default ones call the bridge.
class DescendantsApi {
  const DescendantsApi({
    this.list = _list,
    this.quote = _quote,
    this.check = _check,
    this.receipts = _receipts,
    this.slots = _slots,
    this.openTunnel = _openTunnel,
    this.launch = _launch,
  });

  /// The descendants that the app knows. It reads the database only. Null if the app
  /// cannot read it.
  final DescendantsView? Function(String instanceId) list;

  /// The most MU that a check can cost. It sends nothing.
  final Future<ReadQuoteView> Function(String instanceId, String instanceRef) quote;

  /// The check. It costs MU. The last argument is the budget that the user confirmed.
  final Future<CheckReportView> Function(String instanceId, String instanceRef, String maxMu)
  check;

  final ReceiptsView? Function(String instanceId, String instanceRef) receipts;
  final Future<DescendantSlotsView> Function(String instanceId, String instanceRef) slots;
  final Future<int> Function(String instanceId, String instanceRef, int slot) openTunnel;
  final Future<bool> Function(Uri uri) launch;
}

DescendantsView? _list(String id) {
  try {
    return celautDescendants(instanceId: id);
  } catch (_) {
    return null;
  }
}

Future<ReadQuoteView> _quote(String id, String ref) =>
    celautQuoteDescendantRead(instanceId: id, instanceRef: ref);

Future<CheckReportView> _check(String id, String ref, String maxMu) =>
    celautCheckDescendant(instanceId: id, instanceRef: ref, maxMu: maxMu);

ReceiptsView? _receipts(String id, String ref) {
  try {
    return celautDescendantReceipts(instanceId: id, instanceRef: ref);
  } catch (_) {
    return null;
  }
}

Future<DescendantSlotsView> _slots(String id, String ref) =>
    celautDescendantSlots(instanceId: id, instanceRef: ref);

Future<int> _openTunnel(String id, String ref, int slot) =>
    celautOpenDescendantTunnel(instanceId: id, instanceRef: ref, slot: slot);

Future<bool> _launch(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

String _errorText(Object e) =>
    e is CelautError ? CelautStrings.errorText(e.kind) : '$e';

/// The detail of an error: its kind in words, and the technical reason after it.
String _errorDetail(Object e) => e is CelautError && e.message.isNotEmpty
    ? '${CelautStrings.errorText(e.kind)} (${e.message})'
    : _errorText(e);

String _short(String hex) => hex.length > 12 ? '${hex.substring(0, 12)}…' : hex;

/// Ask the user before a check, with the most that it can cost. The field starts with the
/// maximum of the quote, and the user can change it. Gives the budget as text, or null if
/// the user cancelled. The check never starts without this answer, each time.
Future<String?> confirmDescendantCheck(BuildContext context, ReadQuoteView quote) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CheckDialog(quote: quote),
  );
}

class _CheckDialog extends StatefulWidget {
  const _CheckDialog({required this.quote});

  final ReadQuoteView quote;

  @override
  State<_CheckDialog> createState() => _CheckDialogState();
}

class _CheckDialogState extends State<_CheckDialog> {
  late final TextEditingController _max = TextEditingController(text: widget.quote.maxMu);

  @override
  void dispose() {
    _max.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[0-9]+$').hasMatch(_max.text.trim());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const Key('descendant-check-dialog'),
      title: Text(l.descendantsCheckTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.descendantsCheckBody(widget.quote.node)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('descendant-check-max'),
            controller: _max,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.descendantsMaxLabel,
              suffixText: 'MU',
              errorText: _valid ? null : l.descendantsMaxInvalid,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('descendant-check-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.descendantsCancel),
        ),
        FilledButton(
          key: const Key('descendant-check-confirm'),
          onPressed: _valid ? () => Navigator.of(context).pop(_max.text.trim()) : null,
          child: Text(l.descendantsCheckConfirm),
        ),
      ],
    );
  }
}

/// The text of a finding, for the alert.
String findingText(AppLocalizations l, DescendantFindingView f) {
  switch (f.kind) {
    case DescendantFindingKind.stoppedWithMu:
      final base = l.descendantsDiedWithMu(muOrUnknown(f.leftoverMu), f.reason);
      return f.fatherGone ? '$base ${l.descendantsFatherGone}' : base;
    case DescendantFindingKind.statementRefused:
      return l.descendantsRefused;
  }
}

/// The Descendants part of the info page of an instance: each descendant with its
/// service, node state and last check, a Check button that always asks first, an alert
/// for an instance that a node ended with MU on it, its receipts, and Open for a page that
/// the service declares.
class InstanceDescendantsSection extends StatefulWidget {
  const InstanceDescendantsSection({
    super.key,
    required this.instanceId,
    required this.node,
    this.api = const DescendantsApi(),
  });

  final String instanceId;

  /// The address of the node, for the texts.
  final String node;
  final DescendantsApi api;

  @override
  State<InstanceDescendantsSection> createState() => _InstanceDescendantsSectionState();
}

class _InstanceDescendantsSectionState extends State<InstanceDescendantsSection> {
  late DescendantsView? _view = widget.api.list(widget.instanceId);

  /// The checks that run now, by instance_ref: a second tap does nothing.
  final Set<String> _busy = {};

  void _reload() {
    if (mounted) setState(() => _view = widget.api.list(widget.instanceId));
  }

  /// Quote, ask, and only after a yes, check. Nothing here runs by itself.
  Future<void> _check(DescendantView d) async {
    if (_busy.contains(d.instanceRef)) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(d.instanceRef));
    try {
      final ReadQuoteView quote;
      try {
        quote = await widget.api.quote(widget.instanceId, d.instanceRef);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.descendantsQuoteFailed(_errorDetail(e)))),
        );
        return;
      }
      if (!mounted) return;
      final budget = await confirmDescendantCheck(context, quote);
      if (budget == null || !mounted) return;
      final CheckReportView report;
      try {
        report = await widget.api.check(widget.instanceId, d.instanceRef, budget);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.descendantsCheckFailed(_errorDetail(e)))),
        );
        return;
      } finally {
        _reload();
      }
      if (!mounted) return;
      if (report.findings.isNotEmpty) {
        await _showFindings(report.findings);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              report.newDescendants.isEmpty
                  ? l.descendantsFoundNone
                  : l.descendantsFoundNew('${report.newDescendants.length}'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(d.instanceRef));
    }
  }

  Future<void> _showFindings(List<DescendantFindingView> findings) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('descendant-findings'),
        title: Text(
          findings.any((f) => f.kind == DescendantFindingKind.stoppedWithMu)
              ? l.descendantsDiedWithMuTitle
              : l.descendantsRefusedTitle,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in findings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(findingText(l, f)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.descendantsClose),
          ),
        ],
      ),
    );
  }

  /// Open the first web page that the service declares, through the tunnel. A service
  /// that declares none opens nothing.
  Future<void> _open(DescendantView d) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final slots = await widget.api.slots(widget.instanceId, d.instanceRef);
      if (slots.webSlots.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(slots.chatSlots.isEmpty ? l.descendantsNoWeb : l.descendantsChatSlots),
          ),
        );
        return;
      }
      final port = await widget.api.openTunnel(
        widget.instanceId,
        d.instanceRef,
        slots.webSlots.first,
      );
      if (!await widget.api.launch(Uri.parse('http://127.0.0.1:$port/'))) {
        messenger.showSnackBar(SnackBar(content: Text(l.chatsBrowserFailed)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.descendantsOpenFailed(_errorDetail(e)))));
    }
  }

  String _stateText(AppLocalizations l, DescendantStateView s) => switch (s) {
    DescendantStateView.alive => l.descendantsStateAlive,
    DescendantStateView.stopped => l.descendantsStateStopped,
    DescendantStateView.notVerifiable => l.descendantsStateNotVerifiable,
    DescendantStateView.notChecked => l.descendantsStateNotChecked,
  };

  bool _diedWithMu(DescendantView d) {
    final n = BigInt.tryParse(d.leftoverMu ?? '');
    return d.state == DescendantStateView.stopped && n != null && n > BigInt.zero;
  }

  Widget _row(BuildContext context, DescendantView d, {required bool root}) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final red = rustFor(context);
    final checked = d.lastCheckedAt == null
        ? l.descendantsNeverChecked
        : l.descendantsLastCheck(formatTxTime(d.lastCheckedAt!.toInt() * 1000));
    final service = d.serviceId == null || d.serviceId!.isEmpty
        ? l.descendantsServiceUnknown
        : l.descendantsService(_short(d.serviceId!));
    final receipts = root ? null : widget.api.receipts(widget.instanceId, d.instanceRef);
    final busy = _busy.contains(d.instanceRef);
    return Padding(
      key: Key('descendant-${root ? 'root' : d.instanceRef}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            root ? l.descendantsThisInstance : '${l.descendantsDepth('${d.depth}')} · ${_short(d.instanceRef)}',
            style: t.primary,
          ),
          Text(service, style: t.secondary),
          Text(
            _stateText(l, d.state),
            key: Key('descendant-state-${root ? 'root' : d.instanceRef}'),
            style: d.state == DescendantStateView.notVerifiable || _diedWithMu(d)
                ? t.primary.copyWith(color: red)
                : t.primary,
          ),
          Text(checked, style: t.secondary),
          if (_diedWithMu(d))
            Container(
              key: Key('descendant-alert-${d.instanceRef}'),
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.descendantsDiedWithMuTitle, style: t.primary.copyWith(color: red)),
                  Text(
                    findingText(
                      l,
                      DescendantFindingView(
                        kind: DescendantFindingKind.stoppedWithMu,
                        instanceRef: d.instanceRef,
                        reason: d.stopReason ?? '',
                        leftoverMu: d.leftoverMu,
                        fatherGone: d.fatherGone,
                        text: '',
                      ),
                    ),
                    style: t.secondary,
                  ),
                ],
              ),
            ),
          if (d.state == DescendantStateView.notVerifiable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.descendantsRefused, style: t.secondary.copyWith(color: red)),
            ),
          if (receipts != null && (receipts.streams > BigInt.zero || receipts.faults.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InstanceReceiptsSection(view: receipts),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              // A stopped account has nothing more to check: nothing follows a stop.
              if (d.state != DescendantStateView.stopped)
                OutlinedButton(
                  key: Key('descendant-check-${root ? 'root' : d.instanceRef}'),
                  onPressed: busy ? null : () => _check(d),
                  child: Text(l.descendantsCheck),
                ),
              if (!root && d.state == DescendantStateView.alive)
                OutlinedButton(
                  key: Key('descendant-open-${d.instanceRef}'),
                  onPressed: () => _open(d),
                  child: Text(l.descendantsOpen),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    if (view == null) return const SizedBox.shrink();
    final l = context.l10n;
    final t = HomeText.of(context);
    return Column(
      key: const Key('info-descendants'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.descendantsTitle.toUpperCase(), style: t.label),
        const SizedBox(height: 4),
        _row(context, view.root, root: true),
        for (final d in view.descendants) ...[
          const Divider(height: 1),
          _row(context, d, root: false),
        ],
        const SizedBox(height: 8),
        Text(l.descendantsNote, style: t.secondary),
      ],
    );
  }
}
