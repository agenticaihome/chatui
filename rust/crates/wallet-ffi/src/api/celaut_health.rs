//! Whether the nodes of the app are available (milestone M4).
//!
//! Each node of the node list has a record of its last checks in the Celaut database
//! (`celaut_client::health`): when, how fast, and why a check failed. The overview of the
//! home screen records one check for each node that it asks. [`celaut_check_nodes`] asks
//! the nodes that are due, at the same time and with a short limit, so that the app can
//! check from time to time without the whole overview. A node that fails is asked later
//! and later.
//!
//! A check is not made while the route is blocked (Tor is starting or failed): the node
//! is not at fault.

use std::time::Duration;

use celaut_client::health::{Availability, Health, CHECK_TIMEOUT_S, CHECK_TIMEOUT_TOR_S};
use celaut_net::Route;

use super::celaut::{CelautError, CelautErrorKind};
use super::celaut_db::{db, now_seconds};
use super::celaut_home::{reach_within, Reached};

/// What the checks say about a node.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NodeAvailability {
    /// The node was never checked.
    Unknown,
    /// The last check worked.
    Available,
    /// The last check worked and was slow.
    Slow,
    /// The last check failed.
    Unreachable,
}

/// The state of one node from its checks.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodeHealthView {
    pub peer_id: String,
    /// The address (`host:port`) that the app uses first for this node.
    pub address: String,
    pub availability: NodeAvailability,
    /// How long the last working check took, in milliseconds.
    pub latency_ms: Option<u32>,
    /// The time of the last check, in Unix seconds. 0 if there was none.
    pub checked_at: i64,
    /// The time of the last check that worked, in Unix seconds. 0 if there was none.
    pub last_ok_at: i64,
    /// How many checks failed in a row.
    pub failures: u32,
    /// Why the last check failed.
    pub error_kind: Option<CelautErrorKind>,
    /// The text of the last failure, from the node or from the transport.
    pub error: Option<String>,
    /// The time when the next check is due, in Unix seconds.
    pub next_check_at: i64,
}

/// True if the connections go through Tor or another proxy: they are slower.
fn through_proxy() -> bool {
    !matches!(celaut_net::route(), Route::Direct)
}

fn limit() -> Duration {
    Duration::from_secs(if through_proxy() {
        CHECK_TIMEOUT_TOR_S
    } else {
        CHECK_TIMEOUT_S
    })
}

/// The name that the database keeps for an error kind.
fn kind_name(kind: CelautErrorKind) -> &'static str {
    use CelautErrorKind as K;
    match kind {
        K::InvalidInput => "InvalidInput",
        K::Unreachable => "Unreachable",
        K::Timeout => "Timeout",
        K::IdentityMismatch => "IdentityMismatch",
        K::BadCertificate => "BadCertificate",
        K::BadSignature => "BadSignature",
        K::StaleTimestamp => "StaleTimestamp",
        K::UnsupportedScheme => "UnsupportedScheme",
        K::ProofOfWork => "ProofOfWork",
        K::Protocol => "Protocol",
        K::Storage => "Storage",
        K::LimitReached => "LimitReached",
        K::Wallet => "Wallet",
        K::ClientUnknown => "ClientUnknown",
        K::NodeClosed => "NodeClosed",
        K::NoRoom => "NoRoom",
        K::ServiceMissing => "ServiceMissing",
        K::PolicyRefused => "PolicyRefused",
        K::UnsupportedArchitecture => "UnsupportedArchitecture",
        K::RateLimited => "RateLimited",
        K::RecursionLimit => "RecursionLimit",
        K::InsufficientCredit => "InsufficientCredit",
        K::LaunchFailed => "LaunchFailed",
        K::TransferFailed => "TransferFailed",
        K::NoDescendants => "NoDescendants",
    }
}

fn kind_from_name(name: &str) -> Option<CelautErrorKind> {
    use CelautErrorKind as K;
    [
        K::InvalidInput,
        K::Unreachable,
        K::Timeout,
        K::IdentityMismatch,
        K::BadCertificate,
        K::BadSignature,
        K::StaleTimestamp,
        K::UnsupportedScheme,
        K::ProofOfWork,
        K::Protocol,
        K::Storage,
        K::LimitReached,
        K::Wallet,
        K::ClientUnknown,
        K::NodeClosed,
        K::NoRoom,
        K::ServiceMissing,
        K::PolicyRefused,
        K::UnsupportedArchitecture,
        K::RateLimited,
        K::RecursionLimit,
        K::InsufficientCredit,
        K::LaunchFailed,
        K::TransferFailed,
        K::NoDescendants,
    ]
    .into_iter()
    .find(|k| kind_name(*k) == name)
}

/// An error after which the node did answer: the node is up.
fn node_answered(error: &CelautError) -> bool {
    matches!(
        error.kind,
        CelautErrorKind::ClientUnknown | CelautErrorKind::RateLimited
    )
}

/// Put what a [`reach`](super::celaut_home) says into the record of each node. Nothing is
/// recorded while the route is blocked.
pub(crate) fn record<'a>(reached: impl Iterator<Item = (&'a str, &'a Reached)>, now: i64) {
    if matches!(celaut_net::route(), Route::Blocked(_)) {
        return;
    }
    let results: Vec<(String, Result<u32, (CelautErrorKind, String)>)> = reached
        .map(|(peer_id, r)| {
            let outcome = match &r.error {
                None => Ok(r.latency_ms),
                Some(e) if node_answered(e) => Ok(r.latency_ms),
                Some(e) => Err((e.kind, e.message.clone())),
            };
            (peer_id.to_string(), outcome)
        })
        .collect();
    let stored = db().update(|d| {
        for (peer_id, outcome) in &results {
            let Some(node) = d.nodes.get_mut(peer_id) else {
                continue;
            };
            match outcome {
                Ok(latency) => node.health.record_ok(now, *latency),
                Err((kind, text)) => node.health.record_failure(now, kind_name(*kind), text),
            }
        }
    });
    if let Err(e) = stored {
        tracing::warn!("the checks of the nodes are not stored: {e}");
    }
}

