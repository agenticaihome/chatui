//! Connect to a node from the peer invitation of a QR code (`docs/celaut/invite.md`,
//! nodo#579).
//!
//! The invitation has the identity key of the node and its addresses. The app tries the
//! addresses that can work on the current route ([`celaut_client::invite::plan`]), in
//! order, and stops at the first node that proves the invited key: the TLS handshake fails
//! for any other key, so an address that another node holds is never used. Then the app
//! does what it does for a typed address (client id, advertisement, node list).

use std::time::Duration;

use celaut_client::invite::{self, InviteAddr, Skip, Via};

use super::celaut::{invalid, CelautError, CelautErrorKind};
use super::celaut_db::db;
use super::celaut_home::{list_node, KnownNodeView};
use super::celaut_network::{celaut_network_status, NetworkChoice};
use super::celaut_service::{forget_if_broken_key, key, session_pinned, NodeAddress};

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
}

/// One address of the invitation, in the order that the app used.
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
    let mut attempts = Vec::new();
    let mut node = None;
    for a in &plan.order {
        let address = NodeAddress {
            host: a.host.clone(),
            port: a.port,
        };
        match dial(address.clone(), parsed.peer_id.clone(), timeout).await {
            Ok(peer_id) => {
                node = Some(list_node(&peer_id, &key(&address))?);
                attempts.push(InviteAttemptView {
                    address: a.text(),
                    kind: InviteAttemptKind::Connected,
                    error: None,
                    message: String::new(),
                });
                break;
            }
            Err(e) => {
                forget_if_broken_key(&key(&address));
                attempts.push(InviteAttemptView {
                    address: a.text(),
                    kind: InviteAttemptKind::Failed,
                    error: Some(e.kind),
                    message: e.message,
                });
            }
        }
    }
    // The addresses that were not tried come after the tried ones.
    attempts.extend(plan.skipped.iter().map(|(a, why)| skipped(a, *why)));
    Ok(InviteConnectView {
        peer_id: parsed.peer_id,
        node,
        attempts,
    })
}

/// One address of an invitation, before any connection.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InviteAddrView {
    /// `host:port`, with brackets for IPv6.
    pub address: String,
    /// Why the app will not try it on the current route, or none if it will.
    pub skipped: Option<InviteAttemptKind>,
}

/// What an invitation says, read without any connection: for the confirmation that the
/// user sees before the app connects (a `celaut://` link, `docs/celaut/invite.md`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InviteReadView {
    /// The `peer_id` of the invitation: its key in lowercase hex.
    pub peer_id: String,
    /// The addresses that the app knows, in the order that it would use: the ones that it
    /// tries on the current route, then the ones that it skips.
    pub addresses: Vec<InviteAddrView>,
    /// True if the node is already in the node list.
    pub listed: bool,
}

/// Read the invitation `invite` without connecting: the key, the addresses and what the
/// app would do with each one on the current route. Bytes that are not an invitation are
/// an `InvalidInput` error.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_read_invite(invite: Vec<u8>) -> Result<InviteReadView, CelautError> {
    let parsed = invite::parse(&invite).map_err(|e| invalid(&e.to_string()))?;
    let listed = db().read(|d| d.nodes.get(&parsed.peer_id).is_some_and(|n| n.listed));
    Ok(read(parsed, via_now(), listed))
}

/// The part of [`celaut_read_invite`] that does not depend on the route of the app.
fn read(parsed: invite::Invite, via: Via, listed: bool) -> InviteReadView {
    let plan = invite::plan(&parsed.addrs, via);
    let mut addresses: Vec<InviteAddrView> = plan
        .order
        .iter()
        .map(|a| InviteAddrView {
            address: a.text(),
            skipped: None,
        })
        .collect();
    addresses.extend(plan.skipped.iter().map(|(a, why)| InviteAddrView {
        address: a.text(),
        skipped: Some(skipped(a, *why).kind),
    }));
    InviteReadView {
        peer_id: parsed.peer_id,
        addresses,
        listed,
    }
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
                    Err(refuse(CelautErrorKind::Timeout))
                } else {
                    Ok(p)
                }
            }
        })
        .await
        .unwrap();
        // Each try pins the invited key, and the third address is not asked.
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

    #[tokio::test]
    async fn bytes_that_are_not_an_invitation_are_refused() {
        let e = celaut_connect_invite(vec![1, 2, 3]).await.unwrap_err();
        assert_eq!(e.kind, CelautErrorKind::InvalidInput);
        let e = celaut_connect_invite(vec![]).await.unwrap_err();
        assert_eq!(e.kind, CelautErrorKind::InvalidInput);
    }

    #[test]
    fn reading_an_invitation_gives_the_addresses_in_the_order_of_the_route() {
        let peer = "ab".repeat(32);
        let parsed = invite_of(
            &peer,
            vec![
                addr(Kind::Ip4, "203.0.113.7", 1),
                addr(Kind::Onion, "x.onion", 2),
                addr(Kind::Ip4, "10.0.0.2", 3),
            ],
        );
        let direct = read(parsed.clone(), Via::Direct, false);
        assert_eq!(direct.peer_id, peer);
        assert!(!direct.listed);
        let shown: Vec<_> = direct
            .addresses
            .iter()
            .map(|a| (a.address.as_str(), a.skipped))
            .collect();
        assert_eq!(
            shown,
            [
                ("203.0.113.7:1", None),
                ("10.0.0.2:3", None),
                ("x.onion:2", Some(InviteAttemptKind::OnionNeedsProxy)),
            ]
        );
        let proxy = read(parsed, Via::TorProxy, true);
        assert!(proxy.listed);
        let shown: Vec<_> = proxy
            .addresses
            .iter()
            .map(|a| (a.address.as_str(), a.skipped))
            .collect();
        assert_eq!(
            shown,
            [
                ("x.onion:2", None),
                ("203.0.113.7:1", None),
                ("10.0.0.2:3", Some(InviteAttemptKind::PrivateOverTor)),
            ]
        );
    }

    #[test]
    fn reading_says_whether_the_node_is_in_the_list_and_refuses_junk() {
        // A real invitation: field 1 with a key of 32 bytes, and one ip4 address.
        let key = [0x5au8; 32];
        let mut addr_msg = vec![0x0a, 0x03];
        addr_msg.extend_from_slice(b"ip4");
        addr_msg.extend_from_slice(&[0x1a, 0x06, 192, 0, 2, 1, 0xd0, 0xd4]);
        let mut raw = vec![0x0a, 0x20];
        raw.extend_from_slice(&key);
        raw.push(0x12);
        raw.push(addr_msg.len() as u8);
        raw.extend_from_slice(&addr_msg);
        let peer = "5a".repeat(32);
        let view = celaut_read_invite(raw.clone()).unwrap();
        assert_eq!(view.peer_id, peer);
        assert_eq!(view.addresses.len(), 1);
        assert_eq!(view.addresses[0].address, "192.0.2.1:53460");
        assert!(!view.listed);
        db().update(|d| {
            d.nodes.insert(
                peer.clone(),
                NodeRecord {
                    client_id: "c-read-1".into(),
                    listed: true,
                    ..Default::default()
                },
            );
        })
        .unwrap();
        assert!(celaut_read_invite(raw).unwrap().listed);
        db().update(|d| {
            d.nodes.remove(&peer);
        })
        .unwrap();
        for junk in [vec![], vec![1, 2, 3], vec![0x0a, 0x20, 1]] {
            let e = celaut_read_invite(junk).unwrap_err();
            assert_eq!(e.kind, CelautErrorKind::InvalidInput);
        }
    }
}
