//! The calls of the Esplora HTTP API that the wallet makes
//! (<https://github.com/Blockstream/esplora/blob/master/API.md>).
//!
//! Every request goes through `wallet_net::http`: one reqwest, rustls with ring, and the
//! network route of the app (direct, Tor, or blocked). The server is trusted only for
//! what it reports. A transaction from the server is rebuilt here and its id is computed
//! again: a transaction whose bytes do not give the id that the server sent is refused.

use std::collections::BTreeMap;
use std::str::FromStr;
use std::time::Duration;

use bdk_wallet::bitcoin::absolute::LockTime;
use bdk_wallet::bitcoin::consensus::encode::serialize_hex;
use bdk_wallet::bitcoin::transaction::Version;
use bdk_wallet::bitcoin::{
    Address, Amount, BlockHash, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid,
    Witness,
};
use serde::Deserialize;

/// The time limit of one request.
const TIMEOUT: Duration = Duration::from_secs(30);

/// An Esplora answer that the wallet cannot use, or no answer.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum EsploraError {
    #[error("the Esplora server did not answer: {0}")]
    Unreachable(String),
    #[error("the Esplora server answered {status}: {body}")]
    Status { status: u16, body: String },
    #[error("the Esplora server sent data that is not valid: {0}")]
    Invalid(String),
}

/// The status of a transaction (`status` of the API).
#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
pub struct TxStatus {
    pub confirmed: bool,
    pub block_height: Option<u32>,
    pub block_hash: Option<BlockHash>,
    pub block_time: Option<u64>,
}

#[derive(Debug, Clone, Deserialize)]
struct PrevOut {
    scriptpubkey: String,
    value: u64,
}

#[derive(Debug, Clone, Deserialize)]
struct Vin {
    txid: Txid,
    vout: u32,
    prevout: Option<PrevOut>,
    #[serde(default)]
    scriptsig: String,
    #[serde(default)]
    witness: Vec<String>,
    sequence: u32,
}

#[derive(Debug, Clone, Deserialize)]
struct Vout {
    scriptpubkey: String,
    value: u64,
}

#[derive(Debug, Clone, Deserialize)]
struct RawTx {
    txid: Txid,
    version: i32,
    locktime: u32,
    vin: Vec<Vin>,
    vout: Vec<Vout>,
    status: TxStatus,
}

/// A transaction of an address, with what the server says about its inputs.
#[derive(Debug, Clone)]
pub struct EsploraTx {
    pub tx: Transaction,
    pub status: TxStatus,
    /// The outputs that the inputs spend, when the server gives them. They let the wallet
    /// compute the fee of a transaction that it did not make.
    pub prevouts: Vec<(OutPoint, TxOut)>,
}

fn script(hex_text: &str) -> Result<ScriptBuf, EsploraError> {
    ScriptBuf::from_hex(hex_text).map_err(|e| EsploraError::Invalid(format!("script: {e}")))
}

impl RawTx {
    fn into_tx(self) -> Result<EsploraTx, EsploraError> {
        let mut prevouts = Vec::new();
        let mut input = Vec::with_capacity(self.vin.len());
        for vin in self.vin {
            let witness = vin
                .witness
                .iter()
                .map(|w| hex::decode(w).map_err(|e| EsploraError::Invalid(format!("witness: {e}"))))
                .collect::<Result<Vec<_>, _>>()?;
            let previous_output = OutPoint::new(vin.txid, vin.vout);
            if let Some(prev) = vin.prevout {
                prevouts.push((
                    previous_output,
                    TxOut {
                        value: Amount::from_sat(prev.value),
                        script_pubkey: script(&prev.scriptpubkey)?,
                    },
                ));
            }
            input.push(TxIn {
                previous_output,
                script_sig: script(&vin.scriptsig)?,
                sequence: Sequence(vin.sequence),
                witness: Witness::from_slice(&witness),
            });
        }
        let output = self
            .vout
            .iter()
            .map(|o| {
                Ok(TxOut {
                    value: Amount::from_sat(o.value),
                    script_pubkey: script(&o.scriptpubkey)?,
                })
            })
            .collect::<Result<Vec<_>, EsploraError>>()?;
        let tx = Transaction {
            version: Version(self.version),
            lock_time: LockTime::from_consensus(self.locktime),
            input,
            output,
        };
        if tx.compute_txid() != self.txid {
            return Err(EsploraError::Invalid(format!(
                "the transaction {} does not have that id",
                self.txid
            )));
        }
        Ok(EsploraTx {
            tx,
            status: self.status,
            prevouts,
        })
    }
}

#[derive(Debug, Clone, Deserialize)]
struct BlockSummary {
    id: BlockHash,
    height: u32,
}

/// An Esplora server.
#[derive(Debug, Clone)]
pub struct Esplora {
    base: String,
    http: reqwest::Client,
}

