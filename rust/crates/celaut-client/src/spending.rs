//! The balance and the spending of the app on a node (issue #136,
//! `docs/celaut/spending.md`).
//!
//! The app reads the signed balance statements of the node (`GetBalanceStatement`) and
//! keeps a running tally of each account that it read: the account of its client on the
//! node, and the account of each of its instances. A tally holds sums only, never the
//! movements, and the head of the chain that the node signed, so that the next read starts
//! after it and must agree with it ([`celaut_wire::statement::KeptHead`]).
//!
//! # No automatic read
//!
//! A read costs MU and writes a `statement_query` movement on the node. Nothing in this
//! module reads by itself: [`quote_client_read`] and [`quote_instance_read`] give the most
//! MU of one read, the caller shows it to the user, and [`read`] sends one request only
//! with the budget that the user confirmed. One call is one read.
//!
//! # What a tally can say
//!
//! - The balance at the head, signed by the node.
//! - What went in (`deposit`, `credit`) and what the operator took (`debit`).
//! - What the account spent: what came in, less what is left. When the node no longer
//!   holds the first movements (its retention), the sums start at the first movement that
//!   it gave, and the tally is `partial`.
//! - For the client: the MU that went to each instance (`child_start` with its
//!   `child_bound`, `top_up`) and the MU that came back (`withdrawal`, `refund`), by the
//!   `instance_ref` of the instance.
//! - For an instance: the part of each kind of charge (`build`, `maintenance`, `tunnel`,
//!   `resource_change`, ...).
//!
//! A value that the app did not read is `None`: the screens show "unknown", not 0.

use std::collections::BTreeMap;

use celaut_proto::celaut::Peer;
use celaut_wire::gateway::get_balance_statement;
use celaut_wire::statement::{
    account_ref, instance_ref as ref_of_token, KeptHead, Kind, Movement, Rates,
    StatementError, StatementRequest, VerifiedStatement,
};
use celaut_wire::Transport;
use serde::{Deserialize, Serialize};

/// The `remaining_hops` of a read of the app's own accounts. The node answers from its own
/// chains and asks no peer, so a read is one read of cost.
pub const OWN_READ_HOPS: u32 = 1;

/// Serde of an `i128` amount as decimal text: JSON numbers lose precision above 2^53.
mod mu_text {
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(v: &i128, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&v.to_string())
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<i128, D::Error> {
        let text = String::deserialize(d)?;
        text.parse().map_err(serde::de::Error::custom)
    }
}

/// Serde of an optional `i128` amount as decimal text.
mod opt_mu_text {
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(v: &Option<i128>, s: S) -> Result<S::Ok, S::Error> {
        match v {
            Some(v) => s.serialize_some(&v.to_string()),
            None => s.serialize_none(),
        }
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Option<i128>, D::Error> {
        match Option::<String>::deserialize(d)? {
            None => Ok(None),
            Some(text) => text.parse().map(Some).map_err(serde::de::Error::custom),
        }
    }
}

/// The MU that moved in each direction: `out_mu` left the account, `in_mu` came in.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Flow {
    #[serde(with = "mu_text", default)]
    pub out_mu: i128,
    #[serde(with = "mu_text", default)]
    pub in_mu: i128,
}

impl Flow {
    fn add(&mut self, amount: i128) {
        if amount < 0 {
            self.out_mu = self.out_mu.saturating_add(amount.saturating_neg());
        } else {
            self.in_mu = self.in_mu.saturating_add(amount);
        }
    }

    /// What left and did not come back. Below 0 when more came back than left.
    pub fn net_out(&self) -> i128 {
        self.out_mu.saturating_sub(self.in_mu)
    }
}

/// Whose account a tally is.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Owner {
    /// The client of the app on the node.
    Client,
    /// An instance of the app.
    Instance,
}

