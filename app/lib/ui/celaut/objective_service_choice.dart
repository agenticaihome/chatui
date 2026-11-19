import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/api/celaut_catalog.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';

/// The step of a skill's services, with little to read (issue #122): one recommended
/// service and one main action; the other services, the id, the exact score and where the
/// data comes from are one tap away. The ranking does not change: the recommended service
/// is the first of the ranking (`docs/celaut/catalog.md`).

/// How good a service looks, in plain words: the score of the ranking (0 to 1) in three
/// levels. The exact number is in the details only.
enum ServiceRating { high, medium, low }

/// The level of [score]: from 0.7 high, from 0.4 medium, else low. A service with no
/// result and no reputation scores 0.5 (medium).
ServiceRating serviceRatingOf(double score) => score >= 0.7
    ? ServiceRating.high
    : score >= 0.4
        ? ServiceRating.medium
        : ServiceRating.low;

String serviceRatingText(AppLocalizations l, ServiceRating r) => switch (r) {
      ServiceRating.high => l.celautSkillRatingHigh,
      ServiceRating.medium => l.celautSkillRatingMedium,
      ServiceRating.low => l.celautSkillRatingLow,
    };

/// A service id in short form: the first 6 and the last 4 characters.
String shortServiceId(String id) => id.length <= 12 ? id : '${id.substring(0, 6)}…${id.substring(id.length - 4)}';

/// The one warning about test data, at the top of the step: not on each card.
class SkillTestDataBanner extends StatelessWidget {
  const SkillTestDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('skill-test-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: t.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.celautSkillTestBanner, style: t.secondary)),
        ],
      ),
    );
  }
}

/// The services of a skill as a choice: the first (the best of the ranking) is the main
/// card, "Recommended"; the others are under "Other options (N)", closed at first. A tap on
/// a card chooses it; [chosen] has a check. The keys start with [keyPrefix]: the card of a
/// service is `<prefix>-<id>`, the check `<prefix>-chosen`, the label of the first
/// `<prefix>-recommended`, the closed part `<prefix>-others`.
class SkillServiceChoice extends StatelessWidget {
  const SkillServiceChoice({
    super.key,
    required this.services,
    required this.chosen,
    required this.onChoose,
    required this.keyPrefix,
  });

  final List<SkillServiceView> services;
  final String? chosen;
  final ValueChanged<String> onChoose;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    final t = HomeText.of(context);
    final others = services.skip(1).toList();
    Widget card(SkillServiceView s, {required bool recommended}) => SkillServiceCard(
          key: Key('$keyPrefix-${s.serviceId}'),
          service: s,
          recommended: recommended,
          chosen: chosen == s.serviceId,
          onTap: () => onChoose(s.serviceId),
          keyPrefix: keyPrefix,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(services.first, recommended: true),
        if (others.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: Key('$keyPrefix-others'),
              tilePadding: EdgeInsets.zero,
              dense: true,
              // A chosen other option stays in view.
              initiallyExpanded: others.any((s) => s.serviceId == chosen),
              title: Text(context.l10n.celautSkillOtherOptions('${others.length}'), style: t.label),
              children: [
                for (final s in others) ...[
                  card(s, recommended: false),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One service of a skill: its rating as a level with a short bar, where its data comes
/// from as an icon with a tooltip, an "Unverified" chip if no publisher declared it, and a
/// closed "Details" part with the short id, a Copy action for the full id, the exact score
/// and where the data comes from in words.
class SkillServiceCard extends StatefulWidget {
  const SkillServiceCard({
    super.key,
    required this.service,
    required this.recommended,
    required this.chosen,
    required this.onTap,
    required this.keyPrefix,
  });

  final SkillServiceView service;
  final bool recommended;
  final bool chosen;
  final VoidCallback onTap;
  final String keyPrefix;

  @override
  State<SkillServiceCard> createState() => _SkillServiceCardState();
}

class _SkillServiceCardState extends State<SkillServiceCard> {
  bool _details = false;

  Future<void> _copy() async {
    final l = context.l10n;
    await Clipboard.setData(ClipboardData(text: widget.service.serviceId));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.celautSkillIdCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = widget.service;
    final p = widget.keyPrefix;
    final id = s.serviceId;
    final rating = serviceRatingOf(s.score);
    final source = s.direct ? l.celautSkillDeclared : l.celautSkillFromResults;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: widget.chosen
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide(color: ArgusColors.of(context).cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: widget.recommended
                        ? Text(l.celautSkillRecommended.toUpperCase(), key: Key('$p-recommended'), style: t.label)
                        : const SizedBox.shrink(),
                  ),
                  if (widget.chosen)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle, key: Key('$p-chosen'), size: 20, color: scheme.primary),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    l.celautSkillRating(serviceRatingText(l, rating)),
                    key: Key('$p-rating-$id'),
                    style: t.primary.copyWith(fontWeight: FontWeight.w600),
                  ),
                  _RatingBar(rating),
                  Tooltip(
                    message: source,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Semantics(
                      label: source,
                      child: Icon(
                        s.direct ? Icons.verified_outlined : Icons.science_outlined,
                        key: Key('$p-source-$id'),
                        size: 18,
                        color: t.muted,
                      ),
                    ),
                  ),
                  if (!s.direct) _UnverifiedChip(key: Key('$p-unverified-$id')),
                ],
              ),
              TextButton(
                key: Key('$p-details-$id'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _details = !_details),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.celautRunDetails),
                    Icon(_details ? Icons.expand_less : Icons.expand_more, size: 18),
                  ],
                ),
              ),
              if (_details)
                Padding(
                  key: Key('$p-detail-$id'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.celautSkillServiceId(shortServiceId(id)),
                              key: Key('$p-short-id-$id'),
                              style: t.secondary.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                          TextButton(
                            key: Key('$p-copy-$id'),
                            style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                            onPressed: _copy,
                            child: Text(l.commonCopy),
                          ),
                        ],
                      ),
                      Text(l.celautSkillRatingExact(s.score.toStringAsFixed(2)), style: t.secondary),
                      Text(source, style: t.secondary),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The level of a rating as three short segments, filled from the left.
class _RatingBar extends StatelessWidget {
  const _RatingBar(this.rating);

  final ServiceRating rating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = switch (rating) {
      ServiceRating.high => 3,
      ServiceRating.medium => 2,
      ServiceRating.low => 1,
    };
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 14,
              height: 6,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < filled ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnverifiedChip extends StatelessWidget {
  const _UnverifiedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ArgusColors.of(context).cardBorder),
      ),
      child: Text(
        context.l10n.celautSkillUnverified,
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
