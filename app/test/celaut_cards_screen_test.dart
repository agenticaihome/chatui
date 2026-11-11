import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/cards_client.dart';
import 'package:argus_wallet/celaut/chat/gen/cards.pb.dart' as cpb;
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/chat_done_watcher.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:argus_wallet/celaut/conversations.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/cards_screen.dart';
import 'package:argus_wallet/ui/celaut/chat_screen.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

cpb.Deck _deck({String id = 'shopping-list'}) => cpb.Deck(
      deckId: id,
      title: 'Shopping list',
      showProgress: true,
      actions: [
        cpb.DeckAction(actionId: 'later', label: 'Not yet', icon: cpb.Icon.ICON_LATER, direction: cpb.Direction.DIRECTION_LEFT),
        cpb.DeckAction(
          actionId: 'basket',
          label: 'In the basket',
          icon: cpb.Icon.ICON_CART,
          tone: cpb.Tone.TONE_POSITIVE,
          direction: cpb.Direction.DIRECTION_RIGHT,
        ),
      ],
      cards: [
        cpb.Card(itemId: 'milk', title: 'Milk', text: '2 litres', group: 'Dairy'),
        cpb.Card(itemId: 'bread', title: 'Bread', group: 'Bakery', detail: 'Whole grain, sliced.'),
        cpb.Card(
          itemId: 'eggs',
          title: 'Eggs',
          buttons: [cpb.CardButton(actionId: 'remove', label: 'Remove', tone: cpb.Tone.TONE_NEGATIVE)],
        ),
      ],
    );

/// A deck screen with no network: the events come from [events], the decisions go to [sent].
class _Harness {
  final events = StreamController<cpb.DeckEvent>();
  final sent = <cpb.SendActionRequest>[];
  late final CardsClient client = CardsClient(
    port: 0,
    watchOverride: () => events.stream,
    sendOverride: (r) async => sent.add(r),
  );
  int _version = 0;

  void push(cpb.Deck deck) => events.add(cpb.DeckEvent(version: Int64(++_version), deckId: deck.deckId, deck: deck));

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CardsScreen(title: 'Echo', client: client),
    ));
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await client.close();
    await events.close();
  }
}

InstanceListView _instance({List<int> cards = const [8081], List<int> web = const []}) => InstanceListView(
      instanceId: 'i1',
      peerId: 'aa' * 32,
      address: 'node.example:53460',
      serviceId: '65' * 32,
      slots: Uint16List.fromList([8080, ...cards, ...web]),
      chatSlots: Uint16List.fromList([8080]),
      cardsSlots: Uint16List.fromList(cards),
      webSlots: Uint16List.fromList(web),
      startedAt: 1760000000,
      startChargeMu: '1000',
      refundMu: '',
      name: 'Echo',
      alias: '',
      title: '',
    );

