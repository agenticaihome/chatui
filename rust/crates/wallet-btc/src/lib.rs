//! The Bitcoin wallet of Chatui (issue #92).
//!
//! - [`keys`]: the keys come from the same BIP-39 seed as the Ergo wallet, on the BIP-84
//!   path (`m/84'/0'/0'` on mainnet, `m/84'/1'/0'` on the test networks). Any standard
//!   Bitcoin wallet opens the same funds from the same words. nodo uses the same paths.
//! - [`network`]: mainnet, testnet, signet and regtest, with the names that nodo writes in
//!   its ledger declaration.
//! - [`esplora`]: the few calls of the Esplora HTTP API that the wallet needs, made with
//!   `wallet_net::http`, so a request follows the network route of the app (Tor).
//! - [`scan`]: a full scan of the wallet's scripts on an Esplora server, as `bdk_esplora`
//!   does it.
//! - [`wallet`]: the wallet itself: addresses, balance, history, fee rates, send, and a
//!   higher fee for a payment that waits (RBF). A watch-only wallet reads while locked.
//! - [`uri`]: payment requests (`bitcoin:` URIs, BIP-21).
//!
//! The wallet keeps only public descriptors. The private key is held apart, in
//! [`keys::MasterKey`], and is used only to sign.

pub mod esplora;
pub mod keys;
pub mod network;
pub mod scan;
pub mod uri;
pub mod wallet;

pub use bdk_wallet::bitcoin;
pub use network::BtcNetwork;
pub use wallet::{AddressView, BtcWallet, PreparedSend, TxDetail, TxPart, TxView, UtxoView, WalletError};
