//! Import a service from a link (issue #135, `docs/celaut/package.md`, "From a link").
//!
//! The link gives one of two things, and the app tells them apart by the content, not by
//! the name or the `Content-Type`:
//!
//! - **a `.celaut.bee` file.** Its first byte is the first byte of the length of its first
//!   record (big-endian), which is never more than [`MAX_RECORD`] (16 MiB): so it is `0x00`
//!   or `0x01`.
//! - **a manifest**: UTF-8 text with the link of one chunk on each line. The chunks, joined
//!   in the order of the lines, are the `.celaut.bee` file. Text starts with a printable
//!   character (or a byte order mark), never with `0x00` or `0x01`.
//!
//! The file can be very large. [`download`] writes it to disk as the bytes arrive and checks
//! it at the same time ([`Check`]): it keeps no more than one record in memory. At the end
//! the Service must hash to the id of the service. A file that fails the check is deleted.
//!
//! A failed request is tried again ([`LinkOptions::attempts`]), from the byte where it
//! stopped when the server takes a `Range`. A download that stops (no network, the app was
//! closed) stays on disk, and the next download of the same link goes on from there: a
//! file from its last byte, a manifest from its last complete chunk (and from the byte in
//! that chunk, with a `Range`). A cancel deletes the files. Only the last download is kept:
//! a download of another link deletes the files of the one before.
//!
//! Before it writes, a download checks the free space of the phone ([`LinkOptions::min_free`]):
//! a file that does not fit is refused before its first byte, and a download that fills the
//! disk later stops and is kept, like a download that lost the network
//! ([`PackageError::NoSpace`], issue #151).
//!
//! The requests go through a [`Source`]: the app gives one on its HTTP client (with the
//! network route of the app), and the tests give one in memory.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;

use futures::future::BoxFuture;
use futures::stream::BoxStream;
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use sha3::{Digest, Sha3_256};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};

use crate::package::{
    free_space, into_library_whole, is_disk_full, Cancel, Check, Layout, PackageError, Storage,
    MAX_RECORD,
};

/// The largest manifest, in bytes. 1 MiB holds thousands of links.
pub const MAX_MANIFEST: usize = 1024 * 1024;
/// The most chunks that a manifest can list.
pub const MAX_CHUNKS: usize = 10_000;
/// The longest link, in bytes.
pub const MAX_URL: usize = 4096;

/// The scheme of a link.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scheme {
    Https,
    /// Not encrypted: anyone on the way sees what the app downloads, and can change it. The
    /// check of the hash still refuses a changed file.
    Http,
}

/// Check that `url` is a link that the app can download: `https://` or `http://`, a host,
/// no space and no control character. Gives its scheme.
pub fn check_url(url: &str) -> Result<Scheme, PackageError> {
    let bad = |why: &str| PackageError::Invalid(format!("the link is not valid: {why}"));
    if url.is_empty() {
        return Err(bad("it is empty"));
    }
    if url.len() > MAX_URL {
        return Err(bad("it is too long"));
    }
    if url.chars().any(|c| c.is_whitespace() || c.is_control()) {
        return Err(bad("it has a space or a control character"));
    }
    let lower = url.to_ascii_lowercase();
    let (scheme, rest) = if let Some(rest) = lower.strip_prefix("https://") {
        (Scheme::Https, rest)
    } else if let Some(rest) = lower.strip_prefix("http://") {
        (Scheme::Http, rest)
    } else {
        return Err(bad("only https:// and http:// links are accepted"));
    };
    let authority = rest.split(['/', '?', '#']).next().unwrap_or_default();
    let host = authority.rsplit('@').next().unwrap_or_default();
    if host.is_empty() || host.starts_with(':') {
        return Err(bad("it has no host"));
    }
    Ok(scheme)
}

/// The id of the service that the link asks for, if its fragment is 64 hexadecimal
/// characters (`https://host/echo.celaut.bee#<id>`). The fragment does not go to the server.
pub fn expected_id(url: &str) -> Option<[u8; 32]> {
    let fragment = url.split_once('#')?.1;
    if fragment.len() != 64 {
        return None;
    }
    hex::decode(fragment).ok()?.try_into().ok()
}

/// The name of the service that the link suggests: the last part of its path, decoded, with
/// no `.txt` (a manifest). The library then removes `.celaut.bee` (`clean_name`).
pub fn name_of(url: &str) -> String {
    let no_fragment = url.split('#').next().unwrap_or_default();
    let path = no_fragment.split('?').next().unwrap_or_default();
    let after_scheme = path.split_once("://").map(|(_, r)| r).unwrap_or(path);
    let last = after_scheme
        .split_once('/')
        .map(|(_, p)| p)
        .unwrap_or_default()
        .rsplit('/')
        .find(|s| !s.is_empty())
        .unwrap_or_default();
    let decoded = percent_decode(last);
    let lower = decoded.to_ascii_lowercase();
    match lower.strip_suffix(".txt") {
        Some(_) => decoded[..decoded.len() - 4].to_string(),
        None => decoded,
    }
}

