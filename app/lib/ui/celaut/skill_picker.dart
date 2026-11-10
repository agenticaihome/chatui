import 'package:flutter/material.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_catalog.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/service_strings.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';
import '../settings/settings_shared.dart';
import '../widgets/soft_card.dart';
import 'skill_service_choice.dart';
import 'skill_store.dart';

/// Pick a skill of the catalog (`docs/celaut/catalog.md`), then one of the services that
/// cover it. The skills are in groups by field, the most backed first, with a short list
/// and "Show more". The services come ranked: the best is recommended and chosen at first,
/// the others are one tap away ([SkillServiceChoice], issue #122). The screen returns the
/// id of the chosen service (64 hexadecimal characters), or nothing if the user goes back.
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

  /// The whole list of skills is shown, not only the first [storeShortList].
  bool _showAll = false;

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
    final l = context.l10n;
    final t = HomeText.of(context);
    final muted = ArgusColors.of(context).muted;
    final ranked = rankSkills(_skills ?? const <SkillView>[]);
    final cut = !_showAll && ranked.length > storeShortList;
    return [
      SettingsNote(l.celautSkillsIntro),
      if (_loadingSkills)
        const SoftCard(child: Text(ServiceStrings.skillsLoading, key: Key('picker-loading')))
      else if (_skills != null && ranked.isEmpty)
        SoftCard(child: Text(ServiceStrings.skillsEmpty, style: TextStyle(color: muted))),
      for (final g in skillGroups(cut ? ranked.take(storeShortList).toList() : ranked)) ...[
        Padding(
          key: Key('picker-group-${g.key}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: Text((g.title.isEmpty ? l.celautStoreOtherField : g.title).toUpperCase(), style: t.label),
        ),
        for (final skill in g.skills) ...[
          SkillCard(
            key: Key('picker-skill-${skill.boxId}'),
            skill: skill,
            onTap: () => _readServices(skill),
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

  List<Widget> _serviceList(BuildContext context, SkillView skill) {
    final muted = ArgusColors.of(context).muted;
    final services = _services;
    return [
      Text(
        skill.name,
        key: const Key('picker-skill-name'),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      SkillAbout(skill: skill),
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
        const SkillTestDataBanner(),
        const SizedBox(height: 10),
        SkillServiceChoice(
          services: services,
          chosen: _chosen,
          onChoose: (id) => setState(() => _chosen = id),
          keyPrefix: 'picker-service',
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('picker-use'),
          onPressed: _chosen == null ? null : () => Navigator.of(context).pop(_chosen),
          child: Text(context.l10n.celautSkillUse),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('picker-other-skill'),
        onPressed: _backToSkills,
        child: const Text(ServiceStrings.otherSkill),
      ),
    ];
  }
}
