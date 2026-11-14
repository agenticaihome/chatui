//! The network route of the app (milestone M5).
//!
//! Every outbound connection of the app asks this crate how to reach a host:
//!
//! - [`Route::Direct`]: a TCP connection from the phone, as before.
//! - [`Route::Socks`]: a SOCKS5 proxy. The host name goes to the proxy, so the phone does
//!   not look it up (SOCKS5 with a domain name, like `socks5h`). The proxy is an external
//!   one (Orbot) or the one that `celaut-tor` runs on the loopback.
//! - [`Route::Blocked`]: Tor is on but not ready, or it failed. Every connection fails.
//!   The app never falls back to a direct connection (`docs/celaut-plan.md`, M5).
//!
//! The route is one value for the whole process: [`set_route`] and [`route`].

mod route;
pub mod socks;

pub use route::{connect, is_onion, route, set_route, AsyncStream, BoxStream, Route, Socks5};
