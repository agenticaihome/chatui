//! The descendants of an instance that the app holds (nodo#631, `docs/celaut/descendants.md`).
//!
//! A descendant is an instance below an instance of the app. The app holds the token of
//! the ancestor only. It names the descendant by its `instance_ref`, which it finds in
//! the `child_bound` movements of a statement.
//!
//! # No automatic read
//!
//! A statement read costs MU and writes a movement on the node. So nothing in this module
//! reads by itself:
//!
//! - There is no loop, no timer and no background task.
//! - [`quote_read`] gives the maximum MU of one read. The caller shows it to the user.
//! - [`read_statement`] needs the `max_mu` of the caller and refuses a read whose maximum
//!   cost is more than it. One call is one read. The caller asks the user again for the
//!   next read.
//! - The search for descendants goes one read at a time, level by level. [`apply_read`]
//!   keeps the `child_bound` rows of a statement as new records in the state
//!   [`DescendantState::Bound`]. [`pending`] lists them, the shallowest first. The caller
//!   chooses one, quotes it, and asks the user.
//!
//! # Limits
//!
//! The depth of a descendant is limited to [`MAX_DEPTH`]. The `remaining_hops` of a read is
//! limited to [`MAX_REMAINING_HOPS`], and the app always sends it. The number of
//! descendants of one instance is limited to [`MAX_PER_INSTANCE`]. These values are
//! choices of this app, not of nodo.
//!
//! # Death with MU kept
//!
//! A `stop` movement with a `leftover` above 0 means that the MU of the account stayed
//! with the node: [`Finding::StoppedWithMu`]. A node that refuses to show the statement of
//! a descendant can hide this, and the app cannot know: [`Finding::StatementRefused`].

use celaut_proto::celaut::Peer;
use celaut_wire::gateway::get_balance_statement;
use celaut_wire::statement::{
    instance_ref as ref_of_token, KeptHead, Kind, Rates, StatementError, StatementRequest,
    VerifiedStatement,
};
use celaut_wire::{ReceiptEvent, ReceiptSink, Transport, WireError};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

use crate::db::{CelautData, CelautDb};

/// The deepest descendant that the app keeps. The held instance is depth 0, its children
/// are depth 1.
pub const MAX_DEPTH: u32 = 4;

/// The `remaining_hops` of a read, if the caller has no other value. A node asks at most
/// `remaining_hops - 1` peers, and the caller can pay at most `max(1, remaining_hops - 1)`
/// reads, so 2 means one read.
pub const DEFAULT_REMAINING_HOPS: u32 = 2;

/// The most `remaining_hops` that the app sends. It gives at most 3 reads of cost.
pub const MAX_REMAINING_HOPS: u32 = 4;

/// The most descendants that the app keeps for one instance.
pub const MAX_PER_INSTANCE: usize = 256;

/// Where a descendant is, as far as the app knows.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DescendantState {
    /// A `child_bound` row names it. The app did not read its statement.
    Bound,
    /// The last read gave a statement with no `stop` movement.
    Running,
    /// A `stop` movement ended the account. Nothing follows a `stop`.
    Stopped,
    /// The last read was refused by the node. The app does not know more.
    Refused,
}

/// A descendant (or, at depth 0, the held instance itself) as the database keeps it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DescendantRecord {
    /// The local id of the instance that the app holds.
    pub instance_id: String,
    /// The `instance_ref` of the descendant: 64 lowercase hex characters.
    pub instance_ref: String,
    /// The service of the descendant, in lowercase hex, if the node said it.
    #[serde(default)]
    pub service_id: Option<String>,
    /// The token of the held instance. A bearer secret. Each read and each tunnel names
    /// the descendant through it.
    pub parent_token: String,
    /// The `instance_ref` of the descendant that holds this one. `None` for a child of
    /// the held instance.
    #[serde(default)]
    pub parent_ref: Option<String>,
    /// The node that the held instance runs on. Statements and heads are per node.
    pub peer_id: String,
    /// 0 for the held instance, 1 for its children, and so on.
    pub depth: u32,
    /// The `seq` of the last movement that the app read. The next read starts after it.
    #[serde(default)]
    pub rows_seq: u64,
    /// The head `seq` that the node signed in the last read.
    #[serde(default)]
    pub head_seq: u64,
    /// The head hash that the node signed in the last read. Empty before a read.
    #[serde(default)]
    pub head_hash: String,
    pub state: DescendantState,
    /// The time of the last read, in Unix seconds.
    #[serde(default)]
    pub last_checked_at: Option<i64>,
    /// The `reason` of the `stop` movement.
    #[serde(default)]
    pub stop_reason: Option<String>,
    /// The `leftover` of the `stop` movement, in MU, as text.
    #[serde(default)]
    pub leftover_mu: Option<String>,
    /// True if the `refund` before the `stop` says `lost = father_gone`.
    #[serde(default)]
    pub father_gone: bool,
    /// True if the node that signed the last statement read it from another node.
    #[serde(default)]
    pub relayed: bool,
    /// The text of the last refusal of the node, if the last read was refused.
    #[serde(default)]
    pub last_refusal: Option<String>,
}

