//! Celaut services on the free credit of a new client (milestone M2): quotes from
//! several nodes, start, a local port for a slot of the instance, and stop.
//!
//! The client id of each node and the started instances are in the database of the app
//! (`celaut_db`), one for all the wallets. A restart of the app keeps them: the next
//! call to the node uses the same client id, and an instance can be stopped after a
//! restart. Dart gets an instance id that is not the instance token, so the token never
//! leaves Rust. The connections and the local ports are in memory only.
//!
//! Starting and stopping need a full wallet in the app (`docs/celaut/ui.md`); the screen
//! checks that, because this side has no wallet.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use celaut_balancer::QuoteCache;
use celaut_client::db::{
    CelautDb, InstancePricing, InstanceRecord, KeepAlive, NodeRecord, QuoteRecord, Resources,
    ResourcesSource,
};
use celaut_client::hibernation::{self, Hibernation, HibernationError};
use celaut_client::receipts::{check_start, InstanceReceipts, StoredReceipt};
use celaut_client::session::parse_service_id;
use celaut_client::ResourceRefusal;
use celaut_client::{new_client_id, quotes_weighted, ClientError, LocalPort, NodeSession};
use celaut_proto::celaut::{Amount, Configuration, EstimatedCost};
use celaut_wire::{ConnectOptions, Connection, TunnelOpener, WireError};
use once_cell::sync::Lazy;

use super::celaut::{error_of, invalid, CelautError, CelautErrorKind};
use super::celaut_db::{db, now_seconds, storage_error};
use super::celaut_env::{resolve as resolve_environment, EnvChoice};

pub(crate) type Session = Arc<NodeSession<Connection>>;

// The state stays in Rust: not part of the Dart API.
#[flutter_rust_bridge::frb(ignore)]
#[derive(Default)]
pub(crate) struct State {
    /// The connections, by node address.
    sessions: HashMap<String, Session>,
    /// The local ports of each instance, by instance id.
    ports: HashMap<String, HashMap<u16, LocalPort>>,
    /// The local ports to the descendants of an instance, by the key of the descendant
    /// ([`celaut_client::descendants::key`]).
    pub(crate) descendant_ports: HashMap<String, HashMap<u16, LocalPort>>,
}

static STATE: Lazy<Mutex<State>> = Lazy::new(|| Mutex::new(State::default()));
static QUOTES: Lazy<Mutex<QuoteCache>> = Lazy::new(|| Mutex::new(QuoteCache::new()));
/// One new session at a time, so that two calls do not make two clients on one node.
static OPENING: Lazy<tokio::sync::Mutex<()>> = Lazy::new(|| tokio::sync::Mutex::new(()));

pub(crate) fn state() -> Result<std::sync::MutexGuard<'static, State>, CelautError> {
    STATE.lock().map_err(|_| CelautError {
        kind: CelautErrorKind::Storage,
        message: "the state of the Celaut services is broken".into(),
    })
}

/// The address of a node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodeAddress {
    /// A name or an IP address without brackets.
    pub host: String,
    pub port: u16,
}

pub(crate) fn key(address: &NodeAddress) -> String {
    format!("{}:{}", address.host.trim(), address.port)
}

/// The address of `host:port` text from the database.
pub(crate) fn address_of_key(text: &str) -> Option<NodeAddress> {
    let (host, port) = text.rsplit_once(':')?;
    let port = port.parse().ok().filter(|p| *p != 0)?;
    (!host.is_empty()).then(|| NodeAddress {
        host: host.to_string(),
        port,
    })
}

pub(crate) fn check(address: &NodeAddress) -> Result<(), CelautError> {
    let host = address.host.trim();
    if host.is_empty() || host.contains(|c: char| c.is_whitespace() || c == '/') {
        return Err(invalid(
            "The host is empty or has characters that a host cannot have.",
        ));
    }
    if address.port == 0 {
        return Err(invalid("The port must be from 1 to 65535."));
    }
    Ok(())
}

/// The configuration of a start: the defaults of the node, and the balance of the
/// instance at the start if `initial_mu` is given. The default of a node is one hour of
/// the resources of the service, which can be more than the free credit of a client.
pub(crate) fn configuration(initial_mu: Option<String>) -> Result<Configuration, CelautError> {
    let Some(text) = initial_mu
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
    else {
        return Ok(Configuration::default());
    };
    let amount = Amount { n: text };
    match celaut_balancer::amount(Some(&amount)) {
        Ok(0) | Err(_) => Err(invalid(
            "The start balance must be a whole number of MU, more than 0.",
        )),
        Ok(_) => Ok(Configuration {
            initial_mu: Some(amount),
            ..Default::default()
        }),
    }
}

/// The configuration of a start: the one of [`configuration`] with the environment
/// variables that the user chose. Only a start has them; a quote uses [`configuration`].
pub(crate) fn start_configuration(
    initial_mu: Option<String>,
    environment: &[EnvChoice],
) -> Result<Configuration, CelautError> {
    let mut configuration = configuration(initial_mu)?;
    configuration.environment_variables = resolve_environment(environment)?;
    Ok(configuration)
}

pub(crate) fn service_id(text: &str) -> Result<[u8; 32], CelautError> {
    parse_service_id(text)
        .ok_or_else(|| invalid("The service id must be 64 hexadecimal characters."))
}

/// Check the node on `connection` with the client id that the database has for it, or
/// with a new client (which gets the free credit of the node) that goes into the
/// database. The client id is in the database before the session is used, so that a
/// deposit to it is never lost.
///
/// If the node does not know the stored client id, the answer is a
/// [`CelautErrorKind::ClientUnknown`] error, and nothing changes: the user chooses
/// between [`celaut_new_client`] and a retry later (`docs/celaut/ui.md`, section 3).
pub(crate) async fn open_session(
    connection: Connection,
    address_key: &str,
) -> Result<NodeSession<Connection>, CelautError> {
    let _one = OPENING.lock().await;
    let db = db();
    let peer_id = connection.peer_id().to_string();
    let stored = db.read(|d| d.nodes.get(&peer_id).map(|n| n.client_id.clone()));
    let session = match stored.filter(|c| !c.is_empty()) {
        Some(client_id) => NodeSession::resume(connection, &peer_id, client_id, &*db)
            .await
            .map_err(error_of)?,
        None => new_client_session(connection, &peer_id).await?,
    };
    db.update(|d| d.note_address(&peer_id, address_key))
        .map_err(storage_error)?;
    Ok(session)
}

/// A new client on the node (`GenerateClient`), kept in the database at once. An old
/// client id of the node goes to its earlier ids. Then the balance of the new client is
/// read: it is the free credit of the node.
async fn new_client_session(
    connection: Connection,
    peer_id: &str,
) -> Result<NodeSession<Connection>, CelautError> {
    let db = db();
    let session = NodeSession::open(connection, peer_id, &*db)
        .await
        .map_err(error_of)?;
    let client_id = session.client_id().to_string();
    let keep = |free: Option<u128>| {
        db.update(|d| match d.nodes.get_mut(peer_id) {
            Some(node) if node.client_id == client_id => {
                node.free_credit_mu = free.map(|f| f.to_string());
            }
            Some(node) => node.replace_client(client_id.clone(), free),
            None => {
                d.nodes.insert(
                    peer_id.to_string(),
                    NodeRecord::new_client(client_id.clone(), free),
                );
            }
        })
        .map_err(storage_error)
    };
    keep(None)?;
    if let Ok(free) = session.balance().await {
        keep(Some(free))?;
    }
    Ok(session)
}

/// The client of the app on a node after [`celaut_new_client`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NewClientView {
    pub peer_id: String,
    /// The free credit of the new client, in MU of the node. `None` is unknown.
    pub free_credit_mu: Option<String>,
    /// How many client ids of this node the app used before. Their balance is lost for
    /// the app.
    pub earlier_clients: u32,
}

/// Make a new client on the node, after the node forgot the stored client id and the
/// user chose "New client". The balance of the old client is lost for the app. The
/// deposits of the node and its limit stay in the database.
#[flutter_rust_bridge::frb]
pub async fn celaut_new_client(node: NodeAddress) -> Result<NewClientView, CelautError> {
    check(&node)?;
    let key = key(&node);
    let connection = Connection::connect(node.host.trim(), node.port, ConnectOptions::default())
        .await
        .map_err(|e| error_of(e.into()))?;
    let session = {
        let _one = OPENING.lock().await;
        let peer_id = connection.peer_id().to_string();
        new_client_session(connection, &peer_id).await?
    };
    let peer_id = session.peer_id().to_string();
    db().update(|d| d.note_address(&peer_id, &key))
        .map_err(storage_error)?;
    {
        // A connection at another address of this node still has the old client id.
        let mut s = state()?;
        s.sessions.retain(|_, open| open.peer_id() != peer_id);
        s.sessions.insert(key, Arc::new(session));
    }
    Ok(db().read(|d| {
        let node = d.nodes.get(&peer_id);
        NewClientView {
            peer_id: peer_id.clone(),
            free_credit_mu: node.and_then(|n| n.free_credit_mu.clone()),
            earlier_clients: node
                .map(|n| u32::try_from(n.earlier_client_ids.len()).unwrap_or(u32::MAX))
                .unwrap_or(0),
        }
    }))
}

/// The session of `address`: the open one, or a new connection with the client id of
/// the node from the database (or a new client on the node).
pub(crate) async fn session(address: &NodeAddress) -> Result<Session, CelautError> {
    session_with(address, ConnectOptions::default()).await
}

/// The session of `address`, which must be held by the node `peer_id` (the lowercase hex
/// of its identity key): the TLS handshake fails for any other key, so an address that
/// another node holds is never used. `connect_timeout` is for the dial and the handshake
/// (a route through Tor needs longer).
pub(crate) async fn session_pinned(
    address: &NodeAddress,
    peer_id: &str,
    connect_timeout: std::time::Duration,
) -> Result<Session, CelautError> {
    session_with(
        address,
        ConnectOptions {
            expected_peer_id: Some(peer_id.to_string()),
            connect_timeout,
            ..ConnectOptions::default()
        },
    )
    .await
}

