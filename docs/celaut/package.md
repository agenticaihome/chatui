# Give a service to a node that does not have it

A node runs only the services that it has. A node that does not have a service
refuses a quote or a start with "This node does not have the service X, and the request
does not contain it". The request can contain it: `StartService` and
`GetServiceEstimatedCost` take the service in their indices 4 (hashes), 5 (Metadata) and
6 (Service, with its blocks). This note says how the app does it.

## The library: load a service file once

The user can load a `.celaut.bee` file into the app at any time, with **Import a service
file** in the section "Run a service" of the home screen (the system file picker; any
type, because the file has no MIME type of its own). The picker gives the file at once,
with its name and size, and the card of the import shows before the app reads a byte. The
app then:

1. **reads** it: Android copies the file with a stream into `<private dir>/packages/incoming`
   (not the cache: Android clears the cache when the storage is low, also in the middle of
   a copy of 1.45 GB), and tells the bytes copied (`copied` on the channel `org.celaut.chatui/package`). The card says
   "Reading the service file…" with these bytes; Cancel stops the copy and deletes it. A
   file that the app cannot read is refused with the reason;
2. checks it: the file must be a package of a service, with a Service part, and it must say
   which service it is, in its Metadata or in a hash part. The app does not hash a whole
   service on the phone, so a file with no id is refused, with that reason. It hashes each
   block (SHA3-256, with the blocks inside it) and refuses a file with a block that does
   not hash to its id, or that is cut inside a block: a node refuses that block, but only
   after the whole file was sent to it. While it checks, a card with the rocket (the one of
   a launch, lying on its pad) shows the bytes read of the size of the file, and the pad
   raises the rocket from horizontal to vertical as they grow (`RaiseStage`): the read is the
   first half of the rise, and the check is the second half. Cancel stops the check and
   leaves the chosen file where it was; the copy of the app is deleted, as is the copy of
   a file that the check refuses. The count is `celaut_transfer_progress` (stage
   `checking`);
3. **moves** it (the copy is on the same disk) to
   `<private dir>/packages/library/<service id>.bee`, through a partial file that is
   renamed when it is complete, so the library never holds a cut file;
4. records it in the Celaut database (`packages`: name, size, time, layout). The name is
   the name of the file without `.celaut.bee`. Loading the same service again replaces it.

"Your services" lists the loaded files with Run and Remove. Run launches the service by
its id, like a service of the catalog. If no node has it, the failure sheet offers to send
**the loaded file** to the first node that lacks it, with no file to pick; the file stays
in the library after the send. Remove deletes the file and the record; the nodes that
have the service keep it. A record whose file was deleted shows "The file is gone" and
cannot run until the file is loaded again.

Only a copy that the app made for one transfer is deleted after it: the service that it
fetched from another node (`celaut_fetch_service`).

## Where the app gets a service

1. **A node that has it.** `GetService` gives the indices 4, 5 and 6, the same as
   `StartService`, so the answer can go to another node as it is. A node that has the
   service is one that gave a quote, or one that refused for another reason (closed,
   no room, no credit). `GetService` needs a client id on that node.
2. **A `.celaut.bee` file** that `nodo export` wrote. It has the Metadata at index 1 and
   the Service at index 2; the app gives them the indices 5 and 6.

The skill catalog does not give a source for a package today (`docs/celaut/catalog.md`).

## How it moves

- The app keeps the service in a `.bee` file in its private storage (`packages/`), and
  reads it while it sends it. A service is never in memory: the Buffers go from the
  answer of one node, or from the file, to the next node as they are, with their blocks.
- The app gives the service with a **quote** (`GetServiceEstimatedCost`): the node
  stores the service, then answers with the price. After that the node has it, and the
  launch works as usual, with the hash only. A node can store the service and still
  refuse the quote, for example for an architecture that it does not run.
- A transfer that fails or that the user cancels must not leave half a service on the
  node: nodo does not check the hash of a service when it stores it, and at a clean end
  of a request it takes a cut message for a complete one. So the app sends **cancel
  markers** before it ends the request (bee-rpc 0.2: block A opens, block B opens, block A
  closes). nodo refuses them with `IntersectionError`, and does not store the service.

## A node that already has the service

The app sends the hash of the service first (index 4), before the Metadata and the
Service. nodo looks for the hash in its registry as soon as it reads it
(`abstract_input_service_iterable.py`, `__pattern_matching`). If it has the service, it
answers at once: a signal (stop sending), the answer, and for a quote a second signal
(send again). Then it reads the rest of the request to its end and drops it. nodo's own
client takes the first answer and drops the call (`BeeClient.call_one`).

