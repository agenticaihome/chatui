import 'package:flutter/material.dart';

import '../../bridge/api/celaut_catalog.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';

/// The skills of the catalog as a store shows its apps: a card for each skill with its
/// mark, its name, its field, the start of its text, a few of its tags and one Run
/// button. The catalog has no price and no score for a skill: the price comes from the
/// nodes and the score is per service, so both show in the sheet of a skill's services.
///
/// The sections of the store come from data on Ergo and on this phone only
/// (`docs/celaut/ui.md`, section 2.1); a section with no skill is not shown:
/// - featured ([featuredSkills]): of each field, the skill whose publisher has the most
///   reputation, then the most declared services;
/// - suggested ([suggestedSkills]): the other skills of the fields of the skills that the
///   user ran (the instances in the app);
/// - new ([newSkills]): the highest block height of the skill box first;
/// - popular ([popularSkills]): the most declared services first.

/// The field of a skill, for grouping: [SkillView.domain] with no case and no spaces at
/// the ends. Empty if the publisher gave none.
String skillCategory(SkillView skill) => skill.domain.trim().toLowerCase();

/// The fields of [skills], the most used first, then by name. Each is the key of
/// [skillCategory] with the text that its first skill gives it.
List<({String key, String label})> skillCategories(List<SkillView> skills) {
  final count = <String, int>{};
  final label = <String, String>{};
  for (final s in skills) {
    final key = skillCategory(s);
    if (key.isEmpty) continue;
    count[key] = (count[key] ?? 0) + 1;
    label.putIfAbsent(key, () => s.domain.trim());
  }
  final keys = count.keys.toList()
    ..sort((a, b) {
      final byCount = count[b]!.compareTo(count[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final k in keys) (key: k, label: label[k]!)];
}

/// True if [query] (already in lower case) is in the name, the text, a tag or the field
/// of [skill].
bool skillMatches(SkillView skill, String query) {
  if (query.isEmpty) return true;
  bool has(String text) => text.toLowerCase().contains(query);
  return has(skill.name) || has(skill.prose) || has(skill.domain) || skill.tags.any(has);
}

/// The most skills in a row of the store.
const storeRowSize = 8;

/// The most featured skills.
const featuredSize = 5;

/// The same order on every phone: the name, then the box id.
int _byName(SkillView a, SkillView b) {
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return byName != 0 ? byName : a.boxId.compareTo(b.boxId);
}

/// The reputation of the publisher, then the number of declared services, then the newest.
int _byBacking(SkillView a, SkillView b) {
  final byReputation = b.publisherReputation.compareTo(a.publisherReputation);
  if (byReputation != 0) return byReputation;
  final byServices = b.serviceIds.length.compareTo(a.serviceIds.length);
  if (byServices != 0) return byServices;
  final byHeight = b.height.compareTo(a.height);
  return byHeight != 0 ? byHeight : _byName(a, b);
}

/// The featured skills: of each field, the one with the most backing ([_byBacking]), the
/// skills with no field counting as one field. Only skills that a publisher declared a
/// service for: the others cannot run.
List<SkillView> featuredSkills(List<SkillView> skills) {
  final best = <String, SkillView>{};
  for (final s in [for (final s in skills) if (s.serviceIds.isNotEmpty) s]..sort(_byBacking)) {
    best.putIfAbsent(skillCategory(s), () => s);
  }
  return (best.values.toList()..sort(_byBacking)).take(featuredSize).toList();
}

/// The newest skills: the highest block height first. A skill with no height is not here.
List<SkillView> newSkills(List<SkillView> skills) {
  final known = [for (final s in skills) if (s.height > 0) s]
    ..sort((a, b) {
      final byHeight = b.height.compareTo(a.height);
      return byHeight != 0 ? byHeight : _byName(a, b);
    });
  return known.take(storeRowSize).toList();
}

/// The popular skills: the most declared services first, then the backing. A skill with no
/// service is not here.
List<SkillView> popularSkills(List<SkillView> skills) {
  final served = [for (final s in skills) if (s.serviceIds.isNotEmpty) s]
    ..sort((a, b) {
      final byServices = b.serviceIds.length.compareTo(a.serviceIds.length);
      return byServices != 0 ? byServices : _byBacking(a, b);
    });
  return served.take(storeRowSize).toList();
}

/// An instance that the user started, as the suggestions read it.
typedef RanService = ({String serviceId, String name});

/// True if the user ran [skill]: an instance has one of its services, or its name (the
/// store gives the instance the name of the skill).
bool skillWasRun(SkillView skill, Iterable<RanService> ran) {
  final ids = {for (final id in skill.serviceIds) id.toLowerCase()};
  final name = skill.name.trim().toLowerCase();
  return ran.any((r) => ids.contains(r.serviceId.toLowerCase()) || (name.isNotEmpty && r.name.trim().toLowerCase() == name));
}

/// The suggestions: the skills that the user did not run, in the fields of the skills that
/// the user ran, the most backed first. Empty if the user ran no skill with a field.
List<SkillView> suggestedSkills(List<SkillView> skills, Iterable<RanService> ran) {
  final history = ran.toList();
  if (history.isEmpty) return const [];
  final run = {for (final s in skills) if (skillWasRun(s, history)) s.boxId};
  final fields = {
    for (final s in skills)
      if (run.contains(s.boxId) && skillCategory(s).isNotEmpty) skillCategory(s),
  };
  final suggested = [
    for (final s in skills)
      if (!run.contains(s.boxId) && fields.contains(skillCategory(s))) s,
  ]..sort(_byBacking);
  return suggested.take(storeRowSize).toList();
}

/// The colours of the mark of a skill: a tile and its letter. The hue comes from the
/// field (or the name, with no field), so the skills of one field share it. The letter
/// meets 4.5:1 on the tile in each brightness (skill_store_test.dart).
({Color tile, Color letter}) skillMarkColors(SkillView skill, Brightness brightness) {
  final seed = skillCategory(skill).isEmpty ? skill.name.toLowerCase() : skillCategory(skill);
  // FNV-1a, 32 bits, as the robots of the instances: the same hue on every phone.
  var h = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  final hue = skillMarkHues[h % skillMarkHues.length];
  return brightness == Brightness.dark
      ? (
          tile: HSLColor.fromAHSL(1, hue, 0.32, 0.25).toColor(),
          letter: HSLColor.fromAHSL(1, hue, 0.6, 0.84).toColor(),
        )
      : (
          tile: HSLColor.fromAHSL(1, hue, 0.55, 0.89).toColor(),
          letter: HSLColor.fromAHSL(1, hue, 0.55, 0.28).toColor(),
        );
}

/// The hues of the marks, in degrees: eight, 45 degrees apart.
const skillMarkHues = [15.0, 60.0, 105.0, 150.0, 195.0, 240.0, 285.0, 330.0];

/// The mark of a skill: the first letter of its name on a rounded tile.
class SkillMark extends StatelessWidget {
  const SkillMark({super.key, required this.skill, this.size = 52, this.letter});

  final SkillView skill;
  final double size;

  /// The text whose first letter the tile shows; null for the name of the skill.
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final colors = skillMarkColors(skill, Theme.of(context).brightness);
    final name = (letter ?? skill.name).trim();
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.tile,
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        // The tile has a fixed size: the letter does not grow with the font of the phone.
        child: MediaQuery.withNoTextScaling(
          child: Text(
            initial,
            style: TextStyle(fontSize: size * 0.46, fontWeight: FontWeight.w700, color: colors.letter, height: 1),
          ),
        ),
      ),
    );
  }
}

