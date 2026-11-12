# Chat-first UI (2026-10-21)

Josemi asked for a home screen like Telegram or WhatsApp: each conversation is an instance
of a service that follows the chat convention ([chat.md](chat.md)), and the rest of the app
(wallet, compute, nodes, services, settings) is one level down. This note describes the
screens of that UI. It follows [ui.md](ui.md) and [chat.md](chat.md); section 4 has the
decisions of Josemi on this UI, section 5 what it changes in the older notes, and section 7
the messages and the files of a conversation.

## 1. Research: how the two messengers organise the app

Both apps were checked on Android in October 2026.

| Part | Telegram | WhatsApp |
|---|---|---|
| Home | The chat list, with folder tabs on top | The chat list, with filter chips (All, Unread, Groups) |
| Other places | Before the update of February 2026: a left drawer with the account on top (photo, name, number), then Contacts, Calls, Saved Messages, Settings. From that update: a bottom bar with Chats, Contacts, Settings, Profile | A bottom bar with Chats, Updates, Communities, Calls. ⋮ on the chat list has Settings, Linked devices, Starred |
| New chat | A pencil button. It opens the contacts, with New group and New channel on top | A button at the bottom right. It opens "Select contact", with New group and New contact on top |
| Chat bar | The photo, the name and a status line ("online", "last seen"). A tap opens the info page of the contact, with its actions. ⋮ has Mute, Search, Clear history, Delete | The same: name and status; a tap opens "Contact info"; ⋮ has View contact, Search, Mute, More |
| Long press on a chat | A selection mode, with Pin, Mute, Archive, Delete in the bar | The same, with Pin, Delete, Mute, Archive |
| Archived chats | A row on top of the list | A row on top of the list |
| Unread | A count on the right of the row | The same |
| Empty list | A picture, one sentence, and the new-chat button | The same |

**Choice: a bottom bar, as WhatsApp and Telegram (from February 2026) have it, with ⋮ on the
conversation (decision of Josemi, 2026-10-21: "better a bottom bar").** The bar has four
tabs: Chats, Wallet, Compute, Settings. Each tab holds the places of its kind as rows, so
every other place of the app is one tap under a tab. The conversation screen follows both
apps: name and status in the bar, a tap on it opens the info page, and ⋮ has the actions.

Not taken from the messengers:

- **Unread counts.** A service answers only to a message of the user, while the
  conversation is open ([chat.md](chat.md)). There is nothing unread.
- **Archived chats.** An instance costs money while it runs, so it is not hidden: the user
  stops it. The instances without a chat slot are not in the list: the page of their service, in Compute,
  under Services, shows them with Stop.
- **Selection mode on a long press.** One instance at a time is enough: a long press opens a
  sheet with the actions of that row.

## 2. Screen map

The home screen is a bottom bar with four tabs (`HomeTabs`,
`app/lib/ui/celaut/home_tabs.dart`). Each tab keeps its state while another one shows.
Back on another tab goes to Chats. The conversation, the info page of an instance, the page
of the wallet and the pages under a tab open over the bar.

| Tab | What it holds | Code |
|---|---|---|
| Chats | The instances with a chat slot: the running ones, newest first, then the stopped ones (hidden by default, see below). The pencil button opens "New conversation"; only this tab has it | `ChatsScreen`, `InstanceList` (`chats_screen.dart`, `instance_list.dart`) |
| Wallet | Only the ERG that the wallet holds and its latest transactions (2026-10-24, Josemi). "Wallet details" opens the page of the wallet, which has Send, Receive, the tokens, the addresses, "Deposit to a node" (under More) and the rest. A locked wallet shows its public snapshot, with the transactions of the same refresh. With no wallet: create or restore | `WalletSummaryScreen` (`home/wallet_summary.dart`), `WalletsOverviewScreen` (the welcome), `DepositScreen` |
| Compute | The compute view of [ui.md](ui.md), section 2: only the card of state (nodes, credit on the nodes, ERG of the wallet). Under it: Nodes, Services. It has no list of instances and no "Run a service" button: the instances are in the conversations (Stop is on their info page), and a service is run from Services | `ComputeHomeScreen` |
| Settings | The settings of the app in three sections (2026-10-23): Ergo (the wallet, the Ergo network, the address book, the remote previews), Compute (nodes, deposit, automatic top-up, Tor, environment variables, node check, Celaut service) and General (security, display, the switch of the home screen, About) | `SettingsScreen` |

