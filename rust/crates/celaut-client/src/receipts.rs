//! The execution receipts that the app keeps (nodo#419, `docs/celaut/receipts.md`).
//!
//! A node signs a `start` receipt when it starts an instance, and checkpoints and a
//! `close` on each tunnel stream ([`celaut_wire::receipt`]). The app checks each one when
//! it comes, and keeps them in the Celaut database, per instance
//! ([`InstanceReceipts`]). They are evidence against the node: the user can export them
//! ([`export_jsonl`]) in the form that `nodo receipt verify` reads, and give them to
//! someone else.
//!
//! Some checks can only be made when the receipt comes: the chains of a checkpoint
//! against the bytes that the phone sent and got, and the envs digest against the
//! variables that the phone sent. The app does not keep these bytes, so it keeps what
//! it found ([`Fault`]). The signature and the shape of a stored receipt are checked
//! again each time the app reads them ([`summarize`]).

use std::collections::BTreeMap;

use celaut_proto::celaut::{BytesKeyValue, ExecutionReceipt};
use celaut_wire::receipt::{self, Origin, KIND_CLOSE};
use celaut_wire::{ReceiptEvent, StreamReceipt};
use data_encoding::BASE64;
use prost::Message;
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};

/// How many tunnel streams the app keeps for one instance. A chat opens a stream for
/// each HTTP connection; the oldest streams go first.
pub const MAX_STREAMS: usize = 64;

/// How many receipts with a fault the app keeps for one stream.
pub const MAX_EVIDENCE: usize = 8;

/// How many receipts that failed the check the app keeps for one instance, in one
/// bucket. These receipts do not take a stream slot.
pub const MAX_INVALID: usize = 16;

/// What the phone found wrong in a receipt when it came.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "fault", rename_all = "snake_case")]
pub enum Fault {
    /// The receipt does not verify: the signature, the shape, the node or the token.
    Invalid { reason: String },
    /// The receipt is valid, but it breaks the order of the stream: a receipt after the
    /// close, a seq that does not go up, or a change of session. It is still stored.
    Order { reason: String },
    /// The `in` chain is not the chain of the bytes that the phone sent.
    Sent,
    /// The `out` chain is not the chain of the bytes that the phone got.
    Received,
    /// The envs digest is not the digest of the variables that the phone sent.
    Envs,
    /// The service of the start receipt is not the service that the phone asked for.
    Service,
    /// The node signed a start amount that is not the start balance that the phone
    /// asked for.
    Amount { signed: String, asked: String },
    /// The node gave no start receipt, but the app knows that the node gives them.
    Omitted,
}

/// A receipt as the database keeps it: the protobuf bytes, and what the phone found
/// when it came.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StoredReceipt {
    /// The `ExecutionReceipt`, protobuf bytes in lowercase hex.
    pub proto: String,
    #[serde(default)]
    pub faults: Vec<Fault>,
}

impl StoredReceipt {
    pub fn new(receipt: &ExecutionReceipt, faults: Vec<Fault>) -> Self {
        StoredReceipt {
            proto: hex::encode(receipt.encode_to_vec()),
            faults,
        }
    }

    /// The receipt, if the stored bytes are one.
    pub fn receipt(&self) -> Option<ExecutionReceipt> {
        ExecutionReceipt::decode(hex::decode(&self.proto).ok()?.as_slice()).ok()
    }
}

/// One tunnel stream of an instance.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct StreamRecord {
    /// The time of the first receipt, in Unix seconds.
    pub first_at: i64,
    /// How many checkpoints came, the close too.
    pub checkpoints: u64,
    /// The last checkpoint, if no close came: the highest `seq` is what a dispute reads.
    #[serde(default)]
    pub last: Option<StoredReceipt>,
    /// The close.
    #[serde(default)]
    pub close: Option<StoredReceipt>,
    /// The receipts that had a fault, up to [`MAX_EVIDENCE`].
    #[serde(default)]
    pub evidence: Vec<StoredReceipt>,
    /// True when the stream ended.
    #[serde(default)]
    pub ended: bool,
    /// True if the phone ended the stream. Then the node sends no close, and that is not
    /// a fault.
    #[serde(default)]
    pub cancelled: bool,
}

