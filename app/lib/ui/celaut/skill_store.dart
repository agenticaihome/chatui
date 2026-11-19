import 'package:flutter/material.dart';

import '../../bridge/api/celaut_catalog.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';

/// The skills of the catalog as an app store shows its apps (issue #122, then the
/// "app store" look of 2026-11-19). The data is the catalog's and nothing more: a skill has a
/// name, a text, tags, a field, its declared services, the reputation of its publisher and
/// the block of its box. It has no price and no score: the price comes from the nodes and
/// the score is per service, so both show on the page of the skill, next to its services.
///
/// The store home ([RunServiceSection]): the most backed skill as a featured card, then
/// the skills in shelves by field ([storeShelves]), then "Top skills", the whole catalog
/// ranked, most backed first ([rankSkills]), with its first [storeShortList] rows and "Show
/// more". A search shows the rows that match, in groups by field ([skillGroups]). A tap on a
/// skill opens its page (`skill_detail_screen.dart`); the Run pill of a row runs its
/// recommended service, after the usual confirmation (`docs/celaut/ui.md`, section 2.1).

/// The field of a skill, for grouping: [SkillView.domain] with no case and no spaces at
/// the ends. Empty if the publisher gave none.
String skillCategory(SkillView skill) => skill.domain.trim().toLowerCase();

/// True if [query] (already in lower case) is in the name, the text, a tag or the field
/// of [skill].
bool skillMatches(SkillView skill, String query) {
  if (query.isEmpty) return true;
  bool has(String text) => text.toLowerCase().contains(query);
  return has(skill.name) || has(skill.prose) || has(skill.domain) || skill.tags.any(has);
}

/// The rows of "Top skills" before "Show more".
const storeShortList = 6;

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

/// [skills] with the most backed first: the reputation of the publisher, then the number
/// of declared services, then the newest, then the name. The featured skill is the first;
/// "Top skills" is this order.
List<SkillView> rankSkills(List<SkillView> skills) => [...skills]..sort(_byBacking);

/// A group of the list of skills: the skills of one field. [key] is [skillCategory] (empty
/// for the skills with no field) and [title] the field as its first skill writes it.
typedef SkillGroup = ({String key, String title, List<SkillView> skills});

/// [skills] in groups by field, in their order: a group comes where its first skill is,
/// and keeps the order of its skills. The skills with no field are one group, with an
/// empty title.
List<SkillGroup> skillGroups(List<SkillView> skills) {
  final groups = <String, SkillGroup>{};
  for (final s in skills) {
    groups.putIfAbsent(skillCategory(s), () => (key: skillCategory(s), title: s.domain.trim(), skills: <SkillView>[]))
        .skills
        .add(s);
  }
  return groups.values.toList();
}

/// A shelf of the store home: a row of skill tiles that scrolls sideways. [key] is the
/// field ([skillCategory]) of a shelf of one field, or [mixedShelfKey] for the shelf of the
/// fields with one skill each; [title] is the field as its first skill writes it, empty for
/// the mixed shelf.
typedef SkillShelf = ({String key, String title, List<SkillView> skills});

/// The key of the shelf that holds the fields with a single skill.
const mixedShelfKey = 'mixed';

/// The shelves of the store home, from [ranked] (the order of [rankSkills]): one shelf for
/// each field with two skills or more, in the order of [skillGroups]; the skills of the
/// other fields (and those with no field) all go to one last shelf, in their order, where
/// each tile names its field. A shelf of one tile would be most of the store in a catalog
/// with many fields of one skill each (the live catalog of 2026-11 has 7 skills in 6 fields).
List<SkillShelf> storeShelves(List<SkillView> ranked) {
  final groups = skillGroups(ranked);
  final shelves = <SkillShelf>[
    for (final g in groups)
      if (g.key.isNotEmpty && g.skills.length >= 2) (key: g.key, title: g.title, skills: g.skills),
  ];
  final own = {for (final s in shelves) s.key};
  final rest = [for (final s in ranked) if (!own.contains(skillCategory(s))) s];
  if (rest.isNotEmpty) shelves.add((key: mixedShelfKey, title: '', skills: rest));
  return shelves;
}

