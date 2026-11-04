//! The BTC payment contract of a node (issue #92), as nodo advertises it
//! (`nodo:src/utils/ledger_descriptors.py`, `contracts/bitcoin/interface.py`).

use celaut_client::deposit::{
    is_p2wpkh, BtcPayment, DepositError, DEFAULT_BTC_CONFIRMATIONS, MAX_BTC_CONFIRMATIONS,
};
use celaut_proto::celaut::contract::Ledger;
use celaut_proto::celaut::{Amount, BytesKeyValue, Contract, ContractRate, Peer};

const TOKEN: &str = "1b4e28ba-2fa1-41d2-883f-0016d3cca427";
/// The P2WPKH scriptPubKey of bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu.
const SCRIPT_HEX: &str = "0014c0cebcd6c3d3ca8c75dc5ec62ebe55330ef910e2";

/// nodo's ledger declaration of Bitcoin (sorted `key=value` lines, some of the keys).
fn bitcoin_formal(network: &str, extra: &[(&str, &str)]) -> Vec<u8> {
    let mut pairs: Vec<(String, String)> = [
        ("asset.native", "BTC"),
        ("chain", "bitcoin"),
        ("network", network),
        ("payment.contract_type.p2wpkh", "p2wpkh"),
        (
            "payment.deposit_token",
            "an OP_RETURN output of the same transaction; its data is the UTF-8 deposit token, at most 80 bytes",
        ),
        ("payment.xattr.token_id", "BTC"),
    ]
    .iter()
    .chain(extra.iter())
    .map(|(k, v)| (k.to_string(), v.to_string()))
    .collect();
    pairs.sort();
    pairs
        .iter()
        .map(|(k, v)| format!("{k}={v}"))
        .collect::<Vec<_>>()
        .join("\n")
        .into_bytes()
}

fn kv(key: &str, value: &[u8]) -> BytesKeyValue {
    BytesKeyValue {
        key: key.into(),
        value: Some(value.to_vec()),
    }
}

fn btc_contract(formal: Vec<u8>, kind: &[u8], script: &[u8]) -> Contract {
    Contract {
        ledger: Some(Ledger {
            tags: vec!["bitcoin".into()],
            prose: "This ledger is Bitcoin.".into(),
            formal,
        }),
        xattrs: vec![
            kv("script", script),
            kv("address", b"bc1q..."),
            kv("token_id", b"BTC"),
            kv("contract_type", kind),
        ],
    }
}

fn peer(contracts: Vec<(Contract, &str)>) -> Peer {
    Peer {
        payment_contracts: contracts
            .into_iter()
            .map(|(c, mu)| ContractRate {
                contract: Some(c),
                mu_per_unit: Some(Amount { n: mu.into() }),
            })
            .collect(),
        ..Default::default()
    }
}

fn script() -> Vec<u8> {
    hex::decode(SCRIPT_HEX).unwrap()
}

#[test]
fn the_contract_of_the_wallet_network() {
    let p = peer(vec![
        (btc_contract(bitcoin_formal("mainnet", &[]), b"p2wpkh", &script()), "1400000"),
        (btc_contract(bitcoin_formal("signet", &[]), b"p2wpkh", &script()), "7"),
    ]);
    assert_eq!(BtcPayment::networks(&p), vec!["mainnet", "signet"]);
    let pay = BtcPayment::of(&p, "signet").unwrap();
    assert_eq!(pay.network, "signet");
    assert_eq!(pay.mu_per_sat, 7);
    assert_eq!(pay.script, script());
    assert_eq!(pay.confirmations(), DEFAULT_BTC_CONFIRMATIONS);

    let payment = pay.payment(TOKEN, 50_000).unwrap();
    assert_eq!(payment.deposit_token, TOKEN);
    assert_eq!(payment.amount.unwrap().n, "350000");
    // The contract goes back without a change.
    assert_eq!(payment.contract.as_ref(), Some(&pay.contract));
}

