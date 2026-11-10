import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:argus_wallet/celaut/chat/gen/cards.pbgrpc.dart';
import 'package:argus_wallet/celaut/chat/gen/chat.pbgrpc.dart' as pb;
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/sha3.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:grpc/grpc.dart';

/// A cards service in memory that follows `docs/celaut/cards.md` (revision 1): the
/// shopping list of issue #120. It serves `CardsService` of `cards.proto` and
/// `FileService.DownloadFile` of `chat.proto` over h2c.
class FakeCardsService {
  FakeCardsService() {
    deck = shoppingList();
  }

  late Deck deck;
  int version = 1;

  /// The decisions that the service took, by key, in order; the keys it saw.
  final taken = <SendActionRequest>[];
  final _keys = <String>{};

  /// What the service has for each card (`decision`), after the decisions.
  final decisions = <String, String>{};

  /// The images, by the hex of their SHA3-256 hash, and the hashes that were read.
  final files = <String, Uint8List>{};
  final downloads = <String>[];

  /// Each call of `SendAction` waits for this, if set (a slow service).
  Completer<void>? hold;

  final _streams = <StreamController<DeckEvent>>[];

  static String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  /// An image of [n] bytes as a card image, kept in [files].
  pb.ImageContent image(int n, {int seed = 1}) {
    final bytes = Uint8List.fromList([for (var i = 0; i < n; i++) (i * 31 + seed) & 0xff]);
    final hash = sha3_256(bytes);
    files[hex(hash)] = bytes;
    return pb.ImageContent(
      file: pb.FileReference(
        hashes: [pb.Hash(type: ChatClient.sha3Type, value: hash)],
        mimeType: 'image/png',
        sizeBytes: Int64(n),
      ),
      altText: 'a picture',
    );
  }

  Deck shoppingList({String id = 'shopping-list'}) => Deck(
        deckId: id,
        title: 'Shopping list',
        showProgress: true,
        endText: 'All done. See you at the checkout.',
        actions: [
          DeckAction(
            actionId: 'later',
            label: 'Not yet',
            icon: Icon.ICON_LATER,
            direction: Direction.DIRECTION_LEFT,
          ),
          DeckAction(
            actionId: 'basket',
            label: 'In the basket',
            icon: Icon.ICON_CART,
            tone: Tone.TONE_POSITIVE,
            direction: Direction.DIRECTION_RIGHT,
          ),
        ],
        cards: [
          Card(itemId: 'milk', title: 'Milk', text: '2 litres', group: 'Dairy', image: image(64)),
          Card(itemId: 'bread', title: 'Bread', group: 'Bakery', detail: 'Whole grain, sliced.'),
          Card(
            itemId: 'eggs',
            title: 'Eggs',
            group: 'Dairy',
            buttons: [CardButton(actionId: 'remove', label: 'Remove', icon: Icon.ICON_DELETE, tone: Tone.TONE_NEGATIVE)],
          ),
        ],
      );

  void _publish(DeckEvent e) {
    for (final s in _streams) {
      s.add(e);
    }
  }

  /// Replace the deck (a refresh or a new deck).
  void replace(Deck next) {
    deck = next;
    _publish(DeckEvent(version: Int64(++version), deckId: deck.deckId, deck: deck));
  }

  void add(List<Card> cards, {String? before}) {
    deck.cards.addAll(cards);
    _publish(DeckEvent(
      version: Int64(++version),
      deckId: deck.deckId,
      cardsAdded: CardsAdded(cards: cards, beforeItemId: before),
    ));
  }

  void remove(List<String> ids) {
    deck.cards.removeWhere((c) => ids.contains(c.itemId));
    _publish(DeckEvent(version: Int64(++version), deckId: deck.deckId, cardsRemoved: CardsRemoved(itemIds: ids)));
  }

  /// Send [e] as it is (for example an old version).
  void raw(DeckEvent e) => _publish(e);

  late final CardsServiceBase cards = _Cards(this);
  late final pb.FileServiceBase file = _Files(this);

  Server? server;
  Future<int> start([int port = 0]) async {
    server = Server.create(services: [cards, file]);
    await server!.serve(address: InternetAddress.loopbackIPv4, port: port);
    return server!.port!;
  }

  Future<void> stop() async {
    for (final s in List.of(_streams)) {
      unawaited(s.close());
    }
    await server?.shutdown().timeout(const Duration(seconds: 2), onTimeout: () {});
    server = null;
  }
}

class _Cards extends CardsServiceBase {
  _Cards(this.s);
  final FakeCardsService s;
  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  @override
  Stream<DeckEvent> watch(ServiceCall call, WatchRequest request) {
    late final StreamController<DeckEvent> c;
    c = StreamController<DeckEvent>(
      onListen: () {
        c.add(DeckEvent(version: Int64(s.version), deckId: s.deck.deckId, deck: s.deck));
        s._streams.add(c);
      },
      onCancel: () => s._streams.remove(c),
    );
    return c.stream;
  }

  @override
  Future<SendActionResponse> sendAction(ServiceCall call, SendActionRequest request) async {
    if (!_id.hasMatch(request.idempotencyKey) || request.deckId.isEmpty || request.itemId.isEmpty || request.actionId.isEmpty) {
      throw GrpcError.custom(StatusCode.invalidArgument, 'bad request', null, null, {'cards-reason': 'bad_request'});
    }
    final hold = s.hold;
    if (hold != null) await hold.future;
    // The same key again: OK, no change (section 6.2).
    if (!s._keys.add(request.idempotencyKey)) return SendActionResponse();
    s.taken.add(request);
    // A late decision, for a deck or a card that the service no longer has: OK, ignored.
    final known = request.deckId == s.deck.deckId && s.deck.cards.any((c) => c.itemId == request.itemId);
    if (known) {
      if (request.undo) {
        s.decisions.remove(request.itemId);
      } else {
        s.decisions[request.itemId] = request.actionId;
      }
    }
    return SendActionResponse();
  }
}

class _Files extends pb.FileServiceBase {
  _Files(this.s);
  final FakeCardsService s;

  @override
  Stream<pb.DownloadFileResponse> downloadFile(ServiceCall call, pb.DownloadFileRequest request) async* {
    if (!listEquals(request.hash.type, ChatClient.sha3Type)) {
      throw const GrpcError.invalidArgument('bad hash');
    }
    final key = FakeCardsService.hex(request.hash.value);
    s.downloads.add(key);
    final bytes = s.files[key];
    if (bytes == null) throw const GrpcError.notFound('no file');
    for (var i = 0; i < bytes.length; i += 16) {
      yield pb.DownloadFileResponse(chunk: bytes.sublist(i, i + 16 > bytes.length ? bytes.length : i + 16));
    }
  }

  @override
  Stream<pb.QueryFilesResponse> queryFiles(ServiceCall call, Stream<pb.QueryFilesRequest> request) =>
      throw const GrpcError.unimplemented();

  @override
  Future<pb.UploadFileResponse> uploadFile(ServiceCall call, Stream<pb.UploadFileRequest> request) =>
      throw const GrpcError.unimplemented();
}
