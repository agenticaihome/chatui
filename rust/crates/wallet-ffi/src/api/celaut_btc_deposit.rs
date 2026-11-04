//! Deposits in BTC to a node (issue #92), with the Bitcoin wallet ([`super::btc`]).
//!
//! nodo takes BTC on-chain (`nodo:docs/BITCOIN.md`): one output to the P2WPKH script of
//! the node and the deposit token in an `OP_RETURN` output of the same transaction. The
//! node checks a payment once, and only a confirmed one, so the app calls `Payable` only
//! after [`celaut_client::BtcPayment::confirmations`] confirmations:
//!
//! 1. [`celaut_btc_deposit_node`]: does the node take BTC on the network of the wallet?
//! 2. [`celaut_btc_deposit_prepare`]: the deposit token, and the transaction (not signed).
//! 3. [`celaut_btc_deposit_send`]: the deposit is "sent" in the database before the
//!    broadcast, then it is signed and sent.
//! 4. [`celaut_btc_deposit_status`]: the confirmations, from the Esplora server of the
//!    deposit. The app asks again until there are enough.
//! 5. [`celaut_btc_deposit_notify`]: `Payable`, one time, when there are enough.
//!
//! A deposit that was sent stays in the database ([`celaut_btc_sent_deposits`]), so the
//! app can wait for it again after a restart, with the wallet locked.

use celaut_client::db::{BtcDepositRecord, DepositStage, EventKind, EventRecord};
use celaut_client::new_client_id;
use wallet_btc::bitcoin::{Address, ScriptBuf, Txid};
use wallet_btc::esplora::Esplora;

use super::btc::{BtcError, BtcErrorKind, BtcPreparedView};
use super::celaut::{error_of, invalid, CelautError, CelautErrorKind};
use super::celaut_db::{db, now_seconds, storage_error};
use super::celaut_service::{address_of_key, forget_if_broken, key, session, NodeAddress};

/// The smallest deposit, in satoshi: more than the dust limit of a P2WPKH output (294).
pub const MIN_DEPOSIT_SAT: u64 = 1000;

fn wallet_error(e: BtcError) -> CelautError {
    CelautError {
        kind: match e.kind {
            BtcErrorKind::InvalidInput | BtcErrorKind::Address => CelautErrorKind::InvalidInput,
            BtcErrorKind::Unreachable => CelautErrorKind::Unreachable,
            _ => CelautErrorKind::Wallet,
        },
        message: e.message,
    }
}

fn unknown_deposit() -> CelautError {
    invalid("This BTC deposit is not known.")
}

/// What a node takes in BTC.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcDepositNodeView {
    pub peer_id: String,
    /// The Bitcoin networks of the BTC contracts of the node (empty: no BTC).
    pub networks: Vec<String>,
    /// True if the node takes BTC on `network` (the network of the wallet).
    pub accepts: bool,
    /// Why not, in English, when `accepts` is false.
    pub reason: String,
    /// The address that receives the deposits (empty if not `accepts`).
    pub pay_to_address: String,
    /// The MU of the node for one satoshi (empty if not `accepts`).
    pub mu_per_sat: String,
    /// The confirmations that the app waits for before the node checks the deposit.
    pub confirmations: u32,
    /// True if the node said how many confirmations it wants.
    pub node_says_confirmations: bool,
    /// The balance of the client of this app on the node, in MU.
    pub client_balance_mu: String,
}

fn address_of(script: &[u8], network: &str) -> Result<String, CelautError> {
    let network = wallet_btc::BtcNetwork::from_name(network)
        .ok_or_else(|| invalid("Unknown Bitcoin network."))?;
    Address::from_script(&ScriptBuf::from_bytes(script.to_vec()), network.bitcoin())
        .map(|a| a.to_string())
        .map_err(|e| CelautError {
            kind: CelautErrorKind::Protocol,
            message: format!("the script of the node is not a Bitcoin address: {e}"),
        })
}

/// The BTC contracts of the node, and whether it takes BTC on `network`.
#[flutter_rust_bridge::frb]
pub async fn celaut_btc_deposit_node(
    node: NodeAddress,
    network: String,
) -> Result<BtcDepositNodeView, CelautError> {
    let session = session(&node).await?;
    let networks = session.btc_networks();
    let balance = match session.balance().await {
        Ok(b) => b.to_string(),
        Err(e) => {
            forget_if_broken(&node, &e);
            return Err(error_of(e));
        }
    };
    let mut view = BtcDepositNodeView {
        peer_id: session.peer_id().to_string(),
        networks,
        accepts: false,
        reason: String::new(),
        pay_to_address: String::new(),
        mu_per_sat: String::new(),
        confirmations: 0,
        node_says_confirmations: false,
        client_balance_mu: balance,
    };
    match session.btc_payment(&network) {
        Ok(btc) => {
            view.pay_to_address = address_of(&btc.script, &network)?;
            view.accepts = true;
            view.mu_per_sat = btc.mu_per_sat.to_string();
            view.confirmations = btc.confirmations();
            view.node_says_confirmations = btc.min_confirmations.is_some();
        }
        Err(e) => view.reason = e.to_string(),
    }
    Ok(view)
}

