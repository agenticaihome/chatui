# Peer invitation in a QR code (2026-10-22)

nodo#579 (issue nodo#572, "QR for Chatui") lets a node show a compact invitation to itself as
a QR code: `nodo invite`, or `i` on the PEERS screen of its TUI. The app reads it and
connects to the node. This note says what the app reads and how it chooses an address.
It adds to the two text forms of [wire.md](wire.md), section 6, which stay. Section 6 is
the `celaut://` link that opens the app with an invitation (issue #138).

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

`celaut_connect_invite(bytes)` reads the invitation and tries the addresses that can work
**on the current route** (`celaut-client/src/invite.rs`, `plan`), in order, and stops at the
first node that proves the key.

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
longer). The tries are one after another, so the worst case with four unreachable
addresses on a direct route is 40 seconds.

## 4. Code

| Where | What |
|---|---|
| `rust/crates/celaut-proto/protos/invite.proto`, `src/gen/invite.rs` | The message, copied from nodo; `cargo run -p gen-protos` |
| `rust/crates/celaut-client/src/invite.rs` | `parse`, the formats of each tag, `plan` (the route rules), `is_private` |
| `rust/crates/wallet-ffi/src/api/celaut_invite.rs` | `celaut_connect_invite`, the attempts for the screen |
| `rust/crates/wallet-ffi/src/api/celaut_service.rs` | `session_pinned`: a session that only the invited key can open |
| `app/lib/celaut/invite_scan.dart`, `app/lib/ui/scan_screen.dart` | `ScannedCode`, `looksLikeInvite`, the binary scanner |
| `app/lib/ui/celaut/known_nodes_screen.dart` | The scan button, the confirmation, the result, the reason for each address |
| `rust/crates/wallet-ffi/src/api/celaut_invite.rs` | `celaut_read_invite`: the key and the addresses for the confirmation, with no connection |
| `app/lib/celaut/celaut_link.dart` | `parseCelautLink`: the `celaut://` link, its size checks and its base64 |
| `app/lib/ui/celaut/node_link.dart` | `openCelautLink`, the confirmation of an invitation or an address, the refusal |
| `app/android/.../OpenLinkActivity.kt`, `DeepLinkHandler.kt` | The intent filter of `celaut:` and the way of a link into the app |

## 5. Checks

- `invite.rs`: the vectors give the addresses that nodo gives, the refusals match, unknown
  tags are dropped, the onion name is the one of the key, junk never panics, and the private
  ranges and the route rules (one test per route).
- `celaut_invite.rs`: the first address that works stops the tries and each try pins the key;
  nothing works gives a reason for each address; no usable address asks nobody; a Tor proxy
  tries the onion first with the long timeout; bytes that are not an invitation are refused.
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

**On Android** `OpenLinkActivity` has the intent filter (VIEW, BROWSABLE, scheme `celaut`)
and gives the link to MainActivity in the task of the app, as `OpenPackageActivity` does
for a file: no second Flutter engine in the task of the camera app. `DeepLinkHandler` gives
it to Flutter (`argus/deeplink`, with the ErgoPay links); only the first 4097 characters of
a longer link cross the channel, enough to see that it is too long. A link that Android
gives again from the recent apps is not opened again.

**In the app** the home screen takes the link when it is ready; no wallet is needed. Then:

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

## 7. Open items

- **Onion with the Tor client of the app.** Arti is built without `onion-service-client`.
  With it, an onion address would work on the "Tor inside the app" route and would be first
  there too. It makes the native library bigger and the feature is experimental in Arti.
- **Race the addresses.** The app tries one after another. Trying the first two at the same
  time would save time when the first one hangs. Not built.
- **A screen that shares an invitation link.** The app opens links but makes none: nodo
  shows the QR code of bytes. `celautInviteLink` (Dart) writes the format, for the tests.
