# Product decisions (2026-10-11)

- **Base:** fork of the Argus Ergo wallet (arkadianet/Argus, MIT), history kept.
- **Wallet scope:** one wallet with its seed, send and receive ERG and tokens, history,
  ErgoPay, payment notifications, ERG/USD from the on-chain oracle
  pool. Removed: AMM, SigmaUSD, Dexy, DuckPools, Rosen, SigmaFi, stake recovery, stealth,
  ZeroJoin, dApp browser, CoinGecko prices, the Argus app fee. Removed on 2026-10-16:
  more than one wallet, watch-only addresses and accounts, offline (cold) signing.
- **Updater:** reads the releases of celaut-project/chatui.
- **QR scanner:** flutter_zxing (no Google ML Kit).
- **App:** label "Chatui" (2026-10-23, Josemi; it was "Celaut"), applicationId
  `org.celaut.chatui` (unchanged). Android only (GrapheneOS
  without Play Services must work). APK built in GitHub Actions, published in GitHub
  Releases. UI in English and Spanish.
- **No third-party services:** no Firebase or similar. Ergo data comes from public Ergo
  nodes and explorers that the user can change.
- **Role on the network:** client only. The app never calls `IntroducePeer`.
- **Balancer:** Rust crate in `rust/crates/`, a port of nodo's execution balancer
  (quotes, sort, architecture/resource filter, on-chain reputation, quote cache). It is
  written so that nodo can use it later (PyO3).
- **Reputation for a new client:** the app keeps its own event log, as nodo does. While
  the log is empty, each opinion publisher gets credibility 1, limited by its burned ERG.
  After that, the app uses the nodo formula.
- **Node discovery:** reputation-proof boxes that nodes publish about themselves (see
  [catalog.md](catalog.md)), plus nodes that the user adds by address or QR code.
- **Service catalog:** celaut-project/skills. The user picks a skill. The app selects
  the service with the highest score. The user can also launch by service hash, or
  upload a package from the phone.
- **Wallets and storage (2026-10-16, replaces 2026-10-13):** the app holds one Ergo
  wallet, with its seed. There are no read-only wallets. The wallet manages instances
  (start, stop) and pays nodes. All Celaut data is in one database (no database per
  wallet). See [ui.md](ui.md), section 1.
- **Home screen (2026-10-13):** it shows the compute that the connected nodes offer
  (sum of their resources) and the money for compute first. The ERG of each wallet is
  second level. See [ui.md](ui.md). **Proposed on 2026-10-21, for Josemi to confirm:** the
  first screen is the Chats tab, and the compute view is the Compute tab
  ([ui-chat-first.md](ui-chat-first.md)).
- **Navigation (2026-10-21, Josemi):** a bottom bar with four tabs: Chats, Wallet,
  Compute, Settings. Each tab keeps its state; back on another tab goes to Chats. The
  conversation and the info page of an instance open over the bar. See
  [ui-chat-first.md](ui-chat-first.md), section 2.
- **Checks of the list of conversations (2026-10-21, Josemi):** the list asks the nodes
  when it opens, when the user comes back to it, and on a pull. It does not poll.
- **Instances are kept (2026-10-21, Josemi):** the app never forgets an instance or its
  token on its own, or because its node does not answer. A stopped instance stays in the
  database until the user deletes it; only a stopped instance can be deleted
  (`celaut_forget_instance` refuses the others). See
  [ui-chat-first.md](ui-chat-first.md), section 3. **Changed on 2026-10-23 (Josemi):** the
  lists hide the stopped instances by default, with a button that shows them; they stay in
  the database.
- **Payments:** a deposit per node. A separate client id per node, not linked to the
  others.
- **Access to instances:** `ServiceTunnel` through the node.
- **Chat:** a conversation screen with a launched service (for example an LLM) through
  `ServiceTunnel`. It does not use the `Chat` RPC of nodo, which is for peers only. The
  protocol of the conversation is gRPC since 2026-10-24 (see the entry "Chat over gRPC").
- **Phase 1:** trimmed wallet that builds for Android; Rust crates for the protocol and
  the balancer, with tests against a local node; a screen that launches a service by
  hash and shows the quotes.
- **Environment variables (2026-10-22, Josemi):** the app has a container of named values.
  When a service that declares variables is launched, the app asks for each one: choose
  one of the container, type it as UTF-8, or skip it (it is then absent from the
  configuration). Design in [env-variables.md](env-variables.md).
- **Peer invitation (2026-10-22, Josemi):** the app reads the QR code of nodo#579
  (`protos/invite.proto`) and connects to the node by the address that is most feasible on the
  current route, with the invited key pinned. See [invite.md](invite.md).
