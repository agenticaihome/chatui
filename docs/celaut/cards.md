# Cards interface (gRPC with protobuf)

Revision 1 (2026-11-10), proposal of issue #120. Language: ASD-STE100 (Simplified Technical
English).

This document is the specification of the "cards" interface. A service that follows it can
show a **deck** of cards on the full screen of chatui. The user moves through the cards with a
swipe, a tap on a button or a key. Each move is a **decision** that goes to the service. The
goal is to collect decisions from the user fast: a shopping list in a shop, the triage of
messages, approvals, flash cards, moderation.

The messages and the calls are defined in [cards.proto](cards.proto). It imports
[chat.proto](chat.proto) for `Hash`, `FileReference`, `ImageContent` and `FileService`. This
document gives the rules that the `.proto` files cannot give. If this document and the
comments of `cards.proto` do not agree, this document is right.

Client: `CardsClient` in `app/lib/celaut/cards_client.dart` and `CardsScreen` in
`app/lib/ui/celaut/cards_screen.dart`.

Reference service: the `/cards` command of `echo-chat` (celaut-basics/echo-chat, section 12).

## 1. How to read this document

The requirement words (**must**, **must not**, **can**) and the terms **service**,
**client**, **instance**, **file**, **hash** and **absent** have the meaning of `chat.md`,
section 1. More terms:

| Term | Meaning |
|---|---|
| deck | One `Deck` of `cards.proto`: a `deck_id`, the actions and an ordered list of cards |
| card | One `Card`: an `item_id`, a title and optional text, image, detail, buttons, tone, layout and group |
| action | One `DeckAction` (a swipe direction or a button of the deck) or one `CardButton` (a button of one card). It has an `action_id` |
| decision | One `SendAction` call: `(deck_id, item_id, action_id)` with an `idempotency_key` |
| done card | A card that has a decision: the `decision` of the card, or a decision of the client that the deck has not replaced |
| current card | The first card of the deck, in order, that is not done |
| end of the deck | The state where the deck has no current card |
| version | `DeckEvent.version`: the number of the state of the service after the event |

## 2. Decisions

