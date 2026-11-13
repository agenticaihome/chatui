//! The peer invitation of a QR code (`docs/celaut/invite.md`, nodo#579).
//!
//! A node shows `PeerInvite` (`protos/invite.proto`) as a QR code in byte mode. It holds
//! the identity key of the node and where to reach it, and nothing else: the app connects,
//! checks that the other end holds the key, and then reads the signed advertisement as for
//! any node. The address is never trusted, only the key.
//!
//! Each `Addr` has tags, which are synonyms, and the tag defines the format of its `data`
//! (the host, then the port). The formats are the ones of nodo (`src/utils/peer_invite.py`):
//!
//! | Tag | `data` |
//! |---|---|
//! | `ip4` | 4 bytes and a big-endian port |
//! | `ip6` | 16 bytes and a port |
//! | `tor-onion-v3` | the 32-byte key of the service and a port |
//! | `dns` | an ASCII host name and a port |
//!
//! An `Addr` with no tag that the app knows is ignored. One with a known tag and bad data
//! makes the whole invitation invalid, as in nodo.
//!
//! [`plan`] says which addresses the app can use on the current route, and in what order.

use std::net::{Ipv4Addr, Ipv6Addr};

use celaut_proto::invite::PeerInvite;
use data_encoding::BASE32_NOPAD;
use prost::Message;
use sha3::{Digest, Sha3_256};

/// The tags that the app knows.
pub const TAG_IP4: &str = "ip4";
pub const TAG_IP6: &str = "ip6";
pub const TAG_ONION: &str = "tor-onion-v3";
pub const TAG_DNS: &str = "dns";

const KEY_LEN: usize = 32;
/// A QR code of the version 40 holds 2953 bytes, so a longer input is not an invitation.
const MAX_BYTES: usize = 2953;
const MAX_HOSTNAME: usize = 253;

/// The kind of an address.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Ip4,
    Ip6,
    Onion,
    Dns,
}

/// One address of an invitation, in a form that the connection takes: the host has no
/// brackets.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InviteAddr {
    pub kind: Kind,
    pub host: String,
    pub port: u16,
}

impl InviteAddr {
    /// `host:port`, with brackets for IPv6, as in `nodo connect`.
    pub fn text(&self) -> String {
        match self.kind {
            Kind::Ip6 => format!("[{}]:{}", self.host, self.port),
            _ => format!("{}:{}", self.host, self.port),
        }
    }
}

/// An invitation that was read.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Invite {
    /// The identity of the peer, as the lowercase hex of its key: its `peer_id`.
    pub peer_id: String,
    /// The addresses that the app knows, in the order of the invitation.
    pub addrs: Vec<InviteAddr>,
}

/// Why the bytes are not an invitation.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum InviteError {
    #[error("Not a peer invitation: {0}.")]
    NotAnInvitation(String),
    #[error("The identity key is {0} bytes, expected 32.")]
    Key(usize),
    #[error("An address has a malformed formal: {0}")]
    Formal(String),
    #[error("The data of a '{tag}' address is {got} bytes, expected {expected}.")]
    Length {
        tag: &'static str,
        got: usize,
        expected: String,
    },
    #[error("The host of a 'dns' address is not a host name: {0:?}.")]
    Host(String),
    #[error("The host of a 'tor-onion-v3' address is not valid.")]
    Onion,
}

/// Read an invitation. Addresses of a kind that the app does not know are dropped.
pub fn parse(raw: &[u8]) -> Result<Invite, InviteError> {
    if raw.len() > MAX_BYTES {
        return Err(InviteError::NotAnInvitation(
            "too large for a QR code".into(),
        ));
    }
    let invite =
        PeerInvite::decode(raw).map_err(|e| InviteError::NotAnInvitation(e.to_string()))?;
    if invite.public_key.len() != KEY_LEN {
        return Err(InviteError::Key(invite.public_key.len()));
    }
    let mut addrs = Vec::new();
    for addr in &invite.addr {
        check_formal(&addr.formal)?;
        let Some(kind) = addr.tags.iter().find_map(|t| kind_of(t)) else {
            continue;
        };
        addrs.push(decode(kind, &addr.data)?);
    }
    Ok(Invite {
        peer_id: hex::encode(&invite.public_key),
        addrs,
    })
}

