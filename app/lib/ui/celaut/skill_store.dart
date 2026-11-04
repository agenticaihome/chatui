import 'package:flutter/material.dart';

import '../../bridge/api/celaut_catalog.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';

/// The skills of the catalog as a store shows its apps: a card for each skill with its
/// mark, its name, its field, the start of its text and a few of its tags. The catalog has
/// no price and no reputation for a skill: the price comes from the nodes and the
/// reputation is per service, so both show in the sheet of a skill's services.

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
  const SkillMark({super.key, required this.skill, this.size = 52});

  final SkillView skill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = skillMarkColors(skill, Theme.of(context).brightness);
    final name = skill.name.trim();
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

/// A skill of the catalog as a card of the store. [onTap] opens its services.
class SkillCard extends StatelessWidget {
  const SkillCard({super.key, required this.skill, this.onTap});

  final SkillView skill;
  final VoidCallback? onTap;

  /// The tags shown on a card; the others are in the search.
  static const shownTags = 3;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final colors = ArgusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final domain = skill.domain.trim();
    final tags = [
      for (final tag in skill.tags)
        if (tag.trim().isNotEmpty && tag.trim().toLowerCase() != skillCategory(skill)) tag.trim(),
    ].take(shownTags).toList();
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: colors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Icon(Icons.chevron_right, size: 20, color: t.muted),
              ),
            ],
          ),
        ),
      ),
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
      decoration: BoxDecoration(
        color: ArgusColors.of(context).chip,
        borderRadius: BorderRadius.circular(8),
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