async fn session_with(
    address: &NodeAddress,
    options: ConnectOptions,
) -> Result<Session, CelautError> {
    check(address)?;
    let key = key(address);
    if let Some(s) = state()?.sessions.get(&key) {
        // A session that is open belongs to the node that it proved. With a pin, only the
        // node that the caller expects can use it.
        if options
            .expected_peer_id
            .as_deref()
            .is_none_or(|p| p == s.peer_id())
        {
            return Ok(s.clone());
        }
    }
    let connection = Connection::connect(address.host.trim(), address.port, options)
        .await
        .map_err(|e| error_of(e.into()))?;
    let session = Arc::new(open_session(connection, &key).await?);
    // Another call may have made one at the same time: keep the first.
    let mut state = state()?;
    Ok(match state.sessions.get(&key) {
        Some(open) if open.peer_id() == session.peer_id() => open.clone(),
        _ => {
            state.sessions.insert(key, session.clone());
            session
        }
    })
}

/// Forget the connection of `address` after a connection error, so that the next call
/// connects again. The client id stays in the database.
pub(crate) fn forget_if_broken(address: &NodeAddress, error: &ClientError) {
    if matches!(error, ClientError::Wire(WireError::Connect(_))) {
        if let Ok(mut s) = STATE.lock() {
            s.sessions.remove(&key(address));
        }
    }
}

/// The same as [`forget_if_broken`], for a connection that failed before any session:
/// forget what is stored for the address `key` (`host:port`), so that the next call
/// connects again.
pub(crate) fn forget_if_broken_key(key: &str) {
    if let Ok(mut s) = STATE.lock() {
        s.sessions.remove(key);
    }
}

/// One quote, in the MU of the node and, if the node gives an ERG rate, in nanoERG. An
/// amount that the node did not give is empty (the screen shows "unknown", not 0).
#[derive(Debug, Clone, PartialEq)]
pub struct QuoteView {
    pub address: NodeAddress,
    pub peer_id: String,
    /// The cost of the start (charged by StartService), in MU of the node.
    pub cost_mu: String,
    pub init_maintenance_mu: String,
    pub max_maintenance_mu: String,
    pub maintenance_seconds_loop: i32,
    pub variance: f32,
    /// The cost for the comparison in nanoERG, or `None` if the node gives no ERG rate
    /// (then its price is not compared, and it comes last).
    pub compared_nano_erg: Option<String>,
    /// The balance of this client on the node, in MU of the node (empty if the app could
    /// not read it). The app compares it with `cost_mu` before it asks the node to start
    /// the service.
    pub client_balance_mu: String,
}

/// A node that gave no quote.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuoteFailureView {
    pub address: NodeAddress,
    pub kind: CelautErrorKind,
    pub message: String,
}

/// The quotes, best first, and the nodes that failed.
#[derive(Debug, Clone, PartialEq)]
pub struct QuotesView {
    pub quotes: Vec<QuoteView>,
    pub failures: Vec<QuoteFailureView>,
}

/// The amount as text, or empty if the node did not give it.
pub(crate) fn n(amount: &Option<Amount>) -> String {
    amount.as_ref().map(|a| a.n.clone()).unwrap_or_default()
}

pub(crate) fn quote_view(address: NodeAddress, peer_id: String, q: &EstimatedCost) -> QuoteView {
    QuoteView {
        address,
        peer_id,
        cost_mu: n(&q.cost),
        init_maintenance_mu: n(&q.init_maintenance_cost),
        max_maintenance_mu: n(&q.max_maintenance_cost),
        maintenance_seconds_loop: q.maintenance_seconds_loop,
        variance: q.variance,
        compared_nano_erg: None,
        client_balance_mu: String::new(),
    }
}

/// How long the app waits for the balance of the client on a node that already quoted.
const BALANCE_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(5);

/// Ask each node for the price of the service, and give the quotes best first
/// (`docs/celaut/balancer.md`). The nodes must already have the service.
#[flutter_rust_bridge::frb]
pub async fn celaut_quote_service(
    nodes: Vec<NodeAddress>,
    service_id_hex: String,
    initial_mu: Option<String>,
) -> Result<QuotesView, CelautError> {
    let id = service_id(&service_id_hex)?;
    let configuration = configuration(initial_mu)?;
    if nodes.is_empty() {
        return Err(invalid("Give at least one node."));
    }
    let mut failures = Vec::new();
    let mut open: Vec<(NodeAddress, Session)> = Vec::new();
    let connects = nodes
        .iter()
        .map(|a| async move { (a.clone(), session(a).await) });
    for (address, result) in futures::future::join_all(connects).await {
        match result {
            Ok(s) => open.push((address, s)),
            Err(e) => failures.push(QuoteFailureView {
                address,
                kind: e.kind,
                message: e.message,
            }),
        }
    }
    let sessions: Vec<&NodeSession<Connection>> = open.iter().map(|(_, s)| s.as_ref()).collect();
    // The priority that the user gave to each node weighs in the order.
    // and so do the weights of the score that the user set.
    let (standings, weights) = db().read(|d| (d.standings(), d.balancer_weights()));
    let answer = quotes_weighted(
        &sessions,
        id,
        &configuration,
        &QUOTES,
        None,
        &standings,
        &weights,
    )
    .await;
    let address_of = |peer_id: &str| {
        open.iter()
            .find(|(_, s)| s.peer_id() == peer_id)
            .map(|(a, _)| a.clone())
            .unwrap_or(NodeAddress {
                host: String::new(),
                port: 0,
            })
    };
    for failure in answer.failures {
        let address = address_of(&failure.peer_id);
        forget_if_broken(&address, &failure.error);
        let e = error_of(failure.error);
        failures.push(QuoteFailureView {
            address,
            kind: e.kind,
            message: e.message,
        });
    }
    let at = now_seconds();
    let stored = db().update(|d| {
        for r in &answer.ranked {
            d.add_quote(QuoteRecord {
                peer_id: r.candidate.peer_id.clone(),
                service_id: hex::encode(id),
                cost_mu: n(&r.candidate.quote.cost),
                at,
            });
        }
    });
    if let Err(e) = stored {
        tracing::warn!("the quotes are not stored: {e}");
    }
    // The balance of the client on each node that quoted, read at the same time. A node
    // that does not answer in time leaves it unknown; that never stops a launch.
    let balances = futures::future::join_all(answer.ranked.iter().map(|r| {
        let peer_id = r.candidate.peer_id.clone();
        let session = open
            .iter()
            .find(|(_, s)| s.peer_id() == peer_id)
            .map(|(_, s)| s.clone());
        async move {
            let session = session?;
            tokio::time::timeout(BALANCE_TIMEOUT, session.balance())
                .await
                .ok()?
                .ok()
        }
    }))
    .await;
    let quotes = answer
        .ranked
        .iter()
        .zip(balances)
        .map(|(r, balance)| {
            let peer_id = r.candidate.peer_id.clone();
            let mut view = quote_view(address_of(&peer_id), peer_id, &r.candidate.quote);
            view.compared_nano_erg = r.cost_nano_erg.map(|c| format!("{c:.0}"));
            view.client_balance_mu = balance.map(|b| b.to_string()).unwrap_or_default();
            view
        })
        .collect();
    Ok(QuotesView { quotes, failures })
}

/// A started instance.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstanceView {
    /// A local id for the calls below. It is not the instance token.
    pub instance_id: String,
    pub peer_id: String,
    /// The internal ports of the instance, for [`celaut_open_tunnel`].
    pub slots: Vec<u16>,
    /// The ports that follow the chat convention (`docs/celaut/chat.md`), a part of
    /// `slots`. The chat screen uses the first one.
    pub chat_slots: Vec<u16>,
    /// The ports that a browser can open (`tcp` and `http`, no chat), a part of `slots`.
    pub web_slots: Vec<u16>,
    /// The balance of this client on the node after the start, in MU (empty if
    /// unknown).
    pub client_balance_mu: String,
}