fn percent_decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let pair = &bytes[i + 1..i + 3];
            if pair.iter().all(u8::is_ascii_hexdigit) {
                let text = std::str::from_utf8(pair).unwrap_or_default();
                if let Ok(b) = u8::from_str_radix(text, 16) {
                    out.push(b);
                    i += 3;
                    continue;
                }
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// The links of the chunks in a manifest, in order. A manifest is UTF-8 text (a byte order
/// mark is allowed) with one link on each line; empty lines are skipped. `allow_http` takes
/// `http://` links too.
pub fn parse_manifest(bytes: &[u8], allow_http: bool) -> Result<Vec<String>, PackageError> {
    let text = std::str::from_utf8(bytes)
        .map_err(|_| neither("it is not UTF-8 text, and not a service file"))?;
    let text = text.strip_prefix('\u{feff}').unwrap_or(text);
    let mut links = Vec::new();
    for (n, line) in text.split('\n').enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let scheme = check_url(line).map_err(|e| {
            neither(&format!("the line {} is not a link ({e})", n + 1))
        })?;
        if scheme == Scheme::Http && !allow_http {
            return Err(PackageError::Invalid(format!(
                "the line {} of the list is an http:// link, which is not encrypted",
                n + 1
            )));
        }
        links.push(line.to_string());
        if links.len() > MAX_CHUNKS {
            return Err(PackageError::Invalid(format!(
                "the list has more than {MAX_CHUNKS} links"
            )));
        }
    }
    if links.is_empty() {
        return Err(neither("it is empty"));
    }
    Ok(links)
}

fn neither(why: &str) -> PackageError {
    PackageError::Invalid(format!(
        "the link gives neither a service file nor a list of links: {why}"
    ))
}

/// The error of a request.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FetchError {
    /// It can work later: no connection, a cut answer, a server error (5xx, 408, 429).
    Retry(String),
    /// It will not work (404, 403, …).
    Fatal(String),
}

/// The answer to a request.
pub struct Opened {
    /// The position in the resource of the first byte of `body`: the asked position when
    /// the server took the `Range`, 0 when it gives the whole resource.
    pub start: u64,
    /// The size of the whole resource, when the server says it.
    pub total: Option<u64>,
    pub body: BoxStream<'static, Result<Vec<u8>, FetchError>>,
}

/// Where the bytes of a link come from.
pub trait Source: Send + Sync {
    /// Ask for `url` from the byte `from` (a `Range` when `from` is not 0).
    fn open(&self, url: &str, from: u64) -> BoxFuture<'static, Result<Opened, FetchError>>;
}

/// The space that a download leaves free on the phone, so that the phone keeps working:
/// 256 MiB.
pub const MIN_FREE: u64 = 256 * 1024 * 1024;

/// How a download reads the free space of a folder, in bytes: [`free_space`] (`statvfs`) in
/// the app. The tests give a fake one. `None`: not known, and then nothing is refused.
#[derive(Clone)]
pub struct FreeSpace(pub Arc<FreeSpaceFn>);

/// The function of a [`FreeSpace`].
pub type FreeSpaceFn = dyn Fn(&Path) -> Option<u64> + Send + Sync;

impl FreeSpace {
    pub fn of(&self, folder: &Path) -> Option<u64> {
        (self.0)(folder)
    }
}

impl Default for FreeSpace {
    fn default() -> Self {
        FreeSpace(Arc::new(free_space))
    }
}

impl std::fmt::Debug for FreeSpace {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("FreeSpace")
    }
}

/// The limits of a download.
#[derive(Debug, Clone)]
pub struct LinkOptions {
    /// The largest file, in bytes: a bad link must not fill the storage of the phone.
    pub max_bytes: u64,
    /// Take `http://` links (the user said yes to a warning).
    pub allow_http: bool,
    /// The tries of each request, the first one too.
    pub attempts: u32,
    /// The wait before the second try; it doubles at each try.
    pub backoff: Duration,
    /// A request that gives no byte for this long failed.
    pub idle: Duration,
    /// What the library keeps of the file. With [`Storage::Whole`] the download is whole on
    /// disk, it goes on from there if it stops, and it is the library file. With
    /// [`Storage::WithoutFilesystem`] the content of the blocks is never written: the check
    /// reads it as it arrives and throws it away, so the disk needs the space of the file
    /// that the library keeps, not the size of the service. A download that stops goes on
    /// from the last checkpoint ([`CHECKPOINT`]). `max_bytes` then limits the bytes that are
    /// written, not the bytes that arrive.
    pub storage: Storage,
    /// The space that must stay free after the download ([`MIN_FREE`]). Before it writes, a
    /// download checks that what it still writes, plus this, fits in the free space:
    ///
    /// - at each answer that says its size: a file (or the rest of it, when it goes on), a
    ///   chunk of a manifest when it starts;
    /// - again every [`room_every`](Self::room_every) bytes that arrive;
    /// - only this margin when the size of what is written is not known: no
    ///   `Content-Length`, or [`Storage::WithoutFilesystem`].
    ///
    /// [`max_bytes`](Self::max_bytes) is checked first.
    pub min_free: u64,
    /// How the free space is read.
    pub free_space: FreeSpace,
    /// The bytes that arrive between two checks of the free space during an answer:
    /// [`CHECKPOINT_EVERY`]. The tests make it small.
    pub room_every: u64,
}

impl Default for LinkOptions {
    fn default() -> Self {
        LinkOptions {
            max_bytes: 4 * 1024 * 1024 * 1024,
            allow_http: false,
            attempts: 5,
            backoff: Duration::from_secs(1),
            idle: Duration::from_secs(60),
            storage: Storage::Whole,
            min_free: MIN_FREE,
            free_space: FreeSpace::default(),
            room_every: CHECKPOINT_EVERY,
        }
    }
}

/// How far a download is. Clone it to share it.
#[derive(Debug, Clone, Default)]
pub struct LinkProgress {
    /// The chunk (from 1) and the number of chunks; 0 and 0 for a single file.
    chunk: Arc<AtomicU32>,
    chunks: Arc<AtomicU32>,
    /// The size of the file when known, else `u64::MAX`.
    total: Arc<AtomicU64>,
    /// The tries that failed and were tried again.
    retries: Arc<AtomicU32>,
}

