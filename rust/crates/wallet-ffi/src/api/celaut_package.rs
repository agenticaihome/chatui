//! Give a service to a node that does not have it (`docs/celaut/package.md`).
//!
//! A node refuses a service that it does not have, unless the request carries it. The
//! app gets the service from a node that has it (`GetService`), or from a `.celaut.bee`
//! file that `nodo export` wrote, keeps it in a file of the app, and gives it to the
//! node with a quote: the node stores it, and then the launch works as usual. The file
//! is read while it is sent, so a large service never sits in memory.
//!
//! One transfer at a time. [`celaut_transfer_progress`] gives its bytes so far, and
//! [`celaut_cancel_transfer`] stops it: the node gets markers that make it refuse the cut
//! service, so a node never keeps half a service. A node that already has the service
//! answers after its hash, and the app then stops sending it (`celaut_wire::relay`).

use std::path::PathBuf;
use std::sync::Mutex;

use celaut_client::db::PackageRecord;
use celaut_client::link::{self, LinkOptions, LinkProgress, Scheme};
use celaut_client::package::{
    import, inspect, read, remove_file, save, Cancel, Layout, PackageError, PackageInfo,
};

use super::celaut::{error_of, invalid, CelautError, CelautErrorKind};
use super::celaut_db::{db, now_seconds};
use super::celaut_service::{
    configuration, forget_if_broken, n, quote_view, service_id, session, NodeAddress, QuoteView,
};
use celaut_client::db::QuoteRecord;

/// What a package file holds.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackageView {
    /// Where the file is.
    pub path: String,
    /// The size of the file, in bytes.
    pub bytes: u64,
    /// The id of the service (64 hexadecimal characters), if the package says it.
    pub service_id: Option<String>,
    /// True if the package has the Service part, not only its description.
    pub has_service: bool,
    /// True for a file of `nodo export` (its parts get the indices of a node).
    pub nodo_export: bool,
}

/// A service file that the user loaded into the app (the library of `celaut_packages`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LibraryPackageView {
    /// The id of the service: 64 lowercase hexadecimal characters.
    pub service_id: String,
    /// The name to show.
    pub name: String,
    /// The file of the app that holds the package.
    pub path: String,
    /// The size of the file, in bytes.
    pub bytes: u64,
    /// The time of the load, in Unix seconds.
    pub imported_at: i64,
    /// True for a file of `nodo export`.
    pub nodo_export: bool,
    /// False if the file is gone (the user or the system deleted it): the record stays so
    /// that the screen can say it, and the user can load the file again.
    pub present: bool,
}

/// The longest name that the library keeps, in characters.
const MAX_NAME: usize = 80;

/// The name to show for a file: the name of the file without `.celaut.bee` or `.bee`, with
/// no control characters, and no more than [`MAX_NAME`] characters. An empty name is the
/// first 8 characters of the service id.
fn clean_name(name: &str, service_id: &str) -> String {
    let base = name.rsplit(['/', '\\']).next().unwrap_or(name).trim();
    let lower = base.to_ascii_lowercase();
    let base = if lower.ends_with(".celaut.bee") {
        &base[..base.len() - ".celaut.bee".len()]
    } else if lower.ends_with(".bee") {
        &base[..base.len() - ".bee".len()]
    } else {
        base
    };
    let cleaned: String = base
        .chars()
        .filter(|c| !c.is_control())
        .take(MAX_NAME)
        .collect();
    let cleaned = cleaned.trim().to_string();
    if cleaned.is_empty() {
        service_id.chars().take(8).collect()
    } else {
        cleaned
    }
}

fn library_view(service_id: &str, r: &PackageRecord) -> LibraryPackageView {
    LibraryPackageView {
        service_id: service_id.to_string(),
        name: r.name.clone(),
        path: r.path.clone(),
        bytes: r.bytes,
        imported_at: r.imported_at,
        nodo_export: r.nodo_export,
        present: std::path::Path::new(&r.path).is_file(),
    }
}

