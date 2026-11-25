//! The M3 deposit parts: the ERG contract of a node, the `Payment`, the deposit token,
//! the deposit box on the explorer, and the two calls on fixed bee-rpc streams.

mod common;

use celaut_client::deposit::{
    check_deposit_token, find_deposit_box, unspent_boxes_url, DepositBox, DepositError, ErgPayment,
    NODO_DEFAULT_EXPLORER,
};
use celaut_client::{ClientError, MemoryPeerStore, NodeSession};
use celaut_proto::celaut::contract::{Ledger, Protocol};
use celaut_proto::celaut::{
    Amount, BytesKeyValue, Client, Contract, ContractRate, Payment, Peer, TokenMessage,
};
use celaut_wire::WireError;
use common::{stream_of, FixedStreams};
use prost::Message;
use ring::signature::{Ed25519KeyPair, KeyPair};

const TOKEN: &str = "1b4e28ba-2fa1-41d2-883f-0016d3cca427";
/// A P2PK ErgoTree: `0008cd` and a compressed public key.
const SCRIPT_HEX: &str = "0008cd03a0f4d3b1c2e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f";

/// The ledger declaration of an Ergo payment contract, as nodo makes it
/// (`ledger_descriptors.py`, sorted `key=value` lines). Only some of the keys.
fn ergo_formal(network: &str, binding: &str) -> Vec<u8> {
    let mut pairs = [
        ("asset.native".to_string(), "ERG".to_string()),
        ("chain".to_string(), "ergo".to_string()),
        ("network".to_string(), network.to_string()),
        (
            "payment.accepted".to_string(),
            "that box exists and is unspent, in a block or in the mempool".to_string(),
        ),
        ("payment.deposit_token".to_string(), binding.to_string()),
        (
            "payment.xattr.script".to_string(),
            "ErgoTree bytes (propositionBytes) that receive the payment".to_string(),
        ),
    ];
    pairs.sort();
    pairs
        .iter()
        .map(|(k, v)| format!("{k}={v}"))
        .collect::<Vec<_>>()
        .join("\n")
        .into_bytes()
}

const R4_BINDING: &str = "R4 of that box: Coll[Byte], UTF-8 of the deposit token";

fn kv(key: &str, value: &[u8]) -> BytesKeyValue {
    BytesKeyValue {
        key: key.into(),
        value: Some(value.to_vec()),
    }
}

fn contract(tag: &str, token_id: &str, formal: Vec<u8>, script: Option<&[u8]>) -> Contract {
    let mut xattrs = vec![
        kv("token_id", token_id.as_bytes()),
    ];
    if let Some(s) = script {
        xattrs.push(kv("script", s));
    }
    Contract {
        ledger: Some(Ledger {
            tags: vec![tag.into()],
            prose: "Ergo mainnet.".into(),
            formal,
        }),
        protocol: Some(Protocol {
            tags: vec!["ergo-p2pk".into()],
            prose: "Pay to a public key.".into(),
            formal: b"payment.kind=p2pk: proveDlog(decodePoint())".to_vec(),
        }),
        xattrs,
    }
}

fn rate(contract: Contract, mu_per_unit: &str) -> ContractRate {
    ContractRate {
        contract: Some(contract),
        mu_per_unit: Some(Amount {
            n: mu_per_unit.into(),
        }),
    }
}

fn script() -> Vec<u8> {
    hex::decode(SCRIPT_HEX).unwrap()
}

fn erg_contract() -> Contract {
    contract(
        "ergo-mainnet",
        "ERG",
        ergo_formal("mainnet", R4_BINDING),
        Some(&script()),
    )
}

fn peer_with(rates: Vec<ContractRate>) -> Peer {
    Peer {
        payment_contracts: rates,
        ..Default::default()
    }
}

