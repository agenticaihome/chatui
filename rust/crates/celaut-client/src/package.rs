//! A service as a package: the Buffers that give it to a node that does not have it
//! (`docs/celaut/package.md`).
//!
//! A node takes a service in `StartService` or `GetServiceEstimatedCost`: the hashes
//! (index 4), the Metadata (index 5) and the Service (index 6), with the blocks of the
//! Service. The app gets these Buffers from `GetService` of another node, or from a
//! `.celaut.bee` file that `nodo export` wrote. Both can be large, so this module moves
//! them as a stream, one Buffer at a time, and keeps them in a `.bee` file on the
//! phone, never in memory:
//!
//! - [`save`] writes the Buffers of `GetService` to a `.bee` file.
//! - [`inspect`] reads the head of a `.bee` file: its layout, and the service id from
//!   the Metadata or from a hash part. It stops before the Service.
//! - [`check_file`] checks a `.bee` file with [`Check`]: each block hashes to its id, and
//!   the whole Service hashes to the service id.
//! - [`read`] gives the Buffers of a `.bee` file for a node: the head indices of a
//!   `nodo export` file (1 Metadata, 2 Service) become 5 and 6.
//! - [`strip_filesystem`] copies a `.bee` file, checking it, without the content of the blocks of
//!   its Service (the filesystem of the container), to save space in the library.
//! - [`import_reader`] loads a package from any reader, and [`Check::stripping`] with
//!   [`Check::snapshot`] and [`Check::restore`] make the load of a service of any size need
//!   only the space of the small file: the content of the blocks is hashed and not written,
//!   and a download that stops goes on from a saved state of the check ([`crate::link`]).
//!
//! A [`Cancel`] stops a transfer: the stream gives an error, and the node gets markers
//! that make it refuse the cut input (`bee_rpc::grpc::call_buffers`).

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;

use bee_rpc::buffer::Buffer;
use celaut_proto::celaut::metadata::hash_tag::Hash;
use celaut_proto::celaut::Metadata;
use celaut_wire::gateway::SHA3_256_TYPE;
use celaut_wire::{Buffers, WireError};
use prost::Message;
use sha3_state::digest::common::hazmat::SerializableState;
use sha3_state::{Digest, Sha3_256 as Sha3};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWriteExt, BufReader, BufWriter};

/// The longest record that a `.bee` file can have here. A Buffer carries at most one
/// chunk of 1 MiB; this leaves room, and refuses a false length before it allocates.
pub const MAX_RECORD: u32 = 16 * 1024 * 1024;

/// The space that the app can use on the disk of `path`, in bytes (`statvfs`: the blocks
/// free for a user that is not root × their size). `None` when the system does not say.
pub fn free_space(path: &Path) -> Option<u64> {
    #[cfg(unix)]
    {
        let s = rustix::fs::statvfs(path).ok()?;
        Some(s.f_bavail.saturating_mul(s.f_frsize))
    }
    #[cfg(not(unix))]
    {
        let _ = path;
        None
    }
}

/// True for the error of a write to a full disk.
pub fn is_disk_full(e: &std::io::Error) -> bool {
    matches!(
        e.kind(),
        std::io::ErrorKind::StorageFull | std::io::ErrorKind::QuotaExceeded
    )
}

/// Why a package cannot be used.
#[derive(Debug, thiserror::Error)]
pub enum PackageError {
    /// A file error.
    #[error("the package file: {0}")]
    Io(#[from] std::io::Error),
    /// The file is not a `.bee` file of a service.
    #[error("the package is not valid: {0}")]
    Invalid(String),
    /// The transfer was cancelled.
    #[error("the transfer was cancelled")]
    Cancelled,
    /// A download failed after its tries (no connection, a server error, a cut answer). It
    /// can go on from the bytes on disk ([`crate::link`]).
    #[error("the download failed: {0}")]
    Network(String),
    /// A download is larger than the limit, in bytes.
    #[error("the file is larger than the limit of {0} bytes")]
    TooLarge(u64),
    /// The phone has not enough free space for what a download still writes, plus the
    /// space that must stay free ([`crate::link::LinkOptions::min_free`]). `needed` counts
    /// both; `available` is the space that the app can use now, in bytes.
    #[error("not enough free space: {needed} bytes are needed and {available} are free")]
    NoSpace { needed: u64, available: u64 },
    /// The node gave an error.
    #[error(transparent)]
    Wire(#[from] WireError),
}

/// The indices of the parts of a package.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Layout {
    /// The indices of `StartService` and of the answer of `GetService`: 4 hashes, 5
    /// Metadata, 6 Service.
    Gateway,
    /// The indices of `nodo export`: 1 Metadata, 2 Service.
    NodoExport,
}

impl Layout {
    /// The index of the Metadata and of the Service.
    fn indices(self) -> (i32, i32) {
        match self {
            Layout::Gateway => (5, 6),
            Layout::NodoExport => (1, 2),
        }
    }

    /// The index for a node of a head index of this layout.
    fn for_node(self, index: i32) -> i32 {
        match (self, index) {
            (Layout::NodoExport, 1) => 5,
            (Layout::NodoExport, 2) => 6,
            (_, other) => other,
        }
    }
}

/// What the head of a package says.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackageInfo {
    pub layout: Layout,
    /// The size of the file, in bytes.
    pub bytes: u64,
    /// The id of the service (SHA3-256), from the Metadata or a hash part. `None` if the
    /// package does not say it.
    pub service_id: Option<[u8; 32]>,
    /// The main name of the service for a person: the first tag of the Metadata. `None`
    /// if the Metadata has no tag.
    pub tag: Option<String>,
    /// True if a Service part starts in the package.
    pub has_service: bool,
}