- **Service details and the chat check (2026-10-22, Josemi):** the app reads the Service as a
  stream and never keeps its filesystem. It shows what the service declares (prose, resources,
  interface, networks, variables) and, before a launch, warns if the interface is not the chat
  convention of Chatui. The title of the app is Chatui (2026-10-23, Josemi; it was Celaut Chatui), in lower
  case except the C, with "ui" in the other colour. See [service-info.md](service-info.md).
- **Chat attachments (2026-10-22, Josemi):** a message can carry image and audio files
  (JPEG, PNG, MP3, WAV; at most 4 files of 4 MiB each). A service that accepts them
  announces `accepts` in the history read, and the app shows the attach button only then.
  The files stay in memory only. The app does not play audio: a tap hands the file to the
  share sheet of the system. See [chat.md](chat.md) and
  [ui-chat-first.md](ui-chat-first.md), section 7.
- **Chat without a wait, with streaming (2026-10-23, Josemi):** a send (`POST`) replies at
  once with the user message, and the app reads the conversation (`GET`, with the filters
  `from`, `last` and `limit`) every 2 seconds while it waits for an answer, and every 10
  seconds otherwise. The user can send many messages at the same time. An answer can grow
  while the service makes it (`status` `streaming`), with the `reasoning` of the model
  apart from the `text` (the Claude remote service). A service that sends the whole answer
  stays valid. This is revision 5 of [chat.md](chat.md).
