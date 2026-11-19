import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_format.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/payers.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_scene.dart';
import '../home/home_style.dart';
import '../layout.dart';
import 'skill_service_choice.dart';
import 'skill_store.dart';

/// The page of one skill, as the page of an app in a store: its big mark (it flies from
/// the card that opened it), its name and field, one main action (Run), a row of facts that
/// the catalog has (rank, declared services, the backing of its publisher, the block of its
/// box), its text with "more", its tags, and its services, ranked, the best first and
/// recommended ([SkillServiceChoice], issue #122). The main action runs the chosen service
/// (the recommended one at first); each service also has its own pill.
///
/// For the chosen service it shows the node that the balancer would use and its start
/// cost, if [previewQuote] is given and a node gives a quote. The page returns the id of
/// the service to run, or nothing if the user goes back. Running is done by the caller
/// (the confirmation, then the launch), as from the sheet that this page replaces.
class SkillDetailScreen extends StatefulWidget {
  const SkillDetailScreen({
    super.key,
    required this.skill,
    required this.loadServices,
    this.previewQuote,
    this.wallets,
    this.heroTag,
    this.rank,
    this.actionLabel,
  });

  final SkillView skill;

  /// The ranked services of the skill (its box id).
  final Future<List<SkillServiceView>> Function(String skillBoxId) loadServices;

  /// The best quote for a service on the nodes of the list, or null if there is none.
  final Future<QuoteView?> Function(String serviceId)? previewQuote;

  /// The full wallets: Run needs one. Null: no check (the page only picks a service).
  final FullWallets? wallets;

  /// The tag of the hero of the mark on the card that opened the page.
  final Object? heroTag;

  /// The place of the skill in "Top skills" (1 is the most backed); null if not known.
  final int? rank;

  /// The word of the actions; null for Run.
  final String? actionLabel;

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
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
    final wallets = widget.wallets;
    if (wallets == null) return;
    final gate = fullWalletGate(await wallets.payers());
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

  Future<QuoteView?> _previewOf(String serviceId) =>
      _previews.putIfAbsent(serviceId, () => widget.previewQuote!(serviceId).catchError((_) => null));

  bool get _canRun => _gate != FullWalletGate.none;

