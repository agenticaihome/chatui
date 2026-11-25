import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bridge/api/celaut_catalog.dart';

/// The default type id of a coverage box of the Celaut Registry. It is the same as
/// `DEFAULT_COVERAGE_TYPE` in the `celaut-catalog` crate.
const defaultCoverageTypeId = '1da6799e935cbb0fb14d359f06f23854c3d1bd509508948cc01b7b018dbbbdf5';

/// The default type id of a benchmark box (`DEFAULT_BENCHMARK_TYPE` in `celaut-catalog`).
const defaultBenchmarkTypeId = 'f6480184daf3b7750a58e58319e12adc5266bd986eec0f57ac451c995a30f54d';

/// The default type id of a result box (`DEFAULT_RESULT_TYPE` in `celaut-catalog`).
const defaultResultTypeId = '49b26dc06b1680769477264d2e8e9bf561005236cde3097630bffcff631b7aef';

/// The default type id of an objective box. It is empty: the registry has a new type NFT
/// for the objectives, and the user sets it.
const defaultObjectiveTypeId = '';

final _typeId = RegExp(r'^[0-9a-fA-F]{64}$');

/// True if [id] is 64 hexadecimal characters.
bool isCatalogTypeId(String id) => _typeId.hasMatch(id);

/// The kinds of box of the registry that have a type id.
enum CatalogTypeKind {
  objective(defaultObjectiveTypeId),
  benchmark(defaultBenchmarkTypeId),
  coverage(defaultCoverageTypeId),
  result(defaultResultTypeId);

  const CatalogTypeKind(this.defaultId);

  /// The id that the app uses when the user did not set one.
  final String defaultId;

  /// The objective id can be empty. The other three need 64 hexadecimal characters.
  bool get canBeEmpty => this == objective;

  /// True if [text] (the user input, with spaces cut off) is an id for this kind.
  bool accepts(String text) {
    final id = text.trim();
    return id.isEmpty ? canBeEmpty : isCatalogTypeId(id);
  }

  String get _key => 'celaut_registry_type_$name';
}

/// The type ids of the Celaut Registry (the type NFTs of its boxes). The catalog uses them
/// to find the boxes on Ergo. The user can change them in Settings, Compute, "Celaut
/// Registry". They are in SharedPreferences. A failed read or write keeps the value in
/// memory only. The ids are in lower case.
///
/// The objective id is empty by default. While it is empty, the catalog has no objective.
class CatalogTypes extends ChangeNotifier {
  CatalogTypes();

  final Map<CatalogTypeKind, String> _ids = {for (final k in CatalogTypeKind.values) k: k.defaultId};

  /// The id of [kind] now.
  String idOf(CatalogTypeKind kind) => _ids[kind]!;

  String get objective => idOf(CatalogTypeKind.objective);

  /// True if the catalog can be read: the objective id is set.
  bool get hasObjective => objective.isNotEmpty;

  /// The four ids, for the calls of the catalog.
  CatalogTypeIds get ids => CatalogTypeIds(
        objective: idOf(CatalogTypeKind.objective),
        coverage: idOf(CatalogTypeKind.coverage),
        benchmark: idOf(CatalogTypeKind.benchmark),
        result: idOf(CatalogTypeKind.result),
      );

  /// Read the saved ids. A saved id that is not valid is ignored: the default is used.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in CatalogTypeKind.values) {
        final saved = p.getString(k._key)?.trim();
        _ids[k] = saved != null && k.accepts(saved) ? saved.toLowerCase() : k.defaultId;
      }
    } catch (_) {
      // Keep the defaults.
    }
    notifyListeners();
  }

  /// Save the ids in [values]. The ids of the kinds that [values] does not name stay as they
  /// are. Throws [ArgumentError], and changes nothing, if one id is not valid.
  Future<void> save(Map<CatalogTypeKind, String> values) async {
    final clean = {for (final e in values.entries) e.key: e.value.trim().toLowerCase()};
    for (final e in clean.entries) {
      if (!e.key.accepts(e.value)) throw ArgumentError.value(e.value, e.key.name, 'not a type id');
    }
    _ids.addAll(clean);
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      for (final e in clean.entries) {
        await p.setString(e.key._key, e.value);
      }
    } catch (_) {
      // Memory-only for this run.
    }
  }

  /// Set [kind] to its default id.
  Future<void> restoreDefault(CatalogTypeKind kind) => save({kind: kind.defaultId});
}

/// The type ids of the app.
final catalogTypes = CatalogTypes();
