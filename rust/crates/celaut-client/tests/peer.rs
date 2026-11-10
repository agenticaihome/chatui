//! The check of the Peer against the known answers of `node_identity.py`.

mod common;

use celaut_client::peer::{check_ts, content_digest, signed_payload, verify_signature, PeerError};
use celaut_client::Seen;
use celaut_proto::celaut::peer::signature_scheme::Protocol as SchemeProtocol;
use celaut_proto::celaut::AmountKeyValue;

#[test]
fn digest_payload_and_signature_equal_nodo() {
    let vectors = common::vectors();
    for v in &vectors.peers {
        let peer = v.peer();
        let digest = content_digest(&peer);
        assert_eq!(digest, v.digest, "digest of {}", v.name);
        assert_eq!(
            signed_payload(&peer.public_key, peer.ts, &digest),
            v.payload,
            "payload of {}",
            v.name
        );
        assert_eq!(peer.signature, v.signature);
        assert_eq!(peer.ts, v.ts);
        assert_eq!(
            verify_signature(&peer, &v.public_key),
            Ok(v.digest.clone()),
            "{}",
            v.name
        );
    }
}

#[test]
fn the_vector_peers_cover_the_edge_cases() {
    // A guard for the vectors: the edge peer must keep repeated keys, entries with no
    // value, a zero next to an unset limit, and non-ASCII text.
    let vectors = common::vectors();
    let edge = vectors
        .peers
        .iter()
        .find(|p| p.name == "edge")
        .unwrap()
        .peer();
    assert_eq!(edge.mu_per_call.len(), 3);
    let res = edge.resources[0].resources.clone().unwrap();
    assert_eq!(res.blkio_weight, Some(0));
    assert_eq!(res.cpu_period, None);
    assert!(res.benchmark.iter().any(|e| e.value.is_none()));
    assert!(edge.payment_contracts[0]
        .contract
        .as_ref()
        .unwrap()
        .ledger
        .as_ref()
        .unwrap()
        .prose
        .contains('\u{2713}'));
    assert!(edge.resources[1].resources.is_none());
}

#[test]
fn the_vector_peers_cover_the_activity_window() {
    // A guard for the vectors (nodo#344): no window ("full"), an empty window ("edge",
    // always open) and spans out of text order with HIBERNATE ("window") are three
    // different claims, so the three digests differ.
    let vectors = common::vectors();
    let peer = |name: &str| vectors.peers.iter().find(|p| p.name == name).unwrap().peer();
    assert!(peer("full").activity_window.is_none());
    let edge = peer("edge").activity_window.unwrap();
    assert!(edge.spans.is_empty());
    let window = peer("window").activity_window.unwrap();
    assert_eq!(window.spans.len(), 3);
    assert_eq!(window.spans[0].start_minute, 600);
    assert_eq!(window.on_close, 2);
    let mut without = peer("window");
    without.activity_window = None;
    assert_ne!(content_digest(&without), content_digest(&peer("window")));
}

#[test]
fn scheme_of_nodo_has_the_expected_formal() {
    let vectors = common::vectors();
    let peer = vectors.peers[0].peer();
    let component = &peer.signature_scheme.unwrap().components[0];
    assert_eq!(hex::encode(&component.formal), vectors.scheme_formal_hex);
}

#[test]
fn another_node_is_refused() {
    let vectors = common::vectors();
    let peer = vectors.peers[0].peer();
    assert_eq!(
        verify_signature(&peer, &vectors.other_public_key),
        Err(PeerError::KeyMismatch {
            certificate: vectors.other_public_key.clone(),
            advertised: vectors.public_key.clone(),
        })
    );
}