/// The running sums of one account, from the statements that the app read.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Tally {
    pub owner: Owner,
    /// The node that signed the statements.
    pub peer_id: String,
    /// The `account_ref` of the account: a hash, never the credential.
    pub account_ref: String,
    /// The `seq` of the last movement that the app read. The next read starts after it.
    #[serde(default)]
    pub rows_seq: u64,
    /// The head that the node signed in the last read.
    #[serde(default)]
    pub head_seq: u64,
    #[serde(default)]
    pub head_hash: String,
    /// The time of the last read, in Unix seconds.
    #[serde(default)]
    pub read_at: Option<i64>,
    /// The balance at the head of the last read, in MU. `None` before a read.
    #[serde(with = "opt_mu_text", default)]
    pub balance_mu: Option<i128>,
    /// The balance before the first movement that the app read: 0 when the app read from
    /// the first movement of the account, more when the node no longer held the first ones.
    #[serde(with = "mu_text", default)]
    pub opening_mu: i128,
    /// The time of the first movement that the app read, in Unix seconds.
    #[serde(default)]
    pub first_ts: Option<i64>,
    /// True if the node no longer held the first movements of the account: the sums start
    /// at the first movement that it gave.
    #[serde(default)]
    pub partial: bool,
    /// True if the last read did not reach the head: the node gave fewer movements than
    /// the range. The next read goes on after `rows_seq`.
    #[serde(default)]
    pub incomplete: bool,
    /// True if a `stop` movement ended the account.
    #[serde(default)]
    pub stopped: bool,
    /// The MU of each kind of movement, by the kind as the node wrote it.
    #[serde(default)]
    pub by_kind: BTreeMap<String, Flow>,
    /// The MU that the account moved to each instance (out) and that came back (in), by
    /// the `instance_ref` of the instance. Only for [`Owner::Client`].
    #[serde(default)]
    pub instances: BTreeMap<String, Flow>,
    /// The `child_start` movements whose child the app did not see yet, by `seq`, with
    /// the MU that each one took. A `child_bound` or a `refund` of it ends it.
    #[serde(default)]
    pub open_starts: BTreeMap<u64, String>,
}

impl Tally {
    /// An empty tally, before any read.
    pub fn new(owner: Owner, peer_id: &str, account_ref: &str) -> Tally {
        Tally {
            owner,
            peer_id: peer_id.to_string(),
            account_ref: account_ref.to_string(),
            rows_seq: 0,
            head_seq: 0,
            head_hash: String::new(),
            read_at: None,
            balance_mu: None,
            opening_mu: 0,
            first_ts: None,
            partial: false,
            incomplete: false,
            stopped: false,
            by_kind: BTreeMap::new(),
            instances: BTreeMap::new(),
            open_starts: BTreeMap::new(),
        }
    }

    /// The head to give the next read, if the app has read one.
    pub fn kept_head(&self) -> Option<KeptHead> {
        (!self.head_hash.is_empty()).then(|| KeptHead {
            seq: self.head_seq,
            hash: self.head_hash.clone(),
        })
    }

    /// The flow of one kind of movement (zero if none).
    pub fn kind(&self, kind: &str) -> Flow {
        self.by_kind.get(kind).copied().unwrap_or_default()
    }

    /// The MU that came into the account from outside the node's instances: payments
    /// (`deposit`) and credit that nobody paid in (`credit`), less what the operator took
    /// back (`debit`): an operator that takes back credit is not a spending of the user.
    /// For an instance, also what its father gave it (`start`, `top_up`).
    pub fn received_mu(&self) -> i128 {
        let mut total = self.kind("deposit").in_mu + self.kind("credit").in_mu
            - self.kind("debit").out_mu;
        if self.owner == Owner::Instance {
            total += self.kind("start").in_mu + self.kind("top_up").in_mu;
        }
        total
    }

    /// What the account gave back to its father: only for an instance (`withdrawal`, and
    /// the `refund` of what it did not use).
    pub fn returned_mu(&self) -> i128 {
        if self.owner == Owner::Instance {
            self.kind("withdrawal").out_mu + self.kind("refund").out_mu
        } else {
            0
        }
    }

    /// What the account spent since the first movement that the app read: what it had and
    /// what came in, less what went back to its father and less what is left. `None`
    /// before a read. For the client, the MU that its instances still hold counts as spent
    /// (it comes back as a `refund` when they stop).
    pub fn spent_mu(&self) -> Option<i128> {
        let balance = self.balance_mu?;
        Some(
            self.opening_mu
                .saturating_add(self.received_mu())
                .saturating_sub(self.returned_mu())
                .saturating_sub(balance),
        )
    }

    /// The MU that is moving into an instance that does not exist yet: `child_start`
    /// movements with no `child_bound` and no `refund` yet.
    pub fn starting_mu(&self) -> i128 {
        self.open_starts
            .values()
            .filter_map(|v| v.parse::<i128>().ok())
            .sum()
    }

