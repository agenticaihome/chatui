//! Deposits in ERG on the Ergo ledger (milestone M3).
//!
//! The steps (`docs/celaut/wire.md`, section 4):
//!
//! 1. [`ErgPayment::of`]: the ERG payment contract of the checked advertisement.
//! 2. `GenerateDepositToken` ([`crate::NodeSession::deposit_token`]).
//! 3. The wallet makes a transaction with one output to [`ErgPayment::script`], with the
//!    amount in nanoERG or more, and the token in R4 as `Coll[Byte]` of its UTF-8 bytes.
//! 4. Wait until the explorer of the node shows that box unspent ([`find_deposit_box`]).
//!    The box can be in the mempool.
//! 5. `Payable` once ([`crate::NodeSession::payable`]) with [`ErgPayment::payment`]: the
//!    contract goes back to the node without a change.
//!
//! Deposits in BTC (issue #92) follow the same steps with [`BtcPayment`]: one output to
//! the P2WPKH `script` of the node, the token in an `OP_RETURN` output of the same
//! transaction, and `Payable` once only after the transaction has the confirmations that
//! the node wants (`nodo:docs/BITCOIN.md`). The node checks a payment one time: a call
//! before that depth makes it refuse the token, and the bitcoin stays with the node.
//!
//! This module makes no transaction and no HTTP call. The wallet and the app do that.

use celaut_balancer::amount;
use celaut_proto::celaut::{Amount, Contract, Payment, Peer};

/// The explorer that a node uses: the default of Ergo AppKit for mainnet. The node looks
/// for the deposit box there. A node does not advertise its explorer, so the app uses
/// this one, fixed.
pub const NODO_DEFAULT_EXPLORER: &str = "https://api.ergoplatform.com";

/// The longest deposit token that this client puts in a register. A node gives the
/// 36 characters of a UUID4.
pub const MAX_DEPOSIT_TOKEN_LEN: usize = 64;

/// Why a deposit cannot be made.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum DepositError {
    /// The node gives no payment contract on the ledger `ergo` with the asset `ERG`.
    #[error("the node gives no ERG payment contract")]
    NoErgContract,
    /// The ERG contract has no `script` attribute.
    #[error("the ERG payment contract of the node has no script")]
    NoScript,
    /// The ledger of the contract is not Ergo mainnet, the network of this wallet.
    #[error("the ERG payment contract of the node is not on Ergo mainnet: {0}")]
    NotMainnet(String),
    /// The contract binds the deposit token in a way that this client does not make.
    #[error("the node binds the deposit token in a way that this app does not know: {0}")]
    UnknownBinding(String),
    /// The amount is 0, or too large for the node.
    #[error("the amount of the deposit is not usable: {0}")]
    BadAmount(String),
    /// The deposit token from the node is not one that this client writes on a ledger.
    #[error("the deposit token from the node is not usable: {0}")]
    BadToken(String),
    /// The node gives no payment contract on the ledger `bitcoin` with the asset `BTC`.
    #[error("the node gives no BTC payment contract")]
    NoBtcContract,
    /// The BTC contract of the node is on another Bitcoin network than the wallet.
    #[error("the BTC payment contract of the node is on {node}, not on {wallet}")]
    OtherNetwork { node: String, wallet: String },
    /// The BTC contract is not a P2WPKH script, the only kind that this client pays.
    #[error("the BTC payment contract of the node is not P2WPKH: {0}")]
    NotP2wpkh(String),
}

/// The ERG payment contract of a node.
#[derive(Debug, Clone, PartialEq)]
pub struct ErgPayment {
    /// The contract as the node advertised it. `Payable` sends it back without a change:
    /// the node compares its ledger declaration and selects the payment method with it.
    pub contract: Contract,
    /// The script that receives the payment (attribute `script`): the ErgoTree bytes.
    pub script: Vec<u8>,
    /// The MU of the node for one nanoERG (`ContractRate.mu_per_unit`). More than 0.
    pub mu_per_nano_erg: u128,
}

fn xattr<'a>(contract: &'a Contract, key: &str) -> Option<&'a [u8]> {
    contract
        .xattrs
        .iter()
        .find(|e| e.key == key)
        .and_then(|e| e.value.as_deref())
}

