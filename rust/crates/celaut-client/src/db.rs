//! The Celaut database of the app (`docs/celaut/ui.md`, section 1).
//!
//! All the Celaut data of the app is in one database: the client id of each node, the
//! last accepted advertisement of each node, the instances and their tokens, the
//! deposits, the last quotes and the event log of local reputation. There is one
//! database for the whole app, not one per wallet, and no record has a wallet key. A
//! deposit does not record which wallet paid: the transaction id is enough, and the
//! history of the wallet shows the rest.
//!
//! The client ids and the instance tokens are bearer secrets, so the file is encrypted
//! with AES-256-GCM. The key comes from the caller (on Android, the Keystore store of
//! the app). A write goes to a temporary file first and then replaces the file, so a
//! stop in the middle leaves the old file.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, PoisonError};

use ring::aead::{Aad, LessSafeKey, Nonce, UnboundKey, AES_256_GCM, NONCE_LEN};
use ring::rand::{SecureRandom, SystemRandom};
use serde::{Deserialize, Serialize};

use crate::store::{keep_newer, PeerStore, Seen, StoreError};

/// The version of the content.
pub const DB_VERSION: u32 = 3;

/// The length of the key, in bytes.
pub const KEY_LEN: usize = 32;

/// How many quotes the database keeps. The oldest go first.
pub const MAX_QUOTES: usize = 64;

/// How many events the database keeps. The oldest go first.
pub const MAX_EVENTS: usize = 1024;

const MAGIC: &[u8; 8] = b"CELAUTDB";
const FORMAT: u8 = 1;
const HEADER_LEN: usize = MAGIC.len() + 1;

/// What the app knows about one node. The key is the peer_id, so a node with more than
/// one address is one node.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NodeRecord {
    /// The client id of the app on this node. A bearer secret: the balance of the
    /// client on the node goes with it.
    pub client_id: String,
    /// The addresses (`host:port`) where the app reached this node, the last first.
    #[serde(default)]
    pub addresses: Vec<String>,
    /// The limit of the deposits to this node, in nanoERG, if the user changed it.
    #[serde(default)]
    pub deposit_limit_nano_erg: Option<u64>,
    /// True if the node is in the node list of the user (`docs/celaut/ui.md`, section
    /// 4). Only listed nodes are in the sums of the home screen. A removed node keeps
    /// its record (client id, deposits), so adding it again restores them.
    #[serde(default = "listed_by_default")]
    pub listed: bool,
    /// The MU that the node accepted from the deposits of the app for the current
    /// client id, as text. `None` if the app did not count it yet.
    #[serde(default)]
    pub paid_mu: Option<String>,
    /// The free credit that the node gave the current client id when it was made, in
    /// MU, as text. `None` if the app does not know it.
    #[serde(default)]
    pub free_credit_mu: Option<String>,
    /// The client ids that the app used on this node before the current one, the
    /// oldest first. The balance of these clients is lost for the app.
    #[serde(default)]
    pub earlier_client_ids: Vec<String>,
    /// What the checks of the node say: when, how fast, and why a check failed.
    #[serde(default)]
    pub health: crate::health::Health,
    /// True if the user marked the node as fully trusted: a node of the user, or of family,
    /// friends or the company (`docs/celaut/env-variables.md`, section 3.2). Before a
    /// sensitive variable goes to a node that is not trusted, the app warns. A node of an
    /// earlier version is not trusted.
    #[serde(default)]
    pub trusted: bool,
    /// The reputation that the user gives to the node, from 0 to 100 (`docs/celaut/
    /// balancer.md`). The balancer adds it to the score of the node's quote. 50 is
    /// neutral. A node of an earlier version (database version 1) has 50. See
    /// [`NodeRecord::effective_priority`] for the full trust.
    #[serde(default = "neutral_priority")]
    pub priority: u8,
}

fn neutral_priority() -> u8 {
    celaut_balancer::PRIORITY_NEUTRAL
}

fn listed_by_default() -> bool {
    true
}

impl Default for NodeRecord {
    /// A node that the user just added: in the list, no client yet.
    fn default() -> Self {
        NodeRecord {
            client_id: String::new(),
            addresses: Vec::new(),
            deposit_limit_nano_erg: None,
            listed: true,
            paid_mu: None,
            free_credit_mu: None,
            earlier_client_ids: Vec::new(),
            health: crate::health::Health::default(),
            trusted: false,
            priority: neutral_priority(),
        }
    }
}

impl NodeRecord {
    /// The priority that the balancer uses: the maximum for a node of full trust
    /// ([`NodeRecord::trusted`]), else [`NodeRecord::priority`] limited to the maximum.
    pub fn effective_priority(&self) -> u8 {
        if self.trusted {
            celaut_balancer::PRIORITY_MAX
        } else {
            self.priority.min(celaut_balancer::PRIORITY_MAX)
        }
    }

    /// A record for a new client: nothing paid yet, and the free credit of the node if
    /// the app could read it.
    pub fn new_client(client_id: String, free_credit_mu: Option<u128>) -> Self {
        NodeRecord {
            client_id,
            paid_mu: Some("0".into()),
            free_credit_mu: free_credit_mu.map(|m| m.to_string()),
            ..Default::default()
        }
    }

    /// Use a new client id on this node. The old one goes into
    /// [`NodeRecord::earlier_client_ids`]; its balance is lost for the app. The limit,
    /// the addresses and the deposits of the node do not change.
    pub fn replace_client(&mut self, client_id: String, free_credit_mu: Option<u128>) {
        let old = std::mem::replace(&mut self.client_id, client_id);
        if !old.is_empty() && old != self.client_id {
            self.earlier_client_ids.push(old);
        }
        self.paid_mu = Some("0".into());
        self.free_credit_mu = free_credit_mu.map(|m| m.to_string());
    }

    /// Add `mu` that the node accepted from a deposit to the paid credit.
    pub fn add_paid(&mut self, mu: u128) {
        let before = self
            .paid_mu
            .as_deref()
            .and_then(|p| p.parse::<u128>().ok())
            .unwrap_or(0);
        self.paid_mu = Some(before.saturating_add(mu).to_string());
    }

    /// The paid credit, if known.
    pub fn paid(&self) -> Option<u128> {
        self.paid_mu.as_deref().and_then(|p| p.parse().ok())
    }

    /// The free credit of the current client, if known.
    pub fn free_credit(&self) -> Option<u128> {
        self.free_credit_mu.as_deref().and_then(|p| p.parse().ok())
    }
}

