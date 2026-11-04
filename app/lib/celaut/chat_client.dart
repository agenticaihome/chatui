import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:protobuf/protobuf.dart' show GeneratedMessage;

import 'chat/gen/chat.pbgrpc.dart' as pb;
import 'chat_corrector.dart' show CorrectorReport;
import 'sha3.dart';

/// The description of one file of a message (`docs/celaut/chat.md`, section 5.1). The
/// bytes are not here: [ChatClient.readAttachment] reads them.
class ChatAttachment {
  const ChatAttachment({
    required this.kind,
    required this.mime,
    required this.size,
    this.name,
    this.hash,
  });

  /// The kinds of attachment that the convention defines.
  static const attachmentKinds = {'image', 'audio'};

  /// `image` or `audio`.
  final String kind;
  final String mime;
  final int size;
  final String? name;

  /// The SHA3-256 hash of the file, or null if the message gives none. Without it,
  /// [ChatClient.readAttachment] cannot read the file.
  final Uint8List? hash;

  bool get isImage => kind == 'image';
  bool get isAudio => kind == 'audio';

  /// [name] as a safe name for a file on this device, or null. The name comes from the
  /// service: only its last path segment stays, without control characters or `..`, and
  /// a name that is empty or longer than 100 characters is dropped.
  String? get safeName {
    final last = name?.split(RegExp(r'[\\/]')).last ?? '';
    final clean = last.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').replaceAll('..', '').trim();
    return clean.isEmpty || clean.length > 100 ? null : clean;
  }
}

/// A request of the service for a secret, by name (`docs/celaut/chat.md`, section 5.6).
/// The user answers it with a value or a skip ([ChatClient.answerSecretRequest]).
class ChatSecretRequest {
  const ChatSecretRequest({required this.requestId, required this.name, this.prose = ''});

  final String requestId;

  /// The name of the variable that the service asks for, for example `ANTHROPIC_API_KEY`.
  final String name;

  /// Why the service needs it. Empty if the service gave no text.
  final String prose;

  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _name = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,127}$');

  /// The request of [part], or null if a field breaks the rules of section 5.6: the client
  /// cannot answer it, so it does not show it.
  static ChatSecretRequest? of(pb.SecretRequest part) {
    if (!_id.hasMatch(part.requestId) || !_name.hasMatch(part.name)) return null;
    return ChatSecretRequest(
      requestId: part.requestId,
      name: part.name,
      prose: ChatClient._cutUtf8(part.prose, 1024),
    );
  }
}

/// A file that the user sends with a message.
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.mime,
    required this.bytes,
    this.name,
  });

  final String mime;
  final Uint8List bytes;
  final String? name;

  /// [mime] in lower case and without parameters, as the convention sends it.
  String get baseMime => mime.split(';').first.trim().toLowerCase();

  /// `image`, `audio`, or null for a media type that the convention does not define.
  String? get kind {
    final top = baseMime.split('/').first;
    return ChatAttachment.attachmentKinds.contains(top) ? top : null;
  }
}

/// One message of a conversation (`docs/celaut/chat.md`, section 5).
class ChatMessage {
  const ChatMessage({
    required this.seq,
    required this.role,
    required this.text,
    this.attachments = const [],
    this.status = statusDone,
    this.reasoning = '',
    this.replyTo,
    this.cid,
    this.pinned = false,
    this.id = '',
    this.updatedAt = 0,
    this.createdAt = 0,
    this.error,
    this.secretRequests = const [],
    this.suggestions = const [],
  });

  /// The values of [status] (`docs/celaut/chat.md`, section 5.2). `streaming` is a message
  /// that is `PENDING` or `IN_PROGRESS`.
  static const statusStreaming = 'streaming';
  static const statusDone = 'done';
  static const statusFailed = 'failed';
  static const statusCancelled = 'cancelled';

  /// The `sequence` of the message, from 1.
  final int seq;

  /// `user` or `assistant`.
  final String role;
  final String text;
  final List<ChatAttachment> attachments;

  /// `streaming` while the service still makes the answer, then `done`, `failed` or
  /// `cancelled`.
  final String status;

  /// The reasoning of the model, apart from [text]. Empty if the service gives none.
  final String reasoning;

  /// The `seq` of the user message that this message answers, if the service says it and
  /// the client knows that message.
  final int? replyTo;

  /// The `idempotency_key` of the send of a user message, if the service gives it.
  final String? cid;

  /// The message is pinned. Any message can be, and the user or the service can change it
  /// at any time. The client keeps the last pinned message at the top of the chat once the
  /// conversation grows past it.
  final bool pinned;

  /// The `message_id`. It is empty for a message that the service did not make.
  final String id;

  /// The time of the last change of [status] or [pinned], in milliseconds since 1970.
  final int updatedAt;

  /// The time when the service made the message (`created_at`), in milliseconds since 1970.
  /// Zero if the message has none, as a message that is still on its way.
  final int createdAt;

  /// The reason of a failure, for the user to read: the `error` of a `FAILED` message
  /// (section 5.2). Null if the service gave none. The client does not read the failure
  /// from [text] or from `metadata`.
  final String? error;

  /// The secrets that the service asks for in this message (section 5.6). Only a done
  /// assistant message has them.
  final List<ChatSecretRequest> secretRequests;

  /// Up to 3 short replies that the service proposes after this message (section 5.7). Only
  /// a done assistant message has them.
  final List<String> suggestions;

  bool get fromUser => role == 'user';

  /// An answer that grows: its [text] and [reasoning] are not final yet.
  bool get isOpen => status == statusStreaming;
  bool get isFailed => status == statusFailed;
  bool get isCancelled => status == statusCancelled;

  ChatMessage copyWith({
    String? text,
    String? status,
    String? reasoning,
    bool? pinned,
    int? updatedAt,
    String? error,
    List<String>? suggestions,
  }) =>
      ChatMessage(
        seq: seq,
        role: role,
        text: text ?? this.text,
        attachments: attachments,
        status: status ?? this.status,
        reasoning: reasoning ?? this.reasoning,
        replyTo: replyTo,
        cid: cid,
        pinned: pinned ?? this.pinned,
        id: id,
        updatedAt: updatedAt ?? this.updatedAt,
        createdAt: createdAt,
        error: error ?? this.error,
        secretRequests: secretRequests,
        suggestions: suggestions ?? this.suggestions,
      );
}

enum ChatErrorKind {
  /// The service did not answer, or the connection broke.
  unreachable,

  /// The answer of the service does not follow the convention.
  badAnswer,

  /// The service refused the request (`INVALID_ARGUMENT`, `NOT_FOUND`,
  /// `FAILED_PRECONDITION`), or the client refused to send it.
  badRequest,

