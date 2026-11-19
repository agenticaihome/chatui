import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../celaut/catalog_types.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/service_strings.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';
import 'objective_service_choice.dart';
import 'objective_store.dart';
import 'objective_type_missing.dart';

/// Pick an objective of the catalog (`docs/celaut/catalog.md`), then one of the services that
/// cover it. The objectives are in groups by field, the most backed first, with a short list
/// and "Show more". The services come ranked: the best is recommended and chosen at first,
/// the others are one tap away ([ObjectiveServiceChoice], issue #122). The screen returns the
/// id of the chosen service (64 hexadecimal characters), or nothing if the user goes back.
class ObjectivePickerScreen extends StatefulWidget {
  const ObjectivePickerScreen({super.key, this.loadObjectives, this.loadServices, this.types});

  /// Read the objectives. Tests give their own.
  final Future<List<ObjectiveView>> Function()? loadObjectives;

  /// The type ids of the registry. Tests give their own. With no [loadObjectives] and no
  /// objective type id, the screen shows [ObjectiveTypeMissing] and reads nothing.
  final CatalogTypes? types;

  /// Read the ranked services of an objective (its box id). Tests give their own.
  final Future<List<ObjectiveServiceView>> Function(String objectiveBoxId)? loadServices;

  @override
  State<ObjectivePickerScreen> createState() => _ObjectivePickerScreenState();
}

class _ObjectivePickerScreenState extends State<ObjectivePickerScreen> {
  List<ObjectiveView>? _objectives;
  bool _loadingObjectives = true;

  ObjectiveView? _objective;
  List<ObjectiveServiceView>? _services;
  bool _loadingServices = false;
  String? _chosen;

  /// The whole list of objectives is shown, not only the first [storeShortList].
  bool _showAll = false;

  CelautError? _error;

  late final CatalogTypes _types = widget.types ?? catalogTypes;

  /// The objective type id is not set, and so the catalog is empty.
  bool get _typeMissing => widget.loadObjectives == null && !_types.hasObjective;

  @override
  void initState() {
    super.initState();
    _readObjectives();
  }

  Future<void> _readObjectives() async {
    if (_typeMissing) {
      setState(() {
        _objectives = null;
        _loadingObjectives = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loadingObjectives = true;
      _error = null;
    });
    try {
      final load = widget.loadObjectives ?? () => celautObjectives(types: _types.ids);
      final objectives = await load();
      if (mounted) setState(() => _objectives = objectives);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loadingObjectives = false);
    }
  }

  Future<void> _readServices(ObjectiveView objective) async {
    setState(() {
      _objective = objective;
      _services = null;
      _chosen = null;
      _loadingServices = true;
      _error = null;
    });
    try {
      final load = widget.loadServices ??
          (String id) => celautObjectiveServices(types: _types.ids, objectiveBoxId: id);
      final services = await load(objective.boxId);
      // The user may have gone to another objective while this one loaded.
      if (!mounted || _objective?.boxId != objective.boxId) return;
      setState(() {
        _services = services;
        _chosen = services.isEmpty ? null : services.first.serviceId;
      });
    } on CelautError catch (e) {
      if (mounted && _objective?.boxId == objective.boxId) setState(() => _error = e);
    } finally {
      if (mounted && _objective?.boxId == objective.boxId) {
        setState(() => _loadingServices = false);
      }
    }
  }

  void _backToObjectives() => setState(() {
        _objective = null;
        _services = null;
        _chosen = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final objective = _objective;
    return PopScope(
      canPop: objective == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToObjectives();
      },
      child: SettingsPage(
        title: ServiceStrings.objectivesTitle,
        children: [
          if (_error != null) _errorCard(context, _error!, objective),
          if (objective == null) ..._objectiveList(context) else ..._serviceList(context, objective),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, CelautError e, ObjectiveView? objective) {
    return SoftCard(
      child: Column(
        key: const Key('picker-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CelautStrings.errorText(e.kind),
            style: TextStyle(fontSize: 14, color: rustFor(context)),
          ),
          if (e.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              CelautStrings.detailLabel(e.message),
              style: TextStyle(fontSize: 12, color: ArgusColors.of(context).muted),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('picker-retry'),
            onPressed: () => objective == null ? _readObjectives() : _readServices(objective),
            child: const Text(ServiceStrings.retry),
          ),
        ],
      ),
    );
  }

  List<Widget> _objectiveList(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final muted = ArgusColors.of(context).muted;
    final ranked = rankObjectives(_objectives ?? const <ObjectiveView>[]);
    final cut = !_showAll && ranked.length > storeShortList;
    if (_typeMissing) return [ObjectiveTypeMissing(onBack: _readObjectives)];
    return [
      SettingsNote(l.celautObjectivesIntro),
      if (_loadingObjectives)
        const SoftCard(child: Text(ServiceStrings.objectivesLoading, key: Key('picker-loading')))
      else if (_objectives != null && ranked.isEmpty)
        SoftCard(child: Text(ServiceStrings.objectivesEmpty, style: TextStyle(color: muted))),
      for (final g in objectiveGroups(cut ? ranked.take(storeShortList).toList() : ranked)) ...[
        Padding(
          key: Key('picker-group-${g.key}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: Text((g.title.isEmpty ? l.celautStoreOtherField : g.title).toUpperCase(), style: t.label),
        ),
        for (final objective in g.objectives) ...[
          ObjectiveCard(
            key: Key('picker-objective-${objective.boxId}'),
            objective: objective,
            onTap: () => _readServices(objective),
          ),
          const SizedBox(height: 10),
        ],
      ],
      if (ranked.length > storeShortList)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('picker-more'),
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? l.celautStoreShowFewer : l.celautStoreShowMore(ranked.length - storeShortList)),
          ),
        ),
    ];
  }

  List<Widget> _serviceList(BuildContext context, ObjectiveView objective) {
    final muted = ArgusColors.of(context).muted;
    final services = _services;
    return [
      Text(
        objective.name,
        key: const Key('picker-objective-name'),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      ObjectiveAbout(objective: objective),
      const SizedBox(height: 6),
      if (_loadingServices)
        const SoftCard(child: Text(ServiceStrings.servicesLoading, key: Key('picker-loading')))
      else if (services != null && services.isEmpty)
        SoftCard(
          child: Text(
            ServiceStrings.servicesEmpty,
            key: const Key('picker-no-services'),
            style: TextStyle(color: muted),
          ),
        ),
      if (services != null && services.isNotEmpty) ...[
        const ObjectiveTestDataBanner(),
        const SizedBox(height: 10),
        ObjectiveServiceChoice(
          services: services,
          chosen: _chosen,
          onChoose: (id) => setState(() => _chosen = id),
          keyPrefix: 'picker-service',
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('picker-use'),
          onPressed: _chosen == null ? null : () => Navigator.of(context).pop(_chosen),
          child: Text(context.l10n.celautObjectiveUse),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('picker-other-objective'),
        onPressed: _backToObjectives,
        child: const Text(ServiceStrings.otherObjective),
      ),
    ];
  }
}
