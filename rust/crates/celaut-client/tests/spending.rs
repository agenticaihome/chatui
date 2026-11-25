//! The balance and the spending of the app on a node (issue #136): the tallies of the
//! signed statements of the account of the client and of an instance.
//!
//! The statements are made and signed with the statement code of `celaut-wire`, as a node
//! does (`nodo:src/manager/balance_statement.py`); no real node answered these tests.

use std::sync::Mutex;

use bee_rpc::frame::Part;
use celaut_client::spending::{
    day_of, quote_client_read, quote_instance_read, read, Owner, SpendingError, Tally,
    PAGE_ROWS,
};
use celaut_proto::celaut::{
    Amount, AmountKeyValue, BalanceMovement, BalanceStatement, BalanceStatementRequest, Peer,
};
use celaut_wire::statement::{
    self, account_ref, genesis_hash, instance_ref, movement_hash, KeptHead, Kind, Movement,
    StatementError, VerifiedStatement,
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
            p.rates.push(AmountKeyValue {
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
        let request = BalanceStatementRequest::decode(parts[0].data.as_slice()).unwrap();
        let (from_seq, to_seq) = (request.from_seq, request.to_seq);
        self.sent.lock().unwrap().push(request);
        let mut answers = self.answers.lock().unwrap();
        if answers.is_empty() {
            return Err(WireError::Call("no more answers".into()));
        }
        let mut answer = answers.remove(0);
        // A node answers for the range of the request: the movements from `from_seq` up to
        // `to_seq`.
        if answer.to_seq != to_seq || answer.from_seq < from_seq {
            answer.from_seq = from_seq;
            answer.to_seq = to_seq;
            answer
                .movements
                .retain(|m| m.seq >= from_seq && (to_seq == 0 || m.seq <= to_seq));
            statement::sign_with_seed(&mut answer, &SEED).unwrap();
        }
        Ok(vec![Part::new(1, answer.encode_to_vec())])
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
    // One read: the fixed part and one page of 100 rows (Josemi, PR #148).
    assert_eq!(q.max_mu_needed(), 100 + 2 * 100);
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
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0).await.unwrap();
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
    assert!(tally.stopped_instances.is_empty());

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
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, Some(&tally), u128::MAX, now(), 0)
        .await
        .unwrap();
    assert_eq!(t.sent.lock().unwrap()[0].from_seq, 8);
    assert_eq!(t.sent.lock().unwrap()[0].to_seq, 8 + PAGE_ROWS - 1);
    assert_eq!(tally.instances[&a].net_out(), 850_000);
    // The refund to `a` is its stop: the node gave back what was left (Josemi, PR #148).
    assert_eq!(tally.stopped_instances.iter().collect::<Vec<_>>(), [&a]);
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
    let (tally, _) = read(&Fixed::new(vec![s]), &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0)
        .await
        .unwrap();
    assert_eq!(tally.starting_mu(), 0);
    assert_eq!(tally.spent_mu(), Some(0));
    assert!(tally.instances.is_empty());
}

#[tokio::test]
async fn credit_that_the_operator_takes_back_is_spending() {
    // The rows of a real node (n538e, 2026-11-13): a test credit, then the operator takes
    // most of it back with a debit. Josemi (PR #148): a debit counts as spending.
    let rows = vec![
        row("credit", 9_000_000),
        row("credit", 20_000_000),
        row("child_start", -11_378_234),
        ("child_bound", 0, instance_ref("t1"), starts_seq(3)),
        row_of("refund", 71_481, &instance_ref("t1")),
        row("debit", -8_693_247),
        row("statement_query", -114),
    ];
    let (s, _) = statement(CLIENT, None, &rows, 1);
    let p = peer(Some("100"), Some("1"));
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let (tally, _) = read(&Fixed::new(vec![s]), &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0)
        .await
        .unwrap();
    assert_eq!(tally.received_mu(), 29_000_000);
    assert_eq!(tally.kind("debit").out_mu, 8_693_247);
    assert_eq!(tally.spent_mu(), Some(11_306_753 + 114 + 8_693_247));
}

#[tokio::test]
async fn a_read_asks_for_one_page_and_the_next_one_goes_on() {
    // 150 movements: a credit and 149 reads of 1 MU.
    let mut rows = vec![row("credit", 1_000)];
    rows.extend((0..149).map(|_| row("statement_query", -1)));
    let (all, _) = statement(CLIENT, None, &rows, 1);
    let p = peer(Some("10"), Some("1"));
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    assert_eq!(q.max_mu_needed(), 10 + PAGE_ROWS as u128);
    let t = Fixed::new(vec![all.clone(), all]);
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0)
        .await
        .unwrap();
    assert_eq!(t.sent.lock().unwrap()[0].to_seq, PAGE_ROWS);
    // The page is full and the head is further: read the rest.
    assert_eq!(tally.rows_seq, 100);
    assert_eq!(tally.head_seq, 150);
    assert!(tally.incomplete);
    assert_eq!(tally.spent_mu(), Some(99));
    let q = quote_client_read(&p, CLIENT, Some(&tally)).unwrap();
    assert_eq!(q.from_seq(), 101);
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, Some(&tally), u128::MAX, now(), 0)
        .await
        .unwrap();
    assert_eq!(t.sent.lock().unwrap()[1].to_seq, 200);
    assert_eq!(tally.rows_seq, 150);
    assert!(!tally.incomplete);
    assert_eq!(tally.spent_mu(), Some(149));
    assert_eq!(tally.balance_mu, Some(851));
}