The app does the same (`celaut_wire::relay`):

- After the head (Client, guard, Configuration, Hash), it waits at most 2 seconds
  (`EARLY_ANSWER_WAIT`) for the first Buffer of the node. A node that has the service
  answers in about one round trip. A node that does not have it answers nothing until the
  end of the request, so the wait only delays the start of the Service.
- It sends the Service while it reads the answer. It stops when an answer comes before
  the end of the Service: it sends no more Buffers and resets the request (HTTP/2
  `RST_STREAM`). A reset is not a clean end, so the node cannot take the cut Service for
  a complete one. The early answer comes only for a service that the node already had
  when it read the hash, so nothing is stored from this call.
- A node that does not have the service gets all of it, and a clean end, as before.
- A cancel or a file error still sends the cancel markers, then a clean end.
- `StartService` of nodo sends no second signal. A client that waits for the signal
  before it sends more would wait to its time limit; this call stops at the answer.

So a node that has the service (a retry, a second transfer, or a node that got it from
another client meanwhile) gets almost no Service bytes. The app counts the Buffers that
it gives to the call (`SendCounter`), logs them after each send
(`celaut_send_service`), and the progress of the transfer shows them.

### Blocks that the node already has

A node can lack the service and still hold some of its blocks, when another service has
the same files (blocks are SHA3-256 of their content; nodo makes a block of each file of
32 KiB or more). bee-rpc lets a receiver ask the sender to skip such a block
(`StreamControl`, `Buffer.skip`): a Buffer with `skip` and an empty chunk, in the answer
direction. The sender stops the body of the block and still sends its end marker.

- A nodo before celaut-project/nodo#584 does not ask. `abstract_input_service_iterable.py`
  parses the request with no `control`, so it reads a block that it holds from the wire and
  drops it (bee_rpc `save_chunks_to_block`). It uses `StreamControl` only in `GetService`,
  where the node sends.
- A nodo with #584 parses the request with a `StreamControl` and sends the skip requests
  while it reads the Service. This is the same for `StartService` and
  `GetServiceEstimatedCost`.
- The app is the sender, so it reads the requests (`celaut_wire::Skips`, in
  `relay::call_with_service`) and the stream of the service, wrapped with `Skips::wrap`,
  drops the body of the blocks that the node asked for. The check is made for each Buffer, so
  a request that comes in the middle of a block stops the rest of it. The Buffers that were
  already on the way arrive too, so a block of a few KiB is sent whole.
- There is no capability flag: the app always wraps. A node that does not send a skip
  request (an older nodo) gets the whole service, as before.
- The app does not use the `block_skip` option of bee-rpc. It keeps the request open after
  its input, for a receiver that has skip requests to send; nodo reads the request to its
  end before it ends its answer, so such a call waits to its time limit. The app only reads
  the answer while it sends, and its request ends when the service ends.
- `SendCounter` counts after the wrap, so it is what left the app. The progress of the
  transfer counts a record when the call takes it from the file, and the file is read
  whole, so the bar reaches its end also when blocks are skipped.

### Measured

Live node (nodo `ec1274d8`, the same WSL host, loopback), 2026-10-23, with
`celaut-client/tests/real_node_transfer.rs`. Bytes are the encoded Buffers of the
Service part that the app gave to the call. "Before" is the call of the app before this
change (`Transport::call_buffers`); "after" is `NodeSession::quote_with_service`.

| Service | The node | Before | After |
|---|---|---|---|
| echo-chat v1 `653cdd`, 122.7 MB, 631 blocks | has it | 122 677 814 B (all), 0.9 s | 0 B, 0.02 to 0.1 s |
| `2e0a23` (snake-challenge), 1.05 GB, 11 blocks | lacks it; holds 1 of the blocks | not measured (the first send stores it) | 1 051 165 779 B (all), 41 s; stored |
| `2e0a23` again | has it now | 1 051 165 779 B (all), 19 s | 0 B, 0.02 s |

With no wait after the head (`call_with_service` with a wait of zero), echo-chat sent
763 309 B (9 Buffers) before the answer stopped it, on loopback. All quotes were
answered, and the node logged no error for the reset calls.

