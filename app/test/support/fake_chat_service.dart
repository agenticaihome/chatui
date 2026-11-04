import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:argus_wallet/celaut/chat/gen/chat.pbgrpc.dart';
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/sha3.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:grpc/grpc.dart';

/// The `chat-reason` trailer of `docs/celaut/chat.md`, section 9.
GrpcError chatError(int code, String reason, [String message = 'error']) =>
    GrpcError.custom(code, message, null, null, {'chat-reason': reason});

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// A chat service in memory that follows `docs/celaut/chat.md` (revision 6), with switches
/// to break it. It serves `ChatService` and `FileService` of `chat.proto` over h2c.
class FakeChatService {
  Capabilities caps = Capabilities(acceptedMimeTypes: ['image/jpeg', 'image/png', 'audio/wav']);

  final msgs = <Message>[];
  int _clock = 1000;

  /// What the service got.
  final unarySends = <SendMessageRequest>[];
  final streamEvents = <ClientEvent>[];
  final reads = <int>[];
  final subscribes = <int>[];
  int capabilityCalls = 0;
  int connects = 0;
  int pinCalls = 0;

  /// The next calls to `SetMessagePinned` fail with these errors, in order.
  final pinErrors = <GrpcError>[];

  /// The answers to secret requests that the service took (section 6.9).
  final secretAnswers = <AnswerSecretRequestRequest>[];

  /// The next calls to `AnswerSecretRequest` fail with these errors, in order.
  final secretErrors = <GrpcError>[];

  /// The title of the conversation (`docs/celaut/chat.md`, section 6.10), or null.
  String? title;
  int conversationCalls = 0;

  /// The service gives the conversation a new title, or removes it ([value] null): each
  /// open stream gets `ConversationTitleChanged`.
  void setTitle(String? value) {
    title = value;
    emit(ServerEvent(
      conversationTitleChanged: ConversationTitleChanged(
        title: value,
        updatedAt: Int64(_clock++),
      ),
    ));
  }

  /// Each user message gets a whole answer `echo: <text>` at once.
  bool autoAnswer = false;

  /// The most messages in the answer to one read, or null for all.
  int? readLimit;

  /// The next calls to `SendMessage` fail with these errors, in order, and add nothing.
  final sendErrors = <GrpcError>[];

  /// The next call to `SendMessage` adds the message and then fails with this error.
  GrpcError? failAfterApply;

  /// The next `Connect` calls end with this status.
  GrpcError? connectError;

  /// The next `Connect` calls end with these statuses, in order, one for each call.
  final connectErrors = <GrpcError>[];

  /// The next `Connect` streams send a `ProtocolError` with no `event_id` before the
  /// replay, this many times.
  int protocolErrorsBeforeReady = 0;

  /// Runs when a `send_message` event came over `Connect` and the message was added.
  void Function()? onStreamSend;

  /// `GetMessages` gives a gap: the first message has this `sequence` plus one.
  bool gapInReads = false;

  /// A `SendMessage` of this kind fails with `file_missing` while the file is not uploaded.
  bool requireFiles = true;
  int fileMissingTimes = 0;

  final files = <String, Uint8List>{};
  final uploads = <FileReference>[];
  final queries = <List<String>>[];
  final chunkSizes = <int>[];
  int downloads = 0;

  /// [DownloadFile] gives these bytes instead of the file.
  Uint8List? downloadOverride;
  GrpcError? uploadError;

  /// The file store is full: an upload that passed the other checks ends with
  /// `storage_full`.
  bool storageFull = false;

  final _streams = <StreamController<ServerEvent>>[];

  Message user(String text, {String? key, List<ContentPart> extra = const []}) {
    final m = Message(
      messageId: 'm${msgs.length + 1}',
      sequence: Int64(msgs.length + 1),
      content: [if (text.isNotEmpty) ContentPart(text: TextContent(text: text)), ...extra],
      status: MessageStatus.MESSAGE_STATUS_COMPLETED,
      createdAt: Int64(_clock),
      updatedAt: Int64(_clock++),
      idempotencyKey: key,
    );
    msgs.add(m);
    return m;
  }

