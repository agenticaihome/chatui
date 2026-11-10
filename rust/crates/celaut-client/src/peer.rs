//! The check of a signed `Peer` (`docs/celaut/wire.md`, section 3).
//!
//! The digest is a port of `canonical_peer_content_digest` and the payload of
//! `canonical_peer_payload` (`nodo:src/identity/node_identity.py`). The text is built
//! field by field and must be the same, byte for byte, as in nodo. Known-answer vectors
//! from the Python code are in `tests/vectors`.

use std::collections::BTreeMap;

use blake2::digest::consts::U32;
use blake2::{Blake2b, Digest};
use celaut_proto::celaut::peer::signature_scheme::Protocol as SchemeProtocol;
use celaut_proto::celaut::peer::uri::Protocol;
use celaut_proto::celaut::{
    ActivityWindow, AmountKeyValue, ArchitectureResources, Contract, ContractRate, Peer, Sysresources,
};
use ring::signature::{UnparsedPublicKey, ED25519};

use crate::store::Seen;

/// A `Peer` that the client does not accept.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum PeerError {
    /// No public key or no signature.
    #[error("the node advertisement is not signed")]
    Unsigned,
    /// The signature scheme is not Ed25519 as nodo defines it.
    #[error("the node signs with a scheme that this app does not support")]
    UnsupportedScheme,
    /// The public key is not 64 lowercase hexadecimal characters.
    #[error("the node advertised a public key that is not in canonical form")]
    NonCanonicalKey,
    /// The public key is not the identity that the TLS certificate proved.
    #[error(
        "the advertisement is for node {advertised}, but the connection reached node {certificate}"
    )]
    KeyMismatch {
        /// The peer_id of the certificate.
        certificate: String,
        /// `Peer.public_key`.
        advertised: String,
    },
    /// The signature does not match the advertisement.
    #[error("the signature of the advertisement is not valid")]
    BadSignature,
    /// The `ts` is older than the last advertisement that this app accepted.
    #[error("the advertisement is older than one that was accepted before (ts {ts}, last {last})")]
    StaleTs {
        /// The `ts` of the new message.
        ts: i64,
        /// The `ts` of the last accepted message.
        last: i64,
    },
}

// ─── The digest ───────────────────────────────────────────────────────────

/// Sorted, as Python sorts strings (by code point, the same as by UTF-8 bytes).
fn sorted(mut items: Vec<String>) -> Vec<String> {
    items.sort();
    items
}

/// `keyvalue.items`: the last entry of a repeated key wins, in key order.
fn items<'a, T, V>(
    entries: &'a [T],
    key: impl Fn(&'a T) -> &'a str,
    value: impl Fn(&'a T) -> V,
) -> BTreeMap<&'a str, V> {
    entries.iter().map(|e| (key(e), value(e))).collect()
}

fn canonical_protocol_parts(formal: &[u8], tags: &[String], prose: &str) -> String {
    let tags = sorted(tags.to_vec()).join(",");
    format!("{}~{}~{}", hex::encode(formal), tags, prose)
}

fn canonical_protocol(p: &Protocol) -> String {
    canonical_protocol_parts(&p.formal, &p.tags, &p.prose)
}

fn canonical_scheme_protocol(p: &SchemeProtocol) -> String {
    canonical_protocol_parts(&p.formal, &p.tags, &p.prose)
}

fn canonical_contract_message(contract: &Contract) -> String {
    let ledger = contract.ledger.clone().unwrap_or_default();
    let xattrs = items(
        &contract.xattrs,
        |e| e.key.as_str(),
        |e| hex::encode(e.value.as_deref().unwrap_or_default()),
    )
    .into_iter()
    .map(|(key, value)| format!("{key}={value}"))
    .collect::<Vec<_>>()
    .join(";");
    [
        hex::encode(&ledger.formal),
        sorted(ledger.tags.clone()).join(","),
        ledger.prose.clone(),
        xattrs,
    ]
    .join("~")
}