/// The `key=value` lines of a ledger declaration (`component_formal` of nodo). A line
/// without `=` is not a pair and is skipped.
fn formal_pairs(formal: &[u8]) -> Vec<(String, String)> {
    String::from_utf8_lossy(formal)
        .lines()
        .filter_map(|line| line.split_once('='))
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect()
}

fn formal_value<'a>(pairs: &'a [(String, String)], key: &str) -> Option<&'a str> {
    pairs
        .iter()
        .find(|(k, _)| k == key)
        .map(|(_, v)| v.as_str())
}

/// The ledger declaration must be Ergo mainnet, and the deposit token must go in R4.
/// A declaration that says nothing about the network is refused: a box on the wrong
/// network is money lost.
fn check_ledger(contract: &Contract) -> Result<(), DepositError> {
    let formal = contract
        .ledger
        .as_ref()
        .map(|l| l.formal.as_slice())
        .unwrap_or_default();
    let pairs = formal_pairs(formal);
    match formal_value(&pairs, "chain") {
        Some("ergo") => {}
        other => {
            return Err(DepositError::NotMainnet(format!(
                "chain {}",
                other.unwrap_or("not given")
            )))
        }
    }
    match formal_value(&pairs, "network") {
        Some("mainnet") => {}
        other => {
            return Err(DepositError::NotMainnet(format!(
                "network {}",
                other.unwrap_or("not given")
            )))
        }
    }
    if let Some(binding) = formal_value(&pairs, "payment.deposit_token") {
        if !binding.starts_with("R4") {
            return Err(DepositError::UnknownBinding(binding.to_string()));
        }
    }
    Ok(())
}

impl ErgPayment {
    /// The first payment contract of `peer` on the ledger `ergo` with the asset `ERG` and
    /// a rate more than 0: the same contract that the balancer uses for the price
    /// ([`celaut_balancer::erg_rate`]).
    pub fn of(peer: &Peer) -> Result<Self, DepositError> {
        for rate in &peer.payment_contracts {
            let Some(contract) = &rate.contract else {
                continue;
            };
            let on_ergo = contract
                .ledger
                .as_ref()
                .and_then(|l| l.tags.first())
                .is_some_and(|t| t == "ergo");
            if !on_ergo || xattr(contract, "token_id") != Some(b"ERG".as_slice()) {
                continue;
            }
            let mu_per_nano_erg = match amount(rate.mu_per_unit.as_ref()) {
                Ok(mu) if mu > 0 => mu,
                _ => continue,
            };
            check_ledger(contract)?;
            let script = xattr(contract, "script")
                .filter(|s| !s.is_empty())
                .ok_or(DepositError::NoScript)?
                .to_vec();
            return Ok(ErgPayment {
                contract: contract.clone(),
                script,
                mu_per_nano_erg,
            });
        }
        Err(DepositError::NoErgContract)
    }

    /// The MU that `nano_erg` buys on the node: `nano_erg * mu_per_nano_erg`. The node
    /// converts back with a division that rounds down, so it asks for `nano_erg`
    /// exactly.
    pub fn mu_for(&self, nano_erg: u64) -> Result<u128, DepositError> {
        if nano_erg == 0 {
            return Err(DepositError::BadAmount("0 nanoERG".into()));
        }
        u128::from(nano_erg)
            .checked_mul(self.mu_per_nano_erg)
            .ok_or_else(|| DepositError::BadAmount("too large".into()))
    }

    /// The `Payment` of `Payable`: the token, the contract without a change, and the MU
    /// that `nano_erg` buys.
    pub fn payment(&self, deposit_token: &str, nano_erg: u64) -> Result<Payment, DepositError> {
        check_deposit_token(deposit_token)?;
        Ok(Payment {
            deposit_token: deposit_token.to_string(),
            contract: Some(self.contract.clone()),
            amount: Some(Amount {
                n: self.mu_for(nano_erg)?.to_string(),
            }),
        })
    }
}

/// The confirmations that the app waits for before `Payable` when the node does not say
/// how many it wants: about an hour. nodo's default (`MIN_CONFIRMATIONS`) is 1, and the
/// deposit token lives 6 hours.
pub const DEFAULT_BTC_CONFIRMATIONS: u32 = 6;