  void _runService(String serviceId) => Navigator.of(context).pop(serviceId);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final skill = widget.skill;
    final services = _services;
    final chosen = _chosen;
    final action = widget.actionLabel ?? l.celautRunButton;
    final glow = skillGlow(skill, Theme.of(context).brightness);
    final prose = skill.prose.trim();
    final tags = [
      for (final tag in skill.tags)
        if (tag.trim().isNotEmpty) tag.trim(),
    ];
    return SceneBackdrop(
      child: Stack(
        children: [
          // The glow of the skill, from the top of the screen (behind the bar) down to
          // nothing: no edge.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top + kToolbarHeight + 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      glow,
                      glow.withValues(alpha: glow.a * 0.6),
                      glow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(),
            body: Stack(
              children: [
                ReadableWidth(
                  child: ListView(
                    key: const Key('skill-detail'),
                    padding: EdgeInsets.fromLTRB(homeGutter, 4, homeGutter, 32 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      SkillDetailHeader(
                        skill: skill,
                        heroTag: widget.heroTag,
                        action: SkillRunButton(
                          key: const Key('skill-detail-run'),
                          filled: true,
                          label: action,
                          busy: _loading,
                          semanticsLabel: '$action ${skill.name}',
                          onPressed: chosen == null || !_canRun ? null : () => _runService(chosen),
                        ),
                      ),
                      if (chosen != null && widget.previewQuote != null) ...[
                        const SizedBox(height: 10),
                        _preview(context, chosen),
                      ],
                      if (!_canRun) ...[
                        const SizedBox(height: 10),
                        Text(l.celautNoFullWallet, key: const Key('skill-detail-no-wallet'), style: t.secondary),
                      ],
                      const SizedBox(height: 18),
                      SkillStats(skill: skill, rank: widget.rank),
                      if (prose.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        StoreSectionTitle(l.celautSkillAbout),
                        const SizedBox(height: 8),
                        SkillProse(prose),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          key: const Key('skill-detail-tags'),
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final tag in tags) SkillTag(tag)],
                        ),
                      ],
                      const SizedBox(height: 26),
                      StoreSectionTitle(l.celautRunServicesTitle),
                      const SizedBox(height: 10),
                      if (_loading)
                        const _ServicesSkeleton(key: Key('skill-detail-loading'))
                      else if (_error != null)
                        StoreMessage(
                          icon: Icons.cloud_off_outlined,
                          text: CelautStrings.errorText(_error!.kind),
                          textKey: const Key('skill-detail-error'),
                          action: OutlinedButton(
                            key: const Key('skill-detail-retry'),
                            // The theme asks for the full width, which a column of text does not need.
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _read,
                            child: Text(l.celautRunRetry),
                          ),
                        )
                      else if (services != null && services.isEmpty)
                        StoreMessage(
                          icon: Icons.inventory_2_outlined,
                          text: l.celautRunNoServices,
                          textKey: const Key('skill-detail-empty'),
                        ),
                      if (services != null && services.isNotEmpty) ...[
                        const SkillTestDataBanner(),
                        const SizedBox(height: 10),
                        SkillServiceChoice(
                          services: services,
                          chosen: chosen,
                          onChoose: (id) => setState(() => _chosen = id),
                          keyPrefix: 'skill-service',
                          showRun: true,
                          runLabel: widget.actionLabel,
                          onRun: _canRun ? _runService : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
          return Text(l.celautRunPreviewLoading, key: const Key('skill-detail-preview-loading'), style: t.secondary);
        }
        final quote = snapshot.data;
        if (quote == null) return const SizedBox.shrink();
        return Text(
          l.celautRunPreview('${quote.address.host}:${quote.address.port}', muOrUnknown(quote.costMu)),
          key: const Key('skill-detail-preview'),
          style: t.secondary,
        );
      },
    );
  }
}

/// The top of the page of a skill: its big mark, its name, its field and the main action.
class SkillDetailHeader extends StatelessWidget {
  const SkillDetailHeader({super.key, required this.skill, this.heroTag, this.action, this.nameKey});

  final SkillView skill;
  final Object? heroTag;
  final Widget? action;
  final Key? nameKey;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final field = skill.domain.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillMark(skill: skill, size: 104, heroTag: heroTag),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  skill.name,
                  key: nameKey ?? const Key('skill-detail-name'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.primary.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
              if (field.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  field,
                  key: const Key('skill-detail-field'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.secondary.copyWith(fontSize: 14),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ],
    );
  }
}

/// The facts of a skill in a row, as the row under the name of an app in a store: each a
/// small caption, a big value and a note. Only what the catalog has: the rank in "Top
/// skills", the declared services, the backing of the publisher (its reputation, in ERG)
/// and the block of the skill box. A fact that is not known is left out.
class SkillStats extends StatelessWidget {
  const SkillStats({super.key, required this.skill, this.rank});

  final SkillView skill;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final backing = skillBackingText(skill);
    final r = rank;
    final stats = <Widget>[
      if (r != null)
        _Stat(
          key: const Key('skill-stat-rank'),
          caption: l.celautSkillStatRank,
          value: '#$r',
          note: l.celautSkillStatRankNote,
        ),
      _Stat(
        key: const Key('skill-stat-services'),
        caption: l.celautSkillStatServices,
        value: '${skill.serviceIds.length}',
        note: l.celautSkillStatServicesNote,
      ),
      if (backing != null)
        _Stat(
          key: const Key('skill-stat-backing'),
          caption: l.celautSkillStatBacking,
          value: backing,
          note: l.celautSkillStatBackingNote,
        ),
      if (skill.height > 0)
        _Stat(
          key: const Key('skill-stat-block'),
          caption: l.celautSkillStatBlock,
          value: NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(skill.height),
          note: l.celautSkillStatBlockNote,
        ),
    ];
    final line = Theme.of(context).dividerColor;
    return Container(
      key: const Key('skill-detail-stats'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: line.withValues(alpha: 0.6))),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: line.withValues(alpha: 0.6)),
              Expanded(child: stats[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.caption, required this.value, required this.note});

  final String caption;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    return Semantics(
      container: true,
      label: '$caption: $value, $note',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Text(
                caption.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.secondary.copyWith(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, maxLines: 1, style: t.primary.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 2),
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The text of a skill: three lines, and "more" for the rest if it does not fit.
class SkillProse extends StatefulWidget {
  const SkillProse(this.text, {super.key});

  final String text;

  @override
  State<SkillProse> createState() => _SkillProseState();
}

class _SkillProseState extends State<SkillProse> {
  static const _lines = 3;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final style = t.primary.copyWith(color: t.ink.withValues(alpha: 0.85), height: 1.4);
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _lines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final long = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                key: const Key('skill-detail-prose'),
                maxLines: _open ? null : _lines,
                overflow: _open ? null : TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (long)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('skill-detail-more'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 36), visualDensity: VisualDensity.compact),
                  onPressed: () => setState(() => _open = !_open),
                  child: Text(_open ? l.celautSkillLess : l.celautSkillMore),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The services while they load: grey cards where they will be.
class _ServicesSkeleton extends StatelessWidget {
  const _ServicesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final shade = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    return Semantics(
      label: context.l10n.celautSkillServicesLoading,
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              height: 76,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: shade, borderRadius: BorderRadius.circular(cardRadius)),
            ),
        ],
      ),
    );
  }
}