impl LinkProgress {
    pub fn new() -> Self {
        let p = LinkProgress::default();
        p.total.store(u64::MAX, Ordering::Release);
        p
    }

    /// The chunk that downloads now (from 1), and the number of chunks. `(0, 0)` for a file.
    pub fn chunk(&self) -> (u32, u32) {
        (
            self.chunk.load(Ordering::Acquire),
            self.chunks.load(Ordering::Acquire),
        )
    }

    /// The size of the file, when the server said it (a single file).
    pub fn total(&self) -> Option<u64> {
        match self.total.load(Ordering::Acquire) {
            u64::MAX => None,
            t => Some(t),
        }
    }

    pub fn retries(&self) -> u32 {
        self.retries.load(Ordering::Acquire)
    }
}

/// A download that stopped and can go on.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Pending {
    pub url: String,
    /// The bytes on disk; for a download without the filesystem, the bytes that were read
    /// up to its last checkpoint.
    pub bytes: u64,
}

/// A downloaded, checked service, now in the library.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Downloaded {
    pub service_id: [u8; 32],
    /// The file in the library.
    pub path: PathBuf,
    /// The size of the file in the library, in bytes.
    pub bytes: u64,
    /// False if the library file has no content in the blocks of the Service
    /// ([`LinkOptions::storage`]).
    pub filesystem_kept: bool,
    pub layout: Layout,
    /// The number of chunks; 0 for a single file.
    pub chunks: u32,
    /// True if it went on from a download that stopped before.
    pub resumed: bool,
}

/// What is on disk for a download (`state.json`).
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
struct State {
    url: String,
    /// The links of the chunks; `None` for a single file, and before the app knows.
    chunks: Option<Vec<String>>,
    /// The end, in the file, of each chunk that is complete. With [`Storage::WithoutFilesystem`],
    /// the end in the bytes that arrived.
    done: Vec<u64>,
    /// True if the file on disk is the one without the content of the blocks, with its
    /// checkpoint.
    #[serde(default)]
    stripped: bool,
}

/// The folder of the downloads inside `dir`, a private directory of the app.
pub fn downloads_dir(dir: &Path) -> PathBuf {
    dir.join("packages").join("downloads")
}

fn key_of(url: &str) -> String {
    hex::encode(&Sha3_256::digest(url.as_bytes())[..8])
}

const STATE: &str = "state.json";
const PARTIAL: &str = "service.bee.partial";
/// The checkpoint of a download without the filesystem: where the bytes that arrived stop,
/// how long the file on disk is, and the state of the check.
const CHECKPOINT: &str = "check.state";
/// The bytes that arrive between two checkpoints of a download without the filesystem.
/// A download that stops goes on from the last one: it loses at most this much.
pub const CHECKPOINT_EVERY: u64 = 64 * 1024 * 1024;

/// A point of a download without the filesystem where it can go on.
#[derive(Debug, Clone)]
struct Checkpoint {
    /// The bytes of the download that the check read.
    pos: u64,
    /// The bytes of the file on disk at that point.
    file_len: u64,
    /// [`Check::snapshot`].
    check: Vec<u8>,
}

const CHECKPOINT_MAGIC: &[u8; 8] = b"CELCKP01";

impl Checkpoint {
    fn encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(24 + self.check.len());
        out.extend_from_slice(CHECKPOINT_MAGIC);
        out.extend_from_slice(&self.pos.to_be_bytes());
        out.extend_from_slice(&self.file_len.to_be_bytes());
        out.extend_from_slice(&self.check);
        out
    }

    fn decode(data: &[u8]) -> Option<Self> {
        let rest = data.strip_prefix(CHECKPOINT_MAGIC)?;
        let pos = u64::from_be_bytes(rest.get(..8)?.try_into().ok()?);
        let file_len = u64::from_be_bytes(rest.get(8..16)?.try_into().ok()?);
        Some(Checkpoint {
            pos,
            file_len,
            check: rest.get(16..)?.to_vec(),
        })
    }
}

fn read_checkpoint(folder: &Path) -> Option<Checkpoint> {
    Checkpoint::decode(&std::fs::read(folder.join(CHECKPOINT)).ok()?)
}

fn read_state(folder: &Path) -> Option<State> {
    serde_json::from_slice(&std::fs::read(folder.join(STATE)).ok()?).ok()
}

async fn write_state(folder: &Path, state: &State) -> Result<(), PackageError> {
    let tmp = folder.join("state.json.tmp");
    let text = serde_json::to_vec(state).map_err(|e| PackageError::Io(std::io::Error::other(e)))?;
    tokio::fs::write(&tmp, text).await?;
    tokio::fs::rename(&tmp, folder.join(STATE)).await?;
    Ok(())
}

/// The download that stopped, if any.
pub fn pending(dir: &Path) -> Option<Pending> {
    let entries = std::fs::read_dir(downloads_dir(dir)).ok()?;
    for entry in entries.flatten() {
        let folder = entry.path();
        if let Some(state) = read_state(&folder) {
            let bytes = if state.stripped {
                read_checkpoint(&folder).map_or(0, |c| c.pos)
            } else {
                std::fs::metadata(folder.join(PARTIAL))
                    .map(|m| m.len())
                    .unwrap_or(0)
            };
            return Some(Pending {
                url: state.url,
                bytes,
            });
        }
    }
    None
}

/// Delete the files of every download that stopped.
pub fn discard(dir: &Path) -> Result<(), PackageError> {
    match std::fs::remove_dir_all(downloads_dir(dir)) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e.into()),
    }
}

/// True for an error after which the download can go on from the disk: the network failed,
/// or the phone had no more free space ([`PackageError::NoSpace`]; its files are kept only
/// if it wrote bytes). The other errors delete the files.
pub fn can_resume(e: &PackageError) -> bool {
    matches!(e, PackageError::Network(_) | PackageError::NoSpace { .. })
}

