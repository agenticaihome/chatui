//! The signed price offer of a node (`EstimatedCost`, nodo#657).
//!
//! A port of `nodo:src/utils/cost_functions/signed_offer.py` (`offer_digest`, `verify`) and of
//! `offer_payload` (`nodo:src/identity/node_identity.py`). The node signs the UTF-8 of
//! `celaut-price-offer:<peer_id>|<offer_digest>` with its identity key. The digest is Blake2b-256
//! over a canonical text of every field but the signature, never over the protobuf bytes.
//! Known-answer vectors made with the Python code are in `tests/vectors/wire_vectors.json`.

use celaut_proto::celaut::{Amount, EstimatedCost};
use ring::signature::{UnparsedPublicKey, ED25519};
use std::collections::BTreeMap;

use crate::receipt::{blake2b_256_hex, normalize_key};

/// The prefix of the signed text (`node_identity._OFFER_PREFIX`).
pub const PREFIX: &str = "celaut-price-offer:";

fn hex_text(text: &str) -> String {
    hex::encode(text.as_bytes())
}

fn amount_hex(a: &Option<Amount>) -> String {
    hex_text(a.as_ref().map_or("", |a| a.n.as_str()))
}

/// The load in `offer`, in parts per million (the last entry of a key wins), sorted by key
/// (`scarcity_of`).
pub fn scarcity_of(offer: &EstimatedCost) -> BTreeMap<&str, u64> {
    offer
        .launch_scarcity
        .iter()
        .map(|e| (e.key.as_str(), e.value.unwrap_or_default()))
        .collect()
}

/// The text that [`offer_digest`] hashes: the parts, in the order of the numbers of the fields
/// in `celaut.proto`, joined by `|`: `hex(cost.n)`, `hex(init_maintenance_cost.n)`,
/// `hex(max_maintenance_cost.n)`, `maintenance_seconds_loop`, `launch_scarcity`
/// (`key=value` sorted by key, joined by `;`), `price_bounded` (1 or 0), the 4 bytes of
/// `price_volatility` (big-endian float, hex), `volatility_period_seconds`, `valid_until`,
/// `closes_at` and the number of `on_close`.
pub fn canonical_offer(offer: &EstimatedCost) -> String {
    let scarcity = scarcity_of(offer)
        .into_iter()
        .map(|(k, v)| format!("{k}={v}"))
        .collect::<Vec<_>>()
        .join(";");
    [
        amount_hex(&offer.cost),
        amount_hex(&offer.init_maintenance_cost),
        amount_hex(&offer.max_maintenance_cost),
        offer.maintenance_seconds_loop.to_string(),
        scarcity,
        if offer.price_bounded { "1" } else { "0" }.to_string(),
        hex::encode(offer.price_volatility.to_be_bytes()),
        offer.volatility_period_seconds.to_string(),
        offer.valid_until.to_string(),
        offer.closes_at.to_string(),
        offer.on_close.to_string(),
    ]
    .join("|")
}

/// `offer_digest`: Blake2b-256 hex of [`canonical_offer`].
pub fn offer_digest(offer: &EstimatedCost) -> String {
    blake2b_256_hex(canonical_offer(offer).as_bytes())
}

/// `offer_payload`: the exact text that the node signs.
pub fn signed_text(peer_id: &str, digest: &str) -> String {
    format!("{PREFIX}{peer_id}|{digest}")
}

/// `verify`: whether `peer_id` signed exactly this offer. `peer_id` must be 64 lowercase hex
/// digits. An offer with no signature is never valid.
pub fn verify(offer: &EstimatedCost, peer_id: &str) -> bool {
    if offer.signature.is_empty() || normalize_key(peer_id).as_deref() != Some(peer_id) {
        return false;
    }
    let (Ok(key), Ok(signature)) = (hex::decode(peer_id), hex::decode(&offer.signature)) else {
        return false;
    };
    let text = signed_text(peer_id, &offer_digest(offer));
    UnparsedPublicKey::new(&ED25519, key)
        .verify(text.as_bytes(), &signature)
        .is_ok()
}

/// `committed_until`: the time until which `peer_id` keeps the price of `offer`, or 0. 0 when
/// the offer promises nothing, and also when it names a time with no valid signature.
pub fn committed_until(offer: &EstimatedCost, peer_id: &str) -> i64 {
    if offer.valid_until <= 0 || !verify(offer, peer_id) {
        return 0;
    }
    offer.valid_until
}

/// Sign `offer` in place with the Ed25519 key of this `seed`. The app never signs an offer:
/// this is for tests and tools. Gives the peer id of the key.
pub fn sign_with_seed(offer: &mut EstimatedCost, seed: &[u8; 32]) -> Result<String, String> {
    let pair =
        ring::signature::Ed25519KeyPair::from_seed_unchecked(seed).map_err(|e| e.to_string())?;
    let peer_id = hex::encode(ring::signature::KeyPair::public_key(&pair).as_ref());
    offer.signature.clear();
    let text = signed_text(&peer_id, &offer_digest(offer));
    offer.signature = hex::encode(pair.sign(text.as_bytes()).as_ref());
    Ok(peer_id)
}
