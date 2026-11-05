//! The Bitcoin wallet (issue #92), for Dart.
//!
//! The Bitcoin wallet is the open wallet's seed on BIP-84 (`wallet_btc::keys`). The seed
//! is kept here, in memory, from `wallet_create`/`wallet_restore` until `wallet_lock`, as
//! the Ergo keys are kept in the wallet handle. Nothing about Bitcoin is written to disk:
//! after an unlock, the first [`btc_sync`] reads the history again from the server.
//!
//! The network and the Esplora server come from the app's settings ([`btc_open`]). A
//! change of either makes a new wallet.
//!
//! While the wallet is locked, [`btc_watch`] reads the balance and the history with the
//! public descriptors that [`btc_descriptors`] gave at the last unlock (issue #103), as the
//! Ergo wallet reads its public addresses while it is locked. Those descriptors hold no
//! key: they cannot sign.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use once_cell::sync::Lazy;
use rand::{rngs::SysRng, TryRng};
use wallet_btc::esplora::{Esplora, EsploraError};
use wallet_btc::scan::{full_scan, STOP_GAP};
use wallet_btc::uri::{parse_payment_request, payment_uri};
use wallet_btc::wallet::{parse_address, WalletError};
use wallet_btc::{BtcNetwork, BtcWallet, PreparedSend};
use zeroize::Zeroizing;

/// Why a Bitcoin call failed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BtcErrorKind {
    /// The wallet is locked: unlock it first.
    Locked,
    /// A value from the user (network, server, amount, fee rate) is not usable.
    InvalidInput,
    /// Not an address of the wallet's network.
    Address,
    /// Not enough confirmed bitcoin.
    Funds,
    /// The Esplora server did not answer (or the network route is closed).
    Unreachable,
    /// The Esplora server answered with an error or with data that is not valid.
    Server,
    /// The transaction could not be made or signed.
    Transaction,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcError {
    pub kind: BtcErrorKind,
    /// The technical reason, in English.
    pub message: String,
}

fn error(kind: BtcErrorKind, message: impl Into<String>) -> BtcError {
    BtcError {
        kind,
        message: message.into(),
    }
}

impl From<EsploraError> for BtcError {
    fn from(e: EsploraError) -> Self {
        let kind = match e {
            EsploraError::Unreachable(_) => BtcErrorKind::Unreachable,
            _ => BtcErrorKind::Server,
        };
        error(kind, e.to_string())
    }
}

impl From<WalletError> for BtcError {
    fn from(e: WalletError) -> Self {
        let kind = match e {
            WalletError::Address { .. } => BtcErrorKind::Address,
            WalletError::Amount(_) | WalletError::FeeRate(_) => BtcErrorKind::InvalidInput,
            WalletError::Funds(_) => BtcErrorKind::Funds,
            WalletError::Chain(_) => BtcErrorKind::Server,
            WalletError::Keys(_)
            | WalletError::Build(_)
            | WalletError::Sign(_)
            | WalletError::Bump(_) => BtcErrorKind::Transaction,
            WalletError::WatchOnly => BtcErrorKind::Locked,
        };
        error(kind, e.to_string())
    }
}

fn recover<T>(r: std::sync::LockResult<T>) -> T {
    r.unwrap_or_else(|p| p.into_inner())
}

/// The seeds of the open wallet handles.
static SEEDS: Lazy<Mutex<HashMap<u64, Zeroizing<Vec<u8>>>>> = Lazy::new(Default::default);

struct Open {
    handle_id: u64,
    network: BtcNetwork,
    esplora: Esplora,
    wallet: Arc<Mutex<BtcWallet>>,
}

/// The Bitcoin wallet of the open handle. One at a time, like the open Ergo wallet.
static OPEN: Lazy<Mutex<Option<Open>>> = Lazy::new(Default::default);

/// Prepared transactions, by id, until they are sent or cancelled.
static PREPARED: Lazy<Mutex<HashMap<u64, (u64, PreparedSend)>>> = Lazy::new(Default::default);

