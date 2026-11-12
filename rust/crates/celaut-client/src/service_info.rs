//! What a service says about itself, read from its `Service` part as a stream
//! (`docs/celaut/service-info.md`).
//!
//! The `Service` of a package holds the filesystem of the container in its bytes, and the
//! filesystem is most of the weight: hundreds of megabytes (`claude-code.bee` has 536 MB).
//! The app does not need it to describe the service, so the Service part is not decoded as
//! one message. This module walks its protobuf fields as a stream, skips the bytes of the
//! filesystem without keeping them, and decodes only the small parts: the prose, the
//! architecture, the resources, the entry point, the environment variables, the interface,
//! the networks and the workloads. The memory that it holds is one Buffer and the parts
//! that it keeps, whatever the size of the service.
//!
//! The fields come in the order of their numbers, so the interface and the networks (3 and
//! 4) are after the container (2), and so after the filesystem: the whole Service part is
//! read to the end, but never kept.
//!
//! The Buffers are the ones of `GetService` or of a `.bee` file through
//! [`crate::package::read`]: the Service part is the object with the index 6, and its
//! bytes are its chunks in order, with the chunks of its blocks included.

use std::path::Path;

use bee_rpc::buffer::Buffer;
use celaut_proto::celaut::service::container::{Architecture, ConfigDeclaration, Init, Resources};
use celaut_proto::celaut::service::{Api, Clause, Network};
use celaut_proto::celaut::DataFormatKeyValue;
use celaut_wire::gateway::SHA3_256_TYPE;
use celaut_wire::{Buffers, Skipper};
use prost::Message;
use tokio_stream::StreamExt;

use crate::package::{inspect, read, Cancel, PackageError};
use crate::session::api_chat_ports;

/// A field of at least this many bytes is asked to be skipped, if the node can skip it
/// (it is a block that holds the filesystem of a service).
const SKIP_THRESHOLD: u64 = 1024 * 1024;

/// How long the reader waits for the next Buffer before it gives up.
const IDLE_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(30);

/// The least that a Buffer counts against the limit, in bytes.
const BUFFER_OVERHEAD: u64 = 16;

/// The index of the Service part.
const SERVICE_INDEX: i32 = 6;

/// The largest part that is decoded. A larger part is skipped and counted.
const MAX_ENTRY: u64 = 256 * 1024;

/// How many items of one list a service can have here. A longer list is refused.
pub const MAX_ITEMS: usize = 256;

/// A variable that a service declares.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Declared {
    pub name: String,
    /// The names of its format.
    pub tags: Vec<String>,
    /// The text that explains it.
    pub prose: String,
}

/// The bytes of the Service part, pulled one Buffer at a time.
struct ServiceBytes {
    input: Buffers,
    buf: Vec<u8>,
    pos: usize,
    /// The index of the object that is open, if one is.
    open: Option<i32>,
    ended: bool,
    /// The bytes of the Service part that were read.
    consumed: u64,
    /// The bytes of the whole stream that were read, for the limit.
    seen: u64,
    limit: Option<u64>,
    /// True if the stream passed the limit: the Service part ends there for the reader.
    limit_hit: bool,
    /// The parts that were larger than the reader decodes, and were skipped.
    skipped: u32,
    /// Asks the node to skip a block, if the transport can.
    skipper: Option<Skipper>,
    /// The ids of the blocks of the Service part that are open, outermost first.
    stack: Vec<Vec<u8>>,
    /// The id of the block that the node was asked to skip, until its end marker comes.
    skipping: Option<Vec<u8>>,
    /// The block that opened at the top level since it was last looked at.
    opened: Option<Vec<u8>>,
    /// How many blocks the node was asked to skip.
    blocks_skipped: u32,
}

