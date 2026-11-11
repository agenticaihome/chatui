import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

import 'chat/gen/cards.pbgrpc.dart' as cpb;
import 'chat/gen/chat.pbgrpc.dart' as pb;
import 'chat_client.dart' show ChatClient;
import 'sha3.dart';

/// An action of a deck or a button of a card (`docs/celaut/cards.md`, section 5.3).
@immutable
class CardsAction {
  const CardsAction({
    required this.id,
    required this.label,
    this.icon = cpb.Icon.ICON_NONE,
    this.tone = cpb.Tone.TONE_NEUTRAL,
    this.direction = cpb.Direction.DIRECTION_NONE,
    this.keep = false,
  });

  final String id;
  final String label;
  final cpb.Icon icon;
  final cpb.Tone tone;

  /// The side of a swipe that makes this action. [cpb.Direction.DIRECTION_NONE] for a button
  /// only, and for each button of a card.
  final cpb.Direction direction;

  /// The card is not done with this action: it goes to the end of the deck and comes back
  /// after the other cards, until the user makes an action that is not a keep.
  final bool keep;
}

/// One card of a deck (`docs/celaut/cards.md`, section 5.2), with its texts cut to the
/// limits of section 8.
@immutable
class DeckCard {
  const DeckCard({
    required this.itemId,
    required this.title,
    this.text = '',
    this.image,
    this.altText = '',
    this.detail = '',
    this.buttons = const [],
    this.tone = cpb.Tone.TONE_NEUTRAL,
    this.layout = cpb.Layout.LAYOUT_IMAGE_TOP,
    this.group = '',
    this.decision,
  });

  final String itemId;
  final String title;
  final String text;

  /// The SHA3-256 digest of the image and its size, or null if the card has no image that
  /// the client can read (`docs/celaut/cards.md`, section 6.3).
  final ({Uint8List hash, int size})? image;
  final String altText;
  final String detail;
  final List<CardsAction> buttons;
  final cpb.Tone tone;
  final cpb.Layout layout;
  final String group;

  /// The decision that the service has for this card, if any.
  final String? decision;
}

/// The deck of a cards slot. An empty [id] is "no deck".
@immutable
class CardsDeck {
  const CardsDeck({
    this.id = '',
    this.title = '',
    this.actions = const [],
    this.cards = const [],
    this.showProgress = false,
    this.endText = '',
  });

  final String id;
  final String title;
  final List<CardsAction> actions;
  final List<DeckCard> cards;
  final bool showProgress;
  final String endText;

  CardsDeck copyWith({List<DeckCard>? cards}) => CardsDeck(
        id: id,
        title: title,
        actions: actions,
        cards: cards ?? this.cards,
        showProgress: showProgress,
        endText: endText,
      );
}

/// The client of the cards interface for one slot of an instance (`docs/celaut/cards.md`):
/// gRPC over HTTP/2 in clear text, on the local port of the tunnel of the node, as
/// [ChatClient].
///
/// [start] opens `Watch` and keeps it open: the first event replaces the deck and the
/// next ones change it ([deck], [version]). [act] and [undo] mark the card in the client at
/// once and put a `SendAction` in a queue that goes out in order, one at a time, and
/// that waits while the slot cannot be reached (section 7). Images are read with
/// `FileService.DownloadFile` only when [image] asks for them (section 6.3).
class CardsClient extends ChangeNotifier {
  CardsClient({
    required this.port,
    this.waits = ChatClient.startWaits,
    this.callTimeout = const Duration(seconds: 30),
    this.fileTimeout = const Duration(seconds: 120),
    DateTime Function()? now,
    String Function()? newKey,
    this.watchOverride,
    this.sendOverride,
  })  : _now = now ?? DateTime.now,
        _newKey = newKey ?? (() => const Uuid().v4().replaceAll('-', ''));

  /// The local port of the cards slot of the instance (`celautOpenTunnel`).
  final int port;

  /// The waits before each new try to open `Watch`, and to send the queue again.
  final List<Duration> waits;
  final Duration callTimeout;
  final Duration fileTimeout;
  final DateTime Function() _now;
  final String Function() _newKey;

