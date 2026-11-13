# Peer invitation in a QR code (2026-10-22)

nodo#579 (issue nodo#572, "QR for Chatui") lets a node show a compact invitation to itself as
a QR code: `nodo invite`, or `i` on the PEERS screen of its TUI. The app reads it and
connects to the node. This note says what the app reads and how it chooses an address.
It adds to the two text forms of [wire.md](wire.md), section 6, which stay.

Sources: `protos/invite.proto` and `src/utils/peer_invite.py` of nodo dev at `f4dcb3b2`.

## 1. What the QR code holds

A `PeerInvite` as protobuf bytes, in QR byte mode at level M, with no base64 and no URL:

| Field | Content |
|---|---|
| `public_key` (1) | The 32 bytes of the ed25519 identity key of the node: its `peer_id` |
| `addr` (2, repeated) | Where to reach it, in order of preference |

Each `Addr` has `tags` (synonyms; one that the app knows is enough), `formal` (key=value
lines, usually empty) and `data` (the host and then the port, as the tag says):

| Tag | `data` | App |
|---|---|---|
| `ip4` | 4 bytes and a big-endian port | yes |
| `ip6` | 16 bytes and a port | yes |
| `tor-onion-v3` | the 32-byte key of the service and a port; the app makes the `.onion` name | yes, with a Tor proxy (section 3) |
| `dns` | an ASCII host name and a port | yes |
| any other tag | | ignored, as nodo says |

The invitation has no signature, no resources and no proofs. The address is never trusted,
only the key. One address with 49 bytes plus the key fits in a QR code of version 4, and
ip4, ip6 and onion in 128 bytes (version 8); nodo refuses more than 1000 bytes.

The rules of nodo are kept: an `Addr` of a known tag with bad data (a wrong length, a host
that is not a name, an onion name that is not valid) makes the whole invitation invalid, and
so does a `formal` that is not UTF-8 `key=value` lines, or a key that is empty or repeated.
`celaut-client/src/invite.rs` has the same rules. Its test vectors
(`celaut-client/tests/vectors/invite_vectors.json`, from `generate_invite.py`) hold the
sizes of nodo (49 and 128 bytes), the valid cases and 19 cases that its rules refuse.

## 2. The scanner reads bytes

The existing scanner gave only the text of the code. An invitation is not text, and the
text that a decoder makes from its bytes is not the data. `ScanScreen(binary: true)` gives a
`ScannedCode` with the text and the raw bytes (`Code.rawBytes` of `flutter_zxing`, which is
the payload of the code). The other callers (send, ErgoPay, the dashboard) still get text.

The node list screen (`KnownNodesScreen`, the scan button of the address field) tells the
two forms apart by the first bytes: an invitation begins with field 1 and 32 bytes
(`0x0a 0x20`), which the text of a QR code cannot. An invitation goes to Rust. Anything else
is a node address, as before. Rust refuses what is not an invitation and the screen shows
the error of a bad address.

## 3. The way that is most feasible

`celaut_connect_invite(bytes)` reads the invitation and races the addresses that can work
**on the current route** (`celaut-client/src/invite.rs`, `plan`), in that order, and uses the
first node that proves the key (section 3.1).

| Route | Onion | Private network (10.x, 192.168.x, fd00::, `.local`, no dot) | Order |
|---|---|---|---|
| Direct | skipped: no way to reach it | tried: the QR code is often shown on the same network | the one of the invitation |
| Tor inside the app | skipped: Arti is built without onion services | skipped: a Tor exit cannot reach it | the one of the invitation |
| External SOCKS5 proxy (Orbot) | tried **first**: it never leaves the Tor network | skipped | onion, then the one of the invitation |