  Message assistant(
    String text, {
    String? replyTo,
    MessageStatus status = MessageStatus.MESSAGE_STATUS_COMPLETED,
    String reasoning = '',
    bool pinned = false,
    String? error,
    List<ContentPart> extra = const [],
    List<String> suggestions = const [],
  }) {
    final m = Message(
      messageId: 'm${msgs.length + 1}',
      sequence: Int64(msgs.length + 1),
      content: [if (text.isNotEmpty) ContentPart(text: TextContent(text: text)), ...extra],
      status: status,
      createdAt: Int64(_clock),
      updatedAt: Int64(_clock++),
      fromService: true,
      reasoning: reasoning,
      pinned: pinned,
      replyToMessageId: replyTo,
      error: error,
      suggestions: suggestions,
    );
    msgs.add(m);
    return m;
  }

  Message byId(String id) => msgs.firstWhere((m) => m.messageId == id);

  /// The most events in the queue of a stream that the client does not read (section 6.5):
  /// 1 000 or more. With [stallQueues] the fake counts each event of a stream as queued
  /// (no client reads), and it ends the stream with `busy` when the count is above the limit.
  int queueLimit = 1000;
  bool stallQueues = false;
  final _queued = <StreamController<ServerEvent>, int>{};

  void emit(ServerEvent e) {
    for (final s in List.of(_streams)) {
      s.add(e);
      if (stallQueues) {
        final n = (_queued[s] ?? 0) + 1;
        _queued[s] = n;
        if (n > queueLimit) {
          s
            ..addError(chatError(StatusCode.unavailable, 'busy'))
            ..close();
          _streams.remove(s);
        }
      }
    }
  }

  void emitCreated(Message m) => emit(ServerEvent(messageCreated: MessageCreated(message: m)));

  void emitDelta(String id, {String text = '', String reasoning = ''}) {
    final m = byId(id);
    if (text.isNotEmpty) {
      if (m.content.isNotEmpty && m.content.last.hasText()) {
        m.content.last.text.text += text;
      } else {
        m.content.add(ContentPart(text: TextContent(text: text)));
      }
    }
    m.reasoning += reasoning;
    emit(ServerEvent(
      messageDelta: MessageDelta(messageId: id, textAppend: text, reasoningAppend: reasoning),
    ));
  }

  /// Change the status of an open message and send `MessageStatusChanged`. A final message
  /// does not change, and `PENDING` to `IN_PROGRESS` exists only for a message that was
  /// `PENDING` (section 5.2). `error` is for `FAILED`, and the service sets it one time.
  void setStatus(String id, MessageStatus status, {String? error, List<String> suggestions = const []}) {
    final m = byId(id);
    final open = m.status == MessageStatus.MESSAGE_STATUS_PENDING ||
        m.status == MessageStatus.MESSAGE_STATUS_IN_PROGRESS;
    if (!open) throw StateError('A final message does not change.');
    if (status == MessageStatus.MESSAGE_STATUS_IN_PROGRESS &&
        m.status != MessageStatus.MESSAGE_STATUS_PENDING) {
      throw StateError('There is no change to IN_PROGRESS for a message that is not PENDING.');
    }
    if (error != null && status != MessageStatus.MESSAGE_STATUS_FAILED) {
      throw StateError('Only a FAILED message has an error.');
    }
    m
      ..status = status
      ..updatedAt = Int64(_clock++);
    if (error != null && error.isNotEmpty) m.error = error;
    // The suggestions come one time, with COMPLETED (section 5.7).
    if (status == MessageStatus.MESSAGE_STATUS_COMPLETED) m.suggestions.addAll(suggestions);
    emit(ServerEvent(
      messageStatusChanged: MessageStatusChanged(
        messageId: id,
        status: status,
        updatedAt: m.updatedAt,
        error: error != null && error.isNotEmpty ? error : null,
        suggestions: status == MessageStatus.MESSAGE_STATUS_COMPLETED ? suggestions : null,
      ),
    ));
  }

  /// Every open stream ends with `UNAVAILABLE`, reason `busy`: its queue was full
  /// (section 6.5).
  void closeStreamsBusy() {
    for (final s in List.of(_streams)) {
      s
        ..addError(chatError(StatusCode.unavailable, 'busy'))
        ..close();
    }
  }

