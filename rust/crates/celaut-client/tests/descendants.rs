//! The descendants of nodo#631: the discovery from `child_bound` rows, the read with a
//! budget, the findings of a death with MU kept, and the receipts of a tunnel.
//!
//! The statements are made with the statement code of `celaut-wire`, whose hashes and
//! digests match the vectors of `docs/celaut/descendants.md` (section 10). Those vectors
//! come from a script that follows the nodo code; no real node answered these tests.

mod common;

use std::sync::{Arc, Mutex};

use bee_rpc::frame::Part;
use celaut_client::db::{CelautData, CelautDb, InstanceRecord};
use celaut_client::descendants::{
    self, apply_read, apply_refusal, ensure_root, key, pending, quote_read, read_statement,
    DescendantError, DescendantState, Finding, RefusalKind, MAX_DEPTH, MAX_PER_INSTANCE,
    MAX_REMAINING_HOPS,
};
use celaut_client::receipts::{summarize_descendant, Fault};
use celaut_client::{MemoryPeerStore, NodeSession};
use celaut_proto::celaut::{
    Amount, AmountKeyValue, BalanceMovement, BalanceStatement, Client, ExecutionReceipt, Peer,
};
use celaut_wire::receipt::{self, sign_with_seed, DIRECTION_IN, PLANE_TUNNEL};
use celaut_wire::statement::{
    self, account_ref, genesis_hash, instance_ref, movement_hash, Rates, StatementError,
};
use celaut_wire::{ReceiptEvent, StreamReceipt, Transport, TunnelOpener, WireError};
use common::stream_of;
use prost::Message;
use ring::signature::{Ed25519KeyPair, KeyPair};
use tokio::sync::mpsc;

const SEED: [u8; 32] = [7u8; 32];
const RATES: Rates = Rates {
    query_mu: 100,
    row_mu: 1,
};

fn peer_id() -> String {
    let pair = Ed25519KeyPair::from_seed_unchecked(&SEED).unwrap();
    hex::encode(pair.public_key().as_ref())
}

fn service() -> String {
    "cd".repeat(32)
}

fn amount(n: &str) -> Option<Amount> {
    Some(Amount { n: n.into() })
}

/// The time of the test in Unix seconds. A statement must be dated near the clock of the
/// app, and the session reads the real clock.
///
/// The value is read once, so that two statements of one test have the same dates.
fn stamp() -> i64 {
    static BASE: std::sync::OnceLock<i64> = std::sync::OnceLock::new();
    *BASE.get_or_init(|| {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64
    })
}

