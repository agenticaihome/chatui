//! The descendants of an instance (nodo#631, `docs/celaut/descendants.md`).
//!
//! An instance can start other instances, and those can start more. The app holds the
//! token of the first one only. It finds the others from the statement of the node and
//! names each by its `instance_ref`.
//!
//! # A check costs MU
//!
//! A read of a statement costs MU on the node and writes a movement there. So:
//!
//! - Nothing here reads by itself. There is no timer, no loop and no background task.
//! - [`celaut_quote_descendant_read`] gives the most MU that one read can cost. It sends
//!   nothing. The screen shows this number and asks the user, each time.
//! - [`celaut_check_descendant`] needs the `max_mu` that the user confirmed. If the read
//!   can cost more, it sends nothing. One call is one read.
//! - Two reads of the same descendant cannot run together.
//!
//! - [`celaut_quote_descendant_tunnel`] gives the most MU that one stream of a tunnel can
//!   cost to open. It sends nothing. [`celaut_open_descendant_tunnel`] needs the `max_mu`
//!   that the user confirmed. The local port opens only as many streams as that budget
//!   pays for at the maximum cost of each, and it never opens a stream again by itself.
//!
//! The list ([`celaut_descendants`]), the receipts and the slots send nothing that costs
//! MU to the node by themselves. With Tor on, each call uses the route of the app.

use std::collections::HashSet;
use std::sync::{Arc, Mutex};

use celaut_client::db::InstanceRecord;
use celaut_client::descendants::{
    self, DescendantError, DescendantRecord, DescendantState, Finding, RefusalKind,
};
use celaut_client::local_port::PortLimits;
use celaut_client::receipts::summarize_descendant;
use celaut_client::session::{api_chat_ports, api_web_ports};
use celaut_client::{ClientError, LocalPort};
use celaut_wire::statement::StatementError;
use celaut_wire::{ReceiptSink, Tunnel, TunnelOpener, WireError};
use once_cell::sync::Lazy;

use super::celaut::{error_of, invalid, CelautError, CelautErrorKind};
use super::celaut_db::{db, now_seconds, storage_error};
use super::celaut_receipts::{descendant_sink, fault_view, ReceiptsView, StartReceiptState};
use super::celaut_service::{
    address_of_key, instance, preferred_port, state, unknown_instance, NodeAddress,
};
use super::celaut_service_info::read_info;

/// The reads that run now, by the key of the descendant.
static READING: Lazy<Mutex<HashSet<String>>> = Lazy::new(|| Mutex::new(HashSet::new()));

/// Where a descendant is, as far as the app knows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DescendantStateView {
    /// A statement names it, and the app did not check it. It is not verifiable yet.
    NotChecked,
    /// The last check gave a statement with no stop. It is alive.
    Alive,
    /// A stop movement ended its account.
    Stopped,
    /// The node refused the last check. The app cannot verify it.
    NotVerifiable,
}

fn state_view(state: DescendantState) -> DescendantStateView {
    match state {
        DescendantState::Bound => DescendantStateView::NotChecked,
        DescendantState::Running => DescendantStateView::Alive,
        DescendantState::Stopped => DescendantStateView::Stopped,
        DescendantState::Refused => DescendantStateView::NotVerifiable,
    }
}

/// A descendant, or the held instance itself at depth 0. The token never leaves Rust.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DescendantView {
    /// The name of the descendant on the node: 64 lowercase hexadecimal characters.
    pub instance_ref: String,
    /// The service, as lowercase hexadecimal, if the node said it.
    pub service_id: Option<String>,
    /// 0 for the held instance, 1 for its children, and so on.
    pub depth: u32,
    /// The `instance_ref` of the descendant above this one, if it is not the held one.
    pub parent_ref: Option<String>,
    pub state: DescendantStateView,
    /// The time of the last check, in Unix seconds.
    pub last_checked_at: Option<i64>,
    /// The reason of the stop movement.
    pub stop_reason: Option<String>,
    /// The MU that stayed with the node when the account ended, as text.
    pub leftover_mu: Option<String>,
    /// The node did not give the MU to anyone: the father was gone.
    pub father_gone: bool,
    /// Another node signed the last statement for the node of the instance.
    pub relayed: bool,
    /// The text of the last refusal of the node.
    pub last_refusal: Option<String>,
    /// The last check did not reach the end of the statement: some movements are not read,
    /// and one of them can be a stop. The descendant is not shown as alive. Check again.
    pub unread_rows: bool,
}

