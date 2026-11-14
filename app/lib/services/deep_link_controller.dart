import 'package:flutter/foundation.dart';

/// Parks an incoming deep link (ErgoPay, a `celaut://` node link) until a screen that can act
/// on it is ready, e.g. after the wallet unlocks.
class DeepLinkController extends ChangeNotifier {
  String? _pending;

  String? get pending => _pending;

  void push(String link) {
    final clean = link.trim();
    if (clean.isEmpty) return;
    _pending = clean;
    notifyListeners();
  }

  /// Returns and clears the parked link.
  String? take() {
    final link = _pending;
    _pending = null;
    return link;
  }
}

final deepLinkController = DeepLinkController();

/// Where a tapped notification leads. The service posts `argus://<target>`
/// as a deep link so a tap parks like an ErgoPay link until the wallet is
/// unlocked; the home screen then opens the route.
String? argusLinkRoute(String link) => switch (link.trim().toLowerCase()) {
      'argus://activity' => '/transactions',
      _ => null,
    };


final _chatLink = RegExp(r'^argus://chat/([A-Za-z0-9_-]{1,128})$');

/// The instance id of a chat link (`argus://chat/<id>`, from the tap on the notice of an
/// answer that is done), or null for any other link. The case of the id is kept.
String? argusChatInstance(String link) => _chatLink.firstMatch(link.trim())?.group(1);
