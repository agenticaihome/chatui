import 'package:flutter/material.dart';

import '../../celaut/catalog_types.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';
import 'settings_shared.dart';

/// Settings, Compute, "Celaut Registry": the type ids of the boxes of the registry
/// ([CatalogTypes]). The Objective id is empty by default, and then the catalog is empty.
/// The other three have a default. Each field has "Restore default". An id that is not 64
/// hexadecimal characters (or empty, for the Objective) is not saved.
class RegistrySettingsPage extends StatefulWidget {
  const RegistrySettingsPage({super.key, this.types});

  /// The type ids of the app. Tests give their own.
  final CatalogTypes? types;

  @override
  State<RegistrySettingsPage> createState() => _RegistrySettingsPageState();
}

class _RegistrySettingsPageState extends State<RegistrySettingsPage> {
  late final CatalogTypes _types = widget.types ?? catalogTypes;
  late final Map<CatalogTypeKind, TextEditingController> _fields = {
    for (final k in CatalogTypeKind.values) k: TextEditingController(text: _types.idOf(k)),
  };

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(CatalogTypeKind kind) {
    final l = context.l10n;
    return switch (kind) {
      CatalogTypeKind.objective => l.registryTypeObjective,
      CatalogTypeKind.benchmark => l.registryTypeBenchmark,
      CatalogTypeKind.coverage => l.registryTypeCoverage,
      CatalogTypeKind.result => l.registryTypeResult,
    };
  }

  String? _error(CatalogTypeKind kind) {
    if (kind.accepts(_fields[kind]!.text)) return null;
    final l = context.l10n;
    return kind.canBeEmpty ? l.registryTypeInvalidOrEmpty : l.registryTypeInvalid;
  }

  bool get _valid => CatalogTypeKind.values.every((k) => k.accepts(_fields[k]!.text));

  Future<void> _save() async {
    if (!_valid) {
      setState(() {});
      return;
    }
    await _types.save({for (final k in CatalogTypeKind.values) k: _fields[k]!.text});
    if (!mounted) return;
    for (final k in CatalogTypeKind.values) {
      _fields[k]!.text = _types.idOf(k);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.registryTypesSaved)));
  }

  Future<void> _restore(CatalogTypeKind kind) async {
    await _types.restoreDefault(kind);
    if (mounted) setState(() => _fields[kind]!.text = _types.idOf(kind));
  }

  Widget _field(CatalogTypeKind kind) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: Key('registry-type-${kind.name}'),
            controller: _fields[kind],
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: _label(kind),
              helperText: kind.canBeEmpty ? l.registryTypeObjectiveHelper : null,
              helperMaxLines: 2,
              errorText: _error(kind),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: Key('registry-restore-${kind.name}'),
              onPressed: _fields[kind]!.text == kind.defaultId && idIsSaved(kind) ? null : () => _restore(kind),
              child: Text(l.registryRestoreDefault),
            ),
          ),
        ],
      ),
    );
  }

  /// True if the saved id of [kind] is the text in its field.
  bool idIsSaved(CatalogTypeKind kind) => _types.idOf(kind) == _fields[kind]!.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    return SettingsPage(
      title: l.registrySettingsTitle,
      children: [
        Text(l.registrySettingsIntro, key: const Key('registry-intro'), style: t.secondary),
        const SizedBox(height: 16),
        for (final kind in CatalogTypeKind.values) _field(kind),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('registry-save'),
            // The theme asks for the full width; this button is alone in its row.
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _save,
            child: Text(l.commonSave),
          ),
        ),
      ],
    );
  }
}