  void setPinned(String id, bool pinned) {
    final m = byId(id);
    if (m.pinned == pinned) return;
    m
      ..pinned = pinned
      ..updatedAt = Int64(_clock++);
    emit(ServerEvent(
      messagePinnedChanged:
          MessagePinnedChanged(messageId: id, pinned: pinned, updatedAt: m.updatedAt),
    ));
  }

  /// The number of streams that are open.
  int get openStreams => _streams.length;

  String? _text(SendMessageRequest r) =>
      r.content.where((p) => p.hasText()).map((p) => p.text.text).join();

  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The limit of the size of a file, with the default of section 7.
  int get _maxFile => caps.maxFileBytes == Int64.ZERO ? 4 * 1024 * 1024 : caps.maxFileBytes.toInt();

  static String _base(String mime) => mime.split(';').first.trim().toLowerCase();

  static String? _class(String mime) {
    final top = _base(mime).split('/').first;
    return top == 'image' || top == 'audio' ? top : null;
  }

  /// The `FileReference` of a part, and the kind of the part.
  static List<(String, FileReference)> _refs(SendMessageRequest r) => [
        for (final p in r.content)
          if (p.hasImage()) ('image', p.image.file) else if (p.hasAudio()) ('audio', p.audio.file),
      ];

  /// The hash of SHA3-256 of [f], as the key of the file store, or null if it has none.
  static String? sha3Key(FileReference f) {
    for (final h in f.hashes) {
      if (listEquals(h.type, ChatClient.sha3Type)) return hex(h.value);
    }
    return null;
  }

  /// The structure of a `FileReference` (section 5.1): the reason `bad_request`, or null.
  static bool _fileStructureBad(FileReference f) =>
      f.mimeType.isEmpty ||
      f.sizeBytes <= Int64.ZERO ||
      f.hashes.isEmpty ||
      f.hashes.any((h) => h.type.isEmpty) ||
      f.hashes.any((h) => listEquals(h.type, ChatClient.sha3Type) && h.value.length != 32) ||
      sha3Key(f) == null;

  /// The checks of section 6.1 that the fake does, in the order of the table: structure,
  /// size, type, then the others. The reason, or null.
  String? check(SendMessageRequest r) {
    final text = _text(r);
    final refs = _refs(r);
    // Step 1: structure.
    if (r.content.isEmpty || text == 'bad') return 'bad_request';
    if (r.idempotencyKey.isNotEmpty && !_id.hasMatch(r.idempotencyKey)) return 'bad_request';
    for (final (kind, f) in refs) {
      if (_fileStructureBad(f)) return 'bad_request';
      final c = _class(f.mimeType);
      if (c != null && c != kind) return 'bad_request';
    }
    if (refs.length > 4) return 'bad_request';
    // Step 2: size.
    if (refs.any((e) => e.$2.sizeBytes.toInt() > _maxFile)) return 'too_large';
    // Step 3: type, for each kind of part.
    final accepted = {for (final m in caps.acceptedMimeTypes) _base(m)};
    if (refs.any((e) => !accepted.contains(_base(e.$2.mimeType)))) return 'unsupported_media';
    if (text == 'media') return 'unsupported_media';
    // The rest.
    if (text == 'busy') return 'busy';
    if (text == 'full') return 'history_full';
    if (requireFiles) {
      for (final (_, f) in refs) {
        if (!files.containsKey(sha3Key(f))) return 'file_missing';
      }
    }
    return null;
  }

  static GrpcError errorFor(String reason) => switch (reason) {
        'busy' => chatError(StatusCode.unavailable, reason),
        'history_full' || 'storage_full' => chatError(StatusCode.resourceExhausted, reason),
        'file_missing' => chatError(StatusCode.failedPrecondition, reason),
        'unsupported_media' => chatError(StatusCode.invalidArgument, reason),
        _ => chatError(StatusCode.invalidArgument, reason),
      };