/// The receipts of one instance.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstanceReceipts {
    /// The start receipt. `None` if the node gave none (a node without receipts).
    #[serde(default)]
    pub start: Option<StoredReceipt>,
    /// The tunnel streams, by session.
    #[serde(default)]
    pub streams: BTreeMap<String, StreamRecord>,
    /// Streams that the app dropped over [`MAX_STREAMS`]. The streams with no fault go
    /// first, the oldest first.
    #[serde(default)]
    pub dropped_streams: u64,
    /// The receipts that failed the check (the signature, the node, the token or the
    /// shape), up to [`MAX_INVALID`]. The node chose their session, so they have no
    /// stream. A receipt that cannot be read is not here.
    #[serde(default)]
    pub invalid: Vec<StoredReceipt>,
    /// The faults of the receipts that failed the check, with no repeat, up to
    /// [`MAX_INVALID`].
    #[serde(default)]
    pub invalid_faults: Vec<Fault>,
    /// True if the app knows that the node of this instance gives receipts: it gave a
    /// start receipt for an instance before. Then a missing start receipt is a fault.
    #[serde(default)]
    pub expects_start: bool,
}

/// The faults of a checked stream receipt.
fn faults_of(checked: &StreamReceipt) -> Vec<Fault> {
    let mut faults: Vec<Fault> = checked
        .problems
        .iter()
        .map(|p| Fault::Invalid { reason: p.clone() })
        .collect();
    faults.extend(
        checked
            .ordering
            .iter()
            .map(|p| Fault::Order { reason: p.clone() }),
    );
    if checked.sent_mismatch {
        faults.push(Fault::Sent);
    }
    if checked.got_mismatch {
        faults.push(Fault::Received);
    }
    faults
}

impl InstanceReceipts {
    /// Keep an event of a tunnel stream. `now` is in Unix seconds.
    pub fn apply(&mut self, event: &ReceiptEvent, now: i64) {
        match event {
            ReceiptEvent::Receipt(checked) => {
                let session = checked.receipt.session.clone();
                let faults = faults_of(checked);
                // The node chose the session of a receipt that failed the check. Such a
                // receipt does not take a stream slot.
                if !checked.problems.is_empty() || session.is_empty() {
                    self.keep_invalid(&checked.receipt, faults);
                    return;
                }
                let stored = StoredReceipt::new(&checked.receipt, faults.clone());
                if !self.streams.contains_key(&session) {
                    self.make_room();
                }
                let stream = self.streams.entry(session).or_insert_with(|| StreamRecord {
                    first_at: now,
                    ..Default::default()
                });
                stream.checkpoints += 1;
                if !faults.is_empty() && stream.evidence.len() < MAX_EVIDENCE {
                    stream.evidence.push(stored.clone());
                }
                // A receipt with an ordering fault is valid and signed, so it is stored.
                // The first close stays. A checkpoint with a lower seq does not replace
                // a checkpoint with a higher seq.
                if checked.receipt.kind == KIND_CLOSE {
                    if stream.close.is_none() {
                        stream.close = Some(stored);
                        stream.last = None;
                    }
                } else if stream.close.is_none() {
                    let newer = stream
                        .last
                        .as_ref()
                        .and_then(StoredReceipt::receipt)
                        .is_none_or(|old| checked.receipt.seq >= old.seq);
                    if newer {
                        stream.last = Some(stored);
                    }
                }
            }
            ReceiptEvent::Ended {
                session: Some(session),
                cancelled,
                ..
            } => {
                if let Some(stream) = self.streams.get_mut(session) {
                    stream.ended = true;
                    stream.cancelled = *cancelled;
                }
            }
            // A stream with no receipt: nothing to keep.
            ReceiptEvent::Ended { session: None, .. } => {}
        }
    }

    /// Keep a receipt that failed the check in the bucket. A receipt with no field
    /// (the app could not decode it) gives a fault but is not stored.
    fn keep_invalid(&mut self, receipt: &ExecutionReceipt, mut faults: Vec<Fault>) {
        if faults.is_empty() {
            faults.push(Fault::Invalid {
                reason: "the receipt has no session".to_string(),
            });
        }
        for fault in &faults {
            if self.invalid_faults.len() < MAX_INVALID && !self.invalid_faults.contains(fault) {
                self.invalid_faults.push(fault.clone());
            }
        }
        if *receipt != ExecutionReceipt::default() && self.invalid.len() < MAX_INVALID {
            self.invalid.push(StoredReceipt::new(receipt, faults));
        }
    }

