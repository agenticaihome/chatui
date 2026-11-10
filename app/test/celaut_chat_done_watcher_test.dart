import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/chat_done_watcher.dart';
import 'package:argus_wallet/celaut/chat_notifier.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chat client with no network: the test sets the messages, and [onSync] changes them
/// at each read.
class _Chat extends ChatClient {
  _Chat(List<ChatMessage> history)
      : _messages = [...history],
        super(port: 0);

  final List<ChatMessage> _messages;
  int syncs = 0;
  bool broken = false;
  void Function(List<ChatMessage> messages)? onSync;

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  @override
  bool get awaitingAnswer =>
      _messages.any((m) => m.isOpen) ||
      _messages.where((m) => m.fromUser).length > _messages.where((m) => !m.fromUser).length;

  @override
  Future<void> sync() async {
    syncs++;
    if (broken) throw const ChatException(ChatErrorKind.unreachable);
    onSync?.call(_messages);
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this._run);

  final Duration delay;
  final void Function() _run;
  bool cancelled = false;
  bool fired = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => 0;

  void fire() {
    fired = true;
    _run();
  }
}

const _user = ChatMessage(seq: 0, role: 'user', text: 'hi');
ChatMessage _answer(int seq, String status) =>
    ChatMessage(seq: seq, role: 'assistant', text: 'secret text', status: status, replyTo: seq - 1);

InstanceListView _instance(String id, {String alias = ''}) => InstanceListView(
      instanceId: id,
      peerId: 'aa' * 32,
      address: 'node.example:53460',
      serviceId: '65' * 32,
      slots: Uint16List.fromList([8080]),
      chatSlots: Uint16List.fromList([8080]),
      cardsSlots: Uint16List(0),
      webSlots: Uint16List(0),
      startedAt: 1760000000,
      startChargeMu: '1000',
      refundMu: '',
      name: 'Echo chat',
      alias: alias,
      title: '',
    );