/// Stops a transfer, and counts its bytes. Clone it to share it.
#[derive(Debug, Clone, Default)]
pub struct Cancel {
    cancelled: Arc<AtomicBool>,
    bytes: Arc<AtomicU64>,
}

impl Cancel {
    pub fn new() -> Self {
        Cancel::default()
    }

    /// Stop the transfer: the next Buffer is an error.
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Acquire)
    }

    /// The bytes that the transfer moved so far: the records of the `.bee` file that
    /// [`save`] wrote, or that the call took from [`read`].
    pub fn bytes(&self) -> u64 {
        self.bytes.load(Ordering::Acquire)
    }

    /// Set the bytes so far (a download: the bytes on disk).
    pub fn set(&self, n: u64) {
        self.bytes.store(n, Ordering::Release);
    }

    fn add(&self, n: u64) {
        self.bytes.fetch_add(n, Ordering::AcqRel);
    }
}

/// A Buffer with no data for a package: a flow control signal or a skip request of the
/// sender. They are for the call that carried them, not for the next node.
fn is_control_only(b: &Buffer) -> bool {
    b.chunk.is_none() && b.head.is_none() && b.block.is_none() && b.separator != Some(true)
}

/// Write the Buffers of `input` to a `.bee` file at `path`. The file is written next to
/// `path` and renamed when it is complete, so `path` never holds a cut package. Gives
/// the number of bytes.
pub async fn save(mut input: Buffers, path: &Path, cancel: &Cancel) -> Result<u64, PackageError> {
    use tokio_stream::StreamExt;
    let partial = partial_path(path);
    let result = async {
        let file = tokio::fs::File::create(&partial).await?;
        let mut writer = BufWriter::new(file);
        let mut total = 0u64;
        while let Some(item) = input.next().await {
            if cancel.is_cancelled() {
                return Err(PackageError::Cancelled);
            }
            let mut buffer = item?;
            if is_control_only(&buffer) {
                continue;
            }
            // A signal is for the call that carried it.
            buffer.signal = None;
            buffer.skip = None;
            let record = buffer.encode_to_vec();
            let len = u32::try_from(record.len())
                .ok()
                .filter(|l| *l <= MAX_RECORD)
                .ok_or_else(|| PackageError::Invalid("a Buffer is too large".into()))?;
            writer.write_u32(len).await?;
            writer.write_all(&record).await?;
            let n = 4 + u64::from(len);
            total += n;
            cancel.add(n);
        }
        writer.flush().await?;
        Ok(total)
    }
    .await;
    match result {
        Ok(total) if total > 0 => {
            tokio::fs::rename(&partial, path).await?;
            Ok(total)
        }
        Ok(_) => {
            let _ = tokio::fs::remove_file(&partial).await;
            Err(PackageError::Invalid("the node gave nothing: it does not have the service".into()))
        }
        Err(e) => {
            let _ = tokio::fs::remove_file(&partial).await;
            Err(e)
        }
    }
}

fn partial_path(path: &Path) -> PathBuf {
    let mut name = path.file_name().map(|n| n.to_os_string()).unwrap_or_default();
    name.push(".partial");
    path.with_file_name(name)
}

/// One record of a `.bee` file, or `None` at a clean end.
async fn next_record<R: tokio::io::AsyncRead + Unpin>(
    reader: &mut R,
) -> Result<Option<Buffer>, PackageError> {
    // A clean end has no byte of a new record. One to three bytes are a cut length.
    let mut prefix = [0u8; 4];
    let mut got = 0;
    while got < prefix.len() {
        let n = reader.read(&mut prefix[got..]).await?;
        if n == 0 {
            break;
        }
        got += n;
    }
    match got {
        0 => return Ok(None),
        4 => {}
        _ => return Err(PackageError::Invalid("the file is cut".into())),
    }
    let len = u32::from_be_bytes(prefix);
    if len > MAX_RECORD {
        return Err(PackageError::Invalid(format!("a record of {len} bytes")));
    }
    let mut record = vec![0u8; len as usize];
    reader.read_exact(&mut record).await.map_err(|e| {
        if e.kind() == std::io::ErrorKind::UnexpectedEof {
            PackageError::Invalid("the file is cut".into())
        } else {
            e.into()
        }
    })?;
    Buffer::decode(record.as_slice())
        .map(Some)
        .map_err(|e| PackageError::Invalid(format!("a record is not a Buffer: {e}")))
}

/// The id of the service in a Metadata: its SHA3-256 hash.
fn id_in_metadata(metadata: &Metadata) -> Option<[u8; 32]> {
    metadata
        .hashtag
        .as_ref()?
        .hash
        .iter()
        .find_map(id_in_hash)
}

/// The main name in a Metadata: its first tag that is not empty.
fn tag_in_metadata(metadata: &Metadata) -> Option<String> {
    metadata
        .hashtag
        .as_ref()?
        .tag
        .iter()
        .map(|t| t.trim())
        .find(|t| !t.is_empty())
        .map(str::to_string)
}

