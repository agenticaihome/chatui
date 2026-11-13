# Product and UI direction (2026-10-13)

This note tells developers how the app must look and how it must treat wallets and
instances. It follows [decisions.md](decisions.md). Josemi decided these points on
2026-10-13. Features that are not built yet (M4 and M5) must follow this note.

This note says what the app must do. PR #15 brought the code of M3 to this note. Where
the plan describes the code, it describes the code of `master`; this note wins when
they differ.

## 1. Wallets

**Decision of 2026-10-16 (Josemi), which replaces the two types of wallet of
2026-10-13:** the app holds **one** Ergo wallet, with its seed on this device. There are
no read-only (watch-only) wallets and no offline signing.

- With no wallet, the app offers to create a wallet or to restore one from its recovery
  phrase. With a wallet, it offers neither.
- To change the wallet, the user removes it in its settings (Settings, This wallet,
  Remove wallet), then creates or restores another one.
- **Migration at the update.** An earlier version can hold more than one wallet and
  watched addresses or accounts. At each start the app removes them
  (`app/lib/services/single_wallet.dart`):
  - the watched addresses, the watched accounts and their token tables;
  - the default payer of the deposits;
  - every wallet after the first of the user order of the wallets list, with its seed.
    This delete cannot be undone: the recovery phrase on paper is the only way back to
    such a wallet.

Rules:

- A wallet is **not** the owner of Celaut data. Instances, client ids, instance
  tokens, node sessions, quotes and the reputation event log are kept in **one
  database for the whole app**. There is no database per wallet. Do not add a
  `wallet_id` key to the Celaut tables.
- The wallet manages the instances (start, stop and any action that needs a signature)
  and pays the nodes (a deposit, M3). If the app has no wallet, the deposit screen says
  so and does not start, and the instance actions are disabled with the same message.
- The deposit screen shows the wallet that pays and its balance. Before a deposit signs,
  it asks for the PIN or fingerprint of the wallet, even if the wallet is already open.
- Start and stop need the wallet **open** (unlocked). If it is locked, the action asks
  the user to unlock it.
- The data of a node (deposit, client id, balance) does not record which wallet paid,
  except in the transaction history that the user can see (transaction id, address).
  After the user changes the wallet, a later deposit to the same node comes from the new
  wallet.

## 2. Home screen: what the user acts on

**Chat-first UI (2026-10-21):** the home screen is a bottom bar with Chats, Wallet,
Compute and Settings (decision of Josemi). The first tab is Chats (for Josemi to confirm),
and the compute view of this section is the Compute tab
([ui-chat-first.md](ui-chat-first.md)). The view itself is as this section describes it. The landing page of Celaut (branch `celaut-design`) is the visual reference.