/// Refuse with [`PackageError::NoSpace`] when `rest` (the bytes that the download still
/// writes, 0 when not known) and [`LinkOptions::min_free`] do not fit in the free space of
/// `folder`. An unknown free space passes.
fn ensure_room(options: &LinkOptions, folder: &Path, rest: u64) -> Result<(), PackageError> {
    let Some(available) = options.free_space.of(folder) else {
        return Ok(());
    };
    let needed = rest.saturating_add(options.min_free);
    if needed > available {
        return Err(PackageError::NoSpace { needed, available });
    }
    Ok(())
}

/// The error of a write to a full disk becomes [`PackageError::NoSpace`], the error of the
/// check, with `rest` as in [`ensure_room`].
fn full_disk(e: PackageError, options: &LinkOptions, folder: &Path, rest: u64) -> PackageError {
    match e {
        PackageError::Io(io) if is_disk_full(&io) => PackageError::NoSpace {
            needed: rest.saturating_add(options.min_free),
            available: options.free_space.of(folder).unwrap_or(0),
        },
        e => e,
    }
}

/// Download the service at `url` into `dir` (a private directory of the app), check it while
/// it arrives, and move it into the library. See the module. `cancel` counts the bytes on
/// disk and stops the download (its files are then deleted).
pub async fn download<S: Source + ?Sized>(
    source: &S,
    url: &str,
    dir: &Path,
    options: &LinkOptions,
    cancel: &Cancel,
    progress: &LinkProgress,
) -> Result<Downloaded, PackageError> {
    let url = url.trim();
    if check_url(url)? == Scheme::Http && !options.allow_http {
        return Err(PackageError::Invalid(
            "the link is http://, which is not encrypted".into(),
        ));
    }
    let downloads = downloads_dir(dir);
    let key = key_of(url);
    let folder = downloads.join(&key);
    // Only one download is kept: the files of another link go.
    if let Ok(entries) = std::fs::read_dir(&downloads) {
        for entry in entries.flatten() {
            if entry.file_name() != key.as_str() {
                let _ = std::fs::remove_dir_all(entry.path());
            }
        }
    }
    let result = run(source, url, dir, &folder, options, cancel, progress)
        .await
        .map_err(|e| full_disk(e, options, &downloads, 0));
    // A download that stopped is kept if it got something: bytes, or the list of a manifest.
    // Without free space, only bytes: a download refused before its first byte keeps nothing.
    let has_bytes = || {
        std::fs::metadata(folder.join(PARTIAL)).is_ok_and(|m| m.len() > 0)
            || read_checkpoint(&folder).is_some_and(|c| c.pos > 0)
    };
    let kept = match &result {
        Err(PackageError::NoSpace { .. }) => has_bytes(),
        Err(e) if can_resume(e) => {
            has_bytes()
                || read_checkpoint(&folder).is_some()
                || read_state(&folder).is_some_and(|s| s.chunks.is_some())
        }
        _ => false,
    };
    if !kept {
        let _ = tokio::fs::remove_dir_all(&folder).await;
    }
    result
}

/// The file on disk, written as the bytes arrive, with its check.
struct Sink {
    file: tokio::io::BufWriter<tokio::fs::File>,
    path: PathBuf,
    /// The bytes of the download that the check read. For a whole file, they are the bytes
    /// in the file (written or in the buffer).
    pos: u64,
    /// The bytes written to the file. They are the same as `pos` for a whole file.
    file_len: u64,
    check: Check,
    /// Set for a download without the filesystem.
    strip: Option<Stripped>,
    /// `pos` at the last check of the free space.
    room_at: u64,
}

/// What a download without the filesystem keeps to go on after a stop.
struct Stripped {
    folder: PathBuf,
    /// The last checkpoint, on disk too.
    last: Option<Checkpoint>,
    /// The checkpoint at the end of the last complete chunk: where a chunk starts again if
    /// the server does not take a Range.
    boundary: Option<Checkpoint>,
}

impl Sink {
    async fn open(path: PathBuf, strip: Option<PathBuf>) -> Result<Self, PackageError> {
        let file = tokio::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(&path)
            .await?;
        let check = if strip.is_some() { Check::stripping() } else { Check::new() };
        Ok(Sink {
            file: tokio::io::BufWriter::with_capacity(1024 * 1024, file),
            path,
            pos: 0,
            file_len: 0,
            check,
            strip: strip.map(|folder| Stripped {
                folder,
                last: None,
                boundary: None,
            }),
            room_at: 0,
        })
    }

    /// The folder of the download, where the free space is read.
    fn folder(&self) -> &Path {
        self.path.parent().unwrap_or(Path::new("."))
    }

    /// The bytes that count against the size limit: the ones that the library keeps.
    fn kept(&self) -> u64 {
        if self.strip.is_some() { self.file_len } else { self.pos }
    }

    /// Where a download without the filesystem goes on: the bytes of the download up to its
    /// last checkpoint on disk, 0 if there is none (the file on disk is then emptied).
    async fn load_checkpoint(&mut self) -> Result<u64, PackageError> {
        let Some(strip) = self.strip.as_mut() else {
            return Ok(0);
        };
        match read_checkpoint(&strip.folder) {
            Some(cp) => {
                let pos = cp.pos;
                strip.last = Some(cp);
                Ok(pos)
            }
            None => {
                self.file.flush().await?;
                let file = self.file.get_mut();
                file.set_len(0).await?;
                file.seek(std::io::SeekFrom::Start(0)).await?;
                Ok(0)
            }
        }
    }