/// Load the service file at `path` (a copy of the file that the user chose, in the cache of
/// the app) into the library of the app, which keeps it in a private directory `dir` under
/// the id of its service. The file is moved, not copied. `name` is the name of the file
/// that the user chose. A file that is not a package of a service, that does not say which
/// service it is, or that has a block that does not hash to its id, is refused (kind
/// `invalidInput`) and stays where it is. While it checks the file, the load is the
/// transfer that `celaut_transfer_progress` tells, and `celaut_cancel_transfer` stops it.
/// A second load of the same service replaces the first.
#[flutter_rust_bridge::frb]
pub async fn celaut_import_package(
    path: String,
    name: String,
    dir: String,
) -> Result<LibraryPackageView, CelautError> {
    if dir.trim().is_empty() {
        return Err(invalid("the app has no directory for the package"));
    }
    let source = PathBuf::from(&path);
    let size = std::fs::metadata(&source).map_err(|e| package_error(e.into()))?.len();
    let cancel = begin(TransferStage::Checking, Some(size))?;
    let imported = import(&source, &PathBuf::from(dir), &cancel).await;
    end();
    let imported = imported.map_err(package_error)?;
    let id = hex::encode(imported.service_id);
    let record = PackageRecord {
        name: clean_name(&name, &id),
        path: imported.path.display().to_string(),
        bytes: imported.info.bytes,
        imported_at: now_seconds(),
        nodo_export: imported.info.layout == Layout::NodoExport,
    };
    let view = library_view(&id, &record);
    db().update(|d| {
        d.packages.insert(id.clone(), record);
    })
    .map_err(super::celaut_db::storage_error)?;
    Ok(view)
}

/// The service files that the user loaded into the app, by name. It makes no connection.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_packages() -> Vec<LibraryPackageView> {
    let mut list: Vec<LibraryPackageView> = db().read(|d| {
        d.packages
            .iter()
            .map(|(id, r)| library_view(id, r))
            .collect()
    });
    list.sort_by(|a, b| {
        a.name
            .to_lowercase()
            .cmp(&b.name.to_lowercase())
            .then_with(|| a.service_id.cmp(&b.service_id))
    });
    list
}

/// Remove a service file from the library: the file is deleted and the record is dropped.
/// The nodes that have the service keep it. Nothing happens for a service that is not in
/// the library.
#[flutter_rust_bridge::frb]
pub async fn celaut_remove_package(service_id_hex: String) -> Result<(), CelautError> {
    let id = hex::encode(service_id(&service_id_hex)?);
    let record = db().read(|d| d.packages.get(&id).cloned());
    let Some(record) = record else {
        return Ok(());
    };
    remove_file(&PathBuf::from(&record.path))
        .await
        .map_err(package_error)?;
    db().update(|d| {
        d.packages.remove(&id);
    })
    .map_err(super::celaut_db::storage_error)?;
    Ok(())
}

/// A link that the user gave, before the download (issue #135).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinkView {
    /// The link, without the spaces around it.
    pub url: String,
    /// True for `http://`: not encrypted. The app warns before it downloads.
    pub insecure: bool,
    /// The name that the service gets in the library, from the path of the link; empty if
    /// the link has none (the library then uses the start of the service id).
    pub name: String,
    /// The id of the service that the link asks for (its fragment), if it says one.
    pub service_id: Option<String>,
}

/// A download of a link that stopped and can go on.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PendingLinkView {
    pub url: String,
    /// The bytes that are on the phone.
    pub bytes: u64,
}

/// Check a link that the user typed, pasted, scanned or opened: `https://` (or `http://`,
/// with [`LinkView::insecure`]), with a host. Refused with the kind `invalidInput`.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_check_link(url: String) -> Result<LinkView, CelautError> {
    let url = url.trim().to_string();
    let scheme = link::check_url(&url).map_err(package_error)?;
    let name = link::name_of(&url);
    Ok(LinkView {
        insecure: scheme == Scheme::Http,
        name: if name.is_empty() { String::new() } else { clean_name(&name, "") },
        service_id: link::expected_id(&url).map(hex::encode),
        url,
    })
}

/// The download of a link that stopped (no network, the app closed), if any. It goes on
/// when the user imports the same link again.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_pending_link(dir: String) -> Option<PendingLinkView> {
    if dir.trim().is_empty() {
        return None;
    }
    link::pending(&PathBuf::from(dir)).map(|p| PendingLinkView {
        url: p.url,
        bytes: p.bytes,
    })
}