/// An instance that the app started. Any full wallet of the app can stop it.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstanceRecord {
    /// The node.
    pub peer_id: String,
    /// The address (`host:port`) of the node at the start.
    pub address: String,
    /// The instance token. A bearer secret.
    pub token: String,
    /// The service id, in lowercase hex.
    pub service_id: String,
    /// The internal ports of the instance.
    #[serde(default)]
    pub slots: Vec<u16>,
    /// The slots that follow the chat convention (`docs/celaut/chat.md`), a part of
    /// `slots`. An old record has none.
    #[serde(default)]
    pub chat_slots: Vec<u16>,
    /// The slots that a browser can open (`tcp` and `http`, no chat), a part of `slots`.
    /// An old record has none.
    #[serde(default)]
    pub web_slots: Vec<u16>,
    /// The time of the start, in Unix seconds.
    pub started_at: i64,
    /// What the start took from the balance of the client, in MU of the node, if the
    /// app could read the balance before and after the start.
    #[serde(default)]
    pub start_charge_mu: Option<String>,
    /// The name that the user saw when the instance started: the skill or the service
    /// file. The list of conversations shows it. An old record has none.
    #[serde(default)]
    pub name: Option<String>,
    /// The name that the user gave the instance in the app, if any. It is local: the
    /// node never gets it. The list shows it before [`InstanceRecord::name`].
    #[serde(default)]
    pub alias: Option<String>,
    /// The title that the service gave the conversation (`docs/celaut/chat.md`, section
    /// 6.10), the last one that the app read. The list shows it after
    /// [`InstanceRecord::alias`] and before [`InstanceRecord::name`]. An old record has none.
    #[serde(default)]
    pub title: Option<String>,
    /// What the app moved from the credit of the client to the instance after the start,
    /// in MU (the automatic top-up, `ModifyDeposit`). The cost so far counts it.
    #[serde(default)]
    pub topped_up_mu: Option<String>,
    /// The time of the stop, in Unix seconds. A stopped instance stays in the database
    /// until the user deletes it (`docs/celaut/ui-chat-first.md`). An old record has
    /// none: it runs.
    #[serde(default)]
    pub stopped_at: Option<i64>,
    /// What the node gave back at the stop, in MU, if the app knows it.
    #[serde(default)]
    pub refund_mu: Option<String>,
    /// What the node charges to keep the instance, from the quote that won the start. It
    /// turns MU into time and back. An old record has none.
    #[serde(default)]
    pub pricing: Option<InstancePricing>,
    /// The instance runs until the user stops it: the app tops it up when its balance is
    /// low (`docs/celaut/ui.md`, section 4b). Off for an old record.
    #[serde(default)]
    pub keep_alive: Option<KeepAlive>,
    /// The CPU and the RAM that [`crate::hibernation::wake`] sends to wake the instance.
    /// While the instance runs, they are the last values that the app got from the node
    /// (every answer of `ModifyServiceSystemResources`; the answer of the start has none).
    /// At a hibernation, they are the values that the instance had at that moment
    /// (`docs/celaut/decisions.md`), which can differ from the values of the start.
    /// An old record has none.
    #[serde(default)]
    pub awake_resources: Option<Resources>,
    /// Where [`InstanceRecord::awake_resources`] came from. None if it has no value.
    #[serde(default)]
    pub awake_source: Option<ResourcesSource>,
    /// The time of the hibernation, in Unix seconds, when the node confirmed it. It is
    /// not `stopped_at`: a hibernated instance is not stopped, it keeps its disk and
    /// can wake. The node has no RPC that says "hibernated", so only this record knows.
    /// An old record has none: it is awake.
    #[serde(default)]
    pub hibernated_at: Option<i64>,
    /// What the node charges while the instance is hibernated: its disk only. The app
    /// works it out at the hibernation from the rates that the node advertised
    /// ([`HibernatedPrice`]). Cleared at a wake. None: the app does not know it, and the
    /// keep-alive uses the price of the awake instance, which is more than needed.
    #[serde(default)]
    pub hibernated_price: Option<HibernatedPrice>,
}

/// The price of a hibernated instance and the fee of the wake call, in MU
/// (`docs/celaut/decisions.md`). The node charges a hibernated instance for its disk only
/// (nodo `docs/PRICING.md`, "Hibernating an instance"), and the instance pays the fee of
/// the wake call (`modify_resources_mu`), so its balance must hold both.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HibernatedPrice {
    /// The disk of one period, in MU. It is never more than the price of the awake
    /// instance. The period is `InstanceRecord::pricing.maintenance_seconds`.
    pub disk_maintenance_mu: String,
    /// The fee of one call that changes the resources, in MU. Empty if the node did not
    /// advertise it.
    #[serde(default)]
    pub wake_fee_mu: String,
}

/// The resources that an instance needs to wake: the three fields that the node asks for
/// in a wake, all above 0 (`ModifyServiceSystemResources`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Resources {
    /// The CPU quota in microseconds for each `cpu_period`.
    pub cpu_quota: u64,
    /// The CPU period in microseconds.
    pub cpu_period: u64,
    /// The RAM limit in bytes.
    pub mem_limit: u64,
}

impl Resources {
    /// The resources of `sysreq`, if `cpu_quota`, `cpu_period` and `mem_limit` are all
    /// set and above 0. None otherwise: a 0 means hibernated, not a size.
    pub fn from_sysresources(sysreq: &celaut_proto::celaut::Sysresources) -> Option<Self> {
        let above_zero = |v: Option<u64>| v.filter(|v| *v > 0);
        Some(Resources {
            cpu_quota: above_zero(sysreq.cpu_quota)?,
            cpu_period: above_zero(sysreq.cpu_period)?,
            mem_limit: above_zero(sysreq.mem_limit)?,
        })
    }

    /// The same resources as a `Sysresources` with the three fields set.
    pub fn to_sysresources(self) -> celaut_proto::celaut::Sysresources {
        celaut_proto::celaut::Sysresources {
            cpu_quota: Some(self.cpu_quota),
            cpu_period: Some(self.cpu_period),
            mem_limit: Some(self.mem_limit),
            ..Default::default()
        }
    }
}

/// Where the awake resources of an instance came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResourcesSource {
    /// The app read them from the node just before the hibernation. They are exact, as
    /// far as the wire allows (a resize in the small gap between the read and the
    /// hibernation is not seen).
    ReadFromNode,
    /// The last values that the app got from the node: the answers of the changes of
    /// resources. They can be old, because the parent or the
    /// instance may have resized it without the app. The UI must warn about them.
    LastKnown,
}

/// The price of keeping an instance on its node, as the quote gave it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstancePricing {
    /// The maintenance of one period, in MU.
    pub maintenance_mu: String,
    /// The seconds of one period (`maintenance_seconds_loop`).
    pub maintenance_seconds: u32,
    /// The most that the price can rise in one volatility period, as text: the
    /// `price_volatility` of a bounded quote, 0 for one that is not bounded (nodo#636). A
    /// record from before #636 has its `variance` here: with a period of 0 it is the same
    /// margin on each period.
    #[serde(alias = "variance")]
    pub volatility: String,
    /// The seconds of one volatility period (`volatility_period_seconds`); 0 is one period
    /// for the whole life.
    #[serde(default)]
    pub volatility_period_seconds: u32,
}

/// The settings of an instance that runs until the user stops it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct KeepAlive {
    /// The most that the app may move to the instance from now on, in MU. None: no limit.
    #[serde(default)]
    pub budget_mu: Option<String>,
    /// What `InstanceRecord::topped_up_mu` was when the user turned this on, so that the
    /// spent amount counts only from then.
    #[serde(default)]
    pub topped_up_at_start_mu: String,
}

