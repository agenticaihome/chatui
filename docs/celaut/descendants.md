# Descendants of nodo#631

This file is the specification for the use of descendants in the app. It follows nodo
`a97148dd` (`nodo:docs/TUNNELING.md`, `nodo:docs/REPUTATION.md`,
`nodo:docs/EXECUTION_RECEIPTS.md`, `nodo:src/manager/balance_statement.py`,
`nodo:src/database/ledger.py`). The proto is `rust/crates/celaut-proto/protos/celaut.proto`.

A descendant is an instance below an instance that the app holds. The app holds the token
of the ancestor. It never holds the token of the descendant. It names the descendant by
its `instance_ref`.

Two features use it:

- `GetBalanceStatement` with `instance_ref`: read the signed movements of a descendant.
- `ServiceTunnel` with a `DescendantTunnel` message: open a byte stream to a descendant.

## 1. The rules of the plan

1. A statement read costs MU and writes a `statement_query` movement on the node. The app
   must NEVER read a statement by itself. This includes polling, a timer, a background task
   and a read at the start of a screen.
2. Each read needs an explicit confirmation of the user. The confirmation shows the
   maximum MU of that read (section 8). One confirmation is for one read. It is never saved
   for a later read.
3. The API of the read takes a `max_mu` argument. The caller must pass it. The code
   refuses a read when the maximum MU of the read is more than `max_mu`. The code does not
   send the request in that case.
4. The app refuses an answer in each of these cases:
   - the `instance_ref` of the answer is not the `instance_ref` of the request;
   - the signature does not verify;
   - the hash chain does not verify;
   - the answer is from a node that ignores the field (section 9).
5. A node that does not know `DescendantTunnel` (index 2) gives an error. The app shows
   the message "node does not support descendants".
6. With Tor on, each call uses the existing route (`network.md`). The app never opens a
   direct connection.
7. The app never invents a cryptographic detail. Each text and hash in this file is from
   the nodo code. The tests use the vectors of section 10.

## 2. The request

`BalanceStatementRequest` (RPC `GetBalanceStatement`, request index 1, `Client` at index 2):

| Field | Meaning |
|---|---|
| `token` (1) | The token of an instance that the caller holds: the ancestor. Empty means the account of the client. |
| `from_seq` (2) | The first movement. 0 asks for no movement, only the head. |
| `to_seq` (3) | The last movement, included. 0 asks up to the head. |
| `instance_ref` (4) | The descendant. Empty reads the account that `token` names. |
| `remaining_hops` (5, optional) | The hop budget. Absent means the maximum of the node (default 16). |

The `instance_ref` of the instance of `token` itself is also accepted. It reads that
account, also when the instance stopped.

The app finds the `instance_ref` of a descendant in the `child_bound` movements (section 6)
of the statement of its ancestor. It cannot make one up: the node asks no peer for a ref
that no chain links, and answers `PERMISSION_DENIED`.

## 3. The instance_ref

    instance_ref(token) = blake2b-256 hex of UTF-8("celaut-ledger-instance:" + token)

The token is the string of `ServiceInstance.token`. The hash has 32 bytes and gives 64
lowercase hex characters (`ledger.instance_ref`). For a delegated child, the token is the
alias that the node gave, not the token of the peer.

The `account_ref` of a statement is the same hash with the prefix `celaut-ledger-account:`
and the `client_id` or the instance token (`ledger.account_ref`).

## 4. The statement

New fields of `BalanceStatement`:

| Field | Meaning |
|---|---|
| `relayed` (12) | True when the signing node did not write the movements. It read them from the next node and signed them again. |
| `service_id` (13) | The service of the descendant, as lowercase hex of its content hash. Empty if the node does not know it. |
| `instance_ref` (14) | The `instance_ref` of the request. Empty in the answer to a read without `instance_ref`. |

### 4.1 The digest

The digest is the blake2b-256 hex of the UTF-8 of this text (`statement_digest`). All
the fields but `signature` are in it. `hex(x)` is the lowercase hex of the UTF-8 bytes of
the text `x`. Numbers are decimal.

    account_ref | from_seq | to_seq | ts | retention_days | oldest_seq | head_seq
      | head_hash | hex(balance.n) | hash(m1)/hash(m2)/.../hash(mN)

