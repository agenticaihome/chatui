import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/payers.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';
import 'skill_service_choice.dart';
import 'skill_store.dart';

/// The services of one skill as a bottom sheet: one recommended service (the best of the
/// ranking, chosen at first), the others under "Other options", and Run ([SkillServiceChoice],
/// issue #122). For the chosen service it shows the node that the balancer would use and the
/// start cost, if a node gives a quote. It returns the id of the service when the user taps
/// Run, or nothing if the sheet is closed. Running is done by the caller.
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
            SkillAbout(skill: widget.skill),
            const SizedBox(height: 6),
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
            if (services != null && services.isNotEmpty) ...[
              const SkillTestDataBanner(),
              const SizedBox(height: 10),
              SkillServiceChoice(
                services: services,
                chosen: _chosen,
                onChoose: (id) => setState(() => _chosen = id),
                keyPrefix: 'skill-service',
              ),
            ],
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