  /// In place of `Watch` and `SendAction` on the port: tests give their own.
  @visibleForTesting
  final Stream<cpb.DeckEvent> Function()? watchOverride;
  @visibleForTesting
  final Future<void> Function(cpb.SendActionRequest request)? sendOverride;

  /// Limits of `docs/celaut/cards.md`, section 8.
  static const maxCards = 500;
  static const maxActions = 8;
  static const maxButtons = 4;
  static const maxImageBytes = 4 * 1024 * 1024;
  static const maxCachedBytes = 24 * 1024 * 1024;

  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  ClientChannel? _channel;
  ClientChannel get _ch => _channel ??= ClientChannel(
        '127.0.0.1',
        port: port,
        options: ChannelOptions(
          credentials: const ChannelCredentials.insecure(),
          // One connection for the whole deck: each one costs a tunnel stream.
          idleTimeout: null,
          connectionTimeout: const Duration(days: 365),
          codecRegistry: CodecRegistry(codecs: const [IdentityCodec()]),
        ),
      );
  late final cpb.CardsServiceClient _cards = cpb.CardsServiceClient(_ch);
  late final pb.FileServiceClient _files = pb.FileServiceClient(_ch);

  CardsDeck _deck = const CardsDeck();
  int _version = 0;
  bool _loaded = false;
  bool _watching = false;
  bool _closed = false;
  bool _started = false;
  bool _stopWatch = false;
  final Completer<void> _closing = Completer<void>();
  ResponseStream<cpb.DeckEvent>? _call;

  /// The decisions of this client for the cards of [deck]: an action id, or '' after an
  /// undo. They win over [DeckCard.decision] while the deck has the same id.
  final Map<String, String> _local = {};

  /// The decisions of the user in this deck, for undo: the last one is at the end.
  final List<({String itemId, String actionId, int? turn})> _history = [];

  /// For each card that a keep action sent to the end: its turn. A higher turn is later in
  /// the loop. A card with no turn keeps its place in the deck.
  final Map<String, int> _turns = {};
  int _turn = 0;

  final Queue<cpb.SendActionRequest> _queue = Queue();
  bool _sending = false;

  final LinkedHashMap<String, Uint8List> _images = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _reading = {};
  int _imageBytes = 0;

  /// The deck now. Before the first event, an empty deck ([loaded] is false).
  CardsDeck get deck => _deck;

  /// The version of the state of the service that [deck] shows.
  int get version => _version;

  /// The client has the first event of `Watch`.
  bool get loaded => _loaded;

  /// `Watch` is open.
  bool get watching => _watching;

  /// The decisions that wait in the queue.
  int get pending => _queue.length;

  bool _isKeep(String actionId) {
    for (final a in _deck.actions) {
      if (a.id == actionId) return a.keep;
    }
    return false;
  }

  /// A card is done with a decision that is not a keep action.
  bool isDone(DeckCard card) {
    final mine = _local[card.itemId];
    final id = mine ?? card.decision ?? '';
    return id.isNotEmpty && !_isKeep(id);
  }

  /// The cards in the order of the loop: the ones that no keep action moved, in the order of
  /// the deck, then the ones that it moved, the oldest first.
  List<DeckCard> get _loop {
    final cards = [..._deck.cards];
    if (_turns.isEmpty) return cards;
    final index = {for (var i = 0; i < cards.length; i++) cards[i].itemId: i};
    cards.sort((a, b) {
      final t = (_turns[a.itemId] ?? 0).compareTo(_turns[b.itemId] ?? 0);
      return t != 0 ? t : index[a.itemId]!.compareTo(index[b.itemId]!);
    });
    return cards;
  }

  /// The first card that is not done, or null at the end of the deck.
  DeckCard? get current {
    for (final card in _loop) {
      if (!isDone(card)) return card;
    }
    return null;
  }

  /// The cards that are not done, in order: the current card first.
  List<DeckCard> get ahead => [for (final c in _loop) if (!isDone(c)) c];

  int get doneCount => _deck.cards.where(isDone).length;

  /// The deck has cards, and all are done (section 7, end of the deck).
  bool get ended => _loaded && _deck.id.isNotEmpty && current == null;

  bool get canUndo => _history.isNotEmpty;

