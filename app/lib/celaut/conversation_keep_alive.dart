import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Why the app keeps itself alive in the background.
enum KeepAliveReason {
  /// A conversation is open: its tunnel to the node stays up.
  conversation,

  /// A service is being launched, or the app waits for a service that just started.
  launch,

  /// A service file goes to a node.
  transfer,

  /// The user left a chat while a service still makes an answer: the app reads the chat
  /// in the background to tell the user when it is done (`chat_done_watcher.dart`).
  answer,

  /// A service file is being loaded into the app (the system file picker is open, or the
  /// file is being copied).
  import,

  /// An instance has automatic top-up on ([AutoTopUp]). Only on macOS: there it keeps App
  /// Nap off. On Android it does not start the foreground service.
  topUp,
}

/// The holds on the Android foreground service (`ConversationService.kt`), and on macOS the
/// activity that keeps App Nap off (`KeepAwakeChannel.swift`): the service
/// runs while at least one hold is taken, and stops when the last one is released. The
/// conversation, the launch, the transfer and the import of a service share it, so that
/// one of them never stops the service while another one needs it.
///
/// While a launch, a transfer, an import or a pending answer holds it, the service also keeps the CPU
/// awake (a partial wake lock), so that the work goes on with the screen off. A
/// conversation alone does not: it waits for the user.
///
/// No call throws: the work goes on without the service.
class ForegroundHolds {
  ForegroundHolds({MethodChannel? channel, bool? isAndroid, bool? isMacOS})
      : _channel = channel ?? const MethodChannel(channelName),
        _isAndroid = isAndroid ?? Platform.isAndroid,
        _isMacOS = isMacOS ?? Platform.isMacOS;

  static const channelName = 'org.celaut.chatui/conversation';

  final MethodChannel _channel;
  final bool _isAndroid;
  final bool _isMacOS;
  final Map<KeepAliveReason, int> _held = {};

  /// The reasons that hold the service now.
  Set<KeepAliveReason> get reasons => {
        for (final e in _held.entries)
          if (e.value > 0) e.key,
      };

  /// Take a hold for [reason]. The service starts, or shows the new reason. Call the
  /// function that this gives, once, to release the hold.
  Future<void> Function() hold(KeepAliveReason reason) {
    // Android runs the foreground service for the work that the user sees, not for a top-up.
    if (reason == KeepAliveReason.topUp && !_isMacOS) return () async {};
    _held[reason] = (_held[reason] ?? 0) + 1;
    unawaited(_sync());
    var released = false;
    return () async {
      if (released) return;
      released = true;
      _held[reason] = (_held[reason] ?? 1) - 1;
      await _sync();
    };
  }

  /// Ask for the notification permission (Android 13+). The answer does not matter:
  /// without it, the service runs with no notification.
  Future<void> askNotificationPermission() => _call('requestNotificationPermission');

  Future<void> _sync() async {
    final now = reasons;
    if (now.isEmpty) {
      await _call('stop');
    } else {
      await _call('start', {
        'reasons': [
          for (final r in KeepAliveReason.values)
            if (now.contains(r)) r.name,
        ],
      });
    }
  }

  Future<void> _call(String method, [Object? arguments]) async {
    if (!_isAndroid && !_isMacOS) return;
    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on Object {
      // PlatformException, MissingPluginException: nothing to keep alive.
    }
  }
}

/// The holds of the app.
final foregroundHolds = ForegroundHolds();

/// Keeps the app alive in the background while a conversation with a service is open,
/// so that the tunnel to the node stays up (`docs/celaut-plan.md`, section 3). The
/// instance runs on the node and is not affected: only the phone side is kept.
///
/// No call throws: the conversation works without the keep-alive.
abstract class ConversationKeepAlive {
  /// Ask for the notification permission (Android 13+), then start the foreground
  /// service. The service runs also if the user refuses the permission.
  Future<void> start();

  /// The conversation waits for an instance that just started ([on] true), or the wait
  /// is over. While it waits, the CPU stays awake with the screen off, as for a launch.
  Future<void> waiting(bool on);

  /// Stop the foreground service. It is safe to call it more than once.
  Future<void> stop();
}

/// The Android half lives in `ConversationHandler.kt` and `ConversationService.kt`. On
/// other platforms, and when the channel is missing, it does nothing.
class ChannelConversationKeepAlive implements ConversationKeepAlive {
  ChannelConversationKeepAlive({ForegroundHolds? holds}) : _holds = holds ?? foregroundHolds;

  static const channelName = ForegroundHolds.channelName;

  final ForegroundHolds _holds;
  bool _started = false;
  Future<void> Function()? _conversation;
  Future<void> Function()? _wait;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _holds.askNotificationPermission();
    // Stopped while the permission question was open: nothing to hold.
    if (!_started) return;
    _conversation = _holds.hold(KeepAliveReason.conversation);
  }

  @override
  Future<void> waiting(bool on) async {
    if (on) {
      _wait ??= _holds.hold(KeepAliveReason.launch);
    } else {
      final release = _wait;
      _wait = null;
      await release?.call();
    }
  }

  @override
  Future<void> stop() async {
    _started = false;
    await waiting(false);
    final release = _conversation;
    _conversation = null;
    await release?.call();
  }
}
