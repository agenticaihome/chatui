//! Issue #136: add MU to an instance or take it back, and the balance and the spending of
//! each node (`docs/celaut/spending.md`).
//!
//! - [`celaut_move_instance_mu`] moves credit of the client to an instance, or back
//!   (`ModifyDeposit`). Nothing goes on a ledger, and nothing is signed.
//! - [`celaut_node_credit`] reads the balance of the client on a node (`GetClientMetrics`,
//!   free).
//! - The spending comes from the signed balance statements of the node. A read costs MU, so
//!   each read is one call with the budget that the user confirmed:
//!   [`celaut_quote_node_statement`] then [`celaut_read_node_statement`] for the account of
//!   the client, and [`celaut_quote_instance_statement`] then
//!   [`celaut_read_instance_statement`] for the account of one instance. The app never
//!   reads in the background.
//! - [`celaut_node_spending`] and [`celaut_spending_overview`] read the database only: the
//!   sums of the reads so far, for today, the last 7 days or all ([`SpendingPeriod`]). A
//!   value that the app did not read is empty ("unknown"). The node screen also gives the
//!   balances of the running instances ([`celaut_live_instance_balances`], free): the MU
//!   that they still hold is not spent.
//! - The statement of an instance and the check of its descendants (depth 0) read the same
//!   account: they share one cursor ([`shared_rows_seq`]), and each read is kept in both.

use std::collections::BTreeSet;
use std::sync::Mutex;

use celaut_client::db::{CelautData, InstanceRecord};
use celaut_client::descendants;
use celaut_client::spending::{day_of, Owner, SpendingError, Sums, Tally};
use celaut_wire::statement::VerifiedStatement;
use celaut_wire::statement::{account_ref, instance_ref, StatementError};
use celaut_wire::WireError;
use celaut_client::ClientError;
use once_cell::sync::Lazy;

use super::celaut::{error_of, invalid, CelautError, CelautErrorKind};
use super::celaut_db::{db, now_seconds, storage_error};
use super::celaut_descendants::ReadingGuard;
use super::celaut_service::{
    address_of_key, instance, session, unknown_instance, NodeAddress, Session, TopUpView,
};

// ─── Add and take back MU ─────────────────────────────────────────────────

fn parse_mu(text: &str) -> Result<u128, CelautError> {
    match text.trim().parse::<u128>() {
        Ok(mu) if mu > 0 && i128::try_from(mu).is_ok() => Ok(mu),
        _ => Err(invalid("The amount must be a whole number of MU above zero.")),
    }
}

fn add_text(before: Option<&str>, mu: u128) -> String {
    let before: u128 = before.and_then(|t| t.parse().ok()).unwrap_or(0);
    before.saturating_add(mu).to_string()
}

/// Move `amount_mu` MU between the credit of the client on the node of the instance and the
/// instance (`ModifyDeposit`): to the instance, or back from it when `take_back` is true.
/// This moves credit that the client already has on the node. Nothing goes on a ledger,
/// and the node charges no fee for it.
///
/// The app checks before it asks the node: the amount is above 0; to add, the credit is at
/// least the amount ([`CelautErrorKind::InsufficientCredit`]); to take back, the balance of
/// the instance is at least the amount ([`CelautErrorKind::InvalidInput`]). A refusal of the
/// node is a [`CelautErrorKind::Protocol`] error with the text of the node. The record of
/// the instance keeps what the user moved, for the cost so far.
#[flutter_rust_bridge::frb]
pub async fn celaut_move_instance_mu(
    instance_id: String,
    amount_mu: String,
    take_back: bool,
) -> Result<TopUpView, CelautError> {
    let mu = parse_mu(&amount_mu)?;
    let (session, record) = instance(&instance_id).await?;
    if take_back {
        let balance = session
            .instance_balance(&record.token)
            .await
            .map_err(error_of)?;
        if balance < mu {
            return Err(invalid(&format!(
                "The instance has {balance} MU: it cannot give back {mu} MU."
            )));
        }
        session.take_back(&record.token, mu).await.map_err(error_of)?;
    } else {
        let credit = session.balance().await.map_err(error_of)?;
        if credit < mu {
            return Err(CelautError {
                kind: CelautErrorKind::InsufficientCredit,
                message: format!("credit {credit} MU, add {mu} MU"),
            });
        }
        session.top_up(&record.token, mu).await.map_err(error_of)?;
    }
    db().update(|d| {
        if let Some(r) = d.instances.get_mut(&instance_id) {
            if take_back {
                r.withdrawn_mu = Some(add_text(r.withdrawn_mu.as_deref(), mu));
            } else {
                r.added_mu = Some(add_text(r.added_mu.as_deref(), mu));
            }
        }
    })
    .map_err(storage_error)?;
    let instance_balance = session
        .instance_balance(&record.token)
        .await
        .map(|b| b.to_string())
        .unwrap_or_default();
    let client_balance = session
        .balance()
        .await
        .map(|b| b.to_string())
        .unwrap_or_default();
    Ok(TopUpView {
        instance_balance_mu: instance_balance,
        client_balance_mu: client_balance,
    })
}

/// The balance of the client of the app on the node, in MU (`GetClientMetrics`). It is
/// free. It does not make a client: a node with no client of the app gives an error.
#[flutter_rust_bridge::frb]
pub async fn celaut_node_credit(node: NodeAddress) -> Result<String, CelautError> {
    let session = session(&node).await?;
    let credit = session.balance().await.map_err(error_of)?;
    Ok(credit.to_string())
}