/// The most confirmations that the app waits for: 36 blocks are about 6 hours, the life of
/// a deposit token.
pub const MAX_BTC_CONFIRMATIONS: u32 = 36;

/// The BTC payment contract of a node (`nodo:src/payment_system/contracts/bitcoin`).
#[derive(Debug, Clone, PartialEq)]
pub struct BtcPayment {
    /// The contract as the node advertised it, for `Payable` without a change.
    pub contract: Contract,
    /// The scriptPubKey that receives the payment: P2WPKH (`0014` and 20 bytes).
    pub script: Vec<u8>,
    /// The MU of the node for one satoshi. More than 0.
    pub mu_per_sat: u128,
    /// The Bitcoin network of the contract (`network=` of the declaration).
    pub network: String,
    /// The confirmations that the node says it wants (`payment.min_confirmations=`), if it
    /// says it. nodo does not say it yet.
    pub min_confirmations: Option<u32>,
}

/// True for a P2WPKH scriptPubKey: `OP_0 PUSH20 <20 bytes>`.
pub fn is_p2wpkh(script: &[u8]) -> bool {
    script.len() == 22 && script[0] == 0x00 && script[1] == 0x14
}

fn on_bitcoin(contract: &Contract) -> bool {
    contract
        .ledger
        .as_ref()
        .and_then(|l| l.tags.first())
        .is_some_and(|t| t == "bitcoin")
        && xattr(contract, "token_id") == Some(b"BTC".as_slice())
}

fn formal_of(contract: &Contract) -> Vec<(String, String)> {
    formal_pairs(
        contract
            .ledger
            .as_ref()
            .map(|l| l.formal.as_slice())
            .unwrap_or_default(),
    )
}

impl BtcPayment {
    /// The Bitcoin networks of the BTC payment contracts of `peer` with a rate more than 0.
    /// The app offers a BTC deposit only when the wallet's network is one of them.
    pub fn networks(peer: &Peer) -> Vec<String> {
        let mut all: Vec<String> = peer
            .payment_contracts
            .iter()
            .filter(|r| amount(r.mu_per_unit.as_ref()).is_ok_and(|mu| mu > 0))
            .filter_map(|r| r.contract.as_ref())
            .filter(|c| on_bitcoin(c))
            .filter_map(|c| {
                let pairs = formal_of(c);
                (formal_value(&pairs, "chain") == Some("bitcoin"))
                    .then(|| formal_value(&pairs, "network").map(str::to_string))
                    .flatten()
            })
            .collect();
        all.dedup();
        all
    }

    /// The BTC payment contract of `peer` on the Bitcoin network `network` (`mainnet`,
    /// `testnet`, `signet`, `regtest`). A declaration without a network, or with another
    /// one, is refused: a payment on the wrong network is money lost.
    pub fn of(peer: &Peer, network: &str) -> Result<Self, DepositError> {
        let mut other = None;
        for rate in &peer.payment_contracts {
            let Some(contract) = &rate.contract else {
                continue;
            };
            if !on_bitcoin(contract) {
                continue;
            }
            let mu_per_sat = match amount(rate.mu_per_unit.as_ref()) {
                Ok(mu) if mu > 0 => mu,
                _ => continue,
            };
            let pairs = formal_of(contract);
            if formal_value(&pairs, "chain") != Some("bitcoin") {
                continue;
            }
            let node_network = formal_value(&pairs, "network").unwrap_or("not given");
            if node_network != network {
                other = Some(node_network.to_string());
                continue;
            }
            if let Some(binding) = formal_value(&pairs, "payment.deposit_token") {
                if !binding.contains("OP_RETURN") {
                    return Err(DepositError::UnknownBinding(binding.to_string()));
                }
            }
            if let Some(kind) = xattr(contract, "contract_type") {
                if kind != b"p2wpkh" {
                    return Err(DepositError::NotP2wpkh(
                        String::from_utf8_lossy(kind).into_owned(),
                    ));
                }
            }
            let script = xattr(contract, "script")
                .filter(|s| !s.is_empty())
                .ok_or(DepositError::NoScript)?
                .to_vec();
            if !is_p2wpkh(&script) {
                return Err(DepositError::NotP2wpkh(hex::encode(&script)));
            }
            let min_confirmations = formal_value(&pairs, "payment.min_confirmations")
                .and_then(|v| v.trim().parse::<u32>().ok())
                .filter(|n| *n > 0);
            return Ok(BtcPayment {
                contract: contract.clone(),
                script,
                mu_per_sat,
                network: network.to_string(),
                min_confirmations,
            });
        }
        match other {
            Some(node) => Err(DepositError::OtherNetwork {
                node,
                wallet: network.to_string(),
            }),
            None => Err(DepositError::NoBtcContract),
        }
    }

