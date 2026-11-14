import 'package:flutter/material.dart';

import '../../bridge/api/celaut_package.dart';
import '../../l10n/l10n.dart';
import '../settings/settings_shared.dart';

/// The setting "Do not keep the filesystem of a service" (`docs/celaut/package.md`,
/// "Without the filesystem"). On: a service that the user loads from a file or a link is kept
/// without the content of its filesystem, to save space; it cannot then be given to a node
/// that lacks it. Off by default. The core keeps the setting in the Celaut database.
class PackagesStorageRow extends StatefulWidget {
  const PackagesStorageRow({super.key, this.read, this.write});

  /// Read and write the setting. Tests give their own.
  final bool Function()? read;
  final void Function(bool)? write;

  @override
  State<PackagesStorageRow> createState() => _PackagesStorageRowState();
}

class _PackagesStorageRowState extends State<PackagesStorageRow> {
  late bool _on = _read();

  bool _read() {
    try {
      return (widget.read ?? celautPackagesWithoutFilesystem)();
    } catch (_) {
      // The core is not ready (or has no database): the default, off.
      return false;
    }
  }

  void _set(bool value) {
    try {
      (widget.write ?? (v) => celautSetPackagesWithoutFilesystem(enabled: v))(value);
    } catch (_) {
      // The setting is not stored: the switch stays where it was.
      return;
    }
    setState(() => _on = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return SettingsRow(
      icon: Icons.compress_outlined,
      title: t.celautKeepNoFilesystemTitle,
      subtitle: t.celautKeepNoFilesystemSubtitle,
      trailing: Switch(
        key: const Key('settings-keep-no-filesystem'),
        value: _on,
        onChanged: _set,
      ),
    );
  }
}