/// Keep the seed of a new handle (`wallet_create`, `wallet_restore`).
pub(crate) fn keep_seed(handle_id: u64, seed: &[u8]) {
    recover(SEEDS.lock()).insert(handle_id, Zeroizing::new(seed.to_vec()));
}

/// Forget everything of a handle that is locked.
pub(crate) fn forget(handle_id: u64) {
    recover(SEEDS.lock()).remove(&handle_id);
    let mut open = recover(OPEN.lock());
    if open.as_ref().is_some_and(|o| o.handle_id == handle_id) {
        *open = None;
    }
    recover(PREPARED.lock()).retain(|_, (h, _)| *h != handle_id);
}

fn network_of(name: &str) -> Result<BtcNetwork, BtcError> {
    BtcNetwork::from_name(name)
        .ok_or_else(|| error(BtcErrorKind::InvalidInput, format!("unknown network {name:?}")))
}

/// The wallet of `handle_id`, its network and its server.
fn current(handle_id: u64) -> Result<(Arc<Mutex<BtcWallet>>, BtcNetwork, Esplora), BtcError> {
    let open = recover(OPEN.lock());
    match open.as_ref() {
        Some(o) if o.handle_id == handle_id => Ok((o.wallet.clone(), o.network, o.esplora.clone())),
        _ => Err(error(
            BtcErrorKind::Locked,
            "the Bitcoin wallet is not open: unlock the wallet",
        )),
    }
}

/// The networks that the app knows, by the names of nodo's ledger declaration.
#[flutter_rust_bridge::frb(sync)]
pub fn btc_networks() -> Vec<String> {
    BtcNetwork::ALL.iter().map(|n| n.name().to_string()).collect()
}

/// The Esplora server that the app uses on `network` when the user gives none (empty for
/// regtest).
#[flutter_rust_bridge::frb(sync)]
pub fn btc_default_server(network: String) -> String {
    BtcNetwork::from_name(&network)
        .and_then(BtcNetwork::default_esplora)
        .unwrap_or_default()
        .to_string()
}

/// True if `address` is a Bitcoin address of `network`.
#[flutter_rust_bridge::frb(sync)]
pub fn btc_is_address(network: String, address: String) -> bool {
    BtcNetwork::from_name(&network).is_some_and(|n| parse_address(&address, n).is_ok())
}

/// What the wallet shows.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcWalletView {
    pub network: String,
    pub server: String,
    /// The first receive address without a transaction.
    pub receive_address: String,
    /// Confirmed, in satoshi.
    pub confirmed_sat: u64,
    /// Not confirmed yet, in satoshi.
    pub pending_sat: u64,
    /// Mined and not mature yet, in satoshi.
    pub immature_sat: u64,
    /// The height of the last block that the wallet knows (0 before the first sync).
    pub tip_height: u32,
}

fn view(wallet: &mut BtcWallet, server: &str) -> BtcWalletView {
    let balance = wallet.balance();
    BtcWalletView {
        network: wallet.network().name().to_string(),
        server: server.to_string(),
        receive_address: wallet.receive_address(),
        confirmed_sat: balance.confirmed,
        pending_sat: balance.pending,
        immature_sat: balance.immature,
        tip_height: wallet.tip_height(),
    }
}

