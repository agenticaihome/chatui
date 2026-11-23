import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// iOS suspends the app a few seconds after it goes to the background (`docs/ios.md`,
/// "Background"): the tunnels and the gRPC streams stop, and nothing runs until the user
/// opens the app again. Android keeps them with its foreground service, so this does
/// nothing there.
///
/// A session (an open chat) registers two functions:
///
/// - `suspend`: end its connections cleanly. The iOS side (`LifecyclePlugin.swift`) calls
///   `suspend` on [channelName] when the app goes to the background, inside a short
///   background task, and waits for the answer (at most [suspendLimit] here).
/// - `resume`: the app is in front again after a suspend. Reconnect at once and read
///   what came meanwhile. It gets the time that the app was away.
class AppSuspension with WidgetsBindingObserver {
  /// [enabled] and [now] stand in for the platform and the clock in tests.
  AppSuspension({MethodChannel? channel, bool? enabled, DateTime Function()? now})
      : _channel = channel ?? const MethodChannel(channelName),
        _enabled = enabled ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS),
        _now = now ?? DateTime.now;

  static const channelName = 'org.celaut.superapp/lifecycle';

  /// The longest time that the sessions get to close: iOS gives the background task about
  /// 30 seconds, and the Swift side ends it after 8.
  static const suspendLimit = Duration(seconds: 5);

  final MethodChannel _channel;
  final bool _enabled;
  final DateTime Function() _now;
  final _sessions = <_Session>[];
  bool _started = false;
  bool _suspended = false;
  DateTime? _awaySince;

  bool get enabled => _enabled;

  /// The sessions were closed for a suspension, and the app is not in front again yet.
  bool get suspended => _suspended;

  /// Listen to the iOS side and to the lifecycle of the app. Once, at the start.
  void start() {
    if (!_enabled || _started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'suspend') await suspendAll();
      return null;
    });
    WidgetsBinding.instance.addObserver(this);
  }

  /// Register a session. Call the function that this gives to remove it. Off iOS this
  /// registers nothing.
  VoidCallback register({
    required Future<void> Function() suspend,
    required Future<void> Function(Duration away) resume,
  }) {
    if (!_enabled) return () {};
    final session = _Session(suspend, resume);
    _sessions.add(session);
    return () => _sessions.remove(session);
  }

  /// End every session, before iOS suspends the app.
  @visibleForTesting
  Future<void> suspendAll() async {
    _suspended = true;
    _awaySince ??= _now();
    final all = [for (final s in List.of(_sessions)) _guard(s.suspend())];
    await Future.wait(all).timeout(suspendLimit, onTimeout: () => const []);
  }

  /// The app is in front again: each session reconnects, if the sessions were closed.
  @visibleForTesting
  Future<void> resumeAll() async {
    if (!_suspended) return;
    _suspended = false;
    final away = _awaySince == null ? Duration.zero : _now().difference(_awaySince!);
    _awaySince = null;
    await Future.wait([for (final s in List.of(_sessions)) _guard(s.resume(away))]);
  }

  static Future<void> _guard(Future<void> work) => work.catchError((Object e) {
        debugPrint('A session did not follow the suspension: $e');
      });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _awaySince ??= _now();
    if (state == AppLifecycleState.resumed) {
      if (!_suspended) _awaySince = null;
      unawaited(resumeAll());
    }
  }
}

class _Session {
  _Session(this.suspend, this.resume);

  final Future<void> Function() suspend;
  final Future<void> Function(Duration away) resume;
}

final appSuspension = AppSuspension();
