//! Celaut client.
//!
//! Milestone M1: ask a node for its advertisement. The steps of [`fetch_node_info`]:
//!
//! 1. `GenerateClient`, with the proof of work if the node asks for it ([`pow`]).
//! 2. `GetPeerInfo`.
//! 3. Check the `Peer`: the signature, the key equal to the identity that the TLS
//!    certificate proved, and the `ts` against the last advertisement that this app
//!    accepted from that node ([`peer`], [`store`]).
//!
//! Milestone M2, on the free credit of a new client:
//!
//! - [`session`]: a [`NodeSession`] keeps the client id of one node and makes the calls
//!   of a service: quote, start, stop and balance.
//! - [`quotes`]: the quotes of several nodes, best first ([`celaut_balancer`]).
//! - [`local_port`]: a TCP port on 127.0.0.1 for one port of an instance. Each TCP
//!   connection is one `ServiceTunnel` stream.
//! - [`receipts`]: the execution receipts of the instances (nodo#419): their check when
//!   they come, the form that the database keeps, and the export.
//!
//! Milestone M3, a deposit in ERG:
//!
//! - [`deposit`]: the ERG payment contract of a node, the `Payment` of `Payable`, and the
//!   check of the deposit box on the explorer. The wallet makes the transaction.
//!
//! Milestone M4, the descendants of nodo#631:
//!
//! - [`descendants`]: the descendants of an instance, found in the `child_bound` rows of
//!   its statement. A statement read costs MU, so each read is one call with a `max_mu`
//!   that the user confirmed. Nothing reads by itself.
//!
//! Storage, for the whole app (`docs/celaut/ui.md`):
//!
//! - [`db`]: one encrypted database for all the Celaut data of the app (client ids,
//!   advertisements, instances and their tokens, deposits, quotes, the event log). No
//!   database per wallet, and no wallet key in it.
//! - [`overview`]: the sums of the compute overview (the offered resources per unique
//!   peer_id, and the credit on the nodes); a missing value is unknown, never 0.
//!
//! Input from a peer must never make this crate panic.
#![forbid(unsafe_code)]
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

pub mod db;
pub mod deposit;
pub mod descendants;
pub mod env;
pub mod health;
pub mod hibernation;
pub mod invite;
pub mod local_port;
pub mod overview;
pub mod package;
pub mod peer;
pub mod pow;
pub mod quotes;
pub mod receipts;
pub mod refusal;
pub mod service_info;
pub mod session;
pub mod store;

use celaut_proto::celaut::{Client, Peer};
use celaut_wire::gateway::{generate_client, get_peer_info, GenerateClientReply};
use celaut_wire::{ConnectOptions, Connection, Transport, WireError};

pub use db::{CelautData, CelautDb, DbError};
pub use deposit::{BtcPayment, DepositBox, DepositError, ErgPayment};
pub use health::{Availability, Health};
pub use local_port::LocalPort;
pub use peer::PeerError;
pub use quotes::{
    quotes, quotes_for, quotes_weighted, quotes_with, QuoteFailure, QuoteSkip, Quotes,
};
pub use refusal::{Refusal, ResourceRefusal};
pub use session::{NodeSession, StartedInstance};
pub use store::{FilePeerStore, MemoryPeerStore, PeerStore, Seen, StoreError};

