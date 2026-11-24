//! The off-chain reputation proof of a node (`ReputationProof`, nodo#652 and #677).
//!
//! A port of `nodo:src/reputation_system/offchain_proof.py` (`pow_base`, `proof_digest`,
//! `pow_bits`, `verify`), `fault_proofs.digest` and `node_identity.canonical_contract_message`.
//! The node signs the UTF-8 of `celaut-reputation-proof:<publisher>|<proof_digest>`. The
//! digest is `blake2b_256(pow_base "|" pow_nonce)`, so it covers every field but the
//! signature, and the work of the proof is its number of leading zero bits. Known-answer
//! vectors made with the Python code are in `tests/vectors/wire_vectors.json`.
//!
//! The app does not weigh the opinions of a proof: this module only checks that a proof is
//! the one that its publisher signed.

use std::collections::BTreeMap;

use celaut_proto::celaut::{Contract, FaultEvidence, ReputationOpinion, ReputationProof};
use ring::signature::{UnparsedPublicKey, ED25519};

use crate::receipt::{blake2b_256_hex, canonical_scheme, normalize_key, receipt_digest, scheme_is_ours};
use crate::statement::statement_digest;

/// The prefix of the signed text (`node_identity._REPUTATION_PROOF_PREFIX`).
pub const PREFIX: &str = "celaut-reputation-proof:";

fn hex_text(text: &str) -> String {
    hex::encode(text.as_bytes())
}

fn sorted(mut items: Vec<String>) -> Vec<String> {
    items.sort();
    items
}

/// `canonical_contract_message`: a `Contract` (ledger, protocol and xattrs) as text. The
/// xattrs are by key, and the last entry of a repeated key wins.
pub fn canonical_contract_message(contract: &Contract) -> String {
    let ledger = contract.ledger.clone().unwrap_or_default();
    let protocol = contract.protocol.clone().unwrap_or_default();
    let xattrs = contract
        .xattrs
        .iter()
        .map(|e| {
            (
                e.key.as_str(),
                hex::encode(e.value.as_deref().unwrap_or_default()),
            )
        })
        .collect::<BTreeMap<_, _>>()
        .into_iter()
        .map(|(key, value)| format!("{key}={value}"))
        .collect::<Vec<_>>()
        .join(";");
    [
        hex::encode(&ledger.formal),
        sorted(ledger.tags.clone()).join(","),
        ledger.prose.clone(),
        hex::encode(&protocol.formal),
        sorted(protocol.tags.clone()).join(","),
        protocol.prose.clone(),
        xattrs,
    ]
    .join("~")
}

fn escape(text: &str) -> String {
    text.replace('\\', "\\\\").replace('|', "\\|")
}

/// `fault_proofs.digest`: Blake2b-256 hex of the signed digests of the evidence, one per
/// statement and per receipt, after the escaped `reason` and `accused`, joined by `|`.
pub fn fault_evidence_digest(evidence: &FaultEvidence) -> String {
    let mut parts = vec![escape(&evidence.reason), escape(&evidence.accused)];
    parts.extend(evidence.statements.iter().map(statement_digest));
    parts.extend(evidence.receipts.iter().map(receipt_digest));
    blake2b_256_hex(parts.join("|").as_bytes())
}

fn opinion_text(o: &ReputationOpinion) -> String {
    let evidence = o
        .evidence
        .as_ref()
        .map(fault_evidence_digest)
        .unwrap_or_default();
    [
        hex_text(&o.r#type),
        hex_text(&o.object),
        o.amount.to_string(),
        if o.positive { "1" } else { "0" }.to_string(),
        hex::encode(&o.content),
        evidence,
    ]
    .join("~")
}

/// `pow_base`: Blake2b-256 hex of `publisher|scheme|ts|opinions|pointers`, in the order of
/// the numbers of the fields. An opinion is
/// `hex(type)~hex(object)~amount~positive~hex(content)~evidence`. The pointers are the sorted
/// [`canonical_contract_message`] of each `ledger_proofs`, joined by `/`.
pub fn pow_base(p: &ReputationProof) -> String {
    let scheme = p
        .signature_scheme
        .as_ref()
        .map(canonical_scheme)
        .unwrap_or_default();
    let opinions = p
        .opinions
        .iter()
        .map(opinion_text)
        .collect::<Vec<_>>()
        .join("/");
    let pointers = sorted(
        p.ledger_proofs
            .iter()
            .map(canonical_contract_message)
            .collect(),
    )
    .join("/");
    let text = [
        p.publisher.clone(),
        scheme,
        p.ts.to_string(),
        opinions,
        pointers,
    ]
    .join("|");
    blake2b_256_hex(text.as_bytes())
}

fn pow_hash(base: &str, nonce: u64) -> String {
    blake2b_256_hex(format!("{base}|{nonce}").as_bytes())
}

/// `proof_digest`: Blake2b-256 hex of `pow_base|pow_nonce`. It covers every field but the
/// signature.
pub fn proof_digest(p: &ReputationProof) -> String {
    pow_hash(&pow_base(p), p.pow_nonce)
}

/// The number of leading zero bits of a hex digest.
fn zero_bits_hex(digest: &str) -> u32 {
    let mut bits = 0;
    for b in digest.bytes() {
        let nibble = match b {
            b'0'..=b'9' => b - b'0',
            _ => b - b'a' + 10,
        };
        if nibble == 0 {
            bits += 4;
        } else {
            return bits + nibble.leading_zeros() - 4;
        }
    }
    bits
}

/// `pow_bits`: the work of the proof, the leading zero bits of its digest.
pub fn pow_bits(p: &ReputationProof) -> u32 {
    zero_bits_hex(&proof_digest(p))
}

/// `reputation_proof_payload`: the exact text that the publisher signs.
pub fn signed_text(publisher: &str, digest: &str) -> String {
    format!("{PREFIX}{publisher}|{digest}")
}

/// `offchain_proof.verify`: whether `publisher` signed exactly this proof, in the Ed25519
/// scheme. The publisher and the signature are in lowercase hex.
pub fn verify(p: &ReputationProof) -> bool {
    if normalize_key(&p.publisher).as_deref() != Some(p.publisher.as_str())
        || p.signature.is_empty()
        || p.signature != p.signature.to_ascii_lowercase()
        || !scheme_is_ours(p.signature_scheme.as_ref())
    {
        return false;
    }
    let (Ok(key), Ok(signature)) = (hex::decode(&p.publisher), hex::decode(&p.signature)) else {
        return false;
    };
    let text = signed_text(&p.publisher, &proof_digest(p));
    UnparsedPublicKey::new(&ED25519, key)
        .verify(text.as_bytes(), &signature)
        .is_ok()
}

/// Sign `p` in place with the Ed25519 key of this `seed`: fills `publisher` and
/// `signature_scheme`. Set `pow_nonce` first. For tests and tools.
pub fn sign_with_seed(p: &mut ReputationProof, seed: &[u8; 32]) -> Result<(), String> {
    let pair =
        ring::signature::Ed25519KeyPair::from_seed_unchecked(seed).map_err(|e| e.to_string())?;
    p.publisher = hex::encode(ring::signature::KeyPair::public_key(&pair).as_ref());
    p.signature_scheme = Some(crate::receipt::receipt_scheme());
    let text = signed_text(&p.publisher, &proof_digest(p));
    p.signature = hex::encode(pair.sign(text.as_bytes()).as_ref());
    Ok(())
}