/// Open the Bitcoin wallet of the open handle on `network` (`mainnet`, `testnet`, `signet`
/// or `regtest`) with the Esplora server `server` (empty: the default of the network).
/// With the same network and server, the wallet that is open stays (with its history).
pub fn btc_open(handle_id: u64, network: String, server: String) -> Result<BtcWalletView, BtcError> {
    let network = network_of(&network)?;
    let server = match server.trim() {
        "" => network.default_esplora().ok_or_else(|| {
            error(BtcErrorKind::InvalidInput, "regtest needs an Esplora server address")
        })?,
        s => s,
    };
    let esplora = Esplora::new(server).map_err(|e| error(BtcErrorKind::InvalidInput, e.to_string()))?;
    let mut open = recover(OPEN.lock());
    if let Some(o) = open.as_ref() {
        if o.handle_id == handle_id && o.network == network && o.esplora.base() == esplora.base() {
            let mut wallet = recover(o.wallet.lock());
            return Ok(view(&mut wallet, o.esplora.base()));
        }
    }
    let seeds = recover(SEEDS.lock());
    let seed = seeds.get(&handle_id).ok_or_else(|| {
        error(BtcErrorKind::Locked, "the wallet is locked: unlock it first")
    })?;
    let mut wallet = BtcWallet::new(seed, network)?;
    drop(seeds);
    let shown = view(&mut wallet, esplora.base());
    recover(PREPARED.lock()).retain(|_, (h, _)| *h != handle_id);
    *open = Some(Open {
        handle_id,
        network,
        esplora,
        wallet: Arc::new(Mutex::new(wallet)),
    });
    Ok(shown)
}

/// Read the wallet's transactions from the server again.
pub async fn btc_sync(handle_id: u64) -> Result<BtcWalletView, BtcError> {
    let (wallet, network, esplora) = current(handle_id)?;
    let request = recover(wallet.lock()).scan_request();
    let response = full_scan(&esplora, network.bitcoin(), request, STOP_GAP).await?;
    let mut wallet = recover(wallet.lock());
    wallet.apply_scan(response)?;
    Ok(view(&mut wallet, esplora.base()))
}

/// A transaction of the history.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcTxView {
    pub txid: String,
    /// Received minus sent, in satoshi (negative for a payment).
    pub net_sat: i64,
    /// The fee, if the wallet knows it (0 if not).
    pub fee_sat: u64,
    pub fee_known: bool,
    /// 0 while the transaction is not confirmed.
    pub confirmations: u32,
    /// Unix seconds: the block time, or when the wallet saw it first (0 if not known).
    pub time: u64,
}

/// The history, the newest first.
pub fn btc_transactions(handle_id: u64) -> Result<Vec<BtcTxView>, BtcError> {
    let (wallet, _, _) = current(handle_id)?;
    let wallet = recover(wallet.lock());
    Ok(wallet.transactions().into_iter().map(tx_view).collect())
}

fn tx_view(t: wallet_btc::TxView) -> BtcTxView {
    BtcTxView {
        txid: t.txid,
        net_sat: t.net_sat,
        fee_sat: t.fee_sat.unwrap_or(0),
        fee_known: t.fee_sat.is_some(),
        confirmations: t.confirmations,
        time: t.time.unwrap_or(0),
    }
}

/// Fee rates in sat/vB.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BtcFeeRates {
    /// For the next block or two.
    pub fast: f64,
    /// For about an hour (6 blocks).
    pub normal: f64,
    /// For about a day (144 blocks).
    pub slow: f64,
    /// False when the server gave no estimate (regtest): the rates are the lowest.
    pub estimated: bool,
}

fn rate_for(estimates: &std::collections::BTreeMap<u16, f64>, target: u16) -> Option<f64> {
    // The estimate for the target, or for the nearest target that is longer, else shorter.
    estimates
        .range(target..)
        .next()
        .or_else(|| estimates.range(..target).next_back())
        .map(|(_, rate)| *rate)
}

/// The fee rates of the server, rounded up to 0.1 sat/vB, never under the lowest rate.
pub async fn btc_fee_rates(handle_id: u64) -> Result<BtcFeeRates, BtcError> {
    let (_, _, esplora) = current(handle_id)?;
    let estimates = esplora.fee_estimates().await?;
    let min = wallet_btc::wallet::MIN_FEE_RATE;
    let round = |r: Option<f64>| ((r.unwrap_or(min) * 10.0).ceil() / 10.0).max(min);
    Ok(BtcFeeRates {
        fast: round(rate_for(&estimates, 2)),
        normal: round(rate_for(&estimates, 6)),
        slow: round(rate_for(&estimates, 144)),
        estimated: !estimates.is_empty(),
    })
}

