//! Connect to a node from the peer invitation of a QR code (`docs/celaut/invite.md`,
//! nodo#579).
//!
//! The invitation has the identity key of the node and its addresses. The app races the
//! addresses that can work on the current route ([`celaut_client::invite::plan`]), two at
//! a time in their order ([`celaut_client::race`]), and uses the first node that proves
//! the invited key: the TLS handshake fails for any other key, so an address that another
//! node holds is never used. Then the app does what it does for a typed address (client
//! id, advertisement, node list).

use std::time::Duration;

use celaut_client::invite::{self, InviteAddr, Skip, Via};
use celaut_client::race::{self, race, Outcome};

use super::celaut::{invalid, CelautError, CelautErrorKind};
use super::celaut_home::{list_node, KnownNodeView};
use super::celaut_network::{celaut_network_status, NetworkChoice};
use super::celaut_service::{
    close_unused, forget_if_broken_key, is_open, key, session_pinned, NodeAddress,
};

/// The dial and the handshake of a direct connection.
const DIRECT_TIMEOUT: Duration = Duration::from_secs(10);
/// Through Tor a circuit takes longer.
const TOR_TIMEOUT: Duration = Duration::from_secs(45);

/// What happened with one address of the invitation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InviteAttemptKind {
    /// The node proved the invited key and is in the node list.
    Connected,
    /// Not tried: an onion address needs a Tor proxy that resolves them, and the route
    /// is direct or the Tor client of the app.
    OnionNeedsProxy,
    /// Not tried: a private network address cannot be reached through Tor.
    PrivateOverTor,
    /// Tried and failed: `error` and `message` say why.
    Failed,
    /// Tried at the same time as another address, which connected first: this one was
    /// stopped, or it connected too but after an address before it in the order.
    NotNeeded,
}

/// One address of the invitation. The tried ones are in the order of preference.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InviteAttemptView {
    /// `host:port`, with brackets for IPv6.
    pub address: String,
    pub kind: InviteAttemptKind,
    /// The kind of the error. Only for `Failed`.
    pub error: Option<CelautErrorKind>,
    /// The technical reason, in English. Only for `Failed`.
    pub message: String,
}

/// The result of reading an invitation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InviteConnectView {
    /// The `peer_id` of the invitation: its key in lowercase hex.
    pub peer_id: String,
    /// The node, if one address worked. It is in the node list.
    pub node: Option<KnownNodeView>,
    /// What happened with each address that the app knows, the ones that it tried first.
    pub attempts: Vec<InviteAttemptView>,
}

fn via_now() -> Via {
    match celaut_network_status().choice {
        NetworkChoice::Off => Via::Direct,
        NetworkChoice::Embedded => Via::TorEmbedded,
        NetworkChoice::Socks => Via::TorProxy,
    }
}

fn skipped(a: &InviteAddr, why: Skip) -> InviteAttemptView {
    InviteAttemptView {
        address: a.text(),
        kind: match why {
            Skip::OnionNeedsProxy => InviteAttemptKind::OnionNeedsProxy,
            Skip::PrivateOverTor => InviteAttemptKind::PrivateOverTor,
        },
        error: None,
        message: String::new(),
    }
}

/// Read the invitation `invite` (the bytes of the QR code) and connect to the node that it
/// names, by the first address that works on the current route. A node that proves the
/// invited key is added to the node list, with the address that worked first. If no
/// address works, `node` is none and `attempts` says why for each one. Bytes that are not
/// an invitation are an `InvalidInput` error.
///
/// If the node forgot the client id of the app, the attempt fails with `ClientUnknown`
/// and the screen asks the user, as for a typed address.
#[flutter_rust_bridge::frb]
pub async fn celaut_connect_invite(invite: Vec<u8>) -> Result<InviteConnectView, CelautError> {
    let parsed = invite::parse(&invite).map_err(|e| invalid(&e.to_string()))?;
    connect(parsed, via_now(), |address, peer_id, timeout| async move {
        session_pinned(&address, &peer_id, timeout)
            .await
            .map(|s| s.peer_id().to_string())
    })
    .await
}