fn view_of(r: &DescendantRecord) -> DescendantView {
    DescendantView {
        instance_ref: r.instance_ref.clone(),
        service_id: r.service_id.clone(),
        depth: r.depth,
        parent_ref: r.parent_ref.clone(),
        state: state_view(r.state),
        last_checked_at: r.last_checked_at,
        stop_reason: r.stop_reason.clone(),
        leftover_mu: r.leftover_mu.clone(),
        father_gone: r.father_gone,
        relayed: r.relayed,
        last_refusal: r.last_refusal.clone(),
        unread_rows: r.incomplete,
    }
}

/// The descendants that the app knows for an instance.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DescendantsView {
    /// The held instance. Check it to find its children.
    pub root: DescendantView,
    /// The descendants, the shallowest first.
    pub descendants: Vec<DescendantView>,
}

/// The descendants of the instance `instance_id` that the app knows. It sends nothing to
/// the node: it reads the database. A descendant appears after a check found it.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_descendants(instance_id: String) -> Result<DescendantsView, CelautError> {
    let view = db()
        .update(|d| {
            let root = descendants::ensure_root(d, &instance_id)?;
            let root = d.descendants.get(&root).map(view_of)?;
            let list = descendants::of_instance(d, &instance_id)
                .into_iter()
                .map(view_of)
                .collect();
            Some(DescendantsView {
                root,
                descendants: list,
            })
        })
        .map_err(storage_error)?;
    view.ok_or_else(unknown_instance)
}

/// Why the node refused a check.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DescendantRefusalKind {
    /// No chain below the token links the descendant.
    NotLinked,
    /// The user or an instance cannot pay.
    CannotPay,
    /// The descendant or a node below does not answer.
    Unavailable,
    NotFound,
    /// The instance is delegated to another node.
    Delegated,
    Other,
}

/// What the app must show to the user after a check.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DescendantFindingKind {
    /// The account ended and MU stayed with the node: a node killed an instance that
    /// still had MU.
    StoppedWithMu,
    /// The node refused to show the statement. If the descendant died with MU, the app
    /// cannot see it.
    StatementRefused,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DescendantFindingView {
    pub kind: DescendantFindingKind,
    pub instance_ref: String,
    /// `StoppedWithMu`: the reason of the stop movement.
    pub reason: String,
    /// `StoppedWithMu`: the MU that stayed with the node, as text.
    pub leftover_mu: Option<String>,
    /// `StoppedWithMu`: the node did not give the MU to anyone.
    pub father_gone: bool,
    /// `StatementRefused`: why.
    pub refusal: Option<DescendantRefusalKind>,
    /// `StatementRefused`: the text of the node.
    pub text: String,
}

fn refusal_view(k: RefusalKind) -> DescendantRefusalKind {
    match k {
        RefusalKind::NotLinked => DescendantRefusalKind::NotLinked,
        RefusalKind::CannotPay => DescendantRefusalKind::CannotPay,
        RefusalKind::Unavailable => DescendantRefusalKind::Unavailable,
        RefusalKind::NotFound => DescendantRefusalKind::NotFound,
        RefusalKind::Delegated => DescendantRefusalKind::Delegated,
        RefusalKind::Other => DescendantRefusalKind::Other,
    }
}

