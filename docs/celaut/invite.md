# Peer invitation in a QR code (2026-10-22)

nodo#579 (issue nodo#572, "QR for Chatui") lets a node show a compact invitation to itself as
a QR code: `nodo invite`, or `i` on the PEERS screen of its TUI. The app reads it and
connects to the node. This note says what the app reads and how it chooses an address.
It adds to the two text forms of [wire.md](wire.md), section 6, which stay. Section 6 is
the `celaut://` link that opens the app with an invitation (issue #138), and the Share
action that makes one.

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

`celaut_connect_invite(bytes)` reads the invitation and races the addresses that can work
**on the current route** (`celaut-client/src/invite.rs`, `plan`), in that order, and uses the
first node that proves the key (section 3.1).

| Route | Onion | Private network (10.x, 192.168.x, fd00::, `.local`, no dot) | Order |
|---|---|---|---|
| Direct | skipped: no way to reach it | tried: the QR code is often shown on the same network | the one of the invitation |
| Tor inside the app | tried **first**: it never leaves the Tor network (Arti with `onion-service-client`, section 8) | skipped: a Tor exit cannot reach it | onion, then the one of the invitation |
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
before the first byte; section 8).

### 3.1 The race of the addresses

Tried one after another, an address that hangs made the user wait for its whole timeout
before the next one was tried: four addresses that hang on a direct route took 40
seconds. Now the addresses race (`celaut-client/src/race.rs`, issue #139):

- The first address starts alone, with a head start of 250 ms (`HEAD_START`, the
  "Connection Attempt Delay" of Happy Eyeballs, RFC 8305). The second address starts when
  the head start is over, or at once if the first fails before. So a healthy first address
  is the only one that is dialed. The same holds between each try and the next.
- At most two tries run at once; when one fails, the next address of the order starts.
- When a try proves the key, no new try starts and the tries after it in the order are
  stopped (their future is dropped, so the dial or the handshake ends there).
- A try before it in the order can still be running. It has 250 ms more (`GRACE`): if it
  proves the key in that time, it is used instead, so the order of preference wins when two
  addresses answer at nearly the same time. After that it is stopped. A second address that
  worked but is not used has its connection closed, unless it was open before.
- The screen lists the tried addresses in the order of preference. A try that was stopped,
  or that worked after an address before it, is `NotNeeded`. It never shows: the list of
  reasons shows only when no address worked.

The worst case with four addresses that hang on a direct route is now about 20 seconds
(two rounds of two), and a hanging first address with a working second one costs the head
start, the time of the second one and the grace, not 10 seconds. The grace and the head
start are the same through Tor. Through Tor the two tries build two circuits at once.

A try that completed TLS still has to open a session: `GetPeerInfo` with the client id that
the app has on the node, or `GenerateClient` first if it has none (`celaut_service.rs`,
`open_session`). Two tries must not make two clients on one node, so making a client takes
a lock of that node (`OPENING`, by `peer_id`):

- A node where the app has a client takes no lock: resuming the client makes none. An
  address that hangs in `GetPeerInfo` holds up nothing.
- Without a client, a try takes the lock of the node, looks again (another try may have made
  the client while it waited) and only then calls `GenerateClient`. An address that hangs
  there holds up only the other tries on the same node, until it is stopped (its time
  limit) — the price of one client per node. Other nodes are not held up.

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
| `rust/crates/celaut-client/src/race.rs` | `race`: the head start, two tries at a time, the first that works, the order within the grace |
| `rust/crates/wallet-ffi/src/api/celaut_invite.rs` | `celaut_connect_invite`, the attempts for the screen |
| `rust/crates/wallet-ffi/src/api/celaut_home.rs` | `reach_within`: the same race for a node of the node list |
| `rust/crates/wallet-ffi/src/api/celaut_service.rs` | `session_pinned`: a session that only the invited key can open; `open_on`, `OPENING`: one new client at a time on each node |
| `app/lib/celaut/invite_scan.dart`, `app/lib/ui/scan_screen.dart` | `ScannedCode`, `looksLikeInvite`, the binary scanner |
| `app/lib/ui/celaut/known_nodes_screen.dart` | The scan button, the confirmation, the result, the reason for each address |
| `rust/crates/wallet-ffi/src/api/celaut_invite.rs` | `celaut_read_invite`: the key and the addresses for the confirmation, with no connection |
| `app/lib/celaut/celaut_link.dart` | `parseCelautLink`: the `celaut://` link, its size checks and its base64 |
| `app/lib/ui/celaut/node_link.dart` | `openNodeLink`, the confirmation of an invitation or an address, the refusal; `showNodeShare` |
| `app/lib/ui/celaut/celaut_link_open.dart` | `openCelautLink` and `celautLinkOpeners`: the opener of each host |
| `rust/crates/celaut-client/src/invite.rs`, `wallet-ffi/.../celaut_invite.rs` | `build`, `celaut_node_invite`: the invitation of a listed node, for Share |
| `app/lib/ui/celaut/node_connect_screen.dart` | The Share action of the node detail |
| `app/android/.../OpenLinkActivity.kt`, `DeepLinkHandler.kt` | The intent filter of `celaut:` and the way of a link into the app |

## 5. Checks

- `invite.rs`: the vectors give the addresses that nodo gives, the refusals match, unknown
  tags are dropped, the onion name is the one of the key, junk never panics, and the private
  ranges and the route rules (one test per route).
- `race.rs` (with a paused clock): a healthy first address is the only one dialed; the
  second starts at the end of the head start, or at once when the first fails; each try has
  its head start over the next; without a head start the first two start together; a first
  address that hangs or waits for its whole timeout does not hold up a fast second one; the
  first in the order wins when both answer within the grace and loses after it; a winner
  stops the tries after it at once; never more than two at a time and a failure starts the
  next; one at a time gives the old order and times.
- `celaut_service.rs` (the lock of each node): a node that hangs while it makes a client
  does not hold up another node; a known node whose first address hangs in `GetPeerInfo`
  is reached by the second address in the race; two calls never make two clients on one
  node; a new node whose first address hangs in `GenerateClient` makes one client, by the
  second address, after the first is stopped; the locks that nobody uses are dropped.
- `celaut_invite.rs`: the first address that works stops the tries and each try pins the key;
  nothing works gives a reason for each address; no usable address asks nobody; each Tor
  route (the client of the app and a proxy) tries the onion first with the long timeout; a
  direct route says that the onion needs Tor; bytes that are not an invitation are refused;
  a slow fake address and a fast one connect by the fast one in well under the timeout; the
  order of the invitation wins when both answer at nearly the same time; never more than two
  addresses at a time.
- `app/test/celaut_known_nodes_test.dart`: an invitation asks first (key, addresses, the
  ones that the route skips, "already in your list") and Cancel connects nothing; then it
  connects and lists the node; the reasons are shown; a code of text never goes to the
  reader; a QR code with the text of an invitation link is an invitation; a node that forgot
  the client id asks and connects again; opened from a confirmed link, the screen connects
  at once.
- `app/test/celaut_link_test.dart`: the link gives the bytes back (padding or not, `%3D`,
  upper case, other parameters); a link of a megabyte and an invitation over 1000 bytes are
  refused before they are decoded; malformed forms are refused with their reason;
  3000 random links never throw; the confirmation, Cancel, the address form and each
  refusal on screen.
- `celaut_invite.rs`: the reader gives the addresses in the order of the route and the
  skipped ones last, says whether the node is listed, and refuses junk.
- `invite.rs` (`build`): the bytes are the ones of nodo for the vectors and for the real
  invitation of a test node; loopback, malformed and repeated addresses are left out; the
  invitation stays within 1000 bytes; no address or no key is an error.
  `celaut_invite.rs`: the invitation of a listed node reads back with its addresses.
- `celaut_link_test.dart`: `celautLinkHost`; a link goes to the opener of its host, a
  second host is one entry, an unknown host says so; the Share dialog shows the link (QR
  code and text) that opens the same invitation, Copy and Share give it, and a node with no
  address says so. `celaut_node_screen_test.dart`: the detail has Share, the empty form
  has not.
- Not checked: a real node (`nodo invite --raw` into a phone), a scan with a camera, an onion
  address through Orbot, IPv6 on a phone. The vectors were written from the proto and the
  format of nodo and not made with its code, because nodo needs `bee-rpc-over-grpc-py` and the
  tool that installs it was refused in this environment. They match the figures of nodo#579
  (49 and 128 bytes) and its tests.

## 6. A link that opens the app

A phone camera app opens a QR code of text that is a link, and a chat or a web page can
hold one. The invitation of nodo is binary, and nodo says no to a URL wrapper, so the link
is a format of the app:

```
celaut://node?invite=<the bytes of the invitation in URL-safe base64>
```

### 6.1 The format

- The host is `node`, as in the address form of [wire.md](wire.md), section 6: a link to a
  node, by an invitation or by an address (`celaut://node?addr=host:port`). The scheme and
  the host are case-insensitive; a `/` after `node` is allowed; no fragment.
- The base64 is the URL-safe alphabet of RFC 4648, section 5 (`-` and `_`), with or without
  the `=` padding (also as `%3D`). `+`, `/` and any other character make the link invalid.
- `invite` comes once. Other parameters are ignored, so that a later version can add one.
  With `invite`, an `addr` is ignored.
- Sizes, checked in this order and before anything is decoded: a link longer than 2048
  characters; a base64 longer than 1336 characters (the base64 of 1000 bytes); then, after
  decoding, more than 1000 bytes, the limit of nodo. An invitation of 49 bytes is a link of
  87 characters, and one of 128 bytes a link of 192.
- The bytes must then begin as an invitation (`0x0a 0x20`), and Rust reads them by the rules
  of section 1.

### 6.2 The way into the app

**On Android** `OpenLinkActivity` has the intent filter (VIEW, BROWSABLE, scheme `celaut`)
and gives the link to MainActivity in the task of the app, as `OpenPackageActivity` does
for a file: no second Flutter engine in the task of the camera app. `DeepLinkHandler` gives
it to Flutter (`argus/deeplink`, with the ErgoPay links); only the first 4097 characters of
a longer link cross the channel, enough to see that it is too long. A link that Android
gives again from the recent apps is not opened again.
MainActivity turns off the deep linking of Flutter (`flutter_deeplinking_enabled`): it is
on by default since Flutter 3.27 and pushed every link that came while the app ran as a
route, which is unknown, so a second home screen covered the dialog of the link. The ErgoPay
links had the same fault.

**In the app** the home screen takes the link when it is ready; no wallet is needed.
`openCelautLink` gives a `node` link to `openNodeLink` (section 6.3). Then:

1. `parseCelautLink` reads it. A link that is too long, malformed or not an invitation
   shows a dialog that says which, and nothing else happens. Nothing in a link can make the
   parser throw.
2. `celaut_read_invite` reads the invitation with no connection. A refusal of Rust is "the
   invitation in the link is damaged".
3. The confirmation shows the key of the node (short, with Copy and the full key), "already
   in your list" if it is, and the addresses in the order that the app will try them, with
   "not tried on the current route" for the ones that the route skips.
4. Add opens the node list, which connects as for a scanned code (section 3) and shows the
   result there. Cancel does nothing.

The scanner of the node list shows the same confirmation before it connects, for the bytes
of an invitation and for a QR code with the text of an invitation link. A link with an
address (`addr`) asks "add the node at host:port?" and then adds it as a typed address.
A link that comes while another screen is open closes the screens above home first, as an
ErgoPay link or a tapped notification does.

### 6.3 One handler for every host

`celaut://` is the scheme of the app for all its links, not only for nodes: `celaut://import`
(a service from a link, #135) is the next one. There is one way in for all of them:

- **Android:** `OpenLinkActivity` has the only intent filter of the scheme, with no host, and
  does not look at the host. `DeepLinkHandler` passes every `celaut:` link to Dart.
- **Dart:** the home screen calls `openCelautLink` (`celaut_link_open.dart`). It reads only
  the host (`celautLinkHost`: `celaut://<host>` then the end, `/`, `?` or `#`, case-
  insensitive) and calls the opener of that host in `celautLinkOpeners`:

  ```dart
  const Map<String, CelautLinkOpener> celautLinkOpeners = {
    'node': openNodeLink,
    // 'import': openImportLink,   <- a new kind of link is one line
  };
  ```

  A `CelautLinkOpener` gets the context and the whole link. It checks its own form and
  sizes, asks the user, and shows `showCelautLinkRefused` for a link that it does not open.
  A host with no opener shows "this app cannot open this kind of celaut link".

### 6.4 Share: making a link

The node detail (the node list, then a node) has a **Share** action in its app bar. It shows
the `celaut://node?invite=` link of the node:

- as a QR code, which a phone camera app opens;
- as text, with **Copy**;
- with **Share link**, the share sheet of the system (a chat, an e-mail).

The invitation is made in Rust (`celaut_node_invite`, `invite::build`) as nodo's
`build_invite` writes it: the key of the node, then the addresses where the app reached it,
the last one first, one tag each and no formal. The bytes are the same as nodo's for the same
addresses. Loopback addresses (`127.0.0.0/8`, `::1`, `localhost`) are left out, because they
would point at the device that opens the link. So are repeated ones, and the ones that would
pass the 1000 bytes of nodo. If no address is left, the dialog says that the app cannot make
a link. The link holds no client id and no credit: it only says who the node is and where
to find it, like the QR code of `nodo invite`.

## 7. Open items

- **Onion with the Tor client of the app.** Done (issue #140): section 8.
- **The guest bridge in nodo's invitations.** `nodo invite` lists `192.168.200.1`, the
  host side of nodo's guest bridge, first (seen on a test node, nodo dev 76dcac3b). No
  client off the host can reach it; the app tries it and goes on. nodo#655 asks
  `build_invite` to leave it out. The Share of the app does not add it: the app shares only the
  addresses where it reached the node.

## 8. Onion with the Tor client of the app (#140, 2026-11-13)

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

### The onion of the advertisement

When the app opens a session with a node, it checks the signed advertisement (`Peer`). The
onions in it join the addresses of the node (`CelautData::add_announced_addresses`), after
the ones that the app knows. Only a `Peer.Uri` counts whose transport has the tag
`tor-onion-v3`, whose host is a valid v3 onion name (the checksum and the version), whose
port is from 1 to 65535 and that has not expired (`expiry_unix_timestamp`, 0 for none), as
nodo reads it (`celaut_client::node_addresses::advertised_onions`). So a node first added
by its IP gets its onion, and the app keeps it: nodo announces the onion only while its Tor
is up.

The addresses of a node are tried in the order of the route
(`celaut_client::node_addresses::order`, 2026-11-14, Josemi): through Tor (the client of the
app or a proxy) the onions first, as for an invitation; on a direct route the onions last,
and an onion alone fails with "needs Tor". The node list (`celaut_known_nodes`), the
checks of the nodes, the overview and the nodes of a run use this order.

### A typed onion on a direct route

The app refuses it before the dial (`check_route`) with the error kind `OnionNeedsTor`, and
the screens show a localized hint (en and es): "An onion address needs Tor. Turn on Tor in
the network settings: the Tor client of the app or an external proxy such as Orbot." The
name is never looked up.

### Decisions (Josemi, 2026-11-14)

- 60 s for an onion attempt of an invitation stays.
- +2 MB per ABI is accepted, and the feature is always on (no build flag).
- An e2e with nodo's own onion service on a dedicated node is not needed.

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
- `node_addresses.rs`: the onion of an advertisement is read; only the `tor-onion-v3`
  transport with a valid v3 name and port counts; any case, no repeats; an expired onion is
  left out; the order through Tor and on a direct route. `db.rs`: an announced address goes
  after the known ones, once. `celaut_home.rs`: a typed onion on a direct route is
  `OnionNeedsTor` for adding a node, a new client and the node check, with no connection; a
  failing address says more than an onion that needs Tor; the node list shows the onions
  last on a direct route. `celaut_known_nodes_test.dart`: the hint, in place of the
  technical text.
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
- The onion of the advertisement (2026-11-14), the test node with nodo's own Tor
  (`routing.tor.ENABLED` and `ANNOUNCE` true) and the app on a direct route: after a check,
  the earlier build did not add the onion that the node announces, and a typed onion showed
  the generic error with the English detail; this build added the onion to the node, after
  its IP, and a typed onion showed only the hint. With "Tor inside the
  app" and the app started again: the onions first, the IP last; the node answered through
  the onion of its advertisement ("Slow · 16600 ms", then "Available · 789 ms"), on the
  onion gRPC server of nodo, and that onion became the first address of the node.
- nodo (dev `76dcac3b`) starts Tor before it configures the onion service
  (`routing.start_backends()` before `_start_onion_server` in `src/serve.py`). With Tor
  already installed, the torrc has no `HiddenServiceDir`: the node announces an onion that
  it does not host. For the check above, the onion service was added to the command line of
  Tor (the directory and the port that nodo would write).
- Not checked: a phone, Orbot.

