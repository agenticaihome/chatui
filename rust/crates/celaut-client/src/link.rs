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

use crate::package::{into_library, Cancel, Check, Layout, PackageError, MAX_RECORD};

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
}

impl Default for LinkOptions {
    fn default() -> Self {
        LinkOptions {
            max_bytes: 4 * 1024 * 1024 * 1024,
            allow_http: false,
            attempts: 5,
            backoff: Duration::from_secs(1),
            idle: Duration::from_secs(60),
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
    /// The bytes on disk.
    pub bytes: u64,
}

/// A downloaded, checked service, now in the library.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Downloaded {
    pub service_id: [u8; 32],
    /// The file in the library.
    pub path: PathBuf,
    pub bytes: u64,
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
    /// The end, in the file, of each chunk that is complete.
    done: Vec<u64>,
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
            let bytes = std::fs::metadata(folder.join(PARTIAL))
                .map(|m| m.len())
                .unwrap_or(0);
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

/// True for an error after which the download can go on from the disk: the network failed.
/// The other errors delete the files.
pub fn can_resume(e: &PackageError) -> bool {
    matches!(e, PackageError::Network(_))
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
    let result = run(source, url, dir, &folder, options, cancel, progress).await;
    // A download that stopped is kept if it got something: bytes, or the list of a manifest.
    let worth = || {
        read_state(&folder).is_some_and(|s| s.chunks.is_some())
            || std::fs::metadata(folder.join(PARTIAL)).is_ok_and(|m| m.len() > 0)
    };
    match &result {
        Err(e) if can_resume(e) && worth() => {}
        _ => {
            let _ = tokio::fs::remove_dir_all(&folder).await;
        }
    }
    result
}

/// The file on disk, written as the bytes arrive, with its check.
struct Sink {
    file: tokio::io::BufWriter<tokio::fs::File>,
    path: PathBuf,
    /// The bytes in the file (written or in the buffer).
    pos: u64,
    check: Check,
}

impl Sink {
    async fn open(path: PathBuf) -> Result<Self, PackageError> {
        let file = tokio::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(&path)
            .await?;
        Ok(Sink {
            file: tokio::io::BufWriter::with_capacity(1024 * 1024, file),
            path,
            pos: 0,
            check: Check::new(),
        })
    }

    /// Keep the first `len` bytes of the file, and check them again from the disk: the check
    /// cannot go back, so it reads them once more (a local read, no download).
    async fn reset_to(&mut self, len: u64, cancel: &Cancel) -> Result<(), PackageError> {
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
        cancel.set(len);
        Ok(())
    }

    async fn write(&mut self, data: &[u8], cancel: &Cancel) -> Result<(), PackageError> {
        self.file.write_all(data).await?;
        self.pos += data.len() as u64;
        cancel.set(self.pos);
        self.check.feed(data)
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
    let saved = read_state(folder).filter(|s| s.url == url);
    let resumed = saved.is_some();
    let mut state = saved.unwrap_or_else(|| State {
        url: url.to_string(),
        ..State::default()
    });
    if !resumed {
        let _ = tokio::fs::remove_file(&partial).await;
        write_state(folder, &state).await?;
    }
    let mut sink = Sink::open(partial.clone()).await?;
    let on_disk = tokio::fs::metadata(&partial).await?.len();

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
                state.done.push(sink.pos);
                write_state(folder, &state).await?;
            }
        }
    }
    sink.sync().await?;
    let Sink { check, pos, .. } = sink;
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
    let path = into_library(&partial, dir, &checked.service_id).await?;
    Ok(Downloaded {
        service_id: checked.service_id,
        path,
        bytes: pos,
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
                if start + total > options.max_bytes {
                    return Err(PackageError::TooLarge(options.max_bytes));
                }
            }
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
                if sink.pos + data.len() as u64 > options.max_bytes {
                    return Err(PackageError::TooLarge(options.max_bytes));
                }
                sink.write(&data, cancel).await?;
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