fn finding_view(f: &Finding) -> DescendantFindingView {
    match f {
        Finding::StoppedWithMu {
            instance_ref,
            reason,
            leftover_mu,
            father_gone,
        } => DescendantFindingView {
            kind: DescendantFindingKind::StoppedWithMu,
            instance_ref: instance_ref.clone(),
            reason: reason.clone(),
            leftover_mu: Some(leftover_mu.to_string()),
            father_gone: *father_gone,
            refusal: None,
            text: String::new(),
        },
        Finding::StatementRefused {
            instance_ref,
            refusal,
            text,
            ..
        } => DescendantFindingView {
            kind: DescendantFindingKind::StatementRefused,
            instance_ref: instance_ref.clone(),
            reason: String::new(),
            leftover_mu: None,
            father_gone: false,
            refusal: Some(refusal_view(*refusal)),
            text: text.clone(),
        },
    }
}

/// The most that one check can cost. It is a quote: nothing was sent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadQuoteView {
    pub instance_ref: String,
    /// The node that is asked (`host:port`).
    pub node: String,
    /// The `remaining_hops` that the check sends.
    pub remaining_hops: u32,
    /// The most MU that the check can cost, as text. The dialog shows it and starts
    /// with it as the budget.
    pub max_mu: String,
}

/// The `remaining_hops` of a check, if the screen gives none.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_descendant_default_hops() -> u32 {
    descendants::DEFAULT_REMAINING_HOPS
}

fn record_of(instance_id: &str, instance_ref: &str) -> Result<DescendantRecord, CelautError> {
    let key = descendants::key(instance_id, instance_ref);
    db().update(|d| {
        if !d.descendants.contains_key(&key) {
            // The held instance has a record when the list was read. Make it here too.
            descendants::ensure_root(d, instance_id);
        }
        // The file keeps no copy of the token: take it from the held instance.
        let token = d.instances.get(instance_id).map(|i| i.token.clone());
        d.descendants
            .get(&key)
            .cloned()
            .zip(token)
            .map(|(record, token)| record.with_token(&token))
    })
    .map_err(storage_error)?
    .ok_or_else(|| invalid("The app does not know this descendant."))
}

/// The error of the app for a descendant call that failed.
fn error_of_descendant(e: DescendantError) -> CelautError {
    match e {
        DescendantError::Statement(StatementError::Wire(w)) => error_of(ClientError::Wire(w)),
        DescendantError::Statement(StatementError::NoDescendants) => CelautError {
            kind: CelautErrorKind::NoDescendants,
            message: WireError::NoDescendants.to_string(),
        },
        DescendantError::Statement(StatementError::Invalid(m)) => CelautError {
            kind: CelautErrorKind::Protocol,
            message: m,
        },
        e @ DescendantError::ServiceChanged { .. } => CelautError {
            kind: CelautErrorKind::Protocol,
            message: e.to_string(),
        },
        other => CelautError {
            kind: CelautErrorKind::InvalidInput,
            message: other.to_string(),
        },
    }
}

fn parse_max_mu(text: &str) -> Result<u128, CelautError> {
    text.trim()
        .parse::<u128>()
        .map_err(|_| invalid("The budget must be a whole number of MU."))
}

/// The most MU that the next check of a descendant can cost. This sends nothing and costs
/// nothing. `remaining_hops` is the depth that the node can go below the instance, from 1
/// to 4 (`None` for [`celaut_descendant_default_hops`]). A node that does not say what a
/// statement costs gives an error: the check stays closed.
#[flutter_rust_bridge::frb]
pub async fn celaut_quote_descendant_read(
    instance_id: String,
    instance_ref: String,
    remaining_hops: Option<u32>,
) -> Result<ReadQuoteView, CelautError> {
    let record = record_of(&instance_id, &instance_ref)?;
    let (session, held) = instance(&instance_id).await?;
    let hops = remaining_hops.unwrap_or(descendants::DEFAULT_REMAINING_HOPS);
    let quote = session
        .quote_statement(&record, hops)
        .map_err(error_of_descendant)?;
    Ok(ReadQuoteView {
        instance_ref,
        node: held.address,
        remaining_hops: quote.remaining_hops(),
        max_mu: quote.max_mu_needed().to_string(),
    })
}