/// Delete the files of a download that stopped.
#[flutter_rust_bridge::frb]
pub async fn celaut_discard_link(dir: String) -> Result<(), CelautError> {
    if dir.trim().is_empty() {
        return Ok(());
    }
    link::discard(&PathBuf::from(dir)).map_err(package_error)
}

/// The time that a download through Tor or another proxy waits for a byte.
const LINK_IDLE_PROXY: std::time::Duration = std::time::Duration::from_secs(120);

/// Download the service at `url` (a `.celaut.bee` file, or a manifest: one link of a chunk
/// on each line) into the library of the app in `dir`, and check it while the bytes arrive:
/// each block, and the hash of the whole Service against the id of the service. See
/// `celaut_client::link`. The requests follow the network route of the app (Tor).
///
/// - `allow_http`: the user said yes to the warning for `http://`.
/// - `max_bytes`: the largest file. A larger one stops, and its bytes are deleted
///   (kind `limitReached`, the message is the limit).
///
/// A failed request is tried again. A download that still fails (kind `unreachable`) stays
/// on the phone, and the same link goes on from there ([`celaut_pending_link`]). A cancel
/// ([`celaut_cancel_transfer`]) and a file that fails the check (kind `invalidInput`)
/// delete it. [`celaut_transfer_progress`] gives the bytes and the chunk.
#[flutter_rust_bridge::frb]
pub async fn celaut_import_link(
    url: String,
    dir: String,
    allow_http: bool,
    max_bytes: u64,
) -> Result<LibraryPackageView, CelautError> {
    if dir.trim().is_empty() {
        return Err(invalid("the app has no directory for the package"));
    }
    let checked = celaut_check_link(url)?;
    let cancel = begin(TransferStage::Downloading, None)?;
    let progress = LinkProgress::new();
    if let Some(r) = transfer().as_mut() {
        r.link = Some(progress.clone());
    }
    let mut options = LinkOptions {
        max_bytes,
        allow_http,
        ..LinkOptions::default()
    };
    if !matches!(celaut_net::route(), celaut_net::Route::Direct) {
        options.idle = LINK_IDLE_PROXY;
    }
    let source = HttpSource { allow_http };
    let result = link::download(
        &source,
        &checked.url,
        &PathBuf::from(&dir),
        &options,
        &cancel,
        &progress,
    )
    .await;
    end();
    let downloaded = result.map_err(package_error)?;
    let id = hex::encode(downloaded.service_id);
    tracing::info!(
        "service {id}: {} bytes from a link{}, {} retries{}",
        downloaded.bytes,
        if downloaded.chunks > 0 {
            format!(" in {} chunks", downloaded.chunks)
        } else {
            String::new()
        },
        progress.retries(),
        if downloaded.resumed { ", resumed" } else { "" }
    );
    let record = PackageRecord {
        name: clean_name(&checked.name, &id),
        path: downloaded.path.display().to_string(),
        bytes: downloaded.bytes,
        imported_at: now_seconds(),
        nodo_export: downloaded.layout == Layout::NodoExport,
    };
    let view = library_view(&id, &record);
    db().update(|d| {
        d.packages.insert(id.clone(), record);
    })
    .map_err(super::celaut_db::storage_error)?;
    Ok(view)
}

/// The requests of a download, on the HTTP client of the app (its TLS roots and its network
/// route). A redirect to `http://` is refused unless the user allowed `http://`.
struct HttpSource {
    allow_http: bool,
}

impl HttpSource {
    fn client(&self) -> Result<reqwest::Client, link::FetchError> {
        let allow_http = self.allow_http;
        wallet_net::http::client_builder()
            .connect_timeout(std::time::Duration::from_secs(30))
            .redirect(reqwest::redirect::Policy::custom(move |attempt| {
                if attempt.previous().len() >= 10 {
                    attempt.error("too many redirects")
                } else if attempt.url().scheme() == "https"
                    || (allow_http && attempt.url().scheme() == "http")
                {
                    attempt.follow()
                } else {
                    attempt.error("a redirect to a link that is not https://")
                }
            }))
            .build()
            .map_err(|e| link::FetchError::Fatal(describe(&e)))
    }
}

