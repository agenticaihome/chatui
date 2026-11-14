//! A real bootstrap on the Tor network. It needs the Internet and takes a minute, so it
//! is ignored: `cargo test -p celaut-tor --test real_tor -- --ignored --nocapture`.

use std::time::Duration;

use celaut_net::{route, Route};
use celaut_tor::{Manager, Mode, State};

#[tokio::test]
#[ignore = "needs the Internet"]
async fn the_embedded_client_gives_a_tor_exit_and_reaches_onion_services() {
    let dir = std::env::temp_dir().join(format!("celaut-tor-real-{}", std::process::id()));
    let manager = Manager::new();
    manager.set_mode(Mode::Embedded {
        state_dir: dir.join("state"),
        cache_dir: dir.join("cache"),
    });
    assert!(matches!(route(), Route::Blocked(_)));

    let started = std::time::Instant::now();
    let mut last = 0;
    loop {
        match manager.status().state {
            State::Ready => break,
            State::Failed(reason) => panic!("Tor did not start: {reason}"),
            State::Starting { percent } => {
                if percent != last {
                    println!("bootstrap {percent}% after {:?}", started.elapsed());
                    last = percent;
                }
            }
            State::Off => panic!("off"),
        }
        assert!(started.elapsed() < Duration::from_secs(300), "too slow");
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
    println!("ready after {:?}", started.elapsed());
    assert!(matches!(route(), Route::Socks(_)));

    // The service of the Tor Project says if the request came from Tor.
    let answer = wallet_net::http::client()
        .get("https://check.torproject.org/api/ip")
        .timeout(Duration::from_secs(120))
        .send()
        .await
        .expect("the request through Tor")
        .text()
        .await
        .unwrap();
    println!("{answer}");
    assert!(answer.contains("\"IsTor\":true"), "{answer}");

    // The same through the connection to a node: the TCP dial goes through Tor.
    let stream = celaut_net::connect("check.torproject.org", 443).await;
    assert!(stream.is_ok(), "{:?}", stream.err());

    // An onion service, as the dial of a node with an onion address does it: the stream
    // opens only after the descriptor, the introduction and the rendezvous, so a stream
    // that answers proves the onion client. The onion service of www.torproject.org.
    let onion = "2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion";
    for round in ["first", "second"] {
        let started = std::time::Instant::now();
        let mut stream = tokio::time::timeout(
            Duration::from_secs(120),
            celaut_net::connect(onion, 80),
        )
        .await
        .expect("the onion service in time")
        .expect("the onion service through Tor");
        println!("onion {round} stream after {:?}", started.elapsed());
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        stream
            .write_all(format!("HEAD / HTTP/1.0\r\nHost: {onion}\r\n\r\n").as_bytes())
            .await
            .unwrap();
        let mut head = [0u8; 12];
        stream.read_exact(&mut head).await.unwrap();
        println!("onion {round} answer after {:?}", started.elapsed());
        assert!(head.starts_with(b"HTTP/1."), "{head:?}");
    }

    manager.set_mode(Mode::Off);
    assert_eq!(route(), Route::Direct);
    let _ = std::fs::remove_dir_all(&dir);
}