/// The fee that the node of the instance advertises for a move of MU
/// (`modify_deposit_mu` in `Peer.mu_per_call`), in MU; empty if it advertises none (nodo
/// charges nothing today). It reads what the app already knows of the node.
#[flutter_rust_bridge::frb]
pub async fn celaut_move_fee(instance_id: String) -> Result<String, CelautError> {
    let (session, _) = instance(&instance_id).await?;
    Ok(session
        .modify_deposit_fee()
        .filter(|fee| *fee > 0)
        .map(|fee| fee.to_string())
        .unwrap_or_default())
}

// ─── The views ────────────────────────────────────────────────────────────

/// The movements that a view sums (Josemi, PR #148).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpendingPeriod {
    /// Every movement that the app read.
    All,
    /// The movements of today, on the clock of the device.
    Today,
    /// The movements of the last 7 days, today included.
    Week,
}

/// The first day ([`day_of`]) of `period` at `now`, or `None` for all of them.
fn from_day(period: SpendingPeriod, now: i64, utc_offset_s: i32) -> Option<i64> {
    let today = day_of(now, utc_offset_s);
    match period {
        SpendingPeriod::All => None,
        SpendingPeriod::Today => Some(today),
        SpendingPeriod::Week => Some(today - 6),
    }
}

/// The balance of one running instance now (`GetMetrics`, free).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LiveBalanceView {
    /// The `instance_ref` of the instance.
    pub instance_ref: String,
    /// Its balance, in MU.
    pub balance_mu: String,
}

/// The MU of one kind of movement of an account.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KindFlowView {
    /// The kind, as the node writes it: `maintenance`, `tunnel`, `build`, ...
    pub kind: String,
    /// The MU that left the account.
    pub out_mu: String,
    /// The MU that came in.
    pub in_mu: String,
}

/// What the reads of one account say, for one [`SpendingPeriod`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AccountSpendingView {
    /// The time of the last read, in Unix seconds; 0 before any read.
    pub read_at: i64,
    /// The balance at the head of the last read, in MU (empty before a read).
    pub balance_mu: String,
    /// What the account spent in the period, in MU (empty before a read). On the view of a
    /// node, the MU that the running instances still hold is taken out
    /// ([`NodeSpendingView::in_instances_mu`]).
    pub spent_mu: String,
    /// What came in: payments and free credit for a client; for an instance, also the
    /// start and the MU that was added.
    pub received_mu: String,
    /// What the account gave back to its father (an instance only).
    pub returned_mu: String,
    /// The time of the first movement that the app read, in Unix seconds; 0 if none.
    pub since: i64,
    /// True if the node no longer held the first movements: the sums start at `since`.
    pub partial: bool,
    /// True if the last read did not reach the head: read again to go on.
    pub incomplete: bool,
    /// True if a `stop` movement ended the account.
    pub stopped: bool,
    /// The MU of each kind of movement, the largest outflow first. A kind that moves
    /// nothing is left out.
    pub kinds: Vec<KindFlowView>,
}

/// One instance of the client on a node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstanceSpendingView {
    /// The `instance_ref` of the instance: the name that the statements give it.
    pub instance_ref: String,
    /// The local id of the instance, if the app still has it (empty if it was deleted).
    pub instance_id: String,
    /// True if the app has the instance, it was not stopped, and the statement of the
    /// client has no `refund` to it (the node gives back what is left at the stop).
    pub running: bool,
    /// The MU that went from the credit to the instance and did not come back in the
    /// period, from the statement of the client (empty if the app did not read it yet).
    pub moved_mu: String,
    /// The balance of the running instance now, if the screen read it (empty if not).
    pub live_mu: String,
    /// What the instance spent of it: `moved_mu` less the part of `live_mu` that it holds
    /// (at most `moved_mu`: the MU still held is the MU moved last). `moved_mu` when the
    /// balance now is not known.
    pub spent_mu: String,
    /// What the statement of the instance says, if the app read it.
    pub costs: Option<AccountSpendingView>,
}

/// The balance and the spending of the client of the app on one node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodeSpendingView {
    pub peer_id: String,
    /// The address (`host:port`) that the app knows last.
    pub address: String,
    /// What the reads of the account of the client say (`read_at` 0: never read).
    pub account: AccountSpendingView,
    /// What the reads of statements cost (the `statement_query` movements that the app
    /// read), in MU.
    pub statements_mu: String,
    /// The MU of starts whose instance the statement did not name yet.
    pub starting_mu: String,
    /// The instances of the client on the node: the ones that the statement names and the
    /// ones that the app has.
    pub instances: Vec<InstanceSpendingView>,
    /// The MU that the running instances still hold and that `account.spent_mu` does not
    /// count (empty if the screen gave no balance now).
    pub in_instances_mu: String,
    /// The running instances whose balance now is not known: their MU counts as spent.
    pub live_unknown: u32,
}

fn text_of(v: Option<i128>) -> String {
    v.map(|v| v.to_string()).unwrap_or_default()
}

