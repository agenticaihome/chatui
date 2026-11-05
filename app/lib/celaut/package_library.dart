import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../bridge/api/celaut_package.dart';
import '../services/secure_storage.dart';
import 'package_channel.dart';
import 'service_transfer.dart';

/// The name that the library gives to a file of this name (as `clean_name` of the core):
/// without its folders and without `.celaut.bee` or `.bee`, with no control characters, and
/// no more than 80 characters. Null for a name that is then empty.
String? libraryNameOf(String fileName) {
  var base = fileName.split(RegExp(r'[/\\]')).last.trim();
  final lower = base.toLowerCase();
  if (lower.endsWith('.celaut.bee')) {
    base = base.substring(0, base.length - '.celaut.bee'.length);
  } else if (lower.endsWith('.bee')) {
    base = base.substring(0, base.length - '.bee'.length);
  }
  final kept = base.runes.where((r) => r >= 0x20 && (r < 0x7f || r > 0x9f)).take(80);
  final name = String.fromCharCodes(kept).trim();
  return name.isEmpty ? null : name;
}

/// What an import does now.
enum ImportPhase {
  /// The app copies the chosen file into a private folder.
  reading,

  /// The app checks the blocks of its copy.
  checking,
}

/// How far an import is: the bytes of its phase, of [total] (null while not known).
@immutable
class ImportProgress {
  const ImportProgress({required this.phase, required this.bytes, this.total});

  final ImportPhase phase;
  final int bytes;
  final int? total;

  /// The share of the phase that is done, or null while the total is not known.
  double? get fraction {
    final t = total;
    if (t == null || t <= 0) return null;
    return (bytes / t).clamp(0.0, 1.0).toDouble();
  }

  /// The share of the whole import that is done: the read is the first half, and the
  /// check is the second half (each reads the whole file once). Null while the read does
  /// not know the size of the file.
  double? get overall {
    final f = fraction;
    if (f == null) return phase == ImportPhase.checking ? 0.5 : null;
    return phase == ImportPhase.reading ? f / 2 : 0.5 + f / 2;
  }
}

/// The service files that the user loaded into the app (`docs/celaut/package.md`).
///
/// A file is loaded once: the app checks it, keeps it in a private directory under the id
/// of its service, and records its name. From then on the service can be run, and given to
/// a node that does not have it, with no need to choose the file again. The calls are
/// injected so that tests need no Rust.
class PackageLibrary {
  PackageLibrary({
    Future<LibraryPackageView> Function(String path, String name, String dir)? importPackage,
    List<LibraryPackageView> Function()? list,
    Future<void> Function(String serviceId)? remove,
    Future<String?> Function()? privateDir,
    TransferView Function()? progress,
    void Function()? cancel,
  })  : _import = importPackage ??
            ((path, name, dir) => celautImportPackage(path: path, name: name, dir: dir)),
        _list = list ?? celautPackages,
        _remove = remove ?? ((id) => celautRemovePackage(serviceIdHex: id)),
        _privateDir = privateDir ?? _appPrivateDir,
        progress = progress ?? celautTransferProgress,
        cancel = cancel ?? celautCancelTransfer;

  final Future<LibraryPackageView> Function(String, String, String) _import;
  final List<LibraryPackageView> Function() _list;
  final Future<void> Function(String) _remove;
  final Future<String?> Function() _privateDir;

  /// The load that runs now: the bytes that the app checked so far.
  final TransferView Function() progress;

  /// Stop the load that runs.
  final void Function() cancel;

  /// The directory of the Celaut database: private to the app.
  static Future<String?> _appPrivateDir() async {
    try {
      final path = await SecureStorageService.celautDbPath();
      if (path == null || path.isEmpty) return null;
      return File(path).parent.path;
    } on MissingPluginException {
      return null;
    }
  }

  /// The loaded services, by name.
  List<LibraryPackageView> list() => _list();

  /// The loaded service with this id, if its file is there. A record whose file is gone is
  /// not a service that the app can send.
  LibraryPackageView? find(String serviceId) {
    final id = serviceId.toLowerCase();
    for (final p in _list()) {
      if (p.serviceId == id && p.present) return p;
    }
    return null;
  }

  ImportPhase _phase = ImportPhase.reading;
  int? _size;
  PackageChannel? _channel;
  bool _cancelled = false;

  /// The import that runs now ([importChosen]).
  ImportProgress importProgress() {
    if (_phase == ImportPhase.reading) {
      return ImportProgress(phase: _phase, bytes: _channel?.copied ?? 0, total: _size);
    }
    final view = progress();
    return ImportProgress(
      phase: _phase,
      bytes: view.bytes.toInt(),
      total: view.total?.toInt() ?? _size,
    );
  }

  /// Stop the import that runs: the copy, or the check.
  void cancelImport() {
    _cancelled = true;
    _channel?.cancelCopy();
    cancel();
  }

  /// Copy the file that the user chose into a private folder of the app (through [channel]), then
  /// load it ([importPicked]). A copy that the library does not take is deleted. Throws
  /// [CopyCancelled] or [CopyFailed] for the copy, and as [importPicked] for the load.
  Future<LibraryPackageView> importChosen(ChosenFile file, PackageChannel channel) async {
    final dir = await _privateDir();
    if (dir == null || dir.isEmpty) throw const PackageRefused(PackageRefusal.noDirectory);
    _phase = ImportPhase.reading;
    _size = file.bytes;
    _channel = channel;
    _cancelled = false;
    final picked = await channel.copy(file);
    try {
      if (_cancelled) throw const CopyCancelled();
      _phase = ImportPhase.checking;
      _size = picked.bytes;
      return await _import(picked.path, picked.name, dir);
    } catch (_) {
      // A refused file stays where it was: here, the copy of the app.
      _deleteQuietly(picked.path);
      rethrow;
    } finally {
      _channel = null;
    }
  }

  static void _deleteQuietly(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // The next copy deletes what is left in the folder.
    }
  }

  /// Load the file that the user picked. Throws [CelautError] (`invalidInput` for a file
  /// that is not a package of a service) or [PackageRefused] when the app has no private
  /// directory.
  Future<LibraryPackageView> importPicked(PickedPackage picked) async {
    final dir = await _privateDir();
    if (dir == null || dir.isEmpty) throw const PackageRefused(PackageRefusal.noDirectory);
    return _import(picked.path, picked.name, dir);
  }

  /// Remove a loaded service: its file is deleted. The nodes that have it keep it.
  Future<void> remove(String serviceId) => _remove(serviceId);
}