/// Start the service on the node. The node charges the quote to the balance of the
/// client of the app on that node. The node runs it itself (no delegation). The
/// instance goes into the database of the app.
///
/// `environment` has the values of the environment variables of the service
/// (`docs/celaut/env-variables.md`). Only a start carries them: a quote never does, so
/// a node that only prices the service does not read them. A variable that the user
/// skipped is not in the list, so it is not in the configuration.
#[flutter_rust_bridge::frb]
pub async fn celaut_start_service(
    node: NodeAddress,
    service_id_hex: String,
    initial_mu: Option<String>,
    environment: Vec<EnvChoice>,
) -> Result<InstanceView, CelautError> {
    let id = service_id(&service_id_hex)?;
    let configuration = start_configuration(initial_mu, &environment)?;
    // What the start receipt must sign: the variables and the balance that the phone sent.
    let sent_envs = configuration.environment_variables.clone();
    let sent_mu = configuration.initial_mu.as_ref().map(|a| a.n.clone());
    let session = session(&node).await?;
    let before = session.balance().await.ok();
    let started = match session.start(id, configuration).await {
        Ok(s) => s,
        Err(e) => {
            forget_if_broken(&node, &e);
            return Err(error_of(e));
        }
    };
    let after = session.balance().await.ok();
    let instance_id = new_client_id().map_err(error_of)?;
    let record = InstanceRecord {
        peer_id: session.peer_id().to_string(),
        address: key(&node),
        token: started.token.clone(),
        service_id: hex::encode(id),
        slots: started.slots(),
        chat_slots: started.chat_slots(),
        web_slots: started.web_slots(),
        started_at: now_seconds(),
        start_charge_mu: match (before, after) {
            (Some(b), Some(a)) if b >= a => Some((b - a).to_string()),
            _ => None,
        },
        name: None,
        alias: None,
        title: None,
        topped_up_mu: None,
        stopped_at: None,
        refund_mu: None,
        pricing: None,
        keep_alive: None,
        // The answer of StartService has no resources (`ServiceInstance` holds the token,
        // the addresses and the receipt), so there is no value of the start to keep. The
        // first value comes from a read of the node at the hibernation.
        awake_resources: None,
        awake_source: None,
        hibernated_at: None,
        hibernated_price: None,
    };
    let view = InstanceView {
        instance_id: instance_id.clone(),
        peer_id: record.peer_id.clone(),
        slots: record.slots.clone(),
        chat_slots: record.chat_slots.clone(),
        web_slots: record.web_slots.clone(),
        client_balance_mu: after.map(|b| b.to_string()).unwrap_or_default(),
    };
    let start_receipt = started.receipt.as_ref().map(|r| {
        let faults = check_start(
            r,
            session.peer_id(),
            &started.token,
            &id,
            &sent_envs,
            sent_mu.as_deref(),
        );
        StoredReceipt::new(r, faults)
    });
    db().update(|d| {
        // A node that gave a start receipt for an instance before must give one now.
        let expects_start = start_receipt.is_none()
            && d.instances.iter().any(|(id, r)| {
                r.peer_id == record.peer_id && d.receipts.get(id).is_some_and(|k| k.start.is_some())
            });
        d.receipts.insert(
            instance_id.clone(),
            InstanceReceipts {
                start: start_receipt,
                expects_start,
                ..Default::default()
            },
        );
        d.instances.insert(instance_id, record);
    })
    .map_err(storage_error)?;
    Ok(view)
}

pub(crate) fn unknown_instance() -> CelautError {
    invalid("This instance is not known. It was deleted.")
}

fn stopped_instance() -> CelautError {
    invalid("This instance was stopped.")
}

/// The instance `instance_id` from the database, and a session on its node. A stopped
/// instance has none: the node does not run it.
pub(crate) async fn instance(instance_id: &str) -> Result<(Session, InstanceRecord), CelautError> {
    let record = db()
        .read(|d| d.instances.get(instance_id).cloned())
        .ok_or_else(unknown_instance)?;
    if record.stopped_at.is_some() {
        return Err(stopped_instance());
    }
    let address = address_of_key(&record.address).ok_or_else(|| CelautError {
        kind: CelautErrorKind::Storage,
        message: format!(
            "the address of the instance is not valid: {}",
            record.address
        ),
    })?;
    let session = session(&address).await?;
    if session.peer_id() != record.peer_id {
        return Err(CelautError {
            kind: CelautErrorKind::IdentityMismatch,
            message: format!(
                "the node at {} is now {}, not the node of the instance {}",
                record.address,
                session.peer_id(),
                record.peer_id
            ),
        });
    }
    Ok((session, record))
}

/// An instance in the database, without its token.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstanceListView {
    pub instance_id: String,
    pub peer_id: String,
    /// The address (`host:port`) of the node.
    pub address: String,
    pub service_id: String,
    pub slots: Vec<u16>,
    /// The ports that follow the chat convention, a part of `slots`.
    pub chat_slots: Vec<u16>,
    /// The ports that a browser can open, a part of `slots`.
    pub web_slots: Vec<u16>,
    /// The time of the start, in Unix seconds.
    pub started_at: i64,
    /// What the start took from the balance of the client, in MU (empty if unknown).
    pub start_charge_mu: String,
    /// The name of the skill or the service file at the start (empty if unknown).
    pub name: String,
    /// The name that the user gave the instance in the app (empty if none). Local only.
    pub alias: String,
    /// The title that the service gave the conversation, the last one that the app read
    /// (empty if none).
    pub title: String,
    /// The time of the stop, in Unix seconds; none while the instance runs.
    pub stopped_at: Option<i64>,
    /// What the node gave back at the stop, in MU (empty if unknown or not stopped).
    pub refund_mu: String,
    /// The time of the hibernation, in Unix seconds; none while the instance is awake.
    pub hibernated_at: Option<i64>,
    /// The resources that the app keeps for the instance: the ones that a wake sends
    /// while it is hibernated, the last known ones while it is awake. None if the app
    /// has not got them yet.
    pub awake_resources: Option<AwakeResourcesView>,
}

/// The instances that the app started, whichever wallet was open: the ones that run,
/// and the stopped ones that the user did not delete.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_instances() -> Vec<InstanceListView> {
    db().read(|d| {
        d.instances
            .iter()
            .map(|(id, r)| InstanceListView {
                instance_id: id.clone(),
                peer_id: r.peer_id.clone(),
                address: r.address.clone(),
                service_id: r.service_id.clone(),
                slots: r.slots.clone(),
                chat_slots: r.chat_slots.clone(),
                web_slots: r.web_slots.clone(),
                started_at: r.started_at,
                start_charge_mu: r.start_charge_mu.clone().unwrap_or_default(),
                name: r.name.clone().unwrap_or_default(),
                alias: r.alias.clone().unwrap_or_default(),
                title: r.title.clone().unwrap_or_default(),
                stopped_at: r.stopped_at,
                refund_mu: r.refund_mu.clone().unwrap_or_default(),
                hibernated_at: r.hibernated_at,
                awake_resources: awake_view(r),
            })
            .collect()
    })
}

/// Keep the name that the user saw at the start (the skill or the service file), so
/// that the list of conversations shows it after a restart. An empty name removes it.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_name_instance(instance_id: String, name: String) -> Result<(), CelautError> {
    let name = name.trim().to_string();
    let known = db()
        .update(|d| match d.instances.get_mut(&instance_id) {
            Some(r) => {
                r.name = (!name.is_empty()).then_some(name);
                true
            }
            None => false,
        })
        .map_err(storage_error)?;
    if known {
        Ok(())
    } else {
        Err(unknown_instance())
    }
}

/// The longest title of a service that the app keeps, in characters. The chat client cuts
/// a title to this length before it keeps it (`ChatClient.titleMaxChars`).
pub(crate) const TITLE_MAX_CHARS: usize = 80;

/// Keep the title that the service gave the conversation of an instance
/// (`docs/celaut/chat.md`, section 6.10), so that the list shows it after a restart and
/// after a stop. An empty title removes it. It does not touch the name that the user gave
/// the instance: that name stays stronger.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_set_instance_title(instance_id: String, title: String) -> Result<(), CelautError> {
    let title = title.split_whitespace().collect::<Vec<_>>().join(" ");
    if title.chars().count() > TITLE_MAX_CHARS {
        return Err(invalid("The title is too long."));
    }
    let known = db()
        .update(|d| match d.instances.get_mut(&instance_id) {
            Some(r) => {
                r.title = (!title.is_empty()).then_some(title);
                true
            }
            None => false,
        })
        .map_err(storage_error)?;
    if known {
        Ok(())
    } else {
        Err(unknown_instance())
    }
}

/// The longest name that the user can give an instance, in characters.
pub(crate) const ALIAS_MAX_CHARS: usize = 60;

/// Give an instance a name of the user's choice, for this app only (Josemi, 2026-10-23).
/// The name stays in the Celaut database of the app and never goes to the node. An empty
/// name removes it: the list shows the name of the skill or the service file again.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_rename_instance(instance_id: String, alias: String) -> Result<(), CelautError> {
    let alias = alias.split_whitespace().collect::<Vec<_>>().join(" ");
    if alias.chars().count() > ALIAS_MAX_CHARS {
        return Err(invalid("The name is too long."));
    }
    let known = db()
        .update(|d| match d.instances.get_mut(&instance_id) {
            Some(r) => {
                r.alias = (!alias.is_empty()).then_some(alias);
                true
            }
            None => false,
        })
        .map_err(storage_error)?;
    if known {
        Ok(())
    } else {
        Err(unknown_instance())
    }
}

/// Delete a stopped instance: take it out of the database. The user asks for it on a
/// stopped row of the list. An instance that was not stopped is refused and kept: the
/// app never forgets the token of an instance that may still run, even if its node
/// does not answer (`docs/celaut/decisions.md`).
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_forget_instance(instance_id: String) -> Result<(), CelautError> {
    let removed = db()
        .update(|d| match d.instances.get(&instance_id) {
            None => Err(unknown_instance()),
            Some(r) if r.stopped_at.is_none() => Err(invalid(
                "This instance was not stopped. Stop it before you delete it.",
            )),
            Some(_) => {
                d.instances.remove(&instance_id);
                d.receipts.remove(&instance_id);
                d.remove_descendants_of(&instance_id);
                Ok(())
            }
        })
        .map_err(storage_error)?;
    removed?;
    let prefix = format!("{instance_id}/");
    let mut s = state()?;
    drop(s.ports.remove(&instance_id));
    s.descendant_ports.retain(|k, _| !k.starts_with(&prefix));
    Ok(())
}