fn id_in_hash(hash: &Hash) -> Option<[u8; 32]> {
    (hash.r#type == SHA3_256_TYPE).then(|| hash.value.as_slice().try_into().ok())?
}

/// Read the head of the package at `path`: its layout and the id of its service. It
/// reads until the Service part starts, so it does not read the Service.
pub async fn inspect(path: &Path) -> Result<PackageInfo, PackageError> {
    let file = tokio::fs::File::open(path).await?;
    let bytes = file.metadata().await?.len();
    let mut reader = BufReader::new(file);
    let mut layout = None;
    let mut service_id = None;
    let mut tag = None;
    let mut has_service = false;
    // The message that is open: its index and its bytes (only small parts are kept).
    let mut open: Option<(i32, Vec<u8>)> = None;
    while let Some(buffer) = next_record(&mut reader).await? {
        if let Some(head) = &buffer.head {
            if open.is_none() {
                let index = head.index;
                let detected = *layout.get_or_insert(match index {
                    1 | 2 => Layout::NodoExport,
                    _ => Layout::Gateway,
                });
                let (_, service_index) = detected.indices();
                if index == service_index {
                    has_service = true;
                    break;
                }
                open = Some((index, Vec::new()));
            }
        }
        if let Some((_, data)) = open.as_mut() {
            if buffer.block.is_some() {
                return Err(PackageError::Invalid("a block before the Service".into()));
            }
            if let Some(chunk) = &buffer.chunk {
                data.extend_from_slice(chunk);
                if data.len() > MAX_RECORD as usize {
                    return Err(PackageError::Invalid("a part before the Service is too large".into()));
                }
            }
        }
        if buffer.separator == Some(true) {
            if let (Some((index, data)), Some(l)) = (open.take(), layout) {
                let (metadata_index, _) = l.indices();
                if index == metadata_index {
                    let metadata = Metadata::decode(data.as_slice())
                        .map_err(|e| PackageError::Invalid(format!("the Metadata: {e}")))?;
                    service_id = service_id.or(id_in_metadata(&metadata));
                    tag = tag.or(tag_in_metadata(&metadata));
                } else if index == 4 {
                    if let Ok(hash) = Hash::decode(data.as_slice()) {
                        service_id = service_id.or(id_in_hash(&hash));
                    }
                }
            }
        }
    }
    let layout = layout.ok_or_else(|| PackageError::Invalid("the file is empty".into()))?;
    Ok(PackageInfo {
        layout,
        bytes,
        service_id,
        tag,
        has_service,
    })
}

/// Check the package at `path` with [`Check`], as a download is checked: each block holds
/// what its id names, and the whole Service hashes to the id of the service that the file
/// gives. The file is read once, in pieces; [`Check`] keeps at most one record in memory.
/// `cancel` counts the bytes that were read, and stops the check when it is cancelled.
pub async fn check_file(path: &Path, cancel: &Cancel) -> Result<Checked, PackageError> {
    let mut file = tokio::fs::File::open(path).await?;
    let mut check = Check::new();
    let mut piece = vec![0u8; 256 * 1024];
    loop {
        if cancel.is_cancelled() {
            return Err(PackageError::Cancelled);
        }
        let n = file.read(&mut piece).await?;
        if n == 0 {
            break;
        }
        check.feed(&piece[..n])?;
        cancel.add(n as u64);
    }
    check.finish()
}

/// The Buffers of the package at `path` for a node, with the indices of `StartService`.
/// The file is read while the Buffers are sent. An error of the file, or a cancel, is
/// an error of the stream (the node then refuses the input). `cancel` counts a record
/// when the call takes it, not when the file gives it: a call that stops early (the node
/// has the service) does not count the records that were read ahead.
pub fn read(path: PathBuf, layout: Layout, cancel: Cancel) -> Buffers {
    use tokio_stream::StreamExt;
    let (tx, rx) = tokio::sync::mpsc::channel::<Result<Buffer, WireError>>(4);
    let counter = cancel.clone();
    tokio::spawn(async move {
        let failed = |e: PackageError| Err(WireError::Relay(e.to_string()));
        let file = match tokio::fs::File::open(&path).await {
            Ok(file) => file,
            Err(e) => {
                let _ = tx.send(failed(e.into())).await;
                return;
            }
        };
        let mut reader = BufReader::new(file);
        loop {
            if cancel.is_cancelled() {
                let _ = tx.send(failed(PackageError::Cancelled)).await;
                return;
            }
            let item = match next_record(&mut reader).await {
                Ok(Some(mut buffer)) => {
                    if let Some(head) = buffer.head.as_mut() {
                        head.index = layout.for_node(head.index);
                    }
                    Ok(buffer)
                }
                Ok(None) => return,
                Err(e) => failed(e),
            };
            let stop = item.is_err();
            if tx.send(item).await.is_err() || stop {
                return;
            }
        }
    });
    Box::pin(
        tokio_stream::wrappers::ReceiverStream::new(rx).map(move |item| {
            if let Ok(buffer) = &item {
                counter.add(4 + buffer.encoded_len() as u64);
            }
            item
        }),
    )
}

/// The check of a package while its bytes arrive (a download, issue #135). Give it the
/// bytes of the file in order ([`Check::feed`]), in pieces of any size; it keeps at most one
/// record in memory. It checks what [`import`] checks, and more:
///
/// - each record is a Buffer of at most [`MAX_RECORD`] bytes;
/// - each block holds what its id names;
/// - the **whole Service** hashes (SHA3-256) to the id of the service that the Metadata or
///   a hash part gives. The id of a service is the hash of its content with its blocks in
///   place, which is the bytes of the chunks of the Service part in order (nodo
///   `zip_with_dockerfile`: the digest of `read_multiblock_directory`).
///
/// A downloaded file is not trusted: only this check makes it valid. [`Check::finish`] says
/// if the file was complete and valid.
#[derive(Default)]
pub struct Check {
    /// The bytes of the record that is not complete yet (its length prefix too).
    record: Vec<u8>,
    layout: Option<Layout>,
    /// The part that is open: its index.
    part: Option<i32>,
    /// The bytes of a small part (the Metadata or a hash), to read the id in it.
    small: Vec<u8>,
    service_id: Option<[u8; 32]>,
    /// The hash of the Service part while it arrives, then its digest.
    service: Option<Sha3>,
    service_hash: Option<[u8; 32]>,
    blocks: Vec<([u8; 32], Sha3)>,
    bytes: u64,
    /// True if the check also writes the file without the content of the blocks of the
    /// Service ([`Check::stripping`]).
    strip: bool,
    /// The records of that file that are not taken yet ([`Check::take_output`]).
    out: Vec<u8>,
}

impl std::fmt::Debug for Check {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Check")
            .field("bytes", &self.bytes)
            .field("part", &self.part)
            .field("open_blocks", &self.blocks.len())
            .finish()
    }
}