**Decision of 2026-10-16 (Josemi), which replaces the order of 2026-10-13 ("compute
first"):** the home screen shows only what the user acts on. The figures and the detail of
each node are one tap away. In this order:

1. **Running instances**, only when there are some: they cost money now. Each has its cost
   so far and a stop action. With no instance, nothing is shown.
2. **Run a service**: one button. It opens a screen of its own with the catalog of skills,
   the service files of the user and the import of a file
   (`app/lib/ui/celaut/run_service_screen.dart`). The catalog is read only there.
3. **One card of state**, three lines, each opens its detail:
   - the nodes: "N of M nodes ready · cores · memory", with a coloured dot (all ready,
     some, none). It opens the Nodes screen;
   - the credit on the nodes, in ERG with its USD value. It opens the Nodes screen;
   - the ERG of the wallet, with its USD value. It opens the page of the wallet; with no
     wallet, the screen that creates or restores one.
   A node that forgot the client of the app shows its action under the nodes line,
   because the user must choose (section 3).

Not on the home screen any more: the big figure of the cores, memory and disk as separate
figures, the note "offered, not free", the paid and the free credit
apart, the USD source note, the card of each node (address, MU, rate, latency, reasons) and
"Check now". The Nodes screen has the card of each node: its availability (section 4), its
credit from the last overview, the action for a forgotten client, and "Check now".

**Load.** The home screen shows the last overview at once when it opens again (it is kept
in memory), with a thin line while it asks the nodes; on the first open it says that it
loads, and the button and the wallets do not wait. The overview gives each node 5 seconds
for each step (20 through Tor), not 15: one node that does not answer no longer holds the
screen for 30 seconds. The home screen does not check the nodes in the background (the
overview records one check for each node it asks); the Nodes screen checks them while it is
open. The catalog keeps its answers for 5 minutes, and gives the last answer when the
explorer fails.

Rules for the numbers:

- Sums are over **advertised** resources, not free resources. Say "offered", not
  "free", unless the node tells how much is free.
- A sum with a missing part reads "at least X (N nodes unknown)". The data keeps the
  known part and the number of nodes without the value.
- A node that advertises several architecture entries counts with its **largest**
  entry, not the sum of them. The largest entry has the most memory; with equal
  memory, the most cores; then the most disk. A known value is larger than an unknown
  value. The values of different entries are not mixed.
- Do not add the resources of one node twice when the node is reachable through more
  than one URI. The key is the peer_id.
- Show a value as "unknown" when it is missing. Do not show 0.
- ERG and MU are different units. Show both where money is shown, with the rate of the
  node that the value uses (see M3 in the plan).

### Run a service

The pencil button of the Chats tab ("New conversation"), "Services" in the Compute tab and
the button "Run a service" of the Compute tab open this screen
(`app/lib/ui/celaut/run_service_screen.dart`, with the section
`app/lib/ui/celaut/run_service_section.dart`). It lists the skills of the catalog with a
search field. A skill opens a sheet with its services, best first, and the node that the
balancer would use with its start cost. Run needs the wallet open.

- The screen lists every skill of the catalog; the search narrows the list.
- Run asks first: "Run <name>?", with what a running instance costs and the node that the
  balancer would use now with its start cost (or that no node gave a price yet). Run in
  the list of the service files of the user asks in the same way. The launch again after
  a transfer of the service does not ask a second time.

- Run asks every node of the Nodes list for a quote and starts the service on the first
  node that works (`launchService`). Nodes whose last checks failed twice in a row are not
  asked, unless that would leave no node. A node where the credit of the app is less than
  the price is not asked to start.
- If the service has a chat slot, the app goes back to the list of conversations and opens
  the conversation. If not, a message shows, and the instance is in the page of its service
  (Compute tab, Services).
- If no node starts it, a sheet says why for each node: the reason and what to do (the text
  of the error kind), the numbers for a credit problem with a button to the deposit screen,
  "left out" for the nodes that were not asked, and the original text of the node under
  "Details". A node that forgot the client id gives the usual choice; the app never makes a
  new client by itself.

#### 2.1 The store (#102, 2026-11-05; simpler in #122, 2026-11-10)

The screen is a store. These parts stay at the top at all times, above the part that
scrolls:

- the search field;
- two small actions for the service files on this phone: "Import" (pick a `.celaut.bee`
  file) and "On this phone" (a sheet with the saved files, each with Run and Remove, and
  the import). On a narrow screen they are icons with a tooltip; from 560 dp they also
  show their text. The phone icon shows the number of saved files.

Under them there is one way to browse (#122): one list of the skills, in groups by field.
The field is the title of its group, not a line of each card; the skills with no field are
one group, "Other". The skills come with the most backed first: the reputation of the
publisher (nanoERG of the boxes that hold the profile token of the skill box), then the
number of declared services, then the newest, then the name. The list shows the first 6
skills and "Show more (N)"; a search shows all the skills that match, in their groups. The
search looks in the name, the text, the tags and the field.

A card has at most three lines of text: the name, one line of the text and the number of
services, with one action, Run. The tags and the whole text are in "About this skill", a
closed part at the top of the services of the skill. The rows Featured, Suggested, New and
Popular, the tiles of the fields and the chips of #102 are gone: they repeated the same
grouping.

#### 2.2 The services of a skill (#122)

Run on a card opens a sheet (in the Run screen) or a page (the skill picker of the service
screen) with the services of the skill. The ranking does not change (`catalog.md`); the
screen shows less at each step:

- One banner at the top: "Most results are tests. Check before you trust them." It is not
  repeated on the cards or under the button.
- One main card, "Recommended": the first of the ranking, chosen at first. One main action:
  Run (sheet) or "Use this service" (picker).
- The other services are under "Other options (N)", closed at first. A tap on a card
  chooses it; the chosen card has a check and a border.
- The score is a level, "Rating: High / Medium / Low" (from 0.7 high, from 0.4 medium, else
  low; a service with no data scores 0.5), with a short bar of three parts.
- Where the data comes from is an icon with a tooltip: "Declared by the publisher", or
  "Seen only in test results, not declared by a publisher". The second also has the chip
  "Unverified".
- "Details", closed at first: the id in short form (first 6 and last 4 characters) with
  Copy (the full id), the exact rating ("0.62 of 1") and the source in words. No screen
  shows the 64-character id or the raw score before the user opens "Details".

## 3. What this changes in the milestones

| Milestone | Change |
|---|---|
| M3 | The deposit uses the wallet of the app. The confirmation screen shows the wallet, ERG and MU |
| M4 | The conversation screen and the instance list read from the single database. Starting or stopping an instance needs the wallet open |
| Home | The home screen follows section 2. Do it with the first screen that needs the node data (M3), or in its own PR before it |
| Storage | The Celaut store (client ids, instance tokens) is one encrypted store for the app, as the plan already says. See plan section 3 |
| Client ids | If a node forgets a stored client id, the app shows the error and asks the user: create a new client (the old balance is lost) or retry later. It never creates a client silently |
| Per-node limit | 1 ERG per node. It counts all deposits of the app to that node, from any wallet, and is kept across restarts |

## 4. Known nodes and the explorer

- The app keeps an **explicit list of nodes**, with add and remove. A node is added by
  address or QR code, or comes from the on-chain directory (decisions.md).
- Removing a node takes it out of the sums of the home screen. Its deposits and client
  id are kept, so adding it back restores them.
- The user can mark a node as **fully trusted** (a node of the user, or of family, friends
  or the company), with the switch on its card. Before a sensitive environment variable goes
  to a node that is not trusted, the launch warns ([env-variables.md](env-variables.md),
  section 3.2). A new node is not trusted.
- The Ergo explorer is fixed to the nodo default. A node does not advertise an
  explorer, and the app does not poll one from the node.

### Availability of the nodes

Each node card on the home screen has a line with the availability of the node, from the
checks that the Rust core keeps in the Celaut database (`celaut-client/src/health.rs`):

| State | Line |
|---|---|
| Available | "Available · 42 ms" |
| Slow (3 s or more) | "Slow · 4200 ms", in the warning colour |
| Unreachable | "Not answering · Last answer 2 h ago" (or "It has never answered"), then the reason in words (the text of the error kind) and the text of the node or of the transport in a smaller muted line |
| Not checked yet | "Not checked yet" |

A coloured dot goes with the text and never replaces it. While a check runs, the line adds
"Checking…".

When the home screen is open, the app asks the core every minute to check the nodes that are
due, and when the app is in use again. The core decides which node is due: a node that works
is checked every 5 minutes, and a node that fails later and later (30 s up to 15 minutes);
through Tor the times are three times longer. A check has a limit of 5 seconds (25 through
Tor). "Check now" under the node cards checks all the nodes. A check changes only the node
cards: the overview (the figures) is not loaded again. Nothing is checked while Tor is
starting or has failed.

### The detail of a node and the resources (#123, 2026-11-10)

Each row of the node list has a Details action (an info icon). It opens the detail of the
node: the screen of `node_connect_screen.dart`, which connects at once and checks the peer id.
The rule is the one of #122: the minimum first, the details behind one tap.

- **Ids.** The peer id and the client id of the app show in short form (first 6 and last 4
  characters), each with "Copy" (the full id) and "Show full id". The client id is read from
  the Celaut database of the app (`celaut_client_id`); it shows only in the detail, never in
  the node list, never in a log or an error report. With no client yet the row says "No
  client yet". A node that forgot the client id shows no id: only the usual message and
  "Make a new client" (the same choice as in the list; never a new client by itself).
- **Resources of one node.** One summary line: CPU, memory and disk with their units, from
  the entry that the node counts with (the largest; the same as the sums of the home). A
  value that the node does not give is "unknown", never 0. When the last overview of the
  home has other nodes, a small bar for each resource shows the part of the total of the
  nodes that answered that this node has. The architectures and the benchmark are in a closed
  "Details" part.
- **Resources of all the nodes.** The home line stays one short total. A tap opens
  "Resources of the nodes", with one view at a time (a switch; "By resource" is the default):
  - *By resource*: CPU, memory or disk (chips, in this order). The total ("at least …" when
    some nodes do not give the value), and a stacked bar that splits it between the nodes,
    with one row for each node, the largest first. A node whose value is unknown is a striped
    part of the bar and says "unknown".
  - *By node*: a card for each node with its three resources (a bar and the value for each),
    the largest node first (memory, then cores, then disk).
  - The nodes that did not answer are counted apart ("1 node did not answer and is not in the
    total"), never as 0. One note says that this is what the nodes offer, not what is free.
  - No full id: a node shows as its address and its peer id in short form.
  - "By architecture" is not there yet: the overview has one entry for each node (its
    largest), not the entries of each architecture.

## 4b. Keep running (2026-10-29, Josemi; before: "Automatic top-up", 2026-10-23)

An instance stops when its balance on the node runs out. Two ways to choose how long it runs:

- **For a time.** The confirmation of a launch has a field in minutes; the app turns it into
  the start balance (`initial_mu`) with the price of the node (`survivalBalanceMu`: the periods
  in the time plus one, each at `init_maintenance_mu * (1 + price_volatility)^k`, as nodo's
  `funding_sum_mu`; [balancer.md](balancer.md)). Without a time, no `initial_mu`: the node
  chooses the start balance (issue #119). On a running instance, **Add time** on its info page
  moves that much more, at the volatility periods after the time since its start.
- **Until I stop it.** The second choice of the confirmation, and a switch on the info page.
  The app tops the instance up while the user does not stop it. It is the dangerous one: it
  uses the credit of the user on the node. The warning is always on screen when the user
  chooses it, and it says that it works only while the app runs and there is credit.

Details:

- **Per instance.** `InstanceRecord.keep_alive` (with an optional limit, `budget_mu`) and
  `InstanceRecord.pricing` (the price of the node that won the start, so that MU and time turn
  into each other). `celaut_set_keep_alive`, `celaut_set_instance_pricing`,
  `celaut_instance_plan` (the plan, from the database) and `celaut_instance_credit` (the credit
  of the user on the node, asked to the node). There is no global switch any more: the old
  one (`celaut_auto_top_up_v1`) is not read, so an instance that ran under it must be turned
  on again.
- **What it moves.** When a kept instance would last less than the threshold (default 15 min;
  1 min to 1 day), the app moves a chunk of time (default 1 h; 1 min to 30 days) from the credit
  of its client on that node to the instance, with `ModifyDeposit` (`celaut_top_up_instance`,
  at most 100 000 000 MU a call; a longer time goes in several calls). The threshold and the
  chunk are in Settings, Compute, "Keep running". An instance with no price (it started before
  the app kept it) uses 200 000 MU and 1 000 000 MU. That credit is already on the node:
  nothing goes on the blockchain and nothing is signed. The instance keeps the sum of its
  top-ups (`topped_up_mu`), and the cost so far counts it.
- **The limit.** Optional, in MU, from the moment the user turned it on (`spent_mu`: what was
  moved since then). At the limit the app moves nothing and says so; the instance stops when
  its balance runs out. A new limit: turn the switch off and on.
- **Time and credit** on the info page of a running instance: the balance and the credit of the
  user on the node, each with the time that it lasts; the switch; Add time (chips +30 min, +1 h,
  +1 day, or minutes; the cost, and what is left). If the credit is not enough, the sheet says
  so and offers the deposit screen. The list marks a kept instance with the infinity sign.
- **No transaction without the user.** The app checks the credit first. If it is less than
  the amount, the app moves nothing and pays nothing: the list of conversations shows a
  banner, and its Deposit button opens the deposit screen, where the user chooses the amount
  and confirms the transaction with the PIN or the fingerprint, as for any deposit. Choice:
  keep running never makes an on-chain deposit, also not a small one with a cap; only node
  credit moves without a question.
- **Turning it on** asks again, with the warning and the limit, and needs the wallet open (PIN
  or fingerprint), because from then on the app moves credit without asking each time. Turning
  it off moves nothing.
- **When it checks.** When the list of conversations reads the balances (it opens, the user
  comes back, a pull), and once a minute while the app runs and an instance is kept; with none
  kept, nothing polls and there is no timer. Only kept instances are read for this. After a
  top-up of an instance the app waits a minute before the next one for it; after a failure, ten
  minutes. The app does not run when it is closed: then nothing tops up, and the node stops the
  instance when its balance runs out. A foreground service for that is not done.
- **A node that closes** (issue #129, nodo#344; [balancer.md](balancer.md), The activity
  window of a node). The confirmation of a launch says when the best node closes and what it
  does with the instance then: "stops the instance and gives back the balance that is left",
  or "hibernates the instance, and wakes it when it opens again". It is red when the close
  comes before the instance would end. With "until I stop it" on a node that stops it, it
  says that keep running cannot keep the instance after that time; the info page of a kept
  instance says the same under the switch, and so does the question that turns keep running
  on. The settings screen of keep running has a general note. A node that leaves running
  instances alone at its close (REFUSE) says nothing. A launch that fails because a node is
  closed says when its schedule opens again.

## 4c. Add or take back MU, and the spending of each node (issue #136)

- **Add MU / Take back MU** on the info page of a running instance, next to "Add time": an
  amount (typed or a quick value), the balance of the instance and the credit before and
  after, "no fee", a note when "Keep running" is on, and a second question before the move
  (`ModifyDeposit`; credit already on the node, nothing on the blockchain).
- **Balance and spending** in the detail of a node: the balance now (free), and what the
  signed statements say it spent. A read of a statement costs MU, so it is a tap with a
  question that gives the most that it can cost; the app never reads by itself. The split by
  instance is one tap away. The home line of the credit says "spent X" too, and opens the
  split by node.
- The details are in [spending.md](spending.md).

## 5. Open items

- The exact layout, colors and motion of the compute screen. Use the celaut-design
  landing page as the reference, and ask Josemi for anything it does not show.

Ask Josemi before you decide anything not written here.

## Hibernate and wake

The long press of a row (and the info page) offers Hibernate for a running instance, and Wake
for a hibernated one. Both ask first, and both need the wallet open, as Stop does. The
Hibernate dialog says that the process state is lost when the instance wakes, and that the node
charges only for the disk meanwhile. The Wake dialog shows the CPU and RAM that the instance will
use, and says if those values are only the last that the app knows. The info page of a hibernated
instance shows the state, the time of the hibernation and the stored CPU and RAM. A tap on a
hibernated row opens its info page, because its service does not answer. A refusal of the node
(shared filesystem, no restart from its own disk, not enough balance for the fee, no room on the
node, or another reason) shows as a snack bar, and nothing changes.

A hibernated instance with "run until I stop it" on is kept alive for its disk only (see
`decisions.md`): the engine tops it up to the disk price plus the fee of the wake call, and the
top-up does not wake it. A hibernated row is never "Not answering" and gives no notice. If the
node stopped it for lack of balance, the row shows as stopped after the next read. If the node
refuses hibernation as unsupported, the app says so once, and the rows of that node show no
Hibernate or Wake until the app restarts; the info page says why.