/// What a check found.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckReportView {
    /// The descendant after the check.
    pub descendant: DescendantView,
    /// The `instance_ref` of each new descendant that the statement named.
    pub new_descendants: Vec<String>,
    /// How many children the app left out because they are too deep.
    pub too_deep: u32,
    /// How many children the app left out because the instance has too many.
    pub too_many: u32,
    /// What to show to the user.
    pub findings: Vec<DescendantFindingView>,
}

/// Releases the read of a descendant when the call ends, also on an error.
struct ReadingGuard(String);

impl ReadingGuard {
    fn take(key: &str) -> Result<ReadingGuard, CelautError> {
        let mut set = READING.lock().unwrap_or_else(|e| e.into_inner());
        if !set.insert(key.to_string()) {
            return Err(invalid("A check of this descendant is already running."));
        }
        Ok(ReadingGuard(key.to_string()))
    }
}

impl Drop for ReadingGuard {
    fn drop(&mut self) {
        READING
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&self.0);
    }
}

/// Check a descendant: read its statement from the node. THIS COSTS MU.
///
/// `max_mu` is the budget that the user confirmed in the dialog, as text. It is not
/// optional. If the check can cost more, nothing is sent. The statement is verified (the
/// `instance_ref`, the signature, the chain and the head that the app kept) before the app
/// keeps anything. A node that does not know descendants gives
/// [`CelautErrorKind::NoDescendants`]. A node that refuses the statement is not an error:
/// the descendant becomes not verifiable, and the report has a finding for it.
#[flutter_rust_bridge::frb]
pub async fn celaut_check_descendant(
    instance_id: String,
    instance_ref: String,
    remaining_hops: Option<u32>,
    max_mu: String,
) -> Result<CheckReportView, CelautError> {
    let budget = parse_max_mu(&max_mu)?;
    let record = record_of(&instance_id, &instance_ref)?;
    let key = descendants::key(&instance_id, &instance_ref);
    let _reading = ReadingGuard::take(&key)?;
    let (session, _) = instance(&instance_id).await?;
    let quote = session
        .quote_statement(
            &record,
            remaining_hops.unwrap_or(descendants::DEFAULT_REMAINING_HOPS),
        )
        .map_err(error_of_descendant)?;
    match session.read_statement(&record, &quote, budget).await {
        Ok(statement) => {
            let report = db()
                .update(|d| descendants::apply_read(d, &key, &statement, now_seconds()))
                .map_err(storage_error)?
                .ok_or_else(|| invalid("The app does not know this descendant."))?;
            let descendant = db()
                .read(|d| d.descendants.get(&key).map(view_of))
                .ok_or_else(|| invalid("The app does not know this descendant."))?;
            Ok(CheckReportView {
                descendant,
                new_descendants: report.new,
                too_deep: u32::try_from(report.too_deep).unwrap_or(u32::MAX),
                too_many: u32::try_from(report.too_many).unwrap_or(u32::MAX),
                findings: report.findings.iter().map(finding_view).collect(),
            })
        }
        Err(e) => {
            // A reason that the app knows (a client the node forgot, a limit of rate) is an
            // error. Another refusal of the node is a result: the app cannot verify.
            let known_reason = match &e {
                DescendantError::Statement(StatementError::Wire(WireError::Call(text))) => {
                    celaut_client::refusal::classify(text).is_some()
                }
                _ => false,
            };
            if !known_reason {
                let finding = db()
                    .update(|d| descendants::apply_refusal(d, &key, &e, now_seconds()))
                    .map_err(storage_error)?;
                if let Some(finding) = finding {
                    let descendant = db()
                        .read(|d| d.descendants.get(&key).map(view_of))
                        .ok_or_else(|| invalid("The app does not know this descendant."))?;
                    return Ok(CheckReportView {
                        descendant,
                        new_descendants: Vec::new(),
                        too_deep: 0,
                        too_many: 0,
                        findings: vec![finding_view(&finding)],
                    });
                }
            }
            Err(error_of_descendant(e))
        }
    }
}

