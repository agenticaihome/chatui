//! The Bitcoin wallet: addresses, balance, history, fee rates and send.
//!
//! The `bdk_wallet::Wallet` inside has only the public descriptors. [`BtcWallet::sign`]
//! signs a prepared transaction with the master key, with `bitcoin::Psbt::sign`, and then
//! lets the wallet finalize it.

use std::str::FromStr;

use bdk_wallet::bitcoin::script::PushBytesBuf;
use bdk_wallet::bitcoin::secp256k1::{All, Secp256k1};
use bdk_wallet::bitcoin::{Address, Amount, FeeRate, Psbt, Transaction, Txid};
use bdk_wallet::chain::spk_client::{FullScanRequest, FullScanResponse};
use bdk_wallet::chain::ChainPosition;
use bdk_wallet::{KeychainKind, SignOptions, Wallet};

use crate::keys::MasterKey;
use crate::network::BtcNetwork;

/// The lowest fee rate that nodes relay, in sat/vB.
pub const MIN_FEE_RATE: f64 = 1.0;

/// A fee rate above this (sat/vB) is refused as a typing mistake.
pub const MAX_FEE_RATE: f64 = 1000.0;

/// The most bytes of an `OP_RETURN` output that nodes relay (and that nodo reads).
pub const MAX_DATA_BYTES: usize = 80;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum WalletError {
    #[error("the Bitcoin wallet could not be made: {0}")]
    Keys(String),
    #[error("this is not a Bitcoin address of {network}: {reason}")]
    Address { network: &'static str, reason: String },
    #[error("the amount is not usable: {0}")]
    Amount(String),
    #[error("the fee rate is not usable: {0}")]
    FeeRate(String),
    #[error("the wallet does not have enough confirmed bitcoin: {0}")]
    Funds(String),
    #[error("the transaction could not be made: {0}")]
    Build(String),
    #[error("the transaction could not be signed: {0}")]
    Sign(String),
    #[error("the chain of the server does not connect to the wallet's chain: {0}")]
    Chain(String),
}

/// The balance, in satoshi.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct BalanceView {
    /// Confirmed and spendable.
    pub confirmed: u64,
    /// Not confirmed yet (from this wallet or from others).
    pub pending: u64,
    /// Mined coins that are not 100 blocks deep yet.
    pub immature: u64,
}

impl BalanceView {
    pub fn total(&self) -> u64 {
        self.confirmed + self.pending + self.immature
    }
}

/// A transaction of the wallet, for the history.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TxView {
    pub txid: String,
    /// What the transaction moved for the wallet: received minus sent, in satoshi.
    pub net_sat: i64,
    /// The fee, when the wallet knows every input.
    pub fee_sat: Option<u64>,
    /// The height of the block, or `None` while it is not confirmed.
    pub height: Option<u32>,
    /// The time of the block, or when the wallet saw it first (Unix seconds).
    pub time: Option<u64>,
    /// The confirmations at the wallet's tip (0 while it is not confirmed).
    pub confirmations: u32,
}

/// A transaction that is made but not signed.
#[derive(Debug, Clone)]
pub struct PreparedSend {
    psbt: Psbt,
    pub to: String,
    /// What goes to `to`, in satoshi.
    pub amount_sat: u64,
    pub fee_sat: u64,
    pub fee_rate_sat_vb: f64,
    /// The change back to the wallet, in satoshi (0 if none).
    pub change_sat: u64,
    /// The data of the `OP_RETURN` output, if any.
    pub data: Option<Vec<u8>>,
    /// The id that the transaction will have (a segwit id does not change with the
    /// signatures).
    pub txid: Txid,
}

pub struct BtcWallet {
    network: BtcNetwork,
    wallet: Wallet,
    key: MasterKey,
    secp: Secp256k1<All>,
}

impl std::fmt::Debug for BtcWallet {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "BtcWallet({})", self.network.name())
    }
}

/// `sat/vB` as a [`FeeRate`] (sat per 1000 weight units, rounded up).
fn fee_rate(sat_vb: f64) -> Result<FeeRate, WalletError> {
    if !sat_vb.is_finite() || sat_vb < MIN_FEE_RATE {
        return Err(WalletError::FeeRate(format!(
            "{sat_vb} sat/vB is less than {MIN_FEE_RATE} sat/vB"
        )));
    }
    if sat_vb > MAX_FEE_RATE {
        return Err(WalletError::FeeRate(format!(
            "{sat_vb} sat/vB is more than {MAX_FEE_RATE} sat/vB"
        )));
    }
    Ok(FeeRate::from_sat_per_kwu((sat_vb * 250.0).ceil() as u64))
}