/// A transaction that is made and not sent.
#[derive(Debug, Clone, PartialEq)]
pub struct BtcPreparedView {
    pub id: u64,
    pub to: String,
    pub amount_sat: u64,
    pub fee_sat: u64,
    pub fee_rate: f64,
    pub change_sat: u64,
    pub txid: String,
    /// The transaction that this one replaces with a higher fee (empty if none).
    pub replaces: String,
}

fn store(handle_id: u64, prepared: PreparedSend) -> BtcPreparedView {
    let mut all = recover(PREPARED.lock());
    // One prepared send per wallet: a new one replaces the old one.
    all.retain(|_, (h, _)| *h != handle_id);
    let id = loop {
        let id = (SysRng.try_next_u64().expect("OS RNG") & 0x7FFF_FFFF_FFFF_FFFF).max(1);
        if !all.contains_key(&id) {
            break id;
        }
    };
    let shown = BtcPreparedView {
        id,
        to: prepared.to.clone(),
        amount_sat: prepared.amount_sat,
        fee_sat: prepared.fee_sat,
        fee_rate: prepared.fee_rate_sat_vb,
        change_sat: prepared.change_sat,
        txid: prepared.txid.to_string(),
        replaces: prepared.replaces.map(|t| t.to_string()).unwrap_or_default(),
    };
    all.insert(id, (handle_id, prepared));
    shown
}

/// Make (not sign) a payment of `amount_sat` to `to` at `fee_rate` sat/vB. With
/// `send_all`, everything that the wallet can spend, less the fee.
pub fn btc_prepare_send(
    handle_id: u64,
    to: String,
    amount_sat: u64,
    send_all: bool,
    fee_rate: f64,
) -> Result<BtcPreparedView, BtcError> {
    let (wallet, _, _) = current(handle_id)?;
    let prepared = recover(wallet.lock()).prepare_send(&to, amount_sat, send_all, fee_rate, None)?;
    Ok(store(handle_id, prepared))
}

/// Make a payment with `data` in an `OP_RETURN` output (a deposit token).
pub(crate) fn prepare_with_data(
    handle_id: u64,
    to: &str,
    amount_sat: u64,
    fee_rate: f64,
    data: &[u8],
) -> Result<BtcPreparedView, BtcError> {
    let (wallet, _, _) = current(handle_id)?;
    let prepared = recover(wallet.lock()).prepare_send(to, amount_sat, false, fee_rate, Some(data))?;
    Ok(store(handle_id, prepared))
}

/// The network of the open Bitcoin wallet of `handle_id`.
pub(crate) fn open_network(handle_id: u64) -> Result<BtcNetwork, BtcError> {
    current(handle_id).map(|(_, network, _)| network)
}

/// The Esplora server of the open Bitcoin wallet of `handle_id`.
pub(crate) fn open_server(handle_id: u64) -> Result<Esplora, BtcError> {
    current(handle_id).map(|(_, _, esplora)| esplora)
}

/// Forget a prepared payment.
#[flutter_rust_bridge::frb(sync)]
pub fn btc_cancel(prepared_id: u64) {
    recover(PREPARED.lock()).remove(&prepared_id);
}

/// Sign and send a prepared payment. Returns the transaction id.
pub async fn btc_send(handle_id: u64, prepared_id: u64) -> Result<String, BtcError> {
    let (wallet, _, esplora) = current(handle_id)?;
    let prepared = {
        let mut all = recover(PREPARED.lock());
        match all.remove(&prepared_id) {
            Some((h, p)) if h == handle_id => p,
            Some(other) => {
                all.insert(prepared_id, other);
                return Err(error(BtcErrorKind::InvalidInput, "this payment is of another wallet"));
            }
            None => return Err(error(BtcErrorKind::InvalidInput, "unknown or old payment")),
        }
    };
    let tx = recover(wallet.lock()).sign(&prepared)?;
    let txid = esplora.broadcast(&tx).await?;
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    recover(wallet.lock()).record_sent(tx, now);
    Ok(txid.to_string())
}

