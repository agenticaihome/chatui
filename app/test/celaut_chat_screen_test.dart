import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/attachment_picker.dart';
import 'package:argus_wallet/celaut/audio_recorder.dart';
import 'package:argus_wallet/celaut/chat_backgrounds.dart';
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/chat_corrector.dart';
import 'package:argus_wallet/celaut/chat_done_watcher.dart';
import 'package:argus_wallet/celaut/chat_notifier.dart';
import 'package:argus_wallet/celaut/chat_prefs.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:argus_wallet/celaut/conversations.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/chat_screen.dart';
import 'package:argus_wallet/ui/celaut/instance_info_screen.dart';
import 'package:argus_wallet/ui/layout.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A chat client with no network: it echoes in memory, and it can fail.
class _FakeChat extends ChatClient {
  _FakeChat({List<ChatMessage> history = const []})
      : _messages = [...history],
        super(port: 0);

  final List<ChatMessage> _messages;
  ChatException? failWith;
  final sent = <String>[];

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  @override
  int get count => _messages.length;

  /// The fake stream is open: the screen does not read, and the test calls [push] for the
  /// events.
  bool open = false;

  @override
  bool get streaming => open;

  /// An event of the stream changed [messages].
  void push() => notifyListeners();

  /// The title of the service (section 6.10), once [titleKnown].
  String? fakeTitle;
  bool fakeTitleKnown = false;

  @override
  String? get title => fakeTitle;

  @override
  bool get titleKnown => fakeTitleKnown;

  /// Holds [syncWhenStarted] until it completes.
  Completer<void>? starting;

  /// The reads fail while this is true, as when the service is not up yet.
  bool broken = false;

  /// The reads that the screen made, and what the fake service does at each one.
  int syncs = 0;
  void Function()? onSync;

  /// While this is true the service makes no answer: each message waits.
  bool holdAnswers = false;
  int _unanswered = 0;

  /// The service makes the answers that it held.
  void releaseAnswers() {
    holdAnswers = false;
    _flush();
  }

  void _flush() {
    for (; _unanswered > 0; _unanswered--) {
      _messages.add(ChatMessage(
        seq: _messages.length + 1,
        role: 'assistant',
        text: 'echo: ${_messages.where((m) => m.fromUser).toList()[_messages.where((m) => !m.fromUser).length].text}',
      ));
    }
  }

  @override
  bool get awaitingAnswer => _messages.any((m) => m.isOpen);

  @override
  Future<void> sync() async {
    syncs++;
    if (broken) throw const ChatException(ChatErrorKind.unreachable);
    onSync?.call();
  }

  @override
  Future<void> syncWhenStarted(
          {Duration limit = const Duration(minutes: 2), Future<void> Function(Duration)? wait}) =>
      starting?.future ?? Future.value();

  /// The service takes `SetMessagePinned`. Holds [setPinned] on [pinGate]. Fails with
  /// [pinFailWith], as the client does: the message gets its old value back.
  bool pinSupported = true;
  Completer<void>? pinGate;
  ChatException? pinFailWith;
  final pinCalls = <(int, bool)>[];

  @override
  bool get canPin => pinSupported;

  @override
  Future<void> setPinned(ChatMessage message, bool pinned) async {
    pinCalls.add((message.seq, pinned));
    final i = _messages.indexWhere((m) => m.seq == message.seq);
    final before = _messages[i].pinned;
    _messages[i] = _messages[i].copyWith(pinned: pinned);
    notifyListeners();
    await pinGate?.future;
    final failure = pinFailWith;
    if (failure != null) {
      _messages[i] = _messages[i].copyWith(pinned: before);
      if (failure.status == 12) pinSupported = false;
      notifyListeners();
      throw failure;
    }
  }

  /// Holds [send] until it completes: a slow service.
  Completer<void>? gate;

  /// The kinds that the fake service accepts.
  Set<String> kinds = const {};

  @override
  Set<String> get accepts => broken ? const {} : kinds;

  /// The files of each send.
  final sentFiles = <List<OutgoingAttachment>>[];

  /// The bytes that [readAttachment] gives.
  Uint8List fileBytes = Uint8List(0);

  /// Holds [readAttachment] until it completes.
  Completer<void>? fileGate;

  /// The next reads of a file fail this many times.
  int failReads = 0;

  @override
  Future<Uint8List> readAttachment(int seq, int index) async {
    await fileGate?.future;
    if (failReads > 0) {
      failReads--;
      throw const ChatException(ChatErrorKind.unreachable);
    }
    return fileBytes;
  }

  /// The state of the corrector of each send (section 5.7).
  final correctors = <CorrectorReport?>[];

  @override
  Future<void> send(String text, {List<OutgoingAttachment> attachments = const [], CorrectorReport? corrector}) async {
    correctors.add(corrector);
    await gate?.future;
    final failure = failWith;
    if (failure != null) throw failure;
    sent.add(text);
    sentFiles.add(attachments);
    _messages.add(ChatMessage(
      seq: _messages.length + 1,
      role: 'user',
      text: text,
      attachments: [
        for (final f in attachments)
          ChatAttachment(kind: f.kind!, mime: f.mime, size: f.bytes.length, name: f.name),
      ],
    ));
    _unanswered++;
    if (!holdAnswers) _flush();
  }
}

/// A recorder with no microphone: it records a short, silent sound.
class _FakeRecorder implements AudioRecorderService {
  _FakeRecorder({this.permitted = true});

  final bool permitted;
  bool open = false;
  int cancels = 0;

  @override
  Stream<Duration> get elapsed => _elapsed.stream;
  final _elapsed = StreamController<Duration>.broadcast();

  @override
  Future<bool> start() async => open = permitted;

  @override
  Future<OutgoingAttachment?> stop() async {
    if (!open) return null;
    open = false;
    return OutgoingAttachment(
      mime: 'audio/wav',
      bytes: encodeWav(Uint8List(3200)),
      name: 'voice.wav',
    );
  }

  @override
  Future<void> cancel() async {
    open = false;
    cancels++;
  }

  /// The size limit: the stream of the length ends and the recording stays open.
  Future<void> hitLimit() => _elapsed.close();
}

/// A keep-alive that writes down what the screen asks of it.
class _FakeKeepAlive implements ConversationKeepAlive {
  final events = <String>[];
  final waits = <bool>[];

  @override
  Future<void> start() async => events.add('start');

  @override
  Future<void> waiting(bool on) async => waits.add(on);

  @override
  Future<void> stop() async => events.add('stop');
}

class _Wallets implements FullWallets {
  _Wallets({required this.full});

  final bool full;

  @override
  Future<List<PayerWallet>> payers() async => full
      ? [const PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: true)]
      : const [];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async => true;
}

/// A watcher with no network and no timers: it takes a hand-over and does nothing else.
ChatDoneWatcher _idleWatcher() => ChatDoneWatcher(
      holds: ForegroundHolds(isAndroid: false),
      isMuted: (_) => false,
      timer: (d, f) => _NoTimer(),
      connect: (_) async => throw Exception('no tunnel in this test'),
    );

class _NoTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}

final _echo = InstanceListView(
  instanceId: 'i1',
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
  alias: '',
  title: '',
);

const _streaming = ChatMessage(
  seq: 1,
  role: 'assistant',
  text: 'part',
  status: ChatMessage.statusStreaming,
  replyTo: 0,
);

extension on ChatMessage {
  ChatMessage copyDone() => ChatMessage(seq: seq, role: role, text: text, replyTo: replyTo);
}

/// A watcher that writes down what the screen tells it.
class _RecordingWatcher extends ChatDoneWatcher {
  _RecordingWatcher(this.handed, this.statuses, this.released)
      : super(holds: ForegroundHolds(isAndroid: false), isMuted: (_) => false);

  final List<InstanceListView> handed;
  final List<Map<int, String>> statuses;
  final List<String> released;

  @override
  void handOver(InstanceListView instance, Map<int, String> statuses) {
    handed.add(instance);
    this.statuses.add(statuses);
  }

  @override
  void release(String instanceId) => released.add(instanceId);
}

/// The text of a [Text], also when it is [Text.rich] (the Markdown of a message).
String plain(Text t) => t.data ?? t.textSpan!.toPlainText();

/// The style of the span that has exactly [text], looked up in the rich text of the tree.
TextStyle? spanStyle(WidgetTester tester, String text) {
  TextStyle? found;
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    r.text.visitChildren((s) {
      if (s is TextSpan && s.text == text) found = s.style;
      return true;
    });
  }
  return found;
}