impl BtcWallet {
    /// The wallet of a 64-byte BIP-39 seed on `network`. It knows no transaction until
    /// [`BtcWallet::apply_scan`].
    pub fn new(seed: &[u8], network: BtcNetwork) -> Result<Self, WalletError> {
        let key = MasterKey::from_seed(seed, network).map_err(WalletError::Keys)?;
        let (external, internal) = key.public_descriptors(network).map_err(WalletError::Keys)?;
        let wallet = Wallet::create(external, internal)
            .network(network.bitcoin())
            .create_wallet_no_persist()
            .map_err(|e| WalletError::Keys(e.to_string()))?;
        Ok(BtcWallet {
            network,
            wallet,
            key,
            secp: Secp256k1::new(),
        })
    }

    pub fn network(&self) -> BtcNetwork {
        self.network
    }

    /// What a scan must read ([`crate::scan::full_scan`]).
    pub fn scan_request(&self) -> FullScanRequest<KeychainKind> {
        self.wallet.start_full_scan().build()
    }

    /// Take the result of a scan.
    pub fn apply_scan(&mut self, response: FullScanResponse<KeychainKind>) -> Result<(), WalletError> {
        self.wallet
            .apply_update(response)
            .map_err(|e| WalletError::Chain(e.to_string()))
    }

    /// The height of the wallet's last block (0 before the first scan).
    pub fn tip_height(&self) -> u32 {
        self.wallet.latest_checkpoint().height()
    }

    /// The first receive address that has no transaction.
    pub fn receive_address(&mut self) -> String {
        self.wallet
            .next_unused_address(KeychainKind::External)
            .address
            .to_string()
    }

    pub fn balance(&self) -> BalanceView {
        let b = self.wallet.balance();
        BalanceView {
            confirmed: b.confirmed.to_sat(),
            pending: (b.trusted_pending + b.untrusted_pending).to_sat(),
            immature: b.immature.to_sat(),
        }
    }

    /// The history, the newest first (unconfirmed transactions on top).
    pub fn transactions(&self) -> Vec<TxView> {
        let tip = self.tip_height();
        let mut all: Vec<TxView> = self
            .wallet
            .transactions()
            .map(|t| {
                let tx = &t.tx_node.tx;
                let (sent, received) = self.wallet.sent_and_received(tx);
                let (height, time) = match &t.chain_position {
                    ChainPosition::Confirmed { anchor, .. } => {
                        (Some(anchor.block_id.height), Some(anchor.confirmation_time))
                    }
                    ChainPosition::Unconfirmed { first_seen, .. } => (None, *first_seen),
                };
                TxView {
                    txid: t.tx_node.txid.to_string(),
                    net_sat: received.to_sat() as i64 - sent.to_sat() as i64,
                    fee_sat: self.wallet.calculate_fee(tx).ok().map(Amount::to_sat),
                    height,
                    time,
                    confirmations: height.map_or(0, |h| tip.saturating_sub(h) + 1),
                }
            })
            .collect();
        all.sort_by(|a, b| {
            let key = |t: &TxView| (t.height.unwrap_or(u32::MAX), t.time.unwrap_or(0));
            key(b).cmp(&key(a))
        });
        all
    }

    /// `text` as an address of the wallet's network.
    pub fn parse_address(&self, text: &str) -> Result<Address, WalletError> {
        parse_address(text, self.network)
    }

    /// Make (not sign) a transaction that pays `amount_sat` to `to`, at `fee_rate_sat_vb`,
    /// with `data` in an `OP_RETURN` output when it is given. With `send_all`, the amount
    /// is everything that the wallet can spend, less the fee.
    pub fn prepare_send(
        &mut self,
        to: &str,
        amount_sat: u64,
        send_all: bool,
        fee_rate_sat_vb: f64,
        data: Option<&[u8]>,
    ) -> Result<PreparedSend, WalletError> {
        let address = self.parse_address(to)?;
        let rate = fee_rate(fee_rate_sat_vb)?;
        if !send_all && amount_sat == 0 {
            return Err(WalletError::Amount("0 sat".into()));
        }
        let script = address.script_pubkey();
        let mut builder = self.wallet.build_tx();
        builder.fee_rate(rate);
        if send_all {
            builder.drain_wallet().drain_to(script.clone());
        } else {
            builder.add_recipient(script.clone(), Amount::from_sat(amount_sat));
        }
        if let Some(bytes) = data {
            if bytes.is_empty() || bytes.len() > MAX_DATA_BYTES {
                return Err(WalletError::Build(format!(
                    "the OP_RETURN data has {} bytes, not 1 to {MAX_DATA_BYTES}",
                    bytes.len()
                )));
            }
            let push = PushBytesBuf::try_from(bytes.to_vec())
                .map_err(|e| WalletError::Build(e.to_string()))?;
            builder.add_data(&push);
        }
        let psbt = builder.finish().map_err(|e| {
            let text = e.to_string();
            if text.contains("Insufficient funds") || text.contains("insufficient") {
                WalletError::Funds(text)
            } else if text.contains("dust") {
                WalletError::Amount(text)
            } else {
                WalletError::Build(text)
            }
        })?;
        let fee_sat = psbt
            .fee()
            .map_err(|e| WalletError::Build(e.to_string()))?
            .to_sat();
        let tx = &psbt.unsigned_tx;
        let paid: u64 = tx
            .output
            .iter()
            .filter(|o| o.script_pubkey == script)
            .map(|o| o.value.to_sat())
            .sum();
        let change: u64 = tx
            .output
            .iter()
            .filter(|o| o.script_pubkey != script && self.wallet.is_mine(o.script_pubkey.clone()))
            .map(|o| o.value.to_sat())
            .sum();
        Ok(PreparedSend {
            txid: tx.compute_txid(),
            to: address.to_string(),
            amount_sat: paid,
            fee_sat,
            fee_rate_sat_vb,
            change_sat: change,
            data: data.map(<[u8]>::to_vec),
            psbt,
        })
    }