/// The receipts of the tunnels to a descendant. A descendant has no start receipt, so the
/// start is `None`. The names in the receipts are checked against its `instance_ref`.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_descendant_receipts(
    instance_id: String,
    instance_ref: String,
) -> Result<ReceiptsView, CelautError> {
    let key = descendants::key(&instance_id, &instance_ref);
    let (record, receipts) = db()
        .read(|d| {
            d.descendants
                .get(&key)
                .map(|r| (r.clone(), d.descendant_receipts.get(&key).cloned()))
        })
        .ok_or_else(|| invalid("The app does not know this descendant."))?;
    let s = summarize_descendant(
        &receipts.unwrap_or_default(),
        &record.peer_id,
        &record.instance_ref,
    );
    Ok(ReceiptsView {
        start: StartReceiptState::None,
        checkpoints: s.checkpoints,
        streams: s.streams,
        dropped_streams: s.dropped_streams,
        closed: s.closed,
        cancelled: s.cancelled,
        no_close: s.no_close,
        faults: s.faults.iter().map(fault_view).collect(),
    })
}

/// The ports that the service of a descendant declares.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DescendantSlotsView {
    /// False if the app does not know the service or could not read its interface. Then
    /// nothing opens.
    pub known: bool,
    /// The ports that follow the chat convention.
    pub chat_slots: Vec<u16>,
    /// The ports that a browser can open.
    pub web_slots: Vec<u16>,
}

fn node_of(held: &InstanceRecord) -> Option<NodeAddress> {
    address_of_key(&held.address)
}

/// What the service of a descendant declares. The app reads it from the library file, or
/// from the node of the instance. It does not guess: no service id, or an interface that
/// the app could not read, gives `known = false`.
#[flutter_rust_bridge::frb]
pub async fn celaut_descendant_slots(
    instance_id: String,
    instance_ref: String,
) -> Result<DescendantSlotsView, CelautError> {
    let record = record_of(&instance_id, &instance_ref)?;
    let held = db()
        .read(|d| d.instances.get(&instance_id).cloned())
        .ok_or_else(unknown_instance)?;
    declared_slots(&record, node_of(&held)).await
}

async fn declared_slots(
    record: &DescendantRecord,
    node: Option<NodeAddress>,
) -> Result<DescendantSlotsView, CelautError> {
    let none = DescendantSlotsView {
        known: false,
        chat_slots: Vec::new(),
        web_slots: Vec::new(),
    };
    let Some(service) = record.service_id.as_deref().filter(|s| !s.is_empty()) else {
        return Ok(none);
    };
    let info = read_info(service, node).await?;
    if !info.interface_known() {
        return Ok(none);
    }
    let Some(api) = info.api.as_ref() else {
        return Ok(none);
    };
    Ok(DescendantSlotsView {
        known: true,
        chat_slots: api_chat_ports(api),
        web_slots: api_web_ports(api),
    })
}

/// The most that one stream of a tunnel to a descendant can cost to open. It is a quote:
/// nothing was sent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TunnelQuoteView {
    pub instance_ref: String,
    /// The node that is asked (`host:port`).
    pub node: String,
    /// The `remaining_hops` that each stream sends.
    pub remaining_hops: u32,
    /// The `tunnel_open_mu` of the node, as text.
    pub open_mu: String,
    /// The most MU that the opening of one stream can cost, as text: the fee of each leg,
    /// up to `remaining_hops` legs. The dialog shows it and starts with it as the budget.
    /// The traffic after the opening costs more, and this number does not cover it.
    pub max_mu_per_stream: String,
}