/// A port on 127.0.0.1 for the slot of the instance. The same port while the
/// instance runs. Each TCP connection to it opens one `ServiceTunnel` stream, which
/// the node charges (`TUNNEL_OPEN_MU`): keep HTTP connections alive.
#[flutter_rust_bridge::frb]
pub async fn celaut_open_tunnel(instance_id: String, slot: u16) -> Result<u16, CelautError> {
    let (session, record) = instance(&instance_id).await?;
    if !record.slots.contains(&slot) {
        return Err(invalid("The instance has no such slot."));
    }
    let opener: Arc<dyn TunnelOpener> = Arc::new(session.transport().clone());
    {
        let mut s = state()?;
        let ports = s.ports.entry(instance_id.clone()).or_default();
        match ports.get(&slot) {
            // The port stays, and so does its address in the browser. Its next streams
            // use the current connection to the node: the one it had can be broken.
            Some(port) if port.is_alive() => {
                port.set_opener(opener);
                return Ok(port.port());
            }
            // The task of the port ended: make a new one.
            Some(_) => {
                ports.remove(&slot);
            }
            None => {}
        }
    }
    let sink = super::celaut_receipts::sink(instance_id.clone());
    let port = LocalPort::bind_preferred(
        opener,
        record.token.clone(),
        slot,
        Some(sink),
        Some(preferred_port(&instance_id, slot)),
    )
    .await
    .map_err(|e| CelautError {
        kind: CelautErrorKind::Unreachable,
        message: format!("cannot open a local port: {e}"),
    })?;
    let mut s = state()?;
    // A call that came in while this one bound its port wins: its port is kept.
    Ok(s.ports
        .entry(instance_id)
        .or_default()
        .entry(slot)
        .or_insert(port)
        .port())
}

/// The port that an instance slot asks for. It comes from the id of the instance and the
/// slot, so it is the same in each start of the app, and a web page keeps its origin (its
/// cookies and its local storage). It is under the range of the ports that the system
/// gives to outgoing connections. If it is taken, the port is another one.
pub(crate) fn preferred_port(instance_id: &str, slot: u16) -> u16 {
    // FNV-1a: the same value on every run and every platform.
    let mut h: u32 = 0x811c_9dc5;
    for b in instance_id.bytes().chain(slot.to_be_bytes()) {
        h ^= u32::from(b);
        h = h.wrapping_mul(0x0100_0193);
    }
    10_000 + (h % 22_000) as u16
}

/// The state of an instance.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstanceStatusView {
    /// The balance of the instance on the node, in MU.
    pub instance_balance_mu: String,
    /// What the instance cost so far, in MU: what the start took from the client,
    /// less what the instance still has. Empty if unknown.
    pub cost_so_far_mu: String,
    /// How many tunnel streams the local ports opened (one per TCP connection).
    pub streams_opened: u64,
    /// The last error of a tunnel stream, if any.
    pub last_tunnel_error: Option<String>,
}

/// What an instance cost so far: the charge of the start, plus what the app moved to it
/// later (the automatic top-up), less the balance that the instance still has. `None` if
/// the charge is not known.
pub(crate) fn cost_so_far(
    start_charge_mu: Option<&str>,
    topped_up_mu: Option<&str>,
    instance_balance: u128,
) -> Option<u128> {
    let charge: u128 = start_charge_mu?.parse().ok()?;
    let topped: u128 = topped_up_mu.and_then(|t| t.parse().ok()).unwrap_or(0);
    Some((charge + topped).saturating_sub(instance_balance))
}

/// The node answered that the token of a hibernated instance is not one of its instances:
/// it stopped the instance after the grace period for lack of balance (nodo
/// `docs/PRICING.md`, "Hibernating an instance"), and its disk is gone. Mark the record
/// stopped, as a stop does, with no refund (the node kept none). Gives true if the record
/// changed. An awake instance, a stopped one, and any other error change nothing: only a
/// hibernated record has a reason to read "unknown token" as "stopped by the node", because
/// the app does not know the state of an instance that it cannot reach.
pub(crate) fn mark_gone_if_hibernated(
    db: &CelautDb,
    instance_id: &str,
    error: &ClientError,
) -> bool {
    if !error.is_unknown_token() {
        return false;
    }
    db.update(|d| match d.instances.get_mut(instance_id) {
        Some(r) if r.stopped_at.is_none() && r.hibernated_at.is_some() => {
            r.stopped_at = Some(now_seconds());
            true
        }
        _ => false,
    })
    .unwrap_or(false)
}

/// The balance of the instance and the use of its tunnels.
#[flutter_rust_bridge::frb]
pub async fn celaut_instance_status(
    instance_id: String,
) -> Result<InstanceStatusView, CelautError> {
    let (session, record) = instance(&instance_id).await?;
    let (streams, last) = {
        let s = state()?;
        let ports = s.ports.get(&instance_id);
        (
            ports.map_or(0, |p| p.values().map(LocalPort::streams_opened).sum()),
            ports.and_then(|p| p.values().find_map(LocalPort::last_error)),
        )
    };
    let balance = match session.instance_balance(&record.token).await {
        Ok(balance) => balance,
        Err(e) => {
            // The node stops a hibernated instance that cannot pay its disk, after the
            // grace, and forgets its token. Then it is gone, and the record must say so.
            if mark_gone_if_hibernated(&db(), &instance_id, &e) {
                drop(state()?.ports.remove(&instance_id));
            }
            return Err(error_of(e));
        }
    };
    Ok(InstanceStatusView {
        instance_balance_mu: balance.to_string(),
        cost_so_far_mu: cost_so_far(
            record.start_charge_mu.as_deref(),
            record.topped_up_mu.as_deref(),
            balance,
        )
        .map(|c| c.to_string())
        .unwrap_or_default(),
        streams_opened: streams,
        last_tunnel_error: last,
    })
}

/// What the app knows to keep an instance running: the price of its node, and whether the
/// user asked for it to run until they stop it.
#[derive(Debug, Clone, PartialEq)]
pub struct InstancePlanView {
    /// The app tops the instance up when its balance is low.
    pub keep_alive: bool,
    /// The most that the app may move from now on, in MU (empty: no limit).
    pub budget_mu: String,
    /// What the app moved since the user turned `keep_alive` on, in MU (empty if off).
    pub spent_mu: String,
    /// The maintenance of one period, in MU (empty if the app does not know it).
    pub maintenance_mu: String,
    /// The seconds of one period (0 if unknown).
    pub maintenance_seconds: u32,
    /// The margin of the node for the difference of the real cost.
    pub variance: f64,
    /// The app keeps the instance hibernated. A top-up does not wake it, and the node
    /// charges it for its disk only.
    pub hibernated: bool,
    /// `maintenance_mu` is the price of the disk only. False for a hibernated instance
    /// whose disk price the app could not work out: `maintenance_mu` is then the price
    /// of the awake instance, which is more than the node charges.
    pub disk_only: bool,
    /// The fee of the call that wakes the instance, in MU. The instance pays it, so a
    /// hibernated instance needs it in its balance (empty if the app does not know it).
    pub wake_fee_mu: String,
}

/// What the app moved to the instance since `keep_alive` started, in MU.
pub(crate) fn spent_since(topped_up_mu: Option<&str>, at_start_mu: &str) -> u128 {
    let now: u128 = topped_up_mu.and_then(|t| t.parse().ok()).unwrap_or(0);
    let before: u128 = at_start_mu.parse().unwrap_or(0);
    now.saturating_sub(before)
}

/// The plan of an instance: its price and its keep-alive settings. Reads the database
/// only; no node is asked.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_instance_plan(instance_id: String) -> Result<InstancePlanView, CelautError> {
    db().read(|d| {
        let r = d.instances.get(&instance_id).ok_or_else(unknown_instance)?;
        let keep = r.keep_alive.as_ref();
        let (mut maintenance_mu, maintenance_seconds, variance) = match &r.pricing {
            Some(p) => (
                p.maintenance_mu.clone(),
                p.maintenance_seconds,
                p.variance.parse().unwrap_or(0.0),
            ),
            None => (String::new(), 0, 0.0),
        };
        // A hibernated instance costs its disk only: the keep-alive aims at that.
        let hibernated = r.hibernated_at.is_some();
        let price = r.hibernated_price.as_ref().filter(|_| hibernated);
        if let Some(p) = price.filter(|_| !maintenance_mu.is_empty()) {
            maintenance_mu = p.disk_maintenance_mu.clone();
        }
        let disk_only = price.is_some() && !maintenance_mu.is_empty();
        Ok(InstancePlanView {
            keep_alive: keep.is_some(),
            budget_mu: keep.and_then(|k| k.budget_mu.clone()).unwrap_or_default(),
            spent_mu: keep
                .map(|k| {
                    spent_since(r.topped_up_mu.as_deref(), &k.topped_up_at_start_mu).to_string()
                })
                .unwrap_or_default(),
            maintenance_mu,
            maintenance_seconds,
            variance,
            hibernated,
            disk_only,
            wake_fee_mu: price.map(|p| p.wake_fee_mu.clone()).unwrap_or_default(),
        })
    })
}

/// Keep the price of the node of an instance, from the quote that won its start, so that
/// the app can say how long a balance lasts and how much a time costs.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_set_instance_pricing(
    instance_id: String,
    maintenance_mu: String,
    maintenance_seconds: u32,
    variance: f64,
) -> Result<(), CelautError> {
    if maintenance_mu.parse::<u128>().map_or(true, |m| m == 0) || maintenance_seconds == 0 {
        return Err(invalid("The price of the maintenance is not valid."));
    }
    let known = db()
        .update(|d| match d.instances.get_mut(&instance_id) {
            Some(r) => {
                r.pricing = Some(InstancePricing {
                    maintenance_mu,
                    maintenance_seconds,
                    variance: variance.max(0.0).to_string(),
                });
                true
            }
            None => false,
        })
        .map_err(storage_error)?;
    if known {
        Ok(())
    } else {
        Err(unknown_instance())
    }
}

/// Turn "run until I stop it" on or off for a running instance (Josemi, 2026-10-29).
/// `budget_mu` is the most that the app may move from now on; empty or none is no limit.
/// Turning it on again restarts the count of the spent amount. This moves no credit.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_set_keep_alive(
    instance_id: String,
    enabled: bool,
    budget_mu: Option<String>,
) -> Result<(), CelautError> {
    let budget = match budget_mu
        .as_deref()
        .map(str::trim)
        .filter(|b| !b.is_empty())
    {
        None => None,
        Some(text) => match text.parse::<u128>() {
            Ok(b) if b > 0 => Some(b.to_string()),
            _ => return Err(invalid("The limit is not a number of MU above zero.")),
        },
    };
    db().update(|d| match d.instances.get_mut(&instance_id) {
        None => Err(unknown_instance()),
        Some(r) if r.stopped_at.is_some() => Err(stopped_instance()),
        Some(r) => {
            r.keep_alive = enabled.then(|| KeepAlive {
                budget_mu: budget,
                topped_up_at_start_mu: r.topped_up_mu.clone().unwrap_or_default(),
            });
            Ok(())
        }
    })
    .map_err(storage_error)?
}