    /// Drop the oldest stream with no fault. If all the streams have a fault, drop the
    /// oldest of them.
    fn make_room(&mut self) {
        while self.streams.len() >= MAX_STREAMS {
            let oldest = self
                .streams
                .iter()
                .min_by_key(|(_, s)| (!s.evidence.is_empty(), s.first_at))
                .map(|(k, _)| k.clone());
            let Some(oldest) = oldest else { break };
            self.streams.remove(&oldest);
            self.dropped_streams += 1;
        }
    }

    /// The receipts that the app keeps, in the order of the export: the start, then each
    /// stream (its receipts with a fault, then its last checkpoint or its close).
    pub fn stored(&self) -> Vec<&StoredReceipt> {
        let mut out: Vec<&StoredReceipt> = self.start.iter().collect();
        out.extend(self.invalid.iter());
        let mut streams: Vec<&StreamRecord> = self.streams.values().collect();
        streams.sort_by_key(|s| s.first_at);
        for s in streams {
            for r in s.evidence.iter().chain(s.last.iter()).chain(s.close.iter()) {
                if !out.iter().any(|o| o.proto == r.proto) {
                    out.push(r);
                }
            }
        }
        out
    }
}

/// Check the start receipt of an instance that this phone started: signed by the node
/// of the connection (`peer_id`), named by `token`, for the service `service_id`, with the
/// digest of the variables that the phone sent, and, if the phone asked for a start
/// balance, that amount.
pub fn check_start(
    r: &ExecutionReceipt,
    peer_id: &str,
    token: &str,
    service_id: &[u8; 32],
    envs: &[BytesKeyValue],
    initial_mu: Option<&str>,
) -> Vec<Fault> {
    let mut faults: Vec<Fault> = receipt::problems(r, Some(peer_id), Some(token))
        .into_iter()
        .map(|reason| Fault::Invalid { reason })
        .collect();
    if faults.is_empty() && r.kind != receipt::KIND_START {
        faults.push(Fault::Invalid {
            reason: format!("the answer of the start has a {} receipt", r.kind),
        });
    }
    if !faults.is_empty() {
        return faults;
    }
    if r.service_id
        .as_ref()
        .is_none_or(|s| s.r#type != celaut_wire::gateway::SHA3_256_TYPE || s.value != service_id)
    {
        faults.push(Fault::Service);
    }
    // With the salt of the receipt, which must be 16 bytes.
    if !receipt::envs_match(
        r,
        &receipt::service_envs(envs),
        &BTreeMap::<String, Origin>::new(),
        None,
    ) {
        faults.push(Fault::Envs);
    }
    let signed = r
        .initial_mu
        .as_ref()
        .map(|a| a.n.clone())
        .unwrap_or_default();
    if let Some(asked) = initial_mu.filter(|a| !a.is_empty()) {
        if signed != asked {
            faults.push(Fault::Amount {
                signed,
                asked: asked.to_string(),
            });
        }
    }
    faults
}

/// What the app shows about the receipts of one instance.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ReceiptSummary {
    /// `None` if the node gave no start receipt; else whether it is good.
    pub start_ok: Option<bool>,
    /// How many checkpoints came on all the streams, the closes too.
    pub checkpoints: u64,
    /// The streams that the app keeps.
    pub streams: u64,
    /// The streams that the app dropped over [`MAX_STREAMS`].
    pub dropped_streams: u64,
    /// The streams with a close.
    pub closed: u64,
    /// The streams that the phone ended (no close, and not a fault).
    pub cancelled: u64,
    /// The streams that ended with no close, and that the phone did not end: for example
    /// the node stopped the instance. A missing close is not by itself a fault.
    pub no_close: u64,
    /// Everything wrong, the start first. Empty when all is good.
    pub faults: Vec<Fault>,
}

