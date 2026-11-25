import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env_store.dart';

/// How one environment variable of a preset gets its value at the launch
/// (`docs/celaut/presets.md`, section 3).
enum PresetValueKind {
  /// The value of a variable of the container: the preset keeps only its name. The value
  /// stays in the encrypted database of the app.
  container,

  /// A value that the user typed and did not mark as sensitive: the preset keeps it.
  text,

  /// A value that the user typed, marked as sensitive and did not save: the preset does not
  /// keep it, so the launch asks for it again.
  ask,

  /// The user did not give the variable.
  skip,
}

/// One variable of a preset, or of the settings that an instance was started with.
@immutable
class PresetVariable {
  const PresetVariable.container(this.name, String containerName)
      : kind = PresetValueKind.container,
        value = containerName;
  const PresetVariable.text(this.name, String text)
      : kind = PresetValueKind.text,
        value = text;
  const PresetVariable.ask(this.name)
      : kind = PresetValueKind.ask,
        value = null;
  const PresetVariable.skip(this.name)
      : kind = PresetValueKind.skip,
        value = null;

  /// The name that the service declares.
  final String name;
  final PresetValueKind kind;

  /// The name of the variable of the container, or the typed text; null for [ask] and
  /// [skip].
  final String? value;

  Map<String, String> toJson() => switch (kind) {
        PresetValueKind.container => {'n': name, 'c': value!},
        PresetValueKind.text => {'n': name, 't': value!},
        PresetValueKind.ask => {'n': name, 'k': 'ask'},
        PresetValueKind.skip => {'n': name, 'k': 'skip'},
      };

  /// The variable of [j], or null if [j] is not a valid one. The stored text is not
  /// trusted: a name or a value that the node would refuse is left out.
  static PresetVariable? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = j['n'];
    if (name is! String || envNameProblem(name) != null) return null;
    final c = j['c'], t = j['t'], k = j['k'];
    if (c is String) return envNameProblem(c) == null ? PresetVariable.container(name, c) : null;
    if (t is String) return envValueProblem(t) == null ? PresetVariable.text(name, t) : null;
    if (k == 'ask') return PresetVariable.ask(name);
    if (k == 'skip') return PresetVariable.skip(name);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PresetVariable && other.name == name && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(name, kind, value);

  @override
  String toString() => 'PresetVariable($name, ${kind.name}${value == null ? '' : ', $value'})';
}

/// A service with its settings, on the wheel of the pencil button of Chats
/// (`docs/celaut/presets.md`). It comes from an instance: "Pin as preset" on its info page.
@immutable
class ServicePreset {
  const ServicePreset({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.fromInstance,
    required this.known,
    this.variables = const [],
  });

  /// An id of the preset on this phone. It does not change when the preset is renamed.
  final String id;

  /// The service, by its hash: 64 hexadecimal characters.
  final String serviceId;

  /// The name on the wheel. It is also the name of the instances that it starts.
  final String name;

  /// The instance that it was pinned from: its robot is the icon of the preset, and its
  /// info page says "Pinned".
  final String fromInstance;

  /// True if the app knew the variables that the instance was started with. False for an
  /// instance started before this version, or on another phone: the launch asks for each
  /// variable as for a new service.
  final bool known;

  /// The variables, in the order of the service.
  final List<PresetVariable> variables;

  /// The number of variables that the launch asks for again (typed sensitive values).
  int get asked => variables.where((v) => v.kind == PresetValueKind.ask).length;

  ServicePreset renamed(String name) => ServicePreset(
        id: id,
        serviceId: serviceId,
        name: name,
        fromInstance: fromInstance,
        known: known,
        variables: variables,
      );

  Map<String, Object> toJson() => {
        'id': id,
        's': serviceId,
        'name': name,
        'from': fromInstance,
        'known': known,
        'env': [for (final v in variables) v.toJson()],
      };

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  static ServicePreset? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], s = j['s'], name = j['name'], from = j['from'], known = j['known'], env = j['env'];
    if (id is! String || id.isEmpty || s is! String || !_hex64.hasMatch(s)) return null;
    if (name is! String || from is! String || known is! bool) return null;
    final clean = ServicePresets.cleanName(name);
    if (clean.isEmpty) return null;
    return ServicePreset(
      id: id,
      serviceId: s,
      name: clean,
      fromInstance: from,
      known: known,
      variables: [
        if (env is List)
          for (final v in env) ?PresetVariable.fromJson(v),
      ],
    );
  }
}

/// The presets of the wheel, and the settings that each instance of this phone was started
/// with (the variables, without the secret values), so that an instance can be pinned
/// later. Only this phone knows them: the node gets nothing.
///
/// Stored as one JSON text in SharedPreferences, like the groups of the chats
/// ([ChatGroups]). No secret is in it: a value of the container is kept by its name, and a
/// typed value that the user marked as sensitive is not kept at all
/// (`docs/celaut/presets.md`, section 3). A failed read or write keeps the data in memory
/// only.
class ServicePresets extends ChangeNotifier {
  static const _key = 'celaut_presets_v1';

