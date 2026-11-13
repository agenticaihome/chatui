//! Issue #136 against a real node: add MU to an instance and take it back
//! (`ModifyDeposit`), and the spending from the signed statements of the client and of
//! the instance.
//!
//! It is `#[ignore]`d: it needs a running nodo that has the service in its registry, built,
//! and it spends the free credit of a new client on that node. A statement read costs MU, so
//! the test reads nothing unless a person sets `CELAUT_SPENDING_MAX_MU`: that is the
//! confirmation, and the budget of each read.
//!
//! ```text
//! CELAUT_NODE_HOST=10.213.195.2 CELAUT_NODE_PORT=58526 CELAUT_SERVICE_ID=<64 hex> \
//! CELAUT_SPENDING_MAX_MU=5000 \
//!   cargo test -p celaut-client --test real_node_spending -- --ignored --nocapture
//! ```
//!
//! The checks: each move changes the balances of the client and of the instance by the
//! amount, and nothing else (no fee); a take-back of more than the instance has is refused;
//! each statement verifies; the second read of the client starts after the first; and after
//! the stop, what the client statement says went to the instance and did not come back is
//! what the statement of the instance says it spent.

use std::time::Duration;

use celaut_client::session::parse_service_id;
use celaut_client::spending::{Owner, Tally};
use celaut_client::{MemoryPeerStore, NodeSession};
use celaut_proto::celaut::{Amount, Configuration};
use celaut_wire::statement::instance_ref;
use celaut_wire::{ConnectOptions, Connection};

fn env(name: &str) -> Option<String> {
    std::env::var(name).ok().filter(|v| !v.is_empty())
}

fn show(what: &str, t: &Tally) {
    println!(
        "{what}: rows to {} (head {}), balance {:?}, received {}, returned {}, spent {:?}, partial {}, incomplete {}, kinds {:?}",
        t.rows_seq,
        t.head_seq,
        t.balance_mu,
        t.received_mu(),
        t.returned_mu(),
        t.spent_mu(),
        t.partial,
        t.incomplete,
        t.by_kind
            .iter()
            .map(|(k, f)| format!("{k}: -{} +{}", f.out_mu, f.in_mu))
            .collect::<Vec<_>>()
    );
}