fn account_view(t: Option<&Tally>, from: Option<i64>) -> AccountSpendingView {
    let Some(t) = t.filter(|t| t.read_at.is_some()) else {
        return AccountSpendingView {
            read_at: 0,
            balance_mu: String::new(),
            spent_mu: String::new(),
            received_mu: String::new(),
            returned_mu: String::new(),
            since: 0,
            partial: false,
            incomplete: false,
            stopped: false,
            kinds: Vec::new(),
        };
    };
    let sums = t.sums(from);
    let mut kinds: Vec<KindFlowView> = sums
        .kinds
        .iter()
        .filter(|(_, f)| f.out_mu != 0 || f.in_mu != 0)
        .map(|(k, f)| KindFlowView {
            kind: k.clone(),
            out_mu: f.out_mu.to_string(),
            in_mu: f.in_mu.to_string(),
        })
        .collect();
    kinds.sort_by(|a, b| {
        let (x, y): (i128, i128) = (a.out_mu.parse().unwrap_or(0), b.out_mu.parse().unwrap_or(0));
        y.cmp(&x).then_with(|| a.kind.cmp(&b.kind))
    });
    AccountSpendingView {
        read_at: t.read_at.unwrap_or(0),
        balance_mu: text_of(t.balance_mu),
        spent_mu: t.balance_mu.map(|_| sums.spent_mu(t.owner).to_string()).unwrap_or_default(),
        received_mu: sums.received_mu(t.owner).to_string(),
        returned_mu: sums.returned_mu(t.owner).to_string(),
        since: t.first_ts.unwrap_or(0),
        partial: t.partial,
        incomplete: t.incomplete,
        stopped: t.stopped,
        kinds,
    }
}

/// The `account_ref` of the current client of the app on the node, if it has one.
fn client_ref(d: &CelautData, peer_id: &str) -> Option<String> {
    d.nodes
        .get(peer_id)
        .map(|n| n.client_id.as_str())
        .filter(|c| !c.is_empty())
        .map(account_ref)
}

/// The tally of an instance: its account on its node.
fn instance_tally<'a>(d: &'a CelautData, r: &InstanceRecord) -> Option<&'a Tally> {
    d.tallies
        .get(&account_ref(&r.token))
        .filter(|t| t.peer_id == r.peer_id && t.owner == Owner::Instance)
}

/// The tally of the client of the app on the node, if the app read it.
fn node_tally<'a>(d: &'a CelautData, peer_id: &str) -> Option<&'a Tally> {
    client_ref(d, peer_id)
        .and_then(|r| d.tallies.get(&r))
        .filter(|t| t.peer_id == peer_id && t.owner == Owner::Client)
}

/// True if the instance `r` runs as far as the app knows: it has no stop, and the
/// statement of the client has no `refund` to it.
fn is_running(tally: Option<&Tally>, r: &InstanceRecord) -> bool {
    r.stopped_at.is_none()
        && !tally.is_some_and(|t| t.stopped_instances.contains(&instance_ref(&r.token)))
}

fn parse_i128(text: &str) -> Option<i128> {
    text.trim().parse().ok()
}

/// The view of the node `peer_id` for `period`. `live` holds the balances now of the
/// running instances that the screen read; `None` if it read none (the home screen).
fn node_view(
    d: &CelautData,
    peer_id: &str,
    from: Option<i64>,
    live: Option<&[LiveBalanceView]>,
) -> NodeSpendingView {
    let tally = node_tally(d, peer_id);
    let sums: Option<Sums> = tally.filter(|t| t.read_at.is_some()).map(|t| t.sums(from));
    let address = d
        .nodes
        .get(peer_id)
        .and_then(|n| n.addresses.first().cloned())
        .unwrap_or_default();
    // The instances of the app on this node, by instance_ref, the newest first.
    let mut own: Vec<(&String, &InstanceRecord)> = d
        .instances
        .iter()
        .filter(|(_, r)| r.peer_id == peer_id && !r.token.is_empty())
        .collect();
    own.sort_by(|a, b| b.1.started_at.cmp(&a.1.started_at));
    let mut seen = BTreeSet::new();
    let mut instances = Vec::new();
    let mut in_instances: i128 = 0;
    let mut live_unknown = 0u32;
    for (id, r) in own {
        let iref = instance_ref(&r.token);
        seen.insert(iref.clone());
        let running = is_running(tally, r);
        let moved = sums
            .as_ref()
            .map(|s| s.instances.get(&iref).map_or(0, |f| f.net_out()));
        let live_mu = live
            .filter(|_| running)
            .and_then(|l| l.iter().find(|b| b.instance_ref == iref))
            .and_then(|b| parse_i128(&b.balance_mu));
        if running && live.is_some() && live_mu.is_none() {
            live_unknown += 1;
        }
        // The MU still in the instance is the MU moved to it last: take out at most what
        // moved in the period.
        let held = match (moved, live_mu) {
            (Some(m), Some(l)) => l.clamp(0, m.max(0)),
            _ => 0,
        };
        in_instances = in_instances.saturating_add(held);
        instances.push(InstanceSpendingView {
            moved_mu: moved.map(|m| m.to_string()).unwrap_or_default(),
            live_mu: live_mu.map(|l| l.to_string()).unwrap_or_default(),
            spent_mu: moved.map(|m| (m - held).to_string()).unwrap_or_default(),
            instance_ref: iref,
            instance_id: id.clone(),
            running,
            costs: instance_tally(d, r).map(|t| account_view(Some(t), from)),
        });
    }
    // The instances that the statement names and the app no longer has.
    if let Some(s) = &sums {
        for (iref, flow) in &s.instances {
            if seen.contains(iref) {
                continue;
            }
            instances.push(InstanceSpendingView {
                instance_ref: iref.clone(),
                instance_id: String::new(),
                running: false,
                moved_mu: flow.net_out().to_string(),
                live_mu: String::new(),
                spent_mu: flow.net_out().to_string(),
                costs: None,
            });
        }
    }
    let mut account = account_view(tally, from);
    if live.is_some() {
        if let Some(spent) = parse_i128(&account.spent_mu) {
            account.spent_mu = (spent - in_instances).to_string();
        }
    }
    NodeSpendingView {
        peer_id: peer_id.to_string(),
        address,
        account,
        statements_mu: sums
            .as_ref()
            .map(|s| s.kinds.get("statement_query").map_or(0, |f| f.out_mu).to_string())
            .unwrap_or_default(),
        starting_mu: tally
            .filter(|t| t.read_at.is_some())
            .map(|t| t.starting_mu().to_string())
            .unwrap_or_default(),
        instances,
        in_instances_mu: live.map(|_| in_instances.to_string()).unwrap_or_default(),
        live_unknown,
    }
}