#[test]
fn another_network_is_refused() {
    let p = peer(vec![(
        btc_contract(bitcoin_formal("mainnet", &[]), b"p2wpkh", &script()),
        "1400000",
    )]);
    assert_eq!(
        BtcPayment::of(&p, "signet"),
        Err(DepositError::OtherNetwork {
            node: "mainnet".into(),
            wallet: "signet".into()
        })
    );
    // No network line: refused too.
    let formal = String::from_utf8(bitcoin_formal("x", &[]))
        .unwrap()
        .lines()
        .filter(|l| !l.starts_with("network="))
        .collect::<Vec<_>>()
        .join("\n");
    let p = peer(vec![(btc_contract(formal.into_bytes(), b"p2wpkh", &script()), "1")]);
    assert!(BtcPayment::of(&p, "mainnet").is_err());
    assert!(BtcPayment::networks(&p).is_empty());
}

#[test]
fn no_btc_contract() {
    assert_eq!(BtcPayment::of(&peer(vec![]), "mainnet"), Err(DepositError::NoBtcContract));
    // A rate of 0 is not an offer.
    let p = peer(vec![(btc_contract(bitcoin_formal("mainnet", &[]), b"p2wpkh", &script()), "0")]);
    assert_eq!(BtcPayment::of(&p, "mainnet"), Err(DepositError::NoBtcContract));
    assert!(BtcPayment::networks(&p).is_empty());
}

#[test]
fn only_p2wpkh_is_paid() {
    let p = peer(vec![(btc_contract(bitcoin_formal("mainnet", &[]), b"p2tr", &script()), "1")]);
    assert!(matches!(BtcPayment::of(&p, "mainnet"), Err(DepositError::NotP2wpkh(_))));
    let mut taproot = vec![0x51, 0x20];
    taproot.extend([7u8; 32]);
    let p = peer(vec![(btc_contract(bitcoin_formal("mainnet", &[]), b"p2wpkh", &taproot), "1")]);
    assert!(matches!(BtcPayment::of(&p, "mainnet"), Err(DepositError::NotP2wpkh(_))));
    assert!(is_p2wpkh(&script()));
    assert!(!is_p2wpkh(&taproot));
}

#[test]
fn another_binding_is_refused() {
    let formal = bitcoin_formal("mainnet", &[])
        .split(|b| *b == b'\n')
        .map(|l| {
            if l.starts_with(b"payment.deposit_token=") {
                b"payment.deposit_token=in the witness".to_vec()
            } else {
                l.to_vec()
            }
        })
        .collect::<Vec<_>>()
        .join(&b'\n');
    let p = peer(vec![(btc_contract(formal, b"p2wpkh", &script()), "1")]);
    assert!(matches!(
        BtcPayment::of(&p, "mainnet"),
        Err(DepositError::UnknownBinding(_))
    ));
}

#[test]
fn the_node_can_say_its_confirmations() {
    let make = |n: &str| {
        let p = peer(vec![(
            btc_contract(
                bitcoin_formal("regtest", &[("payment.min_confirmations", n)]),
                b"p2wpkh",
                &script(),
            ),
            "1",
        )]);
        BtcPayment::of(&p, "regtest").unwrap().confirmations()
    };
    assert_eq!(make("2"), 2);
    assert_eq!(make("0"), DEFAULT_BTC_CONFIRMATIONS);
    assert_eq!(make("many"), DEFAULT_BTC_CONFIRMATIONS);
    assert_eq!(make("1000"), MAX_BTC_CONFIRMATIONS);
}

#[test]
fn amounts() {
    let p = peer(vec![(btc_contract(bitcoin_formal("mainnet", &[]), b"p2wpkh", &script()), "1400000")]);
    let pay = BtcPayment::of(&p, "mainnet").unwrap();
    assert!(matches!(pay.mu_for(0), Err(DepositError::BadAmount(_))));
    assert_eq!(pay.mu_for(546).unwrap(), 764_400_000);
    assert!(matches!(pay.payment("bad token", 1000), Err(DepositError::BadToken(_))));
}