  /// The most presets on the wheel.
  static const maxPresets = 8;

  /// The longest name of a preset.
  static const maxNameChars = 40;

  /// The most instances whose settings are kept; the oldest go first.
  static const maxLaunches = 200;

  final List<ServicePreset> _presets = [];

  /// The settings of each instance, oldest first.
  final Map<String, List<PresetVariable>> _launched = {};

  /// The presets, in the order of the wheel.
  List<ServicePreset> get presets => List.unmodifiable(_presets);

  bool get isEmpty => _presets.isEmpty;
  bool get full => _presets.length >= maxPresets;

  /// The preset pinned from [instanceId], or null.
  ServicePreset? pinnedFrom(String instanceId) {
    for (final p in _presets) {
      if (p.fromInstance == instanceId) return p;
    }
    return null;
  }

  ServicePreset? byId(String id) {
    for (final p in _presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The variables that [instanceId] was started with, or null if this phone does not know
  /// them.
  List<PresetVariable>? launchedWith(String instanceId) {
    final v = _launched[instanceId];
    return v == null ? null : List.unmodifiable(v);
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final text = p.getString(_key);
      if (text != null) _decode(text);
    } catch (_) {
      // Keep what is in memory.
    }
    notifyListeners();
  }

  void _decode(String text) {
    final data = jsonDecode(text);
    if (data is! Map) return;
    _presets.clear();
    _launched.clear();
    final presets = data['presets'];
    if (presets is List) {
      for (final j in presets) {
        final p = ServicePreset.fromJson(j);
        if (p != null && byId(p.id) == null && _presets.length < maxPresets) _presets.add(p);
      }
    }
    final launched = data['launched'];
    if (launched is Map) {
      for (final e in launched.entries) {
        final k = e.key, v = e.value;
        if (k is! String || v is! List) continue;
        _launched[k] = [for (final j in v) ?PresetVariable.fromJson(j)];
      }
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _key,
        jsonEncode({
          'presets': [for (final p in _presets) p.toJson()],
          'launched': {
            for (final e in _launched.entries) e.key: [for (final v in e.value) v.toJson()],
          },
        }),
      );
    } catch (_) {
      // Memory only for this run.
    }
  }

  Future<void> _changed() async {
    notifyListeners();
    await _save();
  }

  /// A name as the user typed it: one line, trimmed, not too long.
  static String cleanName(String name) {
    final one = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= maxNameChars ? one : one.substring(0, maxNameChars).trimRight();
  }

  /// Keep the variables that [instanceId] was started with. A typed sensitive value must
  /// already be [PresetValueKind.ask]: this class never sees a secret.
  Future<void> recordLaunch(String instanceId, List<PresetVariable> variables) async {
    _launched.remove(instanceId);
    _launched[instanceId] = List.of(variables);
    while (_launched.length > maxLaunches) {
      _launched.remove(_launched.keys.first);
    }
    await _save();
  }

  /// Pin the instance [instanceId] of [serviceId] as a preset named [name], with the
  /// variables that it was started with. Null if the wheel is full, the name is blank, or
  /// the instance is pinned already.
  Future<ServicePreset?> pin({
    required String instanceId,
    required String serviceId,
    required String name,
  }) async {
    final clean = cleanName(name);
    if (clean.isEmpty || full || pinnedFrom(instanceId) != null) return null;
    var n = DateTime.now().microsecondsSinceEpoch;
    while (byId('p$n') != null) {
      n++;
    }
    final launched = _launched[instanceId];
    final preset = ServicePreset(
      id: 'p$n',
      serviceId: serviceId.toLowerCase(),
      name: clean,
      fromInstance: instanceId,
      known: launched != null,
      variables: launched ?? const [],
    );
    _presets.add(preset);
    await _changed();
    return preset;
  }

  /// Give the preset a new name. A blank name changes nothing.
  Future<void> rename(String id, String name) async {
    final clean = cleanName(name);
    final at = _presets.indexWhere((p) => p.id == id);
    if (clean.isEmpty || at < 0 || _presets[at].name == clean) return;
    _presets[at] = _presets[at].renamed(clean);
    await _changed();
  }

  /// Take the preset off the wheel. The instance that it came from does not change.
  Future<void> remove(String id) async {
    final at = _presets.indexWhere((p) => p.id == id);
    if (at < 0) return;
    _presets.removeAt(at);
    await _changed();
  }

  /// Forget the settings of a deleted instance. A preset pinned from it stays.
  Future<void> forget(String instanceId) async {
    if (_launched.remove(instanceId) != null) await _save();
  }
}

final ServicePresets servicePresets = ServicePresets();