/// Where a deposit is.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "stage", rename_all = "snake_case")]
pub enum DepositStage {
    /// The preparation waits for the confirmation of the user.
    Prepared,
    /// The transaction was sent; the box is not yet seen on the explorer.
    Sent { tx_id: String },
    /// `Payable` was called. It is never called again for this deposit.
    PayableCalled { tx_id: String, accepted: bool },
}

/// A deposit to a node. It does not record which wallet paid (`docs/celaut/ui.md`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DepositRecord {
    pub peer_id: String,
    /// The address (`host:port`) of the node when the deposit was made.
    pub address: String,
    /// The deposit token in R4.
    pub deposit_token: String,
    pub nano_erg: u64,
    /// The MU that the amount buys on the node.
    pub mu: String,
    /// The address that receives the deposit.
    pub pay_to_address: String,
    /// The id of the deposit transaction, known before the signature.
    #[serde(default)]
    pub tx_id: String,
    /// The time of the preparation, in Unix seconds.
    pub made_at: i64,
    pub stage: DepositStage,
}

/// A deposit in BTC to a node (issue #92). The token goes in an `OP_RETURN` output, and
/// `Payable` waits for [`BtcDepositRecord::confirmations`].
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BtcDepositRecord {
    pub peer_id: String,
    /// The address (`host:port`) of the node when the deposit was made.
    pub address: String,
    /// The deposit token in the `OP_RETURN` output.
    pub deposit_token: String,
    /// The Bitcoin network (`mainnet`, `testnet`, `signet`, `regtest`).
    pub network: String,
    /// The Esplora server that the app asks about the transaction.
    pub server: String,
    pub sat: u64,
    /// The MU that the amount buys on the node.
    pub mu: String,
    /// The address that receives the deposit.
    pub pay_to_address: String,
    /// The id of the transaction: a segwit id is known before the signature.
    pub tx_id: String,
    /// The confirmations to wait for before `Payable`.
    pub confirmations: u32,
    /// The time of the preparation, in Unix seconds.
    pub made_at: i64,
    pub stage: DepositStage,
}

/// The last quote of a node for a service.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct QuoteRecord {
    pub peer_id: String,
    pub service_id: String,
    /// The cost of the start, in MU of the node.
    pub cost_mu: String,
    /// The time of the quote, in Unix seconds.
    pub at: i64,
}

/// What happened with a node, for the local reputation (`docs/celaut/balancer.md`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventKind {
    /// The node accepted a payment (+10 in nodo).
    PaymentCommunicated,
    /// The node did not accept a payment (−100 in nodo).
    PaymentNotAcknowledged,
}

/// One event of the log.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EventRecord {
    pub peer_id: String,
    pub kind: EventKind,
    /// The time, in Unix seconds.
    pub at: i64,
}

/// The content of the database.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CelautData {
    #[serde(default)]
    pub version: u32,
    /// The weights of the balancer that the user set, in thousandths: price, reputation,
    /// on-chain, donation, priority (`celaut_balancer::Weights::to_milli`). `None` means
    /// the defaults. Use [`CelautData::balancer_weights`].
    #[serde(default)]
    pub balancer_weights_milli: Option<[u32; 5]>,
    /// The nodes, by peer_id.
    #[serde(default)]
    pub nodes: BTreeMap<String, NodeRecord>,
    /// The last accepted advertisement of each node, by peer_id.
    #[serde(default)]
    pub seen: BTreeMap<String, Seen>,
    /// The instances that run, by local instance id.
    #[serde(default)]
    pub instances: BTreeMap<String, InstanceRecord>,
    /// The deposits, by local deposit id.
    #[serde(default)]
    pub deposits: BTreeMap<String, DepositRecord>,
    /// The deposits in BTC, by local deposit id (issue #92).
    #[serde(default)]
    pub btc_deposits: BTreeMap<String, BtcDepositRecord>,
    /// The last quotes, the oldest first.
    #[serde(default)]
    pub quotes: Vec<QuoteRecord>,
    /// The event log, the oldest first.
    #[serde(default)]
    pub events: Vec<EventRecord>,
    /// The service files that the user loaded into the app, by service id (64 lowercase
    /// hexadecimal characters). `docs/celaut/package.md`.
    #[serde(default)]
    pub packages: BTreeMap<String, PackageRecord>,
    /// The environment variables that the user keeps for the launches, by name
    /// (`docs/celaut/env-variables.md`). A value can be a secret.
    #[serde(default)]
    pub env_variables: BTreeMap<String, EnvRecord>,
    /// The execution receipts of the instances, by local instance id (nodo#419). They
    /// go when the instance is deleted.
    #[serde(default)]
    pub receipts: BTreeMap<String, crate::receipts::InstanceReceipts>,
    /// The descendants of the instances (nodo#631), by [`crate::descendants::key`]: the
    /// local id of the held instance and the `instance_ref`. Version 3. They go when the
    /// instance is deleted ([`CelautData::remove_descendants_of`]).
    #[serde(default)]
    pub descendants: BTreeMap<String, crate::descendants::DescendantRecord>,
    /// The receipts of the tunnels to descendants, by the same key. They are named by
    /// `instance_ref`, not by token.
    #[serde(default)]
    pub descendant_receipts: BTreeMap<String, crate::receipts::InstanceReceipts>,
}

/// One environment variable of the container of the app.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EnvRecord {
    /// The value, as UTF-8 text.
    #[serde(default)]
    pub value: String,
    /// The time of the last change, in Unix seconds.
    #[serde(default)]
    pub changed_at: i64,
    /// True if the value is a credential (`docs/celaut/env-variables.md`, section 3.2). Only
    /// a sensitive value makes the app warn before a launch. A variable of an earlier version
    /// is sensitive: the user saved it to keep it.
    #[serde(default = "sensitive_by_default")]
    pub sensitive: bool,
}

fn sensitive_by_default() -> bool {
    true
}

impl Default for EnvRecord {
    /// A variable of the container is sensitive unless the user says that it is not.
    fn default() -> Self {
        EnvRecord {
            value: String::new(),
            changed_at: 0,
            sensitive: true,
        }
    }
}

/// A service file that the user loaded into the app.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct PackageRecord {
    /// The name to show: the name of the file that the user chose, without `.celaut.bee`.
    #[serde(default)]
    pub name: String,
    /// The file of the app that holds the package.
    #[serde(default)]
    pub path: String,
    /// The size of the file, in bytes.
    #[serde(default)]
    pub bytes: u64,
    /// The time of the load, in Unix seconds.
    #[serde(default)]
    pub imported_at: i64,
    /// True for a file of `nodo export` (its parts get the indices of a node).
    #[serde(default)]
    pub nodo_export: bool,
}

impl CelautData {
    /// The nanoERG of the deposits to `peer_id` that count against its limit: every
    /// deposit that was prepared and not cancelled.
    pub fn deposited_nano_erg(&self, peer_id: &str) -> u64 {
        self.deposits
            .values()
            .filter(|d| d.peer_id == peer_id)
            .fold(0u64, |sum, d| sum.saturating_add(d.nano_erg))
    }

