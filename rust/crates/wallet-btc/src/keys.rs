//! The keys of the Bitcoin wallet: BIP-84 from the BIP-39 seed of the Ergo wallet.
//!
//! One seed, two chains. The Ergo wallet uses EIP-3 (`m/44'/429'/0'/0/i`); this wallet uses
//! BIP-84 (`m/84'/0'/0'/{0,1}/i` on mainnet, `m/84'/1'/0'/{0,1}/i` on the test networks).
//! The paths do not overlap, so no key is used on both chains. The BIP-32 master key of a
//! seed is the same on both chains ("Bitcoin seed" HMAC), so any standard wallet (Sparrow,
//! Electrum, BlueWallet, nodo) opens the same Bitcoin funds from the same words.

use bdk_wallet::bitcoin::bip32::{ChainCode, ChildNumber, DerivationPath, Fingerprint, Xpriv, Xpub};
use bdk_wallet::bitcoin::secp256k1::{All, Secp256k1};
use bdk_wallet::bitcoin::NetworkKind;
use bdk_wallet::template::{Bip84Public, DescriptorTemplate};
use bdk_wallet::KeychainKind;

use crate::network::BtcNetwork;

/// The BIP-32 master key of the seed. It signs; it is never written anywhere. Its secret
/// bytes are erased when it is dropped.
pub struct MasterKey {
    xpriv: Xpriv,
}

impl Drop for MasterKey {
    fn drop(&mut self) {
        self.xpriv.private_key.non_secure_erase();
        self.xpriv.chain_code = ChainCode::from([0u8; 32]);
    }
}

impl std::fmt::Debug for MasterKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("MasterKey(..)")
    }
}

/// The coin type of BIP-44 for `network`: 0 on mainnet, 1 on every test network.
pub fn coin_type(network: BtcNetwork) -> u32 {
    if network.is_mainnet() {
        0
    } else {
        1
    }
}

/// `m/84'/coin'/0'`, the account of the wallet.
pub fn account_path(network: BtcNetwork) -> DerivationPath {
    DerivationPath::from(vec![
        ChildNumber::Hardened { index: 84 },
        ChildNumber::Hardened {
            index: coin_type(network),
        },
        ChildNumber::Hardened { index: 0 },
    ])
}

impl MasterKey {
    /// The master key of a 64-byte BIP-39 seed (the bytes that the Ergo wallet keeps).
    pub fn from_seed(seed: &[u8], network: BtcNetwork) -> Result<Self, String> {
        if seed.len() != 64 {
            return Err("the seed must be 64 bytes".into());
        }
        let kind = NetworkKind::from(network.bitcoin());
        let xpriv = Xpriv::new_master(kind, seed).map_err(|e| e.to_string())?;
        Ok(MasterKey { xpriv })
    }

    pub fn fingerprint(&self, secp: &Secp256k1<All>) -> Fingerprint {
        self.xpriv.fingerprint(secp)
    }

    /// The public key of the account (`m/84'/coin'/0'`).
    pub fn account_xpub(&self, secp: &Secp256k1<All>, network: BtcNetwork) -> Result<Xpub, String> {
        let account = self
            .xpriv
            .derive_priv(secp, &account_path(network))
            .map_err(|e| e.to_string())?;
        Ok(Xpub::from_priv(secp, &account))
    }

    /// The public descriptors of the receive (`/0/*`) and change (`/1/*`) keychains, with
    /// the key origin, so that a PSBT carries the full path of each input key.
    pub fn public_descriptors(&self, network: BtcNetwork) -> Result<(String, String), String> {
        let secp = Secp256k1::new();
        let xpub = self.account_xpub(&secp, network)?;
        let fingerprint = self.fingerprint(&secp);
        let kind = NetworkKind::from(network.bitcoin());
        let one = |keychain| {
            let (descriptor, _, _) = Bip84Public(xpub, fingerprint, keychain)
                .build(kind)
                .map_err(|e| e.to_string())?;
            Ok::<_, String>(descriptor.to_string())
        };
        Ok((one(KeychainKind::External)?, one(KeychainKind::Internal)?))
    }

    pub(crate) fn xpriv(&self) -> &Xpriv {
        &self.xpriv
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use bdk_wallet::Wallet;

    const ABANDON: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    fn seed() -> [u8; 64] {
        wallet_core::seed::MnemonicPhrase::parse(ABANDON)
            .unwrap()
            .to_seed("")
            .unwrap()
    }

    fn first_address(network: BtcNetwork) -> String {
        let key = MasterKey::from_seed(&seed(), network).unwrap();
        let (ext, int) = key.public_descriptors(network).unwrap();
        let wallet = Wallet::create(ext, int)
            .network(network.bitcoin())
            .create_wallet_no_persist()
            .unwrap();
        wallet.peek_address(KeychainKind::External, 0).address.to_string()
    }

    /// The test vector of BIP-84, from the seed that the Ergo wallet stores.
    #[test]
    fn bip84_vector_mainnet() {
        assert_eq!(
            first_address(BtcNetwork::Mainnet),
            "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
        );
    }

    #[test]
    fn test_networks_use_coin_type_1() {
        let signet = first_address(BtcNetwork::Signet);
        let testnet = first_address(BtcNetwork::Testnet);
        let regtest = first_address(BtcNetwork::Regtest);
        assert!(signet.starts_with("tb1q"), "{signet}");
        assert_eq!(signet, testnet);
        assert!(regtest.starts_with("bcrt1q"), "{regtest}");
        // Coin type 1, so not the mainnet key.
        let key = MasterKey::from_seed(&seed(), BtcNetwork::Signet).unwrap();
        let (ext, _) = key.public_descriptors(BtcNetwork::Signet).unwrap();
        assert!(ext.contains("/84'/1'/0']"), "{ext}");
    }

    #[test]
    fn descriptors_are_public() {
        let key = MasterKey::from_seed(&seed(), BtcNetwork::Mainnet).unwrap();
        let (ext, int) = key.public_descriptors(BtcNetwork::Mainnet).unwrap();
        assert!(ext.starts_with("wpkh([73c5da0a/84'/0'/0']xpub"), "{ext}");
        assert!(ext.contains("/0/*"), "{ext}");
        assert!(int.contains("/1/*"), "{int}");
        assert!(!ext.contains("prv") && !int.contains("prv"));
    }

    #[test]
    fn rejects_short_seed() {
        assert!(MasterKey::from_seed(&[0u8; 32], BtcNetwork::Mainnet).is_err());
    }
}