/// The reputation of a publisher (nanoERG, as the catalog gives it) as ERG with its unit,
/// with at most three decimals; null if unknown (0).
String? skillBackingText(SkillView skill) {
  final nano = skill.publisherReputation;
  if (!nano.isFinite || nano <= 0) return null;
  return formatErg(nano.round(), maxFrac: 3);
}

/// The colours of the mark of a skill: a tile and its letter. The hue comes from the
/// field (or the name, with no field), so the skills of one field share it. The letter
/// meets 4.5:1 on the tile in each brightness (skill_store_test.dart).
({Color tile, Color letter}) skillMarkColors(SkillView skill, Brightness brightness) {
  final hue = skillHue(skill);
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

/// The hue of a skill, in degrees, one of [skillMarkHues]: from its field, or its name if
/// it has none. FNV-1a, 32 bits, as the robots of the instances: the same on every phone.
double skillHue(SkillView skill) {
  final seed = skillCategory(skill).isEmpty ? skill.name.toLowerCase() : skillCategory(skill);
  var h = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return skillMarkHues[h % skillMarkHues.length];
}

/// The glow of a skill: its hue, soft, for the featured card and the top of its page.
Color skillGlow(SkillView skill, Brightness brightness) => brightness == Brightness.dark
    ? HSLColor.fromAHSL(0.42, skillHue(skill), 0.45, 0.32).toColor()
    : HSLColor.fromAHSL(0.55, skillHue(skill), 0.7, 0.86).toColor();

/// The hues of the marks, in degrees: eight, 45 degrees apart.
const skillMarkHues = [15.0, 60.0, 105.0, 150.0, 195.0, 240.0, 285.0, 330.0];

/// The tag of the [Hero] of the mark of [skill] in one [place] of the store. A skill can be
/// in several places of one screen (featured, a shelf, Top skills), and two heroes of one
/// screen cannot share a tag.
Object skillHeroTag(String place, SkillView skill) => ('skill-mark', place, skill.boxId);

/// The mark of a skill: the first letter of its name on a rounded tile. With [heroTag] it
/// flies to the page of the skill.
class SkillMark extends StatelessWidget {
  const SkillMark({super.key, required this.skill, this.size = 52, this.letter, this.heroTag});

  final SkillView skill;
  final double size;

  /// The text whose first letter the tile shows; null for the name of the skill.
  final String? letter;

  /// The tag of its [Hero]; null for none.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = skillMarkColors(skill, Theme.of(context).brightness);
    final name = (letter ?? skill.name).trim();
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
    final tile = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.tile,
          borderRadius: BorderRadius.circular(size * 0.27),
          border: Border.all(color: colors.letter.withValues(alpha: 0.12)),
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
    final tag = heroTag;
    return tag == null ? tile : Hero(tag: tag, child: tile);
  }
}

/// The one action of a skill or of a service, as the pill of a store ("Get"): Run, or
/// [label]. With [busy] it shows a small progress in place of its text and does nothing.
class SkillRunButton extends StatelessWidget {
  const SkillRunButton({
    super.key,
    required this.onPressed,
    this.label,
    this.busy = false,
    this.semanticsLabel,
    this.filled = false,
  });

  final VoidCallback? onPressed;
  final String? label;
  final bool busy;

  /// What a screen reader says, as "Run Proof of reserves": the label alone repeats on
  /// every row.
  final String? semanticsLabel;

