//! Argus wallet FFI — flutter_rust_bridge interface.

use std::collections::{HashMap, HashSet};
use std::sync::Mutex;

use citadel_core::constants::{MIN_BOX_VALUE_NANO, TX_FEE_NANO};
use ergo_lib::chain::transaction::reduced::ReducedTransaction;
use ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox;
use ergo_lib::ergotree_ir::serialization::SigmaSerializable;
use ergo_tx::build_send_tx_with_registers;
use ergopay_core::reduce_transaction_with_context;
use once_cell::sync::Lazy;
use rand::{rngs::SysRng, TryRng};
use wallet_core::seed::MnemonicPhrase;
use wallet_core::spend::{select_exact, select_for_send};
use wallet_core::wallet::WalletHandle;
use wallet_core::PinWrappedKey;
use wallet_net::client::{address_to_ergo_tree, ErgoNodeClient};

use crate::error::ArgusError;

/// Pending transactions: the unconfirmed-spending policy, where every wallet
/// spend gathers its inputs, and the pending summary the sync shows.
pub mod mempool;

/// Celaut nodes: connect to a node and show its advertisement (milestone M1).
pub mod celaut;

/// The Celaut database of the app: one for all the wallets (`docs/celaut/ui.md`).
pub mod celaut_db;

/// Celaut services: quotes, start, a local port for the tunnel, stop (milestone M2).
pub mod celaut_service;

/// The environment variables of a service: the container of the app, the declaration of a
/// service and the values of a start (`docs/celaut/env-variables.md`).
pub mod celaut_env;

/// Connect to a node from the peer invitation of a QR code (`docs/celaut/invite.md`).
pub mod celaut_invite;

/// What a service says about itself, read as a stream (`docs/celaut/service-info.md`).
pub mod celaut_service_info;

/// Celaut deposits: pay a node in ERG from one full wallet (milestone M3).
pub mod celaut_deposit;

/// The compute overview of the home screen: offered compute, credit, instances.
pub mod celaut_home;

/// The skill catalog: the skills and the ranked services of a skill (milestone M4).
pub mod celaut_catalog;

/// Optional Tor for the outbound connections (M5).
pub mod celaut_network;

/// Whether the nodes are available: the checks and their record (M4).
pub mod celaut_health;

/// Give a service to a node that does not have it (a package).
pub mod celaut_package;

/// The execution receipts of the instances: what the app keeps, shows and exports.
pub mod celaut_receipts;

/// The Bitcoin wallet of the open wallet's seed (issue #92).
pub mod btc;

/// Deposits in BTC to a node (issue #92).
pub mod celaut_btc_deposit;

fn err_str<E: Into<ArgusError>>(e: E) -> String {
    e.into().to_json_string()
}

fn recover<T>(r: std::sync::LockResult<T>) -> T {
    r.unwrap_or_else(|p| p.into_inner())
}

static HANDLES: Lazy<Mutex<HashMap<u64, WalletHandle>>> = Lazy::new(|| Mutex::new(HashMap::new()));

struct CachedPreparation {
    handle_id: u64,
    ergo_boxes: Vec<ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox>,
    data_input_boxes: Vec<ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox>,
    unsigned_tx: ergo_tx::Eip12UnsignedTx,
    miner_fee: i64,
    change_erg: i64,
    recipient_erg: i64,
    node_url: Option<String>,
}

static PREPARATIONS: Lazy<Mutex<HashMap<u64, CachedPreparation>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

fn store_preparation(prep: CachedPreparation) -> u64 {
    let mut cache = recover(PREPARATIONS.lock());
    cache.retain(|_, p| p.handle_id != prep.handle_id);
    loop {
        let id = (SysRng.try_next_u64().expect("OS RNG") & 0x7FFF_FFFF_FFFF_FFFF).max(1);
        if let std::collections::hash_map::Entry::Vacant(e) = cache.entry(id) {
            e.insert(prep);
            return id;
        }
    }
}

fn take_preparation(handle_id: u64, preparation_id: u64) -> Result<CachedPreparation, String> {
    let mut cache = recover(PREPARATIONS.lock());
    match cache.get(&preparation_id).map(|p| p.handle_id) {
        None => Err(
            ArgusError::TxBuildFailed("unknown or stale send preparation".into()).to_json_string(),
        ),
        Some(owner) if owner != handle_id => Err(ArgusError::TxBuildFailed(
            "send preparation does not match wallet".into(),
        )
        .to_json_string()),
        Some(_) => Ok(cache.remove(&preparation_id).expect("preparation present")),
    }
}

fn drop_preparations_for(handle_id: u64) {
    recover(PREPARATIONS.lock()).retain(|_, p| p.handle_id != handle_id);
    mempool::forget_held_back(handle_id);
}

/// Adjust miner fee in an already-built EIP-12 unsigned tx.
/// Finds the fee output (by `MINER_FEE_ERGO_TREE`), the change output (by `change_ergo_tree`)
/// and shifts `delta = custom_fee - current_fee` from change to fee.
fn apply_custom_fee(
    tx: &mut ergo_tx::Eip12UnsignedTx,
    change_ergo_tree: &str,
    current_fee: i64,
    custom_fee: i64,
) -> Result<i64, String> {
    if current_fee == custom_fee {
        return Ok(current_fee);
    }
    let delta = custom_fee - current_fee;
    let fee_idx = tx
        .outputs
        .iter()
        .position(|o| o.ergo_tree == citadel_core::constants::MINER_FEE_ERGO_TREE)
        .ok_or_else(|| {
            ArgusError::TxBuildFailed("fee output not found in unsigned tx".into()).to_json_string()
        })?;

    let change_idx = tx
        .outputs
        .iter()
        .rposition(|o| o.ergo_tree == change_ergo_tree)
        .ok_or_else(|| {
            ArgusError::TxBuildFailed("change output not found in unsigned tx".into())
                .to_json_string()
        })?;

    let change_val: i64 = tx.outputs[change_idx].value.parse::<i64>().map_err(|e| {
        ArgusError::TxBuildFailed(format!("invalid change value: {e}")).to_json_string()
    })?;
    let new_change = change_val - delta;
    if new_change < 0 {
        return Err(ArgusError::TxBuildFailed(format!(
            "custom fee {custom_fee} nanoERG exceeds available change {change_val} nanoERG"
        ))
        .to_json_string());
    }
    tx.outputs[fee_idx].value = custom_fee.to_string();
    // The change box is the sole carrier of leftover tokens — never erase it.
    let carries_tokens = !tx.outputs[change_idx].assets.is_empty();
    if new_change == 0 && carries_tokens {
        return Err(ArgusError::TxBuildFailed(
            "custom fee would remove the change box holding tokens; lower the fee".into(),
        )
        .to_json_string());
    }
    let mut final_fee = custom_fee;
    if new_change == 0 || (!carries_tokens && new_change < MIN_BOX_VALUE_NANO) {
        // Dust change folds into the miner fee rather than failing the send.
        final_fee = i64::checked_add(custom_fee, new_change).ok_or_else(|| {
            ArgusError::TxBuildFailed("custom fee out of range".into()).to_json_string()
        })?;
        tx.outputs[fee_idx].value = final_fee.to_string();
        tx.outputs.remove(change_idx);
    } else {
        tx.outputs[change_idx].value = new_change.to_string();
    }
    Ok(final_fee)
}

/// The miner fee to use: `fee_nano`, or the minimum when it is not given.
fn checked_miner_fee(fee_nano: Option<i64>) -> Result<i64, String> {
    let fee = fee_nano.unwrap_or(TX_FEE_NANO);
    if fee < TX_FEE_NANO {
        return Err(ArgusError::TxBuildFailed(format!(
            "custom fee {fee} nanoERG is below minimum {TX_FEE_NANO}"
        ))
        .to_json_string());
    }
    Ok(fee)
}

fn register_handle(handle: WalletHandle) -> u64 {
    let mut handles = recover(HANDLES.lock());
    loop {
        let id = (SysRng.try_next_u64().expect("OS RNG") & 0x7FFF_FFFF_FFFF_FFFF).max(1);
        if let std::collections::hash_map::Entry::Vacant(e) = handles.entry(id) {
            e.insert(handle);
            return id;
        }
    }
}

fn with_handle<T>(
    handle_id: u64,
    op: &'static str,
    f: impl FnOnce(&WalletHandle) -> Result<T, String>,
) -> Result<T, String> {
    let handles = recover(HANDLES.lock());
    let handle = handles
        .get(&handle_id)
        .ok_or_else(|| ArgusError::HandleNotFound(op, handle_id).to_json_string())?;
    f(handle)
}

/// Connected clients by preferred URL, kept for a minute. Every call used
/// to reconnect and probe `/info` first; a refresh is a dozen calls, so the
/// probes alone cost seconds on a public node. A node that dies inside
/// the minute fails its calls until the entry expires, which the sync
/// reports as stale rather than hiding.
static NODE_CLIENTS: Mutex<Option<HashMap<String, (std::time::Instant, ErgoNodeClient)>>> =
    Mutex::new(None);
const NODE_CLIENT_TTL: std::time::Duration = std::time::Duration::from_secs(60);

pub(crate) fn clear_node_clients() {
    if let Some(map) = recover(NODE_CLIENTS.lock()).as_mut() {
        map.clear();
    }
}

async fn node_client(node_url: Option<String>) -> Result<ErgoNodeClient, String> {
    let key = node_url.clone().unwrap_or_default();
    if let Some(map) = recover(NODE_CLIENTS.lock()).as_ref() {
        if let Some((at, client)) = map.get(&key) {
            if at.elapsed() < NODE_CLIENT_TTL {
                return Ok(client.clone());
            }
        }
    }
    let client = ErgoNodeClient::connect(node_url)
        .await
        .map_err(|e| ArgusError::NodeUnreachable(e).to_json_string())?;
    recover(NODE_CLIENTS.lock())
        .get_or_insert_with(HashMap::new)
        .insert(key, (std::time::Instant::now(), client.clone()));
    Ok(client)
}

#[flutter_rust_bridge::frb]
pub fn set_network(node_urls: Vec<String>, explorer_url: Option<String>) {
    wallet_net::client::set_network(node_urls, explorer_url);
    clear_node_clients();
}

