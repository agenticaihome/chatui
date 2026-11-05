//! Hibernate and wake an instance that the app runs, and keep its record
//! (`docs/celaut/decisions.md`).
//!
//! The node has no RPC that says "hibernated": this record is the only place that knows.
//! A wake needs the CPU and the RAM that the instance had when it was hibernated. They
//! can differ from the resources of the start, because the parent or the instance may
//! have resized it. So the app reads them from the node just before the request that
//! sets them to 0 ([`NodeSession::current_resources`]), and keeps them in the record
//! ([`InstanceRecord::awake_resources`]).
//!
//! Order of a hibernation:
//!
//! 1. Take the lock of the instance, so that no other call of this module runs on it.
//! 2. Read the current resources. If the read fails, use the last values that the app
//!    got from the node, and mark them [`ResourcesSource::LastKnown`]. If there are none,
//!    stop here: no call that changes the instance is made.
//! 3. Write them in the record, and flush the database.
//! 4. Send the hibernation. If it fails, or the node does not answer 0, write the
//!    previous values back: the record does not claim a hibernation.
//! 5. Set `hibernated_at`, and the price of the hibernated instance
//!    ([`hibernated_price`]), so that the keep-alive tops up the disk only.
//!
//! The wire has no call that reads and hibernates in one step. A resize of the instance
//! between step 2 and step 4 is not seen. The gap is small.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock, PoisonError};

use celaut_proto::celaut::Peer;
use celaut_wire::Transport;

use crate::db::{
    CelautDb, DbError, HibernatedPrice, InstancePricing, InstanceRecord, Resources, ResourcesSource,
};
use crate::session::NodeSession;
use crate::ClientError;