    /// Add what a verified statement of this account says. It keeps the sums of the
    /// movements after `rows_seq`, the head and the balance. Movements that the app read
    /// before are not counted twice.
    pub fn fold(&mut self, statement: &VerifiedStatement, now: i64) {
        let new: Vec<&Movement> = statement
            .movements
            .iter()
            .filter(|m| m.seq > self.rows_seq)
            .collect();
        if let Some(first) = new.first() {
            if self.rows_seq == 0 {
                // The first read: the balance before the first movement given. A node that
                // no longer holds the first movements starts later than seq 1.
                self.opening_mu = first.balance_after.saturating_sub(first.amount);
                self.first_ts = Some(first.ts);
                self.partial = first.seq > 1;
            } else if first.seq > self.rows_seq + 1 {
                // The node deleted movements that the app did not read yet.
                self.partial = true;
            }
        }
        for m in &new {
            self.add(m);
        }
        if let Some(last) = new.last() {
            self.rows_seq = last.seq;
        }
        self.head_seq = statement.head.seq;
        self.head_hash = statement.head.hash.clone();
        self.balance_mu = Some(statement.balance);
        self.read_at = Some(now);
        self.incomplete = statement.next_from_seq.is_some();
    }

    fn add(&mut self, m: &Movement) {
        let name = kind_name(&m.kind);
        self.by_kind.entry(name.to_string()).or_default().add(m.amount);
        if matches!(m.kind, Kind::Stop(_)) {
            self.stopped = true;
        }
        if self.owner != Owner::Client {
            return;
        }
        match &m.kind {
            Kind::ChildStart => {
                self.open_starts
                    .insert(m.seq, m.amount.saturating_neg().to_string());
            }
            Kind::ChildBound(bound) => {
                let start = bound
                    .starts_seq
                    .and_then(|seq| self.open_starts.remove(&seq))
                    .and_then(|v| v.parse::<i128>().ok())
                    .unwrap_or(0);
                let flow = self.instances.entry(m.instance_ref.clone()).or_default();
                flow.out_mu = flow.out_mu.saturating_add(start);
            }
            Kind::TopUp | Kind::Withdrawal | Kind::Refund if !m.instance_ref.is_empty() => {
                self.instances
                    .entry(m.instance_ref.clone())
                    .or_default()
                    .add(m.amount);
            }
            Kind::Refund => {
                // The refund of a start that failed names the charge that it gives back.
                if let Some(seq) = refunds_seq(&m.detail) {
                    self.open_starts.remove(&seq);
                }
            }
            _ => {}
        }
    }
}

/// The name of a kind, as the node writes it.
fn kind_name(kind: &Kind) -> &str {
    match kind {
        Kind::Deposit => "deposit",
        Kind::Credit => "credit",
        Kind::Debit => "debit",
        Kind::Start => "start",
        Kind::Build => "build",
        Kind::Maintenance => "maintenance",
        Kind::ChildStart => "child_start",
        Kind::ChildBound(_) => "child_bound",
        Kind::TopUp => "top_up",
        Kind::Withdrawal => "withdrawal",
        Kind::Refund => "refund",
        Kind::Tunnel => "tunnel",
        Kind::ResourceChange => "resource_change",
        Kind::Stop(_) => "stop",
        Kind::StatementQuery => "statement_query",
        Kind::Unknown(name) => name,
    }
}

/// The `refunds_seq` of the detail of a `refund`, if it has one.
fn refunds_seq(detail: &str) -> Option<u64> {
    let value: serde_json::Value = serde_json::from_str(detail).ok()?;
    match value.get("refunds_seq")? {
        serde_json::Value::String(text) => text.parse().ok(),
        serde_json::Value::Number(n) => n.as_u64(),
        _ => None,
    }
}

// ─── The quote and the read ───────────────────────────────────────────────

/// One read of an account: the request and the most MU that it can cost. Only
/// [`quote_client_read`] and [`quote_instance_read`] make one. Show
/// [`AccountRead::max_mu_needed`] to the user, and read only after a yes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AccountRead {
    owner: Owner,
    account_ref: String,
    request: StatementRequest,
    rates: Rates,
}

impl AccountRead {
    /// The most MU that the read can cost: the fixed price and the price of the most rows
    /// that one answer can hold.
    pub fn max_mu_needed(&self) -> u128 {
        self.request.max_mu_needed(&self.rates)
    }