    /// Sign `prepared` and check it: every input signed and finalized, the same id.
    pub fn sign(&self, prepared: &PreparedSend) -> Result<Transaction, WalletError> {
        let mut psbt = prepared.psbt.clone();
        psbt.sign(self.key.xpriv(), &self.secp)
            .map_err(|(_, errors)| WalletError::Sign(format!("{errors:?}")))?;
        let finalized = self
            .wallet
            .finalize_psbt(&mut psbt, SignOptions::default())
            .map_err(|e| WalletError::Sign(e.to_string()))?;
        if !finalized {
            return Err(WalletError::Sign("an input is not signed".into()));
        }
        let tx = psbt
            .extract_tx()
            .map_err(|e| WalletError::Sign(e.to_string()))?;
        if tx.compute_txid() != prepared.txid {
            return Err(WalletError::Sign("the signed transaction has another id".into()));
        }
        Ok(tx)
    }

    /// Keep a transaction that was sent, so that the balance and the history show it
    /// before the next scan.
    pub fn record_sent(&mut self, tx: Transaction, seen_at: u64) {
        self.wallet.apply_unconfirmed_txs([(tx, seen_at)]);
    }
}

/// `text` as an address of `network`.
pub fn parse_address(text: &str, network: BtcNetwork) -> Result<Address, WalletError> {
    let wrong = |reason: String| WalletError::Address {
        network: network.name(),
        reason,
    };
    Address::from_str(text.trim())
        .map_err(|e| wrong(e.to_string()))?
        .require_network(network.bitcoin())
        .map_err(|e| wrong(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    const ABANDON: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    fn wallet(network: BtcNetwork) -> BtcWallet {
        let seed = wallet_core::seed::MnemonicPhrase::parse(ABANDON)
            .unwrap()
            .to_seed("")
            .unwrap();
        BtcWallet::new(&seed, network).unwrap()
    }

    #[test]
    fn empty_wallet() {
        let mut w = wallet(BtcNetwork::Signet);
        assert_eq!(w.balance(), BalanceView::default());
        assert!(w.transactions().is_empty());
        let first = w.receive_address();
        // No transaction yet, so the same address again.
        assert_eq!(w.receive_address(), first);
        assert!(first.starts_with("tb1q"));
    }

    #[test]
    fn addresses_of_another_network_are_refused() {
        let mut signet = wallet(BtcNetwork::Signet);
        let mut regtest = wallet(BtcNetwork::Regtest);
        let mut mainnet = wallet(BtcNetwork::Mainnet);
        let (s, r, m) = (signet.receive_address(), regtest.receive_address(), mainnet.receive_address());
        assert!(signet.parse_address(&format!(" {s} ")).is_ok());
        assert!(signet.parse_address(&m).is_err());
        assert!(signet.parse_address(&r).is_err());
        assert!(regtest.parse_address(&r).is_ok());
        assert!(regtest.parse_address(&s).is_err());
        assert!(mainnet.parse_address(&s).is_err());
        assert!(signet.parse_address("not an address").is_err());
    }

    #[test]
    fn fee_rate_limits() {
        assert!(fee_rate(0.5).is_err());
        assert!(fee_rate(f64::NAN).is_err());
        assert!(fee_rate(1001.0).is_err());
        assert_eq!(fee_rate(1.0).unwrap(), FeeRate::from_sat_per_vb_u32(1));
        assert_eq!(fee_rate(2.5).unwrap().to_sat_per_kwu(), 625);
    }

    #[test]
    fn no_funds_no_transaction() {
        let mut w = wallet(BtcNetwork::Signet);
        let to = w.receive_address();
        let err = w.prepare_send(&to, 10_000, false, 2.0, None).unwrap_err();
        assert!(matches!(err, WalletError::Funds(_)), "{err:?}");
        assert!(matches!(
            w.prepare_send(&to, 0, false, 2.0, None),
            Err(WalletError::Amount(_))
        ));
        assert!(matches!(
            w.prepare_send(&to, 1000, false, 2.0, Some(&[0u8; 81])),
            Err(WalletError::Build(_))
        ));
    }
}