#[test]
fn the_erg_contract_is_kept_without_a_change() {
    let token_contract = contract(
        "ergo-mainnet",
        "03faf2cb329f2e90d6d23b58d91bbb6c046aa143261cc21f52fbe2824bfcbf04",
        ergo_formal("mainnet", R4_BINDING),
        Some(&script()),
    );
    let peer = peer_with(vec![
        rate(
            contract("bitcoin-mainnet", "BTC", Vec::new(), Some(b"\x00\x14")),
            "1400000",
        ),
        rate(token_contract, "5"),
        rate(erg_contract(), "0"),
        rate(erg_contract(), "3"),
    ]);
    let payment = ErgPayment::of(&peer).unwrap();
    // The first ERG contract with a rate more than 0, as the balancer selects it.
    assert_eq!(payment.mu_per_nano_erg, 3);
    assert_eq!(payment.script, script());
    let advertised = peer.payment_contracts[3].contract.as_ref().unwrap();
    assert_eq!(payment.contract.encode_to_vec(), advertised.encode_to_vec());
}

#[test]
fn a_node_without_a_usable_erg_contract_is_refused() {
    assert_eq!(
        ErgPayment::of(&peer_with(vec![])).unwrap_err(),
        DepositError::NoErgContract
    );
    let no_script = contract("ergo-mainnet", "ERG", ergo_formal("mainnet", R4_BINDING), None);
    assert_eq!(
        ErgPayment::of(&peer_with(vec![rate(no_script, "1")])).unwrap_err(),
        DepositError::NoScript
    );
    let empty_script = contract("ergo-mainnet", "ERG", ergo_formal("mainnet", R4_BINDING), Some(b""));
    assert_eq!(
        ErgPayment::of(&peer_with(vec![rate(empty_script, "1")])).unwrap_err(),
        DepositError::NoScript
    );
    let bad_rate = rate(erg_contract(), "lots");
    assert_eq!(
        ErgPayment::of(&peer_with(vec![bad_rate])).unwrap_err(),
        DepositError::NoErgContract
    );
}

#[test]
fn only_ergo_mainnet_with_the_token_in_r4_is_paid() {
    let cases = [
        (ergo_formal("genesis 0123", R4_BINDING), "network"),
        (Vec::new(), "chain"),
        (b"chain=ergo".to_vec(), "network"),
        (ergo_formal("mainnet", "an OP_RETURN output"), "OP_RETURN"),
    ];
    for (formal, what) in cases {
        let c = contract("ergo-mainnet", "ERG", formal, Some(&script()));
        let err = ErgPayment::of(&peer_with(vec![rate(c, "1")])).unwrap_err();
        assert!(
            matches!(
                err,
                DepositError::NotMainnet(_) | DepositError::UnknownBinding(_)
            ),
            "{what}: {err}"
        );
        assert!(err.to_string().contains(what), "{what}: {err}");
    }
    // A declaration that does not name the binding is accepted (R4 is the rule of
    // `docs/celaut/wire.md`).
    let unnamed = contract(
        "ergo-mainnet",
        "ERG",
        b"chain=ergo\nnetwork=mainnet".to_vec(),
        Some(&script()),
    );
    assert!(ErgPayment::of(&peer_with(vec![rate(unnamed, "1")])).is_ok());
}

#[test]
fn the_payment_buys_the_mu_of_the_amount() {
    let peer = peer_with(vec![rate(erg_contract(), "1")]);
    let erg = ErgPayment::of(&peer).unwrap();
    assert_eq!(erg.mu_for(10_000_000).unwrap(), 10_000_000);
    let payment = erg.payment(TOKEN, 10_000_000).unwrap();
    assert_eq!(payment.deposit_token, TOKEN);
    assert_eq!(payment.amount.unwrap().n, "10000000");
    assert_eq!(
        payment.contract.unwrap().encode_to_vec(),
        erg_contract().encode_to_vec()
    );

    let three = ErgPayment::of(&peer_with(vec![rate(erg_contract(), "3")])).unwrap();
    assert_eq!(three.mu_for(7).unwrap(), 21);
    assert!(matches!(three.mu_for(0), Err(DepositError::BadAmount(_))));
    let huge = ErgPayment::of(&peer_with(vec![rate(
        erg_contract(),
        &(u128::MAX / 2).to_string(),
    )]))
    .unwrap();
    assert!(matches!(
        huge.mu_for(u64::MAX),
        Err(DepositError::BadAmount(_))
    ));
    assert!(matches!(
        erg.payment("has space", 1),
        Err(DepositError::BadToken(_))
    ));
}

