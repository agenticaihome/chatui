//! The payment contracts as the real Python code of nodo advertises them
//! (`ledger_descriptors.ergo_payment_ledger`, `ergo_payment_protocol`,
//! `bitcoin_payment_ledger`, `bitcoin_payment_protocol`; vectors made by
//! `tests/vectors/generate_payment.py`). The client must read the declaration and the
//! `Contract.protocol` of nodo: the network, the binding of the deposit token and the script.

use celaut_client::deposit::{BtcPayment, ErgPayment};
use celaut_proto::celaut::{ContractRate, Peer};
use prost::Message;
use serde_json::Value;

fn vectors() -> Value {
    serde_json::from_str(include_str!("vectors/payment_vectors.json")).unwrap()
}

fn rate(v: &Value, key: &str) -> ContractRate {
    ContractRate::decode(hex::decode(v["contracts"][key].as_str().unwrap()).unwrap().as_slice())
        .unwrap()
}

#[test]
fn the_ergo_contract_of_nodo_is_read() {
    let v = vectors();
    let peer = Peer {
        payment_contracts: vec![rate(&v, "ergo_mainnet_erg")],
        ..Default::default()
    };
    let payment = ErgPayment::of(&peer).unwrap();
    assert_eq!(hex::encode(&payment.script), v["contracts"]["ergo_script"].as_str().unwrap());
    // 0008cd + the compressed key: the P2PK ErgoTree.
    assert!(payment.script.starts_with(&[0x00, 0x08, 0xcd]) && payment.script.len() == 36);
    assert_eq!(payment.mu_for(7).unwrap(), 7000);
}

#[test]
fn the_bitcoin_contract_of_nodo_is_read() {
    let v = vectors();
    let peer = Peer {
        payment_contracts: vec![rate(&v, "bitcoin_mainnet_btc")],
        ..Default::default()
    };
    assert_eq!(BtcPayment::networks(&peer), vec!["mainnet".to_string()]);
    let payment = BtcPayment::of(&peer, "mainnet").unwrap();
    assert_eq!(hex::encode(&payment.script), v["contracts"]["bitcoin_script"].as_str().unwrap());
    assert_eq!(payment.mu_per_sat, 5_000_000);
    assert_eq!(payment.network, "mainnet");
    // nodo says how many confirmations it wants, in the protocol (`payment.min_confirmations`).
    assert_eq!(payment.min_confirmations, Some(1));
    // Another network is refused, not paid.
    assert!(BtcPayment::of(&peer, "regtest").is_err());
}
