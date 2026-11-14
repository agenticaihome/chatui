//! Optional Tor for the outbound connections of the app (milestone M5).
//!
//! The user chooses a [`Mode`]:
//!
//! - [`Mode::Off`]: direct connections, as before.
//! - [`Mode::Embedded`]: an Arti client inside the app. It listens on a SOCKS5 port on
//!   the loopback, protected by a random user name and password, and everything that
//!   goes through `celaut_net` uses that port. It reaches `.onion` addresses too
//!   (`onion-service-client`).
//! - [`Mode::Socks`]: an external SOCKS5 proxy, for example Orbot.
//!
//! The rule of this crate: with Tor on, the app never connects directly. From the moment
//! that [`Manager::set_mode`] returns, the route of `celaut_net` is blocked until the
//! proxy is ready, and it is blocked again if the proxy fails.

mod arti;
mod manager;

pub use manager::{manager, Manager, Mode, ModeKind, State, Status};