/// The error with its causes: "error sending request" alone does not say why.
fn describe(error: &dyn std::error::Error) -> String {
    let mut text = error.to_string();
    let mut source = error.source();
    while let Some(cause) = source {
        text.push_str(": ");
        text.push_str(&cause.to_string());
        source = cause.source();
    }
    text
}

/// The start and the total of a `Content-Range: bytes a-b/total` (or `bytes */total`).
fn content_range(value: &str) -> Option<(Option<u64>, Option<u64>)> {
    let rest = value.trim().strip_prefix("bytes")?.trim();
    let (range, total) = rest.split_once('/')?;
    let total = total.trim().parse::<u64>().ok();
    let start = match range.trim() {
        "*" => None,
        r => Some(r.split_once('-')?.0.trim().parse::<u64>().ok()?),
    };
    Some((start, total))
}

impl link::Source for HttpSource {
    fn open(
        &self,
        url: &str,
        from: u64,
    ) -> futures::future::BoxFuture<'static, Result<link::Opened, link::FetchError>> {
        use link::FetchError::{Fatal, Retry};
        let client = self.client();
        // The fragment names the service for the app; it does not go to the server.
        let url = url.split('#').next().unwrap_or_default().to_string();
        Box::pin(async move {
            let client = client?;
            let mut request = client.get(&url);
            if from > 0 {
                request = request.header(reqwest::header::RANGE, format!("bytes={from}-"));
            }
            let response = request.send().await.map_err(|e| {
                if e.is_redirect() || e.is_builder() {
                    Fatal(describe(&e))
                } else {
                    Retry(describe(&e))
                }
            })?;
            let status = response.status();
            let range = response
                .headers()
                .get(reqwest::header::CONTENT_RANGE)
                .and_then(|v| v.to_str().ok())
                .and_then(content_range);
            let (start, total) = match status.as_u16() {
                200 => (0, response.content_length()),
                206 => match range {
                    Some((Some(start), total)) => (start, total),
                    _ => return Err(Retry("a partial answer with no Content-Range".into())),
                },
                // The Range starts at the end: the resource is already complete.
                416 if from > 0 && range.and_then(|r| r.1) == Some(from) => {
                    return Ok(link::Opened {
                        start: from,
                        total: Some(from),
                        body: Box::pin(futures::stream::empty()),
                    });
                }
                408 | 425 | 429 | 500..=599 => return Err(Retry(format!("HTTP {status}"))),
                _ => return Err(Fatal(format!("HTTP {status}"))),
            };
            let body = futures::stream::unfold(Some(response), |response| async move {
                let mut response = response?;
                match response.chunk().await {
                    Ok(Some(bytes)) => Some((Ok(bytes.to_vec()), Some(response))),
                    Ok(None) => None,
                    Err(e) => Some((Err(Retry(describe(&e))), None)),
                }
            });
            Ok(link::Opened {
                start,
                total,
                body: Box::pin(body),
            })
        })
    }
}

/// What a transfer does now.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransferStage {
    /// No transfer.
    Idle,
    /// The app gets the service from a node.
    Fetching,
    /// The app gives the service to a node.
    Sending,
    /// The app checks the blocks of a file that the user loads: the bytes that it read
    /// so far, of the size of the file.
    Checking,
    /// The app downloads a service from a link and checks it while the bytes arrive
    /// (`celaut_import_link`): the bytes on disk, of the size when the server says it.
    Downloading,
}

/// The transfer that runs, if any.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransferView {
    pub stage: TransferStage,
    /// The bytes moved so far.
    pub bytes: u64,
    /// The size of the whole package, when the app knows it (a send of a file).
    pub total: Option<u64>,
    /// For a download of a manifest: the chunk that downloads now, from 1. 0 otherwise.
    pub chunk: u32,
    /// For a download of a manifest: the number of chunks. 0 otherwise.
    pub chunks: u32,
    /// For a download: the tries that failed and were tried again.
    pub retries: u32,
}

struct Running {
    stage: TransferStage,
    cancel: Cancel,
    total: Option<u64>,
    link: Option<LinkProgress>,
}

static TRANSFER: Mutex<Option<Running>> = Mutex::new(None);

