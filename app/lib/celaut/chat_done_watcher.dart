import 'dart:async';

import '../bridge/api/celaut_service.dart';
import '../l10n/l10n.dart';
import 'chat_client.dart';
import 'chat_notifier.dart';
import 'chat_prefs.dart';
import 'conversation_keep_alive.dart';
import 'conversations.dart';

/// A chat of one instance that the watcher reads: the client, and what closes its
/// connection.
class WatchedChat {
  const WatchedChat(this.client, this.close);

  final ChatClient client;
  final void Function() close;
}

/// Tells the user, with a notice of the system, that an answer is done after the user
/// left the chat screen (`docs/celaut/ui-chat-first.md`, "Notices"). While the screen is
/// open, the screen reads the chat and gives the notice. When the screen closes with an
/// answer that is not done, it hands the chat to this watcher ([handOver]). The watcher
/// opens its own tunnel, with its own client and its own `Connect` stream, and checks the
/// chat every [ChatClient.pollWaiting] until no answer is pending. The client reads with
/// `GetMessages` only while it has no stream. When the user opens the chat again, the watcher stops for it
/// ([release]).
///
/// - A message gets one notice only: the watcher and the screen share the list of the
///   messages that got one ([claim]).
/// - The messages that were done at the hand-over never get a notice: they are history.
/// - An answer with status `failed` gets no notice. The user did not get an answer, and
///   "the answer is ready" would be false. The failure shows when the user opens the chat.
/// - A watch stops when no answer is pending, when the instance is muted, when the
///   instance cannot be reached for [giveUpAfter], or after [maxWatch].
/// - While at least one watch runs, the foreground service holds the process and the
///   CPU ([KeepAliveReason.answer]), so that the reads go on in the background. When the
///   last watch stops, the hold is released.
///
/// The text of the answer is never in the notice, and nothing leaves the device.
class ChatDoneWatcher {
  ChatDoneWatcher({
    ChatNotifier? notifier,
    ForegroundHolds? holds,
    Future<WatchedChat> Function(InstanceListView instance)? connect,
    bool Function(String instanceId)? isMuted,
    bool Function(String instanceId)? isParked,
    Timer Function(Duration delay, void Function() run)? timer,
    DateTime Function()? now,
    this.giveUpAfter = defaultGiveUpAfter,
    this.maxWatch = defaultMaxWatch,
  }) : _notifier = notifier,
       _holds = holds ?? foregroundHolds,
       _connect = connect ?? _connectTunnel,
       _isMuted = isMuted ?? chatPrefs.isMuted,
       _isParked = isParked ?? _recordIsParked,
       _timer = timer ?? Timer.new,
       _now = now ?? DateTime.now;

  /// How long an instance can stay unreachable before the watch stops.
  static const defaultGiveUpAfter = Duration(minutes: 5);

  /// The longest one watch runs. A service that keeps an answer open for longer is
  /// not watched: the user sees it when the chat opens.
  static const defaultMaxWatch = Duration(minutes: 30);

  final Duration giveUpAfter;
  final Duration maxWatch;

  final ChatNotifier? _notifier;
  final ForegroundHolds _holds;
  final Future<WatchedChat> Function(InstanceListView) _connect;
  final bool Function(String) _isMuted;
  final bool Function(String) _isParked;
  final Timer Function(Duration, void Function()) _timer;
  final DateTime Function() _now;

  final Map<String, _Watch> _watches = {};
  final Set<(String, int)> _claimed = {};
  Future<void> Function()? _release;

  /// The instances that the watcher reads now.
  Set<String> get watching => _watches.keys.toSet();

  /// True the first time it is called for the message [seq] of [instanceId]. The caller
  /// that gets true gives the notice. The others do not.
  bool claim(String instanceId, int seq) => _claimed.add((instanceId, seq));