/// The credit of the app on the node of the instance, in MU: what is left to spend on it
/// and on the other instances of that node. If it runs out, the user must make a deposit.
#[flutter_rust_bridge::frb]
pub async fn celaut_instance_credit(instance_id: String) -> Result<String, CelautError> {
    let (session, _) = instance(&instance_id).await?;
    let credit = session.balance().await.map_err(error_of)?;
    Ok(credit.to_string())
}

/// The balances after an automatic top-up.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopUpView {
    /// The balance of the instance on the node, in MU (empty if the app could not read it).
    pub instance_balance_mu: String,
    /// The credit of the client on the node, in MU (empty if the app could not read it).
    pub client_balance_mu: String,
}

/// The most that one top-up moves, in MU.
pub(crate) const TOP_UP_MAX_MU: u128 = 100_000_000;

/// Move `amount_mu` MU of the credit of the app on the node of the instance to the
/// instance (`ModifyDeposit`), for the automatic top-up (Josemi, 2026-10-23). This moves
/// credit that the client already has: nothing goes on a ledger, nothing is signed. If
/// the credit is less than the amount, nothing is asked of the node and the error is
/// [`CelautErrorKind::InsufficientCredit`]; the app then asks the user, who can make a
/// deposit, which has its own confirmation and PIN.
#[flutter_rust_bridge::frb]
pub async fn celaut_top_up_instance(
    instance_id: String,
    amount_mu: String,
) -> Result<TopUpView, CelautError> {
    let mu: u128 = amount_mu
        .trim()
        .parse()
        .map_err(|_| invalid("The amount is not a number of MU."))?;
    if mu == 0 || mu > TOP_UP_MAX_MU {
        return Err(invalid(
            "The amount of a top-up must be from 1 to 100,000,000 MU.",
        ));
    }
    let (session, record) = instance(&instance_id).await?;
    let credit = session.balance().await.map_err(error_of)?;
    if credit < mu {
        return Err(CelautError {
            kind: CelautErrorKind::InsufficientCredit,
            message: format!("credit {credit} MU, top-up {mu} MU"),
        });
    }
    session.top_up(&record.token, mu).await.map_err(error_of)?;
    db().update(|d| {
        if let Some(r) = d.instances.get_mut(&instance_id) {
            let before: u128 = r
                .topped_up_mu
                .as_deref()
                .and_then(|t| t.parse().ok())
                .unwrap_or(0);
            r.topped_up_mu = Some((before + mu).to_string());
        }
    })
    .map_err(storage_error)?;
    let instance_balance = session
        .instance_balance(&record.token)
        .await
        .map(|b| b.to_string())
        .unwrap_or_default();
    let client_balance = session
        .balance()
        .await
        .map(|b| b.to_string())
        .unwrap_or_default();
    Ok(TopUpView {
        instance_balance_mu: instance_balance,
        client_balance_mu: client_balance,
    })
}

/// What a stop gives back.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StopView {
    /// The unused balance of the instance that the node gave back to the client, in MU.
    pub refund_mu: String,
    /// The balance of the client after the stop, in MU (empty if unknown).
    pub client_balance_mu: String,
}

/// Close the local ports of the instance and stop it on the node. When the node
/// confirms the stop, the database marks the instance stopped, with the refund; it
/// stays there until the user deletes it ([`celaut_forget_instance`]).
#[flutter_rust_bridge::frb]
pub async fn celaut_stop_service(instance_id: String) -> Result<StopView, CelautError> {
    let (session, record) = instance(&instance_id).await?;
    drop(state()?.ports.remove(&instance_id));
    let refund = session.stop(&record.token).await.map_err(error_of)?;
    db().update(|d| {
        if let Some(r) = d.instances.get_mut(&instance_id) {
            r.stopped_at = Some(now_seconds());
            r.refund_mu = Some(refund.to_string());
        }
    })
    .map_err(storage_error)?;
    let balance = session
        .balance()
        .await
        .map(|b| b.to_string())
        .unwrap_or_default();
    Ok(StopView {
        refund_mu: refund.to_string(),
        client_balance_mu: balance,
    })
}

/// Where the resources of [`AwakeResourcesView`] came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResourcesSourceView {
    /// The app read them from the node just before the hibernation.
    ReadFromNode,
    /// The last values that the app got from the node. They can be old: the screen must
    /// warn the user.
    LastKnown,
}

fn source_view(source: Option<ResourcesSource>) -> ResourcesSourceView {
    match source {
        Some(ResourcesSource::ReadFromNode) => ResourcesSourceView::ReadFromNode,
        // A record that has resources and no source is a guess.
        _ => ResourcesSourceView::LastKnown,
    }
}

/// The CPU and RAM that an instance has when it is awake. For a hibernated instance,
/// these are the values that the wake sends.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AwakeResourcesView {
    /// The CPU quota in microseconds for each `cpu_period`.
    pub cpu_quota: u64,
    /// The CPU period in microseconds.
    pub cpu_period: u64,
    /// The RAM limit in bytes.
    pub mem_limit: u64,
    pub source: ResourcesSourceView,
}

fn resources_view(r: Resources, source: Option<ResourcesSource>) -> AwakeResourcesView {
    AwakeResourcesView {
        cpu_quota: r.cpu_quota,
        cpu_period: r.cpu_period,
        mem_limit: r.mem_limit,
        source: source_view(source),
    }
}

fn awake_view(r: &InstanceRecord) -> Option<AwakeResourcesView> {
    r.awake_resources
        .map(|res| resources_view(res, r.awake_source))
}

/// The state of an instance that the app keeps (the node has no call that says
/// "hibernated").
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InstanceStateView {
    Running,
    Hibernated,
}

/// Why the node, or the app, did not hibernate or wake an instance. The screen shows its
/// own text for each one. When there is a reason, nothing changed, and the state is the
/// one from before the call.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResourceRefusalView {
    /// The instance exports or mounts a shared filesystem. The node does not hibernate it.
    SharedFilesystem,
    /// The instance cannot be started again from its own disk. The node does not
    /// hibernate it.
    NotRevivable,
    /// The instance has not enough balance for the fee of the call. A top-up is the way
    /// to continue.
    InstanceBalance,
    /// The node has no room for the resources of the wake. The instance stays hibernated.
    DoesNotFit,
    /// The node has no local instance with that token: it runs on a peer of the node, or
    /// it is gone. The node cannot hibernate it.
    NoLocalInstance,
    /// The node says that the father of the instance is a client and this call is not
    /// from it.
    NotTheFather,
    /// The app does not know the resources of the instance, so it cannot hibernate it
    /// (the read failed), or cannot wake it (no stored values).
    NoResources,
    /// The node answered the hibernation, but did not confirm it.
    NotConfirmed,
    /// The node does not support hibernation (it is older than the `service_token` of
    /// `ModifyServiceSystemResources`). Nothing was charged. The screen says it once and
    /// hides the hibernate and wake actions of that node.
    Unsupported,
    /// The node refused the call with a text that the app does not know. See `message`.
    Other,
}

fn refusal_view(reason: ResourceRefusal) -> ResourceRefusalView {
    match reason {
        ResourceRefusal::SharedFilesystem => ResourceRefusalView::SharedFilesystem,
        ResourceRefusal::NotRevivable => ResourceRefusalView::NotRevivable,
        ResourceRefusal::InstanceBalance => ResourceRefusalView::InstanceBalance,
        ResourceRefusal::DoesNotFit => ResourceRefusalView::DoesNotFit,
        ResourceRefusal::NoLocalInstance => ResourceRefusalView::NoLocalInstance,
        ResourceRefusal::NotTheFather => ResourceRefusalView::NotTheFather,
        ResourceRefusal::Unsupported => ResourceRefusalView::Unsupported,
    }
}

/// What a hibernation or a wake gave.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HibernationView {
    /// The state of the instance after the call. With a `refusal`, it is the state from
    /// before the call.
    pub state: InstanceStateView,
    /// The balance of the instance in MU after the call (empty if unknown, or if the
    /// call was refused).
    pub instance_balance_mu: String,
    /// The resources now: after a hibernation, the ones that a wake sends; after a wake,
    /// the ones that the node gave. None if the app has none.
    pub resources: Option<AwakeResourcesView>,
    /// The reason, if the call did not happen.
    pub refusal: Option<ResourceRefusalView>,
    /// The text of the node for the refusal, without the wrapper of the transport (empty
    /// if there is no refusal, or the app found the reason itself).
    pub message: String,
}

fn state_of(record: &InstanceRecord) -> InstanceStateView {
    if record.hibernated_at.is_some() {
        InstanceStateView::Hibernated
    } else {
        InstanceStateView::Running
    }
}

/// The view of the record `instance_id` after a call that did not happen for `reason`.
fn refused_view(
    db: &CelautDb,
    instance_id: &str,
    reason: ResourceRefusalView,
    message: String,
) -> Result<HibernationView, CelautError> {
    let record = db
        .read(|d| d.instances.get(instance_id).cloned())
        .ok_or_else(unknown_instance)?;
    Ok(HibernationView {
        state: state_of(&record),
        instance_balance_mu: String::new(),
        resources: awake_view(&record),
        refusal: Some(reason),
        message,
    })
}