fn transfer() -> std::sync::MutexGuard<'static, Option<Running>> {
    TRANSFER.lock().unwrap_or_else(|e| e.into_inner())
}

/// Mark a transfer as running. Refused if another one runs.
fn begin(stage: TransferStage, total: Option<u64>) -> Result<Cancel, CelautError> {
    let mut t = transfer();
    if t.is_some() {
        return Err(invalid("another transfer of a service runs"));
    }
    let cancel = Cancel::new();
    *t = Some(Running {
        stage,
        cancel: cancel.clone(),
        total,
        link: None,
    });
    Ok(cancel)
}

fn end() {
    *transfer() = None;
}

pub(crate) fn package_error(e: PackageError) -> CelautError {
    match e {
        PackageError::Io(e) => CelautError {
            kind: CelautErrorKind::Storage,
            message: e.to_string(),
        },
        PackageError::Invalid(text) => CelautError {
            kind: CelautErrorKind::InvalidInput,
            message: text,
        },
        PackageError::Cancelled => CelautError {
            kind: CelautErrorKind::TransferFailed,
            message: "the transfer was cancelled".into(),
        },
        PackageError::Network(text) => CelautError {
            kind: CelautErrorKind::Unreachable,
            message: text,
        },
        PackageError::TooLarge(limit) => CelautError {
            kind: CelautErrorKind::LimitReached,
            message: limit.to_string(),
        },
        PackageError::Wire(e) => error_of(e.into()),
    }
}

fn view_of(path: String, info: &PackageInfo) -> PackageView {
    PackageView {
        path,
        bytes: info.bytes,
        service_id: info.service_id.map(hex::encode),
        has_service: info.has_service,
        nodo_export: info.layout == Layout::NodoExport,
    }
}

/// Get the service from `source`, a node that has it, into a file in `dir` (a
/// directory of the app), and say what the file holds. A node that does not have the
/// service gives the error [`CelautErrorKind::ServiceMissing`].
#[flutter_rust_bridge::frb]
pub async fn celaut_fetch_service(
    source: NodeAddress,
    service_id_hex: String,
    dir: String,
) -> Result<PackageView, CelautError> {
    let id = service_id(&service_id_hex)?;
    if dir.trim().is_empty() {
        return Err(invalid("the app has no directory for the package"));
    }
    let folder = PathBuf::from(dir).join("packages");
    std::fs::create_dir_all(&folder).map_err(|e| package_error(e.into()))?;
    let path = folder.join(format!("{}.bee", hex::encode(id)));
    let s = session(&source).await?;
    let cancel = begin(TransferStage::Fetching, None)?;
    let result = async {
        let raw = s.get_service(id).await.map_err(|e| {
            forget_if_broken(&source, &e);
            error_of(e)
        })?;
        save(raw, &path, &cancel).await.map_err(|e| match e {
            PackageError::Invalid(text) if text.contains("does not have the service") => {
                CelautError {
                    kind: CelautErrorKind::ServiceMissing,
                    message: text,
                }
            }
            other => package_error(other),
        })?;
        let info = inspect(&path).await.map_err(package_error)?;
        if info.service_id.is_some_and(|got| got != id) || !info.has_service {
            let _ = std::fs::remove_file(&path);
            return Err(invalid("the node gave another service, or no Service part"));
        }
        Ok(view_of(path.display().to_string(), &info))
    }
    .await;
    end();
    result
}

/// What the package file at `path` holds: for a `.celaut.bee` that the user chose.
#[flutter_rust_bridge::frb]
pub async fn celaut_inspect_package(path: String) -> Result<PackageView, CelautError> {
    let info = inspect(&PathBuf::from(&path)).await.map_err(package_error)?;
    Ok(view_of(path, &info))
}