    /// The MU of the deposits to `peer_id` that the node accepted.
    pub fn accepted_mu(&self, peer_id: &str) -> u128 {
        self.deposits
            .values()
            .filter(|d| d.peer_id == peer_id)
            .filter(|d| matches!(d.stage, DepositStage::PayableCalled { accepted: true, .. }))
            .filter_map(|d| d.mu.parse::<u128>().ok())
            .fold(0u128, u128::saturating_add)
    }

    /// Count the paid credit of the nodes that do not have it yet (a database of an
    /// earlier version). Until this version the app never changed the client id of a
    /// node, so every accepted deposit of the node went to the current client.
    pub fn count_paid_credit(&mut self) {
        let missing: Vec<String> = self
            .nodes
            .iter()
            .filter(|(_, n)| n.paid_mu.is_none())
            .map(|(p, _)| p.clone())
            .collect();
        for peer_id in missing {
            let paid = self.accepted_mu(&peer_id);
            if let Some(node) = self.nodes.get_mut(&peer_id) {
                node.paid_mu = Some(paid.to_string());
            }
        }
    }

    /// The weights of the score that the balancer uses: the ones that the user set, else
    /// the defaults.
    pub fn balancer_weights(&self) -> celaut_balancer::Weights {
        self.balancer_weights_milli
            .map(celaut_balancer::Weights::from_milli)
            .unwrap_or_default()
    }

    /// Set the weights of the balancer. Values are limited by `Weights::sanitized`.
    /// Weights equal to the defaults are stored as "not set".
    pub fn set_balancer_weights(&mut self, weights: celaut_balancer::Weights) {
        let milli = weights.to_milli();
        self.balancer_weights_milli = if milli == celaut_balancer::Weights::default().to_milli() {
            None
        } else {
            Some(milli)
        };
    }

    /// What the balancer knows about each node of the database, by peer_id: for now the
    /// priority of the user ([`NodeRecord::effective_priority`]).
    pub fn standings(&self) -> std::collections::HashMap<String, celaut_balancer::Standing> {
        self.nodes
            .iter()
            .map(|(peer_id, n)| {
                let standing = celaut_balancer::Standing {
                    priority: n.effective_priority(),
                    ..Default::default()
                };
                (peer_id.clone(), standing)
            })
            .collect()
    }

    /// The peer_ids of the nodes in the node list of the user.
    pub fn listed_nodes(&self) -> impl Iterator<Item = (&String, &NodeRecord)> {
        self.nodes.iter().filter(|(_, n)| n.listed)
    }

    /// Remember the address of a node, the last first.
    pub fn note_address(&mut self, peer_id: &str, address: &str) {
        if let Some(node) = self.nodes.get_mut(peer_id) {
            node.addresses.retain(|a| a != address);
            node.addresses.insert(0, address.to_string());
        }
    }

    /// Add a quote, and drop the oldest ones over [`MAX_QUOTES`].
    pub fn add_quote(&mut self, quote: QuoteRecord) {
        self.quotes
            .retain(|q| !(q.peer_id == quote.peer_id && q.service_id == quote.service_id));
        self.quotes.push(quote);
        let over = self.quotes.len().saturating_sub(MAX_QUOTES);
        self.quotes.drain(..over);
    }

    /// Add an event, and drop the oldest ones over [`MAX_EVENTS`].
    pub fn add_event(&mut self, event: EventRecord) {
        self.events.push(event);
        let over = self.events.len().saturating_sub(MAX_EVENTS);
        self.events.drain(..over);
    }

    /// Add what `other` has and this one does not. An entry of this one wins.
    pub fn merge_missing(&mut self, other: CelautData) {
        for (k, v) in other.nodes {
            self.nodes.entry(k).or_insert(v);
        }
        for (k, v) in other.seen {
            keep_newer(&mut self.seen, &k, v);
        }
        for (k, v) in other.instances {
            self.instances.entry(k).or_insert(v);
        }
        for (k, v) in other.deposits {
            self.deposits.entry(k).or_insert(v);
        }
        for q in other.quotes {
            self.add_quote(q);
        }
        for e in other.events {
            self.add_event(e);
        }
        for (k, v) in other.env_variables {
            self.env_variables.entry(k).or_insert(v);
        }
        for (k, v) in other.receipts {
            self.receipts.entry(k).or_insert(v);
        }
        for (k, v) in other.descendants {
            self.descendants.entry(k).or_insert(v);
        }
        for (k, v) in other.descendant_receipts {
            self.descendant_receipts.entry(k).or_insert(v);
        }
    }

    /// Add or replace the environment variable `name`, with its mark `sensitive`. The name
    /// and the value follow [`crate::env`]; a new name over [`crate::env::MAX_VARIABLES`] is
    /// refused.
    pub fn set_env(
        &mut self,
        name: &str,
        value: &str,
        sensitive: bool,
        at: i64,
    ) -> Result<(), crate::env::EnvError> {
        crate::env::check_name(name)?;
        crate::env::check_value(value)?;
        if !self.env_variables.contains_key(name)
            && self.env_variables.len() >= crate::env::MAX_VARIABLES
        {
            return Err(crate::env::EnvError::TooMany);
        }
        self.env_variables.insert(
            name.to_string(),
            EnvRecord {
                value: value.to_string(),
                changed_at: at,
                sensitive,
            },
        );
        Ok(())
    }
}

/// The database failed.
#[derive(Debug, thiserror::Error)]
pub enum DbError {
    /// The file cannot be read or written.
    #[error("the Celaut database file {path}: {message}")]
    Io { path: String, message: String },
    /// The file exists but this key cannot open it, or it is damaged.
    #[error("the Celaut database file {0} cannot be opened with this key, or it is damaged")]
    Unreadable(String),
    /// The key is not 32 bytes.
    #[error("the key of the Celaut database must be {KEY_LEN} bytes")]
    Key,
    /// No random numbers from the system.
    #[error("the system gave no random numbers")]
    Random,
}

impl From<DbError> for StoreError {
    fn from(e: DbError) -> Self {
        StoreError(e.to_string())
    }
}

struct DbFile {
    path: PathBuf,
    key: LessSafeKey,
}

impl DbFile {
    fn new(path: PathBuf, key: &[u8]) -> Result<Self, DbError> {
        let unbound = UnboundKey::new(&AES_256_GCM, key).map_err(|_| DbError::Key)?;
        Ok(DbFile {
            path,
            key: LessSafeKey::new(unbound),
        })
    }

    fn io(&self, e: impl std::fmt::Display) -> DbError {
        DbError::Io {
            path: self.path.display().to_string(),
            message: e.to_string(),
        }
    }

    fn unreadable(&self) -> DbError {
        DbError::Unreadable(self.path.display().to_string())
    }

    /// The content of the file, or `None` if there is no file.
    fn read(&self) -> Result<Option<CelautData>, DbError> {
        let bytes = match std::fs::read(&self.path) {
            Ok(b) => b,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
            Err(e) => return Err(self.io(e)),
        };
        if bytes.len() < HEADER_LEN + NONCE_LEN || &bytes[..MAGIC.len()] != MAGIC {
            return Err(self.unreadable());
        }
        if bytes[MAGIC.len()] != FORMAT {
            return Err(self.unreadable());
        }
        let (header, rest) = bytes.split_at(HEADER_LEN);
        let (nonce, sealed) = rest.split_at(NONCE_LEN);
        let nonce = Nonce::try_assume_unique_for_key(nonce).map_err(|_| self.unreadable())?;
        let mut sealed = sealed.to_vec();
        let plain = self
            .key
            .open_in_place(nonce, Aad::from(header), &mut sealed)
            .map_err(|_| self.unreadable())?;
        let data = serde_json::from_slice(plain).map_err(|_| self.unreadable())?;
        Ok(Some(data))
    }