    /// Keep the first `len` bytes of the download, and check them again: the check cannot
    /// go back. A whole file reads them once more from the disk (a local read, no download).
    /// A download without the filesystem goes back to a checkpoint: the start, or the
    /// checkpoint that is at `len`.
    async fn reset_to(&mut self, len: u64, cancel: &Cancel) -> Result<(), PackageError> {
        if self.strip.is_some() {
            return self.reset_to_checkpoint(len, cancel).await;
        }
        self.file.flush().await?;
        let file = self.file.get_mut();
        file.set_len(len).await?;
        file.seek(std::io::SeekFrom::Start(len)).await?;
        let mut check = Check::new();
        let mut reader = tokio::fs::File::open(&self.path).await?;
        let mut buf = vec![0u8; 1024 * 1024];
        let mut left = len;
        while left > 0 {
            if cancel.is_cancelled() {
                return Err(PackageError::Cancelled);
            }
            let want = buf.len().min(left as usize);
            let n = reader.read(&mut buf[..want]).await?;
            if n == 0 {
                return Err(PackageError::Invalid("the file on disk is shorter".into()));
            }
            check.feed(&buf[..n])?;
            left -= n as u64;
        }
        self.check = check;
        self.pos = len;
        self.file_len = len;
        cancel.set(len);
        Ok(())
    }

    async fn reset_to_checkpoint(&mut self, len: u64, cancel: &Cancel) -> Result<(), PackageError> {
        let strip = self.strip.as_ref().expect("a download without the filesystem");
        let (check, file_len) = if len == 0 {
            (Check::stripping(), 0)
        } else {
            let cp = [&strip.boundary, &strip.last]
                .into_iter()
                .flatten()
                .find(|cp| cp.pos == len)
                .ok_or_else(|| {
                    PackageError::Invalid(
                        "the download cannot go back to byte {len}: it goes on from a Range only"
                            .replace("{len}", &len.to_string()),
                    )
                })?;
            (Check::restore(&cp.check)?, cp.file_len)
        };
        self.file.flush().await?;
        let file = self.file.get_mut();
        if file.metadata().await?.len() < file_len {
            return Err(PackageError::Invalid("the file on disk is shorter".into()));
        }
        file.set_len(file_len).await?;
        file.seek(std::io::SeekFrom::Start(file_len)).await?;
        self.check = check;
        self.pos = len;
        self.file_len = file_len;
        cancel.set(len);
        // The checkpoint on disk is at this point now, not at a later one that was undone.
        self.checkpoint(false).await
    }

    async fn write(&mut self, data: &[u8], cancel: &Cancel) -> Result<(), PackageError> {
        if self.strip.is_none() {
            self.file.write_all(data).await?;
            self.pos += data.len() as u64;
            self.file_len = self.pos;
            cancel.set(self.pos);
            return self.check.feed(data);
        }
        // The check gives the bytes of the file that the library keeps; the rest is thrown
        // away as it is read.
        self.check.feed(data)?;
        let out = self.check.take_output();
        self.file.write_all(&out).await?;
        self.file_len += out.len() as u64;
        self.pos += data.len() as u64;
        cancel.set(self.pos);
        let last = self.strip.as_ref().and_then(|s| s.last.as_ref()).map_or(0, |cp| cp.pos);
        if self.pos.saturating_sub(last) >= CHECKPOINT_EVERY {
            self.checkpoint(false).await?;
        }
        Ok(())
    }

    /// Save the point where the download is, to go on from it if the app stops
    /// ([`Checkpoint`]): the file is on the disk up to there, and the state of the check is in
    /// `check.state`. `boundary`: the end of a chunk. Does nothing for a whole file.
    async fn checkpoint(&mut self, boundary: bool) -> Result<(), PackageError> {
        let Some(strip) = self.strip.as_mut() else {
            return Ok(());
        };
        self.file.flush().await?;
        self.file.get_mut().sync_data().await?;
        let cp = Checkpoint {
            pos: self.pos,
            file_len: self.file_len,
            check: self.check.snapshot(),
        };
        let tmp = strip.folder.join("check.state.tmp");
        tokio::fs::write(&tmp, cp.encode()).await?;
        tokio::fs::rename(&tmp, strip.folder.join(CHECKPOINT)).await?;
        if boundary {
            strip.boundary = Some(cp.clone());
        }
        strip.last = Some(cp);
        Ok(())
    }

    /// Keep what is on disk for a download that stops because the phone has no free space:
    /// the bytes in the buffer, and a checkpoint without the filesystem. With a full disk this
    /// can fail: the download then goes on from what did reach the disk.
    async fn keep(&mut self) {
        let _ = self.file.flush().await;
        let _ = self.checkpoint(false).await;
    }

    async fn sync(&mut self) -> Result<(), PackageError> {
        self.file.flush().await?;
        self.file.get_mut().sync_data().await?;
        Ok(())
    }
}

