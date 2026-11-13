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
| `tor-onion-v3` | the 32-byte key of the service and a port; the app makes the `.onion` name | yes, with Tor on (section 3) |
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

`celaut_connect_invite(bytes)` reads the invitation and tries the addresses that can work
**on the current route** (`celaut-client/src/invite.rs`, `plan`), in order, and stops at the
first node that proves the key.

| Route | Onion | Private network (10.x, 192.168.x, fd00::, `.local`, no dot) | Order |
|---|---|---|---|
| Direct | skipped: no way to reach it | tried: the QR code is often shown on the same network | the one of the invitation |
| Tor inside the app | tried **first**: it never leaves the Tor network (Arti with `onion-service-client`, section 7) | skipped: a Tor exit cannot reach it | onion, then the one of the invitation |
| External SOCKS5 proxy (Orbot) | tried **first**: it never leaves the Tor network | skipped | onion, then the one of the invitation |

An address that is skipped is not an error: the screen says why for each one that the app
knows ("needs Tor", "a private network address cannot be reached through Tor"). The order of the invitation is the preference of the node, which puts the
addresses that work first (nodo `build_invite`).

Each try pins the identity: `ConnectOptions.expected_peer_id` is the key of the invitation,
so the TLS handshake fails for any other key. An address that another node holds, for
example after the host changed its key, is a failure of that address and the next one is
tried, as `nodo connect --invite` does. A dial that works is the same as for a typed address
from then on: the client id of the node (or a new client), the signature of the
advertisement, and the node goes into the node list with that address first. A node that
forgot the client id gives the usual choice (a new client, or later).

Timeouts: 10 seconds for a direct address, 45 for a route through Tor (a circuit takes
longer), and 60 for an onion address (its descriptor, an introduction and a rendezvous come
before the first byte; section 7). The tries are one after another, so the worst case with four unreachable
addresses on a direct route is 40 seconds.

## 4. Code

| Where | What |
|---|---|
| `rust/crates/celaut-proto/protos/invite.proto`, `src/gen/invite.rs` | The message, copied from nodo; `cargo run -p gen-protos` |
| `rust/crates/celaut-client/src/invite.rs` | `parse`, the formats of each tag, `plan` (the route rules), `is_private` |
| `rust/crates/wallet-ffi/src/api/celaut_invite.rs` | `celaut_connect_invite`, the attempts for the screen |
| `rust/crates/wallet-ffi/src/api/celaut_service.rs` | `session_pinned`: a session that only the invited key can open |
| `app/lib/celaut/invite_scan.dart`, `app/lib/ui/scan_screen.dart` | `ScannedCode`, `looksLikeInvite`, the binary scanner |
| `app/lib/ui/celaut/known_nodes_screen.dart` | The scan button, the result, the reason for each address |

## 5. Checks

- `invite.rs`: the vectors give the addresses that nodo gives, the refusals match, unknown
  tags are dropped, the onion name is the one of the key, junk never panics, and the private
  ranges and the route rules (one test per route).
- `celaut_invite.rs`: the first address that works stops the tries and each try pins the key;
  nothing works gives a reason for each address; no usable address asks nobody; each Tor
  route (the client of the app and a proxy) tries the onion first with the long timeout; a
  direct route says that the onion needs Tor; bytes that are not an invitation are refused.
- `app/test/celaut_known_nodes_test.dart`: an invitation connects and lists the node; the
  reasons are shown; a code of text never goes to the reader; a node that forgot the client
  id asks and connects again.
- Not checked: a real node (`nodo invite --raw` into a phone), a scan with a camera, an onion
  address through Orbot, IPv6 on a phone. The vectors were written from the proto and the
  format of nodo and not made with its code, because nodo needs `bee-rpc-over-grpc-py` and the
  tool that installs it was refused in this environment. They match the figures of nodo#579
  (49 and 128 bytes) and its tests.

## 6. Open items