/// The id of a block, from its marker: the SHA3-256 hash that names it.
fn block_id(block: &bee_rpc::buffer::buffer::Block) -> Option<Vec<u8>> {
    block
        .hashes
        .iter()
        .find(|h| h.r#type == SHA3_256_TYPE)
        .map(|h| h.value.clone())
        .filter(|v| !v.is_empty())
}

fn invalid(text: &str) -> PackageError {
    PackageError::Invalid(text.into())
}

impl ServiceBytes {
    fn new(input: Buffers, limit: Option<u64>, skipper: Option<Skipper>) -> Self {
        ServiceBytes {
            input,
            buf: Vec::new(),
            pos: 0,
            open: None,
            ended: false,
            consumed: 0,
            seen: 0,
            limit,
            limit_hit: false,
            skipped: 0,
            skipper,
            stack: Vec::new(),
            skipping: None,
            opened: None,
            blocks_skipped: 0,
        }
    }

    /// Read one more Buffer, and keep its bytes if it is part of the Service. False when
    /// the Service part is over (or the stream is).
    async fn pull(&mut self) -> Result<bool, PackageError> {
        if self.ended {
            return Ok(false);
        }
        // A node that goes quiet must not hold the reader for ever.
        let next = tokio::time::timeout(IDLE_TIMEOUT, self.input.next())
            .await
            .map_err(|_| invalid("the node stopped sending the service"))?;
        let Some(item) = next else {
            self.ended = true;
            return Ok(false);
        };
        let buffer: Buffer = item?;
        // Each Buffer counts at least its framing, so a stream of empty Buffers reaches the
        // limit too.
        self.seen += (buffer.encoded_len() as u64).max(BUFFER_OVERHEAD);
        if self.limit.is_some_and(|l| self.seen > l) {
            self.limit_hit = true;
            self.ended = true;
            return Ok(false);
        }
        let starts = buffer.head.is_some() || buffer.chunk.is_some() || buffer.block.is_some();
        if self.open.is_none() && starts {
            self.open = Some(buffer.head.as_ref().map_or(0, |h| h.index));
        }
        if self.open == Some(SERVICE_INDEX) {
            if let Some(id) = buffer.block.as_ref().and_then(block_id) {
                self.mark_block(id);
            }
            // The chunks of a block that the node was asked to skip are not the field: they
            // are what was on the way when the request arrived.
            if let (Some(chunk), None) = (&buffer.chunk, &self.skipping) {
                if self.pos > 0 && self.pos == self.buf.len() {
                    self.buf.clear();
                    self.pos = 0;
                }
                self.buf.extend_from_slice(chunk);
            }
        }
        if buffer.separator == Some(true) || (self.open.is_some() && !starts) {
            if self.open == Some(SERVICE_INDEX) {
                self.ended = true;
            }
            self.open = None;
        }
        Ok(true)
    }

    /// A block marker of the Service part. The id of a block that is open closes it, and
    /// the blocks that were open inside it (a node that skips a block drops the markers of
    /// its children); any other id opens one.
    fn mark_block(&mut self, id: Vec<u8>) {
        match self.stack.iter().rposition(|open| *open == id) {
            Some(at) => {
                self.stack.truncate(at);
                if at == 0 {
                    self.skipping = None;
                }
            }
            None => {
                if self.stack.is_empty() {
                    self.opened = Some(id.clone());
                }
                self.stack.push(id);
            }
        }
    }

    /// Skip the `len` bytes of a field. A field of a megabyte or more that is a block, and
    /// that the node can skip, is not read: the reader asks the node to drop it, ignores what
    /// was on the way until the end marker of the block, and counts the field as read (the
    /// length of a field that is a block is the length of the block). If the field is not a
    /// block, or the node cannot skip, the bytes are read and dropped.
    async fn skip_field(&mut self, len: u64) -> Result<(), PackageError> {
        if len >= SKIP_THRESHOLD && self.skipper.is_some() && self.pos >= self.buf.len() {
            self.opened = None;
            // The next Buffer: a marker if the field is a block, else its first bytes.
            while self.pos >= self.buf.len() && self.opened.is_none() {
                if !self.pull().await? {
                    break;
                }
            }
            if let Some(id) = self.opened.take() {
                let asked = self.skipper.as_ref().is_some_and(|skip| skip(&id));
                if asked && self.stack.len() == 1 {
                    self.skipping = Some(id);
                    self.blocks_skipped += 1;
                    while self.skipping.is_some() {
                        if !self.pull().await? {
                            return Err(invalid("the Service is cut"));
                        }
                    }
                    self.consumed = self.consumed.saturating_add(len);
                    return Ok(());
                }
            }
        }
        self.skip(len).await
    }

    /// Make sure that at least one byte is ready. False at the end of the Service part.
    async fn ready(&mut self) -> Result<bool, PackageError> {
        while self.pos >= self.buf.len() {
            if !self.pull().await? {
                return Ok(false);
            }
        }
        Ok(true)
    }

    async fn byte(&mut self) -> Result<Option<u8>, PackageError> {
        if !self.ready().await? {
            return Ok(None);
        }
        let b = self.buf[self.pos];
        self.pos += 1;
        self.consumed += 1;
        Ok(Some(b))
    }

    /// A varint. `None` if the Service part ends before its first byte.
    async fn varint(&mut self) -> Result<Option<u64>, PackageError> {
        let mut value = 0u64;
        for shift in (0..64).step_by(7) {
            let Some(b) = self.byte().await? else {
                return if shift == 0 {
                    Ok(None)
                } else {
                    Err(invalid("the Service is cut"))
                };
            };
            value |= u64::from(b & 0x7f) << shift;
            if b & 0x80 == 0 {
                return Ok(Some(value));
            }
        }
        Err(invalid("a varint of the Service is too long"))
    }

    async fn need_varint(&mut self) -> Result<u64, PackageError> {
        self.varint()
            .await?
            .ok_or_else(|| invalid("the Service is cut"))
    }

    async fn take(&mut self, n: u64) -> Result<Vec<u8>, PackageError> {
        let n = usize::try_from(n).map_err(|_| invalid("a field is too long"))?;
        let mut out = Vec::with_capacity(n.min(64 * 1024));
        while out.len() < n {
            if !self.ready().await? {
                return Err(invalid("the Service is cut"));
            }
            let take = (n - out.len()).min(self.buf.len() - self.pos);
            out.extend_from_slice(&self.buf[self.pos..self.pos + take]);
            self.pos += take;
            self.consumed += take as u64;
        }
        Ok(out)
    }

    async fn skip(&mut self, mut n: u64) -> Result<(), PackageError> {
        while n > 0 {
            if !self.ready().await? {
                return Err(invalid("the Service is cut"));
            }
            let take = n.min((self.buf.len() - self.pos) as u64);
            self.pos += take as usize;
            self.consumed += take;
            n -= take;
        }
        Ok(())
    }

    /// Skip the value of a field of this wire type.
    async fn skip_value(&mut self, wire_type: u64) -> Result<(), PackageError> {
        match wire_type {
            0 => {
                self.need_varint().await?;
                Ok(())
            }
            1 => self.skip(8).await,
            2 => {
                let len = self.need_varint().await?;
                self.skip(len).await
            }
            5 => self.skip(4).await,
            _ => Err(invalid(
                "the Service has a field of a wire type that is not valid",
            )),
        }
    }
}

/// What a service says about itself. A field that the service does not set is empty.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ServiceInfo {
    /// `Service.prose`.
    pub prose: String,
    /// `Container.architecture`.
    pub architecture: Option<Architecture>,
    /// The size of the filesystem of the container, in bytes. The filesystem is not kept.
    pub filesystem_bytes: u64,
    /// `Container.init`: the executable that the node starts.
    pub init: Option<Init>,
    /// `Container.resources`.
    pub resources: Option<Resources>,
    /// `Container.config_declaration`.
    pub config: Option<ConfigDeclaration>,
    /// The protocols that the service expects from the node.
    pub node_protocol_stack: Vec<celaut_proto::celaut::service::api::Protocol>,
    /// The environment variables that the service declares, in order.
    pub environment: Vec<Declared>,
    /// `Service.api`.
    pub api: Option<Api>,
    /// `Service.network`.
    pub networks: Vec<Network>,
    /// The descendant instances that the service can start while it runs
    /// (`Service.possible_environment_workload`). An AND of clauses; a clause is an OR of
    /// groups; a group is an AND of workloads that run at the same time (nodo#538).
    pub workloads: Vec<Clause>,
    /// The descendant instances that the service starts at its start
    /// (`Service.initial_environment_workload`), in the same form. The `cost` of a quote
    /// includes their start (nodo#538).
    pub initial_workloads: Vec<Clause>,
    /// How many clauses of the two fields were too large to read (they carry a whole
    /// service).
    pub workloads_skipped: u32,
    /// How many other parts (the architecture, the resources, a network, …) were larger than
    /// the reader decodes and were skipped. Each is unknown, not absent.
    pub parts_skipped: u32,
    /// True if the interface was larger than the reader decodes and was skipped, so the
    /// chat check cannot tell.
    pub api_skipped: bool,
    /// How many blocks the node was asked not to send (the block of the filesystem).
    pub blocks_skipped: u32,
    /// True if the stream passed the limit before the end of the Service part. The fields
    /// after the filesystem (everything but the prose and the architecture) are then
    /// unknown, which is not the same as empty.
    pub truncated: bool,
}

