//! Known-answer vectors made with the real Python code of nodo (`tests/vectors/generate.py`,
//! nodo working tree of 2026-11-24, `celaut.proto` sha256 4c48c295). Every digest and every
//! signature of the wire crate is checked against a value that nodo produced: the
//! statement and its movements, the execution receipts, the price offer (`EstimatedCost`)
//! and the reputation proof (with its evidence, its ledger pointers and its work).

use std::collections::BTreeMap;

use celaut_proto::celaut::{
    BalanceStatement, Contract, EstimatedCost, ExecutionReceipt, FaultEvidence, ReputationProof,
};
use celaut_wire::receipt::{self, Origin};
use celaut_wire::{offer, reputation, statement};
use prost::Message;
use serde_json::Value;

fn vectors() -> Value {
    serde_json::from_str(include_str!("vectors/wire_vectors.json")).unwrap()
}

fn text<'a>(v: &'a Value, key: &str) -> &'a str {
    v[key].as_str().unwrap_or_else(|| panic!("no {key}"))
}

fn decode<M: Message + Default>(v: &Value, key: &str) -> M {
    M::decode(hex::decode(text(v, key)).unwrap().as_slice()).unwrap()
}

#[test]
fn refs_and_names_match_nodo() {
    let v = vectors();
    let refs = &v["refs"];
    assert_eq!(statement::instance_ref("child-token-1"), text(refs, "instance_ref"));
    let account = statement::account_ref("parent-token-1");
    assert_eq!(account, text(refs, "account_ref"));
    assert_eq!(statement::genesis_hash(&account), text(refs, "genesis_hash"));
    let peer = text(&v, "peer_id");
    assert_eq!(
        receipt::execution_name(text(&v, "token"), peer).unwrap(),
        text(refs, "execution_name")
    );
    assert_eq!(
        receipt::execution_name_by_ref(text(refs, "instance_ref"), peer).unwrap(),
        text(refs, "execution_name_by_ref")
    );
}

#[test]
fn envs_and_chain_match_nodo() {
    let v = vectors();
    let envs: BTreeMap<String, Vec<u8>> = [
        ("A".to_string(), b"1".to_vec()),
        ("B".to_string(), vec![0xff, 0x00]),
    ]
    .into();
    let salt = hex::decode(text(&v["envs"], "salt_hex")).unwrap();
    let origins = BTreeMap::<String, Origin>::new();
    assert_eq!(receipt::canonical_envs(&envs, &origins), text(&v["envs"], "canonical"));
    assert_eq!(receipt::envs_digest(&envs, &salt, &origins), text(&v["envs"], "digest"));
    let chain = &v["chain"];
    assert_eq!(receipt::payload_digest(b"ping"), text(chain, "digest"));
    assert_eq!(
        receipt::chain_link(receipt::CHAIN_GENESIS, 1, "in", 4, text(chain, "digest")),
        text(chain, "link1")
    );
}

#[test]
fn statements_match_nodo() {
    let v = vectors();
    let peer_id = text(&v, "peer_id");
    for s in v["statements"].as_array().unwrap() {
        let name = text(s, "name");
        let st: BalanceStatement = decode(s, "statement_hex");
        let hashes: Vec<String> = st.movements.iter().map(statement::movement_hash).collect();
        let expected: Vec<String> = s["movement_hashes"]
            .as_array()
            .unwrap()
            .iter()
            .map(|h| h.as_str().unwrap().to_string())
            .collect();
        assert_eq!(hashes, expected, "{name}: movement hashes");
        let digest = statement::statement_digest(&st);
        assert_eq!(digest, text(s, "digest"), "{name}: digest");
        assert_eq!(
            statement::signed_text(peer_id, &digest),
            text(s, "payload"),
            "{name}: payload"
        );
        assert_eq!(st.signature, text(s, "signature"));
        assert!(statement::signature_verifies(&st, peer_id), "{name}: nodo signature");
        let mut tampered = st.clone();
        tampered.ts += 1;
        assert!(!statement::signature_verifies(&tampered, peer_id), "{name}: tampered");
        // Every field that the digest covers moves it.
        for change in [
            |s: &mut BalanceStatement| s.relayed = !s.relayed,
            |s: &mut BalanceStatement| s.account_ref.push('0'),
            |s: &mut BalanceStatement| s.service_id.push('0'),
            |s: &mut BalanceStatement| s.instance_ref.push('0'),
            |s: &mut BalanceStatement| s.from_seq += 1,
            |s: &mut BalanceStatement| s.head_seq += 1,
            |s: &mut BalanceStatement| s.head_hash.push('0'),
            |s: &mut BalanceStatement| s.oldest_seq += 1,
            |s: &mut BalanceStatement| s.retention_days += 1,
        ] {
            let mut other = st.clone();
            change(&mut other);
            assert_ne!(statement::statement_digest(&other), digest, "{name}");
        }
    }
}

