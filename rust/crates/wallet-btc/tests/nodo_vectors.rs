//! The Bitcoin wallet against the real Python code of nodo (`signer.derive_wallet_key`,
//! `signer.op_return_script`; vectors made by
//! `celaut-client/tests/vectors/generate_payment.py`). The same words must open the same
//! funds: the receive address of the wallet is the one key at `m/84'/coin'/0'/0/0` that nodo
//! spends from and advertises as its payment script.

use bdk_wallet::bitcoin::script::PushBytesBuf;
use bdk_wallet::bitcoin::ScriptBuf;
use serde_json::Value;
use wallet_btc::{BtcNetwork, BtcWallet};

fn vectors() -> Value {
    serde_json::from_str(include_str!("../../celaut-client/tests/vectors/payment_vectors.json"))
        .unwrap()
}

#[test]
fn the_first_address_is_the_one_key_of_nodo() {
    let v = vectors();
    for w in v["wallets"].as_array().unwrap() {
        let seed = hex::decode(w["seed_hex"].as_str().unwrap()).unwrap();
        for network in BtcNetwork::ALL {
            let expected = &w["bitcoin"][network.name()];
            let mut wallet = BtcWallet::new(&seed, network).unwrap();
            let address = wallet.receive_address();
            assert_eq!(address, expected["address"].as_str().unwrap(), "{}", network.name());
            // The scriptPubKey that nodo advertises is the one of this address.
            let script = wallet.parse_address(&address).unwrap().script_pubkey();
            assert_eq!(hex::encode(script.as_bytes()), expected["script_pubkey"].as_str().unwrap());
        }
    }
}

#[test]
fn the_op_return_of_the_deposit_token_is_the_one_of_nodo() {
    let v = vectors();
    for o in v["op_returns"].as_array().unwrap() {
        let data = hex::decode(o["data_hex"].as_str().unwrap()).unwrap();
        let push = PushBytesBuf::try_from(data).unwrap();
        let script = ScriptBuf::new_op_return(&push);
        assert_eq!(hex::encode(script.as_bytes()), o["script"].as_str().unwrap());
    }
}