The separator `|` has no spaces around it (the spaces above are for reading). The movement
hashes are joined with `/`. For a statement with no movement, the last part is empty.
Then the optional parts follow, in this order:

1. If `service_id` is not empty: `|service_id:` and `hex(service_id)`.
2. If `instance_ref` is not empty: `|instance_ref:` and `hex(instance_ref)`.
3. If `relayed` is true: `|relayed`.

A field that is empty or false adds nothing. So the digest of an old statement does not
change. The digest does not cover the rows by their fields. It covers the hash of each row
(section 5).

### 4.2 The signature

The node signs the UTF-8 of this text with its identity key (Ed25519):

    celaut-balance-statement:<peer_id>|<statement_digest>

`peer_id` is the 64 lowercase hex characters of the public key of the node
(`statement_payload`). The signature is 128 lowercase hex characters
(`sign_peer_payload`). The app refuses any other spelling. The check uses the `peer_id` of
the TLS connection, as for a receipt. A statement with an empty signature is not valid.

With no identity key, a node gives an empty signature. The app refuses that statement.

## 5. The hash chain

The hash of a movement (`ledger.movement_hash`) is the blake2b-256 hex of the UTF-8 of:

    celaut-balance-movement:<prev_hash>|<seq>~<ts>~<hex(amount)>~<hex(balance_after)>~<hex(kind)>~<instance_ref>~<hex(detail)>

- `amount` and `balance_after` are the decimal integers of `Amount.n`, with `-` for a
  negative value. `hex()` is applied to that decimal text.
- `instance_ref` is the plain text of the movement, and empty if the movement has none.
  It is not hexed.
- `detail` is the text of the movement (JSON with sorted keys and no spaces), and empty if
  the movement has none.
- `prev_hash` is the hash of the movement before. For the first movement of an account, it
  is the genesis hash:

      genesis(account_ref) = blake2b-256 hex of UTF-8("celaut-balance-genesis:" + account_ref)

  The `account_ref` here is the hash of section 3, as a text.

The app checks the chain of a statement in this way:

1. Each movement has `prev_hash` equal to the hash of the movement before it. The `seq`
   goes up by 1, with no gap.
2. The first movement of the range hangs from a hash that the app cannot check, unless
   the range starts at seq 1. Then the `prev_hash` must be the genesis hash.
3. If the statement has movements up to the head, the hash of the last movement is
   `head_hash`, and its `seq` is `head_seq`.
4. With no movement in the range (`from_seq` 0), the head is only signed. If `head_seq` is
   0, `head_hash` is the genesis hash.
5. If the app kept an earlier head of the same descendant, a statement must agree with it.
   The head never goes back, a `seq` keeps its hash, and the movement after the kept head
   hangs from it (`head_conflict`).

## 6. The movements child_bound and stop

`child_bound` (a new kind of movement):

- It moves nothing: `amount` is 0, and `balance_after` is the balance of the account.
- `instance_ref` is the child, by the hash of section 3.
- `detail.starts_seq` is the `seq` of the `child_start` movement that it completes, as a
  decimal text.
- `detail.service_id` is the service of the child, as lowercase hex. Old rows do not have
  it.

A `child_start` with no `child_bound` and no `refund` is a start in progress. A
`child_start` has `detail.start_ref` (hex) when the start request had one.

`stop` (the last movement of an account that ended):

- It moves nothing. `balance_after` is what stays after the `refund`.
- `detail.reason` is the death reason of the instance.
- `detail.leftover` is the MU that the `refund` took out, as a decimal text. It is `0` if
  none.
- `detail.tick` is present when the reason is `out_of_balance`. It is the price of the
  maintenance tick that the instance could not pay.
- A stopped account takes no more movements.
- If the father is gone, the `refund` before the `stop` has `detail.lost = father_gone`.
  If the `leftover` is above 0, the MU stayed with the node. This is the fault that the
  node `killed_with_mu` scores. The app only shows it.

The app treats a movement of a kind that it does not know as a charge that it did not
cause. It shows it and does not stop.

## 7. The tunnel to a descendant

`ServiceTunnel` takes `DescendantTunnel` at index 2 as its first message, in place of the
`TokenMessage` at index 1:

