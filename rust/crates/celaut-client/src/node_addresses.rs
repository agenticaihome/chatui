//! The onion addresses that a node announces, and the order in which the app tries the
//! addresses of a node (`docs/celaut/network.md`, issue #140).
//!
//! A node with Tor on announces its onion in its signed advertisement: a `Peer.Uri` whose
//! transport has the tag `tor-onion-v3` (nodo `src/gateway/utils.py`). The app keeps that
//! onion with the other addresses of the node, so a node first added by its IP can be
//! reached by its onion later. Through Tor the onion goes first, as in an invitation
//! ([`crate::invite::plan`]): it never leaves the Tor network. On a direct route it goes
//! last, because the phone cannot open it.

use celaut_proto::celaut::Peer;
use data_encoding::BASE32_NOPAD;

use crate::invite::{onion_text, Via, TAG_ONION};

/// True for a `host:port` text (or a host) whose host is a `.onion` name.
pub fn is_onion_address(text: &str) -> bool {
    let host = match text.rsplit_once(':') {
        Some((host, port)) if !port.is_empty() && port.bytes().all(|b| b.is_ascii_digit()) => host,
        _ => text,
    };
    host.trim_end_matches('.')
        .to_ascii_lowercase()
        .ends_with(".onion")
}

/// True for the name of a Tor v3 onion service: 56 base32 characters of the key, the
/// checksum and the version 3, then `.onion`, in lowercase.
pub fn is_onion_v3_host(host: &str) -> bool {
    let Some(label) = host.strip_suffix(".onion") else {
        return false;
    };
    if label.len() != 56 || label.bytes().any(|b| b.is_ascii_uppercase()) {
        return false;
    }
    let Ok(raw) = BASE32_NOPAD.decode(label.to_ascii_uppercase().as_bytes()) else {
        return false;
    };
    raw.len() == 35 && raw[34] == 3 && onion_text(&raw[..32]) == host
}

/// The onion addresses (`host:port`) that `peer` announces, in its order, with no
/// repeats. Only an address whose transport is `tor-onion-v3` and whose host is a valid v3
/// onion name counts. An address that expired by `now_unix` (`expiry_unix_timestamp`, 0
/// for none) is left out, as nodo does.
///
/// `peer` must be an advertisement that the app checked (its signature and the identity
/// of the connection): then the onion is the node's own word.
pub fn advertised_onions(peer: &Peer, now_unix: i64) -> Vec<String> {
    let mut onions: Vec<String> = Vec::new();
    for uri in &peer.uri {
        let onion_transport = uri.transport.as_ref().is_some_and(|t| {
            t.tags
                .iter()
                .any(|tag| tag.trim().eq_ignore_ascii_case(TAG_ONION))
        });
        let host = uri.ip.trim().to_ascii_lowercase();
        let expired = uri.expiry_unix_timestamp != 0 && uri.expiry_unix_timestamp <= now_unix;
        let Ok(port) = u16::try_from(uri.port) else {
            continue;
        };
        if !onion_transport || expired || port == 0 || !is_onion_v3_host(&host) {
            continue;
        }
        let text = format!("{host}:{port}");
        if !onions.contains(&text) {
            onions.push(text);
        }
    }
    onions
}