/// The part of [`celaut_connect_invite`] that does not depend on the network: tests give
/// their own `dial`.
async fn connect<F, Fut>(
    parsed: invite::Invite,
    via: Via,
    dial: F,
) -> Result<InviteConnectView, CelautError>
where
    F: Fn(NodeAddress, String, Duration) -> Fut,
    Fut: std::future::Future<Output = Result<String, CelautError>>,
{
    let plan = invite::plan(&parsed.addrs, via);
    let timeout = if via == Via::Direct {
        DIRECT_TIMEOUT
    } else {
        TOR_TIMEOUT
    };
    let addresses: Vec<NodeAddress> = plan
        .order
        .iter()
        .map(|a| NodeAddress {
            host: a.host.clone(),
            port: a.port,
        })
        .collect();
    let was_open: Vec<bool> = addresses.iter().map(|a| is_open(&key(a))).collect();
    let outcomes = race(addresses.len(), race::WIDTH, race::GRACE, |i| {
        dial(addresses[i].clone(), parsed.peer_id.clone(), timeout)
    })
    .await;
    let used = outcomes
        .iter()
        .position(|o| matches!(o, Outcome::Won(_)))
        .map(|i| key(&addresses[i]))
        .unwrap_or_default();
    let mut attempts = Vec::new();
    let mut node = None;
    for (i, outcome) in outcomes.into_iter().enumerate() {
        let (a, k) = (&plan.order[i], key(&addresses[i]));
        let (kind, error, message) = match outcome {
            Outcome::NotStarted => continue,
            Outcome::Won(peer_id) => {
                node = Some(list_node(&peer_id, &k)?);
                (InviteAttemptKind::Connected, None, String::new())
            }
            Outcome::Failed(e) => {
                if k != used {
                    forget_if_broken_key(&k);
                }
                (InviteAttemptKind::Failed, Some(e.kind), e.message)
            }
            Outcome::Unused(_) => {
                close_unused(&k, was_open[i], &used);
                (InviteAttemptKind::NotNeeded, None, String::new())
            }
            Outcome::Stopped => (InviteAttemptKind::NotNeeded, None, String::new()),
        };
        attempts.push(InviteAttemptView {
            address: a.text(),
            kind,
            error,
            message,
        });
    }
    // The addresses that were not tried come after the tried ones.
    attempts.extend(plan.skipped.iter().map(|(a, why)| skipped(a, *why)));
    Ok(InviteConnectView {
        peer_id: parsed.peer_id,
        node,
        attempts,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::celaut_db::db;
    use celaut_client::db::NodeRecord;
    use celaut_client::invite::{Invite, Kind};
    use std::sync::Mutex;

    fn addr(kind: Kind, host: &str, port: u16) -> InviteAddr {
        InviteAddr {
            kind,
            host: host.into(),
            port,
        }
    }

    fn invite_of(peer_id: &str, addrs: Vec<InviteAddr>) -> Invite {
        Invite {
            peer_id: peer_id.into(),
            addrs,
        }
    }

    fn refuse(kind: CelautErrorKind) -> CelautError {
        CelautError {
            kind,
            message: "no".into(),
        }
    }

    #[tokio::test]
    async fn the_first_address_that_works_is_used_and_the_next_ones_are_not_tried() {
        let peer = "aa".repeat(32);
        db().update(|d| {
            d.nodes.insert(
                peer.clone(),
                NodeRecord {
                    client_id: "c-invite-1".into(),
                    listed: false,
                    ..Default::default()
                },
            );
        })
        .unwrap();
        let asked = Mutex::new(Vec::new());
        let parsed = invite_of(
            &peer,
            vec![
                addr(Kind::Ip4, "203.0.113.7", 1),
                addr(Kind::Dns, "node.example.org", 2),
                addr(Kind::Ip4, "203.0.113.8", 3),
            ],
        );
        let p = peer.clone();
        let view = connect(parsed, Via::Direct, |address, expected, _| {
            asked.lock().unwrap().push((address.port, expected));
            let p = p.clone();
            async move {
                if address.port == 1 {
                    // It fails while the second one is in its grace.
                    tokio::time::sleep(Duration::from_millis(50)).await;
                    Err(refuse(CelautErrorKind::Timeout))
                } else {
                    Ok(p)
                }
            }
        })
        .await
        .unwrap();
        // The first two start at the same time, each try pins the invited key, and the
        // third address is not asked.
        assert_eq!(
            *asked.lock().unwrap(),
            vec![(1, peer.clone()), (2, peer.clone())]
        );
        let node = view.node.unwrap();
        assert_eq!(node.peer_id, peer);
        assert_eq!(node.addresses[0], "node.example.org:2");
        let kinds: Vec<_> = view
            .attempts
            .iter()
            .map(|a| (a.address.as_str(), a.kind))
            .collect();
        assert_eq!(
            kinds,
            [
                ("203.0.113.7:1", InviteAttemptKind::Failed),
                ("node.example.org:2", InviteAttemptKind::Connected),
            ]
        );
        assert_eq!(view.attempts[0].error, Some(CelautErrorKind::Timeout));
        // A node that was removed from the list comes back.
        assert!(db().read(|d| d.nodes[&peer].listed));
    }

    #[tokio::test]
    async fn when_nothing_works_each_address_says_why_and_no_node_is_listed() {
        let parsed = invite_of(
            &"bb".repeat(32),
            vec![
                addr(Kind::Onion, "x.onion", 1),
                addr(Kind::Ip4, "203.0.113.7", 2),
                addr(Kind::Ip6, "fd00::1", 3),
            ],
        );
        let view = connect(parsed, Via::TorEmbedded, |_, _, _| async {
            Err(refuse(CelautErrorKind::IdentityMismatch))
        })
        .await
        .unwrap();
        assert!(view.node.is_none());
        let got: Vec<_> = view
            .attempts
            .iter()
            .map(|a| (a.address.as_str(), a.kind))
            .collect();
        // The tried address first, then the ones that cannot work on this route.
        assert_eq!(
            got,
            [
                ("203.0.113.7:2", InviteAttemptKind::Failed),
                ("x.onion:1", InviteAttemptKind::OnionNeedsProxy),
                ("[fd00::1]:3", InviteAttemptKind::PrivateOverTor),
            ]
        );
        assert_eq!(
            view.attempts[0].error,
            Some(CelautErrorKind::IdentityMismatch)
        );
    }

    #[tokio::test]
    async fn an_invitation_with_no_usable_address_asks_nobody() {
        let asked = Mutex::new(0);
        let view = connect(
            invite_of(&"cc".repeat(32), vec![]),
            Via::Direct,
            |_, _, _| {
                *asked.lock().unwrap() += 1;
                async { Ok(String::new()) }
            },
        )
        .await
        .unwrap();
        assert_eq!(*asked.lock().unwrap(), 0);
        assert!(view.node.is_none() && view.attempts.is_empty());
    }

    #[tokio::test]
    async fn a_tor_proxy_tries_the_onion_first_and_with_a_longer_timeout() {
        let seen = Mutex::new(Vec::new());
        let parsed = invite_of(
            &"dd".repeat(32),
            vec![
                addr(Kind::Ip4, "203.0.113.7", 1),
                addr(Kind::Onion, "x.onion", 2),
            ],
        );
        let _ = connect(parsed, Via::TorProxy, |a, _, t| {
            seen.lock().unwrap().push((a.port, t));
            async { Err(refuse(CelautErrorKind::Unreachable)) }
        })
        .await
        .unwrap();
        assert_eq!(
            *seen.lock().unwrap(),
            vec![(2, TOR_TIMEOUT), (1, TOR_TIMEOUT)]
        );
    }

    /// The record that a real session would leave in the database.
    fn known(peer: &str) {
        db().update(|d| {
            d.nodes.insert(
                peer.to_string(),
                NodeRecord {
                    client_id: format!("c-{peer}"),
                    ..Default::default()
                },
            );
        })
        .unwrap();
    }

    fn kinds(view: &InviteConnectView) -> Vec<(&str, InviteAttemptKind)> {
        view.attempts
            .iter()
            .map(|a| (a.address.as_str(), a.kind))
            .collect()
    }

    #[tokio::test]
    async fn a_first_address_that_hangs_does_not_hold_up_a_fast_second_one() {
        let peer = "e1".repeat(32);
        known(&peer);
        let parsed = invite_of(
            &peer,
            vec![
                addr(Kind::Ip4, "203.0.113.7", 1),
                addr(Kind::Ip4, "198.51.100.9", 2),
            ],
        );
        let started = std::time::Instant::now();
        let p = peer.clone();
        let view = connect(parsed, Via::Direct, |address, _, timeout| {
            let p = p.clone();
            async move {
                if address.port == 1 {
                    // A slow address: it would answer only at the end of its timeout.
                    tokio::time::sleep(timeout).await;
                    Err(refuse(CelautErrorKind::Timeout))
                } else {
                    tokio::time::sleep(Duration::from_millis(20)).await;
                    Ok(p)
                }
            }
        })
        .await
        .unwrap();
        // One after another this took the 10 seconds of the first address first.
        assert!(started.elapsed() < Duration::from_secs(2), "{:?}", started.elapsed());
        assert_eq!(view.node.as_ref().unwrap().addresses[0], "198.51.100.9:2");
        assert_eq!(
            kinds(&view),
            [
                ("203.0.113.7:1", InviteAttemptKind::NotNeeded),
                ("198.51.100.9:2", InviteAttemptKind::Connected),
            ]
        );
        assert_eq!(view.attempts[0].error, None);
    }

    #[tokio::test]
    async fn the_order_of_the_invitation_wins_when_both_answer_at_nearly_the_same_time() {
        let peer = "e2".repeat(32);
        known(&peer);
        let parsed = invite_of(
            &peer,
            vec![
                addr(Kind::Ip4, "203.0.113.7", 1),
                addr(Kind::Ip4, "198.51.100.9", 2),
            ],
        );
        let p = peer.clone();
        let view = connect(parsed, Via::Direct, |address, _, _| {
            let p = p.clone();
            async move {
                // The second answers a little sooner than the first.
                let ms = if address.port == 1 { 60 } else { 30 };
                tokio::time::sleep(Duration::from_millis(ms)).await;
                Ok(p)
            }
        })
        .await
        .unwrap();
        assert_eq!(view.node.as_ref().unwrap().addresses[0], "203.0.113.7:1");
        assert_eq!(
            kinds(&view),
            [
                ("203.0.113.7:1", InviteAttemptKind::Connected),
                ("198.51.100.9:2", InviteAttemptKind::NotNeeded),
            ]
        );
    }

    #[tokio::test]
    async fn never_more_than_two_addresses_at_a_time() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        let now = AtomicUsize::new(0);
        let most = AtomicUsize::new(0);
        let parsed = invite_of(
            &"e3".repeat(32),
            (1..=5)
                .map(|port| addr(Kind::Ip4, "203.0.113.7", port))
                .collect(),
        );
        let view = connect(parsed, Via::Direct, |address, _, _| {
            let (now, most) = (&now, &most);
            async move {
                let n = now.fetch_add(1, Ordering::SeqCst) + 1;
                most.fetch_max(n, Ordering::SeqCst);
                tokio::time::sleep(Duration::from_millis(5 * u64::from(address.port))).await;
                now.fetch_sub(1, Ordering::SeqCst);
                Err(refuse(CelautErrorKind::Unreachable))
            }
        })
        .await
        .unwrap();
        assert_eq!(most.load(Ordering::SeqCst), 2);
        assert!(view.node.is_none());
        // Every address failed, and the screen lists them in the order of the invitation.
        let ports: Vec<_> = view.attempts.iter().map(|a| a.address.clone()).collect();
        assert_eq!(
            ports,
            (1..=5)
                .map(|p| format!("203.0.113.7:{p}"))
                .collect::<Vec<_>>()
        );
        assert!(view
            .attempts
            .iter()
            .all(|a| a.kind == InviteAttemptKind::Failed));
    }

    /// The race against a real node (#139). `CELAUT_RACE_HANG` is a `host:port` that
    /// accepts the TCP connection and never answers; `CELAUT_RACE_NODE` is the `host:port`
    /// of a running node. The app makes a client on that node (free credit, no payment).
    ///
    /// `cargo test -p wallet-ffi --lib real_node_race -- --ignored --nocapture`
    #[tokio::test]
    #[ignore = "needs a running node and an address that hangs; see the comment"]
    async fn real_node_race() {
        use super::super::celaut_home::reach_within;
        use super::super::celaut_service::{address_of_key, session};
        let hang = std::env::var("CELAUT_RACE_HANG").expect("CELAUT_RACE_HANG");
        let real = std::env::var("CELAUT_RACE_NODE").expect("CELAUT_RACE_NODE");
        let (h, n) = (address_of_key(&hang).unwrap(), address_of_key(&real).unwrap());
        let peer = session(&n).await.expect("the node").peer_id().to_string();
        forget_if_broken_key(&real);
        let invite = |peer: &str| {
            invite_of(
                peer,
                vec![
                    addr(Kind::Ip4, &h.host, h.port),
                    addr(Kind::Ip4, &n.host, n.port),
                ],
            )
        };
        let dial = |address: NodeAddress, peer_id: String, timeout| async move {
            session_pinned(&address, &peer_id, timeout)
                .await
                .map(|s| s.peer_id().to_string())
        };

        // The invitation: the hanging address is first.
        let t0 = std::time::Instant::now();
        let view = connect(invite(&peer), Via::Direct, dial).await.unwrap();
        let raced = t0.elapsed();
        println!("invite, raced:   {raced:?} {:?}", kinds(&view));
        assert_eq!(view.node.as_ref().unwrap().peer_id, peer);
        assert_eq!(
            kinds(&view),
            [
                (hang.as_str(), InviteAttemptKind::NotNeeded),
                (real.as_str(), InviteAttemptKind::Connected),
            ]
        );
        assert!(raced < DIRECT_TIMEOUT / 2, "{raced:?}");

        // The same two, one after another (the old way), for comparison.
        forget_if_broken_key(&real);
        let t0 = std::time::Instant::now();
        let old = race(2, 1, race::GRACE, |i| {
            let a = if i == 0 { h.clone() } else { n.clone() };
            dial(a, peer.clone(), DIRECT_TIMEOUT)
        })
        .await;
        let one_by_one = t0.elapsed();
        println!(
            "invite, one by one: {one_by_one:?} {:?}",
            old.iter().map(Outcome::started).collect::<Vec<_>>()
        );
        assert!(matches!(old[1], Outcome::Won(_)));
        assert!(one_by_one >= DIRECT_TIMEOUT);

        // A node of the node list (compute overview, checks of the nodes).
        forget_if_broken_key(&real);
        let t0 = std::time::Instant::now();
        let r = reach_within(&peer, &[hang.clone(), real.clone()], Duration::from_secs(5)).await;
        let reached = t0.elapsed();
        println!(
            "node list, raced: {reached:?} address {} latency {} ms credit {:?}",
            r.address, r.latency_ms, r.credit_mu
        );
        assert!(r.session.is_some() && r.error.is_none());
        assert_eq!(r.address, real);
        assert!(reached < Duration::from_secs(4), "{reached:?}");
    }

    #[tokio::test]
    async fn bytes_that_are_not_an_invitation_are_refused() {
        let e = celaut_connect_invite(vec![1, 2, 3]).await.unwrap_err();
        assert_eq!(e.kind, CelautErrorKind::InvalidInput);
        let e = celaut_connect_invite(vec![]).await.unwrap_err();
        assert_eq!(e.kind, CelautErrorKind::InvalidInput);
    }
}
