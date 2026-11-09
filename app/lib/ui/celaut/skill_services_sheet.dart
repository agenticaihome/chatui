import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/payers.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';

/// The services of one skill, best first, as a bottom sheet. The best is chosen at first.
/// For the chosen service it shows the node that the balancer would use and the start
/// cost, if a node gives a quote. It returns the id of the service when the user taps Run,
/// or nothing if the sheet is closed. Running is done by the caller.
class SkillServicesSheet extends StatefulWidget {
  const SkillServicesSheet({
    super.key,
    required this.skill,
    required this.loadServices,
    required this.previewQuote,
    required this.wallets,
  });

  final SkillView skill;

  /// The ranked services of the skill.
  final Future<List<SkillServiceView>> Function(String skillBoxId) loadServices;

  /// The best quote for a service on the nodes of the list, or null if there is none.
  final Future<QuoteView?> Function(String serviceId) previewQuote;

  /// The full wallets: Run needs one.
  final FullWallets wallets;

  @override
  State<SkillServicesSheet> createState() => _SkillServicesSheetState();
}

class _SkillServicesSheetState extends State<SkillServicesSheet> {
  List<SkillServiceView>? _services;
  bool _loading = true;
  CelautError? _error;
  String? _chosen;

  /// The other services, beyond the best, are folded until the user asks for them.
  bool _showAll = false;
  FullWalletGate _gate = FullWalletGate.open;
  final _previews = <String, Future<QuoteView?>>{};

  @override
  void initState() {
    super.initState();
    _read();
    _readGate();
  }

  Future<void> _readGate() async {
    final gate = fullWalletGate(await widget.wallets.payers());
    if (mounted) setState(() => _gate = gate);
  }

  Future<void> _read() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = await widget.loadServices(widget.skill.boxId);
      if (!mounted) return;
      setState(() {
        _services = services;
        _chosen = services.isEmpty ? null : services.first.serviceId;
      });
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (e) {
      if (mounted) {
        setState(() => _error = CelautError(kind: CelautErrorKind.protocol, message: '$e'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<QuoteView?> _previewOf(String serviceId) => _previews.putIfAbsent(
    serviceId,
    () => widget.previewQuote(serviceId).catchError((_) => null),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final services = _services;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('skill-sheet'),
        padding: const EdgeInsets.fromLTRB(homeGutter, 0, homeGutter, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.skill.name, key: const Key('skill-sheet-name'), style: t.title),
            const SizedBox(height: 4),
            Text(l.celautRunServicesTitle.toUpperCase(), style: t.label),
            const SizedBox(height: 10),
            if (_loading)
              Text(l.celautRunLoading, key: const Key('skill-sheet-loading'), style: t.secondary)
            else if (_error != null) ...[
              Text(
                CelautStrings.errorText(_error!.kind),
                key: const Key('skill-sheet-error'),
                style: t.secondary,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('skill-sheet-retry'),
                onPressed: _read,
                child: Text(l.celautRunRetry),
              ),
            ] else if (services != null && services.isEmpty)
              Text(l.celautRunNoServices, key: const Key('skill-sheet-empty'), style: t.secondary),
            // The best service, chosen already, is what most users take: the others are one
            // tap away, and stay in view if the user chose one of them.
            for (var i = 0; i < (services?.length ?? 0); i++)
              if (i == 0 || _showAll || services![i].serviceId == _chosen) ...[
                _serviceRow(context, services![i], best: i == 0),
                const SizedBox(height: 4),
              ],
            if (services != null && services.length > 1)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('skill-sheet-more'),
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll
                        ? l.celautRunFewerOptions
                        : l.celautRunMoreOptions('${services.length - 1}'),
                  ),
                ),
              ),
            if (_chosen != null) ...[
              const SizedBox(height: 4),
              _preview(context, _chosen!),
              const SizedBox(height: 12),
              if (_gate == FullWalletGate.none)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l.celautNoFullWallet,
                    key: const Key('skill-sheet-no-wallet'),
                    style: t.secondary,
                  ),
                ),
              FilledButton(
                key: const Key('skill-sheet-run'),
                onPressed: _gate == FullWalletGate.none
                    ? null
                    : () => Navigator.of(context).pop(_chosen),
                child: Text(l.celautRunButton),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _serviceRow(BuildContext context, SkillServiceView service, {required bool best}) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final chosen = _chosen == service.serviceId;
    return InkWell(
      key: Key('skill-service-${service.serviceId}'),
      onTap: () => setState(() => _chosen = service.serviceId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              chosen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              key: Key(chosen ? 'skill-service-chosen' : 'skill-service-not-chosen'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l.celautRunScore('${(service.score * 100).round()}%'),
                        style: t.primary,
                      ),
                      if (best) ...[
                        const SizedBox(width: 8),
                        Text(l.celautRunBest, key: const Key('skill-service-best'), style: t.label),
                      ],
                    ],
                  ),
                  // The start of the id is enough to tell two services apart; the whole id is in
                  // the info of the service. Not selectable: a selectable text takes the tap
                  // that chooses the row.
                  Text(
                    '${service.serviceId.substring(0, 8)}…',
                    style: t.secondary.copyWith(fontFamily: 'monospace', fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, String serviceId) {
    final l = context.l10n;
    final t = HomeText.of(context);
    return FutureBuilder<QuoteView?>(
      key: ValueKey('preview-$serviceId'),
      future: _previewOf(serviceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Text(
            l.celautRunPreviewLoading,
            key: const Key('skill-sheet-preview-loading'),
            style: t.secondary,
          );
        }
        final quote = snapshot.data;
        if (quote == null) return const SizedBox.shrink();
        return Text(
          l.celautRunPreview(
            '${quote.address.host}:${quote.address.port}',
            muOrUnknown(quote.costMu),
          ),
          key: const Key('skill-sheet-preview'),
          style: t.secondary,
        );
      },
    );
  }
}