async fn run<S: Source + ?Sized>(
    source: &S,
    url: &str,
    dir: &Path,
    folder: &Path,
    options: &LinkOptions,
    cancel: &Cancel,
    progress: &LinkProgress,
) -> Result<Downloaded, PackageError> {
    tokio::fs::create_dir_all(folder).await?;
    let partial = folder.join(PARTIAL);
    let strip = options.storage == Storage::WithoutFilesystem;
    // What is on disk of the same link but of the other storage cannot go on.
    let saved = read_state(folder).filter(|s| s.url == url && s.stripped == strip);
    let resumed = saved.is_some();
    let mut state = saved.unwrap_or_else(|| State {
        url: url.to_string(),
        stripped: strip,
        ..State::default()
    });
    if !resumed {
        let _ = tokio::fs::remove_file(&partial).await;
        let _ = tokio::fs::remove_file(folder.join(CHECKPOINT)).await;
        write_state(folder, &state).await?;
    }
    let mut sink = Sink::open(partial.clone(), strip.then(|| folder.to_path_buf())).await?;
    // The bytes of the download that are safe on disk.
    let on_disk = if strip {
        sink.load_checkpoint().await?
    } else {
        tokio::fs::metadata(&partial).await?.len()
    };

    // A new download: the first answer says what the link gives.
    let mut first = None;
    if state.chunks.is_none() && on_disk == 0 {
        let (opened, head) = open_with_retry(source, url, 0, options, cancel, progress).await?;
        match head.first() {
            Some(0 | 1) | None => {
                // A service file (or nothing, which the check refuses).
                first = Some((opened, head));
            }
            Some(_) => {
                let links = read_manifest(opened, head, options, cancel).await?;
                state.chunks = Some(links);
            }
        }
        write_state(folder, &state).await?;
    }

    match state.chunks.clone() {
        None => {
            if on_disk > 0 {
                sink.reset_to(on_disk, cancel).await?;
            }
            fetch(source, url, 0, &mut sink, first, options, cancel, progress).await?;
        }
        Some(links) => {
            let count = links.len() as u32;
            progress.chunks.store(count, Ordering::Release);
            // The complete chunks that are on disk; the bytes after them are of the next one.
            state.done.retain(|end| *end <= on_disk);
            let start = state.done.last().copied().unwrap_or(0);
            let keep = if state.done.len() < links.len() { on_disk } else { start };
            if keep > 0 {
                sink.reset_to(keep, cancel).await?;
            }
            for (i, link) in links.iter().enumerate().skip(state.done.len()) {
                progress.chunk.store(i as u32 + 1, Ordering::Release);
                let chunk_start = state.done.last().copied().unwrap_or(0);
                fetch(source, link, chunk_start, &mut sink, None, options, cancel, progress)
                    .await?;
                sink.sync().await?;
                sink.checkpoint(true).await?;
                state.done.push(sink.pos);
                write_state(folder, &state).await?;
            }
        }
    }
    sink.sync().await?;
    let Sink { check, .. } = sink;
    let checked = check.finish()?;
    if let Some(want) = expected_id(url) {
        if want != checked.service_id {
            return Err(PackageError::Invalid(format!(
                "the link asks for the service {}, and the file is the service {}",
                hex::encode(want),
                hex::encode(checked.service_id)
            )));
        }
    }
    // The file is the one that the library keeps: the whole file, or the one that the check
    // wrote without the content of the blocks.
    let path = into_library_whole(&partial, dir, &checked.service_id).await?;
    let stored = tokio::fs::metadata(&path).await?.len();
    Ok(Downloaded {
        service_id: checked.service_id,
        path,
        bytes: stored,
        filesystem_kept: options.storage == Storage::Whole,
        layout: checked.layout,
        chunks: state.chunks.as_ref().map_or(0, |c| c.len() as u32),
        resumed,
    })
}

/// Read the whole manifest (at most [`MAX_MANIFEST`] bytes) and give its links.
async fn read_manifest(
    mut opened: Opened,
    mut text: Vec<u8>,
    options: &LinkOptions,
    cancel: &Cancel,
) -> Result<Vec<String>, PackageError> {
    if opened.total.is_some_and(|t| t > MAX_MANIFEST as u64) {
        return Err(neither("it is text, and too large for a list of links"));
    }
    loop {
        if text.len() > MAX_MANIFEST {
            return Err(neither("it is text, and too large for a list of links"));
        }
        match next_piece(&mut opened.body, options.idle, cancel).await? {
            Some(Ok(piece)) => text.extend_from_slice(&piece),
            Some(Err(FetchError::Retry(e) | FetchError::Fatal(e))) => {
                return Err(PackageError::Network(e))
            }
            None => break,
        }
    }
    parse_manifest(&text, options.allow_http)
}

/// The next piece of a body, a cancel, or no byte for `idle` (a retry).
async fn next_piece(
    body: &mut BoxStream<'static, Result<Vec<u8>, FetchError>>,
    idle: Duration,
    cancel: &Cancel,
) -> Result<Option<Result<Vec<u8>, FetchError>>, PackageError> {
    let deadline = tokio::time::Instant::now() + idle;
    loop {
        if cancel.is_cancelled() {
            return Err(PackageError::Cancelled);
        }
        let tick = tokio::time::sleep(Duration::from_millis(200));
        tokio::select! {
            item = body.next() => return Ok(item),
            _ = tick => {
                if tokio::time::Instant::now() >= deadline {
                    return Ok(Some(Err(FetchError::Retry(format!(
                        "no data for {} s",
                        idle.as_secs()
                    )))));
                }
            }
        }
    }
}

/// Sleep, unless the user cancels.
async fn wait(time: Duration, cancel: &Cancel) -> Result<(), PackageError> {
    let end = tokio::time::Instant::now() + time;
    while tokio::time::Instant::now() < end {
        if cancel.is_cancelled() {
            return Err(PackageError::Cancelled);
        }
        let left = end - tokio::time::Instant::now();
        tokio::time::sleep(left.min(Duration::from_millis(200))).await;
    }
    Ok(())
}

/// Open `url` from `from`, with the tries of [`LinkOptions`], and read its first bytes (at
/// least one, unless the body is empty).
async fn open_with_retry<S: Source + ?Sized>(
    source: &S,
    url: &str,
    from: u64,
    options: &LinkOptions,
    cancel: &Cancel,
    progress: &LinkProgress,
) -> Result<(Opened, Vec<u8>), PackageError> {
    let mut tries = 0;
    loop {
        tries += 1;
        match open_once(source, url, from, options, cancel).await? {
            Ok(opened) => return Ok(opened),
            Err(FetchError::Fatal(e)) => return Err(PackageError::Network(e)),
            Err(FetchError::Retry(e)) if tries >= options.attempts => {
                return Err(PackageError::Network(e))
            }
            Err(FetchError::Retry(_)) => {
                progress.retries.fetch_add(1, Ordering::AcqRel);
                wait(options.backoff * 2u32.pow(tries - 1), cancel).await?;
            }
        }
    }
}

