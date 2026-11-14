//! A real node through its onion address and the Tor client of the app (#140). It needs
//! the Internet and a node that announces an onion address, so it is ignored:
//!
//! ```text
//! nodo invite --raw - | xxd -p | tr -d '\n'     # on the node
//! CELAUT_INVITE_HEX=<that hex> \
//!   cargo test -p celaut-tor --test real_onion_node -- --ignored --nocapture
//! ```
//!
//! It reads the invitation as the app does, keeps the addresses that the Tor client of
//! the app can try (the onion first, no private network), and dials them in that order
//! with the invited key pinned, as `celaut_connect_invite` does. The first one that
//! proves the key ends the test. It sends no call, so it makes no client on the node.

use std::time::{Duration, Instant};

use celaut_client::invite::{self, Kind, Via};
use celaut_tor::{Manager, Mode, State};
use celaut_wire::{ConnectOptions, Connection};

#[tokio::test]
#[ignore = "needs the Internet and a node with an onion address"]
async fn an_invitation_reaches_the_node_by_its_onion_through_the_tor_client_of_the_app() {
    let raw = hex::decode(std::env::var("CELAUT_INVITE_HEX").expect("CELAUT_INVITE_HEX"))
        .expect("hex");
    let parsed = invite::parse(&raw).expect("an invitation");
    let plan = invite::plan(&parsed.addrs, Via::TorEmbedded);
    println!("order {:?}", plan.order.iter().map(|a| a.text()).collect::<Vec<_>>());
    println!("skipped {:?}", plan.skipped);
    assert_eq!(
        plan.order.first().map(|a| a.kind),
        Some(Kind::Onion),
        "the invitation has no onion address"
    );

    let dir = std::env::temp_dir().join(format!("celaut-tor-onion-{}", std::process::id()));
    let manager = Manager::new();
    manager.set_mode(Mode::Embedded {
        state_dir: dir.join("state"),
        cache_dir: dir.join("cache"),
    });
    let started = Instant::now();
    loop {
        match manager.status().state {
            State::Ready => break,
            State::Failed(reason) => panic!("Tor did not start: {reason}"),
            _ => {}
        }
        assert!(started.elapsed() < Duration::from_secs(300), "too slow");
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
    println!("Tor ready after {:?}", started.elapsed());

    let mut proved = None;
    for a in &plan.order {
        let t = Instant::now();
        let result = Connection::connect(
            &a.host,
            a.port,
            ConnectOptions {
                expected_peer_id: Some(parsed.peer_id.clone()),
                connect_timeout: Duration::from_secs(90),
                ..ConnectOptions::default()
            },
        )
        .await;
        match result {
            Ok(c) => {
                println!("{} proved {} after {:?}", a.text(), c.peer_id(), t.elapsed());
                proved = Some((a.kind, c.peer_id().to_string()));
                break;
            }
            Err(e) => println!("{} failed after {:?}: {e}", a.text(), t.elapsed()),
        }
    }
    manager.set_mode(Mode::Off);
    let _ = std::fs::remove_dir_all(&dir);
    let (kind, peer_id) = proved.expect("no address of the invitation worked");
    assert_eq!(kind, Kind::Onion);
    assert_eq!(peer_id, parsed.peer_id);
}
