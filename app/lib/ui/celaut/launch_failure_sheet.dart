import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/launch_problems.dart';
import '../../celaut/launcher.dart';
import '../../celaut/service_transfer.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';
import 'closing_text.dart';

/// Show why a launch failed: one line for each node, with the reason, what to do, and the
/// text of the node under "Details" (`docs/celaut/ui.md`).
Future<void> showLaunchFailureSheet(
  BuildContext context,
  LaunchFailure failure, {
  VoidCallback? onDeposit,
  ValueChanged<TransferOffer>? onSendService,
  String? libraryPath,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LaunchFailureSheet(
      failure: failure,
      libraryPath: libraryPath,
      onDeposit: onDeposit == null
          ? null
          : () {
              Navigator.of(context).pop();
              onDeposit();
            },
      onSendService: onSendService == null
          ? null
          : (offer) {
              Navigator.of(context).pop();
              onSendService(offer);
            },
    ),
  );
}

/// The content of the sheet of a failed launch.
class LaunchFailureSheet extends StatelessWidget {
  const LaunchFailureSheet({
    super.key,
    required this.failure,
    this.onDeposit,
    this.onSendService,
    this.libraryPath,
  });

  final LaunchFailure failure;

  /// The file of this service in the library of the app, if the user loaded it. The offer
  /// to send the service then uses that file.
  final String? libraryPath;

  /// Open the deposit screen. The button is shown only for a credit problem.
  final VoidCallback? onDeposit;

  /// Give the service to a node that does not have it (`docs/celaut/package.md`). The
  /// section is shown only when some node said that it lacks the service.
  final ValueChanged<TransferOffer>? onSendService;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final problems = problemsOf(failure);
    final intro = switch (failure.kind) {
      LaunchFailureKind.noNodes => l.celautRunFailedNoNodes,
      LaunchFailureKind.noQuotes => l.celautRunFailedNoQuotes,
      LaunchFailureKind.allFailed => l.celautRunFailedAll,
    };
    final needsDeposit = problems.any((p) => p.action == ProblemAction.addDeposit);
    final offer = onSendService == null
        ? null
        : transferOfferOf(failure, libraryPath: libraryPath);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('launch-failure'),
        padding: const EdgeInsets.fromLTRB(homeGutter, 0, homeGutter, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.celautRunFailedTitle, style: t.title),
            const SizedBox(height: 8),
            Text(intro, key: const Key('launch-failure-intro'), style: t.secondary),
            const SizedBox(height: 12),
            for (final p in problems) ...[
              _ProblemTile(problem: p),
              const SizedBox(height: 10),
            ],
            if (offer != null) ...[
              const SizedBox(height: 4),
              _MissingSection(offer: offer, onSend: () => onSendService!(offer)),
              const SizedBox(height: 10),
            ],
            if (needsDeposit && onDeposit != null) ...[
              const SizedBox(height: 4),
              FilledButton(
                key: const Key('launch-failure-deposit'),
                onPressed: onDeposit,
                child: Text(l.celautRunDeposit),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('launch-failure-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.celautRunClose),
            ),
          ],
        ),
      ),
    );
  }
}

String _hostPort(NodeAddress a) => '${a.host}:${a.port}';

/// The nodes that do not have the service, and the way to give it to one of them.
class _MissingSection extends StatelessWidget {
  const _MissingSection({required this.offer, required this.onSend});

  final TransferOffer offer;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final to = _hostPort(offer.to);
    final fromNode = offer.source == TransferSource.node && offer.from != null;
    final fromLibrary = offer.source == TransferSource.library;
    return Column(
      key: const Key('launch-missing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The list above says which nodes lack it.
        Text(l.celautSendMissingTitle, style: t.label),
        if (!fromNode && !fromLibrary) ...[
          const SizedBox(height: 6),
          Text(l.celautSendNoHolder, style: t.secondary),
        ],
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('launch-send-service'),
          onPressed: onSend,
          child: Text(
            fromLibrary
                ? l.celautSendFromLibrary(to)
                : fromNode
                    ? l.celautSendFromNode(_hostPort(offer.from!), to)
                    : l.celautSendFromFile(to),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({required this.problem});

  final LaunchProblem problem;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final p = problem;
    final credit = p.kind == CelautErrorKind.insufficientCredit &&
        p.creditMu != null &&
        p.costMu != null;
    final lines = <String>[
      if (p.leftOut) l.celautRunLeftOut,
      if (credit)
        l.celautRunNeedsCredit(muOrUnknown(p.creditMu), muOrUnknown(p.costMu))
      else
        CelautStrings.errorText(p.kind),
      if (p.kind == CelautErrorKind.nodeClosed) ?openingNote(context, p.opensAt),
    ];
    return Column(
      key: Key('launch-problem-${p.address}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.address,
          style: t.primary.copyWith(fontFamily: 'monospace', fontSize: 13.5),
        ),
        const SizedBox(height: 2),
        for (final line in lines) Text(line, style: t.secondary),
        if (p.message.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: Key('launch-details-${p.address}'),
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.celautRunDetails, style: t.label),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    p.message,
                    style: t.secondary.copyWith(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