/// The answer of `celaut_client::hibernation` as the view of the app. A refusal of the
/// node that the app knows, or one with an unknown text, is a view with a `refusal`. A
/// failure of the connection, and a refusal that the other calls also have (rate limit,
/// unknown client), is an error.
fn hibernation_view(
    db: &CelautDb,
    instance_id: &str,
    now_state: InstanceStateView,
    outcome: Result<Hibernation, HibernationError>,
) -> Result<HibernationView, CelautError> {
    match outcome {
        Ok(done) => Ok(HibernationView {
            state: now_state,
            instance_balance_mu: if done.balance_mu > 0 {
                done.balance_mu.to_string()
            } else {
                String::new()
            },
            resources: Some(resources_view(done.resources, Some(done.source))),
            refusal: None,
            message: String::new(),
        }),
        Err(HibernationError::Client(e)) => {
            if let Some(reason) = e.resource_refusal() {
                let message = match &e {
                    ClientError::Wire(WireError::Call(text)) => {
                        celaut_client::refusal::message_of(text)
                    }
                    _ => e.to_string(),
                };
                return refused_view(db, instance_id, refusal_view(reason), message);
            }
            if let ClientError::Wire(WireError::Call(text)) = &e {
                if celaut_client::refusal::classify(text).is_none() && !e.is_unknown_client() {
                    let message = celaut_client::refusal::message_of(text);
                    return refused_view(db, instance_id, ResourceRefusalView::Other, message);
                }
            }
            Err(error_of(e))
        }
        Err(HibernationError::NoResources) => refused_view(
            db,
            instance_id,
            ResourceRefusalView::NoResources,
            String::new(),
        ),
        Err(HibernationError::NotConfirmed) => refused_view(
            db,
            instance_id,
            ResourceRefusalView::NotConfirmed,
            String::new(),
        ),
        Err(HibernationError::Db(e)) => Err(storage_error(e)),
        Err(HibernationError::UnknownInstance) => Err(unknown_instance()),
        Err(HibernationError::Stopped) => Err(stopped_instance()),
        Err(HibernationError::AlreadyHibernated) => Err(already_hibernated()),
        Err(HibernationError::NotHibernated) => Err(not_hibernated()),
    }
}

fn already_hibernated() -> CelautError {
    invalid("This instance is hibernated already.")
}

fn not_hibernated() -> CelautError {
    invalid("This instance is not hibernated, so it cannot wake.")
}

/// Hibernate the instance: the node stops its CPU and RAM, and charges it for its disk
/// only. The app reads the resources of the instance from the node just before, and keeps
/// them in the database, so a wake gives it the same CPU and RAM. The values are the
/// ones that the instance has at this moment, not the ones that it had at the start.
///
/// This costs the instance two fees of the node (one for the read, one for the
/// hibernation). The call is refused with an error for a stopped instance, and for one
/// that is hibernated already. A refusal of the node or of the rules of the app is not an
/// error: it is the `refusal` of the view, and the state does not change. The process
/// state of the instance is lost at the next wake.
#[flutter_rust_bridge::frb]
pub async fn celaut_hibernate_instance(
    instance_id: String,
) -> Result<HibernationView, CelautError> {
    let known = db()
        .read(|d| d.instances.get(&instance_id).cloned())
        .ok_or_else(unknown_instance)?;
    if known.hibernated_at.is_some() {
        return Err(already_hibernated());
    }
    let (session, _) = instance(&instance_id).await?;
    let outcome = hibernation::hibernate(&session, &db(), &instance_id, now_seconds()).await;
    if outcome.is_ok() {
        // The instance does not run: its local ports have no one behind them.
        drop(state()?.ports.remove(&instance_id));
    }
    hibernation_view(&db(), &instance_id, InstanceStateView::Hibernated, outcome)
}

/// Wake a hibernated instance with the resources that the app kept at the hibernation
/// (all of CPU quota, CPU period and RAM, as the node asks). The node runs the
/// entrypoint again; the address and the ports stay. The call is refused with an error
/// for a stopped instance and for one that is not hibernated. If the node has no room,
/// the `refusal` is `DoesNotFit`, and the instance stays hibernated with the same stored
/// resources.
#[flutter_rust_bridge::frb]
pub async fn celaut_wake_instance(instance_id: String) -> Result<HibernationView, CelautError> {
    let known = db()
        .read(|d| d.instances.get(&instance_id).cloned())
        .ok_or_else(unknown_instance)?;
    if known.hibernated_at.is_none() {
        // The same error for a stopped instance comes from `instance` below.
        if known.stopped_at.is_some() {
            return Err(stopped_instance());
        }
        return Err(not_hibernated());
    }
    let (session, _) = instance(&instance_id).await?;
    let outcome = hibernation::wake(&session, &db(), &instance_id).await;
    hibernation_view(&db(), &instance_id, InstanceStateView::Running, outcome)
}

#[cfg(test)]
mod tests {
    #[test]
    fn the_preferred_port_is_stable_and_in_range() {
        let a = preferred_port("instance-a", 80);
        assert_eq!(a, preferred_port("instance-a", 80));
        assert_ne!(a, preferred_port("instance-a", 8080));
        assert_ne!(a, preferred_port("instance-b", 80));
        for (id, slot) in [("", 0), ("x", 65535), ("instance-a", 80)] {
            assert!((10_000..32_000).contains(&preferred_port(id, slot)));
        }
    }

    use super::*;

    #[tokio::test]
    async fn bad_input_is_refused_before_any_connection() {
        let node = NodeAddress {
            host: "localhost".into(),
            port: 0,
        };
        let id = "ab".repeat(32);
        let err = celaut_start_service(node, id.clone(), None, vec![])
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        let node = NodeAddress {
            host: "127.0.0.1".into(),
            port: 1,
        };
        let err = celaut_start_service(node.clone(), "xyz".into(), None, vec![])
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        let err = celaut_quote_service(vec![], id.clone(), None)
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        for bad in ["0", "-5", "1.5", "lots"] {
            let err = celaut_start_service(node.clone(), id.clone(), Some(bad.into()), vec![])
                .await
                .unwrap_err();
            assert_eq!(err.kind, CelautErrorKind::InvalidInput, "{bad}");
        }
        let err = celaut_open_tunnel("nope".into(), 80).await.unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        let err = celaut_stop_service("nope".into()).await.unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
    }

    fn remove_record(id: &str) {
        // `celaut_forget_instance` refuses a running instance.
        db().update(|d| d.instances.remove(id)).unwrap();
    }

    fn hibernation_record(id: &str, hibernated: bool) {
        db().update(|d| {
            d.instances.insert(
                id.to_string(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    address: "127.0.0.1:1".into(),
                    token: "token".into(),
                    awake_resources: Some(Resources {
                        cpu_quota: 50_000,
                        cpu_period: 100_000,
                        mem_limit: 512 << 20,
                    }),
                    awake_source: Some(ResourcesSource::ReadFromNode),
                    hibernated_at: hibernated.then_some(7),
                    ..Default::default()
                },
            );
        })
        .unwrap();
    }

    fn unknown_token() -> ClientError {
        ClientError::Wire(WireError::Call(
            "status: Unknown, message: \"Exception calling application: Invalid token, it should be an instance token.  token: x\"".into(),
        ))
    }

    #[test]
    fn a_hibernated_instance_that_the_node_forgot_is_marked_stopped() {
        let asleep = "gone-test-asleep".to_string();
        let awake = "gone-test-awake".to_string();
        hibernation_record(&asleep, true);
        hibernation_record(&awake, false);
        // Any other error says nothing about the instance.
        let timeout = ClientError::Wire(WireError::Call("status: Unavailable".into()));
        assert!(!mark_gone_if_hibernated(&db(), &asleep, &timeout));
        assert_eq!(db().read(|d| d.instances[&asleep].stopped_at), None);
        // An awake instance is not marked: the app cannot tell why it does not answer.
        assert!(!mark_gone_if_hibernated(&db(), &awake, &unknown_token()));
        assert_eq!(db().read(|d| d.instances[&awake].stopped_at), None);
        // A hibernated one is, and the hibernation stays in the record as it is.
        assert!(mark_gone_if_hibernated(&db(), &asleep, &unknown_token()));
        let r = db().read(|d| d.instances[&asleep].clone());
        assert!(r.stopped_at.is_some());
        assert_eq!(r.refund_mu, None);
        // It is stopped now: a second answer changes nothing.
        assert!(!mark_gone_if_hibernated(&db(), &asleep, &unknown_token()));
    }

    #[test]
    fn the_plan_of_a_hibernated_instance_has_the_price_of_its_disk() {
        use celaut_client::db::HibernatedPrice;
        let id = "plan-hibernated-test".to_string();
        hibernation_record(&id, true);
        celaut_set_instance_pricing(id.clone(), "1000".into(), 60, 0.0).unwrap();
        // The app has no price of the disk: it uses the awake price and says so.
        let plan = celaut_instance_plan(id.clone()).unwrap();
        assert!(plan.hibernated);
        assert!(!plan.disk_only);
        assert_eq!(plan.maintenance_mu, "1000");
        db().update(|d| {
            d.instances.get_mut(&id).unwrap().hibernated_price = Some(HibernatedPrice {
                disk_maintenance_mu: "40".into(),
                wake_fee_mu: "10000".into(),
            })
        })
        .unwrap();
        let plan = celaut_instance_plan(id.clone()).unwrap();
        assert!(plan.disk_only);
        assert_eq!(plan.maintenance_mu, "40");
        assert_eq!(plan.maintenance_seconds, 60);
        assert_eq!(plan.wake_fee_mu, "10000");
        // A wake brings the awake price back.
        db().update(|d| d.instances.get_mut(&id).unwrap().hibernated_at = None)
            .unwrap();
        let plan = celaut_instance_plan(id.clone()).unwrap();
        assert!(!plan.hibernated && !plan.disk_only);
        assert_eq!(plan.maintenance_mu, "1000");
        assert_eq!(plan.wake_fee_mu, "");
    }