/// Why a hibernation or a wake did not happen.
#[derive(Debug, thiserror::Error)]
pub enum HibernationError {
    /// The call to the node failed, or the node refused it. See
    /// [`ClientError::resource_refusal`].
    #[error(transparent)]
    Client(#[from] ClientError),
    /// The database could not save the record.
    #[error(transparent)]
    Db(#[from] DbError),
    /// The database has no instance with this id.
    #[error("the database has no instance with this id")]
    UnknownInstance,
    /// The instance is stopped.
    #[error("the instance is stopped")]
    Stopped,
    /// The record says that the instance is hibernated already.
    #[error("the instance is hibernated already")]
    AlreadyHibernated,
    /// The record does not say that the instance is hibernated, so there is nothing to wake.
    #[error("the instance is not hibernated")]
    NotHibernated,
    /// The app has no resources for this instance: the read failed, and the app never
    /// got a value from the node. The instance is not hibernated, because the app could
    /// not wake it with the same resources.
    #[error("the app does not know the resources of the instance, so it cannot hibernate it")]
    NoResources,
    /// The node answered the hibernation, but not with 0 for the CPU or the RAM. The
    /// record does not say that the instance is hibernated.
    #[error("the node did not confirm the hibernation")]
    NotConfirmed,
}

/// What a hibernation or a wake gave.
#[derive(Debug, Clone, PartialEq)]
pub struct Hibernation {
    /// The resources in the record after the call: the ones that a wake sends (after a
    /// hibernation), or the ones that the instance has now (after a wake).
    pub resources: Resources,
    /// Where `resources` came from. After a hibernation, [`ResourcesSource::LastKnown`]
    /// means a guess: the UI must warn about it.
    pub source: ResourcesSource,
    /// The balance of the instance in MU after the last call, or 0 if the node gave none.
    pub balance_mu: u128,
}

type Locks = Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>;

/// The lock of one instance. It is the same for all callers in this process.
fn lock_of(instance_id: &str) -> Arc<tokio::sync::Mutex<()>> {
    static LOCKS: OnceLock<Locks> = OnceLock::new();
    let mut map = LOCKS
        .get_or_init(Default::default)
        .lock()
        .unwrap_or_else(PoisonError::into_inner);
    Arc::clone(map.entry(instance_id.to_string()).or_default())
}

fn record_of(db: &CelautDb, instance_id: &str) -> Result<InstanceRecord, HibernationError> {
    db.read(|d| d.instances.get(instance_id).cloned())
        .ok_or(HibernationError::UnknownInstance)
}

/// Write the awake resources of the record and flush.
fn store(
    db: &CelautDb,
    instance_id: &str,
    resources: Option<Resources>,
    source: Option<ResourcesSource>,
    hibernated_at: Option<Option<i64>>,
) -> Result<(), HibernationError> {
    db.update(|d| match d.instances.get_mut(instance_id) {
        Some(r) => {
            r.awake_resources = resources;
            r.awake_source = source;
            if let Some(at) = hibernated_at {
                r.hibernated_at = at;
            }
            Ok(())
        }
        None => Err(HibernationError::UnknownInstance),
    })?
}

/// Hibernate the instance `instance_id` of the database, through `session`. `now` is the
/// time in Unix seconds for `hibernated_at`. Gives the resources that a wake will send.
///
/// If this gives an error, the record has the values that it had before the call.
pub async fn hibernate<T: Transport>(
    session: &NodeSession<T>,
    db: &CelautDb,
    instance_id: &str,
    now: i64,
) -> Result<Hibernation, HibernationError> {
    let lock = lock_of(instance_id);
    let _guard = lock.lock().await;
    let record = record_of(db, instance_id)?;
    if record.stopped_at.is_some() {
        return Err(HibernationError::Stopped);
    }
    if record.hibernated_at.is_some() {
        return Err(HibernationError::AlreadyHibernated);
    }
    let before = (record.awake_resources, record.awake_source);

    // The resources of this moment, not the ones of the start.
    let mut disk_space = None;
    let (resources, source) = match session.current_resources(&record.token).await {
        Ok(read) => match Resources::from_sysresources(&read.sysreq) {
            Some(r) => {
                disk_space = read.sysreq.disk_space;
                (r, ResourcesSource::ReadFromNode)
            }
            None => last_known(&record)?,
        },
        // The node refused: the hibernation would get the same refusal. Do not go on.
        Err(e) if e.resource_refusal().is_some() => return Err(e.into()),
        // No usable read (a timeout, an old node, or an all-zero answer). Use the last
        // values from the node, if there are any.
        Err(_) => last_known(&record)?,
    };

    // Save them before the request that sets them to 0 in the node.
    store(db, instance_id, Some(resources), Some(source), None)?;
    let answer = match session.hibernate(&record.token).await {
        Ok(a) => a,
        Err(e) => {
            // The record keeps its previous state. A failed write here changes nothing
            // for the caller: the error of the node is the one to show.
            let _ = store(db, instance_id, before.0, before.1, None);
            return Err(e.into());
        }
    };
    let confirmed = answer.sysreq.cpu_quota == Some(0) || answer.sysreq.mem_limit == Some(0);
    if !confirmed {
        let _ = store(db, instance_id, before.0, before.1, None);
        return Err(HibernationError::NotConfirmed);
    }
    store(
        db,
        instance_id,
        Some(resources),
        Some(source),
        Some(Some(now)),
    )?;
    // The price is a help for the keep-alive. If it fails to save, the hibernation stays,
    // and the keep-alive uses the price of the awake instance.
    let price = match (&record.pricing, disk_space) {
        (Some(pricing), Some(disk)) => hibernated_price(&session.info().peer, disk, pricing),
        _ => None,
    };
    let _ = set_price(db, instance_id, price);
    Ok(Hibernation {
        resources,
        source,
        balance_mu: answer.balance_mu,
    })
}

fn set_price(
    db: &CelautDb,
    instance_id: &str,
    price: Option<HibernatedPrice>,
) -> Result<(), DbError> {
    db.update(|d| {
        if let Some(r) = d.instances.get_mut(instance_id) {
            r.hibernated_price = price;
        }
    })
}

const GIB: u128 = 1 << 30;

/// The rate `key` of the node, in MU, from the rates that it advertised.
fn rate(peer: &Peer, key: &str) -> Option<u128> {
    peer.mu_per_call
        .iter()
        .find(|kv| kv.key == key)
        .and_then(|kv| kv.value.as_ref())
        .and_then(|a| a.n.trim().parse().ok())
}

/// The price of a hibernated instance: its disk of `disk_bytes` for one period of
/// `awake.maintenance_seconds`, and the fee of the wake call. The node charges a
/// hibernated instance for its disk only (nodo `docs/PRICING.md`, "Hibernating an
/// instance"), so this is the cost of the awake instance without its CPU and RAM.
///
/// The figure is an upper bound, so that a top-up never comes late:
///
/// - The node advertises the rate per GiB and second after an integer division, which
///   drops the fraction. This function adds 1 to it.
/// - It multiplies by `scarcity_max_multiplier` (1 if the node does not advertise it),
///   the most that the node adds when the disk is scarce.
/// - It is never more than the maintenance of the awake instance (`awake`).
///
/// Gives `None` if the node advertises no disk rate (the node omits a rate of 0, or the
/// price is too small to show) or the numbers do not fit. The keep-alive then uses the
/// price of the awake instance.
pub fn hibernated_price(
    peer: &Peer,
    disk_bytes: u64,
    awake: &InstancePricing,
) -> Option<HibernatedPrice> {
    let disk_rate = rate(peer, "disk_mu_per_gib_second")?;
    let scarcity = rate(peer, "scarcity_max_multiplier").unwrap_or(1).max(1);
    let seconds = u128::from(awake.maintenance_seconds);
    let per_period = disk_rate
        .checked_add(1)?
        .checked_mul(scarcity)?
        .checked_mul(u128::from(disk_bytes))?
        .checked_mul(seconds)?
        .div_ceil(GIB);
    let awake_mu: u128 = awake.maintenance_mu.trim().parse().ok()?;
    let disk = per_period.min(awake_mu);
    Some(HibernatedPrice {
        disk_maintenance_mu: disk.to_string(),
        wake_fee_mu: rate(peer, "modify_resources_mu")
            .map(|f| f.to_string())
            .unwrap_or_default(),
    })
}

fn last_known(record: &InstanceRecord) -> Result<(Resources, ResourcesSource), HibernationError> {
    record
        .awake_resources
        .map(|r| (r, ResourcesSource::LastKnown))
        .ok_or(HibernationError::NoResources)
}

/// Wake the instance `instance_id` with the resources of its record: `cpu_quota`,
/// `cpu_period` and `mem_limit` together. When the node accepts, `hibernated_at` is
/// cleared and the record keeps the resources of the answer. If the call fails or the
/// node refuses it (for example, it has no room), the record stays hibernated, with the
/// same resources.
pub async fn wake<T: Transport>(
    session: &NodeSession<T>,
    db: &CelautDb,
    instance_id: &str,
) -> Result<Hibernation, HibernationError> {
    let lock = lock_of(instance_id);
    let _guard = lock.lock().await;
    let record = record_of(db, instance_id)?;
    if record.stopped_at.is_some() {
        return Err(HibernationError::Stopped);
    }
    if record.hibernated_at.is_none() {
        return Err(HibernationError::NotHibernated);
    }
    let stored = record
        .awake_resources
        .ok_or(HibernationError::NoResources)?;
    let answer = session
        .wake(&record.token, &stored.to_sysresources())
        .await?;
    // What the node says it has now. If the answer has no usable value, keep the stored
    // ones: the node accepted them.
    let (resources, source) = match Resources::from_sysresources(&answer.sysreq) {
        Some(r) => (r, ResourcesSource::LastKnown),
        None => (
            stored,
            record.awake_source.unwrap_or(ResourcesSource::LastKnown),
        ),
    };
    store(db, instance_id, Some(resources), Some(source), Some(None))?;
    // A wake is not a top-up, and a top-up is not a wake: the price of the awake
    // instance applies again only now.
    let _ = set_price(db, instance_id, None);
    Ok(Hibernation {
        resources,
        source,
        balance_mu: answer.balance_mu,
    })
}