/// What [`Check::finish`] found in a complete, valid package.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Checked {
    pub service_id: [u8; 32],
    pub layout: Layout,
    /// The size of the file, in bytes.
    pub bytes: u64,
}

impl Check {
    pub fn new() -> Self {
        Check::default()
    }

    /// A check that also writes the file without the content of the blocks of the Service
    /// (`docs/celaut/package.md`, "Without the filesystem"). Of each top-level block the
    /// file keeps the two markers, the one that opens it and the one that ends it, and
    /// nothing between them: no chunk and no marker of a block inside. The rest of the
    /// records are as they are, so [`inspect`] and the reader of the service information
    /// (`service_info`) read it as before. After each [`Check::feed`], [`Check::take_output`]
    /// gives the bytes to append to that file. Those bytes are only good when
    /// [`Check::finish`] says that the package is valid: a file with a false block is
    /// deleted, and a cut file is not a library file.
    pub fn stripping() -> Self {
        Check {
            strip: true,
            ..Check::default()
        }
    }

    /// The bytes of the file without the content of the blocks that the last calls of
    /// [`Check::feed`] made, and nothing more. Empty if the check does not strip.
    pub fn take_output(&mut self) -> Vec<u8> {
        std::mem::take(&mut self.out)
    }

    /// The state of the check, to go on from it later ([`Check::restore`]): the bytes of
    /// the record that is not complete, the hashes, and the blocks that are open. It is at
    /// most one record and a few hundred bytes for each open block. Call it after
    /// [`Check::take_output`]: the output that is not taken is not in it.
    pub fn snapshot(&self) -> Vec<u8> {
        let mut e = Encoder::default();
        e.u8(SNAPSHOT_VERSION);
        e.u64(self.bytes);
        e.u8(u8::from(self.strip));
        e.bytes(&self.record);
        e.u8(match self.layout {
            None => 0,
            Some(Layout::Gateway) => 1,
            Some(Layout::NodoExport) => 2,
        });
        match self.part {
            None => e.u8(0),
            Some(index) => {
                e.u8(1);
                e.u32(index as u32);
            }
        }
        e.bytes(&self.small);
        e.option_id(self.service_id);
        match &self.service {
            None => e.u8(0),
            Some(hasher) => {
                e.u8(1);
                e.raw(hasher.serialize().as_slice());
            }
        }
        e.option_id(self.service_hash);
        e.u32(self.blocks.len() as u32);
        for (id, hasher) in &self.blocks {
            e.raw(id);
            e.raw(hasher.serialize().as_slice());
        }
        e.finish()
    }

    /// The check as [`Check::snapshot`] left it. An error if the bytes are not a snapshot.
    pub fn restore(data: &[u8]) -> Result<Self, PackageError> {
        let bad = || PackageError::Invalid("the saved state of the check is not valid".into());
        let mut d = Decoder::new(data);
        if d.u8().ok_or_else(bad)? != SNAPSHOT_VERSION {
            return Err(bad());
        }
        let bytes = d.u64().ok_or_else(bad)?;
        let strip = d.u8().ok_or_else(bad)? == 1;
        let record = d.bytes().ok_or_else(bad)?.to_vec();
        let layout = match d.u8().ok_or_else(bad)? {
            0 => None,
            1 => Some(Layout::Gateway),
            2 => Some(Layout::NodoExport),
            _ => return Err(bad()),
        };
        let part = match d.u8().ok_or_else(bad)? {
            0 => None,
            1 => Some(d.u32().ok_or_else(bad)? as i32),
            _ => return Err(bad()),
        };
        let small = d.bytes().ok_or_else(bad)?.to_vec();
        let service_id = d.option_id().ok_or_else(bad)?;
        let service = match d.u8().ok_or_else(bad)? {
            0 => None,
            1 => Some(d.hasher().ok_or_else(bad)?),
            _ => return Err(bad()),
        };
        let service_hash = d.option_id().ok_or_else(bad)?;
        let count = d.u32().ok_or_else(bad)? as usize;
        let mut blocks = Vec::new();
        for _ in 0..count {
            let id = d.id().ok_or_else(bad)?;
            blocks.push((id, d.hasher().ok_or_else(bad)?));
        }
        if !d.done() || record.len() > 4 + MAX_RECORD as usize {
            return Err(bad());
        }
        Ok(Check {
            record,
            layout,
            part,
            small,
            service_id,
            service,
            service_hash,
            blocks,
            bytes,
            strip,
            out: Vec::new(),
        })
    }

    /// The bytes that the check got so far.
    pub fn bytes(&self) -> u64 {
        self.bytes
    }