    /// The first movement that the read asks for.
    pub fn from_seq(&self) -> u64 {
        self.request.from_seq
    }

    /// The `account_ref` that the answer must have.
    pub fn account_ref(&self) -> &str {
        &self.account_ref
    }
}

/// Why a read could not be made or was refused.
#[derive(Debug, thiserror::Error)]
pub enum SpendingError {
    /// The node does not say what a statement costs: the app does not read.
    #[error("the node does not advertise the price of a statement")]
    NoRates,
    /// The tally is of another account or node than the read.
    #[error("the tally is not the account of this read")]
    WrongTally,
    /// The answer is of another account.
    #[error("the statement is of another account")]
    OtherAccount,
    #[error(transparent)]
    Statement(#[from] StatementError),
}

impl SpendingError {
    /// True if the request went out and the answer was refused, so the node may have
    /// charged the read.
    pub fn may_have_charged(&self) -> bool {
        match self {
            SpendingError::OtherAccount => true,
            SpendingError::Statement(e) => e.may_have_charged(),
            _ => false,
        }
    }
}

fn rates(peer: &Peer) -> Result<Rates, SpendingError> {
    Rates::from_peer(peer).ok_or(SpendingError::NoRates)
}

/// The next read of the account of the client: the movements after the ones in `tally`
/// (from the first one if `None`), up to the head. It sends nothing and costs nothing.
pub fn quote_client_read(
    peer: &Peer,
    client_id: &str,
    tally: Option<&Tally>,
) -> Result<AccountRead, SpendingError> {
    let request = StatementRequest {
        token: String::new(),
        instance_ref: String::new(),
        from_seq: tally.map_or(0, |t| t.rows_seq).saturating_add(1),
        to_seq: 0,
        remaining_hops: OWN_READ_HOPS,
    };
    request.check()?;
    Ok(AccountRead {
        owner: Owner::Client,
        account_ref: account_ref(client_id),
        request,
        rates: rates(peer)?,
    })
}

/// The next read of the account of the instance of `token`. It names the instance by its
/// own `instance_ref`, so that the node also reads the account of an instance that
/// stopped, while it keeps its row. It sends nothing and costs nothing.
pub fn quote_instance_read(
    peer: &Peer,
    token: &str,
    tally: Option<&Tally>,
) -> Result<AccountRead, SpendingError> {
    let request = StatementRequest {
        token: token.to_string(),
        instance_ref: ref_of_token(token),
        from_seq: tally.map_or(0, |t| t.rows_seq).saturating_add(1),
        to_seq: 0,
        remaining_hops: OWN_READ_HOPS,
    };
    request.check()?;
    Ok(AccountRead {
        owner: Owner::Instance,
        account_ref: account_ref(token),
        request,
        rates: rates(peer)?,
    })
}

/// Read one statement and add it to `tally` (a new one if `None`). This is one paid call.
///
/// `max_mu` is the budget that the user confirmed: if the read can cost more, nothing is
/// sent. The answer is checked against the node of the connection (`peer_id`): the
/// signature, the date against `now`, the chain, the head that the tally kept, and the
/// account. Gives the tally after the read; the caller keeps it.
#[allow(clippy::too_many_arguments)]
pub async fn read<T: Transport>(
    transport: &T,
    peer_id: &str,
    client_id: &str,
    quote: &AccountRead,
    tally: Option<&Tally>,
    max_mu: u128,
    now: i64,
) -> Result<(Tally, VerifiedStatement), SpendingError> {
    let mut tally = match tally {
        Some(t) => {
            if t.peer_id != peer_id || t.account_ref != quote.account_ref || t.owner != quote.owner
            {
                return Err(SpendingError::WrongTally);
            }
            t.clone()
        }
        None => Tally::new(quote.owner, peer_id, &quote.account_ref),
    };
    let kept = tally.kept_head();
    let statement = get_balance_statement(
        transport,
        peer_id,
        client_id,
        &quote.request,
        &quote.rates,
        max_mu,
        kept.as_ref(),
        now,
    )
    .await?;
    if statement.statement.account_ref != quote.account_ref {
        return Err(SpendingError::OtherAccount);
    }
    tally.fold(&statement, now);
    Ok((tally, statement))
}