impl DescendantRecord {
    /// The head to give the next read, if the app has read one.
    pub fn kept_head(&self) -> Option<KeptHead> {
        (!self.head_hash.is_empty()).then(|| KeptHead {
            seq: self.head_seq,
            hash: self.head_hash.clone(),
        })
    }

    /// The MU that stayed with the node, if the account ended with some.
    pub fn leftover(&self) -> Option<u128> {
        self.leftover_mu.as_deref().and_then(|t| t.parse().ok())
    }
}

/// The key of a descendant in [`CelautData::descendants`].
pub fn key(instance_id: &str, instance_ref: &str) -> String {
    format!("{instance_id}/{instance_ref}")
}

/// Something that the app must show to the user.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Finding {
    /// The account ended and the MU that stayed with the node is above 0.
    StoppedWithMu {
        instance_ref: String,
        reason: String,
        leftover_mu: u128,
        /// The `refund` says `lost = father_gone`: the node did not give the MU to
        /// anyone.
        father_gone: bool,
    },
    /// The node refused to show the statement. If the descendant died with MU, the app
    /// cannot see it.
    StatementRefused {
        instance_ref: String,
        /// The state before this read.
        before: DescendantState,
        refusal: RefusalKind,
        text: String,
    },
}

/// Why a node refused to show a statement (the status of the call).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefusalKind {
    /// `PERMISSION_DENIED`: no chain below the token links the descendant.
    NotLinked,
    /// `RESOURCE_EXHAUSTED`: the caller or an instance cannot pay.
    CannotPay,
    /// `UNAVAILABLE`: the descendant or a node below does not answer.
    Unavailable,
    /// `NOT_FOUND`.
    NotFound,
    /// `UNIMPLEMENTED`: a delegated instance.
    Delegated,
    /// Another text.
    Other,
}

impl RefusalKind {
    /// The kind of the text of a failed call. It looks for the name of the gRPC status.
    pub fn of_text(text: &str) -> RefusalKind {
        let t: String = text
            .chars()
            .filter(|c| c.is_ascii_alphabetic())
            .collect::<String>()
            .to_ascii_lowercase();
        if t.contains("permissiondenied") {
            RefusalKind::NotLinked
        } else if t.contains("resourceexhausted") {
            RefusalKind::CannotPay
        } else if t.contains("unavailable") {
            RefusalKind::Unavailable
        } else if t.contains("notfound") {
            RefusalKind::NotFound
        } else if t.contains("unimplemented") {
            RefusalKind::Delegated
        } else {
            RefusalKind::Other
        }
    }
}

/// Why a descendant call was not made, or failed.
#[derive(Debug, thiserror::Error)]
pub enum DescendantError {
    /// The database has no such descendant.
    #[error("the app does not know this descendant")]
    Unknown,
    /// The descendant is on another node than the session. Nothing was sent.
    #[error("the descendant is on another node")]
    OtherNode,
    /// The node gave no `statement_query_mu` and `statement_row_mu`, so the cost is not
    /// known. Nothing was sent.
    #[error("the node does not say what a statement costs")]
    NoRates,
    /// `remaining_hops` is 0 or above [`MAX_REMAINING_HOPS`]. Nothing was sent.
    #[error("remaining_hops {hops} is not between 1 and {max}")]
    BadHops { hops: u32, max: u32 },
    /// The maximum cost of the read is above the budget. Nothing was sent.
    #[error("the read can cost {needed} MU, and the budget is {max} MU")]
    OverBudget { needed: u128, max: u128 },
    /// The quote is for another descendant than the record. Nothing was sent.
    #[error("the quote is for another descendant")]
    WrongQuote,
    /// A tunnel needs a descendant, not the held instance. Nothing was sent.
    #[error("the held instance is not a descendant: use its own tunnel")]
    NotADescendant,
    /// The read failed or its answer was refused.
    #[error(transparent)]
    Statement(#[from] StatementError),
}

impl DescendantError {
    /// True if the request went out and the node may have charged the read.
    pub fn may_have_charged(&self) -> bool {
        match self {
            DescendantError::Statement(e) => e.may_have_charged(),
            _ => false,
        }
    }