fn canonical_contract(rate: &ContractRate) -> String {
    let contract = rate.contract.clone().unwrap_or_default();
    let mu = rate.mu_per_unit.clone().unwrap_or_default();
    [canonical_contract_message(&contract), mu.n].join("~")
}

fn canonical_uri(uri: &celaut_proto::celaut::peer::Uri) -> String {
    let transport = uri.transport.clone().unwrap_or_default();
    let stack = sorted(uri.protocol_stack.iter().map(canonical_protocol).collect()).join(";");
    [
        uri.ip.clone(),
        uri.port.to_string(),
        uri.expiry_unix_timestamp.to_string(),
        canonical_protocol(&transport),
        stack,
    ]
    .join("~")
}

fn canonical_sysresources(r: &Sysresources) -> String {
    let scalar = |name: &str, value: Option<u64>| match value {
        Some(v) => format!("{name}={v}"),
        None => format!("{name}="),
    };
    let scalars = [
        scalar("blkio_weight", r.blkio_weight),
        scalar("cpu_period", r.cpu_period),
        scalar("cpu_quota", r.cpu_quota),
        scalar("mem_limit", r.mem_limit),
        scalar("disk_space", r.disk_space),
    ]
    .join(",");
    // Not by key: the text of each entry is sorted, and a repeated key stays.
    let benchmark = sorted(
        r.benchmark
            .iter()
            .map(|e| match e.value {
                Some(v) => format!("{}={v}", e.key),
                None => format!("{}=", e.key),
            })
            .collect(),
    )
    .join(";");
    [scalars, benchmark].join("~")
}

fn canonical_architecture_resources(entry: &ArchitectureResources) -> String {
    let architecture = entry.architecture.clone().unwrap_or_default();
    let tags = sorted(architecture.tags.clone()).join(",");
    let protocol = format!(
        "{}~{}~{}",
        hex::encode(&architecture.formal),
        tags,
        architecture.prose
    );
    let resources = match &entry.resources {
        Some(r) => canonical_sysresources(r),
        None => "-".to_string(),
    };
    [protocol, resources].join("~")
}

fn canonical_rates(entries: &[AmountKeyValue]) -> String {
    items(
        entries,
        |e| e.key.as_str(),
        |e| e.value.clone().unwrap_or_default().n,
    )
    .into_iter()
    .map(|(key, n)| format!("{key}={n}"))
    .collect::<Vec<_>>()
    .join(";")
}

/// The `activity_window` part of the digest (nodo#344): `-` when the Peer has no window
/// (it gives no schedule), else `w:<on_close>:<spans>`, with the spans as
/// `start-end` texts sorted as text and joined by `,` (empty: always open).
fn canonical_activity_window(window: Option<&ActivityWindow>) -> String {
    let Some(window) = window else {
        return "-".to_string();
    };
    let spans = sorted(
        window
            .spans
            .iter()
            .map(|s| format!("{}-{}", s.start_minute, s.end_minute))
            .collect(),
    );
    format!("w:{}:{}", window.on_close, spans.join(","))
}

/// `canonical_peer_content_digest`: blake2b-256 over the canonical text of every
/// field of the Peer except the key, the signature and the `ts`. Lowercase hex.
pub fn content_digest(peer: &Peer) -> String {
    let uris = sorted(peer.uri.iter().map(canonical_uri).collect());
    let contracts = sorted(
        peer.payment_contracts
            .iter()
            .map(canonical_contract)
            .collect(),
    );
    let proofs = sorted(
        peer.reputation_proofs
            .iter()
            .map(canonical_contract_message)
            .collect(),
    );
    let scheme = sorted(
        peer.signature_scheme
            .clone()
            .unwrap_or_default()
            .components
            .iter()
            .map(canonical_scheme_protocol)
            .collect(),
    )
    .join(";");
    let resources = sorted(
        peer.resources
            .iter()
            .map(canonical_architecture_resources)
            .collect(),
    );
    let canonical = [
        uris.join("/"),
        contracts.join("/"),
        proofs.join("/"),
        canonical_rates(&peer.mu_per_call),
        scheme,
        resources.join("/"),
        canonical_activity_window(peer.activity_window.as_ref()),
    ]
    .join("|");
    let mut hasher = Blake2b::<U32>::new();
    hasher.update(canonical.as_bytes());
    hex::encode(hasher.finalize())
}