#[test]
fn every_changed_field_breaks_the_signature() {
    let vectors = common::vectors();
    let id = vectors.public_key.clone();
    let good = vectors.peers[0].peer();
    type Change = Box<dyn Fn(&mut celaut_proto::celaut::Peer)>;
    let changes: Vec<(&str, Change)> = vec![
        ("uri port", Box::new(|p| p.uri[0].port += 1)),
        ("uri ip", Box::new(|p| p.uri[1].ip.push('x'))),
        (
            "uri expiry",
            Box::new(|p| p.uri[0].expiry_unix_timestamp += 1),
        ),
        (
            "uri stack",
            Box::new(|p| p.uri[0].protocol_stack.truncate(1)),
        ),
        (
            "rate",
            Box::new(|p| p.payment_contracts[0].mu_per_unit.as_mut().unwrap().n = "2".into()),
        ),
        (
            "script",
            Box::new(|p| {
                p.payment_contracts[0].contract.as_mut().unwrap().xattrs[0].value = Some(vec![1])
            }),
        ),
        (
            "mu_per_call",
            Box::new(|p| {
                p.mu_per_call.push(AmountKeyValue {
                    key: "z".into(),
                    value: None,
                })
            }),
        ),
        ("proof", Box::new(|p| p.reputation_proofs.clear())),
        (
            "resources",
            Box::new(|p| p.resources[0].resources.as_mut().unwrap().mem_limit = Some(1)),
        ),
        (
            "benchmark",
            Box::new(|p| p.resources[0].resources.as_mut().unwrap().benchmark[0].value = Some(5)),
        ),
        ("ts", Box::new(|p| p.ts += 1)),
        (
            "signature",
            Box::new(|p| {
                let first = if p.signature.starts_with('0') {
                    "1"
                } else {
                    "0"
                };
                p.signature.replace_range(0..1, first);
            }),
        ),
        ("signature hex", Box::new(|p| p.signature = "zz".into())),
        ("signature short", Box::new(|p| p.signature.truncate(10))),
    ];
    for (what, change) in changes {
        let mut peer = good.clone();
        change(&mut peer);
        assert_eq!(
            verify_signature(&peer, &id),
            Err(PeerError::BadSignature),
            "{what}"
        );
    }
}

#[test]
fn unsigned_and_wrong_scheme_and_bad_key() {
    let vectors = common::vectors();
    let id = vectors.public_key.clone();
    let good = vectors.peers[0].peer();

    let mut peer = good.clone();
    peer.signature.clear();
    assert_eq!(verify_signature(&peer, &id), Err(PeerError::Unsigned));
    let mut peer = good.clone();
    peer.public_key.clear();
    assert_eq!(verify_signature(&peer, &id), Err(PeerError::Unsigned));

    let mut peer = good.clone();
    peer.signature_scheme = None;
    assert_eq!(
        verify_signature(&peer, &id),
        Err(PeerError::UnsupportedScheme)
    );
    let mut peer = good.clone();
    peer.signature_scheme.as_mut().unwrap().components[0].tags = vec!["ecdsa".into()];
    peer.signature_scheme.as_mut().unwrap().components[0].formal = b"algorithm=ecdsa".to_vec();
    assert_eq!(
        verify_signature(&peer, &id),
        Err(PeerError::UnsupportedScheme)
    );
    let mut peer = good.clone();
    peer.signature_scheme
        .as_mut()
        .unwrap()
        .components
        .push(SchemeProtocol::default());
    assert_eq!(
        verify_signature(&peer, &id),
        Err(PeerError::UnsupportedScheme)
    );
    let mut peer = good.clone();
    peer.signature_scheme.as_mut().unwrap().components[0] = SchemeProtocol {
        prose: "only prose".into(),
        ..Default::default()
    };
    assert_eq!(
        verify_signature(&peer, &id),
        Err(PeerError::UnsupportedScheme)
    );

    let mut peer = good.clone();
    peer.public_key = peer.public_key.to_uppercase();
    assert_eq!(
        verify_signature(&peer, &id),
        Err(PeerError::NonCanonicalKey)
    );
    let mut peer = good;
    peer.public_key = format!(" {}", &peer.public_key[..63]);
    assert_eq!(
        verify_signature(&peer, &id),
        Err(PeerError::NonCanonicalKey)
    );
}

#[test]
fn a_scheme_with_tags_only_is_enough() {
    // nodo: when one side has no formal, one common tag pairs the components.
    let vectors = common::vectors();
    let mut peer = vectors.peers[0].peer();
    peer.signature_scheme.as_mut().unwrap().components[0]
        .formal
        .clear();
    // The scheme is part of the digest, so sign the changed message again.
    common::resign(&mut peer, &vectors);
    assert!(verify_signature(&peer, &vectors.public_key).is_ok());
}

#[test]
fn ts_rules() {
    let seen = |ts, digest: &str| Seen {
        ts,
        digest: digest.into(),
    };
    assert_eq!(check_ts(None, 5, "a"), Ok(()));
    assert_eq!(check_ts(Some(&seen(4, "z")), 5, "a"), Ok(()));
    // The same message again (the node serves it for up to 60 s).
    assert_eq!(check_ts(Some(&seen(5, "a")), 5, "a"), Ok(()));
    // Same ts, other content, or older ts: refused.
    assert_eq!(
        check_ts(Some(&seen(5, "z")), 5, "a"),
        Err(PeerError::StaleTs { ts: 5, last: 5 })
    );
    assert_eq!(
        check_ts(Some(&seen(6, "a")), 5, "a"),
        Err(PeerError::StaleTs { ts: 5, last: 6 })
    );
    assert_eq!(
        check_ts(Some(&seen(i64::MAX, "a")), i64::MIN, "a"),
        Err(PeerError::StaleTs {
            ts: i64::MIN,
            last: i64::MAX
        })
    );
}