#[test]
fn receipts_match_nodo() {
    let v = vectors();
    let peer_id = text(&v, "peer_id");
    for r in v["receipts"].as_array().unwrap() {
        let name = text(r, "name");
        let rc: ExecutionReceipt = decode(r, "receipt_hex");
        assert_eq!(receipt::canonical_receipt(&rc), text(r, "canonical"), "{name}: canonical");
        let digest = receipt::receipt_digest(&rc);
        assert_eq!(digest, text(r, "digest"), "{name}: digest");
        assert_eq!(
            String::from_utf8(receipt::signed_bytes(&rc)).unwrap(),
            text(r, "payload"),
            "{name}: payload"
        );
        assert_eq!(rc.signature, text(r, "signature"));
        assert_eq!(
            receipt::problems(&rc, Some(peer_id), Some(text(&v, "token"))),
            Vec::<String>::new(),
            "{name}: nodo says it is valid"
        );
        let mut tampered = rc.clone();
        tampered.mu_charged = Some(celaut_proto::celaut::Amount { n: "1".into() });
        assert!(!receipt::verify(&tampered, None, None), "{name}: tampered");
    }
}

#[test]
fn every_receipt_field_moves_the_digest() {
    let v = vectors();
    let full = v["receipts"]
        .as_array()
        .unwrap()
        .iter()
        .find(|r| text(r, "name") == "start_with_resources")
        .unwrap();
    let rc: ExecutionReceipt = decode(full, "receipt_hex");
    let digest = receipt::receipt_digest(&rc);
    for change in [
        |r: &mut ExecutionReceipt| r.cpu_period += 1,
        |r: &mut ExecutionReceipt| r.cpu_quota += 1,
        |r: &mut ExecutionReceipt| r.mem_limit += 1,
        |r: &mut ExecutionReceipt| r.disk_space += 1,
        |r: &mut ExecutionReceipt| r.kernel = "cd".repeat(32),
        |r: &mut ExecutionReceipt| r.devices.push("zz".into()),
        |r: &mut ExecutionReceipt| r.ts += 1,
        |r: &mut ExecutionReceipt| r.execution_name = "ee".repeat(32),
        |r: &mut ExecutionReceipt| r.envs_digest = "ee".repeat(32),
        |r: &mut ExecutionReceipt| r.signature_scheme = None,
    ] {
        let mut other = rc.clone();
        change(&mut other);
        assert_ne!(receipt::receipt_digest(&other), digest);
    }
    // The salt is not covered, as in nodo.
    let mut other = rc.clone();
    other.envs_salt = vec![9; 16];
    assert_eq!(receipt::receipt_digest(&other), digest);
}

#[test]
fn offers_match_nodo() {
    let v = vectors();
    for o in v["offers"].as_array().unwrap() {
        let name = text(o, "name");
        let peer_id = text(o, "peer_id");
        let of: EstimatedCost = decode(o, "offer_hex");
        let digest = offer::offer_digest(&of);
        assert_eq!(digest, text(o, "digest"), "{name}: digest");
        assert_eq!(offer::signed_text(peer_id, &digest), text(o, "payload"), "{name}: payload");
        assert_eq!(of.signature, text(o, "signature"));
        let committed = o["committed_until"].as_i64().unwrap();
        assert_eq!(offer::committed_until(&of, peer_id), committed, "{name}: committed_until");
        assert_eq!(offer::verify(&of, peer_id), committed > 0, "{name}: verify");
    }
    let by_name = |n: &str| -> EstimatedCost {
        let o = v["offers"].as_array().unwrap().iter().find(|o| text(o, "name") == n).unwrap();
        decode(o, "offer_hex")
    };
    let full = by_name("full");
    let peer_id = text(&v["offers"][0], "peer_id");
    assert!(offer::verify(&full, peer_id));
    assert_eq!(offer::committed_until(&full, peer_id), 1800000000);
    // Signed by another key: it does not verify for this peer, and it does for its signer.
    let other = by_name("signed_by_other");
    assert!(!offer::verify(&other, peer_id));
    let other_id = text(&v["offers"][3], "other_peer_id");
    assert!(offer::verify(&other, other_id));
    // No signature, no promise.
    assert!(!offer::verify(&by_name("no_promise_unsigned"), peer_id));
    // Each field of the offer moves the digest.
    let digest = offer::offer_digest(&full);
    for change in [
        |o: &mut EstimatedCost| o.cost.as_mut().unwrap().n.push('0'),
        |o: &mut EstimatedCost| o.init_maintenance_cost.as_mut().unwrap().n.push('0'),
        |o: &mut EstimatedCost| o.max_maintenance_cost.as_mut().unwrap().n.push('0'),
        |o: &mut EstimatedCost| o.maintenance_seconds_loop += 1,
        |o: &mut EstimatedCost| o.launch_scarcity[0].value = Some(1),
        |o: &mut EstimatedCost| o.price_bounded = !o.price_bounded,
        |o: &mut EstimatedCost| o.price_volatility += 0.5,
        |o: &mut EstimatedCost| o.volatility_period_seconds += 1,
        |o: &mut EstimatedCost| o.valid_until += 1,
        |o: &mut EstimatedCost| o.closes_at += 1,
        |o: &mut EstimatedCost| o.on_close = 0,
    ] {
        let mut o = full.clone();
        change(&mut o);
        assert_ne!(offer::offer_digest(&o), digest);
        assert!(!offer::verify(&o, peer_id));
    }
}