void main() {
  group('deck', () {
    late _Harness h;
    setUp(() => h = _Harness());

    testWidgets('waits for the deck, then shows the first card, the count and a button for each action',
        (tester) async {
      await h.open(tester);
      expect(find.byKey(const Key('cards-loading')), findsOneWidget);
      h.push(_deck());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('cards-card-milk')), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('DAIRY'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.byKey(const Key('cards-action-later')), findsOneWidget);
      expect(find.byKey(const Key('cards-action-basket')), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('a swipe to the right sends its action and the next card comes', (tester) async {
      await h.open(tester);
      h.push(_deck());
      await tester.pump();
      await tester.pump();
      await tester.drag(find.byKey(const Key('cards-card-milk')), const Offset(500, 0));
      await tester.pump();
      expect(h.sent.single.itemId, 'milk');
      expect(h.sent.single.actionId, 'basket');
      expect(h.sent.single.deckId, 'shopping-list');
      expect(h.sent.single.idempotencyKey, isNotEmpty);
      expect(find.byKey(const Key('cards-card-bread')), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('a short drag goes back and sends nothing', (tester) async {
      await h.open(tester);
      h.push(_deck());
      await tester.pump();
      await tester.pump();
      await tester.drag(find.byKey(const Key('cards-card-milk')), const Offset(30, 0));
      await tester.pump();
      expect(h.sent, isEmpty);
      expect(find.byKey(const Key('cards-card-milk')), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('the buttons and the arrow keys make the same decisions as a swipe', (tester) async {
      await h.open(tester);
      h.push(_deck());
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('cards-action-later')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      // The card's own button.
      await tester.tap(find.byKey(const Key('cards-action-remove')));
      await tester.pump();
      expect([for (final r in h.sent) '${r.itemId}:${r.actionId}'], ['milk:later', 'bread:basket', 'eggs:remove']);
      expect(find.byKey(const Key('cards-end')), findsOneWidget);
      expect(find.byKey(const Key('cards-back')), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('a press shows the detail in the card, another press hides it; no decision is sent', (tester) async {
      await h.open(tester);
      final deck = _deck();
      deck.cards.removeAt(0);
      h.push(deck);
      await tester.pump();
      await tester.pump();
      expect(find.text('Whole grain, sliced.'), findsNothing);
      await tester.tap(find.byKey(const Key('cards-card-bread')));
      await tester.pump();
      expect(find.byKey(const Key('cards-expanded-bread')), findsOneWidget);
      expect(find.text('Whole grain, sliced.'), findsOneWidget);
      expect(h.sent, isEmpty);
      await tester.tap(find.byKey(const Key('cards-card-bread')));
      await tester.pump();
      expect(find.byKey(const Key('cards-expanded-bread')), findsNothing);
      expect(find.text('Whole grain, sliced.'), findsNothing);
      await tester.longPress(find.byKey(const Key('cards-card-bread')));
      await tester.pump();
      expect(find.text('Whole grain, sliced.'), findsOneWidget);
      // An action closes it and the next card comes, with its texts hidden.
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      expect(h.sent.single.itemId, 'bread');
      expect(find.byKey(const Key('cards-card-eggs')), findsOneWidget);
      expect(find.byKey(const Key('cards-expanded-eggs')), findsNothing);
      await h.close(tester);
    });

    // Opens the deck from a page and gives what the page gets when the deck closes.
    Future<List<Object?>> openFrom(WidgetTester tester, cpb.Deck deck) async {
      final results = <Object?>[];
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open'),
            onPressed: () async => results.add(await Navigator.of(context)
                .push<Object>(MaterialPageRoute(builder: (_) => CardsScreen(title: 'Echo', client: h.client)))),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      h.push(deck);
      await tester.pump();
      await tester.pump();
      return results;
    }

    testWidgets('the button of the end gives the done_text of the deck to the chat', (tester) async {
      final deck = _deck()..doneText = 'I answered';
      deck.cards.removeWhere((c) => c.itemId != 'milk');
      final results = await openFrom(tester, deck);
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      expect(find.byKey(const Key('cards-end')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cards-back')));
      await tester.pumpAndSettle();
      expect(results, ['I answered']);
      await h.close(tester);
    });

    testWidgets('with no done_text, or with the back arrow, the chat gets nothing', (tester) async {
      final deck = _deck();
      deck.cards.removeWhere((c) => c.itemId != 'milk');
      var results = await openFrom(tester, deck);
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cards-back')));
      await tester.pumpAndSettle();
      expect(results, [null]);
      await h.close(tester);

      // A deck with a text, left by the back arrow.
      h = _Harness();
      final withText = _deck()..doneText = 'I answered';
      withText.cards.removeWhere((c) => c.itemId != 'milk');
      results = await openFrom(tester, withText);
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(results, [null]);
      await h.close(tester);
    });

    testWidgets('undo sends an undo and shows the card again', (tester) async {
      await h.open(tester);
      h.push(_deck());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('cards-undo')), findsNothing);
      await tester.tap(find.byKey(const Key('cards-action-basket')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cards-undo')));
      await tester.pump();
      expect(h.sent.last.undo, isTrue);
      expect(h.sent.last.itemId, 'milk');
      expect(h.sent.last.actionId, 'basket');
      expect(find.byKey(const Key('cards-card-milk')), findsOneWidget);
      await h.close(tester);
    });

    testWidgets('the service refreshes the deck while it is on screen, and an empty deck id is "no cards"',
        (tester) async {
      await h.open(tester);
      h.push(_deck());
      await tester.pump();
      await tester.pump();
      h.push(_deck()..cards.insert(0, cpb.Card(itemId: 'tea', title: 'Tea')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('cards-card-tea')), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      h.push(cpb.Deck());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('cards-none')), findsOneWidget);
      await h.close(tester);
    });
  });

  group('slot link of the chat (chat.md 5.8)', () {
    test('a button only for a cards slot or a web slot of the instance', () {
      final i = _instance(web: [3000]);
      expect(slotLinkButtonKind(i, const ChatSlotLink(port: 8081)), SlotKind.cards);
      expect(slotLinkButtonKind(i, const ChatSlotLink(port: 3000)), SlotKind.web);
      // The conversation itself, and a port that is not a slot of the instance.
      expect(slotLinkButtonKind(i, const ChatSlotLink(port: 8080)), isNull);
      expect(slotLinkButtonKind(i, const ChatSlotLink(port: 9999)), isNull);
    });

    testWidgets('the message shows a button; the deck opens only after a tap', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final opened = <int>[];
      final chat = _LinkChat();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          instance: _instance(),
          port: 1,
          chat: chat,
          wallets: _Wallets(),
          keepAlive: _KeepAlive(),
          typewriter: false,
          watcher: ChatDoneWatcher(
            holds: ForegroundHolds(isAndroid: false),
            isMuted: (_) => false,
            timer: (d, f) => _NoTimer(),
            connect: (_) async => throw Exception('no tunnel in this test'),
          ),
          notes: ConversationNotes(),
          loadStatus: (_) async =>
              InstanceStatusView(instanceBalanceMu: '900', costSoFarMu: '100', streamsOpened: BigInt.one),
          // The tunnel never opens in this test: the deck page waits.
          openTunnel: (id, slot) {
            opened.add(slot);
            return Completer<int>().future;
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-slot-link-2-8081')), findsOneWidget);
      expect(find.text('Open the list'), findsOneWidget);
      // No button for a port that is not a slot of the instance.
      expect(find.byKey(const Key('chat-slot-link-2-9999')), findsNothing);
      expect(opened, isEmpty);
      expect(find.byKey(const Key('cards-screen')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-slot-link-2-8081')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opened, [8081]);
      expect(find.byKey(const Key('cards-screen')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// A chat client with no network: one answer that points to the cards slot 8081, and to a
/// port that is not a slot.
class _LinkChat extends ChatClient {
  _LinkChat() : super(port: 0);

  final _messages = [
    const ChatMessage(seq: 1, role: 'user', text: '/cards', id: 'm1'),
    const ChatMessage(
      seq: 2,
      role: 'assistant',
      text: 'Your shopping list is ready.',
      id: 'm2',
      slotLinks: [ChatSlotLink(port: 8081, label: 'Open the list'), ChatSlotLink(port: 9999)],
    ),
  ];

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  @override
  int get count => _messages.length;
  @override
  bool get streaming => true;
  @override
  bool get awaitingAnswer => false;
  @override
  Future<void> sync() async {}
  @override
  Future<void> syncWhenStarted({Duration limit = const Duration(minutes: 2), Future<void> Function(Duration)? wait}) async {}
}

class _KeepAlive implements ConversationKeepAlive {
  @override
  Future<void> start() async {}
  @override
  Future<void> waiting(bool on) async {}
  @override
  Future<void> stop() async {}
}

class _Wallets implements FullWallets {
  @override
  Future<List<PayerWallet>> payers() async => const [];
  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async => true;
}

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}