  /// `RESOURCE_EXHAUSTED` with the reason `history_full`: the service cannot keep more
  /// messages.
  historyFull,

  /// `RESOURCE_EXHAUSTED` with the reason `storage_full`: the file store of the service
  /// cannot take the upload. The client does not send the file again by itself.
  storageFull,

  /// `UNAVAILABLE` with the reason `busy`: the service cannot keep one more message that
  /// waits. Try again later.
  busy,

  /// The service does not accept the kind of file: no attachment is sent.
  unsupportedMedia,

  /// Another status that the convention does not define.
  other,
}

class ChatException implements Exception {
  const ChatException(this.kind, {this.status, this.reason, this.message});

  final ChatErrorKind kind;

  /// The gRPC status code (`StatusCode`), if the error came from a call.
  final int? status;

  /// The `chat-reason` of the service, for example `busy`.
  final String? reason;

  /// The `message` of the service, for the user, if it sent one.
  final String? message;

  @override
  String toString() =>
      'ChatException($kind, status: $status, reason: $reason, message: $message)';
}

/// A gap in the numbers of the messages: the stream starts again from the last message.
class _Gap implements Exception {
  const _Gap();
}

/// The limits that `GetCapabilities` gives (`docs/celaut/chat.md`, section 6.7), with the
/// defaults of section 7 for each field that is 0.
class _Caps {
  _Caps(pb.Capabilities c)
      : mimeTypes = {
          for (final m in c.acceptedMimeTypes) m.split(';').first.trim().toLowerCase(),
        },
        maxFileBytes = c.maxFileBytes == Int64.ZERO
            ? ChatClient.maxAttachmentBytes
            : min(c.maxFileBytes.toInt(), ChatClient.maxAttachmentBytes),
        maxFiles = c.maxFilesPerMessage == 0
            ? ChatClient.maxAttachments
            : min(c.maxFilesPerMessage, ChatClient.maxAttachments),
        maxTextBytes = c.maxTextBytes == 0 ? ChatClient.defaultMaxTextBytes : c.maxTextBytes;

  final Set<String> mimeTypes;
  final int maxFileBytes;
  final int maxFiles;
  final int maxTextBytes;

  Set<String> get kinds => {
        for (final m in mimeTypes)
          if (ChatAttachment.attachmentKinds.contains(m.split('/').first)) m.split('/').first,
      };
}

class _PendingSend {
  _PendingSend(this.key) : done = Completer<ChatMessage>();

  final String key;
  final Completer<ChatMessage> done;
}

/// The client of the chat interface for one instance (`docs/celaut/chat.md`): gRPC over
/// HTTP/2 in clear text, on the local port of the tunnel of the node.
///
/// The service keeps the history. This object keeps a copy in memory only, and it
/// writes nothing to the Celaut database. [count] is the number of messages that the
/// client knows.
///
/// The client has one channel, which is one TCP connection and one tunnel stream, and
/// sends all its calls on it. [sync] reads the history, then opens the `Connect` stream.
/// While the stream is open ([streaming]), the events change [messages] and notify the
/// listeners: an answer that the service still makes is an open message
/// ([ChatMessage.isOpen]) that grows. While no stream is open, the owner calls [sync] to
/// read the history, every [pollWaiting] or [pollIdle].
class ChatClient extends ChangeNotifier {
  ChatClient({
    required this.port,
    this.reconnectWaits = startWaits,
    this.stableAfter = const Duration(seconds: 10),
    this.ackEvery = const Duration(seconds: 1),
    this.callTimeout = const Duration(seconds: 30),
    this.fileTimeout = const Duration(seconds: 120),
    Duration Function(Duration? last)? channelBackoff,
  }) : _backoff = channelBackoff ?? _defaultBackoff;

  /// The local port of the chat slot of the instance (`celautOpenTunnel`).
  final int port;

  /// The waits before each new try to open the stream (section 6.5). Tests make them short.
  final List<Duration> reconnectWaits;

  /// A stream that stayed open this long is not a failure: the next try has no wait.
  final Duration stableAfter;

  /// The least time between two `acknowledge` events.
  final Duration ackEvery;

  /// The deadline of a call that has no file stream, and of a call with files.
  final Duration callTimeout;
  final Duration fileTimeout;

  final Duration Function(Duration? last) _backoff;

  static Duration _defaultBackoff(Duration? last) =>
      last == null ? const Duration(seconds: 1) : Duration(seconds: min(last.inSeconds * 2, 10));

  /// The most files in one send, and the most bytes in one file
  /// (`docs/celaut/chat.md`, section 7).
  static const maxAttachments = 4;
  static const maxAttachmentBytes = 4 * 1024 * 1024;

  /// The most bytes of text in one message, if the service gives no other limit.
  static const defaultMaxTextBytes = 16384;

  /// The most bytes of a `SendMessageRequest`.
  static const maxRequestBytes = 128 * 1024;

  /// The most bytes of a message that the client accepts (section 4).
  static const maxMessageBytes = 4 * 1024 * 1024;

  /// The size of the chunks of an upload.
  static const chunkBytes = 64 * 1024;

  /// How often the client reads the conversation while it has no stream
  /// (`docs/celaut/chat.md`, section 10): while it waits for an answer, and otherwise.
  static const pollWaiting = Duration(seconds: 2);
  static const pollIdle = Duration(seconds: 10);

  /// The most bytes of files that stay in memory. Past it, the files of the other
  /// messages are dropped: the service gives them again.
  static const maxCachedBytes = 24 * 1024 * 1024;

