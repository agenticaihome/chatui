# Add or take back MU, and the balance and the spending of each node (issue #136)

This file says how the app moves MU between the credit of the user on a node and an
instance, and how it shows what the user has and spent on each node. The rule of #122 and
#123 applies: the minimum first, the details behind one tap.

## 1. Add MU and take back MU

On the info page of a running instance, "Time and credit" has two buttons: **Add MU** and
**Take back MU**. They are there also when "Keep running" is on.

- **The call.** `ModifyDeposit` (wire.md, line ModifyDeposit) with the difference in MU: a
  positive value moves MU from the credit of the client on the node to the instance, a
  negative value moves MU from the instance back to the credit. The `Client` is the father of
  the instance (nodo #597). Nothing goes on the blockchain and nothing is signed. FFI:
  `celaut_move_instance_mu(instance_id, amount_mu, take_back)`; Rust:
  `NodeSession::top_up` and `NodeSession::take_back`.
- **The fee.** nodo charges no fee for `ModifyDeposit` (`manager.modify_deposit` writes a
  `top_up` or a `withdrawal` row on each side and nothing else). A node that charges one
  advertises it in `Peer.mu_per_call` as `modify_deposit_mu` (Josemi, PR #148): the sheet
  then says "The node charges X for this move" (FFI `celaut_move_fee`); with no such key it
  says "The node charges no fee for this move".
- **The sheet.** An amount in MU (typed, or a quick value: +100 000, +1 000 000, +10 000 000
  when the credit covers them; to take back, half of the balance, and **all but one period**:
  the balance less what keeps the instance one more period at the price of the node now (the
  period that runs and the next one, as "how long it lasts" counts them), so that the quick
  value never stops the instance (Josemi, PR #148). That quick value needs the price of the node and a balance of
  more than one period. A typed amount can still take all of it; the sheet then says that
  the node stops the instance at its next charge). It shows the
  balance of the instance and the credit of the user, each as "before → after", and how
  long the instance lasts after the move at the price of the node now (or that the node
  stops it at its next charge). A second question ("Add MU to the instance?") comes before
  the call: the call moves money.
- **The checks.** Before the call: the amount is a whole number above 0; to add, it is not
  more than the credit (`GetClientMetrics`, else `InsufficientCredit` and the sheet offers
  the deposit screen); to take back, it is not more than the balance of the instance
  (`GetMetrics`). The node checks again; a refusal shows its text ("The node refused: …").
- **The wallet.** As for "Keep running", a move needs the full wallet open (PIN or
  fingerprint): a read-only wallet only sees.
- **Keep running.** The two do not fight, and neither turns the other off. With keep running
  on, the sheet says so: to add, that the top-up goes on adding MU when the balance is low;
  to take back, that it moves MU to the instance again when the balance gets low, so turn it
  off first to keep the MU on the credit.
- **The cost so far.** `InstanceRecord.added_mu` (by hand) and `withdrawn_mu` keep what the
  user moved. The cost so far is the start charge, plus the top-ups and what was added, less
  what was taken back, less the balance now. "Keep running" counts only its own top-ups
  (`topped_up_mu`) against its limit.

## 2. The balance and the spending of each node

### What the app reads

- **The balance now** comes from `GetClientMetrics`. It is free.
- **The spending** comes from the signed balance statements of the node
  (`GetBalanceStatement`). A read costs MU (`statement_query_mu` + `statement_row_mu` for
  each movement, from `Peer.mu_per_call`) and writes a `statement_query` movement. So:
  - the app never reads a statement by itself, in the background or on a timer;
  - each read is one tap, after a question with the most that it can cost (the fixed price
    and the price of one page of **100 movements**, Josemi PR #148);
  - a read asks for one page: the 100 movements after the last one read
    (`to_seq = from_seq + 99`). When the account has more, the sums say that the node gave
    part of the movements, and the button becomes "Read the rest", which reads the next page;
  - a node that does not advertise the two rates is not read ("This node does not say what a
    statement costs").
- **Each read is incremental.** The app keeps, for each account that it read, a tally
  (`celaut_client::spending::Tally`, in `CelautData.tallies` by `account_ref`): sums by kind
  of movement, the MU that went to each instance by its `instance_ref`, the balance and the
  head that the node signed. The next read asks from the movement after the last one that it
  read, so a movement is paid for once. The tally keeps no movement and no credential.
- **The checks** are the ones of descendants.md: the signature of the node of the
  connection, the date, the hash chain, each balance after, the head and the head that the
  app kept, and the account (`account_ref` of the client id or of the token). A statement
  that fails a check changes nothing; the node may have charged the read, and the screen
  says that the statement could not be read.

### Two accounts

- **The client.** `BalanceStatementRequest` with no token. It gives the balance, what came
  in (`deposit`, `credit`), what the operator took back (`debit`), the reads of statements,
  and for each instance the MU that went to it (`child_start` with its `child_bound`,
  `top_up`) and that came back (`withdrawal`, `refund`). A `child_start` with no
  `child_bound` yet is "starting"; a `refund` that names it (`refunds_seq`) ends it. A
  `refund` to an instance (its `instance_ref`) is its stop: the node gives back what was
  left. The app then shows the instance as stopped, also when its own record says it runs
  (the node stopped it, for example out of balance) (Josemi, PR #148).
- **An instance.** The token of the instance and its own `instance_ref`, so that the node
  also reads an instance that stopped while it keeps its row. It gives each kind of charge:
  `maintenance` (the resources), `tunnel` (the traffic), `build`, `resource_change`,
  `statement_query`, `child_start` (children), and what came in and went back.

### Spent

Spent is the sum of the movements that the app read: what left the account less what came
back, of each kind that is not money coming in (`deposit`, `credit`) nor, for an instance,
MU moved with its father (`start`, `top_up`, `withdrawal`, `refund`). With every movement
read, it is what the account had + what came in − what went back to the father − the
balance. A sum of movements also holds when a read stops before the head (a page).

- **A `debit` is spending** (Josemi, PR #148): credit that the operator takes back is gone
  from the user's credit like any charge.
- **The running instances.** For the client, the MU that went to an instance counts until it
  comes back. On the node screen, the app asks the node for the balance now of each running
  instance (`GetMetrics`, free, FFI `celaut_live_instance_balances`) and takes it out of
  spent (Josemi, PR #148): "Still in running instances: X". For each instance, the part
  taken out is at most the MU that moved to it in the period: the MU still held is the MU
  moved last. An instance that does not answer keeps its MU in spent, and the screen says
  how many did not answer. The home line and "Balance and spending by node" ask no node, so
  there the MU in running instances counts as spent; their note says so.
- When the node no longer holds the first movements (its retention; the first movement read
  has a `seq` above 1), the sum of all the movements starts there: "X, since <date>".

A value that the app did not read is "unknown", never 0.

### The period: today, 7 days, all

The tally also keeps the sums of each day (`Tally::days`, by the day of the movement on the
clock of the device at the read; Josemi, PR #148): the MU of each kind, and the MU that went
to and came back from each instance. The node screen has a switch **Today / 7 days / All**:
spent, what the reads cost, the split by instance and the costs of an instance are the sums
of that period. "7 days" is today and the 6 days before it. The tally keeps the days of the
last 92 days; "All" uses the sums of every movement read, which it keeps apart.

### One cursor for the account of an instance

The check of the descendants of an instance (descendants.md, depth 0) and "Read the costs"
read the same account. They share one cursor (Josemi, PR #148): the next read of either one
starts after the last movement that **both** have read, and each verified read is kept in
both (`keep_instance_read`: the tally, and the head, state, stop and children of the record
of the held instance). A movement that one of them had already read is not counted twice.
A check of the descendants that one tap starts still shows its findings; a read of the costs
updates the record of the held instance (its state and its new children) without a dialog.
Both take the same lock, so they never run at once.

### The screens

- **Home (Compute tab).** One line: the credit on all the nodes (as before), and under it
  "spent X" from the last read of each node, in ERG at the rate of each node: the sum, "at
  least …" when a node was never read or has no rate, or "unknown". No read happens here. A
  tap opens "Balance and spending by node": for each node the balance now and the spending
  of the last read; a tap on a node opens its detail.
- **The detail of a node** (#123) has "Balance and spending" when the app has a client there:
  the balance now, the switch Today / 7 days / All, spent (less what the running instances
  still hold, shown on its own line), the balance at the last read, what the reads cost, the
  date of the last read, and "Read the statement" (or "Read the rest" when the node gave
  part of the movements). "Spending by instance (N)" is a closed part: each instance
  (running, stopped, or deleted from the app, by its short `instance_ref`) with what it
  spent of the MU that went to it. A tap opens its costs: the MU moved to it, its balance
  now, and "Read the costs" (a paid read of the account of the instance).

## 3. Decisions (Josemi, PR #148)

- The wallet gate stays: Add MU and Take back MU need the full wallet open.
- The home credit line opens "Balance and spending by node"; the node list stays one row
  below.
- The tally of an earlier client of a node (after "Make a new client") stays in the database
  and is not shown.