/// A skill of the catalog as a card of the store. [onTap] opens its services. With
/// [onRun], the card has a Run button (key [runKey]) in place of the arrow.
class SkillCard extends StatelessWidget {
  const SkillCard({super.key, required this.skill, this.onTap, this.onRun, this.runKey});

  final SkillView skill;
  final VoidCallback? onTap;
  final VoidCallback? onRun;
  final Key? runKey;

  /// The tags shown on a card; the others are in the search.
  static const shownTags = 3;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final domain = skill.domain.trim();
    final tags = [
      for (final tag in skill.tags)
        if (tag.trim().isNotEmpty && tag.trim().toLowerCase() != skillCategory(skill)) tag.trim(),
    ].take(shownTags).toList();
    final services = skill.serviceIds.length;
    return _StoreSurface(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 14, onRun == null ? 8 : 14, onRun == null ? 14 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkillMark(skill: skill),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.primary.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (domain.isNotEmpty)
                    Text(
                      domain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.secondary.copyWith(color: accentTextOf(context)),
                    ),
                  if (skill.prose.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(skill.prose, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.secondary),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final tag in tags) _Tag(tag)],
                    ),
                  ],
                  if (onRun != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: services == 0
                              ? const SizedBox.shrink()
                              : Text(
                                  context.l10n.celautStoreServices(services),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.secondary,
                                ),
                        ),
                        SkillRunButton(key: runKey, onPressed: onRun),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onRun == null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Icon(Icons.chevron_right, size: 20, color: t.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// The surface of a card of the store: the colour of a card, its border, and the tap.
class _StoreSurface extends StatelessWidget {
  const _StoreSurface({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: ArgusColors.of(context).cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// The one action of a skill: Run. It opens the services of the skill, with the best one
/// chosen; the run starts after the confirmation, as from the card.
class SkillRunButton extends StatelessWidget {
  const SkillRunButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      // The theme asks for the full width, which a row cannot give.
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(context.l10n.celautRunButton),
    );
  }
}

/// The field of a skill and its number of services, on one line.
String _skillMeta(BuildContext context, SkillView skill) {
  final parts = [
    if (skill.domain.trim().isNotEmpty) skill.domain.trim(),
    if (skill.serviceIds.isNotEmpty) context.l10n.celautStoreServices(skill.serviceIds.length),
  ];
  return parts.join(' · ');
}

/// A skill in a row of the store: the mark, the name, the field, and Run. Compact, so
/// that a row is short.
class SkillTile extends StatelessWidget {
  const SkillTile({super.key, required this.skill, this.onTap, this.onRun, this.runKey});

  final SkillView skill;
  final VoidCallback? onTap;
  final VoidCallback? onRun;
  final Key? runKey;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final meta = _skillMeta(context, skill);
    return _StoreSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            SkillMark(skill: skill, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    skill.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.primary.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (meta.isNotEmpty)
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SkillRunButton(key: runKey, onPressed: onRun),
          ],
        ),
      ),
    );
  }
}