/// Give the service in the package at `path` to `node` with a quote, and give the quote.
/// After it, the node has the service. The package must hold the service
/// `service_id_hex` (when it says its id) and its Service part. If the transfer fails or
/// is cancelled, the node refuses the cut service, and the error has the kind
/// [`CelautErrorKind::TransferFailed`]. A node can store the service and still refuse
/// the quote (for example, for an architecture that it does not run): that refusal is
/// the error.
#[flutter_rust_bridge::frb]
pub async fn celaut_send_service(
    node: NodeAddress,
    service_id_hex: String,
    initial_mu: Option<String>,
    path: String,
) -> Result<QuoteView, CelautError> {
    let id = service_id(&service_id_hex)?;
    let configuration = configuration(initial_mu)?;
    let path = PathBuf::from(path);
    let info = inspect(&path).await.map_err(package_error)?;
    if !info.has_service {
        return Err(invalid("the package has no Service part"));
    }
    if info.service_id.is_some_and(|got| got != id) {
        return Err(invalid("the package holds another service"));
    }
    let s = session(&node).await?;
    let cancel = begin(TransferStage::Sending, Some(info.bytes))?;
    // What the node got of the service: it can answer before the end when it already
    // has the service, and then the rest is not sent. It can also say which blocks it
    // holds while it reads (`skips`), and those are not sent. The count is after that.
    let sent = celaut_wire::SendCounter::new();
    let skips = celaut_wire::Skips::new();
    let result = s
        .quote_with_service(
            id,
            configuration,
            sent.wrap(skips.wrap(read(path, info.layout, cancel))),
            &skips,
        )
        .await;
    end();
    tracing::info!(
        "service {}: sent {} bytes in {} Buffers to {}, of a package of {} bytes, \
         {} block(s) that the node holds skipped; {}",
        hex::encode(id),
        sent.bytes(),
        sent.buffers(),
        s.peer_id(),
        info.bytes,
        skips.blocks(),
        if sent.ended() {
            "the whole service went"
        } else if result.is_ok() {
            "the node answered first: it has the service"
        } else {
            "the transfer stopped"
        }
    );
    let quote = result.map_err(|e| {
        forget_if_broken(&node, &e);
        error_of(e)
    })?;
    let stored = db().update(|d| {
        d.add_quote(QuoteRecord {
            peer_id: s.peer_id().to_string(),
            service_id: hex::encode(id),
            cost_mu: n(&quote.cost),
            at: now_seconds(),
        });
    });
    if let Err(e) = stored {
        tracing::warn!("the quote is not stored: {e}");
    }
    let mut view = quote_view(node, s.peer_id().to_string(), &quote);
    view.client_balance_mu = s.balance().await.map(|b| b.to_string()).unwrap_or_default();
    Ok(view)
}

/// The transfer that runs now.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_transfer_progress() -> TransferView {
    match transfer().as_ref() {
        Some(r) => {
            let (chunk, chunks) = r.link.as_ref().map_or((0, 0), LinkProgress::chunk);
            TransferView {
                stage: r.stage,
                bytes: r.cancel.bytes(),
                total: r.total.or_else(|| r.link.as_ref().and_then(LinkProgress::total)),
                chunk,
                chunks,
                retries: r.link.as_ref().map_or(0, LinkProgress::retries),
            }
        }
        None => TransferView {
            stage: TransferStage::Idle,
            bytes: 0,
            total: None,
            chunk: 0,
            chunks: 0,
            retries: 0,
        },
    }
}

