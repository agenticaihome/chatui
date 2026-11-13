//! The balance and the spending of the app on a node (issue #136): the tallies of the
//! signed statements of the account of the client and of an instance.
//!
//! The statements are made and signed with the statement code of `celaut-wire`, as a node
//! does (`nodo:src/manager/balance_statement.py`); no real node answered these tests.

use std::sync::Mutex;

use bee_rpc::frame::Part;
use celaut_client::spending::{
    quote_client_read, quote_instance_read, read, Owner, SpendingError, Tally,
};
use celaut_proto::celaut::{
    Amount, AmountKeyValue, BalanceMovement, BalanceStatement, BalanceStatementRequest, Peer,
};
use celaut_wire::statement::{
    self, account_ref, genesis_hash, instance_ref, movement_hash, StatementError,
};
use celaut_wire::{Transport, WireError};
use prost::Message;
use ring::signature::{Ed25519KeyPair, KeyPair};

const SEED: [u8; 32] = [9u8; 32];
const CLIENT: &str = "c11e47000000400080000000000000bb";
const TOKEN: &str = "instance-token-1";

fn peer_id() -> String {
    let pair = Ed25519KeyPair::from_seed_unchecked(&SEED).unwrap();
    hex::encode(pair.public_key().as_ref())
}

fn amount(n: i128) -> Option<Amount> {
    Some(Amount { n: n.to_string() })
}

/// A `Peer` that advertises the price of a statement.
fn peer(query: Option<&str>, row: Option<&str>) -> Peer {
    let mut p = Peer::default();
    for (key, value) in [("statement_query_mu", query), ("statement_row_mu", row)] {
        if let Some(v) = value {
            p.mu_per_call.push(AmountKeyValue {
                key: key.into(),
                value: Some(Amount { n: v.into() }),
            });
        }
    }
    p
}

fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64
}

