//! The whole M1 flow on fixed bee-rpc streams: GenerateClient (with proof of work),
//! GetPeerInfo, and the checks of the Peer.

mod common;

use celaut_client::{fetch_node_info, ClientError, MemoryPeerStore, PeerError, PeerStore, Seen};
use celaut_proto::celaut::{Client, Peer, PoWRequired};
use celaut_wire::WireError;
use common::{chunked_stream_of, stream_of, FixedStreams};
use prost::Message;

fn client_reply(id: &str) -> Vec<bee_rpc::buffer::Buffer> {
    stream_of(
        1,
        &Client {
            client_id: id.into(),
            ..Default::default()
        },
    )
}

fn pow_reply(challenge: &str, difficulty: i32) -> Vec<bee_rpc::buffer::Buffer> {
    let required = PoWRequired {
        tags: vec!["blake2b".into()],
        prose: "Find a solution.".into(),
        formal: b"Blake2b(challenge || solution).hexdigest().endswith(\"0\" * difficulty)".to_vec(),
        challenge: challenge.into(),
        difficulty,
    };
    stream_of(2, &required)
}

fn decode_client(parts: &[bee_rpc::frame::Part]) -> Client {
    assert_eq!(parts.len(), 1);
    assert_eq!(parts[0].index, 1);
    Client::decode(parts[0].data.as_slice()).unwrap()
}

#[tokio::test]
async fn free_node_gives_a_verified_peer() {
    let vectors = common::vectors();
    let v = &vectors.peers[0];
    let transport = FixedStreams::new(vec![
        client_reply("c0ffee00c0ffee00c0ffee00c0ffee00"),
        // The Peer comes in three chunks.
        chunked_stream_of(1, &v.peer(), 700),
    ]);
    let store = MemoryPeerStore::new();
    let info = fetch_node_info(&transport, &vectors.public_key, &store)
        .await
        .unwrap();
    assert_eq!(info.peer_id, vectors.public_key);
    assert_eq!(info.peer, v.peer());

    assert_eq!(transport.calls(), 2);
    let (method, parts) = transport.request(0);
    assert_eq!(method, "GenerateClient");
    let proposed = decode_client(&parts);
    assert_eq!(proposed.client_id.len(), 32);
    assert!(proposed
        .client_id
        .bytes()
        .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase()));
    assert_eq!(&proposed.client_id[12..13], "4"); // UUID4
    assert!(proposed.challenge.is_none() && proposed.pow_solution.is_none());
    // GetPeerInfo uses the id that the node gave.
    let (method, parts) = transport.request(1);
    assert_eq!(method, "GetPeerInfo");
    assert_eq!(
        decode_client(&parts).client_id,
        "c0ffee00c0ffee00c0ffee00c0ffee00"
    );

    let seen = store.get(&vectors.public_key).unwrap().unwrap();
    assert_eq!(
        seen,
        Seen {
            ts: v.ts,
            digest: v.digest.clone()
        }
    );
}

#[tokio::test]
async fn proof_of_work_is_solved_and_sent_back() {
    let vectors = common::vectors();
    let work = &vectors.pow[2]; // difficulty 3
    let transport = FixedStreams::new(vec![
        pow_reply(&work.challenge, work.difficulty as i32),
        client_reply("11111111111111111111111111111111"),
        stream_of(1, &vectors.peers[1].peer()),
    ]);
    let store = MemoryPeerStore::new();
    let info = fetch_node_info(&transport, &vectors.public_key, &store)
        .await
        .unwrap();
    assert_eq!(info.peer, vectors.peers[1].peer());

    assert_eq!(transport.calls(), 3);
    let first = decode_client(&transport.request(0).1);
    let retry = decode_client(&transport.request(1).1);
    assert_eq!(transport.request(1).0, "GenerateClient");
    assert_eq!(retry.client_id, first.client_id);
    assert_eq!(retry.challenge.as_deref(), Some(work.challenge.as_str()));
    assert_eq!(retry.pow_solution.as_deref(), Some(work.solution.as_str()));
    assert_eq!(transport.request(2).0, "GetPeerInfo");
}

#[tokio::test]
async fn proof_of_work_uses_the_difficulty_of_the_challenge() {
    // The copy in PoWRequired says 1. The challenge says 2. The node checks the challenge.
    let vectors = common::vectors();
    let work = &vectors.pow[1]; // difficulty 2
    let transport = FixedStreams::new(vec![
        pow_reply(&work.challenge, 1),
        client_reply("11111111111111111111111111111111"),
        stream_of(1, &vectors.peers[0].peer()),
    ]);
    fetch_node_info(&transport, &vectors.public_key, &MemoryPeerStore::new())
        .await
        .unwrap();
    let retry = decode_client(&transport.request(1).1);
    assert_eq!(retry.pow_solution.as_deref(), Some(work.solution.as_str()));
}