  Message _accept(SendMessageRequest r) {
    if (r.idempotencyKey.isNotEmpty) {
      for (final m in msgs) {
        if (m.idempotencyKey == r.idempotencyKey) return m;
      }
    }
    final m = user('', key: r.idempotencyKey.isNotEmpty ? r.idempotencyKey : null)
      ..content.addAll(r.content);
    emitCreated(m);
    if (autoAnswer) {
      final a = assistant('echo: ${_text(r)}', replyTo: m.messageId);
      emitCreated(a);
    }
    return m;
  }

  late final ChatServiceBase chat = _Chat(this);
  late final FileServiceBase file = _Files(this);

  Server? server;
  Future<int> start([int port = 0]) async {
    server = Server.create(services: [chat, file]);
    await server!.serve(address: InternetAddress.loopbackIPv4, port: port);
    return server!.port!;
  }

  Future<void> stop() async {
    for (final s in List.of(_streams)) {
      unawaited(s.close());
    }
    // A handler of a call that the client cancelled can stay open: do not wait for it.
    await server?.shutdown().timeout(const Duration(seconds: 2), onTimeout: () {});
    server = null;
  }
}

class _Chat extends ChatServiceBase {
  _Chat(this.f);
  final FakeChatService f;

  @override
  Future<Capabilities> getCapabilities(ServiceCall call, GetCapabilitiesRequest request) async {
    f.capabilityCalls++;
    return f.caps;
  }

  @override
  Future<Message> sendMessage(ServiceCall call, SendMessageRequest request) async {
    f.unarySends.add(request);
    if (f.sendErrors.isNotEmpty) throw f.sendErrors.removeAt(0);
    if (f.fileMissingTimes > 0) {
      f.fileMissingTimes--;
      throw FakeChatService.errorFor('file_missing');
    }
    final reason = f.check(request);
    if (reason != null) throw FakeChatService.errorFor(reason);
    final m = f._accept(request);
    final fail = f.failAfterApply;
    if (fail != null) {
      f.failAfterApply = null;
      throw fail;
    }
    return m;
  }

  @override
  Stream<Message> getMessages(ServiceCall call, GetMessagesRequest request) async* {
    final after = request.afterSequence.toInt();
    f.reads.add(after);
    if (after > f.msgs.length) throw FakeChatService.errorFor('bad_request');
    var list = f.msgs.skip(after).toList();
    final limit = f.readLimit;
    if (limit != null && list.length > limit) list = list.take(limit).toList();
    for (final m in list) {
      if (f.gapInReads) {
        yield m.deepCopy()..sequence = m.sequence + 1;
      } else {
        yield m.deepCopy();
      }
    }
  }

  @override
  Stream<ServerEvent> connect(ServiceCall call, Stream<ClientEvent> request) async* {
    f.connects++;
    if (f.connectErrors.isNotEmpty) throw f.connectErrors.removeAt(0);
    final error = f.connectError;
    if (error != null) throw error;
    final out = StreamController<ServerEvent>();
    final seen = <String>{};
    var subscribed = false;
    var first = true;
    void fail(GrpcError e) {
      out
        ..addError(e)
        ..close();
    }
    request.listen(
      (e) {
        f.streamEvents.add(e);
        if (out.isClosed) return;
        final badId = e.eventId.isNotEmpty && !FakeChatService._id.hasMatch(e.eventId);
        final repeated = e.eventId.isNotEmpty && !seen.add(e.eventId);
        if (first) {
          // A first event that fails ends the call with a status (section 6.5).
          first = false;
          if (!e.hasSubscribe()) return fail(chatError(StatusCode.failedPrecondition, 'bad_state'));
          if (badId || e.subscribe.afterSequence.toInt() > f.msgs.length) {
            return fail(chatError(StatusCode.invalidArgument, 'bad_request'));
          }
          // A conversation that does not exist (no branches here, section 6.8).
          if (e.subscribe.hasConversationId() && e.subscribe.conversationId.isNotEmpty) {
            return fail(chatError(StatusCode.notFound, 'not_found'));
          }
        } else if (badId || repeated) {
          // The service does not copy an `event_id` that is not valid or not new.
          out.add(ServerEvent(error: ProtocolError(code: 'bad_request', message: 'event_id')));
          return;
        }
        if (e.hasSubscribe()) {
          if (subscribed) {
            out.add(ServerEvent(
              error: ProtocolError(code: 'bad_state', message: 'subscribed', eventId: e.eventId),
            ));
            return;
          }
          subscribed = true;
          if (f.protocolErrorsBeforeReady > 0) {
            f.protocolErrorsBeforeReady--;
            out.add(ServerEvent(error: ProtocolError(code: 'bad_request', message: 'x')));
          }
          final after = e.subscribe.afterSequence.toInt();
          f.subscribes.add(after);
          for (final m in f.msgs.skip(after)) {
            out.add(ServerEvent(messageCreated: MessageCreated(message: m.deepCopy())));
          }
          out.add(ServerEvent(
            subscriptionReady: SubscriptionReady(latestSequence: Int64(f.msgs.length), title: f.title),
          ));
          f._streams.add(out);
        } else if (e.hasSendMessage()) {
          final reason = f.check(e.sendMessage);
          if (reason != null) {
            out.add(ServerEvent(
              error: ProtocolError(code: reason, message: 'no', eventId: e.eventId),
            ));
            return;
          }
          f._accept(e.sendMessage);
          f.onStreamSend?.call();
        } else if (e.hasAcknowledge()) {
          if (e.acknowledge.lastSequence.toInt() > f.msgs.length) {
            out.add(ServerEvent(
              error: ProtocolError(code: 'bad_request', message: 'ack', eventId: e.eventId),
            ));
          }
        }
      },
      onDone: out.close,
      onError: (_) {},
    );
    try {
      yield* out.stream;
    } finally {
      f._streams.remove(out);
    }
  }