    fn write(&self, data: &CelautData) -> Result<(), DbError> {
        let mut plain = serde_json::to_vec(data).map_err(|e| self.io(e))?;
        let mut nonce = [0u8; NONCE_LEN];
        SystemRandom::new()
            .fill(&mut nonce)
            .map_err(|_| DbError::Random)?;
        let mut header = Vec::with_capacity(HEADER_LEN);
        header.extend_from_slice(MAGIC);
        header.push(FORMAT);
        self.key
            .seal_in_place_append_tag(
                Nonce::assume_unique_for_key(nonce),
                Aad::from(&header[..]),
                &mut plain,
            )
            .map_err(|_| self.io("the encryption failed"))?;
        let mut bytes = header;
        bytes.extend_from_slice(&nonce);
        bytes.extend_from_slice(&plain);

        if let Some(dir) = self.path.parent() {
            std::fs::create_dir_all(dir).map_err(|e| self.io(e))?;
        }
        let mut temporary = self.path.clone().into_os_string();
        temporary.push(".tmp");
        let temporary = PathBuf::from(temporary);
        {
            use std::io::Write;
            let mut file = std::fs::File::create(&temporary).map_err(|e| self.io(e))?;
            file.write_all(&bytes).map_err(|e| self.io(e))?;
            file.sync_all().map_err(|e| self.io(e))?;
        }
        std::fs::rename(&temporary, &self.path).map_err(|e| self.io(e))
    }
}

struct Inner {
    data: CelautData,
    file: Option<Arc<DbFile>>,
}

/// The Celaut database of the app: in memory, or in one encrypted file.
pub struct CelautDb {
    inner: Mutex<Inner>,
    /// Orders the writes of the file, so that an old copy never replaces a new one.
    /// Take it before `inner`.
    writing: Mutex<()>,
}

impl std::fmt::Debug for CelautDb {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let inner = self.inner.lock().unwrap_or_else(PoisonError::into_inner);
        f.debug_struct("CelautDb")
            .field("path", &inner.file.as_ref().map(|f| f.path.clone()))
            .finish_non_exhaustive()
    }
}

impl Default for CelautDb {
    fn default() -> Self {
        Self::in_memory()
    }
}

impl CelautDb {
    /// A database in memory. It is empty after a restart.
    pub fn in_memory() -> Self {
        CelautDb {
            inner: Mutex::new(Inner {
                data: CelautData {
                    version: DB_VERSION,
                    ..Default::default()
                },
                file: None,
            }),
            writing: Mutex::new(()),
        }
    }

    /// The database in the file `path`, encrypted with `key`. The file is made on the
    /// first change. A file that this key cannot open is an error: the database never
    /// writes over it.
    pub fn open(path: impl Into<PathBuf>, key: &[u8]) -> Result<Self, DbError> {
        if key.len() != KEY_LEN {
            return Err(DbError::Key);
        }
        let file = DbFile::new(path.into(), key)?;
        let mut data = file.read()?.unwrap_or_default();
        data.version = DB_VERSION;
        Ok(CelautDb {
            inner: Mutex::new(Inner {
                data,
                file: Some(Arc::new(file)),
            }),
            writing: Mutex::new(()),
        })
    }

    /// The file of the database, if it has one.
    pub fn path(&self) -> Option<PathBuf> {
        self.lock().file.as_ref().map(|f| f.path.clone())
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        self.inner.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Read the content.
    pub fn read<R>(&self, f: impl FnOnce(&CelautData) -> R) -> R {
        f(&self.lock().data)
    }

    /// A copy of the content.
    pub fn snapshot(&self) -> CelautData {
        self.lock().data.clone()
    }

    /// Change the content and write the file. If the write fails, the change stays in
    /// memory and the error comes back; the next successful write saves it.
    pub fn update<R>(&self, f: impl FnOnce(&mut CelautData) -> R) -> Result<R, DbError> {
        let _writing = self.writing.lock().unwrap_or_else(PoisonError::into_inner);
        let mut inner = self.lock();
        let answer = f(&mut inner.data);
        if let Some(file) = &inner.file {
            file.write(&inner.data)?;
        }
        Ok(answer)
    }

    /// Change the content in memory only. It is quick and it does not touch the disk.
    /// Call [`CelautDb::flush`] later to save the change.
    pub fn update_in_memory<R>(&self, f: impl FnOnce(&mut CelautData) -> R) -> R {
        f(&mut self.lock().data)
    }

    /// Write the content to the file. The content is copied first, so a change in
    /// memory does not wait for the disk. Does nothing for a database in memory.
    pub fn flush(&self) -> Result<(), DbError> {
        let _writing = self.writing.lock().unwrap_or_else(PoisonError::into_inner);
        let (file, data) = {
            let inner = self.lock();
            match &inner.file {
                Some(file) => (Arc::clone(file), inner.data.clone()),
                None => return Ok(()),
            }
        };
        file.write(&data)
    }
}

/// The advertisements are part of the database.
impl PeerStore for CelautDb {
    fn get(&self, peer_id: &str) -> Result<Option<Seen>, StoreError> {
        Ok(self.read(|d| d.seen.get(peer_id).cloned()))
    }

