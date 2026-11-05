import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A `.celaut.bee` file that the user chose. The app did not read it yet.
@immutable
class ChosenFile {
  const ChosenFile({required this.uri, required this.name, this.bytes});

  /// The content uri of the file.
  final String uri;

  /// The name of the file that the user chose.
  final String name;

  /// The size of the file, if its provider says it.
  final int? bytes;
}

/// A `.celaut.bee` file that the user picked, copied into a private folder of the app.
@immutable
class PickedPackage {
  const PickedPackage({required this.path, required this.bytes, required this.name});

  final String path;
  final int bytes;

  /// The name of the file that the user chose.
  final String name;
}

/// The copy of a chosen file stopped because the user cancelled it.
class CopyCancelled implements Exception {
  const CopyCancelled();

  @override
  String toString() => 'CopyCancelled()';
}

/// The copy of a chosen file failed: the file cannot be read.
class CopyFailed implements Exception {
  const CopyFailed(this.message);

  final String message;

  @override
  String toString() => 'CopyFailed($message)';
}

/// The Android side of a transfer of a service (`docs/celaut/package.md`): the file
/// picker, the copy of the chosen file, and whether the network is metered. Off Android,
/// or without the channel, the picker and the metered check do nothing and never throw.
abstract class PackageChannel {
  /// Let the user pick a `.celaut.bee` file. It answers as soon as the user chose the
  /// file: the app did not read it yet. Null if the user cancels, or off Android.
  Future<ChosenFile?> pick();

  /// Copy [file] into a private folder of the app, with a stream. Throws [CopyCancelled] after
  /// [cancelCopy], or [CopyFailed] when the file cannot be read.
  Future<PickedPackage> copy(ChosenFile file);

  /// The bytes that the copy that runs wrote so far.
  int get copied;

  /// Stop the copy that runs. The partial copy is deleted.
  void cancelCopy();

  /// True on mobile data (a metered network).
  Future<bool> isMetered();
}

class AndroidPackageChannel implements PackageChannel {
  /// [android] stands in for the platform check in tests.
  const AndroidPackageChannel({bool? android}) : _android = android;

  static const channel = MethodChannel('org.celaut.chatui/package');

  /// The count of the copy: one for the app, as the Android side has one channel.
  static int _copied = 0;
  static bool _listening = false;

  final bool? _android;

  bool get _onAndroid => _android ?? Platform.isAndroid;

  /// Take the counts of the copy that the Android side sends.
  static void _listen() {
    if (_listening) return;
    _listening = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'copied' && call.arguments is int) _copied = call.arguments as int;
    });
  }

  @override
  Future<ChosenFile?> pick() async {
    if (!_onAndroid) return null;
    try {
      final answer = await channel.invokeMapMethod<String, Object?>('pickPackage');
      if (answer == null) return null;
      final uri = answer['uri'];
      if (uri is! String) return null;
      final name = answer['name'];
      final bytes = answer['bytes'];
      return ChosenFile(
        uri: uri,
        name: name is String ? name : uri,
        bytes: bytes is int && bytes >= 0 ? bytes : null,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('The package was not picked: ${e.message}');
      return null;
    }
  }

  @override
  Future<PickedPackage> copy(ChosenFile file) async {
    _listen();
    _copied = 0;
    try {
      final answer = await channel.invokeMapMethod<String, Object?>('copyPackage', {
        'uri': file.uri,
      });
      final path = answer?['path'];
      final bytes = answer?['bytes'];
      if (path is! String || bytes is! int) throw const CopyFailed('no copy');
      return PickedPackage(path: path, bytes: bytes, name: file.name);
    } on MissingPluginException {
      throw const CopyFailed('no channel');
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') throw const CopyCancelled();
      throw CopyFailed(e.message ?? e.code);
    }
  }

  @override
  int get copied => _copied;

  @override
  void cancelCopy() => unawaited(_cancelCopy());

  static Future<void> _cancelCopy() async {
    try {
      await channel.invokeMethod<void>('cancelCopy');
    } on MissingPluginException {
      // No copy runs off Android.
    } on PlatformException {
      // The copy ended meanwhile.
    }
  }

  @override
  Future<bool> isMetered() async {
    if (!_onAndroid) return false;
    try {
      return await channel.invokeMethod<bool>('isMetered') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