/// Stop the transfer that runs, if any. The node refuses the cut service.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_cancel_transfer() {
    if let Some(r) = transfer().as_ref() {
        r.cancel.cancel();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_name_of_a_file_is_cleaned() {
        let id = "ab".repeat(32);
        for (raw, want) in [
            ("echo.celaut.bee", "echo"),
            ("ECHO.CELAUT.BEE", "ECHO"),
            ("my service.bee", "my service"),
            ("plain", "plain"),
            ("/storage/emulated/0/Download/echo.celaut.bee", "echo"),
            ("C:\\Users\\x\\echo.celaut.bee", "echo"),
            ("  spaced  .celaut.bee", "spaced"),
            ("tab\there\u{7}.bee", "tabhere"),
            ("", "abababab"),
            (".celaut.bee", "abababab"),
            ("   ", "abababab"),
        ] {
            assert_eq!(clean_name(raw, &id), want, "{raw:?}");
        }
        let long = format!("{}.celaut.bee", "x".repeat(300));
        assert_eq!(clean_name(&long, &id).chars().count(), MAX_NAME);
        // A name in another alphabet is not cut in the middle of a character.
        let wide = format!("{}.bee", "é".repeat(200));
        assert_eq!(clean_name(&wide, &id).chars().count(), MAX_NAME);
    }

    #[test]
    fn a_record_is_a_view_and_a_missing_file_is_not_present() {
        let id = "cd".repeat(32);
        let record = PackageRecord {
            name: "echo".into(),
            path: "/no/such/file.bee".into(),
            bytes: 9,
            imported_at: 3,
            nodo_export: true,
        };
        let view = library_view(&id, &record);
        assert_eq!((view.name.as_str(), view.bytes, view.nodo_export), ("echo", 9, true));
        assert!(!view.present);
        let here = std::env::temp_dir().join(format!("celaut-view-{}", std::process::id()));
        std::fs::write(&here, b"x").unwrap();
        let present = library_view(&id, &PackageRecord { path: here.display().to_string(), ..record });
        assert!(present.present);
        std::fs::remove_file(here).unwrap();
    }

    #[test]
    fn one_transfer_at_a_time_and_its_progress() {
        let cancel = begin(TransferStage::Sending, Some(100)).unwrap();
        assert!(begin(TransferStage::Fetching, None).is_err());
        let p = celaut_transfer_progress();
        assert_eq!((p.stage, p.bytes, p.total), (TransferStage::Sending, 0, Some(100)));
        celaut_cancel_transfer();
        assert!(cancel.is_cancelled());
        end();
        assert_eq!(celaut_transfer_progress().stage, TransferStage::Idle);
        // No transfer: cancel does nothing.
        celaut_cancel_transfer();
    }

    #[test]
    fn content_ranges_are_read() {
        assert_eq!(content_range("bytes 10-99/100"), Some((Some(10), Some(100))));
        assert_eq!(content_range("bytes 10-99/*"), Some((Some(10), None)));
        assert_eq!(content_range("bytes */100"), Some((None, Some(100))));
        assert_eq!(content_range("items 1-2/3"), None);
        assert_eq!(content_range("bytes x-2/3"), None);
    }

    #[test]
    fn a_link_is_checked_and_named() {
        let id = "ab".repeat(32);
        let v = celaut_check_link(format!("  https://h/dir/Echo%20Chat.celaut.bee#{id} ")).unwrap();
        assert_eq!(v.url, format!("https://h/dir/Echo%20Chat.celaut.bee#{id}"));
        assert!(!v.insecure);
        assert_eq!(v.name, "Echo Chat");
        assert_eq!(v.service_id.as_deref(), Some(id.as_str()));
        let v = celaut_check_link("http://h/x.celaut.bee.txt".into()).unwrap();
        assert!(v.insecure);
        assert_eq!(v.name, "x");
        assert_eq!(celaut_check_link("https://h".into()).unwrap().name, "");
        let e = celaut_check_link("ftp://h/x".into()).unwrap_err();
        assert_eq!(e.kind, CelautErrorKind::InvalidInput);
    }

    /// A small HTTP/1.1 server on 127.0.0.1: `/file` (1000 bytes, takes a Range),
    /// `/norange` (the same, no Range), `/missing` (404), `/busy` (503), `/to-http` (a
    /// redirect to `http://…/file`). Gives its port.
    async fn http_server() -> u16 {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        tokio::spawn(async move {
            loop {
                let Ok((mut tcp, _)) = listener.accept().await else { return };
                tokio::spawn(async move {
                    let mut request = Vec::new();
                    let mut buf = [0u8; 1024];
                    while !request.windows(4).any(|w| w == b"\r\n\r\n") {
                        match tcp.read(&mut buf).await {
                            Ok(0) | Err(_) => return,
                            Ok(n) => request.extend_from_slice(&buf[..n]),
                        }
                    }
                    let text = String::from_utf8_lossy(&request).to_string();
                    let path = text.split_whitespace().nth(1).unwrap_or("/").to_string();
                    let from = text
                        .lines()
                        .find_map(|l| l.to_ascii_lowercase().strip_prefix("range: bytes=").map(str::to_string))
                        .and_then(|r| r.trim_end_matches('-').trim().parse::<usize>().ok());
                    let file: Vec<u8> = (0..1000u32).map(|i| (i % 251) as u8).collect();
                    let (head, body) = match (path.as_str(), from) {
                        ("/file", Some(f)) if f >= file.len() => (
                            format!("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */{}\r\nContent-Length: 0\r\n", file.len()),
                            Vec::new(),
                        ),
                        ("/file", Some(f)) => (
                            format!(
                                "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes {f}-{}/{}\r\nContent-Length: {}\r\n",
                                file.len() - 1,
                                file.len(),
                                file.len() - f
                            ),
                            file[f..].to_vec(),
                        ),
                        ("/file" | "/norange", _) => (
                            format!("HTTP/1.1 200 OK\r\nContent-Length: {}\r\n", file.len()),
                            file,
                        ),
                        ("/busy", _) => ("HTTP/1.1 503 Busy\r\nContent-Length: 0\r\n".into(), Vec::new()),
                        ("/to-http", _) => (
                            format!("HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:{port}/file\r\nContent-Length: 0\r\n"),
                            Vec::new(),
                        ),
                        _ => ("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n".into(), Vec::new()),
                    };
                    let _ = tcp.write_all(format!("{head}Connection: close\r\n\r\n").as_bytes()).await;
                    let _ = tcp.write_all(&body).await;
                    let _ = tcp.shutdown().await;
                });
            }
        });
        port
    }

    async fn body_of(opened: link::Opened) -> Vec<u8> {
        use futures::StreamExt;
        let mut out = Vec::new();
        let mut body = opened.body;
        while let Some(piece) = body.next().await {
            out.extend(piece.unwrap());
        }
        out
    }

    #[tokio::test]
    async fn the_http_source_takes_ranges_and_sorts_the_errors() {
        use link::Source;
        let port = http_server().await;
        let url = |p: &str| format!("http://127.0.0.1:{port}{p}");
        let strict = HttpSource { allow_http: false };
        let file: Vec<u8> = (0..1000u32).map(|i| (i % 251) as u8).collect();

        let whole = strict.open(&url("/file"), 0).await.unwrap();
        assert_eq!((whole.start, whole.total), (0, Some(1000)));
        assert_eq!(body_of(whole).await, file);

        let rest = strict.open(&url("/file#ignored"), 600).await.unwrap();
        assert_eq!((rest.start, rest.total), (600, Some(1000)));
        assert_eq!(body_of(rest).await, file[600..]);

        // A server with no Range gives the whole file: the download starts it again.
        let again = strict.open(&url("/norange"), 600).await.unwrap();
        assert_eq!(again.start, 0);

        // A Range at the end: the file is already complete.
        let done = strict.open(&url("/file"), 1000).await.unwrap();
        assert_eq!((done.start, done.total), (1000, Some(1000)));
        assert!(body_of(done).await.is_empty());

        assert!(matches!(strict.open(&url("/missing"), 0).await, Err(link::FetchError::Fatal(e)) if e.contains("404")));
        assert!(matches!(strict.open(&url("/busy"), 0).await, Err(link::FetchError::Retry(e)) if e.contains("503")));
        // A redirect to http:// only with the consent of the user.
        assert!(matches!(strict.open(&url("/to-http"), 0).await, Err(link::FetchError::Fatal(_))));
        let lax = HttpSource { allow_http: true };
        assert_eq!(body_of(lax.open(&url("/to-http"), 0).await.unwrap()).await, file);
        // No server: a retry.
        let closed = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let dead = closed.local_addr().unwrap().port();
        drop(closed);
        assert!(matches!(
            strict.open(&format!("http://127.0.0.1:{dead}/file"), 0).await,
            Err(link::FetchError::Retry(_))
        ));
    }

    #[test]
    fn package_errors_have_their_kinds() {
        assert_eq!(
            package_error(PackageError::Cancelled).kind,
            CelautErrorKind::TransferFailed
        );
        assert_eq!(
            package_error(PackageError::Invalid("x".into())).kind,
            CelautErrorKind::InvalidInput
        );
        assert_eq!(
            package_error(PackageError::Io(std::io::Error::other("disk"))).kind,
            CelautErrorKind::Storage
        );
        assert_eq!(
            package_error(PackageError::Wire(celaut_wire::WireError::Relay("cut".into()))).kind,
            CelautErrorKind::TransferFailed
        );
    }
}
