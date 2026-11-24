//! The Ergo wallet against the real Python code of nodo (`Mnemonic.to_seed`,
//! `bip_wallet_verification.derive_compressed_pubkey` at `m/44'/429'/0'/0/0`,
//! `ergo_tree.p2pk_proposition_bytes_from_pk`; vectors made by
//! `celaut-client/tests/vectors/generate_payment.py`). The address 0 of the wallet is the key
//! of the node on Ergo, and its ErgoTree is the `script` that the node advertises.

use ergo_lib::ergotree_ir::chain::address::{Address, AddressEncoder, NetworkPrefix};
use ergo_lib::ergotree_ir::serialization::SigmaSerializable;
use serde_json::Value;
use wallet_core::derivation::derive_address_from_seed;
use wallet_core::seed::MnemonicPhrase;

fn vectors() -> Value {
    serde_json::from_str(include_str!("../../celaut-client/tests/vectors/payment_vectors.json"))
        .unwrap()
}

#[test]
fn the_seed_and_the_address_zero_are_the_ones_of_nodo() {
    let v = vectors();
    for w in v["wallets"].as_array().unwrap() {
        let phrase = MnemonicPhrase::parse(w["mnemonic"].as_str().unwrap()).unwrap();
        let seed = phrase.to_seed("").unwrap();
        assert_eq!(hex::encode(seed), w["seed_hex"].as_str().unwrap());
        let address = derive_address_from_seed(seed, 0).unwrap();
        assert_eq!(address, w["ergo"]["address_mainnet"].as_str().unwrap());
        // The address is a P2PK of the key of nodo, and its ErgoTree is `0008cd` + the key.
        let parsed = AddressEncoder::new(NetworkPrefix::Mainnet).parse_address_from_str(&address).unwrap();
        let Address::P2Pk(_) = &parsed else { panic!("not a P2PK address") };
        let tree = parsed.script().unwrap().sigma_serialize_bytes().unwrap();
        assert_eq!(hex::encode(tree), w["ergo"]["ergo_tree"].as_str().unwrap());
    }
}