  /// The action of [direction] in the deck, if any.
  CardsAction? actionFor(cpb.Direction direction) {
    if (direction == cpb.Direction.DIRECTION_NONE) return null;
    for (final a in _deck.actions) {
      if (a.direction == direction) return a;
    }
    return null;
  }

  /// Open `Watch`, and keep it open until [close].
  void start() {
    if (_started || _closed) return;
    _started = true;
    unawaited(_watchLoop());
  }

  Future<void> _watchLoop() async {
    var fails = 0;
    while (!_closed && !_stopWatch) {
      final opened = DateTime.now();
      try {
        final Stream<cpb.DeckEvent> call;
        if (watchOverride case final watch?) {
          call = watch();
        } else {
          call = _call = _cards.watch(cpb.WatchRequest());
        }
        await for (final event in call) {
          if (!_watching) {
            _watching = true;
            notifyListeners();
          }
          _apply(event);
        }
      } catch (_) {
        // The stream ends: try again below.
      }
      _call = null;
      if (_closed || _stopWatch) return;
      if (_watching) {
        _watching = false;
        notifyListeners();
      }
      // A stream that stayed open is not a failure: the next try has the first wait.
      if (DateTime.now().difference(opened) > const Duration(seconds: 10)) fails = 0;
      await _pause(waits[min(fails++, waits.length - 1)]);
    }
  }

  Future<void> _pause(Duration d) => Future.any([Future<void>.delayed(d), _closing.future]);

  void _apply(cpb.DeckEvent e) {
    final v = e.version.toInt();
    // An event that the client has, or an older one, changes nothing (section 6.1).
    if (_loaded && v <= _version) return;
    switch (e.whichEvent()) {
      case cpb.DeckEvent_Event.deck:
        final next = _deckOf(e.deck);
        if (next.id != _deck.id) {
          _local.clear();
          _history.clear();
          _turns.clear();
        }
        _deck = next;
      case cpb.DeckEvent_Event.cardsAdded when e.deckId == _deck.id:
        final cards = [..._deck.cards];
        final known = {for (final c in cards) c.itemId};
        final add = [
          for (final c in e.cardsAdded.cards.map(_cardOf).whereType<DeckCard>())
            if (known.add(c.itemId)) c,
        ];
        final at = e.cardsAdded.hasBeforeItemId()
            ? cards.indexWhere((c) => c.itemId == e.cardsAdded.beforeItemId)
            : -1;
        cards.insertAll(at < 0 ? cards.length : at, add);
        _deck = _deck.copyWith(cards: cards.take(maxCards).toList());
      case cpb.DeckEvent_Event.cardsRemoved when e.deckId == _deck.id:
        final gone = e.cardsRemoved.itemIds.toSet();
        _deck = _deck.copyWith(cards: [for (final c in _deck.cards) if (!gone.contains(c.itemId)) c]);
      case cpb.DeckEvent_Event.cardMoved when e.deckId == _deck.id:
        final cards = [..._deck.cards];
        final from = cards.indexWhere((c) => c.itemId == e.cardMoved.itemId);
        if (from >= 0) {
          final card = cards.removeAt(from);
          final at = e.cardMoved.hasBeforeItemId()
              ? cards.indexWhere((c) => c.itemId == e.cardMoved.beforeItemId)
              : -1;
          cards.insert(at < 0 ? cards.length : at, card);
          _deck = _deck.copyWith(cards: cards);
        }
      case cpb.DeckEvent_Event.cardChanged when e.deckId == _deck.id:
        final card = _cardOf(e.cardChanged.card);
        if (card != null) {
          _deck = _deck.copyWith(
            cards: [for (final c in _deck.cards) c.itemId == card.itemId ? card : c],
          );
        }
      default:
        // An event for another deck, or a kind of a newer revision.
        break;
    }
    _version = max(_version, v);
    _loaded = true;
    notifyListeners();
  }

  static String _line(String s, int maxChars) {
    final one = s.replaceAll(RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]'), ' ').trim();
    return one.length <= maxChars ? one : one.substring(0, maxChars).trimRight();
  }

  static String _cut(String s, int maxBytes) {
    // Byte limits of section 8, applied in characters: a client can cut for display.
    return s.length <= maxBytes ? s : s.substring(0, maxBytes);
  }

