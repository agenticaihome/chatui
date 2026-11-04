import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/service_strings.dart';
import '../../theme/argus_theme.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';
import 'skill_store.dart';

/// Pick a skill of the catalog (`docs/celaut/catalog.md`), then one of the services that
/// cover it. The services come ranked, best first, and the best is chosen at first. The
/// screen returns the id of the chosen service (64 hexadecimal characters), or nothing
/// if the user goes back.
class SkillPickerScreen extends StatefulWidget {
  const SkillPickerScreen({super.key, this.loadSkills, this.loadServices});

  /// Read the skills. Tests give their own.
  final Future<List<SkillView>> Function()? loadSkills;

  /// Read the ranked services of a skill (its box id). Tests give their own.
  final Future<List<SkillServiceView>> Function(String skillBoxId)? loadServices;

  @override
  State<SkillPickerScreen> createState() => _SkillPickerScreenState();
}

class _SkillPickerScreenState extends State<SkillPickerScreen> {
  List<SkillView>? _skills;
  bool _loadingSkills = true;

  SkillView? _skill;
  List<SkillServiceView>? _services;
  bool _loadingServices = false;
  String? _chosen;

  CelautError? _error;

  @override
  void initState() {
    super.initState();
    _readSkills();
  }

  Future<void> _readSkills() async {
    setState(() {
      _loadingSkills = true;
      _error = null;
    });
    try {
      final load = widget.loadSkills ?? celautSkills;
      final skills = await load();
      if (mounted) setState(() => _skills = skills);
    } on CelautError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loadingSkills = false);
    }
  }

  Future<void> _readServices(SkillView skill) async {
    setState(() {
      _skill = skill;
      _services = null;
      _chosen = null;
      _loadingServices = true;
      _error = null;
    });
    try {
      final load = widget.loadServices ??
          (String id) => celautSkillServices(skillBoxId: id);
      final services = await load(skill.boxId);
      // The user may have gone to another skill while this one loaded.
      if (!mounted || _skill?.boxId != skill.boxId) return;
      setState(() {
        _services = services;
        _chosen = services.isEmpty ? null : services.first.serviceId;
      });
    } on CelautError catch (e) {
      if (mounted && _skill?.boxId == skill.boxId) setState(() => _error = e);
    } finally {
      if (mounted && _skill?.boxId == skill.boxId) {
        setState(() => _loadingServices = false);
      }
    }
  }

  void _backToSkills() => setState(() {
        _skill = null;
        _services = null;
        _chosen = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final skill = _skill;
    return PopScope(
      canPop: skill == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToSkills();
      },
      child: SettingsPage(
        title: ServiceStrings.skillsTitle,
        children: [
          if (_error != null) _errorCard(context, _error!, skill),
          if (skill == null) ..._skillList(context) else ..._serviceList(context, skill),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, CelautError e, SkillView? skill) {
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
            onPressed: () => skill == null ? _readSkills() : _readServices(skill),
            child: const Text(ServiceStrings.retry),
          ),
        ],
      ),
    );
  }

  List<Widget> _skillList(BuildContext context) {
    final muted = ArgusColors.of(context).muted;
    final skills = _skills;
    return [
      const SettingsNote(ServiceStrings.skillsIntro),
      if (_loadingSkills)
        const SoftCard(child: Text(ServiceStrings.skillsLoading, key: Key('picker-loading')))
      else if (skills != null && skills.isEmpty)
        SoftCard(child: Text(ServiceStrings.skillsEmpty, style: TextStyle(color: muted))),
      for (final skill in skills ?? const <SkillView>[]) ...[
        SkillCard(
          key: Key('picker-skill-${skill.boxId}'),
          skill: skill,
          onTap: () => _readServices(skill),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _serviceList(BuildContext context, SkillView skill) {
    final muted = ArgusColors.of(context).muted;
    final services = _services;
    return [
      Text(
        skill.name,
        key: const Key('picker-skill-name'),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      const SizedBox(height: 10),
      const SectionLabel(ServiceStrings.servicesTitle),
      const SizedBox(height: 10),
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
      for (var i = 0; i < (services?.length ?? 0); i++) ...[
        _serviceCard(context, services![i], best: i == 0),
        const SizedBox(height: 10),
      ],
      if (services != null && services.isNotEmpty) ...[
        FilledButton(
          key: const Key('picker-use'),
          onPressed: _chosen == null ? null : () => Navigator.of(context).pop(_chosen),
          child: const Text(ServiceStrings.useService),
        ),
        const SizedBox(height: 8),
        Text(ServiceStrings.testDataNote, style: TextStyle(fontSize: 12, color: muted)),
      ],
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('picker-other-skill'),
        onPressed: _backToSkills,
        child: const Text(ServiceStrings.otherSkill),
      ),
    ];
  }

  Widget _serviceCard(BuildContext context, SkillServiceView service, {required bool best}) {
    final muted = ArgusColors.of(context).muted;
    final chosen = _chosen == service.serviceId;
    return SoftCard(
      child: InkWell(
        key: Key('picker-service-${service.serviceId}'),
        onTap: () => setState(() => _chosen = service.serviceId),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                chosen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                key: Key(chosen ? 'picker-chosen' : 'picker-not-chosen'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ServiceStrings.serviceScore(service.score.toStringAsFixed(2)),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (best) ...[
                          const SizedBox(width: 8),
                          Text(
                            ServiceStrings.bestService,
                            key: const Key('picker-best'),
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Not selectable: a selectable text takes the tap that chooses the card.
                    Text(
                      service.serviceId,
                      style: TextStyle(fontSize: 11.5, color: muted, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.direct
                          ? ServiceStrings.serviceDeclared
                          : ServiceStrings.serviceFromResults,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
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
