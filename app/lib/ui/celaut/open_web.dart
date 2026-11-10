import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_service.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/conversation_keep_alive.dart';
import '../../l10n/l10n.dart';

/// How long the app stays alive in the background after a page was opened in the browser.
/// The port is in this process: if the system stops it, the page stops loading.
const browserHoldDuration = Duration(minutes: 30);

Timer? _browserHoldTimer;
Future<void> Function()? _browserRelease;

/// Keep the foreground service for [duration] from now, so that the app (and the tunnel
/// port in it) is not stopped while the browser is in front. Each call starts the time
/// again.
void _holdForBrowser(ForegroundHolds holds, Duration duration) {
  final previous = _browserRelease;
  _browserRelease = holds.hold(KeepAliveReason.conversation);
  if (previous != null) unawaited(previous());
  _browserHoldTimer?.cancel();
  _browserHoldTimer = Timer(duration, () {
    final release = _browserRelease;
    _browserRelease = null;
    if (release != null) unawaited(release());
  });
}

/// Release the hold of the browser now. For tests, which must not end with a timer.
@visibleForTesting
Future<void> releaseBrowserHold() async {
  _browserHoldTimer?.cancel();
  _browserHoldTimer = null;
  final release = _browserRelease;
  _browserRelease = null;
  if (release != null) await release();
}

/// Open the first web slot of [instance] in the browser of the phone, or the web slot
/// [slot] (a `slot_link` of the chat, `docs/celaut/chat.md`, section 5.8).
///
/// The slot gets a local port (`celautOpenTunnel`) on 127.0.0.1, and the browser goes to
/// it. Each TCP connection of the browser is one tunnel stream, and the node charges each
/// one. The port stays while the app runs, and on Android the app stays alive in the
/// background for [browserHoldDuration] after the page was opened. [openTunnel], [launch]
/// and [holds] are for tests ([holds] also turns the hold on, off Android).
Future<void> openWebInBrowser(
  BuildContext context,
  InstanceListView instance, {
  int? slot,
  Future<int> Function(String instanceId, int slot)? openTunnel,
  Future<bool> Function(Uri uri)? launch,
  ForegroundHolds? holds,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  if (instance.webSlots.isEmpty || (slot != null && !instance.webSlots.contains(slot))) {
    messenger.showSnackBar(SnackBar(content: Text(l.chatsNoInterface)));
    return;
  }
  try {
    final port =
        await (openTunnel ??
            (id, s) => celautOpenTunnel(instanceId: id, slot: s))(
          instance.instanceId,
          slot ?? instance.webSlots.first,
        );
    // Before the browser takes the screen: the app goes to the background right after.
    if (holds != null || Platform.isAndroid) {
      _holdForBrowser(holds ?? foregroundHolds, browserHoldDuration);
    }
    final open =
        launch ?? (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!await open(Uri.parse('http://127.0.0.1:$port/'))) {
      messenger.showSnackBar(SnackBar(content: Text(l.chatsBrowserFailed)));
    }
  } on CelautError catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(CelautStrings.errorText(e.kind))),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.chatsBrowserFailed)));
  }
}