  static CardsAction? _actionOf(String id, String label, cpb.Icon icon, cpb.Tone tone,
      [cpb.Direction direction = cpb.Direction.DIRECTION_NONE, bool keep = false]) {
    final text = _line(label, 32);
    if (!_id.hasMatch(id) || text.isEmpty) return null;
    return CardsAction(id: id, label: text, icon: icon, tone: tone, direction: direction, keep: keep);
  }

  CardsDeck _deckOf(cpb.Deck d) {
    // A deck with a bad id is shown as no deck (section 6.1).
    if (!_id.hasMatch(d.deckId)) return const CardsDeck();
    final actions = <CardsAction>[];
    final sides = <cpb.Direction>{};
    for (final a in d.actions) {
      if (actions.length == maxActions) break;
      final action = _actionOf(a.actionId, a.label, a.icon, a.tone, a.direction, a.keep);
      if (action == null || actions.any((x) => x.id == action.id)) continue;
      // Two actions on one side: the first one keeps it.
      final side = action.direction;
      final keep = side == cpb.Direction.DIRECTION_NONE || sides.add(side);
      actions.add(keep
          ? action
          : CardsAction(id: action.id, label: action.label, icon: action.icon, tone: action.tone, keep: action.keep));
    }
    final cards = <DeckCard>[];
    final ids = <String>{};
    for (final c in d.cards) {
      if (cards.length == maxCards) break;
      final card = _cardOf(c);
      if (card != null && ids.add(card.itemId)) cards.add(card);
    }
    return CardsDeck(
      id: d.deckId,
      title: _line(d.title, 256),
      actions: actions,
      cards: cards,
      showProgress: d.showProgress,
      endText: _cut(d.endText, 1024),
    );
  }

  static DeckCard? _cardOf(cpb.Card c) {
    final title = _line(c.title, 256);
    if (!_id.hasMatch(c.itemId) || title.isEmpty) return null;
    ({Uint8List hash, int size})? image;
    if (c.hasImage()) {
      final f = c.image.file;
      final mime = f.mimeType.toLowerCase().split(';').first.trim();
      final size = f.sizeBytes.toInt();
      if ((mime == 'image/jpeg' || mime == 'image/png') && size > 0 && size <= maxImageBytes) {
        for (final h in f.hashes) {
          if (listEquals(h.type, ChatClient.sha3Type) && h.value.length == 32) {
            image = (hash: Uint8List.fromList(h.value), size: size);
            break;
          }
        }
      }
    }
    return DeckCard(
      itemId: c.itemId,
      title: title,
      text: _cut(c.text, 1024),
      image: c.layout == cpb.Layout.LAYOUT_TEXT ? null : image,
      altText: _line(c.image.altText, 256),
      detail: _cut(c.detail, 16384),
      buttons: [
        for (final b in c.buttons.take(maxButtons)) _actionOf(b.actionId, b.label, b.icon, b.tone),
      ].whereType<CardsAction>().toList(),
      tone: c.tone,
      // IMAGE_FULL with no image is IMAGE_TOP (section 5.4).
      layout: c.layout == cpb.Layout.LAYOUT_IMAGE_FULL && image == null ? cpb.Layout.LAYOUT_IMAGE_TOP : c.layout,
      group: _line(c.group, 64),
      decision: c.hasDecision() && c.decision.isNotEmpty ? c.decision : null,
    );
  }

  /// The user makes [actionId] on [card] (the current card if null): the card is done at
  /// once and the decision goes in the queue.
  void act(String actionId, {DeckCard? card}) {
    final target = card ?? current;
    if (target == null || _closed) return;
    _history.add((itemId: target.itemId, actionId: actionId, turn: _turns[target.itemId]));
    _local[target.itemId] = actionId;
    // A keep action sends the card to the end of the loop.
    if (_isKeep(actionId)) {
      _turns[target.itemId] = ++_turn;
    } else {
      _turns.remove(target.itemId);
    }
    _enqueue(target.itemId, actionId, undo: false);
    notifyListeners();
  }