/// One row of a statement: kind, instance_ref, detail.
type Row = (&'static str, String, String);

fn bound(child: &str) -> Row {
    (
        "child_bound",
        child.to_string(),
        format!(r#"{{"service_id":"{}","starts_seq":"1"}}"#, service()),
    )
}

fn stop(reason: &str, leftover: u128) -> Row {
    (
        "stop",
        String::new(),
        format!(r#"{{"leftover":"{leftover}","reason":"{reason}"}}"#),
    )
}

/// A signed statement of `account` for the rows, from seq `from` (the chain starts at the
/// genesis hash only if `from` is 1; for a later start the first `prev_hash` is a made-up
/// hash, as the app cannot check it). The head is the last row.
fn statement_of(
    token: &str,
    iref: &str,
    from: u64,
    kept_prev: Option<&str>,
    rows: &[Row],
) -> BalanceStatement {
    let account = account_ref(token);
    let mut prev = match (from, kept_prev) {
        (1, _) => genesis_hash(&account),
        (_, Some(h)) => h.to_string(),
        _ => "11".repeat(32),
    };
    let mut movements = Vec::new();
    for (i, (kind, mref, detail)) in rows.iter().enumerate() {
        let mut m = BalanceMovement {
            seq: from + i as u64,
            ts: stamp() - 500 + (from + i as u64) as i64,
            amount: amount("0"),
            balance_after: amount("0"),
            kind: (*kind).into(),
            instance_ref: mref.clone(),
            detail: detail.clone(),
            prev_hash: prev.clone(),
        };
        prev = movement_hash(&m);
        movements.push(m);
    }
    let head_seq = from + rows.len() as u64 - 1;
    let mut s = BalanceStatement {
        account_ref: account,
        from_seq: from,
        to_seq: 0,
        movements,
        balance: amount("0"),
        head_seq,
        head_hash: prev,
        oldest_seq: 1,
        retention_days: 0,
        ts: stamp(),
        signature: String::new(),
        relayed: false,
        service_id: String::new(),
        instance_ref: iref.into(),
    };
    statement::sign_with_seed(&mut s, &SEED).unwrap();
    s
}

/// Re-sign after a change.
fn resigned(mut s: BalanceStatement) -> BalanceStatement {
    statement::sign_with_seed(&mut s, &SEED).unwrap();
    s
}

/// A transport with fixed answers. It counts the calls and keeps the requests.
struct Fixed {
    answers: Mutex<Vec<Result<Vec<Part>, WireError>>>,
    sent: Mutex<Vec<(String, Vec<Part>)>>,
}

impl Fixed {
    fn new() -> Self {
        Fixed {
            answers: Mutex::new(Vec::new()),
            sent: Mutex::new(Vec::new()),
        }
    }
    fn with_statements(list: Vec<BalanceStatement>) -> Self {
        let t = Fixed::new();
        for s in list {
            t.answers
                .lock()
                .unwrap()
                .push(Ok(vec![Part::new(1, s.encode_to_vec())]));
        }
        t
    }
    fn failing(text: &str) -> Self {
        let t = Fixed::new();
        t.answers
            .lock()
            .unwrap()
            .push(Err(WireError::Call(text.into())));
        t
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
        self.sent.lock().unwrap().push((method.into(), parts));
        let mut answers = self.answers.lock().unwrap();
        if answers.is_empty() {
            return Err(WireError::Call("no more answers".into()));
        }
        answers.remove(0)
    }
}

// The database with one held instance.

const INSTANCE_ID: &str = "inst-1";
const TOKEN: &str = "held-token";

fn data_with_instance() -> (CelautData, String) {
    let mut data = CelautData::default();
    data.instances.insert(
        INSTANCE_ID.into(),
        InstanceRecord {
            peer_id: peer_id(),
            address: "node:1".into(),
            token: TOKEN.into(),
            service_id: service(),
            ..Default::default()
        },
    );
    let root = ensure_root(&mut data, INSTANCE_ID).unwrap();
    (data, root)
}

fn client() -> &'static str {
    "c11e47000000400080000000000000aa"
}

async fn read(
    data: &CelautData,
    k: &str,
    t: &Fixed,
    hops: u32,
    max_mu: u128,
) -> Result<statement::VerifiedStatement, DescendantError> {
    let record = data.descendants[k].clone();
    let quote = quote_read(&record, Some(RATES), hops)?;
    read_statement(t, &peer_id(), client(), &record, &quote, max_mu, stamp()).await
}

fn child(n: u8) -> String {
    instance_ref(&format!("child-{n}"))
}

// ─── The budget ───────────────────────────────────────────────────────────

#[tokio::test]
async fn a_read_over_the_budget_sends_nothing() {
    let (data, root) = data_with_instance();
    let s = statement_of(TOKEN, "", 1, None, &[bound(&child(1))]);
    let t = Fixed::with_statements(vec![s]);
    let quote = quote_read(&data.descendants[&root], Some(RATES), 3).unwrap();
    // from_seq 1, to_seq 0: up to 1000 rows. 2 reads of (100 + 1000).
    assert_eq!(quote.max_mu_needed(), 2 * (100 + 1000));
    let needed = quote.max_mu_needed();
    let record = data.descendants[&root].clone();
    let result = read_statement(
        &t,
        &peer_id(),
        client(),
        &record,
        &quote,
        needed - 1,
        stamp(),
    )
    .await;
    match result {
        Err(DescendantError::OverBudget { needed: n, max }) => {
            assert_eq!((n, max), (needed, needed - 1))
        }
        other => panic!("{other:?}"),
    }
    assert_eq!(t.calls(), 0, "nothing went out");
    // The exact budget goes through, and it is one call, not more.
    read_statement(&t, &peer_id(), client(), &record, &quote, needed, stamp())
        .await
        .unwrap();
    assert_eq!(t.calls(), 1);
}

#[test]
fn the_hops_are_capped_and_the_rates_are_needed() {
    let (data, root) = data_with_instance();
    let r = &data.descendants[&root];
    for hops in [0, MAX_REMAINING_HOPS + 1, u32::MAX] {
        assert!(matches!(
            quote_read(r, Some(RATES), hops),
            Err(DescendantError::BadHops { .. })
        ));
    }
    assert!(quote_read(r, Some(RATES), MAX_REMAINING_HOPS).is_ok());
    assert!(matches!(
        quote_read(r, None, 2),
        Err(DescendantError::NoRates)
    ));
}

#[tokio::test]
async fn the_request_names_the_ancestor_token_and_the_descendant() {
    let (mut data, root) = data_with_instance();
    let s = statement_of(TOKEN, "", 1, None, &[bound(&child(1))]);
    let v = statement::verify(
        &quote_read(&data.descendants[&root], Some(RATES), 2)
            .unwrap()
            .request()
            .clone(),
        &peer_id(),
        s,
        None,
        stamp(),
    )
    .unwrap();
    apply_read(&mut data, &root, &v, 10).unwrap();
    let c = key(INSTANCE_ID, &child(1));
    let quote = quote_read(&data.descendants[&c], Some(RATES), 2).unwrap();
    let r = quote.request();
    assert_eq!(r.token, TOKEN);
    assert_eq!(r.instance_ref, child(1));
    assert_eq!(r.from_seq, 1);
    assert_eq!(r.remaining_hops, 2, "the app always sets the hops");
    // The root is read through its own token: no instance_ref.
    let q = quote_read(&data.descendants[&root], Some(RATES), 2).unwrap();
    assert_eq!(q.request().instance_ref, "");
}

#[tokio::test]
async fn a_descendant_of_another_node_is_not_read() {
    let (data, root) = data_with_instance();
    let t = Fixed::with_statements(vec![]);
    let record = data.descendants[&root].clone();
    let quote = quote_read(&record, Some(RATES), 2).unwrap();
    let other = "00".repeat(32);
    let e = read_statement(&t, &other, client(), &record, &quote, u128::MAX, stamp())
        .await
        .unwrap_err();
    assert!(matches!(e, DescendantError::OtherNode));
    assert_eq!(t.calls(), 0);
}

// ─── The discovery, level by level ────────────────────────────────────────

#[tokio::test]
async fn the_children_are_found_level_by_level_and_each_read_is_a_call() {
    let (mut data, root) = data_with_instance();
    // Level 1: the held instance binds two children.
    let t = Fixed::with_statements(vec![statement_of(
        TOKEN,
        "",
        1,
        None,
        &[bound(&child(2)), bound(&child(1))],
    )]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    let report = apply_read(&mut data, &root, &v, 100).unwrap();
    assert_eq!(report.new, vec![child(2), child(1)]);
    assert_eq!(t.calls(), 1, "one read; the children are not read");
    assert_eq!(data.descendants[&root].state, DescendantState::Running);
    assert_eq!(data.descendants[&root].rows_seq, 2);
    assert_eq!(data.descendants[&root].last_checked_at, Some(100));

    let list = pending(&data, INSTANCE_ID);
    assert_eq!(list.len(), 2);
    assert!(list.iter().all(|r| r.depth == 1 && r.parent_ref.is_none()));
    assert_eq!(list[0].service_id.as_deref(), Some(service().as_str()));

    // Level 2: the user confirmed the read of child 1.
    let c1 = key(INSTANCE_ID, &child(1));
    let t = Fixed::with_statements(vec![statement_of(
        TOKEN,
        &child(1),
        1,
        None,
        &[bound(&child(3))],
    )]);
    let v = read(&data, &c1, &t, 2, u128::MAX).await.unwrap();
    let report = apply_read(&mut data, &c1, &v, 200).unwrap();
    assert_eq!(report.new, vec![child(3)]);
    let g = &data.descendants[&key(INSTANCE_ID, &child(3))];
    assert_eq!(g.depth, 2);
    assert_eq!(g.parent_ref.as_deref(), Some(child(1).as_str()));
    assert_eq!(g.parent_token, TOKEN);
    // The shallowest first: child 2 (depth 1) before child 3 (depth 2).
    let order: Vec<_> = pending(&data, INSTANCE_ID)
        .iter()
        .map(|r| r.instance_ref.clone())
        .collect();
    assert_eq!(order, vec![child(2), child(3)]);
}

#[tokio::test]
async fn a_second_read_goes_on_after_the_last_row_and_keeps_the_head() {
    let (mut data, root) = data_with_instance();
    let first = statement_of(TOKEN, "", 1, None, &[bound(&child(1))]);
    let first_hash = first.head_hash.clone();
    let t = Fixed::with_statements(vec![first]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    apply_read(&mut data, &root, &v, 1).unwrap();
    let r = &data.descendants[&root];
    assert_eq!(
        (r.rows_seq, r.head_seq, r.head_hash.as_str()),
        (1, 1, first_hash.as_str())
    );

    // The next read asks from seq 2. The new row hangs from the kept head.
    let second = statement_of(TOKEN, "", 2, Some(&first_hash), &[bound(&child(2))]);
    let t = Fixed::with_statements(vec![second]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    {
        let sent = t.sent.lock().unwrap();
        let request =
            celaut_proto::celaut::BalanceStatementRequest::decode(sent[0].1[0].data.as_slice())
                .unwrap();
        assert_eq!(request.from_seq, 2);
    }
    apply_read(&mut data, &root, &v, 2).unwrap();
    assert_eq!(data.descendants[&root].rows_seq, 2);

    // A node that goes back on its head is refused.
    let other = statement_of(TOKEN, "", 2, Some(&"22".repeat(32)), &[bound(&child(5))]);
    let t = Fixed::with_statements(vec![other]);
    let e = read(&data, &root, &t, 2, u128::MAX).await.unwrap_err();
    assert!(
        matches!(e, DescendantError::Statement(StatementError::Invalid(_))),
        "{e:?}"
    );
    assert!(e.may_have_charged());
}

#[test]
fn the_depth_and_the_number_of_descendants_are_capped() {
    let (mut data, root) = data_with_instance();
    let request = quote_read(&data.descendants[&root], Some(RATES), 2).unwrap();
    let verified = |iref: &str, rows: &[Row]| {
        let mut r = request.request().clone();
        r.instance_ref = iref.into();
        statement::verify(
            &r,
            &peer_id(),
            statement_of(TOKEN, iref, 1, None, rows),
            None,
            stamp(),
        )
        .unwrap()
    };

    // A record at the depth limit: its children are left out and counted.
    let deep_ref = child(9);
    let deep_key = key(INSTANCE_ID, &deep_ref);
    let mut deep = data.descendants[&root].clone();
    deep.instance_ref = deep_ref.clone();
    deep.depth = MAX_DEPTH;
    deep.state = DescendantState::Bound;
    data.descendants.insert(deep_key.clone(), deep);
    let v = verified(&deep_ref, &[bound(&child(10))]);
    let report = apply_read(&mut data, &deep_key, &v, 1).unwrap();
    assert_eq!((report.new.len(), report.too_deep), (0, 1));
    assert!(!data.descendants.contains_key(&key(INSTANCE_ID, &child(10))));

    // One level above the limit still takes children.
    let mut up = data.descendants[&deep_key].clone();
    up.instance_ref = child(11);
    up.depth = MAX_DEPTH - 1;
    let up_key = key(INSTANCE_ID, &up.instance_ref);
    data.descendants.insert(up_key.clone(), up);
    let v = verified(&child(11), &[bound(&child(12))]);
    let report = apply_read(&mut data, &up_key, &v, 1).unwrap();
    assert_eq!(report.new, vec![child(12)]);
    assert_eq!(
        data.descendants[&key(INSTANCE_ID, &child(12))].depth,
        MAX_DEPTH
    );

    // The number of descendants of one instance is capped.
    let held = data.descendants.values().filter(|r| r.depth > 0).count();
    for n in held..MAX_PER_INSTANCE {
        let mut r = data.descendants[&root].clone();
        r.instance_ref = instance_ref(&format!("fill-{n}"));
        r.depth = 1;
        data.descendants
            .insert(key(INSTANCE_ID, &r.instance_ref), r);
    }
    let v = verified("", &[bound(&child(13))]);
    let report = apply_read(&mut data, &root, &v, 1).unwrap();
    assert_eq!((report.new.len(), report.too_many), (0, 1));
}

// ─── Death with MU kept ───────────────────────────────────────────────────

#[tokio::test]
async fn a_stop_with_a_leftover_is_a_finding_and_the_state_is_kept() {
    let (mut data, root) = data_with_instance();
    let v = read(
        &data,
        &root,
        &Fixed::with_statements(vec![statement_of(TOKEN, "", 1, None, &[bound(&child(1))])]),
        2,
        u128::MAX,
    )
    .await
    .unwrap();
    apply_read(&mut data, &root, &v, 1).unwrap();
    let c = key(INSTANCE_ID, &child(1));

    let refund: Row = (
        "refund",
        String::new(),
        r#"{"lost":"father_gone"}"#.to_string(),
    );
    let t = Fixed::with_statements(vec![statement_of(
        TOKEN,
        &child(1),
        1,
        None,
        &[refund, stop("out_of_balance", 12)],
    )]);
    let v = read(&data, &c, &t, 2, u128::MAX).await.unwrap();
    let report = apply_read(&mut data, &c, &v, 50).unwrap();
    assert_eq!(
        report.findings,
        vec![Finding::StoppedWithMu {
            instance_ref: child(1),
            reason: "out_of_balance".into(),
            leftover_mu: 12,
            father_gone: true,
        }]
    );
    let r = &data.descendants[&c];
    assert_eq!(r.state, DescendantState::Stopped);
    assert_eq!(r.stop_reason.as_deref(), Some("out_of_balance"));
    assert_eq!(r.leftover(), Some(12));
    assert!(r.father_gone);
}

#[tokio::test]
async fn a_stop_with_no_leftover_is_no_finding_but_stays_stopped() {
    let (mut data, root) = data_with_instance();
    let t = Fixed::with_statements(vec![statement_of(
        TOKEN,
        "",
        1,
        None,
        &[stop("stopped", 0)],
    )]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    let report = apply_read(&mut data, &root, &v, 1).unwrap();
    assert!(report.findings.is_empty());
    assert_eq!(data.descendants[&root].state, DescendantState::Stopped);
    assert_eq!(data.descendants[&root].leftover(), Some(0));
    assert!(!data.descendants[&root].father_gone);
}

#[tokio::test]
async fn a_refusal_of_the_node_is_a_finding_and_other_errors_are_not() {
    let (mut data, root) = data_with_instance();
    let c = key(INSTANCE_ID, &child(1));
    let mut rec = data.descendants[&root].clone();
    rec.instance_ref = child(1);
    rec.depth = 1;
    rec.state = DescendantState::Running;
    data.descendants.insert(c.clone(), rec);

    let t = Fixed::failing("status: PermissionDenied, message: \"No chain\"");
    let e = read(&data, &c, &t, 2, u128::MAX).await.unwrap_err();
    assert!(!e.may_have_charged());
    let finding = apply_refusal(&mut data, &c, &e, 77).unwrap();
    match finding {
        Finding::StatementRefused {
            before, refusal, ..
        } => assert_eq!(
            (before, refusal),
            (DescendantState::Running, RefusalKind::NotLinked)
        ),
        other => panic!("{other:?}"),
    }
    let r = &data.descendants[&c];
    assert_eq!(r.state, DescendantState::Refused);
    assert_eq!(r.last_checked_at, Some(77));
    assert!(r
        .last_refusal
        .as_deref()
        .unwrap()
        .contains("PermissionDenied"));

    // A budget error and a timeout change nothing.
    let budget = DescendantError::OverBudget { needed: 2, max: 1 };
    assert_eq!(apply_refusal(&mut data, &c, &budget, 1), None);
    let timeout = DescendantError::Statement(StatementError::Wire(WireError::Timeout));
    assert_eq!(apply_refusal(&mut data, &c, &timeout, 1), None);
    assert_eq!(data.descendants[&c].last_checked_at, Some(77));

    // A stopped descendant stays stopped when a later read is refused.
    data.descendants.get_mut(&c).unwrap().state = DescendantState::Stopped;
    let t = Fixed::failing("status: Unavailable");
    let e = read(&data, &c, &t, 2, u128::MAX).await.unwrap_err();
    apply_refusal(&mut data, &c, &e, 80).unwrap();
    assert_eq!(data.descendants[&c].state, DescendantState::Stopped);

    assert_eq!(
        RefusalKind::of_text("status: ResourceExhausted"),
        RefusalKind::CannotPay
    );
    assert_eq!(
        RefusalKind::of_text("RESOURCE_EXHAUSTED"),
        RefusalKind::CannotPay
    );
    assert_eq!(
        RefusalKind::of_text("status: Unimplemented"),
        RefusalKind::Delegated
    );
    assert_eq!(
        RefusalKind::of_text("status: NotFound"),
        RefusalKind::NotFound
    );
    assert_eq!(RefusalKind::of_text("something"), RefusalKind::Other);
}

// ─── Bad answers ──────────────────────────────────────────────────────────

#[tokio::test]
async fn an_old_node_that_ignores_instance_ref_is_refused_with_a_clear_error() {
    let (mut data, root) = data_with_instance();
    let c = key(INSTANCE_ID, &child(1));
    let mut rec = data.descendants[&root].clone();
    rec.instance_ref = child(1);
    rec.depth = 1;
    data.descendants.insert(c.clone(), rec);
    // The old node answers with the account of the token, and no instance_ref.
    let t = Fixed::with_statements(vec![statement_of(TOKEN, "", 1, None, &[bound(&child(7))])]);
    let e = read(&data, &c, &t, 2, u128::MAX).await.unwrap_err();
    assert_eq!(e.to_string(), "node does not support descendants");
    assert!(matches!(
        e,
        DescendantError::Statement(StatementError::NoDescendants)
    ));
    assert!(e.may_have_charged(), "the read was charged: tell the user");
    // Nothing of that answer is kept.
    assert_eq!(apply_refusal(&mut data, &c, &e, 1), None);
    assert!(!data.descendants.contains_key(&key(INSTANCE_ID, &child(7))));
}

#[tokio::test]
async fn another_instance_ref_a_bad_signature_and_a_bad_chain_are_refused() {
    let (mut data, root) = data_with_instance();
    let c = key(INSTANCE_ID, &child(1));
    let mut rec = data.descendants[&root].clone();
    rec.instance_ref = child(1);
    rec.depth = 1;
    data.descendants.insert(c.clone(), rec);
    let rows = [bound(&child(7))];

    // Another instance_ref, correctly signed.
    let t = Fixed::with_statements(vec![statement_of(TOKEN, &child(2), 1, None, &rows)]);
    let e = read(&data, &c, &t, 2, u128::MAX).await.unwrap_err();
    assert!(matches!(
        e,
        DescendantError::Statement(StatementError::Invalid(_))
    ));

    // A changed signature.
    let mut s = statement_of(TOKEN, &child(1), 1, None, &rows);
    s.signature.replace_range(
        0..1,
        if s.signature.starts_with('a') {
            "b"
        } else {
            "a"
        },
    );
    let e = read(&data, &c, &Fixed::with_statements(vec![s]), 2, u128::MAX)
        .await
        .unwrap_err();
    assert!(matches!(
        e,
        DescendantError::Statement(StatementError::Invalid(_))
    ));

    // A broken chain, signed.
    let mut s = statement_of(TOKEN, &child(1), 1, None, &rows);
    s.movements[0].prev_hash = "33".repeat(32);
    let e = read(
        &data,
        &c,
        &Fixed::with_statements(vec![resigned(s)]),
        2,
        u128::MAX,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        e,
        DescendantError::Statement(StatementError::Invalid(_))
    ));
    assert!(data.descendants.keys().all(|k| !k.ends_with(&child(7))));
    let _ = &mut data;
}

// ─── The database ─────────────────────────────────────────────────────────

#[test]
fn the_descendants_go_with_their_instance_and_a_merge_keeps_both() {
    let (mut data, root) = data_with_instance();
    data.descendant_receipts
        .insert(root.clone(), Default::default());
    let mut other = CelautData::default();
    let (o, ok) = data_with_instance();
    other.merge_missing(o);
    assert!(other.descendants.contains_key(&ok));
    other.descendants.clear();
    data.merge_missing(other);
    assert!(data.descendants.contains_key(&root));
    data.remove_descendants_of("another");
    assert!(data.descendants.contains_key(&root));
    data.remove_descendants_of(INSTANCE_ID);
    assert!(data.descendants.is_empty() && data.descendant_receipts.is_empty());
}

// ─── The session ──────────────────────────────────────────────────────────

fn signed_peer(rates: &[(&str, &str)]) -> Peer {
    let mut peer = common::vectors().peers[0].peer();
    peer.mu_per_call = rates
        .iter()
        .map(|(k, v)| AmountKeyValue {
            key: (*k).into(),
            value: amount(v),
        })
        .collect();
    let pair = Ed25519KeyPair::from_seed_unchecked(&SEED).unwrap();
    peer.public_key = peer_id();
    let digest = celaut_client::peer::content_digest(&peer);
    let payload = celaut_client::peer::signed_payload(&peer.public_key, peer.ts, &digest);
    peer.signature = hex::encode(pair.sign(payload.as_bytes()).as_ref());
    peer
}

/// The arguments of a descendant tunnel call: token, instance_ref, slot, hops.
type TunnelCall = (String, String, u16, Option<u32>);

/// A transport with a Peer, that also opens descendant tunnels. A tunnel call is kept.
struct Node {
    inner: common::FixedStreams,
    tunnels: Mutex<Vec<TunnelCall>>,
    knows_descendants: bool,
}

impl Transport for Node {
    async fn call(
        &self,
        method: &str,
        parts: Vec<Part>,
        accepted: &[i32],
    ) -> Result<Vec<Part>, WireError> {
        self.inner.call(method, parts, accepted).await
    }
}

impl TunnelOpener for Node {
    fn open_tunnel(
        &self,
        _token: &str,
        _slot: u16,
        _receipts: Option<celaut_wire::ReceiptSink>,
    ) -> celaut_wire::Tunnel {
        unreachable!("not used")
    }

    fn open_descendant_tunnel(
        &self,
        token: &str,
        instance_ref: &str,
        slot: u16,
        remaining_hops: Option<u32>,
        _receipts: Option<celaut_wire::ReceiptSink>,
    ) -> celaut_wire::Tunnel {
        self.tunnels.lock().unwrap().push((
            token.into(),
            instance_ref.into(),
            slot,
            remaining_hops,
        ));
        let (to_service, _) = mpsc::channel(1);
        let (from_tx, from_service) = mpsc::channel(1);
        if !self.knows_descendants {
            from_tx.try_send(Err(WireError::NoDescendants)).unwrap();
        }
        celaut_wire::Tunnel {
            to_service,
            from_service,
        }
    }
}

async fn session(
    rates: &[(&str, &str)],
    more: Vec<BalanceStatement>,
    knows_descendants: bool,
) -> NodeSession<Node> {
    let mut answers = vec![
        stream_of(
            1,
            &Client {
                client_id: client().into(),
                ..Default::default()
            },
        ),
        stream_of(1, &signed_peer(rates)),
    ];
    answers.extend(more.iter().map(|s| stream_of(1, s)));
    let node = Node {
        inner: common::FixedStreams::new(answers),
        tunnels: Mutex::new(Vec::new()),
        knows_descendants,
    };
    NodeSession::open(node, &peer_id(), &MemoryPeerStore::new())
        .await
        .expect("open")
}

const PRICED: [(&str, &str); 2] = [("statement_query_mu", "100"), ("statement_row_mu", "1")];

#[tokio::test]
async fn the_session_quotes_from_the_rates_of_the_node_and_reads_once() {
    let (mut data, root) = data_with_instance();
    let s = session(
        &PRICED,
        vec![statement_of(TOKEN, "", 1, None, &[bound(&child(1))])],
        true,
    )
    .await;
    let record = data.descendants[&root].clone();
    let quote = s.quote_statement(&record, 2).unwrap();
    assert_eq!(quote.max_mu_needed(), 1100);
    let before = s.transport().inner.calls();
    assert!(matches!(
        s.read_statement(&record, &quote, 1099).await,
        Err(DescendantError::OverBudget { .. })
    ));
    assert_eq!(
        s.transport().inner.calls(),
        before,
        "no call over the budget"
    );
    let v = s.read_statement(&record, &quote, 1100).await.unwrap();
    assert_eq!(s.transport().inner.calls(), before + 1);
    assert_eq!(s.transport().inner.request(before).0, "GetBalanceStatement");
    apply_read(&mut data, &root, &v, 5).unwrap();
    assert_eq!(data.descendants.len(), 2);
}

#[tokio::test]
async fn a_node_that_gives_no_rates_gives_no_quote() {
    let (data, root) = data_with_instance();
    let s = session(&[("statement_query_mu", "100")], vec![], true).await;
    assert!(matches!(
        s.quote_statement(&data.descendants[&root], 2),
        Err(DescendantError::NoRates)
    ));
}

#[tokio::test]
async fn the_tunnel_to_a_descendant_goes_through_the_ancestor_token() {
    let (mut data, root) = data_with_instance();
    let s = session(&PRICED, vec![], true).await;
    let v = {
        let t = Fixed::with_statements(vec![statement_of(TOKEN, "", 1, None, &[bound(&child(1))])]);
        read(&data, &root, &t, 2, u128::MAX).await.unwrap()
    };
    apply_read(&mut data, &root, &v, 1).unwrap();
    let c = &data.descendants[&key(INSTANCE_ID, &child(1))];
    s.open_descendant_tunnel(c, 8080, Some(3), None).unwrap();
    assert_eq!(
        s.transport().tunnels.lock().unwrap()[0],
        (TOKEN.into(), child(1), 8080, Some(3))
    );
    // The held instance is not a descendant, and the hops are capped. No tunnel opened.
    let r = &data.descendants[&root];
    assert!(matches!(
        s.open_descendant_tunnel(r, 8080, None, None),
        Err(DescendantError::NotADescendant)
    ));
    assert!(matches!(
        s.open_descendant_tunnel(c, 8080, Some(0), None),
        Err(DescendantError::BadHops { .. })
    ));
    assert!(matches!(
        s.open_descendant_tunnel(c, 8080, Some(MAX_REMAINING_HOPS + 1), None),
        Err(DescendantError::BadHops { .. })
    ));
    let mut elsewhere = c.clone();
    elsewhere.peer_id = "00".repeat(32);
    assert!(matches!(
        s.open_descendant_tunnel(&elsewhere, 8080, None, None),
        Err(DescendantError::OtherNode)
    ));
    assert_eq!(s.transport().tunnels.lock().unwrap().len(), 1);
}

#[tokio::test]
async fn an_old_node_ends_the_tunnel_with_no_descendants() {
    let (mut data, root) = data_with_instance();
    let s = session(&PRICED, vec![], false).await;
    let v = {
        let t = Fixed::with_statements(vec![statement_of(TOKEN, "", 1, None, &[bound(&child(1))])]);
        read(&data, &root, &t, 2, u128::MAX).await.unwrap()
    };
    apply_read(&mut data, &root, &v, 1).unwrap();
    let c = &data.descendants[&key(INSTANCE_ID, &child(1))];
    let mut tunnel = s.open_descendant_tunnel(c, 80, None, None).unwrap();
    let first = tunnel.from_service.recv().await.unwrap();
    let e = first.unwrap_err();
    assert!(matches!(e, WireError::NoDescendants));
    assert_eq!(e.to_string(), "node does not support descendants");
}

// ─── The receipts ─────────────────────────────────────────────────────────

fn checkpoint_for(execution_name: String) -> ExecutionReceipt {
    let i = receipt::replay_chain([b"ping".as_slice()], DIRECTION_IN);
    let o = receipt::Chain::default();
    let mut r = ExecutionReceipt {
        kind: receipt::KIND_CHECKPOINT.into(),
        execution_name,
        ts: 100,
        plane: PLANE_TUNNEL.into(),
        session: "ab".repeat(8),
        slot: "8080".into(),
        seq: 1,
        in_events: i.events,
        in_bytes: i.bytes,
        in_head: i.head,
        out_events: o.events,
        out_bytes: o.bytes,
        out_head: o.head,
        mu_charged: amount("10"),
        coverage: receipt::COVERAGE_CLIENT_TUNNEL.into(),
        ..Default::default()
    };
    sign_with_seed(&mut r, &SEED).unwrap();
    r
}

fn event_of(r: ExecutionReceipt) -> ReceiptEvent {
    ReceiptEvent::Receipt(StreamReceipt {
        receipt: r,
        problems: vec![],
        ordering: vec![],
        sent_mismatch: false,
        got_mismatch: false,
    })
}

#[test]
fn the_receipts_of_a_descendant_tunnel_are_kept_with_the_descendant() {
    let (data, root) = data_with_instance();
    let db = Arc::new(CelautDb::in_memory());
    db.update(|d| *d = data).unwrap();
    let c = key(INSTANCE_ID, &child(1));
    db.update(|d| {
        let mut r = d.descendants[&root].clone();
        r.instance_ref = child(1);
        r.depth = 1;
        d.descendants.insert(c.clone(), r);
    })
    .unwrap();

    let sink = descendants::receipt_sink(db.clone(), c.clone(), || 1234);
    let good = receipt::execution_name_by_ref(&child(1), &peer_id()).unwrap();
    sink(event_of(checkpoint_for(good)));
    sink(ReceiptEvent::Ended {
        session: Some("ab".repeat(8)),
        closed: false,
        cancelled: true,
    });
    // A receipt of an unknown descendant keeps nothing.
    let unknown = descendants::receipt_sink(db.clone(), "nobody".into(), || 1);
    unknown(event_of(checkpoint_for("00".repeat(32))));

    let data = db.snapshot();
    assert_eq!(data.descendant_receipts.len(), 1);
    assert!(data.receipts.is_empty(), "not in the receipts of instances");
    let kept = &data.descendant_receipts[&c];
    let summary = summarize_descendant(kept, &peer_id(), &child(1));
    assert_eq!(summary.faults, vec![]);
    assert_eq!(
        (summary.streams, summary.checkpoints, summary.cancelled),
        (1, 1, 1)
    );
    // Named by another descendant, or as a token, the same receipts are a fault.
    let other = summarize_descendant(kept, &peer_id(), &child(2));
    assert!(matches!(other.faults[0], Fault::Invalid { .. }));
    let as_token = celaut_client::receipts::summarize(kept, &peer_id(), &child(1));
    assert!(!as_token.faults.is_empty());
}

// ─── Review findings ──────────────────────────────────────────────────────

#[tokio::test]
async fn a_paged_read_is_not_a_proof_that_the_account_is_alive() {
    let (mut data, root) = data_with_instance();
    // The account has a stop at seq 3. The node gives only row 1 and signs the head.
    let full = statement_of(
        TOKEN,
        "",
        1,
        None,
        &[bound(&child(1)), bound(&child(2)), stop("stopped", 40)],
    );
    let mut paged = full.clone();
    paged.movements.truncate(1);
    let paged = resigned(paged);
    let first_hash = movement_hash(&full.movements[0]);
    let t = Fixed::with_statements(vec![paged]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    assert_eq!(v.next_from_seq, Some(2));
    let report = apply_read(&mut data, &root, &v, 1).unwrap();
    assert!(report.incomplete);
    let r = &data.descendants[&root];
    assert!(r.incomplete);
    assert_eq!(r.rows_seq, 1);
    assert_eq!(r.head_seq, 3, "the signed head is kept");
    assert_ne!(r.state, DescendantState::Running, "the stop was not read");
    assert_eq!(r.state, DescendantState::Bound);

    // The next read goes on after row 1, reaches the head and finds the stop.
    let rest = statement_of(
        TOKEN,
        "",
        2,
        Some(&first_hash),
        &[bound(&child(2)), stop("stopped", 40)],
    );
    let t = Fixed::with_statements(vec![rest]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    assert_eq!(v.next_from_seq, None);
    let report = apply_read(&mut data, &root, &v, 2).unwrap();
    assert!(!report.incomplete);
    let r = &data.descendants[&root];
    assert!(!r.incomplete);
    assert_eq!(r.state, DescendantState::Stopped);
    assert!(matches!(
        report.findings[0],
        Finding::StoppedWithMu {
            leftover_mu: 40,
            ..
        }
    ));
}

#[tokio::test]
async fn a_complete_read_with_no_stop_is_alive() {
    let (mut data, root) = data_with_instance();
    let t = Fixed::with_statements(vec![statement_of(TOKEN, "", 1, None, &[bound(&child(1))])]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    let report = apply_read(&mut data, &root, &v, 1).unwrap();
    assert!(!report.incomplete && !data.descendants[&root].incomplete);
    assert_eq!(data.descendants[&root].state, DescendantState::Running);
}

#[tokio::test]
async fn another_service_than_the_known_one_is_refused() {
    let (mut data, root) = data_with_instance();
    // The held instance has the service `cd..cd`. A statement says `ab..ab`.
    let mut s = statement_of(TOKEN, "", 1, None, &[bound(&child(1))]);
    s.service_id = "ab".repeat(32);
    let t = Fixed::with_statements(vec![resigned(s)]);
    let e = read(&data, &root, &t, 2, u128::MAX).await.unwrap_err();
    assert!(matches!(e, DescendantError::ServiceChanged { .. }), "{e:?}");
    assert!(e.may_have_charged());
    assert_eq!(data.descendants[&root].service_id, Some(service()));

    // The same service is fine.
    let mut s = statement_of(TOKEN, "", 1, None, &[bound(&child(1))]);
    s.service_id = service();
    let t = Fixed::with_statements(vec![resigned(s)]);
    let v = read(&data, &root, &t, 2, u128::MAX).await.unwrap();
    apply_read(&mut data, &root, &v, 1).unwrap();

    // A caller that skips `read_statement` still keeps the first service in the record,
    // and the report names the conflict.
    let mut s = statement_of(TOKEN, "", 1, None, &[bound(&child(1))]);
    s.service_id = "ab".repeat(32);
    let mut request = quote_read(&data.descendants[&root], Some(RATES), 2)
        .unwrap()
        .request()
        .clone();
    request.from_seq = 1;
    let v = statement::verify(&request, &peer_id(), resigned(s), None, stamp()).unwrap();
    let report = apply_read(&mut data, &root, &v, 2).unwrap();
    assert_eq!(
        report.service_conflicts,
        vec![data.descendants[&root].instance_ref.clone()]
    );
    assert_eq!(data.descendants[&root].service_id, Some(service()));
}

#[test]
fn a_bound_row_with_another_service_does_not_change_a_known_descendant() {
    let (mut data, root) = data_with_instance();
    let request = quote_read(&data.descendants[&root], Some(RATES), 2)
        .unwrap()
        .request()
        .clone();
    let verified = |rows: &[Row]| {
        statement::verify(
            &request,
            &peer_id(),
            statement_of(TOKEN, "", 1, None, rows),
            None,
            stamp(),
        )
        .unwrap()
    };
    let v = verified(&[bound(&child(1))]);
    apply_read(&mut data, &root, &v, 1).unwrap();
    let c = key(INSTANCE_ID, &child(1));
    assert_eq!(data.descendants[&c].service_id, Some(service()));
    // The same child, bound again with another service.
    let other = (
        "child_bound",
        child(1),
        format!(r#"{{"service_id":"{}","starts_seq":"1"}}"#, "ab".repeat(32)),
    );
    let v = verified(&[other]);
    let report = apply_read(&mut data, &root, &v, 2).unwrap();
    assert_eq!(report.service_conflicts, vec![child(1)]);
    assert_eq!(data.descendants[&c].service_id, Some(service()));
}

#[test]
fn the_token_is_not_written_to_the_file_and_not_in_the_debug_text() {
    let (data, root) = data_with_instance();
    let record = data.descendants[&root].clone();
    assert_eq!(record.parent_token, TOKEN);
    let json = serde_json::to_string(&record).unwrap();
    assert!(!json.contains(TOKEN), "{json}");
    let debug = format!("{record:?}");
    assert!(!debug.contains(TOKEN), "{debug}");
    // The whole database holds no copy of the token of a descendant either.
    let mut data = data;
    let v = statement::verify(
        quote_read(&record, Some(RATES), 2).unwrap().request(),
        &peer_id(),
        statement_of(TOKEN, "", 1, None, &[bound(&child(1))]),
        None,
        stamp(),
    )
    .unwrap();
    apply_read(&mut data, &root, &v, 1).unwrap();
    assert_eq!(data.descendants.len(), 2);
    let count = serde_json::to_string(&data.descendants).unwrap();
    assert!(!count.contains(TOKEN), "{count}");
    // A quote hides the token in its Debug text too.
    let quote = quote_read(&record, Some(RATES), 2).unwrap();
    assert!(!format!("{quote:?}").contains(TOKEN));
    // The record from the file has no token until the caller sets it.
    let back: celaut_client::descendants::DescendantRecord = serde_json::from_str(&json).unwrap();
    assert_eq!(back.parent_token, "");
    assert_eq!(back.with_token(TOKEN).parent_token, TOKEN);
}

#[tokio::test]
async fn the_tunnel_quote_gives_the_most_that_a_stream_can_cost_and_a_stream_count() {
    let (mut data, root) = data_with_instance();
    let v = {
        let t = Fixed::with_statements(vec![statement_of(TOKEN, "", 1, None, &[bound(&child(1))])]);
        read(&data, &root, &t, 2, u128::MAX).await.unwrap()
    };
    apply_read(&mut data, &root, &v, 1).unwrap();
    let c = &data.descendants[&key(INSTANCE_ID, &child(1))];
    let priced = [
        ("statement_query_mu", "100"),
        ("statement_row_mu", "1"),
        ("tunnel_open_mu", "10000"),
    ];
    let s = session(&priced, vec![], true).await;
    let q = s.quote_tunnel(c, 3).unwrap();
    assert_eq!(q.remaining_hops(), 3);
    assert_eq!(q.open_mu(), 10_000);
    assert_eq!(q.max_mu_per_stream(), 30_000, "one fee for each leg");
    assert!(q.is_for(c));
    assert_eq!(q.streams_for(30_000).unwrap(), 1);
    assert_eq!(q.streams_for(95_000).unwrap(), 3);
    assert!(matches!(
        q.streams_for(29_999),
        Err(DescendantError::OverBudget {
            needed: 30_000,
            max: 29_999
        })
    ));
    // The hops are always set and capped, and the held instance has no quote.
    assert!(matches!(
        s.quote_tunnel(c, 0),
        Err(DescendantError::BadHops { .. })
    ));
    assert!(matches!(
        s.quote_tunnel(c, MAX_REMAINING_HOPS + 1),
        Err(DescendantError::BadHops { .. })
    ));
    assert!(matches!(
        s.quote_tunnel(&data.descendants[&root], 2),
        Err(DescendantError::NotADescendant)
    ));
    // A node that does not say its fee gives no quote: the tunnel stays closed.
    let none = session(&PRICED, vec![], true).await;
    assert!(matches!(
        none.quote_tunnel(c, 2),
        Err(DescendantError::NoRates)
    ));
}
