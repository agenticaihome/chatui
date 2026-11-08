//! Integration test of milestone M2 against a real node: quote, start, a call through
//! the local port, stop, and the refund in `GetMetrics`.
//!
//! It is `#[ignore]`d because it needs a running nodo (x86_64 with KVM) that already
//! has the service in its registry, and it spends the free credit of a new client on
//! that node. Reach the Gateway through a local port, for example an SSH port-forward
//! (no new firewall rule on the host):
//!
//! ```text
//! ssh -N -L 18460:127.0.0.1:53460 node-host &
//! CELAUT_NODE_PORT=18460 CELAUT_SERVICE_ID=<64 hex> \
//!   cargo test -p celaut-client --test real_node -- --ignored --nocapture
//! ```
//!
//! Optional: `CELAUT_NODE_HOST` (default `127.0.0.1`), `CELAUT_HTTP_PATH` (default
//! `/`) and `CELAUT_INITIAL_MU`, the balance of the instance at the start (default
//! 1000000 MU; the default of the node is one hour of the resources, more than the free
//! credit). The service must answer HTTP/1.1 on its first slot.
//!
//! With `CELAUT_RECEIPTS=1`, for a node with execution receipts (nodo#419), it also
//! checks the start receipt, the close of the kept-alive stream, and a second stream that
//! the client cancels (no close, and no fault). `CELAUT_RECEIPTS_OUT=<file>` writes the
//! receipts in the form of `nodo receipt verify`.
//!
//! The second test, `read_the_statements_of_the_descendants`, reads the statement of a
//! held instance and of its descendants. A read costs MU and writes a movement on the
//! node, so the test reads nothing unless a person sets `CELAUT_DESCENDANTS_MAX_MU`: that
//! is the confirmation, and it is the budget of each read. It needs the token of a running
//! instance of the same session that has descendants: the test starts a service itself
//! (`CELAUT_START_SERVICE_ID`, and one POST with `CELAUT_CALL_PATH` and `CELAUT_CALL_BODY`
//! to make it start descendants), or takes `CELAUT_INSTANCE_TOKEN` of a held instance. It never loops: it
//! reads each statement once, down to `CELAUT_DESCENDANTS_MAX_READS` reads (default 4).
//! `CELAUT_DESCENDANT_SLOT` also opens a tunnel to the first descendant that is alive (it
//! does not send data; a real tunnel costs the opening fee).

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use celaut_balancer::QuoteCache;
use celaut_client::db::{CelautData, InstanceRecord};
use celaut_client::descendants::{self, DescendantState};
use celaut_client::receipts::{check_start, export_jsonl, summarize, InstanceReceipts};
use celaut_client::session::parse_service_id;
use celaut_client::{quotes, LocalPort, MemoryPeerStore, NodeSession};
use celaut_proto::celaut::{Amount, Configuration};
use celaut_wire::{ConnectOptions, Connection, ReceiptEvent, ReceiptSink, TunnelOpener};
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpStream;

fn env(name: &str) -> Option<String> {
    std::env::var(name).ok().filter(|v| !v.is_empty())
}

/// One HTTP/1.1 GET on a kept-alive connection. Gives the status code and the body.
async fn get(socket: &mut BufReader<TcpStream>, path: &str) -> std::io::Result<(u16, String)> {
    let request = format!("GET {path} HTTP/1.1\r\nHost: service\r\nConnection: keep-alive\r\n\r\n");
    socket.get_mut().write_all(request.as_bytes()).await?;
    let mut status = String::new();
    if socket.read_line(&mut status).await? == 0 {
        return Err(std::io::ErrorKind::UnexpectedEof.into());
    }
    let code = status
        .split_whitespace()
        .nth(1)
        .and_then(|c| c.parse().ok())
        .ok_or(std::io::ErrorKind::InvalidData)?;
    let mut length = 0usize;
    loop {
        let mut line = String::new();
        if socket.read_line(&mut line).await? == 0 {
            return Err(std::io::ErrorKind::UnexpectedEof.into());
        }
        let line = line.trim_end();
        if line.is_empty() {
            break;
        }
        if let Some((name, value)) = line.split_once(':') {
            if name.eq_ignore_ascii_case("content-length") {
                length = value
                    .trim()
                    .parse()
                    .map_err(|_| std::io::ErrorKind::InvalidData)?;
            }
        }
    }
    let mut body = vec![0u8; length];
    socket.read_exact(&mut body).await?;
    Ok((code, String::from_utf8_lossy(&body).into_owned()))
}