| Topic | Date | Decision |
|---|---|---|
| A separate interface | 2026-11-10 | Proposal (issue #120). A deck is not a part of `chat.md`: a swipe has no answer and must not start a new turn of the model; a deck is a live state that the service replaces, and the chat history only grows; the images of a deck load on demand. The interface has its own slot, so a client that does not know `cards` never shows it |
| Transport | 2026-11-10 | Proposal. gRPC over h2c, as `chat.md`, sections 3 and 4, on its own slot. The events have a version and the decisions have an `idempotency_key`, so another transport (QUIC, WebRTC) can come later with a new `Protocol` in the stack and the same meaning |
| One deck at a time | 2026-11-10 | Proposal (open question of the issue). A slot shows one deck at a time. A new `deck_id` replaces the old deck. A service that needs two decks at the same time declares two slots |
| Files | 2026-11-10 | Proposal. An image is an `ImageContent` of `chat.proto`. The client reads it with `FileService.DownloadFile` on the same slot, only when it needs it (`chat.md`, section 6.4) |
| Look | 2026-11-10 | Proposal. The service chooses the look only from fixed sets: `Tone` (a role, not a color), `Layout` and `Icon`. The client takes the colors from its theme. No script, no markup, no network resource |
| Pointer from the chat | 2026-11-10 | Proposal. A chat message can point to the slot (`slot_link`, `chat.md`, section 5.8). The app shows a button. The deck opens only when the user taps it |

## 3. Declaration in the service interface

A service follows this interface if its `Service.Api` has one `Slot` with these values
(`nodo:protos/celaut.proto`, `Service.Api.Slot`):

| Field | Value |
|---|---|
| `transport.tags` | contains `tcp` |
| `protocol_stack` | from bottom to top: a `Protocol` with the tag `http2`, above it a `Protocol` with the tag `grpc`, and above it a `Protocol` with the tag `cards` |

The rules of `chat.md`, section 3, apply, with `cards` in place of `chat`:

- A slot counts only if the instance has that port in `Instance.uri_slot`.
- If no slot counts, the client must not show a deck for the instance.
- The service must listen on the port of the slot, and must not use that port for other
  protocols.
- A service can have a `chat` slot and a `cards` slot in the same instance, on two ports.
- The `prose` of the `cards` protocol can describe the deck for the user. The client does not
  parse it.

## 4. Transport

The rules of `chat.md`, section 4, apply: gRPC over HTTP/2 in clear text with prior knowledge
(h2c), no TLS, any `:authority`, one TCP connection for all calls, at least 8 HTTP/2 streams at
the same time, no compression unless the client accepts it, unknown fields and metadata
ignored, `UNIMPLEMENTED` for a call that this document does not define.

- `cards.proto` has no package. The paths are `/CardsService/Watch`,
  `/CardsService/SendAction` and `/FileService/DownloadFile`.
- A service that sends images must implement `FileService.DownloadFile` of `chat.proto` on the
  cards slot, with the rules of `chat.md`, section 6.4. It need not implement `QueryFiles` or
  `UploadFile`: the client of this document does not upload.
- The service must not send a `DeckEvent` of more than 1 MiB. A deck that does not fit is sent
  as a `deck` event with the first cards, then `cards_added` events.
- The client sets no deadline for `Watch`, and a deadline of 30 seconds for `SendAction` and of
  120 seconds for `DownloadFile`.

## 5. Deck and cards

### 5.1 Deck

| Field | Type | Rule |
|---|---|---|
| `deck_id` | string | 1 to 64 characters from `A-Z`, `a-z`, `0-9`, `-` and `_`. An empty `deck_id` means that the service has no deck to show now |
| `title` | string, optional | One line, 256 bytes or less. The client shows it at the top |
| `actions` | `DeckAction`, repeated | 0 to 8 actions. Each `action_id` is unique in the deck. Two actions must not have the same `direction`, except `DIRECTION_NONE` |
| `cards` | `Card`, repeated | 0 to 500 cards, in the order that the user sees them. Each `item_id` is unique in the deck |
| `show_progress` | bool | The client shows the count, for example "12 of 30" |
| `end_text` | string, optional | A text for the end of the deck, 1 024 bytes or less |

### 5.2 Card

| Field | Type | Rule |
|---|---|---|
| `item_id` | string | 1 to 64 characters from `A-Z`, `a-z`, `0-9`, `-` and `_`. Unique in the deck. It must not change when the service sends the deck again |
| `title` | string | One line, 1 to 256 bytes |
| `text` | string, optional | Plain text, 1 024 bytes or less. The client shows it under the title |
| `image` | `ImageContent`, optional | A file of `image/jpeg` or `image/png`, 4 MiB or less, with a SHA3-256 hash (`chat.md`, sections 5.1 and 6.4). `alt_text` is the text for a screen reader |
| `detail` | string, optional | Plain text, 16 384 bytes or less. The client shows it on the card, in place of the image, with a press on the card |
| `buttons` | `CardButton`, repeated | 0 to 4 buttons of this card only |
| `tone` | `Tone` | The role of the color of the card |
| `layout` | `Layout` | The form of the card |
| `group` | string, optional | One line, 64 bytes or less, for example the aisle of the shop. The client shows it on the card |
| `decision` | string, optional | The `action_id` of the decision that the service has for this card. A card with a decision is done |

### 5.3 Actions and buttons

A `DeckAction` is a decision that the user can make on each card. A `CardButton` is a decision
for one card. Both have:

| Field | Rule |
|---|---|
| `action_id` | 1 to 64 characters from `A-Z`, `a-z`, `0-9`, `-` and `_` |
| `label` | 1 to 32 characters, one line. The client shows it on the button, and gives it to a screen reader |
| `icon` | A value of `Icon`. A value that the client does not know is `ICON_NONE` |
| `tone` | A value of `Tone`. A value that the client does not know is `TONE_NEUTRAL` |

A `DeckAction` also has `direction`. With `DIRECTION_LEFT`, `DIRECTION_RIGHT`, `DIRECTION_UP`
or `DIRECTION_DOWN`, a swipe of the card to that side makes the action. With `DIRECTION_NONE`,
the action is only a button.

A `DeckAction` can also have `keep` (`false` by default). With `keep`, the card is **not done**
by the action: it goes to the end of the deck and the client shows it again after the other
cards, until the user makes an action that is not a `keep` on it. The deck is a loop. The client
sends the decision as for any action, so the service knows it (for example "Maybe"). A card
with a `decision` that is a `keep` action is not done either. An undo puts the card back in its
place. A client that does not know `keep` shows the card as done: the field is optional.

**Each action is also a button** (accessibility). The client must show one button for each
`DeckAction`, also for an action with a direction. On a device with a keyboard, the arrow keys
make the action of their direction. A swipe alone is never the only way.

### 5.4 Look

The service cannot draw. It chooses from these sets, and the client maps each value to its
theme (light or dark). A client must support each value of the sets of revision 1.

| Set | Values |
|---|---|
| `Tone` | `NEUTRAL`, `POSITIVE`, `NEGATIVE`, `WARNING`, `ACCENT` |
| `Layout` | `IMAGE_TOP` (image above the text), `IMAGE_FULL` (the image fills the card, the text is on it at the bottom), `TEXT` (no image) |
| `Icon` | `NONE`, `CHECK`, `CLOSE`, `LATER`, `STAR`, `CART`, `ARCHIVE`, `DELETE`, `FLAG`, `INFO` |

- A card with `IMAGE_FULL` and no image is shown as `IMAGE_TOP`.
- The client must not run a script, must not read a network resource, and must not parse
  markup in a text of a deck. Each text is plain text.
- The client must keep the contrast and the size of the text and of the buttons in each theme.

## 6. Calls

### 6.1 Watch

`Watch` gives the state of the deck and its changes.

1. The client calls `Watch` with an empty `WatchRequest`.
2. The service must send first a `DeckEvent` with `deck`: the whole state now, with its
   `version`. With no deck, the `deck` has an empty `deck_id`.
3. Then the service sends one event for each change, in order, while the stream is open.
4. The service must not end the stream to signal a change. It can end the stream with
   `UNAVAILABLE` when it stops.

Each event has `version` and `deck_id`:

- `version` grows with each change and never goes down during the life of the instance. Two
  events must not have the same `version`.
- The client keeps the `version` of its state. It ignores an event with a `version` that is
  not more than its own. So an event that comes twice (for example after a new stream on
  another transport) changes nothing.
- A `deck` event replaces the whole state, with its `deck_id`. A service sends it for a new
  deck, and also for a refresh of the same deck.
- The other events apply to the deck that has their `deck_id`. The client ignores an event for
  another `deck_id`.

| Event | Effect |
|---|---|
| `deck` | Replace the state. A new `deck_id` ends the old deck: the client drops its done marks and its undo for the old deck. The same `deck_id`: the cards are replaced, the client keeps its decisions for the `item_id`s that stay |
| `cards_added` | Put the cards before `before_item_id`, or at the end if it is absent or not in the deck. A card with an `item_id` that is in the deck is ignored |
| `cards_removed` | Remove the cards. An `item_id` that is not in the deck is ignored |
| `card_moved` | Move the card before `before_item_id`, or to the end |
| `card_changed` | Replace the card with the same `item_id`. If it is not in the deck, the client ignores the event |

A card or a deck that breaks a rule of section 5 (for example a bad `item_id`) is ignored by
the client; the other cards stay. A `deck` with a bad `deck_id` is shown as no deck.

**Lost stream.** When `Watch` ends, the client calls it again with the waits of `chat.md`,
section 6.5 (2, 3, 5, 8, then 10 seconds), while the deck is on screen. The first event of the
new stream replaces the state.

### 6.2 SendAction

`SendAction` sends one decision. The service must reply at once, with no wait for a model or
for other work. The reply is empty: a decision gets no answer, and makes no message in the
chat.

| Field | Rule |
|---|---|
| `deck_id`, `item_id` | The deck and the card |
| `action_id` | The action. With `undo`, the action that is undone |
| `idempotency_key` | 1 to 64 characters from `A-Z`, `a-z`, `0-9`, `-` and `_`, unique for each decision of the client |
| `undo` | `true`: the decision undoes the last decision of the card |
| `acted_at` | The time of the move of the user, in milliseconds since 1970-01-01 UTC |

Rules for the service:

- **Late decision.** A decision for a `deck_id` or an `item_id` that the service no longer
  has is not an error. The service must reply `OK` and ignore it (a late swipe).
- **Unknown action.** An `action_id` that is not an action of the deck or a button of the card
  is not an error either: the service replies `OK` and ignores it.
- **Same key.** A decision with an `idempotency_key` that the service has already taken gets
  `OK` and changes nothing.
- **Undo.** An undo is a new decision on the same card. The history of decisions only grows.
  After an undo, the card has no decision. The service can send `card_changed` with no
  `decision`.
- **Order.** The service takes the decisions in the order that they come. The client sends
  them one at a time, in order.
- The service can send `card_changed` with the new `decision` after a decision. It need not.
- A field that breaks the rules of the table (an empty or bad `idempotency_key`, an empty
  `deck_id`, `item_id` or `action_id`) is `INVALID_ARGUMENT` with the reason `bad_request` in
  the trailer `cards-reason`.

### 6.3 Images

A card has the hash of its image, not its bytes. The client reads the image with
`DownloadFile` on the same slot, only when it needs it: for the current card and the next two
cards. The client checks the SHA3-256 hash of the bytes,
and keeps the images in memory only (24 MiB or less). An image that it cannot read or that
fails the check is not shown; the card stays usable.

## 7. Client rules

- **Order.** The client shows the current card on top, and the next cards under it. A move
  marks the current card as done in the client at once, and the next card comes.
- **Detail on the card.** A press on the card (a tap or a long press) shows the group, the
  title, the text and the `detail` in full, on the card and not on another screen. Another
  press hides them. The actions and the buttons of the card stay on screen. A decision hides
  the detail of the card.
- **Queue with no connection.** The client puts each decision in a local queue, in order, and
  sends the queue one decision at a time. If a send fails because the slot cannot be reached,
  the client keeps the decision and sends it again later with the same `idempotency_key`, in
  the same order. The user can go on: the moves do not wait for the network. A decision that
  the service rejects with `INVALID_ARGUMENT` is dropped from the queue. The queue is in memory
  while the app runs.
- **Undo.** The client shows an undo button after the first decision. Undo takes the last
  decision of the user in this deck, sends an undo for its card, and shows that card again as
  the current card. The user can undo more than once, back to the first decision of the
  session.
- **End of the deck.** With no current card, the client shows the end: `end_text` (or a short
  default text), the undo button and a button to go back to the chat. A new deck or a refresh
  with new cards shows cards again.
- **Progress.** With `show_progress`, the client shows the position of the current card: the
  number of done cards plus one, "of" the number of cards.
- **Group.** The client shows the `group` of the card on the card.
- **No deck.** With an empty `deck_id`, the client shows a short text that the service has no
  cards now, and waits for a `deck` event.
- **Open and close.** The deck opens from a pointer in the chat (`chat.md`, section 5.8) or from
  the menu of the conversation. The user can close it at any time and go back to the chat. The
  conversation stays open under the deck: a chat message that comes while the deck is open
  stays in the chat, with its normal notice.

## 8. Limits

| Limit | Value |
|---|---|
| Cards in a deck | 500 |
| Actions of a deck | 8 |
| Buttons of a card | 4 |
| `deck_id`, `item_id`, `action_id`, `idempotency_key` | 64 characters |
| Title of a card | 256 bytes |
| `text` of a card, `end_text` | 1 024 bytes |
| `detail` of a card | 16 384 bytes |
| Label of an action or a button | 32 characters |
| `group` | 64 bytes |
| One `DeckEvent` | 1 MiB |
| One image | 4 MiB |

The client can cut a text that is longer than its limit, for display. It ignores the cards
after the 500th, and the actions and buttons after the limit.

## 9. Errors

Errors are gRPC statuses with the reason in the trailer `cards-reason`, as `chat.md`, section 9
(the trailer has another name, the meaning is the same).

| Status | Reason | When |
|---|---|---|
| `INVALID_ARGUMENT` | `bad_request` | A decision breaks the rules of section 6.2 |
| `UNAVAILABLE` | `busy` | The service cannot take the call now. The client tries again later |
| `UNIMPLEMENTED` | (none) | A call that this document does not define |

The rules of `chat.md`, section 9, for `DownloadFile` apply.

## 10. Conformance

### 10.1 Tests of a service

| # | Test | Expected |
|---|---|---|
| 1 | `Watch` | The first event is `deck`, with a `version` |
| 2 | A change of the deck while `Watch` is open | One event, with a `version` more than the last one |
| 3 | `SendAction` for a card of the deck | `OK` at once, with an empty reply. No chat message is made |
| 4 | The same `SendAction` again (same key) | `OK`. The service counts one decision |
| 5 | `SendAction` for an `item_id` or a `deck_id` that the service does not have | `OK`. Nothing changes |
| 6 | `SendAction` with an empty `idempotency_key` | `INVALID_ARGUMENT`, `bad_request` |
| 7 | `SendAction` with `undo` | `OK`. The card has no decision |
| 8 | `DownloadFile` with the hash of the image of a card | The bytes of the image; their SHA3-256 hash is the hash |
| 9 | `Watch` twice at the same time | Both streams get the same events |

### 10.2 Tests of a client

| # | Test | Expected |
|---|---|---|
| 20 | A slot with `http2`, `grpc`, `cards` | The client can open the deck. A slot without `cards` is not a deck |
| 21 | A swipe to a side with an action | One `SendAction` with that `action_id`; the next card shows |
| 22 | The button of each action | The same decision as the swipe |
| 22a | An action with `keep` | One `SendAction`; the card shows again after the other cards; the end of the deck does not show while a card is kept |
| 23 | A press on the card | The card shows its title, text and `detail` in full; another press hides them; no decision is sent |
| 24 | Undo | One `SendAction` with `undo` for the last card; that card shows again |
| 25 | No connection, three moves, then the connection comes back | Three decisions, in order, each with its first key |
| 26 | A `deck` event with a new `deck_id` | The new deck shows from its first card; undo is empty |
| 27 | `cards_added`, `cards_removed`, `card_moved`, `card_changed` | The deck changes; the current card follows the rules of section 7 |
| 28 | An event with an old `version` | No change |
| 29 | An image of a card that is not on screen | No `DownloadFile` for it |
| 30 | All cards done | The end of the deck shows, with undo and the button to go back |

## 11. Changes to the interface

The tag is `cards` and it has no version. The rules of `chat.md`, section 12, apply: a new field
is optional and has a new number; a new value of `Tone`, `Layout` or `Icon` is permitted,
because a client that does not know it uses the default value of its set (section 5.4).

## 12. Reference service

The echo service (celaut-basics/echo-chat) has a second slot with the stack `http2`, `grpc`,
`cards`. The command `/cards` in the chat makes an answer with a `slot_link` to that slot,
and makes the deck "shopping-list": 8 items in a fixed order, with groups (the aisles), an
image on some cards, the actions "Not yet" (left, `LATER`) and "In the basket" (right,
`CART`, `POSITIVE`), and a "Remove" button on one card. `/cards refresh` sends the deck
again with one new item, and `/cards new` sends a new deck. The service writes each decision
to its log, and gives no chat message for it.

## 13. Last phase: UX of the widget (not normative for the wire)

Issue #120 plans a last phase for the quality of the widget. Everything in it is a feature of
the client: the wire of this document does not change, and the service cannot require any of
it. Revision 1 of chatui has the base widget only (sections 5 to 7). The last phase adds:

- a reflection on the image that follows the gyroscope (low-pass, limited angle) and the
  finger;
- light vibrations at the decision point of a swipe, at the release, at a cancel and at an
  undo;
- transitions for the next card, the end of the deck and a refresh, with a style that the user
  chooses;
- frames that come from the theme of the app;
- motion gestures (a sharp turn of the wrist is a swipe), off by default, armed by the user,
  with a pause after each gesture, a test in the settings, and undo always on screen;
- a group "Cards" in the settings for each effect.

Rules for the last phase: the effects never change the function; "reduce motion" of the system
turns the transitions and the reflections down; vibration follows the haptics setting of the
system; the sensors run only while the deck is on screen, and their data never leaves the
phone; a device with no gyroscope or no vibration motor hides the setting and uses a fallback;
the effects keep 60 frames per second or turn themselves down.

### 13.1 Acceptance check list (client)

| # | Check |
|---|---|
| U1 | Each effect works, and with all effects off the widget works the same |
| U2 | Each setting of the group "Cards" changes only its effect |
| U3 | With no gyroscope: the reflection follows the pointer; with no vibration motor: the setting is hidden |
| U4 | "Reduce motion" of the system turns the transitions and the reflections down by default |
| U5 | Motion gestures are off by default, need to be armed, end by themselves, and show the move on the card |
| U6 | The sensor stops when the deck leaves the screen or the app goes to the background |
| U7 | 60 frames per second on a low-end phone, measured; the effects turn down when the rate falls |
| U8 | The text and the buttons keep their contrast and size in each theme, with a frame |

## 14. Revision history

| Revision | Date | Change |
|---|---|---|
| 1 | 2026-11-10 | Proposal (issue #120). The interface `cards`: slot `http2`, `grpc`, `cards`; `Watch` with versioned events (`deck`, `cards_added`, `cards_removed`, `card_moved`, `card_changed`); `SendAction` with `idempotency_key` and `undo`; images by hash with `FileService` of `chat.proto`; fixed sets for tone, layout and icon; the client queue, undo, end of the deck, progress and groups; the tests of section 10. The pointer from the chat is `chat.md`, revision 6, round 11 |
