# Wire protocol of the nodo Gateway (light client view)

A node also announces most of this at runtime in `Peer.uri[].protocol_stack` (layers
`tls`, `http2`, `grpc`, `bee-rpc`, `celaut-gateway`), from
`nodo:src/identity/transport_stack.py`. The per-RPC tables are in
`nodo:protos/gateway_bee.py`.

The `nodo:` line numbers are from nodo dev `e3d12301`. Section 4 (the deposit) was
checked against nodo dev `ee5af5bc` and names functions, not lines. The protos and `gateway_bee.py`
are the same as at `b5c1e8a5`, the commit that `celaut-proto` pins.

## 1. Transport

- **Port:** no fixed default. `network.GATEWAY_PORT: auto` picks a free port on the first
  start. Clients learn it from `Peer.uri[].port`.
- **TLS only for a remote client.** The TLS port binds `[::]`. The plaintext port
  (`GATEWAY_PORT + 1`) binds only the guest bridge or loopback (`nodo:src/serve.py:376-401`).
- **gRPC:** path `/celaut.Gateway/<Method>`, `application/grpc`, no custom metadata.
  Every method is `stream buffer.Buffer -> stream buffer.Buffer`. Errors are non-OK
  statuses with readable text.
- **TLS:** TLS 1.3, ALPN `h2`, SNI `celaut-node`, no client certificate. The server
  certificate is self-signed P-256 and changes when the node restarts.
- **Node identity in the certificate** (`nodo:src/identity/tls_identity.py`):
  - Extension OID `2.25.276125094420857322236898758448456352855`, not critical.
  - Its OCTET STRING contents are ASCII `"<pubkey_hex>:<sig_hex>"`.
  - `pubkey_hex` is the 64-character lowercase hex of an Ed25519 key. It is the
    **peer_id**. Reject a non-canonical spelling.
  - `sig_hex` is Ed25519 over UTF-8 `"CELAUT" + hex(DER SubjectPublicKeyInfo)`.
  - A Rust client verifies this in a custom rustls `ServerCertVerifier` and checks the
    TLS 1.3 handshake signature normally. That pins the certificate.

## 2. bee-rpc framing

`buffer.Buffer` (`nodo:protos/buffer.proto`): `chunk=1`, `separator=2`, `signal=3`,
`head=4 {index}`, `block=5`, `skip=6`. All are proto3 `optional`.

nodo pins bee-rpc-over-grpc-py **v0.0.2** (`nodo:bash/requirements.txt:15`). The
`bee_rpc:client.py` line numbers below are from v0.0.2.

**Send one object** (`bee_rpc:client.py:967-1156`, `serialize_to_buffer`):

- Bytes = the serialized message. Index 0 is always raw bytes.
- Fewer than 1 MiB: one `Buffer{chunk, head{index}, separator=true}`.
- 1 MiB or more: `Buffer{head{index}}`, then chunks of 1 MiB or less, then
  `Buffer{separator=true}`.
- A client sends its own messages inline. A client that relays a service (from
  `GetService` or a `.celaut.bee` file) sends its Buffers as they are, with their blocks
  (`docs/celaut/package.md`).

**Receive** (`bee_rpc:client.py:617-965`, `parse_from_buffer`):

- An object starts at a Buffer with `head`, `chunk` or `block`. It ends at
  `separator=true`, or at a Buffer with no `chunk`, no `head` and no `block`.
- `head.index` selects the type. With no head: index 1 if the table has it, else 0. An
  unknown index is an error.
- An object with 0 bytes is dropped, except when index 1 is `buffer.Empty`. So an
  all-default proto3 message never arrives. "Nothing received" can mean "all-default
  message".