fn moved(seq: u64, ts: i64, kind: Kind, amount: i128, balance: i128, iref: &str) -> Movement {
    Movement {
        seq,
        ts,
        amount,
        balance_after: balance,
        kind,
        instance_ref: iref.to_string(),
        detail: String::new(),
        prev_hash: String::new(),
        hash: format!("{seq:064x}"),
    }
}

fn verified(movements: Vec<Movement>) -> VerifiedStatement {
    let head = movements.last().map_or(0, |m| m.seq);
    VerifiedStatement {
        statement: Default::default(),
        peer_id: peer_id(),
        balance: movements.last().map_or(0, |m| m.balance_after),
        relayed: false,
        service_id: String::new(),
        head: KeptHead { seq: head, hash: format!("{head:064x}") },
        next_from_seq: None,
        gap: false,
        movements,
    }
}

#[test]
fn a_tally_keeps_the_sums_of_each_day_on_the_clock_of_the_device() {
    // 2023-11-14 22:30 UTC: 16:30 in Chicago (UTC-6).
    let late = 1_700_001_000;
    let next = late + 2 * 3_600; // 00:30 UTC on the 15th: still the 14th in Chicago.
    let a = instance_ref("tok-a");
    let rows = vec![
        moved(1, late - 86_400, Kind::Credit, 10_000, 10_000, ""),
        moved(2, late, Kind::ChildStart, -1_000, 9_000, ""),
        moved(3, late, Kind::TopUp, -500, 8_500, &a),
        moved(4, next, Kind::StatementQuery, -7, 8_493, ""),
        moved(5, next, Kind::Debit, -100, 8_393, ""),
    ];
    for (offset, today_has) in [(-6 * 3_600, 4usize), (0, 2)] {
        let mut t = Tally::new(Owner::Client, &peer_id(), &account_ref(CLIENT));
        t.fold(&verified(rows.clone()), next, offset);
        let today = day_of(next, offset);
        let sums = t.sums(Some(today));
        let kinds: usize = sums.kinds.values().count();
        assert_eq!(kinds, today_has, "offset {offset}");
        // The sums of all the days are the sums of all the movements.
        assert_eq!(t.sums(Some(today - 6)), t.all());
        assert_eq!(t.sums(None).spent_mu(Owner::Client), 1_000 + 500 + 7 + 100);
    }
    // In Chicago the five movements fall on two days; the instance flow is on the 14th.
    let mut t = Tally::new(Owner::Client, &peer_id(), &account_ref(CLIENT));
    t.fold(&verified(rows), next, -6 * 3_600);
    assert_eq!(t.days.len(), 2);
    let today = t.sums(Some(day_of(next, -6 * 3_600)));
    assert_eq!(today.instances[&a].out_mu, 500);
    assert_eq!(today.spent_mu(Owner::Client), 1_000 + 500 + 7 + 100);
    assert_eq!(today.received_mu(Owner::Client), 0);
}

#[test]
fn a_tally_keeps_only_the_last_days() {
    let first = 1_700_000_000;
    let rows = vec![
        moved(1, first, Kind::Credit, 1_000, 1_000, ""),
        moved(2, first + 200 * 86_400, Kind::StatementQuery, -1, 999, ""),
    ];
    let mut t = Tally::new(Owner::Client, &peer_id(), &account_ref(CLIENT));
    t.fold(&verified(rows), first + 200 * 86_400, 0);
    assert_eq!(t.days.len(), 1);
    // The sums of all the movements stay.
    assert_eq!(t.kind("credit").in_mu, 1_000);
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
    let (tally, _) = read(&Fixed::new(vec![cut]), &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0)
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
    let (tally, _) = read(&t, &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0).await.unwrap();
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
    // The fixed price and one page of 100 rows.
    let e = read(&t, &peer_id(), CLIENT, &q, None, 1_099, now(), 0)
        .await
        .unwrap_err();
    assert!(matches!(
        e,
        SpendingError::Statement(StatementError::OverBudget { needed: 1_100, max: 1_099 })
    ));
    assert!(!e.may_have_charged());
    assert_eq!(t.calls(), 0);
}

#[tokio::test]
async fn a_statement_of_another_account_or_with_a_broken_signature_is_refused() {
    let p = peer(Some("1"), Some("0"));
    let (other, _) = statement("someone-else", None, &[row("credit", 5)], 1);
    let q = quote_client_read(&p, CLIENT, None).unwrap();
    let e = read(&Fixed::new(vec![other]), &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0)
        .await
        .unwrap_err();
    assert!(e.may_have_charged(), "{e:?}");

    let (mut forged, _) = statement(CLIENT, None, &[row("credit", 5)], 1);
    forged.balance = amount(6);
    let e = read(&Fixed::new(vec![forged]), &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0)
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
    let (tally, _) = read(&Fixed::new(vec![first]), &peer_id(), CLIENT, &q, None, u128::MAX, now(), 0)
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
        0,
    )
    .await
    .unwrap_err();
    assert!(
        matches!(e, SpendingError::Statement(StatementError::Invalid(_))),
        "{e:?}"
    );
    // A tally of another account is not used.
    let q = quote_client_read(&p, "other-client", None).unwrap();
    let e = read(&Fixed::new(vec![]), &peer_id(), "other-client", &q, Some(&tally), u128::MAX, now(), 0)
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