/// The balance and the spending of the app on the node `peer_id` in `period`, from the
/// statements that the app read. It reads the database only, and costs nothing.
/// `utc_offset_s` is the offset of the clock of the device from UTC (for today). `live`
/// holds the balances now of the running instances
/// ([`celaut_live_instance_balances`]): their MU is not spent yet. `None` while the screen
/// has not read them: the MU in the instances counts as spent.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_node_spending(
    peer_id: String,
    period: SpendingPeriod,
    utc_offset_s: i32,
    live: Option<Vec<LiveBalanceView>>,
) -> NodeSpendingView {
    let from = from_day(period, now_seconds(), utc_offset_s);
    db().read(|d| node_view(d, &peer_id, from, live.as_deref()))
}

/// [`celaut_node_spending`] of all the movements, for each node in the node list of the
/// user, for the summary of the home screen. It reads the database only, and asks no node:
/// the MU that the running instances hold counts as spent here.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_spending_overview() -> Vec<NodeSpendingView> {
    db().read(overview_of)
}

fn overview_of(d: &CelautData) -> Vec<NodeSpendingView> {
    d.nodes
        .iter()
        .filter(|(_, n)| n.listed)
        .map(|(p, _)| node_view(d, p, None, None))
        .collect()
}

/// The balance now of each running instance of the app on the node `peer_id`
/// (`GetMetrics`, free). An instance that does not answer is left out: its MU counts as
/// spent on the screen.
#[flutter_rust_bridge::frb]
pub async fn celaut_live_instance_balances(peer_id: String) -> Vec<LiveBalanceView> {
    let running: Vec<(String, String)> = db().read(|d| {
        let tally = node_tally(d, &peer_id);
        d.instances
            .iter()
            .filter(|(_, r)| r.peer_id == peer_id && !r.token.is_empty() && is_running(tally, r))
            .map(|(id, r)| (id.clone(), r.token.clone()))
            .collect()
    });
    let mut out = Vec::new();
    for (id, token) in running {
        let Ok((session, _)) = instance(&id).await else {
            continue;
        };
        if let Ok(balance) = session.instance_balance(&token).await {
            out.push(LiveBalanceView {
                instance_ref: instance_ref(&token),
                balance_mu: balance.to_string(),
            });
        }
    }
    out
}

// ─── The quote and the read ───────────────────────────────────────────────

/// The most that the next read of a statement can cost.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SpendingQuoteView {
    /// The most MU of the read; `None` if the node does not say what a statement costs:
    /// then the app does not read.
    pub max_mu: Option<String>,
    /// The first movement that the read asks for: 1 for the first read.
    pub from_seq: u64,
}

/// One read at a time for each account: a second tap must not pay twice.
static STATEMENT_READS: Lazy<Mutex<BTreeSet<String>>> = Lazy::new(|| Mutex::new(BTreeSet::new()));

struct StatementReadGuard(String);

impl StatementReadGuard {
    fn take(key: &str) -> Result<StatementReadGuard, CelautError> {
        let mut set = STATEMENT_READS.lock().unwrap_or_else(|e| e.into_inner());
        if !set.insert(key.to_string()) {
            return Err(invalid("A read of this statement is already running."));
        }
        Ok(StatementReadGuard(key.to_string()))
    }
}

impl Drop for StatementReadGuard {
    fn drop(&mut self) {
        STATEMENT_READS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&self.0);
    }
}

fn parse_budget(text: &str) -> Result<u128, CelautError> {
    text.trim()
        .parse::<u128>()
        .map_err(|_| invalid("The budget must be a whole number of MU."))
}

fn error_of_spending(e: SpendingError) -> CelautError {
    match e {
        SpendingError::Statement(StatementError::Wire(w)) => error_of(ClientError::Wire(w)),
        SpendingError::Statement(StatementError::NoDescendants) => CelautError {
            kind: CelautErrorKind::NoDescendants,
            message: WireError::NoDescendants.to_string(),
        },
        SpendingError::Statement(StatementError::Invalid(m)) => CelautError {
            kind: CelautErrorKind::Protocol,
            message: format!("the statement is not valid: {m}"),
        },
        e @ SpendingError::OtherAccount => CelautError {
            kind: CelautErrorKind::Protocol,
            message: e.to_string(),
        },
        other => CelautError {
            kind: CelautErrorKind::InvalidInput,
            message: other.to_string(),
        },
    }
}

fn quote_view(q: Result<celaut_client::spending::AccountRead, SpendingError>) -> Result<SpendingQuoteView, CelautError> {
    match q {
        Ok(q) => Ok(SpendingQuoteView {
            max_mu: Some(q.max_mu_needed().to_string()),
            from_seq: q.from_seq(),
        }),
        Err(SpendingError::NoRates) => Ok(SpendingQuoteView {
            max_mu: None,
            from_seq: 0,
        }),
        Err(e) => Err(error_of_spending(e)),
    }
}