| Field | Meaning |
|---|---|
| `token` (1) | The token of the ancestor that the caller holds. It can be a stopped instance while the node keeps its row. |
| `instance_ref` (2) | The descendant. |
| `slot` (3) | The internal port, as a decimal number. |
| `receipts` (4) | True to get the checkpoints at index 2 of the answer. |
| `remaining_hops` (5, optional) | The hop budget. |

The node refuses an empty `token`, an empty `instance_ref` and an empty `slot`
(`INVALID_ARGUMENT`).

The errors of `DescendantTunnel` (`rpc_tunnel.py`, `gateway._tunnel_status`):

| Status | Texts of the node | Meaning |
|---|---|---|
| `PERMISSION_DENIED` | "No instance that this token may reach has that descendant." | No chain below the token links the descendant. |
| `RESOURCE_EXHAUSTED` | "The hop budget of this tunnel is used up."; "The instance has not enough balance to open a tunnel."; "A node below has no traffic allowance, balance or hop budget left." | The budget, the balance or the allowance is used up. |
| `UNAVAILABLE` | "The descendant is not alive."; "A node below did not open the tunnel."; "More than one node below gave a statement of that descendant." | The descendant does not answer or is not alive. |
| `PERMISSION_DENIED` | "More than one branch can hold that descendant. Read the statement of the descendant first." | The node cannot choose a peer. The app must not show "not linked". It tells the user to read the statement first. This costs MU, so the user must confirm it (rule 1). |
| `INVALID_ARGUMENT` | "DescendantTunnel carries no token.", "... no instance_ref.", "... no slot; the target port is required.", "A node below refused the tunnel." | The request is not correct, or a node below refused it. |

The relay can fail after the stream started. The node then stops the stream with the
status of the refusal. The app maps the status in the same way.

The tunnel costs MU as any tunnel: the opening fee and the traffic. The descendant pays on
its node, and each relay node charges its own leg. The user confirms the opening fee as for
a normal tunnel (`TUNNEL_OPEN_MU`, default 10 000 MU).

### 7.1 The receipts

A stream of a `DescendantTunnel` has a different execution name, because the caller holds
the `instance_ref` and not the token (`execution_receipt.execution_name_by_ref`):

    execution_name = blake2b-256 of UTF-8("celaut-execution-ref:" + instance_ref) || peer_id_raw

`peer_id_raw` is the 32 bytes of the public key, not its hex text. This is the name for a
token:

    execution_name = blake2b-256 of UTF-8(token) || peer_id_raw

The prefix keeps the two names apart. Each node signs only its own leg, with the
`instance_ref` that it got. The first node uses the `instance_ref` of the caller. The node
does not pass on the receipts of the next node. The `tunnel` rows of the ledger have the
same name in `detail.execution_name`. The call `problems(receipt, instance_ref=...)` of nodo
checks this kind.

## 8. The cost and the maximum MU

The node charges the caller for a statement: a fixed part and a part for each row that it
returns (`statement_price_mu`):

    price(rows) = statement_query_mu + statement_row_mu * rows

The defaults are 100 MU and 1 MU (`docs/PRICING.md`). An operator can change them. The
node advertises them in the `mu_per_call` of its `Peer`, as the rates `statement_query_mu`
and `statement_row_mu`.

- A read of a local descendant writes one `statement_query` movement on the account of the
  caller. The movement has `detail.rows`, `detail.from_seq` and `detail.to_seq`.
- With `from_seq` 0, the answer has no row. The price is `statement_query_mu`.
- One answer has at most `ledger.MAX_STATEMENT_ROWS` rows (default 1000).
- A read that goes to peers is paid, first, by the delegated instance that leads to the
  descendant. If that instance cannot pay, the caller pays one read for each such peer
  (`read_price_mu`: the fixed part and the part for the most rows that the read can
  return).
- A node asks at most `remaining_hops - 1` peers. The caller can pay at most
  `max(1, remaining_hops - 1)` reads (`descendant_read_counts`). With no
  `remaining_hops`, the node uses its own maximum (16 by default).

The app computes the maximum MU of a read in this way:

    rows       = to_seq - from_seq + 1   (if from_seq > 0 and to_seq >= from_seq)
                 else 0 if from_seq == 0, else the row limit that the app asked
    hops       = the remaining_hops that the app sends (always set by the app)
    reads      = max(1, hops - 1)
    max_mu     = reads * (statement_query_mu + statement_row_mu * rows)