/// One request, and its first bytes (none if the body is empty).
async fn open_once<S: Source + ?Sized>(
    source: &S,
    url: &str,
    from: u64,
    options: &LinkOptions,
    cancel: &Cancel,
) -> Result<Result<(Opened, Vec<u8>), FetchError>, PackageError> {
    Ok(match open(source, url, from, options, cancel).await? {
        Ok(mut opened) => match next_piece(&mut opened.body, options.idle, cancel).await? {
            Some(Ok(head)) => Ok((opened, head)),
            None => Ok((opened, Vec::new())),
            Some(Err(e)) => Err(e),
        },
        Err(e) => Err(e),
    })
}

/// One request, with a cancel and a time limit.
async fn open<S: Source + ?Sized>(
    source: &S,
    url: &str,
    from: u64,
    options: &LinkOptions,
    cancel: &Cancel,
) -> Result<Result<Opened, FetchError>, PackageError> {
    let mut request = source.open(url, from);
    let deadline = tokio::time::Instant::now() + options.idle;
    loop {
        if cancel.is_cancelled() {
            return Err(PackageError::Cancelled);
        }
        let tick = tokio::time::sleep(Duration::from_millis(200));
        tokio::select! {
            opened = &mut request => return Ok(opened),
            _ = tick => {
                if tokio::time::Instant::now() >= deadline {
                    return Ok(Err(FetchError::Retry(format!(
                        "no answer for {} s",
                        options.idle.as_secs()
                    ))));
                }
            }
        }
    }
}

/// Download one resource (the file, or one chunk) to the end of `sink`, where it starts at
/// `start`. A failed request is tried again from the byte where it stopped, if the server
/// takes a `Range`, and else from the start of the resource. `first` is an answer that is
/// already open (with its first bytes), for the start of the resource.
#[allow(clippy::too_many_arguments)]
async fn fetch<S: Source + ?Sized>(
    source: &S,
    url: &str,
    start: u64,
    sink: &mut Sink,
    mut first: Option<(Opened, Vec<u8>)>,
    options: &LinkOptions,
    cancel: &Cancel,
    progress: &LinkProgress,
) -> Result<(), PackageError> {
    let mut tries = 0u32;
    loop {
        tries += 1;
        let have = sink.pos - start;
        let error = 'attempt: {
            let (mut opened, head) = match first.take() {
                Some(open) => open,
                None => match open_once(source, url, have, options, cancel).await? {
                    Ok(open) => open,
                    Err(e) => break 'attempt e,
                },
            };
            if opened.start != have {
                if opened.start != 0 {
                    break 'attempt FetchError::Retry(format!(
                        "the server gave the bytes from {}, not from {have}",
                        opened.start
                    ));
                }
                // The server does not take a Range: the resource again, from its start.
                sink.reset_to(start, cancel).await?;
            }
            if let Some(total) = opened.total {
                if progress.chunks.load(Ordering::Acquire) == 0 {
                    progress.total.store(total, Ordering::Release);
                }
                // Without the filesystem the limit is on the bytes that are written.
                if sink.strip.is_none() && start + total > options.max_bytes {
                    return Err(PackageError::TooLarge(options.max_bytes));
                }
            }
            // The bytes of this resource that are still to write, when they are known: the
            // size that the answer says, less the bytes of it on disk.
            let total = opened.total;
            let rest = |sink: &Sink| match total {
                Some(total) if sink.strip.is_none() => total.saturating_sub(sink.pos - start),
                _ => 0,
            };
            if let Err(e) = ensure_room(options, sink.folder(), rest(sink)) {
                sink.keep().await;
                return Err(e);
            }
            sink.room_at = sink.pos;
            let mut piece = Some(head);
            loop {
                let data = match piece.take() {
                    Some(data) => data,
                    None => match next_piece(&mut opened.body, options.idle, cancel).await? {
                        Some(Ok(data)) => data,
                        Some(Err(e)) => break 'attempt e,
                        None => break,
                    },
                };
                if sink.kept() + data.len() as u64 > options.max_bytes {
                    return Err(PackageError::TooLarge(options.max_bytes));
                }
                if sink.pos.saturating_sub(sink.room_at) >= options.room_every {
                    if let Err(e) = ensure_room(options, sink.folder(), rest(sink)) {
                        sink.keep().await;
                        return Err(e);
                    }
                    sink.room_at = sink.pos;
                }
                let left = rest(sink);
                if let Err(e) = sink.write(&data, cancel).await {
                    let e = full_disk(e, options, sink.folder(), left);
                    if matches!(e, PackageError::NoSpace { .. }) {
                        sink.keep().await;
                    }
                    return Err(e);
                }
            }
            let got = sink.pos - start;
            match opened.total {
                Some(total) if got < total => FetchError::Retry(format!(
                    "the answer ended after {got} of {total} bytes"
                )),
                Some(total) if got > total => {
                    return Err(PackageError::Invalid(format!(
                        "the server gave {got} bytes, more than the {total} that it said"
                    )))
                }
                _ => return Ok(()),
            }
        };
        // The bytes so far stay on disk: the next try, or the next download of the link,
        // asks for the rest.
        sink.file.flush().await?;
        sink.checkpoint(false).await?;
        match error {
            FetchError::Fatal(e) => return Err(PackageError::Network(e)),
            FetchError::Retry(e) if tries >= options.attempts => {
                return Err(PackageError::Network(e))
            }
            FetchError::Retry(_) => {
                progress.retries.fetch_add(1, Ordering::AcqRel);
                wait(options.backoff * 2u32.pow(tries - 1), cancel).await?;
            }
        }
    }
}