/// The addresses of a node in the order to try them on `via`, with no repeats.
///
/// - Through Tor (the client of the app or an external proxy), the onions go first.
/// - On a direct route, the onions go last: the phone cannot open them.
/// - Otherwise the order stays: the address that worked last comes first.
pub fn order(addresses: &[String], via: Via) -> Vec<String> {
    let mut out: Vec<String> = Vec::with_capacity(addresses.len());
    for a in addresses {
        if !out.contains(a) {
            out.push(a.clone());
        }
    }
    // A stable sort keeps the order inside each group.
    match via {
        Via::Direct => out.sort_by_key(|a| is_onion_address(a)),
        Via::TorEmbedded | Via::TorProxy => out.sort_by_key(|a| !is_onion_address(a)),
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use celaut_proto::celaut::peer::uri::Protocol;
    use celaut_proto::celaut::peer::Uri;

    /// The onion of the key 0x01 × 32.
    fn onion() -> String {
        onion_text(&[1u8; 32])
    }

    fn uri(ip: &str, port: i32, tag: &str) -> Uri {
        Uri {
            ip: ip.into(),
            port,
            transport: Some(Protocol {
                tags: vec![tag.into()],
                ..Default::default()
            }),
            ..Default::default()
        }
    }

    fn peer(uris: Vec<Uri>) -> Peer {
        Peer {
            uri: uris,
            ..Default::default()
        }
    }

    #[test]
    fn a_valid_v3_onion_name_is_known() {
        assert!(is_onion_v3_host(&onion()));
        // The name of www.torproject.org.
        assert!(is_onion_v3_host(
            "2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion"
        ));
    }

    #[test]
    fn a_name_with_a_wrong_checksum_version_length_or_case_is_not_an_onion() {
        let good = onion();
        let label = good.trim_end_matches(".onion");
        // Another last character changes the version byte or the checksum.
        let mut bad = label.to_string();
        bad.replace_range(55.., if label.ends_with('d') { "a" } else { "d" });
        assert!(!is_onion_v3_host(&format!("{bad}.onion")));
        assert!(!is_onion_v3_host(&format!("{}.onion", &label[1..])));
        assert!(!is_onion_v3_host(&good.to_ascii_uppercase()));
        assert!(!is_onion_v3_host(label));
        assert!(!is_onion_v3_host("node.example"));
        // A v2 name (16 characters) is not v3.
        assert!(!is_onion_v3_host("expyuzz4wqqyqhjn.onion"));
    }

    #[test]
    fn the_onion_of_the_advertisement_is_read() {
        let p = peer(vec![
            uri("203.0.113.5", 53460, "tcp"),
            uri(&onion(), 53460, TAG_ONION),
        ]);
        assert_eq!(
            advertised_onions(&p, 1_000),
            vec![format!("{}:53460", onion())]
        );
    }

    #[test]
    fn only_an_address_with_the_onion_transport_and_a_valid_onion_name_counts() {
        let p = peer(vec![
            // An onion name announced as tcp: nodo refuses it, so the app does too.
            uri(&onion(), 1, "tcp"),
            // No transport at all.
            Uri {
                ip: onion(),
                port: 2,
                ..Default::default()
            },
            // The onion transport on an IP or on a bad name.
            uri("203.0.113.5", 3, TAG_ONION),
            uri("abc.onion", 4, TAG_ONION),
            // Bad ports.
            uri(&onion(), 0, TAG_ONION),
            uri(&onion(), 70_000, TAG_ONION),
            uri(&onion(), -1, TAG_ONION),
        ]);
        assert!(advertised_onions(&p, 1_000).is_empty());
    }

    #[test]
    fn the_tag_and_the_name_are_read_in_any_case_and_a_repeat_counts_once() {
        let upper = onion().to_ascii_uppercase().replace(".ONION", ".onion");
        let p = peer(vec![
            uri(&upper, 9, "TOR-ONION-V3"),
            uri(&onion(), 9, TAG_ONION),
            uri(&onion(), 10, TAG_ONION),
        ]);
        assert_eq!(
            advertised_onions(&p, 1_000),
            vec![format!("{}:9", onion()), format!("{}:10", onion())]
        );
    }

    #[test]
    fn an_expired_onion_is_left_out_and_zero_means_no_expiry() {
        let mut expired = uri(&onion(), 1, TAG_ONION);
        expired.expiry_unix_timestamp = 1_000;
        let mut later = uri(&onion(), 2, TAG_ONION);
        later.expiry_unix_timestamp = 1_001;
        let never = uri(&onion(), 3, TAG_ONION);
        let p = peer(vec![expired, later, never]);
        assert_eq!(
            advertised_onions(&p, 1_000),
            vec![format!("{}:2", onion()), format!("{}:3", onion())]
        );
    }

    #[test]
    fn through_tor_the_onions_go_first_and_keep_their_order() {
        let a = vec![
            "203.0.113.5:1".to_string(),
            format!("{}:1", onion()),
            "node.example:2".to_string(),
            "x.onion:3".to_string(),
        ];
        for via in [Via::TorEmbedded, Via::TorProxy] {
            assert_eq!(
                order(&a, via),
                vec![
                    format!("{}:1", onion()),
                    "x.onion:3".to_string(),
                    "203.0.113.5:1".to_string(),
                    "node.example:2".to_string(),
                ]
            );
        }
    }

    #[test]
    fn on_a_direct_route_the_onions_go_last_and_repeats_go() {
        let a = vec![
            format!("{}:1", onion()),
            "203.0.113.5:1".to_string(),
            "203.0.113.5:1".to_string(),
            "[2001:db8::1]:4".to_string(),
        ];
        assert_eq!(
            order(&a, Via::Direct),
            vec![
                "203.0.113.5:1".to_string(),
                "[2001:db8::1]:4".to_string(),
                format!("{}:1", onion()),
            ]
        );
    }

    #[test]
    fn an_onion_address_is_known_with_or_without_the_port() {
        assert!(is_onion_address("abc.onion:80"));
        assert!(is_onion_address("ABC.ONION."));
        assert!(!is_onion_address("onion.example:80"));
        assert!(!is_onion_address("[2001:db8::1]:4"));
    }
}