    #[tokio::test]
    async fn hibernate_and_wake_check_the_state_before_any_connection() {
        let awake = "hibernate-test-awake".to_string();
        let asleep = "hibernate-test-asleep".to_string();
        let stopped = "hibernate-test-stopped".to_string();
        hibernation_record(&awake, false);
        hibernation_record(&asleep, true);
        hibernation_record(&stopped, false);
        db().update(|d| d.instances.get_mut(&stopped).unwrap().stopped_at = Some(1))
            .unwrap();
        let err = celaut_hibernate_instance("nope".into()).await.unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        assert_eq!(err.message, "This instance is not known. It was deleted.");
        let err = celaut_wake_instance("nope".into()).await.unwrap_err();
        assert_eq!(err.message, "This instance is not known. It was deleted.");
        let err = celaut_hibernate_instance(asleep.clone()).await.unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        assert_eq!(err.message, "This instance is hibernated already.");
        let err = celaut_wake_instance(awake.clone()).await.unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        assert_eq!(
            err.message,
            "This instance is not hibernated, so it cannot wake."
        );
        for err in [
            celaut_hibernate_instance(stopped.clone())
                .await
                .unwrap_err(),
            celaut_wake_instance(stopped.clone()).await.unwrap_err(),
        ] {
            assert_eq!(err.message, "This instance was stopped.");
        }
        // Nothing changed.
        let list = celaut_instances();
        let of = |id: &str| list.iter().find(|i| i.instance_id == id).unwrap().clone();
        assert_eq!(of(&awake).hibernated_at, None);
        assert_eq!(of(&asleep).hibernated_at, Some(7));
        let kept = of(&asleep).awake_resources.unwrap();
        assert_eq!(kept.cpu_quota, 50_000);
        assert_eq!(kept.mem_limit, 512 << 20);
        assert_eq!(kept.source, ResourcesSourceView::ReadFromNode);
        for id in [awake, asleep, stopped] {
            remove_record(&id);
        }
    }

    fn call_error(text: &str) -> HibernationError {
        HibernationError::Client(ClientError::Wire(WireError::Call(text.into())))
    }

    #[test]
    fn a_refusal_of_the_node_is_a_reason_and_not_an_error() {
        let id = "hibernate-test-refusal".to_string();
        hibernation_record(&id, false);
        let reason_of = |text: &str, now: InstanceStateView| {
            hibernation_view(&db(), &id, now, Err(call_error(text)))
        };
        let wrapped = |t: &str| {
            format!("status: Unknown, message: \"Exception calling application: {t}\", details: []")
        };
        for (text, reason) in [
            (
                "This instance exports or mounts a shared filesystem, and hibernating it would take that share away.",
                ResourceRefusalView::SharedFilesystem,
            ),
            (
                "This instance cannot be started again from its own disk, so it cannot be hibernated.",
                ResourceRefusalView::NotRevivable,
            ),
            (
                "Error charging for the resource change of abc",
                ResourceRefusalView::InstanceBalance,
            ),
            (
                "The instance could not be woken: it stays hibernated.",
                ResourceRefusalView::DoesNotFit,
            ),
            (
                "This node has no local instance with that token.",
                ResourceRefusalView::NoLocalInstance,
            ),
            (
                "The father of this instance is a client, and this call must come from it.",
                ResourceRefusalView::NotTheFather,
            ),
            ("Something new went wrong.", ResourceRefusalView::Other),
        ] {
            let view = reason_of(&wrapped(text), InstanceStateView::Hibernated).unwrap();
            assert_eq!(view.refusal, Some(reason), "{text}");
            // The record did not change: the instance still runs, with its resources.
            assert_eq!(view.state, InstanceStateView::Running);
            assert_eq!(view.resources.unwrap().cpu_period, 100_000);
            assert!(!view.message.contains("Exception calling"), "{text}");
        }
        // A reason that every call has stays an error.
        let err = reason_of(
            "Client abc is calling too fast and is temporarily quarantined.",
            InstanceStateView::Hibernated,
        );
        assert_eq!(err.unwrap_err().kind, CelautErrorKind::RateLimited);
        let err = hibernation_view(
            &db(),
            &id,
            InstanceStateView::Hibernated,
            Err(HibernationError::Client(ClientError::Wire(
                WireError::Timeout,
            ))),
        );
        assert_eq!(err.unwrap_err().kind, CelautErrorKind::Timeout);
        remove_record(&id);
    }

    #[test]
    fn the_rules_of_the_app_are_reasons_or_clear_errors() {
        let id = "hibernate-test-rules".to_string();
        hibernation_record(&id, true);
        let state = InstanceStateView::Hibernated;
        let view = |e| hibernation_view(&db(), &id, state, Err(e));
        let v = view(HibernationError::NoResources).unwrap();
        assert_eq!(v.refusal, Some(ResourceRefusalView::NoResources));
        assert_eq!(v.state, InstanceStateView::Hibernated);
        let v = view(HibernationError::NotConfirmed).unwrap();
        assert_eq!(v.refusal, Some(ResourceRefusalView::NotConfirmed));
        assert_eq!(
            view(HibernationError::AlreadyHibernated)
                .unwrap_err()
                .message,
            "This instance is hibernated already."
        );
        assert_eq!(
            view(HibernationError::NotHibernated).unwrap_err().message,
            "This instance is not hibernated, so it cannot wake."
        );
        assert_eq!(
            view(HibernationError::Stopped).unwrap_err().message,
            "This instance was stopped."
        );
        assert_eq!(
            view(HibernationError::UnknownInstance).unwrap_err().kind,
            CelautErrorKind::InvalidInput
        );
        remove_record(&id);
    }

    #[test]
    fn a_done_call_gives_the_state_the_balance_and_the_resources() {
        let id = "hibernate-test-done".to_string();
        hibernation_record(&id, true);
        let resources = Resources {
            cpu_quota: 25_000,
            cpu_period: 100_000,
            mem_limit: 256 << 20,
        };
        let done = |balance_mu| Hibernation {
            resources,
            source: ResourcesSource::LastKnown,
            balance_mu,
        };
        let v = hibernation_view(&db(), &id, InstanceStateView::Running, Ok(done(90))).unwrap();
        assert_eq!(v.state, InstanceStateView::Running);
        assert_eq!(v.instance_balance_mu, "90");
        assert_eq!(v.refusal, None);
        let r = v.resources.unwrap();
        assert_eq!((r.cpu_quota, r.mem_limit), (25_000, 256 << 20));
        assert_eq!(r.source, ResourcesSourceView::LastKnown);
        // A balance that the node did not give is empty, not 0.
        let v = hibernation_view(&db(), &id, InstanceStateView::Hibernated, Ok(done(0))).unwrap();
        assert_eq!(v.instance_balance_mu, "");
        assert_eq!(v.state, InstanceStateView::Hibernated);
        remove_record(&id);
    }

    #[test]
    fn an_instance_keeps_its_name() {
        let id = "name-test-instance".to_string();
        db().update(|d| {
            d.instances.insert(
                id.clone(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    token: "token".into(),
                    ..Default::default()
                },
            );
        })
        .unwrap();
        let name_of = |id: &str| {
            celaut_instances()
                .into_iter()
                .find(|i| i.instance_id == id)
                .map(|i| i.name)
        };
        assert_eq!(name_of(&id).as_deref(), Some(""));
        celaut_name_instance(id.clone(), " Echo chat ".into()).unwrap();
        assert_eq!(name_of(&id).as_deref(), Some("Echo chat"));
        celaut_name_instance(id.clone(), " ".into()).unwrap();
        assert_eq!(name_of(&id).as_deref(), Some(""));
        let err = celaut_name_instance("nope".into(), "x".into()).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        drop(db().update(|d| d.instances.remove(&id)));
    }

    #[test]
    fn keep_alive_counts_what_was_spent_since_it_was_turned_on() {
        assert_eq!(spent_since(None, ""), 0);
        assert_eq!(spent_since(Some("500"), ""), 500);
        assert_eq!(spent_since(Some("1500"), "500"), 1000);
        assert_eq!(spent_since(Some("100"), "500"), 0);
    }

    #[test]
    fn an_instance_keeps_its_price_and_its_keep_alive_settings() {
        let id = "keep-alive-test-instance".to_string();
        db().update(|d| {
            d.instances.insert(
                id.clone(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    token: "token".into(),
                    topped_up_mu: Some("700".into()),
                    ..Default::default()
                },
            );
        })
        .unwrap();
        let plan = celaut_instance_plan(id.clone()).unwrap();
        assert!(!plan.keep_alive);
        assert_eq!(
            (plan.maintenance_mu.as_str(), plan.maintenance_seconds),
            ("", 0)
        );

        celaut_set_instance_pricing(id.clone(), "1000".into(), 60, 0.25).unwrap();
        let plan = celaut_instance_plan(id.clone()).unwrap();
        assert_eq!(plan.maintenance_mu, "1000");
        assert_eq!(plan.maintenance_seconds, 60);
        assert_eq!(plan.variance, 0.25);
        assert!(celaut_set_instance_pricing(id.clone(), "0".into(), 60, 0.0).is_err());
        assert!(celaut_set_instance_pricing(id.clone(), "5".into(), 0, 0.0).is_err());

        // The count starts at the 700 MU that were already moved.
        celaut_set_keep_alive(id.clone(), true, Some(" 5000 ".into())).unwrap();
        let plan = celaut_instance_plan(id.clone()).unwrap();
        assert!(plan.keep_alive);
        assert_eq!(
            (plan.budget_mu.as_str(), plan.spent_mu.as_str()),
            ("5000", "0")
        );
        db().update(|d| d.instances.get_mut(&id).unwrap().topped_up_mu = Some("1200".into()))
            .unwrap();
        assert_eq!(celaut_instance_plan(id.clone()).unwrap().spent_mu, "500");

        // No limit: an empty text, or none.
        celaut_set_keep_alive(id.clone(), true, Some("".into())).unwrap();
        assert_eq!(celaut_instance_plan(id.clone()).unwrap().budget_mu, "");
        assert!(celaut_set_keep_alive(id.clone(), true, Some("0".into())).is_err());
        assert!(celaut_set_keep_alive(id.clone(), true, Some("abc".into())).is_err());

        celaut_set_keep_alive(id.clone(), false, None).unwrap();
        assert!(!celaut_instance_plan(id.clone()).unwrap().keep_alive);

        // A stopped instance cannot be kept alive.
        db().update(|d| d.instances.get_mut(&id).unwrap().stopped_at = Some(5))
            .unwrap();
        assert!(celaut_set_keep_alive(id.clone(), true, None).is_err());
        assert!(celaut_set_keep_alive("nope".into(), true, None).is_err());
        drop(db().update(|d| d.instances.remove(&id)));
    }

