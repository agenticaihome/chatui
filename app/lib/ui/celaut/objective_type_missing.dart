import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../home/home_style.dart';
import '../../theme/argus_theme.dart';
import '../settings/registry_settings_page.dart';

/// The empty state of the catalog of objectives when the objective type id is not set
/// (Settings, Compute, "Celaut Registry"). It says why the catalog is empty and opens the
/// settings. [onBack] runs after the user comes back from the settings, so that the
/// screen reads the catalog again.
class ObjectiveTypeMissing extends StatelessWidget {
  const ObjectiveTypeMissing({super.key, this.onBack});

  final VoidCallback? onBack;

  Future<void> _open(BuildContext context) async {
    await Navigator.push(context, fadeRoute(const RegistrySettingsPage()));
    onBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    return Column(
      key: const Key('objective-type-missing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.registryNoObjectiveTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 6),
        Text(l.registryNoObjectiveBody, style: t.secondary),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const Key('objective-type-open-settings'),
          // The theme asks for the full width, which a column of text does not need.
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => _open(context),
          child: Text(l.registryOpenSettings),
        ),
      ],
    );
  }
}