    /// The next bytes of the file. An error as soon as they show that the file is not a valid
    /// package.
    pub fn feed(&mut self, mut data: &[u8]) -> Result<(), PackageError> {
        self.bytes += data.len() as u64;
        while !data.is_empty() {
            if self.record.len() < 4 {
                let take = (4 - self.record.len()).min(data.len());
                self.record.extend_from_slice(&data[..take]);
                data = &data[take..];
                if self.record.len() == 4 && self.length() > MAX_RECORD {
                    return Err(PackageError::Invalid(format!(
                        "a record of {} bytes",
                        self.length()
                    )));
                }
                continue;
            }
            let want = 4 + self.length() as usize;
            let take = (want - self.record.len()).min(data.len());
            self.record.extend_from_slice(&data[..take]);
            data = &data[take..];
            if self.record.len() == want {
                let buffer = Buffer::decode(&self.record[4..])
                    .map_err(|e| PackageError::Invalid(format!("a record is not a Buffer: {e}")))?;
                self.record.clear();
                self.take(buffer)?;
            }
        }
        Ok(())
    }

    fn length(&self) -> u32 {
        u32::from_be_bytes([self.record[0], self.record[1], self.record[2], self.record[3]])
    }

    fn take(&mut self, buffer: Buffer) -> Result<(), PackageError> {
        if let Some(head) = &buffer.head {
            if self.part.is_none() {
                let index = head.index;
                let layout = *self.layout.get_or_insert(match index {
                    1 | 2 => Layout::NodoExport,
                    _ => Layout::Gateway,
                });
                if index == layout.indices().1 {
                    if self.service.is_some() || self.service_hash.is_some() {
                        return Err(PackageError::Invalid("two Service parts".into()));
                    }
                    self.service = Some(Sha3::new());
                }
                self.part = Some(index);
                self.small.clear();
            }
        }
        // For the file without the content of the blocks: whether the record is kept, and
        // whether its chunk goes (the bytes that come with the marker that opens a top-level
        // block are in the block).
        let mut keep = self.blocks.is_empty();
        let mut drop_chunk = false;
        if let Some(block) = &buffer.block {
            if self.service.is_none() {
                return Err(PackageError::Invalid("a block outside of the Service".into()));
            }
            let id = block
                .hashes
                .iter()
                .find_map(|h| {
                    (h.r#type == SHA3_256_TYPE).then(|| h.value.as_slice().try_into().ok())?
                })
                .ok_or_else(|| PackageError::Invalid("a block has no SHA3-256 id".into()))?;
            if let Some((_, hasher)) = self.blocks.pop_if(|(last, _)| *last == id) {
                // The marker that ends a top-level block stays; one of a block inside goes.
                keep = self.blocks.is_empty();
                let got = hasher.finalize();
                if got.as_slice() != id {
                    return Err(PackageError::Invalid(format!(
                        "the block {} holds other bytes: they hash to {}",
                        hex::encode(id),
                        hex::encode(got)
                    )));
                }
            } else if self.blocks.iter().any(|(other, _)| *other == id) {
                return Err(PackageError::Invalid(format!(
                    "the block {} ends inside a block that it holds",
                    hex::encode(id)
                )));
            } else {
                self.blocks.push((id, Sha3::new()));
                keep = self.blocks.len() == 1;
                drop_chunk = keep;
            }
        }
        if let Some(chunk) = &buffer.chunk {
            if self.part.is_none() {
                return Err(PackageError::Invalid("bytes outside of a part".into()));
            }
            for (_, hasher) in self.blocks.iter_mut() {
                hasher.update(chunk);
            }
            match self.service.as_mut() {
                Some(hasher) => hasher.update(chunk),
                None => {
                    self.small.extend_from_slice(chunk);
                    if self.small.len() > MAX_RECORD as usize {
                        return Err(PackageError::Invalid(
                            "a part before the Service is too large".into(),
                        ));
                    }
                }
            }
        }
        if buffer.separator == Some(true) {
            self.close_part()?;
        }
        if self.strip && keep {
            let mut buffer = buffer;
            if drop_chunk {
                buffer.chunk = None;
            }
            let record = buffer.encode_to_vec();
            let len = u32::try_from(record.len())
                .ok()
                .filter(|l| *l <= MAX_RECORD)
                .ok_or_else(|| PackageError::Invalid("a Buffer is too large".into()))?;
            self.out.extend_from_slice(&len.to_be_bytes());
            self.out.extend_from_slice(&record);
        }
        Ok(())
    }

    fn close_part(&mut self) -> Result<(), PackageError> {
        let (Some(index), Some(layout)) = (self.part.take(), self.layout) else {
            return Ok(());
        };
        if let Some(hasher) = self.service.take() {
            if let Some((id, _)) = self.blocks.last() {
                return Err(PackageError::Invalid(format!(
                    "the Service ends inside the block {}",
                    hex::encode(id)
                )));
            }
            self.service_hash = hasher.finalize().as_slice().try_into().ok();
            return Ok(());
        }
        let data = std::mem::take(&mut self.small);
        if index == layout.indices().0 {
            let metadata = Metadata::decode(data.as_slice())
                .map_err(|e| PackageError::Invalid(format!("the Metadata: {e}")))?;
            self.service_id = self.service_id.or(id_in_metadata(&metadata));
        } else if index == 4 {
            if let Ok(hash) = Hash::decode(data.as_slice()) {
                self.service_id = self.service_id.or(id_in_hash(&hash));
            }
        }
        Ok(())
    }

    /// The end of the file: it must be complete, have a Service part, say which service it
    /// is, and the Service must hash to that id.
    pub fn finish(mut self) -> Result<Checked, PackageError> {
        if !self.record.is_empty() {
            return Err(PackageError::Invalid("the file is cut".into()));
        }
        if let Some((id, _)) = self.blocks.last() {
            return Err(PackageError::Invalid(format!(
                "the file is cut inside the block {}",
                hex::encode(id)
            )));
        }
        // A Service at the end of the file with no separator is complete too.
        if self.service.is_some() {
            self.close_part()?;
        }
        let layout = self
            .layout
            .ok_or_else(|| PackageError::Invalid("the file is empty".into()))?;
        let got = self
            .service_hash
            .ok_or_else(|| PackageError::Invalid("the file has no Service part".into()))?;
        let service_id = self.service_id.ok_or_else(|| {
            PackageError::Invalid("the file does not say which service it is".into())
        })?;
        if got != service_id {
            return Err(PackageError::Invalid(format!(
                "the Service hashes to {}, not to the id {} that the file gives",
                hex::encode(got),
                hex::encode(service_id)
            )));
        }
        Ok(Checked {
            service_id,
            layout,
            bytes: self.bytes,
        })
    }
}

const SNAPSHOT_VERSION: u8 = 1;

/// The bytes of the saved state of a SHA3-256 hash (`SerializableState`).
const HASH_STATE: usize = 201;

/// The bytes of a [`Check::snapshot`], written in order.
#[derive(Default)]
struct Encoder(Vec<u8>);

impl Encoder {
    fn u8(&mut self, v: u8) {
        self.0.push(v);
    }
    fn u32(&mut self, v: u32) {
        self.0.extend_from_slice(&v.to_be_bytes());
    }
    fn u64(&mut self, v: u64) {
        self.0.extend_from_slice(&v.to_be_bytes());
    }
    fn raw(&mut self, v: &[u8]) {
        self.0.extend_from_slice(v);
    }
    fn bytes(&mut self, v: &[u8]) {
        self.u32(v.len() as u32);
        self.raw(v);
    }
    fn option_id(&mut self, v: Option<[u8; 32]>) {
        match v {
            None => self.u8(0),
            Some(id) => {
                self.u8(1);
                self.raw(&id);
            }
        }
    }
    fn finish(self) -> Vec<u8> {
        self.0
    }
}

/// Reads what [`Encoder`] wrote; every read is `None` at the end of the data.
struct Decoder<'a> {
    data: &'a [u8],
}

