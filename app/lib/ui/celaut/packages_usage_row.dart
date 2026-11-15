import 'package:flutter/material.dart';

import '../../bridge/api/celaut_package.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/package_library.dart';
import '../../l10n/l10n.dart';
import '../settings/settings_shared.dart';

/// How much of the phone the services take (`docs/celaut/package.md`, "Space"): the library
/// (the services that the user loaded, with the number of the ones kept without their
/// filesystem), the downloads that stopped, and the copies that wait to be loaded. The sizes
/// are those of the files on the disk. The row reads them when it opens, and again when the
/// user taps it.
class PackagesUsageRow extends StatefulWidget {
  const PackagesUsageRow({super.key, this.load});

  /// Read the space. Tests give their own; the default is [PackageLibrary.storage].
  final Future<PackagesStorageView?> Function()? load;

  @override
  State<PackagesUsageRow> createState() => _PackagesUsageRowState();
}

class _PackagesUsageRowState extends State<PackagesUsageRow> {
  PackagesStorageView? _view;
  bool _failed = false;
  bool _loading = true;
  int _reads = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final read = ++_reads;
    setState(() => _loading = true);
    PackagesStorageView? view;
    var failed = false;
    try {
      view = await (widget.load ?? PackageLibrary().storage)();
      failed = view == null;
    } catch (_) {
      // The core is not ready, or the directory cannot be read.
      failed = true;
    }
    // A later read answers for the row: an old answer does not replace it.
    if (!mounted || read != _reads) return;
    setState(() {
      _view = view;
      _failed = failed;
      _loading = false;
    });
  }

  String _text(AppLocalizations t) {
    final v = _view;
    if (v == null) return _failed ? t.celautStorageUnknown : '';
    final lines = [
      t.celautStorageSummary(v.services, CelautStrings.bytes(v.libraryBytes.toInt())),
      if (v.withoutFilesystem > 0) t.celautStorageWithout(v.withoutFilesystem),
      if (v.downloadsBytes > BigInt.zero) t.celautStorageDownloads(CelautStrings.bytes(v.downloadsBytes.toInt())),
      if (v.incomingBytes > BigInt.zero) t.celautStorageIncoming(CelautStrings.bytes(v.incomingBytes.toInt())),
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return SettingsRow(
      key: const Key('settings-packages-usage'),
      icon: Icons.sd_storage_outlined,
      title: t.celautStorageTitle,
      subtitle: _loading && _view == null ? '…' : _text(t),
      onTap: _loading ? null : _read,
      trailing: IconButton(
        key: const Key('settings-packages-usage-refresh'),
        tooltip: t.celautStorageRefresh,
        icon: const Icon(Icons.refresh),
        onPressed: _loading ? null : _read,
      ),
    );
  }
}