#[tokio::test]
#[ignore = "needs a real node: see the comment at the top of the file"]
async fn moves_and_statements_on_a_real_node() {
    let host = env("CELAUT_NODE_HOST").unwrap_or_else(|| "127.0.0.1".into());
    let port: u16 = env("CELAUT_NODE_PORT").expect("set CELAUT_NODE_PORT").parse().expect("port");
    let service_id =
        parse_service_id(&env("CELAUT_SERVICE_ID").expect("set CELAUT_SERVICE_ID")).expect("id");
    let max_mu: u128 = env("CELAUT_SPENDING_MAX_MU")
        .expect("set CELAUT_SPENDING_MAX_MU: each statement read costs MU")
        .parse()
        .expect("a number of MU");

    let connection = Connection::connect(&host, port, ConnectOptions::default())
        .await
        .expect("connect");
    let peer_id = connection.peer_id().to_string();
    let store = MemoryPeerStore::new();
    let session = NodeSession::open(connection, &peer_id, &store).await.expect("session");
    let credit = session.balance().await.expect("balance");
    println!("node {peer_id}\nfree credit of the new client: {credit} MU");

    // The first read of the client: from the first movement.
    let q = session.quote_client_statement(None).expect("quote");
    println!("first read of the client: from {} , at most {} MU", q.from_seq(), q.max_mu_needed());
    let client = session.read_account(&q, None, max_mu).await.expect("read the client");
    show("client, first read", &client);
    assert_eq!(client.owner, Owner::Client);
    assert!(!client.partial);
    assert_eq!(client.balance_mu, Some(i128::try_from(session.balance().await.unwrap()).unwrap()));
    // The only spending so far is the read itself.
    assert_eq!(
        client.spent_mu(),
        Some(client.kind("statement_query").out_mu),
        "spent = the reads"
    );

    // Start.
    let configuration = Configuration {
        initial_mu: Some(Amount { n: "1000000".into() }),
        ..Default::default()
    };
    let started = session.start(service_id, configuration).await.expect("start");
    let token = started.token.clone();
    let iref = instance_ref(&token);
    let b0 = session.instance_balance(&token).await.expect("metrics");
    let c0 = session.balance().await.expect("balance");
    println!("started {iref}: instance {b0} MU, client {c0} MU");

    // Add 200 000 MU, then take back 50 000 MU: each move is exactly the amount.
    session.top_up(&token, 200_000).await.expect("add");
    let b1 = session.instance_balance(&token).await.unwrap();
    let c1 = session.balance().await.unwrap();
    println!("after add: instance {b1} MU, client {c1} MU");
    assert_eq!(c0 - c1, 200_000, "the client paid more or less than the amount");
    // The instance can pay a maintenance period in between: at most the amount.
    assert!(b1 <= b0 + 200_000 && b1 + 200_000 > b0, "instance {b0} -> {b1}");
    session.take_back(&token, 50_000).await.expect("take back");
    let b2 = session.instance_balance(&token).await.unwrap();
    let c2 = session.balance().await.unwrap();
    println!("after take back: instance {b2} MU, client {c2} MU");
    assert_eq!(c2 - c1, 50_000, "the client got more or less than the amount");
    assert!(b2 + 50_000 <= b1, "instance {b1} -> {b2}");
    // More than the instance has: the node refuses, and nothing moves.
    let e = session.take_back(&token, b2 + 1_000_000_000).await.unwrap_err();
    println!("take back of too much: {e}");
    assert_eq!(session.balance().await.unwrap(), c2);

    // The second read of the client starts after the first.
    let q = session.quote_client_statement(Some(&client)).expect("quote");
    assert_eq!(q.from_seq(), client.rows_seq + 1);
    let client = session.read_account(&q, Some(&client), max_mu).await.expect("read again");
    show("client, second read", &client);
    let flow = client.instances.get(&iref).expect("the instance in the statement");
    println!("to the instance: -{} +{}", flow.out_mu, flow.in_mu);
    assert_eq!(flow.out_mu, 1_000_000 + 200_000);
    assert_eq!(flow.in_mu, 50_000);

    // The account of the instance.
    let q = session.quote_instance_statement(&token, None).expect("quote");
    let inst = session.read_account(&q, None, max_mu).await.expect("read the instance");
    show("instance, first read", &inst);
    assert_eq!(inst.owner, Owner::Instance);
    assert_eq!(inst.kind("start").in_mu, 1_000_000);
    assert_eq!(inst.kind("top_up").in_mu, 200_000);
    assert_eq!(inst.kind("withdrawal").out_mu, 50_000);

    // Stop: the refund goes back to the client. Then both accounts again.
    let refund = session.stop(&token).await.expect("stop");
    println!("refund {refund} MU");
    tokio::time::sleep(Duration::from_secs(2)).await;
    let q = session.quote_instance_statement(&token, Some(&inst)).expect("quote");
    let inst = session.read_account(&q, Some(&inst), max_mu).await.expect("read the stopped instance");
    show("instance, after the stop", &inst);
    assert!(inst.stopped, "no stop movement");
    let q = session.quote_client_statement(Some(&client)).expect("quote");
    let client = session.read_account(&q, Some(&client), max_mu).await.expect("read the client");
    show("client, after the stop", &client);
    let flow = client.instances.get(&iref).expect("the instance");
    println!(
        "client says the instance kept {} MU; the instance says it spent {:?} MU",
        flow.net_out(),
        inst.spent_mu()
    );
    assert_eq!(Some(flow.net_out()), inst.spent_mu(), "the two statements disagree");
    assert_eq!(
        client.balance_mu,
        Some(i128::try_from(session.balance().await.unwrap()).unwrap())
    );
    // Spent = what went to instances and did not come back + the reads.
    assert_eq!(
        client.spent_mu().unwrap(),
        client.instances.values().map(|f| f.net_out()).sum::<i128>()
            + client.kind("statement_query").out_mu
            + client.starting_mu()
    );
}
