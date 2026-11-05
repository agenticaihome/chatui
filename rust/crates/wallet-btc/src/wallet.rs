//! The Bitcoin wallet: addresses, balance, history, fee rates and send.
//!
//! The `bdk_wallet::Wallet` inside has only the public descriptors. [`BtcWallet::sign`]
//! signs a prepared transaction with the master key, with `bitcoin::Psbt::sign`, and then
//! lets the wallet finalize it.
//!
//! A watch-only wallet ([`BtcWallet::watch`]) has the public descriptors and no key: it
//! reads the balance and the history while the wallet is locked, and it cannot sign.

use std::str::FromStr;

use bdk_wallet::bitcoin::script::PushBytesBuf;
use bdk_wallet::bitcoin::secp256k1::{All, Secp256k1};
use bdk_wallet::bitcoin::{Address, Amount, FeeRate, Psbt, ScriptBuf, Transaction, Txid};
use bdk_wallet::chain::spk_client::{FullScanRequest, FullScanResponse};
use bdk_wallet::chain::ChainPosition;
use bdk_wallet::error::CreateTxError;
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
    #[error("this wallet only watches: unlock the wallet to sign")]
    WatchOnly,
    #[error("the fee of this transaction cannot be raised: {0}")]
    Bump(String),
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
    /// The transaction that this one replaces with a higher fee (RBF), if any.
    pub replaces: Option<Txid>,
}

/// An address of the wallet that the wallet showed or used.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AddressView {
    pub address: String,
    /// The index on its keychain.
    pub index: u32,
    /// True for a change address (`/1/*`), false for a receive address (`/0/*`).
    pub change: bool,
    /// A transaction paid to it.
    pub used: bool,
    /// What it holds now, in satoshi.
    pub sat: u64,
    /// The unspent outputs on it.
    pub utxos: u32,
}

/// An unspent output of the wallet.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UtxoView {
    pub txid: String,
    pub vout: u32,
    pub sat: u64,
    pub address: String,
    pub change: bool,
    /// 0 while it is not confirmed.
    pub confirmations: u32,
}

/// One input or output of a transaction.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TxPart {
    /// `None` for an `OP_RETURN` output, or for a script that is not an address.
    pub address: Option<String>,
    /// `None` when the wallet does not know the value (an input of another wallet).
    pub sat: Option<u64>,
    /// The address is one of this wallet.
    pub mine: bool,
    /// An `OP_RETURN` output (data, no value to anybody).
    pub data: bool,
}

/// A transaction of the wallet with its inputs and outputs.
#[derive(Debug, Clone, PartialEq)]
pub struct TxDetail {
    pub tx: TxView,
    pub inputs: Vec<TxPart>,
    pub outputs: Vec<TxPart>,
    /// The size in virtual bytes.
    pub vsize: u64,
    /// sat/vB, when the fee is known.
    pub fee_rate: Option<f64>,
    /// The wallet can send this again with a higher fee (RBF): not confirmed, paid by
    /// this wallet only, signals replacement, and has no `OP_RETURN` data (a deposit to a
    /// node is known by its transaction id, so it keeps it).
    pub can_bump: bool,
}