fn kind_of(tag: &str) -> Option<Kind> {
    match tag {
        TAG_IP4 => Some(Kind::Ip4),
        TAG_IP6 => Some(Kind::Ip6),
        TAG_ONION => Some(Kind::Onion),
        TAG_DNS => Some(Kind::Dns),
        _ => None,
    }
}

/// The rules of `parse_component_formal` of nodo: UTF-8 `key=value` lines, split at the
/// first `=`, with no empty key and no repeated key. White space around the whole text is
/// ignored. The content is not used.
fn check_formal(formal: &[u8]) -> Result<(), InviteError> {
    let text = std::str::from_utf8(formal)
        .map_err(|e| InviteError::Formal(format!("not UTF-8: {e}")))?
        .trim();
    let mut keys = std::collections::BTreeSet::new();
    for (i, line) in text.split('\n').enumerate().filter(|_| !text.is_empty()) {
        let Some((key, _)) = line.split_once('=') else {
            return Err(InviteError::Formal(format!(
                "line {} is not 'key=value'",
                i + 1
            )));
        };
        if key.is_empty() {
            return Err(InviteError::Formal(format!(
                "line {} has an empty key",
                i + 1
            )));
        }
        if !keys.insert(key) {
            return Err(InviteError::Formal(format!("the key {key:?} is twice")));
        }
    }
    Ok(())
}

fn split<'a>(
    data: &'a [u8],
    host_len: usize,
    tag: &'static str,
) -> Result<(&'a [u8], u16), InviteError> {
    if data.len() != host_len + 2 {
        return Err(InviteError::Length {
            tag,
            got: data.len(),
            expected: (host_len + 2).to_string(),
        });
    }
    let (host, port) = data.split_at(host_len);
    Ok((host, u16::from_be_bytes([port[0], port[1]])))
}

fn decode(kind: Kind, data: &[u8]) -> Result<InviteAddr, InviteError> {
    let (host, port) = match kind {
        Kind::Ip4 => {
            let (h, p) = split(data, 4, TAG_IP4)?;
            (Ipv4Addr::new(h[0], h[1], h[2], h[3]).to_string(), p)
        }
        Kind::Ip6 => {
            let (h, p) = split(data, 16, TAG_IP6)?;
            let mut octets = [0u8; 16];
            octets.copy_from_slice(h);
            (Ipv6Addr::from(octets).to_string(), p)
        }
        Kind::Onion => {
            let (h, p) = split(data, KEY_LEN, TAG_ONION)?;
            (onion_text(h), p)
        }
        Kind::Dns => {
            if data.len() <= 2 {
                return Err(InviteError::Length {
                    tag: TAG_DNS,
                    got: data.len(),
                    expected: "at least 3".into(),
                });
            }
            let (host, port) = data.split_at(data.len() - 2);
            let host = std::str::from_utf8(host)
                .ok()
                .filter(|h| h.is_ascii())
                .ok_or_else(|| InviteError::Host(String::from_utf8_lossy(host).into_owned()))?;
            if !valid_hostname(host) || literal_kind(host).is_some() {
                return Err(InviteError::Host(host.to_string()));
            }
            (host.to_string(), u16::from_be_bytes([port[0], port[1]]))
        }
    };
    Ok(InviteAddr { kind, host, port })
}