/// The most MU that the opening of one stream to a descendant can cost. This sends nothing
/// and costs nothing. `remaining_hops` is from 1 to 4 (`None` for
/// [`celaut_descendant_default_hops`]). A node that does not say its fee gives an error:
/// the tunnel stays closed.
#[flutter_rust_bridge::frb]
pub async fn celaut_quote_descendant_tunnel(
    instance_id: String,
    instance_ref: String,
    remaining_hops: Option<u32>,
) -> Result<TunnelQuoteView, CelautError> {
    let record = record_of(&instance_id, &instance_ref)?;
    let (session, held) = instance(&instance_id).await?;
    let quote = session
        .quote_tunnel(
            &record,
            remaining_hops.unwrap_or(descendants::DEFAULT_REMAINING_HOPS),
        )
        .map_err(error_of_descendant)?;
    Ok(TunnelQuoteView {
        instance_ref,
        node: held.address,
        remaining_hops: quote.remaining_hops(),
        open_mu: quote.open_mu().to_string(),
        max_mu_per_stream: quote.max_mu_per_stream().to_string(),
    })
}

/// Opens the tunnel of a local port as a tunnel to a descendant. The port keeps the token
/// of the held instance, and each stream names the descendant and sends the hop budget
/// that the user saw in the quote.
struct DescendantOpener {
    inner: Arc<dyn TunnelOpener>,
    instance_ref: String,
    remaining_hops: u32,
}

impl TunnelOpener for DescendantOpener {
    fn open_tunnel(&self, token: &str, slot: u16, receipts: Option<ReceiptSink>) -> Tunnel {
        self.inner.open_descendant_tunnel(
            token,
            &self.instance_ref,
            slot,
            Some(self.remaining_hops),
            receipts,
        )
    }
}

/// A port on 127.0.0.1 for a slot of a descendant, as [`celaut_open_tunnel`] gives for an
/// instance. Each TCP connection to it opens one `DescendantTunnel` stream, and the node
/// charges each one. THIS CAN COST MU.
///
/// `max_mu` is the budget that the user confirmed after [`celaut_quote_descendant_tunnel`],
/// as text. It is not optional. The port opens at most `max_mu / max_mu_per_stream`
/// streams, and a connection after that is closed with no stream. The port never opens a
/// stream again by itself after a failure. A call for a port that is open adds the streams
/// that the new budget pays for. `remaining_hops` is from 1 to 4 (`None` for
/// [`celaut_descendant_default_hops`]) and each stream sends it.
///
/// The slot must be one that the service declares (a chat or a web port), and the
/// descendant must be alive after a check: a node asks for a read of its statement first.
/// A node that does not know descendants ends the streams, and the error is
/// [`CelautErrorKind::NoDescendants`] in the receipts and in the page.
///
/// [`celaut_open_tunnel`]: super::celaut_service::celaut_open_tunnel
#[flutter_rust_bridge::frb]
pub async fn celaut_open_descendant_tunnel(
    instance_id: String,
    instance_ref: String,
    slot: u16,
    remaining_hops: Option<u32>,
    max_mu: String,
) -> Result<u16, CelautError> {
    let budget = parse_max_mu(&max_mu)?;
    let record = record_of(&instance_id, &instance_ref)?;
    if record.depth == 0 {
        return Err(invalid("This is the held instance. Use its own tunnel."));
    }
    if record.state != DescendantState::Running {
        return Err(invalid(
            "Check the descendant first. The app opens a tunnel only to a descendant that was checked and is alive.",
        ));
    }
    let (session, held) = instance(&instance_id).await?;
    if held.hibernated_at.is_some() {
        return Err(invalid("This instance is hibernated. Wake it first."));
    }
    let hops = remaining_hops.unwrap_or(descendants::DEFAULT_REMAINING_HOPS);
    let quote = session
        .quote_tunnel(&record, hops)
        .map_err(error_of_descendant)?;
    let streams = quote.streams_for(budget).map_err(error_of_descendant)?;
    let declared = declared_slots(&record, node_of(&held)).await?;
    if !declared.known
        || !(declared.chat_slots.contains(&slot) || declared.web_slots.contains(&slot))
    {
        return Err(invalid("The service does not declare this slot."));
    }
    let key = descendants::key(&instance_id, &instance_ref);
    let opener: Arc<dyn TunnelOpener> = Arc::new(DescendantOpener {
        inner: Arc::new(session.transport().clone()),
        instance_ref: record.instance_ref.clone(),
        remaining_hops: quote.remaining_hops(),
    });
    {
        let mut s = state()?;
        let ports = s.descendant_ports.entry(key.clone()).or_default();
        match ports.get(&slot) {
            Some(port) if port.is_alive() => {
                port.set_opener(opener);
                port.allow_streams(streams);
                return Ok(port.port());
            }
            Some(_) => {
                ports.remove(&slot);
            }
            None => {}
        }
    }
    // No try again: a stream that is opened again is a stream that the user did not count.
    let limits = PortLimits {
        max_streams: Some(streams),
        retries: 0,
    };
    let port = LocalPort::bind_limited(
        opener,
        record.parent_token.clone(),
        slot,
        Some(descendant_sink(key.clone())),
        Some(preferred_port(&key, slot)),
        limits,
    )
    .await
    .map_err(|e| CelautError {
        kind: CelautErrorKind::Unreachable,
        message: format!("cannot open a local port: {e}"),
    })?;
    let mut s = state()?;
    Ok(s.descendant_ports
        .entry(key)
        .or_default()
        .entry(slot)
        .or_insert(port)
        .port())
}