fn availability_of(a: Availability) -> NodeAvailability {
    match a {
        Availability::Unknown => NodeAvailability::Unknown,
        Availability::Available => NodeAvailability::Available,
        Availability::Slow => NodeAvailability::Slow,
        Availability::Unreachable => NodeAvailability::Unreachable,
    }
}

fn view_of(peer_id: &str, addresses: &[String], health: &Health) -> NodeHealthView {
    NodeHealthView {
        peer_id: peer_id.to_string(),
        address: addresses.first().cloned().unwrap_or_default(),
        availability: availability_of(health.availability()),
        latency_ms: health.latency_ms,
        checked_at: health.checked_at,
        last_ok_at: health.last_ok_at,
        failures: health.failures,
        error_kind: health.error_kind.as_deref().and_then(kind_from_name),
        error: health.error.clone(),
        next_check_at: health.next_check_at(through_proxy()),
    }
}

/// The nodes of the node list with what their last checks say. It makes no connection.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_nodes_health() -> Vec<NodeHealthView> {
    db().read(|d| {
        d.nodes
            .iter()
            .filter(|(_, n)| n.listed)
            .map(|(peer_id, n)| view_of(peer_id, &n.addresses, &n.health))
            .collect()
    })
}

/// Check the nodes of the node list that are due (all of them if `force`), at the same
/// time, and give the state of every node. A check asks the node for its advertisement and
/// the balance of the client, with a limit of 5 seconds (25 seconds through Tor). A node
/// that fails is due again after a time that grows with each failure, up to 15 minutes
/// (45 through Tor). Nothing is checked while Tor is starting or has failed.
#[flutter_rust_bridge::frb]
pub async fn celaut_check_nodes(force: bool) -> Vec<NodeHealthView> {
    if !matches!(celaut_net::route(), Route::Blocked(_)) {
        let now = now_seconds();
        let proxy = through_proxy();
        let due: Vec<(String, Vec<String>)> = db().read(|d| {
            d.nodes
                .iter()
                .filter(|(_, n)| n.listed && (force || n.health.is_due(now, proxy)))
                .map(|(peer_id, n)| {
                    let mut addresses = n.addresses.clone();
                    addresses.dedup();
                    (peer_id.clone(), addresses)
                })
                .collect()
        });
        let limit = limit();
        let checks = due
            .iter()
            .map(|(peer_id, addresses)| async move {
                (peer_id.as_str(), reach_within(addresses, limit).await)
            });
        let reached = futures::future::join_all(checks).await;
        record(reached.iter().map(|(p, r)| (*p, r)), now_seconds());
    }
    celaut_nodes_health()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_error_kind_has_a_name_that_comes_back() {
        for name in [
            "InvalidInput", "Unreachable", "Timeout", "IdentityMismatch", "BadCertificate",
            "BadSignature", "StaleTimestamp", "UnsupportedScheme", "ProofOfWork", "Protocol",
            "Storage", "LimitReached", "Wallet", "ClientUnknown", "NodeClosed", "NoRoom",
            "ServiceMissing", "PolicyRefused", "UnsupportedArchitecture", "RateLimited",
            "RecursionLimit", "InsufficientCredit", "LaunchFailed", "TransferFailed",
            "NoDescendants",
        ] {
            let kind = kind_from_name(name).unwrap_or_else(|| panic!("{name}"));
            assert_eq!(kind_name(kind), name);
        }
        assert_eq!(kind_from_name("Nothing"), None);
        assert_eq!(kind_from_name(""), None);
    }

    #[test]
    fn a_node_that_answered_with_a_refusal_is_up() {
        let e = |kind| CelautError { kind, message: String::new() };
        assert!(node_answered(&e(CelautErrorKind::ClientUnknown)));
        assert!(node_answered(&e(CelautErrorKind::RateLimited)));
        for kind in [
            CelautErrorKind::Unreachable,
            CelautErrorKind::Timeout,
            CelautErrorKind::IdentityMismatch,
            CelautErrorKind::BadCertificate,
        ] {
            assert!(!node_answered(&e(kind)), "{kind:?}");
        }
    }

    #[test]
    fn the_view_of_a_record() {
        let mut health = Health::default();
        let unknown = view_of("p", &["a:1".into(), "b:2".into()], &health);
        assert_eq!(unknown.availability, NodeAvailability::Unknown);
        assert_eq!(unknown.address, "a:1");
        health.record_ok(100, 40);
        let ok = view_of("p", &[], &health);
        assert_eq!((ok.availability, ok.latency_ms, ok.address.as_str()), (NodeAvailability::Available, Some(40), ""));
        health.record_failure(200, "Timeout", "the node did not answer in time");
        let down = view_of("p", &["a:1".into()], &health);
        assert_eq!(down.availability, NodeAvailability::Unreachable);
        assert_eq!(down.error_kind, Some(CelautErrorKind::Timeout));
        assert_eq!(down.last_ok_at, 100);
        assert_eq!(down.failures, 1);
    }
}