/// The summary of the receipts of an instance. The stored receipts are checked again
/// against the node and the token: a receipt that was changed in the database shows as
/// [`Fault::Invalid`].
pub fn summarize(receipts: &InstanceReceipts, peer_id: &str, token: &str) -> ReceiptSummary {
    summarize_named(receipts, peer_id, receipt::Execution::Token(token))
}

/// [`summarize`] for the receipts of a tunnel to a descendant: the name of the execution
/// is the one that `instance_ref` gives, not the one of a token.
pub fn summarize_descendant(
    receipts: &InstanceReceipts,
    peer_id: &str,
    instance_ref: &str,
) -> ReceiptSummary {
    summarize_named(
        receipts,
        peer_id,
        receipt::Execution::InstanceRef(instance_ref),
    )
}

fn summarize_named(
    receipts: &InstanceReceipts,
    peer_id: &str,
    execution: receipt::Execution<'_>,
) -> ReceiptSummary {
    let mut summary = ReceiptSummary {
        dropped_streams: receipts.dropped_streams,
        ..Default::default()
    };
    let again = |stored: &StoredReceipt| -> Vec<Fault> {
        let mut faults = stored.faults.clone();
        let now = match stored.receipt() {
            Some(r) => receipt::problems_named(&r, Some(peer_id), Some(execution)),
            None => vec!["the stored receipt cannot be read".to_string()],
        };
        for reason in now {
            let fault = Fault::Invalid { reason };
            if !faults.contains(&fault) {
                faults.push(fault);
            }
        }
        faults
    };
    if let Some(start) = &receipts.start {
        let faults = again(start);
        summary.start_ok = Some(faults.is_empty());
        summary.faults.extend(faults);
    } else if receipts.expects_start {
        summary.start_ok = Some(false);
        summary.faults.push(Fault::Omitted);
    }
    for stored in &receipts.invalid {
        for fault in again(stored) {
            if !summary.faults.contains(&fault) {
                summary.faults.push(fault);
            }
        }
    }
    for fault in &receipts.invalid_faults {
        if !summary.faults.contains(fault) {
            summary.faults.push(fault.clone());
        }
    }
    for stream in receipts.streams.values() {
        summary.streams += 1;
        summary.checkpoints += stream.checkpoints;
        if stream.close.is_some() {
            summary.closed += 1;
        } else if stream.cancelled {
            summary.cancelled += 1;
        } else if stream.ended {
            summary.no_close += 1;
        }
        for stored in stream
            .evidence
            .iter()
            .chain(stream.last.iter())
            .chain(stream.close.iter())
        {
            for fault in again(stored) {
                if !summary.faults.contains(&fault) {
                    summary.faults.push(fault);
                }
            }
        }
    }
    summary
}

// ─── The export ───────────────────────────────────────────────────────────