impl Esplora {
    /// A client for the API at `base` (`https://mempool.space/signet/api`). The client
    /// takes the network route of the app now; make a new one when the route changes.
    pub fn new(base: &str) -> Result<Self, EsploraError> {
        let base = base.trim().trim_end_matches('/').to_string();
        if !(base.starts_with("https://") || base.starts_with("http://")) {
            return Err(EsploraError::Invalid(format!(
                "the server address must start with https:// or http://: {base}"
            )));
        }
        let http = wallet_net::http::client_builder()
            .timeout(TIMEOUT)
            .build()
            .map_err(|e| EsploraError::Unreachable(e.to_string()))?;
        Ok(Esplora { base, http })
    }

    pub fn base(&self) -> &str {
        &self.base
    }

    async fn get_text(&self, path: &str) -> Result<String, EsploraError> {
        let response = self
            .http
            .get(format!("{}{path}", self.base))
            .send()
            .await
            .map_err(|e| EsploraError::Unreachable(e.without_url().to_string()))?;
        let status = response.status().as_u16();
        let body = response
            .text()
            .await
            .map_err(|e| EsploraError::Unreachable(e.without_url().to_string()))?;
        if status != 200 {
            return Err(EsploraError::Status {
                status,
                body: body.chars().take(200).collect(),
            });
        }
        Ok(body)
    }

    async fn get_json<T: serde::de::DeserializeOwned>(&self, path: &str) -> Result<T, EsploraError> {
        let text = self.get_text(path).await?;
        serde_json::from_str(&text).map_err(|e| EsploraError::Invalid(e.to_string()))
    }

    /// The height of the last block.
    pub async fn tip_height(&self) -> Result<u32, EsploraError> {
        let text = self.get_text("/blocks/tip/height").await?;
        text.trim()
            .parse()
            .map_err(|_| EsploraError::Invalid(format!("tip height {text:?}")))
    }

    /// The hash of the block at `height` on the best chain.
    pub async fn block_hash(&self, height: u32) -> Result<BlockHash, EsploraError> {
        let text = self.get_text(&format!("/block-height/{height}")).await?;
        BlockHash::from_str(text.trim()).map_err(|e| EsploraError::Invalid(e.to_string()))
    }

    /// The last blocks (the server gives 10), by height.
    pub async fn latest_blocks(&self) -> Result<BTreeMap<u32, BlockHash>, EsploraError> {
        let blocks: Vec<BlockSummary> = self.get_json("/blocks").await?;
        if blocks.is_empty() {
            return Err(EsploraError::Invalid("no blocks".into()));
        }
        Ok(blocks.into_iter().map(|b| (b.height, b.id)).collect())
    }

    /// One page of the transactions of `address`: unconfirmed first, then confirmed, the
    /// newest first. With `after`, the confirmed transactions after that one (25 a page).
    pub async fn address_txs(
        &self,
        address: &Address,
        after: Option<Txid>,
    ) -> Result<Vec<EsploraTx>, EsploraError> {
        let path = match after {
            None => format!("/address/{address}/txs"),
            Some(txid) => format!("/address/{address}/txs/chain/{txid}"),
        };
        let raw: Vec<RawTx> = self.get_json(&path).await?;
        raw.into_iter().map(RawTx::into_tx).collect()
    }

    /// The status of `txid`.
    pub async fn tx_status(&self, txid: &Txid) -> Result<TxStatus, EsploraError> {
        self.get_json(&format!("/tx/{txid}/status")).await
    }

    /// The fee rates in sat/vB by confirmation target in blocks. Regtest servers give none.
    pub async fn fee_estimates(&self) -> Result<BTreeMap<u16, f64>, EsploraError> {
        let raw: BTreeMap<String, f64> = self.get_json("/fee-estimates").await?;
        Ok(raw
            .into_iter()
            .filter_map(|(k, v)| Some((k.parse().ok()?, v)))
            .filter(|(_, v): &(u16, f64)| v.is_finite() && *v > 0.0)
            .collect())
    }

    /// Send `tx` to the network. The server must answer with the id of `tx`.
    pub async fn broadcast(&self, tx: &Transaction) -> Result<Txid, EsploraError> {
        let response = self
            .http
            .post(format!("{}/tx", self.base))
            .body(serialize_hex(tx))
            .send()
            .await
            .map_err(|e| EsploraError::Unreachable(e.without_url().to_string()))?;
        let status = response.status().as_u16();
        let body = response
            .text()
            .await
            .map_err(|e| EsploraError::Unreachable(e.without_url().to_string()))?;
        if status != 200 {
            return Err(EsploraError::Status {
                status,
                body: body.chars().take(300).collect(),
            });
        }
        let txid = tx.compute_txid();
        if body.trim() != txid.to_string() {
            return Err(EsploraError::Invalid(format!(
                "the server answered {:?}, not the id {txid}",
                body.trim()
            )));
        }
        Ok(txid)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A signet transaction as mempool.space gives it (one P2WPKH input, two outputs).
    const TX_JSON: &str = r#"{"txid":"TXID","version":2,"locktime":0,
      "vin":[{"txid":"7c2a2a0e9c5cf1b3c5b9c3a0bd4e7f2fa51ad0c2e8c9a3f8e1f8b4b1a6e4c3d2","vout":1,
        "prevout":{"scriptpubkey":"0014d0c4a3ef09e997b6e99e397e518fe3e41a118ca1","value":100000},
        "scriptsig":"","witness":["3044022000","02aa"],"is_coinbase":false,"sequence":4294967293}],
      "vout":[{"scriptpubkey":"0014d0c4a3ef09e997b6e99e397e518fe3e41a118ca1","value":40000},
              {"scriptpubkey":"6a0474657374","value":0}],
      "status":{"confirmed":true,"block_height":200,"block_hash":"0000000000000000000000000000000000000000000000000000000000000001","block_time":1700000000}}"#;