| Place | Where | What it holds | Code |
|---|---|---|---|
| New conversation | Chats, pencil button | The skills of the catalog (a skill opens its ranked services), the service files of the user, the import of a file | `RunServiceScreen` with the title "New conversation" |
| Conversation | Chats, a row | Bubbles, with images and files (section 7); the bar has the name of the service and "state · node · cost so far"; ⋮ has Info and Stop | `ChatScreen` |
| Instance info | The bar of a conversation, ⋮, a long press, a tap on a stopped row | State, node address, peer id of the node, service id, chat slot, start time, cost so far (or the refund at the stop). Stop, or Delete for a stopped instance | `InstanceInfoScreen` |
| Page of the wallet (the details) | Wallet, "Wallet details" | Balance, Send, Receive, activity, the tools (tokens, UTXOs, addresses, Deposit to a node, lock) and the settings of the wallet. It is the Ergo part of the app, and always has the Ergo look: black and orange (`ergoPalette`), whatever theme the user chose. The look covers the pages that open from it (`ergoThemeActive`) | `DashboardScreen` (wallet page) |
| Deposit to a node | Wallet details, More | The deposit screen | `DepositScreen` |
| Nodes | Compute | The node list with its availability; add a node by address or QR code ("connect to a new peer") | `KnownNodesScreen` |
| Services | Compute | The same picker as "New conversation": the catalog, the service files and the import. The transfer of a service that a node does not have stays in the sheet of a failed launch | `RunServiceScreen` |
| Network and Tor | Settings | The network route ([network.md](network.md)) | `NetworkScreen` |
| About | Settings | The version and the update check | `AboutPage` |

A row of the list has the robot of the instance, its name, the cost so far, the last
message that the app saw in this run (or a note that it saw none), and "state · node". The
name is the name of the skill or the service file at the start; the database keeps it with
the instance (`InstanceRecord.name`). An instance of an earlier version has no name: the row
shows the short service id.

A filter hides the stopped instances, on Chats (Josemi, 2026-10-23).
It is on by default. Under the rows, "Show N stopped instances" shows them, and "Hide stopped
instances" hides them again; the app keeps the choice (`celaut_hide_stopped_v1`). A shown
stopped instance has Delete, as before. A stopped instance stays in the database while it is
hidden.

The robot (Josemi, 2026-10-23) stands for the instance as a photo stands for a contact: a
service has no picture of its own, so every instance gets one. It comes from the instance id
(FNV-1a of the id picks the head, the eyes, the mouth, the antenna and one of eight hues), so
it stays the same after a restart. The app draws it with paths (`robot_avatar.dart`): no
image file, no network, no licence of a third party.

The user can rename an instance (Josemi, 2026-10-23): Rename on the long press of a row, or
the pencil on its info page, running or stopped. The new name is local: the app keeps it in
the Celaut database (`InstanceRecord.alias`, `celaut_rename_instance`, at most 60
characters) and never sends it to the node. The list, the conversation and the info page
show it before the name of the start. An empty name removes it.

The states of a row:

| State | When |
|---|---|
| Checking | The app asks the node (`celautInstanceStatus`) |
| Starting | The instance started in this run, and its service did not answer yet |
| Running | The node reports the instance |
| Not answering | The node does not answer, or does not report the instance. The info page says why |
| Stopped | The instance stopped. The row stays, after a restart too, until the user deletes it |

The list asks the nodes for its running instances when it opens, when the user comes back
to it (from a page or from another tab), and on a pull. It does not poll. A stopped instance
is not asked for.

**Large screens and a phone on its side** (`AppLayout`, `app/lib/ui/layout.dart`). The
layout follows the window size classes of Material 3:

