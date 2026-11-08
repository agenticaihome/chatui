# Celaut client plan

This plan puts the Celaut part of chatui into milestones. The design is in the notes
in `docs/celaut/` (decisions, ui, wire, balancer, catalog). This plan follows those
decisions and does not change them. Each milestone ends with a check that a reviewer
can run.

## 0. Final status

Final status on 2026-10-21: master at `2584cf7` (release 0.1.8, 2026-10-16), the PR
that closes the plan (#43), and the chat-first UI on top of it. **The plan is complete.**

| Item | Status |
|---|---|
| M0: build from source, CI, debug APK in CI | Done (PR #1). CI runs rust, flutter and android on each pull request |
| `celaut-proto` and the design notes (`docs/celaut/`) | Done (merged from `celaut-crates` in `160d24c`) |
| M0b: trimmed wallet and new identity | Done (PR #3). English and Spanish (PR #12) |
| `bee-rpc-over-grpc-rs` (M1a) | Done. Tag `v0.1.0` (`a832abc`), a git dependency of `celaut-wire`. GPL-3.0-only, as chatui (section 7, decision 10) |
| M1: connect to a node and show its advertisement | Done (PR #9) |
| M2: quote, start, tunnel, stop on free credit | Done (PR #11). Checked on our own node from the client crate and from the app in the emulator (M2 in section 5). A phone, a node on the internet and more than one node: section 0.1 |
| M3: deposit with the wallet | Done (PR #13, #15). The wallet of the app pays; the deposit asks for its PIN or fingerprint. One deposit of 0.01 ERG on mainnet from the app in the emulator to our node on 2026-10-13: the node accepted it and the client got 10 000 000 MU (`docs/celaut/deposit-e2e.md`) |
| Home screen (ui.md, section 2) | Done (PR #15, #16, #31, #38). Running instances, "Run a service" and one card of state (decision of 2026-10-16). The Nodes screen adds a node by address or QR code (`docs/celaut/wire.md`, section 6) |
| One wallet (ui.md, section 1) | Done (PR #40, #41). The app holds one Ergo wallet with its seed. There are no watch-only wallets, no offline signing and no default payer. At each start the app removes the watched wallets and every wallet after the first of the user order, with its seed |
| M4: conversation screen | Done (PR #17 to #25, and the closing PR). Checked on 2026-10-21 on our node with `echo-chat` v1 from the app in the emulator: launch, conversation, history after a lost connection, cost so far, stop (M4 in section 5). A phone: section 0.1 |
| Run by skill, availability of the nodes, reasons of a refusal | Done (PR #30, #31, #32, #35, #36, #37, and the closing PR). Run asks first, with the best node and its start cost; the screen lists every skill of the catalog. Checked in the emulator on 2026-10-21. A phone: section 0.1 |
| Descendants of nodo#631 | Done in code (statements with `instance_ref`, `child_bound` and `stop`, `DescendantTunnel`, a confirmation for each paid read). Not checked on a real node: `docs/celaut/descendants.md`, section 12 |
| M5: privacy (Tor) | Done (PR #29, and the closing PR). Off by default, Arti inside the app, or an external SOCKS5 proxy, for the nodes, every HTTP request of the Rust core and the updater of the app (`docs/celaut/network.md`). Checked in the emulator on 2026-10-21 (M5 in section 5). A phone and onion addresses: section 0.1 |
| Open questions (section 7) | Answered on 2026-10-11 to 2026-10-16 |
| Chat-first UI (`docs/celaut/ui-chat-first.md`) | Done (PR #44, stacked on #43). A bottom bar with Chats, Wallet, Compute and Settings; the Wallet tab has the deposit, the Compute tab the nodes, the services and the other instances, the Settings tab the network, Developer and About. A row opens its conversation again; a stopped row stays until the user deletes it. Josemi's answers of 2026-10-21 are in section 4 of the note. Checked in the emulator on 2026-10-21 with `echo-chat` v1. The changed decisions (section 5 of the note) wait for Josemi |

### 0.1 Open after the plan

These items need a device, a second node or nodo work. They are not part of this plan.

| Item | Who |
|---|---|
| Check the app on a phone (GrapheneOS, no Play Services): a conversation with `echo-chat`, the foreground service with the screen off, Tor inside the app, the QR scan | Josemi or Nate, with a phone |
| A node on the internet, and a list of more than one node (the choice of the balancer, the nodes left out of a launch) | Josemi or Nate, with a second node that has a public address |
| Onion addresses for nodes. Through Tor, the app cannot reach a node in a private network (`10.0.2.2`, `192.168.x.x`) | nodo work (decision 7 in section 7) |
| Error codes in the answers of nodo, so that the app does not classify the texts | nodo work |
| A tunnel stream to a stopped instance stays open on the node while the client keeps the TCP connection (seen in `nodo tunnels --inbound` after a phone lost its network) | nodo work |
| `GET /chat/messages?from=²` (a digit that is not ASCII) closes the connection instead of status 400 | `echo-chat` in celaut-basics |

Checks of the closing PR, on 2026-10-21, on Ubuntu 22.04 x86_64 (WSL2 with KVM), Rust
1.99.0, Flutter 3.41.2, NDK 28.2.13676358:

| Check | Result |
|---|---|
| `cargo test --workspace` | pass: 649 passed, 0 failed, 15 ignored |
| `flutter analyze` | no issues |
| `flutter test` | pass: 1389 passed, 2 skipped |
| `flutter_rust_bridge_codegen generate` and `flutter gen-l10n` | no diff |
| `flutter build apk --debug` | pass; the APK has `libwallet_ffi.so` for arm64-v8a and x86_64 |

## 1. Goal

An Android app that uses Celaut services with no intermediary:

1. Find nodes (on-chain directory, or an address or QR code from the user).
2. Find services (celaut-project/skills catalog, or a service hash).
3. Get quotes from the nodes, select one with the balancer, and launch the service.
4. Pay the node from the wallet of the app (one deposit and one client id per node).
5. Use the service through `ServiceTunnel`, for example in a conversation screen.

## 2. Non-goals

- Run services on the phone. Android has no KVM for guests, and nodo needs
  cloud-hypervisor or QEMU on Linux. The app is a client, never a peer
  (it never calls `IntroducePeer`).
- Pack services on the phone. Upload of a package that already exists is in scope
  later; the build of a package is not.
- Operator features of nodo (peer chat, reputation submits for the node,
  configuration of a node).
- iOS and desktop builds.
- Escrow or trustless payment. A deposit is a plain payment to the key of the node.
  The risk is limited by the amount (see section 6).

## 3. What the app can do on a phone

| Topic | Fact | Effect |
|---|---|---|
| Network | The app only opens outbound TLS connections to the Gateway port | NAT and carrier-grade NAT are not a problem. No inbound port is necessary |
| Instance access | `uri_slot` is often empty; `ServiceTunnel` goes through the node | All service traffic goes through the node and is charged to the instance |
| Background | Android stops background sockets and processes | A long tunnel needs a foreground service. Instances continue on the node; the app keeps their tokens and stops them |
| Storage | Instance tokens and client ids are bearer secrets | Keep them encrypted, as the seed is today |
| Size | The native library is 32 MB per ABI now | Removing the DeFi crates (decisions.md) makes it smaller. Tor (section 6) makes it larger |

## 4. Architecture

```
Flutter UI (app/lib/celaut/...)
  │  flutter_rust_bridge (wallet-ffi, new module api_celaut)
  ▼
celaut-client   connect, client ids, quotes, start/stop, deposits, tunnels
  ├─ celaut-wire      TLS identity check, gRPC; uses bee-rpc (external crate)
  │    └─ celaut-proto    prost types (exists on celaut-crates)
  ├─ celaut-balancer  port of the nodo execution balancer (balancer.md)
  ├─ celaut-catalog   node directory and skills catalog from the explorer (catalog.md)
  └─ wallet-core / ergo-tx   deposit transaction (needs an R4 register on one output)
```

Crates to add in `rust/crates/`:

| Crate | Content | Dependencies |
|---|---|---|
| `celaut-proto` | Gateway types. Exists on `celaut-crates` | prost 0.14 |
| `celaut-wire` | rustls `ServerCertVerifier` that checks the identity extension (wire.md section 1) and returns the peer_id; the Celaut calls on top of the `bee-rpc` crate (repo `bee-rpc-over-grpc-rs`: framing, blocks, signal, generic bidi call; wire.md section 2). Not ported in this repo | tonic 0.14 (no generated stubs, because each method is `stream Buffer -> stream Buffer`), tokio-rustls, rustls 0.23 with ring (already in the workspace) |
| `celaut-client` | Typed RPCs, PoW of GenerateClient (blake2b-512), a store for client ids and instance tokens per peer_id, a quote cache, a local TCP listener on 127.0.0.1 that sends each connection through `ServiceTunnel` | celaut-wire, blake2 |
| `celaut-balancer` | Filter, score, MU conversion, event log (balancer.md) | celaut-proto |
| `celaut-catalog` | Explorer queries for node boxes and skills; ranking (catalog.md) | wallet-net (explorer HTTP) |

The FRB surface stays small and uses plain types:

```
celaut_add_node(uri) -> NodeInfo { peer_id, uris, rates, payment_methods, resources }
celaut_quotes(service_hash, config) -> Vec<Quote>        // balancer output, best first
celaut_start(peer_id, service_hash, config) -> Instance  // token stays in Rust
celaut_stop(instance_id) -> Refund
celaut_open_tunnel(instance_id, slot) -> u16             // local port for Dart HTTP
celaut_deposit_prepare(peer_id, amount_mu) -> unsigned tx for the existing sign screen
celaut_deposit_notify(peer_id, deposit_id) -> Balance
celaut_events() -> Stream<CelautEvent>                   // FRB StreamSink
```

A local port lets the Dart side use a normal HTTP client (or a WebView) for a service,
and keeps the gRPC and bee-rpc code in Rust.

## 5. Milestones

Each milestone is one or more PRs into master. Feature code waits for the review of
this plan.

**M0: build is green** (done, PR #1). The Gradle build makes `libwallet_ffi.so` from
source. CI runs on master and builds the debug APK. Check: the CI `android` job.

**M0b: trimmed wallet and new identity** (decisions.md). Remove the DeFi crates and
screens, the dApp browser, the CoinGecko prices and the app fee. Label "Celaut",
applicationId `org.celaut.chatui`, flutter_zxing scanner, updater on the
celaut-project/chatui releases. Check: the APK runs on GrapheneOS without Play
Services; `flutter test` and `cargo test` pass.

Start M0b from master. A partial trim exists on the machine of Josemi, but it will
not be pushed. Do not wait for it.

The items of M0b, as master had them at `160d24c` (all done in PR #3; Spanish in PR #12):

- `namespace` and `applicationId` are `com.argus.argus_wallet`
  (`app/android/app/build.gradle.kts`). Change both to `org.celaut.chatui`, and move
  `MainActivity` to the new package.
- `android:label` is "Argus" (`app/android/app/src/main/AndroidManifest.xml`).
- The updater reads `arkadianet/Argus` (`app/lib/build_info.dart`,
  `app/lib/services/update_service.dart`).
- `mobile_scanner` is still used in `app/lib/ui/scan_screen.dart`. Replace it with
  `flutter_zxing`.
- CoinGecko is still used in `app/lib/ui/home/erg_price_feed.dart`,
  `home_models.dart` and `settings/display_settings_page.dart`. Use only the oracle
  pool price.
- The app fee is still in `rust/crates/vendor/ergo-tx/src/dev_fee.rs` and its callers
  (`send.rs`, `tx_helpers.rs`, `utxo_management.rs`, `wallet-ffi/src/api.rs`,
  `api_ergopay_impl.rs`). Remove it, and remove the tests that expect a fee output.
- Spanish: decisions.md asks for English and Spanish. The app has no localization
  now (no `flutter_localizations`, no ARB files). Add it in a separate PR after M0b,
  before M1 adds new screens.

Also check that `scripts/release_check.sh` and the CI APK check still pass with the
new applicationId.

**M1a: bee-rpc in Rust** (repo `bee-rpc-over-grpc-rs`). Steps 2 to 7 of its
`PORTING.md`, one PR per step. An AI agent can do them: give it `PROMPT.md`; its
rules are in `AGENT_GUIDE.md`. Check: the tests of each step pass in CI (vectors
generated from the Python v0.0.2 reference), and the interop tests with a Python
peer pass.

**M1: connect to a node and show its advertisement.** Uses the `bee-rpc` crate (git
dependency on the tag `v0.1.0`, then a release). `celaut-wire` and the first part of
`celaut-client`: TLS with the identity check, GenerateClient (with PoW), GetPeerInfo.
Verify the `Peer` signature: Ed25519 over `"<public_key>|<ts>|<content_digest>"`
(`nodo:protos/celaut.proto:725-731`, digest in `nodo:src/identity/node_identity.py`),
`public_key` equal to the peer_id of the certificate, and `ts` not older than the last
one seen. A debug screen (Settings, Developer): enter `host:port`, show peer_id, URIs,
rates, payment contracts and resources. Check: an integration test against a nodo that
we run ourselves (M1 starts no service, so a node without KVM is enough if its Gateway
starts); unit tests with fixed bee-rpc streams and a fixed certificate.

Done in M1:

- `celaut-wire`: the identity check (`IdentityVerifier`, a rustls `ServerCertVerifier`;
  TLS 1.3 only, ring, no aws-lc), a tonic channel on it, the `Transport` trait, and
  the typed calls `generate_client` and `get_peer_info`.
- `celaut-client`: the proof of work, the port of `canonical_peer_content_digest`, the
  check of the `Peer`, and a store of the last advertisement per peer_id (memory or one
  JSON file). It keeps no client id: M1 uses it for one call and drops it. (Since M3 the
  app keeps the client id and the advertisement of each node in its Celaut database.)
- FFI: `celaut_peer_info(host, port, expected_peer_id, store_path)`. The debug screen
  passes no `store_path` yet, because the app has no data directory (`path_provider`
  is not a dependency), so the app keeps the last `ts` values in memory.
- Tests: known-answer vectors made with the nodo Python code
  (`celaut-client/tests/vectors/generate.py`), certificates made with it
  (`celaut-wire/tests/data/make_certs.py`), and a test that runs the real `Gateway()` of
  nodo (`celaut-client/tests/nodo.rs`, `#[ignore]`, with instructions at the top of the
  file). That test needs no root and no KVM: `nodo_gateway.py` serves the Gateway on a
  local TLS port without firewall, manager or services.

Facts from nodo dev `e3d12301` that differ from the first notes:

- A node serves the same signed `Peer` again for up to 60 seconds
  (`_SIGNED_PEER_TTL_S`, `nodo:src/gateway/utils.py`), so a second `GetPeerInfo` gives
  the same `ts`. The client accepts an equal `ts` when the content digest is also equal
  (the same message), and refuses an older `ts`, or an equal `ts` with another digest.
- The node checks `Peer.signature_scheme` before the key (`speaks_our_signature_scheme`).
  The client does the same: one component that names Ed25519 as nodo defines it.
- The digest covers the expiry and the transport of each URI, the reputation proofs,
  the scheme and every resource field with its presence. `benchmark` is sorted by the
  text of each entry, and a repeated key stays (it is not "sorted by key").
- GenerateClient: the client proposes a random UUID4 as `client_id`. With a proof of
  work the node uses the id in the challenge, and the difficulty in the challenge
  (the third field), not `PoWRequired.difficulty`. The client refuses a difficulty
  above 6 (about 16 million hashes); nodo accepts up to 64.

**M2: quote, start a service and call it through a tunnel, with no payment.**
GetServiceEstimatedCost on each known node, the balancer, StartService, StopService,
GetMetrics, ServiceTunnel with the local port. Two rules from nodo dev:

- Send Client, RecursionGuard and Configuration before the Hash. The node starts the
  work on the message that makes the service known, and ignores a later Configuration
  (`nodo:src/gateway/iterables/abstract_input_service_iterable.py:96-106`).
- Send `RecursionGuard{token: "", remaining_hops: 1}`. The node then runs the service
  itself and does not delegate it. A delegated instance has no path for a phone:
  ServiceTunnel accepts only tokens of local instances
  (`nodo:src/tunneling/rpc_tunnel.py:346-351`), and the node gives an alias token
  for a delegated one (decision 4 in section 7).

Each TCP connection through the local port is one ServiceTunnel stream and pays
`TUNNEL_OPEN_MU`, so the Dart side keeps HTTP connections alive.

A new client gets free credit (`free_tier.CREDIT_MU_PER_NEW_CLIENT`, default
4 500 000 MU). `pricing.BUILD_MU` (10 000 000 MU) is more than that, so the service
must already be built on the node, or the test node gives more credit. Check: on our
own node (x86_64 with KVM), start a small HTTP service, call it through the local port
from the app, stop it, and see the refund.

What M2 has (PR #11):

- `celaut-wire`: GetServiceEstimatedCost, StartService (time limit 600 s),
  StopService and GetMetrics (StopService and ModifyDeposit now send the `Client` at
  index 2, and the client balance is GetClientMetrics; nodo#597). `ServiceRequest::parts` sends Client (1), RecursionGuard
  (2), Configuration (3, only if it has bytes) and the Hash (4), in this order.
  ServiceTunnel: `TokenMessage{token, slot}` at index 1, then the bytes at index 0 in
  pieces of 64 KiB. The end of the request half-closes the connection to the service.
- `celaut-balancer`: the port of `estimated_cost_sorter` and `scoring.py`. Quotes are
  compared in nanoERG with the `mu_per_unit` of the ERG contract of each node (rounded
  up). A node with no ERG rate comes last. A stable sort, and a quote cache (10 s, 4096
  entries). Not yet: the filter on the advertised resources, and reputation events (0).
- `celaut-client`: `NodeSession` (one client id per node; in memory only in M2, in the
  Celaut database of the app since M3), `quotes`
  (all nodes at the same time, 10 s each), and `LocalPort` on 127.0.0.1: one
  ServiceTunnel stream per TCP connection, half-close in both directions, the last
  error kept.
- FFI (`api/celaut_service.rs`): quote, start (with an optional start balance), open a
  local port, status, stop. Client ids and instance tokens stay in Rust; Dart gets an
  instance id.
- Dart: `TunnelHttp` (one `HttpClient`, one connection per port, no proxy) and the
  debug screen "Celaut service" (Settings, Developer).

Facts from nodo dev `ec1274d` (the node of the check):

- The start cost is the build (`BUILD_MU`, only if the node has no built container
  for the service) plus the start balance of the instance. A service in the registry
  is not built before its first run.
- Without `Configuration.initial_mu`, the start balance is one hour of the resources of
  the service: 5 000 683 MU for the test service on our node, more than the free
  credit. So the app sends `initial_mu` (the screen proposes 1 000 000 MU), and the
  node quotes and charges that amount. This works because Configuration comes before
  the Hash.
- StopService gives the unused balance of the instance back to the client at once, and
  GetClientMetrics shows it.
- GetMetrics with the token of a stopped instance is an error ("Invalid token"), not a
  balance of 0.

Check on 2026-10-12, on our node (x86_64 with KVM, nodo dev `ec1274d`, default
config: free credit 4 500 000 MU, `BUILD_MU` 10 000 000 MU). Service: `tiny` of
demo-service (`9b0e4e45d3b078451984895891402a24b24a7f4112522592d7b3e2326aecb4c4`), an HTTP server on port 3030. The Gateway
port came through an SSH port-forward, with no new firewall rule.

- The node had `tiny` in its registry, but not built: the first quote was 14 389 612
  MU. One `nodo execute` on the node built it, and was stopped at once. No change of
  the config and no restart.
- `cargo test -p celaut-client --test real_node -- --ignored`, start balance
  1 000 000 MU: new client 4 500 000 MU; quote 1 000 000 MU, then 11 990 MU every 10 s;
  start: slot 3030, client 3 500 000 MU; three GETs through the local port on one TCP
  connection: HTTP 200 each time, 1 stream; instance 986 400 MU before the calls and
  976 400 MU after (one `TUNNEL_OPEN_MU`); stop: refund 976 399 MU; client
  3 500 000 MU before the stop and 4 476 399 MU after.
- From the app (debug APK in the arm64 AOSP emulator, the node at `10.0.2.2`): quote,
  start, local port, three calls (HTTP 200, 1 stream), stop: refund 940 074 MU, client
  4 440 074 MU.
- After the check: `nodo doctor` 23 OK and 0 FAIL or WARN; `nft list table inet nodo`
  and `config.yaml` as before; no instance or tunnel of the check left. What stays on
  the node: the built container of `tiny`, and the test clients in its database.

**M3: deposit with the wallet.** The wallet of the app pays (`docs/celaut/ui.md`, section 1). GenerateDepositToken, an Ergo transaction with one
output to the node script and the token in R4 (the send path in `ergo-tx/src/send.rs`
writes no registers today), the existing confirmation and sign screens, wait until the
box is on the explorer, then Payable once. The node needs no confirmation: the box can
be in the mempool, but it must be unspent and visible on the explorer of the node. The
explorer is the default of nodo (`https://api.ergoplatform.com`), fixed: a node does not
advertise an explorer, and the app does not take one from the node.
`Payment.contract` must be the `Contract` from GetPeerInfo without a change, because
the node compares its declaration. A per-node limit and a confirmation screen
that shows ERG and MU. Check: unit tests of the transaction; one end-to-end test on our
own node only after approval of the amount (see section 6).

What M3 has (PR #13):

- `ergo-tx`: `build_send_tx_with_registers`, a send with registers on the recipient
  output only. Registers start at R4 and have no gap; each value is the hex of a
  serialized constant.
- `celaut-wire`: `generate_deposit_token` and `payable`.
- `celaut-client` (`deposit`): `ErgPayment::of` takes the ERG contract that the
  balancer uses, keeps the `Contract` without a change, and refuses a declaration that
  is not `chain=ergo`, `network=mainnet`, with the token in R4. The MU of a deposit is
  `nanoERG × mu_per_unit`. A deposit token must be printable ASCII of 64 characters or
  less. `find_deposit_box` reads an explorer answer as the node does.
- FFI (`api/celaut_deposit.rs`): `celaut_deposit_node` (contract, balance, limit),
  `celaut_set_deposit_limit`, `celaut_deposit_prepare` (token, then a send preparation
  that `send_erg` signs and sends, as every send), `celaut_deposit_cancel`, and
  `celaut_deposit_notify` (waits up to 10 minutes for the box on
  `https://api.ergoplatform.com`, the fixed explorer of nodo, then `Payable` once; a
  timeout sends nothing to the node and can be repeated; an accepted deposit goes to
  the paid credit of the node). The limit is 1 ERG per node: it counts every deposit
  of the app to that node, from any wallet and for any client id, until it is
  cancelled before the send, and it is kept in the database. The user can set a lower
  limit, not a higher one.
- Dart: the screen "Celaut deposit" (Settings, Developer) and the confirmation sheet of
  the wallet with the ERG, the MU, the rate, the fee, the change, the total and the
  use of the limit. No "sign only" for a deposit.
- Tests: the registers, the contract, the amounts, the change and the fee of the
  transaction (`ergo-tx`, and ergo-lib reads R4 back in `wallet-ffi`); the contract,
  the payment, the token and the explorer answer (`celaut-client/tests/deposit.rs`);
  the limit and the wait (FFI); the confirmation sheet and the screen (Dart). The
  end-to-end tests are `#[ignore]`d and need environment variables
  (`api/celaut_deposit_e2e.rs`).

Facts from nodo dev `ee5af5bc` (details in wire.md, section 4):

- GenerateDepositToken writes a `pending` row in the database of the node and nothing
  on a ledger. The token is a UUID4 with hyphens and expires after one hour.
- The node finds the payment method by the ledger tag, the SHA3-256 of xattr
  `contract_type` and xattr `token_id`, and checks the ledger declaration. That is why
  the `Contract` goes back without a change.
- The node reads `R4.renderedValue` on its explorer, the default of Ergo AppKit for
  mainnet (`https://api.ergoplatform.com`), and checks only the first box with the
  token.

Changes for `docs/celaut/ui.md` (2026-10-13), with the one wallet of 2026-10-16:

- Payer: the wallet of the app (a seed on the device) pays. The screen and the
  confirmation sheet show its name, its balance ("unknown" if the app does not know it),
  the ERG and the MU. With no wallet, the screen says so and does not start, and the
  start and stop of the service screen are off with the same message.
- One Celaut database for the app (`celaut-client/src/db.rs`, FFI `api/celaut_db.rs`):
  the client id and addresses of each node (key: peer_id), the last advertisements, the
  instances with their tokens, the deposits, the last quotes and the event log of local
  reputation. No database per wallet and no wallet key; a deposit does not record
  which wallet paid (the transaction id is in the history of that wallet). The file is
  AES-256-GCM in `noBackupFilesDir/celaut/celaut.db`; its key is a random 32-byte key in
  the Keystore-backed `EncryptedSharedPreferences` of the app, the store of the seed
  wrap keys. A file that the key cannot open is kept under a new name and a new
  database starts.
- A restart keeps the client ids (the balance on each node stays usable), the
  instances (they can be stopped after a restart) and the sent deposits: the app marks
  a deposit "sent" before the broadcast, with the transaction id that is known before
  the signature, and the screen lists the sent deposits that wait for `Payable`. A
  deposit that was only prepared is dropped at the next start.
- The limit of a node counts every deposit of the app to it, also from a wallet that the
  user removed, and is kept in the database.
- Compute home (ui.md, section 2), the default home screen (Settings, Developer,
  Compute home turns it off). Since 2026-10-16 the home screen shows only what the user
  acts on (ui.md, section 2), and the figures below are one tap away.
  `celaut_compute_overview` asks every node of the node list
  at the same time:
  the offered resources (CPU, memory, disk; advertised, not free) summed once per
  peer_id, the reachable and unreachable nodes, the credit of the app on each node in
  MU and in ERG at the rate of that node, and each instance with its cost so far (the
  charge of the start less the balance that the instance still has). A sum with an
  unknown part reads "at least X (N nodes unknown)", and a sum with no known part is
  "unknown", never 0. For a node with more than one architecture entry, the largest
  entry counts (more memory, then more cores, then more disk), not the sum and not
  values from different entries. The screen follows the `celaut-design` landing page
  (palette, Playfair Display and Lato, the CELAUT wordmark, spaced capital labels,
  hairlines) and has Wallets and Nodes entries.
- Money: the ERG of the wallet; the credit on the nodes
  is split into paid credit and free credit (the free credit counts as spent first);
  each figure has a USD value from the ERG/USD oracle pool price that the wallet
  already reads on-chain (`TokenPricer`), or "USD unknown".
- Node list (ui.md, section 4): `celaut_known_nodes`, `celaut_add_node`,
  `celaut_remove_node`. A removed node leaves the sums; its client id and its deposits
  stay in the database, so adding it again restores them.
- A node that forgets the client id gives the error kind `ClientUnknown`. The app shows
  the error and asks: "New client" (`celaut_new_client`; the old balance is lost) or
  "Retry later". It never makes a new client by itself.
- Start and stop need the wallet open. If it is locked, the action first asks for its
  PIN or fingerprint. The deposit asks for the PIN or fingerprint of the wallet, also
  when it is open, with the unlock flow of the app.
- Missing values on the node and service screens show "unknown" (they were left out,
  or 0).

Read-only check on 2026-10-13, our node (nodo `ec1274d`): the node advertises the ERG
contract on mainnet, with the token in R4, 1 MU per nanoERG; GenerateDepositToken gives a
36-character token; free credit 4 500 000 MU. No transaction.

**M4: conversation screen.** The instance data is in one database for the app, not per wallet (`docs/celaut/ui.md`). Select a skill or a service hash, launch it, and talk to
it through the tunnel. Show the cost so far. Back leaves the screen and the instance runs
on; Stop is in the menu (the rule is in `docs/celaut/ui-chat-first.md`, section 5, and
waits for the confirmation of Josemi). First write the "chat" convention (HTTP with JSON, decision 3 in section 7).
Check: a conversation with a simple echo service that follows it.

What M4 has (PR #17 to #25, and the closing PR): the convention (`docs/celaut/chat.md`),
`ChatClient`, `ChatScreen` with the history and the cost so far, the detector of the chat slot, the launch on the best
node, the skill catalog and its picker, the filter on the advertised resources, and an
Android foreground service while a conversation is open. After a launch, the screen
says that the service starts and reads the history again until the service answers
(`ChatClient.syncWhenStarted`, chat.md section 9).

Attachments (2026-10-22): `chat.md` was at revision 4 then (revision 5, of 2026-10-23, sends with no wait and adds streaming). It is a specification in ASD-STE100
that covers the protocol only, and its section 10 has the conformance tests that a chat
service must pass. The app sends image and audio files (`file_picker`, the system document
picker), shows them in the bubbles and gives the text and the files back to the field when a
send fails. The flows are in `docs/celaut/ui-chat-first.md`, section 7. The services of the
sibling repositories that read the files are not described in chatui.

Check on 2026-10-21, on our node (x86_64 with KVM, nodo `ec1274d`, default config), from
the debug APK of the closing PR in the x86_64 emulator (Android 15, AOSP), the node at
`10.0.2.2`. Service: `echo-chat` v1 of celaut-basics
(`653cdd2913898145836e8472e33097e558b43b3d93830366951c61f112bc1091`), already in the
registry and built on the node. A new wallet with no ERG; the new client had the free
credit of 4 500 000 MU. No transaction.

- The file `653cdd.celaut.bee` (117 MiB) loaded into the app with "Import a service
  file". Run asked first: "Run 653cdd?", "Best node now: 10.0.2.2:53460 · start cost
  1,000,000 MU". After the PIN, the node started the instance and the conversation
  opened.
- The service listened about 25 seconds after the start. Meanwhile the node refused 4
  tunnels ("Connection refused" on port 8080), and the fifth read of the history
  worked. A second run had 5 refusals. Before the closing PR, the screen stopped at the
  first refusal with "The service did not answer".
- "one", "two" and "hello from the emulator": each one and its echo, in order, on one
  tunnel stream (`nodo tunnels --inbound`).
- Flight mode, then a send of "three": the screen said "The service did not answer" and
  kept the text. After flight mode, the same send: "three" and its echo once each, on a
  new stream.
- The cost so far went up with each answer (204 268, 530 904, 762 687 MU). "Stop the
  instance" stopped it; the credit of the client went from 4 500 000 to 3 694 034 MU.
- The second run: the foreground service of the conversation was on
  (`ConversationService`, `isForeground=true`, an ongoing notification), and after 60
  seconds in the background the process still ran. The app was locked when it came back,
  and the conversation screen was closed (section 0.1). The home screen showed the
  instance with its cost so far, and its Stop gave a refund of 463 595 MU.
- After the check: no instance and no tunnel on the node, the config and the process of
  nodo as before, and only the two base rules of nodo in its firewall table (gateway port
  and established connections), with no rule of an instance.

**M5: privacy** (after M4). Optional Tor (Arti, off by default) for outbound connections,
so that a node does not see the IP address of the phone. It does not hide the node;
onion addresses for nodes are nodo work (decision 7 in section 7).
Done: see `docs/celaut/network.md`. The user can choose Arti inside the app or an
external SOCKS5 proxy, for the nodes, the explorer and the updater of the app. With Tor
on, the app blocks the connections instead of going direct.

Check on 2026-10-21, in the emulator of the M4 check: Arti inside the app was ready in
about 7 seconds. "Check now" of the updater then got "GitHub is limiting requests from
this network", the answer of GitHub to a shared Tor exit, while the same request from
the host got 404 (no latest release) and its GitHub counter did not move. With Tor off,
"Check now" got "GitHub has no release to offer", the same 404.

## 6. Risks

| Risk | Mitigation |
|---|---|
| Payment to a dishonest node: the deposit is a plain payment, and the node can keep it | Small deposits, a per-node limit, local reputation events (balancer.md), refunds through StopService |
| `Payable` is one attempt only | Call it only after the box is on the explorer that the node uses; keep the deposit token and the transaction id so that the user can see what happened |
| Loss of instance tokens or client ids loses the balance on the node | Encrypted storage; StopService when the app closes the conversation |
| Keys on the device | The seed stays in Rust and Android Keystore as today. The app adds no new long-term key: a client id is a random bearer id per node |
| Mobile networks drop long gRPC streams | Reconnect the tunnel; keep requests to a service short, or let the service resume |
| Rate limit: more than 120 calls in 60 s per client puts the client in quarantine for 300 s | Quote cache (10 s), no polling loops |
| Delegated instances cannot be reached from a phone | `remaining_hops: 1` (M2); a nodo change if delegation is wanted later |
| Tunnel cost (open fee 10 000 MU, 2 000 000 MU per GiB) | Show the cost; stop idle instances |
| Privacy: each node sees the IP address of the phone and links its calls by client id | One client id per node (decisions.md); Tor in M5 |
| Protocol drift from nodo dev | `celaut-proto/protos/SOURCE` pins the commit; a CI job can compare it with nodo dev |
| Real funds in tests | No transaction in automated tests. Manual tests on our own node only, with an amount that a maintainer approves first |

## 7. Decisions on the open questions (2026-10-11)

1. **Role:** the app is a light client only. It never acts as a peer. The repository
   description is now "Android light client for Celaut, with an Ergo wallet".
2. **Order of work:** `celaut-crates` is merged into master, and all new work comes
   as PRs into master.
3. **First service for M4:** a simple echo (or translation) service over HTTP with
   JSON, with a small "chat" convention that a later LLM service also follows.
   Write the convention down in M4 before the screen.
4. **Delegation:** no delegation. The app sends `remaining_hops: 1`, so the node
   that it calls runs the service. A nodo change to relay ServiceTunnel comes only if
   delegation is wanted later.
5. **Tests of M2 and M3:** our own node with a large `CREDIT_MU_PER_NEW_CLIENT` for
   M2 (not needed in the end: the M2 check runs on the default credit, see M2 in
   section 5). For M3: nodo does not accept the Ergo testnet (answer of 2026-10-12).
   Mainnet fees are small enough, so the M3 end-to-end test uses one small real
   deposit on mainnet, with an amount that is approved first (section 6).
6. **Package upload:** import a `.celaut.bee` that already exists, through
   StartService indices 5 and 6, for a node that does not have the service. Show the
   size and warn on mobile data. This needs the send side of blocks in
   `bee-rpc-over-grpc-rs`, which is not in its current plan. (Done in PR #35 to #37:
   `docs/celaut/package.md`.)
7. **Tor:** optional, with Arti (Rust), off by default, in M5 after M4.
8. **Node directory:** no bootstrap list in the app. Only on-chain node boxes and
   nodes that the user adds by address or QR code.
9. **Release key:** changed on 2026-10-12. CI signs the release APKs with a key used
   only for chatui. The key is in the secrets of the GitHub environment `release`,
   which accepts only tags `v*` and needs Josemi's approval before each signing job.
   Steps: set `appVersion` and `appBuildNumber` in `build_info.dart` and `pubspec.yaml`,
   merge, then push the tag `v<appVersion>`. The `release` workflow builds the APKs,
   waits for the approval, signs them, runs `release_check.sh apks` and creates a
   prerelease. The updater ignores prereleases, so mark a release as latest only after
   the test on GrapheneOS.

10. **License (decided, 2026-10-12):** `bee-rpc` is GPL-3.0-only and the app links it
    into `libwallet_ffi.so`. Josemi decided that chatui is GPL-3.0-only. `LICENSE` has
    the text, and `NOTICE.md` keeps the MIT notice of Argus, from which chatui is
    forked. The workspace `license` is `GPL-3.0-only`.

11. **Wallets, storage and home screen (decided, 2026-10-13):** full wallets (seed,
    can sign) manage instances and pay nodes. Read-only wallets only view balances and
    history. All Celaut data is in one database, none per wallet. A deposit uses one
    full wallet. (Decision 14 replaces the two types of wallet.)
    The home screen shows the compute that the connected nodes offer (the sum of their
    resources) and the money for compute first; the ERG of each wallet is second level.
    The full rules are in `docs/celaut/ui.md`. New screens must follow them.

12. **Answers on PR #13 (2026-10-13):** the compute home is the default view, with the
    `celaut-design` landing page as the reference; partial sums read "at least X (N
    nodes unknown)" and a node counts with its largest architecture entry; USD from the
    oracle pool price; full and watched ERG as two figures; the deposit asks for the PIN
    or fingerprint of the paying wallet; start and stop need an open full wallet; an
    explicit node list with add and remove (deposits kept); a forgotten client id is the
    user's choice (new client or retry later); free credit apart from paid credit; the
    limit is 1 ERG per node over all deposits of the app, kept across restarts; the
    explorer stays fixed to the nodo default; the e2e deposit of 0.01 ERG was approved
    and done. The nodo deposit check is issue celaut-project/nodo#541. The answers are
    implemented in PR #15. (Decision 14 replaces "full and watched ERG".)

13. **Answers on PR #15 (2026-10-13):** answer 2: the largest architecture entry of a
    node is the one with the most memory, then the most cores, then the most disk (not
    cores first). A known value is larger than an unknown one, and values of different
    entries are not mixed or added. Answer 7: add a node by QR code in the next PR,
    beside the address field. A scanned address goes through the same node check as a
    typed one. The QR format is in `docs/celaut/wire.md`, section 6; Josemi accepted it
    on 2026-10-13. Other answers on PR #15 keep the defaults of the code.

14. **One wallet and the home screen (decided, 2026-10-16):** the app holds one Ergo
    wallet with its seed; there are no watch-only wallets, no offline signing and no
    default payer (PR #40, #41). The home screen shows only what the user acts on: the
    running instances, "Run a service" and one card of state (PR #38). The rules are in
    `docs/celaut/ui.md`, sections 1 and 2.

## 8. Notes for `docs/celaut/wire.md`

Checked against nodo dev `e3d12301`:

- nodo now pins bee-rpc-over-grpc-py v0.0.2 (nested blocks, up to 32 levels). The
  `bee_rpc:client.py` line numbers in wire.md are from v0.0.1.
- Observe needs the instance token (`gateway_bee.py` declares `token`), not "none".
- Section 3: "uri can be empty (delegated …), then use ServiceTunnel" does not work for
  a delegated instance (see M2).
- Add the StartService send order, the Peer signature check and the Payable conditions
  from M1 to M3 above.