fn client_tally(session: &Session) -> Option<Tally> {
    let aref = account_ref(session.client_id());
    db().read(|d| d.tallies.get(&aref).cloned())
        .filter(|t| t.peer_id == session.peer_id() && t.owner == Owner::Client)
}

fn keep(tally: Tally) -> Result<(), CelautError> {
    db().update(|d| {
        d.tallies.insert(tally.account_ref.clone(), tally);
    })
    .map_err(storage_error)
}

/// The most MU that the next read of the statement of the client on `node` can cost. It
/// sends nothing and costs nothing.
#[flutter_rust_bridge::frb]
pub async fn celaut_quote_node_statement(node: NodeAddress) -> Result<SpendingQuoteView, CelautError> {
    let session = session(&node).await?;
    let tally = client_tally(&session);
    quote_view(session.quote_client_statement(tally.as_ref()))
}

/// Read the statement of the client of the app on `node`: one page of the movements after
/// the last read ([`celaut_client::spending::PAGE_ROWS`]). THIS COSTS MU: the node charges
/// the read to the client and writes it as a movement. `max_mu` is the budget that the
/// user confirmed; if the read can cost more, nothing is sent. The statement is verified
/// (the signature of the node, the hash chain, the balance and the head that the app kept)
/// before the app keeps its sums. `utc_offset_s` gives the day of each movement. Then
/// [`celaut_node_spending`] gives the new sums.
#[flutter_rust_bridge::frb]
pub async fn celaut_read_node_statement(
    node: NodeAddress,
    max_mu: String,
    utc_offset_s: i32,
) -> Result<(), CelautError> {
    let budget = parse_budget(&max_mu)?;
    let session = session(&node).await?;
    let _reading = StatementReadGuard::take(&format!("client/{}", session.peer_id()))?;
    let tally = client_tally(&session);
    let quote = session
        .quote_client_statement(tally.as_ref())
        .map_err(error_of_spending)?;
    let (tally, _) = session
        .read_account(&quote, tally.as_ref(), budget, utc_offset_s)
        .await
        .map_err(error_of_spending)?;
    keep(tally)
}

/// The record of an instance and a session on its node. A stopped instance has one too:
/// its node keeps its account for a time.
async fn instance_any(instance_id: &str) -> Result<(Session, InstanceRecord), CelautError> {
    let record = db()
        .read(|d| d.instances.get(instance_id).cloned())
        .ok_or_else(unknown_instance)?;
    if record.stopped_at.is_none() {
        return instance(instance_id).await;
    }
    let address = address_of_key(&record.address)
        .ok_or_else(|| invalid("The address of the instance is not valid."))?;
    let session = session(&address).await?;
    if session.peer_id() != record.peer_id {
        return Err(CelautError {
            kind: CelautErrorKind::IdentityMismatch,
            message: "the node at the address of the instance is now another node".into(),
        });
    }
    Ok((session, record))
}

fn tally_of_instance(record: &InstanceRecord) -> Option<Tally> {
    db().read(|d| instance_tally(d, record).cloned())
}

/// The key of the record of the held instance (depth 0) in the descendants.
fn root_key(instance_id: &str, record: &InstanceRecord) -> String {
    descendants::key(instance_id, &instance_ref(&record.token))
}

/// The cursor of the account of an instance, shared by its tally and the check of its
/// descendants (Josemi, PR #148): the last movement that both have read. A side that never
/// read is at 0. Each read is then kept in both ([`keep_instance_read`]), so that both stay
/// at the same movement and nothing is paid twice.
pub(crate) fn shared_rows_seq(d: &CelautData, instance_id: &str, record: &InstanceRecord) -> u64 {
    let tally = instance_tally(d, record).map_or(0, |t| t.rows_seq);
    let root = d
        .descendants
        .get(&root_key(instance_id, record))
        .map_or(0, |r| r.rows_seq);
    tally.min(root)
}

/// Keep a verified read of the account of the instance `instance_id` in its tally and in
/// the record of the held instance in the descendants (its head, its state, its stop and
/// its children). Movements that one side already read are not counted twice.
pub(crate) fn keep_instance_read(
    d: &mut CelautData,
    instance_id: &str,
    record: &InstanceRecord,
    statement: &VerifiedStatement,
    now: i64,
    utc_offset_s: i32,
) -> Option<descendants::ReadReport> {
    let mut tally = instance_tally(d, record)
        .cloned()
        .unwrap_or_else(|| Tally::new(Owner::Instance, &record.peer_id, &account_ref(&record.token)));
    tally.fold(statement, now, utc_offset_s);
    d.tallies.insert(tally.account_ref.clone(), tally);
    let key = descendants::ensure_root(d, instance_id)?;
    descendants::apply_read(d, &key, statement, now)
}

/// The most MU that the next read of the statement of an instance can cost. It sends
/// nothing and costs nothing.
#[flutter_rust_bridge::frb]
pub async fn celaut_quote_instance_statement(
    instance_id: String,
) -> Result<SpendingQuoteView, CelautError> {
    let (session, record) = instance_any(&instance_id).await?;
    let from = db().read(|d| shared_rows_seq(d, &instance_id, &record));
    quote_view(session.quote_instance_statement_after(&record.token, from))
}

