//! The execution receipts of the instances (nodo#419, `docs/celaut/receipts.md`).
//!
//! The node signs a start receipt for each start, and checkpoints and a close on each
//! tunnel stream. The app checks them when they come and keeps them in the Celaut
//! database ([`celaut_client::receipts`]). The info page of an instance shows a summary
//! ([`celaut_instance_receipts`]), and the user can export them for someone else
//! ([`celaut_export_receipts`]): the file that `nodo receipt verify` reads.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use celaut_client::receipts::{export_jsonl, summarize, Fault};
use celaut_wire::{ReceiptEvent, ReceiptSink};

use super::celaut::{invalid, CelautError};
use super::celaut_db::{db, now_seconds};

/// The state of the start receipt of an instance.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StartReceiptState {
    /// The node gave no start receipt (a node without receipts).
    None,
    /// It verifies, and it signs what the phone sent.
    Valid,
    /// It does not verify, or it signs something that the phone did not send.
    Invalid,
}

/// What is wrong with a receipt.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReceiptFaultKind {
    /// The receipt does not verify (the signature, the node, the token or its shape), or
    /// the stored receipt was changed.
    Invalid,
    /// The node signed data that this phone did not send.
    Sent,
    /// The node signed data that this phone did not receive.
    Received,
    /// The node signed environment variables that this phone did not send.
    Envs,
    /// The node signed another service than the one that this phone asked for.
    Service,
    /// The node signed another start balance than the one that this phone asked for.
    Amount,
    /// The node gave no start receipt, but it gave one for an instance before.
    Omitted,
}

/// One fault, with the detail in English (the text of the check).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReceiptFaultView {
    pub kind: ReceiptFaultKind,
    pub detail: String,
}

/// The receipts of an instance, for its info page.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReceiptsView {
    pub start: StartReceiptState,
    /// How many checkpoints came on all the tunnel streams, the closes too.
    pub checkpoints: u64,
    /// The tunnel streams that the app keeps.
    pub streams: u64,
    /// The streams that the app dropped over its limit.
    pub dropped_streams: u64,
    /// The streams with a close.
    pub closed: u64,
    /// The streams that the phone ended: no close, and that is not a fault.
    pub cancelled: u64,
    /// The streams that ended with no close, and that the phone did not end (for example
    /// the node stopped the instance). A missing close is not by itself a fault.
    pub no_close: u64,
    /// Everything wrong. Empty when all is good.
    pub faults: Vec<ReceiptFaultView>,
}

pub(crate) fn fault_view(fault: &Fault) -> ReceiptFaultView {
    let (kind, detail) = match fault {
        Fault::Invalid { reason } => (ReceiptFaultKind::Invalid, reason.clone()),
        // An ordering fault shows as an invalid receipt, with its reason as the detail.
        Fault::Order { reason } => (ReceiptFaultKind::Invalid, reason.clone()),
        Fault::Sent => (ReceiptFaultKind::Sent, String::new()),
        Fault::Received => (ReceiptFaultKind::Received, String::new()),
        Fault::Envs => (ReceiptFaultKind::Envs, String::new()),
        Fault::Service => (ReceiptFaultKind::Service, String::new()),
        Fault::Omitted => (ReceiptFaultKind::Omitted, String::new()),
        Fault::Amount { signed, asked } => (
            ReceiptFaultKind::Amount,
            format!("signed {signed} MU, asked {asked} MU"),
        ),
    };
    ReceiptFaultView { kind, detail }
}

fn unknown_instance() -> CelautError {
    invalid("This instance is not known. It was deleted.")
}

/// The receipts of the instance `instance_id`. The stored receipts are checked again
/// against the node and the token of the instance.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_instance_receipts(instance_id: String) -> Result<ReceiptsView, CelautError> {
    let (record, receipts) = db()
        .read(|d| {
            d.instances
                .get(&instance_id)
                .map(|r| (r.clone(), d.receipts.get(&instance_id).cloned()))
        })
        .ok_or_else(unknown_instance)?;
    let s = summarize(
        &receipts.unwrap_or_default(),
        &record.peer_id,
        &record.token,
    );
    Ok(ReceiptsView {
        start: match s.start_ok {
            None => StartReceiptState::None,
            Some(true) => StartReceiptState::Valid,
            Some(false) => StartReceiptState::Invalid,
        },
        checkpoints: s.checkpoints,
        streams: s.streams,
        dropped_streams: s.dropped_streams,
        closed: s.closed,
        cancelled: s.cancelled,
        no_close: s.no_close,
        faults: s.faults.iter().map(fault_view).collect(),
    })
}

/// The receipts of the instance as JSON Lines, one receipt on each line, in the form of
/// `nodo receipt verify`. The token is not in it; whoever checks the file with
/// `--token` needs it from the user.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_export_receipts(instance_id: String) -> Result<String, CelautError> {
    db().read(|d| {
        if !d.instances.contains_key(&instance_id) {
            return Err(unknown_instance());
        }
        Ok(d.receipts
            .get(&instance_id)
            .map(export_jsonl)
            .unwrap_or_default())
    })
}

/// How long the sink waits before it writes the receipts to the disk. The receipts that
/// come in this time go to the disk in one write.
const FLUSH_DELAY: std::time::Duration = std::time::Duration::from_millis(500);

/// True while a write to the disk is planned and has not started.
static FLUSH_PLANNED: AtomicBool = AtomicBool::new(false);