- **Onion with the Tor client of the app.** Done (issue #140): section 7.
- **Race the addresses.** The app tries one after another. Trying the first two at the same
  time would save time when the first one hangs. Not built.
- **A link to open the app.** `celaut://` for an invitation, so that a phone camera app can
  open it. The invitation is binary, so it would need base64 and a size check; nodo says no
  to a URL wrapper.

## 7. Onion with the Tor client of the app (#140, 2026-11-13)

The Arti client of the app is built with the `onion-service-client` feature of
`arti-client` 0.47 (`rust/crates/celaut-tor/Cargo.toml`), and `address_filter.allow_onion_addrs`
is set on (it is the default of Arti with that feature). In 0.47 this feature is not one of
the experimental ones (`__is_experimental`); the onion *service* side, which the app does not
use, has experimental parts. So both Tor routes open `.onion` addresses: a typed one, and the
onion of an invitation, which goes first (section 3). A direct route refuses a `.onion` name
before any lookup (`celaut_net::connect`), so the name never reaches the DNS server of the
network.

Nodes: nodo announces an onion address with its own Tor (`nodo tor`, `routing.tor.ENABLED`,
`routing.tor.ANNOUNCE`, or `routing.HIDDEN`). It serves the gateway to Tor on a second gRPC
server that treats every caller as a remote peer, with the same TLS certificate, so the app
checks the key of the node through the onion as on the clearnet.

### Measures

On Ubuntu 22.04 x86_64 (WSL2), the same network, `libwallet_ffi.so` of release builds
(`scripts/build_android.sh`, NDK 28.2):

| | Before | After | Change |
|---|---|---|---|
| arm64-v8a | 56 812 272 bytes (17 957 611 with gzip -9) | 58 843 248 bytes (18 581 877 with gzip -9) | +2 030 976 bytes (+3.6 %); +624 266 with gzip |
| x86_64 | 55 648 424 bytes (18 031 869 with gzip -9) | 57 658 744 bytes (18 651 608 with gzip -9) | +2 010 320 bytes (+3.6 %); +619 739 with gzip |

The start of Arti (`real_tor`, a new state directory each time, so a cold bootstrap), the
two builds one after the other in the same minutes: before 153.6, 93.2, 47.2 and 24.3 s;
after 107.1, 85.9, 38.2 and 27.1 s. The time is the one of the network: the onion client
does nothing until the app dials an onion, and the start is not slower.

An onion service (the one of `www.torproject.org`, `celaut_net::connect` as for a node):
the first stream after 8.8, 13.8 and 32.3 s (the descriptor, an introduction and a
rendezvous), the second one after 0.6 to 0.9 s (the descriptor and the circuits are cached).

Verdict: kept. A node that hides its IP address can only be reached by its onion. The cost
is about 2 MB of native code for each ABI (3.6 %, about 0.6 MB in the compressed APK), and
nothing changes for a user without Tor or for the start of Tor.

### Checks

- `invite.rs`: one test per route; the client of the app tries the onion first and skips the
  private network. `celaut_invite.rs`: both Tor routes try the onion first with 60 s; a
  direct route says that the onion needs Tor. `celaut-net`: a direct route refuses an onion
  name with no lookup.
- `cargo test -p celaut-tor --test real_tor -- --ignored --nocapture` (Internet) now opens
  the onion service of `www.torproject.org` twice after the clearnet checks.
- `cargo test -p celaut-tor --test real_onion_node -- --ignored --nocapture` with
  `CELAUT_INVITE_HEX` (the hex of `nodo invite --raw -`): it reads the invitation, keeps the
  addresses of the route "Tor inside the app" and dials them with the key pinned. On
  2026-11-13 the test node (nodo dev `76dcac3b`), with an invitation of its key, its private
  address and an onion address, gave: the private address skipped, the onion first, the key
  proved after 9.6 s (Tor ready after 22 s).
- The app in the emulator, with "Tor inside the app" and the test node behind an onion
  service (`tor` 0.4.9.11, `HiddenServicePort` to its gateway): the build before #140 could
  not add the onion address ("the proxy could not connect: general failure"); the build of
  #140 added it ("The node was added.", the onion first in the addresses of the node,
  "Available · 1084 ms"). Then `echo-chat` (`b4e043`) with a balance for 10 minutes: the
  quote named the onion as the best node, the start, the tunnel, an answer to "hello over
  onion", and the stop with its refund, all through the onion.
- Not checked: a phone, nodo's own onion service (`routing.tor.ANNOUNCE` on a node: the test
  node is shared, so its onion was a separate `tor` with `HiddenServicePort` to its gateway;
  the gateway is the same, the gRPC server in front of it is not), Orbot.