An address that is skipped is not an error: the screen says why for each one that the app
knows ("needs Tor with an external proxy", "a private network address cannot be reached
through Tor"). The order of the invitation is the preference of the node, which puts the
addresses that work first (nodo `build_invite`).

Each try pins the identity: `ConnectOptions.expected_peer_id` is the key of the invitation,
so the TLS handshake fails for any other key. An address that another node holds, for
example after the host changed its key, is a failure of that address and the next one is
tried, as `nodo connect --invite` does. A dial that works is the same as for a typed address
from then on: the client id of the node (or a new client), the signature of the
advertisement, and the node goes into the node list with that address first. A node that
forgot the client id gives the usual choice (a new client, or later).

Timeouts: 10 seconds for a direct address, 45 for a route through Tor (a circuit takes
longer).

### 3.1 The race of the addresses

Tried one after another, an address that hangs made the user wait for its whole timeout
before the next one was tried: four addresses that hang on a direct route took 40
seconds. Now the addresses race (`celaut-client/src/race.rs`, issue #139):

- The first two addresses start at the same time. At most two tries run at once; when one
  fails, the next address of the order starts.
- When a try proves the key, no new try starts and the tries after it in the order are
  stopped (their future is dropped, so the dial or the handshake ends there).
- A try before it in the order can still be running. It has 250 ms more (`GRACE`): if it
  proves the key in that time, it is used instead, so the order of preference wins when two
  addresses answer at nearly the same time. After that it is stopped. A second address that
  worked but is not used has its connection closed, unless it was open before.
- The screen lists the tried addresses in the order of preference. A try that was stopped,
  or that worked after an address before it, is `NotNeeded`. It never shows: the list of
  reasons shows only when no address worked.

The worst case with four addresses that hang on a direct route is now 20 seconds (two
rounds of two), and a hanging first address with a working second one costs the time of the
second one and the grace, not 10 seconds. Through Tor the two tries build two circuits at
once.

The same race connects to a node of the node list (`celaut_home.rs`, `reach_within`): the
compute overview and the checks of the nodes (`celaut_health.rs`) race the addresses where
the app reached the node, the last one first. There a try that reaches another node (the
`peer_id` of the advertisement is not the one of the list) is a failure, so it never wins
over the node.

## 4. Code

| Where | What |
|---|---|
| `rust/crates/celaut-proto/protos/invite.proto`, `src/gen/invite.rs` | The message, copied from nodo; `cargo run -p gen-protos` |
| `rust/crates/celaut-client/src/invite.rs` | `parse`, the formats of each tag, `plan` (the route rules), `is_private` |
| `rust/crates/celaut-client/src/race.rs` | `race`: two tries at a time, the first that works, the order within the grace |
| `rust/crates/wallet-ffi/src/api/celaut_invite.rs` | `celaut_connect_invite`, the attempts for the screen |
| `rust/crates/wallet-ffi/src/api/celaut_home.rs` | `reach_within`: the same race for a node of the node list |
| `rust/crates/wallet-ffi/src/api/celaut_service.rs` | `session_pinned`: a session that only the invited key can open |
| `app/lib/celaut/invite_scan.dart`, `app/lib/ui/scan_screen.dart` | `ScannedCode`, `looksLikeInvite`, the binary scanner |
| `app/lib/ui/celaut/known_nodes_screen.dart` | The scan button, the result, the reason for each address |

## 5. Checks

- `invite.rs`: the vectors give the addresses that nodo gives, the refusals match, unknown
  tags are dropped, the onion name is the one of the key, junk never panics, and the private
  ranges and the route rules (one test per route).
- `race.rs` (with a paused clock): a first address that hangs or waits for its whole
  timeout does not hold up a fast second one; the first in the order wins when both answer
  within the grace and loses after it; a winner stops the tries after it at once; never more
  than two at a time and a failure starts the next; one at a time gives the old order and
  times.
- `celaut_invite.rs`: the first address that works stops the tries and each try pins the key;
  nothing works gives a reason for each address; no usable address asks nobody; a Tor proxy
  tries the onion first with the long timeout; bytes that are not an invitation are refused;
  a slow fake address and a fast one connect by the fast one in well under the timeout; the
  order of the invitation wins when both answer at nearly the same time; never more than two
  addresses at a time.
- `app/test/celaut_known_nodes_test.dart`: an invitation connects and lists the node; the
  reasons are shown; a code of text never goes to the reader; a node that forgot the client
  id asks and connects again.
- Not checked: a real node (`nodo invite --raw` into a phone), a scan with a camera, an onion
  address through Orbot, IPv6 on a phone. The vectors were written from the proto and the
  format of nodo and not made with its code, because nodo needs `bee-rpc-over-grpc-py` and the
  tool that installs it was refused in this environment. They match the figures of nodo#579
  (49 and 128 bytes) and its tests.

## 6. Open items

- **Onion with the Tor client of the app.** Arti is built without `onion-service-client`.
  With it, an onion address would work on the "Tor inside the app" route and would be first
  there too. It makes the native library bigger and the feature is experimental in Arti.
- **A link to open the app.** `celaut://` for an invitation, so that a phone camera app can
  open it. The invitation is binary, so it would need base64 and a size check; nodo says no
  to a URL wrapper.