    /// The refusal of the node, if the node refused the call.
    pub fn refusal(&self) -> Option<(RefusalKind, &str)> {
        match self {
            DescendantError::Statement(StatementError::Wire(WireError::Call(text))) => {
                Some((RefusalKind::of_text(text), text))
            }
            _ => None,
        }
    }
}

// ─── Records ──────────────────────────────────────────────────────────────

/// Make the record of the held instance (depth 0), if there is none. Its statement is
/// the first one to read. Gives its key. `None` if the instance is not in the database.
pub fn ensure_root(data: &mut CelautData, instance_id: &str) -> Option<String> {
    let instance = data.instances.get(instance_id)?;
    let instance_ref = ref_of_token(&instance.token);
    let k = key(instance_id, &instance_ref);
    let record = DescendantRecord {
        instance_id: instance_id.to_string(),
        instance_ref,
        service_id: Some(instance.service_id.clone()).filter(|s| !s.is_empty()),
        parent_token: instance.token.clone(),
        parent_ref: None,
        peer_id: instance.peer_id.clone(),
        depth: 0,
        rows_seq: 0,
        head_seq: 0,
        head_hash: String::new(),
        state: DescendantState::Bound,
        last_checked_at: None,
        stop_reason: None,
        leftover_mu: None,
        father_gone: false,
        relayed: false,
        last_refusal: None,
    };
    data.descendants.entry(k.clone()).or_insert(record);
    Some(k)
}

/// The descendants of an instance (not the instance itself), the shallowest first.
pub fn of_instance<'a>(data: &'a CelautData, instance_id: &str) -> Vec<&'a DescendantRecord> {
    let mut list: Vec<&DescendantRecord> = data
        .descendants
        .values()
        .filter(|r| r.instance_id == instance_id && r.depth > 0)
        .collect();
    list.sort_by(|a, b| (a.depth, &a.instance_ref).cmp(&(b.depth, &b.instance_ref)));
    list
}

/// The descendants that the app did not read yet, the shallowest first (level by level).
/// This is a list. It reads nothing.
pub fn pending<'a>(data: &'a CelautData, instance_id: &str) -> Vec<&'a DescendantRecord> {
    of_instance(data, instance_id)
        .into_iter()
        .filter(|r| r.state == DescendantState::Bound)
        .collect()
}

impl CelautData {
    /// Delete the descendants of an instance, and their receipts. Call it when the
    /// instance is deleted.
    pub fn remove_descendants_of(&mut self, instance_id: &str) {
        let keys: Vec<String> = self
            .descendants
            .iter()
            .filter(|(_, r)| r.instance_id == instance_id)
            .map(|(k, _)| k.clone())
            .collect();
        for k in keys {
            self.descendants.remove(&k);
            self.descendant_receipts.remove(&k);
        }
    }
}

// ─── The quote and the read ───────────────────────────────────────────────

/// The maximum cost of one read, and the request that makes it. Only [`quote_read`] makes
/// one. Show [`ReadQuote::max_mu_needed`] and the node to the user, and read only after
/// the user said yes to this read.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadQuote {
    key: String,
    request: StatementRequest,
    rates: Rates,
}

impl ReadQuote {
    /// The most MU that the read can cost.
    pub fn max_mu_needed(&self) -> u128 {
        self.request.max_mu_needed(&self.rates)
    }

    /// The request that [`read_statement`] sends.
    pub fn request(&self) -> &StatementRequest {
        &self.request
    }

    /// The `remaining_hops` of the read.
    pub fn remaining_hops(&self) -> u32 {
        self.request.remaining_hops
    }
}