    #[test]
    fn the_cost_so_far_counts_the_top_ups() {
        assert_eq!(cost_so_far(Some("1000"), None, 400), Some(600));
        // 1000 at the start, 500 moved later, 700 left: 800 spent.
        assert_eq!(cost_so_far(Some("1000"), Some("500"), 700), Some(800));
        assert_eq!(cost_so_far(None, Some("500"), 700), None);
    }

    #[tokio::test]
    async fn a_top_up_refuses_a_bad_amount_and_a_stopped_instance_before_any_call() {
        for amount in ["", "x", "0", "100000001", "-5"] {
            let err = celaut_top_up_instance("any".into(), amount.into())
                .await
                .unwrap_err();
            assert_eq!(err.kind, CelautErrorKind::InvalidInput, "{amount}");
        }
        let id = "top-up-stopped-instance".to_string();
        db().update(|d| {
            d.instances.insert(
                id.clone(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    address: "127.0.0.1:1".into(),
                    token: "token".into(),
                    stopped_at: Some(1),
                    ..Default::default()
                },
            );
        })
        .unwrap();
        let err = celaut_top_up_instance(id.clone(), "10".into())
            .await
            .unwrap_err();
        assert_eq!(err.message, "This instance was stopped.");
        celaut_forget_instance(id).unwrap();
    }

    #[test]
    fn a_rename_is_local_and_kept_with_the_name_of_the_start() {
        let id = "rename-test-instance".to_string();
        db().update(|d| {
            d.instances.insert(
                id.clone(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    token: "token".into(),
                    name: Some("echo-chat".into()),
                    ..Default::default()
                },
            );
        })
        .unwrap();
        let view = |id: &str| {
            celaut_instances()
                .into_iter()
                .find(|i| i.instance_id == id)
                .unwrap()
        };
        celaut_rename_instance(id.clone(), "  My   echo ".into()).unwrap();
        let v = view(&id);
        assert_eq!(
            (v.name.as_str(), v.alias.as_str()),
            ("echo-chat", "My echo")
        );
        // Empty: the alias goes, the name of the start stays.
        celaut_rename_instance(id.clone(), " ".into()).unwrap();
        let v = view(&id);
        assert_eq!((v.name.as_str(), v.alias.as_str()), ("echo-chat", ""));
        let long = "x".repeat(ALIAS_MAX_CHARS + 1);
        let err = celaut_rename_instance(id.clone(), long).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        let err = celaut_rename_instance("nope".into(), "x".into()).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        // A stopped instance can be renamed too.
        db().update(|d| d.instances.get_mut(&id).unwrap().stopped_at = Some(1))
            .unwrap();
        celaut_rename_instance(id.clone(), "Old echo".into()).unwrap();
        assert_eq!(view(&id).alias, "Old echo");
        drop(db().update(|d| d.instances.remove(&id)));
    }

    #[test]
    fn the_title_of_the_service_is_kept_apart_from_the_name_of_the_user() {
        let id = "title-test-instance".to_string();
        db().update(|d| {
            d.instances.insert(
                id.clone(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    token: "token".into(),
                    name: Some("echo-chat".into()),
                    ..Default::default()
                },
            );
        })
        .unwrap();
        let view = |id: &str| {
            celaut_instances()
                .into_iter()
                .find(|i| i.instance_id == id)
                .unwrap()
        };
        celaut_set_instance_title(id.clone(), " Trip  to\tLisbon ".into()).unwrap();
        celaut_rename_instance(id.clone(), "Mine".into()).unwrap();
        let v = view(&id);
        assert_eq!(
            (v.name.as_str(), v.alias.as_str(), v.title.as_str()),
            ("echo-chat", "Mine", "Trip to Lisbon")
        );
        // A new title does not touch the name of the user, and the other way round.
        celaut_set_instance_title(id.clone(), "Lisbon in May".into()).unwrap();
        assert_eq!(view(&id).alias, "Mine");
        celaut_rename_instance(id.clone(), "".into()).unwrap();
        assert_eq!(view(&id).title, "Lisbon in May");
        // Empty: the title goes.
        celaut_set_instance_title(id.clone(), " ".into()).unwrap();
        assert_eq!(view(&id).title, "");
        let long = "x".repeat(TITLE_MAX_CHARS + 1);
        let err = celaut_set_instance_title(id.clone(), long).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        assert!(celaut_set_instance_title(id.clone(), "x".repeat(TITLE_MAX_CHARS)).is_ok());
        let err = celaut_set_instance_title("nope".into(), "x".into()).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        drop(db().update(|d| d.instances.remove(&id)));
    }

    #[test]
    fn only_a_stopped_instance_can_be_deleted() {
        let id = "delete-test-instance".to_string();
        db().update(|d| {
            d.instances.insert(
                id.clone(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    token: "token".into(),
                    ..Default::default()
                },
            );
        })
        .unwrap();
        let listed = |id: &str| celaut_instances().into_iter().find(|i| i.instance_id == id);

        // A running instance, or one whose node does not answer: refused, and kept with
        // its token.
        let err = celaut_forget_instance(id.clone()).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        assert!(err.message.contains("not stopped"), "{}", err.message);
        assert_eq!(listed(&id).unwrap().stopped_at, None);
        assert_eq!(
            db().read(|d| d.instances[&id].token.clone()),
            "token".to_string()
        );

        // Stopped: it stays in the list, with the refund, until the user deletes it.
        db().update(|d| {
            let r = d.instances.get_mut(&id).unwrap();
            r.stopped_at = Some(42);
            r.refund_mu = Some("700".into());
        })
        .unwrap();
        let view = listed(&id).unwrap();
        assert_eq!(
            (view.stopped_at, view.refund_mu.as_str()),
            (Some(42), "700")
        );
        celaut_forget_instance(id.clone()).unwrap();
        assert!(listed(&id).is_none());
        let err = celaut_forget_instance(id).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
    }

    #[tokio::test]
    async fn a_stopped_instance_is_not_asked_for() {
        let id = "stopped-test-instance".to_string();
        db().update(|d| {
            d.instances.insert(
                id.clone(),
                InstanceRecord {
                    peer_id: "ab".repeat(32),
                    address: "127.0.0.1:1".into(),
                    token: "token".into(),
                    slots: vec![8080],
                    stopped_at: Some(1),
                    ..Default::default()
                },
            );
        })
        .unwrap();
        for err in [
            celaut_stop_service(id.clone()).await.unwrap_err(),
            celaut_instance_status(id.clone()).await.unwrap_err(),
            celaut_open_tunnel(id.clone(), 8080).await.unwrap_err(),
        ] {
            assert_eq!(err.kind, CelautErrorKind::InvalidInput);
            assert_eq!(err.message, "This instance was stopped.");
        }
        celaut_forget_instance(id).unwrap();
    }

    #[test]
    fn only_a_start_carries_the_environment_variables() {
        let typed = |name: &str, text: &str| EnvChoice {
            name: name.into(),
            container: None,
            text: Some(text.into()),
        };
        // No choice: the same message as before the variables existed.
        assert_eq!(
            start_configuration(None, &[]).unwrap(),
            Configuration::default()
        );
        let c = start_configuration(Some("5".into()), &[typed("B", "2"), typed("A", "1")]).unwrap();
        assert_eq!(c.initial_mu, Some(Amount { n: "5".into() }));
        let names: Vec<_> = c
            .environment_variables
            .iter()
            .map(|e| e.key.as_str())
            .collect();
        assert_eq!(names, ["B", "A"]);
        // A quote never has them.
        assert!(configuration(Some("5".into()))
            .unwrap()
            .environment_variables
            .is_empty());
        // A bad choice is refused before any node is asked.
        let err = start_configuration(None, &[typed("1", "x")]).unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
    }

    #[test]
    fn the_start_balance_goes_in_the_configuration() {
        assert_eq!(configuration(None).unwrap(), Configuration::default());
        assert_eq!(
            configuration(Some(" ".into())).unwrap(),
            Configuration::default()
        );
        let c = configuration(Some(" 1000000 ".into())).unwrap();
        assert_eq!(c.initial_mu.unwrap().n, "1000000");
    }

    #[tokio::test]
    async fn a_closed_node_is_a_failure_of_the_quote() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();
        drop(listener);
        let node = NodeAddress {
            host: "127.0.0.1".into(),
            port,
        };
        let answer = celaut_quote_service(vec![node.clone()], "ab".repeat(32), None)
            .await
            .unwrap();
        assert!(answer.quotes.is_empty());
        assert_eq!(answer.failures.len(), 1);
        assert_eq!(answer.failures[0].address, node);
        assert_eq!(answer.failures[0].kind, CelautErrorKind::Unreachable);
    }
}