- **Chat reading, pinned messages and audio (2026-10-24, Josemi):** an assistant message
  has no bubble. The size and the font of the text are set in Settings. While an answer
  streams, the text appears slowly and the phone gives small haptic ticks. An assistant
  message can have `pinned` `true` (an optional boolean that the service sets when it
  makes the message, and never changes). A pinned message anchors only what comes after it: the app
  shows the last pinned message that is all above the visible part, and not while it is the
  last message or its bottom is still visible. The banner takes at most 25% of the chat
  area (the part between the two bars; set in Settings), and 60% when the user taps it. A block
  ```` ```html ```` in `text` shows as a simple widget if Settings allow it (on by default),
  with no script and no network. A local notice shows when an assistant message gets `done`
  and the chat is not in front (the app is in the background, or another screen covers the
  chat), and the user can mute each instance. The notice has the name of the chat and a
  generic text, never the answer, so the lock screen shows nothing private. A tap on the
  notice opens that chat if the instance runs, and the list of chats if not. The notice
  also comes after the user left the chat screen (see the watcher of answers, below). If many answers get done between two reads,
  the user gets one notice for the chat. Each instance has its own chat background. The header
  and the input float over the chat. This is still revision 5 of [chat.md](chat.md): the
  field `pinned` is optional.
- **Voice messages and the microphone (2026-10-24, Josemi):** the app asks for the
  permission `RECORD_AUDIO`. It was removed before (`tools:node="remove"`). The input of a
  chat can record audio from the microphone and attach it as `audio/wav` (16 kHz, mono).
  Every service that accepts `audio` must accept `audio/wav`. The app asks for the
  permission at the first recording only, uses the microphone only while the user keeps a
  recording open, and keeps the sound in memory until the message is sent. The recording
  stops by itself at the size limit of an attachment, and the app attaches it and tells the
  user. The app records nothing in the background and keeps no sound on the storage. If the
  user denies the permission, the record button says so. The QR scanner still records no
  sound. The privacy notes say this (`docs/security-design.md`).
- **Specification of the chat interface (2026-10-22):** [chat.md](chat.md) is written in
  ASD-STE100, has a revision number (4 on that day, 5 since 2026-10-23), covers the protocol only, and has conformance
  tests (section 10). A service follows the interface if it passes them. The rules for the
  app are in [ui-chat-first.md](ui-chat-first.md).
- **Leaving a conversation (proposed on 2026-10-21, for Josemi to confirm):** Back goes to
  the list without a question. The instance runs on and the node keeps charging. Stop is
  in the menu, on the info page and on a long press. See
  [ui-chat-first.md](ui-chat-first.md), section 5.
- **Settings (2026-10-23, Josemi):** three sections. Ergo: the wallet, the Ergo network, the
  address book, the remote previews. Compute: the nodes, the deposit, the automatic top-up,
  Tor, the environment variables, the node check and the Celaut service screen. General:
  security and auto-lock, display, the first screen, About. There is no Developer group.
  The app has no setting for the language: it follows the language of the phone.
- **Sleep and the auto-lock (2026-10-23, Josemi):** a launch, a transfer of a service file
  and an import of a service file go on with the screen off or the app in the background:
  the foreground service holds the process and a partial wake lock while they run. The
  auto-lock still locks the wallet on time; while one of them runs it does not close its
  page. See [ui-chat-first.md](ui-chat-first.md), section 8.
- **Keep running (2026-10-29, Josemi; before: automatic top-up, 2026-10-23):** per instance,
  not global. At the launch the user chooses "for a time" or "until I stop it", and can change
  it on the info page of the running instance, where Add time and the credit on the node
  are. The app moves credit that it already has on a node to a kept instance that would last
  less than a threshold (`ModifyDeposit`), in time and not in MU. It never makes an on-chain
  deposit: with too little credit it asks the user, and a deposit keeps its own confirmation
  and PIN. The mode "until I stop it" always shows a warning, and has an optional limit of
  spending. It works only while the app runs; a foreground service is left for later. The
  switch of 2026-10-23 is gone and its value is not read. See [ui.md](ui.md), section 4b.
- **Watcher of answers (2026-10-24, Josemi):** the notice of a done answer also comes when
  the user left the chat screen while a service still makes an answer. When the screen
  closes with an answer pending (an open message, or more user messages than assistant
  messages), it hands the chat to `ChatDoneWatcher`. The watcher opens its own tunnel and
  reads the chat every 2 seconds (`ChatClient.pollWaiting`), only while an answer is pending.
  (Since the entry "Chat over gRPC" of 2026-10-24, the watcher follows the `Connect` stream
  and not a poll; the other rules stay.)
  While it runs, the foreground service holds the process and the CPU (reason `answer`).
  The watcher and the screen share one list of the messages that got a notice, so a
  message gets one notice only. The messages that were done when the screen closed get none.
  The notice is the same as before: the name of the chat, a generic text, private on the
  lock screen, no notice for a muted instance. An answer with status `failed` gets no
  notice: the user did not get an answer, and the failure shows when the chat opens. A watch
  stops when no answer is pending, when the instance is muted, when the chat screen opens
  again, when the user stops the instance, after 5 minutes without a good read, and after
  30 minutes. The watcher does not look at instances that the user never opened in this
  run, and a watch is lost if the system kills the app. See
  [ui-chat-first.md](ui-chat-first.md), section 9.
- **Chat over gRPC (2026-10-24, Josemi):** the chat interface is no longer HTTP/1.1 with
  JSON. It is gRPC over HTTP/2 in clear text (h2c) through `ServiceTunnel`, defined by
  [chat.proto](chat.proto) (`ChatService` and `FileService`, no package: paths `/ChatService/...` and `/FileService/...`). The slot
  declares the protocol stack `http2`, `grpc`, `chat`. The app reads new messages with the
  bidirectional stream `Connect` and does not poll; `GetMessages` with `after_sequence` gives
  the history and the catch-up. Streaming has two new events (`MessageDelta`,
  `MessagePinnedChanged`) and two new fields of `Message` (`reasoning`, `idempotency_key`).
  What a service accepts is in `GetCapabilities`. Files go in `FileService`, identified by
  SHA3-256 hash, and the app asks `QueryFiles` before it uploads. `pinned` is mutable for any
  message (`SetMessagePinned`); the app keeps the last pinned message above the visible part
  at the top. HTML widgets stay a fenced block in the text. Branches and other conversations
  are optional, and the app ignores them. The app sends over `Connect` when its stream is
  open (each event has an `event_id`, an error gives it back, and the app matches the user
  message by `idempotency_key`), and with the unary `SendMessage` when it is not. SHA3-256 is
  the hash that the app uses and that each service that accepts files supports; more
  algorithms can be added later because `Hash.type` names the algorithm. The limits (1 MiB
  message, 4 MiB file, 64 KiB chunk) are defaults that `GetCapabilities` can replace.
  `CANCELLED` is a final status shown as cancelled, with no notice and no cancel button
  for now. `acknowledge` is a hint that lets the service drop buffered events. This is revision 6 of [chat.md](chat.md); the
  services `echo-chat` and the Claude remote service must migrate (section 13 of that file).
- **Chat interface, clarifications (2026-10-24, Josemi):** after the migration of the two
  services, revision 6 of [chat.md](chat.md) fixes these points. `Hash.type` and `Hash.value`
  are the raw bytes of the digest (32 bytes for SHA3-256), not hexadecimal text. A `FAILED`
  message has `error` (a short text for the user, 1 KiB at most, set once with the status);
  `metadata["error"]` is not used. A new reason `storage_full` is for a file store that cannot
  take an upload, and `history_full` is only for the history. An empty file is not valid. A
  `mime_type` that a service does not accept is `unsupported_media` for each kind of part, and
  `bad_request` only when an `image` part has an `audio/*` type or an `audio` part has an
  `image/*` type. The app shows the `error` of a failed answer and tells the user about a full
  file store.
- **Chat interface, second round of clarifications (2026-10-24, Josemi):** [chat.md](chat.md)
  gives one rule for each point that the three implementations found. A later `file` of an
  upload is found while the chunks are read, after the size, type and storage checks. A `type`
  that is set and empty is an unknown type (replaced by the entry "Hash.type is required" below), and a SHA3-256 hash with a `value` that is not 32
  bytes is `bad_request`. A service limits the queue of a `Connect` stream at 1 000 events or
  more and then ends it with `UNAVAILABLE` and `busy`; the app waits at least 2 seconds and
  subscribes again. A failing first event has a fixed status for each case. If the app is ahead
  of the service (`bad_request` for `after_sequence`), it drops its copy and reads from 0; for
  other statuses it retries and shows the error after 3 failures in a row. The app ignores a
  `ProtocolError` with no `event_id` after `SubscriptionReady`. The app does not download a file
  that has no SHA3-256 hash. `error` has at most 1 KiB, and the app can cut it for display.
- **Hash.type is required (2026-10-24, Josemi):** in [chat.proto](chat.proto) `Hash.type` is
  `bytes type = 1;` and not `optional`. The field number is the same, so the wire is the same.
  Every `Hash` of every call has an explicit `type`; the rule "reuse the last `type` of the
  stream" in `QueryFiles` is gone. Why: proto3 gives no presence to a `bytes` field without
  `optional`, so an empty `type` cannot be told from a missing one (the `Hash` of
  `celaut.proto` is the same); `QueryFiles` no longer depends on the state of the stream; and
  the cost is about 32 bytes for each query. An empty `type` is `bad_request` in each call that
  takes a `Hash`. A `type` that is not empty and that the service does not know is an unknown
  algorithm (`available` false, or ignored in a `FileReference`). A SHA3-256 hash whose `value`
  is not 32 bytes is `bad_request`, `QueryFiles` too. This is round 5 of revision 6 of
  [chat.md](chat.md).
- **Hibernate and wake (2026-11-05, Josemi):** the user can hibernate an instance that the app
  runs, so that it costs only its disk, and wake it later with the same CPU and RAM. There is
  no new RPC: both are `ModifyServiceSystemResources` with `service_token` and the `Client`
  of the father (the app). The resources that a wake sends are the resources that the
  instance has at the moment of the hibernation, and not its resources at the launch (it can
  be resized later). The app reads them from the node just before it hibernates the instance,
  and keeps them in its record. If the read fails, it uses the last values that it knows,
  and the wake dialog says so. If it has none, it does not hibernate. The node does not say
  that an instance is hibernated (`GetMetrics.suspended` is false), so the state is in the
  record of the app. The list shows a hibernated instance as "Hibernated", not as "Not
  answering", and the filter of stopped instances does not hide it. A hibernated instance
  cannot be deleted: the user stops it first. Hibernate costs the instance two call fees
  (the read and the request); a wake costs one. A wake keeps the address and the ports, but
  the process state is lost, and the dialog warns about it.
- **Hibernate and the rest of the app (2026-11-05, Josemi's plan, phase 5):**
  - Keep-alive: a top-up never wakes a hibernated instance (the node does not wake it
    either). While it is hibernated, the keep-alive aims at the disk price plus the fee of
    one wake call. At the hibernation the app works out the disk price from the rates that
    the node advertised (`disk_mu_per_gib_second`, `scarcity_max_multiplier`,
    `modify_resources_mu`) and the disk that the read of the resources gave. The figure is an
    upper bound (the rate plus 1, because the node drops the fraction; times the scarcity
    ceiling; never more than the awake price). If the app cannot work it out, the keep-alive
    uses the awake price, which only over-funds. The wake clears the hibernated price.
  - A hibernated instance gives no "unreachable" state and no notice. The watcher of finished
    answers does not watch it, and ends a watch when the record says that the instance is
    hibernated. The status read (a balance only) goes on.
  - If the status read of a hibernated instance gets "Invalid token" from the node, the node
    stopped the instance after the grace period and deleted its disk. The core marks the
    record stopped and the list reads again. An awake instance is not marked this way: the
    app cannot tell why it does not answer.
  - A node that does not support hibernation (older than `service_token`) is found at the
    first call, by its refusal. The app says so once and hides Hibernate and Wake for the
    instances of that node, until the app restarts. The call costs nothing.