  /// The chat screen of [instance] closed while an answer was pending. [statuses] are the
  /// statuses of the messages (by `seq`) that the screen knew: the messages that are
  /// done in it are history and get no notice. A muted instance is not watched.
  ///
  /// An instance that is hibernated or stopped is not watched: its service does not run,
  /// so there is no answer to wait for, and its silence is not a fault. The screen holds
  /// the state from before the hibernation, so the record of the app is asked.
  void handOver(InstanceListView instance, Map<int, String> statuses) {
    final id = instance.instanceId;
    release(id);
    if (_isMuted(id) || _isParked(id)) return;
    for (final e in statuses.entries) {
      if (e.value == ChatMessage.statusDone) claim(id, e.key);
    }
    final watch = _watches[id] = _Watch(instance, _now());
    _holdService();
    unawaited(_tick(watch));
  }

  /// Stop the watch of [instanceId]: the chat screen is open again, or the instance
  /// stopped.
  void release(String instanceId) {
    final watch = _watches.remove(instanceId);
    if (watch == null) return;
    _end(watch);
    _releaseService();
  }

  /// Stop all the watches.
  void stopAll() {
    for (final id in _watches.keys.toList()) {
      release(id);
    }
  }

  void _holdService() => _release ??= _holds.hold(KeepAliveReason.answer);

  void _releaseService() {
    if (_watches.isNotEmpty) return;
    final release = _release;
    _release = null;
    if (release != null) unawaited(release());
  }

  void _end(_Watch watch) {
    watch.ended = true;
    watch.timer?.cancel();
    watch.timer = null;
    watch.chat?.close();
    watch.chat = null;
  }

  void _drop(_Watch watch) {
    if (_watches[watch.instance.instanceId] != watch) return;
    release(watch.instance.instanceId);
  }

  void _next(_Watch watch) {
    if (watch.ended) return;
    watch.timer = _timer(ChatClient.pollWaiting, () => unawaited(_tick(watch)));
  }

  Future<void> _tick(_Watch watch) async {
    watch.timer = null;
    final id = watch.instance.instanceId;
    if (watch.ended) return;
    if (_isMuted(id) || _isParked(id) || _now().difference(watch.started) >= maxWatch) {
      return _drop(watch);
    }
    try {
      final chat = watch.chat ??= await _connect(watch.instance);
      if (watch.ended) {
        chat.close();
        return;
      }
      await chat.client.sync();
    } on Object {
      if (watch.ended) return;
      final since = watch.failingSince ??= _now();
      if (_now().difference(since) >= giveUpAfter) return _drop(watch);
      return _next(watch);
    }
    if (watch.ended) return;
    watch.failingSince = null;
    final client = watch.chat!.client;
    var fresh = false;
    for (final m in client.messages) {
      if (!m.fromUser && m.status == ChatMessage.statusDone && claim(id, m.seq)) fresh = true;
    }
    if (fresh) await _notify(watch.instance);
    if (watch.ended) return;
    if (!client.awaitingAnswer) return _drop(watch);
    _next(watch);
  }

  Future<void> _notify(InstanceListView instance) => (_notifier ?? chatNotifier).notifyDone(
        instanceId: instance.instanceId,
        title: instanceTitle(instance),
        body: appL10n.chatNotifyDoneBody,
      );

  /// True if the record of the app says that the instance is hibernated or stopped. No
  /// record, or no database, is false.
  static bool _recordIsParked(String instanceId) {
    try {
      return celautInstances().any(
        (i) => i.instanceId == instanceId && (i.hibernatedAt != null || i.stoppedAt != null),
      );
    } on Object {
      return false;
    }
  }

  static Future<WatchedChat> _connectTunnel(InstanceListView instance) async {
    final port = await celautOpenTunnel(instanceId: instance.instanceId, slot: instance.chatSlots.first);
    final client = ChatClient(port: port);
    return WatchedChat(client, () => unawaited(client.close()));
  }
}

class _Watch {
  _Watch(this.instance, this.started);

  final InstanceListView instance;
  final DateTime started;
  WatchedChat? chat;
  Timer? timer;
  DateTime? failingSince;
  bool ended = false;
}

/// The watcher of the app.
final chatDoneWatcher = ChatDoneWatcher();