/// Every error of this crate.
#[derive(Debug, thiserror::Error)]
pub enum ClientError {
    /// The connection or a call failed.
    #[error(transparent)]
    Wire(#[from] WireError),
    /// The advertisement of the node is not acceptable.
    #[error(transparent)]
    Peer(#[from] PeerError),
    /// The store of last-seen values failed.
    #[error(transparent)]
    Store(#[from] StoreError),
    /// The node asks for more work than this client does.
    #[error("the node asks for a proof of work of difficulty {0}, which is too much work")]
    PowTooHard(u32),
    /// The node did not accept the proof of work, or asked for it again.
    #[error("the node did not accept the proof of work")]
    PowRejected,
    /// The answer of the node is not usable.
    #[error("unexpected answer: {0}")]
    Protocol(String),
    /// No random numbers from the system.
    #[error("the system gave no random numbers")]
    Random,
    /// An amount of the node cannot be used.
    #[error(transparent)]
    Amount(#[from] celaut_balancer::BalancerError),
    /// A deposit cannot be made.
    #[error(transparent)]
    Deposit(#[from] DepositError),
    /// The resources of a hibernation or a wake are not usable. No call was made, or the
    /// answer of the node cannot be used to wake the instance later.
    #[error(transparent)]
    Resources(#[from] ResourcesError),
}

/// The longest message of the support chat, in bytes. It is the limit of nodo
/// (`chat.MAX_MESSAGE_BYTES`).
pub const MAX_SUPPORT_MESSAGE_BYTES: usize = 4096;

/// The resources of an instance are not usable to hibernate or wake it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
pub enum ResourcesError {
    /// A wake needs `cpu_quota`, `cpu_period` and `mem_limit`, all above 0. The node
    /// keeps the old value of a field that is not set, and a hibernated instance holds 0.
    /// The name is the first field that is not set or is 0. No call was made.
    #[error("the resources to wake the instance have no value above 0 for {0}")]
    WakeIncomplete(&'static str),
    /// The node answered the read of the current resources with 0 or no value for
    /// `cpu_quota`, `cpu_period` or `mem_limit`. The instance is hibernated, or the node
    /// has no value for it, so there are no resources to store for a wake.
    #[error("the node gave no resources above 0 for {0}: the instance has none to store")]
    NotReadable(&'static str),
}

/// The texts of a node that does not know the client id. nodo `dev` refuses the call in
/// `src/gateway/client_gate.py` (`require_caller`) with the first text; older nodes
/// raise the second one in `src/manager/manager.py`.
const UNKNOWN_CLIENT_TEXTS: [&str; 2] = [
    "requires a client_id minted by generateclient",
    "does not exists",
];

impl ClientError {
    /// The reason in the refusal of `ModifyServiceSystemResources` (hibernate, wake and
    /// the read of the resources), if the node refused it and the text is one that
    /// [`refusal::classify_resources`] knows.
    pub fn resource_refusal(&self) -> Option<ResourceRefusal> {
        match self {
            ClientError::Wire(WireError::Call(text)) => refusal::classify_resources(text),
            _ => None,
        }
    }

    /// True if the node says that the token of the instance is not one of its instances
    /// (see [`refusal::is_unknown_token`]).
    pub fn is_unknown_token(&self) -> bool {
        match self {
            ClientError::Wire(WireError::Call(text)) => refusal::is_unknown_token(text),
            _ => false,
        }
    }

    /// True if the node refused the call because it does not know the client id: the
    /// node forgot it, or never made it. The app must then ask the user what to do
    /// (`docs/celaut/ui.md`, section 3); it never makes a new client by itself.
    pub fn is_unknown_client(&self) -> bool {
        match self {
            ClientError::Wire(WireError::Call(text)) => {
                let lower = text.to_ascii_lowercase();
                lower.contains("client") && UNKNOWN_CLIENT_TEXTS.iter().any(|t| lower.contains(t))
            }
            _ => false,
        }
    }
}

#[cfg(test)]
mod unknown_client_tests {
    use super::*;

    #[test]
    fn the_refusal_of_an_unknown_client_is_found() {
        let dev = ClientError::Wire(WireError::Call(
            "status: Unknown, message: \"Exception calling application: This RPC requires \
             a client_id minted by GenerateClient first. Wrong or missing client_id: 'x'\""
                .into(),
        ));
        assert!(dev.is_unknown_client());
        let old = ClientError::Wire(WireError::Call("Client abc does not exists.".into()));
        assert!(old.is_unknown_client());
        // Other refusals are not this case.
        let other = ClientError::Wire(WireError::Call(
            "Client abc is calling too fast and is temporarily quarantined.".into(),
        ));
        assert!(!other.is_unknown_client());
        assert!(!ClientError::Wire(WireError::Timeout).is_unknown_client());
        assert!(!ClientError::Protocol("does not exists client".into()).is_unknown_client());
    }
}

/// The advertisement of a node, after the checks.
#[derive(Debug, Clone, PartialEq)]
pub struct NodeInfo {
    /// The identity of the node (Ed25519 key, 64 lowercase hex characters). It is the
    /// one that the TLS certificate proved.
    pub peer_id: String,
    /// The `Peer`, signed by that identity.
    pub peer: Peer,
}

/// A new client id: the 32 lowercase hex characters of a random UUID4.
pub fn new_client_id() -> Result<String, ClientError> {
    use ring::rand::{SecureRandom, SystemRandom};
    let mut bytes = [0u8; 16];
    SystemRandom::new()
        .fill(&mut bytes)
        .map_err(|_| ClientError::Random)?;
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    Ok(hex::encode(bytes))
}

/// `GenerateClient`, with the proof of work when the node asks for it. Gives the
/// client id.
pub async fn obtain_client_id<T: Transport>(transport: &T) -> Result<String, ClientError> {
    let proposed = new_client_id()?;
    let request = Client {
        client_id: proposed.clone(),
        ..Default::default()
    };
    let required = match generate_client(transport, &request).await? {
        GenerateClientReply::Client(client) => return accepted_client(client),
        GenerateClientReply::PowRequired(required) => required,
    };

    // The node uses the difficulty in the challenge, not its copy.
    let challenge = required.challenge;
    let difficulty = pow::challenge_difficulty(&challenge)
        .or_else(|| u32::try_from(required.difficulty).ok())
        .ok_or_else(|| ClientError::Protocol("the proof of work has no difficulty".into()))?;
    if difficulty > pow::MAX_DIFFICULTY {
        return Err(ClientError::PowTooHard(difficulty));
    }
    let work = challenge.clone();
    let solution = tokio::task::spawn_blocking(move || pow::solve_pow(&work, difficulty))
        .await
        .map_err(|e| ClientError::Protocol(format!("the proof of work stopped: {e}")))??;

    let retry = Client {
        client_id: proposed,
        challenge: Some(challenge),
        pow_solution: Some(solution),
        ..Default::default()
    };
    match generate_client(transport, &retry).await? {
        GenerateClientReply::Client(client) => accepted_client(client),
        GenerateClientReply::PowRequired(_) => Err(ClientError::PowRejected),
    }
}

fn accepted_client(client: Client) -> Result<String, ClientError> {
    if client.client_id.is_empty() {
        return Err(ClientError::Protocol(
            "the node gave an empty client id".into(),
        ));
    }
    Ok(client.client_id)
}

/// Get the `Peer` of the node on `transport` and check it. `certificate_peer_id` is the
/// identity that the TLS certificate proved.
///
/// The `ts` is stored only after every check passed.
pub async fn fetch_node_info<T: Transport>(
    transport: &T,
    certificate_peer_id: &str,
    store: &dyn PeerStore,
) -> Result<NodeInfo, ClientError> {
    let client_id = obtain_client_id(transport).await?;
    fetch_node_info_as(transport, &client_id, certificate_peer_id, store).await
}

/// [`fetch_node_info`] with a client id that the caller already has.
pub async fn fetch_node_info_as<T: Transport>(
    transport: &T,
    client_id: &str,
    certificate_peer_id: &str,
    store: &dyn PeerStore,
) -> Result<NodeInfo, ClientError> {
    let peer = get_peer_info(transport, client_id).await?;
    let digest = peer::verify_signature(&peer, certificate_peer_id)?;
    let last = store.get(certificate_peer_id)?;
    peer::check_ts(last.as_ref(), peer.ts, &digest)?;
    store.put(
        certificate_peer_id,
        Seen {
            ts: peer.ts,
            digest,
        },
    )?;
    Ok(NodeInfo {
        peer_id: certificate_peer_id.to_string(),
        peer,
    })
}

/// Connect to `host:port`, check the certificate, and call [`fetch_node_info`].
pub async fn connect_and_fetch(
    host: &str,
    port: u16,
    options: ConnectOptions,
    store: &dyn PeerStore,
) -> Result<NodeInfo, ClientError> {
    let connection = Connection::connect(host, port, options).await?;
    fetch_node_info(&connection, connection.peer_id(), store).await
}