#[cfg(test)]
mod tests {
    use super::*;
    use celaut_client::db::InstanceRecord;
    use celaut_wire::Tunnel;

    fn held(id: &str) {
        db().update(|d| {
            d.instances.insert(
                id.into(),
                InstanceRecord {
                    peer_id: "1".repeat(64),
                    address: "h:1".into(),
                    token: format!("token-of-{id}"),
                    service_id: "2".repeat(64),
                    slots: vec![8080],
                    chat_slots: vec![],
                    web_slots: vec![],
                    started_at: 1,
                    start_charge_mu: None,
                    name: None,
                    alias: None,
                    title: None,
                    topped_up_mu: None,
                    stopped_at: None,
                    refund_mu: None,
                    pricing: None,
                    keep_alive: None,
                    awake_resources: None,
                    awake_source: None,
                    hibernated_at: None,
                    hibernated_price: None,
                },
            );
        })
        .unwrap();
    }

    #[test]
    fn the_list_gives_the_held_instance_and_reads_nothing() {
        held("desc-list");
        let v = celaut_descendants("desc-list".into()).unwrap();
        assert_eq!(v.root.depth, 0);
        assert_eq!(v.root.state, DescendantStateView::NotChecked);
        assert_eq!(v.root.last_checked_at, None);
        assert!(v.descendants.is_empty());
        assert!(celaut_descendants("desc-unknown".into()).is_err());
    }

    #[test]
    fn the_budget_must_be_a_whole_number() {
        assert_eq!(parse_max_mu(" 120 ").unwrap(), 120);
        assert!(parse_max_mu("").is_err());
        assert!(parse_max_mu("-1").is_err());
        assert!(parse_max_mu("1.5").is_err());
    }

    #[test]
    fn a_missing_service_id_gives_unknown_slots() {
        let mut r = {
            held("desc-slots");
            record_of(
                "desc-slots",
                &celaut_wire::statement::instance_ref("token-of-desc-slots"),
            )
            .unwrap()
        };
        r.service_id = None;
        let v = tokio::runtime::Builder::new_current_thread()
            .build()
            .unwrap()
            .block_on(declared_slots(&r, None))
            .unwrap();
        assert!(!v.known);
        assert!(v.chat_slots.is_empty() && v.web_slots.is_empty());
    }