impl ServiceInfo {
    /// True if the interface was read, so [`ServiceInfo::chat_ports`] is the answer and not
    /// a guess: the service was not cut and its interface was not skipped.
    pub fn interface_known(&self) -> bool {
        !self.truncated && !self.api_skipped
    }

    /// The ports of the interface that follow the chat convention (`docs/celaut/chat.md`,
    /// section 2), in the order of the interface. Empty also when the interface is not
    /// known: check [`ServiceInfo::truncated`].
    pub fn chat_ports(&self) -> Vec<u16> {
        self.api.as_ref().map(api_chat_ports).unwrap_or_default()
    }
}

/// Decode a part of `len` bytes, or skip it if it is larger than [`MAX_ENTRY`]. A skipped
/// part is counted in `src.skipped`.
async fn part<M: Message + Default>(
    src: &mut ServiceBytes,
    len: u64,
    what: &str,
) -> Result<Option<M>, PackageError> {
    if len > MAX_ENTRY {
        src.skip(len).await?;
        src.skipped += 1;
        return Ok(None);
    }
    let bytes = src.take(len).await?;
    M::decode(bytes.as_slice())
        .map(Some)
        .map_err(|e| PackageError::Invalid(format!("{what}: {e}")))
}

fn keep<T>(list: &mut Vec<T>, item: T) -> Result<(), PackageError> {
    if list.len() >= MAX_ITEMS {
        return Err(invalid("the service has too long a list"));
    }
    list.push(item);
    Ok(())
}

/// The fields of `Service.container`, from `consumed` up to `end`.
async fn scan_container(
    src: &mut ServiceBytes,
    end: u64,
    info: &mut ServiceInfo,
) -> Result<(), PackageError> {
    while src.consumed < end {
        let tag = src.need_varint().await?;
        let (field, wire_type) = (tag >> 3, tag & 7);
        if wire_type != 2 || !(1..=7).contains(&field) {
            src.skip_value(wire_type).await?;
            continue;
        }
        let len = src.need_varint().await?;
        match field {
            1 => info.architecture = part(src, len, "the architecture").await?,
            // The filesystem is skipped: it is the weight of the service.
            2 => {
                info.filesystem_bytes = info.filesystem_bytes.saturating_add(len);
                src.skip_field(len).await?;
            }
            3 => info.init = part(src, len, "the init").await?,
            4 => info.resources = part(src, len, "the resources").await?,
            5 => info.config = part(src, len, "the configuration").await?,
            6 => {
                if let Some(p) = part(src, len, "a node protocol").await? {
                    keep(&mut info.node_protocol_stack, p)?;
                }
            }
            _ => {
                if len > MAX_ENTRY {
                    return Err(invalid("an entry of the declaration is too large"));
                }
                if let Some(entry) =
                    part::<DataFormatKeyValue>(src, len, "a declared variable").await?
                {
                    let format = entry.value.unwrap_or_default();
                    keep(
                        &mut info.environment,
                        Declared {
                            name: entry.key,
                            tags: format.tags,
                            prose: format.prose,
                        },
                    )?;
                }
            }
        }
    }
    if src.consumed != end {
        return Err(invalid("the container of the Service is cut"));
    }
    Ok(())
}

async fn scan(src: &mut ServiceBytes, info: &mut ServiceInfo) -> Result<(), PackageError> {
    while let Some(tag) = src.varint().await? {
        let (field, wire_type) = (tag >> 3, tag & 7);
        if wire_type != 2 || !(1..=6).contains(&field) {
            src.skip_value(wire_type).await?;
            continue;
        }
        let len = src.need_varint().await?;
        match field {
            1 => {
                if len > MAX_ENTRY {
                    return Err(invalid("the prose of the Service is too long"));
                }
                let bytes = src.take(len).await?;
                info.prose = String::from_utf8(bytes)
                    .map_err(|_| invalid("the prose of the Service is not UTF-8"))?;
            }
            2 => {
                let end = src.consumed.saturating_add(len);
                scan_container(src, end, info).await?;
            }
            3 => {
                let api = part(src, len, "the interface").await?;
                info.api_skipped = api.is_none();
                info.api = api;
            }
            4 => {
                if let Some(n) = part(src, len, "a network").await? {
                    keep(&mut info.networks, n)?;
                }
            }
            _ => {
                // A clause that is too large is counted apart: it carries a whole service.
                let before = src.skipped;
                match part(src, len, "a workload").await? {
                    Some(w) if field == 6 => keep(&mut info.initial_workloads, w)?,
                    Some(w) => keep(&mut info.workloads, w)?,
                    None => {
                        src.skipped = before;
                        info.workloads_skipped += 1;
                    }
                }
            }
        }
    }
    Ok(())
}

