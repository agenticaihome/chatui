# Chat interface (gRPC with protobuf)

Revision 6 (2026-10-24). Language: ASD-STE100 (Simplified Technical English).

This document is the specification of the "chat" interface. A service that follows it can
be used from the conversation screen of chatui. This document is the only source of truth
for the interface. Each service and each client must adapt to it. If a service or a client
and this document do not agree, the service or the client is wrong.

The messages and the calls are defined in [chat.proto](chat.proto). This document gives the
rules that the `.proto` file cannot give: the meaning of each field, the order of the events,
the limits and the errors. If this document and the comments of `chat.proto` do not agree,
this document is right, and `chat.proto` must be corrected.

Services that must follow this document:

| Service | Repository |
|---|---|
| `echo-chat` (echo service, the check of M4) | celaut-basics/echo-chat |
| Claude remote service | Copa-ai/claude-remote-service |

Client: `ChatClient` in `app/lib/celaut/chat_client.dart`.

The interface is small on purpose. gRPC and the file [chat.proto](chat.proto) are the only
parts that the client and the service share.

## 1. How to read this document

### 1.1 Requirement words

| Word | Meaning |
|---|---|
| must | The rule is a requirement. A service or a client that does not obey it does not follow this document |
| must not | The action is not permitted |
| can | The action is permitted. It is not a requirement |

Text in a table or in a list that does not use these words is a fact or an example.

### 1.2 Terms

| Term | Meaning |
|---|---|
| service | The program in the instance. It answers the calls of this document |
| client | The program that makes the calls. In chatui, the app |
| instance | One running copy of a service. One instance holds one main conversation |
| main conversation | The conversation of the instance. It has no `conversation_id` (section 6.8) |
| message | One `Message` of `chat.proto`: `message_id`, `sequence`, `content`, `status` and other fields (section 5) |
| `sequence` | The position of a message in its conversation. The first message has `sequence` 1 |
| `latest` | The `sequence` of the last message that the service holds. It is 0 if the history is empty |
| content | The `ContentPart` items of a message |
| text of a message | The `text` of the `TextContent` parts of the content, joined in order |
| attachment | A `ContentPart` that is `image`, `audio` or `file` (section 5.1) |
| file | A sequence of bytes that has a hash. A client or a service reads and writes a file with `FileService` (section 6.4) |
| hash | A `Hash` of `chat.proto`. The hash of a file is a SHA3-256 hash (section 6.4) |
| `idempotency_key` | A name that the client gives to a send. It lets the client send again with no risk (section 6.1) |
| send | One `SendMessage` call, or one `send_message` event of `Connect` |
| answer | The assistant message that the service makes for a user message (section 5.2) |
| user message | A message with `from_service` equal to `false` |
| assistant message | A message with `from_service` equal to `true` |
| open message | A message with `status` equal to `PENDING` or `IN_PROGRESS`. Its content and `reasoning` can still grow |
| final message | A message with `status` equal to `COMPLETED`, `FAILED` or `CANCELLED`. It never changes, except for `pinned` (section 5.3) |
| history | The list of all messages of a conversation, in order of `sequence` |
| delta | A `MessageDelta` event (section 5.2) |
| reason | A short name of an error, for example `busy`. The service sends it in the trailer `chat-reason` (section 9) |
| title | A short text that the service gives the conversation, to tell what it is about (section 6.10) |
| suggestion | A short reply that the service proposes to the user after an answer. The user can put it in the input with one tap (section 5.7) |
| corrector | The part of a client that proposes words while the user writes, and changes a word when the user taps one (section 5.7) |
| slot link | A pointer of an assistant message to another slot of the same instance, for example a deck of `cards.md`. The user opens it with a tap (section 5.8) |
| absent | An optional field that is not set. For a string field of this document, an empty string has the same meaning as an absent field (section 5) |

## 2. Decisions

Josemi took each decision on the date in the table. A row with an older date is still valid
if the text of the row is not in conflict with a newer row.