/// [`MAX_RECORD`] is the reason why a service file starts with `0x00`.
const _: () = assert!(MAX_RECORD <= (1 << 24));

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_full_disk_gives_the_error_of_the_check() {
        let options = LinkOptions {
            min_free: 100,
            free_space: FreeSpace(Arc::new(|_| Some(7))),
            ..LinkOptions::default()
        };
        let full = PackageError::Io(std::io::Error::from(std::io::ErrorKind::StorageFull));
        let e = full_disk(full, &options, Path::new("/x"), 50);
        assert!(
            matches!(e, PackageError::NoSpace { needed: 150, available: 7 }),
            "{e}"
        );
        let quota = PackageError::Io(std::io::Error::from(std::io::ErrorKind::QuotaExceeded));
        assert!(matches!(
            full_disk(quota, &options, Path::new("/x"), 0),
            PackageError::NoSpace { needed: 100, .. }
        ));
        // Another error stays as it is.
        let other = PackageError::Io(std::io::Error::from(std::io::ErrorKind::PermissionDenied));
        assert!(matches!(full_disk(other, &options, Path::new("/x"), 0), PackageError::Io(_)));
        // The free space that the system does not say is 0 in the error.
        let unknown = LinkOptions {
            free_space: FreeSpace(Arc::new(|_| None)),
            ..options
        };
        let full = PackageError::Io(std::io::Error::from(std::io::ErrorKind::StorageFull));
        assert!(matches!(
            full_disk(full, &unknown, Path::new("/x"), 0),
            PackageError::NoSpace { available: 0, .. }
        ));
    }

    #[test]
    fn an_unknown_free_space_refuses_nothing() {
        let options = LinkOptions {
            free_space: FreeSpace(Arc::new(|_| None)),
            ..LinkOptions::default()
        };
        assert!(ensure_room(&options, Path::new("/x"), u64::MAX).is_ok());
    }

    #[cfg(unix)]
    #[test]
    fn the_free_space_of_the_phone_is_read() {
        let free = FreeSpace::default().of(&std::env::temp_dir());
        assert!(free.is_some_and(|f| f > 0), "{free:?}");
        assert_eq!(FreeSpace::default().of(Path::new("/no/such/folder/151")), None);
    }

    #[test]
    fn links_are_checked() {
        assert_eq!(check_url("https://example.org/a.celaut.bee").unwrap(), Scheme::Https);
        assert_eq!(check_url("HTTP://example.org/a").unwrap(), Scheme::Http);
        assert_eq!(check_url("https://user@host:8443/x?y#z").unwrap(), Scheme::Https);
        for bad in [
            "",
            "ftp://example.org/a",
            "file:///sdcard/a.celaut.bee",
            "content://x/y",
            "https://",
            "https:///path",
            "https://:443/x",
            "https://exa mple.org/a",
            "https://example.org/a\n",
            "example.org/a.celaut.bee",
        ] {
            assert!(check_url(bad).is_err(), "{bad:?}");
        }
        assert!(check_url(&format!("https://h/{}", "a".repeat(MAX_URL))).is_err());
    }

    #[test]
    fn the_fragment_can_name_the_service() {
        let id = "ab".repeat(32);
        assert_eq!(expected_id(&format!("https://h/x.celaut.bee#{id}")), Some([0xab; 32]));
        assert_eq!(expected_id("https://h/x.celaut.bee#top"), None);
        assert_eq!(expected_id("https://h/x.celaut.bee"), None);
        assert_eq!(expected_id(&format!("https://h/x#{}", "zz".repeat(32))), None);
    }

    #[test]
    fn the_name_comes_from_the_path() {
        assert_eq!(name_of("https://h/files/echo.celaut.bee"), "echo.celaut.bee");
        assert_eq!(name_of("https://h/files/echo.celaut.bee?x=1#ab"), "echo.celaut.bee");
        assert_eq!(name_of("https://h/files/echo.celaut.bee.txt"), "echo.celaut.bee");
        assert_eq!(name_of("https://h/files/My%20Echo.celaut.bee"), "My Echo.celaut.bee");
        assert_eq!(name_of("https://h/dir/"), "dir");
        assert_eq!(name_of("https://h"), "");
        assert_eq!(name_of("https://h/a%2"), "a%2");
    }

    #[test]
    fn a_manifest_is_text_with_one_link_per_line() {
        let text = "\u{feff}https://a/1\r\n\r\nhttps://a/2\n  https://b/3  \n";
        assert_eq!(
            parse_manifest(text.as_bytes(), false).unwrap(),
            vec!["https://a/1", "https://a/2", "https://b/3"]
        );
        assert!(parse_manifest(b"https://a/1\nhttp://a/2", false).is_err());
        assert_eq!(parse_manifest(b"https://a/1\nhttp://a/2", true).unwrap().len(), 2);
        assert!(parse_manifest(b"", false).is_err());
        assert!(parse_manifest(b"\n \n", false).is_err());
        assert!(parse_manifest(b"https://a/1\nnot a link", false).is_err());
        assert!(parse_manifest(&[0xff, 0xfe, 0x00], false).is_err());
        let many: String = (0..=MAX_CHUNKS).map(|i| format!("https://a/{i}\n")).collect();
        assert!(parse_manifest(many.as_bytes(), false).is_err());
    }
}