/// Read the statement of the account of one instance, running or stopped: one page of the
/// charges of the node (build, maintenance, traffic, resources). THIS COSTS MU, charged to
/// the client. `max_mu` is the budget that the user confirmed. The statement is verified
/// before the app keeps its sums. The read goes on from the cursor that it shares with the
/// check of the descendants, and is kept in both.
#[flutter_rust_bridge::frb]
pub async fn celaut_read_instance_statement(
    instance_id: String,
    max_mu: String,
    utc_offset_s: i32,
) -> Result<(), CelautError> {
    let budget = parse_budget(&max_mu)?;
    let (session, record) = instance_any(&instance_id).await?;
    let _reading = ReadingGuard::take(&root_key(&instance_id, &record))?;
    let (from, tally) = db().read(|d| {
        (
            shared_rows_seq(d, &instance_id, &record),
            instance_tally(d, &record).cloned(),
        )
    });
    let quote = session
        .quote_instance_statement_after(&record.token, from)
        .map_err(error_of_spending)?;
    let (_, statement) = session
        .read_account(&quote, tally.as_ref(), budget, utc_offset_s)
        .await
        .map_err(error_of_spending)?;
    db().update(|d| {
        keep_instance_read(d, &instance_id, &record, &statement, now_seconds(), utc_offset_s);
    })
    .map_err(storage_error)
}