#[test]
fn contracts_match_nodo() {
    let v = vectors();
    for c in v["contracts"].as_array().unwrap() {
        let contract: Contract = decode(c, "contract_hex");
        assert_eq!(reputation::canonical_contract_message(&contract), text(c, "canonical"));
    }
}

#[test]
fn fault_evidence_digest_matches_nodo() {
    let v = vectors();
    let ev: FaultEvidence = decode(&v["fault_evidence"], "evidence_hex");
    assert_eq!(reputation::fault_evidence_digest(&ev), text(&v["fault_evidence"], "digest"));
}

#[test]
fn reputation_proofs_match_nodo() {
    let v = vectors();
    for p in v["proofs"].as_array().unwrap() {
        let name = text(p, "name");
        let proof: ReputationProof = decode(p, "proof_hex");
        assert_eq!(reputation::pow_base(&proof), text(p, "pow_base"), "{name}: pow_base");
        let digest = reputation::proof_digest(&proof);
        assert_eq!(digest, text(p, "digest"), "{name}: digest");
        assert_eq!(u64::from(reputation::pow_bits(&proof)), p["pow_bits"].as_u64().unwrap(), "{name}: bits");
        assert_eq!(proof.pow_nonce, p["pow_nonce"].as_u64().unwrap());
        assert_eq!(
            reputation::signed_text(&proof.publisher, &digest),
            text(p, "payload"),
            "{name}: payload"
        );
        assert_eq!(proof.signature, text(p, "signature"));
        assert!(reputation::verify(&proof), "{name}: nodo signature");
        // The signature covers the nonce.
        let mut other = proof.clone();
        other.pow_nonce += 1;
        assert!(!reputation::verify(&other), "{name}: nonce");
        let mut other = proof.clone();
        other.ts += 1;
        assert!(!reputation::verify(&other), "{name}: ts");
    }
    let mined = v["proofs"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| text(p, "name") == "mined_10_bits")
        .unwrap();
    assert!(mined["pow_bits"].as_u64().unwrap() >= 10);
}

#[test]
fn a_proof_covers_opinions_evidence_and_pointers() {
    let v = vectors();
    let find = |n: &str| -> ReputationProof {
        decode(
            v["proofs"].as_array().unwrap().iter().find(|p| text(p, "name") == n).unwrap(),
            "proof_hex",
        )
    };
    let with_evidence = find("fault_evidence");
    assert!(with_evidence.opinions[0].evidence.is_some());
    let mut other = with_evidence.clone();
    other.opinions[0].evidence.as_mut().unwrap().reason.push('x');
    assert!(!reputation::verify(&other));
    other = with_evidence.clone();
    other.opinions[0].evidence = None;
    assert!(!reputation::verify(&other));
    let pointers = find("ledger_proofs");
    // The order of the pointers does not matter.
    let mut swapped = pointers.clone();
    swapped.ledger_proofs.reverse();
    assert_eq!(reputation::proof_digest(&swapped), reputation::proof_digest(&pointers));
    assert!(reputation::verify(&swapped));
    let mut dropped = pointers.clone();
    dropped.ledger_proofs.pop();
    assert!(!reputation::verify(&dropped));
}