  /// Undo the last decision of the user in this deck: its card is not done any more, and
  /// an undo goes in the queue (section 6.2). Returns the card, or null.
  String? undo() {
    if (_history.isEmpty || _closed) return null;
    final last = _history.removeLast();
    _local[last.itemId] = '';
    // The card comes back to the place that it had before the decision.
    if (last.turn == null) {
      _turns.remove(last.itemId);
    } else {
      _turns[last.itemId] = last.turn!;
    }
    _enqueue(last.itemId, last.actionId, undo: true);
    notifyListeners();
    return last.itemId;
  }

  void _enqueue(String itemId, String actionId, {required bool undo}) {
    _queue.add(cpb.SendActionRequest(
      deckId: _deck.id,
      itemId: itemId,
      actionId: actionId,
      idempotencyKey: _newKey(),
      undo: undo,
      actedAt: Int64(_now().millisecondsSinceEpoch),
    ));
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_sending) return;
    _sending = true;
    var fails = 0;
    try {
      while (_queue.isNotEmpty && !_closed) {
        try {
          final request = _queue.first;
          await (sendOverride?.call(request) ??
              _cards.sendAction(request, options: CallOptions(timeout: callTimeout)));
          _queue.removeFirst();
          fails = 0;
          notifyListeners();
        } on GrpcError catch (e) {
          if (e.code == StatusCode.invalidArgument) {
            // The service refuses it: sending it again cannot help (section 7).
            _queue.removeFirst();
            notifyListeners();
            continue;
          }
          await _pause(waits[min(fails++, waits.length - 1)]);
        } catch (_) {
          await _pause(waits[min(fails++, waits.length - 1)]);
        }
      }
    } finally {
      _sending = false;
    }
  }

  static String _hex(Uint8List b) => [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

  /// The image of [card], if it has one and it can be read: from memory, or with
  /// `DownloadFile`. The bytes must have the SHA3-256 hash of the card. Null on any failure.
  Future<Uint8List?> image(DeckCard card) {
    final ref = card.image;
    if (ref == null || _closed) return Future.value();
    final key = _hex(ref.hash);
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached; // the most recent at the end
      return Future.value(cached);
    }
    return _reading[key] ??= _download(ref.hash, ref.size).then((bytes) {
      if (bytes != null) _keep(key, bytes);
      return bytes;
    }).whenComplete(() {
      // Not `=> _reading.remove(key)`: that returns this future, which would wait for itself.
      _reading.remove(key);
    });
  }

  /// The image of [card] if it is in memory now.
  Uint8List? cachedImage(DeckCard card) {
    final ref = card.image;
    return ref == null ? null : _images[_hex(ref.hash)];
  }

  Future<Uint8List?> _download(Uint8List hash, int size) async {
    try {
      final builder = BytesBuilder(copy: false);
      final call = _files.downloadFile(
        pb.DownloadFileRequest(hash: pb.Hash(type: ChatClient.sha3Type, value: hash)),
        options: CallOptions(timeout: fileTimeout),
      );
      await for (final part in call) {
        builder.add(part.chunk);
        if (builder.length > maxImageBytes) return null;
      }
      final bytes = builder.takeBytes();
      if (bytes.length != size || !listEquals(sha3_256(bytes), hash)) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _keep(String key, Uint8List bytes) {
    _images[key] = bytes;
    _imageBytes += bytes.length;
    while (_imageBytes > maxCachedBytes && _images.length > 1) {
      final first = _images.keys.first;
      _imageBytes -= _images.remove(first)!.length;
    }
  }

  /// Read the images of the current card and of the next two (section 6.3).
  void prefetch() {
    for (final c in ahead.take(3)) {
      unawaited(image(c));
    }
  }

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }

  /// Stop `Watch`, send what waits in the queue (for at most [limit]), then [close]. The
  /// screen calls it when it goes away: a move that the user made with no connection still
  /// reaches the service when the connection comes back (section 7).
  Future<void> closeWhenSent({Duration limit = const Duration(minutes: 30)}) async {
    if (_closed) return;
    _stopWatch = true;
    await _call?.cancel();
    final end = DateTime.now().add(limit);
    while (_queue.isNotEmpty && !_closed && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await close();
  }

  /// Close `Watch` and the connection. The decisions that wait in the queue are lost.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_closing.isCompleted) _closing.complete();
    await _call?.cancel();
    await _channel?.shutdown();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