pub struct BtcWallet {
    network: BtcNetwork,
    wallet: Wallet,
    /// `None` for a watch-only wallet.
    key: Option<MasterKey>,
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
            key: Some(key),
            secp: Secp256k1::new(),
        })
    }

    /// A watch-only wallet of the public descriptors that [`BtcWallet::public_descriptors`]
    /// gave. A descriptor with a private key is refused.
    pub fn watch(external: &str, internal: &str, network: BtcNetwork) -> Result<Self, WalletError> {
        for d in [external, internal] {
            if d.contains("prv") {
                return Err(WalletError::Keys("a watch-only wallet takes public descriptors only".into()));
            }
        }
        let wallet = Wallet::create(external.to_string(), internal.to_string())
            .network(network.bitcoin())
            .create_wallet_no_persist()
            .map_err(|e| WalletError::Keys(e.to_string()))?;
        Ok(BtcWallet {
            network,
            wallet,
            key: None,
            secp: Secp256k1::new(),
        })
    }

    pub fn network(&self) -> BtcNetwork {
        self.network
    }

    /// False for a watch-only wallet.
    pub fn can_sign(&self) -> bool {
        self.key.is_some()
    }

    /// The public descriptors (receive, change), with their checksums. They give every
    /// address of the wallet and no key.
    pub fn public_descriptors(&self) -> (String, String) {
        (
            self.wallet.public_descriptor(KeychainKind::External).to_string(),
            self.wallet.public_descriptor(KeychainKind::Internal).to_string(),
        )
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
        let mut all: Vec<TxView> = self
            .wallet
            .transactions()
            .map(|t| self.tx_view(&t.tx_node.tx, t.tx_node.txid, &t.chain_position))
            .collect();
        all.sort_by(|a, b| {
            let key = |t: &TxView| (t.height.unwrap_or(u32::MAX), t.time.unwrap_or(0));
            key(b).cmp(&key(a))
        });
        all
    }

    fn tx_view(
        &self,
        tx: &Transaction,
        txid: Txid,
        position: &ChainPosition<bdk_wallet::chain::ConfirmationBlockTime>,
    ) -> TxView {
        let (sent, received) = self.wallet.sent_and_received(tx);
        let (height, time) = match position {
            ChainPosition::Confirmed { anchor, .. } => {
                (Some(anchor.block_id.height), Some(anchor.confirmation_time))
            }
            ChainPosition::Unconfirmed { first_seen, .. } => (None, *first_seen),
        };
        TxView {
            txid: txid.to_string(),
            net_sat: received.to_sat() as i64 - sent.to_sat() as i64,
            fee_sat: self.wallet.calculate_fee(tx).ok().map(Amount::to_sat),
            height,
            time,
            confirmations: height.map_or(0, |h| self.tip_height().saturating_sub(h) + 1),
        }
    }

    fn address_of(&self, script: &ScriptBuf) -> Option<String> {
        Address::from_script(script, self.network.bitcoin())
            .ok()
            .map(|a| a.to_string())
    }

    fn confirmations(&self, position: &ChainPosition<bdk_wallet::chain::ConfirmationBlockTime>) -> u32 {
        match position {
            ChainPosition::Confirmed { anchor, .. } => {
                self.tip_height().saturating_sub(anchor.block_id.height) + 1
            }
            ChainPosition::Unconfirmed { .. } => 0,
        }
    }

    /// The addresses that the wallet showed or used, receive addresses first, each
    /// keychain by index.
    pub fn addresses(&self) -> Vec<AddressView> {
        let mut held = std::collections::HashMap::<(bool, u32), (u64, u32)>::new();
        for u in self.wallet.list_unspent() {
            let entry = held
                .entry((u.keychain == KeychainKind::Internal, u.derivation_index))
                .or_default();
            entry.0 += u.txout.value.to_sat();
            entry.1 += 1;
        }
        let index = self.wallet.spk_index();
        let mut all = Vec::new();
        for keychain in [KeychainKind::External, KeychainKind::Internal] {
            let change = keychain == KeychainKind::Internal;
            for (i, script) in index.revealed_keychain_spks(keychain) {
                let Some(address) = self.address_of(&script) else { continue };
                let (sat, utxos) = held.get(&(change, i)).copied().unwrap_or_default();
                all.push(AddressView {
                    address,
                    index: i,
                    change,
                    used: index.is_used(keychain, i),
                    sat,
                    utxos,
                });
            }
        }
        all
    }

    /// The unspent outputs, the largest first.
    pub fn utxos(&self) -> Vec<UtxoView> {
        let mut all: Vec<UtxoView> = self
            .wallet
            .list_unspent()
            .map(|u| UtxoView {
                txid: u.outpoint.txid.to_string(),
                vout: u.outpoint.vout,
                sat: u.txout.value.to_sat(),
                address: self.address_of(&u.txout.script_pubkey).unwrap_or_default(),
                change: u.keychain == KeychainKind::Internal,
                confirmations: self.confirmations(&u.chain_position),
            })
            .collect();
        all.sort_by(|a, b| b.sat.cmp(&a.sat).then_with(|| a.txid.cmp(&b.txid)));
        all
    }

    /// A transaction of the wallet with its inputs and outputs. `None` if the wallet does
    /// not know it.
    pub fn tx_detail(&self, txid: &str) -> Option<TxDetail> {
        let txid = Txid::from_str(txid.trim()).ok()?;
        let t = self.wallet.get_tx(txid)?;
        let tx = t.tx_node.tx.as_ref();
        let view = self.tx_view(tx, txid, &t.chain_position);
        let graph = self.wallet.tx_graph();
        let inputs: Vec<TxPart> = tx
            .input
            .iter()
            .map(|i| {
                let prev = graph.get_txout(i.previous_output);
                TxPart {
                    address: prev.and_then(|o| self.address_of(&o.script_pubkey)),
                    sat: prev.map(|o| o.value.to_sat()),
                    mine: prev.is_some_and(|o| self.wallet.is_mine(o.script_pubkey.clone())),
                    data: false,
                }
            })
            .collect();
        let outputs: Vec<TxPart> = tx
            .output
            .iter()
            .map(|o| TxPart {
                address: self.address_of(&o.script_pubkey),
                sat: Some(o.value.to_sat()),
                mine: self.wallet.is_mine(o.script_pubkey.clone()),
                data: o.script_pubkey.is_op_return(),
            })
            .collect();
        let vsize = tx.vsize() as u64;
        let fee_rate = view.fee_sat.map(|f| f as f64 / vsize.max(1) as f64);
        let can_bump = view.height.is_none()
            && inputs.iter().all(|i| i.mine)
            && !outputs.iter().any(|o| o.data)
            && tx.is_explicitly_rbf();
        Some(TxDetail {
            tx: view,
            inputs,
            outputs,
            vsize,
            fee_rate,
            can_bump,
        })
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
        let psbt = builder.finish().map_err(create_error)?;
        self.prepared(psbt, &script, address.to_string(), fee_rate_sat_vb, data.map(<[u8]>::to_vec), None)
    }

    fn prepared(
        &self,
        psbt: Psbt,
        to: &ScriptBuf,
        to_text: String,
        fee_rate_sat_vb: f64,
        data: Option<Vec<u8>>,
        replaces: Option<Txid>,
    ) -> Result<PreparedSend, WalletError> {
        let fee_sat = psbt
            .fee()
            .map_err(|e| WalletError::Build(e.to_string()))?
            .to_sat();
        let tx = &psbt.unsigned_tx;
        let paid: u64 = tx
            .output
            .iter()
            .filter(|o| &o.script_pubkey == to)
            .map(|o| o.value.to_sat())
            .sum();
        let change: u64 = tx
            .output
            .iter()
            .filter(|o| &o.script_pubkey != to && self.wallet.is_mine(o.script_pubkey.clone()))
            .map(|o| o.value.to_sat())
            .sum();
        Ok(PreparedSend {
            txid: tx.compute_txid(),
            to: to_text,
            amount_sat: paid,
            fee_sat,
            fee_rate_sat_vb,
            change_sat: change,
            data,
            replaces,
            psbt,
        })
    }

    /// Make (not sign) a transaction that replaces the unconfirmed transaction `txid` with
    /// the same payment at the higher fee rate `fee_rate_sat_vb` (RBF, BIP-125). The fee
    /// comes out of the change.
    pub fn prepare_bump(&mut self, txid: &str, fee_rate_sat_vb: f64) -> Result<PreparedSend, WalletError> {
        let detail = self
            .tx_detail(txid)
            .ok_or_else(|| WalletError::Bump("the wallet does not know this transaction".into()))?;
        if !detail.can_bump {
            return Err(WalletError::Bump(
                "only an unconfirmed payment of this wallet, without OP_RETURN data, can be sent again".into(),
            ));
        }
        let rate = fee_rate(fee_rate_sat_vb)?;
        let id = Txid::from_str(txid.trim()).map_err(|e| WalletError::Bump(e.to_string()))?;
        // The payment: the first output that is not of this wallet, else the first output.
        let original = self.wallet.get_tx(id).map(|t| t.tx_node.tx.clone());
        let to = original
            .as_ref()
            .and_then(|tx| {
                tx.output
                    .iter()
                    .find(|o| !self.wallet.is_mine(o.script_pubkey.clone()))
                    .or_else(|| tx.output.first())
                    .map(|o| o.script_pubkey.clone())
            })
            .ok_or_else(|| WalletError::Bump("the transaction has no output".into()))?;
        let mut builder = self
            .wallet
            .build_fee_bump(id)
            .map_err(|e| WalletError::Bump(e.to_string()))?;
        builder.fee_rate(rate);
        let psbt = builder.finish().map_err(create_error)?;
        let to_text = self.address_of(&to).unwrap_or_default();
        self.prepared(psbt, &to, to_text, fee_rate_sat_vb, None, Some(id))
    }

    /// Sign `prepared` and check it: every input signed and finalized, the same id.
    pub fn sign(&self, prepared: &PreparedSend) -> Result<Transaction, WalletError> {
        let key = self.key.as_ref().ok_or(WalletError::WatchOnly)?;
        let mut psbt = prepared.psbt.clone();
        psbt.sign(key.xpriv(), &self.secp)
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

fn create_error(e: CreateTxError) -> WalletError {
    match e {
        CreateTxError::FeeRateTooLow { .. } | CreateTxError::FeeTooLow { .. } => {
            WalletError::FeeRate(e.to_string())
        }
        _ => {
            let text = e.to_string();
            if text.contains("Insufficient funds") || text.contains("insufficient") {
                WalletError::Funds(text)
            } else if text.contains("dust") {
                WalletError::Amount(text)
            } else {
                WalletError::Build(text)
            }
        }
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

    /// A signet wallet with one unconfirmed output of `sat` from another wallet.
    fn funded(sat: u64) -> BtcWallet {
        use bdk_wallet::bitcoin::{absolute, transaction, OutPoint, Sequence, TxIn, TxOut, Witness};
        let mut w = wallet(BtcNetwork::Signet);
        let first = w.receive_address();
        let to = w.parse_address(&first).unwrap();
        let funding = Transaction {
            version: transaction::Version::TWO,
            lock_time: absolute::LockTime::ZERO,
            input: vec![TxIn {
                previous_output: OutPoint::new(Txid::from_str(&"11".repeat(32)).unwrap(), 0),
                script_sig: ScriptBuf::new(),
                sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
                witness: Witness::new(),
            }],
            output: vec![TxOut {
                value: Amount::from_sat(sat),
                script_pubkey: to.script_pubkey(),
            }],
        };
        w.record_sent(funding, 100);
        w
    }

    const OTHER: &str = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";

    #[test]
    fn watch_only_reads_and_does_not_sign() {
        let mut full = funded(50_000);
        let (external, internal) = full.public_descriptors();
        assert!(!external.contains("prv") && external.contains("tpub"));
        let mut watch = BtcWallet::watch(&external, &internal, BtcNetwork::Signet).unwrap();
        assert!(full.can_sign() && !watch.can_sign());
        assert_eq!(watch.receive_address(), wallet(BtcNetwork::Signet).receive_address());
        let prepared = full.prepare_send(OTHER, 10_000, false, 2.0, None).unwrap();
        assert!(matches!(watch.sign(&prepared), Err(WalletError::WatchOnly)));
        assert!(full.sign(&prepared).is_ok());
        // A private descriptor is refused.
        let xprv = "wpkh(tprv8ZgxMBicQKsPd1EzCPZcQSPhsotX5HvRDCivA7ASNQFmjWuTsW3WWEwUNKFAZrnD9qpz55rtyLdphqkwRZUqNWYXwSEzd6P4pYvXGByRim3/84'/1'/0'/0/*)";
        assert!(matches!(BtcWallet::watch(xprv, xprv, BtcNetwork::Signet), Err(WalletError::Keys(_))));
        let _ = full.receive_address();
    }

    #[test]
    fn addresses_utxos_and_detail() {
        let mut w = funded(50_000);
        let addresses = w.addresses();
        let first = &addresses[0];
        assert!(!first.change && first.index == 0 && first.used);
        assert_eq!((first.sat, first.utxos), (50_000, 1));
        // The next receive address is shown and not used yet.
        let next = w.receive_address();
        assert!(w.addresses().iter().any(|a| a.address == next && !a.used && a.sat == 0));
        let utxos = w.utxos();
        assert_eq!(utxos.len(), 1);
        assert_eq!((utxos[0].sat, utxos[0].confirmations, utxos[0].change), (50_000, 0, false));
        let detail = w.tx_detail(&utxos[0].txid).unwrap();
        assert_eq!(detail.tx.net_sat, 50_000);
        // The input is of another wallet: its value is not known, and it is not bumped here.
        assert_eq!(detail.inputs[0].sat, None);
        assert!(!detail.inputs[0].mine && detail.outputs[0].mine);
        assert!(!detail.can_bump);
        assert!(w.tx_detail(&"22".repeat(32)).is_none());
        assert!(w.tx_detail("not a txid").is_none());
    }

    #[test]
    fn a_payment_that_waits_gets_a_higher_fee() {
        let mut w = funded(100_000);
        let prepared = w.prepare_send(OTHER, 30_000, false, 2.0, None).unwrap();
        let tx = w.sign(&prepared).unwrap();
        w.record_sent(tx, 200);
        let txid = prepared.txid.to_string();
        let detail = w.tx_detail(&txid).unwrap();
        assert!(detail.can_bump, "{detail:?}");
        assert!(detail.inputs.iter().all(|i| i.mine && i.sat == Some(100_000)));
        assert_eq!(detail.tx.fee_sat, Some(prepared.fee_sat));
        // The rate of the signed transaction: the signatures can be a byte shorter than
        // the estimate.
        assert!(detail.fee_rate.unwrap() > 1.9, "{:?}", detail.fee_rate);
        // Not higher than before: refused.
        assert!(matches!(w.prepare_bump(&txid, 1.0), Err(WalletError::FeeRate(_))));
        let bump = w.prepare_bump(&txid, 6.0).unwrap();
        assert_eq!(bump.replaces, Some(prepared.txid));
        assert_eq!(bump.to, OTHER);
        assert_eq!(bump.amount_sat, 30_000);
        assert!(bump.fee_sat > prepared.fee_sat);
        assert_eq!(bump.change_sat, prepared.change_sat + prepared.fee_sat - bump.fee_sat);
        assert_ne!(bump.txid, prepared.txid);
        assert!(w.sign(&bump).is_ok());
    }

    #[test]
    fn a_deposit_keeps_its_transaction_id() {
        let mut w = funded(100_000);
        let prepared = w.prepare_send(OTHER, 30_000, false, 2.0, Some(b"token")).unwrap();
        let tx = w.sign(&prepared).unwrap();
        w.record_sent(tx, 200);
        let txid = prepared.txid.to_string();
        let detail = w.tx_detail(&txid).unwrap();
        assert!(detail.outputs.iter().any(|o| o.data && o.address.is_none()));
        assert!(!detail.can_bump);
        assert!(matches!(w.prepare_bump(&txid, 6.0), Err(WalletError::Bump(_))));
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
