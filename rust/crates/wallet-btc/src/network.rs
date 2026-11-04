//! The Bitcoin networks of the wallet.

use bdk_wallet::bitcoin::Network;

/// A Bitcoin network. The names are the ones of nodo's ledger declaration (`network=`
/// in `Contract.ledger.formal`) and of `ledgers.bitcoin.NETWORK`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BtcNetwork {
    Mainnet,
    Testnet,
    Signet,
    Regtest,
}

impl BtcNetwork {
    pub const ALL: [BtcNetwork; 4] = [
        BtcNetwork::Mainnet,
        BtcNetwork::Testnet,
        BtcNetwork::Signet,
        BtcNetwork::Regtest,
    ];

    /// The network of `name` (`mainnet`, `testnet`, `signet` or `regtest`, any case).
    pub fn from_name(name: &str) -> Option<Self> {
        match name.trim().to_ascii_lowercase().as_str() {
            "mainnet" | "bitcoin" => Some(BtcNetwork::Mainnet),
            "testnet" => Some(BtcNetwork::Testnet),
            "signet" => Some(BtcNetwork::Signet),
            "regtest" => Some(BtcNetwork::Regtest),
            _ => None,
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            BtcNetwork::Mainnet => "mainnet",
            BtcNetwork::Testnet => "testnet",
            BtcNetwork::Signet => "signet",
            BtcNetwork::Regtest => "regtest",
        }
    }

    pub fn bitcoin(self) -> Network {
        match self {
            BtcNetwork::Mainnet => Network::Bitcoin,
            BtcNetwork::Testnet => Network::Testnet,
            BtcNetwork::Signet => Network::Signet,
            BtcNetwork::Regtest => Network::Regtest,
        }
    }

    /// True only on mainnet: the coins have a value.
    pub fn is_mainnet(self) -> bool {
        self == BtcNetwork::Mainnet
    }

    /// The Esplora server that the app uses when the user gives none. Regtest has no public
    /// server: the user gives one.
    pub fn default_esplora(self) -> Option<&'static str> {
        match self {
            BtcNetwork::Mainnet => Some("https://mempool.space/api"),
            BtcNetwork::Testnet => Some("https://mempool.space/testnet/api"),
            BtcNetwork::Signet => Some("https://mempool.space/signet/api"),
            BtcNetwork::Regtest => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_round_trip() {
        for n in BtcNetwork::ALL {
            assert_eq!(BtcNetwork::from_name(n.name()), Some(n));
        }
        assert_eq!(BtcNetwork::from_name(" Signet "), Some(BtcNetwork::Signet));
        assert_eq!(BtcNetwork::from_name("testnet4"), None);
        assert_eq!(BtcNetwork::from_name(""), None);
    }

    #[test]
    fn only_mainnet_has_value() {
        assert!(BtcNetwork::Mainnet.is_mainnet());
        assert!(!BtcNetwork::Signet.is_mainnet());
        assert!(BtcNetwork::Regtest.default_esplora().is_none());
    }
}