/// Forget the sums of the statements of an instance, when the user deletes it.
pub(crate) fn forget_instance_tally(d: &mut CelautData, record: &InstanceRecord) {
    if !record.token.is_empty() {
        d.tallies.remove(&account_ref(&record.token));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use celaut_client::spending::Flow;

    fn record(peer: &str, token: &str, started_at: i64, stopped: bool) -> InstanceRecord {
        InstanceRecord {
            peer_id: peer.into(),
            address: "node:1".into(),
            token: token.into(),
            started_at,
            stopped_at: stopped.then_some(started_at + 10),
            ..Default::default()
        }
    }

    #[test]
    fn an_amount_must_be_a_whole_number_above_zero() {
        assert_eq!(parse_mu(" 25 ").unwrap(), 25);
        for bad in ["", "0", "-5", "1.5", "abc", &u128::MAX.to_string()] {
            assert!(parse_mu(bad).is_err(), "{bad}");
        }
        assert_eq!(add_text(None, 5), "5");
        assert_eq!(add_text(Some("10"), 5), "15");
    }

    #[test]
    fn a_node_never_read_says_unknown_not_zero() {
        let mut d = CelautData::default();
        d.nodes.insert(
            "peer".into(),
            celaut_client::db::NodeRecord {
                client_id: "client".into(),
                ..Default::default()
            },
        );
        d.instances.insert("i1".into(), record("peer", "tok-1", 100, false));
        let v = node_view(&d, "peer", None, None);
        assert_eq!(v.account.read_at, 0);
        assert_eq!(v.account.balance_mu, "");
        assert_eq!(v.account.spent_mu, "");
        assert_eq!(v.statements_mu, "");
        assert_eq!(v.instances.len(), 1);
        assert_eq!(v.instances[0].moved_mu, "");
        assert!(v.instances[0].running);
        assert!(v.instances[0].costs.is_none());
    }

    #[test]
    fn the_view_of_a_node_joins_the_statement_and_the_instances_of_the_app() {
        let mut d = CelautData::default();
        d.nodes.insert(
            "peer".into(),
            celaut_client::db::NodeRecord {
                client_id: "client".into(),
                addresses: vec!["node:1".into()],
                ..Default::default()
            },
        );
        d.instances.insert("old".into(), record("peer", "tok-old", 100, true));
        d.instances.insert("new".into(), record("peer", "tok-new", 200, false));
        d.instances.insert("other".into(), record("other-peer", "tok-x", 300, false));
        let mut t = Tally::new(Owner::Client, "peer", &account_ref("client"));
        t.read_at = Some(1_000);
        t.balance_mu = Some(800);
        t.by_kind.insert("credit".into(), Flow { out_mu: 0, in_mu: 1_000 });
        t.by_kind.insert("child_start".into(), Flow { out_mu: 195, in_mu: 0 });
        t.by_kind.insert("refund".into(), Flow { out_mu: 0, in_mu: 50 });
        t.by_kind.insert("statement_query".into(), Flow { out_mu: 5, in_mu: 0 });
        t.instances.insert(instance_ref("tok-old"), Flow { out_mu: 150, in_mu: 50 });
        t.instances.insert(instance_ref("tok-new"), Flow { out_mu: 45, in_mu: 0 });
        t.instances.insert(instance_ref("tok-gone"), Flow { out_mu: 0, in_mu: 0 });
        d.tallies.insert(t.account_ref.clone(), t);
        let mut it = Tally::new(Owner::Instance, "peer", &account_ref("tok-new"));
        it.read_at = Some(1_100);
        it.balance_mu = Some(30);
        it.by_kind.insert("start".into(), Flow { out_mu: 0, in_mu: 45 });
        it.by_kind.insert("maintenance".into(), Flow { out_mu: 10, in_mu: 0 });
        it.by_kind.insert("tunnel".into(), Flow { out_mu: 5, in_mu: 0 });
        it.by_kind.insert("child_bound".into(), Flow::default());
        d.tallies.insert(it.account_ref.clone(), it);

        let v = node_view(&d, "peer", None, None);
        assert_eq!(v.address, "node:1");
        assert_eq!(v.account.balance_mu, "800");
        // The MU that went to the instances and did not come back, and the reads.
        assert_eq!(v.account.spent_mu, "150");
        assert_eq!(v.in_instances_mu, "");
        assert_eq!(v.statements_mu, "5");
        let ids: Vec<&str> = v.instances.iter().map(|i| i.instance_id.as_str()).collect();
        // The newest first, then what the statement names and the app does not have.
        assert_eq!(ids, ["new", "old", ""]);
        assert_eq!(v.instances[0].moved_mu, "45");
        assert!(v.instances[0].running);
        assert_eq!(v.instances[1].moved_mu, "100");
        assert!(!v.instances[1].running);
        assert_eq!(v.instances[2].instance_ref, instance_ref("tok-gone"));
        let costs = v.instances[0].costs.as_ref().unwrap();
        assert_eq!(costs.spent_mu, "15");
        assert_eq!(costs.kinds.iter().map(|k| k.kind.as_str()).collect::<Vec<_>>(), ["maintenance", "tunnel", "start"]);
        // A tally of another client of the node (an earlier one) is not shown.
        d.nodes.get_mut("peer").unwrap().client_id = "client-2".into();
        assert_eq!(node_view(&d, "peer", None, None).account.read_at, 0);
    }

    #[test]
    fn the_overview_has_the_listed_nodes_only() {
        let mut d = CelautData::default();
        for (p, listed) in [("a", true), ("b", false)] {
            d.nodes.insert(
                p.into(),
                celaut_client::db::NodeRecord {
                    client_id: format!("c-{p}"),
                    listed,
                    ..Default::default()
                },
            );
        }
        let peers: Vec<String> = overview_of(&d).into_iter().map(|v| v.peer_id).collect();
        assert_eq!(peers, ["a"]);
    }

    #[tokio::test]
    async fn a_move_refuses_a_bad_amount_and_a_stopped_instance_before_any_call() {
        for (amount, back) in [("", false), ("x", true), ("0", false), ("-5", true)] {
            let err = celaut_move_instance_mu("any".into(), amount.into(), back)
                .await
                .unwrap_err();
            assert_eq!(err.kind, CelautErrorKind::InvalidInput, "{amount}");
        }
        let id = "move-mu-stopped-instance".to_string();
        db().update(|d| {
            d.instances.insert(id.clone(), record(&"ab".repeat(32), "token-move", 1, true));
        })
        .unwrap();
        for back in [false, true] {
            let err = celaut_move_instance_mu(id.clone(), "10".into(), back)
                .await
                .unwrap_err();
            assert_eq!(err.message, "This instance was stopped.");
        }
        drop(db().update(|d| d.instances.remove(&id)));
    }

    #[tokio::test]
    async fn a_read_needs_a_budget() {
        let node = NodeAddress {
            host: "127.0.0.1".into(),
            port: 1,
        };
        let err = celaut_read_node_statement(node, "lots".into(), 0).await.unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        let err = celaut_read_instance_statement("nope".into(), "".into(), 0)
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
    }

    #[test]
    fn deleting_an_instance_forgets_its_tally() {
        let mut d = CelautData::default();
        let r = record("peer", "tok", 1, true);
        let t = Tally::new(Owner::Instance, "peer", &account_ref("tok"));
        d.tallies.insert(t.account_ref.clone(), t);
        forget_instance_tally(&mut d, &r);
        assert!(d.tallies.is_empty());
    }

    fn node_with_client(d: &mut CelautData) {
        d.nodes.insert(
            "peer".into(),
            celaut_client::db::NodeRecord {
                client_id: "client".into(),
                ..Default::default()
            },
        );
    }

    fn sums(kinds: &[(&str, i128, i128)], instances: &[(&str, i128, i128)]) -> Sums {
        let flow = |o: i128, i: i128| Flow { out_mu: o, in_mu: i };
        Sums {
            kinds: kinds.iter().map(|(k, o, i)| (k.to_string(), flow(*o, *i))).collect(),
            instances: instances
                .iter()
                .map(|(t, o, i)| (instance_ref(t), flow(*o, *i)))
                .collect(),
        }
    }

    #[test]
    fn the_period_sums_the_days_and_the_live_balances_are_not_spent() {
        let mut d = CelautData::default();
        node_with_client(&mut d);
        d.instances.insert("old".into(), record("peer", "tok-old", 100, false));
        d.instances.insert("new".into(), record("peer", "tok-new", 200, false));
        d.instances.insert("ended".into(), record("peer", "tok-ended", 50, false));
        let now = 1_700_000_000;
        let today = day_of(now, 3_600);
        let mut t = Tally::new(Owner::Client, "peer", &account_ref("client"));
        t.read_at = Some(now);
        t.balance_mu = Some(0);
        // 10 days ago: the credit, the old instance and an instance that ended.
        t.days.insert(
            today - 10,
            sums(
                &[("credit", 0, 10_000), ("child_start", 3_000, 0), ("refund", 0, 400)],
                &[("tok-old", 2_000, 0), ("tok-ended", 1_000, 400)],
            ),
        );
        // 3 days ago: 500 more to the old instance.
        t.days.insert(today - 3, sums(&[("top_up", 500, 0)], &[("tok-old", 500, 0)]));
        // Today: the new instance and a read; the operator takes back 100.
        t.days.insert(
            today,
            sums(
                &[("child_start", 700, 0), ("statement_query", 7, 0), ("debit", 100, 0)],
                &[("tok-new", 700, 0)],
            ),
        );
        let mut all = Sums::default();
        for s in t.days.values() {
            all.merge(s);
        }
        t.by_kind = all.kinds;
        t.instances = all.instances;
        t.stopped_instances.insert(instance_ref("tok-ended"));
        d.tallies.insert(t.account_ref.clone(), t);

        let live = [
            LiveBalanceView { instance_ref: instance_ref("tok-old"), balance_mu: "2200".into() },
            LiveBalanceView { instance_ref: instance_ref("tok-new"), balance_mu: "650".into() },
            // A refunded instance is not running: its balance is not used.
            LiveBalanceView { instance_ref: instance_ref("tok-ended"), balance_mu: "9".into() },
        ];
        let by_ref = |v: &NodeSpendingView, tok: &str| {
            v.instances.iter().find(|i| i.instance_ref == instance_ref(tok)).unwrap().clone()
        };

        // All: 3,000 + 500 + 700 − 400 to the instances, the read and the debit, less what
        // the old and the new instance still hold.
        let v = node_view(&d, "peer", from_day(SpendingPeriod::All, now, 3_600), Some(&live));
        assert_eq!(v.in_instances_mu, (2_200 + 650).to_string());
        assert_eq!(v.account.spent_mu, (3_800 + 7 + 100 - 2_850).to_string());
        assert_eq!(v.live_unknown, 0);
        assert!(!by_ref(&v, "tok-ended").running);
        assert_eq!(by_ref(&v, "tok-ended").live_mu, "");
        assert_eq!(by_ref(&v, "tok-old").spent_mu, "300");

        // The week: only the top-up of the old instance and today. The old instance holds
        // 2,200, but only 500 of it moved in the week.
        let v = node_view(&d, "peer", from_day(SpendingPeriod::Week, now, 3_600), Some(&live));
        assert_eq!(by_ref(&v, "tok-old").moved_mu, "500");
        assert_eq!(by_ref(&v, "tok-old").spent_mu, "0");
        assert_eq!(v.in_instances_mu, (500 + 650).to_string());
        assert_eq!(v.account.spent_mu, (500 + 700 + 7 + 100 - 1_150).to_string());

        // Today, with no balance of the new instance: its MU counts as spent.
        let v = node_view(&d, "peer", from_day(SpendingPeriod::Today, now, 3_600), Some(&live[..1]));
        assert_eq!(v.live_unknown, 1);
        assert_eq!(v.account.spent_mu, (700 + 7 + 100).to_string());
        assert_eq!(v.statements_mu, "7");
        assert_eq!(by_ref(&v, "tok-old").moved_mu, "0");

        // The home screen asks no node: the MU in the instances counts as spent.
        let v = node_view(&d, "peer", None, None);
        assert_eq!(v.account.spent_mu, (3_800 + 7 + 100).to_string());
        assert_eq!(v.in_instances_mu, "");
    }

    fn movement(seq: u64, kind: celaut_wire::statement::Kind, amount: i128, balance: i128) -> celaut_wire::statement::Movement {
        celaut_wire::statement::Movement {
            seq,
            ts: 1_700_000_000,
            amount,
            balance_after: balance,
            kind,
            instance_ref: String::new(),
            detail: String::new(),
            prev_hash: String::new(),
            hash: format!("{seq:064x}"),
        }
    }

    fn verified(movements: Vec<celaut_wire::statement::Movement>, head: u64) -> VerifiedStatement {
        VerifiedStatement {
            statement: Default::default(),
            peer_id: "peer".into(),
            balance: movements.last().map_or(0, |m| m.balance_after),
            relayed: false,
            service_id: String::new(),
            head: celaut_wire::statement::KeptHead { seq: head, hash: format!("{head:064x}") },
            next_from_seq: None,
            gap: false,
            movements,
        }
    }

    #[test]
    fn the_tally_and_the_check_of_the_descendants_share_one_cursor() {
        use celaut_wire::statement::Kind;
        let mut d = CelautData::default();
        node_with_client(&mut d);
        let r = record("peer", "tok-held", 1, false);
        d.instances.insert("held".into(), r.clone());
        assert_eq!(shared_rows_seq(&d, "held", &r), 0);

        // A read of the costs (a page of 2 of 3 movements) is kept in both.
        let page = verified(
            vec![
                movement(1, Kind::Start, 1_000, 1_000),
                movement(2, Kind::Maintenance, -10, 990),
            ],
            3,
        );
        let report = keep_instance_read(&mut d, "held", &r, &page, 1_700_000_100, 0).unwrap();
        assert!(report.incomplete);
        assert_eq!(shared_rows_seq(&d, "held", &r), 2);
        let root = &d.descendants[&root_key("held", &r)];
        assert_eq!((root.rows_seq, root.head_seq, root.incomplete), (2, 3, true));
        assert_eq!(instance_tally(&d, &r).unwrap().spent_mu(), Some(10));

        // A check of the descendants that reads again from 1 (an older cursor) counts
        // nothing twice.
        let check = verified(
            vec![
                movement(1, Kind::Start, 1_000, 1_000),
                movement(2, Kind::Maintenance, -10, 990),
                movement(3, Kind::Maintenance, -10, 980),
            ],
            3,
        );
        keep_instance_read(&mut d, "held", &r, &check, 1_700_000_200, 0).unwrap();
        assert_eq!(shared_rows_seq(&d, "held", &r), 3);
        let t = instance_tally(&d, &r).unwrap();
        assert_eq!(t.spent_mu(), Some(20));
        assert!(!t.incomplete);
        assert!(!d.descendants[&root_key("held", &r)].incomplete);

        // A side that is behind (an earlier version read only the descendants) pulls the
        // cursor back, so that the tally sees every movement once.
        d.tallies.clear();
        assert_eq!(shared_rows_seq(&d, "held", &r), 0);
    }
}