    #[test]
    fn a_second_read_of_the_same_descendant_is_refused_until_the_first_ends() {
        let first = ReadingGuard::take("a/b").unwrap();
        assert!(ReadingGuard::take("a/b").is_err());
        assert!(ReadingGuard::take("a/c").is_ok());
        drop(first);
        assert!(ReadingGuard::take("a/b").is_ok());
    }

    #[test]
    fn a_stop_with_leftover_shows_in_the_view() {
        let mut r = {
            held("desc-stop");
            record_of(
                "desc-stop",
                &celaut_wire::statement::instance_ref("token-of-desc-stop"),
            )
            .unwrap()
        };
        r.state = DescendantState::Stopped;
        r.leftover_mu = Some("40".into());
        let v = view_of(&r);
        assert_eq!(v.state, DescendantStateView::Stopped);
        assert_eq!(v.leftover_mu.as_deref(), Some("40"));
    }

    #[test]
    fn the_token_comes_from_the_held_instance_and_not_from_the_file() {
        held("desc-token");
        let r = record_of(
            "desc-token",
            &celaut_wire::statement::instance_ref("token-of-desc-token"),
        )
        .unwrap();
        assert_eq!(r.parent_token, "token-of-desc-token");
        // The stored record has no token, as the file does not keep one.
        let stored = db()
            .read(|d| {
                d.descendants
                    .values()
                    .find(|x| x.instance_id == "desc-token")
                    .map(|x| serde_json::to_string(x).unwrap())
            })
            .unwrap();
        assert!(!stored.contains("token-of-desc-token"), "{stored}");
    }

    /// An opener that keeps the arguments of each descendant stream.
    struct Spy {
        calls: Mutex<Vec<(String, String, u16, Option<u32>)>>,
    }

    impl TunnelOpener for Spy {
        fn open_tunnel(&self, _t: &str, _s: u16, _r: Option<ReceiptSink>) -> Tunnel {
            panic!("a descendant stream must use open_descendant_tunnel");
        }

        fn open_descendant_tunnel(
            &self,
            token: &str,
            instance_ref: &str,
            slot: u16,
            remaining_hops: Option<u32>,
            _receipts: Option<ReceiptSink>,
        ) -> Tunnel {
            self.calls.lock().unwrap().push((
                token.into(),
                instance_ref.into(),
                slot,
                remaining_hops,
            ));
            let (to_service, _) = tokio::sync::mpsc::channel(1);
            let (_, from_service) = tokio::sync::mpsc::channel(1);
            Tunnel {
                to_service,
                from_service,
            }
        }
    }

    #[tokio::test]
    async fn each_stream_of_a_descendant_port_sends_the_hop_budget() {
        let spy = Arc::new(Spy {
            calls: Mutex::new(Vec::new()),
        });
        let opener = DescendantOpener {
            inner: spy.clone(),
            instance_ref: "r".repeat(64),
            remaining_hops: 3,
        };
        let _ = opener.open_tunnel("tok", 8080, None);
        assert_eq!(
            spy.calls.lock().unwrap()[0],
            ("tok".into(), "r".repeat(64), 8080, Some(3)),
            "the hops are never absent"
        );
    }

    #[tokio::test]
    async fn opening_needs_a_budget_that_is_a_whole_number_before_anything_else() {
        held("desc-open");
        let iref = celaut_wire::statement::instance_ref("token-of-desc-open");
        for bad in ["", "-1", "1.5", "x"] {
            let e = celaut_open_descendant_tunnel(
                "desc-open".into(),
                iref.clone(),
                8080,
                Some(2),
                bad.into(),
            )
            .await
            .unwrap_err();
            assert_eq!(e.kind, CelautErrorKind::InvalidInput, "{bad}");
            assert!(e.message.contains("whole number"), "{}", e.message);
        }
        // The held instance and a descendant that was not checked get no port.
        let e = celaut_open_descendant_tunnel("desc-open".into(), iref, 8080, Some(2), "9".into())
            .await
            .unwrap_err();
        assert!(e.message.contains("held instance"), "{}", e.message);
    }
}
