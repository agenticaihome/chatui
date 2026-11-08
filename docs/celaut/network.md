# Network route and Tor (M5)

By default the app connects to Celaut nodes, to the Ergo explorer and to GitHub (the
updater) from the phone, so each of them sees the IP address of the phone. With Tor on,
they see a Tor exit.

## What the user can choose (Settings, Compute, Tor)

| Choice | What it does |
|---|---|
| Off | Direct connections. The default |
| Tor inside the app | An Arti client (`arti-client`) in the app, behind a SOCKS5 port on the loopback. The first start takes about 15 seconds on a good network, and up to a minute |
| External SOCKS5 proxy | Any SOCKS5 proxy at an IP address and a port, for example Orbot at `127.0.0.1:9050`. The app trusts that it is a Tor proxy |

The choice is kept in the preferences and is applied at the start of the app, after
`RustLib.init` and before any other connection.

## What goes through Tor

Everything that the Rust core connects to:

- The TLS connection to a Celaut node (`celaut-wire`). The identity check of the node is
  the same on every route, so a node proves its identity through Tor too.
- Every HTTP request of the core (`wallet-net`'s `http::client_builder`): the Ergo explorer,
  the Ergo nodes, the catalog, token metadata. The environment proxies are never used.
- The updater of the app, the one part of the Dart side that makes its own HTTP requests
  (the check of the latest release and the download of the APK on GitHub). Its client is
  `routedHttpClient` (`app/lib/celaut/routed_http.dart`): it reads the route of the core
  (`celaut_network_proxy`) when it is built, and then connects directly, opens the
  connection through the SOCKS5 proxy (the proxy looks up the name, and the TLS of GitHub
  goes inside), or fails with the reason. Through the proxy it accepts HTTPS only.

- The statement reads and the tunnels of descendants (`GetBalanceStatement` with
  `instance_ref`, and `ServiceTunnel` with `DescendantTunnel`). They use the connection of
  the node that holds the instance, so they use its route. The code has no other dial for
  them. With Tor on, a descendant read or tunnel never opens a direct connection. The node
  that holds the instance asks the other nodes, not the phone, so Tor does not need to
  reach them.

What does not go through Tor: the system (for example the DNS of Android and the
connections of other apps).

## The rule: never direct

With Tor on, the app never falls back to a direct connection.

- From the moment that the choice is applied, every connection fails until the proxy is
  ready. The route is `Blocked`.
- If the proxy fails or stops, the route is `Blocked` again, with the reason.
- If the settings cannot be used (an address that is not an IP address and a port, or no
  private directory for the Tor state), the route is `Blocked` too. A wrong setting never
  becomes a direct connection.
- An HTTP client that was built before a change keeps the route that it had. The core
  builds its clients for each use. Only the cached clients of the Ergo nodes are kept, and
  the change of the route clears them.

## Limits

- A node on a private network (`10.0.2.2` of the emulator, `192.168.x.x`) cannot be reached
  through Tor. The app does not try such an address of a peer invitation on a Tor route
  ([invite.md](invite.md), section 3).
- Tor hides the IP address of the phone from the node. It does not hide the node, and a
  node still links the calls of one client id. Onion addresses for nodes are nodo work
  (decision 7 in `docs/celaut-plan.md`).
- The native library gets bigger with Arti.
- An open `ServiceTunnel` stream does not move when the route changes. It keeps the route
  that it had; a new connection uses the new one.

## Code

| Where | What |
|---|---|
| `rust/crates/celaut-net` | `Route` (`Direct`, `Socks`, `Blocked`), `connect`, and a small SOCKS5 client and server with user name and password. 10 tests |
| `rust/crates/celaut-tor` | `Manager`: the modes, the state, the Arti client and its SOCKS5 port. The port has a random user name and password, so another app on the phone cannot use it |
| `rust/crates/celaut-wire` | The TCP dial of a node goes through `celaut_net::connect` |
| `rust/crates/wallet-net` | `http::client_builder` follows the route |
| `rust/crates/wallet-ffi/src/api/celaut_network.rs` | `celaut_set_network`, `celaut_network_status`, and `celaut_network_proxy` (the route for the Dart side) |
| `app/lib/celaut/network_route.dart`, `app/lib/ui/celaut/network_screen.dart` | The setting, and the screen |
| `app/lib/celaut/routed_http.dart` | The HTTP client of the updater on the route: direct, a SOCKS5 client (RFC 1928 and 1929) under TLS, or blocked |

## Checks

- Each route has a test with a local server: direct, through the SOCKS5 proxy with a
  password, a wrong password, and blocked (`celaut-wire/tests/route.rs`,
  `wallet-net/tests/route.rs`).
- A real test on the Tor network is ignored in the CI because it needs the Internet:
  `cargo test -p celaut-tor --test real_tor -- --ignored --nocapture`. On 2026-10-15 it
  started Arti in 15 seconds, and a request through the HTTP client of the app got
  `{"IsTor":true}` from `check.torproject.org`.
- The client of the updater has tests with a local HTTPS server and a local SOCKS5 proxy
  with a password: direct, through the proxy, a wrong password, no proxy, blocked, and
  plain HTTP refused; in each failure nothing reaches the server
  (`app/test/celaut_routed_http_test.dart`).
- A test on a fake transport checks that a descendant read and a descendant tunnel use the
  transport of the session and no other (`celaut-client/tests/descendants.rs`). The real
  descendant test is ignored (`celaut-client/tests/real_node.rs`) and was not run through Tor.
- Not checked: a phone, Android (the Arti client builds for the Android targets in the CI,
  but it was not run there), the battery use, and a Celaut node through Tor.