| Window | Layout |
|---|---|
| Under 600 wide (a phone held upright) | The bottom bar, as above |
| 600 wide or more (a phone on its side, a small tablet) | The tabs are a rail on the left, so the bar does not take the little height there is. A conversation still opens over the tabs |
| 840 wide or more and 480 high or more (a tablet on its side, a desktop window) | The rail, and Chats shows the list (360 wide) with the open conversation next to it, as a messenger on a tablet. The pane keeps its own pages (the info page of an instance opens there too); the open row is marked; Back closes the pane first. A tablet turned upright opens the conversation of the pane again over the list |

On any window the text and the forms of a page keep to a column of at most 760 in the
middle (`ReadableWidth`), and the conversation too, over its background. A window under
500 high (a phone on its side) has the keys of the keyboard of the app lower (36, not 48),
so the conversation keeps room above it.

## 3. Flows

- **New conversation.** Pencil → "New conversation" → a skill → its services, best first →
  Run → "Run <name>?" with the node, the start cost and the least time that the
  instance must run ([balancer.md](balancer.md), "The least time of a launch") → the PIN or fingerprint if the wallet
  is locked → the launch → back to the list and into the conversation, which says that the
  service starts (`ChatClient.syncWhenStarted`). Back from the conversation is the list.
  "Services" and "Run a service" in the Compute tab end the same way, on the Chats tab. A
  service without a chat slot starts, and a message says that it is in Compute, under
  Services, in the page of the service.
- **Open a conversation again.** A tap on a row opens the local port of the chat slot and
  reads the history from `after_sequence` 0 and opens `Connect` ([chat.md](chat.md), sections 6.2 and 6.5). This works after the lock of the
  app closed the screen, and after a restart of the app. The screen shows at once, with the
  name of the instance and a spinner, while the port opens: a far node, or Tor, can take
  seconds. If the port does not open, the screen closes and the list says why.
- **Leave.** Back goes to the list at once. The instance runs on, the node keeps charging,
  and the row shows its cost.
- **Stop.** From ⋮ in the conversation, from its info page, from a long press in the list,
  or from the Compute tab. The app asks "Stop <name>?", then needs the wallet open. If the
  node does not answer, the app says why and the row stays as it was. After the stop the
  database keeps the instance as stopped, with the refund (`InstanceRecord.stopped_at`,
  `refund_mu`), and the row shows "Stopped" with the last message.
- **Delete.** A long press on a stopped row, or its info page, offers Delete. The app asks
  "Delete <name>?", then takes the instance out of the database (`celaut_forget_instance`).
  This is the only way an instance leaves the list. A row that is running, starting or not
  answering has no Delete, and `celaut_forget_instance` refuses an instance that was not
  stopped.

The last message of each conversation and the starting instances are in memory only
(`ConversationNotes`, `app/lib/celaut/conversations.dart`). The app writes no message to the
Celaut database.

The setting "Chats home" (Settings, General; key `celaut_compute_home_v1`) chooses the
first screen: the tabs, on Chats (on, the default), or the wallets list (off). The compute
view is the Compute tab, not a first screen.

## 4. Decisions of Josemi (2026-10-21)

| Question | Decision |
|---|---|
| A drawer or a bottom bar | A bottom bar: Chats, Wallet, Compute, Settings (section 2). Every place of the first build of this UI is under a tab |
| When the list checks the nodes | Only when it opens, when the user comes back to it, and on a pull. No polling |
| Forget an instance whose node does not answer | No. The app keeps every instance and its token until the user deletes it, and only a stopped instance can be deleted (section 3) |

## 5. Changed decisions (for Josemi to confirm)

| Where | Before | In this UI |
|---|---|---|
| The conversation screen: leaving it (decision of 2026-10-14, first written in `chat.md` revision 1; since revision 2 of `chat.md` the rules for the app are in this file and not there) | The app asks "Stop the instance" or "Leave it running" | Back goes to the list without a question. The instance runs on and stays in the list. Stop is in ⋮, the info page and the long press |
| [ui.md](ui.md), section 2: the home screen (decision of 2026-10-16) | The compute view: running instances, "Run a service", the card of state | The Chats tab. The compute view is unchanged and is the Compute tab |
| [ui.md](ui.md), section 2: "Run a service" | A button of the home screen | The pencil button ("New conversation") and "Services" in the Compute tab; the Compute tab keeps its button. The confirmation is the same |
| The Celaut database | An instance has no name, and leaves the database at its stop | An instance keeps the name of its skill or service file (`InstanceRecord.name`), and stays after its stop, as stopped, until the user deletes it |