    fn tx_json() -> String {
        // The id of the transaction that the JSON describes, put where the server writes it.
        let prev = Txid::from_str("7c2a2a0e9c5cf1b3c5b9c3a0bd4e7f2fa51ad0c2e8c9a3f8e1f8b4b1a6e4c3d2").unwrap();
        let rebuilt = Transaction {
            version: Version(2),
            lock_time: LockTime::from_consensus(0),
            input: vec![TxIn {
                previous_output: OutPoint::new(prev, 1),
                script_sig: ScriptBuf::new(),
                sequence: Sequence(4294967293),
                witness: Witness::from_slice(&[hex::decode("3044022000").unwrap(), hex::decode("02aa").unwrap()]),
            }],
            output: vec![
                TxOut {
                    value: Amount::from_sat(40000),
                    script_pubkey: ScriptBuf::from_hex("0014d0c4a3ef09e997b6e99e397e518fe3e41a118ca1").unwrap(),
                },
                TxOut {
                    value: Amount::ZERO,
                    script_pubkey: ScriptBuf::from_hex("6a0474657374").unwrap(),
                },
            ],
        };
        TX_JSON.replace("TXID", &rebuilt.compute_txid().to_string())
    }

    #[test]
    fn rebuilds_the_transaction_and_checks_its_id() {
        let raw: RawTx = serde_json::from_str(&tx_json()).unwrap();
        let tx = raw.into_tx().unwrap();
        assert_eq!(tx.tx.output.len(), 2);
        assert!(tx.tx.output[1].script_pubkey.is_op_return());
        assert_eq!(tx.prevouts.len(), 1);
        assert_eq!(tx.prevouts[0].1.value, Amount::from_sat(100000));
        assert!(tx.status.confirmed);
        assert_eq!(tx.status.block_height, Some(200));
    }

    #[test]
    fn refuses_a_transaction_with_another_id() {
        let wrong = tx_json().replace("\"value\":40000", "\"value\":40001");
        let raw: RawTx = serde_json::from_str(&wrong).unwrap();
        assert!(matches!(raw.into_tx(), Err(EsploraError::Invalid(_))));
    }

    #[test]
    fn refuses_a_server_without_scheme() {
        assert!(Esplora::new("mempool.space/api").is_err());
        assert_eq!(
            Esplora::new("https://mempool.space/signet/api/").unwrap().base(),
            "https://mempool.space/signet/api"
        );
    }

    /// Answer `count` HTTP/1.1 requests, one per connection, from `route(target)`.
    fn serve(
        count: usize,
        route: fn(&str) -> (u16, String),
    ) -> (String, std::thread::JoinHandle<()>) {
        use std::io::{BufRead, BufReader, Write};
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let handle = std::thread::spawn(move || {
            for stream in listener.incoming().take(count) {
                let mut stream = stream.unwrap();
                let mut line = String::new();
                BufReader::new(&stream).read_line(&mut line).unwrap();
                let target = line.split_whitespace().nth(1).unwrap_or("").to_string();
                let (status, body) = route(&target);
                write!(
                    stream,
                    "HTTP/1.1 {status} X\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{body}",
                    body.len()
                )
                .unwrap();
            }
        });
        (url, handle)
    }

    #[tokio::test]
    async fn reads_the_api() {
        let (url, server) = serve(4, |target| match target {
            "/blocks/tip/height" => (200, "812\n".into()),
            "/block-height/5" => (
                200,
                "0000000000000000000000000000000000000000000000000000000000000005".into(),
            ),
            "/fee-estimates" => (200, r#"{"1":20.5,"6":4.1,"144":1.0,"x":3,"3":-1}"#.into()),
            "/blocks" => (
                200,
                r#"[{"id":"0000000000000000000000000000000000000000000000000000000000000009","height":9}]"#
                    .into(),
            ),
            _ => (404, "not found".into()),
        });
        let esplora = Esplora::new(&url).unwrap();
        assert_eq!(esplora.tip_height().await.unwrap(), 812);
        assert_eq!(
            esplora.block_hash(5).await.unwrap().to_string(),
            "0000000000000000000000000000000000000000000000000000000000000005"
        );
        let fees = esplora.fee_estimates().await.unwrap();
        assert_eq!(fees.keys().copied().collect::<Vec<_>>(), vec![1, 6, 144]);
        assert_eq!(esplora.latest_blocks().await.unwrap().len(), 1);
        server.join().unwrap();
    }
}