impl<'a> Decoder<'a> {
    fn new(data: &'a [u8]) -> Self {
        Decoder { data }
    }
    fn take(&mut self, n: usize) -> Option<&'a [u8]> {
        let (head, rest) = self.data.split_at_checked(n)?;
        self.data = rest;
        Some(head)
    }
    fn u8(&mut self) -> Option<u8> {
        Some(self.take(1)?[0])
    }
    fn u32(&mut self) -> Option<u32> {
        Some(u32::from_be_bytes(self.take(4)?.try_into().ok()?))
    }
    fn u64(&mut self) -> Option<u64> {
        Some(u64::from_be_bytes(self.take(8)?.try_into().ok()?))
    }
    fn bytes(&mut self) -> Option<&'a [u8]> {
        let n = self.u32()? as usize;
        self.take(n)
    }
    fn id(&mut self) -> Option<[u8; 32]> {
        self.take(32)?.try_into().ok()
    }
    fn option_id(&mut self) -> Option<Option<[u8; 32]>> {
        match self.u8()? {
            0 => Some(None),
            1 => Some(Some(self.id()?)),
            _ => None,
        }
    }
    fn hasher(&mut self) -> Option<Sha3> {
        let state = self.take(HASH_STATE)?;
        Sha3::deserialize(state.try_into().ok()?).ok()
    }
    fn done(&self) -> bool {
        self.data.is_empty()
    }
}

/// Read a package from `reader` once, check it with [`Check`], and write the file that the
/// library keeps to `partial`: the whole file, or without the content of the blocks of its
/// Service (`strip`). The content of the blocks is read, hashed and thrown away; it is never
/// on the disk. `cancel` counts the bytes that were read, and stops it. Gives what the check
/// found and the size of the file written. `partial` is the caller's to rename or delete.
async fn intake<R: AsyncRead + Unpin>(
    mut reader: R,
    partial: &Path,
    strip: bool,
    cancel: &Cancel,
) -> Result<(Checked, u64), PackageError> {
    let mut writer = BufWriter::with_capacity(1024 * 1024, tokio::fs::File::create(partial).await?);
    let mut check = if strip { Check::stripping() } else { Check::new() };
    let mut piece = vec![0u8; 256 * 1024];
    let mut written = 0u64;
    loop {
        if cancel.is_cancelled() {
            return Err(PackageError::Cancelled);
        }
        let n = reader.read(&mut piece).await?;
        if n == 0 {
            break;
        }
        check.feed(&piece[..n])?;
        if strip {
            let out = check.take_output();
            writer.write_all(&out).await?;
            written += out.len() as u64;
        } else {
            writer.write_all(&piece[..n]).await?;
            written += n as u64;
        }
        cancel.add(n as u64);
    }
    let checked = check.finish()?;
    writer.flush().await?;
    Ok((checked, written))
}