/// The rates of a node for a statement, from its checked advertisement.
pub fn rates_of(peer: &Peer) -> Option<Rates> {
    Rates::from_peer(peer)
}

/// The quote for the next read of `record`: the rows after the last one that the app
/// read, up to the head. `rates` are the rates that the node advertises (`None` if it
/// gives none). The quote sends nothing and costs nothing.
pub fn quote_read(
    record: &DescendantRecord,
    rates: Option<Rates>,
    remaining_hops: u32,
) -> Result<ReadQuote, DescendantError> {
    if remaining_hops == 0 || remaining_hops > MAX_REMAINING_HOPS {
        return Err(DescendantError::BadHops {
            hops: remaining_hops,
            max: MAX_REMAINING_HOPS,
        });
    }
    let rates = rates.ok_or(DescendantError::NoRates)?;
    let request = StatementRequest {
        token: record.parent_token.clone(),
        // The held instance is read through its own token.
        instance_ref: if record.depth == 0 {
            String::new()
        } else {
            record.instance_ref.clone()
        },
        from_seq: record.rows_seq.saturating_add(1),
        to_seq: 0,
        remaining_hops,
    };
    request.check()?;
    Ok(ReadQuote {
        key: key(&record.instance_id, &record.instance_ref),
        request,
        rates,
    })
}

/// Read one statement. This is one paid call.
///
/// `max_mu` is the budget that the user confirmed for this read. If the maximum cost of
/// the quote is more than `max_mu`, the call returns [`DescendantError::OverBudget`] and
/// sends nothing. The answer is checked as [`celaut_wire::statement::verify`] says: the
/// `instance_ref`, the signature against `peer_id`, the chain and the head that the record
/// kept. A node that ignores `instance_ref` gives `NoDescendants`.
pub async fn read_statement<T: Transport>(
    transport: &T,
    peer_id: &str,
    client_id: &str,
    record: &DescendantRecord,
    quote: &ReadQuote,
    max_mu: u128,
) -> Result<VerifiedStatement, DescendantError> {
    if record.peer_id != peer_id {
        return Err(DescendantError::OtherNode);
    }
    if quote.key != key(&record.instance_id, &record.instance_ref) {
        return Err(DescendantError::WrongQuote);
    }
    let needed = quote.max_mu_needed();
    if needed > max_mu {
        return Err(DescendantError::OverBudget {
            needed,
            max: max_mu,
        });
    }
    let kept = record.kept_head();
    Ok(get_balance_statement(
        transport,
        peer_id,
        client_id,
        &quote.request,
        &quote.rates,
        max_mu,
        kept.as_ref(),
    )
    .await?)
}

// ─── What a read changes ──────────────────────────────────────────────────

/// What [`apply_read`] found.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ReadReport {
    /// The `instance_ref` of each new descendant, in the order of the movements.
    pub new: Vec<String>,
    /// The children that were left out because they are deeper than [`MAX_DEPTH`].
    pub too_deep: usize,
    /// The children that were left out because the instance has [`MAX_PER_INSTANCE`].
    pub too_many: usize,
    pub findings: Vec<Finding>,
}

fn lost_father_gone(statement: &VerifiedStatement) -> bool {
    statement
        .movements
        .iter()
        .filter(|m| m.kind == Kind::Refund)
        .filter_map(|m| serde_json::from_str::<serde_json::Value>(&m.detail).ok())
        .any(|d| d.get("lost").and_then(|v| v.as_str()) == Some("father_gone"))
}

