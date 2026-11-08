# Execution receipts

A node signs **execution receipts** (nodo#419, `nodo:docs/EXECUTION_RECEIPTS.md`). A
receipt is evidence against the node that signed it. It is never evidence for the node.
The app checks each receipt when it comes. It keeps the receipt and lets the user export it.

## 1. What the node sends

| Kind | Where | What it signs |
|---|---|---|
| `start` | `ServiceInstance.receipt`, in the answer of `StartService` | the service, a salted digest of the environment variables, and the start amount (`initial_mu`) |
| `checkpoint` | `ServiceTunnel`, index 2 of the answer | the counters and two hash chains of the stream: the messages into the service (`in`) and out of it (`out`), and what the tunnel cost (`mu_charged`) |
| `close` | the same place, as the last receipt | the same fields. The stream stopped normally |

The node signs `celaut-execution-receipt:<peer_id>|<receipt_digest>` with its identity
key (Ed25519). The signature has one spelling: 128 lowercase hex characters. The app
refuses any other spelling. The file `rust/crates/celaut-wire/src/receipt.rs` has the
canonical text, the digests, the chains and the check. Its tests use the vectors of
`nodo:tests/identity/test_execution_receipt.py`. They give the same bytes.

## 2. The tunnel

- The client sets `TokenMessage.receipts` on each tunnel.
- The client accepts index 2 also when it did not ask. A bee-rpc reader refuses an index
  that it does not know. This lets the node send receipts to all callers.
- Each message that the client sends at index 0 is one event of the `in` chain.
- Each message that the client gets at index 0 is one event of the `out` chain.
- The client sends a payload in pieces of 64 KiB or less. Each piece is one message.
- The receipt must verify against the `peer_id` of the TLS connection and the token of
  the instance (`execution_name`).
- A tunnel to a descendant (`DescendantTunnel`) has no token of the instance. Its receipts
  name the execution by the `instance_ref` instead:
  `blake2b_256("celaut-execution-ref:" + instance_ref || peer_id_raw)`. See
  [descendants.md](descendants.md). Each node signs only its own leg.

### 2.1 The check of a checkpoint

At each checkpoint, the client finds the state of its own chain with the same count. It
compares the bytes and the head. There are three results:

- **Match.** The bytes and the head are the same.
- **Mismatch.** The count is known, but the bytes or the head are not the same. The node
  signed data that the phone did not send or did not receive.
- **Ahead.** The checkpoint counts more messages than the client has seen.

The node can count fewer `in` messages than the client sent. They can be still on the
way. So the client keeps the state after each message since the last checkpoint that
matched.

A checkpoint that is ahead is not a mismatch yet. It waits until the chains of the client
catch up with it. This applies to the `in` chain and to the `out` chain. A receipt never
passes the receipts that wait before it. The client gives the receipts in the order of the
stream.

When the stream ends, a checkpoint that is still ahead is a mismatch. The client then gives
all the receipts that wait.

### 2.2 The order of the stream

A receipt can be valid and signed, but it can break the order of the stream. These are
ordering faults:

- a receipt after the close;
- a `seq` that does not go up;
- a change of session.

An ordering fault is not a failed check. The app stores the receipt and shows the fault.
The app keeps the first close of a stream. A checkpoint with a lower `seq` does not
replace a checkpoint with a higher `seq`.

### 2.3 The end of a stream

- A stream that the phone cancels has no close. This is not a fault. The node cannot send
  after the cancel. The app shows "none (cancelled)", not an error.
- The node signs a checkpoint every 1 MiB or 5 s of traffic.
- After 65 536 messages with no checkpoint, the client stops the chain check of that
  stream. This is not a fault. The client still checks the signatures.
- If the app has no sink for the receipts, nobody reads them. The client then does not
  compute the chains.

## 3. The start

The app checks the start receipt against what it sent:

- The node of the connection signed it, for the token of the instance.
- `service_id` is the SHA3-256 id of the service that the phone started.
- `envs_digest` is `blake2b_256(envs_salt || canonical envs)`. It uses the variables that
  the phone sent and the salt of the receipt. It uses the last value of a name. It does
  not use `__nodo_instance_name`.
- The salt must be exactly 16 bytes. Nothing separates the salt from the text. A longer
  salt could hold the first variables and open the digest with fewer
  (`envs_match` of nodo).
- If the phone sent `Configuration.initial_mu`, the receipt has the same amount.

### 3.1 A missing start receipt

Some nodes give no receipts. This is not a fault. But if a node gave a start receipt for
an instance before, the app knows that this node gives receipts. The app then saves this
fact (`expects_start`). After that, a missing start receipt is a fault. The start shows
as failed (✗).

## 4. What the app keeps

The receipts are in the Celaut database (`CelautData.receipts`, by instance id). They go
when the instance is deleted. For each instance, the app keeps these items:

- the start receipt;
- the streams of the tunnels (see below);
- the bucket of the receipts that failed the check (see below).

For each tunnel stream, the app keeps these items:

- the count of the checkpoints;
- the last checkpoint or the close (the highest `seq` is what a dispute reads);
- the receipts with a fault (8 at most);
- the fact that the phone cancelled the stream.

### 4.1 The limit of streams and the eviction rule

The app keeps 64 streams at most. If it must drop a stream, it drops the oldest stream
with no fault. If all the streams have a fault, it drops the oldest of them. A stream with
a fault is evidence, so it stays as long as possible. The app counts the dropped streams.
The info page shows the count as **Tunnels dropped**.

### 4.2 The bucket of invalid receipts

A receipt can fail the check of the signature, the node, the token or the shape. The node
chose the session of such a receipt. So the receipt has no trusted stream. These receipts
go in one bucket for the instance. They do not take a stream slot. This stops a node from
pushing out good streams with many bad receipts.

- The bucket holds 16 receipts at most.
- The app also keeps the faults of these receipts, with no repeat, 16 at most.
- A receipt that the app cannot decode has no field. It gives a fault, but the app does
  not store it. It is not in the export.

### 4.3 The check of stored receipts

The chains cannot be checked again later, because the app does not keep the bytes. So the
app keeps what it found when the receipt came. The app checks the signature and the shape
of each stored receipt again each time it reads them. A stored receipt that changed shows
as a receipt that does not verify.

## 5. The info page

The info page of an instance has a **Receipts** part. It shows these items:

- the start (✓, ✗ or none);
- the count of the checkpoints;
- the close of each tunnel;
- the count of the dropped tunnels;
- each fault, in red.

The close of a tunnel has one of these values:

- ✓: the close is valid.
- "none (cancelled)": the phone ended the stream.
- "none": the stream ended with no close, and the phone did not end it. For example, the
  node stopped the instance and closed its tunnels.
- "open": the stream did not end yet.

A missing close is never shown as a fault.

The faults that the page can show are these:

- the node signed data that does not match what the phone sent or received;
- the node signed environment variables that the phone did not send;
- the node signed a different service or a different start amount;
- a receipt does not verify, or a receipt breaks the order of the stream (the page shows
  the reason of an ordering fault as the detail);
- the node gave no start receipt, but it gave one before.

**Export receipts** shares a JSON Lines file. The file has one receipt on each line, in
the proto3 JSON form. It has the stored receipts of the streams and the bucket of the
invalid receipts. This command checks the file:

    nodo receipt verify receipts-<id>.jsonl --peer <peer_id> [--token <token>]

The file has no token. The token opens the instance.