/// A BTC deposit that waits for the confirmation of the user.
#[derive(Debug, Clone, PartialEq)]
pub struct BtcDepositPreparedView {
    pub deposit_id: String,
    pub peer_id: String,
    pub pay_to_address: String,
    /// The MU that the amount buys on the node.
    pub mu: String,
    pub confirmations: u32,
    /// The transaction, for the confirmation sheet and [`celaut_btc_deposit_send`].
    pub transaction: BtcPreparedView,
}

/// Prepare a deposit of `sat` satoshi to `node` from the open Bitcoin wallet, at
/// `fee_rate` sat/vB: the deposit token of the node, then the transaction with the token
/// in an `OP_RETURN` output. Nothing is signed.
#[flutter_rust_bridge::frb]
pub async fn celaut_btc_deposit_prepare(
    handle_id: u64,
    node: NodeAddress,
    sat: u64,
    fee_rate: f64,
) -> Result<BtcDepositPreparedView, CelautError> {
    if sat < MIN_DEPOSIT_SAT {
        return Err(invalid(&format!(
            "The amount must be at least {MIN_DEPOSIT_SAT} sat."
        )));
    }
    let network = super::btc::open_network(handle_id).map_err(wallet_error)?;
    let server = super::btc::open_server(handle_id).map_err(wallet_error)?;
    let session = session(&node).await?;
    let btc = session.btc_payment(network.name()).map_err(error_of)?;
    let mu = btc.mu_for(sat).map_err(|e| error_of(e.into()))?;
    let pay_to_address = address_of(&btc.script, network.name())?;
    let token = match session.deposit_token().await {
        Ok(t) => t,
        Err(e) => {
            forget_if_broken(&node, &e);
            return Err(error_of(e));
        }
    };
    btc.payment(&token, sat).map_err(|e| error_of(e.into()))?;
    let transaction =
        super::btc::prepare_with_data(handle_id, &pay_to_address, sat, fee_rate, token.as_bytes())
            .map_err(wallet_error)?;
    let deposit_id = new_client_id().map_err(error_of)?;
    let peer_id = session.peer_id().to_string();
    let record = BtcDepositRecord {
        peer_id: peer_id.clone(),
        address: key(&node),
        deposit_token: token,
        network: network.name().to_string(),
        server: server.base().to_string(),
        sat,
        mu: mu.to_string(),
        pay_to_address: pay_to_address.clone(),
        tx_id: transaction.txid.clone(),
        confirmations: btc.confirmations(),
        made_at: now_seconds(),
        stage: DepositStage::Prepared,
    };
    let confirmations = record.confirmations;
    db().update(|d| {
        // A deposit that was prepared and never sent is dropped.
        d.btc_deposits.retain(|_, r| r.stage != DepositStage::Prepared);
        d.btc_deposits.insert(deposit_id.clone(), record);
    })
    .map_err(storage_error)?;
    Ok(BtcDepositPreparedView {
        deposit_id,
        peer_id,
        pay_to_address,
        mu: mu.to_string(),
        confirmations,
        transaction,
    })
}

/// Forget a deposit that was prepared and not sent.
#[flutter_rust_bridge::frb]
pub fn celaut_btc_deposit_cancel(deposit_id: String, prepared_id: u64) -> Result<(), CelautError> {
    super::btc::btc_cancel(prepared_id);
    db().update(|d| match d.btc_deposits.get(&deposit_id) {
        Some(r) if r.stage == DepositStage::Prepared => {
            d.btc_deposits.remove(&deposit_id);
            Ok(())
        }
        Some(_) => Err(invalid("This deposit was sent.")),
        None => Err(unknown_deposit()),
    })
    .map_err(storage_error)?
}