/// One movement: kind, amount, instance_ref, detail.
type Row = (&'static str, i128, String, String);

fn row(kind: &'static str, amount: i128) -> Row {
    (kind, amount, String::new(), String::new())
}

fn row_of(kind: &'static str, amount: i128, iref: &str) -> Row {
    (kind, amount, iref.to_string(), String::new())
}

/// The chain state after the movements made so far: seq, hash and balance of the head.
#[derive(Clone)]
struct Head {
    seq: u64,
    hash: String,
    balance: i128,
}

/// A signed statement of `account` (a client id or a token) with `rows` after `head`
/// (`None`: from the first movement of the account). Gives the statement and the new head.
fn statement(account: &str, head: Option<&Head>, rows: &[Row], oldest: u64) -> (BalanceStatement, Head) {
    let aref = account_ref(account);
    let mut h = head.cloned().unwrap_or(Head {
        seq: 0,
        hash: genesis_hash(&aref),
        balance: 0,
    });
    let from = h.seq + 1;
    let mut movements = Vec::new();
    for (kind, amt, iref, detail) in rows {
        h.seq += 1;
        h.balance += amt;
        let m = BalanceMovement {
            seq: h.seq,
            ts: now() - 100,
            amount: amount(*amt),
            balance_after: amount(h.balance),
            kind: (*kind).into(),
            instance_ref: iref.clone(),
            detail: detail.clone(),
            prev_hash: h.hash.clone(),
        };
        h.hash = movement_hash(&m);
        movements.push(m);
    }
    let mut s = BalanceStatement {
        account_ref: aref,
        from_seq: from,
        to_seq: 0,
        movements,
        balance: amount(h.balance),
        head_seq: h.seq,
        head_hash: h.hash.clone(),
        oldest_seq: oldest,
        retention_days: 0,
        ts: now(),
        signature: String::new(),
        relayed: false,
        service_id: String::new(),
        instance_ref: String::new(),
    };
    statement::sign_with_seed(&mut s, &SEED).unwrap();
    (s, h)
}

/// A transport with fixed answers that keeps the requests.
struct Fixed {
    answers: Mutex<Vec<BalanceStatement>>,
    sent: Mutex<Vec<BalanceStatementRequest>>,
}

impl Fixed {
    fn new(list: Vec<BalanceStatement>) -> Self {
        Fixed {
            answers: Mutex::new(list),
            sent: Mutex::new(Vec::new()),
        }
    }
    fn calls(&self) -> usize {
        self.sent.lock().unwrap().len()
    }
}

impl Transport for Fixed {
    async fn call(
        &self,
        method: &str,
        parts: Vec<Part>,
        _accepted: &[i32],
    ) -> Result<Vec<Part>, WireError> {
        assert_eq!(method, "GetBalanceStatement");
        self.sent
            .lock()
            .unwrap()
            .push(BalanceStatementRequest::decode(parts[0].data.as_slice()).unwrap());
        let mut answers = self.answers.lock().unwrap();
        if answers.is_empty() {
            return Err(WireError::Call("no more answers".into()));
        }
        Ok(vec![Part::new(1, answers.remove(0).encode_to_vec())])
    }
}

fn starts_seq(seq: u64) -> String {
    format!(r#"{{"starts_seq":"{seq}"}}"#)
}

#[test]
fn a_quote_needs_the_rates_of_the_node_and_reads_from_the_first_movement() {
    let none = quote_client_read(&peer(Some("100"), None), CLIENT, None).unwrap_err();
    assert!(matches!(none, SpendingError::NoRates));
    let q = quote_client_read(&peer(Some("100"), Some("2")), CLIENT, None).unwrap();
    assert_eq!(q.from_seq(), 1);
    // One read: the fixed part and the most rows of one answer.
    assert_eq!(q.max_mu_needed(), 100 + 2 * 1000);
    assert_eq!(q.account_ref(), account_ref(CLIENT));
    let mut t = Tally::new(Owner::Client, &peer_id(), &account_ref(CLIENT));
    t.rows_seq = 41;
    let q = quote_client_read(&peer(Some("100"), Some("2")), CLIENT, Some(&t)).unwrap();
    assert_eq!(q.from_seq(), 42);
}

#[tokio::test]
async fn the_client_tally_splits_the_spending_by_instance_and_reads_only_new_movements() {
    let a = instance_ref("token-a");
    let b = instance_ref("token-b");
    let rows = vec![
        row("credit", 9_000_000),
        row("child_start", -1_000_000),
        (
            "child_bound",
            0,
            a.clone(),
            format!(r#"{{"service_id":"ab","starts_seq":"2"}}"#),
        ),
        row_of("top_up", -200_000, &a),
        row_of("withdrawal", 50_000, &a),
        row("child_start", -700_000),
        row("statement_query", -1_100),
    ];
    let (first, head) = statement(CLIENT, None, &rows, 1);
    let p = peer(Some("1000"), Some("1"));
    let t = Fixed::new(vec![first]);
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, None, u128::MAX, now()).await.unwrap();
    assert_eq!(tally.balance_mu, Some(7_148_900));
    assert_eq!(tally.received_mu(), 9_000_000);
    assert_eq!(tally.spent_mu(), Some(1_851_100));
    assert!(!tally.partial && !tally.incomplete);
    assert_eq!(tally.instances[&a].out_mu, 1_200_000);
    assert_eq!(tally.instances[&a].in_mu, 50_000);
    assert_eq!(tally.instances[&a].net_out(), 1_150_000);
    // The second start has no child yet.
    assert_eq!(tally.starting_mu(), 700_000);
    assert_eq!(tally.kind("statement_query").out_mu, 1_100);
    assert_eq!(tally.rows_seq, 7);

    // The next read starts after the head, and the child of the second start shows.
    let more = vec![
        ("child_bound", 0, b.clone(), starts_seq(6)),
        row_of("refund", 300_000, &a),
        row("statement_query", -1_005),
    ];
    let (second, _) = statement(CLIENT, Some(&head), &more, 1);
    let t = Fixed::new(vec![second]);
    let q = quote_client_read(&p, CLIENT, Some(&tally)).unwrap();
    assert_eq!(q.from_seq(), 8);
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, Some(&tally), u128::MAX, now())
        .await
        .unwrap();
    assert_eq!(t.sent.lock().unwrap()[0].from_seq, 8);
    assert_eq!(tally.instances[&a].net_out(), 850_000);
    assert_eq!(tally.instances[&b].net_out(), 700_000);
    assert_eq!(tally.starting_mu(), 0);
    assert_eq!(tally.balance_mu, Some(7_447_895));
    assert_eq!(tally.spent_mu(), Some(1_552_105));
    // The spending is what went to the instances plus the reads of statements.
    assert_eq!(
        tally.spent_mu().unwrap(),
        tally.instances.values().map(|f| f.net_out()).sum::<i128>()
            + tally.kind("statement_query").out_mu
    );
}

#[tokio::test]
async fn a_failed_start_given_back_is_not_spending() {
    let rows = vec![
        row("credit", 1_000),
        row("child_start", -400),
        ("refund", 400, String::new(), r#"{"refunds_seq":"2"}"#.to_string()),
    ];
    let (s, _) = statement(CLIENT, None, &rows, 1);
    let p = peer(Some("1"), Some("0"));
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let (tally, _) = read(&Fixed::new(vec![s]), &peer_id(), CLIENT, &q, None, u128::MAX, now())
        .await
        .unwrap();
    assert_eq!(tally.starting_mu(), 0);
    assert_eq!(tally.spent_mu(), Some(0));
    assert!(tally.instances.is_empty());
}

#[tokio::test]
async fn a_node_that_deleted_the_first_movements_gives_a_partial_tally() {
    // The node holds movements from seq 3 on: the first two are gone.
    let (full, _) = statement(
        CLIENT,
        None,
        &[row("credit", 5_000), row("child_start", -1_000), row("statement_query", -10)],
        1,
    );
    let mut cut = full.clone();
    cut.movements.drain(..2);
    cut.oldest_seq = 3;
    statement::sign_with_seed(&mut cut, &SEED).unwrap();
    let p = peer(Some("1"), Some("0"));
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let (tally, _) = read(&Fixed::new(vec![cut]), &peer_id(), CLIENT, &q, None, u128::MAX, now())
        .await
        .unwrap();
    assert!(tally.partial);
    // The balance before the first movement given: 4,000.
    assert_eq!(tally.opening_mu, 4_000);
    assert_eq!(tally.balance_mu, Some(3_990));
    assert_eq!(tally.spent_mu(), Some(10));
}

#[tokio::test]
async fn the_instance_tally_gives_each_kind_of_charge() {
    let rows = vec![
        row("start", 1_000_000),
        row("build", -100_000),
        row("maintenance", -50_000),
        row("tunnel", -10_000),
        row("resource_change", -2_000),
        row("top_up", 200_000),
        row("withdrawal", -50_000),
        row("maintenance", -50_000),
    ];
    let (mut s, _) = statement(TOKEN, None, &rows, 1);
    // A read by instance_ref: the node signs the instance_ref of the request.
    s.instance_ref = instance_ref(TOKEN);
    statement::sign_with_seed(&mut s, &SEED).unwrap();
    let p = peer(Some("10"), Some("1"));
    let q = quote_instance_read(&p, TOKEN, None).unwrap();
    let t = Fixed::new(vec![s]);
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, None, u128::MAX, now()).await.unwrap();
    let sent = &t.sent.lock().unwrap()[0];
    assert_eq!(sent.token, TOKEN);
    assert_eq!(sent.instance_ref, instance_ref(TOKEN));
    assert_eq!(sent.remaining_hops, Some(1));
    assert_eq!(tally.owner, Owner::Instance);
    assert_eq!(tally.received_mu(), 1_200_000);
    assert_eq!(tally.returned_mu(), 50_000);
    assert_eq!(tally.balance_mu, Some(938_000));
    assert_eq!(tally.kind("maintenance").out_mu, 100_000);
    assert_eq!(tally.kind("tunnel").out_mu, 10_000);
    assert_eq!(tally.kind("build").out_mu, 100_000);
    // Spent = the charges: build, maintenance, tunnel and resources.
    assert_eq!(tally.spent_mu(), Some(212_000));
    assert!(!tally.stopped);
}

#[tokio::test]
async fn a_read_over_the_budget_sends_nothing() {
    let p = peer(Some("1000"), Some("1"));
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let t = Fixed::new(vec![]);
    let e = read(&t, &peer_id(), CLIENT, &q, None, 1_999, now())
        .await
        .unwrap_err();
    assert!(matches!(
        e,
        SpendingError::Statement(StatementError::OverBudget { needed: 2_000, max: 1_999 })
    ));
    assert!(!e.may_have_charged());
    assert_eq!(t.calls(), 0);
}

#[tokio::test]
async fn a_statement_of_another_account_or_with_a_broken_signature_is_refused() {
    let p = peer(Some("1"), Some("0"));
    let (other, _) = statement("someone-else", None, &[row("credit", 5)], 1);
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let e = read(&Fixed::new(vec![other]), &peer_id(), CLIENT, &q, None, u128::MAX, now())
        .await
        .unwrap_err();
    assert!(e.may_have_charged(), "{e:?}");

    let (mut forged, _) = statement(CLIENT, None, &[row("credit", 5)], 1);
    forged.balance = amount(6);
    let e = read(&Fixed::new(vec![forged]), &peer_id(), CLIENT, &q, None, u128::MAX, now())
        .await
        .unwrap_err();
    assert!(
        matches!(e, SpendingError::Statement(StatementError::Invalid(_))),
        "{e:?}"
    );
}

#[tokio::test]
async fn a_head_that_changed_since_the_last_read_is_refused() {
    let p = peer(Some("1"), Some("0"));
    let (first, head) = statement(CLIENT, None, &[row("credit", 5), row("statement_query", -1)], 1);
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let (tally, _) = read(&Fixed::new(vec![first]), &peer_id(), CLIENT, &q, None, u128::MAX, now())
        .await
        .unwrap();
    // A node that rewrote the head: the next movement hangs from another hash.
    let other = Head {
        hash: "22".repeat(32),
        ..head
    };
    let (rewritten, _) = statement(CLIENT, Some(&other), &[row("statement_query", -1)], 1);
    let q = quote_client_read(&p, CLIENT, Some(&tally)).unwrap();
    let e = read(
        &Fixed::new(vec![rewritten]),
        &peer_id(),
        CLIENT,
        &q,
        Some(&tally),
        u128::MAX,
        now(),
    )
    .await
    .unwrap_err();
    assert!(
        matches!(e, SpendingError::Statement(StatementError::Invalid(_))),
        "{e:?}"
    );
    // A tally of another account is not used.
    let q = quote_client_read(&p, "other-client", None).unwrap();
    let e = read(&Fixed::new(vec![]), &peer_id(), "other-client", &q, Some(&tally), u128::MAX, now())
        .await
        .unwrap_err();
    assert!(matches!(e, SpendingError::WrongTally));
}

#[test]
fn a_tally_keeps_its_amounts_as_text_in_the_database() {
    let mut t = Tally::new(Owner::Client, &peer_id(), &account_ref(CLIENT));
    t.balance_mu = Some(i128::MAX);
    t.by_kind.insert(
        "deposit".into(),
        celaut_client::spending::Flow {
            out_mu: 0,
            in_mu: 123_456_789_012_345_678_901,
        },
    );
    let json = serde_json::to_string(&t).unwrap();
    assert!(json.contains("\"123456789012345678901\""), "{json}");
    let back: Tally = serde_json::from_str(&json).unwrap();
    assert_eq!(back, t);
    // A tally of an earlier version, with fewer fields, reads as before a read.
    let old: Tally = serde_json::from_str(&format!(
        r#"{{"owner":"client","peer_id":"p","account_ref":"{}"}}"#,
        account_ref(CLIENT)
    ))
    .unwrap();
    assert_eq!(old.balance_mu, None);
    assert_eq!(old.spent_mu(), None);
}