/// One HTTP/1.1 POST of JSON, read to the end of the connection. For an MCP service.
async fn post(port: u16, path: &str, body: &str) -> std::io::Result<String> {
    let mut socket = TcpStream::connect(("127.0.0.1", port)).await?;
    let request = format!(
        "POST {path} HTTP/1.1\r\nHost: service\r\nContent-Type: application/json\r\nAccept: application/json, text/event-stream\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    socket.write_all(request.as_bytes()).await?;
    let mut out = Vec::new();
    socket.read_to_end(&mut out).await?;
    if out.is_empty() {
        // The service is not listening yet: the caller tries again.
        return Err(std::io::ErrorKind::UnexpectedEof.into());
    }
    Ok(String::from_utf8_lossy(&out).into_owned())
}

#[tokio::test]
#[ignore = "needs a real node: see the comment at the top of the file"]
async fn quote_start_call_stop_and_refund() {
    let host = env("CELAUT_NODE_HOST").unwrap_or_else(|| "127.0.0.1".into());
    let port: u16 = env("CELAUT_NODE_PORT")
        .expect("set CELAUT_NODE_PORT")
        .parse()
        .expect("port");
    let service_id =
        parse_service_id(&env("CELAUT_SERVICE_ID").expect("set CELAUT_SERVICE_ID")).expect("id");
    let path = env("CELAUT_HTTP_PATH").unwrap_or_else(|| "/".into());
    let configuration = Configuration {
        initial_mu: Some(Amount {
            n: env("CELAUT_INITIAL_MU").unwrap_or_else(|| "1000000".into()),
        }),
        ..Default::default()
    };

    let connection = Connection::connect(&host, port, ConnectOptions::default())
        .await
        .expect("connect");
    let peer_id = connection.peer_id().to_string();
    let store = MemoryPeerStore::new();
    let session = NodeSession::open(connection, &peer_id, &store)
        .await
        .expect("open a session");
    let credit = session.balance().await.expect("balance");
    println!("node {peer_id}\nfree credit of the new client: {credit} MU");

    // The quote, through the balancer.
    let cache = Mutex::new(QuoteCache::new());
    let ranked = quotes(&[&session], service_id, &configuration, &cache).await;
    assert!(ranked.failures.is_empty(), "{:?}", ranked.failures);
    let best = &ranked.ranked[0];
    println!(
        "quote: {:?}\ncost for the comparison: {:?} nanoERG",
        best.candidate.quote, best.cost_nano_erg
    );
    let cost = celaut_balancer::amount(best.candidate.quote.cost.as_ref()).expect("cost");
    assert!(
        cost <= credit,
        "the quote {cost} is more than the credit {credit}"
    );

    // Start.
    let started = session
        .start(service_id, configuration.clone())
        .await
        .expect("start");
    let slots = started.slots();
    let after_start = session.balance().await.expect("balance");
    let instance_balance = session
        .instance_balance(&started.token)
        .await
        .expect("metrics");
    println!(
        "started: slots {slots:?}\nclient balance after the start: {after_start} MU\ninstance balance: {instance_balance} MU"
    );
    assert!(!slots.is_empty(), "the instance has no slot");
    let receipts = env("CELAUT_RECEIPTS").is_some();
    if receipts {
        let start = started.receipt.as_ref().expect("a start receipt");
        let faults = check_start(
            start,
            &peer_id,
            &started.token,
            &service_id,
            &configuration.environment_variables,
            configuration.initial_mu.as_ref().map(|a| a.n.as_str()),
        );
        println!("start receipt: initial_mu {:?}, faults {faults:?}", start.initial_mu);
        assert!(faults.is_empty(), "{faults:?}");
    }
    let kept = Arc::new(Mutex::new(InstanceReceipts {
        start: started
            .receipt
            .as_ref()
            .map(|r| celaut_client::receipts::StoredReceipt::new(r, vec![])),
        ..Default::default()
    }));
    let ends = Arc::new(Mutex::new(Vec::new()));
    let sink: ReceiptSink = {
        let (kept, ends) = (kept.clone(), ends.clone());
        Arc::new(move |event: ReceiptEvent| {
            if let ReceiptEvent::Ended { closed, cancelled, .. } = &event {
                ends.lock().unwrap().push((*closed, *cancelled));
            }
            kept.lock().unwrap().apply(&event, 0);
        })
    };
    assert!(after_start < credit, "the start cost nothing");

    // Calls through the local port, all on one TCP connection (one stream). The
    // service can need a moment to listen: a connection that closes before an answer
    // is tried again.
    let opener: Arc<dyn TunnelOpener> = Arc::new(session.transport().clone());
    let local = LocalPort::bind(opener, started.token.clone(), slots[0], Some(sink))
        .await
        .expect("local port");
    let deadline = Instant::now() + Duration::from_secs(120);
    let (mut socket, first) = loop {
        let mut socket = BufReader::new(
            TcpStream::connect(("127.0.0.1", local.port()))
                .await
                .expect("connect to the local port"),
        );
        match tokio::time::timeout(Duration::from_secs(20), get(&mut socket, &path)).await {
            Ok(Ok(answer)) => break (socket, answer),
            other => {
                assert!(
                    Instant::now() < deadline,
                    "no answer through the tunnel: {other:?}, last error {:?}",
                    local.last_error()
                );
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
        }
    };
    let streams_before = local.streams_opened();
    let mut answers = vec![first];
    for _ in 0..2 {
        answers.push(get(&mut socket, &path).await.expect("kept-alive call"));
    }
    println!("answers through the tunnel: {answers:?}");
    assert!(answers.iter().all(|(code, _)| *code == 200), "{answers:?}");
    assert_eq!(
        local.streams_opened(),
        streams_before,
        "the kept-alive calls opened new streams"
    );
    drop(socket);
    if receipts {
        // The end of the local connection half-closes the stream: the node ends it on
        // its own, with a close. Then a second stream, cancelled by this side.
        let deadline = Instant::now() + Duration::from_secs(30);
        while !ends.lock().unwrap().contains(&(true, false)) {
            assert!(Instant::now() < deadline, "no close: {:?}", ends.lock().unwrap());
            tokio::time::sleep(Duration::from_millis(200)).await;
        }
        let mut second = BufReader::new(
            TcpStream::connect(("127.0.0.1", local.port()))
                .await
                .expect("connect to the local port"),
        );
        get(&mut second, &path).await.expect("a call on a second stream");
        // A checkpoint comes after 5 s of traffic.
        tokio::time::sleep(Duration::from_secs(6)).await;
        get(&mut second, &path).await.expect("a second call");
        tokio::time::sleep(Duration::from_secs(1)).await;
        // Dropping the port aborts the relay: the stream is cancelled.
        drop(local);
        let deadline = Instant::now() + Duration::from_secs(30);
        while !ends.lock().unwrap().iter().any(|e| e.1) {
            assert!(Instant::now() < deadline, "no cancel: {:?}", ends.lock().unwrap());
            tokio::time::sleep(Duration::from_millis(200)).await;
        }
        let kept = kept.lock().unwrap().clone();
        let summary = summarize(&kept, &peer_id, &started.token);
        println!("receipts: {summary:?}\nends: {:?}", ends.lock().unwrap());
        assert!(summary.faults.is_empty(), "{summary:?}");
        assert_eq!(summary.start_ok, Some(true));
        assert!(summary.closed >= 1 && summary.cancelled >= 1, "{summary:?}");
        if let Some(out) = env("CELAUT_RECEIPTS_OUT") {
            std::fs::write(&out, export_jsonl(&kept)).expect("write the receipts");
            println!("receipts written to {out}");
        }
        return stop_and_refund(&session, &started.token).await;
    }
    let instance_after_calls = session
        .instance_balance(&started.token)
        .await
        .expect("metrics");
    println!(
        "streams opened: {}\ninstance balance after the calls: {instance_after_calls} MU",
        local.streams_opened()
    );
    drop(local);
    stop_and_refund(&session, &started.token).await;
}

/// Stop, and the refund in the balance of the client.
async fn stop_and_refund(session: &NodeSession<Connection>, token: &str) {
    let before_stop = session.balance().await.expect("balance");
    let refund = session.stop(token).await.expect("stop");
    let after_stop = session.balance().await.expect("balance");
    println!(
        "refund: {refund} MU\nclient balance: {before_stop} MU before the stop, {after_stop} MU after"
    );
    assert!(refund > 0, "no refund");
    assert_eq!(
        after_stop,
        before_stop + refund,
        "the refund is not in GetMetrics"
    );
    // The node forgets the token of a stopped instance.
    let gone = session.instance_balance(token).await;
    assert!(
        gone.is_err(),
        "the stopped instance is still known: {gone:?}"
    );
}

/// The statements of a held instance and of its descendants, one read each, with the
/// budget that a person gave. See the comment at the top of the file.
#[tokio::test]
#[ignore = "needs a real node and spends MU: see the comment at the top of the file"]
async fn read_the_statements_of_the_descendants() {
    let host = env("CELAUT_NODE_HOST").unwrap_or_else(|| "127.0.0.1".into());
    let port: u16 = env("CELAUT_NODE_PORT")
        .expect("set CELAUT_NODE_PORT")
        .parse()
        .expect("port");
    // The confirmation of the person: the most MU that one read can cost.
    let max_mu: u128 = env("CELAUT_DESCENDANTS_MAX_MU")
        .expect("set CELAUT_DESCENDANTS_MAX_MU: each read costs MU and needs a confirmation")
        .parse()
        .expect("MU");
    let max_reads: usize = env("CELAUT_DESCENDANTS_MAX_READS")
        .map(|v| v.parse().expect("number of reads"))
        .unwrap_or(4);

    let connection = Connection::connect(&host, port, ConnectOptions::default())
        .await
        .expect("connect");
    let peer_id = connection.peer_id().to_string();
    let store = MemoryPeerStore::new();
    let session = NodeSession::open(connection, &peer_id, &store)
        .await
        .expect("open a session");

    // The token of an instance of this client. A new client sees only its own instances,
    // so the test can start the service itself (CELAUT_START_SERVICE_ID) and call it to make
    // it start descendants (CELAUT_CALL_PATH and CELAUT_CALL_BODY, one POST), or take a
    // token that a person gives (CELAUT_INSTANCE_TOKEN) when this session holds it.
    let mut started_token = None;
    let token = if let Some(id) = env("CELAUT_START_SERVICE_ID") {
        let service_id = parse_service_id(&id).expect("id");
        let configuration = Configuration {
            initial_mu: Some(Amount {
                n: env("CELAUT_INITIAL_MU").unwrap_or_else(|| "5000000".into()),
            }),
            ..Default::default()
        };
        let started = session.start(service_id, configuration).await.expect("start");
        println!("started {}: slots {:?}", id, started.slots());
        started_token = Some(started.token.clone());
        if let Some(path) = env("CELAUT_CALL_PATH") {
            let slot = started.slots()[0];
            let opener: Arc<dyn TunnelOpener> = Arc::new(session.transport().clone());
            let local = LocalPort::bind(opener, started.token.clone(), slot, None)
                .await
                .expect("local port");
            let body = env("CELAUT_CALL_BODY").unwrap_or_default();
            let deadline = Instant::now() + Duration::from_secs(180);
            loop {
                let answer = tokio::time::timeout(
                    Duration::from_secs(120),
                    post(local.port(), &path, &body),
                )
                .await;
                match answer {
                    Ok(Ok(text)) => {
                        println!("answer to the call: {}", &text[..text.len().min(1500)]);
                        break;
                    }
                    other => {
                        if Instant::now() > deadline {
                            println!("no answer to the call: {other:?}");
                            break;
                        }
                        tokio::time::sleep(Duration::from_secs(3)).await;
                    }
                }
            }
        }
        // A service can start its dependencies after it starts: give it time to bind them.
        let wait: u64 = env("CELAUT_CALL_WAIT_S").and_then(|v| v.parse().ok()).unwrap_or(0);
        tokio::time::sleep(Duration::from_secs(wait)).await;
        started.token
    } else {
        env("CELAUT_INSTANCE_TOKEN").expect("set CELAUT_START_SERVICE_ID or CELAUT_INSTANCE_TOKEN")
    };

    let mut data = CelautData::default();
    data.instances.insert(
        "real".into(),
        InstanceRecord {
            peer_id: peer_id.clone(),
            address: format!("{host}:{port}"),
            token,
            ..Default::default()
        },
    );
    let root = descendants::ensure_root(&mut data, "real").expect("root");
    let before = session.balance().await.expect("balance");

    // One read for each record that is not read yet, shallowest first. No loop on time.
    let mut reads = 0;
    let mut next = Some(root);
    while let Some(k) = next.take() {
        if reads == max_reads {
            break;
        }
        let record = data.descendants[&k].clone();
        let quote = session
            .quote_statement(&record, descendants::DEFAULT_REMAINING_HOPS)
            .expect("quote");
        println!(
            "read {}: at most {} MU of {max_mu}",
            record.instance_ref,
            quote.max_mu_needed()
        );
        let verified = match session.read_statement(&record, &quote, max_mu).await {
            Ok(v) => v,
            Err(e) => {
                // Do not leave the instance of the test running on the node.
                if let Some(token) = &started_token {
                    stop_and_refund(&session, token).await;
                }
                panic!("a checked statement: {e:?}");
            }
        };
        reads += 1;
        println!(
            "balance {} MU, head {}, {} rows, children {:?}",
            verified.balance,
            verified.head.seq,
            verified.movements.len(),
            verified.children().count()
        );
        let mut kinds = std::collections::BTreeMap::new();
        for m in &verified.movements {
            *kinds.entry(format!("{:?}", m.kind)).or_insert(0u32) += 1;
        }
        println!("movements by kind: {kinds:?}");
        let report = descendants::apply_read(&mut data, &k, &verified, 0).expect("apply");
        println!("new descendants: {:?}, findings: {:?}", report.new, report.findings);
        next = descendants::pending(&data, "real")
            .first()
            .map(|r| descendants::key(&r.instance_id, &r.instance_ref));
    }
    let after = session.balance().await.expect("balance");
    println!("{reads} reads cost {} MU", before.saturating_sub(after));
    assert!(
        before.saturating_sub(after) <= max_mu * reads as u128,
        "the reads cost more than the budget"
    );

    // A tunnel to the first descendant that is alive, if a slot is given.
    let Some(slot) = env("CELAUT_DESCENDANT_SLOT") else {
        if let Some(token) = started_token {
            stop_and_refund(&session, &token).await;
        }
        return;
    };
    let slot: u16 = slot.parse().expect("slot");
    let alive = descendants::of_instance(&data, "real")
        .into_iter()
        .find(|r| r.state == DescendantState::Running)
        .cloned()
        .expect("no descendant is alive");
    let tunnel = session
        .open_descendant_tunnel(&alive, slot, None, None)
        .expect("tunnel");
    let _keep = tunnel;
    println!("tunnel to {} opened on slot {slot}", alive.instance_ref);
    if let Some(token) = started_token {
        stop_and_refund(&session, &token).await;
    }
}