/// Sign and send the deposit. The deposit is "sent" in the database before the
/// broadcast, so that a stop of the app does not lose it. Gives the transaction id.
#[flutter_rust_bridge::frb]
pub async fn celaut_btc_deposit_send(
    handle_id: u64,
    deposit_id: String,
    prepared_id: u64,
) -> Result<String, CelautError> {
    let tx_id = db()
        .update(|d| match d.btc_deposits.get_mut(&deposit_id) {
            Some(r) if r.stage == DepositStage::Prepared => {
                r.stage = DepositStage::Sent {
                    tx_id: r.tx_id.clone(),
                };
                Ok(r.tx_id.clone())
            }
            Some(_) => Err(invalid("This deposit was sent.")),
            None => Err(unknown_deposit()),
        })
        .map_err(storage_error)??;
    match super::btc::btc_send(handle_id, prepared_id).await {
        Ok(sent) if sent == tx_id => Ok(sent),
        Ok(other) => Err(CelautError {
            kind: CelautErrorKind::Wallet,
            message: format!("the transaction {other} is not the transaction {tx_id} of the deposit"),
        }),
        Err(e) => {
            // Before the broadcast nothing went out: forget the deposit. After it (no answer,
            // or an answer that is not valid) the transaction can be on the network: the
            // deposit stays "sent", and [`celaut_btc_deposit_forget`] drops it if the server
            // does not know the transaction.
            let before_broadcast = !matches!(e.kind, BtcErrorKind::Unreachable | BtcErrorKind::Server);
            if before_broadcast {
                let _ = db().update(|d| {
                    d.btc_deposits.remove(&deposit_id);
                });
            }
            Err(wallet_error(e))
        }
    }
}

/// Forget a deposit that was "sent" but that the Esplora server does not know (the
/// broadcast failed). A deposit that the server knows is never forgotten.
#[flutter_rust_bridge::frb]
pub async fn celaut_btc_deposit_forget(deposit_id: String) -> Result<(), CelautError> {
    let (record, tx_id) = sent_record(&deposit_id)?;
    let (_, known) = confirmations(&record.server, &tx_id).await?;
    if known {
        return Err(invalid(
            "The server knows this transaction. Wait for its confirmations.",
        ));
    }
    db().update(|d| {
        d.btc_deposits.remove(&deposit_id);
    })
    .map_err(storage_error)
}

/// A BTC deposit that was sent and that the node did not check yet.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcDepositSentView {
    pub deposit_id: String,
    pub peer_id: String,
    pub address: String,
    pub network: String,
    pub sat: u64,
    pub mu: String,
    pub tx_id: String,
    pub confirmations: u32,
    pub made_at: i64,
}

/// The BTC deposits that were sent and that the node did not check yet, the oldest first.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_btc_sent_deposits() -> Vec<BtcDepositSentView> {
    let mut all: Vec<BtcDepositSentView> = db().read(|d| {
        d.btc_deposits
            .iter()
            .filter_map(|(id, r)| match &r.stage {
                DepositStage::Sent { tx_id } => Some(BtcDepositSentView {
                    deposit_id: id.clone(),
                    peer_id: r.peer_id.clone(),
                    address: r.address.clone(),
                    network: r.network.clone(),
                    sat: r.sat,
                    mu: r.mu.clone(),
                    tx_id: tx_id.clone(),
                    confirmations: r.confirmations,
                    made_at: r.made_at,
                }),
                _ => None,
            })
            .collect()
    });
    all.sort_by_key(|d| d.made_at);
    all
}

/// The confirmations of a deposit transaction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BtcDepositStatusView {
    /// 0 while the transaction is in the mempool.
    pub confirmations: u32,
    /// What the app waits for before the node checks it.
    pub needed: u32,
    /// False if the server does not know the transaction (not sent, or dropped).
    pub known: bool,
}

fn sent_record(deposit_id: &str) -> Result<(BtcDepositRecord, String), CelautError> {
    let record = db()
        .read(|d| d.btc_deposits.get(deposit_id).cloned())
        .ok_or_else(unknown_deposit)?;
    match &record.stage {
        DepositStage::Sent { tx_id } => {
            let tx_id = tx_id.clone();
            Ok((record, tx_id))
        }
        DepositStage::Prepared => Err(invalid("This deposit was not sent yet.")),
        DepositStage::PayableCalled { .. } => Err(invalid("The node already checked this deposit.")),
    }
}

async fn confirmations(server: &str, tx_id: &str) -> Result<(u32, bool), CelautError> {
    let unreachable = |e: wallet_btc::esplora::EsploraError| CelautError {
        kind: CelautErrorKind::Unreachable,
        message: e.to_string(),
    };
    let esplora = Esplora::new(server).map_err(unreachable)?;
    let txid: Txid = tx_id
        .parse()
        .map_err(|_| invalid("The transaction id is not valid."))?;
    let status = match esplora.tx_status(&txid).await {
        Ok(s) => s,
        Err(wallet_btc::esplora::EsploraError::Status { status: 404, .. }) => return Ok((0, false)),
        Err(e) => return Err(unreachable(e)),
    };
    let Some(height) = status.block_height.filter(|_| status.confirmed) else {
        return Ok((0, true));
    };
    let tip = esplora.tip_height().await.map_err(unreachable)?;
    Ok((tip.saturating_sub(height) + 1, true))
}