/// `canonical_peer_payload`: the text that the signature covers.
pub fn signed_payload(public_key: &str, ts: i64, digest: &str) -> String {
    format!("{public_key}|{ts}|{digest}")
}

// ─── The signature scheme ─────────────────────────────────────────────────

/// The `formal` of the one component of the scheme of nodo (`SIGNATURE_SCHEME_COMPONENTS`).
const ED25519_FORMAL: &str = "algorithm=eddsa\ncontext=none\ncurve=edwards25519\nmessage=as-given\nprehash=none\nprivate_key_bytes=32\npublic_key_bytes=32\npublic_key_encoding=hex-lowercase\nsignature_bytes=64\nsignature_encoding=hex-lowercase\nsignature_layout=R||S\nspec=RFC8032\nvariant=pure\nverification=RFC8032-5.1.7";

/// `speaks_our_signature_scheme`: one component that names the same thing as the
/// Ed25519 component of nodo. Two components are the same if both have a `formal` and
/// the two are equal, else if they have one tag in common (`same_component`).
fn speaks_ed25519(peer: &Peer) -> bool {
    let Some(scheme) = &peer.signature_scheme else {
        return false;
    };
    let [component] = scheme.components.as_slice() else {
        return false;
    };
    if component.tags.is_empty() && component.formal.is_empty() {
        return false;
    }
    if !component.formal.is_empty() {
        return component.formal == ED25519_FORMAL.as_bytes();
    }
    component.tags.iter().any(|t| t == "ed25519")
}

// ─── The check ────────────────────────────────────────────────────────────

fn is_canonical_key(text: &str) -> bool {
    text.len() == 64
        && text
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// Accept `ts` against the last advertisement that was accepted.
///
/// The rule of the plan is `ts` greater than the last one. A node serves the same
/// signed message again for up to 60 seconds (`_SIGNED_PEER_TTL_S` in
/// `nodo:src/gateway/utils.py`), so a second request gives the same `ts`. An equal
/// `ts` with the same content digest is accepted: it is the same message and it
/// changes nothing. An equal `ts` with another digest is not.
pub fn check_ts(last: Option<&Seen>, ts: i64, digest: &str) -> Result<(), PeerError> {
    match last {
        Some(last) if ts < last.ts || (ts == last.ts && digest != last.digest) => {
            Err(PeerError::StaleTs { ts, last: last.ts })
        }
        _ => Ok(()),
    }
}

/// Check the signature, and that the key is the `peer_id` of the TLS certificate. Gives
/// the content digest.
///
/// This does not check `ts`: see [`check_ts`].
pub fn verify_signature(peer: &Peer, certificate_peer_id: &str) -> Result<String, PeerError> {
    if peer.public_key.is_empty() || peer.signature.is_empty() {
        return Err(PeerError::Unsigned);
    }
    if !speaks_ed25519(peer) {
        return Err(PeerError::UnsupportedScheme);
    }
    if !is_canonical_key(&peer.public_key) {
        return Err(PeerError::NonCanonicalKey);
    }
    if peer.public_key != certificate_peer_id {
        return Err(PeerError::KeyMismatch {
            certificate: certificate_peer_id.to_string(),
            advertised: peer.public_key.clone(),
        });
    }
    let digest = content_digest(peer);
    let payload = signed_payload(&peer.public_key, peer.ts, &digest);
    let key = hex::decode(&peer.public_key).map_err(|_| PeerError::NonCanonicalKey)?;
    let signature = hex::decode(&peer.signature).map_err(|_| PeerError::BadSignature)?;
    UnparsedPublicKey::new(&ED25519, key)
        .verify(payload.as_bytes(), &signature)
        .map_err(|_| PeerError::BadSignature)?;
    Ok(digest)
}