## 6. Open questions

1. An instance that its node no longer knows (for example after a restart of the node)
   cannot be stopped, so it cannot be deleted either. Should Stop mark such an instance
   stopped when the node answers that the token is unknown?

   Decision (issue #73): no change in Stop. nodo answers `StopService` for a token that it
   does not know, or that is already dead, with a refund of 0 and no error (`stop_instance`
   returns nothing and the gateway sends `Refund(0)`), so `celaut_stop_service` already
   marks the instance stopped, with no refund, and the user can then delete it. Only a
   failure of the call itself (node not reachable, client unknown) leaves the row as it is.
   The status read of such an instance fails, so `AutoTopUp.check()` waits ten minutes
   before it asks again (`ui.md` section 4), as for any other failure.

## 7. Messages and files

The screen is `ChatScreen`. The protocol is in [chat.md](chat.md). The picker is in
`app/lib/celaut/attachment_picker.dart` (`file_picker`, the system document picker).

| Part | What the user sees |
|---|---|
| Attach button | It shows only if `GetCapabilities` lists a media type of the kind in `accepted_mime_types` ([chat.md](chat.md), section 6.7). The app calls `GetCapabilities` when the chat opens, and the result does not change |
| Picker | It offers only JPEG, PNG, MP3 and WAV. At most 4 files, of 4 MiB each |
| Chips | A picked file shows as a chip above the field |
| Image in a bubble | The image shows inside the bubble |
| Audio in a bubble | The bubble shows the name of the file. A tap hands the file to the share sheet of the system. The app has no player |
| Hash of a file | The client sends and reads `Hash.type` and `Hash.value` as raw bytes (32 bytes each for SHA3-256), and checks a download against the SHA3-256 digest. It sends no empty file, no hash without `type` and no empty string in an optional field |
| Files in memory | The app keeps the files in memory only. It writes no file to the storage and no message to the Celaut database |
| List of conversations | A message with only a file shows a preview, "Photo" or "Audio" |

Flows:

- **Send.** The message shows at once as a paler bubble with "Sending…". The field is free
  for the next message.
- **Wait for the answer.** Three pulsing dots show that the service answers. After 5
  seconds, a counter shows "Still working… N s".
- **A send fails.** The text and the files come back to the field. The app never sends a
  message again by itself.
- **A slow service.** If the service takes more than 30 seconds, the app waits. It reads
  the history every 5 seconds, for up to 3 minutes. After that, it says that the service
  does not answer.

## 8. Sleep, the background and the auto-lock (2026-10-23, Josemi)

A launch, the transfer of a service file to a node, and the import of a service file do
not stop when the phone sleeps or the app goes to the background.

- **The process and the CPU.** The foreground service of the conversations
  (`ConversationService.kt`) holds them too. Dart takes a hold for each reason
  (`ForegroundHolds`, `app/lib/celaut/conversation_keep_alive.dart`): conversation, launch,
  transfer, import. The service runs while one hold is taken, and the notification names
  the most urgent reason. While a launch, a transfer or an import holds it, the service also
  takes a partial wake lock (at most 30 minutes), so the work goes on with the screen off.
  The wait of a new conversation for its service (`ChatClient.syncWhenStarted`) holds a
  launch too. A conversation alone takes no wake lock.
- **The auto-lock.** The lock does not change: when the app is in the background for the
  time of the auto-lock (2 seconds by default), the wallet locks and its keys leave the
  memory. What changes is the pages. A lock closes every page over the home screen; that
  closed the page of an import, because the file picker of Android puts the app in the
  background. While a work runs (`BackgroundWork`, `app/lib/celaut/background_work.dart`),
  the lock locks the wallet but leaves the pages. When the last work ends, the pages over
  the page of the work close, if the wallet is still locked. The pages of a launch and of an
  import show no secret, and a step that needs the wallet (a stop, a deposit) asks for the
  PIN or the fingerprint again.

## 9. Chat screen: reading, widgets, notices and audio (2026-10-24, Josemi)

These rules are for the app. The protocol is in [chat.md](chat.md), revision 6 (gRPC; the rules below are for the app and are the same as before, with the changes of section 9.1).

| Part | What the user sees |
|---|---|
| Assistant message | It has no bubble. The text shows on the background. A user message keeps its bubble |
| Text size and font | The user sets them in Settings. The default size is larger than before |
| Typewriter | The text of an answer that streams appears letter by letter. The display catches up, so it is never far behind the text that arrived |
| Haptic ticks | While an answer streams and the chat screen is shown, the phone gives small ticks (`HapticFeedback`). The app needs no new permission |
| Pinned message | A message with `pinned` `true` stays at the top once the conversation grows. It uses at most N% of the chat area, which is the height between the header and the input (25% by default, set in Settings). A tap opens it to 60% of the chat area (`pinnedExpandedFraction` in `pinned_position.dart`). The part that does not fit scrolls inside it. The list leaves room under it, so no message is hidden |
| Which one is pinned | A pinned message anchors only what comes after it. The app pins the last pinned message that is all above the visible part. It does not pin a message that is the last message, or whose bottom is still visible. If the user scrolls up past the place of that message, the app pins the one before it |
| HTML widget | A block ```` ```html ```` in `text` shows as a simple widget if the switch in Settings is on (it is on by default). Otherwise it shows as code. No script, no network, no external resource. Only an allow-list of tags and styles shows |
| Notice | When an assistant message gets `done`, the app shows a local notice. It does so only if the app is in the background (paused or hidden, not a short pause), or another screen covers the chat. The notice has the name of the chat and a generic text, never the answer. A tap on it opens that chat if the instance runs (`argus://chat/<id>`), and the list of chats if not. The user can mute each instance, in the menu of the chat and in the list of chats |
| Background | The user picks the background of the chat of each instance, in the same way as the title. The choice stays on the phone |
| Record button | The input has a record button. The app records with the microphone and attaches the sound as `audio/wav` (16 kHz, mono). The recording stops by itself before the limit of 4 MiB |
| Floating bars | The header and the input float over the chat as rounded, translucent surfaces. The list scrolls behind them. Its padding keeps the first and the last message visible. The app measures the height of the header, so a large text size does not cut it |

The watcher of answers (`chat_done_watcher.dart`) gives the notice when the user left the chat
screen:

- When the chat screen closes with an answer pending (a message is open), it hands the chat to the watcher. This includes
  the way back to the list, another tab, and the app in the background. The screen gives
  the statuses of the messages that it knew. The messages that are done in them are
  history and get no notice.
- The watcher opens a tunnel to the chat slot and a `Connect` stream ([chat.md](chat.md),
  section 6.5). It does not poll: if no stream can be opened, it reads with `GetMessages` every
  2 seconds (`ChatClient.pollWaiting`). It runs only while an answer is pending. It gives the
  notice when an assistant message gets `COMPLETED` (`done`), with the same text as the screen
  and the same rules (generic text, private on the lock screen, no notice for a muted instance).
- A message gets one notice only. The screen and the watcher share the list of the messages
  that got one. When the user opens the chat again, the watcher stops for that instance.
- An answer with status `FAILED` (`failed`) or `CANCELLED` gets no notice. The chat shows a `CANCELLED` message as cancelled. There is no cancel button for now. The user did not get an answer, so
  "the answer is ready" would be false. The user sees the failure when the chat opens.
- While a watch runs, the foreground service runs with the reason `answer`: it keeps the
  process and the CPU awake (a partial wake lock), so the reads go on with the screen off. Its
  notification says that the app waits for an answer. When the last watch stops, the app
  releases the service.
- A watch stops when no answer is pending, when the instance is muted (also during the
  watch), when the user stops the instance, when the chat screen opens again, after 5
  minutes in which the instance cannot be read, and after 30 minutes.

Known limits of the notices:

- Only a chat that the user opened in this run, and left with an answer pending, is
  watched. If the system kills the app, the watch is lost and no notice comes.
- If many answers get done between two reads of the conversation, the user gets one
  notice for the chat, not one for each answer.

### 9.0 Web services (2026-10-27, Josemi)

Every instance is a conversation, and Chats lists all of them. A row does this:

- A chat slot (`http2`, `grpc`, `chat`): it opens the chat.
- No chat slot, but a web slot (`tcp` with `http`, and no `chat` or `grpc`): it opens the
  browser of the phone at `http://127.0.0.1:<port>/`. The port is the local port of the slot
  (`celautOpenTunnel`), so the browser reaches the node through the tunnel. Each TCP
  connection of the browser is one tunnel stream, and the node charges each one. The port
  lasts while the app runs.
- Neither: the row says that there is no interface, and a tap shows the same.
- Both: the chat opens, and the menu (⋮) of the chat has "Open in browser" for the web slot.

An instance that an older version started has no web slots recorded: it shows as with no
interface.

### 9.1 Changes of revision 6 of the protocol (2026-10-24)

- The app sends over the `Connect` stream while it is open, and with `SendMessage` while it is not (the watcher uses `SendMessage` only if it must send). It reads new messages with the stream and not with a poll. While a stream
  is open there is no read every 2 or 10 seconds.
- A pinned message is any message, and the user or the service can change it. The app keeps
  the same rule for the banner: the last pinned message that is all above the visible part.
  A pin that changes while the chat is open updates the banner at once.
- The text and the reasoning of an answer grow with deltas. The slow text and the haptic ticks
  follow each delta.
- An HTML widget is still a fenced block in the text ([chat.md](chat.md), section 5.4).
- `ChatMessage.seq` is the `sequence` of the protocol, from 1. The keys of the notices, the
  slow text and the banner use it.
- `ChatClient` tells the screen about the events of the stream (it is a `ChangeNotifier`) and
  says if the stream is open (`streaming`). The screen reads with `sync` only while no stream is
  open: every 2 seconds while it waits for an answer, and every 10 seconds otherwise. The app
  reads the whole history from `after_sequence` 0 and does not use `last` or `before_sequence`:
  the list of messages has no gap.
- The user pins and unpins a message with a long press on it (an answer or a bubble of the
  user). On the text, the long press selects it, and the menu of the selection has the item
  `Pin` or `Unpin`. Outside the text (the padding, a file), the long press opens a menu with
  `Copy` (if the message has text) and `Pin` or `Unpin`. A pinned message has a small pin
  icon.
- `ChatClient.setPinned` changes the message at once. If `SetMessagePinned` fails, the
  message gets its old value back (unless the stream has set the same value as the user
  meanwhile), and the screen shows the error in a snack bar, with the text of the error kind
  (section 9 of [chat.md](chat.md)). The banner reads the messages after each change, so it
  follows a pin or an unpin of the user, and a `MessagePinnedChanged` of the stream. If the
  user unpins the message that the banner shows, the banner shows the pinned message before
  it, or none.
- Section 6.6 of [chat.md](chat.md) says that a service must implement `SetMessagePinned`.
  If a service ends the call with `UNIMPLEMENTED` anyway, `ChatClient.canPin` becomes
  `false`: the screen hides `Pin` and `Unpin`, and the client does not call the service
  again while the chat screen is open.
- A failed answer shows the `error` text of the service, under the line that says that the
  answer stopped, if it has one. The app does not read the failure from the text of the
  message or from `metadata`. A `RESOURCE_EXHAUSTED` status with no reason is `too_large`
  for a send and for a file, and `other` for another call. A full file store (`storage_full`) shows a message
  to the user, and the app does not send the file again by itself. A `Connect` stream that
  ends with `busy` is not shown to the user: the app waits at least 2 seconds and subscribes again.
- If the app cannot subscribe to the chat (the first event of `Connect` fails), it tries again
  and shows the error after 3 failures in a row. If the service has fewer messages than the
  app (for example after a reset of the instance), the app drops its copy of the chat and
  reads it again from the start ([chat.md](chat.md), section 6.5). A file whose reference has
  no SHA3-256 hash shows as unreadable, and the app does not call `DownloadFile` for it. A long
  `error` text is cut for display, by UTF-8 bytes, to 1 024 bytes. A `ProtocolError` with no
  `event_id` after `SubscriptionReady` is ignored and written in the log.