/// The confirmations of the deposit, from the Esplora server of the deposit. The wallet
/// can be locked.
#[flutter_rust_bridge::frb]
pub async fn celaut_btc_deposit_status(deposit_id: String) -> Result<BtcDepositStatusView, CelautError> {
    let (record, tx_id) = sent_record(&deposit_id)?;
    let (confirmations, known) = confirmations(&record.server, &tx_id).await?;
    Ok(BtcDepositStatusView {
        confirmations,
        needed: record.confirmations,
        known,
    })
}

/// The end of a BTC deposit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtcDepositDoneView {
    pub deposit_id: String,
    pub tx_id: String,
    pub accepted: bool,
    /// The answer of the node if it refused the payment.
    pub node_message: Option<String>,
    /// The balance of the client on the node after `Payable`, in MU (empty if unknown).
    pub client_balance_mu: String,
}

/// `Payable`, one time, if the deposit has its confirmations. With fewer, nothing is sent
/// to the node: the node would refuse the token for good.
#[flutter_rust_bridge::frb]
pub async fn celaut_btc_deposit_notify(deposit_id: String) -> Result<BtcDepositDoneView, CelautError> {
    let (record, tx_id) = sent_record(&deposit_id)?;
    let (have, _) = confirmations(&record.server, &tx_id).await?;
    if have < record.confirmations {
        return Err(CelautError {
            kind: CelautErrorKind::Timeout,
            message: format!(
                "the deposit has {have} of {} confirmations. Nothing was sent to the node.",
                record.confirmations
            ),
        });
    }
    let node = address_of_key(&record.address).ok_or_else(|| CelautError {
        kind: CelautErrorKind::Storage,
        message: format!("the address of the node is not valid: {}", record.address),
    })?;
    let session = session(&node).await?;
    if session.peer_id() != record.peer_id {
        return Err(CelautError {
            kind: CelautErrorKind::IdentityMismatch,
            message: format!(
                "the node at {} is now {}, not the node of the deposit {}. Nothing was sent \
                 to the node.",
                record.address,
                session.peer_id(),
                record.peer_id
            ),
        });
    }
    let payment = session
        .btc_payment(&record.network)
        .and_then(|btc| Ok(btc.payment(&record.deposit_token, record.sat)?))
        .map_err(error_of)?;

    // One attempt only: the stage changes in the database before the call.
    db().update(|d| match d.btc_deposits.get_mut(&deposit_id) {
        Some(r) if matches!(r.stage, DepositStage::Sent { .. }) => {
            r.stage = DepositStage::PayableCalled {
                tx_id: tx_id.clone(),
                accepted: false,
            };
            Ok(())
        }
        Some(_) => Err(invalid("The node already checked this deposit.")),
        None => Err(unknown_deposit()),
    })
    .map_err(storage_error)??;
    let (accepted, node_message) = match session.payable(&payment).await {
        Ok(()) => (true, None),
        Err(e) => {
            forget_if_broken(&node, &e);
            (false, Some(e.to_string()))
        }
    };
    let logged = db().update(|d| {
        if let Some(r) = d.btc_deposits.get_mut(&deposit_id) {
            r.stage = DepositStage::PayableCalled {
                tx_id: tx_id.clone(),
                accepted,
            };
        }
        if accepted {
            if let (Some(node), Ok(mu)) = (d.nodes.get_mut(&record.peer_id), record.mu.parse()) {
                node.add_paid(mu);
            }
        }
        d.add_event(EventRecord {
            peer_id: record.peer_id.clone(),
            kind: if accepted {
                EventKind::PaymentCommunicated
            } else {
                EventKind::PaymentNotAcknowledged
            },
            at: now_seconds(),
        });
    });
    if let Err(e) = logged {
        tracing::warn!("the answer of the node to the BTC deposit is not stored: {e}");
    }
    let client_balance_mu = session
        .balance()
        .await
        .map(|b| b.to_string())
        .unwrap_or_default();
    Ok(BtcDepositDoneView {
        deposit_id,
        tx_id,
        accepted,
        node_message,
        client_balance_mu,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn script_to_address() {
        let script = hex::decode("0014c0cebcd6c3d3ca8c75dc5ec62ebe55330ef910e2").unwrap();
        assert_eq!(
            address_of(&script, "mainnet").unwrap(),
            "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
        );
        assert!(address_of(&script, "signet").unwrap().starts_with("tb1q"));
        assert!(address_of(&script, "regtest").unwrap().starts_with("bcrt1q"));
        assert!(address_of(&script, "dogecoin").is_err());
    }

    #[test]
    fn unknown_deposits() {
        assert_eq!(
            celaut_btc_deposit_cancel("nope".into(), 1).unwrap_err().kind,
            CelautErrorKind::InvalidInput
        );
        assert!(sent_record("nope").is_err());
    }
}