  @override
  Future<Conversation> forkConversation(ServiceCall call, ForkConversationRequest request) =>
      throw GrpcError.unimplemented();

  @override
  Future<Conversation> getConversation(ServiceCall call, GetConversationRequest request) async {
    f.conversationCalls++;
    return Conversation(title: f.title);
  }

  @override
  Future<AnswerSecretRequestResponse> answerSecretRequest(
    ServiceCall call,
    AnswerSecretRequestRequest request,
  ) async {
    if (f.secretErrors.isNotEmpty) throw f.secretErrors.removeAt(0);
    final m = f.msgs.where((m) => m.messageId == request.messageId).firstOrNull;
    final asked = m != null &&
        m.content.any((p) => p.hasSecretRequest() && p.secretRequest.requestId == request.requestId);
    if (!asked) throw chatError(StatusCode.notFound, 'not_found');
    switch (request.whichAnswer()) {
      case AnswerSecretRequestRequest_Answer.value:
        if (request.value.isEmpty || request.value.contains('\u0000')) {
          throw chatError(StatusCode.invalidArgument, 'bad_request');
        }
        if (utf8.encode(request.value).length > 8192) throw chatError(StatusCode.invalidArgument, 'too_large');
      case AnswerSecretRequestRequest_Answer.skipped:
        if (!request.skipped) throw chatError(StatusCode.invalidArgument, 'bad_request');
      case AnswerSecretRequestRequest_Answer.notSet:
        throw chatError(StatusCode.invalidArgument, 'bad_request');
    }
    f.secretAnswers.add(request);
    return AnswerSecretRequestResponse();
  }

  @override
  Future<Message> setMessagePinned(ServiceCall call, SetMessagePinnedRequest request) async {
    f.pinCalls++;
    if (f.pinErrors.isNotEmpty) throw f.pinErrors.removeAt(0);
    final m = f.msgs.where((m) => m.messageId == request.messageId).firstOrNull;
    if (m == null) throw chatError(StatusCode.notFound, 'not_found');
    f.setPinned(m.messageId, request.pinned);
    return m.deepCopy();
  }
}

class _Files extends FileServiceBase {
  _Files(this.f);
  final FakeChatService f;