/// The public descriptors of a Bitcoin wallet: every address, no key.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcDescriptors {
    pub network: String,
    /// The receive addresses (`/0/*`).
    pub receive: String,
    /// The change addresses (`/1/*`).
    pub change: String,
}

/// The public descriptors of the open Bitcoin wallet, for [`btc_watch`] while the wallet
/// is locked.
pub fn btc_descriptors(handle_id: u64) -> Result<BtcDescriptors, BtcError> {
    let (wallet, network, _) = current(handle_id)?;
    let (receive, change) = recover(wallet.lock()).public_descriptors();
    Ok(BtcDescriptors {
        network: network.name().to_string(),
        receive,
        change,
    })
}

/// What a watch-only read gives: the wallet's figures and its history.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcWatchView {
    pub wallet: BtcWalletView,
    /// The newest first.
    pub transactions: Vec<BtcTxView>,
}

/// Read the balance and the history of `descriptors` on `server` (empty: the default of
/// the network) with no key: for a locked wallet. Nothing is kept.
pub async fn btc_watch(descriptors: BtcDescriptors, server: String) -> Result<BtcWatchView, BtcError> {
    let network = network_of(&descriptors.network)?;
    let server = match server.trim() {
        "" => network.default_esplora().ok_or_else(|| {
            error(BtcErrorKind::InvalidInput, "regtest needs an Esplora server address")
        })?,
        s => s,
    };
    let esplora = Esplora::new(server).map_err(|e| error(BtcErrorKind::InvalidInput, e.to_string()))?;
    let mut wallet = BtcWallet::watch(&descriptors.receive, &descriptors.change, network)
        .map_err(|e| error(BtcErrorKind::InvalidInput, e.to_string()))?;
    let response = full_scan(&esplora, network.bitcoin(), wallet.scan_request(), STOP_GAP).await?;
    wallet.apply_scan(response)?;
    Ok(BtcWatchView {
        wallet: view(&mut wallet, esplora.base()),
        transactions: wallet.transactions().into_iter().map(tx_view).collect(),
    })
}

/// An address of the wallet.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcAddressView {
    pub address: String,
    pub index: u32,
    /// A change address (`/1/*`).
    pub change: bool,
    pub used: bool,
    pub sat: u64,
    pub utxos: u32,
}

/// The addresses that the wallet showed or used: receive addresses first.
pub fn btc_addresses(handle_id: u64) -> Result<Vec<BtcAddressView>, BtcError> {
    let (wallet, _, _) = current(handle_id)?;
    let wallet = recover(wallet.lock());
    Ok(wallet
        .addresses()
        .into_iter()
        .map(|a| BtcAddressView {
            address: a.address,
            index: a.index,
            change: a.change,
            used: a.used,
            sat: a.sat,
            utxos: a.utxos,
        })
        .collect())
}

/// An unspent output of the wallet.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcUtxoView {
    pub txid: String,
    pub vout: u32,
    pub sat: u64,
    pub address: String,
    pub change: bool,
    pub confirmations: u32,
}

/// The unspent outputs, the largest first.
pub fn btc_utxos(handle_id: u64) -> Result<Vec<BtcUtxoView>, BtcError> {
    let (wallet, _, _) = current(handle_id)?;
    let wallet = recover(wallet.lock());
    Ok(wallet
        .utxos()
        .into_iter()
        .map(|u| BtcUtxoView {
            txid: u.txid,
            vout: u.vout,
            sat: u.sat,
            address: u.address,
            change: u.change,
            confirmations: u.confirmations,
        })
        .collect())
}