#[tokio::test]
async fn too_much_work_is_refused() {
    let transport = FixedStreams::new(vec![pow_reply("id:nonce:40:mac", 40)]);
    let err = fetch_node_info(&transport, "x", &MemoryPeerStore::new())
        .await
        .unwrap_err();
    assert!(matches!(err, ClientError::PowTooHard(40)), "{err:?}");
    assert_eq!(transport.calls(), 1);
}

#[tokio::test]
async fn a_second_proof_of_work_request_is_refused() {
    let vectors = common::vectors();
    let work = &vectors.pow[0];
    let transport = FixedStreams::new(vec![
        pow_reply(&work.challenge, 1),
        pow_reply(&work.challenge, 1),
    ]);
    let err = fetch_node_info(&transport, "x", &MemoryPeerStore::new())
        .await
        .unwrap_err();
    assert!(matches!(err, ClientError::PowRejected), "{err:?}");
    assert_eq!(transport.calls(), 2);
}

#[tokio::test]
async fn bad_answers_are_errors() {
    let vectors = common::vectors();
    let store = MemoryPeerStore::new();
    // No message at all.
    let transport = FixedStreams::new(vec![vec![]]);
    let err = fetch_node_info(&transport, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Wire(WireError::Protocol(_))),
        "{err:?}"
    );
    // An empty client id.
    let transport = FixedStreams::new(vec![client_reply("")]);
    let err = fetch_node_info(&transport, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(matches!(err, ClientError::Protocol(_)), "{err:?}");
    // Bytes that are no Client.
    let junk = bee_rpc::buffer::Buffer {
        chunk: Some(vec![0xff, 0xff, 0xff]),
        head: Some(bee_rpc::buffer::buffer::Head {
            index: 1,
            partitions: vec![],
        }),
        separator: Some(true),
        ..Default::default()
    };
    let transport = FixedStreams::new(vec![vec![junk]]);
    let err = fetch_node_info(&transport, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Wire(WireError::Protocol(_))),
        "{err:?}"
    );
    // A head index that the method does not have.
    let wrong = stream_of(7, &Client::default());
    let transport = FixedStreams::new(vec![wrong]);
    let err = fetch_node_info(&transport, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Wire(WireError::Call(_))),
        "{err:?}"
    );
    // A call that fails.
    let transport = FixedStreams::new(vec![]);
    let err = fetch_node_info(&transport, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Wire(WireError::Call(_))),
        "{err:?}"
    );
    assert!(store.get(&vectors.public_key).unwrap().is_none());
}

async fn fetch_peer(
    peer: &Peer,
    certificate: &str,
    store: &MemoryPeerStore,
) -> Result<(), ClientError> {
    let transport = FixedStreams::new(vec![
        client_reply("22222222222222222222222222222222"),
        stream_of(1, peer),
    ]);
    fetch_node_info(&transport, certificate, store)
        .await
        .map(|_| ())
}

#[tokio::test]
async fn peer_of_another_node_is_refused_and_not_stored() {
    let vectors = common::vectors();
    let store = MemoryPeerStore::new();
    let err = fetch_peer(&vectors.peers[0].peer(), &vectors.other_public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Peer(PeerError::KeyMismatch { .. })),
        "{err:?}"
    );
    assert!(store.get(&vectors.other_public_key).unwrap().is_none());
    assert!(store.get(&vectors.public_key).unwrap().is_none());
}

#[tokio::test]
async fn bad_signature_is_refused_and_not_stored() {
    let vectors = common::vectors();
    let store = MemoryPeerStore::new();
    let mut peer = vectors.peers[0].peer();
    peer.ts += 1; // The signature covers the ts.
    let err = fetch_peer(&peer, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Peer(PeerError::BadSignature)),
        "{err:?}"
    );
    assert!(store.get(&vectors.public_key).unwrap().is_none());
}

#[tokio::test]
async fn ts_must_not_go_back() {
    let vectors = common::vectors();
    let store = MemoryPeerStore::new();
    let mut peer = vectors.peers[0].peer();

    peer.ts = 1000;
    common::resign(&mut peer, &vectors);
    fetch_peer(&peer, &vectors.public_key, &store)
        .await
        .unwrap();
    // The same message again (the node serves it for up to 60 s).
    fetch_peer(&peer, &vectors.public_key, &store)
        .await
        .unwrap();
    // A newer one.
    let mut newer = peer.clone();
    newer.ts = 1001;
    common::resign(&mut newer, &vectors);
    fetch_peer(&newer, &vectors.public_key, &store)
        .await
        .unwrap();
    // The old one is now stale.
    let err = fetch_peer(&peer, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(
            err,
            ClientError::Peer(PeerError::StaleTs {
                ts: 1000,
                last: 1001
            })
        ),
        "{err:?}"
    );
    // Same ts, other content: stale too.
    let mut changed = newer.clone();
    changed.rates.clear();
    common::resign(&mut changed, &vectors);
    let err = fetch_peer(&changed, &vectors.public_key, &store)
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Peer(PeerError::StaleTs { .. })),
        "{err:?}"
    );
    assert_eq!(store.get(&vectors.public_key).unwrap().unwrap().ts, 1001);
}