The app always sets `remaining_hops`. It never leaves it absent, because the cost then
depends on a value that the node chooses. The default of the app is chosen by the phase
that makes the read.

The app does not know the rates of a node that gave no rates. Then it does not send the
read. The confirmation shows the maximum MU and the node. The user confirms each read.

An answer cannot charge more than the maximum. The account of the client on the node shows
the charge as a `statement_query` movement.

## 9. A node that does not know the fields

A node older than nodo#631 reads `BalanceStatementRequest` and ignores the field
`instance_ref` and the field `remaining_hops` (proto3 skips unknown fields). It does not
refuse. It answers with the statement of the account that `token` names, and it charges the
caller. Its answer has an empty `instance_ref`.

So the rule is:

- If the request has `instance_ref` and the answer has another `instance_ref`, or none, the
  app refuses the answer (`StatementInvalid` in nodo). The app shows "node does not support
  descendants". The read cost MU. The app tells the user that the node did charge.
- The app does this check before it reads the movements.
- The check of the signature also covers the `instance_ref`: a node cannot say later that
  the statement was for another account.

A node older than nodo#631 gets a `DescendantTunnel` at index 2 and refuses the stream. The
exact status was not read in the nodo code, because the bee-rpc layer of the old node does
the refusal (this was not verified). So the app uses this rule: if a stream with
`DescendantTunnel` fails before the first byte, with a status that is not one of the
statuses of section 7, or with an error of the framing, the app shows "node does not
support descendants". The statuses `PERMISSION_DENIED`, `RESOURCE_EXHAUSTED` and
`UNAVAILABLE` of section 7 keep their own meaning. A phase that has a node to test must
check this.

## 10. Test vectors

These values are for a test. They are not a real account. Each value is computed with a
script that follows the nodo code (see the note below). The values give the same bytes as
the rules of sections 3 to 5.

Tokens: `parent-token-1` (the ancestor) and `child-token-1` (the descendant).

    instance_ref("child-token-1") =
      407e5db0b61e39e7eeeef075270dbf0d1f60f8cb6f9a56493fca5a6f464cfa61
    account_ref("parent-token-1") =
      707f5710da5b6e024393aa806427f0331905f9fc894d205a365c0b79bf3fc481
    genesis hash of that account =
      4e3977840f3f19220cb66feb8cde682426b9a59759d5bf3f5136b8e9b712774a

Movements (`S` is `cdcd...cd`, 32 bytes of `cd`, as 64 hex characters):

| seq | ts | amount | balance_after | kind | instance_ref | detail |
|---|---|---|---|---|---|---|
| 1 | 1700000000 | -5000 | 995000 | child_start | none | `{"start_ref":"ab"}` |
| 2 | 1700000001 | 0 | 995000 | child_bound | the child | `{"service_id":"S","starts_seq":"1"}` |
| 3 | 1700000900 | -30 | 994970 | statement_query | none | `{"from_seq":"0","rows":"0","to_seq":"0"}` |
| 4 | 1700001000 | 0 | 994970 | stop | none | `{"leftover":"0","reason":"stopped"}` |

The hash of each movement:

    1 d8ea596e8c3a1c055558447ac715cf0561a698ee63e3e894fcaa542e468b7552
    2 8d3fa7af31d646e24ea3a56fe6cf3ac4b5f802cb6128851dba405771b9080716
    3 ae6ca76d104952b3005d25afbaa3e6a766b444137185d5786844d4be6cda7b1e
    4 d1826e9d6c4b19f8e535061e7e9f01351adcef405318f212d0dbcc2b7515ebbf

The statement has `from_seq` 1, `to_seq` 4, `ts` 1700001001, `retention_days` 0,
`oldest_seq` 1, `head_seq` 4, `head_hash` = the hash of movement 4, and `balance` 994970
(its hex is `393934393730`). The digests are:

| Optional fields | Digest |
|---|---|
| none | `1fe4d386b30d8a32a6728b8e838d0adbaf90c9a83b95543ac6f7b6815591ead4` |
| `service_id` = `S` and `instance_ref` = the child | `ba57e06097700132860ca253f405a2436a45642bbdae479cff2a8ecf8f258d30` |
| the two above and `relayed` | `2cc1dce4e4304f8902c3a2c03492ce357dcb77be34a184bca665f1dfc1b7f351` |
| only `relayed` | `33a235c568d0c346910a0e7044dea9733563e2ce561908eca84e90c3abddb9bb` |

