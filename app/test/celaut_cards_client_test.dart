import 'dart:io';
import 'dart:typed_data';

import 'package:argus_wallet/celaut/cards_client.dart';
import 'package:argus_wallet/celaut/chat/gen/cards.pb.dart';
import 'package:argus_wallet/celaut/chat/gen/chat.pbgrpc.dart' as pb;
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_cards_service.dart';
import 'support/fake_chat_service.dart' show FakeChatService, TcpProxy;

/// Wait until [ok] is true, or fail after [limit].
Future<void> until(bool Function() ok, {Duration limit = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(limit);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late FakeCardsService svc;
  late TcpProxy proxy;
  late CardsClient client;
  const fast = [Duration(milliseconds: 50), Duration(milliseconds: 100)];

  setUp(() async {
    svc = FakeCardsService();
    proxy = TcpProxy(await svc.start());
    await proxy.start();
    var n = 0;
    client = CardsClient(port: proxy.port, waits: fast, newKey: () => 'k${++n}');
  });

  tearDown(() async {
    await client.close();
    await proxy.stop();
    await svc.stop();
  });

  // docs/celaut/cards.md, section 10.2, tests 21 to 30.

  test('Watch: the first event is the whole deck, then the changes come in order', () async {
    client.start();
    await until(() => client.loaded);
    expect(client.deck.id, 'shopping-list');
    expect(client.deck.cards.map((c) => c.itemId), ['milk', 'bread', 'eggs']);
    expect(client.current!.itemId, 'milk');
    expect(client.actionFor(Direction.DIRECTION_RIGHT)!.id, 'basket');
    expect(client.deck.cards.last.buttons.single.id, 'remove');

    svc.add([Card(itemId: 'tea', title: 'Tea')], before: 'eggs');
    await until(() => client.deck.cards.length == 4);
    expect(client.deck.cards.map((c) => c.itemId), ['milk', 'bread', 'tea', 'eggs']);

    svc.remove(['bread']);
    await until(() => client.deck.cards.length == 3);

    // An old version changes nothing (test 28).
    svc.raw(DeckEvent(version: Int64(1), deckId: 'shopping-list', cardsRemoved: CardsRemoved(itemIds: ['milk'])));
    svc.add([Card(itemId: 'jam', title: 'Jam')]);
    await until(() => client.deck.cards.length == 4);
    expect(client.deck.cards.map((c) => c.itemId), ['milk', 'tea', 'eggs', 'jam']);
  });

  test('a move sends one decision and the next card comes; undo shows the card again', () async {
    client.start();
    await until(() => client.loaded);
    client.act('basket');
    expect(client.current!.itemId, 'bread');
    expect(client.doneCount, 1);
    await until(() => svc.taken.length == 1);
    expect(svc.taken.single.itemId, 'milk');
    expect(svc.taken.single.actionId, 'basket');
    expect(svc.taken.single.undo, isFalse);
    expect(svc.decisions, {'milk': 'basket'});

    expect(client.undo(), 'milk');
    expect(client.current!.itemId, 'milk');
    await until(() => svc.taken.length == 2);
    expect(svc.taken.last.undo, isTrue);
    expect(svc.taken.last.actionId, 'basket');
    expect(svc.decisions, isEmpty);
    expect(client.canUndo, isFalse);
  });

  test('the sound of an action reaches the client, also on a button of a card and on a side that lost its action', () async {
    final deck = svc.shoppingList();
    deck.actions.clear();
    deck.actions.addAll([
      DeckAction(actionId: 'want', label: 'Want', direction: Direction.DIRECTION_RIGHT, sound: Sound.SOUND_SPECIAL),
      DeckAction(actionId: 'also', label: 'Also', direction: Direction.DIRECTION_RIGHT, sound: Sound.SOUND_REJECT),
      DeckAction(actionId: 'no', label: 'No', direction: Direction.DIRECTION_LEFT),
    ]);
    deck.cards.first.buttons
      ..clear()
      ..add(CardButton(actionId: 'remove', label: 'Remove', sound: Sound.SOUND_REJECT));
    svc.replace(deck);
    client.start();
    await until(() => client.deck.actions.length == 3);
    final byId = {for (final a in client.deck.actions) a.id: a};
    expect(byId['want']!.sound, Sound.SOUND_SPECIAL);
    expect(byId['also']!.sound, Sound.SOUND_REJECT); // the second one on a side is a button only
    expect(byId['no']!.sound, Sound.SOUND_DEFAULT);
    expect(client.deck.cards.first.buttons.single.sound, Sound.SOUND_REJECT);
  });

  test('a keep action sends the card to the end of the loop until another action is made', () async {
    final deck = svc.shoppingList();
    deck.actions.clear();
    deck.actions.addAll([
      DeckAction(actionId: 'maybe', label: 'Maybe', direction: Direction.DIRECTION_UP, keep: true),
      DeckAction(actionId: 'want', label: 'Want', direction: Direction.DIRECTION_RIGHT),
      DeckAction(actionId: 'no', label: 'No', direction: Direction.DIRECTION_LEFT),
    ]);
    svc.replace(deck);
    client.start();
    await until(() => client.deck.actions.length == 3);
    expect(client.deck.actions.first.keep, isTrue);

    client.act('maybe'); // milk
    expect(client.current!.itemId, 'bread');
    expect(client.doneCount, 0);
    client.act('maybe'); // bread
    client.act('want'); // eggs
    expect(client.ended, isFalse);
    // The loop: milk comes back first, then bread.
    expect(client.ahead.map((c) => c.itemId), ['milk', 'bread']);
    client.act('maybe'); // milk again: it goes behind bread
    expect(client.ahead.map((c) => c.itemId), ['bread', 'milk']);
    client.act('want');
    client.act('no');
    expect(client.ended, isTrue);

    // A keep decision still goes to the service, in order.
    await until(() => svc.taken.length == 6);
    expect(svc.taken.map((r) => r.actionId), ['maybe', 'maybe', 'want', 'maybe', 'want', 'no']);

    // Undo of a keep brings the card back to its place.
    expect(client.undo(), 'milk');
    expect(client.undo(), 'bread');
    expect(client.undo(), 'milk');
    expect(client.ahead.map((c) => c.itemId), ['milk', 'bread']);
    expect(client.undo(), 'eggs');
    expect(client.ahead.map((c) => c.itemId), ['eggs', 'milk', 'bread']);
    await until(() => svc.taken.length == 10);
  });

  test('with no connection the moves wait, then go in order with their first keys', () async {
    // A relay on a fixed port, like the tunnel: it can go down and come back.
    final relay = _Relay(svc.server!.port!);
    await relay.up();
    var n = 0;
    final c = CardsClient(port: relay.port, waits: fast, newKey: () => 'k${++n}');
    c.start();
    await until(() => c.loaded);
    await relay.down();
    c.act('later');
    c.act('basket');
    c.act('remove');
    // The user goes on: the moves do not wait for the network (section 7).
    expect(c.ended, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(svc.taken, isEmpty);
    expect(c.pending, 3);
    await relay.up();
    await until(() => c.pending == 0, limit: const Duration(seconds: 20));
    expect([for (final r in svc.taken) r.idempotencyKey], ['k1', 'k2', 'k3']);
    expect([for (final r in svc.taken) r.itemId], ['milk', 'bread', 'eggs']);
    expect(svc.decisions, {'milk': 'later', 'bread': 'basket', 'eggs': 'remove'});
    await c.close();
    await relay.down();
  });

  test('a late decision and the same key twice are OK and change nothing', () async {
    client.start();
    await until(() => client.loaded);
    client.act('basket');
    await until(() => client.pending == 0);
    svc.replace(svc.shoppingList(id: 'week-2'));
    await until(() => client.deck.id == 'week-2');
    svc.remove(['milk']);
    await until(() => client.deck.cards.length == 2);
    // A card that the service no longer has (a late swipe).
    client.act('basket', card: const DeckCard(itemId: 'milk', title: 'Milk'));
    await until(() => client.pending == 0);
    expect(svc.taken, hasLength(2));
    expect(svc.decisions, {'milk': 'basket'});
  });

  test('a new deck starts from its first card and undo is empty; a refresh keeps the moves', () async {
    client.start();
    await until(() => client.loaded);
    client.act('basket');
    svc.replace(svc.shoppingList()..title = 'Shopping list (again)');
    await until(() => client.deck.title == 'Shopping list (again)');
    // The same deck: the decision of the client stays.
    expect(client.current!.itemId, 'bread');
    expect(client.canUndo, isTrue);
    svc.replace(svc.shoppingList(id: 'week-2'));
    await until(() => client.deck.id == 'week-2');
    expect(client.current!.itemId, 'milk');
    expect(client.canUndo, isFalse);
    await until(() => client.pending == 0);
  });

  test('a card with a decision of the service is done; the end of the deck', () async {
    final deck = svc.shoppingList();
    deck.cards[0].decision = 'basket';
    svc.deck = deck;
    client.start();
    await until(() => client.loaded);
    expect(client.current!.itemId, 'bread');
    client.act('basket');
    client.act('basket');
    expect(client.ended, isTrue);
    expect(client.current, isNull);
    await until(() => client.pending == 0);
  });

  test('an image is read only when asked, and its hash is checked', () async {
    client.start();
    await until(() => client.loaded);
    expect(svc.downloads, isEmpty);
    final milk = client.deck.cards.first;
    final bytes = await client.image(milk);
    expect(bytes, isNotNull);
    expect(bytes!.length, 64);
    expect(svc.downloads, hasLength(1));
    // From memory the second time.
    await client.image(milk);
    expect(svc.downloads, hasLength(1));
    // Bytes that do not match the hash are not shown.
    svc.files[svc.files.keys.single] = Uint8List.fromList([for (final b in svc.files.values.single) b ^ 1]);
    final other = CardsClient(port: proxy.port, waits: fast);
    other.start();
    await until(() => other.loaded);
    expect(await other.image(other.deck.cards.first), isNull);
    await other.close();
  });

  test('chat.md 5.8: the client reads slot_link of an assistant message, not of a user message', () async {
    final chat = FakeChatService();
    final port = await chat.start();
    final c = ChatClient(port: port, callTimeout: const Duration(seconds: 5));
    pb.ContentPart link(int port, [String? label]) =>
        pb.ContentPart(slotLink: pb.SlotLink(port: port, label: label));
    chat.user('/cards', extra: [link(8081)]);
    chat.assistant('Your list is ready.', replyTo: 'm1', extra: [link(8081, 'Open the list'), link(0), link(8081, 'Open the list')]);
    await c.sync();
    final m = c.messages;
    expect(m[0].slotLinks, isEmpty);
    expect(m[1].slotLinks, [const ChatSlotLink(port: 8081, label: 'Open the list')]);
    expect(m[1].text, 'Your list is ready.');
    await c.close();
    await chat.stop();
  });

  test('cards and actions that break the rules are dropped; a bad deck id is no deck', () async {
    final deck = svc.shoppingList()
      ..cards.add(Card(itemId: 'bad id', title: 'x'))
      ..cards.add(Card(itemId: 'empty', title: '  '))
      ..actions.add(DeckAction(actionId: 'other', label: 'Other', direction: Direction.DIRECTION_LEFT));
    svc.deck = deck;
    client.start();
    await until(() => client.loaded);
    expect(client.deck.cards.map((c) => c.itemId), ['milk', 'bread', 'eggs']);
    // Two actions on one side: the first one keeps it; the other is a button.
    expect(client.actionFor(Direction.DIRECTION_LEFT)!.id, 'later');
    expect(client.deck.actions.map((a) => a.id), contains('other'));
    svc.replace(Deck(deckId: 'no good!', cards: [Card(itemId: 'a', title: 'A')]));
    await until(() => client.deck.id.isEmpty);
  });
}

/// A TCP relay on a fixed local port to [target]. [down] closes the port and every
/// connection; [up] opens the same port again.
class _Relay {
  _Relay(this.target);

  final int target;
  int port = 0;
  ServerSocket? _listen;
  final _sockets = <Socket>[];

  Future<void> up() async {
    _listen = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    port = _listen!.port;
    _listen!.listen((client) async {
      final Socket server;
      try {
        server = await Socket.connect(InternetAddress.loopbackIPv4, target);
      } on Object {
        client.destroy();
        return;
      }
      _sockets
        ..add(client)
        ..add(server);
      client.listen(server.add, onDone: server.destroy, onError: (_) => server.destroy());
      server.listen(client.add, onDone: client.destroy, onError: (_) => client.destroy());
    });
  }

  Future<void> down() async {
    for (final s in _sockets) {
      s.destroy();
    }
    _sockets.clear();
    await _listen?.close();
    _listen = null;
  }
}