#[test]
fn deposit_tokens_are_short_printable_ascii() {
    assert!(check_deposit_token(TOKEN).is_ok());
    assert!(check_deposit_token(&"a".repeat(64)).is_ok());
    for bad in ["", "two words", "tab\there", "ünïcode", &"a".repeat(65)] {
        assert!(
            matches!(check_deposit_token(bad), Err(DepositError::BadToken(_))),
            "{bad:?}"
        );
    }
}

#[test]
fn the_explorer_url_is_the_one_of_the_node() {
    assert_eq!(
        unspent_boxes_url(NODO_DEFAULT_EXPLORER, "9fRAWh"),
        "https://api.ergoplatform.com/api/v1/boxes/unspent/unconfirmed/byAddress/9fRAWh"
    );
    assert_eq!(
        unspent_boxes_url(" https://explorer.example/ ", "9f"),
        "https://explorer.example/api/v1/boxes/unspent/unconfirmed/byAddress/9f"
    );
}

/// An explorer box in the shape of `api.ergoplatform.com` (registers as on box
/// `6ceec77d…69bdd1` of mainnet).
fn explorer_box(id: &str, value: u64, r4: serde_json::Value) -> serde_json::Value {
    serde_json::json!({
        "boxId": id,
        "transactionId": "aa",
        "value": value,
        "index": 0,
        "assets": [],
        "additionalRegisters": { "R4": r4 },
    })
}

fn coll_byte(text: &str) -> serde_json::Value {
    let hex = hex::encode(text);
    serde_json::json!({
        "serializedValue": format!("0e{:02x}{hex}", text.len()),
        "sigmaType": "Coll[SByte]",
        "renderedValue": hex,
    })
}

#[test]
fn the_first_box_with_the_token_in_r4_is_the_deposit() {
    let other_int = serde_json::json!({
        "serializedValue": "0402", "sigmaType": "SInt", "renderedValue": "1"
    });
    let not_utf8 = serde_json::json!({
        "serializedValue": "0e02ff00", "sigmaType": "Coll[SByte]", "renderedValue": "ff00"
    });
    let boxes = serde_json::json!([
        { "boxId": "plain", "value": 5, "additionalRegisters": {} },
        explorer_box("int", 7, other_int),
        explorer_box("bytes", 7, not_utf8),
        explorer_box("name", 1_000_000, coll_byte("Celaut Node")),
        explorer_box("deposit", 10_000_000, coll_byte(TOKEN)),
        explorer_box("later", 99_000_000, coll_byte(TOKEN)),
    ]);
    assert_eq!(
        find_deposit_box(&boxes, TOKEN),
        Some(DepositBox {
            box_id: "deposit".into(),
            value: 10_000_000
        })
    );
    assert_eq!(find_deposit_box(&boxes, "1b4e28ba"), None);
    assert_eq!(
        find_deposit_box(&serde_json::json!({"items": []}), TOKEN),
        None
    );
    assert_eq!(find_deposit_box(&serde_json::json!([]), TOKEN), None);
}