/// Read what the service says about itself from the Buffers of a service (`GetService`,
/// or a package through [`read`]). With a `skipper`, the node is asked not to send the block of
/// the filesystem, so it is not even received. With `limit`, a stream of more bytes than that ends
/// the reading: what was read so far is given, with `truncated` set (a node can send a
/// service of gigabytes, and the fields after the filesystem need all of it).
pub async fn read_service_info(
    input: Buffers,
    limit: Option<u64>,
    skipper: Option<Skipper>,
) -> Result<ServiceInfo, PackageError> {
    let mut src = ServiceBytes::new(input, limit, skipper);
    let mut info = ServiceInfo::default();
    match scan(&mut src, &mut info).await {
        Ok(()) => {}
        // The reader ended at the limit, in the middle of the service: not a cut service.
        Err(_) if src.limit_hit => {}
        Err(e) => return Err(e),
    }
    info.truncated = src.limit_hit;
    info.parts_skipped = src.skipped;
    info.blocks_skipped = src.blocks_skipped;
    Ok(info)
}

/// The same for a package file: the library file of a service, or a file that was
/// fetched from a node.
pub async fn read_service_info_of_file(path: &Path) -> Result<ServiceInfo, PackageError> {
    let info = inspect(path).await?;
    if !info.has_service {
        return Err(invalid("the file has no Service part"));
    }
    read_service_info(
        read(path.to_path_buf(), info.layout, Cancel::new()),
        None,
        None,
    )
    .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use bee_rpc::buffer::buffer::Head;
    use celaut_proto::celaut::service::api::{Protocol, Slot};
    use celaut_proto::celaut::service::container::Resources as ContainerResources;
    use celaut_proto::celaut::service::workload::Dependency;
    use celaut_proto::celaut::service::{Group, Workload};
    use celaut_proto::celaut::service::Container;
    use celaut_proto::celaut::{DataFormat, Service, Sysresources, Uint64KeyValue};

    fn varint(mut v: u64, out: &mut Vec<u8>) {
        while v >= 0x80 {
            out.push((v as u8 & 0x7f) | 0x80);
            v >>= 7;
        }
        out.push(v as u8);
    }

    fn declaration(names: &[&str]) -> Vec<DataFormatKeyValue> {
        names
            .iter()
            .map(|n| DataFormatKeyValue {
                key: n.to_string(),
                value: Some(DataFormat {
                    tags: vec!["text".into()],
                    prose: format!("the {n}"),
                    formal: Vec::new(),
                }),
            })
            .collect()
    }

    fn protocol(tags: &[&str]) -> Protocol {
        Protocol {
            tags: tags.iter().map(|t| t.to_string()).collect(),
            prose: String::new(),
            formal: Vec::new(),
        }
    }

    fn slot(port: i32, transport: &str, stack: &[&[&str]]) -> Slot {
        Slot {
            port,
            transport: Some(protocol(&[transport])),
            protocol_stack: stack.iter().map(|t| protocol(t)).collect(),
            mu_per_call: Vec::new(),
        }
    }

    fn resources() -> Sysresources {
        Sysresources {
            cpu_quota: Some(200_000),
            cpu_period: Some(100_000),
            mem_limit: Some(512 << 20),
            disk_space: Some(2 << 30),
            benchmark: vec![Uint64KeyValue {
                key: "int_ops_per_sec".into(),
                value: Some(1_000_000),
            }],
            ..Default::default()
        }
    }

    /// A Service with every part that the reader keeps, and a filesystem of `fs` bytes.
    fn service(fs: usize, names: &[&str]) -> Service {
        Service {
            prose: "A service for the tests ñ".into(),
            container: Some(Container {
                architecture: Some(celaut_proto::celaut::service::container::Architecture {
                    tags: vec!["linux/arm64".into()],
                    prose: "ARM".into(),
                    formal: Vec::new(),
                }),
                filesystem: vec![7u8; fs],
                init: Some(Init {
                    entry_path: vec!["usr".into(), "bin".into(), "serve".into()],
                    xattrs: Vec::new(),
                }),
                resources: Some(ContainerResources {
                    at_init: Some(resources()),
                    at_most: Some(Sysresources {
                        mem_limit: Some(1 << 30),
                        ..Default::default()
                    }),
                }),
                config_declaration: Some(ConfigDeclaration {
                    path: vec!["__config__".into()],
                    format: None,
                }),
                node_protocol_stack: vec![protocol(&["grpc"])],
                environment_variables: declaration(names),
                ..Default::default()
            }),
            api: Some(Api {
                slot: vec![
                    slot(3030, "tcp", &[&["http2"], &["grpc"], &["chat"]]),
                    slot(53, "udp", &[]),
                ],
                payment_contracts: Vec::new(),
            }),
            network: vec![
                Network {
                    tags: vec!["api.example.org".into()],
                    prose: "The API".into(),
                    formal: b"pow.chain=ergo".to_vec(),
                    protocol_stack: vec![protocol(&["https"])],
                },
                Network {
                    tags: vec!["*".into()],
                    ..Default::default()
                },
            ],
            possible_environment_workload: vec![Clause {
                any_of: vec![Group {
                    workloads: vec![Workload {
                        count: 3,
                        dependency: Some(Dependency {
                            service: Some(Service {
                                container: Some(Container {
                                    resources: Some(ContainerResources {
                                        at_init: Some(resources()),
                                        at_most: None,
                                    }),
                                    ..Default::default()
                                }),
                                ..Default::default()
                            }),
                            ..Default::default()
                        }),
                    }],
                }],
            }],
            initial_environment_workload: vec![Clause {
                any_of: vec![
                    Group {
                        workloads: vec![Workload {
                            count: 1,
                            dependency: Some(Dependency {
                                hash: vec![celaut_proto::celaut::metadata::hash_tag::Hash {
                                    r#type: vec![1],
                                    value: vec![7; 32],
                                }],
                                ..Default::default()
                            }),
                        }],
                    },
                    Group {
                        workloads: vec![Workload {
                            count: 2,
                            dependency: None,
                        }],
                    },
                ],
            }],
        }
    }

    fn stream(buffers: Vec<Buffer>) -> Buffers {
        Box::pin(tokio_stream::iter(buffers.into_iter().map(Ok)))
    }

    fn head(index: i32) -> Option<Head> {
        Some(Head {
            index,
            partitions: Vec::new(),
        })
    }

    /// The parts of a package: a Metadata part, then the Service in chunks of `size`
    /// bytes, with a block marker in the middle.
    fn package(bytes: &[u8], size: usize) -> Buffers {
        let mut out = vec![Buffer {
            head: head(5),
            chunk: Some(vec![1, 2, 3]),
            separator: Some(true),
            ..Default::default()
        }];
        out.push(Buffer {
            head: head(SERVICE_INDEX),
            ..Default::default()
        });
        for (i, part) in bytes.chunks(size).enumerate() {
            if i == 1 {
                out.push(Buffer {
                    block: Some(Default::default()),
                    ..Default::default()
                });
            }
            out.push(Buffer {
                chunk: Some(part.to_vec()),
                ..Default::default()
            });
        }
        out.push(Buffer {
            separator: Some(true),
            ..Default::default()
        });
        stream(out)
    }

    #[tokio::test]
    async fn every_part_is_read_after_a_large_filesystem() {
        let bytes = service(300_000, &["API_KEY", "DB_PASSWORD"]).encode_to_vec();
        for size in [1, 7, 4096, 1 << 20] {
            let info = read_service_info(package(&bytes, size), None, None)
                .await
                .unwrap();
            assert!(!info.truncated, "chunks of {size}");
            assert_eq!(info.prose, "A service for the tests ñ");
            assert_eq!(info.filesystem_bytes, 300_000);
            let arch = info.architecture.as_ref().unwrap();
            assert_eq!(arch.tags, vec!["linux/arm64".to_string()]);
            assert_eq!(
                info.init.as_ref().unwrap().entry_path,
                ["usr", "bin", "serve"]
            );
            let res = info.resources.as_ref().unwrap();
            assert_eq!(res.at_init.as_ref().unwrap().mem_limit, Some(512 << 20));
            assert_eq!(res.at_most.as_ref().unwrap().mem_limit, Some(1 << 30));
            assert_eq!(info.config.as_ref().unwrap().path, ["__config__"]);
            assert_eq!(info.node_protocol_stack.len(), 1);
            let names: Vec<_> = info.environment.iter().map(|d| d.name.as_str()).collect();
            assert_eq!(names, ["API_KEY", "DB_PASSWORD"]);
            assert_eq!(info.environment[1].prose, "the DB_PASSWORD");
            let api = info.api.as_ref().unwrap();
            assert_eq!(api.slot.len(), 2);
            assert_eq!(info.networks.len(), 2);
            assert_eq!(info.networks[0].tags, vec!["api.example.org".to_string()]);
            assert_eq!(info.networks[0].formal, b"pow.chain=ergo");
            assert_eq!(info.workloads.len(), 1);
            assert_eq!(info.workloads[0].any_of[0].workloads[0].count, 3);
            assert_eq!(info.initial_workloads.len(), 1);
            let groups = &info.initial_workloads[0].any_of;
            assert_eq!(groups.len(), 2);
            assert_eq!(groups[0].workloads[0].count, 1);
            assert_eq!(groups[1].workloads[0].count, 2);
            assert_eq!(info.workloads_skipped, 0);
        }
    }

    #[tokio::test]
    async fn the_filesystem_is_never_kept() {
        // A filesystem of 40 MiB, read in chunks of 1 MiB: the buffer of the reader stays
        // as large as one chunk and the parts that it keeps, never as the filesystem.
        let bytes = service(40 << 20, &["A"]).encode_to_vec();
        let mut src = ServiceBytes::new(package(&bytes, 1 << 20), None, None);
        let mut max = 0usize;
        // Drive the scan by hand, so the buffer can be measured between the pulls.
        let tag = src.varint().await.unwrap().unwrap();
        assert_eq!(tag >> 3, 1);
        let len = src.need_varint().await.unwrap();
        src.take(len).await.unwrap();
        let tag = src.varint().await.unwrap().unwrap();
        assert_eq!(tag >> 3, 2);
        let len = src.need_varint().await.unwrap();
        let end = src.consumed + len;
        // The architecture is the first field of the container, then the filesystem.
        while src.consumed < end {
            let tag = src.need_varint().await.unwrap();
            let len = src.need_varint().await.unwrap();
            if tag >> 3 == 2 {
                let mut left = len;
                while left > 0 {
                    let step = left.min(1 << 20);
                    src.skip(step).await.unwrap();
                    max = max.max(src.buf.capacity());
                    left -= step;
                }
            } else {
                src.skip(len).await.unwrap();
            }
        }
        assert!(max < 4 << 20, "the buffer grew to {max} bytes");
    }

    #[tokio::test]
    async fn the_chat_interface_is_found_on_the_declared_ports() {
        let bytes = service(10, &[]).encode_to_vec();
        let info = read_service_info(package(&bytes, 64), None, None)
            .await
            .unwrap();
        assert_eq!(info.chat_ports(), vec![3030]);
        // No interface, or one without the chat protocol above http2 and grpc: not supported.
        let none = Service::default().encode_to_vec();
        let info = read_service_info(package(&none, 64), None, None)
            .await
            .unwrap();
        assert!(info.chat_ports().is_empty());
        for stack in [
            vec![vec!["chat"], vec!["grpc"], vec!["http2"]],
            vec![vec!["http"], vec!["chat"]],
            vec![vec!["http2"], vec!["chat"]],
            vec![vec!["http2"], vec!["grpc"]],
            vec![vec!["http"]],
            vec![vec!["chat"]],
            vec![],
        ] {
            let stack: Vec<&[&str]> = stack.iter().map(|p| p.as_slice()).collect();
            let svc = Service {
                api: Some(Api {
                    slot: vec![slot(80, "tcp", &stack)],
                    payment_contracts: Vec::new(),
                }),
                ..Default::default()
            };
            let info = read_service_info(package(&svc.encode_to_vec(), 64), None, None)
                .await
                .unwrap();
            assert!(info.chat_ports().is_empty(), "{stack:?}");
        }
        let udp = Service {
            api: Some(Api {
                slot: vec![slot(80, "udp", &[&["http2"], &["grpc"], &["chat"]])],
                payment_contracts: Vec::new(),
            }),
            ..Default::default()
        };
        let info = read_service_info(package(&udp.encode_to_vec(), 64), None, None)
            .await
            .unwrap();
        assert!(info.chat_ports().is_empty());
    }

    #[tokio::test]
    async fn a_service_with_nothing_gives_an_empty_info() {
        let empty = Service::default().encode_to_vec();
        let info = read_service_info(package(&empty, 4), None, None)
            .await
            .unwrap();
        assert_eq!(info, ServiceInfo::default());
        // No Service part at all.
        let info = read_service_info(stream(vec![]), None, None).await.unwrap();
        assert_eq!(info, ServiceInfo::default());
    }

    #[tokio::test]
    async fn the_limit_gives_what_came_before_the_filesystem_and_says_so() {
        let bytes = service(200_000, &["A"]).encode_to_vec();
        let info = read_service_info(package(&bytes, 4096), Some(50_000), None)
            .await
            .unwrap();
        assert!(info.truncated);
        assert_eq!(info.prose, "A service for the tests ñ");
        assert_eq!(
            info.architecture.unwrap().tags,
            vec!["linux/arm64".to_string()]
        );
        // What is after the filesystem is unknown, not empty.
        assert!(info.api.is_none() && info.environment.is_empty() && info.networks.is_empty());
        let whole = read_service_info(package(&bytes, 4096), Some(1 << 20), None)
            .await
            .unwrap();
        assert!(!whole.truncated);
        assert_eq!(whole.environment.len(), 1);
    }

    #[tokio::test]
    async fn a_part_that_is_too_large_is_counted_and_the_interface_is_not_known() {
        let mut svc = service(0, &[]);
        svc.api.as_mut().unwrap().slot = (0..2000)
            .map(|i| Slot {
                port: i,
                transport: Some(protocol(&["tcp"])),
                protocol_stack: vec![Protocol {
                    tags: vec!["http".into()],
                    prose: "x".repeat(200),
                    formal: Vec::new(),
                }],
                mu_per_call: Vec::new(),
            })
            .collect();
        assert!(svc.api.as_ref().unwrap().encoded_len() as u64 > MAX_ENTRY);
        let info = read_service_info(package(&svc.encode_to_vec(), 4096), None, None)
            .await
            .unwrap();
        // Not "no chat interface": the interface is unknown.
        assert!(info.api.is_none() && info.api_skipped);
        assert!(!info.interface_known());
        assert_eq!(info.parts_skipped, 1);
        assert!(!info.truncated);
        // The parts after it are still read.
        assert_eq!(info.networks.len(), 2);
        // A normal service has all of its parts and a known interface.
        let ok = read_service_info(package(&service(0, &[]).encode_to_vec(), 4096), None, None)
            .await
            .unwrap();
        assert!(ok.interface_known() && ok.parts_skipped == 0 && !ok.api_skipped);
    }

    #[tokio::test]
    async fn a_stream_of_empty_buffers_reaches_the_limit() {
        // Before the Service part, an empty Buffer changes nothing (inside it, it would end
        // the part), so a node could send them for ever.
        let mut parts: Vec<Buffer> = (0..1000).map(|_| Buffer::default()).collect();
        parts.push(Buffer {
            head: head(SERVICE_INDEX),
            ..Default::default()
        });
        let info = read_service_info(stream(parts), Some(4096), None)
            .await
            .unwrap();
        assert!(info.truncated);
    }

    #[tokio::test(start_paused = true)]
    async fn a_node_that_stops_sending_does_not_hold_the_reader() {
        let silent: Buffers = Box::pin(futures::stream::pending());
        let err = read_service_info(silent, Some(1 << 20), None)
            .await
            .unwrap_err();
        assert!(err.to_string().contains("stopped sending"), "{err}");
    }

    #[tokio::test]
    async fn a_workload_that_carries_a_whole_service_is_counted_and_not_read() {
        let mut big = service(0, &[]);
        let nested = Clause {
            any_of: vec![Group {
                workloads: vec![Workload {
                    count: 1,
                    dependency: Some(Dependency {
                        hash: Vec::new(),
                        service: Some(service((MAX_ENTRY as usize) + 1000, &["X"])),
                        is_completed: true,
                        on_filesystem: false,
                    }),
                }],
            }],
        };
        big.possible_environment_workload.push(nested.clone());
        big.initial_environment_workload.push(nested);
        let info = read_service_info(package(&big.encode_to_vec(), 4096), None, None)
            .await
            .unwrap();
        assert_eq!(info.workloads.len(), 1);
        assert_eq!(info.initial_workloads.len(), 1);
        assert_eq!(info.workloads_skipped, 2);
        assert_eq!(info.api.unwrap().slot.len(), 2);
    }

    #[tokio::test]
    async fn a_cut_service_is_an_error_and_never_a_panic() {
        let bytes = service(1000, &["A", "B"]).encode_to_vec();
        for cut in [1, 3, 500, bytes.len() - 3] {
            let _ = read_service_info(package(&bytes[..cut], 64), None, None).await;
        }
        let mut junk = Vec::new();
        varint((2 << 3) | 2, &mut junk);
        varint(1 << 40, &mut junk);
        junk.extend_from_slice(&[0xff; 32]);
        assert!(read_service_info(package(&junk, 8), None, None)
            .await
            .is_err());
        // A group wire type is not valid.
        assert!(read_service_info(package(&[0x0b], 8), None, None)
            .await
            .is_err());
        // The prose must be UTF-8.
        let mut bad = Vec::new();
        varint((1 << 3) | 2, &mut bad);
        varint(2, &mut bad);
        bad.extend_from_slice(&[0xff, 0xfe]);
        assert!(read_service_info(package(&bad, 8), None, None)
            .await
            .is_err());
    }

    #[tokio::test]
    async fn another_part_with_the_same_bytes_is_not_the_service() {
        let other = service(10, &["A"]).encode_to_vec();
        let mut parts = vec![Buffer {
            head: head(5),
            chunk: Some(other),
            separator: Some(true),
            ..Default::default()
        }];
        parts.push(Buffer {
            head: head(SERVICE_INDEX),
            chunk: Some(service(0, &["B"]).encode_to_vec()),
            separator: Some(true),
            ..Default::default()
        });
        let info = read_service_info(stream(parts), None, None).await.unwrap();
        assert_eq!(info.environment.len(), 1);
        assert_eq!(info.environment[0].name, "B");
    }

    /// A real package, for a manual check: `CELAUT_TEST_BEE=/path/to/service.bee cargo
    /// test -p celaut-client --lib real_package -- --ignored --nocapture`.
    #[tokio::test]
    #[ignore = "needs a .bee file"]
    async fn real_package() {
        let path = std::env::var("CELAUT_TEST_BEE").expect("set CELAUT_TEST_BEE");
        let started = std::time::Instant::now();
        let got = read_service_info_of_file(Path::new(&path)).await.unwrap();
        println!(
            "prose {:?}\narch {:?}\nfs {} bytes\nenv {:?}\nslots {:?}\nnetworks {}\nchat {:?}\nin {:?}",
            got.prose,
            got.architecture.as_ref().map(|a| &a.tags),
            got.filesystem_bytes,
            got.environment,
            got.api.as_ref().map(|a| a.slot.len()),
            got.networks.len(),
            got.chat_ports(),
            started.elapsed()
        );
    }

    // --- skipping the block of the filesystem -------------------------------------------

    use bee_rpc::hash::HashAlgorithm;
    use bee_rpc::pointer::block_pointer;
    use bee_rpc::skip::{skip_buffer, SkipFilter, StreamControl};
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Mutex};

    const ALG: HashAlgorithm = HashAlgorithm::Sha3_256;

    /// A Service whose filesystem is `fs` bytes, in pieces: what comes before the
    /// filesystem (its tag and length included), the filesystem, and what comes after.
    fn pieces(fs: usize, names: &[&str]) -> (Vec<u8>, Vec<u8>, Vec<u8>) {
        let mut svc = service(0, names);
        svc.container.as_mut().unwrap().filesystem = vec![0xAB; fs];
        let bytes = svc.encode_to_vec();
        let start = bytes.windows(8).position(|w| w == [0xAB; 8]).unwrap();
        (
            bytes[..start].to_vec(),
            bytes[start..start + fs].to_vec(),
            bytes[start + fs..].to_vec(),
        )
    }

    fn marker(id: &[u8]) -> Buffer {
        Buffer {
            block: Some(block_pointer(id, ALG, false)),
            ..Default::default()
        }
    }

    fn chunk(data: &[u8]) -> Buffer {
        Buffer {
            chunk: Some(data.to_vec()),
            ..Default::default()
        }
    }

    /// The Buffers of a Service part as nodo sends them: the filesystem in a block, with
    /// blocks of its own inside it.
    fn block_buffers(fs: usize, names: &[&str]) -> Vec<Buffer> {
        let (before, body, after) = pieces(fs, names);
        let top = ALG.digest(&body);
        let (left, right) = body.split_at(body.len() / 2);
        let (child_a, child_b) = (ALG.digest(left), ALG.digest(right));
        let mut out = vec![
            Buffer {
                head: head(SERVICE_INDEX),
                chunk: Some(before),
                ..Default::default()
            },
            marker(&top),
            marker(&child_a),
        ];
        out.extend(left.chunks(64 * 1024).map(chunk));
        out.push(marker(&child_a));
        out.push(marker(&child_b));
        out.extend(right.chunks(64 * 1024).map(chunk));
        out.push(marker(&child_b));
        out.push(marker(&top));
        out.push(chunk(&after));
        out.push(Buffer {
            separator: Some(true),
            ..Default::default()
        });
        out
    }

    /// A node that honours the skip requests, as the reference does: the stream is lazy, and
    /// each Buffer goes through the filter when it is asked for, so what the reader asked to
    /// skip is not sent. Gives the stream, the skipper, the ids that were asked and how many
    /// Buffers left the node.
    fn skipping_node(
        buffers: Vec<Buffer>,
    ) -> (Buffers, Skipper, Arc<Mutex<Vec<Vec<u8>>>>, Arc<AtomicUsize>) {
        let control = StreamControl::new(ALG);
        let asked = Arc::new(Mutex::new(Vec::new()));
        let sent = Arc::new(AtomicUsize::new(0));
        let (observe, record) = (control.clone(), asked.clone());
        let skipper: Skipper = Arc::new(move |id: &[u8]| {
            record.lock().unwrap().push(id.to_vec());
            observe.observe(&skip_buffer(id, ALG))
        });
        let filter = SkipFilter::new(control);
        let count = sent.clone();
        let stream = futures::stream::unfold(
            (buffers.into_iter(), filter),
            move |(mut rest, mut filter)| {
                let count = count.clone();
                async move {
                    for buffer in rest.by_ref() {
                        if let Some(out) = filter.push(buffer) {
                            count.fetch_add(1, Ordering::SeqCst);
                            return Some((Ok(out), (rest, filter)));
                        }
                    }
                    None
                }
            },
        );
        (Box::pin(stream), skipper, asked, sent)
    }

    #[tokio::test]
    async fn the_node_is_asked_to_skip_the_filesystem_and_the_rest_is_read() {
        let fs = 8 << 20;
        let buffers = block_buffers(fs, &["API_KEY", "MODE"]);
        let total = buffers.len();
        let top = ALG.digest(&pieces(fs, &["API_KEY", "MODE"]).1);
        let (stream, skipper, asked, sent) = skipping_node(buffers);
        let info = read_service_info(stream, None, Some(skipper))
            .await
            .unwrap();
        // Everything after the filesystem is read: the variables, the interface, the networks.
        assert!(!info.truncated);
        assert_eq!(info.filesystem_bytes, fs as u64);
        let names: Vec<_> = info.environment.iter().map(|d| d.name.as_str()).collect();
        assert_eq!(names, ["API_KEY", "MODE"]);
        assert_eq!(info.chat_ports(), vec![3030]);
        assert_eq!(info.networks.len(), 2);
        assert_eq!(info.workloads.len(), 1);
        // The request named the block of the filesystem, once, and the body did not come.
        assert_eq!(*asked.lock().unwrap(), vec![top]);
        assert_eq!(info.blocks_skipped, 1);
        let sent = sent.load(Ordering::SeqCst);
        assert!(sent < 10, "{sent} of {total} Buffers left the node");
    }

    #[tokio::test]
    async fn without_a_skipper_the_same_service_is_read_in_full() {
        let fs = 8 << 20;
        let buffers = block_buffers(fs, &["API_KEY"]);
        let total = buffers.len();
        let sent = Arc::new(AtomicUsize::new(0));
        let count = sent.clone();
        let stream: Buffers = Box::pin(tokio_stream::iter(buffers.into_iter().map(move |b| {
            count.fetch_add(1, Ordering::SeqCst);
            Ok(b)
        })));
        let info = read_service_info(stream, None, None).await.unwrap();
        assert_eq!(sent.load(Ordering::SeqCst), total);
        assert_eq!(info.blocks_skipped, 0);
        assert_eq!(info.filesystem_bytes, fs as u64);
        assert_eq!(info.environment.len(), 1);
        assert_eq!(info.chat_ports(), vec![3030]);
    }

    #[tokio::test]
    async fn a_node_that_refuses_the_request_gives_the_filesystem_and_the_result_is_the_same() {
        let fs = 4 << 20;
        let buffers = block_buffers(fs, &["API_KEY"]);
        let total = buffers.len();
        let sent = Arc::new(AtomicUsize::new(0));
        let count = sent.clone();
        let stream: Buffers = Box::pin(tokio_stream::iter(buffers.into_iter().map(move |b| {
            count.fetch_add(1, Ordering::SeqCst);
            Ok(b)
        })));
        let refusing: Skipper = Arc::new(|_: &[u8]| false);
        let info = read_service_info(stream, None, Some(refusing))
            .await
            .unwrap();
        assert_eq!(sent.load(Ordering::SeqCst), total);
        assert_eq!(info.blocks_skipped, 0);
        assert_eq!(info.environment.len(), 1);
        assert_eq!(info.chat_ports(), vec![3030]);
    }

    #[tokio::test]
    async fn a_large_field_that_is_not_a_block_is_read_and_the_node_is_not_asked() {
        // The same message with the filesystem inline, as `claude-code.bee` is not: no marker.
        let fs = 3 << 20;
        let (before, body, after) = pieces(fs, &["API_KEY"]);
        let mut parts = vec![Buffer {
            head: head(SERVICE_INDEX),
            chunk: Some(before),
            ..Default::default()
        }];
        parts.extend(body.chunks(1 << 20).map(chunk));
        parts.push(chunk(&after));
        parts.push(Buffer {
            separator: Some(true),
            ..Default::default()
        });
        let (stream, skipper, asked, _) = skipping_node(parts);
        let info = read_service_info(stream, None, Some(skipper))
            .await
            .unwrap();
        assert!(asked.lock().unwrap().is_empty());
        assert_eq!(info.blocks_skipped, 0);
        assert_eq!(info.environment.len(), 1);
        assert_eq!(info.chat_ports(), vec![3030]);
    }

    #[tokio::test]
    async fn a_small_field_is_never_asked_to_skip() {
        // Under a megabyte the bytes are cheaper than the request.
        let (before, body, after) = pieces(100_000, &["A"]);
        let top = ALG.digest(&body);
        let parts = vec![
            Buffer {
                head: head(SERVICE_INDEX),
                chunk: Some(before),
                ..Default::default()
            },
            marker(&top),
            chunk(&body),
            marker(&top),
            chunk(&after),
            Buffer {
                separator: Some(true),
                ..Default::default()
            },
        ];
        let (stream, skipper, asked, _) = skipping_node(parts);
        let info = read_service_info(stream, None, Some(skipper))
            .await
            .unwrap();
        assert!(asked.lock().unwrap().is_empty());
        assert_eq!(info.environment.len(), 1);
    }

    #[tokio::test]
    async fn blocks_that_were_open_when_the_request_arrived_close_with_the_skipped_one() {
        // The node sent the start of a child before it saw the request, and then dropped the
        // child, its end marker included, and sent only the end of the skipped block.
        let fs = 2 << 20;
        let (before, body, after) = pieces(fs, &["A", "B"]);
        let top = ALG.digest(&body);
        let child = ALG.digest(&body[..1000]);
        let parts = vec![
            Buffer {
                head: head(SERVICE_INDEX),
                chunk: Some(before),
                ..Default::default()
            },
            marker(&top),
            marker(&child),
            chunk(&body[..64 * 1024]),
            marker(&top),
            chunk(&after),
            Buffer {
                separator: Some(true),
                ..Default::default()
            },
        ];
        let ids = Arc::new(Mutex::new(Vec::new()));
        let record = ids.clone();
        let skipper: Skipper = Arc::new(move |id: &[u8]| {
            record.lock().unwrap().push(id.to_vec());
            true
        });
        let info = read_service_info(stream(parts), None, Some(skipper))
            .await
            .unwrap();
        assert_eq!(*ids.lock().unwrap(), vec![top]);
        assert_eq!(info.environment.len(), 2);
        assert_eq!(info.filesystem_bytes, fs as u64);
        assert_eq!(info.chat_ports(), vec![3030]);
    }

    #[tokio::test]
    async fn a_node_that_never_ends_the_block_is_a_cut_service() {
        let fs = 2 << 20;
        let (before, body, _) = pieces(fs, &[]);
        let top = ALG.digest(&body);
        let parts = vec![
            Buffer {
                head: head(SERVICE_INDEX),
                chunk: Some(before),
                ..Default::default()
            },
            marker(&top),
            chunk(&[1, 2, 3]),
            Buffer {
                separator: Some(true),
                ..Default::default()
            },
        ];
        let skipper: Skipper = Arc::new(|_: &[u8]| true);
        let err = read_service_info(stream(parts), None, Some(skipper))
            .await
            .unwrap_err();
        assert!(err.to_string().contains("cut"), "{err}");
    }
}