/// The `.onion` name of a v3 service: the key, a checksum and the version, in base32.
fn onion_text(key: &[u8]) -> String {
    let mut hasher = Sha3_256::new();
    hasher.update(b".onion checksum");
    hasher.update(key);
    hasher.update([3u8]);
    let checksum = hasher.finalize();
    let mut raw = key.to_vec();
    raw.extend_from_slice(&checksum[..2]);
    raw.push(3);
    format!("{}.onion", BASE32_NOPAD.encode(&raw).to_ascii_lowercase())
}

/// A DNS name: ASCII labels of letters, digits and hyphens, none of them empty, longer
/// than 63 bytes, or starting or ending with a hyphen.
fn valid_hostname(host: &str) -> bool {
    !host.is_empty()
        && host.len() <= MAX_HOSTNAME
        && host.is_ascii()
        && host.trim_end_matches('.').split('.').all(|label| {
            !label.is_empty()
                && label.len() <= 63
                && !label.starts_with('-')
                && !label.ends_with('-')
                && label
                    .bytes()
                    .all(|b| b == b'-' || b.is_ascii_alphanumeric())
        })
}

/// The kind of `host` when it is an IP literal or an onion name.
fn literal_kind(host: &str) -> Option<Kind> {
    if host.to_ascii_lowercase().ends_with(".onion") {
        return Some(Kind::Onion);
    }
    if host.parse::<Ipv4Addr>().is_ok() {
        return Some(Kind::Ip4);
    }
    host.parse::<Ipv6Addr>().ok().map(|_| Kind::Ip6)
}

/// How the app reaches a host now.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Via {
    /// A TCP connection from the phone.
    Direct,
    /// Through the Tor client inside the app. It is built with `onion-service-client`, so
    /// it reaches onion services too.
    TorEmbedded,
    /// Through an external SOCKS5 proxy, which the user says is Tor (Orbot).
    TorProxy,
}

/// Why an address is not tried.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Skip {
    /// An onion address needs Tor, and the route is direct.
    OnionNeedsTor,
    /// The address is on a private network, and a Tor exit cannot reach it.
    PrivateOverTor,
}

/// The addresses to try, in order, and the ones that cannot work on this route.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Plan {
    pub order: Vec<InviteAddr>,
    pub skipped: Vec<(InviteAddr, Skip)>,
}

/// Choose the addresses that can work on `via`, and the order to try them.
///
/// - A direct route cannot reach an onion address.
/// - Through Tor, an address on a private network is out of reach.
/// - Through Tor (the client of the app or an external proxy), an onion address goes
///   first: it never leaves the Tor network.
/// - The rest keeps the order of the invitation, which is the preference of the node.
pub fn plan(addrs: &[InviteAddr], via: Via) -> Plan {
    let mut order = Vec::new();
    let mut skipped = Vec::new();
    for a in addrs {
        let skip = match (via, a.kind) {
            (Via::Direct, Kind::Onion) => Some(Skip::OnionNeedsTor),
            (Via::TorEmbedded | Via::TorProxy, _) if is_private(a) => Some(Skip::PrivateOverTor),
            _ => None,
        };
        match skip {
            Some(s) => skipped.push((a.clone(), s)),
            None => order.push(a.clone()),
        }
    }
    if via != Via::Direct {
        // A stable sort: onion first, the others in their order.
        order.sort_by_key(|a| a.kind != Kind::Onion);
    }
    Plan { order, skipped }
}