/// A session with an ERG contract at rate 1; `more` are the answers after the opening.
async fn session(more: Vec<Vec<bee_rpc::buffer::Buffer>>) -> NodeSession<FixedStreams> {
    let mut peer = common::vectors().peers[0].peer();
    peer.payment_contracts = vec![rate(erg_contract(), "1")];
    let pair = Ed25519KeyPair::from_seed_unchecked(&[7; 32]).unwrap();
    peer.public_key = hex::encode(pair.public_key().as_ref());
    let digest = celaut_client::peer::content_digest(&peer);
    let payload = celaut_client::peer::signed_payload(&peer.public_key, peer.ts, &digest);
    peer.signature = hex::encode(pair.sign(payload.as_bytes()).as_ref());
    let peer_id = peer.public_key.clone();
    let mut answers = vec![
        stream_of(
            1,
            &Client {
                client_id: "c11e47000000400080000000000000aa".into(),
                ..Default::default()
            },
        ),
        stream_of(1, &peer),
    ];
    answers.extend(more);
    NodeSession::open(
        FixedStreams::new(answers),
        &peer_id,
        &MemoryPeerStore::new(),
    )
    .await
    .expect("open")
}

fn token_answer(token: &str) -> Vec<bee_rpc::buffer::Buffer> {
    stream_of(
        1,
        &TokenMessage {
            token: token.into(),
            slot: None,
            receipts: false,
        },
    )
}

#[tokio::test]
async fn the_deposit_token_comes_from_the_client() {
    let s = session(vec![token_answer(TOKEN)]).await;
    assert_eq!(s.erg_payment().unwrap().mu_per_nano_erg, 1);
    assert_eq!(s.deposit_token().await.unwrap(), TOKEN);
    let (method, parts) = s.transport().request(2);
    assert_eq!(method, "GenerateDepositToken");
    assert_eq!(parts.len(), 1);
    assert_eq!(parts[0].index, 1);
    let client = Client::decode(parts[0].data.as_slice()).unwrap();
    assert_eq!(client.client_id, s.client_id());
}

#[tokio::test]
async fn a_bad_deposit_token_is_refused() {
    // An empty TokenMessage has no bytes, so the stream carries nothing.
    let s = session(vec![Vec::new(), token_answer("not a token")]).await;
    assert!(matches!(
        s.deposit_token().await,
        Err(ClientError::Wire(WireError::Protocol(_)))
    ));
    assert!(matches!(
        s.deposit_token().await,
        Err(ClientError::Deposit(DepositError::BadToken(_)))
    ));
}

#[tokio::test]
async fn payable_sends_the_payment_and_the_client() {
    let s = session(vec![Vec::new()]).await;
    let payment = s.erg_payment().unwrap().payment(TOKEN, 10_000_000).unwrap();
    s.payable(&payment).await.unwrap();
    let (method, parts) = s.transport().request(2);
    assert_eq!(method, "Payable");
    assert_eq!(
        parts.iter().map(|p| p.index).collect::<Vec<_>>(),
        vec![1, 2]
    );
    let sent = Payment::decode(parts[0].data.as_slice()).unwrap();
    assert_eq!(sent, payment);
    // The contract goes back byte for byte.
    assert_eq!(
        sent.contract.unwrap().encode_to_vec(),
        erg_contract().encode_to_vec()
    );
    let client = Client::decode(parts[1].data.as_slice()).unwrap();
    assert_eq!(client.client_id, s.client_id());
}

#[tokio::test]
async fn a_refused_payment_is_an_error() {
    // No more fixed answers: the transport gives an error, as a non-OK status does.
    let s = session(vec![]).await;
    let payment = s.erg_payment().unwrap().payment(TOKEN, 1_000_000).unwrap();
    assert!(matches!(
        s.payable(&payment).await,
        Err(ClientError::Wire(WireError::Call(_)))
    ));
}

#[test]
fn the_binding_of_the_protocol_is_checked() {
    // nodo puts payment.deposit_token in the formal of the protocol.
    let mut bad = erg_contract();
    bad.protocol.as_mut().unwrap().formal = b"payment.deposit_token=R5 of that box".to_vec();
    assert!(matches!(
        ErgPayment::of(&peer_with(vec![rate(bad, "1")])).unwrap_err(),
        DepositError::UnknownBinding(_)
    ));
    let mut good = erg_contract();
    good.protocol.as_mut().unwrap().formal = format!("payment.deposit_token={R4_BINDING}").into_bytes();
    assert!(ErgPayment::of(&peer_with(vec![rate(good, "1")])).is_ok());
}
