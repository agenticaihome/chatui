import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/celaut/chat/gen/chat.pbgrpc.dart' as pb;
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/chat_corrector.dart';
import 'package:argus_wallet/celaut/sha3.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'support/fake_chat_service.dart';

/// Wait until [condition] is true. The fake service and the client run in this isolate.
Future<void> until(bool Function() condition, {String what = 'condition'}) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('Timeout while it waited for: $what');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Uint8List bytes(int n, [int seed = 1]) => Uint8List.fromList([for (var i = 0; i < n; i++) (i * 31 + seed) & 255]);

class GrpcChannelAndFiles {
  GrpcChannelAndFiles(this.channel, this.files, this.chat);
  final ClientChannel channel;
  final pb.FileServiceClient files;
  final pb.ChatServiceClient chat;
}

void main() {
  late FakeChatService svc;
  late TcpProxy proxy;
  late ChatClient chat;
  var booted = false;

  Future<void> boot({
    Duration ackEvery = const Duration(milliseconds: 150),
    Duration stableAfter = const Duration(seconds: 10),
    Duration callTimeout = const Duration(seconds: 5),
    List<Duration> waits = const [Duration(milliseconds: 60)],
  }) async {
    final port = await svc.start();
    proxy = TcpProxy(port);
    await proxy.start();
    booted = true;
    chat = ChatClient(
      port: proxy.port,
      reconnectWaits: waits,
      stableAfter: stableAfter,
      ackEvery: ackEvery,
      callTimeout: callTimeout,
      channelBackoff: (_) => const Duration(milliseconds: 50),
    );
  }

  setUp(() {
    svc = FakeChatService();
    booted = false;
  });
  tearDown(() async {
    if (!booted) return;
    await chat.close();
    await proxy.stop();
    await svc.stop();
  });

  group('sha3_256', () {
    test('matches the vectors of NIST', () {
      expect(hex(sha3_256([])), 'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a');
      expect(hex(sha3_256('abc'.codeUnits)), '3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532');
      expect(
        hex(sha3_256(('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq').codeUnits)),
        '41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376',
      );
      // The type of a hash is the digest of an empty input (`docs/celaut/chat.md`, 6.4).
      expect(ChatClient.sha3Type, sha3_256([]));
    });
  });

  group('history', () {
    test('sync reads capabilities and the history from 1, and the table of replies', () async {
      final u = svc.user('hello', key: 'k1');
      svc.assistant('hi', replyTo: u.messageId, reasoning: 'think', pinned: true);
      svc.user('again');
      svc.assistant('stopped', status: pb.MessageStatus.MESSAGE_STATUS_CANCELLED);
      svc.assistant('later', replyTo: 'unknown', status: pb.MessageStatus.MESSAGE_STATUS_FAILED);
      await boot();
      await chat.sync();
      expect(chat.count, 5);
      expect(chat.accepts, {'image', 'audio'});
      final m = chat.messages;
      expect(m.map((e) => e.seq), [1, 2, 3, 4, 5]);
      expect(m[0].cid, 'k1');
      expect(m[0].fromUser, isTrue);
      expect(m[1].replyTo, 1);
      expect(m[1].reasoning, 'think');
      expect(m[1].text, 'hi');
      expect(m[1].pinned, isTrue);
      expect(m[3].isCancelled, isTrue);
      expect(m[3].isOpen, isFalse);
      expect(m[4].isFailed, isTrue);
      expect(m[4].replyTo, isNull);
      expect(svc.reads.first, 0);
      expect(svc.capabilityCalls, 1);
      expect(chat.awaitingAnswer, isFalse);
    });

    test('a read that is shorter than the history is read again until it is empty', () async {
      for (var i = 0; i < 5; i++) {
        svc.user('m$i');
      }
      svc.readLimit = 2;
      await boot();
      await chat.sync();
      expect(chat.count, 5);
      expect(svc.reads, [0, 2, 4, 5]);
    });

    test('a gap in a read is a bad answer', () async {
      svc.user('a');
      svc.gapInReads = true;
      await boot();
      await expectLater(
        chat.sync(),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badAnswer)),
      );
    });

    test('a message above the limit of the client is a bad answer', () async {
      svc.user('x' * (ChatClient.maxMessageBytes + 10));
      await boot();
      await expectLater(
        chat.sync(),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badAnswer)),
      );
    });

    test('a message of another conversation is ignored', () async {
      svc.user('a');
      svc.user('b').conversationId = 'other';
      await boot();
      await chat.sync();
      expect(chat.count, 1);
    });

    test('an unreachable service is unreachable', () async {
      final port = await svc.start();
      await svc.stop();
      proxy = TcpProxy(port);
      await proxy.start();
      booted = true;
      chat = ChatClient(
        port: proxy.port,
        callTimeout: const Duration(seconds: 1),
        channelBackoff: (_) => const Duration(milliseconds: 20),
      );
      await expectLater(
        chat.sync(),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.unreachable)),
      );
    });

    test('syncWhenStarted calls again with the waits until the service listens', () async {
      final port = await svc.start();
      await svc.stop();
      proxy = TcpProxy(port);
      await proxy.start();
      booted = true;
      chat = ChatClient(
        port: proxy.port,
        callTimeout: const Duration(seconds: 1),
        channelBackoff: (_) => const Duration(milliseconds: 20),
      );
      final waits = <Duration>[];
      svc.user('ready');
      await chat.syncWhenStarted(wait: (d) async {
        waits.add(d);
        if (waits.length == 2) await svc.start(port);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(waits, ChatClient.startWaits.take(2).toList());
      expect(chat.count, 1);
    });
  });

  group('stream', () {
    test('the events change the messages, and the client does not read', () async {
      final u = svc.user('q');
      final a = svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      await boot();
      var notices = 0;
      chat.addListener(() => notices++);
      await chat.sync();
      await until(() => chat.streaming, what: 'stream ready');
      // The first open message is where the stream starts: `after_sequence` 1.
      expect(svc.subscribes, [1]);
      expect(chat.awaitingAnswer, isTrue);
      final reads = svc.reads.length;

      svc.emitDelta(a.messageId, reasoning: 'think');
      svc.emitDelta(a.messageId, text: 'Hel');
      svc.emitDelta(a.messageId, text: 'lo');
      await until(() => chat.messages.last.text == 'Hello');
      expect(chat.messages.last.reasoning, 'think');
      expect(chat.messages.last.isOpen, isTrue);

      svc.setStatus(a.messageId, pb.MessageStatus.MESSAGE_STATUS_COMPLETED);
      await until(() => !chat.messages.last.isOpen);
      expect(chat.messages.last.status, ChatMessage.statusDone);
      expect(chat.awaitingAnswer, isFalse);
      expect(notices, greaterThan(0));

      // A delta of a final message, and of a message that the client does not have.
      svc.emitDelta(a.messageId, text: '!');
      svc.emit(pb.ServerEvent(messageDelta: pb.MessageDelta(messageId: 'nope', textAppend: 'x')));
      // A new message, whole.
      final b = svc.user('next');
      svc.emitCreated(b);
      await until(() => chat.count == 3);
      expect(chat.messages[1].text, 'Hello');

      // A final message does not change when the service creates it again.
      svc.emitCreated(svc.msgs[1]..content.first.text.text = 'changed');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(chat.messages[1].text, 'Hello');

      // `sync` does nothing while the stream is open.
      await chat.sync();
      expect(svc.reads.length, reads);
      expect(svc.connects, 1);
      expect(proxy.connections, 1);
    });

    test('pinned changes for any message, and the user can pin', () async {
      final u = svc.user('q');
      svc.assistant('a', replyTo: u.messageId);
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      expect(chat.messages.any((m) => m.pinned), isFalse);

      svc.setPinned('m1', true);
      await until(() => chat.messages.first.pinned);
      expect(chat.messages.first.fromUser, isTrue);
      expect(chat.messages.first.status, ChatMessage.statusDone);

      await chat.setPinned(chat.messages[1], true);
      expect(chat.messages[1].pinned, isTrue);
      expect(svc.pinCalls, 1);
      svc.setPinned('m1', false);
      await until(() => !chat.messages.first.pinned);
      expect(chat.messages[1].pinned, isTrue);
      expect(chat.messages[1].text, 'a');

      await expectLater(
        chat.setPinned(const ChatMessage(seq: 9, role: 'user', text: '', id: 'zz'), true),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
      );
    });

    test('a pin shows at once, and a failed call gives the old value back', () async {
      final u = svc.user('q');
      svc.assistant('a', replyTo: u.messageId);
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      final seen = <bool>[];
      chat.addListener(() => seen.add(chat.messages[1].pinned));

      svc.pinErrors.add(chatError(StatusCode.unavailable, 'busy'));
      await expectLater(
        chat.setPinned(chat.messages[1], true),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.busy)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, [true, false]);
      expect(chat.messages[1].pinned, isFalse);
      expect(chat.canPin, isTrue);

      await chat.setPinned(chat.messages[1], true);
      expect(chat.messages[1].pinned, isTrue);
      svc.pinErrors.add(chatError(StatusCode.notFound, 'not_found'));
      await expectLater(chat.setPinned(chat.messages[1], false), throwsA(isA<ChatException>()));
      expect(chat.messages[1].pinned, isTrue);
    });

    test('UNIMPLEMENTED hides the action and the client does not call again', () async {
      final u = svc.user('q');
      svc.assistant('a', replyTo: u.messageId);
      await boot();
      await chat.sync();
      svc.pinErrors.add(chatError(StatusCode.unimplemented, 'unimplemented'));
      await expectLater(
        chat.setPinned(chat.messages[1], true),
        throwsA(isA<ChatException>().having((e) => e.status, 'status', StatusCode.unimplemented)),
      );
      expect(chat.canPin, isFalse);
      expect(chat.messages[1].pinned, isFalse);
      final calls = svc.pinCalls;
      await expectLater(chat.setPinned(chat.messages[1], true), throwsA(isA<ChatException>()));
      expect(svc.pinCalls, calls);
    });

    test('a message that is cancelled is final', () async {
      final u = svc.user('q');
      final a = svc.assistant('part', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      svc.setStatus(a.messageId, pb.MessageStatus.MESSAGE_STATUS_CANCELLED);
      await until(() => chat.messages.last.isCancelled);
      expect(chat.messages.last.text, 'part');
      expect(chat.awaitingAnswer, isFalse);
    });

    test('a gap in the events opens the stream again from the last message', () async {
      svc.user('a');
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      // The service skips message 2.
      svc.user('b');
      final c = svc.user('c');
      svc.emitCreated(c);
      await until(() => svc.subscribes.length == 2);
      await until(() => chat.count == 3);
      expect(svc.subscribes, [1, 1]);
      expect(svc.connects, 2);
    });

    test('a service with no Connect: no stream, and the client reads', () async {
      svc.connectError = GrpcError.unimplemented();
      svc.user('a');
      await boot();
      await chat.sync();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(chat.streaming, isFalse);
      expect(svc.connects, 1, reason: 'no new try');
      svc.user('b');
      await chat.sync();
      expect(chat.count, 2);
      expect(svc.reads.length, greaterThan(2));
    });

    test('a lost connection: the stream opens again and replays the open message', () async {
      final u = svc.user('q');
      final a = svc.assistant('one', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      proxy.drop();
      await until(() => !chat.streaming, what: 'stream lost');
      // The service goes on while the client has no stream.
      svc.emitDelta(a.messageId, text: ' two');
      svc.setStatus(a.messageId, pb.MessageStatus.MESSAGE_STATUS_COMPLETED);
      await until(() => chat.streaming, what: 'stream again');
      await until(() => !chat.messages.last.isOpen);
      expect(chat.messages.last.text, 'one two');
      // `after_sequence` is the `sequence` of the first open message, minus 1.
      expect(svc.subscribes, [1, 1]);
      expect(proxy.connections, 2);
      // The next stream starts at the last message, as no message is open.
      proxy.drop();
      await until(() => svc.subscribes.length == 3);
      expect(svc.subscribes.last, 2);
    });

    test('acknowledge: only when the value rises, and at most once in the interval', () async {
      final u = svc.user('q');
      svc.assistant('a', replyTo: u.messageId);
      final open = svc.assistant('', status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      await boot(ackEvery: const Duration(milliseconds: 400));
      await chat.sync();
      await until(() => chat.streaming);
      List<int> acks() => [
            for (final e in svc.streamEvents)
              if (e.hasAcknowledge()) e.acknowledge.lastSequence.toInt(),
          ];
      await until(() => acks().isNotEmpty);
      // Messages 1 and 2 are final, message 3 is open.
      expect(acks(), [2]);
      svc.setStatus(open.messageId, pb.MessageStatus.MESSAGE_STATUS_COMPLETED);
      final sentAt = DateTime.now();
      final u2 = svc.user('q2');
      svc.emitCreated(u2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(acks(), [2], reason: 'the interval is not over');
      await until(() => acks().length == 2);
      expect(DateTime.now().difference(sentAt), greaterThan(const Duration(milliseconds: 250)));
      expect(acks(), [2, 4]);
      // The same value is not sent again.
      svc.emitDelta(u2.messageId, text: '');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(acks(), [2, 4]);
      // Each event has an event_id, and they are all different.
      final ids = [for (final e in svc.streamEvents) e.eventId];
      expect(ids.every((i) => i.isNotEmpty), isTrue);
      expect(ids.toSet().length, ids.length);
    });
  });

  group('send', () {
    test('over the stream when it is open, with event_id and idempotency_key', () async {
      svc.autoAnswer = true;
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      await chat.send('hello');
      expect(svc.unarySends, isEmpty);
      final e = svc.streamEvents.firstWhere((e) => e.hasSendMessage());
      expect(e.eventId, isNotEmpty);
      expect(e.sendMessage.idempotencyKey, matches(RegExp(r'^[A-Za-z0-9_-]{1,64}$')));
      expect(e.sendMessage.content.single.text.text, 'hello');
      await until(() => chat.count == 2);
      expect(chat.messages[0].cid, e.sendMessage.idempotencyKey);
      expect(chat.messages[1].replyTo, 1);
      expect(chat.messages.map((m) => m.seq), [1, 2]);
    });

    test('with SendMessage when the stream is not open, and each send has a new key', () async {
      svc.autoAnswer = true;
      await boot();
      await chat.send('one');
      await chat.send('two');
      expect(svc.capabilityCalls, 1, reason: 'capabilities first');
      expect(svc.unarySends.length, 2);
      expect(svc.unarySends[0].idempotencyKey, isNot(svc.unarySends[1].idempotencyKey));
      // The reply of the first send is user message 1. The answer was not read yet.
      expect(chat.messages.first.text, 'one');
      expect(chat.messages.first.seq, 1);
      // The second send is at 3: the client reads the gap, and the answer to it.
      expect(chat.messages.map((m) => m.text), ['one', 'echo: one', 'two', 'echo: two']);
      expect(proxy.connections, 1);
    });

    test('errors of the service map to the kinds of section 9', () async {
      await boot();
      for (final (text, kind) in [
        ('bad', ChatErrorKind.badRequest),
        ('busy', ChatErrorKind.busy),
        ('full', ChatErrorKind.historyFull),
        ('media', ChatErrorKind.unsupportedMedia),
      ]) {
        await expectLater(
          chat.send(text),
          throwsA(isA<ChatException>().having((e) => e.kind, text, kind)),
          reason: 'unary $text',
        );
      }
      expect(chat.count, 0);
      svc.sendErrors.add(chatError(StatusCode.internal, 'service_error'));
      await expectLater(
        chat.send('x'),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.other)),
      );
      svc.sendErrors.add(GrpcError.unimplemented());
      await expectLater(
        chat.send('x'),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.other)),
      );
    });

    test('ProtocolError with the event_id fails that send, and the stream stays open', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      for (final (text, kind) in [
        ('bad', ChatErrorKind.badRequest),
        ('busy', ChatErrorKind.busy),
        ('full', ChatErrorKind.historyFull),
        ('media', ChatErrorKind.unsupportedMedia),
      ]) {
        await expectLater(
          chat.send(text),
          throwsA(isA<ChatException>().having((e) => e.kind, text, kind)),
          reason: 'stream $text',
        );
      }
      expect(chat.streaming, isTrue);
      expect(svc.unarySends, isEmpty);
      expect(svc.connects, 1);
      await chat.send('fine');
      expect(chat.messages.single.text, 'fine');
    });

    test('a reply that is lost: the client reads, finds the key, and does not send again', () async {
      await boot();
      svc.failAfterApply = GrpcError.unavailable();
      await chat.send('once');
      expect(svc.unarySends.length, 1);
      expect(svc.msgs.length, 1);
      expect(chat.messages.single.text, 'once');
    });

    test('a send that did not arrive: the client sends again with the same key, once', () async {
      await boot();
      svc.sendErrors.add(GrpcError.deadlineExceeded());
      await chat.send('twice');
      expect(svc.unarySends.length, 2);
      expect(svc.unarySends[0].idempotencyKey, svc.unarySends[1].idempotencyKey);
      expect(svc.msgs.length, 1);
      // The second try fails too: unreachable.
      svc.sendErrors
        ..add(GrpcError.unavailable())
        ..add(GrpcError.unavailable());
      await expectLater(
        chat.send('never'),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.unreachable)),
      );
      expect(svc.unarySends.length, 4);
      expect(svc.msgs.length, 1);
    });

    test('the stream breaks after a send over the stream: the client follows 6.3', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      svc.onStreamSend = proxy.drop;
      await chat.send('over');
      expect(svc.msgs.length, 1, reason: 'no second message');
      expect(chat.messages.single.text, 'over');
      await until(() => chat.streaming, what: 'stream again');
    });

    test('limits of the client: nothing goes to the service', () async {
      svc.caps = pb.Capabilities(
        acceptedMimeTypes: ['image/png'],
        maxTextBytes: 10,
        maxFilesPerMessage: 1,
        maxFileBytes: Int64(100),
      );
      await boot();
      Future<void> bad(Future<void> f, ChatErrorKind kind) => expectLater(
            f,
            throwsA(isA<ChatException>().having((e) => e.kind, 'kind', kind)),
          );
      await bad(chat.send(''), ChatErrorKind.badRequest);
      await bad(chat.send('12345678901'), ChatErrorKind.badRequest);
      await bad(chat.send('é' * 6), ChatErrorKind.badRequest, );
      final png = OutgoingAttachment(mime: 'image/png', bytes: bytes(50));
      await bad(chat.send('', attachments: [png, png]), ChatErrorKind.badRequest);
      await bad(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/png', bytes: bytes(101))]),
        ChatErrorKind.badRequest,
      );
      await bad(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/png', bytes: Uint8List(0))]),
        ChatErrorKind.badRequest,
      );
      await bad(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/jpeg', bytes: bytes(5))]),
        ChatErrorKind.unsupportedMedia,
      );
      await bad(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/gif', bytes: bytes(5))]),
        ChatErrorKind.unsupportedMedia,
      );
      await bad(
        chat.send('', attachments: [OutgoingAttachment(mime: 'application/pdf', bytes: bytes(5))]),
        ChatErrorKind.unsupportedMedia,
      );
      expect(svc.unarySends, isEmpty);
      expect(svc.queries, isEmpty);
      expect(chat.accepts, {'image'});
    });

    test('defaults of the limits when the service sends 0', () async {
      svc.caps = pb.Capabilities(acceptedMimeTypes: ['image/png']);
      await boot();
      await chat.send('é' * 8192);
      await expectLater(
        chat.send('é' * 8193),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
      );
      final png = OutgoingAttachment(mime: 'image/png', bytes: bytes(10));
      await expectLater(
        chat.send('', attachments: List.filled(5, png)),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
      );
    });
  });

  group('files', () {
    test('query, upload in chunks of 64 KiB, then send; a file that is there is not uploaded', () async {
      await boot();
      final big = OutgoingAttachment(mime: 'image/PNG; x=1', bytes: bytes(150 * 1024), name: 'big.png');
      final small = OutgoingAttachment(mime: 'audio/wav', bytes: bytes(1000, 7));
      svc.files[hex(sha3_256(small.bytes))] = small.bytes;
      await chat.send('look', attachments: [big, small]);
      expect(svc.queries.single, [hex(sha3_256(big.bytes)), hex(sha3_256(small.bytes))]);
      expect(svc.uploads.length, 1);
      expect(svc.chunkSizes, [65536, 65536, 150 * 1024 - 2 * 65536]);
      final sent = svc.unarySends.single;
      expect(sent.content.length, 3);
      expect(sent.content[0].text.text, 'look');
      final ref = sent.content[1].image.file;
      expect(ref.mimeType, 'image/png');
      expect(ref.sizeBytes.toInt(), 150 * 1024);
      expect(ref.filename, 'big.png');
      expect(ref.hashes.single.type, ChatClient.sha3Type);
      expect(ref.hashes.single.value, sha3_256(big.bytes));
      expect(sent.content[2].audio.file.mimeType, 'audio/wav');
      // The message in the list has the files, and the bytes are in memory.
      final m = chat.messages.single;
      expect(m.attachments.map((a) => (a.kind, a.mime, a.size)), [
        ('image', 'image/png', 150 * 1024),
        ('audio', 'audio/wav', 1000),
      ]);
      expect(await chat.readAttachment(1, 0), big.bytes);
      expect(svc.downloads, 0);
    });

    test('a send with a file and no text, over the stream', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      final f = OutgoingAttachment(mime: 'image/jpeg', bytes: bytes(300));
      await chat.send('', attachments: [f]);
      expect(svc.streamEvents.where((e) => e.hasSendMessage()).single.sendMessage.content.single.hasImage(), isTrue);
      expect(proxy.connections, 1, reason: 'the stream, the query and the upload share one connection');
    });

    test('download checks the hash, and keeps the bytes once', () async {
      final data = bytes(70000, 3);
      svc.files[hex(sha3_256(data))] = data;
      final ref = pb.FileReference(
        hashes: [pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data))],
        mimeType: 'image/png',
        sizeBytes: Int64(data.length),
      );
      svc.user('', extra: [pb.ContentPart(image: pb.ImageContent(file: ref))]);
      await boot();
      await chat.sync();
      final got = await Future.wait([chat.readAttachment(1, 0), chat.readAttachment(1, 0)]);
      expect(got[0], data);
      expect(await chat.readAttachment(1, 0), data);
      expect(svc.downloads, 1);
    });

    test('a download with the wrong bytes is a bad answer and is not kept', () async {
      final data = bytes(1000);
      svc.files[hex(sha3_256(data))] = data;
      final ref = pb.FileReference(
        hashes: [pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data))],
        mimeType: 'image/png',
        sizeBytes: Int64(data.length),
      );
      svc.user('', extra: [pb.ContentPart(image: pb.ImageContent(file: ref))]);
      await boot();
      await chat.sync();
      Future<void> bad() => expectLater(
            chat.readAttachment(1, 0),
            throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badAnswer)),
          );
      svc.downloadOverride = bytes(1000, 9);
      await bad();
      svc.downloadOverride = bytes(2000);
      await bad();
      svc.downloadOverride = bytes(10);
      await bad();
      svc.downloadOverride = null;
      expect(await chat.readAttachment(1, 0), data);
    });

    test('a message without a SHA3-256 hash gives no file; a file that is not there is an error', () async {
      final ref = pb.FileReference(
        hashes: [pb.Hash(type: [1, 2, 3], value: [4])],
        mimeType: 'image/png',
        sizeBytes: Int64(4),
      );
      svc.user('', extra: [pb.ContentPart(image: pb.ImageContent(file: ref))]);
      final missing = pb.FileReference(
        hashes: [pb.Hash(type: ChatClient.sha3Type, value: bytes(32))],
        mimeType: 'image/png',
        sizeBytes: Int64(4),
      );
      svc.user('', extra: [pb.ContentPart(image: pb.ImageContent(file: missing))]);
      await boot();
      await chat.sync();
      await expectLater(
        chat.readAttachment(1, 0),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badAnswer)),
      );
      await expectLater(
        chat.readAttachment(2, 0),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
      );
      await expectLater(chat.readAttachment(7, 0), throwsA(isA<ChatException>()));
      // A file with no SHA3-256 hash is never asked for: no `DownloadFile`.
      expect(svc.downloads, 1, reason: 'only message 2, which has a SHA3-256 hash');
      // The type of SHA3-256 with a value of 31 bytes is not a SHA3-256 hash either.
      svc.user('', extra: [
        pb.ContentPart(
          image: pb.ImageContent(
            file: pb.FileReference(
              hashes: [pb.Hash(type: ChatClient.sha3Type, value: bytes(31))],
              mimeType: 'image/png',
              sizeBytes: Int64(4),
            ),
          ),
        ),
      ]);
      await chat.sync();
      svc.emitCreated(svc.msgs.last);
      await until(() => chat.count == 3);
      await expectLater(chat.readAttachment(3, 0), throwsA(isA<ChatException>()));
      expect(svc.downloads, 1);
    });

    test('file_missing: upload again and send again with the same key, once', () async {
      await boot();
      final f = OutgoingAttachment(mime: 'image/png', bytes: bytes(500));
      svc.fileMissingTimes = 1;
      await chat.send('x', attachments: [f]);
      expect(svc.unarySends.length, 2);
      expect(svc.unarySends[0].idempotencyKey, svc.unarySends[1].idempotencyKey);
      expect(svc.uploads.length, 2, reason: 'uploaded again, without a query');
      expect(svc.queries.length, 1);
      expect(chat.count, 1);
      // It fails again: the user is told, and the client does not try a third time.
      svc.fileMissingTimes = 5;
      await expectLater(
        chat.send('y', attachments: [f]),
        throwsA(isA<ChatException>().having((e) => e.reason, 'reason', 'file_missing')),
      );
      expect(svc.unarySends.length, 4);
    });

    test('an upload that the service refuses', () async {
      await boot();
      svc.uploadError = chatError(StatusCode.invalidArgument, 'hash_mismatch');
      await expectLater(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/png', bytes: bytes(10))]),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
      );
      svc.uploadError = chatError(StatusCode.invalidArgument, 'unsupported_media');
      await expectLater(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/png', bytes: bytes(10))]),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.unsupportedMedia)),
      );
      expect(svc.unarySends, isEmpty);
    });

    test('the cache keeps at most 24 MiB for other messages', () async {
      await boot();
      final a = OutgoingAttachment(mime: 'image/png', bytes: bytes(4 * 1024 * 1024));
      for (var i = 0; i < 7; i++) {
        await chat.send('', attachments: [OutgoingAttachment(mime: 'image/png', bytes: bytes(4 * 1024 * 1024, i + 1))]);
      }
      expect(a.bytes.length, 4 * 1024 * 1024);
      // The first files were dropped, and the service gives them again.
      expect(await chat.readAttachment(1, 0), bytes(4 * 1024 * 1024, 1));
      expect(svc.downloads, 1);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('revision 6, round 3', () {
    pb.FileReference ref(Uint8List data, {String mime = 'image/png', List<pb.Hash>? hashes, int? size}) =>
        pb.FileReference(
          hashes: hashes ?? [pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data))],
          mimeType: mime,
          sizeBytes: Int64(size ?? data.length),
        );

    Stream<pb.UploadFileRequest> upload(pb.FileReference r, Uint8List data) async* {
      yield pb.UploadFileRequest(file: r);
      if (data.isNotEmpty) yield pb.UploadFileRequest(chunk: data);
    }

    Future<void> expectReason(Future<Object?> call, String reason) => expectLater(
          call,
          throwsA(isA<GrpcError>().having((e) => e.trailers?['chat-reason'], 'reason', reason)),
          reason: reason,
        );

    test('the hash is raw: 32 bytes for the type and for the value', () async {
      expect(ChatClient.sha3Type.length, 32);
      await boot();
      final f = OutgoingAttachment(mime: 'image/png', bytes: bytes(100));
      await chat.send('', attachments: [f]);
      final h = svc.unarySends.single.content.single.image.file.hashes.single;
      expect(h.type, ChatClient.sha3Type);
      expect(h.value.length, 32);
      expect(svc.queries.single.single, hex(sha3_256(f.bytes)));
    });

    test('a hash of 64 ASCII characters is not SHA3-256: the file cannot be read', () async {
      final data = bytes(500);
      svc.files[hex(sha3_256(data))] = data;
      final ascii = pb.Hash(type: hex(ChatClient.sha3Type).codeUnits, value: hex(sha3_256(data)).codeUnits);
      svc.user('', extra: [pb.ContentPart(image: pb.ImageContent(file: ref(data, hashes: [ascii])))]);
      svc.user('', extra: [
        pb.ContentPart(
          image: pb.ImageContent(file: ref(data, hashes: [ascii, pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data))])),
        ),
      ]);
      await boot();
      await chat.sync();
      expect(chat.messages[0].attachments.single.hash, isNull);
      await expectLater(
        chat.readAttachment(1, 0),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badAnswer)),
      );
      expect(await chat.readAttachment(2, 0), data, reason: 'the SHA3-256 hash is used');
    });

    test('error: a FAILED message of a read has it, and a MessageStatusChanged sets it once', () async {
      final u = svc.user('q');
      svc.assistant('Half', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_FAILED, error: 'Read');
      final open = svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      svc.assistant('bad', status: pb.MessageStatus.MESSAGE_STATUS_COMPLETED);
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      expect(chat.messages[1].error, 'Read');
      expect(chat.messages[0].error, isNull);
      expect(chat.messages[3].error, isNull);
      svc.setStatus(open.messageId, pb.MessageStatus.MESSAGE_STATUS_FAILED, error: 'The model is down.');
      await until(() => chat.messages[2].isFailed);
      expect(chat.messages[2].error, 'The model is down.');
      // The text does not give the error, and `metadata` is not read.
      open.metadata['error'] = 'from metadata';
      await chat.sync();
      expect(chat.messages[2].error, 'The model is down.');
    });

    test('error: a failure with no error text has none, and metadata is not used', () async {
      final u = svc.user('q');
      final a = svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      a.metadata['error'] = 'from metadata';
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      svc.setStatus(a.messageId, pb.MessageStatus.MESSAGE_STATUS_FAILED);
      await until(() => chat.messages[1].isFailed);
      expect(chat.messages[1].error, isNull);
    });

    test('an empty string in an optional field is the same as absent', () async {
      final u = svc.user('q', key: '');
      final a = svc.assistant('a', replyTo: '');
      a.error = '';
      await boot();
      await chat.sync();
      expect(chat.messages[0].cid, isNull);
      expect(chat.messages[1].replyTo, isNull);
      expect(chat.messages[1].error, isNull);
      expect(u.hasIdempotencyKey(), isTrue, reason: 'the fake sent an empty key on purpose');
    });

    test('the client sends no empty optional string and no empty name', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      final f = OutgoingAttachment(mime: 'image/png', bytes: bytes(50), name: '');
      await chat.send('hi', attachments: [f]);
      final sent = svc.streamEvents.firstWhere((e) => e.hasSendMessage());
      expect(sent.sendMessage.hasConversationId(), isFalse);
      expect(sent.sendMessage.hasReplyToMessageId(), isFalse);
      expect(sent.sendMessage.idempotencyKey, isNotEmpty);
      expect(sent.sendMessage.content[1].image.file.hasFilename(), isFalse);
      expect(svc.uploads.single.hasFilename(), isFalse);
    });

    test('the client never sends an empty file', () async {
      await boot();
      await expectLater(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/png', bytes: Uint8List(0))]),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
      );
      expect(svc.uploads, isEmpty);
      expect(svc.unarySends, isEmpty);
      expect(svc.queries, isEmpty);
    });

    test('storage_full: its own kind, and the client does not try again', () async {
      await boot();
      svc.storageFull = true;
      final f = OutgoingAttachment(mime: 'image/png', bytes: bytes(80));
      await expectLater(
        chat.send('x', attachments: [f]),
        throwsA(isA<ChatException>()
            .having((e) => e.kind, 'kind', ChatErrorKind.storageFull)
            .having((e) => e.reason, 'reason', 'storage_full')),
      );
      expect(svc.unarySends, isEmpty);
      expect(chat.count, 0);
      // A second try is the choice of the user, and it works when there is room.
      svc.storageFull = false;
      await chat.send('x', attachments: [f]);
      expect(svc.uploads.length, 1);
    });

    test('RESOURCE_EXHAUSTED with no reason: too_large for a send and a file, other elsewhere', () async {
      await boot();
      final plain = GrpcError.resourceExhausted('Received message larger than max');
      svc.sendErrors.add(plain);
      await expectLater(
        chat.send('x'),
        throwsA(isA<ChatException>()
            .having((e) => e.kind, 'kind', ChatErrorKind.badRequest)
            .having((e) => e.reason, 'reason', 'too_large')),
      );
      svc.uploadError = plain;
      await expectLater(
        chat.send('', attachments: [OutgoingAttachment(mime: 'image/png', bytes: bytes(9))]),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.badRequest)),
      );
      svc.uploadError = null;
      // Another call: other. A reason of the service wins.
      svc.pinErrors.add(plain);
      await chat.send('p');
      await expectLater(
        chat.setPinned(chat.messages.single, true),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.other)),
      );
      svc.sendErrors.add(chatError(StatusCode.resourceExhausted, 'history_full'));
      await expectLater(
        chat.send('x'),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.historyFull)),
      );
    });

    test('a Connect stream that ends with busy: no error, and the client subscribes again', () async {
      final u = svc.user('q');
      final a = svc.assistant('one', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      expect(svc.connects, 1);
      svc.closeStreamsBusy();
      await until(() => svc.connects == 2 && chat.streaming, what: 'new stream');
      // The new stream replays the open message from the start of it.
      expect(svc.subscribes, [1, 1]);
      svc.emitDelta(a.messageId, text: '!');
      await until(() => chat.messages.last.text == 'one!');
      expect(chat.messages.length, 2);
    });

    test('a first event that fails: the call ends with a status and the client tries again', () async {
      svc.user('a');
      await boot();
      svc.connectError = chatError(StatusCode.invalidArgument, 'bad_request');
      await chat.sync();
      await until(() => svc.connects >= 2, what: 'tries again');
      expect(chat.streaming, isFalse);
      svc.connectError = null;
      await until(() => chat.streaming, what: 'stream');
      expect(chat.count, 1);
    });

    test('ProtocolError with no event_id does not fail a send, and does not end the stream', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      svc.emit(pb.ServerEvent(error: pb.ProtocolError(code: 'bad_request', message: 'event_id')));
      svc.emit(pb.ServerEvent(error: pb.ProtocolError(code: 'bad_request', message: 'x', eventId: '')));
      await chat.send('fine');
      expect(chat.streaming, isTrue);
      expect(svc.connects, 1);
      expect(chat.messages.single.text, 'fine');
    });

    test('a ProtocolError with the event_id of a send maps an unaccepted type of any kind of part', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      // Any mime type that the service does not accept, in each kind of part.
      svc.caps.acceptedMimeTypes
        ..clear()
        ..add('image/png');
      svc.sendErrors.clear();
      await expectLater(
        chat.send('', attachments: [OutgoingAttachment(mime: 'audio/wav', bytes: bytes(5))]),
        throwsA(isA<ChatException>().having((e) => e.kind, 'kind', ChatErrorKind.unsupportedMedia)),
      );
    });

    group('the fake service follows the new rules', () {
      Future<GrpcChannelAndFiles> files() async {
        await boot();
        final channel = ClientChannel(
          '127.0.0.1',
          port: proxy.port,
          options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
        );
        return GrpcChannelAndFiles(channel, pb.FileServiceClient(channel), pb.ChatServiceClient(channel));
      }

      test('upload: the order of checks is structure, size, type, storage, hash', () async {
        final c = await files();
        addTearDown(c.channel.shutdown);
        final data = bytes(100);
        svc.storageFull = true;
        // Structure: an empty file, a hash with no type, no hash.
        await expectReason(c.files.uploadFile(upload(ref(Uint8List(0), size: 0), Uint8List(0))), 'bad_request');
        await expectReason(
          c.files.uploadFile(upload(ref(data, hashes: [pb.Hash(value: sha3_256(data))]), data)),
          'bad_request',
        );
        await expectReason(c.files.uploadFile(upload(ref(data, hashes: []), data)), 'bad_request');
        // Size comes before type: a file of an unknown type above the limit is too large.
        svc.caps = pb.Capabilities(acceptedMimeTypes: ['image/png'], maxFileBytes: Int64(50));
        await expectReason(c.files.uploadFile(upload(ref(data, mime: 'application/pdf'), data)), 'too_large');
        svc.caps = pb.Capabilities(acceptedMimeTypes: ['image/png']);
        // Type comes before storage.
        await expectReason(c.files.uploadFile(upload(ref(data, mime: 'application/pdf'), data)), 'unsupported_media');
        // Storage comes before the hash.
        final wrong = ref(data, hashes: [pb.Hash(type: ChatClient.sha3Type, value: bytes(32))]);
        await expectReason(c.files.uploadFile(upload(wrong, data)), 'storage_full');
        svc.storageFull = false;
        await expectReason(c.files.uploadFile(upload(wrong, data)), 'hash_mismatch');
        expect(svc.files, isEmpty, reason: 'a failed upload leaves nothing');
        await c.files.uploadFile(upload(ref(data), data));
        expect(svc.files.length, 1);
      });

      test('a hash type of 64 ASCII characters is a type that the service does not know', () async {
        final c = await files();
        addTearDown(c.channel.shutdown);
        final data = bytes(100);
        final ascii = pb.Hash(type: hex(ChatClient.sha3Type).codeUnits, value: sha3_256(data));
        await expectReason(c.files.uploadFile(upload(ref(data, hashes: [ascii]), data)), 'bad_request');
        final answers = await c.files
            .queryFiles(Stream.value(pb.QueryFilesRequest(hash: ascii)))
            .toList();
        expect(answers.single.available, isFalse);
      });

      test('send: an unaccepted mime type is unsupported_media in each kind of part', () async {
        final c = await files();
        addTearDown(c.channel.shutdown);
        final data = bytes(10);
        pb.SendMessageRequest send(pb.ContentPart p) => pb.SendMessageRequest(content: [p]);
        final pdf = ref(data, mime: 'application/pdf');
        await expectReason(c.chat.sendMessage(send(pb.ContentPart(image: pb.ImageContent(file: pdf)))), 'unsupported_media');
        await expectReason(c.chat.sendMessage(send(pb.ContentPart(audio: pb.AudioContent(file: pdf)))), 'unsupported_media');
        final gif = ref(data, mime: 'image/gif');
        await expectReason(c.chat.sendMessage(send(pb.ContentPart(image: pb.ImageContent(file: gif)))), 'unsupported_media');
        // A kind that disagrees with an image/* or audio/* type is bad_request, also when
        // the service would not accept the type.
        await expectReason(c.chat.sendMessage(send(pb.ContentPart(image: pb.ImageContent(file: ref(data, mime: 'audio/wav'))))), 'bad_request');
        await expectReason(c.chat.sendMessage(send(pb.ContentPart(audio: pb.AudioContent(file: ref(data, mime: 'image/png'))))), 'bad_request');
        await expectReason(c.chat.sendMessage(send(pb.ContentPart(audio: pb.AudioContent(file: ref(data, mime: 'image/tiff'))))), 'bad_request');
        // Structure comes before size, and size before type.
        svc.caps = pb.Capabilities(acceptedMimeTypes: ['image/png'], maxFileBytes: Int64(5));
        await expectReason(c.chat.sendMessage(send(pb.ContentPart(image: pb.ImageContent(file: gif)))), 'too_large');
        await expectReason(
          c.chat.sendMessage(send(pb.ContentPart(image: pb.ImageContent(file: ref(data, hashes: [pb.Hash(value: [1])]))))),
          'bad_request',
        );
        expect(svc.msgs, isEmpty);
      });

      test('send: an empty string is absent, and a second send with it adds a second message', () async {
        final c = await files();
        addTearDown(c.channel.shutdown);
        final r = pb.SendMessageRequest(
          content: [pb.ContentPart(text: pb.TextContent(text: 'x'))],
          idempotencyKey: '',
          replyToMessageId: '',
        );
        await c.chat.sendMessage(r);
        await c.chat.sendMessage(r);
        expect(svc.msgs.length, 2);
        expect(svc.msgs.first.hasIdempotencyKey(), isFalse);
      });

      test('the status event PENDING to IN_PROGRESS exists only for a PENDING message', () async {
        final u = svc.user('q');
        final pending = svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_PENDING);
        final running = svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
        svc.setStatus(pending.messageId, pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
        expect(() => svc.setStatus(running.messageId, pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS), throwsStateError);
        svc.setStatus(running.messageId, pb.MessageStatus.MESSAGE_STATUS_FAILED, error: 'no');
        expect(() => svc.setStatus(running.messageId, pb.MessageStatus.MESSAGE_STATUS_COMPLETED), throwsStateError);
        expect(running.error, 'no');
        // A PENDING message goes on to the end, and the client shows it as open.
        await boot();
        await chat.sync();
        expect(chat.messages[1].isOpen, isTrue);
      });

      test('Connect: a bad or repeated event_id gets a ProtocolError with no event_id', () async {
        final c = await files();
        addTearDown(c.channel.shutdown);
        final out = StreamController<pb.ClientEvent>();
        final got = <pb.ServerEvent>[];
        final call = c.chat.connect(out.stream)..listen(got.add, onError: (_) {});
        addTearDown(() async {
          await out.close();
          await call.cancel();
        });
        out.add(pb.ClientEvent(eventId: 'a', subscribe: pb.SubscribeRequest()));
        await until(() => got.any((e) => e.hasSubscriptionReady()));
        out.add(pb.ClientEvent(eventId: 'a', acknowledge: pb.AcknowledgeEvent(lastSequence: Int64(0))));
        out.add(pb.ClientEvent(eventId: 'a b', acknowledge: pb.AcknowledgeEvent(lastSequence: Int64(0))));
        await until(() => got.where((e) => e.hasError()).length == 2);
        for (final e in got.where((e) => e.hasError())) {
          expect(e.error.code, 'bad_request');
          expect(e.error.hasEventId(), isFalse);
        }
      });

      test('Connect: a first event that fails ends the call with a status and a reason', () async {
        final c = await files();
        addTearDown(c.channel.shutdown);
        Future<void> first(pb.ClientEvent e, String reason) => expectReason(
              c.chat.connect(Stream.value(e)).toList(),
              reason,
            );
        await first(pb.ClientEvent(eventId: 'a', subscribe: pb.SubscribeRequest(afterSequence: Int64(5))), 'bad_request');
        await first(pb.ClientEvent(eventId: 'a b', subscribe: pb.SubscribeRequest()), 'bad_request');
        await first(pb.ClientEvent(eventId: 'a', acknowledge: pb.AcknowledgeEvent()), 'bad_state');
      });
    });
  });

  group('revision 6, round 4', () {
    pb.FileReference ref(Uint8List data, {String mime = 'image/png', List<pb.Hash>? hashes, int? size}) =>
        pb.FileReference(
          hashes: hashes ?? [pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data))],
          mimeType: mime,
          sizeBytes: Int64(size ?? data.length),
        );

    Future<void> expectReason(Future<Object?> call, String reason) => expectLater(
          call,
          throwsA(isA<GrpcError>().having((e) => e.trailers?['chat-reason'], 'reason', reason)),
          reason: reason,
        );

    Future<GrpcChannelAndFiles> channel() async {
      await boot();
      final c = ClientChannel(
        '127.0.0.1',
        port: proxy.port,
        options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
      );
      addTearDown(c.shutdown);
      return GrpcChannelAndFiles(c, pb.FileServiceClient(c), pb.ChatServiceClient(c));
    }

    GrpcError notFound() => chatError(StatusCode.notFound, 'not_found');

    test('bad_request with a local copy ahead: read again from 0, then subscribe, once', () async {
      svc.user('a');
      svc.user('b');
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      // The instance was reset: the service has one message that the client does not know.
      svc.msgs
        ..clear()
        ..add(svc.user('new'));
      svc.msgs.removeAt(0);
      proxy.drop();
      await until(() => chat.streaming && chat.messages.length == 1 && chat.messages.single.text == 'new',
          what: 'resync');
      expect(svc.reads.where((r) => r == 0).length, 2, reason: 'one read from 0 at the start, one for the resync');
      expect(chat.streamError, isNull);
    });

    test('bad_request again after the resync: the generic rule, 3 failures, then the error', () async {
      svc.user('a');
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      final seen = <ChatException?>[];
      chat.addListener(() => seen.add(chat.streamError));
      svc.connectError = chatError(StatusCode.invalidArgument, 'bad_request');
      proxy.drop();
      await until(() => chat.streamError != null, what: 'error');
      expect(chat.streamError!.kind, ChatErrorKind.badRequest);
      // One try that resynced, then 3 failures in a row.
      expect(svc.connects, 1 + 1 + 3);
      expect(svc.reads.where((r) => r == 0).length, 2, reason: 'the resync is made once');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(svc.connects, 5, reason: 'the client stopped');
      expect(chat.streaming, isFalse);
    });

    test('another status of the first event: 3 failures stop it; SubscriptionReady resets the count', () async {
      await boot();
      svc.connectErrors.addAll([notFound(), notFound()]);
      await chat.sync();
      await until(() => chat.streaming, what: 'ready after 2 failures');
      expect(svc.connects, 3);
      expect(chat.streamError, isNull);
      svc.connectErrors.addAll([notFound(), notFound(), notFound()]);
      proxy.drop();
      await until(() => chat.streamError != null, what: 'error');
      expect(svc.connects, 6);
      expect(chat.streamError!.kind, ChatErrorKind.badRequest);
      expect(chat.streamError!.reason, 'not_found');
    });

    test('busy: wait the first wait also after a long stream, and never loop with no wait', () async {
      await boot(waits: const [Duration(milliseconds: 300)], stableAfter: const Duration(milliseconds: 30));
      await chat.sync();
      await until(() => chat.streaming);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final t = Stopwatch()..start();
      svc.closeStreamsBusy();
      await until(() => svc.connects == 2 && chat.streaming, what: 'subscribe again');
      expect(t.elapsedMilliseconds, greaterThanOrEqualTo(290));
      // Busy at the first event too: each try waits, and none counts as a failure.
      svc.connectErrors.addAll([
        chatError(StatusCode.unavailable, 'busy'),
        chatError(StatusCode.unavailable, 'busy'),
        chatError(StatusCode.unavailable, 'busy'),
        chatError(StatusCode.unavailable, 'busy'),
      ]);
      t
        ..reset()
        ..start();
      proxy.drop();
      await until(() => chat.streaming && svc.connects == 7, what: 'busy tries');
      expect(t.elapsedMilliseconds, greaterThanOrEqualTo(1100));
      expect(chat.streamError, isNull);
    });

    test('ProtocolError with no event_id: before SubscriptionReady reconnect; after it, ignore', () async {
      svc.user('a');
      svc.protocolErrorsBeforeReady = 1;
      await boot();
      await chat.sync();
      await until(() => svc.connects == 2 && chat.streaming, what: 'reconnect');
      expect(chat.streamError, isNull);
      final reads = svc.reads.length;
      svc.emit(pb.ServerEvent(error: pb.ProtocolError(code: 'bad_request', message: 'ack')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(svc.connects, 2);
      expect(chat.streaming, isTrue);
      expect(svc.reads.length, reads, reason: 'no resync');
    });

    test('a long error text is cut by UTF-8 bytes to 1 024, inside no character', () async {
      final u = svc.user('q');
      svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_FAILED, error: 'é' * 600);
      svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_FAILED, error: 'a' * 1025);
      svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_FAILED, error: '€' * 500);
      svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_FAILED, error: 'ok');
      await boot();
      await chat.sync();
      final errors = [for (final m in chat.messages.skip(1)) m.error!];
      expect(errors[0], 'é' * 512);
      expect(errors[1], 'a' * 1024);
      expect(errors[2], '€' * 341);
      expect(errors[3], 'ok');
    });

    test('the fake: a later file is found after size, type and storage (55c, 55e)', () async {
      final c = await channel();
      final data = bytes(100);
      Stream<pb.UploadFileRequest> twice(pb.FileReference r) async* {
        yield pb.UploadFileRequest(file: r);
        yield pb.UploadFileRequest(chunk: data);
        yield pb.UploadFileRequest(file: r);
      }

      // 55e: valid, with a second file.
      await expectReason(c.files.uploadFile(twice(ref(data))), 'bad_request');
      final answers = await c.files
          .queryFiles(Stream.value(pb.QueryFilesRequest(hash: pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data)))))
          .toList();
      expect(answers.single.available, isFalse);
      // 55c: size, then type, then storage, each before the second file.
      svc.caps = pb.Capabilities(acceptedMimeTypes: ['image/png'], maxFileBytes: Int64(50));
      await expectReason(c.files.uploadFile(twice(ref(data, mime: 'application/pdf'))), 'too_large');
      svc.caps = pb.Capabilities(acceptedMimeTypes: ['image/png']);
      await expectReason(c.files.uploadFile(twice(ref(data, mime: 'application/pdf'))), 'unsupported_media');
      svc.storageFull = true;
      await expectReason(c.files.uploadFile(twice(ref(data))), 'storage_full');
      expect(svc.files, isEmpty);
    });

    test('the fake: an unknown type is not an error (50), no type is (49), 31 bytes is bad_request (49a, 55f)', () async {
      final c = await channel();
      final data = bytes(100);
      final sha = pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data));
      final unknown = pb.Hash(type: [9, 9], value: sha3_256(data));
      final answers = await c.files.queryFiles(Stream.value(pb.QueryFilesRequest(hash: unknown))).toList();
      expect(answers.single.available, isFalse);
      // 49: an empty type is bad_request, first or later, and the type of the earlier hash is not reused.
      final none = pb.QueryFilesRequest(hash: pb.Hash(value: sha3_256(data)));
      await expectReason(c.files.queryFiles(Stream.value(none)).toList(), 'bad_request');
      await expectReason(
        c.files.queryFiles(Stream.fromIterable([pb.QueryFilesRequest(hash: sha), none])).toList(),
        'bad_request',
      );
      // 49a: a SHA3-256 value of 31 bytes, in QueryFiles and in DownloadFile.
      final short = pb.Hash(type: ChatClient.sha3Type, value: bytes(31));
      await expectReason(c.files.queryFiles(Stream.value(pb.QueryFilesRequest(hash: short))).toList(), 'bad_request');
      await expectReason(c.files.downloadFile(pb.DownloadFileRequest(hash: short)).toList(), 'bad_request');
      // 71: DownloadFile with no type.
      await expectReason(
        c.files.downloadFile(pb.DownloadFileRequest(hash: pb.Hash(value: sha3_256(data)))).toList(),
        'bad_request',
      );
      // In a FileReference an unknown type is ignored, and the reference needs a known hash.
      Stream<pb.UploadFileRequest> up(pb.FileReference r) async* {
        yield pb.UploadFileRequest(file: r);
        yield pb.UploadFileRequest(chunk: data);
      }

      await expectReason(c.files.uploadFile(up(ref(data, hashes: [unknown]))), 'bad_request');
      await c.files.uploadFile(up(ref(data, hashes: [unknown, pb.Hash(type: ChatClient.sha3Type, value: sha3_256(data))])));
      expect(svc.files.length, 1);
      await expectReason(c.files.uploadFile(up(ref(data, hashes: [short]))), 'bad_request');
      await expectReason(
        c.files.uploadFile(up(ref(data, hashes: [pb.Hash(value: sha3_256(data))]))),
        'bad_request',
      );
    });

    test('the fake: the first event table, and a full queue ends the stream with busy', () async {
      final c = await channel();
      Future<void> first(pb.ClientEvent e, String reason) =>
          expectReason(c.chat.connect(Stream.value(e)).toList(), reason);
      await first(pb.ClientEvent(eventId: 'a', acknowledge: pb.AcknowledgeEvent()), 'bad_state');
      await first(pb.ClientEvent(eventId: 'a b', subscribe: pb.SubscribeRequest()), 'bad_request');
      await first(pb.ClientEvent(eventId: 'a', subscribe: pb.SubscribeRequest(afterSequence: Int64(1))), 'bad_request');
      await first(pb.ClientEvent(eventId: 'a', subscribe: pb.SubscribeRequest(conversationId: 'other')), 'not_found');
      // Queue: 1 000 events are not enough to end the stream, 1 001 are.
      svc.stallQueues = true;
      final out = StreamController<pb.ClientEvent>();
      final got = <pb.ServerEvent>[];
      Object? ended;
      c.chat.connect(out.stream).listen(got.add, onError: (Object e) => ended = e);
      addTearDown(out.close);
      out.add(pb.ClientEvent(eventId: 'a', subscribe: pb.SubscribeRequest()));
      await until(() => svc.openStreams == 1);
      for (var i = 0; i < 1000; i++) {
        svc.emit(pb.ServerEvent(messageProgress: pb.MessageProgress()));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ended, isNull);
      svc.emit(pb.ServerEvent(messageProgress: pb.MessageProgress()));
      await until(() => ended != null, what: 'busy');
      expect((ended! as GrpcError).trailers?['chat-reason'], 'busy');
      expect((ended! as GrpcError).code, StatusCode.unavailable);
    });
  });

  group('close', () {
    test('close ends the stream and the connection, and the listeners get no more', () async {
      svc.user('a');
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      var notices = 0;
      chat.addListener(() => notices++);
      await chat.close();
      await until(() => svc.openStreams == 0, what: 'stream closed');
      svc.emitCreated(svc.user('b'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(notices, 0);
      expect(chat.count, 1);
    });
  });

  group('suggestions and corrector (section 5.7)', () {
    test('a whole answer has its suggestions; the client keeps 3 valid ones', () async {
      final u = svc.user('q');
      svc.assistant('a', replyTo: u.messageId, suggestions: ['Yes', ' No ', 'Yes', 'bad\nline', 'x' * 65, 'More', 'Fourth']);
      await boot();
      await chat.sync();
      expect(chat.messages.last.suggestions, ['Yes', 'No', 'More']);
      // A user message has none.
      expect(chat.messages.first.suggestions, isEmpty);
    });

    test('a streamed answer gets them with COMPLETED, not before', () async {
      final u = svc.user('q');
      final a = svc.assistant('', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS);
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      svc.emitDelta(a.messageId, text: 'Hi');
      await until(() => chat.messages.last.text == 'Hi');
      expect(chat.messages.last.suggestions, isEmpty);
      svc.setStatus(a.messageId, pb.MessageStatus.MESSAGE_STATUS_COMPLETED, suggestions: ['Thanks', 'Again']);
      await until(() => !chat.messages.last.isOpen);
      expect(chat.messages.last.suggestions, ['Thanks', 'Again']);
    });

    test('a FAILED answer and an open answer have none, even if the service sends them', () async {
      final u = svc.user('q');
      svc.assistant('a', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_FAILED, error: 'no', suggestions: ['x']);
      svc.assistant('b', replyTo: u.messageId, status: pb.MessageStatus.MESSAGE_STATUS_IN_PROGRESS, suggestions: ['y']);
      await boot();
      await chat.sync();
      expect(chat.messages[1].suggestions, isEmpty);
      expect(chat.messages[2].suggestions, isEmpty);
    });

    test('the send has the state of the corrector, over the stream and with SendMessage', () async {
      svc.connectError = GrpcError.unimplemented();
      await boot();
      await chat.sync();
      await chat.send('the cat',
          corrector: const CorrectorReport(enabled: true, corrections: [Correction('teh', 'the')]));
      final c = svc.unarySends.single.corrector;
      expect(c.enabled, isTrue);
      expect([for (final x in c.corrections) (x.original, x.replacement)], [('teh', 'the')]);
      // The text is the text that the user sends.
      expect(svc.unarySends.single.content.single.text.text, 'the cat');
      // No state: no field.
      await chat.send('plain');
      expect(svc.unarySends.last.hasCorrector(), isFalse);
    });

    test('over the stream too', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      await chat.send('hi', corrector: const CorrectorReport(enabled: false));
      final sent = svc.streamEvents.where((e) => e.hasSendMessage()).single.sendMessage;
      expect(sent.hasCorrector(), isTrue);
      expect(sent.corrector.enabled, isFalse);
      expect(sent.corrector.corrections, isEmpty);
    });
  });

  group('title (section 6.10)', () {
    test('SubscriptionReady gives the title, and the events change it', () async {
      svc.title = 'Trip to Lisbon';
      await boot();
      var notices = 0;
      chat.addListener(() => notices++);
      expect(chat.titleKnown, isFalse);
      await chat.sync();
      await until(() => chat.titleKnown, what: 'title');
      expect(chat.title, 'Trip to Lisbon');
      // With a stream, the client does not call GetConversation.
      expect(svc.conversationCalls, 0);

      final before = notices;
      svc.setTitle('Lisbon in May');
      await until(() => chat.title == 'Lisbon in May');
      expect(notices, greaterThan(before));
      // The service removes its title.
      svc.setTitle(null);
      await until(() => chat.title == null);
      expect(chat.titleKnown, isTrue);
      // A title of another conversation is not the title of this one.
      svc.emit(pb.ServerEvent(
        conversationTitleChanged: pb.ConversationTitleChanged(conversationId: 'b1', title: 'Other'),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(chat.title, isNull);
      // A title is not a message.
      expect(chat.count, 0);
    });

    test('a service that gives no title: none, and no error', () async {
      await boot();
      await chat.sync();
      await until(() => chat.streaming);
      expect(chat.titleKnown, isTrue);
      expect(chat.title, isNull);
      expect(chat.streamError, isNull);
    });

    test('a service with no Connect: the client reads the title with GetConversation', () async {
      svc.connectError = GrpcError.unimplemented();
      svc.title = 'Notes';
      await boot();
      await chat.sync();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(chat.streaming, isFalse);
      // The first sync tried the stream; the next one knows that there is none.
      await chat.sync();
      expect(chat.title, 'Notes');
      expect(svc.conversationCalls, greaterThan(0));
    });

    test('cleanTitle: one line of plain text, no direction controls, at most 80 characters', () {
      expect(ChatClient.cleanTitle('  Trip\n\tto   Lisbon '), 'Trip to Lisbon');
      expect(ChatClient.cleanTitle('\u202eevil\u202c name\u2066'), 'evil name');
      expect(ChatClient.cleanTitle('a\u0000b\u007fc'), 'a b c');
      expect(ChatClient.cleanTitle(' \n '), isNull);
      expect(ChatClient.cleanTitle(''), isNull);
      final long = 'é' * 100;
      expect(ChatClient.cleanTitle(long), 'é' * ChatClient.titleMaxChars);
      // A character of many code points is not cut in half.
      final flags = '🇪🇸' * 90;
      expect(ChatClient.cleanTitle(flags)!.length, '🇪🇸'.length * ChatClient.titleMaxChars);
    });
  });
}