/// A featured skill: a large card with the start of its text.
class SkillFeatureCard extends StatelessWidget {
  const SkillFeatureCard({super.key, required this.skill, this.onTap, this.onRun, this.runKey});

  final SkillView skill;
  final VoidCallback? onTap;
  final VoidCallback? onRun;
  final Key? runKey;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final domain = skill.domain.trim();
    final services = skill.serviceIds.length;
    return _StoreSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkillMark(skill: skill, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.primary.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (domain.isNotEmpty)
                        Text(
                          domain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.secondary.copyWith(color: accentTextOf(context)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (skill.prose.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(skill.prose, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.secondary),
            ],
            const Spacer(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    services == 0 ? '' : context.l10n.celautStoreServices(services),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.secondary,
                  ),
                ),
                SkillRunButton(key: runKey, onPressed: onRun),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A section of the store: its title, one line that says where its skills come from, and
/// its cards side by side, which scroll sideways. The cards of a row have one height.
class StoreRow extends StatelessWidget {
  const StoreRow({
    super.key,
    required this.title,
    required this.hint,
    required this.cardWidth,
    required this.children,
  });

  final String title;
  final String hint;
  final double cardWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: homeGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: t.label),
              Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.secondary.copyWith(fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: homeGutter),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  SizedBox(width: cardWidth, child: children[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The fields of the catalog as tiles, with the number of skills of each. A tap chooses
/// the field, as its chip does.
class SkillCategoryGrid extends StatelessWidget {
  const SkillCategoryGrid({super.key, required this.skills, required this.onSelected});

  final List<SkillView> skills;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final categories = skillCategories(skills);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final columns = box.maxWidth >= 560 ? 3 : 2;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in categories)
              SizedBox(
                width: width,
                child: _StoreSurface(
                  key: Key('run-field-${c.key}'),
                  onTap: () => onSelected(c.key),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        SkillMark(
                          skill: skills.firstWhere((s) => skillCategory(s) == c.key),
                          size: 32,
                          letter: c.label,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.primary),
                              Text(
                                context.l10n.celautStoreSkills(
                                  skills.where((s) => skillCategory(s) == c.key).length,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.secondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      // The chip colour is the card's own on some palettes: the border draws the tag.
      decoration: BoxDecoration(
        color: ArgusColors.of(context).chip,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ArgusColors.of(context).cardBorder),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

/// The fields of the catalog as a row of chips, "All" first. [selected] is a key of
/// [skillCategories], or null for all.
class SkillCategoryBar extends StatelessWidget {
  const SkillCategoryBar({
    super.key,
    required this.categories,
    required this.selected,
    required this.allLabel,
    required this.onSelected,
  });

  final List<({String key, String label})> categories;
  final String? selected;
  final String allLabel;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String? key, String label) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(
            key: Key('run-category-${key ?? 'all'}'),
            label: Text(label),
            selected: selected == key,
            showCheckmark: false,
            onSelected: (_) => onSelected(key),
          ),
        );
    return SingleChildScrollView(
      key: const Key('run-categories'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(null, allLabel),
          for (final c in categories) chip(c.key, c.label),
        ],
      ),
    );
  }
}