/// An input or an output of a transaction.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcTxPartView {
    /// Empty for `OP_RETURN` data or a script that is not an address.
    pub address: String,
    /// 0 when not known ([`Self::sat_known`]).
    pub sat: u64,
    pub sat_known: bool,
    pub mine: bool,
    pub data: bool,
}

/// A transaction with its inputs and outputs.
#[derive(Debug, Clone, PartialEq)]
pub struct BtcTxDetailView {
    pub tx: BtcTxView,
    pub inputs: Vec<BtcTxPartView>,
    pub outputs: Vec<BtcTxPartView>,
    pub vsize: u64,
    /// sat/vB; 0 when the fee is not known.
    pub fee_rate: f64,
    /// It can be sent again with a higher fee ([`btc_prepare_bump`]).
    pub can_bump: bool,
}

fn part(p: wallet_btc::TxPart) -> BtcTxPartView {
    BtcTxPartView {
        address: p.address.unwrap_or_default(),
        sat: p.sat.unwrap_or(0),
        sat_known: p.sat.is_some(),
        mine: p.mine,
        data: p.data,
    }
}

/// A transaction of the wallet's history.
pub fn btc_tx_detail(handle_id: u64, txid: String) -> Result<BtcTxDetailView, BtcError> {
    let (wallet, _, _) = current(handle_id)?;
    let wallet = recover(wallet.lock());
    let d = wallet
        .tx_detail(&txid)
        .ok_or_else(|| error(BtcErrorKind::InvalidInput, "the wallet does not know this transaction"))?;
    Ok(BtcTxDetailView {
        tx: tx_view(d.tx),
        inputs: d.inputs.into_iter().map(part).collect(),
        outputs: d.outputs.into_iter().map(part).collect(),
        vsize: d.vsize,
        fee_rate: d.fee_rate.unwrap_or(0.0),
        can_bump: d.can_bump,
    })
}

/// Make (not sign) a transaction that replaces the unconfirmed payment `txid` at the
/// higher `fee_rate` (RBF). Send it with [`btc_send`].
pub fn btc_prepare_bump(handle_id: u64, txid: String, fee_rate: f64) -> Result<BtcPreparedView, BtcError> {
    let (wallet, _, _) = current(handle_id)?;
    let prepared = recover(wallet.lock()).prepare_bump(&txid, fee_rate)?;
    Ok(store(handle_id, prepared))
}

/// A payment request (`bitcoin:` URI or a plain address).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcPaymentRequest {
    pub address: String,
    /// 0 when the request gives no amount.
    pub amount_sat: u64,
    pub label: String,
    pub message: String,
}

/// `text` (a scanned QR code) as a payment request on `network`, or `None`.
#[flutter_rust_bridge::frb(sync)]
pub fn btc_parse_payment_request(network: String, text: String) -> Option<BtcPaymentRequest> {
    let network = BtcNetwork::from_name(&network)?;
    parse_payment_request(&text, network).map(|r| BtcPaymentRequest {
        address: r.address,
        amount_sat: r.amount_sat.unwrap_or(0),
        label: r.label.unwrap_or_default(),
        message: r.message.unwrap_or_default(),
    })
}

/// The `bitcoin:` URI of a request for `amount_sat` (0: any amount) to `address`.
#[flutter_rust_bridge::frb(sync)]
pub fn btc_payment_uri(address: String, amount_sat: u64) -> String {
    payment_uri(&address, amount_sat)
}

#[cfg(test)]
mod tests {
    use super::*;

    const HANDLE: u64 = 0x05ee_db7c;

    /// The open Bitcoin wallet is one for the process: the tests that open one take turns.
    static OPENS: Mutex<()> = Mutex::new(());