/// Copy the package at `source` to `target` without the content of the blocks of its
/// Service, which is the filesystem of the container (`docs/celaut/package.md`, "Without
/// the filesystem"). Of each top-level block the file keeps the two markers, the one that
/// opens it and the one that ends it, and nothing between them. The rest is copied as it
/// is, so [`inspect`] and the reader of the service information (`service_info`) read the
/// copy as before. The package is checked while it is read ([`Check`]); a package that fails
/// the check gives an error and no file. The copy does not pass [`Check`] and [`read`] must
/// not give it to a node: the library records that ([`Imported::filesystem_kept`]).
///
/// The copy is written next to `target` and renamed, so `target` never holds a cut file.
/// Gives the size of the copy, in bytes. `source` is read once, in order; `cancel` stops it.
pub async fn strip_filesystem(
    source: &Path,
    target: &Path,
    cancel: &Cancel,
) -> Result<u64, PackageError> {
    let partial = partial_path(target);
    let result = async {
        let file = tokio::fs::File::open(source).await?;
        let (_, written) = intake(file, &partial, true, cancel).await?;
        tokio::fs::rename(&partial, target).await?;
        Ok(written)
    }
    .await;
    if result.is_err() {
        let _ = tokio::fs::remove_file(&partial).await;
    }
    result
}

/// The folder of the library inside `dir`, a private directory of the app.
pub fn library_dir(dir: &Path) -> PathBuf {
    dir.join("packages").join("library")
}

/// The file of the service `service_id` in the library.
pub fn library_path(dir: &Path, service_id: &[u8; 32]) -> PathBuf {
    library_dir(dir).join(format!("{}.bee", hex::encode(service_id)))
}

/// A package that was loaded into the library.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Imported {
    /// The id of the service.
    pub service_id: [u8; 32],
    /// Where the file is now.
    pub path: PathBuf,
    /// The head of the package, as it was before it went into the library. Its `bytes` is
    /// the size of the file that was loaded; `stored_bytes` is the size in the library.
    pub info: PackageInfo,
    /// The size of the file in the library, in bytes.
    pub stored_bytes: u64,
    /// False if the content of the blocks of the Service was left out
    /// ([`Storage::WithoutFilesystem`]): the library file cannot be given to a node.
    pub filesystem_kept: bool,
}

/// What the library keeps of a checked package.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum Storage {
    /// The whole file: the service can be given to a node that does not have it.
    #[default]
    Whole,
    /// The file without the content of the blocks of its Service ([`strip_filesystem`]).
    /// The service is checked as before, but the file cannot be given to a node.
    WithoutFilesystem,
}

/// Load the package at `source` into the library under `dir`: check it, then move it to
/// `<dir>/packages/library/<service id>.bee`. A file that is not a package of a service,
/// that does not say which service it is, that has a block that does not hold what its id
/// names, or whose Service does not hash to that id ([`check_file`]), is refused and left
/// where it is. The id comes from the Metadata or from a hash part, and the whole Service
/// must hash to it, as for a download. A package of a service that the library already has
/// replaces it. `cancel` counts the bytes that the check read, and stops it.
///
/// The file is moved when `source` is on the same disk (the copy of the file picker is in
/// the cache of the app), and copied otherwise, so a large service is never in memory and
/// is not on the phone twice for long.
pub async fn import(
    source: &Path,
    dir: &Path,
    cancel: &Cancel,
) -> Result<Imported, PackageError> {
    import_with(source, dir, cancel, Storage::Whole).await
}

/// [`import`], with the choice of what the library keeps. With [`Storage::Whole`] the check
/// reads the whole file first, so a file with a false block is refused and left where it is.
/// With [`Storage::WithoutFilesystem`] the file is read once: the check and the copy to the
/// library, without the content of its blocks, happen in the same pass ([`import_reader`]),
/// so the disk never holds more than the copy. `source` is deleted once the copy is in the
/// library.
pub async fn import_with(
    source: &Path,
    dir: &Path,
    cancel: &Cancel,
    storage: Storage,
) -> Result<Imported, PackageError> {
    let info = inspect(source).await?;
    if !info.has_service {
        return Err(PackageError::Invalid("the file has no Service part".into()));
    }
    if info.service_id.is_none() {
        return Err(PackageError::Invalid("the file does not say which service it is".into()));
    }
    if storage == Storage::WithoutFilesystem {
        let file = tokio::fs::File::open(source).await?;
        let imported = import_reader(file, dir, cancel, storage).await?;
        let _ = tokio::fs::remove_file(source).await;
        return Ok(imported);
    }
    // The head says what the file is at once; the check reads all of it.
    let service_id = check_file(source, cancel).await?.service_id;
    let path = into_library_with(source, dir, &service_id, storage).await?;
    let stored_bytes = tokio::fs::metadata(&path).await?.len();
    Ok(Imported {
        service_id,
        path,
        info,
        stored_bytes,
        filesystem_kept: storage == Storage::Whole,
    })
}

/// Load a package that `reader` gives (a file that the app reads where it is, with no copy
/// of its own: the descriptor of a file of Android) into the library under `dir`, with
/// [`Check`] as it reads. The library file is written next to its place and renamed when the
/// check passes, so a package that fails the check leaves nothing. With
/// [`Storage::WithoutFilesystem`] the content of the blocks is never written: the disk needs
/// the space of the copy that the library keeps, not the size of the package. `cancel`
/// counts the bytes that were read and stops the load.
pub async fn import_reader<R: AsyncRead + Unpin>(
    reader: R,
    dir: &Path,
    cancel: &Cancel,
    storage: Storage,
) -> Result<Imported, PackageError> {
    let folder = library_dir(dir);
    tokio::fs::create_dir_all(&folder).await?;
    let partial = folder.join("incoming.bee.partial");
    let result = intake(reader, &partial, storage == Storage::WithoutFilesystem, cancel).await;
    let (checked, stored_bytes) = match result {
        Ok(done) => done,
        Err(e) => {
            let _ = tokio::fs::remove_file(&partial).await;
            return Err(e);
        }
    };
    let path = library_path(dir, &checked.service_id);
    if let Err(e) = tokio::fs::rename(&partial, &path).await {
        let _ = tokio::fs::remove_file(&partial).await;
        return Err(e.into());
    }
    Ok(Imported {
        service_id: checked.service_id,
        path,
        info: PackageInfo {
            layout: checked.layout,
            bytes: checked.bytes,
            service_id: Some(checked.service_id),
            tag: None,
            has_service: true,
        },
        stored_bytes,
        filesystem_kept: storage == Storage::Whole,
    })
}

