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
  `top_up` or a `withdrawal` row on each side and nothing else). The sheet says "The node
  charges no fee for this move". If a node adds a fee one day, it must advertise it in
  `Peer.mu_per_call`, and the sheet must show it.
- **The sheet.** An amount in MU (typed, or a quick value: +100 000, +1 000 000, +10 000 000
  when the credit covers them, or half and all of the balance to take back). It shows the
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
    and the price of the most rows of one answer, 1 000);
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
  in (`deposit`, `credit`), what the operator took (`debit`), the reads of statements, and
  for each instance the MU that went to it (`child_start` with its `child_bound`, `top_up`)
  and that came back (`withdrawal`, `refund`). A `child_start` with no `child_bound` yet is
  "starting"; a `refund` that names it (`refunds_seq`) ends it.
- **An instance.** The token of the instance and its own `instance_ref`, so that the node
  also reads an instance that stopped while it keeps its row. It gives each kind of charge:
  `maintenance` (the resources), `tunnel` (the traffic), `build`, `resource_change`,
  `statement_query`, `child_start` (children), and what came in and went back.

### Spent

Spent = what the account had before the first movement read + what came in − what went
back to the father − the balance at the head. For the client, the MU that a running instance
still holds counts as spent: it comes back as a `refund` when the instance stops. The note
under the sums says this. When the node no longer holds the first movements (its retention;
the first movement read has a `seq` above 1), the sum starts there: "X, since <date>".

A value that the app did not read is "unknown", never 0.

### The screens

- **Home (Compute tab).** One line: the credit on all the nodes (as before), and under it
  "spent X" from the last read of each node, in ERG at the rate of each node: the sum, "at
  least …" when a node was never read or has no rate, or "unknown". No read happens here. A
  tap opens "Balance and spending by node": for each node the balance now and the spending
  of the last read; a tap on a node opens its detail.
- **The detail of a node** (#123) has "Balance and spending" when the app has a client there:
  the balance now, spent, the balance at the last read, what the reads cost, the date of the
  last read, and "Read the statement" (or "Read the rest" when the node gave part of the
  movements). "Spending by instance (N)" is a closed part: each instance (running, stopped,
  or deleted from the app, by its short `instance_ref`) with the MU that went to it. A tap
  opens its costs, with "Read the costs" (a paid read of the account of the instance).

## 3. Open points

- A period for the spending (day, week, all): the tally has sums since the first read, not
  movements by date. A period needs the app to keep the movements, or a sum by day.
- The reads of the descendants section (descendants.md) and of "Read the costs" are of the
  same account of the held instance, with two cursors: the same movements can be paid for
  twice. One cursor for both is a follow-up.
- The tally of an earlier client of a node (after "Make a new client") stays in the database
  and is not shown.