    #[test]
    fn locked_until_a_seed_is_kept() {
        let _turn = recover(OPENS.lock());
        forget(HANDLE);
        let e = btc_open(HANDLE, "signet".into(), String::new()).unwrap_err();
        assert_eq!(e.kind, BtcErrorKind::Locked);
        keep_seed(HANDLE, &[7u8; 64]);
        let shown = btc_open(HANDLE, "signet".into(), String::new()).unwrap();
        assert_eq!(shown.network, "signet");
        assert_eq!(shown.server, "https://mempool.space/signet/api");
        assert!(shown.receive_address.starts_with("tb1q"));
        assert_eq!(shown.confirmed_sat + shown.pending_sat, 0);
        assert!(btc_transactions(HANDLE).unwrap().is_empty());
        // Locking forgets the seed and the wallet.
        forget(HANDLE);
        assert_eq!(btc_transactions(HANDLE).unwrap_err().kind, BtcErrorKind::Locked);
        assert_eq!(
            btc_open(HANDLE, "signet".into(), String::new()).unwrap_err().kind,
            BtcErrorKind::Locked
        );
    }

    #[test]
    fn bad_settings_are_refused() {
        keep_seed(HANDLE + 1, &[8u8; 64]);
        let kind = |n: &str, s: &str| btc_open(HANDLE + 1, n.into(), s.into()).unwrap_err().kind;
        assert_eq!(kind("dogecoin", ""), BtcErrorKind::InvalidInput);
        assert_eq!(kind("regtest", ""), BtcErrorKind::InvalidInput);
        assert_eq!(kind("signet", "ftp://x"), BtcErrorKind::InvalidInput);
        forget(HANDLE + 1);
    }

    #[test]
    fn addresses_and_defaults() {
        assert_eq!(btc_networks(), vec!["mainnet", "testnet", "signet", "regtest"]);
        assert_eq!(btc_default_server("regtest".into()), "");
        assert!(btc_is_address(
            "mainnet".into(),
            "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu".into()
        ));
        assert!(!btc_is_address(
            "signet".into(),
            "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu".into()
        ));
    }

    #[test]
    fn fee_targets() {
        let estimates = [(1u16, 30.0), (3, 12.0), (6, 5.5), (144, 1.2)].into_iter().collect();
        assert_eq!(rate_for(&estimates, 2), Some(12.0));
        assert_eq!(rate_for(&estimates, 6), Some(5.5));
        assert_eq!(rate_for(&estimates, 1008), Some(1.2));
        assert_eq!(rate_for(&Default::default(), 6), None);
    }

    #[test]
    fn descriptors_of_the_open_wallet_watch_the_same_addresses() {
        let _turn = recover(OPENS.lock());
        const H: u64 = HANDLE + 7;
        keep_seed(H, &[9u8; 64]);
        let shown = btc_open(H, "signet".into(), String::new()).unwrap();
        let d = btc_descriptors(H).unwrap();
        assert_eq!(d.network, "signet");
        assert!(d.receive.starts_with("wpkh(") && !d.receive.contains("prv"));
        let mut watch = BtcWallet::watch(&d.receive, &d.change, BtcNetwork::Signet).unwrap();
        assert_eq!(watch.receive_address(), shown.receive_address);
        assert!(btc_utxos(H).unwrap().is_empty());
        assert!(btc_addresses(H).unwrap().iter().any(|a| a.address == shown.receive_address));
        assert_eq!(btc_tx_detail(H, "00".repeat(32)).unwrap_err().kind, BtcErrorKind::InvalidInput);
        assert_eq!(btc_prepare_bump(H, "00".repeat(32), 5.0).unwrap_err().kind, BtcErrorKind::Transaction);
        forget(H);
        assert_eq!(btc_descriptors(H).unwrap_err().kind, BtcErrorKind::Locked);
    }

    #[test]
    fn payment_requests() {
        let a = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
        let r = btc_parse_payment_request("signet".into(), btc_payment_uri(a.into(), 2_500)).unwrap();
        assert_eq!((r.address.as_str(), r.amount_sat), (a, 2_500));
        assert!(btc_parse_payment_request("mainnet".into(), a.into()).is_none());
        assert!(btc_parse_payment_request("dogecoin".into(), a.into()).is_none());
    }
}
