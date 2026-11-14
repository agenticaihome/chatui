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

  /// The app downloads a service from a link, and checks it while the bytes arrive.
  downloading,
}

/// The largest service that the app downloads from a link: 4 GiB. A bad link must not fill
/// the storage of the phone.
const maxLinkBytes = 4 * 1024 * 1024 * 1024;

/// How far an import is: the bytes of its phase, of [total] (null while not known).
@immutable
class ImportProgress {
  const ImportProgress({
    required this.phase,
    required this.bytes,
    this.total,
    this.chunk = 0,
    this.chunks = 0,
    this.retries = 0,
  });

  final ImportPhase phase;
  final int bytes;
  final int? total;

  /// A download of a manifest: the chunk (from 1) and the number of chunks. 0 otherwise.
  final int chunk;
  final int chunks;

  /// A download: the tries that failed and were tried again.
  final int retries;

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
    if (phase == ImportPhase.downloading) {
      // The download is the check too: one pass. A manifest gives no size, only chunks.
      if (f != null) return f;
      return chunks > 0 ? ((chunk - 1) / chunks).clamp(0.0, 1.0).toDouble() : null;
    }
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
    Future<LibraryPackageView> Function(String url, String dir, bool allowHttp, int maxBytes)?
        importLink,
    LinkView Function(String url)? checkLink,
    PendingLinkView? Function(String dir)? pendingLink,
    Future<void> Function(String dir)? discardLink,
  })  : _importLink = importLink ??
            ((url, dir, allowHttp, maxBytes) => celautImportLink(
                  url: url,
                  dir: dir,
                  allowHttp: allowHttp,
                  maxBytes: BigInt.from(maxBytes),
                )),
        _checkLink = checkLink ?? ((url) => celautCheckLink(url: url)),
        _pendingLink = pendingLink ?? ((dir) => celautPendingLink(dir: dir)),
        _discardLink = discardLink ?? ((dir) => celautDiscardLink(dir: dir)),
        _import = importPackage ??
            ((path, name, dir) => celautImportPackage(path: path, name: name, dir: dir)),
        _list = list ?? celautPackages,
        _remove = remove ?? ((id) => celautRemovePackage(serviceIdHex: id)),
        _privateDir = privateDir ?? _appPrivateDir,
        progress = progress ?? celautTransferProgress,
        cancel = cancel ?? celautCancelTransfer;

  final Future<LibraryPackageView> Function(String, String, String) _import;
  final Future<LibraryPackageView> Function(String, String, bool, int) _importLink;
  final LinkView Function(String) _checkLink;
  final PendingLinkView? Function(String) _pendingLink;
  final Future<void> Function(String) _discardLink;
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
    if (_phase == ImportPhase.downloading) {
      final view = progress();
      return ImportProgress(
        phase: _phase,
        bytes: view.bytes.toInt(),
        total: view.total?.toInt(),
        chunk: view.chunk,
        chunks: view.chunks,
        retries: view.retries,
      );
    }
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

  /// Check a link that the user gave (`celautCheckLink`). Throws [CelautError]
  /// (`invalidInput`) for a link that the app does not download.
  LinkView checkLink(String url) => _checkLink(url);

  /// Download the service at [url] into the library, and check it while it arrives
  /// (`celautImportLink`). [allowHttp]: the user said yes to the warning for `http://`.
  /// Throws [CelautError]: `invalidInput` (not a valid service; its bytes are deleted),
  /// `unreachable` (the download stopped; the same link goes on from there),
  /// `limitReached` (larger than [maxLinkBytes]), `transferFailed` (cancelled; deleted).
  Future<LibraryPackageView> importLink(String url, {required bool allowHttp}) async {
    final dir = await _privateDir();
    if (dir == null || dir.isEmpty) throw const PackageRefused(PackageRefusal.noDirectory);
    _phase = ImportPhase.downloading;
    _size = null;
    _cancelled = false;
    return _importLink(url, dir, allowHttp, maxLinkBytes);
  }

  /// The download of a link that stopped, if any: the same link goes on from there.
  Future<PendingLinkView?> pendingLink() async {
    final dir = await _privateDir();
    if (dir == null || dir.isEmpty) return null;
    return _pendingLink(dir);
  }

  /// Delete the download that stopped.
  Future<void> discardLink() async {
    final dir = await _privateDir();
    if (dir == null || dir.isEmpty) return;
    await _discardLink(dir);
  }

  /// Remove a loaded service: its file is deleted. The nodes that have it keep it.
  Future<void> remove(String serviceId) => _remove(serviceId);
}