fn flush_now() {
    // A failed write stays in memory. The next write saves it.
    let _ = db().flush();
}

/// Write the database to the disk, off the task of the tunnel. With `force`, the write
/// starts at once. If not, it waits for [`FLUSH_DELAY`], and the changes that come in
/// the meantime share one write.
fn schedule_flush(force: bool) {
    let Ok(runtime) = tokio::runtime::Handle::try_current() else {
        // No runtime: nothing to block, so write here.
        flush_now();
        return;
    };
    if force {
        runtime.spawn_blocking(flush_now);
    } else if !FLUSH_PLANNED.swap(true, Ordering::AcqRel) {
        let inner = runtime.clone();
        runtime.spawn(async move {
            tokio::time::sleep(FLUSH_DELAY).await;
            // Clear the flag before the write: a change during the write plans a new one.
            FLUSH_PLANNED.store(false, Ordering::Release);
            inner.spawn_blocking(flush_now);
        });
    }
}

/// The sink of the tunnel streams of an instance: each receipt goes into the database
/// in memory, and the disk write comes later, off the task of the tunnel. The end of a
/// stream forces the write. A deleted instance keeps nothing.
pub(crate) fn sink(instance_id: String) -> ReceiptSink {
    Arc::new(move |event| {
        let ended = matches!(event, ReceiptEvent::Ended { .. });
        let kept = db().update_in_memory(|d| {
            let known = d.instances.contains_key(&instance_id);
            if known {
                d.receipts
                    .entry(instance_id.clone())
                    .or_default()
                    .apply(&event, now_seconds());
            }
            known
        });
        if kept {
            schedule_flush(ended);
        }
    })
}

/// The sink of the tunnel streams to a descendant: the receipts go under the descendant
/// `record_key` ([`celaut_client::descendants::key`]), in memory first and then to the
/// disk as for [`sink`]. A descendant that the database does not know keeps nothing.
pub(crate) fn descendant_sink(record_key: String) -> ReceiptSink {
    let inner = celaut_client::descendants::receipt_sink(db(), record_key, now_seconds);
    Arc::new(move |event| {
        let ended = matches!(event, ReceiptEvent::Ended { .. });
        inner(event);
        schedule_flush(ended);
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use celaut_client::db::InstanceRecord;
    use celaut_proto::celaut::ExecutionReceipt;
    use celaut_wire::StreamReceipt;

    fn record(id: &str) {
        db().update(|d| {
            d.instances.insert(
                id.into(),
                InstanceRecord {
                    peer_id: "1".repeat(64),
                    address: "h:1".into(),
                    token: "tok".into(),
                    service_id: "2".repeat(64),
                    slots: vec![8080],
                    chat_slots: vec![],
                    cards_slots: vec![],
                    web_slots: vec![],
                    started_at: 1,
                    start_charge_mu: None,
                    name: None,
                    alias: None,
                    title: None,
                    topped_up_mu: None,
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
        })
        .unwrap();
    }

    #[test]
    fn an_instance_with_no_receipt_shows_none() {
        record("rcpt-none");
        let v = celaut_instance_receipts("rcpt-none".into()).unwrap();
        assert_eq!(v.start, StartReceiptState::None);
        assert_eq!((v.checkpoints, v.streams), (0, 0));
        assert!(v.faults.is_empty());
        assert_eq!(celaut_export_receipts("rcpt-none".into()).unwrap(), "");
        assert!(celaut_instance_receipts("rcpt-unknown".into()).is_err());
    }

    #[test]
    fn a_missing_start_receipt_of_a_node_that_gives_them_is_a_fault() {
        record("rcpt-omit");
        db().update(|d| {
            d.receipts
                .entry("rcpt-omit".into())
                .or_default()
                .expects_start = true;
        })
        .unwrap();
        let v = celaut_instance_receipts("rcpt-omit".into()).unwrap();
        assert_eq!(v.start, StartReceiptState::Invalid);
        assert!(v.faults.iter().any(|f| f.kind == ReceiptFaultKind::Omitted));
    }

    #[test]
    fn the_sink_keeps_what_the_tunnel_found() {
        record("rcpt-sink");
        let sink = sink("rcpt-sink".into());
        sink(ReceiptEvent::Receipt(StreamReceipt {
            receipt: ExecutionReceipt {
                kind: "checkpoint".into(),
                session: "ab".into(),
                seq: 1,
                ..Default::default()
            },
            problems: vec!["the signature does not verify".into()],
            ordering: vec![],
            sent_mismatch: false,
            got_mismatch: false,
        }));
        let v = celaut_instance_receipts("rcpt-sink".into()).unwrap();
        // A receipt that failed the check takes no stream slot.
        assert_eq!((v.checkpoints, v.streams), (0, 0));
        assert!(v.faults.iter().all(|f| f.kind == ReceiptFaultKind::Invalid));
        assert!(!v.faults.is_empty());
        assert_eq!(
            celaut_export_receipts("rcpt-sink".into())
                .unwrap()
                .lines()
                .count(),
            1
        );
        // A deleted instance keeps nothing.
        let gone = super::sink("rcpt-gone".into());
        gone(ReceiptEvent::Ended {
            session: None,
            closed: false,
            cancelled: true,
        });
        assert!(db().read(|d| !d.receipts.contains_key("rcpt-gone")));
    }
}