void main() {
  late List<String> shown;
  late List<String> closed;
  late Map<String, _Chat> chats;
  late Set<String> muted;
  late List<_FakeTimer> timers;
  late ForegroundHolds holds;
  late DateTime clock;
  late int connects;
  late bool connectFails;
  late ChatDoneWatcher watcher;

  /// Run the timer that waits now, as the clock of the app would.
  Future<void> tick() async {
    final next = timers.where((t) => t.isActive).toList();
    expect(next, hasLength(1), reason: 'one timer waits');
    next.single.fire();
    await pumpEventQueue();
  }

  ChatDoneWatcher make({Duration? giveUpAfter, Duration? maxWatch}) => ChatDoneWatcher(
        notifier: ChatNotifier(
          isMuted: (_) => false,
          show: (id, title, body, payload) async => shown.add('$payload|$title|$body'),
        ),
        holds: holds,
        isMuted: muted.contains,
        now: () => clock,
        timer: (d, f) {
          final t = _FakeTimer(d, f);
          timers.add(t);
          return t;
        },
        connect: (instance) async {
          connects++;
          if (connectFails) throw Exception('tunnel');
          final id = instance.instanceId;
          return WatchedChat(chats[id]!, () => closed.add(id));
        },
        giveUpAfter: giveUpAfter ?? ChatDoneWatcher.defaultGiveUpAfter,
        maxWatch: maxWatch ?? ChatDoneWatcher.defaultMaxWatch,
      );

  setUp(() {
    shown = [];
    closed = [];
    chats = {};
    muted = {};
    timers = [];
    holds = ForegroundHolds(isAndroid: false);
    clock = DateTime(2026, 10, 24, 12);
    connects = 0;
    connectFails = false;
    watcher = make();
  });

  Future<void> handOver(String id, _Chat chat, {Map<int, String> statuses = const {}, String alias = ''}) async {
    chats[id] = chat;
    watcher.handOver(_instance(id, alias: alias), statuses);
    await pumpEventQueue();
  }

  group('hand-over', () {
    test('reads at once, then every pollWaiting, and tells the user once when the answer is done', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')]);
      var reads = 0;
      chat.onSync = (m) {
        if (++reads == 3) m[1] = _answer(1, 'done');
      };
      await handOver('a', chat, statuses: {0: 'done', 1: 'streaming'}, alias: 'Pepa');
      expect(watcher.watching, {'a'});
      expect(holds.reasons, {KeepAliveReason.answer});
      expect(chat.syncs, 1);
      expect(timers.single.delay, ChatClient.pollWaiting);
      await tick();
      expect(shown, isEmpty);
      await tick();
      // The notice has the name of the chat and no text of the answer.
      expect(shown, ['chat/a|Pepa|${appL10n.chatNotifyDoneBody}']);
      expect(chat.syncs, 3);
    });

    test('stops when nothing is pending: no timer, the connection closes, the hold goes', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')])..onSync = (m) => m[1] = _answer(1, 'done');
      await handOver('a', chat, statuses: {1: 'streaming'});
      expect(watcher.watching, isEmpty);
      expect(holds.reasons, isEmpty);
      expect(closed, ['a']);
      expect(timers.where((t) => t.isActive), isEmpty);
      expect(shown, hasLength(1));
    });

    test('an answer that was done before the hand-over is history: no notice', () async {
      // The history has a done answer; the user asked again, and no answer came yet.
      final chat = _Chat([_user, _answer(1, 'done'), const ChatMessage(seq: 2, role: 'user', text: 'more')]);
      await handOver('a', chat, statuses: {0: 'done', 1: 'done', 2: 'done'});
      expect(shown, isEmpty);
      expect(watcher.watching, {'a'});
      chat.onSync = (m) => m.add(_answer(3, 'done'));
      await tick();
      expect(shown, hasLength(1));
      expect(watcher.watching, isEmpty);
    });

    test('an unanswered user message is watched until an answer is done', () async {
      final chat = _Chat([_user]);
      await handOver('a', chat, statuses: {0: 'done'});
      expect(watcher.watching, {'a'});
      chat.onSync = (m) => m.add(_answer(1, 'streaming'));
      await tick();
      expect(shown, isEmpty);
      expect(watcher.watching, {'a'});
      chat.onSync = (m) => m[1] = _answer(1, 'done');
      await tick();
      expect(shown, hasLength(1));
      expect(watcher.watching, isEmpty);
    });

    test('many answers done between two reads give one notice', () async {
      final chat = _Chat([_user, _answer(1, 'streaming'), const ChatMessage(seq: 2, role: 'user', text: 'b')]);
      await handOver('a', chat, statuses: {1: 'streaming'});
      chat.onSync = (m) {
        m[1] = _answer(1, 'done');
        m.add(_answer(3, 'done'));
      };
      await tick();
      expect(shown, hasLength(1));
    });

    test('a failed answer gives no notice and ends the watch', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')])..onSync = (m) => m[1] = _answer(1, 'failed');
      await handOver('a', chat, statuses: {1: 'streaming'});
      expect(shown, isEmpty);
      expect(watcher.watching, isEmpty);
      expect(holds.reasons, isEmpty);
    });

    test('a failed answer with an error text gives no notice either', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')])
        ..onSync = (m) => m[1] = const ChatMessage(
              seq: 2,
              role: 'assistant',
              text: 'Half',
              status: ChatMessage.statusFailed,
              error: 'The model is down.',
              replyTo: 1,
            );
      await handOver('a', chat, statuses: {1: 'streaming'});
      expect(shown, isEmpty);
      expect(watcher.watching, isEmpty);
    });

    test('a new hand-over for an instance replaces the old watch', () async {
      final first = _Chat([_user, _answer(1, 'streaming')]);
      await handOver('a', first, statuses: {1: 'streaming'});
      final oldTimer = timers.single;
      final second = _Chat([_user, _answer(1, 'streaming')]);
      await handOver('a', second, statuses: {1: 'streaming'});
      expect(oldTimer.cancelled, isTrue);
      expect(closed, ['a']);
      expect(watcher.watching, {'a'});
      expect(holds.reasons, {KeepAliveReason.answer});
    });
  });

  group('no second notice', () {
    test('a message that the screen claimed gets no notice from the watcher', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')])..onSync = (m) => m[1] = _answer(1, 'done');
      await handOver('a', chat, statuses: {1: 'streaming'});
      // The watcher read at once and the notice is out; the screen claims the same message.
      expect(shown, hasLength(1));
      expect(watcher.claim('a', 1), isFalse);
    });

    test('a message that the screen gave a notice for gets none from the watcher', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')]);
      chats['a'] = chat;
      expect(watcher.claim('a', 1), isTrue);
      expect(watcher.claim('a', 1), isFalse);
      watcher.handOver(_instance('a'), {1: 'streaming'});
      chat.onSync = (m) => m[1] = _answer(1, 'done');
      await pumpEventQueue();
      expect(shown, isEmpty);
      expect(watcher.watching, isEmpty);
    });

    test('the same seq of another instance is another message', () {
      expect(watcher.claim('a', 1), isTrue);
      expect(watcher.claim('b', 1), isTrue);
    });
  });

  group('release', () {
    test('stops the watch, cancels the timer, closes the connection, releases the hold', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')]);
      await handOver('a', chat, statuses: {1: 'streaming'});
      final timer = timers.single;
      watcher.release('a');
      expect(timer.cancelled, isTrue);
      expect(closed, ['a']);
      expect(watcher.watching, isEmpty);
      expect(holds.reasons, isEmpty);
      // Not watched: no read, no notice, even if the timer ran.
      chat.onSync = (m) => m[1] = _answer(1, 'done');
      timer.fire();
      await pumpEventQueue();
      expect(chat.syncs, 1);
      expect(shown, isEmpty);
    });

    test('an instance that is not watched is ignored', () {
      watcher.release('nobody');
      expect(holds.reasons, isEmpty);
    });

    test('the hold stays while one other instance is watched', () async {
      await handOver('a', _Chat([_user]));
      await handOver('b', _Chat([_user]));
      expect(holds.reasons, {KeepAliveReason.answer});
      watcher.release('a');
      expect(holds.reasons, {KeepAliveReason.answer});
      watcher.release('b');
      expect(holds.reasons, isEmpty);
    });

    test('stopAll ends every watch', () async {
      await handOver('a', _Chat([_user]));
      await handOver('b', _Chat([_user]));
      watcher.stopAll();
      expect(watcher.watching, isEmpty);
      expect(holds.reasons, isEmpty);
      expect(timers.where((t) => t.isActive), isEmpty);
    });
  });

  group('mute', () {
    test('a muted instance is not watched: no tunnel, no hold', () async {
      muted.add('a');
      await handOver('a', _Chat([_user]));
      expect(watcher.watching, isEmpty);
      expect(connects, 0);
      expect(holds.reasons, isEmpty);
    });

    test('a mute during the watch ends it without a notice', () async {
      final chat = _Chat([_user, _answer(1, 'streaming')]);
      await handOver('a', chat, statuses: {1: 'streaming'});
      muted.add('a');
      chat.onSync = (m) => m[1] = _answer(1, 'done');
      await tick();
      expect(shown, isEmpty);
      expect(watcher.watching, isEmpty);
      expect(holds.reasons, isEmpty);
      expect(closed, ['a']);
    });
  });

  group('unreachable instance', () {
    test('a short failure is retried and the watch goes on', () async {
      final chat = _Chat([_user])..broken = true;
      await handOver('a', chat);
      clock = clock.add(const Duration(minutes: 1));
      await tick();
      expect(watcher.watching, {'a'});
      chat
        ..broken = false
        ..onSync = (m) => m.add(_answer(1, 'done'));
      await tick();
      expect(shown, hasLength(1));
    });

    test('gives up after giveUpAfter of failures: no timer, no hold', () async {
      final chat = _Chat([_user])..broken = true;
      await handOver('a', chat);
      clock = clock.add(ChatDoneWatcher.defaultGiveUpAfter);
      await tick();
      expect(watcher.watching, isEmpty);
      expect(holds.reasons, isEmpty);
      expect(closed, ['a']);
      expect(timers.where((t) => t.isActive), isEmpty);
    });

    test('a good read resets the time of the failure', () async {
      final chat = _Chat([_user])..broken = true;
      await handOver('a', chat);
      clock = clock.add(const Duration(minutes: 4));
      chat.broken = false;
      await tick();
      chat.broken = true;
      clock = clock.add(const Duration(minutes: 4));
      await tick();
      expect(watcher.watching, {'a'});
    });

    test('a tunnel that does not open is retried, then dropped', () async {
      connectFails = true;
      await handOver('a', _Chat([_user]));
      expect(connects, 1);
      expect(watcher.watching, {'a'});
      clock = clock.add(ChatDoneWatcher.defaultGiveUpAfter);
      await tick();
      expect(connects, 2);
      expect(watcher.watching, isEmpty);
      expect(holds.reasons, isEmpty);
    });

    test('opens one tunnel for the whole watch', () async {
      await handOver('a', _Chat([_user]));
      await tick();
      await tick();
      expect(connects, 1);
    });
  });

  test('a watch stops after maxWatch, even if the answer stays open', () async {
    watcher = make(maxWatch: const Duration(minutes: 10));
    await handOver('a', _Chat([_user, _answer(1, 'streaming')]), statuses: {1: 'streaming'});
    clock = clock.add(const Duration(minutes: 10));
    await tick();
    expect(watcher.watching, isEmpty);
    expect(holds.reasons, isEmpty);
    expect(shown, isEmpty);
  });

  test('a release during the first read closes the connection that opens late', () async {
    final gate = Completer<void>();
    final chat = _Chat([_user]);
    final slow = ChatDoneWatcher(
      holds: holds,
      isMuted: (_) => false,
      timer: (d, f) => _FakeTimer(d, f),
      connect: (_) async {
        await gate.future;
        return WatchedChat(chat, () => closed.add('late'));
      },
    );
    slow.handOver(_instance('a'), const {});
    slow.release('a');
    gate.complete();
    await pumpEventQueue();
    expect(closed, ['late']);
    expect(chat.syncs, 0);
  });
}