    fn put(&self, peer_id: &str, seen: Seen) -> Result<(), StoreError> {
        Ok(self.update(|d| keep_newer(&mut d.seen, peer_id, seen))?)
    }
}

/// Move a file that cannot be opened to a new name next to it, so that a new database
/// can start and the old file stays for the user. Gives the new name.
pub fn set_aside(path: &Path, suffix: &str) -> Result<PathBuf, DbError> {
    let mut name = path.as_os_str().to_owned();
    name.push(format!(".unreadable-{suffix}"));
    let target = PathBuf::from(name);
    std::fs::rename(path, &target).map_err(|e| DbError::Io {
        path: path.display().to_string(),
        message: e.to_string(),
    })?;
    Ok(target)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dir() -> PathBuf {
        let mut bytes = [0u8; 8];
        SystemRandom::new().fill(&mut bytes).unwrap();
        let dir = std::env::temp_dir().join(format!("celaut-db-{}", hex::encode(bytes)));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn sample(data: &mut CelautData) {
        data.nodes.insert(
            "aa".repeat(32),
            NodeRecord {
                client_id: "c1".into(),
                addresses: vec!["node.example:53460".into()],
                deposit_limit_nano_erg: Some(7),
                ..Default::default()
            },
        );
        data.instances.insert(
            "i1".into(),
            InstanceRecord {
                peer_id: "aa".repeat(32),
                address: "node.example:53460".into(),
                token: "secret-token".into(),
                service_id: "bb".repeat(32),
                slots: vec![3030],
                chat_slots: vec![3030],
                web_slots: Vec::new(),
                started_at: 1,
                start_charge_mu: Some("100".into()),
                name: Some("Echo".into()),
                alias: Some("My echo".into()),
                title: Some("Trip to Lisbon".into()),
                topped_up_mu: Some("50".into()),
                stopped_at: None,
                refund_mu: None,
                pricing: None,
                keep_alive: None,
                awake_resources: None,
                awake_source: None,
                hibernated_at: None,
                hibernated_price: None,
            },
        );
        data.deposits.insert(
            "d1".into(),
            DepositRecord {
                peer_id: "aa".repeat(32),
                address: "node.example:53460".into(),
                deposit_token: "tok".into(),
                nano_erg: 10_000_000,
                mu: "10000000".into(),
                pay_to_address: "9f...".into(),
                tx_id: "cc".repeat(32),
                made_at: 2,
                stage: DepositStage::Sent {
                    tx_id: "cc".repeat(32),
                },
            },
        );
        data.add_event(EventRecord {
            peer_id: "aa".repeat(32),
            kind: EventKind::PaymentCommunicated,
            at: 3,
        });
        data.packages.insert(
            "dd".repeat(32),
            PackageRecord {
                name: "echo".into(),
                path: "/data/packages/library/dd.bee".into(),
                bytes: 4096,
                imported_at: 4,
                nodo_export: true,
            },
        );
    }

    #[test]
    fn an_old_database_has_no_variables_and_a_new_one_keeps_them() {
        let old: CelautData = serde_json::from_str(r#"{"version": 1}"#).unwrap();
        assert!(old.env_variables.is_empty());
        let mut data = CelautData::default();
        data.set_env("API_KEY", "sk-1", true, 5).unwrap();
        data.set_env("API_KEY", "sk-2", true, 6).unwrap();
        let back: CelautData =
            serde_json::from_str(&serde_json::to_string(&data).unwrap()).unwrap();
        assert_eq!(back.env_variables.len(), 1);
        assert_eq!(back.env_variables["API_KEY"].value, "sk-2");
        assert_eq!(back.env_variables["API_KEY"].changed_at, 6);
    }

    #[test]
    fn an_old_variable_is_sensitive_and_an_old_node_is_not_trusted() {
        let old: CelautData = serde_json::from_str(
            r#"{"version": 1,
                "nodes": {"aa": {"client_id": "c1"}},
                "env_variables": {"API_KEY": {"value": "sk-1", "changed_at": 5}}}"#,
        )
        .unwrap();
        assert!(old.env_variables["API_KEY"].sensitive);
        assert!(!old.nodes["aa"].trusted);
        let mut data = CelautData::default();
        data.set_env("MODE", "fast", false, 1).unwrap();
        data.nodes.insert(
            "bb".into(),
            NodeRecord {
                trusted: true,
                ..Default::default()
            },
        );
        let back: CelautData =
            serde_json::from_str(&serde_json::to_string(&data).unwrap()).unwrap();
        assert!(!back.env_variables["MODE"].sensitive);
        assert!(back.nodes["bb"].trusted);
        // A change of the value keeps the mark that the caller gives.
        data.set_env("MODE", "slow", true, 2).unwrap();
        assert!(data.env_variables["MODE"].sensitive);
    }

    #[test]
    fn an_old_node_has_neutral_priority_and_full_trust_is_the_maximum() {
        let old: CelautData =
            serde_json::from_str(r#"{"version": 1, "nodes": {"aa": {"client_id": "c1"}}}"#)
                .unwrap();
        assert_eq!(old.nodes["aa"].priority, celaut_balancer::PRIORITY_NEUTRAL);
        assert_eq!(old.nodes["aa"].effective_priority(), 50);
        let mut data = CelautData::default();
        data.nodes.insert(
            "bb".into(),
            NodeRecord {
                priority: 20,
                ..Default::default()
            },
        );
        data.nodes.insert(
            "cc".into(),
            NodeRecord {
                priority: 20,
                trusted: true,
                ..Default::default()
            },
        );
        data.nodes.insert(
            "dd".into(),
            NodeRecord {
                priority: 250,
                ..Default::default()
            },
        );
        let back: CelautData =
            serde_json::from_str(&serde_json::to_string(&data).unwrap()).unwrap();
        assert_eq!(back.nodes["bb"].priority, 20);
        let standings = back.standings();
        assert_eq!(standings["bb"].priority, 20);
        assert_eq!(standings["cc"].priority, celaut_balancer::PRIORITY_MAX);
        assert_eq!(standings["dd"].priority, celaut_balancer::PRIORITY_MAX);
    }

    #[test]
    fn the_container_refuses_bad_entries_and_too_many() {
        let mut data = CelautData::default();
        assert!(data.set_env("1A", "x", true, 0).is_err());
        assert!(data.set_env("A", "", true, 0).is_err());
        assert!(data.env_variables.is_empty());
        for i in 0..crate::env::MAX_VARIABLES {
            data.set_env(&format!("V{i}"), "x", true, 0).unwrap();
        }
        assert_eq!(
            data.set_env("EXTRA", "x", true, 0),
            Err(crate::env::EnvError::TooMany)
        );
        // An existing name is a change, not a new entry.
        data.set_env("V0", "y", true, 1).unwrap();
        assert_eq!(data.env_variables.len(), crate::env::MAX_VARIABLES);
    }

    #[test]
    fn a_merge_keeps_the_variables_that_exist() {
        let mut a = CelautData::default();
        a.set_env("A", "mine", true, 1).unwrap();
        let mut b = CelautData::default();
        b.set_env("A", "other", true, 2).unwrap();
        b.set_env("B", "new", true, 2).unwrap();
        a.merge_missing(b);
        assert_eq!(a.env_variables["A"].value, "mine");
        assert_eq!(a.env_variables["B"].value, "new");
    }

    #[test]
    fn an_old_database_has_no_packages_and_a_new_one_keeps_them() {
        let old: CelautData = serde_json::from_str(r#"{"version": 1}"#).unwrap();
        assert!(old.packages.is_empty());
        let mut data = CelautData::default();
        sample(&mut data);
        let text = serde_json::to_string(&data).unwrap();
        let back: CelautData = serde_json::from_str(&text).unwrap();
        assert_eq!(back.packages, data.packages);
        // A record with only some fields loads, with defaults for the rest.
        let r: PackageRecord = serde_json::from_str(r#"{"name": "x"}"#).unwrap();
        assert_eq!((r.name.as_str(), r.bytes, r.nodo_export), ("x", 0, false));
    }

    #[test]
    fn an_old_instance_has_no_name_and_a_new_one_keeps_it() {
        let old: InstanceRecord =
            serde_json::from_str(r#"{"peer_id": "p", "address": "a:1", "token": "t", "service_id": "s", "started_at": 1}"#)
                .unwrap();
        assert_eq!(old.name, None);
        let mut data = CelautData::default();
        sample(&mut data);
        let text = serde_json::to_string(&data).unwrap();
        let back: CelautData = serde_json::from_str(&text).unwrap();
        assert_eq!(back.instances["i1"].name.as_deref(), Some("Echo"));
    }

    #[test]
    fn an_old_instance_runs_and_a_stop_is_kept() {
        let old: InstanceRecord =
            serde_json::from_str(r#"{"peer_id": "p", "address": "a:1", "token": "t", "service_id": "s", "started_at": 1}"#)
                .unwrap();
        assert_eq!((old.stopped_at, old.refund_mu), (None, None));
        let mut data = CelautData::default();
        sample(&mut data);
        let record = data.instances.get_mut("i1").unwrap();
        record.stopped_at = Some(7);
        record.refund_mu = Some("700".into());
        let back: CelautData =
            serde_json::from_str(&serde_json::to_string(&data).unwrap()).unwrap();
        assert_eq!(back.instances["i1"].stopped_at, Some(7));
        assert_eq!(back.instances["i1"].refund_mu.as_deref(), Some("700"));
    }

    #[test]
    fn an_old_instance_is_awake_and_a_hibernation_is_kept() {
        let old: InstanceRecord =
            serde_json::from_str(r#"{"peer_id": "p", "address": "a:1", "token": "t", "service_id": "s", "started_at": 1}"#)
                .unwrap();
        assert_eq!(
            (old.awake_resources, old.awake_source, old.hibernated_at),
            (None, None, None)
        );
        let mut data = CelautData::default();
        sample(&mut data);
        let record = data.instances.get_mut("i1").unwrap();
        record.awake_resources = Some(Resources {
            cpu_quota: 50_000,
            cpu_period: 100_000,
            mem_limit: 1 << 30,
        });
        record.awake_source = Some(ResourcesSource::LastKnown);
        record.hibernated_at = Some(9);
        let back: CelautData =
            serde_json::from_str(&serde_json::to_string(&data).unwrap()).unwrap();
        assert_eq!(back.instances["i1"], data.instances["i1"]);
        assert_eq!(back.instances["i1"].stopped_at, None);
    }

    #[test]
    fn resources_need_all_three_fields_above_zero() {
        use celaut_proto::celaut::Sysresources;
        let full = Sysresources {
            cpu_quota: Some(1),
            cpu_period: Some(2),
            mem_limit: Some(3),
            disk_space: Some(4),
            ..Default::default()
        };
        let r = Resources::from_sysresources(&full).unwrap();
        assert_eq!((r.cpu_quota, r.cpu_period, r.mem_limit), (1, 2, 3));
        assert_eq!(r.to_sysresources().disk_space, None);
        for broken in [
            Sysresources {
                cpu_quota: Some(0),
                ..full.clone()
            },
            Sysresources {
                cpu_period: None,
                ..full.clone()
            },
            Sysresources {
                mem_limit: Some(0),
                ..full.clone()
            },
        ] {
            assert_eq!(Resources::from_sysresources(&broken), None);
        }
    }

    #[test]
    fn a_change_in_memory_is_on_the_disk_only_after_a_flush() {
        let path = dir().join("celaut.db");
        let key = [7u8; KEY_LEN];
        let db = CelautDb::open(&path, &key).unwrap();
        db.update_in_memory(sample);
        assert!(!path.exists());
        db.flush().unwrap();
        let again = CelautDb::open(&path, &key).unwrap();
        assert_eq!(again.snapshot().nodes, db.snapshot().nodes);
        assert!(CelautDb::in_memory().flush().is_ok());
    }

    #[test]
    fn the_data_survives_a_restart() {
        let path = dir().join("celaut.db");
        let key = [7u8; KEY_LEN];
        {
            let db = CelautDb::open(&path, &key).unwrap();
            db.update(sample).unwrap();
            db.put(
                &"aa".repeat(32),
                Seen {
                    ts: 5,
                    digest: "d".into(),
                },
            )
            .unwrap();
        }
        let again = CelautDb::open(&path, &key).unwrap();
        let data = again.snapshot();
        let mut expected = CelautData {
            version: DB_VERSION,
            ..Default::default()
        };
        sample(&mut expected);
        expected.seen.insert(
            "aa".repeat(32),
            Seen {
                ts: 5,
                digest: "d".into(),
            },
        );
        assert_eq!(data, expected);
    }

    #[test]
    fn the_file_is_encrypted_and_needs_the_key() {
        let path = dir().join("celaut.db");
        let db = CelautDb::open(&path, &[1u8; KEY_LEN]).unwrap();
        db.update(sample).unwrap();
        let bytes = std::fs::read(&path).unwrap();
        let text = String::from_utf8_lossy(&bytes);
        // Long markers: a short one such as "c1" can appear in random bytes by chance.
        assert!(!text.contains("secret-token"));
        assert!(!text.contains("node.example"));
        let err = CelautDb::open(&path, &[2u8; KEY_LEN]).unwrap_err();
        assert!(matches!(err, DbError::Unreadable(_)), "{err}");
        // The file is not changed by the failed open.
        assert_eq!(std::fs::read(&path).unwrap(), bytes);
    }

    #[test]
    fn a_damaged_file_is_unreadable_and_can_be_set_aside() {
        let path = dir().join("celaut.db");
        let db = CelautDb::open(&path, &[1u8; KEY_LEN]).unwrap();
        db.update(sample).unwrap();
        let mut bytes = std::fs::read(&path).unwrap();
        let last = bytes.len() - 1;
        bytes[last] ^= 1;
        std::fs::write(&path, &bytes).unwrap();
        assert!(matches!(
            CelautDb::open(&path, &[1u8; KEY_LEN]),
            Err(DbError::Unreadable(_))
        ));
        let moved = set_aside(&path, "1").unwrap();
        assert!(moved.exists());
        let fresh = CelautDb::open(&path, &[1u8; KEY_LEN]).unwrap();
        assert!(fresh.snapshot().nodes.is_empty());
    }

    #[test]
    fn a_key_of_the_wrong_length_is_refused() {
        let path = dir().join("celaut.db");
        assert!(matches!(
            CelautDb::open(&path, &[1u8; 16]),
            Err(DbError::Key)
        ));
    }

    #[test]
    fn no_file_until_the_first_change() {
        let path = dir().join("sub").join("celaut.db");
        let db = CelautDb::open(&path, &[1u8; KEY_LEN]).unwrap();
        assert!(!path.exists());
        db.update(|d| d.nodes.clear()).unwrap();
        assert!(path.exists());
    }

    #[test]
    fn deposits_count_per_node_and_lists_are_bounded() {
        let mut data = CelautData::default();
        sample(&mut data);
        assert_eq!(data.deposited_nano_erg(&"aa".repeat(32)), 10_000_000);
        assert_eq!(data.deposited_nano_erg(&"bb".repeat(32)), 0);
        for i in 0..(MAX_QUOTES + 5) {
            data.add_quote(QuoteRecord {
                peer_id: format!("p{i}"),
                service_id: "s".into(),
                cost_mu: "1".into(),
                at: i as i64,
            });
        }
        assert_eq!(data.quotes.len(), MAX_QUOTES);
        assert_eq!(data.quotes[0].peer_id, "p5");
        // A new quote of the same node and service replaces the old one.
        data.add_quote(QuoteRecord {
            peer_id: "p6".into(),
            service_id: "s".into(),
            cost_mu: "2".into(),
            at: 99,
        });
        assert_eq!(data.quotes.len(), MAX_QUOTES);
        assert_eq!(data.quotes.iter().filter(|q| q.peer_id == "p6").count(), 1);
        assert_eq!(data.quotes.last().unwrap().cost_mu, "2");
    }

    #[test]
    fn the_addresses_of_a_node_keep_the_last_first() {
        let mut data = CelautData::default();
        sample(&mut data);
        let peer = "aa".repeat(32);
        data.note_address(&peer, "10.0.0.1:1");
        data.note_address(&peer, "node.example:53460");
        assert_eq!(
            data.nodes[&peer].addresses,
            vec!["node.example:53460".to_string(), "10.0.0.1:1".to_string()]
        );
    }

    #[test]
    fn a_merge_keeps_the_entries_that_exist() {
        let mut a = CelautData::default();
        sample(&mut a);
        let mut b = CelautData::default();
        b.nodes.insert(
            "aa".repeat(32),
            NodeRecord {
                client_id: "other".into(),
                ..Default::default()
            },
        );
        b.nodes.insert(
            "dd".repeat(32),
            NodeRecord {
                client_id: "c2".into(),
                ..Default::default()
            },
        );
        a.merge_missing(b);
        assert_eq!(a.nodes[&"aa".repeat(32)].client_id, "c1");
        assert_eq!(a.nodes[&"dd".repeat(32)].client_id, "c2");
    }

    #[test]
    fn a_node_of_an_earlier_version_is_listed_and_gets_its_paid_credit() {
        // A record as the earlier version wrote it: no list flag, no paid credit.
        let json = r#"{"version":1,"nodes":{"p":{"client_id":"c1","addresses":["n:1"]}},
            "deposits":{
              "ok":{"peer_id":"p","address":"n:1","deposit_token":"t1","nano_erg":10,
                    "mu":"10000000","pay_to_address":"9f","made_at":1,
                    "stage":{"stage":"payable_called","tx_id":"a","accepted":true}},
              "no":{"peer_id":"p","address":"n:1","deposit_token":"t2","nano_erg":5,
                    "mu":"5","pay_to_address":"9f","made_at":2,
                    "stage":{"stage":"payable_called","tx_id":"b","accepted":false}},
              "wait":{"peer_id":"p","address":"n:1","deposit_token":"t3","nano_erg":7,
                    "mu":"7","pay_to_address":"9f","made_at":3,
                    "stage":{"stage":"sent","tx_id":"c"}}}}"#;
        let mut data: CelautData = serde_json::from_str(json).unwrap();
        assert!(data.nodes["p"].listed);
        assert_eq!(data.nodes["p"].paid(), None);
        data.count_paid_credit();
        // Only the deposit that the node accepted is paid credit.
        assert_eq!(data.nodes["p"].paid(), Some(10_000_000));
        assert_eq!(data.nodes["p"].free_credit(), None);
        // A second count changes nothing.
        data.nodes.get_mut("p").unwrap().add_paid(1);
        data.count_paid_credit();
        assert_eq!(data.nodes["p"].paid(), Some(10_000_001));
    }

    #[test]
    fn a_new_client_starts_with_no_paid_credit_and_keeps_the_old_id() {
        let mut node = NodeRecord::new_client("c1".into(), Some(4_500_000));
        assert_eq!(node.paid(), Some(0));
        assert_eq!(node.free_credit(), Some(4_500_000));
        node.add_paid(10_000_000);
        node.deposit_limit_nano_erg = Some(3);
        node.addresses = vec!["n:1".into()];
        node.replace_client("c2".into(), None);
        assert_eq!(node.client_id, "c2");
        assert_eq!(node.earlier_client_ids, vec!["c1".to_string()]);
        assert_eq!(node.paid(), Some(0));
        assert_eq!(node.free_credit(), None);
        // The limit and the addresses stay.
        assert_eq!(node.deposit_limit_nano_erg, Some(3));
        assert_eq!(node.addresses, vec!["n:1".to_string()]);
    }

    #[test]
    fn a_database_of_version_2_has_no_descendants_and_a_new_one_keeps_them() {
        use crate::descendants::{DescendantRecord, DescendantState};
        let old: CelautData = serde_json::from_str(
            r#"{"version": 2, "instances": {"i": {"peer_id": "p", "address": "a",
                "token": "t", "service_id": "s", "started_at": 1}},
                "receipts": {"i": {}}}"#,
        )
        .unwrap();
        assert!(old.descendants.is_empty() && old.descendant_receipts.is_empty());
        assert_eq!(old.instances.len(), 1, "the old data stays");
        assert_eq!(old.receipts.len(), 1);

        // The same through the file: a file of version 2 opens, and the version is 3.
        let dir = dir();
        let key = [7u8; KEY_LEN];
        let file = DbFile::new(dir.join("celaut.db"), &key).unwrap();
        file.write(&old).unwrap();
        let db = CelautDb::open(dir.join("celaut.db"), &key).unwrap();
        assert_eq!(db.read(|d| d.version), DB_VERSION);
        assert_eq!(DB_VERSION, 3);
        assert_eq!(db.read(|d| d.instances.len()), 1);
        db.update(|d| {
            d.descendants.insert(
                "i/r".into(),
                DescendantRecord {
                    instance_id: "i".into(),
                    instance_ref: "r".into(),
                    service_id: None,
                    parent_token: "t".into(),
                    parent_ref: None,
                    peer_id: "p".into(),
                    depth: 1,
                    rows_seq: 0,
                    head_seq: 0,
                    head_hash: String::new(),
                    state: DescendantState::Bound,
                    last_checked_at: None,
                    stop_reason: None,
                    leftover_mu: None,
                    father_gone: false,
                    relayed: false,
                    last_refusal: None,
                    incomplete: false,
                },
            );
        })
        .unwrap();
        let again = CelautDb::open(dir.join("celaut.db"), &key).unwrap();
        assert_eq!(again.read(|d| d.descendants.len()), 1);
        assert_eq!(again.read(|d| d.instances.len()), 1);
    }

    #[test]
    fn a_removed_node_keeps_its_record_and_leaves_the_list() {
        let mut data = CelautData::default();
        sample(&mut data);
        let peer = "aa".repeat(32);
        data.nodes.get_mut(&peer).unwrap().listed = false;
        assert_eq!(data.listed_nodes().count(), 0);
        // The client id and the deposits stay.
        assert_eq!(data.nodes[&peer].client_id, "c1");
        assert_eq!(data.deposited_nano_erg(&peer), 10_000_000);
        data.nodes.get_mut(&peer).unwrap().listed = true;
        assert_eq!(data.listed_nodes().count(), 1);
    }

    #[test]
    fn a_price_from_before_nodo_636_reads_its_variance_as_the_volatility() {
        let old: InstancePricing = serde_json::from_str(
            r#"{"maintenance_mu": "1000", "maintenance_seconds": 60, "variance": "0.25"}"#,
        )
        .unwrap();
        assert_eq!(old.volatility, "0.25");
        assert_eq!(old.volatility_period_seconds, 0);
        let new: InstancePricing =
            serde_json::from_str(&serde_json::to_string(&old).unwrap()).unwrap();
        assert_eq!(new, old);
    }
}