  /// The strong colour, for the main action of a page; else the soft one of a row.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final text = label ?? context.l10n.celautRunButton;
    // The theme asks for the full width, which a row cannot give.
    final style = FilledButton.styleFrom(
      minimumSize: Size(filled ? 96 : 72, filled ? 40 : 34),
      padding: EdgeInsets.symmetric(horizontal: filled ? 26 : 18),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2),
    );
    final child = busy
        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    final onTap = busy ? null : onPressed;
    final button = filled
        ? FilledButton(onPressed: onTap, style: style, child: child)
        : FilledButton.tonal(onPressed: onTap, style: style, child: child);
    final said = semanticsLabel;
    return said == null
        ? button
        : Semantics(
            label: said,
            button: true,
            enabled: onTap != null,
            excludeSemantics: true,
            onTap: onTap,
            child: button,
          );
  }
}

/// The field of a skill as a small coloured eyebrow, in capitals.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        height: 1.3,
        color: color ?? accentTextOf(context),
      ),
    );
  }
}

/// The surface of a card of the store: the colour of a card, its border, and the tap.
class _StoreSurface extends StatelessWidget {
  const _StoreSurface({required this.child, this.onTap, this.radius = 20, this.border});

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: onTap == null ? null : context.l10n.celautStoreOpenHint,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: border ?? BorderSide(color: ArgusColors.of(context).cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// The most backed skill, at the top of the store: a tall card in the glow of its hue,
/// with a ring, "Most backed", its mark, its name, two lines of its text, its field and its
/// number of services, and the Run pill.
class SkillFeatureCard extends StatelessWidget {
  const SkillFeatureCard({
    super.key,
    required this.skill,
    this.onTap,
    this.onRun,
    this.runKey,
    this.busy = false,
    this.heroTag,
  });

  final SkillView skill;
  final VoidCallback? onTap;
  final VoidCallback? onRun;
  final Key? runKey;
  final bool busy;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final glow = skillGlow(skill, Theme.of(context).brightness);
    final prose = skill.prose.trim();
    final field = skill.domain.trim();
    final services = skill.serviceIds.length;
    return _StoreSurface(
      radius: 24,
      onTap: onTap,
      // The ring of the top skill.
      border: BorderSide(color: accentOf(context), width: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [glow, glow.withValues(alpha: 0)],
            stops: const [0, 0.85],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _Eyebrow(l.celautStoreFeatured)),
                  Semantics(label: l.celautStoreRank(1), excludeSemantics: true, child: const _TopBadge(text: '#1')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkillMark(skill: skill, size: 64, heroTag: heroTag),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.primary.copyWith(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2),
                        ),
                        if (field.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _Eyebrow(field, color: t.muted),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (prose.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  prose,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.secondary.copyWith(color: t.ink.withValues(alpha: 0.8), fontSize: 13.5),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: services == 0
                        ? const SizedBox.shrink()
                        : Text(
                            l.celautStoreServices(services),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.secondary,
                          ),
                  ),
                  SkillRunButton(
                    key: runKey,
                    onPressed: onRun,
                    busy: busy,
                    semanticsLabel: l.celautStoreRunSkill(skill.name),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: accentOf(context), borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: ArgusColors.of(context).onAccent,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A tile of a shelf: a tall rounded card with the mark, the field (on the mixed shelf),
/// the name in two lines at most, one line of the text and the number of services.
class SkillTile extends StatelessWidget {
  const SkillTile({
    super.key,
    required this.skill,
    this.onTap,
    this.showField = false,
    this.heroTag,
    this.width = 156,
  });

  final SkillView skill;
  final VoidCallback? onTap;
  final bool showField;
  final Object? heroTag;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final field = skill.domain.trim();
    final prose = skill.prose.trim();
    final services = skill.serviceIds.length;
    return SizedBox(
      width: width,
      child: _StoreSurface(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkillMark(skill: skill, size: 56, heroTag: heroTag),
              const SizedBox(height: 12),
              if (showField) _Eyebrow(field.isEmpty ? l.celautStoreOtherField : field),
              Text(
                skill.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.primary.copyWith(fontWeight: FontWeight.w600, height: 1.25),
              ),
              if (prose.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(prose, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.secondary),
              ],
              const Spacer(),
              if (services > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l.celautStoreServices(services),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.secondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of a ranked list, as in the charts of an app store: the mark, the rank (if any),
/// the name, one line of the text, the field (with [showField]; not under the title of a
/// group of one field), and the Run pill on the right. Without [onRun], an arrow in place
/// of the pill.
class SkillRow extends StatelessWidget {
  const SkillRow({
    super.key,
    required this.skill,
    this.rank,
    this.onTap,
    this.onRun,
    this.runKey,
    this.busy = false,
    this.heroTag,
    this.divider = true,
    this.showField = false,
  });

  final SkillView skill;
  final int? rank;
  final bool showField;
  final VoidCallback? onTap;
  final VoidCallback? onRun;
  final Key? runKey;
  final bool busy;
  final Object? heroTag;

  /// A thin line under the text, as between the rows of a list.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final prose = skill.prose.trim();
    final field = skill.domain.trim();
    final r = rank;
    final row = Row(
      children: [
        Expanded(
          child: Semantics(
            label: r == null ? null : l.celautStoreRank(r),
            hint: onTap == null ? null : l.celautStoreOpenHint,
            button: onTap != null,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SkillMark(skill: skill, size: 56, heroTag: heroTag),
                    if (r != null)
                      SizedBox(
                        width: 34,
                        child: ExcludeSemantics(
                          child: Text(
                            '$r',
                            textAlign: TextAlign.center,
                            style: t.primary.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: t.muted),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.primary.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (prose.isNotEmpty)
                            Text(
                              prose,
                              key: Key('skill-card-line-${skill.boxId}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.secondary,
                            ),
                          if (showField && field.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _Eyebrow(field, color: t.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (onRun != null || busy)
          SkillRunButton(
            key: runKey,
            onPressed: onRun,
            busy: busy,
            semanticsLabel: l.celautStoreRunSkill(skill.name),
          )
        else
          Icon(Icons.chevron_right, size: 20, color: t.muted),
      ],
    );
    if (!divider) return row;
    final line = Theme.of(context).dividerColor.withValues(alpha: 0.5);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      child: row,
    );
  }
}

/// A title of a part of the store, as "Top skills", with an optional action on the right.
class StoreSectionTitle extends StatelessWidget {
  const StoreSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.primary.copyWith(fontSize: 19, fontWeight: FontWeight.w700, height: 1.25),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The store while the catalog is read: grey shapes where the featured card, a shelf and
/// rows will be. It does not move: a still shape says "loading" as well, and costs no frame.
class StoreSkeleton extends StatelessWidget {
  const StoreSkeleton({super.key, this.rows = 4, this.featured = true});

  final int rows;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final shade = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    Widget box(double w, double h, {double r = 8}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: shade, borderRadius: BorderRadius.circular(r)),
        );
    return Semantics(
      label: context.l10n.celautRunLoading,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (featured) ...[
              box(double.infinity, 168, r: 24),
              const SizedBox(height: 22),
              Row(children: [box(120, 18)]),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(child: box(double.infinity, 150, r: 20)),
                      if (i < 2) const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            for (var i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    box(56, 56, r: 15),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [box(140, 14), const SizedBox(height: 8), box(200, 11)],
                      ),
                    ),
                    box(72, 34, r: 17),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A state of the store with no skill to show: an icon in a soft circle, a line, and an
/// optional action (Try again).
class StoreMessage extends StatelessWidget {
  const StoreMessage({super.key, required this.icon, required this.text, this.action, this.textKey});

  final IconData icon;
  final String text;
  final Widget? action;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.06), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: t.muted),
            ),
          ),
          const SizedBox(height: 14),
          Text(text, key: textKey, textAlign: TextAlign.center, style: t.primary.copyWith(color: t.muted)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// A tag of a skill, as a chip.
class SkillTag extends StatelessWidget {
  const SkillTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      // The chip colour is the card's own on some palettes: the border draws the tag.
      decoration: BoxDecoration(
        color: ArgusColors.of(context).chip,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArgusColors.of(context).cardBorder),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
