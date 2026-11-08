//! Transport of the Celaut Gateway for a client.
//!
//! - [`identity`]: reads the identity extension of a node certificate
//!   (`docs/celaut/wire.md`, section 1) and checks it. The check is a rustls
//!   `ServerCertVerifier`.
//! - [`channel`]: a TCP and TLS 1.3 connection that uses that verifier, and the tonic
//!   channel on it. It gives the `peer_id` of the node.
//! - [`transport`]: the [`Transport`] trait. One method sends bee-rpc parts to one
//!   Gateway method and returns the parts of the answer. A test can replace it.
//! - [`gateway`]: the typed calls of milestones M1 to M3.
//! - [`relay`]: the call that gives a service to a node, and stops when the node
//!   answers before the end (it already has the service).
//! - [`tunnel`]: `ServiceTunnel`, a byte stream to one port of an instance.
//! - [`statement`]: the balance statements of `GetBalanceStatement`: the request, its
//!   maximum cost, and the check of the signature, the chain and the `instance_ref`.
//! - [`receipt`]: the execution receipts that a node signs (nodo#419), and their check.
//!
//! Input from a peer must never make this crate panic.
#![forbid(unsafe_code)]
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

pub mod channel;
pub mod error;
pub mod gateway;
pub mod identity;
pub mod receipt;
pub mod relay;
pub mod skips;
pub mod statement;
pub mod transport;
pub mod tunnel;

pub use channel::{ConnectOptions, Connection};
pub use error::{IdentityError, WireError};
pub use skips::Skips;
pub use transport::{Buffers, RawAnswer, SendCounter, Skipper, Transport};
pub use tunnel::{ReceiptEvent, ReceiptSink, StreamReceipt, Tunnel, TunnelOpener};