    /// The confirmations to wait for before `Payable`: what the node says, else
    /// [`DEFAULT_BTC_CONFIRMATIONS`]; never more than [`MAX_BTC_CONFIRMATIONS`].
    pub fn confirmations(&self) -> u32 {
        self.min_confirmations
            .unwrap_or(DEFAULT_BTC_CONFIRMATIONS)
            .min(MAX_BTC_CONFIRMATIONS)
    }

    /// The MU that `sat` buys on the node: `sat * mu_per_sat`. The node converts back with
    /// a division that rounds down, so it asks for `sat` exactly.
    pub fn mu_for(&self, sat: u64) -> Result<u128, DepositError> {
        if sat == 0 {
            return Err(DepositError::BadAmount("0 sat".into()));
        }
        u128::from(sat)
            .checked_mul(self.mu_per_sat)
            .ok_or_else(|| DepositError::BadAmount("too large".into()))
    }

    /// The `Payment` of `Payable`: the token, the contract without a change, and the MU
    /// that `sat` buys.
    pub fn payment(&self, deposit_token: &str, sat: u64) -> Result<Payment, DepositError> {
        check_deposit_token(deposit_token)?;
        Ok(Payment {
            deposit_token: deposit_token.to_string(),
            contract: Some(self.contract.clone()),
            amount: Some(Amount {
                n: self.mu_for(sat)?.to_string(),
            }),
        })
    }
}

/// A deposit token goes on a public ledger, in a register: accept only printable ASCII
/// (a node gives a UUID4), from 1 to [`MAX_DEPOSIT_TOKEN_LEN`] characters.
pub fn check_deposit_token(token: &str) -> Result<(), DepositError> {
    if token.is_empty() || token.len() > MAX_DEPOSIT_TOKEN_LEN {
        return Err(DepositError::BadToken(format!(
            "{} characters, not 1 to {MAX_DEPOSIT_TOKEN_LEN}",
            token.len()
        )));
    }
    if !token.bytes().all(|b| b.is_ascii_graphic()) {
        return Err(DepositError::BadToken(
            "it has characters that are not printable ASCII".into(),
        ));
    }
    Ok(())
}

/// The URL of the unspent boxes of `address`, mempool included, on `explorer`: the
/// request that the node makes to find a deposit
/// (`nodo:src/payment_system/contracts/ergo/interface.py`, `_validate`).
pub fn unspent_boxes_url(explorer: &str, address: &str) -> String {
    format!(
        "{}/api/v1/boxes/unspent/unconfirmed/byAddress/{address}",
        explorer.trim().trim_end_matches('/')
    )
}

/// A box of the explorer that has the deposit token in R4.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DepositBox {
    pub box_id: String,
    /// The value of the box, in nanoERG.
    pub value: u64,
}

/// The token in R4 of an explorer box: `additionalRegisters.R4.renderedValue` is the hex
/// of the bytes of a `Coll[Byte]`, and the node reads them as UTF-8.
fn r4_text(item: &serde_json::Value) -> Option<String> {
    let rendered = item
        .get("additionalRegisters")?
        .get("R4")?
        .get("renderedValue")?
        .as_str()?;
    let bytes = hex::decode(rendered).ok()?;
    String::from_utf8(bytes).ok()
}

/// The first box of an explorer answer (a JSON list of boxes) with `token` in R4, as
/// the node finds it. The node accepts the payment if the value of that box is the
/// amount in nanoERG or more. It reads only the first box with the token.
pub fn find_deposit_box(boxes: &serde_json::Value, token: &str) -> Option<DepositBox> {
    boxes.as_array()?.iter().find_map(|item| {
        if r4_text(item)? != token {
            return None;
        }
        Some(DepositBox {
            box_id: item.get("boxId")?.as_str()?.to_string(),
            value: item.get("value")?.as_u64()?,
        })
    })
}