/// The proto3 JSON form of a receipt, with the field names of `celaut.proto`, as
/// `json_format.MessageToDict(preserving_proto_field_name=True)` gives it: a field with
/// its default value is not there, bytes are base64, and 64-bit integers are strings.
/// `nodo receipt verify` reads it.
pub fn to_json(r: &ExecutionReceipt) -> Value {
    let mut out = Map::new();
    let mut text = |name: &str, value: &str| {
        if !value.is_empty() {
            out.insert(name.into(), json!(value));
        }
    };
    text("kind", &r.kind);
    text("peer_id", &r.peer_id);
    text("execution_name", &r.execution_name);
    let number = |out: &mut Map<String, Value>, name: &str, value: String, zero: bool| {
        if !zero {
            out.insert(name.into(), json!(value));
        }
    };
    number(&mut out, "ts", r.ts.to_string(), r.ts == 0);
    if let Some(s) = &r.service_id {
        let mut hash = Map::new();
        if !s.r#type.is_empty() {
            hash.insert("type".into(), json!(BASE64.encode(&s.r#type)));
        }
        if !s.value.is_empty() {
            hash.insert("value".into(), json!(BASE64.encode(&s.value)));
        }
        out.insert("service_id".into(), Value::Object(hash));
    }
    let amount = |a: &celaut_proto::celaut::Amount| {
        let mut m = Map::new();
        if !a.n.is_empty() {
            m.insert("n".into(), json!(a.n));
        }
        Value::Object(m)
    };
    if !r.envs_digest.is_empty() {
        out.insert("envs_digest".into(), json!(r.envs_digest));
    }
    if !r.envs_salt.is_empty() {
        out.insert("envs_salt".into(), json!(BASE64.encode(&r.envs_salt)));
    }
    if let Some(a) = &r.initial_mu {
        out.insert("initial_mu".into(), amount(a));
    }
    for (name, value) in [
        ("plane", &r.plane),
        ("session", &r.session),
        ("slot", &r.slot),
    ] {
        if !value.is_empty() {
            out.insert(name.into(), json!(value));
        }
    }
    number(&mut out, "seq", r.seq.to_string(), r.seq == 0);
    number(
        &mut out,
        "in_events",
        r.in_events.to_string(),
        r.in_events == 0,
    );
    number(
        &mut out,
        "in_bytes",
        r.in_bytes.to_string(),
        r.in_bytes == 0,
    );
    if !r.in_head.is_empty() {
        out.insert("in_head".into(), json!(r.in_head));
    }
    number(
        &mut out,
        "out_events",
        r.out_events.to_string(),
        r.out_events == 0,
    );
    number(
        &mut out,
        "out_bytes",
        r.out_bytes.to_string(),
        r.out_bytes == 0,
    );
    if !r.out_head.is_empty() {
        out.insert("out_head".into(), json!(r.out_head));
    }
    if let Some(a) = &r.mu_charged {
        out.insert("mu_charged".into(), amount(a));
    }
    for (name, value) in [
        ("coverage", &r.coverage),
        ("capture_mode", &r.capture_mode),
        ("degraded_reason", &r.degraded_reason),
    ] {
        if !value.is_empty() {
            out.insert(name.into(), json!(value));
        }
    }
    if let Some(scheme) = &r.signature_scheme {
        let components: Vec<Value> = scheme
            .components
            .iter()
            .map(|c| {
                let mut m = Map::new();
                if !c.tags.is_empty() {
                    m.insert("tags".into(), json!(c.tags));
                }
                if !c.prose.is_empty() {
                    m.insert("prose".into(), json!(c.prose));
                }
                if !c.formal.is_empty() {
                    m.insert("formal".into(), json!(BASE64.encode(&c.formal)));
                }
                Value::Object(m)
            })
            .collect();
        let mut m = Map::new();
        if !components.is_empty() {
            m.insert("components".into(), Value::Array(components));
        }
        out.insert("signature_scheme".into(), Value::Object(m));
    }
    if !r.signature.is_empty() {
        out.insert("signature".into(), json!(r.signature));
    }
    Value::Object(out)
}

/// The receipts of an instance as JSON Lines, one receipt on each line: the file that
/// `nodo receipt verify <file> --token <token> --peer <peer_id>` checks. The token is not
/// in it. A stored receipt that cannot be read, or that has no field, is left out.
pub fn export_jsonl(receipts: &InstanceReceipts) -> String {
    receipts
        .stored()
        .into_iter()
        .filter_map(StoredReceipt::receipt)
        // A receipt with no field is not a receipt: it would be a `{}` line.
        .filter(|r| *r != ExecutionReceipt::default())
        .map(|r| to_json(&r).to_string() + "\n")
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use celaut_proto::celaut::metadata::hash_tag::Hash;
    use celaut_proto::celaut::Amount;
    use celaut_wire::gateway::SHA3_256_TYPE;
    use celaut_wire::receipt::{sign_with_seed, Chain, DIRECTION_IN, DIRECTION_OUT};

    const KEY: [u8; 32] = [7u8; 32];
    const TOKEN: &str = "tok";
    const ID: [u8; 32] = [9u8; 32];
    const SALT: [u8; 16] = [1u8; 16];

    fn peer_id() -> String {
        let mut r = ExecutionReceipt::default();
        sign_with_seed(&mut r, &KEY).unwrap();
        r.peer_id
    }

    fn kv(k: &str, v: &[u8]) -> BytesKeyValue {
        BytesKeyValue {
            key: k.into(),
            value: Some(v.to_vec()),
        }
    }

    fn start(envs: &[BytesKeyValue], mu: &str) -> ExecutionReceipt {
        let mut r = ExecutionReceipt {
            kind: receipt::KIND_START.into(),
            execution_name: receipt::execution_name(TOKEN, &peer_id()).unwrap(),
            ts: 100,
            service_id: Some(Hash {
                r#type: SHA3_256_TYPE.to_vec(),
                value: ID.to_vec(),
            }),
            envs_digest: receipt::envs_digest(
                &receipt::service_envs(envs),
                &SALT,
                &BTreeMap::new(),
            ),
            envs_salt: SALT.to_vec(),
            initial_mu: Some(Amount { n: mu.into() }),
            ..Default::default()
        };
        sign_with_seed(&mut r, &KEY).unwrap();
        r
    }

    fn checkpoint(kind: &str, session: &str, seq: u64, ins: &[&[u8]]) -> ExecutionReceipt {
        let i = receipt::replay_chain(ins.iter().copied(), DIRECTION_IN);
        let o = Chain::default();
        let mut r = ExecutionReceipt {
            kind: kind.into(),
            execution_name: receipt::execution_name(TOKEN, &peer_id()).unwrap(),
            ts: 100 + seq as i64,
            plane: receipt::PLANE_TUNNEL.into(),
            session: session.into(),
            slot: "8080".into(),
            seq,
            in_events: i.events,
            in_bytes: i.bytes,
            in_head: i.head,
            out_events: o.events,
            out_bytes: o.bytes,
            out_head: o.head,
            mu_charged: Some(Amount { n: "10000".into() }),
            coverage: receipt::COVERAGE_CLIENT_TUNNEL.into(),
            ..Default::default()
        };
        let _ = DIRECTION_OUT;
        sign_with_seed(&mut r, &KEY).unwrap();
        r
    }

    fn good(r: ExecutionReceipt) -> ReceiptEvent {
        ReceiptEvent::Receipt(StreamReceipt {
            receipt: r,
            problems: vec![],
            ordering: vec![],
            sent_mismatch: false,
            got_mismatch: false,
        })
    }

    #[test]
    fn a_start_receipt_of_what_the_phone_sent_is_good() {
        let envs = [kv("A", b"1"), kv(receipt::RESERVED_ENV, b"name")];
        let r = start(&envs, "1000000");
        assert_eq!(
            check_start(&r, &peer_id(), TOKEN, &ID, &envs, Some("1000000")),
            vec![]
        );
        assert_eq!(check_start(&r, &peer_id(), TOKEN, &ID, &envs, None), vec![]);
    }

    #[test]
    fn a_start_receipt_of_other_envs_service_amount_or_token_is_a_fault() {
        let envs = [kv("A", b"1")];
        let r = start(&envs, "1000000");
        assert_eq!(
            check_start(&r, &peer_id(), TOKEN, &ID, &[kv("A", b"2")], None),
            vec![Fault::Envs]
        );
        assert_eq!(
            check_start(&r, &peer_id(), TOKEN, &[8u8; 32], &envs, None),
            vec![Fault::Service]
        );
        assert_eq!(
            check_start(&r, &peer_id(), TOKEN, &ID, &envs, Some("5")),
            vec![Fault::Amount {
                signed: "1000000".into(),
                asked: "5".into()
            }]
        );
        assert!(matches!(
            check_start(&r, &peer_id(), "other", &ID, &envs, None).as_slice(),
            [Fault::Invalid { .. }]
        ));
        let other = "1".repeat(64);
        assert!(matches!(
            check_start(&r, &other, TOKEN, &ID, &envs, None).as_slice(),
            [Fault::Invalid { .. }]
        ));
    }

    #[test]
    fn the_streams_are_kept_and_summed() {
        let mut kept = InstanceReceipts {
            start: Some(StoredReceipt::new(&start(&[], "1"), vec![])),
            ..Default::default()
        };
        let a = "aa".repeat(16);
        let b = "bb".repeat(16);
        kept.apply(
            &good(checkpoint(receipt::KIND_CHECKPOINT, &a, 1, &[b"x"])),
            1,
        );
        kept.apply(&good(checkpoint(receipt::KIND_CLOSE, &a, 2, &[b"x"])), 2);
        kept.apply(
            &ReceiptEvent::Ended {
                session: Some(a.clone()),
                closed: true,
                cancelled: false,
            },
            2,
        );
        kept.apply(
            &good(checkpoint(receipt::KIND_CHECKPOINT, &b, 1, &[b"y"])),
            3,
        );
        kept.apply(
            &ReceiptEvent::Ended {
                session: Some(b.clone()),
                closed: false,
                cancelled: true,
            },
            3,
        );
        // A stream that the node ended with no close, and one that is still open.
        let c = "dd".repeat(16);
        let d = "ee".repeat(16);
        kept.apply(
            &good(checkpoint(receipt::KIND_CHECKPOINT, &c, 1, &[b"z"])),
            4,
        );
        kept.apply(
            &ReceiptEvent::Ended {
                session: Some(c.clone()),
                closed: false,
                cancelled: false,
            },
            4,
        );
        kept.apply(
            &good(checkpoint(receipt::KIND_CHECKPOINT, &d, 1, &[b"w"])),
            5,
        );
        let s = summarize(&kept, &peer_id(), TOKEN);
        assert_eq!(
            s,
            ReceiptSummary {
                start_ok: Some(true),
                checkpoints: 5,
                streams: 4,
                dropped_streams: 0,
                closed: 1,
                cancelled: 1,
                no_close: 1,
                faults: vec![],
            }
        );
        // The start, the close of a (its checkpoint goes), the last checkpoint of b, c, d.
        let jsonl = export_jsonl(&kept);
        let lines: Vec<&str> = jsonl.lines().collect();
        assert_eq!(lines.len(), 5);
        let first: Value = serde_json::from_str(lines[0]).unwrap();
        assert_eq!(first["kind"], "start");
        assert_eq!(first["ts"], "100");
        assert_eq!(first["envs_salt"], BASE64.encode(&SALT));
        assert!(
            first.get("seq").is_none(),
            "a default value is not in the JSON"
        );
        let close: Value = serde_json::from_str(lines[1]).unwrap();
        assert_eq!(close["kind"], "close");
        assert_eq!(close["mu_charged"]["n"], "10000");
        assert_eq!(
            close["signature_scheme"]["components"][0]["tags"][0],
            "ed25519"
        );
    }

    #[test]
    fn a_mismatch_is_kept_as_evidence_and_shown() {
        let mut kept = InstanceReceipts::default();
        let s = "cc".repeat(16);
        kept.apply(
            &ReceiptEvent::Receipt(StreamReceipt {
                receipt: checkpoint(receipt::KIND_CHECKPOINT, &s, 1, &[b"x"]),
                problems: vec![],
                ordering: vec![],
                sent_mismatch: false,
                got_mismatch: true,
            }),
            1,
        );
        let summary = summarize(&kept, &peer_id(), TOKEN);
        assert_eq!(summary.faults, vec![Fault::Received]);
        assert_eq!(summary.start_ok, None);
        assert_eq!(export_jsonl(&kept).lines().count(), 1);
    }

    #[test]
    fn a_changed_stored_receipt_shows_as_invalid() {
        let mut stored = StoredReceipt::new(&start(&[], "1"), vec![]);
        let mut r = stored.receipt().unwrap();
        r.initial_mu = Some(Amount { n: "2".into() });
        stored.proto = hex::encode(r.encode_to_vec());
        let kept = InstanceReceipts {
            start: Some(stored),
            ..Default::default()
        };
        let s = summarize(&kept, &peer_id(), TOKEN);
        assert_eq!(s.start_ok, Some(false));
        assert!(matches!(s.faults.as_slice(), [Fault::Invalid { .. }]));
    }

    #[test]
    fn the_oldest_streams_go_first() {
        let mut kept = InstanceReceipts::default();
        for n in 0..(MAX_STREAMS as u64 + 2) {
            let session = format!("{n:032x}");
            kept.apply(
                &good(checkpoint(receipt::KIND_CHECKPOINT, &session, 1, &[b"x"])),
                n as i64,
            );
        }
        assert_eq!(kept.streams.len(), MAX_STREAMS);
        assert_eq!(kept.dropped_streams, 2);
        assert!(!kept.streams.contains_key(&format!("{:032x}", 0)));
    }

    fn bad(r: ExecutionReceipt) -> ReceiptEvent {
        ReceiptEvent::Receipt(StreamReceipt {
            receipt: r,
            problems: vec!["the signature does not verify".into()],
            ordering: vec![],
            sent_mismatch: false,
            got_mismatch: false,
        })
    }

    #[test]
    fn a_stream_with_a_fault_stays_while_a_clean_one_can_go() {
        let mut kept = InstanceReceipts::default();
        // The oldest stream has a fault.
        kept.apply(
            &ReceiptEvent::Receipt(StreamReceipt {
                receipt: checkpoint(receipt::KIND_CHECKPOINT, &format!("{:032x}", 0), 1, &[b"x"]),
                problems: vec![],
                ordering: vec![],
                sent_mismatch: true,
                got_mismatch: false,
            }),
            0,
        );
        for n in 1..(MAX_STREAMS as u64 + 5) {
            let session = format!("{n:032x}");
            kept.apply(
                &good(checkpoint(receipt::KIND_CHECKPOINT, &session, 1, &[b"x"])),
                n as i64,
            );
        }
        assert_eq!(kept.streams.len(), MAX_STREAMS);
        assert_eq!(kept.dropped_streams, 5);
        assert!(kept.streams.contains_key(&format!("{:032x}", 0)));
        let s = summarize(&kept, &peer_id(), TOKEN);
        assert_eq!(s.dropped_streams, 5);
        assert_eq!(s.faults, vec![Fault::Sent]);
    }

    #[test]
    fn a_receipt_that_failed_the_check_takes_no_stream_slot() {
        let mut kept = InstanceReceipts::default();
        for n in 0..(MAX_INVALID as u64 * 3) {
            let session = format!("{n:032x}");
            kept.apply(
                &bad(checkpoint(receipt::KIND_CHECKPOINT, &session, 1, &[b"x"])),
                n as i64,
            );
        }
        // An undecodable receipt is a default receipt.
        kept.apply(&bad(ExecutionReceipt::default()), 1);
        assert!(kept.streams.is_empty());
        assert_eq!(kept.dropped_streams, 0);
        assert_eq!(kept.invalid.len(), MAX_INVALID);
        let s = summarize(&kept, &peer_id(), TOKEN);
        assert!(!s.faults.is_empty());
        assert_eq!(s.streams, 0);
        let jsonl = export_jsonl(&kept);
        assert_eq!(jsonl.lines().count(), MAX_INVALID);
        assert!(jsonl.lines().all(|l| l != "{}"));
        // Only a default receipt: a fault, and nothing to export.
        let mut only = InstanceReceipts::default();
        only.apply(&bad(ExecutionReceipt::default()), 1);
        assert!(only.invalid.is_empty());
        assert_eq!(summarize(&only, &peer_id(), TOKEN).faults.len(), 1);
        assert_eq!(export_jsonl(&only), "");
    }

    #[test]
    fn a_missing_start_receipt_is_a_fault_if_the_node_gave_one_before() {
        let mut kept = InstanceReceipts::default();
        let s = summarize(&kept, &peer_id(), TOKEN);
        assert_eq!((s.start_ok, s.faults.len()), (None, 0));
        kept.expects_start = true;
        let s = summarize(&kept, &peer_id(), TOKEN);
        assert_eq!(s.start_ok, Some(false));
        assert_eq!(s.faults, vec![Fault::Omitted]);
    }

    #[test]
    fn a_receipt_with_an_ordering_fault_is_still_stored() {
        let mut kept = InstanceReceipts::default();
        let s = "dd".repeat(16);
        let order = |r: ExecutionReceipt, why: &str| {
            ReceiptEvent::Receipt(StreamReceipt {
                receipt: r,
                problems: vec![],
                ordering: vec![why.to_string()],
                sent_mismatch: false,
                got_mismatch: false,
            })
        };
        kept.apply(
            &order(checkpoint(receipt::KIND_CLOSE, &s, 2, &[b"x"]), "late"),
            1,
        );
        let stream = &kept.streams[&s];
        assert!(stream.close.is_some());
        assert!(matches!(
            stream.close.as_ref().unwrap().faults.as_slice(),
            [Fault::Order { .. }]
        ));
        assert_eq!(stream.evidence.len(), 1);
        assert!(kept.invalid.is_empty());
    }
}