void main() {
  late _FakeChat chat;
  late List<String> stops;
  late bool closed;
  late _FakeKeepAlive keepAlive;
  late ConversationNotes notes;
  late Future<List<OutgoingAttachment>> Function(Set<String>) pick;
  late List<(String, String)> savedTitles;
  Set<String>? pickedKinds;

  Future<void> open(
    WidgetTester tester, {
    bool fullWallet = true,
    bool starting = false,
    bool typewriter = false,
    VoidCallback? haptic,
    AudioRecorderService? recorder,
    ChatNotifier? notifier,
    ChatDoneWatcher? watcher,
    InstanceListView? instance,
  }) async {
    stops = [];
    savedTitles = [];
    closed = false;
    keepAlive = _FakeKeepAlive();
    notes = ConversationNotes();
    await tester.pumpWidget(
      MaterialApp(
        // The theme of the app: its buttons ask for the full width (the bug of the Run
        // screen), so the layout is checked with it.
        theme: argusTheme(watchful: false),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      instance: instance ?? _echo,
                      saveTitle: (id, title) => savedTitles.add((id, title)),
                      port: 1,
                      chat: chat,
                      wallets: _Wallets(full: fullWallet),
                      keepAlive: keepAlive,
                      starting: starting,
                      typewriter: typewriter,
                      haptic: haptic,
                      recorder: recorder,
                      notifier: notifier,
                      watcher: watcher ?? _idleWatcher(),
                      notes: notes,
                      pickFiles: (kinds, existing) async {
                        pickedKinds = kinds;
                        return selectAttachments(await pick(kinds), existing);
                      },
                      loadStatus: (_) async => InstanceStatusView(
                        instanceBalanceMu: '900',
                        costSoFarMu: '100',
                        streamsOpened: BigInt.one,
                      ),
                      stopInstance: (id) async {
                        stops.add(id);
                        return const StopView(refundMu: '900', clientBalanceMu: '5000');
                      },
                    ),
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    if (starting) {
      // The progress indicator turns until the service answers: no settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  /// The info page is a lazy list, and Stop is after the section of the time: the list
  /// builds it only when it comes near the screen.
  Future<void> scrollToStop(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('info-stop')),
      200,
      scrollable: find.descendant(of: find.byType(InstanceInfoScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
  }

  /// ⋮, then Stop, then the confirmation.
  Future<void> stopFromMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('chat-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-menu-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stop-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop-ok')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    // The old tests type with the keyboard of the system. The group "keyboard under the
    // input" checks the default, the keyboard of the app.
    chatPrefs.systemKeyboard = true;
    chat = _FakeChat();
    pick = (_) async => const [];
    pickedKinds = null;
  });

  // A PNG of one pixel.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  testWidgets('a slow answer shows the message at once, the dots, then the seconds',
      (tester) async {
    chat.gate = Completer<void>();
    await open(tester);
    await tester.enterText(find.byKey(const Key('chat-input')), 'think hard');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    // The message is on screen before the service answers, and the field is free.
    expect(find.byKey(const Key('chat-flying')), findsOneWidget);
    expect(find.text('think hard'), findsOneWidget);
    expect(find.text(appL10n.chatSending), findsOneWidget);
    expect(find.byKey(const Key('chat-typing')), findsOneWidget);
    expect(find.byKey(const Key('chat-waited')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, '');
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).enabled, isNot(false));

    await tester.pump(const Duration(seconds: 6));
    expect(find.text(appL10n.chatWaitingSeconds(6)), findsOneWidget);

    chat.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-flying')), findsNothing);
    expect(find.byKey(const Key('chat-typing')), findsNothing);
    expect(find.text('think hard'), findsOneWidget);
    expect(find.text('echo: think hard'), findsOneWidget);
  });

  testWidgets('a failed slow send gives the text back, with what the user wrote meanwhile',
      (tester) async {
    chat.gate = Completer<void>();
    chat.failWith = const ChatException(ChatErrorKind.busy);
    await open(tester);
    await tester.enterText(find.byKey(const Key('chat-input')), 'first');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('chat-input')), 'second');
    chat.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-flying')), findsNothing);
    expect(find.text(appL10n.chatErrorBusy), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text,
        'first\nsecond');
  });

  testWidgets('the user can send a second message while the first is still on its way',
      (tester) async {
    chat.gate = Completer<void>();
    await open(tester);
    await tester.enterText(find.byKey(const Key('chat-input')), 'first');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('chat-input')), 'second');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    expect(find.byKey(const Key('chat-flying')), findsNWidgets(2));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, '');

    chat.gate!.complete();
    await tester.pumpAndSettle();
    expect(chat.sent, ['first', 'second']);
    expect(find.byKey(const Key('chat-flying')), findsNothing);
    expect(find.text('echo: first'), findsOneWidget);
    expect(find.text('echo: second'), findsOneWidget);
  });

  testWidgets('a message that the service has shows as sent, and the dots wait for the answer',
      (tester) async {
    chat.holdAnswers = true;
    await open(tester);
    await tester.enterText(find.byKey(const Key('chat-input')), 'think hard');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('chat-flying')), findsNothing);
    expect(find.byKey(const Key('chat-bubble-1')), findsOneWidget);
    expect(find.byKey(const Key('chat-typing')), findsOneWidget);
    // The send is not blocked: the user can write on, and send.
    await tester.enterText(find.byKey(const Key('chat-input')), 'more');
    await tester.pump();
    expect(tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed, isNotNull);

    // The screen reads the conversation every 2 seconds while it waits.
    final before = chat.syncs;
    await tester.pump(const Duration(seconds: 2));
    expect(chat.syncs, before + 1);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(appL10n.chatWaitingSeconds(8)), findsOneWidget);

    chat.releaseAnswers();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('echo: think hard'), findsOneWidget);
    expect(find.byKey(const Key('chat-typing')), findsNothing);
    expect(notes.lastMessage('i1')?.text, 'echo: think hard');
  });

  testWidgets('an idle conversation is read every 10 seconds', (tester) async {
    await open(tester);
    final before = chat.syncs;
    await tester.pump(const Duration(seconds: 9));
    expect(chat.syncs, before);
    await tester.pump(const Duration(seconds: 1));
    expect(chat.syncs, before + 1);
  });

  testWidgets('an answer that grows shows its text and its reasoning apart, until it is done',
      (tester) async {
    chat = _FakeChat(history: [
      const ChatMessage(seq: 0, role: 'user', text: 'why?'),
      const ChatMessage(
        seq: 1,
        role: 'assistant',
        text: '',
        status: ChatMessage.statusStreaming,
        reasoning: 'Let me think.',
        replyTo: 0,
      ),
    ]);
    await open(tester);
    // No text yet: the reasoning is open, and the dots are not shown over it.
    expect(find.byKey(const Key('chat-reasoning-text')), findsOneWidget);
    expect(find.text('Let me think.'), findsOneWidget);
    expect(find.byKey(const Key('chat-typing')), findsNothing);

    chat.onSync = () => chat._messages[1] = const ChatMessage(
          seq: 1,
          role: 'assistant',
          text: 'Because.',
          status: ChatMessage.statusStreaming,
          reasoning: 'Let me think. Yes.',
          replyTo: 0,
        );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Because.'), findsOneWidget);
    // The text started: the reasoning closes by itself, and a tap opens it.
    expect(find.byKey(const Key('chat-reasoning-text')), findsNothing);
    await tester.tap(find.byKey(const Key('chat-reasoning-toggle')));
    await tester.pump();
    expect(find.text('Let me think. Yes.'), findsOneWidget);

    chat.onSync = () => chat._messages[1] = const ChatMessage(
          seq: 1,
          role: 'assistant',
          text: 'Because it is.',
          reasoning: 'Let me think. Yes.',
          replyTo: 0,
        );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Because it is.'), findsOneWidget);
    // The user opened it: it stays open. The wait is over, so the reads slow down.
    expect(find.text('Let me think. Yes.'), findsOneWidget);
    expect(chat.awaitingAnswer, isFalse);
  });

  testWidgets('an answer that failed says so, and keeps what it has', (tester) async {
    chat = _FakeChat(history: [
      const ChatMessage(seq: 0, role: 'user', text: 'why?'),
      const ChatMessage(
        seq: 1,
        role: 'assistant',
        text: 'Half',
        status: ChatMessage.statusFailed,
      ),
    ]);
    await open(tester);
    expect(find.text('Half'), findsOneWidget);
    expect(find.byKey(const Key('chat-failed-1')), findsOneWidget);
    expect(find.byKey(const Key('chat-typing')), findsNothing);
  });

  testWidgets('a failed answer shows the error of the service, and only when there is one',
      (tester) async {
    chat = _FakeChat(history: [
      const ChatMessage(seq: 0, role: 'user', text: 'why?'),
      const ChatMessage(
        seq: 1,
        role: 'assistant',
        text: 'Half',
        status: ChatMessage.statusFailed,
        error: 'The model ran out of credit.',
      ),
      const ChatMessage(seq: 2, role: 'user', text: 'again?'),
      const ChatMessage(seq: 3, role: 'assistant', text: 'x', status: ChatMessage.statusFailed),
      const ChatMessage(
        seq: 4,
        role: 'assistant',
        text: 'y',
        status: ChatMessage.statusDone,
        error: 'not shown: the message is not failed',
      ),
    ]);
    await open(tester);
    expect(find.byKey(const Key('chat-failed-1')), findsOneWidget);
    expect(find.byKey(const Key('chat-error-1')), findsOneWidget);
    expect(find.text('The model ran out of credit.'), findsOneWidget);
    expect(find.byKey(const Key('chat-failed-3')), findsOneWidget);
    expect(find.byKey(const Key('chat-error-3')), findsNothing);
    expect(find.byKey(const Key('chat-error-4')), findsNothing);
    expect(find.textContaining('not shown'), findsNothing);
  });

  testWidgets('a send that the file store cannot take says so, and keeps the text',
      (tester) async {
    chat.failWith = const ChatException(ChatErrorKind.storageFull, reason: 'storage_full');
    await open(tester);
    await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-error')), findsOneWidget);
    expect(find.textContaining('no room'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, 'Hello');
    expect(chat.sent, isEmpty, reason: 'no automatic second try');
  });

  testWidgets('a read that fails shows the error, and the next one that works clears it',
      (tester) async {
    await open(tester);
    chat.broken = true;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.byKey(const Key('chat-error')), findsOneWidget);
    chat.broken = false;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.byKey(const Key('chat-error')), findsNothing);
  });

  testWidgets('a service that accepts text only has no attach button', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('chat-attach')), findsNothing);
  });

  testWidgets('a file is picked, shown as a chip, removed, and sent with no text', (tester) async {
    chat.kinds = {'image'};
    chat.fileBytes = Uint8List.fromList(png);
    pick = (_) async =>
        [OutgoingAttachment(mime: 'image/png', bytes: Uint8List.fromList(png), name: 'dot.png')];
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    expect(pickedKinds, {'image'});
    expect(find.byKey(const Key('chat-pending-0')), findsOneWidget);
    expect(find.text('dot.png'), findsOneWidget);

    // Remove it, then pick it again.
    await tester.tap(find.byTooltip(appL10n.chatAttachmentRemove));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-pending')), findsNothing);
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();

    // No text: the file alone is enough to send.
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(chat.sent, ['']);
    expect(chat.sentFiles.single.single.name, 'dot.png');
    expect(find.byKey(const Key('chat-pending')), findsNothing);
    expect(find.byKey(const Key('chat-file-1-0')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a send that fails keeps the files', (tester) async {
    chat.kinds = {'audio'};
    pick = (_) async => [OutgoingAttachment(mime: 'audio/wav', bytes: Uint8List(4), name: 'a.wav')];
    chat.failWith = const ChatException(ChatErrorKind.unsupportedMedia);
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.chatErrorUnsupportedMedia), findsOneWidget);
    expect(find.byKey(const Key('chat-pending-0')), findsOneWidget);
  });

  OutgoingAttachment wav(String name, {int size = 4}) =>
      OutgoingAttachment(mime: 'audio/wav', bytes: Uint8List(size), name: name);

  testWidgets('what the pick leaves out is told in one message, and at most 4 files stay', (
    tester,
  ) async {
    chat.kinds = {'audio'};
    pick = (_) async => [
          for (var i = 0; i < 5; i++) wav('$i.wav'),
          wav('empty.wav', size: 0),
        ];
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-pending-3')), findsOneWidget);
    expect(find.byKey(const Key('chat-pending-4')), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('${appL10n.chatSkippedInvalid(1)}. ${appL10n.chatSkippedTooMany(1)}'),
      findsOneWidget,
    );
    // Four files are the most: the button waits until one is removed.
    expect(tester.widget<IconButton>(find.byKey(const Key('chat-attach'))).onPressed, isNull);
  });

  testWidgets('a file that is already attached is skipped, and the user is told', (tester) async {
    chat.kinds = {'audio'};
    pick = (_) async => [wav('a.wav')];
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-pending-0')), findsOneWidget);
    expect(find.byKey(const Key('chat-pending-1')), findsNothing);
    expect(find.text(appL10n.chatSkippedDuplicate(1)), findsOneWidget);
  });

  testWidgets('a long file name is cut in the chip', (tester) async {
    chat.kinds = {'audio'};
    pick = (_) async => [wav('${'voice-note-' * 10}.wav')];
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('chat-pending-0'))).width, lessThan(300));
  });

  testWidgets('after a first read that failed, Retry reads again and the attach button works', (
    tester,
  ) async {
    chat.kinds = {'audio'};
    chat.broken = true;
    pick = (_) async => [wav('a.wav')];
    await open(tester);
    expect(find.text(appL10n.chatErrorUnreachable), findsOneWidget);
    // The button stays, so the user is not locked out; the service is still down.
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-pending')), findsNothing);
    expect(find.text(appL10n.chatErrorUnreachable), findsOneWidget);

    chat.broken = false;
    await tester.tap(find.byKey(const Key('chat-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-error')), findsNothing);
    expect(find.byKey(const Key('chat-retry')), findsNothing);
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-pending-0')), findsOneWidget);
  });

  testWidgets('attach reads again first when the kinds are not known', (tester) async {
    chat.kinds = {'audio'};
    chat.broken = true;
    pick = (_) async => [wav('a.wav')];
    await open(tester);
    chat.broken = false;
    await tester.tap(find.byKey(const Key('chat-attach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-pending-0')), findsOneWidget);
    expect(find.byKey(const Key('chat-error')), findsNothing);
  });

  testWidgets('an image has its final height while it loads, and a name for the screen reader', (
    tester,
  ) async {
    chat = _FakeChat(history: const [
      ChatMessage(
        seq: 0,
        role: 'assistant',
        text: '',
        attachments: [ChatAttachment(kind: 'image', mime: 'image/png', size: 3, name: 'dot.png')],
      ),
    ]);
    chat.fileBytes = Uint8List.fromList(png);
    chat.fileGate = Completer<void>();
    // The progress indicator turns until the file loads: open without a settle.
    await open(tester, starting: true);
    final file = find.byKey(const Key('chat-file-0-0'));
    final loading = tester.getSize(file).height;
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    chat.fileGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.getSize(file).height, loading);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.semanticLabel, 'dot.png');
    expect(image.gaplessPlayback, isTrue);
    expect(image.image, isA<ResizeImage>());
  });

  testWidgets('a file that did not load loads again with a tap', (tester) async {
    chat = _FakeChat(history: const [
      ChatMessage(
        seq: 0,
        role: 'assistant',
        text: '',
        attachments: [ChatAttachment(kind: 'image', mime: 'image/png', size: 3)],
      ),
    ]);
    chat.fileBytes = Uint8List.fromList(png);
    chat.failReads = 1;
    await open(tester);
    expect(find.text(appL10n.chatAttachmentFailed), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-file-retry')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.chatAttachmentFailed), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel, appL10n.chatImage);
  });

  testWidgets('the audio row is a button for the screen reader, with its name', (tester) async {
    final handle = tester.ensureSemantics();
    chat = _FakeChat(history: const [
      ChatMessage(
        seq: 0,
        role: 'assistant',
        text: '',
        attachments: [
          ChatAttachment(kind: 'audio', mime: 'audio/mpeg', size: 4, name: 'a/../song.mp3')
        ],
      ),
    ]);
    await open(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('song.mp3. ${appL10n.chatAttachmentShare}')),
      matchesSemantics(
        isButton: true,
        hasLongPressAction: true,
        hasTapAction: true,
        label: 'song.mp3. ${appL10n.chatAttachmentShare}',
      ),
    );
    handle.dispose();
  });

  testWidgets('an audio file shows its name in the bubble', (tester) async {
    chat = _FakeChat(history: const [
      ChatMessage(
        seq: 0,
        role: 'assistant',
        text: 'listen',
        attachments: [ChatAttachment(kind: 'audio', mime: 'audio/mpeg', size: 4, name: 'song.mp3')],
      ),
    ]);
    await open(tester);
    expect(find.text('song.mp3'), findsOneWidget);
    expect(find.text('listen'), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack), findsOneWidget);
  });

  testWidgets('shows the history of a running instance and the cost so far', (tester) async {
    chat = _FakeChat(history: const [
      ChatMessage(seq: 0, role: 'user', text: 'one'),
      ChatMessage(seq: 1, role: 'assistant', text: 'echo: one'),
    ]);
    await open(tester);
    expect(find.text('one'), findsOneWidget);
    expect(find.text('echo: one'), findsOneWidget);
    expect(find.byKey(const Key('chat-cost')), findsOneWidget);
    expect(find.textContaining('100'), findsOneWidget);
    // The last message goes to the notes of the list, in memory.
    expect(notes.lastMessage('i1')?.text, 'echo: one');
  });

  testWidgets('the bar has the name, and under it the state, the node and the cost',
      (tester) async {
    await open(tester);
    expect(find.text('Echo chat'), findsOneWidget);
    final subtitle = tester.widget<Text>(find.byKey(const Key('chat-cost'))).data!;
    expect(subtitle, contains(appL10n.chatsStateRunning));
    expect(subtitle, contains('node.example:53460'));
    expect(subtitle, contains('100 MU'));
  });

  testWidgets('a tap on the name opens the info page of the instance', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-title')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.chatsInfoTitle), findsOneWidget);
    expect(find.byKey(const Key('info-name')), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byKey(const Key('info-service'))).data, '65' * 32);
    expect(tester.widget<SelectableText>(find.byKey(const Key('info-instance'))).data, 'i1');
    expect(find.text(appL10n.chatsInfoInstanceId.toUpperCase()), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byKey(const Key('info-node'))).data,
        'node.example:53460');
    expect(tester.widget<SelectableText>(find.byKey(const Key('info-slot'))).data,
        appL10n.chatsInfoChatSlot);
    expect(tester.widget<SelectableText>(find.byKey(const Key('info-cost'))).data, '100 MU');
    expect(find.byKey(const Key('info-started')), findsOneWidget);
    await scrollToStop(tester);
    expect(find.byKey(const Key('info-stop')), findsOneWidget);
    // Back from the info page: the conversation is still there.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('⋮ has Info and Stop', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-menu-info')), findsOneWidget);
    expect(find.byKey(const Key('chat-menu-stop')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-menu-info')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.chatsInfoTitle), findsOneWidget);
  });

  testWidgets('Stop on the info page stops the instance and goes back to the list', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-title')));
    await tester.pumpAndSettle();
    await scrollToStop(tester);
    await tester.tap(find.byKey(const Key('info-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stop-ok')));
    await tester.pumpAndSettle();
    expect(stops, ['i1']);
    expect(closed, isTrue);
    expect(notes.isStarting('i1'), isFalse);
  });

  testWidgets('a new instance shows that the service starts, until it answers', (tester) async {
    chat.starting = Completer<void>();
    await open(tester, starting: true);
    notes.markStarting('i1');
    expect(find.byKey(const Key('chat-starting')), findsOneWidget);
    expect(find.text(appL10n.chatStarting), findsOneWidget);
    expect(find.text(appL10n.chatEmpty), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('chat-cost'))).data,
      contains(appL10n.chatsStateStarting),
    );
    chat.starting!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-starting')), findsNothing);
    expect(find.text(appL10n.chatEmpty), findsOneWidget);
    expect(find.byKey(const Key('chat-error')), findsNothing);
    expect(notes.isStarting('i1'), isFalse);
  });

  testWidgets('a service that never starts shows the error', (tester) async {
    chat.starting = Completer<void>();
    await open(tester, starting: true);
    chat.starting!.completeError(const ChatException(ChatErrorKind.unreachable));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-starting')), findsNothing);
    expect(find.text(appL10n.chatErrorUnreachable), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('chat-cost'))).data,
      contains(appL10n.chatsStateUnreachable),
    );
  });

  testWidgets('an empty conversation asks the user to write', (tester) async {
    await open(tester);
    expect(find.text('Say something to start the conversation.'), findsOneWidget);
  });

  testWidgets('send shows the message and the answer, and clears the field', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(chat.sent, ['Hello']);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('echo: Hello'), findsOneWidget);
    expect(find.byKey(const Key('chat-bubble-1')), findsOneWidget);
    expect(find.byKey(const Key('chat-bubble-2')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, '');
    expect(notes.lastMessage('i1')?.text, 'echo: Hello');
  });

  testWidgets('a failed send shows the error and keeps the text', (tester) async {
    chat.failWith = const ChatException(ChatErrorKind.busy);
    await open(tester);
    await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-error')), findsOneWidget);
    expect(find.textContaining('busy'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, 'Hello');
  });

  testWidgets('back goes to the list at once: no question, and the instance runs on',
      (tester) async {
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stop-confirm')), findsNothing);
    expect(closed, isTrue);
    expect(stops, isEmpty);
    // Only the phone side is released.
    expect(keepAlive.events, ['start', 'stop']);
  });

  testWidgets('⋮ Stop asks, stops it, shows the refund and closes the screen', (tester) async {
    await open(tester);
    await stopFromMenu(tester);
    expect(stops, ['i1']);
    expect(closed, isTrue);
    expect(find.textContaining('Refund'), findsOneWidget);
  });

  testWidgets('⋮ Stop, then Cancel, changes nothing', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('chat-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-menu-stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stop-cancel')));
    await tester.pumpAndSettle();
    expect(stops, isEmpty);
    expect(closed, isFalse);
  });

  testWidgets('stop needs a full wallet: without one it stays and stops nothing', (tester) async {
    await open(tester, fullWallet: false);
    await stopFromMenu(tester);
    expect(stops, isEmpty);
    expect(closed, isFalse);
    expect(find.text(appL10n.celautOpenFullWalletNeeded), findsOneWidget);
  });

  testWidgets('the keep-alive starts when the screen opens and runs while it is open',
      (tester) async {
    await open(tester);
    expect(keepAlive.events, ['start']);
  });

  testWidgets('the wait for a service that just started keeps the phone awake, until it answers',
      (tester) async {
    await open(tester, starting: true);
    await tester.pumpAndSettle();
    expect(keepAlive.waits, [true, false]);
  });

  testWidgets('a running service needs no wait', (tester) async {
    await open(tester);
    expect(keepAlive.waits, isEmpty);
  });

  testWidgets('stopping the instance stops the keep-alive', (tester) async {
    await open(tester);
    await stopFromMenu(tester);
    expect(stops, ['i1']);
    expect(keepAlive.events.first, 'start');
    expect(keepAlive.events.last, 'stop');
  });

  testWidgets('a stop that needs a wallet and fails keeps the keep-alive', (tester) async {
    await open(tester, fullWallet: false);
    await stopFromMenu(tester);
    expect(keepAlive.events, ['start']);
  });

  group('floating layout and reading', () {
    final streaming = ChatMessage(
      seq: 1,
      role: 'assistant',
      text: 'Hello',
      status: ChatMessage.statusStreaming,
      replyTo: 0,
    );

    testWidgets('each message shows its time, with the date when it is not from today', (
      tester,
    ) async {
      final now = DateTime.now();
      chat = _FakeChat(
        history: [
          ChatMessage(
            seq: 0,
            role: 'user',
            text: 'old',
            createdAt: now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
          ),
          ChatMessage(seq: 1, role: 'assistant', text: 'new', createdAt: now.millisecondsSinceEpoch),
          const ChatMessage(seq: 2, role: 'assistant', text: 'no time'),
        ],
      );
      await open(tester);
      final today = tester.widget<Text>(find.byKey(const Key('chat-time-1'))).data!;
      final before = tester.widget<Text>(find.byKey(const Key('chat-time-0'))).data!;
      expect(today, isNot(contains(',')));
      expect(before, contains(','));
      // A message with no time shows none.
      expect(find.byKey(const Key('chat-time-2')), findsNothing);
    });

    testWidgets('entering a chat shows its end', (tester) async {
      chat = _FakeChat(
        history: [
          for (var i = 0; i < 60; i++)
            ChatMessage(
              seq: i,
              role: i.isEven ? 'user' : 'assistant',
              text: 'message $i ${'words ' * (i % 7 * 12)}',
            ),
        ],
      );
      await open(tester);
      final c = tester.widget<ListView>(find.byKey(const Key('chat-messages'))).controller!;
      expect(c.position.maxScrollExtent, greaterThan(0));
      expect(c.position.pixels, c.position.maxScrollExtent);
      expect(find.textContaining('message 59'), findsOneWidget);
      expect(find.textContaining('message 0 '), findsNothing);
    });

    testWidgets('on a wide window the conversation is a column in the middle', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      chat = _FakeChat(
        history: [
          ChatMessage(seq: 0, role: 'user', text: 'a long message of the user ' * 20),
          const ChatMessage(seq: 1, role: 'assistant', text: 'the answer'),
        ],
      );
      await open(tester);
      final column = tester.getRect(find.byKey(const Key('chat-messages')));
      expect(column.width, AppLayout.readable);
      expect(column.center.dx, 700);
      // The header and the input are in the column too.
      expect(tester.getRect(find.byKey(const Key('chat-header'))).left, greaterThanOrEqualTo(column.left));
      expect(tester.getRect(find.byKey(const Key('chat-input-bar'))).right, lessThanOrEqualTo(column.right));
      // A bubble of the user takes at most 80% of the column, not of the window.
      expect(
        tester.getSize(find.byKey(const Key('chat-bubble-0'))).width,
        lessThanOrEqualTo(AppLayout.readable * 0.8),
      );
    });

    testWidgets('the header and the input float over the list, which leaves room for them', (
      tester,
    ) async {
      chat = _FakeChat(
        history: [
          for (var i = 0; i < 30; i++)
            ChatMessage(seq: i, role: i.isEven ? 'user' : 'assistant', text: 'message $i'),
        ],
      );
      await open(tester);
      final list = tester.widget<ListView>(find.byKey(const Key('chat-messages')));
      final pad = list.padding!.resolve(TextDirection.ltr);
      final header = tester.getRect(find.byKey(const Key('chat-header')));
      final input = tester.getRect(find.byKey(const Key('chat-input-bar')));
      final screen = tester.getRect(find.byType(Scaffold).first);
      expect(find.byType(AppBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-header')),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat-input-bar')),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      // The list runs under both bars, and its padding clears them.
      final listRect = tester.getRect(find.byKey(const Key('chat-messages')));
      expect(listRect.top, screen.top);
      expect(listRect.bottom, screen.bottom);
      expect(pad.top, greaterThanOrEqualTo(header.bottom));
      expect(pad.bottom, greaterThanOrEqualTo(screen.bottom - input.top));
      // At the end of the list the last message is above the input.
      expect(tester.getRect(find.text('message 29')).bottom, lessThanOrEqualTo(input.top));
      // The text fades out where it reaches the bars, at both ends.
      expect(
        find.ancestor(of: find.byKey(const Key('chat-messages')), matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
    });

    testWidgets('a message of the service has no bubble, and one of the user has', (tester) async {
      chat = _FakeChat(
        history: const [
          ChatMessage(seq: 0, role: 'user', text: 'q'),
          ChatMessage(seq: 1, role: 'assistant', text: 'a'),
        ],
      );
      await open(tester);
      BoxDecoration? deco(int seq) =>
          tester.widget<Container>(find.byKey(Key('chat-bubble-$seq'))).decoration
              as BoxDecoration?;
      expect(deco(0)?.color, isNotNull);
      expect(deco(1), isNull);
    });

    testWidgets('the size and the font of the text follow the settings', (tester) async {
      chat = _FakeChat(
        history: const [ChatMessage(seq: 0, role: 'assistant', text: 'big')],
      );
      SharedPreferences.setMockInitialValues({});
      final old = chatPrefs.fontSize;
      unawaited(chatPrefs.setFontSize(22));
      await open(tester);
      expect(spanStyle(tester, 'big')?.fontSize, 22);
      unawaited(chatPrefs.setFontSize(14));
      await tester.pump();
      expect(spanStyle(tester, 'big')?.fontSize, 14);
      unawaited(chatPrefs.setFontSize(old));
    });

    testWidgets('the background of the instance is painted behind the list', (tester) async {
      chat = _FakeChat();
      SharedPreferences.setMockInitialValues({});
      unawaited(chatPrefs.setBackground('i1', 'dots'));
      await open(tester);
      final paint = tester.widget<CustomPaint>(find.byKey(const Key('chat-background')));
      expect((paint.painter as ChatBackgroundPainter).id, 'dots');
      unawaited(chatPrefs.setBackground('i1', 'none'));
    });

    testWidgets('a growing answer types, with ticks, and catches up', (tester) async {
      chat = _FakeChat(
        history: [
          const ChatMessage(seq: 0, role: 'user', text: 'hi'),
          streaming,
        ],
      );
      var ticks = 0;
      await open(tester, typewriter: true, haptic: () => ticks++);
      // What the first read had shows at once, with no tick.
      expect(find.text('Hello'), findsOneWidget);
      expect(ticks, 0);
      chat.onSync = () => chat._messages[1] = ChatMessage(
        seq: 1,
        role: 'assistant',
        text: 'Hello ${'world ' * 20}',
        status: ChatMessage.statusStreaming,
        replyTo: 0,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      final partial = plain(tester.widget<Text>(find.textContaining('Hello').last));
      expect(partial.length, lessThan('Hello ${'world ' * 20}'.length));
      expect(partial.startsWith('Hello'), isTrue);
      expect(ticks, greaterThan(0));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(
        plain(tester.widget<Text>(find.textContaining('Hello').last)),
        'Hello ${'world ' * 20}'.trimRight(),
      );
    });

    testWidgets('no tick while the app is in the background', (tester) async {
      chat = _FakeChat(
        history: [
          const ChatMessage(seq: 0, role: 'user', text: 'hi'),
          streaming,
        ],
      );
      var ticks = 0;
      await open(tester, typewriter: true, haptic: () => ticks++);
      for (final st in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      chat.onSync = () => chat._messages[1] = ChatMessage(
        seq: 1,
        role: 'assistant',
        text: 'Hello ${'world ' * 20}',
        status: ChatMessage.statusStreaming,
        replyTo: 0,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      expect(ticks, 0);
      for (final st in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('voice messages', () {
    testWidgets('the microphone takes the place of Send while there is nothing to send',
        (tester) async {
      chat.kinds = {'audio'};
      await open(tester, recorder: _FakeRecorder());
      expect(find.byKey(const Key('chat-mic')), findsOneWidget);
      expect(find.byKey(const Key('chat-send')), findsNothing);
      await tester.enterText(find.byKey(const Key('chat-input')), 'hi');
      await tester.pump();
      expect(find.byKey(const Key('chat-mic')), findsNothing);
      expect(find.byKey(const Key('chat-send')), findsOneWidget);
    });

    testWidgets('a service that takes no audio shows Send only', (tester) async {
      await open(tester, recorder: _FakeRecorder());
      expect(find.byKey(const Key('chat-mic')), findsNothing);
      expect(find.byKey(const Key('chat-send')), findsOneWidget);
    });

    testWidgets('a recording becomes a pending file, and goes with the message', (tester) async {
      chat.kinds = {'audio'};
      final recorder = _FakeRecorder();
      await open(tester, recorder: recorder);
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pump();
      expect(find.byKey(const Key('chat-record-time')), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-record-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-record-time')), findsNothing);
      expect(find.byKey(const Key('chat-pending-0')), findsOneWidget);
      // With a file waiting, Send is back.
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(chat.sentFiles.single.single.mime, 'audio/wav');
    });

    testWidgets('the size limit attaches the recording and says so', (tester) async {
      chat.kinds = {'audio'};
      final recorder = _FakeRecorder();
      await open(tester, recorder: recorder);
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pump();
      await recorder.hitLimit();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-record-time')), findsNothing);
      expect(find.byKey(const Key('chat-pending-0')), findsOneWidget);
      expect(find.text(appL10n.chatMicLimit), findsOneWidget);
    });

    testWidgets('cancel drops the recording', (tester) async {
      chat.kinds = {'audio'};
      final recorder = _FakeRecorder();
      await open(tester, recorder: recorder);
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-record-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-record-time')), findsNothing);
      expect(find.byKey(const Key('chat-pending-0')), findsNothing);
      expect(recorder.cancels, 1);
      expect(find.byKey(const Key('chat-mic')), findsOneWidget);
    });

    testWidgets('a refused permission says so, and records nothing', (tester) async {
      chat.kinds = {'audio'};
      await open(tester, recorder: _FakeRecorder(permitted: false));
      await tester.tap(find.byKey(const Key('chat-mic')));
      await tester.pump();
      expect(find.text(appL10n.chatMicDenied), findsOneWidget);
      expect(find.byKey(const Key('chat-record-time')), findsNothing);
    });
  });

  group('HTML blocks', () {
    const html = ChatMessage(
      seq: 1,
      role: 'assistant',
      text: 'Before\n```html\n<b>bold</b>\n```\nAfter',
    );

    testWidgets('show as widgets when the setting is on', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), html]);
      await open(tester);
      expect(find.byKey(const Key('chat-html')), findsOneWidget);
      expect(find.textContaining('```html'), findsNothing);
    });

    testWidgets('show as code when the setting is off', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), html]);
      await chatPrefs.setHtmlWidgets(false);
      addTearDown(() => chatPrefs.setHtmlWidgets(true));
      await open(tester);
      expect(find.byKey(const Key('chat-html')), findsNothing);
      expect(find.byKey(const Key('chat-code')), findsOneWidget);
      expect(find.text('html'), findsOneWidget);
    });
  });

  group('keyboard under the input', () {
    const form = ChatMessage(
      seq: 1,
      role: 'assistant',
      text: 'Pick\n```keyboard\n<input data-name="n" placeholder="Name"><button data-say="Hi {n}">Go</button>\n```',
      replyTo: 0,
    );

    setUp(() => chatPrefs.systemKeyboard = false);
    tearDown(() => chatPrefs.systemKeyboard = true);

    testWidgets('the keyboard of the app shows under the input, and types in it', (tester) async {
      await open(tester);
      final keyboard = find.byKey(const Key('chat-virtual-keyboard'));
      expect(keyboard, findsOneWidget);
      expect(tester.getTopLeft(keyboard).dy, greaterThan(tester.getBottomLeft(find.byKey(const Key('chat-input'))).dy));
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).keyboardType, TextInputType.none);
      await tester.tap(find.byKey(const Key('vk-char-h')));
      await tester.tap(find.byKey(const Key('vk-char-i')));
      await tester.pump();
      // The first letter of a sentence is a capital.
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, 'Hi');
    });

    testWidgets('fast typing on the keyboard of the app loses no key (#121)', (tester) async {
      await open(tester);
      // Two thumbs: the next finger is down before the last one is up, no frame between
      // the keys, and a finger can land in the space between two caps.
      const text = 'hello there, this is fast typing with two thumbs.';
      final random = Random(121);
      TestGesture? last;
      var pointer = 70;
      for (final c in text.characters) {
        final cap = tester.getRect(find.byKey(Key(c == ' ' ? 'vk-space' : 'vk-char-$c'))).inflate(2.5);
        final g = await tester.createGesture(pointer: pointer++, kind: PointerDeviceKind.touch);
        await g.down(Offset(cap.left + random.nextDouble() * cap.width, cap.top + random.nextDouble() * cap.height));
        await last?.up();
        last = g;
      }
      await last?.up();
      await tester.pump();
      // The first letter of a sentence is a capital; every other key is there.
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, 'H${text.substring(1)}');
      expect(notes.draft(_echo.instanceId), 'H${text.substring(1)}');
    });

    testWidgets('a form shows under the input, instead of the keyboard of the app', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), form]);
      await open(tester);
      final dock = find.byKey(const Key('chat-keyboard-dock'));
      expect(dock, findsOneWidget);
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsNothing);
      expect(tester.getTopLeft(dock).dy, greaterThan(tester.getBottomLeft(find.byKey(const Key('chat-input'))).dy));
    });

    testWidgets('a field of the form types with the keyboard of the app', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), form]);
      await open(tester);
      await tester.tap(find.byKey(const Key('chat-field-n')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard-form')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vk-char-a')));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('chat-field-n'))).controller!.text, 'a');
    });

    testWidgets('closing the form brings the keyboard back, and a tap on the card opens the form', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), form]);
      await open(tester);
      await tester.tap(find.byKey(const Key('chat-keyboard-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsNothing);
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-keyboard-reopen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsOneWidget);
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsNothing);
    });

    List<ChatMessage> longChat({bool withForm = false}) => [
          for (var i = 0; i < 20; i++)
            ChatMessage(
              seq: i,
              role: i.isEven ? 'user' : 'assistant',
              text: 'Line $i ${'word ' * 30}',
              replyTo: i.isEven ? null : i - 1,
            ),
          if (withForm) ChatMessage(seq: 20, role: 'assistant', text: form.text, replyTo: 19),
        ];

    testWidgets('a scroll of the conversation hides the keyboard of the app, and a tap on the input shows it', (tester) async {
      chat = _FakeChat(history: longChat());
      await open(tester);
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsOneWidget);
      // The list runs under the input, so the drag starts above it.
      final messages = tester.getRect(find.byKey(const Key('chat-messages')));
      await tester.dragFrom(Offset(messages.center.dx, messages.center.dy - 150), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-input')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsOneWidget);
    });

    testWidgets('a scroll of the conversation hides the form too', (tester) async {
      chat = _FakeChat(history: longChat(withForm: true));
      await open(tester);
      expect(find.byKey(const Key('chat-keyboard-dock')), findsOneWidget);
      await tester.drag(find.byKey(const Key('chat-messages')), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsNothing);
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-input')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsOneWidget);
    });

    testWidgets('a scroll towards the end does not hide the keyboard', (tester) async {
      chat = _FakeChat(history: longChat());
      await open(tester);
      await tester.drag(find.byKey(const Key('chat-messages')), const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-input')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsOneWidget);
      await tester.drag(find.byKey(const Key('chat-messages')), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsOneWidget);
    });

    testWidgets('a touch that moves the conversation a little does not hide the keyboard', (tester) async {
      chat = _FakeChat(history: longChat());
      await open(tester);
      await tester.drag(find.byKey(const Key('chat-messages')), const Offset(0, 22));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsOneWidget);
    });

    testWidgets('a form that the scroll hid shows again at the end', (tester) async {
      chat = _FakeChat(history: longChat(withForm: true));
      await open(tester);
      await tester.drag(find.byKey(const Key('chat-messages')), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsNothing);
      await tester.drag(find.byKey(const Key('chat-messages')), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsOneWidget);
    });

    testWidgets('a form that a tap on the conversation hid opens with a tap on its card', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), form]);
      await open(tester);
      await tester.tapAt(tester.getTopLeft(find.byKey(const Key('chat-messages'))) + const Offset(200, 120));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-keyboard-reopen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-keyboard-dock')), findsOneWidget);
    });

    testWidgets('Back hides the keyboard of the app first, and then leaves the chat', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsNothing);
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-input')), findsNothing);
    });

    testWidgets('a tap on the conversation hides the keyboard of the app', (tester) async {
      chat = _FakeChat(history: longChat());
      await open(tester);
      // Above the bar of the input, which the chips of the suggestions make taller.
      final list = tester.getRect(find.byKey(const Key('chat-messages')));
      await tester.tapAt(Offset(list.center.dx, list.top + list.height * 0.3));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsNothing);
    });

    testWidgets('the first letter of the input is a capital', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('vk-char-h')));
      await tester.tap(find.byKey(const Key('vk-char-i')));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, 'Hi');
    });

    testWidgets('on a computer Enter sends and Shift+Enter makes a new line', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await open(tester);
        await tester.tap(find.byKey(const Key('chat-input')));
        await tester.pump();
        final input = tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!;
        input.text = 'hello';
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(input.text, 'hello');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(input.text, isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('with the keyboard of the system on, the input uses it, but not under a form', (tester) async {
      chatPrefs.systemKeyboard = true;
      await open(tester);
      expect(find.byKey(const Key('chat-virtual-keyboard')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).keyboardType, TextInputType.multiline);
    });

    testWidgets('with the keyboard of the system on, a form turns it off for the input', (tester) async {
      chatPrefs.systemKeyboard = true;
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), form]);
      await open(tester);
      expect(find.byKey(const Key('chat-keyboard-dock')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).keyboardType, TextInputType.none);
    });
  });

  group('notices of a done answer', () {
    final shown = <String>[];
    late ChatNotifier notifier;

    ChatMessage answer(String status) => ChatMessage(
          seq: 1,
          role: 'assistant',
          text: 'The answer',
          status: status,
          replyTo: 0,
        );

    setUp(() {
      shown.clear();
      notifier = ChatNotifier(show: (id, title, body, payload) async => shown.add('$payload|$body'));
      chat = _FakeChat(history: [
        const ChatMessage(seq: 0, role: 'user', text: 'hi'),
        answer(ChatMessage.statusStreaming),
      ]);
    });

    Future<void> finishAnswer(WidgetTester tester) async {
      chat.onSync = () => chat._messages[1] = answer(ChatMessage.statusDone);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    }

    void background(WidgetTester tester) {
      for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
    }

    void foreground(WidgetTester tester) {
      for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
    }

    testWidgets('are sent when the app is in the background', (tester) async {
      await open(tester, notifier: notifier);
      background(tester);
      await finishAnswer(tester);
      // The notice has no text of the answer: the lock screen can show it.
      expect(shown, ['chat/i1|${appL10n.chatNotifyDoneBody}']);
      foreground(tester);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('are not sent for a short pause of the app (inactive)', (tester) async {
      await open(tester, notifier: notifier);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await finishAnswer(tester);
      expect(shown, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('are not sent while the chat is in front', (tester) async {
      await open(tester, notifier: notifier);
      await finishAnswer(tester);
      expect(shown, isEmpty);
    });

    testWidgets('are sent when another screen covers the chat', (tester) async {
      await open(tester, notifier: notifier);
      await tester.tap(find.byKey(const Key('chat-title')));
      await tester.pumpAndSettle();
      await finishAnswer(tester);
      expect(shown, hasLength(1));
    });

    testWidgets('are not sent for a muted chat', (tester) async {
      await chatPrefs.setMuted('i1', true);
      addTearDown(() => chatPrefs.setMuted('i1', false));
      await open(tester, notifier: ChatNotifier(show: (id, title, body, payload) async => shown.add(payload)));
      background(tester);
      await finishAnswer(tester);
      expect(shown, isEmpty);
      foreground(tester);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('are not sent for the history that the first read brings', (tester) async {
      chat = _FakeChat(history: [
        const ChatMessage(seq: 0, role: 'user', text: 'hi'),
        answer(ChatMessage.statusDone),
      ]);
      await open(tester, notifier: notifier);
      background(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(shown, isEmpty);
      foreground(tester);
    });

    testWidgets('the screen and the watcher give one notice for a message', (tester) async {
      final watcher = _idleWatcher();
      await open(tester, notifier: notifier, watcher: watcher);
      background(tester);
      await finishAnswer(tester);
      expect(shown, hasLength(1));
      // The watcher has this message as claimed: it gives no second notice.
      expect(watcher.claim('i1', 1), isFalse);
      foreground(tester);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a message that the watcher saw gets no notice from the screen', (tester) async {
      final watcher = _idleWatcher();
      expect(watcher.claim('i1', 1), isTrue);
      await open(tester, notifier: notifier, watcher: watcher);
      background(tester);
      await finishAnswer(tester);
      expect(shown, isEmpty);
      foreground(tester);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the menu mutes and unmutes the chat', (tester) async {
      addTearDown(() => chatPrefs.setMuted('i1', false));
      await open(tester, notifier: notifier);
      expect(find.byKey(const Key('chat-muted')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-menu')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatMute), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-menu-mute')));
      await tester.pumpAndSettle();
      expect(chatPrefs.isMuted('i1'), isTrue);
      expect(find.byKey(const Key('chat-muted')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-menu')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatUnmute), findsOneWidget);
    });
  });

  group('hand-over to the watcher', () {
    late List<InstanceListView> handed;
    late List<Map<int, String>> handedStatuses;
    late List<String> released;
    late ChatDoneWatcher watcher;

    setUp(() {
      handed = [];
      handedStatuses = [];
      released = [];
      watcher = _RecordingWatcher(handed, handedStatuses, released);
    });

    Future<void> leave(WidgetTester tester) async {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    testWidgets('the screen takes its instance back from the watcher when it opens', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), _streaming]);
      await open(tester, watcher: watcher);
      expect(released, ['i1']);
      await leave(tester);
    });

    testWidgets('closing with an answer pending hands the chat over, with the statuses', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), _streaming]);
      await open(tester, watcher: watcher);
      await leave(tester);
      expect(handed.map((i) => i.instanceId), ['i1']);
      // The statuses are what the screen knew: the watcher skips the done ones.
      expect(handedStatuses.single, {0: 'done', 1: 'streaming'});
    });

    testWidgets('closing with nothing pending hands nothing over', (tester) async {
      chat = _FakeChat(history: [
        const ChatMessage(seq: 0, role: 'user', text: 'hi'),
        _streaming.copyDone(),
      ]);
      await open(tester, watcher: watcher);
      await leave(tester);
      expect(handed, isEmpty);
    });

    testWidgets('an instance that stops from the screen is not handed over', (tester) async {
      chat = _FakeChat(history: [const ChatMessage(seq: 0, role: 'user', text: 'hi'), _streaming]);
      await open(tester, watcher: watcher);
      await stopFromMenu(tester);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(handed, isEmpty);
    });
  });

  group('pinned messages', () {
    /// A long conversation: the assistant pins the messages in [pins].
    List<ChatMessage> talk(Set<int> pins) => [
          for (var i = 0; i < 40; i++)
            ChatMessage(
              seq: i,
              id: 'm$i',
              role: i.isEven ? 'user' : 'assistant',
              text: pins.contains(i) ? 'PIN$i ${'pinned words ' * 40}' : 'line $i\n\n\nmore\n\nmore',
              pinned: pins.contains(i),
            ),
        ];

    ScrollController list(WidgetTester tester) =>
        tester.widget<ListView>(find.byKey(const Key('chat-messages'))).controller!;

    /// The pinned text that the banner shows, or null.
    String? banner(WidgetTester tester) {
      final f = find.descendant(of: find.byKey(const Key('chat-pinned')), matching: find.byType(Text));
      if (f.evaluate().isEmpty) return null;
      final text = plain(tester.widget<Text>(f.first));
      return text.split(' ').first;
    }

    testWidgets('the last pinned message above the screen is pinned', (tester) async {
      chat = _FakeChat(history: talk({3, 21}));
      await open(tester);
      expect(banner(tester), 'PIN21');
    });

    testWidgets('it stops when the user scrolls up past it, and the one before takes over',
        (tester) async {
      chat = _FakeChat(history: talk({3, 21}));
      await open(tester);
      final c = list(tester);
      final seen = <String?>[];
      for (var y = c.position.maxScrollExtent; y >= 0; y -= 40) {
        c.jumpTo(y);
        await tester.pump();
        await tester.pump();
        seen.add(banner(tester));
      }
      // Going up: PIN21, then PIN3, then none at the top.
      final order = <String?>[];
      for (final b in seen) {
        if (order.isEmpty || order.last != b) order.add(b);
      }
      expect(order, ['PIN21', 'PIN3', null]);
    });

    testWidgets('nothing is pinned at the top of the chat', (tester) async {
      chat = _FakeChat(history: talk({3}));
      await open(tester);
      list(tester).jumpTo(0);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('chat-pinned')), findsNothing);
    });

    testWidgets('it takes at most the share of the chat that the user chose, and opens on a tap',
        (tester) async {
      chat = _FakeChat(history: talk({3}));
      await open(tester);
      final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final closed = tester.getSize(find.byKey(const Key('chat-pinned'))).height;
      expect(closed, lessThanOrEqualTo(height * chatPrefs.pinnedMaxFraction + 1));
      await tester.tap(find.byKey(const Key('chat-pinned-toggle')));
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('chat-pinned'))).height, greaterThan(closed));
    });
  });

  group('pin and unpin by the user', () {
    Future<void> unpinOf(_FakeChat c, int seq) =>
        c.setPinned(c.messages.firstWhere((m) => m.seq == seq), false);

    List<ChatMessage> talk(Set<int> pins) => [
          for (var i = 0; i < 40; i++)
            ChatMessage(
              seq: i,
              id: 'm$i',
              role: i.isEven ? 'user' : 'assistant',
              text: pins.contains(i) ? 'PIN$i ${'pinned words ' * 40}' : 'line $i\n\n\nmore\n\nmore',
              pinned: pins.contains(i),
            ),
        ];

    String? banner(WidgetTester tester) {
      final f = find.descendant(of: find.byKey(const Key('chat-pinned')), matching: find.byType(Text));
      if (f.evaluate().isEmpty) return null;
      return plain(tester.widget<Text>(f.first)).split(' ').first;
    }

    /// A long press on the bubble, next to its text, opens the menu of the message.
    Future<void> menu(WidgetTester tester, int seq) async {
      final at = tester.getTopLeft(find.byKey(Key('chat-bubble-$seq'))) + const Offset(1, 1);
      await tester.longPressAt(at);
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('a long press pins an assistant message, and an icon shows', (tester) async {
      chat = _FakeChat(history: talk({}));
      await open(tester);
      await menu(tester, 39);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Select text'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      await pick(tester, 'chat-menu-pin');
      expect(chat.pinCalls, [(39, true)]);
      expect(find.byKey(const Key('chat-pin-icon-39')), findsOneWidget);
      expect(find.byKey(const Key('chat-pin-icon-38')), findsNothing);
    });

    testWidgets('the menu of a pinned message unpins it', (tester) async {
      chat = _FakeChat(history: talk({39}));
      await open(tester);
      expect(find.byKey(const Key('chat-pin-icon-39')), findsOneWidget);
      await menu(tester, 39);
      expect(find.text('Unpin'), findsOneWidget);
      await pick(tester, 'chat-menu-pin');
      expect(chat.pinCalls, [(39, false)]);
      expect(find.byKey(const Key('chat-pin-icon-39')), findsNothing);
    });

    testWidgets('the user can pin a bubble of the user', (tester) async {
      chat = _FakeChat(history: talk({}));
      await open(tester);
      await menu(tester, 38);
      await pick(tester, 'chat-menu-pin');
      expect(chat.pinCalls, [(38, true)]);
      expect(find.byKey(const Key('chat-pin-icon-38')), findsOneWidget);
    });

    testWidgets('the pin shows before the service answers', (tester) async {
      chat = _FakeChat(history: talk({}))..pinGate = Completer<void>();
      await open(tester);
      await menu(tester, 39);
      await tester.tap(find.byKey(const Key('chat-menu-pin')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('chat-pin-icon-39')), findsOneWidget);
      chat.pinGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-pin-icon-39')), findsOneWidget);
    });

    testWidgets('a failure gives the message back and tells why', (tester) async {
      chat = _FakeChat(history: talk({}))
        ..pinFailWith = const ChatException(ChatErrorKind.unreachable);
      await open(tester);
      await menu(tester, 39);
      await pick(tester, 'chat-menu-pin');
      expect(find.byKey(const Key('chat-pin-icon-39')), findsNothing);
      expect(find.textContaining('did not answer'), findsOneWidget);
    });

    testWidgets('Copy puts the text on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
          (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      chat = _FakeChat(history: talk({}));
      await open(tester);
      await menu(tester, 38);
      await pick(tester, 'chat-menu-copy');
      expect(copied, startsWith('line 38'));
      expect(find.text('Message copied.'), findsOneWidget);
    });

    testWidgets('a long press on the text itself opens the menu, and Select text shows it to select', (
      tester,
    ) async {
      chat = _FakeChat(history: talk({}));
      await open(tester);
      // On the words, not next to them: the text must not start a selection of its own.
      await tester.longPress(find.textContaining('line 38'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-menu-copy')), findsOneWidget);
      await pick(tester, 'chat-menu-select');
      final shown = tester.widget<SelectableText>(find.byKey(const Key('chat-select-text')));
      expect(shown.data, startsWith('line 38'));
    });

    testWidgets('the banner follows a pin and an unpin', (tester) async {
      chat = _FakeChat(history: talk({}));
      await open(tester);
      expect(banner(tester), isNull);
      await menu(tester, 39);
      await pick(tester, 'chat-menu-pin');
      // The last message anchors nothing.
      expect(banner(tester), isNull);
      chat.open = true;
      // The service pins an older message through the stream.
      final c = tester.widget<ListView>(find.byKey(const Key('chat-messages'))).controller!;
      c.jumpTo(c.position.maxScrollExtent);
      chat._messages[20] = chat._messages[20].copyWith(pinned: true);
      chat.push();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(banner(tester), startsWith('line'));
      expect(find.byKey(const Key('chat-pinned')), findsOneWidget);
    });

    testWidgets('a pin from the stream shows, and its unpin drops the banner', (tester) async {
      chat = _FakeChat(history: talk({}))..open = true;
      await open(tester);
      chat._messages[3] = chat._messages[3].copyWith(pinned: true, text: 'PIN3 ${'words ' * 40}');
      chat.push();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(banner(tester), 'PIN3');
      chat._messages[3] = chat._messages[3].copyWith(pinned: false);
      chat.push();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(banner(tester), isNull);
    });

    testWidgets('unpin of the anchored message gives the banner to the one before',
        (tester) async {
      chat = _FakeChat(history: talk({3, 21}));
      await open(tester);
      expect(banner(tester), 'PIN21');
      final c = tester.widget<ListView>(find.byKey(const Key('chat-messages'))).controller!;
      // The user unpins it, as the menu does.
      await unpinOf(chat, 21);
      await tester.pump();
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(banner(tester), 'PIN3');
    });

    testWidgets('a service that does not take it gets no action, and none after UNIMPLEMENTED',
        (tester) async {
      chat = _FakeChat(history: talk({}))
        ..pinFailWith = const ChatException(ChatErrorKind.other, status: 12);
      await open(tester);
      await menu(tester, 39);
      await pick(tester, 'chat-menu-pin');
      expect(find.byKey(const Key('chat-pin-icon-39')), findsNothing);
      await menu(tester, 39);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.byKey(const Key('chat-menu-pin')), findsNothing);
    });

    testWidgets('no action while the client says the service does not take it', (tester) async {
      chat = _FakeChat(history: talk({}))..pinSupported = false;
      await open(tester);
      await menu(tester, 39);
      expect(find.byKey(const Key('chat-menu-pin')), findsNothing);
    });
  });

  group('stream of the client', () {
    testWidgets('the events show without a read, and the screen does not poll', (tester) async {
      chat = _FakeChat(history: [
        const ChatMessage(seq: 1, role: 'user', text: 'hi'),
        const ChatMessage(seq: 2, role: 'assistant', text: 'hello', replyTo: 1),
      ])
        ..open = true;
      await open(tester);
      final syncs = chat.syncs;
      chat._messages.add(const ChatMessage(
        seq: 3,
        role: 'assistant',
        text: 'part',
        status: ChatMessage.statusStreaming,
        replyTo: 1,
      ));
      chat.push();
      await tester.pump();
      expect(find.text('part'), findsOneWidget);
      chat._messages[2] = chat._messages[2].copyWith(text: 'part two', status: ChatMessage.statusDone);
      chat.push();
      await tester.pump();
      expect(find.text('part two'), findsOneWidget);
      // No timer reads while the stream is open, however long the wait.
      await tester.pump(const Duration(seconds: 30));
      expect(chat.syncs, syncs);
    });

    testWidgets('the screen reads again when the stream is lost', (tester) async {
      chat = _FakeChat(history: [
        const ChatMessage(seq: 1, role: 'user', text: 'hi'),
        const ChatMessage(seq: 2, role: 'assistant', text: 'hello', replyTo: 1),
      ])
        ..open = true;
      await open(tester);
      final syncs = chat.syncs;
      chat.open = false;
      chat.push();
      await tester.pump(ChatClient.pollIdle);
      expect(chat.syncs, greaterThan(syncs));
    });

    testWidgets('a cancelled answer says so, and gets no notice', (tester) async {
      chat = _FakeChat(history: [
        const ChatMessage(seq: 1, role: 'user', text: 'hi'),
        const ChatMessage(seq: 2, role: 'assistant', text: 'part', status: ChatMessage.statusCancelled, replyTo: 1),
      ])
        ..open = true;
      await open(tester);
      expect(find.byKey(const Key('chat-cancelled-2')), findsOneWidget);
      expect(find.byKey(const Key('chat-failed-2')), findsNothing);
      expect(find.text('part'), findsOneWidget);
      expect(chat.awaitingAnswer, isFalse);
    });
  });

  group('the keyboard of the system and the end of the list', () {
    List<ChatMessage> long() => [
          for (var i = 0; i < 40; i++)
            ChatMessage(seq: i, role: i.isEven ? 'user' : 'assistant', text: 'message $i'),
        ];

    /// The keyboard of the system opens: the window gets an inset at its foot.
    Future<void> openKeyboard(WidgetTester tester, double height) async {
      tester.view.viewInsets = FakeViewPadding(bottom: height * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
    }

    testWidgets('the input stays above the keyboard, and the last message stays in view', (
      tester,
    ) async {
      chat = _FakeChat(history: long());
      await open(tester);
      await tester.tap(find.byKey(const Key('chat-input')));
      await openKeyboard(tester, 300);
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final input = tester.getRect(find.byKey(const Key('chat-input-bar')));
      expect(input.bottom, lessThanOrEqualTo(screen - 300));
      final c = tester.widget<ListView>(find.byKey(const Key('chat-messages'))).controller!;
      expect(c.position.pixels, c.position.maxScrollExtent);
      expect(tester.getRect(find.text('message 39')).bottom, lessThanOrEqualTo(input.top));
    });

    testWidgets('a list that the user scrolled up stays where it is', (tester) async {
      chat = _FakeChat(history: long());
      await open(tester);
      await tester.drag(find.byKey(const Key('chat-messages')), const Offset(0, 400));
      await tester.pumpAndSettle();
      final c = tester.widget<ListView>(find.byKey(const Key('chat-messages'))).controller!;
      final before = c.position.pixels;
      expect(before, lessThan(c.position.maxScrollExtent - 80));
      await openKeyboard(tester, 300);
      expect(c.position.pixels, before);
    });
  });

  testWidgets('the time in a bubble of the user has the colour of its text', (tester) async {
    chat = _FakeChat(history: [
      ChatMessage(seq: 1, role: 'user', text: 'hi', createdAt: DateTime.now().millisecondsSinceEpoch),
      const ChatMessage(seq: 2, role: 'assistant', text: 'hello', replyTo: 1),
    ]);
    await open(tester);
    final scheme = Theme.of(tester.element(find.byKey(const Key('chat-time-1')))).colorScheme;
    final time = tester.widget<Text>(find.byKey(const Key('chat-time-1')));
    expect(time.style?.color, scheme.onPrimaryContainer);
  });

  group('the input', () {
    IconButton send(WidgetTester tester) => tester.widget<IconButton>(find.byKey(const Key('chat-send')));

    testWidgets('Send is off while there is nothing to send', (tester) async {
      await open(tester);
      expect(send(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('chat-input')), '  \n ');
      await tester.pump();
      expect(send(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('chat-input')), 'hi');
      await tester.pump();
      expect(send(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(chat.sent, ['hi']);
      // The input is empty again after the send.
      expect(send(tester).onPressed, isNull);
    });

    testWidgets('a file alone can be sent', (tester) async {
      chat.kinds = {'image'};
      pick = (_) async => [OutgoingAttachment(mime: 'image/png', bytes: Uint8List.fromList(png), name: 'a.png')];
      await open(tester);
      expect(send(tester).onPressed, isNull);
      await tester.tap(find.byKey(const Key('chat-attach')));
      await tester.pumpAndSettle();
      expect(send(tester).onPressed, isNotNull);
    });

    testWidgets('Enter makes a new line, and a sentence starts with a capital letter', (
      tester,
    ) async {
      await open(tester);
      final field = tester.widget<TextField>(find.byKey(const Key('chat-input')));
      expect(field.textInputAction, TextInputAction.newline);
      expect(field.keyboardType, TextInputType.multiline);
      expect(field.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('a fast stream of the input method, with composing words, is kept whole (#121)', (
      tester,
    ) async {
      await open(tester);
      await tester.showKeyboard(find.byKey(const Key('chat-input')));
      tester.testTextInput.log.clear();
      // As a keyboard of the system sends it when the user types fast: each word is composed
      // (underlined) letter by letter, then committed with a space. No frame between the
      // updates: they come faster than the screen.
      const words = ['typing', 'fast', 'keeps', 'every', 'key'];
      var done = '';
      for (final w in words) {
        for (var i = 1; i <= w.length; i++) {
          final text = done + w.substring(0, i);
          tester.testTextInput.updateEditingValue(TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange(start: done.length, end: text.length),
          ));
        }
        done = '$done$w ';
        tester.testTextInput.updateEditingValue(
          TextEditingValue(text: done, selection: TextSelection.collapsed(offset: done.length)),
        );
      }
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, done);
      expect(notes.draft(_echo.instanceId), done);
      // The screen never writes a value back to the input method: an older value sent back
      // would take the place of the keys typed after it.
      expect(
        tester.testTextInput.log.where((c) => c.method == 'TextInput.setEditingState'),
        isEmpty,
      );
    });

    testWidgets('the text that was not sent is there again when the chat opens again', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('chat-input')), 'half a thought');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(notes.draft(_echo.instanceId), 'half a thought');
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text,
          'half a thought');
      // The send takes the draft away.
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(chat.sent, ['half a thought']);
      expect(notes.draft(_echo.instanceId), isEmpty);
    });

    testWidgets('a stopped or deleted instance has no draft', (tester) async {
      final notes = ConversationNotes()
        ..setDraft('a', 'x')
        ..setDraft('b', 'y');
      notes.stopped('a');
      notes.remove('b');
      expect(notes.draft('a'), isEmpty);
      expect(notes.draft('b'), isEmpty);
    });
  });

  group('suggestions and corrector (chat.md, section 5.7)', () {
    const answer = ChatMessage(
      seq: 2,
      role: 'assistant',
      text: 'Do you want the keyboard of Lisbon?',
      replyTo: 1,
      suggestions: ['Yes, please', 'No'],
    );
    final history = [const ChatMessage(seq: 1, role: 'user', text: 'hello'), answer];

    setUp(() {
      chatPrefs.systemKeyboard = false;
      chatPrefs.wordSuggestions = true;
    });
    tearDown(() {
      chatPrefs.systemKeyboard = true;
      chatPrefs.wordSuggestions = true;
    });

    TextEditingController input(WidgetTester tester) =>
        tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!;

    Future<void> type(WidgetTester tester, String letters) async {
      for (final c in letters.split('')) {
        await tester.tap(find.byKey(Key(c == ' ' ? 'vk-space' : 'vk-char-$c')));
      }
      await tester.pump();
    }

    testWidgets('the suggestions of the service show above the keyboard; a tap puts one in the input', (tester) async {
      chat = _FakeChat(history: history);
      await open(tester);
      final bar = find.byKey(const Key('chat-suggestions'));
      expect(bar, findsOneWidget);
      expect(tester.getBottomLeft(bar).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('chat-virtual-keyboard'))).dy));
      expect(find.text('Yes, please'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-suggestion-0')));
      await tester.pump();
      expect(input(tester).text, 'Yes, please');
      // It does not send: the user sends.
      expect(chat.sent, isEmpty);
    });

    testWidgets('while the user writes a word, the chips are the words of the corrector', (tester) async {
      chat = _FakeChat(history: history);
      await open(tester);
      await type(tester, 'teh keyboa');
      expect(find.byKey(const Key('chat-suggestion-0')), findsNothing);
      // A completion: no correction.
      expect(find.text('keyboard'), findsOneWidget);
      await tester.tap(find.text('keyboard'));
      await tester.pump();
      expect(input(tester).text, 'Teh keyboard ');
      // After a space, the suggestions of the service again.
      expect(find.byKey(const Key('chat-suggestion-0')), findsOneWidget);

      // The cursor in the first word: a correction.
      input(tester).selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-word-0')));
      await tester.pump();
      expect(input(tester).text, 'The keyboard ');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(chat.sent.single, 'The keyboard');
      final report = chat.correctors.single!;
      expect(report.enabled, isTrue);
      expect(report.corrections, const [Correction('Teh', 'The')]);
    });

    testWidgets('with the setting off: no words of the corrector, and the send says it is off', (tester) async {
      chatPrefs.wordSuggestions = false;
      chat = _FakeChat(history: history);
      await open(tester);
      // The suggestions of the service still show.
      expect(find.byKey(const Key('chat-suggestion-0')), findsOneWidget);
      await type(tester, 'keyb');
      expect(find.byKey(const Key('chat-word-0')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(chat.correctors.single!.enabled, isFalse);
    });

    testWidgets('no suggestions and the setting off: no bar', (tester) async {
      chatPrefs.wordSuggestions = false;
      chat = _FakeChat(history: [
        const ChatMessage(seq: 1, role: 'user', text: 'hello'),
        const ChatMessage(seq: 2, role: 'assistant', text: 'hello', replyTo: 1),
      ]);
      await open(tester);
      expect(find.byKey(const Key('chat-suggestions')), findsNothing);
    });

    testWidgets('a message of the user after the answer makes its suggestions inactive', (tester) async {
      // An answer of the service first, so the last message of the user waits for nothing.
      chat = _FakeChat(history: [
        const ChatMessage(seq: 1, role: 'assistant', text: 'Hi'),
        const ChatMessage(seq: 2, role: 'user', text: 'hello'),
        const ChatMessage(seq: 3, role: 'assistant', text: 'Do you?', replyTo: 2, suggestions: ['Yes']),
        const ChatMessage(seq: 4, role: 'user', text: 'more'),
      ]);
      await open(tester);
      expect(chat.awaitingAnswer, isFalse);
      expect(find.byKey(const Key('chat-suggestion-0')), findsNothing);
    });

    testWidgets('with the keyboard of the system, only the suggestions of the service show', (tester) async {
      chatPrefs.systemKeyboard = true;
      chat = _FakeChat(history: history);
      await open(tester);
      expect(find.byKey(const Key('chat-suggestion-0')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), 'keyb');
      await tester.pump();
      expect(find.byKey(const Key('chat-word-0')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(chat.correctors.single!.enabled, isFalse);
    });

    testWidgets('a key with data-send sends no state of the corrector', (tester) async {
      chat = _FakeChat(history: [
        const ChatMessage(seq: 1, role: 'user', text: 'hello'),
        const ChatMessage(
          seq: 2,
          role: 'assistant',
          text: 'Go?\n```keyboard\n<button data-say="Yes" data-send>Yes</button>\n```',
          replyTo: 1,
          suggestions: ['No'],
        ),
      ]);
      await open(tester);
      // The form is under the input: no chips.
      expect(find.byKey(const Key('chat-suggestions')), findsNothing);
      await tester.tap(find.text('Yes').last);
      await tester.pumpAndSettle();
      expect(chat.sent.single, 'Yes');
      expect(chat.correctors.single, isNull);
    });
  });

  group('title of the service (chat.md, section 6.10)', () {
    String header(WidgetTester tester) => tester
        .widgetList<Text>(find.descendant(of: find.byKey(const Key('chat-title')), matching: find.byType(Text)))
        .first
        .data!;

    testWidgets('the title shows at the top, and goes to the database and the list', (tester) async {
      chat = _FakeChat();
      await open(tester);
      expect(header(tester), 'Echo chat');
      final revision = notes.titleRevision;

      chat
        ..fakeTitle = 'Trip to Lisbon'
        ..fakeTitleKnown = true
        ..push();
      await tester.pump();
      expect(header(tester), 'Trip to Lisbon');
      expect(savedTitles, [('i1', 'Trip to Lisbon')]);
      expect(notes.titleRevision, revision + 1);

      // The same title again: nothing to keep.
      chat.push();
      await tester.pump();
      expect(savedTitles, hasLength(1));

      // The service removes its title: the name of the start shows again.
      chat
        ..fakeTitle = null
        ..push();
      await tester.pump();
      expect(header(tester), 'Echo chat');
      expect(savedTitles.last, ('i1', ''));
    });

    testWidgets('a title known at the first read shows at once', (tester) async {
      chat = _FakeChat()
        ..fakeTitle = 'Notes'
        ..fakeTitleKnown = true;
      await open(tester);
      expect(header(tester), 'Notes');
      expect(savedTitles, [('i1', 'Notes')]);
    });

    testWidgets('the name of the user is stronger than the title of the service', (tester) async {
      chat = _FakeChat();
      await open(tester, instance: withAlias(_echo, 'Mine'));
      chat
        ..fakeTitle = 'Trip to Lisbon'
        ..fakeTitleKnown = true
        ..push();
      await tester.pump();
      expect(header(tester), 'Mine');
      // The app keeps the title for the time when the user removes the name.
      expect(savedTitles, [('i1', 'Trip to Lisbon')]);
    });
  });
}