The signature test uses an Ed25519 key with the seed `00 01 02 ... 1f` (bytes 0 to 31).
Its public key (the `peer_id`) is:

    03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8

The signed text, for the second row of the table, is:

    celaut-balance-statement:03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8|ba57e06097700132860ca253f405a2436a45642bbdae479cff2a8ecf8f258d30

The signature is:

    a7af781d441f40e2ef248a39958d7bd1c363c934c1dcb254350060a8850c0906c374dfa991e833cf7d44159b1ee7be0c1b982a0291d8bd46779bd68efc77de0d

The execution name for a `DescendantTunnel` with the child above and that `peer_id`:

    f4ddd19cef1fc8bc22992a1e64f3098c7499d3dcfa931b0c9de925d5a2243b91

Note on the method. The harness did not allow a run of the nodo Python code itself (it
needs modules that are not installed, and the run was refused). The vectors come from a
separate script of about 40 lines. It follows `ledger.py`, `balance_statement.py` and
`node_identity.py` line by line, and uses only `hashlib` and `cryptography`. The nodo code
was not run on these values. The next phase must run its Rust tests against these values
and, if a node is available, against a real statement of nodo.

## 11. The algorithm in short

Read:

1. Take `max_mu` from the caller and the user. Compute `max_mu_needed` (section 8). If it
   is more than `max_mu`, stop with an error and send nothing.
2. Send `BalanceStatementRequest{token, from_seq, to_seq, instance_ref, remaining_hops}`
   and `Client`, through the route of the app.
3. Refuse a status error with its meaning (`RESOURCE_EXHAUSTED`: cannot pay,
   `PERMISSION_DENIED`: not linked, `NOT_FOUND`, `UNIMPLEMENTED`: delegated instance).
4. Refuse the answer if `answer.instance_ref != instance_ref` (also if it is empty), if
   `from_seq` or `to_seq` is not the request, or if the signature does not verify with the
   `peer_id` of the connection.
5. Check the chain (section 5) and the head.
6. Show `relayed`, `service_id`, `child_bound` and `stop` movements.

Tunnel: send `DescendantTunnel` at index 2 as the first message, then bytes at index 0.
Name the receipts with `execution_name_by_ref`.

## 12. What the app does (final code)

Code: `celaut-wire/src/statement.rs`, `celaut-client/src/descendants.rs`,
`wallet-ffi/src/api/celaut_descendants.rs`, `app/lib/ui/celaut/descendants_section.dart`.

- The instance info page has a Descendants section. It reads the list from the database. It
  sends nothing when it opens.
- Check: the app makes a quote (it sends nothing), shows the maximum MU in a dialog, and
  reads one statement only after the user confirms. The user can change the budget. Cancel
  or a tap outside sends nothing. Each check asks again. There is no timer, no loop and no
  background read. A paged read is not followed by itself.
- The app limits are choices of the app, not of nodo: `remaining_hops` is 2 by default
  (the UI has no control for it) and 4 at most; `MAX_DEPTH` is 4; `MAX_PER_INSTANCE` is
  256 descendants.
- The statement of the held instance (depth 0) is read with an empty `instance_ref`, so
  it also works on an old node.
- A node that refuses a statement makes the descendant "not verifiable" and gives a
  finding. It is not an error. A `stop` movement with a leftover above 0 gives an alert.
- Open starts a tunnel only for a descendant that the last check found alive, and only for
  a web slot that the service declares. A chat slot of a descendant is not opened (the
  chat screen needs an instance). The tunnel costs the opening fee, with no extra dialog.
- Errors: `NoDescendants` ("node does not support descendants") is a separate error kind
  in the app.
- The Tor route is the route of the connection of the node (see [network.md](network.md)).
- Tests: Rust tests with the vectors of section 10; Dart widget tests with fakes. The test
  `read_the_statements_of_the_descendants` in `celaut-client/tests/real_node.rs` is for a
  real node. It is ignored, and it reads only if `CELAUT_DESCENDANTS_MAX_MU` is set. No
  real node was used for it. The vectors of section 10 were not compared with the Python
  of nodo (the module `mnemonic` was missing), and the refusal of an old node for
  `DescendantTunnel` is still a heuristic.
