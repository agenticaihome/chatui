//! A full scan of the wallet's scripts on an Esplora server.
//!
//! This is the full scan of `bdk_esplora` 0.22.3 (`async_ext.rs`, MIT OR Apache-2.0),
//! made with [`crate::esplora::Esplora`] instead of `esplora-client`, so that the app has
//! one HTTP stack. The steps are the same: the transactions of each script until
//! `stop_gap` scripts in a row have none, then a chain update that connects to the
//! wallet's local chain (point of agreement, blocks that changed, blocks of the anchors,
//! the last blocks).

use std::collections::{BTreeMap, BTreeSet, HashSet};

use bdk_wallet::bitcoin::{Address, BlockHash, Network, Txid};
use bdk_wallet::chain::spk_client::{FullScanRequest, FullScanResponse};
use bdk_wallet::chain::{BlockId, CheckPoint, ConfirmationBlockTime, TxUpdate};

use crate::esplora::{Esplora, EsploraError, EsploraTx};

/// The number of unused scripts in a row after which a keychain is not read further.
pub const STOP_GAP: usize = 20;

/// The scripts read at the same time.
const PARALLEL: usize = 4;

/// Esplora gives 25 confirmed transactions a page.
const PAGE: usize = 25;

fn insert_tx(update: &mut TxUpdate<ConfirmationBlockTime>, seen: &mut HashSet<Txid>, start_time: u64, tx: EsploraTx) {
    let txid = tx.tx.compute_txid();
    if seen.insert(txid) {
        update.txs.push(tx.tx.into());
    }
    match tx.status {
        crate::esplora::TxStatus {
            confirmed: true,
            block_height: Some(height),
            block_hash: Some(hash),
            block_time: Some(time),
        } => {
            update.anchors.insert((
                ConfirmationBlockTime {
                    block_id: BlockId { height, hash },
                    confirmation_time: time,
                },
                txid,
            ));
        }
        _ => {
            update.seen_ats.insert((txid, start_time));
        }
    }
    for (outpoint, txout) in tx.prevouts {
        update.txouts.insert(outpoint, txout);
    }
}

/// Every transaction of `address`, all pages.
async fn all_txs(esplora: &Esplora, address: &Address) -> Result<Vec<EsploraTx>, EsploraError> {
    let mut all = Vec::new();
    let mut after = None;
    loop {
        let page = esplora.address_txs(address, after).await?;
        let count = page.len();
        after = page.last().map(|t| t.tx.compute_txid());
        all.extend(page);
        if count < PAGE {
            return Ok(all);
        }
    }
}

/// Scan every keychain of `request` on `esplora`.
pub async fn full_scan<K: Ord + Clone>(
    esplora: &Esplora,
    network: Network,
    request: impl Into<FullScanRequest<K>>,
    stop_gap: usize,
) -> Result<FullScanResponse<K>, EsploraError> {
    let mut request: FullScanRequest<K> = request.into();
    let start_time = request.start_time();
    let chain_tip = request.chain_tip();
    let latest_blocks = esplora.latest_blocks().await?;

    let mut tx_update = TxUpdate::<ConfirmationBlockTime>::default();
    let mut seen = HashSet::<Txid>::new();
    let mut last_active_indices = BTreeMap::<K, u32>::new();
    let gap_limit = stop_gap.max(1);

    for keychain in request.keychains() {
        let last_revealed = request.last_revealed(&keychain);
        let mut spks = request.iter_spks(keychain.clone());
        let mut unused = 0usize;
        let mut last_active = None;
        loop {
            let batch: Vec<_> = spks.by_ref().take(PARALLEL).collect();
            if batch.is_empty() {
                break;
            }
            let reads = batch.into_iter().map(|(index, spk)| async move {
                let address = Address::from_script(&spk, network)
                    .map_err(|e| EsploraError::Invalid(format!("script {index}: {e}")))?;
                Ok::<_, EsploraError>((index, all_txs(esplora, &address).await?))
            });
            for (index, txs) in futures::future::try_join_all(reads).await? {
                if !txs.is_empty() {
                    unused = 0;
                    last_active = Some(index);
                } else if last_revealed.is_none_or(|lr| index > lr) {
                    unused += 1;
                }
                for tx in txs {
                    insert_tx(&mut tx_update, &mut seen, start_time, tx);
                }
            }
            if unused >= gap_limit {
                break;
            }
        }
        if let Some(index) = last_active {
            last_active_indices.insert(keychain, index);
        }
    }

    let chain_update = match chain_tip {
        Some(tip) => Some(chain_update(esplora, &latest_blocks, &tip, &tx_update.anchors).await?),
        None => None,
    };
    Ok(FullScanResponse {
        tx_update,
        last_active_indices,
        chain_update,
    })
}

async fn block_at(
    esplora: &Esplora,
    latest: &BTreeMap<u32, BlockHash>,
    height: u32,
) -> Result<Option<BlockHash>, EsploraError> {
    if let Some(hash) = latest.get(&height) {
        return Ok(Some(*hash));
    }
    match latest.keys().last() {
        Some(&tip) if height <= tip => Ok(Some(esplora.block_hash(height).await?)),
        _ => Ok(None),
    }
}

/// A chain update that connects to `local_tip`, as `bdk_esplora` makes it.
async fn chain_update(
    esplora: &Esplora,
    latest: &BTreeMap<u32, BlockHash>,
    local_tip: &CheckPoint,
    anchors: &BTreeSet<(ConfirmationBlockTime, Txid)>,
) -> Result<CheckPoint, EsploraError> {
    let mut agreement = None;
    let mut conflicts = Vec::new();
    for local in local_tip.iter() {
        let Some(remote) = block_at(esplora, latest, local.height()).await? else {
            continue;
        };
        if remote == local.hash() {
            agreement = Some(local);
            break;
        }
        conflicts.push(BlockId {
            height: local.height(),
            hash: remote,
        });
    }
    let mut tip = agreement.ok_or_else(|| {
        EsploraError::Invalid("no block of the wallet's chain is on the server's chain".into())
    })?;
    tip = tip
        .extend(conflicts.into_iter().rev())
        .map_err(|_| EsploraError::Invalid("blocks out of order".into()))?;
    for (anchor, _) in anchors {
        let height = anchor.block_id.height;
        if tip.get(height).is_none() {
            if let Some(hash) = block_at(esplora, latest, height).await? {
                tip = tip.insert(BlockId { height, hash });
            }
        }
    }
    for (&height, &hash) in latest {
        tip = tip.insert(BlockId { height, hash });
    }
    Ok(tip)
}