For `2e0a23` the node already held 11 630 366 bytes (1.1 %): one of its 11 blocks was
already in the block directory of the node. They were sent again, and nodo dropped them.
That is the saving that a skip of held blocks gives for this service, on a node that runs
nodo#584 (this measure is of a node before it). The services
of the celaut-basics releases before echo-chat have one block for the whole filesystem,
so they share no block with the services of the node.

The skip is tested only against an in-process node that sends it
(`celaut-wire/tests/early_answer.rs`, `a_block_that_the_node_holds_stops_when_it_asks`: a block
of 64 MiB, and the node reads less than half of it). It is not measured on a live node: the
one above runs nodo before #584.

## The screens

When a launch from the home screen fails and some node says that it does not have the
service, the failure sheet has a section "The service is not on these nodes", with one
button (`app/lib/celaut/service_transfer.dart` decides which):

- **Send it from A to B**, when a node of the list has the service. A node has it if it
  gave a quote, or if it refused for a reason that nodo gives only for a service that it
  has (closed, no room, no credit, rate limit, launch failed, network policy,
  architecture). A node that did not answer says nothing.
- **Choose a .celaut.bee file and send it to B**, when no node of the list has it. The
  Android file picker copies the file into a private folder of the app with a stream
  (`PackageHandler.kt`). A file of another service, or with no Service part, is refused
  before anything is sent.

B is the first node that said that it lacks the service. Before the transfer, a
confirmation says that the whole service goes through the phone and can be large, and on
a metered network it warns about mobile data. A dialog shows the bytes (and the percent
when the size is known) and has Cancel. When the node has the service, the launch runs
again, so the balancer sees that node. A failed or cancelled transfer, or a refusal of
the quote by the node (it stored the service but cannot run it), is shown with its
reason, and the launch does not run again.

## The Bee-RPC part

bee-rpc-over-grpc-rs 0.2 has two calls for a relay (`grpc::call_buffers`,
`grpc::call_raw`) and the cancel markers. 0.2.1 makes the error of the input come first
when the node refuses the markers before its first answer, as nodo does.

## Code

| Where | What |
|---|---|
| `rust/crates/celaut-wire` | `Transport::call_buffers`, `call_with_service` and `call_raw`; `relay::call_with_service` (stops when the node answers first); `SendCounter`; `gateway::get_service_raw` and `get_service_estimated_cost_with_service`; `WireError::Relay` |
| `rust/crates/celaut-client/src/package.rs` | Save the answer of `GetService` to a `.bee` file, inspect a file (layout, service id), read it for a node, cancel, and load a file into the library (`import`) |
| `rust/crates/wallet-ffi/src/api/celaut_package.rs` | `celaut_fetch_service`, `celaut_inspect_package`, `celaut_send_service`, `celaut_transfer_progress`, `celaut_cancel_transfer`; the library: `celaut_import_package`, `celaut_packages`, `celaut_remove_package` |

## Checks

- `celaut-client/tests/package.rs`: save, inspect, read with the indices of a node, a
  `nodo export` file, a node that does not have the service, an error and a cancel that
  leave no file, a cut file, files that are not packages.
- `celaut-wire/tests/relay_calls.rs`: what the node gets, in order.
- `celaut-wire/tests/early_answer.rs`, against an in-process gRPC server that answers as
  nodo does: a node that lacks the service gets all of it and a clean end; a node that
  has it answers after the hash, gets no Service Buffer, and sees a reset; with no wait,
  the Service stops when the answer comes; a cancel sends the markers and the node
  refuses; a refusal after the hash stops the Service.
- `celaut-client/tests/real_node_transfer.rs` (ignored; needs a real node and a
  package): the bytes of the table above.
- `celaut-client/tests/nodo_service.rs` (ignored; needs nodo, see its header), against two
  real nodo Gateways (nodo master `5649c2c`, bee_rpc v0.0.2), on 2026-10-15:
  - the app gives a service of 3 MiB to node A with a quote, and A stores it;
  - `GetService` of A gives it back (3 145 981 bytes);
  - a transfer from that file to node B that is cut in the middle of the Service is
    refused, and B does not keep it;
  - the whole transfer from the file makes B store it, and `GetService` of B gives the
    same bytes;
  - a first transfer cut in the Service is not stored.
  The quotes themselves were refused (the test service declares no architecture, and the
  test Gateway has no manager): the transfer works, the price is the business of the node.
- Services with blocks went to the live node on 2026-10-23 ("Measured", above).
- Not checked: a phone, mobile data, and Tor (a longer round trip than the wait after the
  head lets more of the Service go before the answer).