| Topic | Date | Decision (Josemi) |
|---|---|---|
| History | 2026-10-14 | The service keeps the history. The client does not send it with each message |
| Session | 2026-10-14 | One main conversation for each instance. The instance is the conversation. When the instance stops, the conversation ends |
| Synchronization | 2026-10-14 | Each message has a number (`sequence`). The client can ask the service for the history at any time |
| Discovery | 2026-10-14 | The service declares the interface in its `Service.Api` (section 3). There is no discovery call |
| Sends without a wait | 2026-10-23 | A send only gives the message to the service. It does not wait for the answer. The client can send many messages at the same time |
| Streaming | 2026-10-23 | A service can make an answer in parts. A service can also give the `reasoning` of the model. A service that sends the whole answer stays valid |
| Transport | 2026-10-24 | The interface is real gRPC over HTTP/2, defined by `chat.proto`. HTTP/2 is clear text (h2c, no TLS) through the tunnel of the node. HTTP/1.1 with JSON is gone. The `protocol_stack` of the slot is, from bottom to top, `http2`, `grpc`, `chat` (section 3) |
| Real time | 2026-10-24 | The client reads new messages with the bidirectional stream `Connect`, and does not poll. `GetMessages` with `after_sequence` gives the history and the catch-up after a lost stream |
| Streaming events | 2026-10-24 | `chat.proto` has two new events: `MessageDelta` (text and reasoning that grow) and `MessagePinnedChanged`. `Message` has three new fields: `reasoning`, `idempotency_key` and `error`. The content of a message is final when its `status` is final. While the message is open, deltas add text at the end (section 5.2) |
| Capabilities | 2026-10-24 | What a service accepts is in the new call `GetCapabilities`, and not in `Conversation`. The result does not change during the life of the instance (section 6.7) |
| Send key | 2026-10-24 | `cid` of revision 5 is `idempotency_key` of `SendMessageRequest`. The service gives it back in `Message.idempotency_key` (section 6.1) |
| Numbers and states | 2026-10-24 | `sequence` starts at 1 and has no gaps. `streaming` is `PENDING` or `IN_PROGRESS`, `done` is `COMPLETED`, `failed` is `FAILED`. `reply_to` is the `message_id` of the user message (section 5) |
| One instance | 2026-10-24 | One instance holds the main conversation. Branches and other conversations are optional (section 6.8). The service need not implement them, and the client can ignore them |
| Pinned | 2026-10-24 | `pinned` follows `chat.proto`: any message can be pinned, `SetMessagePinned` changes it, and `updated_at` changes with it. The service and the client can both change it (section 6.6). The client keeps the last pinned message above the visible part at the top of the chat (section 5.4) |
| Send over the stream | 2026-10-24 | The client sends over `Connect` when its stream is open, and with the unary `SendMessage` when it is not (for example in the watcher of answers). The two ways use the same `idempotency_key` rules. Each `ClientEvent` can have an `event_id`, and `ProtocolError` gives it back, so that the client knows which event failed (section 6.5) |
| Acknowledge | 2026-10-24 | `acknowledge` is a hint: the client has all messages up to `last_sequence` in a final state. The service can drop buffered events for them. It never deletes history (section 6.5) |
| Cancelled | 2026-10-24 | `CANCELLED` is a final status, as `FAILED`: no notice of a done answer. The client shows it as cancelled. Chatui has no cancel button yet. A service can implement `cancel_message` (optional) |
| Other hash algorithms | 2026-10-24 | SHA3-256 is the algorithm that the client uses and that each service that accepts files must support. The `type` of a `Hash` names the algorithm, so more algorithms can be added later with no change to `chat.proto`. A `FileReference` can have many hashes of the same content (section 6.4) |
| Defaults of the limits | 2026-10-24 | 1 MiB for a message, 4 MiB for a file and 64 KiB for a chunk are defaults. `GetCapabilities` replaces them (sections 6.7 and 7) |
| Wire form of the hash | 2026-10-24 | `Hash.type` and `Hash.value` are the raw bytes of the digest (32 bytes for SHA3-256). The hexadecimal text of the document is only a way to write them (section 6.4) |
| Failure reason | 2026-10-24 | A `FAILED` message has `error` (field 14 of `Message`, field 5 of `MessageStatusChanged`): a short text for the user, 1 024 bytes or less, set once with the status. `metadata["error"]` is not used (section 5.2) |
| Storage and empty files | 2026-10-24 | The new reason `storage_full` (`RESOURCE_EXHAUSTED`) is for an upload that the file store cannot take. `history_full` is for the history only. An empty file is not valid: `bad_request` (sections 5.1 and 6.4) |
| Kind and media type | 2026-10-24 | A `mime_type` that the service does not accept is `unsupported_media` for each kind of part. `bad_request` is only for an `image` part with an `audio/*` type and an `audio` part with an `image/*` type (section 5.1) |
| Details of the interface | 2026-10-24 | The order of checks is the same for a send and for an upload: structure, size, type. Every hash of a `FileReference` has a `type`. An empty string is the same as an absent optional string. A request above the gRPC limit gets `RESOURCE_EXHAUSTED` with no reason, and the client reads it as `too_large`. A service can close a `Connect` stream whose queue is full with `UNAVAILABLE`, reason `busy`. The echo service can stream and can return attachments (sections 5.1, 6.4, 6.5, 9, 14.1) |
| Files by hash | 2026-10-24 | A client and a service send files with `FileService`, identified by hash, and not inside a message. A message holds only a `FileReference` (section 6.4). The hash is SHA3-256. The client asks `QueryFiles` before it uploads a file, and does not upload a file that is already available |
| File limits | 2026-10-24 | The limits of revision 5 stay: 4 files of 4 MiB in one message, and `image/jpeg`, `image/png`, `audio/mpeg`, `audio/wav` (section 7) |
| HTML widgets | 2026-10-24 | A service sends an HTML widget as a fenced block that starts with ```` ```html ```` in a `TextContent`. This stays a client feature that is not normative (section 5.4). `StructuredContent` with `text/html` is not used, because the answer of a model comes as a stream of text and a `StructuredContent` part cannot grow |
| Keyboard block | 2026-10-29 | A service offers keys to the user as a fenced block that starts with ```` ```keyboard ````, in a `TextContent`, as the HTML block. A key has a `data-say`. A tap on a key puts the `data-say` in the input of the user. The client does not send it: the user sends it with Send, unless the key has `data-send`: then a tap sends it. The block can also have fields (`input`): a `{name}` in a `data-say` is the value that the user wrote in the field `name`. Nothing changes on the wire, and the service gets the text as a normal user message (section 5.5) |
| Keyboard controls and keyboard of the app | 2026-10-29 | A field of a keyboard block can be a calendar (`type="date"`), a clock (`type="time"`), a slider (`type="range"`), a checkbox (`type="checkbox"`) or a list of options (`select`, one or many with `multiple`), as well as one line of text. The value of each one is text, and a `{name}` in a `data-say` is that text: the wire does not change. In chatui the form shows **under** the input (not above it), the chat does not open the keyboard of the system, and under the input it shows the form or, if there is none, a keyboard of the app. A setting (off by default) lets the user choose the keyboard of the system. A closed form opens again with a tap on its card (section 5.5) |
| Attachments | 2026-10-22 | A message can have image files and audio files. The client shows the attach button only for the kinds that the service accepts. The files stay in memory only |
| Recorded audio | 2026-10-24 | A client can record sound and send it as `audio/wav`. A service that accepts `audio` must accept `audio/wav` |
| Secret requests | 2026-11-01 | The service can ask the user for a secret by name, for example an API key. The app shows the selector of environment variables (`env-variables.md`, section 3), with a typed value and **Skip**. The user can save a typed value in the container. The service waits until the user answers. The value goes to the service in `AnswerSecretRequest`, and never in a message, an event or the history. The app warns before a sensitive value goes out (sections 5.6 and 6.9) |
| Title (proposal, issue #89) | 2026-11-04 | To review. The service can give the main conversation a title. The title is in `GetConversation`, in `SubscriptionReady` and in the new event `ConversationTitleChanged`. A name that the user gives the conversation in the app is stronger: the title of the service does not replace it, and the app does not send the name of the user to the service. The app keeps the last title, so the list of conversations shows it after a restart (section 6.10) |
| Suggestions and corrector (proposal, issue #88) | 2026-11-04 | To review. An assistant message can have up to 3 `suggestions`: short replies that the client shows above its keyboard. They come with the final status `COMPLETED`, once for each message, and not while the user writes: the text that the user writes does not go to the service before Send. The corrector of the client is local. Each send can have `corrector`: if the corrector was on, and which words it changed (`original` and `replacement`). The text of the message is still the text that the user sends (section 5.7) |
| Pointer to another slot (proposal, issue #120) | 2026-11-10 | To review. An assistant message can point to another slot of the same instance with the new part `slot_link` (the `port` of the slot and a `label`). The client shows a button. It opens the slot only when the user taps it: a `cards` slot opens the deck (`cards.md`), an `http` slot opens the browser, a `chat` slot opens the conversation. A port that is not a slot of the instance, or a slot that the client does not support, shows the text of the message only (section 5.8) |
| Version | 2026-10-14 | The tag has no version. The interface only grows with new optional fields (section 11) |

## 3. Declaration in the service interface

A service follows this interface if its `Service.Api` has one `Slot` with these values
(`nodo:protos/celaut.proto`, `Service.Api.Slot`):

| Field | Value |
|---|---|
| `transport.tags` | contains `tcp` |
| `protocol_stack` | from bottom to top: a `Protocol` with `tags` that contain `http2`, above it a `Protocol` with `tags` that contain `grpc`, and above it a `Protocol` with `tags` that contain `chat` |

The three protocols are three items of `protocol_stack`, in this order. A tag is a name in
lower case. The `formal` field of the three protocols can be empty.

The client reads the interface in the answer of `StartService` (`Instance.api`). It uses
the `port` of this slot for `ServiceTunnel`.

This document does not fix a port number. The author of the service chooses the `port` of
the slot. The `port` is the port inside the instance. It names the slot for `ServiceTunnel`
and has no other use for the client. The node chooses every address and port that is
outside the instance. The protocol stack of the slot, and not a number, tells a client that
the service follows this interface. A client must not show the `port` to the user as part of
the interface.

- A slot counts only if the instance has that port in `Instance.uri_slot`.
- If no slot counts, the client must not show the service as a chat service.
- If more than one slot counts, the client must use the first.
- A slot with the stack `http`, `chat` (revision 5 or older) does not count.
- The service must listen on the port of the slot.
- The service must not use the same port for other protocols.

A service can declare two slots, with two ports: one for revision 6 and one for an older
revision. A client of revision 6 uses the first slot that follows this section.

The `prose` of the `chat` protocol can describe the service for the user. The client does
not parse it.

## 4. Transport

- The service must speak gRPC over HTTP/2 on the port of the slot. The service must accept
  HTTP/2 in clear text, with prior knowledge (h2c, RFC 9113 section 3.3). The client does not
  send the HTTP/1.1 `Upgrade` header and does not use ALPN.
- The service must not require TLS. The tunnel of the node gives the secure channel.
- The service must not require a certain `:authority`. The client sends `127.0.0.1` and the
  local port of the tunnel.
- `chat.proto` has no package. The paths of the calls are `/ChatService/<Method>` and
  `/FileService/<Method>`.
- The client opens one TCP connection, which is one `ServiceTunnel` stream, and sends all its
  calls on it. HTTP/2 puts many calls on one connection, so a stream of `Connect`, a send and
  a file transfer can run at the same time. This is the reason for the choice of gRPC: each
  connection costs `TUNNEL_OPEN_MU` (section 10).
- The service must allow at least 8 open HTTP/2 streams at the same time on one connection
  (`SETTINGS_MAX_CONCURRENT_STREAMS`).
- The service must not close a connection that has an open call. The service must close an
  idle connection only after 5 minutes without a call or a PING. The service must not close a
  connection to signal an error. It must end the call with a status (section 9).
- The client must not send an HTTP/2 PING more often than once in 5 minutes. The service
  must accept PING frames at that rate.
- The client sends no compression. The service must accept a message that is not
  compressed. The service can accept `gzip`. The service must not compress a message if the
  client did not say that it accepts it (`grpc-accept-encoding`).
- By default, the service must accept a message of 4 MiB (4 194 304 bytes) or less. By
  default, the service must not send a message of more than 1 MiB. The client must accept a
  message of 4 MiB or less. `GetCapabilities` can give other limits (section 7).
- A message that is above the receive limit of the gRPC layer is rejected by that layer with
  `RESOURCE_EXHAUSTED` and no `chat-reason`. A service should set its receive limit to 4 MiB
  (the maximum of this document) or more, so that it never rejects a valid message.
- The client and the service must ignore protobuf fields that they do not know. They must
  ignore HTTP/2 headers and gRPC metadata that they do not know. A `ContentPart` that has
  no `kind` (a part of a newer revision) is not an error (section 5.1).
- The service must reply to a call that `chat.proto` does not define with the status
  `UNIMPLEMENTED`.
- The service must answer each call in this document at any time, also when it makes answers.
  `GetCapabilities`, `GetMessages` and `SetMessagePinned` must not end with the status
  `UNAVAILABLE`.
- The client does not set a deadline for `Connect`. The client sets a deadline of 30 seconds
  for each other call that has no file stream, and of 120 seconds for an `UploadFile` or a
  `DownloadFile` call.

## 5. Messages

`Message` has these fields. The third column tells what the field is for the user interface.

| Field | Type | Meaning |
|---|---|---|
| `message_id` | string | A name of the message. It is unique in the instance and does not change. It has 1 to 128 characters. The client must not read a meaning from it |
| `sequence` | uint64, 1 or more | The position of the message in its conversation. User messages and assistant messages share the same count. The client shows messages in this order |
| `conversation_id` | string, optional | Absent for the main conversation (section 6.8) |
| `content` | `ContentPart`, repeated | The content of the message (section 5.1) |
| `status` | `MessageStatus` | The state of the message (section 5.2) |
| `created_at` | int64 | The time when the service made the message, in milliseconds since 1970-01-01 UTC |
| `updated_at` | int64 | The time of the last change of `status` or `pinned`. It is equal to `created_at` for a message that never changed. A delta does not change it |
| `reply_to_message_id` | string, optional | The `message_id` of the message that this message answers |
| `pinned` | bool | `true` if the message is pinned (section 5.3) |
| `metadata` | map, string to string | Extra data. This document defines no key. A client ignores each key |
| `from_service` | bool | `false` for a user message, `true` for an assistant message |
| `reasoning` | string | The reasoning of the model (section 5.2). Only an assistant message has it. It is empty if the service gives none |
| `idempotency_key` | string, optional | The `idempotency_key` of the send. Only a user message has it, and only if the send had it (section 6.1) |
| `error` | string, optional | The reason of a failure, for the user to read: UTF-8, 1 to 1 024 bytes. A service must not send more. A client that gets more can cut the text for display, to its own limit. Only an assistant message with `status` `FAILED` has it (section 5.2) |
| `suggestions` | string, repeated | 0 to 3 short replies that the service proposes after this message. Only an assistant message with `status` `COMPLETED` has them (section 5.7) |
| `corrector` | `CorrectorState`, optional | The state of the corrector of the client for this user message, as the send gave it. Only a user message has it (section 5.7) |

Rules:

- For each optional string field of `chat.proto` (`conversation_id`, `reply_to_message_id`,
  `idempotency_key`, `event_id`, `error`), an empty string has the same meaning as an absent
  field. A service must read it in this way, and must not send an empty string in these fields.
- The service must keep `latest`. The next message gets `sequence` equal to `latest` + 1.
- The history has no gaps. The first message has `sequence` 1. A message has `sequence` equal
  to its index in the history, plus 1.
- The service must give a user message its `sequence` when it takes the send. The service
  must give an assistant message its `sequence` when the answer is created, before the first
  text (section 5.2).
- The service must not delete a message that it holds. The service must not send
  `MessageDeleted`. A client can ignore `MessageDeleted`.
- The service must not change a final message. Section 5.3 gives the only change that is
  permitted: `pinned` and `updated_at`.
- The roles do not alternate. The client can send a new message before the answer to the
  messages before it is complete. The answers can be in a different order from the user
  messages. `reply_to_message_id` links an answer to its user message.
- The text of a user message must be the text that the client sent, without a change. The
  service must not remove, add or change a character, including space characters.
- The service must keep and return a message in the same order, with the same `message_id`
  and the same `sequence`, each time.
- A user message always has `status` `COMPLETED`. A user message has no `reasoning`.
- The service must set `reply_to_message_id` in each assistant message to the `message_id` of
  the user message that it answers.
- The client must keep a table from `message_id` to `sequence`. A `reply_to_message_id` that
  is not in the table is not an error. The client can show the message with no link.
- A `message_id` or a `sequence` that is not the next one (a gap) in a read of the history is
  an error of the service. The client treats it as `badAnswer`.

### 5.1 Content and attachments

`content` is a list of `ContentPart`. Each part has one `kind`:

| `kind` | Use |
|---|---|
| `text` (`TextContent`) | Text in UTF-8. A message can have many text parts. The text of the message is the text of the parts, joined in order, with no separator |
| `image` (`ImageContent`) | An image. `file` is a `FileReference` (section 6.4). `alt_text` is optional |
| `audio` (`AudioContent`) | A sound. `file` is a `FileReference`. `transcript` and `duration_ms` are optional |
| `file` (`FileReference`) | Another file. A client of revision 6 does not send it. A service can send it. A client can show it as a file to share |
| `structured` (`StructuredContent`) | Data with a media type. A client that does not know the media type ignores the part. Revision 6 defines no use for it |
| `secret_request` (`SecretRequest`) | A request for a secret value, by name. Only an assistant message with `status` `COMPLETED` has it (section 5.6). A client that does not know it ignores it |
| `slot_link` (`SlotLink`) | A pointer to another slot of the instance, for example a deck of cards. Only an assistant message with `status` `COMPLETED` has it (section 5.8). A client that does not know it ignores it |
| (not set) | A part of a newer revision. The client ignores it |

A `FileReference` in a message must have:

- `hashes`: one or more hashes. Each hash must have an explicit `type`. A hash that has no
  `type` makes the `FileReference` not valid. A `FileReference` that a service sends must have
  a SHA3-256 hash (section 6.4). A `FileReference` that a client of revision 6 sends has
  only SHA3-256 hashes;
- `mime_type`: the media type, in lower case and without parameters, for example
  `image/jpeg`. The service compares it in lower case and without parameters, keeps that
  form, and gives it back in that form;
- `size_bytes`: the number of bytes of the file. It must be 1 or more. An empty file is not
  valid;
- `filename`: optional. It is a name for the user to read. The service must not use it as a
  path.

Two checks apply to the `mime_type` of an `image` part and of an `audio` part:

- If `mime_type` starts with `image/` or `audio/`, and its class is not the kind of the part
  (for example `audio/wav` in an `image` part), the service must reject the send with the
  reason `bad_request`.
- If the service does not accept `mime_type` (section 6.7), the service must reject the send
  with the reason `unsupported_media`, for each kind of part and for each `mime_type`. A
  `mime_type` such as `application/pdf` in an `image` part is not a disagreement of kind:
  it gets `unsupported_media`.

The content of a message must not change after the message is final (section 5.2). The
service must not change the bytes of a file. The service must keep each file that a message
references until the instance stops.

Media types that a service must accept, if it accepts the kind (section 6.7):

| Kind | Media types |
|---|---|
| `image` | `image/jpeg`, `image/png` |
| `audio` | `audio/mpeg`, `audio/wav` |

A service that accepts one media type of a kind must accept the two media types of the kind.
A service can accept more media types. A service can send an attachment in an assistant
message, for example an image that it makes.

A user message has at least one part. A user message that has only a text part must have a
text that is not empty. The client puts the text part first, then the attachments in the
order that the user chose. The client does not send a text part that is empty.

### 5.2 Answers and streaming

A service makes the answer to a user message in one of two ways. Each way is valid.

- **Whole answer.** The service adds the assistant message when the answer is ready. The
  message has `status` `COMPLETED`, and the whole content.
- **Streaming.** The service adds the assistant message when the answer starts. The message
  has `status` `IN_PROGRESS`, and `content` and `reasoning` hold what the service has made so
  far (they can be empty). The service sends deltas while the answer grows. When the answer
  ends, the service sets `status` to `COMPLETED`. If the answer cannot end, the service sets
  `status` to `FAILED`. If the client cancels the answer (section 6.5), the service sets
  `status` to `CANCELLED`.

A service that has a queue can add the assistant message with `status` `PENDING` when it
takes the user message, and change it to `IN_PROGRESS` when the answer starts. A service
must not send a delta for a message that is `PENDING`.

**Final content.** The final content of a message is the `content` and the `reasoning` that
the message holds when its `status` is final. They are the content that the service gives in
each later read (`GetMessages`, a replay of `Connect`). While the message is open, `content`
and `reasoning` are the text that exists at the time of the read, and deltas add text at the
end.

Rules for an open message:

- A delta adds `text_append` to the last `TextContent` of `content`. If `content` has no part,
  or if its last part is not a `TextContent`, the receiver adds a new `TextContent` with
  `text_append` at the end. A delta adds `reasoning_append` to the end of `reasoning`. An
  empty value adds nothing.
- The service must send a delta only for a message that is `IN_PROGRESS`, after the
  `MessageCreated` of that message.
- The service can change only the end of the text of `content`, `reasoning`, `status` and
  `error` of an open message. The service sets `error` one time, together with the status
  `FAILED`, and never changes it after that. The service must not remove or change a
  character that it sent, and must not change a part that is not a text part.
- The text that a reader makes from the `MessageCreated` of an open message and the deltas
  after it must be equal to the text that a read of the same message gives at that time.
- `status` changes in one of these ways: `PENDING` to `IN_PROGRESS`, `PENDING` or
  `IN_PROGRESS` to `COMPLETED`, to `FAILED`, or to `CANCELLED`. Then the message is final.
  Each change of `status` has a `MessageStatusChanged` event, and `updated_at` has the time of
  the change. A service that adds the answer only when its turn starts (it is always
  `IN_PROGRESS`, never `PENDING`) sends no event for `PENDING` to `IN_PROGRESS`, because
  this change does not exist. A service that adds the answer as `PENDING` must send the
  event when the answer starts.
- A reader sees one state of the message at each read. The state is never half changed.
- `latest` does not change when the text of an open message grows.
- A delta has `text_append` and `reasoning_append` of 64 KiB (65 536 bytes) or less. The
  service must not cut a UTF-8 character.

`reasoning` is the text that the model writes before its answer, if the model gives it. It is
not part of the content. A service that has no reasoning does not set the field. The client
shows `reasoning` apart from the text, and the user can hide it.

A `FAILED` message keeps the content and the `reasoning` that exist at that time. The service
must not remove the message. The service must set `error` in the message and in its
`MessageStatusChanged` event (the same value), and must not change it after that. `error` is
a short text for the user, in UTF-8, of 1 024 bytes or less, and it has no secret data of the
service. The service can also put a text such as "Error: ..." in the text of the message, but
the client must not need it. The client can show `error`. The conversation goes on: the user
can send a new message. A message that is not `FAILED` has no `error`.

A `CANCELLED` message keeps the content and the `reasoning` that exist at that time.

The service must end each answer: the service must set `status` to a final value. A user
message with no assistant message after a long time is a service that does not follow this
document.

### 5.3 Pinned messages

`pinned` is a field of the message that the service and the client can change at any time,
also for a message that is open or final, and also for a user message.

- A message is pinned when it is made, if the service sets `pinned` in it. The service sets
  `pinned` in `MessageCreated`.
- The client changes `pinned` with `SetMessagePinned` (section 6.6). The service changes it
  by its own choice.
- Each change of `pinned` sets `updated_at` to the time of the change. `updated_at` must not
  become smaller. A call that sets the value that the message already has changes nothing,
  also not `updated_at`.
- Each change has a `MessagePinnedChanged` event for each open `Connect` stream.
- A change of `pinned` is not a change of the content. The content of a final message stays
  the same.

### 5.4 Client features that use the content (not normative)

This section is for information. A service does not need these features, and a client can
ignore them. The wire format does not change.

- **Pinned message.** A client can keep the last pinned message that is above the visible part
  of the conversation at the top of the chat. It limits the space of this message to a part
  of the chat height. A pinned message anchors only the messages after it. If the user
  scrolls up past a pinned message, the client shows the pinned message before it. This is
  the behavior of chatui ([ui-chat-first.md](ui-chat-first.md), section 9). A client that
  does not have this feature shows a pinned message as the other messages.
- **HTML block.** A service can put a fenced block that starts with ```` ```html ```` in the
  text of a message. A client can show the block as a simple widget. The client must not run
  script and must not load a resource from the network. It shows only the tags and the styles
  of an allow-list. A client that does not show widgets shows the block as code. A block that
  is not closed yet, in an open message, is shown as code until the fence closes.
- **Keyboard block.** A service can offer keys to the user with a fenced block that starts
  with ```` ```keyboard ````. Section 5.5 gives the format.
- **Recorded audio.** A client can record sound with the microphone and send it as an
  `AudioContent` with `mime_type` `audio/wav`. A service that accepts `audio` must accept
  `audio/wav`.

### 5.5 Keyboard block (not normative for the wire)

A keyboard block lets a service offer the user the answers that it expects, for example
"yes" and "no", or the choices of a form, as keys and fields. The user does not have to write them. The
wire format does not change: the block is text in a `TextContent`, and what the user sends is
a normal user message. A service must not expect that the client shows the block. A client
that does not show keyboards shows the block as code, and the user writes the answer.

Format:

````text
```keyboard
<p>Do you accept?</p>
<div>
  <button data-say="Yes, I accept">Accept</button>
  <button data-say="No, I do not accept">Decline</button>
</div>
<div>
  <input data-name="amount" placeholder="Amount">
  <button data-say="Send {amount} ERG" data-send>Send</button>
</div>
```
````

| Rule | Value |
|---|---|
| Fence | A line "```` ```keyboard ````" opens the block, and a line "```` ``` ````" closes it, as the HTML block (section 5.4) |
| Content | The same restricted HTML as the HTML block: allowed tags and attributes only, no script, no network, no `on*` attribute. `button`, `input`, `select` and `option` are allowed tags (`select` and `option` only in a keyboard block: the HTML block drops `select`). `data-say`, `data-send`, `data-name`, `placeholder`, `type`, `min`, `max`, `step`, `value`, `checked`, `data-off`, `multiple` and `selected` are allowed attributes, and the only ones that have a meaning here |
| Key | An element that has a `data-say` that is not empty. Its text is the label of the key. If it has no text, the label is the `data-say` |
| Field | An `input` or `select` element that has a `data-name` is a field: the user gives a value in it, and the `placeholder` is its hint (the label of a checkbox, and the name of a slider). A `data-name` has 1 to 32 characters of `A-Z`, `a-z`, `0-9`, `_` and `-`. An `input` or `select` with no valid `data-name`, a second field with the same name, and a field after the 8th are not shown. Its kind comes from the `type` of the `input`, or from `select`. A `type` that is not in the table of the kinds below (or no `type`) is a line of text, and the client ignores the other attributes of it |
| Placeholders | A `{name}` in a `data-say` is replaced by the value of the field `name` (for every kind of field: the value is always text). The client does this when the key is tapped, in one pass, so a `{x}` inside a value stays as it is. A `{name}` that is not the name of a field stays as it is. A value has its white space (and line breaks) changed to one space, with none at the ends. It has at most 200 characters, and the field does not take more. The `placeholder` of a field has at most 80 characters, and the client cuts the rest |
| Empty field | A key whose `data-say` uses a field that is empty cannot be tapped. A key that does not use the field can. A text, a date, a time and a select are empty until the user gives a value (or until the service gives a `value`). A slider and a checkbox always have a value, so they never block a key |
| Layout | A block element (`div`, `p`, `li`, `tr`, a heading) starts a new row. Text that is not in a key is shown as text between the keys |
| Tap | The client puts the `data-say` (with the values of the fields in it) in the input of the user. If the input is not empty, the client adds it after the text, with a space between them if the text does not end in a space or a line break. A key must not replace what the user has written |
| Send | A key without `data-send` must not send the message: the user changes the text, if the user wants to, and sends it. The service gets it as a user message |
| Send at once | A key that also has the attribute `data-send` (with no value, or any value) sends its `data-say` (with the values of the fields in it) as a user message when it is tapped. The client sends only the `data-say`: it does not send the text that is in the input, or the files that wait, and it does not change them. The keyboard is then inactive. The service decides which keys have `data-send` |
| Limits | One block has at most 8000 characters. A message has at most 2 keyboard blocks. A block has at most 64 keys and 8 fields (of any kind). A `select` has at most 32 options. A `data-say` has at most 500 characters, before the fields are put in it. What is above a limit is shown as text or as code, never cut. A key whose `data-say` is too long is shown as text |
| Open block | A block that is not closed yet, in an open message, is not shown as keys until the fence closes |
| Which keyboard is active | The keyboard of the last block of the last message, if the service made that message and it is complete. A message of the user after it, or a new message of the service, makes it inactive |

The kinds of field. The client gives the value as text, and it is at most 200 characters:

| `type` / element | The user | Attributes that have a meaning | The value |
|---|---|---|---|
| (none), `text`, or any other `type` | Writes one line of text | `placeholder` | What the user wrote, with the white space changed to one space |
| `date` | Chooses a day in a calendar | `min` and `max` (days, `YYYY-MM-DD`), `value` (the day at the start) | `YYYY-MM-DD`. A `min`, a `max` or a `value` that is not a real day is ignored. If `min` is after `max`, both are ignored. With no `min` or `max`, the calendar goes from 1900 to 2100 |
| `time` | Chooses a time in a clock of 24 hours | `value` (the time at the start) | `HH:MM`. A `value` that is not `00:00` to `23:59` is ignored |
| `range` | Moves a slider | `min`, `max`, `step`, `value` | A number inside `min` and `max`, on a step of `step` from `min`, with the decimals of the `step` and of `min` (at most 6). `min` is 0, `max` is 100 and `step` is 1 if they are missing, not a finite number, or if `max` is not more than `min` (then both are the defaults) or `step` is not more than 0. `value` is the start (`min` if it is missing). A slider with more than 1 000 steps moves with no steps, and the value is rounded to the step |
| `checkbox` | Turns a box on and off | `value` (what the value is when it is on, `yes` if it is missing or empty), `data-off` (what it is when it is off, `no` if it is missing or empty), `checked` (it is on at the start) | The `value` or the `data-off` |
| `select` | Chooses one option from a list. With `multiple`, chooses some of them. The options show in the form (not in a menu or a dialog), see "Options" below | `multiple` (with no value, or any value), `selected` on an `option` (it is chosen at the start; a `select` without `multiple` keeps only the first one), and `option` elements: the `value` of an option is the value of the field (the text of the option if it has no `value`), and its text is its label (the `value` if it has no text). The `placeholder` is the hint | The `value` of the chosen option. With `multiple`, the values of the chosen options, in the order of the options, with ", " between them (so a `value` that has a comma is not told apart from two values: a service that needs this must not use commas in its values). The value has at most 200 characters: a box that would make it longer does not turn on, and a value is never cut. An option with an empty value or one of more than 200 characters, and an option with a `value` that an earlier one has, are lost. The label has at most 80 characters, and the client cuts the rest. An `option` can have no closing tag |

A `select` with `multiple` that has no option chosen is empty, so a key that uses it cannot be tapped.

Options. chatui shows the options of a `select` in the form, as chips side by side while they
fit in the width, and in more rows if they do not. The rows turn like a wheel: the row in the
middle is bigger and clear, and the rows above and below are smaller and fade. Three rows show
at once (fewer if there are fewer rows), and the user turns the wheel with a drag up or down.
A tap on a chip chooses it (with `multiple` a chip that is on goes off with another tap, and
shows a check mark). A `select` without `multiple` shows the chosen chip and does not go back to
empty. The `placeholder` shows above the chips. A client can show the options in another way,
for example in a menu: the values are the same. The order of the `option` elements is the order
of the chips.

A service that wants a kind that a client does not know can write a plain `input` with a
`placeholder` that says the format (for example `YYYY-MM-DD`), or keys that give the values.
A client that does not know a `type` shows a line of text, and a `{name}` is still replaced.

In chatui, the form (the keys and the fields) shows **under** the input of the conversation,
never above it. The message itself shows a small card in place of the block, so the keys are
not twice on the screen. The user can close the form with the button of the form. A tap on
the card of the last message opens it again, if the user closed it. The form is also closed
when a key with `data-send` sends. If the HTML widgets are off, the block is shown as code.

Keyboard of the text. chatui does not open the keyboard of the system, so the form can always
be under the input. Under the input it shows:

| Case | What shows under the input |
|---|---|
| There is a form | The form. The fields of text type with the keyboard of the app, which shows under the form while one of them has the focus. A calendar, a clock, a slider, a checkbox and a list of options need no keyboard |
| There is no form | The keyboard of the app: letters (with `ñ`), numbers and symbols, shift, Backspace, space and a new line. It types in the input of the conversation |
| The user records audio | Nothing |

What shows under the input (the form, or the keyboard of the app) hides in three cases, to give
the list the room of the screen:

- The user scrolls the conversation **towards the older messages** (a drag or a fling, of at least
  a few pixels). A scroll towards the end does not hide it, and a touch that hardly moves the list
  does not either.
- The user taps the conversation (not a link or a button in it).
- The user presses Back. The first Back only hides it; the next one leaves the chat.

It shows again with a tap on the input, with a new message (the service's, or the user's own), and,
for a form that is waiting, with a tap on its card (section above) or when the user scrolls back
to the end of the conversation. It hides and shows with a short animation. If the keyboard of the
system is in use, a drag or a tap on the list also takes the focus from the input, and the
keyboard of the system closes.

The keyboard of the app puts a capital at the start of a sentence (not in the fields of a form).
A key acts when the finger touches it, not when the finger goes up, and it shows no splash.
Above the keys, three chips show suggestions (section 5.7).
Shift is for one letter, and two quick taps lock it. Backspace repeats while it is held, and each
key gives a small vibration. On a computer, Enter sends and Shift+Enter makes a new line; on a
phone Enter always makes a new line.

The user can choose the keyboard of the system in the settings of the chat (**Use the system
keyboard**, a setting for the whole app, off by default). Then the input uses the keyboard of
the system, and the keyboard of the app does not show, except that while there is a form the
input does not open the keyboard of the system: the form is under the input, and the fields of
text of the form use the keyboard of the system.

The value of a field is text that the user wrote, and it goes into a message as it is. A service
must not trust it: it is user input, as any other message. A field does not make a request, and the
client does not send the value anywhere but in that message.

A service must write a `data-say` that is a full and safe user message, because the user can
send it with one tap (and with no tap to check it, if the key has `data-send`). A `data-say` must not make the user send private data, or confirm an
action that has a cost, unless the label says it.

### 5.6 Secret requests

A service can ask the user for a secret, for example an API key, by name. The user gives the
value from the variables of the app, or skips the request. The value goes to the service in
`AnswerSecretRequest` (section 6.9). The value is never in a message. This section is revision 6, round 8. `chat.proto` has its messages, and chatui implements it from version 0.1.30. Josemi's decisions of 2026-11-01 are in it.

A `SecretRequest` has these fields:

| Field | Type | Rule |
|---|---|---|
| `request_id` | string | 1 to 64 characters from `A-Z`, `a-z`, `0-9`, `-` and `_`. It is unique in the instance |
| `name` | string | The name of the variable that the service asks for. 1 to 128 characters from `A-Z`, `a-z`, `0-9` and `_`. It does not start with a digit. The client finds the entries of the container with this name. The client must not read a meaning from it |
| `prose` | string, optional | A text for the user that says why the service needs the value. UTF-8, 1 024 bytes or less. An empty string is the same as absent |

**Where the request goes.** The service puts the part in an assistant message with `status`
`COMPLETED`. The service must not put the part in an open message, and must not put it in a
user message. The answer to the request is a new assistant message, and not a change of the
message that asked. The `reply_to_message_id` of that answer is the `message_id` of the message
that has the request. This is the only case in which `reply_to_message_id` is not the
`message_id` of a user message.

**The value is not in the history.** The service must not write the value into a message, an
event, `metadata`, a log, a file, the text of an error or a `ProtocolError`. The service must
not send the value in any call. The service keeps the value in memory, and only as long as it
needs it. The client cannot check what the service does with the value (section 6.9).

**Waiting.** The service waits for the user's answer, a value or a skip, with no time limit. The service must not end the wait by time. A request ends only with the instance: when the instance stops, the request is void.

**Skipped.** A skipped request has no value. The service must go on without the value, or end the answer with a text that says it cannot do the task without it.

**Answered once.** A request has one answer: a value, or a skip. The first answer counts. A
later `AnswerSecretRequest` for the same `request_id` gets `OK` with no change. The service
does not compare the value with the first one. This is the same rule as the key of a send
(section 6.1).

**State.** The service does not send the state of a request. The client keeps the state of each
request (section 10). The state has the name and the word "sent" or "skipped", never the value.

**Where the value goes.** The node of the instance gets the value, as it gets the values of a launch (`env-variables.md`, section 4). A service that declares a network with egress can send the value outside the node.

**Warnings.** The client warns before it sends a value that is sensitive (the mark of the entry, or the switch of a typed value). The warning applies when the node of the instance is not fully trusted, or when the service declares any network. With egress, the warning is the red card of `env-variables.md`, section 3.2, and **Deny** is the default. In the other cases it is the normal warning, and it names the reason. A value that is not sensitive gets no warning (section 10).

**Typed values and saving (decided 2026-11-01).** The user can type a value in the chat. The question has the switch **Sensitive**, off by default, as in `env-variables.md`, section 3.2. A typed value is not kept, unless the user saves it. The user can save it in the container with a name, and the switch of the question becomes the sensitive mark of the entry.

**Open message (decided 2026-11-01).** A request is only in a `COMPLETED` message.

### 5.7 Suggestions and corrector

This section is revision 6, round 10. It is a proposal for issue #88, and Josemi must review
it. A service that sends no suggestions, and that ignores `corrector`, keeps the wire of
revision 6.

**Suggestions.** A service can propose to the user up to 3 short replies after an answer,
for example "Yes", "No" and "Tell me more". The client shows them above its keyboard. A tap
on one puts it in the input of the user, as a key of a keyboard block without `data-send`
(section 5.5): the user can change the text, and sends it with Send.

| Rule | Value |
|---|---|
| Where | `Message.suggestions` (field 15) of an assistant message, and `MessageStatusChanged.suggestions` (field 6) |
| When | With the status `COMPLETED`, one time. A whole answer has them in its `MessageCreated`. A streamed answer has them in the `MessageStatusChanged` that sets `COMPLETED`, and the message has them in each read after that. They do not change after that. A `PENDING`, `IN_PROGRESS`, `FAILED` or `CANCELLED` message has none, and a user message has none |
| Number | 0 to 3. A client uses the first 3 and ignores the others |
| Text | Each one is UTF-8, 1 to 64 characters, in one line: no character from U+0000 to U+001F and no U+007F. The client ignores a suggestion that does not obey this |
| Meaning | Plain text. A service must write a suggestion that is a full and safe user message, as a `data-say` (section 5.5) |
| Which are active | The suggestions of the last message, if the service made it and it is `COMPLETED`. A message of the user after it, or a new message of the service, makes them inactive. This is the rule of the keyboard block (section 5.5) |

The suggestions are for each message. They do not change while the user writes: the text in
the input of the user does not go to the service before Send. This keeps the text private
until the user sends it, and costs no traffic for each key.

**Corrector.** A client can have a corrector: while the user writes a word, it proposes words
that complete or correct it, and a tap on one changes the word. The corrector is part of the
client. This document does not fix how it works. The send tells the service the state of the
corrector, so that the service knows that a word of the text can be a correction, and what
the user wrote first. For example, a model can read the original word when the correction
seems wrong.

`CorrectorState` has these fields:

| Field | Type | Rule |
|---|---|---|
| `enabled` | bool | `true` if the corrector of the client was on while the user wrote this message |
| `corrections` | `Correction`, repeated | The words that the corrector changed in the text of this message, in the order in which the user made the changes. 0 to 32 items |
| `Correction.original` | string | The word that the user wrote. 1 to 64 characters |
| `Correction.replacement` | string | The word that the corrector put in its place. 1 to 64 characters. It is in the text of the message |

The rules:

- The client sends `corrector` in a send that the user wrote. It does not send it for the
  text of a key with `data-send`, which the user did not write.
- The client puts in `corrections` only the changes that are still in the text at Send. A
  word that the user completes (the word that the user wrote is the start of the new word)
  is not a correction.
- The text of the message is the text that the user sends, with the corrections in it.
  `corrections` does not change it, and the service must not change it (section 5).
- The service can use `corrector`, or ignore it. A send must not fail because of it. The
  service can drop the items that are above the limits.
- A service that keeps `corrector` gives it back in `Message.corrector` of the user message,
  in each read. A service that does not keep it sends no `corrector`.
- `corrector` is not a secret, but it is text that the user wrote. A service must not send it
  to a third party for another use.

In chatui: three chips show above the keyboard of the app. While the input is empty, or the
cursor is after a space, they show the active suggestions of the service. While the user
writes a word, they show the words of the corrector: words that start with what the user
wrote, then close words (one or two letters are different), from the words of the
conversation and of the suggestions. A tap changes the word, and adds a space. The corrector
never changes a word by itself, and it has no dictionary: a word that is not in the
conversation can be correct. With the keyboard of the system, only the suggestions of the
service show, and `enabled` is `false`. While a form of a keyboard block is under the input,
the chips do not show. A setting of the chat (**Word suggestions**, on by default) turns the
corrector off.

### 5.8 Pointer to another slot

This section is revision 6, round 11. It is a proposal for issue #120, and Josemi must review
it. A service that sends no `slot_link` keeps the wire of revision 6, and a client that does
not know the part ignores it (section 4): the user sees the text of the message only.

An assistant message can tell the client that the next step is in **another slot** of the same
instance, for example a full-screen deck of cards (`cards.md`). The part is `slot_link`
(`SlotLink`):

| Field | Type | Rule |
|---|---|---|
| `port` | uint32 | The `port` of a `Slot` of the `Service.Api` of the instance (section 3). It names the slot, as for `ServiceTunnel`. It is not an address |
| `label` | string, optional | The text of the button, 1 to 32 characters, one line. Absent: the client uses its own text for the kind of the slot, for example "Open" |

Rules for the service:

- The service puts the part in an assistant message with `status` `COMPLETED`, after a text
  that tells the user what the slot is for. It must not put it in an open message or in a user
  message.
- The `port` must be a slot of the instance that sent the message. The service must not use the
  part to send the user to an address that is not a slot of the instance: the part has no
  field for an address.
- A message can have up to 4 `slot_link` parts.

Rules for the client:

- The slot counts only if the instance has that port in `Instance.uri_slot` (section 3). The
  client reads the kind of the slot from its `protocol_stack`:

  | Stack of the slot | What the client opens |
  |---|---|
  | `http2`, `grpc`, `cards` | The deck of cards (`cards.md`) |
  | `http` (a slot that a browser can open) | The browser, as for the web slots of the instance |
  | `http2`, `grpc`, `chat` | The conversation. If it is the slot of this conversation, the client shows no button |

- A port that is not a slot of the instance, a slot that does not count, and a slot of a kind
  that the client does not support are ignored: the client shows the text of the message only.
- **The link is a request, not an order.** The client shows a button under the message, with
  the `label`. It opens the slot only when the user taps the button. It never opens a slot, a
  page or a screen by itself when the message comes. The tap is the consent of the user.
- The button stays on the message. The user can tap it again later, for example to open the
  deck again after it was closed.
- The client does not send anything to the service for a tap.

## 6. Calls

### 6.1 Send a message

```
rpc SendMessage(SendMessageRequest) returns (Message);
```

| Field | Rule |
|---|---|
| `conversation_id` | Absent (section 6.8) |
| `content` | Required. The content of the message, as section 5.1 says. The text must not be empty, unless the request has an attachment |
| `reply_to_message_id` | Optional. The `message_id` of a message of the conversation. An empty string is the same as absent |
| `idempotency_key` | Optional. 1 to 64 characters from `A-Z`, `a-z`, `0-9`, `-` and `_`. The client uses a new key for each message. An empty string is the same as absent |
| `corrector` | Optional. The state of the corrector of the client for this message (section 5.7). The service does not check it, and a send never fails because of it |

The service must check the request in this order and stop at the first failure:

| Step | Check | Failure |
|---|---|---|
| 1 | `content` has at least one part. Each part has a `kind` that the client can send (`text`, `image`, `audio`). Each text part is valid UTF-8 (protobuf makes sure of this). The text is not empty, unless there is an attachment. `idempotency_key`, if present, is valid. Each attachment has the fields of section 5.1: each hash has a `type`, the `size_bytes` is 1 or more, and the class of its `mime_type` is not another class of image or audio. The number of attachments is 4 or less | `INVALID_ARGUMENT`, reason `bad_request` |
| 2 | The text, the request and each `size_bytes` are in the limit of the service (section 7) | `INVALID_ARGUMENT`, reason `too_large` |
| 3 | Each `mime_type` is a type that the service accepts (section 6.7) | `INVALID_ARGUMENT`, reason `unsupported_media` |
| 4 | `reply_to_message_id`, if present, is the `message_id` of a message of the conversation | `NOT_FOUND`, reason `not_found` |
| 5 | Each referenced file is available in the service (section 6.4) | `FAILED_PRECONDITION`, reason `file_missing` |
| 6 | A user message with the same `idempotency_key` is in the history | `OK`, with that message. The service changes nothing (see below) |
| 7 | The history has room for the user message and its answer | `RESOURCE_EXHAUSTED`, reason `history_full` |
| 8 | The service can keep one more message that waits for an answer | `UNAVAILABLE`, reason `busy` |

The check of the size (step 2) is before the check of the type (step 3). A file of a type
that the service does not accept, and above the limit of size, gets `too_large`. The same
order is in `UploadFile` (section 6.4): first the structure, then the size, then the type.

For step 3, the service reads `mime_type` in lower case and without parameters. A
`mime_type` is accepted if it is in `accepted_mime_types` (section 6.7). A send with an
attachment to a service that has an empty `accepted_mime_types` gets `unsupported_media`. A
`mime_type` that is not accepted gets `unsupported_media` for each kind of part, except the
disagreement of class of step 1 (section 5.1).

For step 6, the same `idempotency_key` means the same send. The service does not compare the
other fields. The service must reply with the user message that it has, and must not add a
message or start an answer. This lets the client send again after a lost connection (section
6.3). The service keeps the key for the life of the instance.

If all checks pass, the service must do these steps:

1. Add the user message with `sequence` equal to `latest` + 1, `status` `COMPLETED`,
   `from_service` `false` and the `idempotency_key`.
2. Start the answer in the background. The service must not wait for the answer.
3. Reply with `OK` and the user message. The reply has the `content` of the message, without
   change.

The service must reply to a send at once. The service must not hold the reply until the
answer is ready. The service must accept a send while it makes the answer to an earlier
message. Many sends can be in progress at the same time. The service decides how it makes the
answers: one after the other, or at the same time.

If the service fails to take the message, the service must change nothing. The service must
end the call with `INTERNAL`, reason `service_error`. A failure to make the answer is not
this case: the service adds an assistant message with `status` `FAILED` (section 5.2).

If a check of the table fails, the service must change nothing.

The `Connect` event `send_message` has the same checks and the same effect, and the same
`idempotency_key` rules. A service must implement `SendMessage` and `send_message`.

- If the checks pass, the service sends the `MessageCreated` event of the user message
  to the stream. The message has the `idempotency_key` of the send. If the key was used
  before, the message is the message that the service has, and the service adds nothing.
- The client that sends over `Connect` must set `idempotency_key` in the `SendMessageRequest`
  and `event_id` in the `ClientEvent`. It matches the `MessageCreated` to its send by
  `idempotency_key`.
- If a check fails, the service sends a `ProtocolError` with the reason in `code` and the
  `event_id` of the event (if it is valid and new, section 6.5). The stream stays open and the service changes nothing. The client
  matches the error to its send by `event_id`.
- The service must not answer a send over `Connect` in any other way.

The client sends over `Connect` when its stream is open and has had `SubscriptionReady`.
Otherwise it sends with `SendMessage`. The client does not wait for a stream to open to send.
The two ways are the same send: the key rules of section 6.3 are the same.

### 6.2 Read the conversation

```
rpc GetMessages(GetMessagesRequest) returns (stream Message);
```

| Field | Rule |
|---|---|
| `conversation_id` | Absent (section 6.8) |
| `after_sequence` | The client wants the messages with a `sequence` of more than this value. 0 gives the whole history |
| `before_sequence` | The client wants the messages with a `sequence` of less than this value. 0 gives no upper bound. The range of the read is the messages with a `sequence` of more than `after_sequence` and less than `before_sequence` |
| `limit` | The most messages in the reply, taken from the start of the range. 0 gives the limit of the service. The limit of the service must be 100 messages or more. A service can choose a higher limit (the echo service uses 1 000). The service can give fewer messages than `limit` |
| `last` | The reply has only the last `last` messages of the range, in order of `sequence`. 0 means that the field is not used. The service must not give fewer than `last` messages if the range has them, up to the limit of the service |

- If `limit` and `last` are both more than 0, the service must end the call with
  `INVALID_ARGUMENT`, reason `bad_request`.
- If `before_sequence` is more than 0 and is not more than `after_sequence` + 1, the range
  is empty and the reply has no message.
- A client opens a long chat with `last`, and reads older messages with `before_sequence`
  equal to the `sequence` of its first message. The client does not need the whole history.

The service sends the messages in order of `sequence`, with no gap between the first and the
last, and ends the call with `OK`. Each message has its state at the time of the read. If
there is no message after `after_sequence`, the service ends the call with no message.

- If `after_sequence` is more than `latest`, the service must end the call with
  `INVALID_ARGUMENT`, reason `bad_request`. If `after_sequence` is equal to `latest`, the
  reply has no message.
- If there is a message after `after_sequence`, the service must send at least one.
- Each message must be 1 MiB or less (section 4).
- If the call gives fewer messages than exist, the client reads again from the `sequence` of
  its last message. The client stops when a read has no message.

The client uses this call:

- to start the screen again when the instance runs, before it opens `Connect`;
- to catch up after a `Connect` stream ends (section 6.5);
- to repair a lost send (section 6.3);
- to read an instance in the background when a stream is not possible;
- to wait for a service that starts (section 10).

`GetMessages` does not give `latest`. The client gets `latest` from `SubscriptionReady`.

### 6.3 Lost connection

A client that loses the connection after a send does not know if the service got the
message. The `idempotency_key` of the send gives the way to know.

1. The client must read the history (section 6.2) from its own last `sequence`.
2. If a user message with the `idempotency_key` is in the history, the send worked.
3. If it is not, the client can send the same request again, with the same key. If the
   service got the first send in the meantime, step 6 of section 6.1 stops a second message.
4. If the client does not send again, the client tells the user. The user decides.

A client that sends a message with no `idempotency_key` must not send it again by itself.

A send that ends with `DEADLINE_EXCEEDED`, `UNAVAILABLE` with no reason, or `CANCELLED`
follows this section. The service replies to a send in much less time than 30 seconds
(section 7).

### 6.4 Files

```
service FileService {
  rpc QueryFiles(stream QueryFilesRequest) returns (stream QueryFilesResponse);
  rpc UploadFile(stream UploadFileRequest) returns (UploadFileResponse);
  rpc DownloadFile(DownloadFileRequest) returns (stream DownloadFileResponse);
}
```

**Hash.** Each hash is a `Hash` with `type` and `value`. This project uses the type of
`nodo:src/utils/hashing.py`: the `type` is the digest of an empty input, made with the
algorithm of the hash. The algorithm of the files of this interface is SHA3-256. Its `type`
is the 32 bytes that this text writes in hexadecimal:

```
a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a
```

On the wire, `Hash.type` and `Hash.value` are the raw bytes of the digest (32 bytes for
SHA3-256). They are not the hexadecimal text. The hexadecimal text is only the way in which
this document writes the bytes. A `type` of 64 bytes of ASCII is not the type of SHA3-256: it is
a `type` that the service does not know.

`value` is the SHA3-256 digest of the bytes of the file, 32 bytes. SHA3-256 is the algorithm
of the registry of nodo, and of the Rust crates of this repository (`SHA3_256_TYPE` in
`celaut-wire`). It is not SHA-256: the two algorithms give different digests.

The system lets a project add other hash algorithms. The `type` of a `Hash` names the
algorithm: it is the digest of an empty input, as in Celaut. A new algorithm needs no change
to `chat.proto`. A new algorithm gets its own `type`.

- Every service that accepts files must support SHA3-256. A service can support other types.
- A client of revision 6 makes and sends SHA3-256 hashes only. A later revision of the client
  can add other algorithms. The client puts the `type` in each `Hash`, in each call.
- A `FileReference` that a service sends must have a SHA3-256 hash, because the client reads
  only this algorithm. It can have other hashes too. A client that gets a `FileReference`
  with no SHA3-256 hash shows the file as unreadable, and must not call `DownloadFile` for it.
- A `FileReference` can have more than one hash of the same content, with different types.
  Each hash names the same bytes. A service needs to know only one of them: any hash that the
  service knows is enough to find or to check the file.
- A hash with a `type` that the service does not know is not an error in a `FileReference`.
  The service ignores it. A `FileReference` must have at least one hash that the service
  knows, or the service ends the call with `INVALID_ARGUMENT`, reason `bad_request`.
- `Hash.type` is required, in each `Hash` of each call: `QueryFilesRequest`,
  `QueryFilesResponse`, `FileReference`, `DownloadFileRequest` and `UploadFile`. In proto3 a
  `bytes` field has no presence, so an empty `type` and a missing `type` are the same case. A
  `Hash` with an empty `type` is an error in every call that takes a `Hash`, `QueryFiles` too:
  `INVALID_ARGUMENT`, reason `bad_request`. A `type` that is not empty and that the service
  does not know is an unknown algorithm (see above and below), not an error.
- A hash of the SHA3-256 type must have a `value` of 32 bytes. A `value` of another length
  is a structure error: `INVALID_ARGUMENT`, reason `bad_request`. This is true in
  `QueryFiles` and in `DownloadFile` too.
- A service that knows more than one hash of a `FileReference` must check each of them.
- `QueryFiles` with a `type` that the service does not know gives `available` `false`. It is
  not an error.

**Query.** The client sends one `QueryFilesRequest` for each hash, and the service sends one
`QueryFilesResponse` for each request, in the same order. The service must send the hash with
an explicit `type` in the response. `available` is `true` if the service has the bytes and can
send them to this client now.

- Each hash must have a `type`. There is no rule to reuse the `type` of an earlier hash of the
  stream. If a hash has an empty `type`, or if a hash of the SHA3-256 type has a `value` that is
  not 32 bytes, the service ends the call with `INVALID_ARGUMENT`, reason `bad_request`.
- A hash with a `type` that the service does not know gets `available` `false`. It is not
  an error.
- The client must end its side of the stream when it has no more questions. The service
  ends its side after the last response.

**Upload.** The first message has `file`, a `FileReference`. The next messages have `chunk`.
The end of the client stream is the end of the file.

The service checks an upload in this order, and stops at the first failure:

| Step | Check | Failure |
|---|---|---|
| 1 | The first message has `file`. The `FileReference` has `mime_type`, `size_bytes` of 1 or more, and one or more hashes. Each hash has a `type` that is not absent, and a hash of the SHA3-256 type has a `value` of 32 bytes (section 6.4, hash rules, and section 5.1) | `INVALID_ARGUMENT`, reason `bad_request` |
| 2 | `size_bytes` is in the limit of the service (section 7). The service checks this before it reads the chunks, and stops to read if the received bytes are more than the limit | `INVALID_ARGUMENT`, reason `too_large` |
| 3 | The `mime_type` is accepted (section 6.7). A service that has an empty `accepted_mime_types` accepts no file | `INVALID_ARGUMENT`, reason `unsupported_media` |
| 4 | The file store can take the file. The service can find this at the start or while it reads | `RESOURCE_EXHAUSTED`, reason `storage_full` |
| 5 | When the stream ends, the number of bytes is equal to `size_bytes`, and each hash that the service knows is equal to the hash of the bytes | `INVALID_ARGUMENT`, reason `hash_mismatch` |

- A client sends chunks of 64 KiB (65 536 bytes) or less. The service must accept a chunk of
  1 MiB or less.
- A later message that has `file` is a structure error too, but the service finds it only while
  it reads the chunks, after the checks of steps 2, 3 and 4. For this reason a `size_bytes`
  that is above the limit gets `too_large`, also if the stream has a second `file`. When the
  service finds a later `file`, it ends the call with `INVALID_ARGUMENT`, reason `bad_request`.
- A failed upload must leave nothing in the file store.
- `storage_full` is for the file store only. `history_full` is for the history only, and the
  service must not use it for a file.
- The service replies with the `FileReference` that it checked: the hashes that it knows
  (all of them have a `type`), and the real size. The service keeps the file until the
  instance stops.
- An upload of a file that the service already has is not an error. The service replies the
  same way.

**Download.** The client sends one `Hash`, with a `type`. The service sends the bytes in
chunks of 64 KiB or less, in order, and ends the call with `OK`. The end of the stream is the
end of the file.

- A `Hash` with no `type` gets `INVALID_ARGUMENT`, reason `bad_request`.
- A hash that is not available gets `NOT_FOUND`, reason `not_found`.
- The service must send each file that a message of the history references, to the client, for
  the life of the instance.
- The client must check the hash of the bytes that it gets, and must drop the bytes if the
  hash is not equal (it treats this as `badAnswer`). The client can keep the bytes in memory.
  It must not write them to the Celaut database.

**Flow of the client for a send with files:**

1. The client makes the SHA3-256 hash of each file.
2. The client sends the hashes with `QueryFiles`, in one call.
3. For each hash with `available` `false`, the client uploads the file with `UploadFile`.
   For each hash with `available` `true`, the client does not upload the file.
4. The client sends the message with `SendMessage`. The attachment parts have the
   `FileReference` with the hash, `mime_type`, `size_bytes` and, optional, `filename`.
5. If `SendMessage` ends with the reason `file_missing`, the client uploads the files again and
   sends the same request again, with the same `idempotency_key`. The client does this one time.
   If it fails again, the client tells the user.

A service that sets `available` to `true` must be able to give the file at once. The service
can drop a file only when the instance stops.

A service that accepts no attachment and sends no file need not implement `FileService`. It
ends each call with `UNIMPLEMENTED`. Then its `accepted_mime_types` is empty. All other services
must implement `FileService`.

### 6.5 Real time

```
rpc Connect(stream ClientEvent) returns (stream ServerEvent);
```

The client opens one `Connect` stream for each conversation that it shows. The stream carries
the events of one conversation, the main conversation.

1. The first `ClientEvent` of the stream must be `subscribe`, with `after_sequence`. If the
   first event is not `subscribe`, the service must end the call with `FAILED_PRECONDITION`,
   reason `bad_state`.
2. The service sends a `MessageCreated` event for each message with a `sequence` of more than
   `after_sequence`, in order of `sequence`. An open message has the state that it has at that
   time. This is the replay. If `after_sequence` is more than `latest`, the service ends the
   call with `INVALID_ARGUMENT`, reason `bad_request`.
3. The service sends `SubscriptionReady`. `latest_sequence` is the `latest` at the end of the
   replay. `title` is the title of the conversation at that time, or absent if it has none
   (section 6.10). The events of the messages that the service made during the replay come before or
   after `SubscriptionReady` in order of `sequence`, and none is lost or sent two times.
4. The service sends the live events (see below).

A first event that fails ends the call: if the first event is a `subscribe` that is not valid (a bad
`event_id`, or `after_sequence` above `latest`), the service ends the call with the status of
section 9 and the trailer `chat-reason`, and sends no `ProtocolError`. This is true for each
failure of steps 1 and 2 above.

A second `subscribe` on the same stream is an error. The service sends a `ProtocolError` with
the code `bad_state`, and the stream stays open. A `ProtocolError` does not end the stream,
unless the service ends the call with a status.

**Event identifiers and answers.** A `ClientEvent` can have an `event_id`: 1 to 64 characters
from `A-Z`, `a-z`, `0-9`, `-` and `_`, unique in the stream. A client that sends `send_message`
or `cancel_message` over `Connect` must set it. The `event_id` of the first `subscribe` counts: no later event can use it again. A service that
gets an `event_id` that is not valid, or that was used before in the stream, sends a
`ProtocolError` with the code `bad_request` and with no `event_id`, and ignores the event. It
does not copy a bad `event_id`, because the client cannot know which event the id names. An
empty `event_id` is the same as no `event_id`. The service answers each event in this way:

| Event | Answer if it works | Answer if it fails |
|---|---|---|
| `subscribe` | The replay, then `SubscriptionReady` | A status that ends the call (steps 1 and 2 above), or a `ProtocolError` for a second `subscribe` |
| `send_message` | `MessageCreated` of the user message, with `idempotency_key` (section 6.1) | `ProtocolError` with the `event_id` |
| `cancel_message` | `MessageStatusChanged` with `CANCELLED` | `ProtocolError` with the `event_id` |
| `acknowledge` | None | `ProtocolError` with the `event_id`, if there is one |

A `ProtocolError` has the `event_id` of the event that failed. It has none if the event had
none, if the `event_id` was not valid or not new, or if the error is not for an event.

Live events. For each change, the service sends the event to each open stream:

| Change | Event |
|---|---|
| A new message (user message or assistant message) | `MessageCreated`, with the whole message |
| Text or reasoning added to an open message | `MessageDelta` |
| A new `status` | `MessageStatusChanged` |
| A new `pinned` | `MessagePinnedChanged` |
| Progress of a long action (optional) | `MessageProgress` |
| A new title of the conversation (section 6.10) | `ConversationTitleChanged` |

- The events of one message come in order. The `MessageCreated` of a message is before any
  other event of that message.
- The service must send a user message to each open stream, also when the send came by
  `SendMessage`. The client can get the user message by the reply of `SendMessage` and by
  `MessageCreated`. The client must treat the two as one message (the same `message_id`).
- `MessageProgress` is for information. A client can ignore it. A service need not send it.
- `acknowledge` tells the service that the client has every message up to `last_sequence` in
  a final state. It is a hint. A service must accept it. The service can use it as the lower
  bound for the events that it keeps for the stream, and can drop the events that it buffers
  for those messages. The service must not delete a message because of it, and must not
  stop to send events because the client did not send it. If `last_sequence` is more than
  `latest`, the service sends a `ProtocolError` with the code `bad_request`. If it is not
  more than an earlier value of the stream, the service ignores it. The client sends
  `acknowledge` after it applied a batch of events, at most once each second, and only
  when the value is more than the last value that it sent. The value is the highest
  `sequence` such that the client holds all the messages up to it as final messages.
- `cancel_message` asks the service to stop the answer `message_id`. A service that has
  `supports_cancel` must set the `status` of the message to `CANCELLED` if it is open, and
  must send `MessageStatusChanged`. If the message is final, the service sends a
  `ProtocolError` with the code `bad_state`. A service that has no `supports_cancel` sends a
  `ProtocolError` with the code `unimplemented`.
- A service can limit the queue of events that it keeps for a stream that the client does not
  read. The service chooses the limit, but the limit must be 1 000 events or more. If the queue is
  more than the limit of the service, the service can end the stream with `UNAVAILABLE`, reason
  `busy`. The client then follows the rules for a lost stream (see below), and does not tell
  the user. This is the reason why a client must read its stream.
- The service keeps the stream open until the client ends it, or the instance stops. When the
  client ends its side of the stream, the service ends its side with `OK`.

**The client after a lost stream.** The stream ends with a status that is not `OK`, or the
connection breaks:

1. The client waits 2 seconds, then 3, 5, 8 and 10 seconds, and then 10 seconds again, before
   each new try. The first wait is 0 if the stream was open for 10 seconds or more.
2. The client opens a new connection if needed, and a new stream.
3. The client sends `subscribe`, with `after_sequence` equal to the `sequence` of its first
   open message, minus 1. If it has no open message, `after_sequence` is its `latest`.
4. The client replaces each open message that it has with the message of the replay that has
   the same `message_id`. The client must not change a final message that it has.

**A first event that fails.** The service ends the call with a status, and sends no
`ProtocolError`. The cases are:

| Case | Status and reason |
|---|---|
| The first event is not `subscribe` | `FAILED_PRECONDITION`, `bad_state` |
| The `subscribe` is not valid, or its `event_id` is not valid | `INVALID_ARGUMENT`, `bad_request` |
| `after_sequence` is more than `latest` | `INVALID_ARGUMENT`, `bad_request` |
| The conversation does not exist (a `conversation_id` that is not empty) | `NOT_FOUND`, `not_found` |

The client acts on the status of a first event in this way:

- If the status is `INVALID_ARGUMENT` with `bad_request`, and the `after_sequence` of the
  client was more than 0, the copy of the client can be ahead of the service (for example,
  the instance was reset). The client drops its local copy of the conversation, reads the
  history again with `GetMessages` from `after_sequence` 0, and then subscribes. It does this
  one time for each series of tries. If the new `subscribe` fails with `bad_request` too, the
  case is the next one.
- For each other status of a first event, the client tries again with the waits of the list
  above. After 3 failures in a row, it shows the error to the user and stops. A try that gets
  `SubscriptionReady` ends the count.
- A stream that ends with `UNAVAILABLE`, reason `busy`, is not an error for the user. The
  client waits at least the first wait of the list above, 2 seconds, before it subscribes
  again, also if the stream was open for 10 seconds or more. It must never subscribe again in
  a loop with no wait.

**A `ProtocolError` that has no `event_id`.** If it comes before `SubscriptionReady`, the
client ends the stream and subscribes again with the waits above. If it comes after
`SubscriptionReady` and it is not the answer to a send (for example the `bad_request` for a
bad `event_id` of an `acknowledge`), the client ignores it and writes it in its log. It does
not read the history again because of it. A `ProtocolError` that has an `event_id` is the
answer to that event (section 6.5, table above).

The client does not poll while a stream is open. If no stream can be opened, the client can
read with `GetMessages`, with the intervals of section 10.

### 6.6 Pin a message

```
rpc SetMessagePinned(SetMessagePinnedRequest) returns (Message);
```

The service sets `pinned` of the message `message_id` to the value of the request and replies
with the message, in its state at that time. The service can do this for any message of the
conversation: a user message, an assistant message, an open message or a final message.

- If the message does not exist, the service must end the call with `NOT_FOUND`.
- If the value is the same as the value that the message has, the service changes nothing and
  replies with the message.
- If the value is not the same, the service sets `updated_at` and sends `MessagePinnedChanged`
  to each open stream (section 5.3).
- The service must not change `content` or `status` because of this call.

A client of revision 6 need not call `SetMessagePinned`. A service must implement it.

### 6.7 Capabilities

```
rpc GetCapabilities(GetCapabilitiesRequest) returns (Capabilities);
```

| Field | Meaning |
|---|---|
| `accepted_mime_types` | The media types that the service accepts, in lower case, without parameters. The kinds that the service accepts are the kinds of these types (`image`, `audio`). The list is empty if the service accepts text only |
| `max_file_bytes` | The largest file that the service accepts. 0: 4 MiB (4 194 304 bytes) |
| `max_files_per_message` | The most attachments in one message. 0: 4 |
| `max_text_bytes` | The most bytes of text (UTF-8) in one message. 0: 16 384 |
| `supports_fork` | `true` if the service implements `ForkConversation` and the conversations that are not the main conversation (section 6.8) |
| `supports_cancel` | `true` if the service implements `cancel_message` (section 6.5) |

- The service must answer this call at any time. The answer must be the same for the whole
  life of the instance, also in the first call and in the last call.
- A field that is not 0 replaces the default of section 7. A field that is 0 keeps the
  default. A service that accepts attachments must accept the media types of section 5.1.
- The client shows the attach button only for a kind that is in `accepted_mime_types`. The
  client sends no attachment if `accepted_mime_types` is empty. The client uses the lower value
  of its own limit (4 MiB and 4 files, for the memory of the app) and the limit of the
  service.
- The client uses this call as the first call. A service can need some seconds to listen after
  the start of its instance. Until then, the call fails to connect. The client calls again
  until it works (section 10).

### 6.8 Conversations and branches

The instance has one main conversation. All the calls of this document are for the main
conversation. The messages of `chat.proto` have a `conversation_id` for other conversations
(branches), which the service can implement. Chatui does not use them.

| Item | Service | Client |
|---|---|---|
| Main conversation (`conversation_id` absent or empty) | must implement | must use |
| `GetConversation` of the main conversation | must implement. It replies with `conversation_id` empty, `created_at` as the start of the instance, `archived` `false`, no `parent_conversation_id`, and `title` (section 6.10) | can ignore. A client that has no `Connect` stream can read the title here |
| A `conversation_id` that is not empty, with `supports_fork` `false` | must end the call with `NOT_FOUND` | must not send it |
| `ForkConversation`, with `supports_fork` `false` | must end the call with `UNIMPLEMENTED` | must not call it |
| `ForkConversation` and branches, with `supports_fork` `true` | The service gives each branch its own history, its own `sequence` (starts at 1) and its own `Connect` stream. A branch has the messages of its parent up to `forked_from_message_id`, as copies with new `message_id` | can ignore |

A client of revision 6 can ignore `supports_fork` and the other conversations. It must treat
an event or a message that has a `conversation_id` as not part of the main conversation. It
must ignore it.

An empty `conversation_id` has the same meaning as an absent one.

### 6.9 Answer a secret request

```
rpc AnswerSecretRequest(AnswerSecretRequestRequest) returns (AnswerSecretRequestResponse);
```

| Field | Rule |
|---|---|
| `message_id` | The `message_id` of the message that has the `SecretRequest` |
| `request_id` | The `request_id` of the `SecretRequest` |
| `value` or `skipped` | Exactly one. `value` is the text of the variable: UTF-8, 1 to 8 192 bytes, with no NUL byte. `skipped` is `true` for a skip |

The response has no field.

The service must check the request in this order and stop at the first failure:

| Step | Check | Failure |
|---|---|---|
| 1 | `message_id` is a message of the instance, and the message has a `SecretRequest` with `request_id` | `NOT_FOUND`, reason `not_found` |
| 2 | Exactly one of `value` and `skipped` is set. `skipped` with the value `false` is not a skip | `INVALID_ARGUMENT`, reason `bad_request` |
| 3 | `value`, if set, is not empty, is valid UTF-8, and has no NUL byte | `INVALID_ARGUMENT`, reason `bad_request` |
| 4 | `value`, if set, is 8 192 bytes or less | `INVALID_ARGUMENT`, reason `too_large` |
| 5 | The service can keep the value, or the skip | `INTERNAL`, reason `service_error`. The service changes nothing |

If the request was answered before, the service replies `OK` and changes nothing (section 5.6,
"Answered once"). If the checks pass, the service keeps the value or the skip, and continues the
work that waits for it.

The service must answer this call at any time, also while it makes an answer. It must reply in
30 seconds or less. It must not change `latest`. It must not reply with the value. The call is
not an event of `Connect`, and it has no `event_id`.

### 6.10 Title of the conversation

This section is revision 6, round 9. It is a proposal for issue #89, and Josemi must review
it. A service that never gives a title keeps the wire of revision 6.

The service can give the main conversation a title: a short text that tells what the
conversation is about, for example "Trip to Lisbon in May". The service chooses when it gives
the title and when it changes it. For example, a service can give a title after its first
answer. A client shows the title in place of the name of the service, in the list of
conversations and at the top of the conversation.

A title has these rules:

| Rule | Value |
|---|---|
| Text | UTF-8, 1 to 256 bytes. One line: it has no character from U+0000 to U+001F and no U+007F. An empty string is the same as absent: the conversation has no title |
| Meaning | Plain text. The client does not read Markdown or HTML in it |
| Changes | At most one change for each answer. The service must not change the title in a loop, or to show progress |
| No title | The service removes its title with a `ConversationTitleChanged` that has no `title` |

Where the title is:

| Place | Value |
|---|---|
| `Conversation.title` of `GetConversation` | The title at the time of the call, or absent |
| `SubscriptionReady.title` (field 2) | The title at the end of the replay (section 6.5, step 3), or absent |
| `ConversationTitleChanged` (event 9 of `ServerEvent`) | The new `title`, or absent if the service removed it, and `updated_at`. The service sends it to each open stream for each change after `SubscriptionReady`. It does not send it for a value that does not change the title |

The rules for the service:

- The service must give the same title in the three places at the same time.
- The service must send `ConversationTitleChanged` only after `SubscriptionReady` on that
  stream. A change during the replay is in `SubscriptionReady.title`.
- `updated_at` is the time of the change, in milliseconds since 1970-01-01 UTC. It must not
  become smaller.
- A title is not a message. It does not change `latest`, and it is not in the history.
- The title must not have a secret value (section 5.6), or private data that the user did
  not write in the conversation.

The rules for the client:

- The client reads the title in `SubscriptionReady`, and then in each
  `ConversationTitleChanged` of the stream. A client that has no stream can read it with
  `GetConversation`.
- The client must show the title as plain text. It removes the characters that control the
  direction of text (U+202A to U+202E, U+2066 to U+2069), because they can make a title look
  like another one. It can cut a long title for display.
- A name that the user gives the conversation in the client is stronger than the title. The
  client shows the name of the user, and keeps the title for the time when the user removes
  the name. The client does not send the name of the user to the service.
- A client that does not know the event ignores it (section 4): a `ServerEvent` that has no
  event that the client knows is not an error.

In chatui: the title shows in the list of conversations and at the top of the conversation,
if the user did not rename the conversation. The app keeps the last title in its database, so
the list shows it after a restart and after the instance stops. The info page of the instance
still shows the name of the service.

## 7. Limits

The values of this table are defaults. A service can set other values for the text, the files
and the number of files in `GetCapabilities` (section 6.7). The values of `GetCapabilities`
replace the defaults for that instance, and the client obeys them. A field that is 0 in
`GetCapabilities` keeps the default.

| Limit | Value |
|---|---|
| Time to reply to a send | The service must reply to `SendMessage` in 30 seconds or less. The service counts the time from the end of the request. The service does not wait for the answer, so it needs this time only to check and keep the message |
| Time to make an answer | There is no limit in this document. An answer can take minutes. The `Connect` stream stays open until the answer is final |
| Size of the text | The service must accept 16 384 bytes (UTF-8) or more of text in one message. The service can accept more, and then it sets `max_text_bytes`. The service must reply with `too_large` to a text above its own limit |
| Size of a send request | The service must accept a `SendMessageRequest` of 128 KiB (131 072 bytes) or less. A request has no file bytes, only references |
| Size of a file | A service that accepts attachments must accept a file of 4 MiB (4 194 304 bytes) or less. The service can accept more. The service must reply with `too_large` to a file above its own limit |
| Number of files | A service that accepts attachments must accept 4 attachments in one message |
| Size of a chunk | 64 KiB or less for the client, and for the service when it sends. A service must accept 1 MiB or less |
| Size of a gRPC message | The service sends 1 MiB or less. The service accepts 4 MiB or less. The client accepts 4 MiB or less |
| Size of a delta | `text_append` and `reasoning_append` are 64 KiB or less each |
| Open streams | The service must allow 8 HTTP/2 streams at the same time on one connection |
| Messages that wait | The service decides how many user messages can wait for an answer. When it cannot keep one more, it replies to a send with `UNAVAILABLE`, reason `busy` |
| Size of the history | The service decides. When the history has no room for the user message and its answer, the service replies with `RESOURCE_EXHAUSTED`, reason `history_full` |
| Size of one message | A message must be 1 MiB or less in its serialized form. A service that makes a longer answer must end the answer, with the status `COMPLETED`, before the message reaches the limit. The service must not make the answer in more than one message |
| Time to upload or download | The client waits 120 seconds for one `UploadFile` or `DownloadFile` call |

The limit for the text of 16 384 bytes and the limit of 128 KiB for the request keep the
rules of revision 5. In revision 5, 4 files of 4 MiB were in the body of the send, in base64.
Now the files go in `FileService`, one call for each file.

## 8. Example

This section is an example only.

```
Client                                    Service
  GetCapabilities  ---------------------> accepted_mime_types = [image/jpeg, ...]
  GetMessages(after_sequence=0) ---------> (messages 1..N, then end)
  Connect: subscribe(after_sequence=N) --> SubscriptionReady(latest=N)
  QueryFiles(h) -------------------------> available=false
  UploadFile(file, chunks) --------------> FileReference (checked)
  SendMessage(text + image(h), key=k1) --> Message 11 (user, COMPLETED)
                                           MessageCreated(11)           (on the stream)
                                           MessageCreated(12, IN_PROGRESS, empty)
                                           MessageDelta(12, reasoning_append="...")
                                           MessageDelta(12, text_append="Hello")
                                           MessageStatusChanged(12, COMPLETED)
```

## 9. Errors

The service ends a call that fails with a gRPC status, and sets the trailer `chat-reason`
(ASCII, lower case) to the reason. The `grpc-message` is a text that the client can show to the
user. It is optional.

| gRPC status | `chat-reason` | Meaning | Client kind (`ChatErrorKind`) |
|---|---|---|---|
| `INVALID_ARGUMENT` | `bad_request` | A request is not valid. The list below gives the cases | `badRequest` |
| `INVALID_ARGUMENT` | `unsupported_media` | A `mime_type` is not accepted, or the service accepts text only. The service changed nothing | `unsupportedMedia` |
| `INVALID_ARGUMENT` | `too_large` | The text, a file or a request is above the limit of the service | `badRequest` |
| `INVALID_ARGUMENT` | `hash_mismatch` | The bytes of an upload do not have the hash or the size that the client gave | `badRequest` |
| `NOT_FOUND` | `not_found` | A message, a conversation, a file or a secret request does not exist | `badRequest` |
| `FAILED_PRECONDITION` | `file_missing` | A message references a file that the service does not have. The client uploads it and sends again (section 6.4) | `badRequest` |
| `FAILED_PRECONDITION` | `bad_state` | The call is not valid in this state: the first event of `Connect` is not `subscribe`, or the answer is final | `badRequest` |
| `RESOURCE_EXHAUSTED` | `history_full` | The history does not have room for more messages. The client tells the user to start a new instance. A service must not use it for a file | `historyFull` |
| `RESOURCE_EXHAUSTED` | `storage_full` | The file store cannot take an upload (section 6.4). The client tells the user. It does not send the file again by itself | `badRequest` |
| `RESOURCE_EXHAUSTED` | none | The gRPC layer rejected a message that is above its receive limit. The client treats it as `too_large` for a send and for a file call | `badRequest` |
| `UNAVAILABLE` | `busy` | The service cannot keep one more message that waits for an answer, or it ends a `Connect` stream because the queue of that stream is full. For a send, the client tells the user and the service changed nothing. For a stream, the client subscribes again | `busy` |
| `UNAVAILABLE` | none | The tunnel, the connection or the instance is not there. The client tries again (section 6.3 and section 10) | `unreachable` |
| `INTERNAL` | `service_error` | The service failed to take the message. The service changed nothing | `other` |
| `UNIMPLEMENTED` | `unimplemented` | The call or the optional feature is not implemented | `other` |
| `DEADLINE_EXCEEDED`, `CANCELLED` | none | The client gave up. The client sets these codes, not the service | `unreachable` |

The status `INVALID_ARGUMENT` with the reason `bad_request` is for one of these cases:

- `content` has no part, or a part has no `kind` that a client can send.
- The text is empty and there is no attachment.
- `idempotency_key` is not valid.
- A hash of the SHA3-256 type has a `value` that is not 32 bytes.
- A `FileReference` has a hash with no `type`, no hash that the service knows, no `mime_type`,
  or a `size_bytes` of 0 (an empty file).
- The `mime_type` of an `image` part starts with `audio/`, or the `mime_type` of an `audio` part
  starts with `image/`.
- A message has more than 4 attachments.
- `after_sequence` is more than `latest`, or `last_sequence` of an `acknowledge` is more than
  `latest`.
- An `event_id` is not valid, or it was used before in the same stream.
- A hash of a `QueryFiles`, `DownloadFile` or `UploadFile` call has no `type` (an empty `type`), or the first message of an
  `UploadFile` stream is not a `FileReference`.

The status `INVALID_ARGUMENT` with the reason `bad_request` is also for `AnswerSecretRequest` with no answer, with both answers, with an empty `value`, or with a `value` that is not valid UTF-8 or has a NUL byte (section 6.9). The status `INVALID_ARGUMENT` with the reason `too_large` is also for a `value` above 8 192 bytes.

`ProtocolError.code` in a `Connect` stream has the same names as `chat-reason`, and
`ProtocolError.message` is a text for the user. `ProtocolError.event_id` is the `event_id` of
the `ClientEvent` that failed (section 6.5). A `ProtocolError` does not end the stream. A
`ProtocolError` with an `event_id` has the same meaning as the status of the table that has
the same reason: the client handles both in the same way.

A service must not use a status that is not in this table for a call that this document
defines. A client treats a status that is not in this table as an error that it does not know
(`ChatErrorKind.other`). A client treats `UNAVAILABLE` as `busy` only if the reason is
`busy`. Other `UNAVAILABLE` statuses are `unreachable`. A client treats `RESOURCE_EXHAUSTED`
that has no `chat-reason` as `too_large` for a send and for a file call, and as `other` for
each other call.

The service must never change `latest` for a send that failed.

## 10. Client rules

These rules cover the protocol only. The screens, the cost, the stop of an instance and the
storage of the app are not part of this document ([ui-chat-first.md](ui-chat-first.md)).

- The client can send a message at any time. It does not wait for the answer to an earlier
  message, and it does not wait for an earlier send to end.
- The client must use one HTTP/2 connection for all its calls (section 4). Each connection
  through the tunnel is one `ServiceTunnel` stream, and the node charges for each stream
  (`TUNNEL_OPEN_MU`).
- The client must give each send a new `idempotency_key` (section 6.1).
- The client must send its messages over `Connect` when its stream is open and has had
  `SubscriptionReady`. It sets `event_id` in the event and `idempotency_key` in the send. It
  matches the user message to the send by `idempotency_key`, and a `ProtocolError` by
  `event_id`. When no stream is open (also in the watcher of answers), it sends with
  `SendMessage`. The key rules are the same for the two ways. If a stream breaks after a
  send over `Connect`, the client follows section 6.3.
- The client reads with `Connect` and `GetMessages`.
- The client must not let the title of the service replace a name that the user gave the
  conversation (section 6.10).
- The client must not send the text of the input to the service before the user sends it. A
  suggestion of the service puts text in the input, and does not send it (section 5.7).
- The client must not send a message that has no text and no attachment.
- The client must send an attachment only if `GetCapabilities` has the media type in
  `accepted_mime_types`.
- The client must not send more than 4 attachments in one message. The client must not send a
  file above 4 MiB. It must not send more than the limits of the service (section 6.7).
- The client must send only the media types of the table in section 5.1.
- The client must send a file with the flow of section 6.4. It must not upload a file that
  `QueryFiles` says is available.
- The client must read the bytes of a file only with `DownloadFile`, and must check the hash.
  It must not call `DownloadFile` for a `FileReference` that has no SHA3-256 hash (section 6.4).
- If the call ends with `unsupported_media`, the client must not send the same files again.
  The client tells the user.
- If the call ends with `bad_request`, `too_large` or `hash_mismatch`, the client must not
  send the same send again by itself. The client tells the user.
- If a send ends with `busy`, the client tells the user. The user decides to send again. If a
  `Connect` stream ends with `busy`, the client does not tell the user, and subscribes again.
- If an upload ends with `storage_full`, the client tells the user and does not send the file
  again by itself.
- The client must call `GetCapabilities` first, and then read the history from `after_sequence`
  0 when it opens a conversation that it does not have.
- The client waits for an answer when the messages that it has include an open message. It
  does not compare the number of user messages with the number of assistant messages: a
  service does not have to answer each user message (section 5.2).
- The client must open `Connect` and follow section 6.5. It must apply the events in
  the order that it gets them:
  - `MessageCreated` of a message that the client does not have adds the message. For a
    message that the client has as open, the new message replaces it. A final message that the
    client has does not change.
  - `MessageDelta` adds the text to the message that the client has, as section 5.2 says. A
    delta of a message that the client does not have, or that is final, is ignored.
  - `MessageStatusChanged` sets `status`, `updated_at` and, if it has `error`, `error`.
  - `MessagePinnedChanged` sets `pinned` and `updated_at`.
  - `ProtocolError` with an `event_id` is the failure of the event that has that `event_id`. The
    client handles it as the status of section 9 that has the same reason.
- The client sends `acknowledge` as section 6.5 says.
- The client shows the `error` of a `FAILED` message to the user if there is one. It must not
  read the failure from the text, and must not need `error` to show that the message failed.
- The client treats `CANCELLED` as a final status. It gets no notice of a done answer, as a
  `FAILED` message. The client shows the message as cancelled. Chatui has no button that
  cancels an answer, so it sends no `cancel_message`.
- A client that has no open stream can read with `GetMessages`. While it waits for an answer,
  it reads every 2 seconds. Otherwise it reads every 10 seconds, or less often. It must not
  read more than one time each second. It reads from the `sequence` of its first open message
  minus 1, and if it has none, from its own `latest`.
- A service can need some seconds to listen after the start of its instance. Until then, a
  call fails to connect. The client can call `GetCapabilities` again until the service answers.
  It must not send a message before `GetCapabilities` works.
- A client that gets a `sequence` that is not the next one (a gap) must treat the answer as an
  error. A client skips a message that it has already, if that message is final.
- The client must show `reasoning` apart from the text. It must not mix them.
- The client must follow section 6.3 after a lost connection, and section 6.5 after a lost
  stream.
- The client shows a `secret_request` part as a card in the conversation, with its `name` and
  `prose`. A tap on the card opens the selector of `env-variables.md`, section 3: the entries of
  the container, with the entries of the same name first, a field for a typed value, and **Skip**.
  The values are not shown. With an empty container, the selector says where to add variables.
- A typed value can be saved in the container with a name (section 5.6). The switch **Sensitive**
  of the question becomes the sensitive mark of the new entry.
- The client reads the value of the chosen entry from the container only after the user
  confirms, and only for the call. The chat client is in Dart, so the value is in the memory of
  Dart during the call; it is not kept after it. The client sends the value, or the skip, with `AnswerSecretRequest` only. It never
  sends a secret as an event of `Connect`.
- Before the client sends a sensitive value (the mark of an entry, or the switch of a typed value),
  it shows the warning of section 5.6. The warning applies when the node of the instance is not
  fully trusted, or when the service declares any network. With egress, the warning is the red
  card of `env-variables.md`, section 3.2, and **Deny** is the default. Deny sends nothing. A value
  that is not sensitive gets no warning.
- After the answer, the card shows "Sent: NAME" or "Skipped". The state is kept by the client.
  The client never writes the value into a message, a log, the text of the input or an error.
- If `AnswerSecretRequest` ends with an error, the client tells the user. It does not send the
  answer again by itself.
- The client must ignore a message, an event and a `ContentPart` that it does not know.
- The client shows a button for each `slot_link` of a `COMPLETED` assistant message whose `port` is a slot that counts and that it supports. It opens the slot only after a tap on the button (section 5.8).

## 11. Conformance

A service follows revision 6 if it obeys each "must" and "must not" of sections 3 to 9. A
client follows revision 6 if it obeys each "must" and "must not" of sections 6.3, 6.4, 6.5
and 10.

### 11.1 Tests

Run these tests on a new instance. A test tool is a gRPC client that can open h2c on the
local port of the tunnel (for example `grpcurl -plaintext`, with `chat.proto`). `N` is the
`latest` of the service at the time of the test. "Wait for the answer" means: read
`GetMessages(after_sequence=<sequence>)` every second, until the assistant message with
`reply_to_message_id` equal to the user message is final. "Stream" means an open `Connect`
stream, after `subscribe`. Each test gives the expected result. A service that accepts
attachments has `accepted_mime_types` that is not empty. A service that accepts text only
has it empty.

| # | Call | Expected result |
|---|---|---|
| 1 | `GetCapabilities` over h2c with no TLS and no ALPN | `OK`. A client that sends HTTP/1.1 gets a failure, and the service does not stop |
| 2 | `GetCapabilities` at the start, after a send and after the last test | The three results are equal. Each type in `accepted_mime_types` is in lower case. If the list has an `image/*` type, it has `image/jpeg` and `image/png`. If it has an `audio/*` type, it has `audio/mpeg` and `audio/wav`. |
| 3 | `GetMessages(after_sequence=0)` | `OK`, no message |
| 4 | `Connect`, `subscribe(after_sequence=0)` | `SubscriptionReady` with `latest_sequence` 0, and no `MessageCreated` before it |
| 5 | `GetMessages(after_sequence=1)` on an empty history | `INVALID_ARGUMENT`, reason `bad_request` |
| 6 | `SendMessage` with text "one" and key `t6` | `OK`. The message has `sequence` 1, `from_service` `false`, `status` `COMPLETED`, text "one", `idempotency_key` `t6` and a `message_id` |
| 7 | Wait for the answer to test 6 | The history has an assistant message with `reply_to_message_id` equal to the `message_id` of test 6, `from_service` `true`, and `status` `COMPLETED` or `FAILED`. Its `sequence` is more than 1 |
| 8 | `SendMessage` with text "one" and key `t6` again | `OK`, with the same `message_id` and `sequence` as test 6. `latest` does not change. No second answer starts |
| 9 | Two `SendMessage` calls at the same time, with different keys | `OK` for each, with two different `sequence`. After the answers, the history has the two user messages and one answer for each |
| 10 | `SendMessage` while the service makes an answer (a slow service) | `OK` at once. It does not wait for the answer. It is not `busy` |
| 11 | `GetMessages(after_sequence=1, limit=1)` when the history has 3 messages or more | One message, with `sequence` 2 |
| 12 | `GetMessages(after_sequence=N)` | `OK`, no message |
| 12a | `GetMessages(last=2)` when the history has 3 messages or more | The last two messages, in order of `sequence` |
| 12b | `GetMessages(before_sequence=3)` when the history has 3 messages or more | The messages with `sequence` 1 and 2 |
| 12c | `GetMessages(limit=1, last=1)` | `INVALID_ARGUMENT`, reason `bad_request` |
| 13 | `SendMessage` with: no `content`; one text part with an empty text; a part that has no `kind`; the key `a b`; a key of 65 characters; a key of 64 characters with a character that is not allowed | `INVALID_ARGUMENT`, reason `bad_request` for each. `latest` stays the same |
| 13a | `SendMessage` with `idempotency_key` `""` and `reply_to_message_id` `""` | `OK`. The user message has no `idempotency_key` and no `reply_to_message_id` (an empty string is the same as absent). A second call with the same values adds a second message |
| 14 | `SendMessage` with the text `  x  é ✓` | `OK`. The text of the user message is `  x  é ✓`, without a change |
| 15 | `SendMessage` with a text of 16 384 bytes. Use a second call with 16 384 newline characters. Use a third call with two text parts that give 16 384 bytes together | `OK` for each. The text of the message is the text of the parts, joined |
| 16 | `SendMessage` with a field that the service does not know (for example field number 99) | `OK`. The service ignores the field |
| 17 | `SendMessage` with `reply_to_message_id` that does not exist | `NOT_FOUND`. `latest` does not change |
| 18 | `SendMessage` with `conversation_id` `"other"`, on a service that has `supports_fork` `false` | `NOT_FOUND`. `latest` does not change |
| 19 | After the answer of test 7 is final, `GetMessages` for the same message two times | The two messages are equal, with the same `updated_at`. A final message does not change |
| 20 | `SendMessage` with a stream open. A service that streams (see the note below) | The stream gets in order: `MessageCreated` of the user message, `MessageCreated` of the assistant message (`PENDING` or `IN_PROGRESS`), `MessageStatusChanged` from `PENDING` to `IN_PROGRESS` (only if the assistant message was `PENDING`: a service that adds the answer only when its turn starts, always `IN_PROGRESS`, sends no such event), zero or more `MessageDelta`, and `MessageStatusChanged` with `COMPLETED`. The text of the `MessageCreated` of the assistant message, plus each `text_append`, is equal to the text of that message in a `GetMessages` after the end. `latest` does not change while the text grows |
| 21 | As test 20, with a service that gives reasoning | `reasoning_append` events make `reasoning`. The `reasoning` after the end is equal to the sum of the first `reasoning` and the `reasoning_append` values. The reasoning is not in a `TextContent` |
| 22 | A new stream after the answer: `subscribe(after_sequence=0)` | One `MessageCreated` for each message, in order of `sequence`, then `SubscriptionReady` with `latest_sequence` equal to `latest`. The state of each message is the final state |
| 23 | A new stream while an answer is open (a slow service): `subscribe(after_sequence=0)` | The `MessageCreated` of the open message has its state at that time. Then the deltas follow. At the end, the text is equal to the final text of a read |
| 24 | A stream, then `send_message` as the first event (no `subscribe`) | `FAILED_PRECONDITION`, reason `bad_state`, and the stream ends |
| 25 | A stream, then a second `subscribe` | A `ProtocolError` with the code `bad_state` (with the `event_id` if the event had one). The stream stays open and gets the next events |
| 26 | A stream, then `send_message` with a valid message, `event_id` `e1` and `idempotency_key` `k26` | `MessageCreated` of the user message, with `idempotency_key` `k26`, and then the events of the answer, as in test 20. The stream gets no `ProtocolError` |
| 27 | A stream, then `send_message` with an empty `content` and `event_id` `e2` | A `ProtocolError` with the code `bad_request` and `event_id` `e2`. The stream stays open. `latest` does not change |
| 27a | A stream, then `send_message` with `event_id` `e1` again (the id of test 26) | A `ProtocolError` with the code `bad_request` and no `event_id`. The service adds no message |
| 27b | A stream, then `send_message` with an `event_id` of 65 characters | A `ProtocolError` with the code `bad_request` and no `event_id`. The stream stays open. The service adds no message |
| 27c | A stream, then `send_message` with the `idempotency_key` of test 26 and a new `event_id` | `MessageCreated` with the same `message_id` and `sequence` as in test 26. `latest` does not change. No second answer starts |
| 27d | A stream, then `send_message` with an attachment that is not accepted, and `event_id` `e3` | A `ProtocolError` with the code `unsupported_media` and `event_id` `e3`. The stream stays open |
| 27e | A stream, then `acknowledge` with `last_sequence` equal to `latest` after the answers are final | No event. The stream stays open and gets the next events. The history is the same in a `GetMessages` |
| 27f | A stream, then `acknowledge` with `last_sequence` equal to `latest` + 1 and `event_id` `e4` | A `ProtocolError` with the code `bad_request` and `event_id` `e4`. The stream stays open |
| 27g | A stream, then `acknowledge` with a value that is less than the value of test 27e | No event, no error. The history is the same |
| 27h | `Connect`, with `subscribe` that has `event_id` `s1`, then `send_message` with `event_id` `s1` | A `ProtocolError` with the code `bad_request` and no `event_id`. The service adds no message |
| 27i | `Connect` with `subscribe` that has an `event_id` of 65 characters | The call ends with `INVALID_ARGUMENT`, reason `bad_request`. There is no `ProtocolError` |
| 27j | `Connect` with `subscribe` that has `conversation_id` `"other"`, on a service that has `supports_fork` `false` | The call ends with `NOT_FOUND`, reason `not_found`. There is no `ProtocolError` |
| 27k | A stream that the client does not read, while the service makes 1 000 events or more (optional) | The service can end the stream with `UNAVAILABLE`, reason `busy`, and it does this only after 1 000 events or more are in the queue. A new stream with `subscribe` works |
| 27l | A stream, then `acknowledge` with an `event_id` of 65 characters | A `ProtocolError` with the code `bad_request` and no `event_id`. The stream stays open |
| 28 | `subscribe(after_sequence=N+1)` | `INVALID_ARGUMENT`, reason `bad_request` |
| 29 | `SendMessage` while the service fails to make the answer (optional) | `OK`. The answer is a message with `status` `FAILED`, with `error` that is a text of 1 to 1 024 bytes. A stream gets `MessageStatusChanged` with `FAILED` and the same `error`. `error` is the same in each later read. A message that is not `FAILED` has no `error`. The next `SendMessage` works. A service that never uses `PENDING` passes this row: the message goes from `IN_PROGRESS` to `FAILED` (or is made `FAILED`), and the row needs no `PENDING` state |
| 30 | `SendMessage` while the service fails to take the message (optional) | `INTERNAL`, reason `service_error`. `latest` does not change. A read does not show the user message |
| 31 | Send messages until the history is full (optional) | `RESOURCE_EXHAUSTED`, reason `history_full`. `latest` does not change |
| 32 | Send messages until the queue is full (optional) | `UNAVAILABLE`, reason `busy`. `latest` does not change |
| 33 | `SetMessagePinned(pinned=true)` for the assistant message of test 7, with a stream open | `OK`. The message has `pinned` `true` and `updated_at` not less than before. The stream gets `MessagePinnedChanged` with `pinned` `true` |
| 34 | `SetMessagePinned(pinned=true)` for the user message of test 6 | `OK`. `pinned` is `true`. The content and the `status` are the same |
| 35 | `SetMessagePinned(pinned=true)` again for the assistant message of test 33 | `OK`. `updated_at` is the same as in the call before. The stream gets no event |
| 36 | `SetMessagePinned(pinned=false)`, then a read of the history | `pinned` is `false` in each read. `updated_at` is not less than in test 33 |
| 37 | `SetMessagePinned` for a `message_id` that does not exist | `NOT_FOUND` |
| 38 | `SetMessagePinned` while a message is open (a slow service) | `OK`. The message keeps growing. In the final message, `pinned` is the value that the call set |
| 39 | A service that pins messages when it makes them (optional): read the history | The message that the service pins has `pinned` `true`, in `MessageCreated` and in each read. The value does not change until a call changes it |
| 40 | `GetConversation` for the main conversation | `OK`. `conversation_id` is empty, `created_at` is more than 0, `archived` is `false` |
| 41 | `ForkConversation`, on a service that has `supports_fork` `false` | `UNIMPLEMENTED` |
| 42 | `ForkConversation` for a message of the history, on a service that has `supports_fork` `true` (optional) | A `Conversation` with a `conversation_id` that is not empty. `GetMessages` for it gives its own messages, with `sequence` that starts at 1 |
| 43 | A stream, `cancel_message` with an `event_id` for an open message, on a service that has `supports_cancel` `true` (optional) | `MessageStatusChanged` with `CANCELLED`. The message is final |
| 44 | `cancel_message` with `event_id` `e5` for a final message (optional) | A `ProtocolError` with the code `bad_state` and `event_id` `e5`. The stream stays open |
| 45 | `cancel_message` with `event_id` `e6`, on a service that has `supports_cancel` `false` | A `ProtocolError` with the code `unimplemented` and `event_id` `e6` |
| 46 | Five unary calls on one HTTP/2 connection, with a stream open | All get an answer on the same connection. The service does not close the connection |
| 47 | A `Connect` stream and 7 unary calls at the same time on one connection | All 8 calls run at the same time |
| 48 | `QueryFiles` with two hashes that are not in the service. Both have the SHA3-256 `type` | Two responses, in the same order. Each has the `type` and `available` `false` |
| 48a | `QueryFiles` with a `type` of 64 bytes (the ASCII hexadecimal text of the SHA3-256 `type`) | A response with `available` `false`. It is not an error. The same query with the 32 raw bytes of the `type` and the hash of the file of test 51 gives `available` `true` after test 51 |
| 48b | (removed in round 5: a `type` that is set and empty cannot be told from a missing `type`, so test 49 covers it. The number stays, so that the other numbers do not change) | |
| 49 | `QueryFiles` with a hash that has no `type` (empty), as the first hash, and a second call with that hash as a later hash | `INVALID_ARGUMENT`, reason `bad_request` for each. The service does not reuse the `type` of an earlier hash |
| 49a | `QueryFiles` with a hash of the SHA3-256 `type` and a `value` of 31 bytes | `INVALID_ARGUMENT`, reason `bad_request` |
| 50 | `QueryFiles` with a `type` that the service does not know | A response with `available` `false`. It is not an error |
| 51 | `UploadFile` with a valid PNG of a known hash, in chunks of 64 KiB, if `accepted_mime_types` has `image/png` | `OK`. The `FileReference` has the SHA3-256 hash with its `type`, and `size_bytes` equal to the real size |
| 52 | `QueryFiles` for the hash of test 51 | `available` `true` |
| 53 | `DownloadFile` for the hash of test 51 | The chunks, joined, are the same bytes. Each chunk is 64 KiB or less. The SHA3-256 of the bytes is the hash |
| 54 | `UploadFile` with a hash that is not the hash of the bytes | `INVALID_ARGUMENT`, reason `hash_mismatch`. `QueryFiles` for that hash gives `available` `false` |
| 55 | `UploadFile` with `size_bytes` that is not the number of bytes | `INVALID_ARGUMENT`, reason `hash_mismatch` |
| 55a | `UploadFile` with `size_bytes` 0 and no chunk | `INVALID_ARGUMENT`, reason `bad_request`. `QueryFiles` gives `available` `false` |
| 55b | `UploadFile` with a hash that has no `type` (empty) | `INVALID_ARGUMENT`, reason `bad_request` |
| 55c | `UploadFile` with `mime_type` `application/pdf` and `size_bytes` above the limit; a second call with `size_bytes` above the limit and a second message that has `file` | `INVALID_ARGUMENT`, reason `too_large` for each (the size is checked before the type, and before a later `file`) |
| 55e | `UploadFile` with a valid first message and a second message that has `file`, in the limit of size | `INVALID_ARGUMENT`, reason `bad_request`. `QueryFiles` gives `available` `false` |
| 55f | `UploadFile` with a SHA3-256 hash whose `value` has 31 bytes | `INVALID_ARGUMENT`, reason `bad_request` |
| 55d | `UploadFile` while the file store is full (optional) | `RESOURCE_EXHAUSTED`, reason `storage_full`. `QueryFiles` gives `available` `false`. A `SendMessage` after it is not `history_full` |
| 56 | `UploadFile` where the first message is a `chunk`, and a second call where a later message is a `file` | `INVALID_ARGUMENT`, reason `bad_request` for each |
| 57 | `UploadFile` with `mime_type` `application/pdf` | `INVALID_ARGUMENT`, reason `unsupported_media`. `QueryFiles` gives `available` `false` |
| 58 | `UploadFile` with a file of exactly 4 MiB (only if `accepted_mime_types` has the type) | `OK` |
| 59 | `UploadFile` with a file of 4 MiB + 1 byte (only if the limit of the service is 4 MiB) | `INVALID_ARGUMENT`, reason `too_large`. `QueryFiles` gives `available` `false` |
| 60 | `UploadFile` with the file of test 51 again | `OK`, with the same `FileReference` |
| 61 | `SendMessage` with an `ImageContent` for the file of test 51 and an empty text (only if `accepted_mime_types` has `image/png`) | `OK`. The user message has an `image` part with the same hash, `mime_type` `image/png` and `size_bytes`. The message has no file bytes |
| 62 | `DownloadFile` for the hash of the message of test 61 | The same bytes as in test 53 |
| 63 | `SendMessage` with an `ImageContent` of a hash that was never uploaded | `FAILED_PRECONDITION`, reason `file_missing`. `latest` does not change |
| 64 | `SendMessage` with an `image` part that has `mime_type` `application/pdf`; a second call with an `image` part that has `mime_type` `audio/wav`; a third call with an `audio` part that has `mime_type` `image/png` | `INVALID_ARGUMENT`, reason `unsupported_media` for the first, and `bad_request` for the second and the third. `latest` does not change |
| 64a | `SendMessage` with an `image` part whose `FileReference` has a hash with no `type`, and a second call with a `FileReference` that has `size_bytes` 0 | `INVALID_ARGUMENT`, reason `bad_request` for each. `latest` does not change |
| 65 | `SendMessage` with 5 attachments | `INVALID_ARGUMENT`, reason `bad_request`. `latest` does not change |
| 66 | `SendMessage` with an attachment, on a service that has an empty `accepted_mime_types` | `INVALID_ARGUMENT`, reason `unsupported_media`. `latest` does not change |
| 67 | `SendMessage` with an attachment of a kind that is not in `accepted_mime_types` (for example `audio/mpeg` to a service that accepts only images) | `INVALID_ARGUMENT`, reason `unsupported_media`. `latest` does not change |
| 68 | `SendMessage` with `mime_type` `IMAGE/PNG` and the file of test 51 (only if `accepted_mime_types` has `image/png`) | `OK`. The part has `mime_type` `image/png` |
| 69 | `SendMessage` with 4 attachments of 4 MiB each, uploaded before (only if the type is accepted) | `OK` |
| 70 | `SendMessage` with a recorded `audio/wav` and `duration_ms`, uploaded before (only if `accepted_mime_types` has `audio/wav`) | `OK`. `duration_ms` is the same in the message |
| 71 | `DownloadFile` for a hash that is not in the service, and for a hash with no `type` (empty) | `NOT_FOUND`, and `INVALID_ARGUMENT` with reason `bad_request` |
| 72 | `DownloadFile` for the file that an assistant message references (only for a service that sends files, or an echo service that returns the attachments) | The bytes, and the SHA3-256 of the bytes is the hash of the message. The `FileReference` of that message has a SHA3-256 hash with a `type` |
| 73 | `FileService` on a service that accepts no attachment (only if it does not implement `FileService`) | `UNIMPLEMENTED` for each call |
| 73a | `SendMessage` with a message that is above the receive limit of the gRPC layer, 4 MiB + 1 byte (optional) | `RESOURCE_EXHAUSTED` with no `chat-reason`. The service does not stop |
| 74 | A call to a method that `chat.proto` does not define | `UNIMPLEMENTED` |
| 75 | `GetMessages` after the service asks for a secret, with `name` `TEST_SECRET` (only for a service that sends secret requests) | An assistant message with a `secret_request` part that has `request_id` and `name`. Its `status` is `COMPLETED`. The part has no value |
| 76 | `AnswerSecretRequest` with the message and the `request_id` of test 75, and `value` `test-value` | `OK`. The service continues the work that waits for the value. Its new assistant message has `reply_to_message_id` equal to the `message_id` of test 75 |
| 77 | `GetMessages`, the replay of `Connect` and the logs of the service, after test 76 | The text `test-value` is in none of them |
| 78 | `AnswerSecretRequest` with `skipped` `true` for a second request | `OK`. The service goes on with no value, or ends the answer with a text |
| 79 | `AnswerSecretRequest` for test 76 again, with `value` `other-value` | `OK`, and no change. The service does not use `other-value` |
| 80 | `AnswerSecretRequest` with an unknown `request_id`; with a valid `request_id` and no answer; with both answers; with an empty `value`; with a `value` that has a NUL byte | `NOT_FOUND` for the first. `bad_request` for each of the others. The service changes nothing |
| 81 | `AnswerSecretRequest` with a `value` of 8 193 bytes | `INVALID_ARGUMENT`, reason `too_large` |
| 82 | `AnswerSecretRequest` while the service makes an answer | `OK` at once |
| 83 | `GetConversation` on a new instance, then subscribe | No `title`, or the same `title` in the two. `SubscriptionReady` has `title` only if the conversation has one |
| 84 | Stream. Make the service give a title (for example, send a message to a service that gives a title after its first answer) | `ConversationTitleChanged` with `title` of 1 to 256 bytes, with no control character, after `SubscriptionReady`. `GetConversation` gives the same `title` |
| 85 | Subscribe again after test 84 | `SubscriptionReady` has the `title` of test 84. No `ConversationTitleChanged` before `SubscriptionReady` |
| 86 | Two streams. The title changes | Each stream gets one `ConversationTitleChanged`, with the same `title` and `updated_at`. `latest` does not change |
| 87 | Send a message to a service that suggests. Wait for the answer | The answer is `COMPLETED` and has 0 to 3 `suggestions`, each of 1 to 64 characters, in one line. A streamed answer has them in the `MessageStatusChanged` of `COMPLETED`, and not before |
| 88 | Read the answer of test 87 again, with `GetMessages` and with a new `Connect` | The same `suggestions`, in the same order |
| 89 | Send with `corrector` (`enabled` `true`, one `Correction` `teh` to `the`) and the text `the cat` | `OK`. The text of the user message is `the cat`. If the service keeps `corrector`, the user message has it as it was sent |
| 90 | Send with `corrector` that has 40 corrections, and a `replacement` that is not in the text | `OK`. The send does not fail because of `corrector` |
| 91 | Send `/cards` (or the command of the service that makes a link) to a service that sends `slot_link` | The answer is `COMPLETED`, and has a `slot_link` with the `port` of a slot of the instance |
| 92 | Read the answer of test 91 again, with `GetMessages` and with a new `Connect` | The same `slot_link` |
| 93 | (Client) A `slot_link` with a port that is not a slot of the instance | No button. The text of the message shows |
| 94 | (Client) A `slot_link` to a `cards` slot | A button under the message. The deck opens only after a tap |

Tests 20, 21, 23 and 38 apply to a service that streams or takes time to answer. A service
that does not do these things can skip them. For a service that sends the whole answer, test
20 gives `MessageCreated` with `COMPLETED` and no delta. The test for a service that returns
the attachments of the user message in its answer (an echo service, for example) is test 72,
and it applies only to that service. Tests 29 to 32, 39, 42 to 44, 55d, 72 and 73a are
optional. A service can fail on request only if it has a way to make it fail, for example
a test mode. A service with a large history limit does not fill the history in a test. Tests
48 to 72 (with the tests that have a letter) apply to a service that accepts attachments. A service that accepts text only runs
tests 48, 48a, 49, 49a, 50, 57, 66, 71 and 73.

Tests 75 to 82 apply to a service that sends secret requests. A service that does not send them can skip them.

Tests 84 to 86 apply to a service that gives a title. A service that does not give a title runs test 83 only.
Tests 87 and 88 apply to a service that sends suggestions. Each service runs tests 89 and 90.
Tests 91 and 92 apply to a service that sends `slot_link`. Tests 93 and 94 are for a client.

## 12. Changes to the interface

The tag is `chat` and it has no version. This document has a revision number. The
revision number is for the people who write services and clients. It is not on the wire.
The method paths (`/ChatService/<Method>`, `/FileService/<Method>`) have no package and no number.

A change must not break a service or a client that follows this document.

- A new field of `chat.proto` is optional and has a new number. A client or service that does
  not know it ignores it. A number that was used does not get a new meaning.
- A new `status`, a new reason or a new event is not permitted for a call that this document
  defines, unless the document gives a rule that an old client can follow.
- A change to a "must" is a new revision. The revision history (section 14) lists it.

Revision 6 is an exception to this rule. It breaks revision 5: the transport and the slot
protocols are not the same (section 3). A service of revision 5 and a client of revision 6 do
not work together, and the opposite is true too. All the services and the clients of this
repository follow revision 6 after the migration of section 13.

## 13. Differences from revision 5

### 13.1 What stays the same

- The service keeps the history, in the order of the messages. The instance is the conversation.
- A send gives the message to the service and replies at once. The service makes the answer in
  the background. Many sends can be in progress.
- A message is not removed. A final message does not change.
- The roles do not alternate. An answer is linked to its user message.
- Streaming answers and `reasoning` are optional. A service that sends the whole answer stays
  valid.
- A send can be repeated with the same key, with no second message.
- The media types, the number of files (4), the size of a file (4 MiB), the size of the text
  (16 384 bytes) and the rule that `audio/wav` is accepted.
- The service must not change the text of a user message.

### 13.2 What changes

| Revision 5 | Revision 6 |
|---|---|
| HTTP/1.1 with JSON on the port of the slot | gRPC over HTTP/2, in clear text (h2c), defined by `chat.proto` |
| `protocol_stack`: `http`, `chat` | `protocol_stack`: `http2`, `grpc`, `chat` |
| `POST /chat/messages` | `send_message` of `Connect` when the stream is open (`event_id`, matched by `idempotency_key`), and `SendMessage` otherwise. A service must implement both |
| `GET /chat/messages?from=&last=&limit=` | `GetMessages(after_sequence, before_sequence, limit, last)`. `from` is `after_sequence` + 1 |
| The client polls every 2 or 10 seconds | The client opens `Connect` and gets events. `GetMessages` is for the catch-up |
| `seq`, from 0 | `sequence`, from 1. `seq` of revision 5 is `sequence` - 1 |
| `count` | `latest`. It is the `sequence` of the last message. It is in `SubscriptionReady` |
| `role` `user` or `assistant` | `from_service` `false` or `true` |
| `text` | The `TextContent` parts of `content`, joined |
| `reasoning` (string) | `reasoning` (string, field 12) |
| `status` `streaming`, `done`, `failed` | `PENDING` or `IN_PROGRESS`, `COMPLETED`, `FAILED`. New: `CANCELLED` |
| A message that grows: each read gives the whole text | `MessageCreated` gives the text so far, and `MessageDelta` adds text at the end |
| `reply_to` (`seq` of the user message) | `reply_to_message_id` (`message_id` of the user message) |
| `cid` (field of the body) | `idempotency_key` (field of the request, and field 13 of `Message`) |
| `pinned`: only an assistant message, set by the service at the creation, never changed | `pinned`: any message, changed by `SetMessagePinned` or by the service, with `updated_at` and `MessagePinnedChanged` |
| `accepts` (in each read of the history): `image`, `audio` | `GetCapabilities`: `accepted_mime_types` and the limits |
| Files in the send, in base64. `GET /chat/messages/<seq>/attachments/<index>` | Files in `FileService`, with SHA3-256. The message has a `FileReference` |
| The reason of a failure: none (the text of the answer) | `error` of a `FAILED` message and of `MessageStatusChanged` |
| Attachment: `kind`, `mime`, `name`, `size` | `ImageContent`, `AudioContent`, `FileReference`: `hashes`, `mime_type`, `filename`, `size_bytes` |
| HTTP statuses 400, 404, 405, 413, 415, 500, 503 and `error` names | gRPC statuses and `chat-reason` (section 9). 413 `history_full` is `RESOURCE_EXHAUSTED`. 503 `busy` is `UNAVAILABLE`. 415 is `unsupported_media`. A body above the limit is `too_large` |
| The limit of 128 KiB for the text body, and 24 MiB with files | 128 KiB for `SendMessageRequest`. A file goes in its own call |
| The limit of 1 MiB for the answer to a read | 1 MiB for each message |
| `Content-Length`, `Allow`, chunked bodies, `HEAD`, leading zeros in a path | Not used |
| HTML block in the text | The same. It is a client feature (section 5.4) |
| No `GetConversation`, branches or cancel | `GetConversation` is required. Branches and cancel are optional |

### 13.3 Migration of the service `echo-chat`

The service must:

1. Declare the slot with the stack `http2`, `grpc`, `chat` (section 3). It can keep the old
   slot on another port for older clients.
2. Run a gRPC server over h2c on the port of the slot, with the services `ChatService` and (if
   it accepts attachments) `FileService` of `chat.proto`. A gRPC server library that can
   serve HTTP/2 without TLS is enough.
3. Implement `GetCapabilities` (an empty `accepted_mime_types` if it accepts text only),
   `SendMessage`, `GetMessages`, `Connect`, `SetMessagePinned` and `GetConversation`. It need
   not implement `ForkConversation`: it ends the call with `UNIMPLEMENTED`.
4. Number the messages from 1. Give each message a `message_id`, `created_at`, `updated_at` and
   `from_service`.
5. Make the answer at once. The default is a whole answer: an assistant message with `status`
   `COMPLETED`, with the text of the user message in a `TextContent`, and
   `reply_to_message_id`. In `Connect`, send `MessageCreated` for the user message, then for
   the answer, with no delta. The echo service can instead stream the answer (an assistant
   message `IN_PROGRESS`, `MessageDelta` events, then `COMPLETED`). Each way is valid.
6. Keep `idempotency_key` in the user message, and give it back (section 6.1, step 6).
7. Send `subscribe` replay and `SubscriptionReady` in `Connect` (section 6.5). Handle `send_message`
   (answer with `MessageCreated`, or with a `ProtocolError` that has the `event_id`),
   `acknowledge` (accept it, check `last_sequence`) and `cancel_message` (a `ProtocolError`
   with `unimplemented` if it does not support it). Copy `ClientEvent.event_id` to
   `ProtocolError.event_id`.
8. Map each error of section 9 to a gRPC status with the trailer `chat-reason`.
9. If it accepts attachments: implement `FileService` with SHA3-256 (the `type` is the 32 raw
   bytes of section 6.4), keep the files in memory, and use `storage_full` when it cannot keep
   one more file. The `accepted_mime_types` is the four types of section 5.1. The default is that
   the answer has only the text. The echo service can also put the attachments of the user
   message in its answer (the same `FileReference` items, with a SHA3-256 hash). Then it
   must serve these files with `DownloadFile`.
10. Use the checks of section 6.1 and of the table of `UploadFile` in section 6.4, in the
    order that they give: structure (`bad_request`, also for a hash with no `type` and for
    a file of 0 bytes), size (`too_large`), media type (`unsupported_media`), storage
    (`storage_full`), and hash (`hash_mismatch`).
11. Read an empty string in `idempotency_key`, `reply_to_message_id`, `conversation_id` and
    `event_id` as absent.
12. Set the receive limit of the gRPC server to 4 MiB or more. For `GetMessages`, the default
    limit can be higher than 100 (the echo service uses 1 000).
13. Close a `Connect` stream with `UNAVAILABLE`, reason `busy`, if the queue of the stream is
    above the limit of the service (optional).
14. End an upload in the order of 6.4: a later `file` is found while the chunks are read,
    after the checks of size, type and storage. `Hash.type` is required: an empty `type` is
    `bad_request` in each call that takes a `Hash`, `QueryFiles` too. A SHA3-256 hash with a
    `value` that is not 32 bytes is `bad_request`, also in `QueryFiles`.
15. If it limits the queue of a stream, use a limit of 1 000 events or more, and end the
    stream with `UNAVAILABLE`, reason `busy`. The echo service uses 20 000.
16. End a failing first event of `Connect` with the status of the table in section 6.5, and
    send no `ProtocolError` (`bad_state`, `bad_request`, `not_found`).
17. Pass the tests of section 11 (without the optional ones).

### 13.4 Migration of the Claude remote service

The service must do all the items of section 13.3, and also:

1. Make the assistant message when the answer starts, with `status` `IN_PROGRESS`, and send a
   `MessageDelta` with `text_append` for each piece of text of the model. The final content is
   the text that the service has sent.
2. Send the reasoning of the model as `reasoning_append`, and keep it in `Message.reasoning`.
   It must not put the reasoning in a `TextContent`.
3. Set `status` to `COMPLETED` when the answer ends, and to `FAILED` if the model call fails.
   For `FAILED`, set `error` (a short text for the user, 1 024 bytes or less, no secret data)
   in the message and in `MessageStatusChanged`, in the same update as the status. Do not use
   `metadata` for this. The service can also write "Error: ..." in the text, but the client
   does not need it. Send `MessageStatusChanged` each time.
4. Keep a `message_id` for each message, and set `reply_to_message_id`.
5. Reply to `SendMessage` at once. It accepts a new send while it makes an answer. It replies
   with `UNAVAILABLE`, reason `busy`, if its queue is full.
6. Implement `FileService` if it accepts images or audio: check the hash (the `type` is the 32
   raw bytes), reject an empty file with `bad_request`, use `storage_full` and not
   `history_full` when it cannot keep a file, keep the files for the life of the instance, and
   make the model request from the bytes. The service no longer reads base64 in the send.
   A `mime_type` that it does not accept gets `unsupported_media` in each kind of part.
7. Send an answer that has an HTML block as text. It need not change this.
8. If it pins a message (`pinned` true), set it in `MessageCreated`. It must accept
   `SetMessagePinned` for each message. If the service changes `pinned` later, it sends
   `MessagePinnedChanged`.
9. Make the message 1 MiB or less (section 7), and set the receive limit of the gRPC server to
   4 MiB or more.
9a. Do the items 14 to 16 of section 13.3. The queue limit of this service is 1 000 events
    or more. It must send a SHA3-256 hash in each `FileReference` that it sends. A service
    that never uses `PENDING` is valid.
10. Optional: `supports_cancel`, with `cancel_message` that stops the model call and sets
    `CANCELLED`.

### 13.5 What changes in the client (chatui)

- `ChatClient` uses `grpc` instead of `TunnelHttp` (an h2c channel on the local port).
- The check of the interface (`api_chat_ports`) looks for `http2`, `grpc`, `chat` and not for
  `http`, `chat`. A service of revision 5 shows as "not supported" in the banner of the
  service details.
- `seq` of the user interface is `sequence`, from 1. The cache of the notices uses it.
- The `ChatMessage` keeps its fields. `ChatMessage.pinned` can be `true` for a user message.
- The client does not poll. It opens `Connect`, and sends over it when it is open. The watcher
  of answers uses its own connection and its own stream, and sends with `SendMessage`.
- `CANCELLED` is a new final status. The client shows it as cancelled, with no notice.
- `ChatMessage` gets an `error` field (the `error` of a `FAILED` message). The client does not
  read `metadata["error"]`.
- The client makes `Hash.type` and `Hash.value` as raw bytes, not as hexadecimal text, and
  checks a downloaded file against the raw SHA3-256 digest.
- The client maps `RESOURCE_EXHAUSTED` with `storage_full` to a message to the user, and
  `RESOURCE_EXHAUSTED` with no reason to `too_large`. It subscribes again when `Connect` ends
  with `UNAVAILABLE` and `busy`.
- The client never sends an empty file, a hash with no `type`, or an empty string in an optional
  field.
- After a status of a first event of `Connect`: `bad_request` with a local `after_sequence` of
  more than 0 means "drop the copy, read from 0, subscribe" (one time). Other statuses: retry
  with the waits of 6.5, and show the error after 3 failures in a row. `UNAVAILABLE` with `busy`
  waits at least 2 seconds. A `ProtocolError` with no `event_id` before `SubscriptionReady`
  ends the stream and subscribes again. After `SubscriptionReady`, the client ignores it and
  writes a log.
- The client shows a file as unreadable, and does not call `DownloadFile`, if its
  `FileReference` has no SHA3-256 hash. It can cut an `error` text for display.

## 14. Reference services

### 14.1 Echo service

The echo service is the check of M4. It follows this document. The text of each answer is the
text of the message that it answers. It keeps the messages in a list in memory. By default it
makes the answer at once, as a whole answer with `status` `COMPLETED` and the text only, so it
does not need the rules for answers in progress (section 5.2). It can stream the answer, and it
can return the attachments of the user message in its answer. These two options are free:
each one is valid. The tests that depend on them say "if the service streams" or "if the
service returns attachments" (section 11.1).

### 14.2 Claude remote service

The Claude remote service sends each user message to a language model. An answer can take
more than 30 seconds. The service must follow these rules:

- It must reply to a send at once, and must accept a new send while it makes an answer.
- It must stream: it must add the assistant message when the answer starts, with `status`
  `IN_PROGRESS`, and must send each text of the model in a `MessageDelta` while the model
  writes it.
- It must give the reasoning of the model in `reasoning_append`, and must not put it in the
  text.
- It must set `status` to `COMPLETED` when the answer ends, and to `FAILED`, with `error`, if
  the model call fails.
- It must give `reply_to_message_id` in each assistant message.
- It must keep the whole history, in the order of `sequence`.

## 15. Revision history

| Revision | Date | Change |
|---|---|---|
| 1 | 2026-10-14 | The convention of M4: messages, send, history, errors, client behavior |
| 2 | 2026-10-22 | The text is a specification in ASD-STE100, with requirement words. The tests 1 to 18 are new. New rules for the service: transport (section 4), the order of the checks (section 6.1), the strict value of `from`, the status 404, 405 and 500, the limits (section 7), and the conformance tests (section 10). The service must add the two messages of a send at the same time. The rules for the app (leave the screen, stop, cost, storage) leave this document |
| 3 | 2026-10-22 | Attachments: `attachments` in a message and in a send. `accepts` in the read of the history. The read of an attachment (section 6.4). The status 415. The limits for files. The tests 19 to 26. A service that does not know them stays valid for text only |
| 4 | 2026-10-22 | Clarifications. The meaning of revision 3 does not change for a service that follows it, with three exceptions. First, the body limit for text only is 128 KiB (it was 32 768 bytes). Second, a send with attachments to a text-only service gets 415 only (it was 400 or 415). Third, the answer to a read of the history must be 1 MiB or less. The checks of section 6.1 have the numbers 1 to 6. A body above the limit gets 400, not 413. The `Allow` header is `GET` for the paths of section 6.4. HEAD gets 405. Section 4 has rules for `Content-Length` of requests and of answers. Section 5.1 defines `kind`, `mime` and `size`. Section 6.3 gives the two waits of the client: 30 seconds, and 120 seconds for a send with files. The 30 seconds of the service start at the end of the request body. Section 6.4 gives the open cases. Section 9 has new rules for the client on files, 415, 400 and the read in parts. The tests 22, 24, 25 and 26 are split in numbered rows. The tests 27 to 36 are new. The tests 1, 2 and 10 accept `accepts`. Section 3 says that this document fixes no port number |
| 5 | 2026-10-23 | The send does not wait for the answer: `POST /chat/messages` replies 200 with the user message (`message`) at once. Many sends can be in progress. The client reads the conversation with `GET /chat/messages` every few seconds. New `last` and `limit` filters. New message fields `status`, `reasoning`, `reply_to` and `cid`. Streaming: an answer can be an open message that grows. The `cid` makes a send safe to repeat. The roles do not alternate. Removed: `expect`, the status 409 `out_of_sync`, the rule of one send at a time, the 30 seconds to make an answer. 503 `busy` now means that the queue of the service is full. New optional field `pinned` for assistant messages, and the tests 42 and 43. Section 5.3 describes, as information only, the pinned message, the HTML block and the recorded `audio/wav` of clients |
| 6 | 2026-10-24 | The interface is gRPC over HTTP/2 (h2c), defined by `chat.proto` (moved to `docs/celaut/chat.proto`). The `protocol_stack` is `http2`, `grpc`, `chat`. The client uses `Connect` for real time, and `GetMessages` for the catch-up. `chat.proto` gets `MessageDelta`, `MessagePinnedChanged`, `Message.reasoning`, `Message.idempotency_key`, `GetCapabilities`, `ClientEvent.event_id` and `ProtocolError.event_id`. `sequence` starts at 1. `pinned` is mutable, for any message, with `SetMessagePinned`. Files go in `FileService`, with SHA3-256, and `QueryFiles` first. Errors are gRPC statuses with the trailer `chat-reason`. Branches and cancel are optional. The tests are new (section 11.1). Section 13 lists the differences from revision 5 and the migration of the two services |
| 6 (round 3) | 2026-10-24 | Clarifications of revision 6 after the migration of the two services. `Hash.type` and `Hash.value` are raw bytes. New field `error` of `Message` (14) and of `MessageStatusChanged` (5), and `metadata["error"]` is not used. New reason `storage_full`. An empty file is not valid. A `mime_type` that is not accepted is `unsupported_media` for each kind of part. The checks of `UploadFile` have one order (size before type). Every hash of a `FileReference` has a `type`. An empty optional string is the same as absent. Rules for a failing first event of `Connect`, for a bad `event_id`, for the queue of a stream, and for a message above the gRPC limit. The echo service can stream and can return attachments. New tests 13a, 27h, 27i, 48a, 55a to 55d, 64a and 73a; changes to tests 13, 20, 29, 35, 64 and 72 |
| 6 (round 4) | 2026-10-24 | More clarifications of revision 6. A later `file` of an upload is found while the chunks are read, after the checks of size, type and storage. A `type` that is set and empty is an unknown type. A SHA3-256 hash with a `value` that is not 32 bytes is `bad_request`. The queue limit of a stream is at least 1 000 events. The cases of a failing first event of `Connect`, and the client behavior after each (also after `busy` and after a `ProtocolError` with no `event_id`). A client does not call `DownloadFile` for a `FileReference` with no SHA3-256 hash. `error` is 1 to 1 024 bytes, and a client can cut it for display. Test 29 is valid for a service that never uses `PENDING`. New tests 27j, 27k, 27l, 48b, 55e and 55f; changes to tests 29 and 55c |
| 6 (round 5) | 2026-10-24 | `Hash.type` is required: `chat.proto` has `bytes type = 1;` (it was `optional`, and the field number is the same). The `type` is explicit in each `Hash` of each call. The rule "reuse the last `type` of the stream" is gone. An empty `type` is the same as a missing `type`: `bad_request` in each call that takes a `Hash`, `QueryFiles` too. A `type` that is not empty and not known is an unknown algorithm. A SHA3-256 hash with a `value` that is not 32 bytes is `bad_request` in `QueryFiles` too. Test 48b is removed (its number stays). Tests 48, 49, 55b and 71 are changed, and test 49a is new |
| 6 (round 6) | 2026-10-29 | New section 5.5 and a line in the decisions table: the keyboard block (```` ```keyboard ````). It is a client feature, as the HTML block, and the wire does not change. Keys can send at once (`data-send`), and the block can have fields (`input` with `data-name`) that a `{name}` in a `data-say` uses |
| 6 (round 7) | 2026-10-29 | Section 5.5: the fields of a keyboard block can be of the types `date`, `time`, `range`, `checkbox` and `select` (one option, or many with `multiple`), with new attributes (`type`, `min`, `max`, `step`, `value`, `checked`, `data-off`, `multiple`, `selected`, and the `option` element). New limits: 32 options in a `select`, 80 characters in the label of an option. Where chatui shows the form, the keyboard of the app, the setting of the keyboard of the system, and how to open a closed form. The options of a `select` show as chips side by side, in a wheel. The wire does not change |
| 6 (round 8) | 2026-11-01 | Draft: secret requests. New part `secret_request` (sections 5.1 and 5.6), new call `AnswerSecretRequest` (section 6.9), new reasons in section 9, new rules for the client (section 10), and tests 75 to 82. Decided on the same day: typed values and saving in the container, a wait with no time limit, requests only in `COMPLETED` messages, and the warnings for sensitive values. A service that does not send secret requests keeps the wire of revision 6. `chat.proto` has the new messages, and chatui implements them from version 0.1.30 |
| 6 (round 9) | 2026-11-04 | Proposal (issue #89): the title of the conversation. New field `title` of `SubscriptionReady` (2), new event `ConversationTitleChanged` (9 of `ServerEvent`), and `Conversation.title` of `GetConversation` for the main conversation (section 6.10). The name that the user gives in the app is stronger than the title. New tests 83 to 86. A service that does not give a title keeps the wire of revision 6 |
| 6 (round 10) | 2026-11-04 | Proposal (issue #88): suggestions and the state of the corrector. New fields `Message.suggestions` (15), `MessageStatusChanged.suggestions` (6), `SendMessageRequest.corrector` (5) and `Message.corrector` (16), and the messages `CorrectorState` and `Correction` (section 5.7). The suggestions are for each message, not live. New tests 87 to 90. A service that does not know the new fields keeps the wire of revision 6 |
| 6 (round 11) | 2026-11-10 | Proposal (issue #120): a pointer to another slot. New part `slot_link` (7 of `ContentPart`) and the message `SlotLink` (`port`, `label`), section 5.8. The client shows a button and opens the slot (a deck of `cards.md`, the browser, or the conversation) only after a tap. New tests 91 to 94. A service that sends no `slot_link` keeps the wire of revision 6 |
