import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package_channel.dart';
import 'service_link.dart';

/// The `.celaut.bee` files that the user opened in a file manager, or shared with the app,
/// and the links to a service that another app opened or shared (`docs/celaut/package.md`). A file waits here until the home screen opens the import
/// for it, and while an import runs ([busy]): one import at a time.
class IncomingPackages extends ChangeNotifier {
  ChosenFile? _pending;

  /// The uri of the file that the app imports now, if it came from here.
  String? _importing;

  /// True while an import runs. The next file waits.
  final busy = ValueNotifier<bool>(false);

  ChosenFile? get pending => _pending;

  /// A file arrived. The same file twice (the cold start can give it twice) counts once.
  void push(ChosenFile file) {
    if (file.uri.isEmpty || file.uri == _pending?.uri || file.uri == _importing) return;
    _pending = file;
    notifyListeners();
  }

  /// Take the file that waits, if no import runs.
  ChosenFile? take() {
    if (busy.value) return null;
    final file = _pending;
    _pending = null;
    _importing = file?.uri;
    return file;
  }

  /// An import starts or ends ([busy]).
  void setBusy(bool value) {
    busy.value = value;
    if (!value) {
      _importing = null;
      if (_pending != null) notifyListeners();
    }
  }
}

final incomingPackages = IncomingPackages();

/// The file of an `incoming` message of the Android side, or null. A message with a `link`
/// is a link to a service that another app opened or shared (issue #135).
ChosenFile? chosenFileOf(Object? answer) {
  if (answer is! Map) return null;
  final link = answer['link'];
  if (link is String) {
    final url = serviceLinkOf(link);
    return url == null ? null : ChosenFile.link(url);
  }
  final uri = answer['uri'];
  if (uri is! String || uri.isEmpty) return null;
  final name = answer['name'];
  final bytes = answer['bytes'];
  return ChosenFile(
    uri: uri,
    name: name is String && name.isNotEmpty ? name : uri,
    bytes: bytes is int && bytes >= 0 ? bytes : null,
  );
}

/// Receives the opened files from the Android side (cold start through `takeIncoming`,
/// the others through `incoming`) and puts them in [incomingPackages].
class IncomingPackageChannel {
  static const channel = MethodChannel('org.celaut.chatui/incoming');
  static bool _started = false;

  static Future<void> start({IncomingPackages? into}) async {
    if (_started) return;
    _started = true;
    final target = into ?? incomingPackages;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'incoming') throw MissingPluginException();
      final file = chosenFileOf(call.arguments);
      if (file != null) target.push(file);
      return true;
    });
    try {
      final file = chosenFileOf(await channel.invokeMethod<Object?>('takeIncoming'));
      if (file != null) target.push(file);
    } on MissingPluginException {
      // Desktop and test hosts have no Android side.
    } on PlatformException {
      // No file.
    }
  }

  @visibleForTesting
  static void reset() => _started = false;
}