- `signal=true` toggles "pause/resume sending". In StartService and
  GetServiceEstimatedCost the server sends a signal when it has the service ("stop
  uploading"), then its answer. GetServiceEstimatedCost then sends the resume;
  StartService does not. In both, the server reads the rest of the request to its end
  and drops it, so a client stops at the answer (`docs/celaut/package.md`).
- Blocks: `Buffer{block}` opens a block, the same hashes close it; they can nest and must
  not overlap. Block contents are chunks; concatenation gives the object. A receiver
  accepts up to 32 levels of nesting (`MAX_BLOCK_NESTING`, `bee_rpc:client.py:317`).
  A deeper block is an error.
- `skip` (receiver to sender) is optional. A client can ignore it. The app reads it in the
  calls that carry a service, and stops the blocks that it names (`docs/celaut/package.md`).
- A request ends when the client half-closes its side.

**Hash types** (`nodo:src/utils/hashing.py`): the type id is the digest of the empty
input. SHA3-256 = `a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a`.
The node registry uses SHA3-256.

## 3. RPCs

Auth "client" = `client_id` must exist on the node (rate limit 120 calls / 60 s per
client). Auth "token" = possession of an instance token.

| RPC | Request indices | Response indices | Auth |
|---|---|---|---|
| GenerateClient | 1 `Client` (optional) | 1 `Client` or 2 `PoWRequired` | none |
| GetPeerInfo | 1 `Client` | 1 `Peer` | client |
| GenerateDepositToken | 1 `Client` | 1 `TokenMessage` | client |
| Payable | 1 `Payment`, 2 `Client` | 1 `buffer.Empty` | client |
| GetServiceEstimatedCost | 1 Client, 2 RecursionGuard, 3 Configuration, 4 `Metadata.HashTag.Hash`, 5 Metadata, 6 Service | signal, then 1 `EstimatedCost` | client |
| StartService | same as above | signal, then 1 `ServiceInstance` (with the start receipt, [receipts.md](receipts.md)) | client |
| StopService | 1 `TokenMessage{instance token}`, 2 `Client` (the father) | 1 `Refund` | token+client |
| ModifyDeposit | 1 `ModifyDepositInput`, 2 `Client` (the father) | 1 `ModifyDepositOutput` | token+client |
| ModifyServiceSystemResources | 1 `ModifyServiceSystemResourcesInput` (with `service_token`), 2 `Client` (the father) | 1 `ModifyServiceSystemResourcesOutput` | token+client |
| GetMetrics | 1 `TokenMessage{instance token}` | 1 `Metrics` | token |
| GetClientMetrics | 1 `Client` | 1 `Metrics` (free) | client |
| GetResourceAvailability | 1 `ArchitectureResources`, 2 `Client` | 1 `ResourceAvailability` | client |
| GetService | 1 Hash, 2 Client (send Client first) | 4 Hash, 5 Metadata, 6 Service | client |
| ServiceTunnel | 1 `TokenMessage{token, slot, receipts}` or 2 `DescendantTunnel{token, instance_ref, slot, receipts, remaining_hops}`, then 0 bytes | 0 bytes, 2 `ExecutionReceipt` | token |
| GetBalanceStatement | 1 `BalanceStatementRequest`, 2 `Client` | 1 `BalanceStatement` | client |
| Observe | 1 `ObserveRequest{instance_id = instance token}` | 1 `ObserveEvent` (stream) | token |
| Chat | 1 `ChatMessage` | 1 `ChatAck` | peers only |

Notes:

- **GenerateClient** (`nodo:src/gateway/client_pow.py`): difficulty =
  `clients // 500`. With difficulty > 0, `client_id` must be 32 lowercase hex characters
  and the reply is `PoWRequired{challenge, difficulty}`. Retry with
  `Client{client_id, challenge, pow_solution}`. Proof of work: the hex of
  `blake2b-512(utf8(challenge) || utf8(solution))` must end with `difficulty` zeros. A
  new client gets free credit (`free_tier.CREDIT_MU_PER_NEW_CLIENT`, default 4 500 000 MU).
- **GetPeerInfo** needs a client, so call GenerateClient first. Verify the `Peer`
  before you use it (`nodo:protos/celaut.proto:722-731` and `:777-779`):
  - `public_key` is 64 lowercase hex characters and is equal to the peer_id of the TLS
    certificate.
  - `signature` is Ed25519 by `public_key` over UTF-8
    `"<public_key>|<ts>|<content_digest>"` (`nodo:src/identity/node_identity.py:651-660`).
  - `content_digest` is the lowercase hex of blake2b-256 over the canonical text of all
    the other fields of the Peer (`canonical_peer_content_digest`,
    `nodo:src/identity/node_identity.py:570-648`).
  - `signature_scheme` has one component that names Ed25519 as nodo defines it
    (`speaks_our_signature_scheme`, `nodo:src/identity/node_identity.py`). nodo checks
    this before the key.
  - `ts` (field 99) is more than the `ts` of the last Peer that the app accepted for the
    same `public_key`. A node serves the same signed Peer again for up to 60 seconds
    (`_SIGNED_PEER_TTL_S`, `nodo:src/gateway/utils.py`), so an equal `ts` with an equal
    content digest is the same message and the app accepts it.
  - The digest text is sorted by the text of each element. `benchmark` entries are sorted
    by their text, and a repeated key stays. The Rust port is in
    `rust/crates/celaut-client/src/peer.rs`, with vectors made by the nodo code.
- **StartService / GetServiceEstimatedCost** (`nodo:src/gateway/iterables/abstract_input_service_iterable.py`):
  send in this order: Client, `RecursionGuard{token: "", remaining_hops: 1}`,
  Configuration, then one Hash per hash type. Send Metadata and Service only if the
  node asks (no signal). The node starts the work on the message that makes the
  service known (a Hash or the Metadata when the node has the service, else the
  Service). Then it sends the signal, and after it the reply. It ignores a
  Configuration or a RecursionGuard that comes later (lines 93-106 and 157-194). For a
  quote, nodo sends only Client, Configuration and the hashes. StartService charges
  `EstimatedCost.cost` from the client balance. After the reply, half-close.
- **RecursionGuard:** `remaining_hops: 1` makes the node run the service itself. It
  does not delegate it. A light client must send it: a delegated instance has no path
  for a phone (see the next item).
- **ServiceInstance.instance.uri_slot[].uri** can be empty (no host ports). Then use
  ServiceTunnel. ServiceTunnel accepts only the token of an instance that runs on that
  node (`nodo:src/tunneling/rpc_tunnel.py:346-351`). For a delegated instance the node
  gives an alias token, and ServiceTunnel refuses it. A delegated instance is not
  reachable from the app.
- **Observe** takes the instance token in `ObserveRequest.instance_id`
  (`nodo:protos/gateway_bee.py:153-157`, `nodo:src/gateway/iterables/observe_iterable.py`).
- **ModifyServiceSystemResources** (`nodo:src/gateway/gateway.py`, `nodo:src/manager/hibernation.py`):
  hibernate and wake use this call. There is no other RPC. Send part 1 with `service_token`
  (the instance token) and `max_sysreq`, and part 2 with the `Client` of the father. The
  answer has the resources of the instance and its balance.
  - Hibernate: `max_sysreq.cpu_quota` or `mem_limit` is 0. The node sends the answer before
    the VM stops. The answer has 0 for CPU and RAM, so it does not give the old resources.
  - Wake: send `cpu_quota`, `cpu_period` and `mem_limit` together, all above 0. A field that
    is not set keeps the value of the node row, and a hibernated row holds 0 for all three.
    The answer gives the resources of the instance now. A wake that does not fit leaves the
    instance hibernated and refunds the call.
  - An empty `max_sysreq` with `service_token` changes nothing for a running instance and
    returns its real resources. The app uses it to read the resources just before it
    hibernates the instance. This is from the nodo source, and no live node confirmed it.
  - The instance pays the call fee (`modify_resources_mu`), not the caller. A call that the
    node refuses after the charge is refunded.
  - No RPC says that an instance is hibernated. `GetMetrics.suspended` is false for it.
  - The node refuses an instance with a shared filesystem, and an instance that it cannot
    start again from its own disk. A delegated instance (alias token) gets "no local
    instance with that token". A node older than `service_token` ignores the field.
  - A hibernated instance pays for its disk only. A top-up keeps it alive and does not
    wake it.
- **Chat** answers `stored=false, "client_id … is not associated with any peer"` to a
  light client (`nodo:src/manager/chat.py:164-184`).

## 4. Client lifecycle and Ergo deposit

1. TLS channel; the peer_id comes from the certificate.
2. `GenerateClient` → `client_id` (solve PoW if asked).
3. `GetPeerInfo` → `Peer.payment_contracts`. Take the first `ContractRate` with
   `contract.ledger.tags[0] == "ergo"`, xattr `token_id == "ERG"` and `mu_per_unit` more
   than 0 (the balancer takes the same one for the price). Xattr `script` is the
   ErgoTree of the node wallet (P2PK). Xattr `contract_type` is
   `proveDlog(decodePoint())`. `mu_per_unit` is MU per nanoERG, an integer (default 1,
   `ledgers.ergo.payments.MU_PER_NANOERG`).
   - `contract.ledger.formal` is the ledger declaration: `key=value` lines sorted by key
     (`component_formal`, `nodo:src/utils/ledger_descriptors.py`). Pay only if it has
     `chain=ergo` and `network=mainnet` (a node on another chain declares
     `network=genesis <id>`), and if `payment.deposit_token` starts with `R4`.
4. `GenerateDepositToken` (`Client` at 1) → `TokenMessage.token` at 1: the text of a
   UUID4 with hyphens (36 characters, `str(uuid.uuid4())`). The node only writes it in its
   database as `pending` for the client. Nothing goes on a ledger. It expires after
   3600 s (`DEPOSIT_TOKEN_TTL`). The node refuses new tokens if
   `client.ACCEPT_NEW_DEPOSITS` is false.
5. Ergo transaction: one output with `ergoTree = script`, value at least
   `amount_mu / mu_per_unit` nanoERG (minimum box value 1 000 000), and
   `R4 = Coll[Byte]` of the UTF-8 deposit token: in EIP-12 the register is the hex of
   `0e`, the length as VLQ (`24` for 36 bytes), and the bytes. The app sends exactly
   `nanoERG`, and `Payment.amount = nanoERG × mu_per_unit` MU: the node divides and
   rounds down, so it asks for that `nanoERG`.
6. **`Payable`** with `Payment{deposit_token, contract (echo it unchanged), amount=MU}`
   at 1 and `Client` at 2. The order does not matter: the node reads the whole request
   (`parse_with_client`, `nodo:src/gateway/client_gate.py`). An accepted payment gives
   an OK status and an empty answer (index 1 is `buffer.Empty`). A refused one gives an
   error status, "Error: payment not valid." (`Payable` in `nodo:src/gateway/gateway.py`,
   `validate_payment_process` in `nodo:src/payment_system/payment_process.py`, `_validate`
   in `nodo:src/payment_system/contracts/ergo/interface.py`). The node accepts the payment
   only if all of these are true:
   - The deposit token is `pending` (not expired, not used) and belongs to a client
     that exists.
   - `contract.ledger` is the same declaration as the ledger of the node
     (`same_declaration`), and the payment method is found by the ledger tag, the
     SHA3-256 of xattr `contract_type` and xattr `token_id`. A changed `Contract` fails,
     so send the one from GetPeerInfo without a change.
   - The address of `script` is the wallet address of the node.
   - The explorer of the node shows an unspent box with the deposit token in R4 and a
     value of at least the amount in nanoERG. The box needs no confirmation: it can be
     in the mempool. The node asks
     `{explorer}/api/v1/boxes/unspent/unconfirmed/byAddress/{address}` with no paging
     parameters. Its explorer is the default of Ergo AppKit for mainnet,
     `https://api.ergoplatform.com` (nodo builds `ErgoAppKit(node_url)` with no
     explorer URL). The answer is a JSON list of all the unspent boxes of the address:
     the endpoint ignores `offset` and `limit`. A node does not advertise its explorer,
     so the app uses this explorer too, fixed.
   - The node reads `additionalRegisters.R4.renderedValue` (the hex of the bytes of the
     `Coll[Byte]`, without the `0e` and the length), decodes it as UTF-8, and compares
     it with the token. It reads only the first box with the token. A box at the node
     address with an R4 that is not hex of UTF-8 text stops the check for every deposit
     while it comes first (celaut-project/nodo#541).

   **One attempt only:** the token becomes `payed` or `rejected`. Call it only after
   the box is visible on the explorer.

   Risks on the node side (nodo dev `ee5af5bc`): a box at the node address with an R4
   that is not hexadecimal UTF-8 text (for example an `SInt`, rendered as `1`) makes the
   check raise, and the node then refuses every deposit while that box is listed before
   the deposit box. And a node wallet with many boxes can depend on the paging of the
   explorer answer.
7. Balance: `GetClientMetrics(Client{client_id})`. It is free. `GetBalanceStatement` is not
   the way to read it: each statement costs MU and writes a `statement_query` movement on
   the account. The app never reads a statement by itself. Each read needs the
   confirmation of the user, with the maximum MU, and the API takes a `max_mu` budget. With
   `BalanceStatementRequest.instance_ref` and `remaining_hops`, the read is of a descendant
   of an instance that the app holds. The answer has `relayed`, `service_id` and
   `instance_ref`. The digest, the signature, the hash chain, the `child_bound` and `stop`
   movements, the cost and the checks are in [descendants.md](descendants.md). The `client_id`
   is the master secret: with it a caller can stop the instances of the client and move its
   funds. A node with no `GetClientMetrics` is not supported.
8. ServiceTunnel charges the instance: open fee 10 000 MU and 2 000 000 MU per GiB.
   StopService refunds the unused instance balance to the client.

## 5. ServiceTunnel bytes

- Request: `Buffer{head{1}, chunk=TokenMessage{token, slot="<internal port>", receipts=true}, separator}`,
  then each payload as `Buffer{head{0}, chunk, separator}` (`head.index=0` is required).
- Response: `Buffer{head{0}, chunk (64 KiB or less), separator}`.
- The node also sends the signed checkpoints of the execution receipt (nodo#419). Each is
  `Buffer{head{2}, chunk=ExecutionReceipt, separator}`.
- The client always asks for the receipts. It accepts index 2 also when it did not ask.
  See [receipts.md](receipts.md).
- TCP: message boundaries carry no meaning. UDP: one message = one datagram.
- To reach a descendant, send `DescendantTunnel` at index 2 in place of the `TokenMessage`
  at index 1: the token of an ancestor, the `instance_ref` of the descendant, the slot, the
  receipts flag and `remaining_hops`. The errors, the receipt naming and the answer of a
  node that does not know index 2 are in [descendants.md](descendants.md).
- Half-closing the request closes the write side of the TCP connection to the service.

## 6. Node address in a QR code

Josemi accepted this format on 2026-10-13. nodo itself has no QR format for a node
address. The app reads two forms. The text is trimmed first.

1. **URI:** `celaut://node?addr=<host>:<port>`
   - The scheme is `celaut` and the host is `node` (both case-insensitive).
   - `addr` comes exactly once. Its value is percent-decoded and must be `host:port` or
     `[ipv6]:port`, the same as in the address field. The port is required.
   - No user info, no port after `node`, no path other than `/`, and no fragment.
   - Other query parameters are ignored, so that a later version can add one (for
     example the expected peer_id) without breaking older apps.
   - Example: `celaut://node?addr=203.0.113.7:53460`.
2. **Bare address:** `host:port` or `[ipv6]:port`, with no scheme.

A third form is binary, not text: the peer invitation of nodo (`protos/invite.proto`). The
app tells it apart by its first bytes and reads it as [invite.md](invite.md) says.

Any other text is not a node address (for example an Ergo address, an ErgoPay link or
a web link). The app shows the same error as for a bad typed address and stores
nothing.

A scanned address then goes through the same check as a typed address:
`celaut_add_node` connects to the node and checks its identity (section 1) before
anything is stored. A node that does not answer or fails the check gives the same
error as a typed address.