/// [`import_reader`] for a file that is already open: a descriptor that the app got from
/// Android for the file that the user chose. It is read where it is, once, in order; it needs
/// no seek, so a pipe of a provider works too. The file is closed when the load ends.
pub async fn import_open_file(
    file: std::fs::File,
    dir: &Path,
    cancel: &Cancel,
    storage: Storage,
) -> Result<Imported, PackageError> {
    import_reader(tokio::fs::File::from_std(file), dir, cancel, storage).await
}

/// Move (or copy, from another disk) the checked package at `source` into the library under
/// `dir`, as the file of `service_id`. Gives its path.
pub async fn into_library(
    source: &Path,
    dir: &Path,
    service_id: &[u8; 32],
) -> Result<PathBuf, PackageError> {
    into_library_with(source, dir, service_id, Storage::Whole).await
}

/// [`into_library`], with the choice of what the library keeps. For
/// [`Storage::WithoutFilesystem`] the library file is written from `source` by
/// [`strip_filesystem`] and `source` is deleted; the library never holds a cut file.
pub async fn into_library_with(
    source: &Path,
    dir: &Path,
    service_id: &[u8; 32],
    storage: Storage,
) -> Result<PathBuf, PackageError> {
    if storage == Storage::WithoutFilesystem {
        let folder = library_dir(dir);
        tokio::fs::create_dir_all(&folder).await?;
        let target = library_path(dir, service_id);
        strip_filesystem(source, &target, &Cancel::new()).await?;
        let _ = tokio::fs::remove_file(source).await;
        return Ok(target);
    }
    into_library_whole(source, dir, service_id).await
}

/// Move a file that is ready (a checked package, or the file without the content of its
/// blocks that a download wrote) into the library as the file of `service_id`.
pub async fn into_library_whole(
    source: &Path,
    dir: &Path,
    service_id: &[u8; 32],
) -> Result<PathBuf, PackageError> {
    let folder = library_dir(dir);
    tokio::fs::create_dir_all(&folder).await?;
    let target = library_path(dir, service_id);
    // The new file is written next to the target and renamed, so the library never holds
    // a cut file, also if the phone stops in the middle.
    let partial = partial_path(&target);
    let _ = tokio::fs::remove_file(&partial).await;
    match tokio::fs::rename(source, &partial).await {
        Ok(()) => {}
        Err(_) => {
            // Another disk: the copy needs the size of the file a second time, until the
            // source is deleted.
            let len = tokio::fs::metadata(source).await?.len();
            let needed = len.saturating_add(crate::link::MIN_FREE);
            if let Some(available) = free_space(&folder) {
                if needed > available {
                    return Err(PackageError::NoSpace { needed, available });
                }
            }
            tokio::fs::copy(source, &partial).await.inspect_err(|_| {
                let _ = std::fs::remove_file(&partial);
            })?;
            let _ = tokio::fs::remove_file(source).await;
        }
    }
    tokio::fs::rename(&partial, &target).await?;
    Ok(target)
}

/// The space that the packages take on the disk under `dir`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct StorageUsage {
    /// The files of the library (`packages/library`): the services that the user loaded,
    /// and what a load that stopped left (`*.partial`).
    pub library_bytes: u64,
    /// The files of the library.
    pub library_files: u64,
    /// The downloads that stopped and can go on (`packages/downloads`).
    pub downloads_bytes: u64,
    /// The copies of a file that the user chose, made before the load
    /// (`packages/incoming`). They are empty unless a copy or a load stopped.
    pub incoming_bytes: u64,
}

/// The bytes and the number of the files in a folder and the folders in it. A folder that is
/// not there is empty. It reads the sizes of the files and nothing more.
fn folder_usage(path: &Path) -> (u64, u64) {
    let (mut bytes, mut files) = (0u64, 0u64);
    let Ok(entries) = std::fs::read_dir(path) else {
        return (0, 0);
    };
    for entry in entries.flatten() {
        // `symlink_metadata`: a link is not followed, so no size counts twice.
        let Ok(meta) = entry.path().symlink_metadata() else {
            continue;
        };
        if meta.is_dir() {
            let (b, f) = folder_usage(&entry.path());
            bytes += b;
            files += f;
        } else if meta.is_file() {
            bytes += meta.len();
            files += 1;
        }
    }
    (bytes, files)
}

/// How much disk the packages under `dir` take now: the library, the downloads that
/// stopped, and the copies that wait to be loaded. It reads the real sizes of the files, not
/// what a record says.
pub async fn storage_usage(dir: &Path) -> StorageUsage {
    let dir = dir.to_path_buf();
    tokio::task::spawn_blocking(move || {
        let (library_bytes, library_files) = folder_usage(&library_dir(&dir));
        StorageUsage {
            library_bytes,
            library_files,
            downloads_bytes: folder_usage(&dir.join("packages").join("downloads")).0,
            incoming_bytes: folder_usage(&dir.join("packages").join("incoming")).0,
        }
    })
    .await
    .unwrap_or_default()
}

/// Delete the file of a package in the library. A file that is not there is not an error.
pub async fn remove_file(path: &Path) -> Result<(), PackageError> {
    match tokio::fs::remove_file(path).await {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e.into()),
    }
}