/// Keep what a verified statement says about the record `record_key`: its head, its
/// state, its `stop` and its children. `now` is in Unix seconds. This reads nothing.
/// `None` if the record is not in the database.
pub fn apply_read(
    data: &mut CelautData,
    record_key: &str,
    statement: &VerifiedStatement,
    now: i64,
) -> Option<ReadReport> {
    let mut report = ReadReport::default();
    let record = data.descendants.get_mut(record_key)?;
    if let Some(last) = statement.movements.last() {
        record.rows_seq = record.rows_seq.max(last.seq);
    }
    record.head_seq = statement.head.seq;
    record.head_hash = statement.head.hash.clone();
    record.relayed = statement.relayed;
    record.last_checked_at = Some(now);
    record.last_refusal = None;
    if !statement.service_id.is_empty() {
        record.service_id = Some(statement.service_id.clone());
    }
    if let Some(stop) = statement.stop() {
        record.state = DescendantState::Stopped;
        record.stop_reason = Some(stop.reason.clone());
        record.leftover_mu = Some(stop.leftover.to_string());
        record.father_gone = lost_father_gone(statement);
        if stop.leftover > 0 {
            report.findings.push(Finding::StoppedWithMu {
                instance_ref: record.instance_ref.clone(),
                reason: stop.reason.clone(),
                leftover_mu: stop.leftover,
                father_gone: record.father_gone,
            });
        }
    } else if record.state != DescendantState::Stopped {
        record.state = DescendantState::Running;
    }

    let parent = record.clone();
    for (child_ref, bound) in statement.children() {
        let k = key(&parent.instance_id, child_ref);
        let service_id = bound.service_id.clone().filter(|s| !s.is_empty());
        if let Some(existing) = data.descendants.get_mut(&k) {
            // A known descendant: keep what it says about the service, if nothing is.
            if existing.service_id.is_none() {
                existing.service_id = service_id;
            }
            continue;
        }
        if parent.depth + 1 > MAX_DEPTH {
            report.too_deep += 1;
            continue;
        }
        let held = data
            .descendants
            .values()
            .filter(|r| r.instance_id == parent.instance_id && r.depth > 0)
            .count();
        if held >= MAX_PER_INSTANCE {
            report.too_many += 1;
            continue;
        }
        data.descendants.insert(
            k,
            DescendantRecord {
                instance_id: parent.instance_id.clone(),
                instance_ref: child_ref.to_string(),
                service_id,
                parent_token: parent.parent_token.clone(),
                parent_ref: (parent.depth > 0).then(|| parent.instance_ref.clone()),
                peer_id: parent.peer_id.clone(),
                depth: parent.depth + 1,
                rows_seq: 0,
                head_seq: 0,
                head_hash: String::new(),
                state: DescendantState::Bound,
                last_checked_at: None,
                stop_reason: None,
                leftover_mu: None,
                father_gone: false,
                relayed: false,
                last_refusal: None,
            },
        );
        report.new.push(child_ref.to_string());
    }
    Some(report)
}

/// Keep that the node refused a read, if `error` is a refusal of the node. A stopped
/// descendant stays stopped. Other errors (a budget, a bad answer, a timeout) change
/// nothing and give `None`. A refusal can hide a death with MU kept, so this gives a
/// [`Finding::StatementRefused`].
pub fn apply_refusal(
    data: &mut CelautData,
    record_key: &str,
    error: &DescendantError,
    now: i64,
) -> Option<Finding> {
    let (refusal, text) = error.refusal()?;
    let record = data.descendants.get_mut(record_key)?;
    let before = record.state;
    record.last_checked_at = Some(now);
    record.last_refusal = Some(text.to_string());
    if before != DescendantState::Stopped {
        record.state = DescendantState::Refused;
    }
    Some(Finding::StatementRefused {
        instance_ref: record.instance_ref.clone(),
        before,
        refusal,
        text: text.to_string(),
    })
}

// ─── The receipts of a tunnel ─────────────────────────────────────────────

impl CelautData {
    /// Keep an event of a tunnel stream under the descendant `record_key`. A descendant
    /// that the database does not know keeps nothing. Gives true if it was kept.
    pub fn apply_descendant_receipt(
        &mut self,
        record_key: &str,
        event: &ReceiptEvent,
        now: i64,
    ) -> bool {
        if !self.descendants.contains_key(record_key) {
            return false;
        }
        self.descendant_receipts
            .entry(record_key.to_string())
            .or_default()
            .apply(event, now);
        true
    }
}

/// The sink for the receipts of a tunnel to a descendant. Each event goes into the
/// database in memory. The caller writes the file later with [`CelautDb::flush`], off the
/// task of the tunnel: the sink must not block. `now` gives the time in Unix seconds.
pub fn receipt_sink(
    db: Arc<CelautDb>,
    record_key: String,
    now: impl Fn() -> i64 + Send + Sync + 'static,
) -> ReceiptSink {
    Arc::new(move |event| {
        db.update_in_memory(|d| d.apply_descendant_receipt(&record_key, &event, now()));
    })
}