  @override
  Stream<QueryFilesResponse> queryFiles(ServiceCall call, Stream<QueryFilesRequest> request) async* {
    final asked = <String>[];
    await for (final r in request) {
      final h = hex(r.hash.value);
      asked.add(h);
      // `type` is required in each hash, and a SHA3-256 `value` has 32 bytes (section 6.4).
      final type = r.hash.type;
      final known = listEquals(type, ChatClient.sha3Type);
      if (type.isEmpty || (known && r.hash.value.length != 32)) {
        f.queries.add(asked);
        throw chatError(StatusCode.invalidArgument, 'bad_request');
      }
      // A `type` that the service does not know gives `available` false.
      yield QueryFilesResponse(
        hash: Hash(type: type, value: r.hash.value),
        available: known && f.files.containsKey(h),
      );
    }
    f.queries.add(asked);
  }

  @override
  Future<UploadFileResponse> uploadFile(ServiceCall call, Stream<UploadFileRequest> request) async {
    final error = f.uploadError;
    if (error != null) throw error;
    FileReference? ref;
    var structure = true;
    var laterFile = false;
    final data = BytesBuilder();
    await for (final r in request) {
      if (r.hasFile()) {
        if (ref == null) {
          ref = r.file;
        } else {
          laterFile = true;
        }
      } else {
        if (ref == null) structure = false;
        f.chunkSizes.add(r.chunk.length);
        data.add(r.chunk);
      }
    }
    // The order of section 6.4: structure, size, type, storage, hash.
    if (ref == null || !structure || FakeChatService._fileStructureBad(ref)) {
      throw chatError(StatusCode.invalidArgument, 'bad_request');
    }
    if (ref.sizeBytes.toInt() > f._maxFile) throw chatError(StatusCode.invalidArgument, 'too_large');
    final accepted = {for (final m in f.caps.acceptedMimeTypes) FakeChatService._base(m)};
    if (!accepted.contains(FakeChatService._base(ref.mimeType))) {
      throw chatError(StatusCode.invalidArgument, 'unsupported_media');
    }
    if (f.storageFull) throw chatError(StatusCode.resourceExhausted, 'storage_full');
    // A later `file` is found while the chunks are read: after the checks above.
    if (laterFile) throw chatError(StatusCode.invalidArgument, 'bad_request');
    final bytes = data.takeBytes();
    final digest = sha3_256(bytes);
    if (hex(digest) != FakeChatService.sha3Key(ref) || bytes.length != ref.sizeBytes.toInt()) {
      throw chatError(StatusCode.invalidArgument, 'hash_mismatch');
    }
    f.files[hex(digest)] = bytes;
    f.uploads.add(ref);
    return UploadFileResponse(file: ref);
  }

  @override
  Stream<DownloadFileResponse> downloadFile(
    ServiceCall call,
    DownloadFileRequest request,
  ) async* {
    f.downloads++;
    final known = listEquals(request.hash.type, ChatClient.sha3Type);
    if (request.hash.type.isEmpty || (known && request.hash.value.length != 32)) {
      throw chatError(StatusCode.invalidArgument, 'bad_request');
    }
    final bytes = f.downloadOverride ?? (known ? f.files[hex(request.hash.value)] : null);
    if (bytes == null) throw chatError(StatusCode.notFound, 'not_found');
    for (var i = 0; i < bytes.length; i += ChatClient.chunkBytes) {
      yield DownloadFileResponse(
        chunk: Uint8List.sublistView(bytes, i, (i + ChatClient.chunkBytes).clamp(0, bytes.length)),
      );
    }
  }
}

/// A TCP forwarder like the tunnel: it counts the connections and it can drop them all.
class TcpProxy {
  TcpProxy(this.targetPort);

  final int targetPort;
  late ServerSocket _listen;
  final _sockets = <Socket>[];
  int connections = 0;
  int get port => _listen.port;

  Future<void> start() async {
    _listen = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _listen.listen((client) async {
      connections++;
      final Socket up;
      try {
        up = await Socket.connect(InternetAddress.loopbackIPv4, targetPort);
      } on Object {
        client.destroy();
        return;
      }
      _sockets
        ..add(client)
        ..add(up);
      client.listen(up.add, onDone: () => up.destroy(), onError: (_) => up.destroy());
      up.listen(client.add, onDone: () => client.destroy(), onError: (_) => client.destroy());
    });
  }

  void drop() {
    for (final s in _sockets) {
      s.destroy();
    }
    _sockets.clear();
  }

  Future<void> stop() async {
    drop();
    await _listen.close();
  }
}