/// True for an address that only a host on the same network can reach: loopback, private,
/// link-local, shared (CGNAT) and unspecified IP addresses, and the names of the local
/// network.
pub fn is_private(a: &InviteAddr) -> bool {
    match a.kind {
        Kind::Ip4 => a.host.parse::<Ipv4Addr>().is_ok_and(|ip| {
            let o = ip.octets();
            ip.is_loopback()
                || ip.is_private()
                || ip.is_link_local()
                || ip.is_unspecified()
                || (o[0] == 100 && (64..128).contains(&o[1]))
        }),
        Kind::Ip6 => a.host.parse::<Ipv6Addr>().is_ok_and(|ip| {
            let s = ip.segments()[0];
            ip.is_loopback()
                || ip.is_unspecified()
                || (s & 0xfe00) == 0xfc00
                || (s & 0xffc0) == 0xfe80
                || ip.to_ipv4_mapped().is_some_and(|v4| {
                    is_private(&InviteAddr {
                        kind: Kind::Ip4,
                        host: v4.to_string(),
                        port: a.port,
                    })
                })
        }),
        Kind::Dns => {
            let h = a.host.trim_end_matches('.').to_ascii_lowercase();
            !h.contains('.')
                || ["local", "localhost", "lan", "internal", "home.arpa"]
                    .iter()
                    .any(|s| h == *s || h.ends_with(&format!(".{s}")))
        }
        Kind::Onion => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    fn vectors() -> Value {
        serde_json::from_str(include_str!("../tests/vectors/invite_vectors.json")).unwrap()
    }

    fn bytes(v: &Value) -> Vec<u8> {
        hex::decode(v.as_str().unwrap()).unwrap()
    }

    fn addr(kind: Kind, host: &str, port: u16) -> InviteAddr {
        InviteAddr {
            kind,
            host: host.into(),
            port,
        }
    }

    #[test]
    fn the_vectors_of_the_format_give_the_addresses_of_nodo() {
        let v = vectors();
        for (name, case) in v["valid"].as_object().unwrap() {
            let invite = parse(&bytes(&case["hex"])).unwrap_or_else(|e| panic!("{name}: {e}"));
            let got: Vec<String> = invite.addrs.iter().map(InviteAddr::text).collect();
            let want: Vec<String> = case["targets"]
                .as_array()
                .unwrap()
                .iter()
                .map(|t| t.as_str().unwrap().to_string())
                .collect();
            assert_eq!(got, want, "{name}");
            assert_eq!(invite.peer_id, v["key"].as_str().unwrap(), "{name}");
        }
    }

    #[test]
    fn the_onion_name_is_the_one_of_the_key() {
        let v = vectors();
        let onion = v["valid"]["all_kinds"]["targets"][2].as_str().unwrap();
        assert_eq!(onion, format!("{}:8092", v["onion"].as_str().unwrap()));
        assert_eq!(
            onion_text(&hex::decode(v["onion_key"].as_str().unwrap()).unwrap()),
            v["onion"]
        );
        // A known name of the specification of Tor: the checksum and the version are in it.
        assert_eq!(onion_text(&[0u8; 32]).len(), 56 + ".onion".len());
    }

    #[test]
    fn the_sizes_of_nodo_hold() {
        let v = vectors();
        assert_eq!(
            bytes(&v["valid"]["ip4"]["hex"]).len() as u64,
            v["sizes"]["ip4"].as_u64().unwrap()
        );
        assert!(v["sizes"]["ip4"].as_u64().unwrap() < 60);
        assert!(v["sizes"]["three"].as_u64().unwrap() < 150);
    }

    #[test]
    fn what_nodo_refuses_is_refused() {
        for (name, raw) in vectors()["refused"].as_object().unwrap() {
            assert!(parse(&bytes(raw)).is_err(), "{name} was accepted");
        }
    }

    #[test]
    fn the_unknown_tag_is_dropped_and_an_invitation_with_only_those_has_no_address() {
        let v = vectors();
        let only = parse(&bytes(&v["valid"]["only_unknown"]["hex"])).unwrap();
        assert!(only.addrs.is_empty());
        assert_eq!(only.peer_id, v["key"].as_str().unwrap());
    }

    #[test]
    fn the_size_limit_and_junk_are_refused_without_a_panic() {
        assert!(parse(&vec![0u8; MAX_BYTES + 1]).is_err());
        for n in 0..64u8 {
            let junk: Vec<u8> = (0..n).map(|i| i.wrapping_mul(37).wrapping_add(n)).collect();
            let _ = parse(&junk);
        }
    }

    #[test]
    fn a_direct_route_skips_the_onion_and_keeps_the_order() {
        let list = [
            addr(Kind::Onion, "x.onion", 1),
            addr(Kind::Ip6, "2001:db8::1", 2),
            addr(Kind::Ip4, "203.0.113.7", 3),
            addr(Kind::Dns, "node.example.org", 4),
        ];
        let p = plan(&list, Via::Direct);
        assert_eq!(
            p.order.iter().map(|a| a.port).collect::<Vec<_>>(),
            [2, 3, 4]
        );
        assert_eq!(p.skipped, vec![(list[0].clone(), Skip::OnionNeedsTor)]);
    }

    #[test]
    fn a_direct_route_reaches_the_private_network_where_the_qr_was_shown() {
        let list = [
            addr(Kind::Ip4, "192.168.1.20", 1),
            addr(Kind::Dns, "nodo.local", 2),
        ];
        let p = plan(&list, Via::Direct);
        assert_eq!(p.order, list);
        assert!(p.skipped.is_empty());
    }

    #[test]
    fn the_tor_client_of_the_app_tries_the_onion_first_and_skips_the_private_network() {
        let list = [
            addr(Kind::Ip4, "10.0.2.2", 1),
            addr(Kind::Ip4, "203.0.113.7", 2),
            addr(Kind::Dns, "node.example.org", 3),
            addr(Kind::Onion, "x.onion", 4),
        ];
        let p = plan(&list, Via::TorEmbedded);
        assert_eq!(
            p.order.iter().map(|a| a.port).collect::<Vec<_>>(),
            [4, 2, 3]
        );
        assert_eq!(p.skipped, vec![(list[0].clone(), Skip::PrivateOverTor)]);
    }

    #[test]
    fn a_tor_proxy_tries_the_onion_first_and_skips_the_private_network() {
        let list = [
            addr(Kind::Ip4, "203.0.113.7", 1),
            addr(Kind::Ip6, "fd00::1", 2),
            addr(Kind::Dns, "node.example.org", 3),
            addr(Kind::Onion, "x.onion", 4),
        ];
        let p = plan(&list, Via::TorProxy);
        assert_eq!(
            p.order.iter().map(|a| a.port).collect::<Vec<_>>(),
            [4, 1, 3]
        );
        assert_eq!(p.skipped, vec![(list[1].clone(), Skip::PrivateOverTor)]);
    }

    #[test]
    fn the_private_ranges() {
        let private = |kind, host: &str| is_private(&addr(kind, host, 1));
        for h in [
            "127.0.0.1",
            "10.1.2.3",
            "172.16.0.1",
            "172.31.255.1",
            "192.168.0.1",
            "169.254.1.1",
            "100.64.0.1",
            "100.127.1.1",
            "0.0.0.0",
        ] {
            assert!(private(Kind::Ip4, h), "{h}");
        }
        for h in [
            "8.8.8.8",
            "172.32.0.1",
            "100.128.0.1",
            "100.63.0.1",
            "203.0.113.7",
        ] {
            assert!(!private(Kind::Ip4, h), "{h}");
        }
        for h in [
            "::1",
            "::",
            "fc00::1",
            "fd12::1",
            "fe80::1",
            "::ffff:192.168.1.1",
        ] {
            assert!(private(Kind::Ip6, h), "{h}");
        }
        for h in ["2001:db8::1", "2606:4700::1111", "::ffff:8.8.8.8"] {
            assert!(!private(Kind::Ip6, h), "{h}");
        }
        for h in [
            "localhost",
            "nodo",
            "nodo.local",
            "a.b.lan",
            "x.internal",
            "x.home.arpa",
            "x.localhost",
        ] {
            assert!(private(Kind::Dns, h), "{h}");
        }
        for h in ["node.example.org", "example.com", "locally.example.com"] {
            assert!(!private(Kind::Dns, h), "{h}");
        }
    }
}
