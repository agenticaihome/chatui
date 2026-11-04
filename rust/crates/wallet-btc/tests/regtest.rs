//! The wallet against a real regtest chain: a bitcoind and an Esplora server.
//!
//! Ignored by default. Run with:
//!
//! ```text
//! BTC_E2E_ESPLORA=http://127.0.0.1:18094/regtest/api \
//! BTC_E2E_CLI="docker exec laneC-esplora cli" \
//!   cargo test -p wallet-btc --test regtest -- --ignored --test-threads 1
//! ```
//!
//! `BTC_E2E_CLI` runs bitcoin-cli of the regtest node; it only mines blocks. No other network.

use std::time::Duration;

use wallet_btc::esplora::Esplora;
use wallet_btc::scan::{full_scan, STOP_GAP};
use wallet_btc::{BtcNetwork, BtcWallet};

fn env(name: &str) -> String {
    std::env::var(name).unwrap_or_else(|_| panic!("set {name}"))
}

/// Run `bitcoin-cli <args>` through the command in `BTC_E2E_CLI` (for example
/// `docker exec laneC-esplora cli`), and return its output.
fn cli(args: &[&str]) -> String {
    let command = format!("{} {}", env("BTC_E2E_CLI"), args.join(" "));
    let out = std::process::Command::new("sh")
        .args(["-c", &command])
        .output()
        .unwrap();
    assert!(out.status.success(), "{command}: {}", String::from_utf8_lossy(&out.stderr));
    String::from_utf8(out.stdout).unwrap().trim().to_string()
}

async fn mine(blocks: u32, address: &str) {
    cli(&["generatetoaddress", &blocks.to_string(), address]);
}

/// Mine, then wait until the Esplora server has indexed the new tip.
async fn mine_and_wait(esplora: &Esplora, blocks: u32, address: &str) {
    let before = esplora.tip_height().await.unwrap();
    mine(blocks, address).await;
    for _ in 0..120 {
        if esplora.tip_height().await.unwrap() >= before + blocks {
            tokio::time::sleep(Duration::from_millis(500)).await;
            return;
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
    panic!("the Esplora server did not index the blocks");
}

async fn sync(wallet: &mut BtcWallet, esplora: &Esplora) {
    let request = wallet.scan_request();
    let response = full_scan(esplora, BtcNetwork::Regtest.bitcoin(), request, STOP_GAP)
        .await
        .unwrap();
    wallet.apply_scan(response).unwrap();
}

fn seed(byte: u8) -> [u8; 64] {
    [byte; 64]
}

#[tokio::test]
#[ignore = "needs a regtest bitcoind and Esplora (BTC_E2E_ESPLORA, BTC_E2E_CLI)"]
async fn receive_send_and_op_return() {
    let esplora = Esplora::new(&env("BTC_E2E_ESPLORA")).unwrap();
    // A seed per run, so that an old run's coins do not count.
    let run = (std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs()
        % 200) as u8
        + 1;
    let mut alice = BtcWallet::new(&seed(run), BtcNetwork::Regtest).unwrap();
    let mut bob = BtcWallet::new(&seed(run.wrapping_add(50)), BtcNetwork::Regtest).unwrap();
    let alice_address = alice.receive_address();
    let bob_address = bob.receive_address();
    assert!(alice_address.starts_with("bcrt1q"));

    // Receive: one coinbase to Alice, matured by 100 more blocks to an outside address.
    // The blocks that are not Alice's go to a third wallet that the test never reads.
    let outside = BtcWallet::new(&seed(run.wrapping_add(100)), BtcNetwork::Regtest)
        .unwrap()
        .receive_address();
    mine_and_wait(&esplora, 1, &alice_address).await;
    mine_and_wait(&esplora, 100, &outside).await;
    sync(&mut alice, &esplora).await;
    let balance = alice.balance();
    assert!(balance.confirmed >= 50_000_000, "{balance:?}");
    assert_eq!(alice.transactions().len(), 1);
    assert_ne!(alice.receive_address(), alice_address, "a used address is not offered again");

    // Send 0.1 BTC to Bob with a deposit token in an OP_RETURN.
    let token = b"7db2e50e-0000-4000-8000-000000000000";
    let prepared = alice
        .prepare_send(&bob_address, 10_000_000, false, 2.0, Some(token))
        .unwrap();
    assert_eq!(prepared.amount_sat, 10_000_000);
    assert!(prepared.fee_sat > 0 && prepared.fee_sat < 2_000, "{}", prepared.fee_sat);
    let tx = alice.sign(&prepared).unwrap();
    let txid = esplora.broadcast(&tx).await.unwrap();
    assert_eq!(txid, prepared.txid);
    alice.record_sent(tx.clone(), 1);
    assert!(alice.balance().pending > 0);

    // Not confirmed: Bob sees it pending.
    tokio::time::sleep(Duration::from_secs(2)).await;
    sync(&mut bob, &esplora).await;
    assert_eq!(bob.balance().pending, 10_000_000, "{:?}", bob.balance());
    assert!(!esplora.tx_status(&txid).await.unwrap().confirmed);

    // One block: confirmed for both.
    mine_and_wait(&esplora, 1, &outside).await;
    sync(&mut bob, &esplora).await;
    sync(&mut alice, &esplora).await;
    assert_eq!(bob.balance().confirmed, 10_000_000);
    let history = bob.transactions();
    assert_eq!(history[0].txid, txid.to_string());
    assert_eq!(history[0].net_sat, 10_000_000);
    assert_eq!(history[0].confirmations, 1);
    let sent = alice.transactions();
    assert_eq!(sent[0].txid, txid.to_string());
    assert_eq!(sent[0].net_sat, -(10_000_000 + prepared.fee_sat as i64));
    assert!(esplora.tx_status(&txid).await.unwrap().confirmed);

    // The OP_RETURN carries the token as it is: what nodo reads.
    let data = tx
        .output
        .iter()
        .find(|o| o.script_pubkey.is_op_return())
        .unwrap();
    assert!(data.script_pubkey.as_bytes().ends_with(token));

    // Send all back to Alice.
    let back = alice.receive_address();
    let all = bob.prepare_send(&back, 0, true, 1.0, None).unwrap();
    assert_eq!(all.amount_sat + all.fee_sat, 10_000_000);
    assert_eq!(all.change_sat, 0);
    let tx = bob.sign(&all).unwrap();
    esplora.broadcast(&tx).await.unwrap();
    mine_and_wait(&esplora, 1, &outside).await;
    sync(&mut bob, &esplora).await;
    assert_eq!(bob.balance().total(), 0);
}
