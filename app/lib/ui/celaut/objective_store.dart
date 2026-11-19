import 'package:flutter/material.dart';

import '../../bridge/api/celaut_catalog.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';

/// The objectives of the catalog as a store shows its apps, with little to read at each step
/// (issue #122): a card for each objective with its mark, its name, one line of its text, its
/// number of services and one Run button. The field of the objectives is the title of their
/// group, not a line of each card. The tags are in the search and in [ObjectiveAbout]. The
/// catalog has no price and no score for an objective: the price comes from the nodes and the
/// score is per service, so both show in the step of an objective's services.
///
/// There is one way to browse: one list, in groups by field ([objectiveGroups]), the most backed
/// objectives first ([rankObjectives]). The store shows the first [storeShortList] objectives and a
/// "Show more" action (`docs/celaut/ui.md`, section 2.1).

/// The field of an objective, for grouping: [ObjectiveView.domain] with no case and no spaces at
/// the ends. Empty if the publisher gave none.
String objectiveCategory(ObjectiveView objective) => objective.domain.trim().toLowerCase();

/// True if [query] (already in lower case) is in the name, the text, a tag or the field
/// of [objective].
bool objectiveMatches(ObjectiveView objective, String query) {
  if (query.isEmpty) return true;
  bool has(String text) => text.toLowerCase().contains(query);
  return has(objective.name) || has(objective.prose) || has(objective.domain) || objective.tags.any(has);
}

/// The objectives that the store shows before "Show more".
const storeShortList = 6;

/// The same order on every phone: the name, then the box id.
int _byName(ObjectiveView a, ObjectiveView b) {
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return byName != 0 ? byName : a.boxId.compareTo(b.boxId);
}

/// The reputation of the publisher, then the number of declared services, then the newest.
int _byBacking(ObjectiveView a, ObjectiveView b) {
  final byReputation = b.publisherReputation.compareTo(a.publisherReputation);
  if (byReputation != 0) return byReputation;
  final byServices = b.serviceIds.length.compareTo(a.serviceIds.length);
  if (byServices != 0) return byServices;
  final byHeight = b.height.compareTo(a.height);
  return byHeight != 0 ? byHeight : _byName(a, b);
}

/// [objectives] with the most backed first: the reputation of the publisher, then the number
/// of declared services, then the newest, then the name. This was the order of the
/// featured objectives; the store keeps it for its short list.
List<ObjectiveView> rankObjectives(List<ObjectiveView> objectives) => [...objectives]..sort(_byBacking);

/// A group of the list of objectives: the objectives of one field. [key] is [objectiveCategory] (empty
/// for the objectives with no field) and [title] the field as its first objective writes it.
typedef ObjectiveGroup = ({String key, String title, List<ObjectiveView> objectives});

/// [objectives] in groups by field, in their order: a group comes where its first objective is,
/// and keeps the order of its objectives. The objectives with no field are one group, with an
/// empty title.
List<ObjectiveGroup> objectiveGroups(List<ObjectiveView> objectives) {
  final groups = <String, ObjectiveGroup>{};
  for (final s in objectives) {
    groups.putIfAbsent(objectiveCategory(s), () => (key: objectiveCategory(s), title: s.domain.trim(), objectives: <ObjectiveView>[]))
        .objectives
        .add(s);
  }
  return groups.values.toList();
}

/// The colours of the mark of an objective: a tile and its letter. The hue comes from the
/// field (or the name, with no field), so the objectives of one field share it. The letter
/// meets 4.5:1 on the tile in each brightness (objective_store_test.dart).
({Color tile, Color letter}) objectiveMarkColors(ObjectiveView objective, Brightness brightness) {
  final seed = objectiveCategory(objective).isEmpty ? objective.name.toLowerCase() : objectiveCategory(objective);
  // FNV-1a, 32 bits, as the robots of the instances: the same hue on every phone.
  var h = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  final hue = objectiveMarkHues[h % objectiveMarkHues.length];
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
const objectiveMarkHues = [15.0, 60.0, 105.0, 150.0, 195.0, 240.0, 285.0, 330.0];

/// The mark of an objective: the first letter of its name on a rounded tile.
class ObjectiveMark extends StatelessWidget {
  const ObjectiveMark({super.key, required this.objective, this.size = 52, this.letter});

  final ObjectiveView objective;
  final double size;

  /// The text whose first letter the tile shows; null for the name of the objective.
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final colors = objectiveMarkColors(objective, Theme.of(context).brightness);
    final name = (letter ?? objective.name).trim();
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

/// An objective of the catalog as a card of the store: at most three lines of text, its name,
/// one line of its text and its number of services. [onTap] opens its services. With
/// [onRun], the card has a Run button (key [runKey]) in place of the arrow.
class ObjectiveCard extends StatelessWidget {
  const ObjectiveCard({super.key, required this.objective, this.onTap, this.onRun, this.runKey});

  final ObjectiveView objective;
  final VoidCallback? onTap;
  final VoidCallback? onRun;
  final Key? runKey;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final services = objective.serviceIds.length;
    final count = services == 0
        ? const SizedBox.shrink()
        : Text(
            context.l10n.celautStoreServices(services),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.secondary,
          );
    return _StoreSurface(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, onRun == null ? 8 : 14, onRun == null ? 12 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ObjectiveMark(objective: objective, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    objective.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.primary.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (objective.prose.trim().isNotEmpty)
                    Text(
                      objective.prose.trim(),
                      key: Key('objective-card-line-${objective.boxId}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.secondary,
                    ),
                  if (onRun != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: count),
                        ObjectiveRunButton(key: runKey, onPressed: onRun),
                      ],
                    ),
                  ] else
                    count,
                ],
              ),
            ),
            if (onRun == null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
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
  const _StoreSurface({required this.child, this.onTap});

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

/// The one action of an objective: Run. It opens the services of the objective, with the best one
/// chosen; the run starts after the confirmation, as from the card.
class ObjectiveRunButton extends StatelessWidget {
  const ObjectiveRunButton({super.key, required this.onPressed});

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

/// The details of an objective, closed at first: all its text, its field and its tags. The
/// cards show one line only (issue #122).
class ObjectiveAbout extends StatelessWidget {
  const ObjectiveAbout({super.key, required this.objective});

  final ObjectiveView objective;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final domain = objective.domain.trim();
    final tags = [for (final tag in objective.tags) if (tag.trim().isNotEmpty) tag.trim()];
    if (objective.prose.trim().isEmpty && domain.isEmpty && tags.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('objective-about'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        dense: true,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(l.celautObjectiveAbout, style: t.label),
        children: [
          if (objective.prose.trim().isNotEmpty) Text(objective.prose.trim(), style: t.secondary),
          if (domain.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l.celautObjectiveField(domain), style: t.secondary),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in tags) _Tag(tag)]),
          ],
        ],
      ),
    );
  }
}