#[flutter_rust_bridge::frb]
pub async fn probe_network() -> Result<String, String> {
    let mut out = Vec::new();
    for url in wallet_net::client::node_urls(None) {
        match wallet_net::client::probe_height(&url).await {
            Ok(height) => out.push(serde_json::json!({
                "url": url,
                "ok": true,
                "height": height,
            })),
            Err(err) => out.push(serde_json::json!({
                "url": url,
                "ok": false,
                "error": err,
            })),
        }
    }
    serde_json::to_string(&serde_json::json!({
        "nodes": out,
        "explorer": wallet_net::client::configured_explorer(),
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

fn tokens_json(tokens: &[(String, u64)]) -> Vec<serde_json::Value> {
    tokens
        .iter()
        .map(|(id, amount)| serde_json::json!({ "id": id, "amount": amount }))
        .collect()
}

fn session_json(
    handle_id: u64,
    encrypted_seed_json: String,
    wrap_key: String,
) -> Result<String, String> {
    serde_json::to_string(&serde_json::json!({
        "handle_id": handle_id.to_string(),
        "encrypted_seed_json": encrypted_seed_json,
        "wrap_key": wrap_key,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

fn open_wallet(mnemonic_phrase: String, passphrase: &str) -> Result<(u64, String, String), String> {
    let phrase = MnemonicPhrase::parse(mnemonic_phrase).map_err(err_str)?;
    let seed = zeroize::Zeroizing::new(phrase.to_seed(passphrase).map_err(err_str)?);
    let encrypted = wallet_core::EncryptedSeed::encrypt(seed.as_slice()).map_err(err_str)?;
    let json = serde_json::to_string(&encrypted.to_json().map_err(err_str)?)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())?;
    let wrap_key = encrypted.wrap_key_hex();
    let handle = WalletHandle::create(phrase, passphrase).map_err(err_str)?;
    let id = register_handle(handle);
    btc::keep_seed(id, seed.as_slice());
    Ok((id, json, wrap_key))
}

/// Create a wallet from a BIP-39 mnemonic. Returns `{handle_id, encrypted_seed_json, wrap_key}`.
#[flutter_rust_bridge::frb]
pub fn wallet_create(mnemonic_phrase: String, passphrase: String) -> Result<String, String> {
    let (id, json, wrap_key) = open_wallet(mnemonic_phrase, &passphrase)?;
    session_json(id, json, wrap_key)
}

/// Restore from a Keystore blob plus the separately stored wrap key.
/// v1 blobs that still embed `k` accept a null wrap key.
#[flutter_rust_bridge::frb]
pub fn wallet_restore(
    encrypted_seed_json: String,
    wrap_key: Option<String>,
) -> Result<u64, String> {
    let json: serde_json::Value = serde_json::from_str(&encrypted_seed_json)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())?;
    let encrypted =
        wallet_core::EncryptedSeed::from_json(&json, wrap_key.as_deref()).map_err(err_str)?;
    let mut seed_bytes = encrypted.decrypt().map_err(err_str)?;
    let handle = WalletHandle::restore_from_seed(&seed_bytes).map_err(err_str)?;
    let id = register_handle(handle);
    btc::keep_seed(id, &seed_bytes);
    use zeroize::Zeroize;
    seed_bytes.zeroize();
    Ok(id)
}

#[flutter_rust_bridge::frb]
pub fn wallet_lock(handle_id: u64) -> Result<(), String> {
    let mut handles = recover(HANDLES.lock());
    let handle = handles
        .remove(&handle_id)
        .ok_or_else(|| ArgusError::HandleNotFound("wallet_lock", handle_id).to_json_string())?;
    handle.lock();
    drop_preparations_for(handle_id);
    btc::forget(handle_id);
    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn wallet_is_unlocked(handle_id: u64) -> Result<bool, String> {
    with_handle(handle_id, "wallet_is_unlocked", |h| Ok(h.is_unlocked()))
}

#[flutter_rust_bridge::frb]
pub fn derive_address(handle_id: u64, index: u32) -> Result<String, String> {
    with_handle(handle_id, "derive_address", |h| {
        h.derive_address(index).map_err(err_str)
    })
}

#[flutter_rust_bridge::frb]
pub fn create_encrypted_seed(
    mnemonic_phrase: String,
    passphrase: String,
) -> Result<String, String> {
    let phrase = MnemonicPhrase::parse(mnemonic_phrase).map_err(err_str)?;
    let mut seed = phrase.to_seed(&passphrase).map_err(err_str)?;
    let encrypted = wallet_core::EncryptedSeed::encrypt(&seed).map_err(err_str)?;
    use zeroize::Zeroize;
    seed.zeroize();
    let json = encrypted.to_json().map_err(err_str)?;
    serde_json::to_string(&serde_json::json!({
        "encrypted_seed_json": json,
        "wrap_key": encrypted.wrap_key_hex(),
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Seal the AES wrap key with a PIN (Argon2id + AES-GCM). Returns pin-wrap JSON.
#[flutter_rust_bridge::frb]
pub fn wrap_key_with_pin(wrap_key_hex: String, pin: String) -> Result<String, String> {
    let bytes = hex::decode(wrap_key_hex.trim())
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())?;
    let wrapped = PinWrappedKey::wrap(&bytes, &pin).map_err(err_str)?;
    Ok(wrapped.to_json().to_string())
}

/// Recover the AES wrap key from pin-wrap JSON.
#[flutter_rust_bridge::frb]
pub fn unwrap_key_with_pin(pin_wrap_json: String, pin: String) -> Result<String, String> {
    let json: serde_json::Value = serde_json::from_str(&pin_wrap_json)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())?;
    let wrapped = PinWrappedKey::from_json(&json).map_err(err_str)?;
    let key = wrapped.unwrap(&pin).map_err(err_str)?;
    Ok(hex::encode(key))
}

#[flutter_rust_bridge::frb]
pub fn sign_reduced_transaction(
    handle_id: u64,
    reduced_tx_bytes: Vec<u8>,
) -> Result<String, String> {
    with_handle(handle_id, "sign_reduced_transaction", |handle| {
        let reduced =
            wallet_core::transaction::deserialize_reduced(&reduced_tx_bytes).map_err(err_str)?;
        let signed_tx = handle.sign_reduced(reduced).map_err(err_str)?;
        serde_json::to_value(&signed_tx)
            .map(|v| v.to_string())
            .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
    })
}

/// Human summary of an ErgoPay reduced transaction: inputs (with values and
/// tokens when the node can supply the boxes), outputs classified as
/// recipient / change / fee, and totals. See `api_ergopay_impl`.
#[flutter_rust_bridge::frb]
pub async fn describe_reduced_transaction(
    handle_id: u64,
    reduced_tx_bytes: Vec<u8>,
    node_url: Option<String>,
) -> Result<String, String> {
    let reduced =
        wallet_core::transaction::deserialize_reduced(&reduced_tx_bytes).map_err(err_str)?;
    // Input boxes are best effort: a node without the box (spent, pruned,
    // unreachable) still leaves the outputs and fee readable.
    let mut input_boxes = Vec::new();
    let client = node_client(node_url).await;
    if let Ok(client) = &client {
        for input in reduced.unsigned_tx.inputs.iter() {
            let id: String = input.box_id.clone().into();
            input_boxes.push(client.get_blockchain_box_by_id(&id).await.ok());
        }
    } else {
        input_boxes.resize(reduced.unsigned_tx.inputs.len(), None);
    }
    // The dApp chose the inputs. A request that spends a box a pending
    // transaction already spends, or the wallet's unconfirmed funds while
    // it waits for confirmations, is refused before it can be signed.
    let ids: Vec<String> = reduced
        .unsigned_tx
        .inputs
        .iter()
        .map(|i| i.box_id.clone().into())
        .collect();
    let trees = ids
        .iter()
        .zip(&input_boxes)
        .filter_map(|(id, b)| Some((id.clone(), b.as_ref()?["ergoTree"].as_str()?.to_string())))
        .collect();
    let client = client?;
    mempool::check_external_inputs(handle_id, &client, &ids, &trees).await?;
    let summary = with_handle(handle_id, "describe_reduced_transaction", |handle| {
        Ok(crate::api_ergopay_impl::summarize_reduced(
            &reduced,
            &|addr| handle.owns_address(addr).unwrap_or(false),
            &input_boxes,
        ))
    })?;
    serde_json::to_string(&summary)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Broadcast an already signed transaction (node JSON) and return its id.
#[flutter_rust_bridge::frb]
pub async fn submit_signed_transaction(
    tx_json: String,
    node_url: Option<String>,
) -> Result<String, String> {
    let value: serde_json::Value = serde_json::from_str(&tx_json)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())?;
    let client = node_client(node_url).await?;
    client
        .submit_transaction(&value)
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())
}

/// True when `address` is an EIP-3 child of the unlocked wallet.
#[flutter_rust_bridge::frb]
pub fn wallet_owns_address(handle_id: u64, address: String) -> Result<bool, String> {
    with_handle(handle_id, "wallet_owns_address", |handle| {
        handle.owns_address(&address).map_err(err_str)
    })
}

#[flutter_rust_bridge::frb]
pub fn generate_mnemonic(strength: u32) -> Result<String, String> {
    use ergo_lib::wallet::mnemonic_generator::{Language, MnemonicGenerator};

    // All five BIP-39 strengths are supported; 160-bit (15 words) is the
    // Ergo ecosystem standard. Unknown values are rejected rather than
    // silently substituted.
    let strength = match strength {
        128 | 160 | 192 | 224 | 256 => strength,
        other => {
            return Err(ArgusError::InvalidMnemonic(format!(
                "unsupported mnemonic strength {other}: use 128, 160, 192, 224, or 256"
            ))
            .to_json_string())
        }
    };
    let byte_len = (strength / 8) as usize;
    let mut entropy = vec![0u8; byte_len];
    SysRng.try_fill_bytes(&mut entropy).expect("OS RNG");
    let generator = MnemonicGenerator::new(Language::English, strength)
        .map_err(|e| ArgusError::InvalidMnemonic(format!("{e:?}")).to_json_string())?;
    let phrase = generator
        .from_entropy(entropy)
        .map_err(|e| ArgusError::InvalidMnemonic(format!("{e:?}")).to_json_string())?;
    Ok(phrase)
}

/// Validate an Ergo address (base58) against the checksum and network prefix.
#[flutter_rust_bridge::frb]
pub fn validate_ergo_address(address: String) -> bool {
    address_to_ergo_tree(&address).is_ok()
}

#[flutter_rust_bridge::frb]
pub async fn get_balance(address: String, node_url: Option<String>) -> Result<String, String> {
    let client = node_client(node_url).await?;
    // One listing serves both the confirmed figure and the mempool netting.
    let (boxes, _) = client
        .get_unspent(&address)
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    let txs = match address_to_ergo_tree(&address) {
        Ok(tree) => client.mempool_txs_for(&tree).await.unwrap_or_default(),
        Err(_) => Vec::new(),
    };
    Ok(balance_from_inputs(&address, &boxes, &txs).to_string())
}

/// One address's balance with its pending movements: `balance_nano_erg` and
/// `tokens` are the figures once everything pending confirms, and `summary`
/// splits them into confirmed, pending in and pending out. A mempool that
/// could not be read arrives here as no transactions, which leaves the
/// confirmed figures — never a failure.
fn balance_from_inputs(
    address: &str,
    boxes: &[ErgoBox],
    txs: &[serde_json::Value],
) -> serde_json::Value {
    let trees: HashSet<String> = address_to_ergo_tree(address).into_iter().collect();
    let summary = wallet_net::mempool::pending_summary(boxes, txs, &trees);
    let tokens: Vec<(String, u64)> = summary
        .tokens
        .iter()
        .map(|t| (t.token_id.clone(), t.amount()))
        .collect();
    serde_json::json!({
        "balance_nano_erg": summary.balance_nano_erg(),
        "tokens": tokens_json(&tokens),
        "summary": summary.to_json(),
    })
}

#[flutter_rust_bridge::frb]
pub async fn get_token_info(
    token_id: String,
    explorer_url: Option<String>,
) -> Result<String, String> {
    let provider = explorer_url.ok_or_else(|| "Explicit metadata provider consent required".to_string())?;
    let info = wallet_net::token_descriptor::load(&token_id, &provider).await?;
    serde_json::to_string(&info).map_err(|e| e.to_string())
}

static METADATA_JOB: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());
static METADATA_CANCEL: once_cell::sync::Lazy<tokio::sync::watch::Sender<u64>> =
    once_cell::sync::Lazy::new(|| tokio::sync::watch::channel(0).0);

/// Explicit single-provider inspection, separate from balance and pricing APIs.
#[flutter_rust_bridge::frb]
pub async fn inspect_token_metadata(
    token_id: String,
    provider_url: String,
    provider_is_node: bool,
) -> Result<String, String> {
    let _job = METADATA_JOB.try_lock().map_err(|_| "Metadata request already running")?;
    let mut cancel = METADATA_CANCEL.subscribe();
    tokio::select! {
        _ = cancel.changed() => Err("Metadata request cancelled".into()),
        answer = tokio::time::timeout(std::time::Duration::from_secs(15),
            wallet_net::token_descriptor::load_from(&token_id, &provider_url, provider_is_node)) => {
            let descriptor = answer.map_err(|_| "Metadata request timed out")??;
            serde_json::to_string(&descriptor).map_err(|e| e.to_string())
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn cancel_token_metadata() {
    METADATA_CANCEL.send_modify(|generation| *generation = generation.wrapping_add(1));
}

/// One page of `address`'s history, each transaction read from the point of
/// view of the whole wallet: `wallet_addresses` are every address it owns
/// (derived indices, the pinned one, a watched account's addresses), so a
/// move between two of them is not a payment and none of them is ever named
/// as the counterparty. Each entry carries `io`, its inputs and outputs
/// grouped by owner with protocol tags, for the activity classifier. An
/// empty list reads the page for `address` alone.
#[flutter_rust_bridge::frb]
pub async fn get_transaction_history(
    address: String,
    wallet_addresses: Vec<String>,
    node_url: Option<String>,
    limit: u64,
    offset: u64,
) -> Result<String, String> {
    let client = node_client(node_url).await?;
    let cap = if limit == 0 { 20 } else { limit.min(100) };
    let mut owned: HashSet<String> =
        wallet_addresses.into_iter().filter(|a| !a.is_empty()).collect();
    owned.insert(address.clone());
    let txs = client
        .get_wallet_transaction_history(&address, &owned, &crate::activity_tags::tag_box, cap, offset)
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    serde_json::to_string(&txs)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Unconfirmed transactions for the wallet's addresses, as activity entries.
///
/// Same shape as confirmed history entries (`TxSummary`) plus `confirmed:
/// false`, so the dashboard renders them through the same tile — `height: 0`
/// is what drives its Pending badge. The queried node endpoint needs no extra
/// index; any per-address failure simply yields no entries from that address.
/// A transaction touching several wallet addresses is returned once.
#[flutter_rust_bridge::frb]
pub async fn get_pending_transactions(
    addresses: Vec<String>,
    node_url: Option<String>,
) -> Result<String, String> {
    let client = node_client(node_url).await?;

    let addrs: Vec<String> = addresses.into_iter().filter(|a| !a.is_empty()).collect();

    let mut join_set = tokio::task::JoinSet::new();
    for addr in &addrs {
        let client_c = client.clone();
        let addr = addr.clone();
        join_set.spawn(async move {
            match address_to_ergo_tree(&addr) {
                Ok(tree) => client_c.mempool_txs_for(&tree).await.unwrap_or_default(),
                Err(_) => Vec::new(),
            }
        });
    }
    // The confirmed listings run alongside the mempool reads instead of
    // one after another once those are in.
    let mut unspent_set = tokio::task::JoinSet::new();
    for addr in &addrs {
        let client_c = client.clone();
        let addr = addr.clone();
        unspent_set.spawn(async move {
            let boxes = client_c
                .get_unspent(&addr)
                .await
                .map(|(boxes, _)| boxes)
                .unwrap_or_default();
            boxes.into_iter().map(|b| (addr.clone(), b)).collect::<Vec<_>>()
        });
    }

    // Collect uniquely by ID first: a transaction touching several wallet
    // addresses surfaces once, regardless of which fetch completes first.
    let mut seen = std::collections::HashSet::new();
    let mut unique: Vec<serde_json::Value> = Vec::new();
    while let Some(res) = join_set.join_next().await {
        let txs = res.unwrap_or_default();
        for tx in txs {
            let id = match tx["id"].as_str() {
                Some(i) => i.to_string(),
                None => continue,
            };
            if seen.insert(id) {
                unique.push(tx);
            }
        }
    }

    // Wallet-wide context: every owned address and the boxes it holds, so
    // each transaction is valued exactly once from the whole wallet's
    // perspective instead of whichever address saw it first.
    let owned: HashSet<String> = addrs.iter().cloned().collect();
    let mut confirmed: Vec<(String, ErgoBox)> = Vec::new();
    while let Some(res) = unspent_set.join_next().await {
        confirmed.extend(res.unwrap_or_default());
    }

    Ok(pending_from_inputs(&unique, &owned, &confirmed).to_string())
}

/// Activity rows for pending transactions, read from the whole wallet's
/// point of view like confirmed history.
///
/// A mempool input is only a box id. It resolves against the wallet's
/// confirmed boxes and the outputs of the other pending transactions (a
/// chained spend); a foreign input (a pool, an order) stays unread, which
/// leaves the row's `io` incomplete but never misstates what the wallet
/// itself spent. No request is made for it.
pub(crate) fn pending_from_inputs(
    unique: &[serde_json::Value],
    owned: &HashSet<String>,
    confirmed: &[(String, ErgoBox)],
) -> serde_json::Value {
    // A confirmed box belongs to the address whose listing returned it.
    let mut known: HashMap<String, serde_json::Value> = HashMap::new();
    for (address, b) in confirmed {
        if let Ok(mut v) = serde_json::to_value(b) {
            v["address"] = address.clone().into();
            known.insert(b.box_id().to_string(), v);
        }
    }
    for tx in unique {
        for o in tx["outputs"].as_array().into_iter().flatten() {
            if let Some(id) = o["boxId"].as_str() {
                known.entry(id.to_string()).or_insert_with(|| o.clone());
            }
        }
    }
    let mut out = Vec::new();
    for tx in unique {
        let inputs: Vec<serde_json::Value> = tx["inputs"]
            .as_array()
            .into_iter()
            .flatten()
            .map(|i| {
                i["boxId"]
                    .as_str()
                    .and_then(|id| known.get(id))
                    .cloned()
                    .unwrap_or_else(|| i.clone())
            })
            .collect();
        let Some(summary) = wallet_net::activity::summarize_for_wallet(
            tx,
            Some(&inputs),
            owned,
            &crate::activity_tags::tag_box,
        ) else {
            continue;
        };
        let Ok(mut row) = serde_json::to_value(&summary) else { continue };
        row["height"] = 0u64.into();
        row["timestamp"] = 0u64.into();
        row["confirmed"] = false.into();
        out.push(row);
    }
    serde_json::Value::Array(out)
}

/// Request-scoped inputs: no TTL cache, so an explicit refresh always reads the node.
/// UTXO and mempool inputs are independent and shared by every consumer:
/// balances, pending rows, the UTXO count and the wallet-wide pending
/// summary, valued once across all the addresses.
#[flutter_rust_bridge::frb]
pub async fn get_sync_inputs(
    addresses: Vec<String>,
    node_url: Option<String>,
) -> Result<String, String> {
    let client = node_client(node_url).await?;
    let mut seen = HashSet::new();
    let addresses: Vec<_> = addresses
        .into_iter()
        .filter(|a| !a.is_empty() && seen.insert(a.clone()))
        .collect();
    Ok(mempool::sync_inputs_together(&client, &addresses).await)
}

const MAX_DISCOVERY: u32 = 512;

#[flutter_rust_bridge::frb]
pub async fn discover_addresses(
    handle_id: u64,
    node_url: Option<String>,
    gap_limit: u32,
) -> Result<String, String> {
    let client = node_client(node_url).await?;
    let gap = gap_limit.max(1).min(100);

    let mut used = Vec::new();
    let mut last_used: Option<u32> = None;
    let mut consecutive_empty = 0u32;
    let mut scanned_up_to = 0u32;

    const CHUNK_SIZE: u32 = 10;
    let mut current_start = 0u32;

    while current_start < MAX_DISCOVERY {
        let chunk_end = (current_start + CHUNK_SIZE).min(MAX_DISCOVERY);
        let mut chunk_addrs = Vec::new();

        for index in current_start..chunk_end {
            let addr = with_handle(handle_id, "discover_addresses", |h| {
                h.derive_address(index).map_err(err_str)
            })?;
            chunk_addrs.push((index, addr));
        }

        // Query tx status for all addresses in this chunk concurrently
        let mut join_set = tokio::task::JoinSet::new();
        for (index, addr) in chunk_addrs {
            let client_c = client.clone();
            join_set.spawn(async move {
                let has_txs = client_c.address_has_transactions(&addr).await;
                (index, addr, has_txs)
            });
        }

        let mut chunk_results = Vec::new();
        while let Some(res) = join_set.join_next().await {
            match res {
                Ok((idx, addr, has_txs_res)) => {
                    chunk_results.push((idx, addr, has_txs_res));
                }
                Err(e) => return Err(ArgusError::NodeError(e.to_string()).to_json_string()),
            }
        }
        chunk_results.sort_by_key(|(idx, _, _)| *idx);

        let mut stopped = false;
        for (index, addr, has_txs_res) in chunk_results {
            scanned_up_to = index;
            let has_txs = has_txs_res.map_err(|e| ArgusError::NodeError(e).to_json_string())?;
            if has_txs {
                consecutive_empty = 0;
                last_used = Some(index);
                with_handle(handle_id, "discover_addresses", |h| {
                    h.ensure_index(index).map_err(err_str)
                })?;
                let balances = client
                    .get_address_balances(&addr)
                    .await
                    .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
                used.push(serde_json::json!({
                    "index": index,
                    "address": addr,
                    "balance_nano_erg": balances.0,
                    "tokens": tokens_json(&balances.1),
                }));
            } else {
                consecutive_empty += 1;
                if consecutive_empty >= gap {
                    stopped = true;
                    break;
                }
            }
        }

        if stopped {
            break;
        }
        current_start = chunk_end;
    }

    let next_unused = last_used.map(|i| i + 1).unwrap_or(0);
    serde_json::to_string(&serde_json::json!({
        "addresses": used,
        "scanned_up_to": scanned_up_to,
        "next_unused_index": next_unused,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Follow a singleton token forward through spent transactions to locate the current unspent box.
///
/// Designed to work on standard nodes without extraIndex or explorer indexing.
#[flutter_rust_bridge::frb]
pub async fn walk_singleton_lineage(
    singleton_token_id: String,
    starting_box_id: String,
    node_url: Option<String>,
    max_hops: Option<u32>,
) -> Result<String, String> {
    let client = node_client(node_url).await?;
    let res = client
        .track_singleton_lineage(
            &singleton_token_id,
            &starting_box_id,
            max_hops.unwrap_or(50),
        )
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    serde_json::to_string(&res)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Compute total balances and summary from a local WalletDatabase JSON snapshot.
#[flutter_rust_bridge::frb]
pub fn db_compute_summary(db_json: String) -> Result<String, String> {
    let db = wallet_core::WalletDatabase::from_json(&db_json).map_err(err_str)?;
    let (erg_nano, tokens) = db.get_total_balances().map_err(err_str)?;
    let unspent_count = db.get_unspent_boxes().len();
    let receive_0 = db.get_address_0().map(|a| a.address.clone());
    let lineages: Vec<&wallet_core::TrackedLineage> = db.lineages.values().collect();

    serde_json::to_string(&serde_json::json!({
        "balance_nano_erg": erg_nano,
        "tokens": tokens,
        "unspent_box_count": unspent_count,
        "receive_address_0": receive_0,
        "last_synced_height": db.sync.last_synced_height,
        "tracked_lineages": lineages,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

fn resolve_send_token(
    token_id: Option<String>,
    token_amount: Option<u64>,
) -> Result<Option<(String, u64)>, String> {
    match (token_id, token_amount) {
        (None, None) => Ok(None),
        (Some(id), Some(amt)) if !id.is_empty() && amt > 0 => Ok(Some((id, amt))),
        _ => Err(ArgusError::TxBuildFailed(
            "token_id and token_amount must both be a non-empty id and amount > 0".into(),
        )
        .to_json_string()),
    }
}

/// A recipient's tokens: the `tokens` array when it has any, else the
/// single `token_id`/`token_amount` pair. The two shapes are alternatives,
/// never added together. A caller sending one token writes both, so that
/// the single-recipient path can read the pair, and summing them would
/// send twice what was asked for.
fn parse_recipient_tokens(rcpt: &serde_json::Value) -> Result<Vec<(String, u64)>, String> {
    if let Some(list) = rcpt["tokens"].as_array() {
        if !list.is_empty() {
            let mut tokens = Vec::with_capacity(list.len());
            for t in list {
                if let Some(pair) = resolve_send_token(
                    t["token_id"].as_str().map(|id| id.to_string()),
                    t["amount"].as_u64(),
                )? {
                    tokens.push(pair);
                }
            }
            return Ok(tokens);
        }
    }
    Ok(resolve_send_token(
        rcpt["token_id"].as_str().map(|id| id.to_string()),
        rcpt["token_amount"].as_u64(),
    )?
    .into_iter()
    .collect())
}

fn resolve_spend_addresses(sender: &str, extra: &[String]) -> Vec<String> {
    let mut spend = extra
        .iter()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>();
    if spend.is_empty() && !sender.is_empty() {
        spend.push(sender.to_string());
    }
    spend.sort();
    spend.dedup();
    spend
}

/// A babel box (EIP-31) able to pay `fee` in `token_id`, as both the
/// signing box and the EIP-12 input, with the box read.
struct BabelPick {
    babel: ergo_tx::BabelBox,
    eip12: ergo_tx::Eip12InputBox,
    ergo_box: ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox,
}

/// The best babel box on the node for `token_id`: the one asking the
/// fewest tokens for `fee` that still stays a box afterwards.
async fn find_babel(
    client: &ErgoNodeClient,
    token_id: &str,
    fee: i64,
) -> Result<BabelPick, String> {
    let tree = ergo_tx::babel_ergo_tree(token_id);
    let boxes = client
        .unspent_boxes_by_ergo_tree(&tree, 0, 100)
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    let mut best: Option<BabelPick> = None;
    for item in boxes {
        // Both shapes from the same item: the signer's box and the
        // builder's input.
        let (Ok(ergo_box), Ok(eip12)) = (
            serde_json::from_value::<ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox>(item.clone()),
            serde_json::from_value::<ergo_tx::Eip12InputBox>(item),
        ) else {
            continue;
        };
        let Ok(babel) = ergo_tx::BabelBox::parse(&eip12, token_id) else { continue };
        if !babel.can_pay(fee) {
            continue;
        }
        if best.as_ref().map(|p| babel.price > p.babel.price).unwrap_or(true) {
            best = Some(BabelPick { babel, eip12, ergo_box });
        }
    }
    best.ok_or_else(|| {
        ArgusError::TxBuildFailed(
            "no babel fee box offers to take this token for the fee right now".into(),
        )
        .to_json_string()
    })
}

/// Add boxes from `pool` to `selected` until they hold `need` of `token`.
fn ensure_token(
    selected: &mut Vec<ergo_tx::Eip12InputBox>,
    pool: &[ergo_tx::Eip12InputBox],
    token: &str,
    need: u64,
) -> Result<(), String> {
    let held = |set: &[ergo_tx::Eip12InputBox]| -> u64 {
        set.iter()
            .flat_map(|b| b.assets.iter())
            .filter(|a| a.token_id.eq_ignore_ascii_case(token))
            .map(|a| a.amount.parse::<u64>().unwrap_or(0))
            .sum()
    };
    let mut have = held(selected);
    for b in pool {
        if have >= need {
            break;
        }
        if selected.iter().any(|s| s.box_id == b.box_id) {
            continue;
        }
        let in_box = held(std::slice::from_ref(b));
        if in_box > 0 {
            have += in_box;
            selected.push(b.clone());
        }
    }
    if have < need {
        return Err(ArgusError::TxBuildFailed(format!(
            "the wallet holds {have} of the fee token but the fee needs {need}"
        ))
        .to_json_string());
    }
    Ok(())
}

fn babel_json(s: &ergo_tx::BabelSummary) -> serde_json::Value {
    serde_json::json!({
        "token_id": s.token_id,
        "tokens_paid": s.tokens_paid,
        "price": s.price,
        "fee_nano": s.fee_nano,
        "babel_box_id": s.babel_box_id,
    })
}

/// The wallet's unspent boxes. Mempool-aware and under the user's
/// unconfirmed-spending policy; see [`mempool::gather_spendable`].
async fn gather_unspent(
    handle_id: u64,
    client: &ErgoNodeClient,
    addresses: &[String],
) -> Result<
    (
        Vec<ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox>,
        Vec<ergo_tx::Eip12InputBox>,
    ),
    String,
> {
    let spendable = mempool::gather_spendable(handle_id, client, addresses).await?;
    Ok((spendable.boxes, spendable.inputs))
}

// Four address sequences overlap latency without unbounded load on a user's node.
// Each sequence still runs all confirmed pages before its mempool lookup.
const GATHER_ADDRESS_CONCURRENCY: usize = 4;

/// Run `fetch` for each of the wallet's `addresses`, at most `concurrency`
/// at a time, and return the results in address order. Empty addresses are
/// skipped; an address the wallet does not own stops admission and fails
/// the gather in its place, never fetched.
async fn gather_unspent_ordered<'a, T, F, Fut>(
    handle_id: u64,
    addresses: &'a [String],
    concurrency: usize,
    fetch: F,
) -> Result<Vec<T>, String>
where
    F: Fn(&'a str) -> Fut,
    Fut: std::future::Future<Output = Result<T, String>>,
{
    use futures::{stream::FuturesOrdered, StreamExt};

    let mut pending = FuturesOrdered::new();
    let mut next_address = 0;
    let mut stopped = false;
    let mut out = Vec::new();
    loop {
        // Admission is synchronous and ordered, before constructing each fetch.
        // Stop at a foreign address, delivering its error in input order so an
        // earlier node failure retains the serial loop's error precedence.
        while !stopped && pending.len() < concurrency && next_address < addresses.len() {
            let addr = &addresses[next_address];
            next_address += 1;
            if addr.is_empty() {
                continue;
            }
            let ownership = with_handle(handle_id, "send", |h| {
                if !h.owns_address(addr).map_err(err_str)? {
                    return Err(ArgusError::InvalidAddress(
                        "spend address is not an address of this wallet".into(),
                    )
                    .to_json_string());
                }
                Ok(())
            });
            stopped = ownership.is_err();
            let fetch = &fetch;
            pending.push_back(async move {
                ownership?;
                fetch(addr).await
            });
        }
        // FuturesOrdered yields in the caller's sorted order, irrespective of
        // completion order. Error/cancellation drops all outstanding futures.
        let Some(result) = pending.next().await else {
            break;
        };
        out.push(result?);
    }
    Ok(out)
}

fn input_boxes_json(boxes: &[ergo_tx::Eip12InputBox]) -> Vec<serde_json::Value> {
    boxes
        .iter()
        .map(|b| {
            serde_json::json!({
                "box_id": b.box_id,
                "value_nano_erg": b.value,
                "creation_height": b.creation_height,
                "assets": b.assets.iter().map(|a| serde_json::json!({
                    "token_id": a.token_id,
                    "amount": a.amount,
                })).collect::<Vec<_>>(),
            })
        })
        .collect()
}

struct ManagementBuild<S> {
    unsigned_tx: ergo_tx::Eip12UnsignedTx,
    summary: S,
    miner_fee: i64,
    change_erg: i64,
    recipient_erg: i64,
}

struct PreparedManagement<S> {
    preparation_id: u64,
    input_boxes: Vec<serde_json::Value>,
    summary: S,
}

/// Index only the prefix needed by the selected IDs, retaining first matches.
/// A single input keeps the allocation-free early-exit search. For multiple
/// inputs each candidate is formatted/indexed at most once, even on a miss.
fn selected_ergo_boxes(
    boxes: &[ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox],
    selected: &[ergo_tx::Eip12InputBox],
) -> Vec<ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox> {
    if selected.len() <= 1 {
        return selected
            .iter()
            .filter_map(|e| {
                boxes
                    .iter()
                    .find(|b| b.box_id().to_string() == e.box_id)
                    .cloned()
            })
            .collect();
    }
    let mut index: HashMap<String, &ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox> =
        HashMap::new();
    let mut remaining = boxes.iter();
    selected
        .iter()
        .filter_map(|e| {
            if let Some(b) = index.get(e.box_id.as_str()) {
                return Some((*b).clone());
            }
            for b in remaining.by_ref() {
                let id = b.box_id().to_string();
                let found = id == e.box_id;
                index.entry(id).or_insert(b);
                if found {
                    return Some(b.clone());
                }
            }
            None
        })
        .collect()
}

fn filter_selected_inputs(
    inputs: Vec<ergo_tx::Eip12InputBox>,
    selected_box_ids: &[String],
) -> Result<Vec<ergo_tx::Eip12InputBox>, String> {
    let selected_ids = selected_box_ids
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    if selected_ids.is_empty() {
        return Ok(inputs);
    }
    let available_ids = inputs
        .iter()
        .map(|input| input.box_id.as_str())
        .collect::<HashSet<_>>();
    let mut missing = selected_ids
        .difference(&available_ids)
        .copied()
        .collect::<Vec<_>>();
    missing.sort_unstable();
    if !missing.is_empty() {
        return Err(ArgusError::TxBuildFailed(format!(
            "selected UTXO(s) not found: {}",
            missing.join(", ")
        ))
        .to_json_string());
    }
    Ok(inputs
        .into_iter()
        .filter(|input| selected_ids.contains(input.box_id.as_str()))
        .collect())
}

async fn prepare_management<S>(
    handle_id: u64,
    operation: &'static str,
    spend_addresses: &[String],
    selected_box_ids: &[String],
    change_address: &str,
    no_inputs_message: String,
    node_url: Option<String>,
    fee_nano: Option<i64>,
    build: impl FnOnce(&[ergo_tx::Eip12InputBox], &str, i32) -> Result<ManagementBuild<S>, String>,
) -> Result<PreparedManagement<S>, String> {
    with_handle(handle_id, operation, |handle| {
        if !handle.owns_address(change_address).map_err(err_str)? {
            return Err(ArgusError::InvalidAddress(
                "change is not an address of this wallet".into(),
            )
            .to_json_string());
        }
        Ok(())
    })?;

    let client = node_client(node_url.clone()).await?;
    let (boxes, inputs) = gather_unspent(handle_id, &client, spend_addresses).await?;
    let inputs = filter_selected_inputs(inputs, selected_box_ids)?;
    let hand_picked = !selected_box_ids.is_empty();
    if inputs.is_empty() {
        let error = ArgusError::NoUtxos(no_inputs_message).to_json_string();
        return Err(mempool::explain_for(handle_id, hand_picked, error));
    }
    let height = client
        .current_height()
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())? as i32;
    let change_tree = address_to_ergo_tree(change_address)
        .map_err(|e| ArgusError::InvalidAddress(e).to_json_string())?;
    let mut built = build(&inputs, &change_tree, height)
        .map_err(|e| mempool::explain_for(handle_id, hand_picked, e))?;

    if let Some(custom_fee) = fee_nano {
        if custom_fee < TX_FEE_NANO {
            return Err(ArgusError::TxBuildFailed(format!(
                "custom fee {custom_fee} nanoERG is below minimum {TX_FEE_NANO}"
            ))
            .to_json_string());
        }
        let applied_fee = apply_custom_fee(
            &mut built.unsigned_tx,
            &change_tree,
            built.miner_fee,
            custom_fee,
        )?;
        built.miner_fee = applied_fee;
        built.change_erg = built
            .unsigned_tx
            .outputs
            .iter()
            .find(|o| o.ergo_tree == change_tree)
            .map(|o| o.value.parse::<i64>().unwrap_or(0))
            .unwrap_or(0);
    }

    let mut boxes_by_id = boxes
        .into_iter()
        .map(|ergo_box| (ergo_box.box_id().to_string(), ergo_box))
        .collect::<HashMap<_, _>>();
    let ergo_boxes = inputs
        .iter()
        .map(|input| {
            boxes_by_id.remove(&input.box_id).ok_or_else(|| {
                ArgusError::TxBuildFailed(format!(
                    "UTXO set mismatch: missing ErgoBox {}",
                    input.box_id
                ))
                .to_json_string()
            })
        })
        .collect::<Result<Vec<_>, _>>()?;
    let input_boxes = input_boxes_json(&inputs);
    let preparation_id = store_preparation(CachedPreparation {
        handle_id,
        ergo_boxes,
        data_input_boxes: Vec::new(),
        unsigned_tx: built.unsigned_tx,
        miner_fee: built.miner_fee,
        change_erg: built.change_erg,
        recipient_erg: built.recipient_erg,
        node_url,
    });
    Ok(PreparedManagement {
        preparation_id,
        input_boxes,
        summary: built.summary,
    })
}

#[allow(clippy::too_many_arguments)]
async fn prepare(
    handle_id: u64,
    sender_address: &str,
    spend_addresses: &[String],
    change_address: &str,
    recipient_address: &str,
    amount_nano_erg: i64,
    token_id: Option<String>,
    token_amount: Option<u64>,
    node_url: Option<String>,
    fee_nano: Option<i64>,
    input_box_ids: Option<Vec<String>>,
    babel_token_id: Option<String>,
    recipient_registers: &HashMap<String, String>,
) -> Result<
    (
        Vec<serde_json::Value>,
        Vec<ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox>,
        ergo_tx::SendBuildResult,
        Option<ergo_tx::BabelSummary>,
    ),
    String,
> {
    if amount_nano_erg < MIN_BOX_VALUE_NANO {
        return Err(ArgusError::TxBuildFailed(format!(
            "amount must be at least {MIN_BOX_VALUE_NANO} nanoERG"
        ))
        .to_json_string());
    }
    if let Some(fee) = fee_nano {
        if fee < TX_FEE_NANO {
            return Err(ArgusError::TxBuildFailed(format!(
                "custom fee {fee} nanoERG is below minimum {TX_FEE_NANO}"
            ))
            .to_json_string());
        }
    }
    with_handle(handle_id, "send", |h| {
        if !h.owns_address(change_address).map_err(err_str)? {
            return Err(ArgusError::InvalidAddress(
                "change is not an address of this wallet".into(),
            )
            .to_json_string());
        }
        Ok(())
    })?;

    let spend = resolve_spend_addresses(sender_address, spend_addresses);

    let send_token = resolve_send_token(token_id, token_amount)?;
    let client = node_client(node_url).await?;
    let (mut boxes, eip12) = gather_unspent(handle_id, &client, &spend).await?;
    if eip12.is_empty() {
        return Err(ArgusError::NoUtxos(spend.join(",")).to_json_string());
    }

    let fee_for_required = fee_nano.unwrap_or(TX_FEE_NANO);
    // With a babel box paying the fee, the wallet's ERG covers only the
    // amount and a change box; the babel box brings the fee's ERG.
    let babel = match babel_token_id.as_deref().filter(|t| !t.is_empty()) {
        Some(t) => Some(find_babel(&client, t, fee_for_required).await?),
        None => None,
    };
    // Use the same complete budget as multi-send: the miner fee and a change
    // box. Omitting them lets selection stop before MAX is funded.
    let required = multi_send_required_erg(amount_nano_erg, fee_for_required, babel.is_some())?;
    let token_ref = send_token.as_ref().map(|(id, amt)| (id.as_str(), *amt));
    // Coin control: when the user chose boxes, spend exactly those. Falling
    // back to automatic selection here would silently pull in a box they
    // deliberately left out, which is the linking they were avoiding.
    let mut selected = match input_box_ids.as_deref() {
        Some(ids) => select_exact(&eip12, ids, required, token_ref)
            .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?,
        None => select_for_send(&eip12, required, token_ref)
            .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?,
    };
    if let Some(pick) = &babel {
        // The fee's worth of the token must be among the inputs too, on
        // top of whatever the send delivers of it.
        let sent_same = send_token
            .as_ref()
            .filter(|(id, _)| id.eq_ignore_ascii_case(&pick.babel.token_id))
            .map(|(_, n)| *n)
            .unwrap_or(0);
        let need = sent_same + pick.babel.tokens_for(fee_for_required);
        ensure_token(&mut selected.boxes, &eip12, &pick.babel.token_id, need)?;
        selected.boxes.push(pick.eip12.clone());
        boxes.push(pick.ergo_box.clone());
    }

    let height = client
        .current_height()
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())? as i32;
    let recipient_tree = address_to_ergo_tree(recipient_address)
        .map_err(|e| ArgusError::InvalidAddress(e).to_json_string())?;
    let change_tree = address_to_ergo_tree(change_address)
        .map_err(|e| ArgusError::InvalidAddress(e).to_json_string())?;

    let built = build_send_tx_with_registers(
        &selected.boxes,
        &recipient_tree,
        &change_tree,
        amount_nano_erg,
        token_ref,
        recipient_registers,
        height,
    )
    .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;

    let mut built = built;
    if let Some(custom_fee) = fee_nano {
        let applied_fee = apply_custom_fee(
            &mut built.unsigned_tx,
            &change_tree,
            built.summary.miner_fee,
            custom_fee,
        )?;
        built.summary.miner_fee = applied_fee;
        built.summary.change_erg = built
            .unsigned_tx
            .outputs
            .iter()
            .find(|o| o.ergo_tree == change_tree)
            .map(|o| o.value.parse::<i64>().unwrap_or(0))
            .unwrap_or(0);
    }
    let babel_summary = match &babel {
        Some(pick) => {
            let s = ergo_tx::apply_babel(&mut built.unsigned_tx, &pick.babel, &change_tree)
                .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;
            built.summary.change_erg = built
                .unsigned_tx
                .outputs
                .iter()
                // From the end, as apply_babel does: a send to the
                // wallet's own change address gives the recipient box the
                // same script, and only the last one is the change.
                .rev()
                .find(|o| o.ergo_tree == change_tree)
                .map(|o| o.value.parse::<i64>().unwrap_or(0))
                .unwrap_or(0);
            Some(s)
        }
        None => None,
    };

    let ergo_boxes = selected_ergo_boxes(&boxes, &selected.boxes);
    if ergo_boxes.len() != selected.boxes.len() {
        return Err(ArgusError::TxBuildFailed("UTXO set mismatch".into()).to_json_string());
    }

    let input_boxes = input_boxes_json(&selected.boxes);

    Ok((input_boxes, ergo_boxes, built, babel_summary))
}

#[flutter_rust_bridge::frb]
pub async fn prepare_send(
    handle_id: u64,
    sender_address: String,
    spend_addresses: Vec<String>,
    change_address: String,
    recipient_address: String,
    amount_nano_erg: i64,
    token_id: Option<String>,
    token_amount: Option<u64>,
    node_url: Option<String>,
    fee_nano: Option<i64>,
    input_box_ids: Option<Vec<String>>,
    babel_token_id: Option<String>,
) -> Result<String, String> {
    let hand_picked = input_box_ids.as_ref().is_some_and(|ids| !ids.is_empty());
    let (input_boxes, ergo_boxes, built, babel) = prepare(
        handle_id,
        &sender_address,
        &spend_addresses,
        &change_address,
        &recipient_address,
        amount_nano_erg,
        token_id,
        token_amount,
        node_url.clone(),
        fee_nano,
        input_box_ids,
        babel_token_id,
        &HashMap::new(),
    )
    .await
    .map_err(|e| mempool::explain_for(handle_id, hand_picked, e))?;
    let recipient_erg = built.summary.recipient_erg;
    let miner_fee = built.summary.miner_fee;
    let change_erg = built.summary.change_erg;
    let input_count = built.summary.input_count;
    let preview_token_id = built.summary.token_id.clone();
    let preview_token_amount = built.summary.token_amount;
    let preparation_id = store_preparation(CachedPreparation {
        handle_id,
        ergo_boxes,
        data_input_boxes: Vec::new(),
        unsigned_tx: built.unsigned_tx,
        miner_fee,
        change_erg,
        recipient_erg,
        node_url,
    });
    serde_json::to_string(&serde_json::json!({
        "preparation_id": preparation_id,
        "recipient": recipient_address,
        "change_address": change_address,
        "amount_nano_erg": recipient_erg,
        "miner_fee": miner_fee,
        "change_nano_erg": change_erg,
        "input_count": input_count,
        "token_id": preview_token_id,
        "token_amount": preview_token_amount,
        "input_boxes": input_boxes,
        "babel": babel.as_ref().map(babel_json),
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// A send that [`prepare_registered_send`] prepared: its id for `send_erg`, the
/// transaction, and the figures for the confirmation. Not part of the Dart API.
#[flutter_rust_bridge::frb(ignore)]
pub(crate) struct RegisteredSend {
    pub preparation_id: u64,
    pub unsigned_tx: ergo_tx::Eip12UnsignedTx,
    pub miner_fee: i64,
    pub change_erg: i64,
    pub input_count: usize,
}

/// Prepare a send of ERG with `registers` on the recipient output (the Celaut deposit,
/// milestone M3). Automatic coin selection, the default fee, no babel box. Confirm with
/// `send_erg`, as a preparation of `prepare_send`.
#[allow(clippy::too_many_arguments)]
pub(crate) async fn prepare_registered_send(
    handle_id: u64,
    sender_address: &str,
    spend_addresses: &[String],
    change_address: &str,
    recipient_address: &str,
    amount_nano_erg: i64,
    registers: &HashMap<String, String>,
    node_url: Option<String>,
) -> Result<RegisteredSend, String> {
    let (_, ergo_boxes, built, _) = prepare(
        handle_id,
        sender_address,
        spend_addresses,
        change_address,
        recipient_address,
        amount_nano_erg,
        None,
        None,
        node_url.clone(),
        None,
        None,
        None,
        registers,
    )
    .await
    .map_err(|e| mempool::explain_for(handle_id, false, e))?;
    let unsigned_tx = built.unsigned_tx.clone();
    let preparation_id = store_preparation(CachedPreparation {
        handle_id,
        ergo_boxes,
        data_input_boxes: Vec::new(),
        unsigned_tx: built.unsigned_tx,
        miner_fee: built.summary.miner_fee,
        change_erg: built.summary.change_erg,
        recipient_erg: built.summary.recipient_erg,
        node_url,
    });
    Ok(RegisteredSend {
        preparation_id,
        unsigned_tx,
        miner_fee: built.summary.miner_fee,
        change_erg: built.summary.change_erg,
        input_count: built.summary.input_count,
    })
}

/// Whether the preparation is still waiting: `send_erg` and `sign_preparation` take it,
/// and a newer preparation of the same wallet replaces it.
pub(crate) fn preparation_waits(preparation_id: u64) -> bool {
    recover(PREPARATIONS.lock()).contains_key(&preparation_id)
}

/// Drop a preparation that the user did not confirm.
pub(crate) fn drop_preparation(preparation_id: u64) {
    recover(PREPARATIONS.lock()).remove(&preparation_id);
}

/// Issue a token (EIP-4): mint `amount` units named `name` into a box of
/// this wallet's `change_address`, with `description` and `decimals`.
/// For an NFT pass `nft_kind` (`picture`, `audio`, `video`), the SHA-256
/// of the content as hex, and its link; amount must be 1 and decimals 0.
/// Confirm with `send_erg`. The token id is known before signing.
#[flutter_rust_bridge::frb]
#[allow(clippy::too_many_arguments)]
pub async fn prepare_mint(
    handle_id: u64,
    sender_address: String,
    spend_addresses: Vec<String>,
    change_address: String,
    name: String,
    description: String,
    decimals: u8,
    amount: u64,
    nft_kind: Option<String>,
    nft_content_hash_hex: Option<String>,
    nft_url: Option<String>,
    node_url: Option<String>,
    fee_nano: Option<i64>,
) -> Result<String, String> {
    let nft = match nft_kind.as_deref().filter(|k| !k.is_empty()) {
        Some(kind) => Some(ergo_tx::NftDetails {
            kind: ergo_tx::NftKind::parse(kind).ok_or_else(|| {
                ArgusError::TxBuildFailed(format!("unknown NFT kind {kind:?}")).to_json_string()
            })?,
            content_hash: hex::decode(nft_content_hash_hex.unwrap_or_default())
                .map_err(|e| ArgusError::TxBuildFailed(format!("content hash: {e}")).to_json_string())?,
            url: nft_url.unwrap_or_default(),
        }),
        None => None,
    };
    let spec = ergo_tx::MintSpec {
        name,
        description,
        decimals,
        amount,
        nft,
    };
    let miner_fee = checked_miner_fee(fee_nano)?;
    let user_tree = with_handle(handle_id, "prepare_mint", |h| {
        if !h.owns_address(&change_address).map_err(err_str)? {
            return Err(ArgusError::InvalidAddress("the token box must go to this wallet".into()).to_json_string());
        }
        address_to_ergo_tree(&change_address).map_err(|e| ArgusError::InvalidAddress(e).to_json_string())
    })?;
    let spend = resolve_spend_addresses(&sender_address, &spend_addresses);
    let client = node_client(node_url.clone()).await?;
    let height = client
        .current_height()
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    let (boxes, utxos) = gather_unspent(handle_id, &client, &spend).await?;
    // The token box, the change box, the miner fee.
    let required = (2 * MIN_BOX_VALUE_NANO + miner_fee) as u64;
    let selected = wallet_core::spend::select_for_send(&utxos, required, None)
        .map_err(|e| mempool::shortfall_error(handle_id, e))?;
    let built = ergo_tx::build_mint_tx(&selected.boxes, &spec, &user_tree, height as i32)
        .map_err(|e| mempool::shortfall_error(handle_id, e))?;
    let ergo_boxes = selected_ergo_boxes(&boxes, &selected.boxes);
    if ergo_boxes.len() != selected.boxes.len() {
        return Err(ArgusError::TxBuildFailed("UTXO set mismatch".into()).to_json_string());
    }
    let input_boxes = input_boxes_json(&selected.boxes);
    let summary = built.summary;
    let preparation_id = store_preparation(CachedPreparation {
        handle_id,
        ergo_boxes,
        data_input_boxes: Vec::new(),
        unsigned_tx: built.unsigned_tx,
        miner_fee: summary.miner_fee,
        change_erg: summary.change_erg,
        recipient_erg: summary.box_value,
        node_url,
    });
    serde_json::to_string(&serde_json::json!({
        "preparation_id": preparation_id,
        "token_id": summary.token_id,
        "amount": summary.amount,
        "box_value": summary.box_value,
        "miner_fee": summary.miner_fee,
        "change_nano_erg": summary.change_erg,
        "input_boxes": input_boxes,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Burn tokens: every input token not in `burns_json` (`[{"token_id":
/// "...", "amount": 5}]`) comes back to `change_address`; the named
/// amounts are left out of every output and so cease to exist. Confirm
/// with `send_erg`.
#[flutter_rust_bridge::frb]
pub async fn prepare_burn(
    handle_id: u64,
    sender_address: String,
    spend_addresses: Vec<String>,
    change_address: String,
    burns_json: String,
    node_url: Option<String>,
) -> Result<String, String> {
    let raw: Vec<serde_json::Value> = serde_json::from_str(&burns_json)
        .map_err(|e| ArgusError::SerializationError(format!("burn list: {e}")).to_json_string())?;
    let mut items: Vec<ergo_tx::BurnItem> = Vec::new();
    for b in raw {
        let token_id = b["token_id"]
            .as_str()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| ArgusError::TxBuildFailed("burn entry without token_id".into()).to_json_string())?
            .to_string();
        let amount = b["amount"]
            .as_u64()
            .filter(|n| *n > 0)
            .ok_or_else(|| ArgusError::TxBuildFailed(format!("burn amount for {token_id} must be positive")).to_json_string())?;
        items.push(ergo_tx::BurnItem { token_id, amount });
    }
    if items.is_empty() {
        return Err(ArgusError::TxBuildFailed("nothing to burn".into()).to_json_string());
    }
    let user_tree = with_handle(handle_id, "prepare_burn", |h| {
        if !h.owns_address(&change_address).map_err(err_str)? {
            return Err(ArgusError::InvalidAddress("change must go to this wallet".into()).to_json_string());
        }
        address_to_ergo_tree(&change_address).map_err(|e| ArgusError::InvalidAddress(e).to_json_string())
    })?;
    let spend = resolve_spend_addresses(&sender_address, &spend_addresses);
    let client = node_client(node_url.clone()).await?;
    let height = client
        .current_height()
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    let (boxes, utxos) = gather_unspent(handle_id, &client, &spend).await?;
    // Every box carrying a token to burn must be spent (the builder burns
    // by omission, so the whole holding passes through it), plus ERG for
    // the miner fee and a change box from wherever.
    let mut chosen: Vec<ergo_tx::Eip12InputBox> = utxos
        .iter()
        .filter(|b| b.assets.iter().any(|a| items.iter().any(|i| i.token_id.eq_ignore_ascii_case(&a.token_id))))
        .cloned()
        .collect();
    let have: i64 = chosen.iter().map(|b| b.value.parse::<i64>().unwrap_or(0)).sum();
    let need = TX_FEE_NANO + MIN_BOX_VALUE_NANO;
    if have < need {
        let more = wallet_core::spend::select_for_send(
            &utxos.iter().filter(|b| !chosen.iter().any(|c| c.box_id == b.box_id)).cloned().collect::<Vec<_>>(),
            (need - have) as u64,
            None,
        )
        .map_err(|e| mempool::shortfall_error(handle_id, e))?;
        chosen.extend(more.boxes);
    }
    let built = ergo_tx::build_multi_burn_tx(&chosen, &items, &user_tree, height as i32)
        .map_err(|e| mempool::shortfall_error(handle_id, e))?;
    let ergo_boxes = selected_ergo_boxes(&boxes, &chosen);
    if ergo_boxes.len() != chosen.len() {
        return Err(ArgusError::TxBuildFailed("UTXO set mismatch".into()).to_json_string());
    }
    let input_boxes = input_boxes_json(&chosen);
    let summary = built.summary;
    let preparation_id = store_preparation(CachedPreparation {
        handle_id,
        ergo_boxes,
        data_input_boxes: Vec::new(),
        unsigned_tx: built.unsigned_tx,
        miner_fee: summary.miner_fee,
        change_erg: summary.change_erg,
        recipient_erg: 0,
        node_url,
    });
    serde_json::to_string(&serde_json::json!({
        "preparation_id": preparation_id,
        "burned": summary.burned_tokens.iter().map(|b| serde_json::json!({"token_id": b.token_id, "amount": b.amount})).collect::<Vec<_>>(),
        "miner_fee": summary.miner_fee,
        "change_nano_erg": summary.change_erg,
        "input_boxes": input_boxes,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Prepare a UTXO consolidation transaction to merge multiple boxes into one.
#[flutter_rust_bridge::frb]
pub async fn prepare_consolidate(
    handle_id: u64,
    spend_addresses: Vec<String>,
    selected_box_ids: Vec<String>,
    change_address: String,
    node_url: Option<String>,
    fee_nano: Option<i64>,
) -> Result<String, String> {
    let prepared = prepare_management(
        handle_id,
        "consolidate",
        &spend_addresses,
        &selected_box_ids,
        &change_address,
        spend_addresses.join(","),
        node_url,
        fee_nano,
        |inputs, change_tree, height| {
            if inputs.len() < 2 {
                return Err(ArgusError::TxBuildFailed(
                    "Consolidation requires at least 2 input boxes".into(),
                )
                .to_json_string());
            }
            let built = ergo_tx::build_consolidate_tx(inputs, change_tree, height)
                .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;
            Ok(ManagementBuild {
                miner_fee: built.summary.miner_fee,
                change_erg: built.summary.change_erg,
                recipient_erg: 0,
                unsigned_tx: built.unsigned_tx,
                summary: built.summary,
            })
        },
    )
    .await?;
    let summary = prepared.summary;

    serde_json::to_string(&serde_json::json!({
        "preparation_id": prepared.preparation_id,
        "input_count": summary.input_count,
        "total_erg_in": summary.total_erg_in,
        "change_nano_erg": summary.change_erg,
        "token_count": summary.token_count,
        "miner_fee": summary.miner_fee,
        "input_boxes": prepared.input_boxes,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Prepare a transaction to split ERG into N equal boxes.
#[flutter_rust_bridge::frb]
pub async fn prepare_split_erg(
    handle_id: u64,
    spend_addresses: Vec<String>,
    selected_box_ids: Vec<String>,
    count: u32,
    amount_per_box_nano: i64,
    change_address: String,
    node_url: Option<String>,
    fee_nano: Option<i64>,
) -> Result<String, String> {
    let mode = ergo_tx::SplitMode::Erg {
        amount_per_box: amount_per_box_nano,
    };
    let prepared = prepare_management(
        handle_id,
        "split_erg",
        &spend_addresses,
        &selected_box_ids,
        &change_address,
        "no inputs available for split".into(),
        node_url,
        fee_nano,
        move |inputs, change_tree, height| {
            let built = ergo_tx::build_split_tx(inputs, &mode, count as usize, change_tree, height)
                .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;
            Ok(ManagementBuild {
                miner_fee: built.summary.miner_fee,
                change_erg: built.summary.change_erg,
                recipient_erg: 0,
                unsigned_tx: built.unsigned_tx,
                summary: built.summary,
            })
        },
    )
    .await?;
    let summary = prepared.summary;

    serde_json::to_string(&serde_json::json!({
        "preparation_id": prepared.preparation_id,
        "split_count": summary.split_count,
        "amount_per_box": summary.amount_per_box,
        "total_split": summary.total_split,
        "change_nano_erg": summary.change_erg,
        "miner_fee": summary.miner_fee,
        "input_boxes": prepared.input_boxes,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Prepare a transaction to split tokens into N equal boxes.
#[flutter_rust_bridge::frb]
pub async fn prepare_split_token(
    handle_id: u64,
    spend_addresses: Vec<String>,
    selected_box_ids: Vec<String>,
    token_id: String,
    count: u32,
    amount_per_box: u64,
    erg_per_box_nano: i64,
    change_address: String,
    node_url: Option<String>,
    fee_nano: Option<i64>,
) -> Result<String, String> {
    let mode = ergo_tx::SplitMode::Token {
        token_id: token_id.clone(),
        amount_per_box,
        erg_per_box: erg_per_box_nano,
    };
    let prepared = prepare_management(
        handle_id,
        "split_token",
        &spend_addresses,
        &selected_box_ids,
        &change_address,
        "no inputs available for split".into(),
        node_url,
        fee_nano,
        move |inputs, change_tree, height| {
            let built = ergo_tx::build_split_tx(inputs, &mode, count as usize, change_tree, height)
                .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;
            Ok(ManagementBuild {
                miner_fee: built.summary.miner_fee,
                change_erg: built.summary.change_erg,
                recipient_erg: 0,
                unsigned_tx: built.unsigned_tx,
                summary: built.summary,
            })
        },
    )
    .await?;
    let summary = prepared.summary;

    serde_json::to_string(&serde_json::json!({
        "preparation_id": prepared.preparation_id,
        "split_count": summary.split_count,
        "token_id": token_id,
        "amount_per_box": summary.amount_per_box,
        "total_split": summary.total_split,
        "change_nano_erg": summary.change_erg,
        "miner_fee": summary.miner_fee,
        "input_boxes": prepared.input_boxes,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Prepare a custom restructure transaction to allocate specific amounts and tokens into custom output boxes.
#[flutter_rust_bridge::frb]
pub async fn prepare_restructure(
    handle_id: u64,
    spend_addresses: Vec<String>,
    selected_box_ids: Vec<String>,
    outputs_json: String,
    change_address: String,
    node_url: Option<String>,
    fee_nano: Option<i64>,
) -> Result<String, String> {
    let parsed_specs: Vec<serde_json::Value> =
        serde_json::from_str(&outputs_json).map_err(|e| {
            ArgusError::SerializationError(format!("Invalid outputs JSON: {e}")).to_json_string()
        })?;

    let mut specs = Vec::with_capacity(parsed_specs.len());
    for s in parsed_specs {
        let value = s["value_nano_erg"].as_i64().ok_or_else(|| {
            ArgusError::TxBuildFailed("output missing value_nano_erg".into()).to_json_string()
        })?;
        let tokens = s["tokens"]
            .as_array()
            .map(|arr| {
                arr.iter()
                    .filter_map(|t| {
                        let id = t["id"].as_str()?.to_string();
                        let amt = t["amount"].as_u64()?;
                        Some((id, amt))
                    })
                    .collect()
            })
            .unwrap_or_default();
        specs.push(ergo_tx::RestructureOutputSpec { value, tokens });
    }
    let prepared = prepare_management(
        handle_id,
        "restructure",
        &spend_addresses,
        &selected_box_ids,
        &change_address,
        "no inputs available for restructure".into(),
        node_url,
        fee_nano,
        move |inputs, change_tree, height| {
            let built = ergo_tx::build_restructure_tx(inputs, &specs, change_tree, height)
                .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;
            Ok(ManagementBuild {
                miner_fee: built.summary.miner_fee,
                change_erg: built.summary.change_erg,
                recipient_erg: built.summary.allocated_erg,
                unsigned_tx: built.unsigned_tx,
                summary: built.summary,
            })
        },
    )
    .await?;
    let summary = prepared.summary;

    serde_json::to_string(&serde_json::json!({
        "preparation_id": prepared.preparation_id,
        "input_count": summary.input_count,
        "output_count": summary.output_count,
        "total_erg_in": summary.total_erg_in,
        "allocated_erg": summary.allocated_erg,
        "change_nano_erg": summary.change_erg,
        "has_change": summary.has_change,
        "miner_fee": summary.miner_fee,
        "input_boxes": prepared.input_boxes,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Storage rent per box and per prepared output; see the module docs.
pub mod storage_rent;

/// List all unspent boxes (UTXOs) for the given addresses. Returns a JSON array
/// of `InputBoxInput`-compatible objects (same shape as the `input_boxes` field
/// in `prepareSend`).
#[flutter_rust_bridge::frb]
pub async fn list_unspent_boxes(
    handle_id: u64,
    addresses: Vec<String>,
    node_url: Option<String>,
) -> Result<String, String> {
    let client = node_client(node_url).await?;
    let (_, eip12) = gather_unspent(handle_id, &client, &addresses).await?;
    let json = input_boxes_json(&eip12);
    serde_json::to_string(&json)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Reduce a prepared transaction and sign it, returning the signed transaction
/// as a `serde_json::Value`.
async fn sign_prepared_tx(
    handle_id: u64,
    prep: &CachedPreparation,
    client: &ErgoNodeClient,
    op: &'static str,
) -> Result<serde_json::Value, String> {
    let state_context = client
        .get_state_context()
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    let reduced_bytes = reduce_transaction_with_context(
        &prep.unsigned_tx,
        prep.ergo_boxes.clone(),
        prep.data_input_boxes.clone(),
        &state_context,
    )
    .map_err(|e| ArgusError::TxReductionFailed(e.to_string()).to_json_string())?;

    with_handle(handle_id, op, |handle| {
        let reduced = ReducedTransaction::sigma_parse_bytes(&reduced_bytes)
            .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())?;
        let signed_tx = handle.sign_reduced(reduced).map_err(err_str)?;
        serde_json::to_value(&signed_tx)
            .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
    })
}

#[flutter_rust_bridge::frb]
pub async fn send_erg(handle_id: u64, preparation_id: u64) -> Result<String, String> {
    let prep = take_preparation(handle_id, preparation_id)?;
    let client = node_client(prep.node_url.clone()).await?;
    let tx_json = sign_prepared_tx(handle_id, &prep, &client, "send_erg").await?;

    let tx_id = client
        .submit_transaction(&tx_json)
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())?;
    // The outputs' ids, so a caller that needs one specific box of this
    // transaction can find it by id rather than by
    // guessing from its value. Ids cover no proofs, so they match the
    // broadcast transaction; best effort, never a reason to fail a send.
    let output_box_ids: Vec<String> = ergo_tx::chain::derive_output_boxes(&prep.unsigned_tx)
        .map(|(_, outs)| outs.into_iter().map(|b| b.box_id).collect())
        .unwrap_or_default();

    // What the wallet's balance moves by once the mempool shows this
    // transaction: outputs back to us minus the inputs we spent. The app
    // shows the row and the figure at once instead of waiting for a poll.
    let wallet_delta = Some(wallet_delta_nano_erg(handle_id, &prep.unsigned_tx, &prep.ergo_boxes));

    serde_json::to_string(&serde_json::json!({
        "tx_id": tx_id,
        "preparation_id": preparation_id,
        "miner_fee": prep.miner_fee,
        "change_nano_erg": prep.change_erg,
        "amount_nano_erg": prep.recipient_erg,
        "output_box_ids": output_box_ids,
        "wallet_delta_nano_erg": wallet_delta,
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Net nanoERG change for the wallet: its outputs minus the inputs, all of
/// which a preparation spends from the wallet. Unknown ownership counts an
/// output as foreign, so the figure errs towards a larger spend.
fn wallet_delta_nano_erg(
    handle_id: u64,
    unsigned: &ergo_tx::Eip12UnsignedTx,
    inputs: &[ergo_lib::ergotree_ir::chain::ergo_box::ErgoBox],
) -> i64 {
    let spent: i64 = inputs.iter().map(|b| b.value.as_i64()).sum();
    let mut back: i64 = 0;
    for out in &unsigned.outputs {
        let owned = ergo_tx::address::ergo_tree_to_address(&out.ergo_tree)
            .ok()
            .map(|addr| {
                with_handle(handle_id, "wallet_delta", |h| {
                    h.owns_address(&addr).map_err(err_str)
                })
                .unwrap_or(false)
            })
            .unwrap_or(false);
        if owned {
            back += out.value.parse::<i64>().unwrap_or(0);
        }
    }
    back - spent
}

/// The transaction behind a preparation, summarised for a confirm sheet's
/// details: inputs, outputs by kind (recipient, change, miner fee, app
/// fee), data inputs, and the unsigned EIP-12 JSON for the user to copy.
/// Does not consume the preparation.
#[flutter_rust_bridge::frb]
pub fn preparation_details(handle_id: u64, preparation_id: u64) -> Result<String, String> {
    let (unsigned, boxes, data_inputs, miner_fee) = {
        let cache = recover(PREPARATIONS.lock());
        let p = cache
            .get(&preparation_id)
            .filter(|p| p.handle_id == handle_id)
            .ok_or_else(|| {
                ArgusError::TxBuildFailed("unknown or stale send preparation".into())
                    .to_json_string()
            })?;
        (
            p.unsigned_tx.clone(),
            p.ergo_boxes.clone(),
            p.data_input_boxes
                .iter()
                .map(|b| b.box_id().to_string())
                .collect::<Vec<_>>(),
            p.miner_fee,
        )
    };
    let tx = ergo_tx::chain::to_unsigned_transaction(&unsigned)
        .map_err(|e| ArgusError::TxBuildFailed(e).to_json_string())?;
    let input_boxes: Vec<Option<serde_json::Value>> =
        boxes.iter().map(|b| serde_json::to_value(b).ok()).collect();
    let mut summary = with_handle(handle_id, "preparation_details", |h| {
        Ok(crate::api_ergopay_impl::summarize_unsigned(
            &tx,
            &|addr| h.owns_address(addr).unwrap_or(false),
            &input_boxes,
        ))
    })?;
    summary["unsigned_tx"] = serde_json::to_value(&unsigned)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())?;
    summary["data_inputs"] = serde_json::json!(data_inputs);
    summary["miner_fee_nano_erg"] = serde_json::json!(miner_fee);
    Ok(summary.to_string())
}

/// Sign a prepared transaction without submitting it. Returns the raw signed
/// transaction as an EIP-12 JSON string. Use this for air-gapped / raw-tx
/// export workflows.
#[flutter_rust_bridge::frb]
pub async fn sign_preparation(handle_id: u64, preparation_id: u64) -> Result<String, String> {
    let prep = take_preparation(handle_id, preparation_id)?;
    let client = node_client(prep.node_url.clone()).await?;
    let tx_json = sign_prepared_tx(handle_id, &prep, &client, "sign_preparation").await?;
    serde_json::to_string(&tx_json)
        .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// A single parsed recipient for a multi-recipient send.
struct ParsedRecipient {
    address: String,
    amount_nano_erg: i64,
    tokens: Vec<(String, u64)>,
}

#[cfg(test)]
#[path = "send_funding_tests.rs"]
mod send_funding_tests;

/// Prepare a multi-recipient send. Each element of `recipients_json` is a JSON
/// object: `{"address":"...","amount_nano_erg":123,"tokens":[{"token_id":"...","amount":456}]}`;
/// a single `token_id`/`token_amount` pair is accepted too.
/// At least one recipient must carry ERG or tokens. The change goes to
/// `change_address`. Supports all `prepare_send` options (fee_nano, etc.).
#[flutter_rust_bridge::frb]
pub async fn prepare_send_multi(
    handle_id: u64,
    sender_address: String,
    spend_addresses: Vec<String>,
    change_address: String,
    recipients_json: String,
    node_url: Option<String>,
    fee_nano: Option<i64>,
    input_box_ids: Option<Vec<String>>,
    babel_token_id: Option<String>,
) -> Result<String, String> {
    let change_tree = address_to_ergo_tree(&change_address)
        .map_err(|e| ArgusError::InvalidAddress(e).to_json_string())?;

    if fee_nano.unwrap_or(TX_FEE_NANO) < TX_FEE_NANO {
        return Err(ArgusError::TxBuildFailed(format!(
            "custom fee is below minimum {TX_FEE_NANO}"
        ))
        .to_json_string());
    }

    let recipients: Vec<serde_json::Value> =
        serde_json::from_str(&recipients_json).map_err(|e| {
            ArgusError::SerializationError(format!("Invalid recipients JSON: {e}")).to_json_string()
        })?;

    if recipients.is_empty() {
        return Err(
            ArgusError::TxBuildFailed("at least one recipient is required".into()).to_json_string(),
        );
    }

    let mut parsed: Vec<ParsedRecipient> = Vec::new();
    let mut total_send_erg: i64 = 0;
    for rcpt in recipients {
        let addr = rcpt["address"].as_str().ok_or_else(|| {
            ArgusError::TxBuildFailed("recipient missing address".into()).to_json_string()
        })?;
        let tokens = parse_recipient_tokens(&rcpt)?;
        let mut amount = match rcpt.get("amount_nano_erg") {
            None | Some(serde_json::Value::Null) => 0,
            Some(value) => value.as_i64().ok_or_else(|| {
                ArgusError::TxBuildFailed("recipient amount_nano_erg must be an integer".into())
                    .to_json_string()
            })?,
        };
        if !tokens.is_empty() {
            if amount < MIN_BOX_VALUE_NANO {
                amount = MIN_BOX_VALUE_NANO;
            }
        } else if amount < MIN_BOX_VALUE_NANO {
            return Err(ArgusError::TxBuildFailed(format!(
                "recipient {} amount must be at least {MIN_BOX_VALUE_NANO} nanoERG or carry tokens",
                addr
            ))
            .to_json_string());
        }
        total_send_erg = total_send_erg.checked_add(amount).ok_or_else(|| {
            ArgusError::TxBuildFailed("recipient total amount out of range".into()).to_json_string()
        })?;
        parsed.push(ParsedRecipient {
            address: addr.to_string(),
            amount_nano_erg: amount,
            tokens,
        });
    }

    let has_sent_tokens = parsed.iter().any(|rcpt| !rcpt.tokens.is_empty());
    if total_send_erg <= 0 && !has_sent_tokens {
        return Err(ArgusError::TxBuildFailed(
            "at least one recipient must receive ERG or tokens".into(),
        )
        .to_json_string());
    }

    // Size-based box floors may exceed the usual 0.001 ERG, or a token
    // bundle may need several outputs. Fund the actual layout before input
    // selection; the confirmation summary includes this normalized amount.
    let mut recipient_specs: Vec<ergo_tx::RecipientSpec> = Vec::new();
    total_send_erg = 0;
    for rcpt in &mut parsed {
        let tree = address_to_ergo_tree(&rcpt.address)
            .map_err(|e| ArgusError::InvalidAddress(e).to_json_string())?;
        let mut spec = ergo_tx::RecipientSpec {
            ergo_tree: tree,
            amount_nano_erg: rcpt.amount_nano_erg,
            tokens: rcpt.tokens.clone(),
        };
        let minimum = spec
            .minimum_value()
            .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;
        let minimum = i64::try_from(minimum).map_err(|_| {
            ArgusError::TxBuildFailed("recipient funding out of range".into()).to_json_string()
        })?;
        if !rcpt.tokens.is_empty() {
            rcpt.amount_nano_erg = rcpt.amount_nano_erg.max(minimum);
            spec.amount_nano_erg = rcpt.amount_nano_erg;
        }
        total_send_erg = total_send_erg
            .checked_add(rcpt.amount_nano_erg)
            .ok_or_else(|| {
                ArgusError::TxBuildFailed("recipient total amount out of range".into())
                    .to_json_string()
            })?;
        recipient_specs.push(spec);
    }

    with_handle(handle_id, "prepare_send_multi", |h| {
        if !h.owns_address(&change_address).map_err(err_str)? {
            return Err(ArgusError::InvalidAddress(
                "change is not an address of this wallet".into(),
            )
            .to_json_string());
        }
        Ok(())
    })?;

    let spend = resolve_spend_addresses(&sender_address, &spend_addresses);
    let client = node_client(node_url.clone()).await?;
    let (mut boxes, eip12) = gather_unspent(handle_id, &client, &spend).await?;
    let hand_picked = input_box_ids.as_ref().is_some_and(|ids| !ids.is_empty());
    if eip12.is_empty() {
        let error = ArgusError::NoUtxos(spend.join(",")).to_json_string();
        return Err(mempool::explain_for(handle_id, hand_picked, error));
    }

    // Collect tokens we need to cover
    let mut needed_tokens: HashMap<String, u64> = HashMap::new();
    for rcpt in &parsed {
        for (id, amt) in &rcpt.tokens {
            let entry = needed_tokens.entry(id.clone()).or_insert(0);
            *entry = entry.checked_add(*amt).ok_or_else(|| {
                ArgusError::TxBuildFailed("token requirement out of range".into()).to_json_string()
            })?;
        }
    }

    // For input selection we need the total ERG + all token amounts
    let fee_for_required = fee_nano.unwrap_or(TX_FEE_NANO);
    // With a babel box paying the fee, the wallet's ERG covers only the
    // recipients and a change box; the miner fee's worth of the token joins
    // what the send needs.
    let babel = match babel_token_id.as_deref().filter(|t| !t.is_empty()) {
        Some(t) => Some(find_babel(&client, t, fee_for_required).await?),
        None => None,
    };
    if let Some(pick) = &babel {
        let entry = needed_tokens
            .entry(pick.babel.token_id.clone())
            .or_insert(0);
        *entry = entry
            .checked_add(pick.babel.tokens_for(fee_for_required))
            .ok_or_else(|| {
                ArgusError::TxBuildFailed("token requirement out of range".into()).to_json_string()
            })?;
    }

    // Cover recipients, the wallet-paid miner fee and minimum change.
    let required = multi_send_required_erg(total_send_erg, fee_for_required, babel.is_some())?;
    // Coin control, as in prepare_send: the chosen boxes are the whole
    // input set, never a starting point the selector may extend.
    let select = |inputs: &[ergo_tx::Eip12InputBox],
                  required: u64|
     -> Result<Vec<ergo_tx::Eip12InputBox>, String> {
        let mut selected = match input_box_ids.as_deref() {
            Some(ids) => {
                let token_ref = needed_tokens
                    .iter()
                    .next()
                    .map(|(id, amt)| (id.as_str(), *amt));
                let exact = select_exact(inputs, ids, required, token_ref)
                    .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?;
                // Every token this send delivers must be covered by the choice.
                for (id, amount) in &needed_tokens {
                    let have: u64 = exact
                        .boxes
                        .iter()
                        .flat_map(|b| b.assets.iter())
                        .filter(|a| &a.token_id == id)
                        .map(|a| a.amount.parse::<u64>().unwrap_or(0))
                        .try_fold(0u64, u64::checked_add)
                        .ok_or_else(|| {
                            ArgusError::TxBuildFailed("token total out of range".into())
                                .to_json_string()
                        })?;
                    if have < *amount {
                        return Err(ArgusError::TxBuildFailed(format!(
                            "the chosen boxes hold {have} of token {id}, this send needs {amount}"
                        ))
                        .to_json_string());
                    }
                }
                exact.boxes
            }
            None => select_for_multi_send(inputs, required, &needed_tokens)
                .map_err(|e| ArgusError::TxBuildFailed(e.to_string()).to_json_string())?,
        };

        if selected.is_empty() {
            return Err(ArgusError::NoUtxos(spend.join(",")).to_json_string());
        }
        if let Some(pick) = &babel {
            selected.push(pick.eip12.clone());
        }
        Ok(selected)
    };

    let height = client
        .current_height()
        .await
        .map_err(|e| ArgusError::NodeError(e).to_json_string())? as i32;

    let build = |inputs: &[ergo_tx::Eip12InputBox]| {
        build_funded_multi_send(
            &recipient_specs,
            &change_tree,
            fee_for_required,
            height,
            required,
            input_box_ids.is_none(),
            babel.as_ref().map(|pick| &pick.babel),
            |budget| select(inputs, budget),
        )
    };
    let (selected, built, babel_summary) =
        build(&eip12).map_err(|e| mempool::explain_for(handle_id, hand_picked, e))?;
    if let Some(pick) = &babel {
        boxes.push(pick.ergo_box.clone());
    }
    let miner_fee = built.summary.miner_fee;
    let unsigned_tx = built.unsigned_tx;
    let change_erg = built.summary.change_erg;

    // Get the ErgoBox representations for signing
    let ergo_boxes = selected_ergo_boxes(&boxes, &selected);
    if ergo_boxes.len() != selected.len() {
        return Err(ArgusError::TxBuildFailed("UTXO set mismatch".into()).to_json_string());
    }

    let input_boxes = input_boxes_json(&selected);
    let preparation_id = store_preparation(CachedPreparation {
        handle_id,
        ergo_boxes,
        data_input_boxes: Vec::new(),
        unsigned_tx,
        miner_fee,
        change_erg,
        recipient_erg: total_send_erg,
        node_url,
    });

    let recipient_summary: Vec<serde_json::Value> = parsed
        .iter()
        .map(|rcpt| {
            serde_json::json!({
                "address": rcpt.address,
                "amount_nano_erg": rcpt.amount_nano_erg,
                "token_id": rcpt.tokens.first().map(|(id, _)| id),
                "token_amount": rcpt.tokens.first().map(|(_, amt)| amt),
                "tokens": rcpt.tokens.iter().map(|(id, amt)| serde_json::json!({"token_id": id, "amount": amt})).collect::<Vec<_>>(),
            })
        })
        .collect();

    serde_json::to_string(&serde_json::json!({
        "preparation_id": preparation_id,
        "recipients": recipient_summary,
        "recipient": parsed[0].address,
        "change_address": change_address,
        "total_amount_nano_erg": total_send_erg,
        "amount_nano_erg": total_send_erg,
        "miner_fee": miner_fee,
        "change_nano_erg": change_erg,
        "input_count": selected.len(),
        "input_boxes": input_boxes,
        "babel": babel_summary.as_ref().map(babel_json),
    }))
    .map_err(|e| ArgusError::SerializationError(e.to_string()).to_json_string())
}

/// Select again only when the actual token-change layout needs more ERG.
/// Coin control calls this with top-up disabled, so no unchosen input can
/// enter a prepared transaction. The final input set is exactly the set
/// reviewed and signed.
fn build_funded_multi_send(
    recipients: &[ergo_tx::RecipientSpec],
    change_tree: &str,
    fee: i64,
    height: i32,
    mut required: u64,
    allow_top_up: bool,
    babel: Option<&ergo_tx::BabelBox>,
    mut select: impl FnMut(u64) -> Result<Vec<ergo_tx::Eip12InputBox>, String>,
) -> Result<
    (
        Vec<ergo_tx::Eip12InputBox>,
        ergo_tx::MultiSendBuildResult,
        Option<ergo_tx::BabelSummary>,
    ),
    String,
> {
    for pass in 1..=ergo_tx::MAX_SELECTION_PASSES {
        let selected = select(required)?;
        let mut built = match ergo_tx::build_multi_send_tx_with_fee(
            &selected,
            recipients,
            change_tree,
            fee,
            height,
        ) {
            Ok(built) => built,
            Err(ergo_tx::MultiSendError::TokenChangeInsufficientErg { have, min })
                if allow_top_up && pass < ergo_tx::MAX_SELECTION_PASSES && min > have =>
            {
                required = add_change_shortfall(required, have, min)?;
                continue;
            }
            Err(error) => return Err(ArgusError::TxBuildFailed(error.to_string()).to_json_string()),
        };
        let babel_summary = if let Some(babel) = babel {
            let start = built.summary.recipient_output_count;
            let old_change_count = built.summary.change_output_count;
            let old_outputs = built.unsigned_tx.outputs.len();
            match ergo_tx::babel::apply_babel_to_change_outputs(
                &mut built.unsigned_tx,
                babel,
                change_tree,
                start..start + old_change_count,
            ) {
                Ok(summary) => {
                    built.summary.change_erg = built
                        .summary
                        .change_erg
                        .checked_sub(babel.value - built.summary.miner_fee)
                        .ok_or_else(|| {
                            ArgusError::TxBuildFailed("change amount out of range".into())
                                .to_json_string()
                        })?;
                    built.summary.change_output_count =
                        built.unsigned_tx.outputs.len() - (old_outputs - old_change_count + 1);
                    Some(summary)
                }
                Err(ergo_tx::BabelError::ChangeNeedsErg { have, min })
                    if allow_top_up && pass < ergo_tx::MAX_SELECTION_PASSES && min > have =>
                {
                    required = add_change_shortfall(required, have, min)?;
                    continue;
                }
                Err(error) => {
                    return Err(ArgusError::TxBuildFailed(error.to_string()).to_json_string())
                }
            }
        } else {
            None
        };
        return Ok((selected, built, babel_summary));
    }
    unreachable!("the final selection pass returns a build or an error")
}

fn add_change_shortfall(required: u64, have: i64, min: i64) -> Result<u64, String> {
    min.checked_sub(have)
        .and_then(|v| u64::try_from(v).ok())
        .and_then(|extra| required.checked_add(extra))
        .ok_or_else(|| {
            ArgusError::TxBuildFailed("change funding out of range".into()).to_json_string()
        })
}

fn multi_send_required_erg(total_send_erg: i64, miner_fee: i64, babel: bool) -> Result<u64, String> {
    i64::checked_add(total_send_erg, if babel { 0 } else { miner_fee })
        .and_then(|v| v.checked_add(MIN_BOX_VALUE_NANO))
        .filter(|v| *v > 0)
        .map(|v| v as u64)
        .ok_or_else(|| {
            ArgusError::TxBuildFailed("recipient total amount out of range".into()).to_json_string()
        })
}

/// Select UTXOs that collectively hold enough ERG and tokens for a multi-send.
fn select_for_multi_send(
    eip12: &[ergo_tx::Eip12InputBox],
    required_erg: u64,
    needed_tokens: &HashMap<String, u64>,
) -> Result<Vec<ergo_tx::Eip12InputBox>, String> {
    if needed_tokens.is_empty() {
        return wallet_core::spend::select_for_send(eip12, required_erg, None)
            .map(|s| s.boxes)
            .map_err(|e| e.to_string());
    }
    // Avoid moving unrelated collectibles when eligible funding can cover
    // the send. Both passes share the same oldest-first selector.
    let safe = eip12
        .iter()
        .filter(|b| {
            b.assets.is_empty()
                || b.assets
                    .iter()
                    .any(|a| needed_tokens.contains_key(&a.token_id))
        })
        .cloned()
        .collect::<Vec<_>>();
    let mut tokens = needed_tokens
        .iter()
        .map(|(id, amount)| (id.as_str(), *amount))
        .collect::<Vec<_>>();
    tokens.sort_by_key(|(id, _)| *id);
    let selected = match ergo_tx::select_multi_token_boxes(&safe, &tokens, required_erg) {
        Err(ergo_tx::BoxSelectorError::InsufficientErg { .. }) => {
            ergo_tx::select_multi_token_boxes(eip12, &tokens, required_erg)
        }
        result => result,
    };
    selected.map(|s| s.boxes).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    mod concurrent_gather;
    mod selected_lookup;

    #[test]
    fn multi_send_budget_is_the_amount_the_miner_fee_and_a_change_box() {
        let amount = 2_000_000_000;
        let required = multi_send_required_erg(amount, TX_FEE_NANO, false).unwrap();
        assert_eq!(required, (amount + TX_FEE_NANO + MIN_BOX_VALUE_NANO) as u64);
        assert_eq!(
            multi_send_required_erg(amount, TX_FEE_NANO, true).unwrap(),
            required - TX_FEE_NANO as u64,
        );
        assert!(multi_send_required_erg(i64::MAX, TX_FEE_NANO, false).is_err());
    }

    #[test]
    fn a_recipients_token_shapes_are_alternatives_not_a_sum() {
        // The app writes both shapes when a recipient gets one token, so
        // that the single-recipient path can read the pair. Reading both
        // would send twice what was asked for.
        let both = serde_json::json!({
            "address": "9x",
            "tokens": [{"token_id": "tok_a", "amount": 250}],
            "token_id": "tok_a",
            "token_amount": 250,
        });
        assert_eq!(
            parse_recipient_tokens(&both).unwrap(),
            vec![("tok_a".to_string(), 250)]
        );
        // Several tokens in one box come through in order.
        let many = serde_json::json!({
            "tokens": [{"token_id": "tok_a", "amount": 1}, {"token_id": "tok_b", "amount": 2}],
            "token_id": "tok_a",
            "token_amount": 1,
        });
        assert_eq!(
            parse_recipient_tokens(&many).unwrap(),
            vec![("tok_a".to_string(), 1), ("tok_b".to_string(), 2)]
        );
        // The pair alone still works, and no tokens at all is fine.
        let pair = serde_json::json!({"token_id": "tok_a", "token_amount": 7});
        assert_eq!(
            parse_recipient_tokens(&pair).unwrap(),
            vec![("tok_a".to_string(), 7)]
        );
        assert!(parse_recipient_tokens(&serde_json::json!({"address": "9x"}))
            .unwrap()
            .is_empty());
        assert!(parse_recipient_tokens(&serde_json::json!({"tokens": []}))
            .unwrap()
            .is_empty());
        // A half-written pair is still refused rather than dropped.
        assert!(parse_recipient_tokens(&serde_json::json!({"token_id": "tok_a"})).is_err());
        assert!(parse_recipient_tokens(&serde_json::json!({
            "tokens": [{"token_id": "tok_a"}]
        }))
        .is_err());
    }

    #[test]
    fn checked_miner_fee_defaults_and_refuses_below_the_minimum() {
        assert_eq!(checked_miner_fee(None).unwrap(), TX_FEE_NANO);
        assert_eq!(
            checked_miner_fee(Some(TX_FEE_NANO + 1)).unwrap(),
            TX_FEE_NANO + 1
        );
        assert!(checked_miner_fee(Some(TX_FEE_NANO - 1)).is_err());
        assert!(checked_miner_fee(Some(-1)).is_err());
    }

    const APPKIT: &str = "slow silly start wash bundle suffer bulb ancient height spin express remind today effort helmet";

    #[test]
    fn generate_mnemonic_supports_the_15_word_ergo_standard() {
        let phrase = generate_mnemonic(160).expect("160-bit generation must work");
        let n = phrase.split_whitespace().count();
        assert_eq!(n, 15, "160-bit entropy must yield 15 words, got {n}");
        wallet_core::bip39::validate_phrase(&phrase)
            .expect("generated 15-word phrase must pass validation");
    }

    #[test]
    fn generate_mnemonic_covers_every_bip39_strength() {
        for (strength, words) in [(128u32, 12usize), (192, 18), (224, 21), (256, 24)] {
            let phrase = generate_mnemonic(strength)
                .unwrap_or_else(|e| panic!("{strength}-bit generation failed: {e}"));
            assert_eq!(
                phrase.split_whitespace().count(),
                words,
                "{strength}-bit entropy must yield {words} words"
            );
        }
        assert!(
            generate_mnemonic(129).is_err(),
            "unsupported strengths must be rejected, not substituted"
        );
    }

    #[test]
    fn create_restore_lock() {
        let session: serde_json::Value =
            serde_json::from_str(&wallet_create(APPKIT.to_string(), "".into()).unwrap()).unwrap();
        let handle_id: u64 = session["handle_id"].as_str().unwrap().parse().unwrap();
        assert!(wallet_is_unlocked(handle_id).unwrap());
        let addr = derive_address(handle_id, 0).unwrap();
        assert_eq!(addr, "9eatpGQdYNjTi5ZZLK7Bo7C3ms6oECPnxbQTRn6sDcBNLMYSCa8");

        let blob = session["encrypted_seed_json"].as_str().unwrap().to_string();
        let wrap_key = session["wrap_key"].as_str().unwrap().to_string();
        assert!(serde_json::from_str::<serde_json::Value>(&blob)
            .unwrap()
            .get("k")
            .is_none());
        wallet_lock(handle_id).unwrap();
        assert!(wallet_is_unlocked(handle_id).is_err());

        let restored = wallet_restore(blob, Some(wrap_key)).unwrap();
        assert_eq!(
            derive_address(restored, 0).unwrap(),
            "9eatpGQdYNjTi5ZZLK7Bo7C3ms6oECPnxbQTRn6sDcBNLMYSCa8"
        );
    }

    #[test]
    fn rejects_bad_mnemonic() {
        assert!(wallet_create("not a real mnemonic phrase at all".into(), "".into()).is_err());
    }

    #[test]
    fn generate_is_valid_bip39() {
        let phrase = generate_mnemonic(128).unwrap();
        assert_eq!(phrase.split_whitespace().count(), 12);
        assert!(MnemonicPhrase::parse(phrase).is_ok());
        let phrase24 = generate_mnemonic(256).unwrap();
        assert_eq!(phrase24.split_whitespace().count(), 24);
    }

    #[test]
    fn preparation_details_reads_without_consuming() {
        // Unknown id, or another wallet's, is refused.
        assert!(preparation_details(1, 424242).is_err());
        let id = store_preparation(CachedPreparation {
            handle_id: 5,
            ergo_boxes: Vec::new(),
            data_input_boxes: Vec::new(),
            unsigned_tx: ergo_tx::Eip12UnsignedTx {
                inputs: Vec::new(),
                data_inputs: Vec::new(),
                outputs: Vec::new(),
            },
            miner_fee: 1_100_000,
            change_erg: 0,
            recipient_erg: 0,
            node_url: None,
        });
        assert!(
            preparation_details(6, id).is_err(),
            "another wallet's preparation"
        );
        // An empty transaction cannot be converted, but the preparation must
        // still be there afterwards: details never consume.
        let _ = preparation_details(5, id);
        assert!(
            take_preparation(5, id).is_ok(),
            "still cached after details"
        );
    }

    #[test]
    fn take_preparation_rejects_unknown_stale_and_repeat() {
        assert!(take_preparation(1, 99).is_err());
        let id = store_preparation(CachedPreparation {
            handle_id: 7,
            ergo_boxes: Vec::new(),
            data_input_boxes: Vec::new(),
            unsigned_tx: ergo_tx::Eip12UnsignedTx {
                inputs: vec![],
                data_inputs: vec![],
                outputs: vec![],
            },
            miner_fee: 0,
            change_erg: 0,
            recipient_erg: 0,
            node_url: None,
        });
        assert!(take_preparation(8, id).is_err());
        assert!(take_preparation(7, id).is_ok());
        assert!(take_preparation(7, id).is_err());
    }

    #[test]
    fn spend_list_uses_all_owned_and_falls_back() {
        let many = resolve_spend_addresses(
            "9aaa",
            &["9ccc".into(), " 9bbb ".into(), "9ccc".into(), "".into()],
        );
        assert_eq!(many, vec!["9bbb", "9ccc"]);
        assert_eq!(resolve_spend_addresses("9aaa", &[]), vec!["9aaa"]);
    }

    #[test]
    fn send_token_pair_must_be_complete() {
        assert!(resolve_send_token(None, None).unwrap().is_none());
        assert_eq!(
            resolve_send_token(Some("abc".into()), Some(2)).unwrap(),
            Some(("abc".into(), 2))
        );
        assert!(resolve_send_token(Some("abc".into()), None).is_err());
        assert!(resolve_send_token(None, Some(2)).is_err());
        assert!(resolve_send_token(Some("".into()), Some(2)).is_err());
        assert!(resolve_send_token(Some("abc".into()), Some(0)).is_err());
    }

    #[test]
    fn pin_wrap_roundtrip() {
        let key = hex::encode([3u8; 32]);
        let json = wrap_key_with_pin(key.clone(), "123456".into()).unwrap();
        assert_eq!(
            unwrap_key_with_pin(json.clone(), "123456".into()).unwrap(),
            key
        );
        assert!(unwrap_key_with_pin(json, "654321".into()).is_err());
    }

    fn test_input_box(
        box_id: &str,
        value: &str,
        assets: Vec<(&str, &str)>,
    ) -> ergo_tx::Eip12InputBox {
        serde_json::from_str(
            &serde_json::json!({
                "boxId": box_id,
                "transactionId": "t",
                "index": 0,
                "value": value,
                "ergoTree": "00",
                "assets": assets.iter().map(|(id, amt)| serde_json::json!({"tokenId": id, "amount": amt})).collect::<Vec<_>>(),
                "creationHeight": 100,
                "additionalRegisters": {},
                "extension": {},
            })
            .to_string(),
        )
        .unwrap()
    }

    #[test]
    fn input_boxes_json_serializes_value_and_assets() {
        let plain = test_input_box("b1", "2700000000", vec![]);
        let nft = test_input_box("b2", "1000000", vec![("nft", "1")]);
        let arr = input_boxes_json(&[plain, nft]);
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[0]["box_id"], "b1");
        assert_eq!(arr[0]["value_nano_erg"], "2700000000");
        assert_eq!(arr[0]["creation_height"], 100);
        assert_eq!(arr[0]["assets"].as_array().unwrap().len(), 0);
        assert_eq!(arr[1]["box_id"], "b2");
        assert_eq!(arr[1]["assets"][0]["token_id"], "nft");
        assert_eq!(arr[1]["assets"][0]["amount"], "1");
    }

    #[test]
    fn selected_inputs_reject_missing_ids_and_preserve_input_order() {
        let inputs = vec![
            test_input_box("b1", "1000000", vec![]),
            test_input_box("b2", "2000000", vec![]),
            test_input_box("b3", "3000000", vec![]),
        ];
        let filtered = filter_selected_inputs(inputs.clone(), &["b3".into(), "b1".into()]).unwrap();
        assert_eq!(
            filtered
                .iter()
                .map(|input| input.box_id.as_str())
                .collect::<Vec<_>>(),
            vec!["b1", "b3"]
        );
        let error = filter_selected_inputs(inputs, &["b1".into(), "missing".into()]).unwrap_err();
        assert!(error.contains("selected UTXO(s) not found: missing"));
    }
}

#[cfg(test)]
#[path = "sync_tests.rs"]
mod sync_tests;