  /// The waits between the tries to reach a service that starts, and between the tries to
  /// open the stream: they get longer, then stay at 10 seconds.
  static const startWaits = [
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 10),
  ];

  /// The type of a SHA3-256 `Hash`: the digest of an empty input (section 6.4).
  static final sha3Type = Uint8List.fromList([
    for (var i = 0; i < 64; i += 2)
      int.parse(
        'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a'.substring(i, i + 2),
        radix: 16,
      ),
  ]);

  ClientChannel? _channel;
  pb.ChatServiceClient? _chatStub;
  pb.FileServiceClient? _fileStub;

  ClientChannel get _ch => _channel ??= ClientChannel(
        '127.0.0.1',
        port: port,
        options: ChannelOptions(
          credentials: const ChannelCredentials.insecure(),
          // One connection for the whole session: each one costs a tunnel stream.
          idleTimeout: null,
          connectionTimeout: const Duration(days: 365),
          keepAlive: const ClientKeepAliveOptions(
            pingInterval: Duration(minutes: 5),
            permitWithoutCalls: false,
          ),
          codecRegistry: CodecRegistry(codecs: const [IdentityCodec()]),
          backoffStrategy: _backoff,
        ),
      );
  pb.ChatServiceClient get _chat => _chatStub ??= pb.ChatServiceClient(_ch);
  pb.FileServiceClient get _fileService => _fileStub ??= pb.FileServiceClient(_ch);

  final List<ChatMessage> _messages = [];

  /// The `sequence` of each `message_id` that the client has (section 5).
  final Map<String, int> _seqById = {};
  final Map<(int, int), Uint8List> _files = {};
  final Map<(int, int), Future<Uint8List>> _reading = {};
  _Caps? _caps;
  Future<void>? _syncing;
  bool _closed = false;
  bool _notifyScheduled = false;

  // The stream.
  Future<void>? _streamTask;
  bool _streamUnsupported = false;
  bool _streamReady = false;
  StreamController<pb.ClientEvent>? _out;
  final Completer<void> _closing = Completer<void>();
  final Map<String, _PendingSend> _pendingSends = {};
  int _eventCounter = 0;
  int _acked = 0;
  DateTime _lastAck = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _ackTimer;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  String? _title;
  bool _titleKnown = false;

  /// The title that the service gives the conversation (`docs/celaut/chat.md`, section
  /// 6.10), cleaned for display ([cleanTitle]). Null if it has none, or before
  /// [titleKnown].
  String? get title => _title;

  /// The client has read the title of the service: in `SubscriptionReady`, in an event, or
  /// with `GetConversation`. Before that, [title] says nothing.
  bool get titleKnown => _titleKnown;

  /// The most characters of a title that the app keeps and shows.
  static const titleMaxChars = 80;

  /// [raw] as a title to show (section 6.10): plain text in one line, with no control
  /// character and no character that changes the direction of the text, the white space
  /// made one space, and at most [titleMaxChars] characters. Null if nothing is left.
  static String? cleanTitle(String raw) {
    final text = raw
        .replaceAll(RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return null;
    final chars = text.characters;
    return chars.length <= titleMaxChars ? text : chars.take(titleMaxChars).toString().trimRight();
  }

  void _setTitle(String? raw) {
    final next = raw == null ? null : cleanTitle(raw);
    if (_titleKnown && next == _title) return;
    _titleKnown = true;
    _title = next;
    _notify();
  }

  /// Read the title with `GetConversation`, for a service that has no `Connect` stream. A
  /// failure keeps the title that the client has: the title is not needed for the chat.
  Future<void> _readTitle() async {
    try {
      final c = await _guard(
        () => _chat.getConversation(pb.GetConversationRequest(), options: _unaryOptions),
      );
      _setTitle(c.hasTitle() ? c.title : null);
    } on ChatException {
      // No title this time.
    }
  }

  /// The kinds of attachment (`image`, `audio`) that the service said it accepts in
  /// `GetCapabilities`. Empty: the service accepts text only, or the client did not read
  /// the capabilities yet.
  Set<String> get accepts => _caps?.kinds ?? const {};
  int get count => _messages.length;

  /// The `Connect` stream is open and its replay is done: the events keep [messages] up
  /// to date, and the owner need not read. False while no stream can be opened.
  bool get streaming => _streamReady;

  /// The client waits for an answer: a message is open, or there are more user messages
  /// than assistant messages (`docs/celaut/chat.md`, section 10).
  bool get awaitingAnswer {
    var users = 0;
    var replies = 0;
    for (final message in _messages) {
      if (message.isOpen) return true;
      message.fromUser ? users++ : replies++;
    }
    return users > replies;
  }

  /// Read the capabilities (once) and what is new in the conversation, put it in
  /// [messages], and open the `Connect` stream if it is not open. While the stream is
  /// open this does nothing: the events bring the news. Use it when the screen opens a
  /// running instance, and every [pollWaiting] or [pollIdle] while [streaming] is false.
  Future<void> sync() {
    if (_streamReady) return Future.value();
    return _syncing ??= _sync().whenComplete(() {
      _syncing = null;
    });
  }

  Future<void> _sync() async {
    await _ensureCaps();
    await _catchUp();
    // With a stream, the title comes in `SubscriptionReady` and in its events.
    if (_streamUnsupported) await _readTitle();
    _startStream();
  }

  /// [sync] for an instance that has just started. The service starts to listen some
  /// seconds after `StartService` (the echo service of M4: 18 to 60 seconds), and until
  /// then the node cannot connect the tunnel. So the client calls `GetCapabilities` again
  /// while the service is not reachable, with longer waits ([startWaits]), until it has
  /// waited [limit]. Then it throws `unreachable`. Each try can open one tunnel stream,
  /// and the node charges each one (`TUNNEL_OPEN_MU`).
  Future<void> syncWhenStarted({
    Duration limit = const Duration(minutes: 2),
    Future<void> Function(Duration wait)? wait,
  }) async {
    final pause = wait ?? (d) => Future<void>.delayed(d);
    var waited = Duration.zero;
    for (var i = 0;; i++) {
      try {
        await sync();
        return;
      } on ChatException catch (e) {
        if (e.kind != ChatErrorKind.unreachable || waited >= limit) rethrow;
      }
      final next = startWaits[i < startWaits.length ? i : startWaits.length - 1];
      await pause(next);
      waited += next;
    }
  }

  /// Close the stream and the connection for good: no call follows. The listeners get no
  /// more notices.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_closing.isCompleted) _closing.complete();
    _ackTimer?.cancel();
    for (final pending in _pendingSends.values) {
      if (!pending.done.isCompleted) {
        pending.done.completeError(const ChatException(ChatErrorKind.unreachable));
      }
    }
    _pendingSends.clear();
    await _closeSink(_out);
    await _channel?.terminate();
    super.dispose();
  }

  /// Close [sink], and do not wait for a listener that does not take the end.
  Future<void> _closeSink(StreamController<pb.ClientEvent>? sink) async {
    if (sink == null || sink.isClosed) return;
    try {
      await sink.close().timeout(const Duration(seconds: 1));
    } on Object {
      // The call is over, or does not take the end: cancel follows.
    }
  }

  void _notify() {
    if (_closed || _notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_closed) notifyListeners();
    });
  }

  // --- Errors --------------------------------------------------------------------------

  /// The kind of an error of the table in section 9, from its status and its reason.
  ///
  /// [sizeLimit] is true for a send and for a file call: `RESOURCE_EXHAUSTED` with no
  /// reason is the receive limit of the gRPC layer, and it counts as `too_large`
  /// (`badRequest`). For another call it is `other`.
  static ChatErrorKind _kind(int? code, String? reason, {bool sizeLimit = false}) {
    switch (reason) {
      case 'busy':
        return ChatErrorKind.busy;
      case 'history_full':
        return ChatErrorKind.historyFull;
      case 'storage_full':
        return ChatErrorKind.storageFull;
      case 'unsupported_media':
        return ChatErrorKind.unsupportedMedia;
      case 'bad_request' || 'too_large' || 'hash_mismatch' || 'not_found' || 'file_missing' ||
            'bad_state':
        return ChatErrorKind.badRequest;
      case 'service_error' || 'unimplemented':
        return ChatErrorKind.other;
    }
    return switch (code) {
      StatusCode.unavailable ||
      StatusCode.deadlineExceeded ||
      StatusCode.cancelled ||
      // A connection that drops ends the calls with this status in package:grpc.
      StatusCode.unknown =>
        ChatErrorKind.unreachable,
      StatusCode.invalidArgument ||
      StatusCode.notFound ||
      StatusCode.failedPrecondition =>
        ChatErrorKind.badRequest,
      StatusCode.resourceExhausted =>
        sizeLimit ? ChatErrorKind.badRequest : ChatErrorKind.other,
      _ => ChatErrorKind.other,
    };
  }

  static ChatException _toException(Object e, {bool sizeLimit = false}) {
    if (e is ChatException) return e;
    if (e is GrpcError) {
      var reason = e.trailers?['chat-reason'];
      if (reason != null && reason.isEmpty) reason = null;
      if (reason == null && sizeLimit && e.code == StatusCode.resourceExhausted) {
        reason = 'too_large';
      }
      return ChatException(
        _kind(e.code, reason, sizeLimit: sizeLimit),
        status: e.code,
        reason: reason,
        message: e.message,
      );
    }
    return const ChatException(ChatErrorKind.unreachable);
  }

  /// Run [call] and give its errors as [ChatException]. [sizeLimit] is true for a send and
  /// for a file call (see [_kind]).
  Future<T> _guard<T>(Future<T> Function() call, {bool sizeLimit = false}) async {
    try {
      return await call();
    } on ChatException {
      rethrow;
    } on Object catch (e) {
      throw _toException(e, sizeLimit: sizeLimit);
    }
  }

  CallOptions get _unaryOptions => CallOptions(timeout: callTimeout);
  CallOptions get _fileOptions => CallOptions(timeout: fileTimeout);

  void _checkSize(GeneratedMessage message) {
    if (message.writeToBuffer().length > maxMessageBytes) {
      throw const ChatException(ChatErrorKind.badAnswer);
    }
  }

  // --- Capabilities and history --------------------------------------------------------

  Future<_Caps> _ensureCaps() async {
    final kept = _caps;
    if (kept != null) return kept;
    final caps = await _guard(
      () => _chat.getCapabilities(pb.GetCapabilitiesRequest(), options: _unaryOptions),
    );
    return _caps ??= _Caps(caps);
  }

  /// The `sequence` after which the next read starts: before the first open message, or
  /// at the end.
  int get _readFrom {
    final open = _messages.indexWhere((m) => m.isOpen);
    return open < 0 ? _messages.length : open;
  }

  /// Read from [_readFrom] until a read has no message (a read can be shorter than the
  /// history: section 6.2). The client reads the whole history from `after_sequence` 0,
  /// and not the last messages only: the list of messages has no gap.
  Future<void> _catchUp() async {
    var after = _readFrom;
    while (true) {
      final got = await _guard(
        () => _chat
            .getMessages(pb.GetMessagesRequest(afterSequence: Int64(after)), options: _unaryOptions)
            .toList(),
      );
      if (got.isEmpty) return;
      var expected = after + 1;
      var applied = false;
      for (final raw in got) {
        _checkSize(raw);
        if (raw.conversationId.isNotEmpty) continue;
        if (raw.sequence.toInt() != expected) throw const ChatException(ChatErrorKind.badAnswer);
        expected++;
        applied = true;
        try {
          _apply(raw);
        } on _Gap {
          throw const ChatException(ChatErrorKind.badAnswer);
        }
      }
      // A read that has only messages of other conversations ends the loop.
      if (!applied) return;
      after = expected - 1;
      _notify();
    }
  }

  // --- Messages ------------------------------------------------------------------------

  static String _statusOf(pb.MessageStatus status) => switch (status) {
        pb.MessageStatus.MESSAGE_STATUS_PENDING ||
        pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS =>
          ChatMessage.statusStreaming,
        pb.MessageStatus.MESSAGE_STATUS_COMPLETED => ChatMessage.statusDone,
        pb.MessageStatus.MESSAGE_STATUS_FAILED => ChatMessage.statusFailed,
        pb.MessageStatus.MESSAGE_STATUS_CANCELLED => ChatMessage.statusCancelled,
        _ => throw const ChatException(ChatErrorKind.badAnswer),
      };

  Uint8List? _sha3Of(pb.FileReference file) {
    for (final hash in file.hashes) {
      if (listEquals(hash.type, sha3Type) && hash.value.length == 32) {
        return Uint8List.fromList(hash.value);
      }
    }
    return null;
  }

  ChatAttachment _attachment(String kind, pb.FileReference file) => ChatAttachment(
        kind: kind,
        mime: file.mimeType.split(';').first.trim().toLowerCase(),
        size: file.hasSizeBytes() ? file.sizeBytes.toInt() : 0,
        name: file.filename.isNotEmpty ? file.filename : null,
        hash: _sha3Of(file),
      );

  /// The message of the interface as a [ChatMessage]. A part that the client does not know
  /// is ignored.
  ChatMessage _convert(pb.Message m) {
    if (m.messageId.isEmpty || m.messageId.length > 128 || m.sequence.toInt() < 1) {
      throw const ChatException(ChatErrorKind.badAnswer);
    }
    final text = StringBuffer();
    final attachments = <ChatAttachment>[];
    final secrets = <ChatSecretRequest>[];
    for (final part in m.content) {
      switch (part.whichKind()) {
        case pb.ContentPart_Kind.text:
          text.write(part.text.text);
        case pb.ContentPart_Kind.image:
          attachments.add(_attachment('image', part.image.file));
        case pb.ContentPart_Kind.audio:
          attachments.add(_attachment('audio', part.audio.file));
        // Only a COMPLETED assistant message can ask (section 5.6); elsewhere it is ignored.
        case pb.ContentPart_Kind.secretRequest
            when m.fromService && m.status == pb.MessageStatus.MESSAGE_STATUS_COMPLETED:
          final request = ChatSecretRequest.of(part.secretRequest);
          if (request != null) secrets.add(request);
        default:
          break;
      }
    }
    // An empty string is the same as an absent optional field (section 5).
    final reply = m.replyToMessageId.isNotEmpty ? _seqById[m.replyToMessageId] : null;
    return ChatMessage(
      seq: m.sequence.toInt(),
      role: m.fromService ? 'assistant' : 'user',
      text: text.toString(),
      attachments: attachments,
      status: _statusOf(m.status),
      reasoning: m.reasoning,
      replyTo: reply,
      cid: m.idempotencyKey.isNotEmpty ? m.idempotencyKey : null,
      pinned: m.pinned,
      id: m.messageId,
      updatedAt: m.updatedAt.toInt(),
      createdAt: m.createdAt.toInt(),
      error: _errorOf(m.error),
      secretRequests: secrets,
      suggestions: m.fromService && m.status == pb.MessageStatus.MESSAGE_STATUS_COMPLETED
          ? suggestionsOf(m.suggestions)
          : const [],
    );
  }

  /// The most suggestions of a message, and the most characters of one (section 5.7).
  static const maxSuggestions = 3;
  static const maxSuggestionChars = 64;

  /// The suggestions of the service that the client shows: the first [maxSuggestions] of
  /// [raw] that are valid. One that is empty, longer than [maxSuggestionChars], or not in
  /// one line is ignored. White space at the ends goes, and a suggestion that is the same
  /// as an earlier one is ignored.
  static List<String> suggestionsOf(Iterable<String> raw) {
    final out = <String>[];
    for (final s in raw) {
      final t = s.trim();
      if (t.isEmpty || t.characters.length > maxSuggestionChars) continue;
      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(t) || out.contains(t)) continue;
      out.add(t);
      if (out.length == maxSuggestions) break;
    }
    return List.unmodifiable(out);
  }

  /// `error` of a message, or null if it is empty. At most 1 024 bytes are expected
  /// (section 5.2); a longer text is cut so that the screen stays small.
  static String? _errorOf(String error) => error.isEmpty ? null : _cutUtf8(error, 1024);

  /// [text] cut to [max] bytes of UTF-8, not inside a character.
  static String _cutUtf8(String text, int max) {
    final raw = utf8.encode(text);
    if (raw.length <= max) return text;
    var end = max;
    while (end > 0 && (raw[end] & 0xC0) == 0x80) {
      end--;
    }
    return utf8.decode(raw.sublist(0, end));
  }

  /// Add the message, or take the newer state of the message that the client has. The
  /// events and the reads can arrive in any order, so this is safe to repeat. A message
  /// that is past the end is a [_Gap].
  void _apply(pb.Message raw) {
    final incoming = _convert(raw);
    final index = incoming.seq - 1;
    if (index > _messages.length) throw const _Gap();
    if (index == _messages.length) {
      _messages.add(incoming);
      _seqById[incoming.id] = incoming.seq;
      return;
    }
    final have = _messages[index];
    if (have.id != incoming.id) throw const ChatException(ChatErrorKind.badAnswer);
    if (have.isOpen) {
      // A read can be older than the events that came since: keep the longer text.
      final older = incoming.isOpen &&
          incoming.text.length + incoming.reasoning.length < have.text.length + have.reasoning.length;
      if (!older) _messages[index] = _withNewerPin(incoming, have);
    } else if (!incoming.isOpen && incoming.updatedAt > have.updatedAt) {
      // A final message does not change, except for `pinned`.
      _messages[index] = have.copyWith(pinned: incoming.pinned, updatedAt: incoming.updatedAt);
    }
  }

  ChatMessage _withNewerPin(ChatMessage incoming, ChatMessage have) =>
      have.updatedAt > incoming.updatedAt
          ? incoming.copyWith(pinned: have.pinned, updatedAt: have.updatedAt)
          : incoming;

  ChatMessage? _byId(String id) {
    final seq = _seqById[id];
    return seq == null ? null : _messages[seq - 1];
  }

  void _onDelta(pb.MessageDelta d) {
    final have = _byId(d.messageId);
    if (have == null || !have.isOpen) return;
    if (d.textAppend.isEmpty && d.reasoningAppend.isEmpty) return;
    _messages[have.seq - 1] = have.copyWith(
      text: have.text + d.textAppend,
      reasoning: have.reasoning + d.reasoningAppend,
    );
  }

  void _onStatus(pb.MessageStatusChanged s) {
    final have = _byId(s.messageId);
    if (have == null || !have.isOpen) return;
    final status = _statusOf(s.status);
    _messages[have.seq - 1] = have.copyWith(
      status: status,
      updatedAt: s.updatedAt.toInt(),
      // The service sets `error` one time, with the status FAILED.
      error: status == ChatMessage.statusFailed ? _errorOf(s.error) : null,
      // And the suggestions one time, with the status COMPLETED (section 5.7).
      suggestions: status == ChatMessage.statusDone && !have.fromUser ? suggestionsOf(s.suggestions) : null,
    );
  }

  void _setLocalPinned(String id, bool pinned) {
    final have = _byId(id);
    if (have != null) _messages[have.seq - 1] = have.copyWith(pinned: pinned);
  }

  void _onPinned(String id, bool pinned, int updatedAt) {
    final have = _byId(id);
    if (have == null || updatedAt < have.updatedAt) return;
    _messages[have.seq - 1] = have.copyWith(pinned: pinned, updatedAt: updatedAt);
  }

  /// The highest `sequence` such that the client has all the messages up to it as final
  /// messages.
  int get _ackable {
    var n = 0;
    for (final m in _messages) {
      if (m.isOpen) break;
      n = m.seq;
    }
    return n;
  }

  // --- The stream ----------------------------------------------------------------------

  void _startStream() {
    if (_closed || _streamTask != null || _streamUnsupported || _streamStopped) return;
    _streamTask = _streamLoop().whenComplete(() {
      _streamTask = null;
    });
  }

  Future<void> _sleep(Duration wait) {
    if (wait == Duration.zero) return Future.value();
    final timer = Completer<void>();
    final t = Timer(wait, timer.complete);
    return Future.any([timer.future, _closing.future]).whenComplete(t.cancel);
  }

  /// The error that stopped the stream for good (3 failures of the first event in a row,
  /// section 6.5), or null. The owner shows it like the error of a read. The client then
  /// opens no more streams; the owner can read with [sync].
  ChatException? get streamError => _streamError;
  ChatException? _streamError;
  bool _streamStopped = false;

  /// The failures in a row of the first event, and the number of them that stop the stream.
  static const maxFirstEventFailures = 3;

  /// Open the stream, and open it again after it ends (section 6.5).
  Future<void> _streamLoop() async {
    var attempt = 0;
    var failures = 0;
    var resynced = false;
    while (!_closed) {
      final started = DateTime.now();
      final afterUsed = _subscribeAfter;
      Object? failure;
      try {
        await _runStream();
      } on Object catch (e) {
        failure = e;
      }
      final ready = _readyInRun;
      _streamReady = false;
      _notify();
      if (_closed) return;
      if (failure is GrpcError && failure.code == StatusCode.unimplemented) {
        _streamUnsupported = true;
        return;
      }
      final error = failure == null ? null : _toException(failure);
      // `UNAVAILABLE` with the reason `busy` (the queue of the stream was full) is not an
      // error for the user: wait at least the first wait, also after a long stream, and
      // subscribe again from the last message that the client has.
      final busy = error?.kind == ChatErrorKind.busy;
      if (ready) {
        failures = 0;
        resynced = false;
      }
      if (!ready && !busy) {
        // The first event failed (or the stream broke before `SubscriptionReady`).
        if (error?.reason == 'bad_request' &&
            failure is GrpcError &&
            afterUsed > 0 &&
            !resynced) {
          // The local copy can be ahead of the service: read it all again, once.
          resynced = true;
          _dropLocalCopy();
          try {
            await _catchUp();
            continue;
          } on Object catch (e) {
            if (_closed) return;
            failure = e;
          }
        }
        if (++failures >= maxFirstEventFailures) {
          _streamError = failure == null
              ? const ChatException(ChatErrorKind.unreachable)
              : _toException(failure);
          _streamStopped = true;
          _notify();
          return;
        }
      }
      final stable = DateTime.now().difference(started) >= stableAfter;
      if (stable && !busy) {
        attempt = 0;
      } else {
        if (stable) attempt = 0;
        await _sleep(reconnectWaits[min(attempt, reconnectWaits.length - 1)]);
        attempt++;
      }
    }
  }

  /// Forget the messages that the client has, to read them again from `after_sequence` 0.
  void _dropLocalCopy() {
    _messages.clear();
    _seqById.clear();
    _files.clear();
    _acked = 0;
    _notify();
  }

  /// `SubscriptionReady` came in the stream that runs or ran last.
  bool _readyInRun = false;

  String _nextEventId() => 'e${_eventCounter++}';

  /// `after_sequence` of a new stream: before the first open message, or the last message.
  int get _subscribeAfter => _readFrom;

  Future<void> _runStream() async {
    final out = StreamController<pb.ClientEvent>();
    _out = out;
    _acked = 0;
    _readyInRun = false;
    _lastAck = DateTime.fromMillisecondsSinceEpoch(0);
    final done = Completer<void>();
    var mine = false;
    final call = _chat.connect(out.stream);
    final sub = call.listen(
      (event) {
        try {
          _onServerEvent(event);
        } on Object catch (e) {
          if (!done.isCompleted) done.completeError(e);
        }
      },
      onError: (Object e) {
        // `cancel` of the call puts CANCELLED in the stream: it is not an error here.
        if (mine && e is GrpcError && e.code == StatusCode.cancelled) return;
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    out.add(
      pb.ClientEvent(
        eventId: _nextEventId(),
        subscribe: pb.SubscribeRequest(afterSequence: Int64(_subscribeAfter)),
      ),
    );
    unawaited(_closing.future.then((_) {
      if (!done.isCompleted) done.complete();
    }));
    try {
      await done.future;
    } finally {
      mine = true;
      _streamReady = false;
      _out = null;
      _ackTimer?.cancel();
      _ackTimer = null;
      // A send over the stream that has no reply now: the client follows section 6.3.
      for (final pending in _pendingSends.values) {
        if (!pending.done.isCompleted) {
          pending.done.completeError(const ChatException(ChatErrorKind.unreachable));
        }
      }
      _pendingSends.clear();
      // End our side first, then drop the call: the other order lets package:grpc add an
      // event to a stream that it closed.
      await _closeSink(out);
      await sub.cancel();
      await call.cancel().catchError((_) {});
    }
  }

  bool _foreign(String conversationId) => conversationId.isNotEmpty;

  void _onServerEvent(pb.ServerEvent e) {
    switch (e.whichEvent()) {
      case pb.ServerEvent_Event.messageCreated:
        final raw = e.messageCreated.message;
        _checkSize(raw);
        if (_foreign(raw.conversationId)) return;
        _apply(raw);
        if (raw.idempotencyKey.isNotEmpty) {
          final pending = _pendingSends[_pendingKeyToEvent(raw.idempotencyKey)];
          final message = _byId(raw.messageId);
          if (pending != null && message != null && !pending.done.isCompleted) {
            pending.done.complete(message);
          }
        }
      case pb.ServerEvent_Event.messageDelta:
        if (_foreign(e.messageDelta.conversationId)) {
          return;
        }
        _onDelta(e.messageDelta);
      case pb.ServerEvent_Event.messageStatusChanged:
        final s = e.messageStatusChanged;
        if (_foreign(s.conversationId)) return;
        _onStatus(s);
      case pb.ServerEvent_Event.messagePinnedChanged:
        final p = e.messagePinnedChanged;
        if (_foreign(p.conversationId)) return;
        _onPinned(p.messageId, p.pinned, p.updatedAt.toInt());
      case pb.ServerEvent_Event.subscriptionReady:
        _streamReady = true;
        _readyInRun = true;
        final ready = e.subscriptionReady;
        _setTitle(ready.hasTitle() ? ready.title : null);
      case pb.ServerEvent_Event.conversationTitleChanged:
        final t = e.conversationTitleChanged;
        if (_foreign(t.conversationId)) return;
        _setTitle(t.hasTitle() ? t.title : null);
      case pb.ServerEvent_Event.error:
        final err = e.error;
        // An empty `event_id` is no `event_id`: the error is not for an event that the
        // client can name (a bad or repeated id, section 6.5), so it matches no send.
        final pending = err.eventId.isNotEmpty ? _pendingSends.remove(err.eventId) : null;
        if (pending != null && !pending.done.isCompleted) {
          pending.done.completeError(
            ChatException(
              _kind(null, err.code, sizeLimit: true),
              reason: err.code,
              message: err.message,
            ),
          );
        } else if (!_streamReady && err.eventId.isEmpty) {
          // A failure of the first event that comes as an event: the stream is no good.
          throw ChatException(_kind(null, err.code), reason: err.code, message: err.message);
        } else if (err.eventId.isEmpty) {
          // After `SubscriptionReady`, and not the answer to a send: ignore it, no resync.
          debugPrint('chat: ProtocolError with no event_id: ${err.code} ${err.message}');
        }
      default:
        break;
    }
    _notify();
    _maybeAck();
  }

  String _pendingKeyToEvent(String key) {
    for (final entry in _pendingSends.entries) {
      if (entry.value.key == key) return entry.key;
    }
    return '';
  }

  /// Tell the service which messages are final (section 6.5): at most once each second,
  /// and only when the value rises.
  void _maybeAck() {
    final out = _out;
    if (!_streamReady || out == null) return;
    final value = _ackable;
    if (value <= _acked) return;
    final wait = _lastAck.add(ackEvery).difference(DateTime.now());
    if (wait > Duration.zero) {
      _ackTimer ??= Timer(wait, () {
        _ackTimer = null;
        _maybeAck();
      });
      return;
    }
    _acked = value;
    _lastAck = DateTime.now();
    out.add(
      pb.ClientEvent(
        eventId: _nextEventId(),
        acknowledge: pb.AcknowledgeEvent(lastSequence: Int64(value)),
      ),
    );
  }

  // --- Send ----------------------------------------------------------------------------

  /// Send [text] and add the user message to [messages]. It does not wait for the answer:
  /// the answer comes with the events of the stream, or with [sync].
  ///
  /// Each send has its own `idempotency_key`. The client sends over the `Connect` stream
  /// when it is open, and with `SendMessage` when it is not. If the connection breaks, the
  /// client reads the history first. If the message is in it, the send worked. If not,
  /// the client sends the same request again once, with the same key, so the service
  /// cannot add it twice (`docs/celaut/chat.md`, section 6.3).
  ///
  /// [attachments] are sent only if the service accepts their media types ([accepts]). A
  /// send with files and no text is valid.
  ///
  /// [corrector] is the state of the corrector of the keyboard while the user wrote [text]
  /// (section 5.7). It is null for a text that the user did not write.
  Future<void> send(
    String text, {
    List<OutgoingAttachment> attachments = const [],
    CorrectorReport? corrector,
  }) async {
    final caps = await _ensureCaps();
    _checkSend(caps, text, attachments);
    final key = _newCid();
    final hashes = [for (final f in attachments) sha3_256(f.bytes)];
    if (attachments.isNotEmpty) await _uploadMissing(attachments, hashes, onlyMissing: true);
    final request = pb.SendMessageRequest(
      content: [
        if (text.isNotEmpty) pb.ContentPart(text: pb.TextContent(text: text)),
        for (var i = 0; i < attachments.length; i++) _part(attachments[i], hashes[i]),
      ],
      idempotencyKey: key,
      corrector: corrector == null
          ? null
          : pb.CorrectorState(
              enabled: corrector.enabled,
              corrections: [
                for (final c in corrector.corrections)
                  pb.Correction(original: c.original, replacement: c.replacement),
              ],
            ),
    );
    if (request.writeToBuffer().length > maxRequestBytes) {
      throw const ChatException(ChatErrorKind.badRequest);
    }
    ChatMessage sent;
    try {
      sent = await _sendWithRecovery(request, key);
    } on ChatException catch (e) {
      if (e.reason != 'file_missing') rethrow;
      // The service lost a file: upload the files again, and send once more.
      await _uploadMissing(attachments, hashes, onlyMissing: false);
      sent = await _sendWithRecovery(request, key);
    }
    _keepFiles(sent.seq, attachments);
  }

  Future<ChatMessage> _sendWithRecovery(pb.SendMessageRequest request, String key) async {
    try {
      return await _sendOnce(request, key);
    } on ChatException catch (e) {
      if (e.kind != ChatErrorKind.unreachable) rethrow;
    }
    // The client does not know if the service got the message: read the history.
    final found = await _recovered(key);
    if (found != null) return found;
    return _sendOnce(request, key);
  }

  Future<ChatMessage> _sendOnce(pb.SendMessageRequest request, String key) async {
    final out = _out;
    if (_streamReady && out != null) {
      final id = _nextEventId();
      final pending = _pendingSends[id] = _PendingSend(key);
      out.add(pb.ClientEvent(eventId: id, sendMessage: request));
      try {
        return await pending.done.future.timeout(
          callTimeout,
          onTimeout: () => throw const ChatException(ChatErrorKind.unreachable),
        );
      } finally {
        _pendingSends.remove(id);
      }
    }
    final raw = await _guard(
      () => _chat.sendMessage(request, options: _unaryOptions),
      sizeLimit: true,
    );
    _checkSize(raw);
    final index = raw.sequence.toInt() - 1;
    try {
      _apply(raw);
    } on _Gap {
      // The service added answers since the last read: read the gap.
      await _catchUp();
    }
    final message = index >= 0 && index < _messages.length ? _messages[index] : null;
    if (message == null || message.id != raw.messageId) {
      throw const ChatException(ChatErrorKind.badAnswer);
    }
    _notify();
    return message;
  }

  /// Read the history, and give the user message with [key] if it is in it. A read that
  /// fails counts as "no": the caller sends again, and that fails too if the service is
  /// gone.
  Future<ChatMessage?> _recovered(String key) async {
    try {
      await _catchUp();
    } on Object {
      return null;
    }
    for (final message in _messages) {
      if (message.fromUser && message.cid == key) return message;
    }
    return null;
  }

  /// Check the limits of `docs/celaut/chat.md` (sections 6.1, 6.7 and 10) before anything
  /// goes to the service.
  void _checkSend(_Caps caps, String text, List<OutgoingAttachment> attachments) {
    if (text.isEmpty && attachments.isEmpty) {
      throw const ChatException(ChatErrorKind.badRequest);
    }
    if (utf8.encode(text).length > caps.maxTextBytes) {
      throw const ChatException(ChatErrorKind.badRequest);
    }
    if (attachments.isEmpty) return;
    if (attachments.length > caps.maxFiles) {
      throw const ChatException(ChatErrorKind.badRequest);
    }
    for (final file in attachments) {
      if (file.kind == null ||
          !_sendableMimes.contains(file.baseMime) ||
          !caps.mimeTypes.contains(file.baseMime)) {
        throw const ChatException(ChatErrorKind.unsupportedMedia);
      }
      if (file.bytes.isEmpty || file.bytes.length > caps.maxFileBytes) {
        throw const ChatException(ChatErrorKind.badRequest);
      }
    }
  }

  /// The media types that the client sends (section 5.1).
  static const _sendableMimes = {'image/jpeg', 'image/png', 'audio/mpeg', 'audio/wav'};

  pb.FileReference _reference(OutgoingAttachment file, Uint8List hash) => pb.FileReference(
        hashes: [pb.Hash(type: sha3Type, value: hash)],
        mimeType: file.baseMime,
        sizeBytes: Int64(file.bytes.length),
        // An empty name is the same as no name: the client sends none.
        filename: file.name == null || file.name!.isEmpty ? null : file.name,
      );

  pb.ContentPart _part(OutgoingAttachment file, Uint8List hash) => file.kind == 'image'
      ? pb.ContentPart(image: pb.ImageContent(file: _reference(file, hash)))
      : pb.ContentPart(audio: pb.AudioContent(file: _reference(file, hash)));

  /// A name for a send: 22 characters from the set that the convention allows.
  static String _newCid() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final random = Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < 22; i++) chars.codeUnitAt(random.nextInt(chars.length)),
    ]);
  }

  // --- Files ---------------------------------------------------------------------------

  /// Ask `QueryFiles` which files the service has (one call for all the hashes), and
  /// upload the others. With [onlyMissing] false, upload all of them.
  Future<void> _uploadMissing(
    List<OutgoingAttachment> files,
    List<Uint8List> hashes, {
    required bool onlyMissing,
  }) async {
    var missing = [for (var i = 0; i < files.length; i++) i];
    if (onlyMissing) {
      final answers = await _guard(
        () => _fileService
            .queryFiles(
              Stream.fromIterable([
                for (final h in hashes) pb.QueryFilesRequest(hash: pb.Hash(type: sha3Type, value: h)),
              ]),
              options: _unaryOptions,
            )
            .toList(),
        sizeLimit: true,
      );
      if (answers.length != files.length) throw const ChatException(ChatErrorKind.badAnswer);
      missing = [
        for (var i = 0; i < files.length; i++)
          if (!answers[i].available) i,
      ];
    }
    for (final i in missing) {
      await _guard(
        () => _fileService.uploadFile(_uploadStream(files[i], hashes[i]), options: _fileOptions),
        sizeLimit: true,
      );
    }
  }

  Stream<pb.UploadFileRequest> _uploadStream(OutgoingAttachment file, Uint8List hash) async* {
    yield pb.UploadFileRequest(file: _reference(file, hash));
    for (var i = 0; i < file.bytes.length; i += chunkBytes) {
      yield pb.UploadFileRequest(
        chunk: Uint8List.sublistView(file.bytes, i, min(i + chunkBytes, file.bytes.length)),
      );
    }
  }

  /// The user message of a send is at [seq]: keep the bytes that the client has, so that
  /// the screen does not read them back.
  void _keepFiles(int seq, List<OutgoingAttachment> attachments) {
    for (var i = 0; i < attachments.length; i++) {
      _remember(seq, i, attachments[i].bytes);
    }
  }

  void _remember(int seq, int index, Uint8List bytes) {
    _files[(seq, index)] = bytes;
    var total = 0;
    for (final file in _files.values) {
      total += file.length;
    }
    if (total > maxCachedBytes) _files.removeWhere((key, _) => key.$1 != seq);
  }

  /// The bytes of attachment [index] of message [seq]. A file that this client sent is
  /// already in memory; the others are read from the service with `DownloadFile`
  /// (`docs/celaut/chat.md`, section 6.4) once, and the client checks their hash. They are
  /// kept in memory only.
  Future<Uint8List> readAttachment(int seq, int index) {
    final early = _files[(seq, index)];
    if (early != null) return Future.value(early);
    return _reading[(seq, index)] ??= _read(seq, index).whenComplete(() {
      _reading.remove((seq, index));
    });
  }

  Future<Uint8List> _read(int seq, int index) async {
    final message = seq >= 1 && seq <= _messages.length ? _messages[seq - 1] : null;
    if (message == null || index < 0 || index >= message.attachments.length) {
      throw const ChatException(ChatErrorKind.badRequest);
    }
    final file = message.attachments[index];
    final hash = file.hash;
    if (hash == null || file.size > maxCachedBytes) {
      throw const ChatException(ChatErrorKind.badAnswer);
    }
    final bytes = await _guard(() async {
      final builder = BytesBuilder(copy: false);
      final call = _fileService.downloadFile(
        pb.DownloadFileRequest(hash: pb.Hash(type: sha3Type, value: hash)),
        options: _fileOptions,
      );
      await for (final part in call) {
        builder.add(part.chunk);
        if (builder.length > file.size) {
          unawaited(call.cancel().catchError((_) {}));
          throw const ChatException(ChatErrorKind.badAnswer);
        }
      }
      return builder.takeBytes();
    }, sizeLimit: true);
    if (bytes.length != file.size || !listEquals(sha3_256(bytes), hash)) {
      throw const ChatException(ChatErrorKind.badAnswer);
    }
    _remember(seq, index, bytes);
    return bytes;
  }

  // --- Pinned messages -----------------------------------------------------------------

  bool _pinSupported = true;

  /// The service takes `SetMessagePinned`. Section 6.6 says that a service must, but one
  /// that ends the call with `UNIMPLEMENTED` is not asked again while this client lives.
  bool get canPin => _pinSupported;

  /// Pin or unpin [message] (`SetMessagePinned`, section 6.6). The user can do it for any
  /// message. The message changes at once. If the call fails, the message gets its old
  /// value back, and the error goes to the caller. The service sends `MessagePinnedChanged`
  /// to the stream too.
  Future<void> setPinned(ChatMessage message, bool pinned) async {
    if (!_pinSupported) throw const ChatException(ChatErrorKind.other, status: StatusCode.unimplemented);
    final before = _byId(message.id)?.pinned;
    if (before != null && before != pinned) {
      _setLocalPinned(message.id, pinned);
      _notify();
    }
    final pb.Message raw;
    try {
      raw = await _guard(
        () => _chat.setMessagePinned(
          pb.SetMessagePinnedRequest(messageId: message.id, pinned: pinned),
          options: _unaryOptions,
        ),
      );
    } on ChatException catch (e) {
      if (e.status == StatusCode.unimplemented) _pinSupported = false;
      // A change that the stream brought meanwhile stays.
      if (before != null && _byId(message.id)?.pinned == pinned) _setLocalPinned(message.id, before);
      _notify();
      rethrow;
    }
    _onPinned(raw.messageId, raw.pinned, raw.updatedAt.toInt());
    _notify();
  }

  /// The most bytes of the value of a secret (section 6.9).
  static const maxSecretBytes = 8192;

  /// Answer the secret [request] of [message] (`AnswerSecretRequest`, section 6.9): with
  /// [value], or with a skip if [value] is null. The value goes only in this call: it is not
  /// kept, and it is never in a message, a log or the text of an error. The client does not
  /// send the answer again by itself; the caller tells the user if it fails.
  Future<void> answerSecretRequest(ChatMessage message, ChatSecretRequest request, {String? value}) async {
    if (value != null &&
        (value.isEmpty || value.contains('\u0000') || utf8.encode(value).length > maxSecretBytes)) {
      throw const ChatException(ChatErrorKind.badRequest);
    }
    final call = pb.AnswerSecretRequestRequest(messageId: message.id, requestId: request.requestId);
    if (value != null) {
      call.value = value;
    } else {
      call.skipped = true;
    }
    await _guard(() => _chat.answerSecretRequest(call, options: _unaryOptions));
  }
}
