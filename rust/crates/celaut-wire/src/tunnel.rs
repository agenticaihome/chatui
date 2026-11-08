//! `ServiceTunnel`: a byte stream to one port of an instance, through the node.
//!
//! The request is `TokenMessage{token, slot, receipts}` at index 1, then each payload at
//! index 0. A caller that holds the token of an ancestor can send a `DescendantTunnel`
//! at index 2 in place of it ([`TunnelOpener::open_descendant_tunnel`]). The answer is the bytes of the service at index 0 (`docs/celaut/wire.md`,
//! section 5), and the signed checkpoints of the execution receipt at index 2
//! (nodo#419). The end of the request (a half-close) closes the write side of the TCP
//! connection from the node to the service.
//!
//! The node charges the instance `TUNNEL_OPEN_MU` for each stream, and then for the
//! traffic. One stream carries one TCP connection.
//!
//! # Receipts
//!
//! The client always asks for receipts (`TokenMessage.receipts`), and it accepts index 2
//! also when it did not ask: a node can send receipts to every caller. Each message
//! that this side sends at index 0 is one event of the `in` chain, and each message
//! that it gets at index 0 is one event of the `out` chain ([`crate::receipt`]). The
//! client keeps both chains, and checks each checkpoint against them: the node must
//! sign the bytes that this side sent and got. The result goes to a [`ReceiptSink`].
//! A stream that this side cancels gets no `close`, and that is not a fault.

use std::collections::VecDeque;
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, PoisonError};

use bee_rpc::buffer::Buffer;
use bee_rpc::frame::{serialize_part, ParseOptions, Parser, Part};
use celaut_proto::celaut::{DescendantTunnel, ExecutionReceipt, TokenMessage};
use prost::Message;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tokio_stream::StreamExt;
use tonic::codegen::http::uri::PathAndQuery;

use crate::receipt::{self, Chain, Execution, DIRECTION_IN, DIRECTION_OUT, KIND_CLOSE};
use crate::{Connection, WireError};

/// How many messages wait in each direction before the sender waits.
const QUEUE: usize = 16;

/// The largest payload in one Buffer. Under the one-Buffer limit of bee-rpc (1 MiB).
pub const MAX_PAYLOAD: usize = 64 * 1024;

/// The index of the payloads.
const BYTES: i32 = 0;
/// The index of the handshake in the request: a `TokenMessage`.
const HANDSHAKE: i32 = 1;
/// The index of the handshake of a tunnel to a descendant: a `DescendantTunnel`.
const DESCENDANT_HANDSHAKE: i32 = 2;
/// The index of the receipts in the answer.
const RECEIPT: i32 = 2;

/// How many messages of one direction the client keeps the heads of, between two
/// checkpoints that match. The node signs a checkpoint every 1 MiB or 5 s of traffic, so
/// this is a limit for a node that does not. Past it, the client stops the check of the
/// chains of the stream (it does not call that a fault) and still checks the signatures.
const MAX_MARKS: usize = 1 << 16;

/// One receipt of a tunnel stream, and what this side found in it.
#[derive(Debug, Clone, PartialEq)]
pub struct StreamReceipt {
    pub receipt: ExecutionReceipt,
    /// Why the receipt is not valid ([`receipt::problems`] against the node of the
    /// connection and the token). Empty when it is valid.
    pub problems: Vec<String>,
    /// The faults of the order of the stream (a receipt after the close, a seq that does
    /// not go up, a change of session). The receipt can still be valid and signed, so
    /// these do not stop the storage of it.
    pub ordering: Vec<String>,
    /// The `in` chain of the receipt is not the chain of the messages that this side
    /// sent: the node signed data that this side did not send.
    pub sent_mismatch: bool,
    /// The `out` chain of the receipt is not the chain of the messages that this side
    /// got: the node signed data that this side did not get.
    pub got_mismatch: bool,
}

impl StreamReceipt {
    /// True if nothing is wrong with it.
    pub fn is_good(&self) -> bool {
        self.problems.is_empty()
            && self.ordering.is_empty()
            && !self.sent_mismatch
            && !self.got_mismatch
    }
}

/// What a tunnel tells its [`ReceiptSink`].
#[derive(Debug, Clone, PartialEq)]
pub enum ReceiptEvent {
    /// A checkpoint or the close of the stream, in the order of the stream.
    Receipt(StreamReceipt),
    /// The stream ended. `session` is the stream of the receipts, if one came. `closed`:
    /// a close came. `cancelled`: this side ended the stream (its reader went away);
    /// then the node sends no close, and that is not a fault.
    Ended {
        session: Option<String>,
        closed: bool,
        cancelled: bool,
    },
}

/// Gets the receipts of a tunnel. It is called from the task of the tunnel, so it must
/// not block for long.
pub type ReceiptSink = Arc<dyn Fn(ReceiptEvent) + Send + Sync>;

/// One open tunnel.
///
/// The call runs in a task of its own. It ends when the node ends the answer, when
/// [`Tunnel::from_service`] is dropped, or on an error. An error comes as the last item
/// of [`Tunnel::from_service`]. A refusal of the node (wrong token, a slot that the
/// instance does not have, no balance) comes that way too, because the node sends
/// nothing before the service sends bytes.
#[derive(Debug)]
pub struct Tunnel {
    /// Bytes to the service. Drop it to half-close.
    pub to_service: mpsc::Sender<Vec<u8>>,
    /// Bytes from the service.
    pub from_service: mpsc::Receiver<Result<Vec<u8>, WireError>>,
}

/// Opens tunnels. [`Connection`] opens them on the node; a test can replace it.
pub trait TunnelOpener: Send + Sync + 'static {
    /// Open a tunnel to port `slot` of the instance with `token`. The receipts of the
    /// stream go to `receipts`, if given. Must be called inside a Tokio runtime.
    fn open_tunnel(&self, token: &str, slot: u16, receipts: Option<ReceiptSink>) -> Tunnel;

    /// Open a tunnel to port `slot` of the descendant `instance_ref` of the instance with
    /// `token` (`DescendantTunnel`). The receipts of the stream go to `receipts`, if
    /// given: they name the execution by `instance_ref`. A node that does not know
    /// descendants makes the stream end with [`WireError::NoDescendants`].
    ///
    /// The default gives a tunnel that fails with [`WireError::NoDescendants`]. Must be
    /// called inside a Tokio runtime.
    fn open_descendant_tunnel(
        &self,
        token: &str,
        instance_ref: &str,
        slot: u16,
        remaining_hops: Option<u32>,
        receipts: Option<ReceiptSink>,
    ) -> Tunnel {
        let _ = (token, instance_ref, slot, remaining_hops, receipts);
        let (to_service, _) = mpsc::channel(1);
        let (from_tx, from_service) = mpsc::channel(1);
        let _ = from_tx.try_send(Err(WireError::NoDescendants));
        Tunnel {
            to_service,
            from_service,
        }
    }
}

impl TunnelOpener for Connection {
    fn open_tunnel(&self, token: &str, slot: u16, receipts: Option<ReceiptSink>) -> Tunnel {
        open(self.channel(), self.peer_id(), token, slot, receipts)
    }

    fn open_descendant_tunnel(
        &self,
        token: &str,
        instance_ref: &str,
        slot: u16,
        remaining_hops: Option<u32>,
        receipts: Option<ReceiptSink>,
    ) -> Tunnel {
        open_descendant(
            self.channel(),
            self.peer_id(),
            token,
            instance_ref,
            slot,
            remaining_hops,
            receipts,
        )
    }
}

/// Open a tunnel on `channel`, to a node with this `peer_id`: the receipts must be
/// signed by it. [`Connection`] gives both; a test gives its own channel.
pub fn open(
    channel: tonic::transport::Channel,
    peer_id: &str,
    token: &str,
    slot: u16,
    receipts: Option<ReceiptSink>,
) -> Tunnel {
    open_with(
        channel,
        peer_id,
        Handshake::Token(handshake(token, slot)),
        receipts,
    )
}

/// [`open`] for a descendant: the first message is a [`DescendantTunnel`] at index 2.
/// The receipts must carry the name that [`receipt::execution_name_by_ref`] gives.
pub fn open_descendant(
    channel: tonic::transport::Channel,
    peer_id: &str,
    token: &str,
    instance_ref: &str,
    slot: u16,
    remaining_hops: Option<u32>,
    receipts: Option<ReceiptSink>,
) -> Tunnel {
    open_with(
        channel,
        peer_id,
        Handshake::Descendant(descendant_handshake(
            token,
            instance_ref,
            slot,
            remaining_hops,
        )),
        receipts,
    )
}

fn open_with(
    channel: tonic::transport::Channel,
    peer_id: &str,
    handshake: Handshake,
    receipts: Option<ReceiptSink>,
) -> Tunnel {
    let (to_service, to_rx) = mpsc::channel(QUEUE);
    let (from_tx, from_service) = mpsc::channel(QUEUE);
    // With no sink, nobody reads the receipts: the chains are not computed.
    let checker = receipts
        .as_ref()
        .map(|_| Arc::new(Mutex::new(Checker::new(peer_id, handshake.execution()))));
    tokio::spawn(async move {
        let cancelled = match run(
            channel,
            handshake,
            to_rx,
            &from_tx,
            checker.as_ref(),
            receipts.as_ref(),
        )
        .await
        {
            Ok(cancelled) => cancelled,
            Err(e) => {
                let _ = from_tx.send(Err(e)).await;
                false
            }
        };
        if let (Some(sink), Some(checker)) = (&receipts, &checker) {
            // The stream ended: a checkpoint that is still ahead of the chains is a
            // mismatch now.
            let (last, session, closed) = {
                let mut checker = lock(checker);
                (checker.finish(), checker.session.clone(), checker.closed)
            };
            for checked in last {
                sink(ReceiptEvent::Receipt(checked));
            }
            sink(ReceiptEvent::Ended {
                session,
                closed,
                cancelled,
            });
        }
    });
    Tunnel {
        to_service,
        from_service,
    }
}

/// The handshake of a tunnel: the token, the slot, and the receipts, which the client
/// always asks for.
pub fn handshake(token: &str, slot: u16) -> TokenMessage {
    TokenMessage {
        token: token.to_string(),
        slot: Some(slot.to_string()),
        receipts: true,
    }
}

/// The handshake of a tunnel to a descendant: the token of the ancestor, the descendant,
/// the slot, and the receipts, which the client always asks for. `remaining_hops` is the
/// hop budget: with `None` the node uses its own maximum.
pub fn descendant_handshake(
    token: &str,
    instance_ref: &str,
    slot: u16,
    remaining_hops: Option<u32>,
) -> DescendantTunnel {
    DescendantTunnel {
        token: token.to_string(),
        instance_ref: instance_ref.to_string(),
        slot: slot.to_string(),
        receipts: true,
        remaining_hops,
    }
}

/// The first message of a tunnel.
#[derive(Debug, Clone, PartialEq)]
pub enum Handshake {
    /// A `TokenMessage` at index 1: an instance that the caller holds.
    Token(TokenMessage),
    /// A `DescendantTunnel` at index 2: a descendant of such an instance.
    Descendant(DescendantTunnel),
}

impl Handshake {
    fn index(&self) -> i32 {
        match self {
            Handshake::Token(_) => HANDSHAKE,
            Handshake::Descendant(_) => DESCENDANT_HANDSHAKE,
        }
    }

    fn encode(&self) -> Vec<u8> {
        match self {
            Handshake::Token(m) => m.encode_to_vec(),
            Handshake::Descendant(m) => m.encode_to_vec(),
        }
    }

    /// How the receipts of the stream name the execution.
    fn execution(&self) -> ExecutionKey {
        match self {
            Handshake::Token(m) => ExecutionKey::Token(m.token.clone()),
            Handshake::Descendant(m) => ExecutionKey::InstanceRef(m.instance_ref.clone()),
        }
    }

    fn is_descendant(&self) -> bool {
        matches!(self, Handshake::Descendant(_))
    }
}

/// The owned form of [`Execution`].
#[derive(Debug, Clone)]
enum ExecutionKey {
    Token(String),
    InstanceRef(String),
}

impl ExecutionKey {
    fn as_execution(&self) -> Execution<'_> {
        match self {
            ExecutionKey::Token(t) => Execution::Token(t),
            ExecutionKey::InstanceRef(r) => Execution::InstanceRef(r),
        }
    }
}

/// The result of the check of one checkpoint against one chain.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Match {
    Yes,
    No,
    /// The checkpoint counts more messages than this side has seen. It can catch up.
    Ahead,
}

/// The messages of one direction as this side saw them: the chain, and its state after
/// each message since the last checkpoint that matched.
#[derive(Debug)]
struct Seen {
    direction: &'static str,
    chain: Chain,
    /// `(events, bytes, head)` at the last checkpoint that matched, then after each
    /// message.
    marks: VecDeque<(u64, u64, [u8; 32])>,
    /// True after more than [`MAX_MARKS`] messages with no checkpoint: the chains of the
    /// stream are not checked any more.
    unchecked: bool,
}

/// A head of a chain as 32 bytes. `None` if the text is not 64 hex digits.
fn head_bytes(head: &str) -> Option<[u8; 32]> {
    let mut out = [0u8; 32];
    hex::decode_to_slice(head, &mut out).ok()?;
    Some(out)
}

impl Seen {
    fn new(direction: &'static str) -> Self {
        let chain = Chain::default();
        let genesis = head_bytes(&chain.head).unwrap_or_default();
        Seen {
            direction,
            marks: VecDeque::from([(0, 0, genesis)]),
            chain,
            unchecked: false,
        }
    }

    fn push(&mut self, payload: &[u8]) {
        self.chain.push(self.direction, payload);
        if self.unchecked {
            return;
        }
        if self.marks.len() > MAX_MARKS {
            self.unchecked = true;
            self.marks.clear();
            return;
        }
        let c = &self.chain;
        let head = head_bytes(&c.head).unwrap_or_default();
        self.marks.push_back((c.events, c.bytes, head));
    }

    /// Whether the node's `(events, bytes, head)` is a state of this chain. On a match,
    /// the states before it are dropped: the next checkpoint counts at least as many.
    fn matches(&mut self, events: u64, bytes: u64, head: &str) -> Match {
        if self.unchecked {
            return Match::Yes;
        }
        let Some(first) = self.marks.front().map(|m| m.0) else {
            return Match::Yes;
        };
        let Some(index) = events
            .checked_sub(first)
            .and_then(|i| usize::try_from(i).ok())
        else {
            return Match::No;
        };
        let Some((_, b, h)) = self.marks.get(index) else {
            return Match::Ahead;
        };
        if *b != bytes || head_bytes(head).as_ref() != Some(h) {
            return Match::No;
        }
        self.marks.drain(..index);
        Match::Yes
    }
}

/// A checkpoint that waits for the chains of this side to catch up with it.
#[derive(Debug)]
struct Waiting {
    checked: StreamReceipt,
    /// `(events, bytes, head)` of the `in` and `out` chains of the receipt. `None` when
    /// the receipt has no chain check (it failed the check of the signature).
    counters: Option<([u64; 2], [u64; 2], [String; 2])>,
    sent: Option<bool>,
    got: Option<bool>,
}

/// Checks the receipts of one stream against what this side sent and got.
///
/// A checkpoint that counts more messages than this side has seen waits. The checkers
/// give the receipts in the order of the stream, so a receipt waits behind the ones
/// before it.
#[derive(Debug)]
struct Checker {
    peer_id: String,
    execution: ExecutionKey,
    sent: Seen,
    got: Seen,
    session: Option<String>,
    last_seq: u64,
    closed: bool,
    waiting: VecDeque<Waiting>,
}

impl Checker {
    fn new(peer_id: &str, execution: ExecutionKey) -> Self {
        Checker {
            peer_id: peer_id.to_string(),
            execution,
            sent: Seen::new(DIRECTION_IN),
            got: Seen::new(DIRECTION_OUT),
            session: None,
            last_seq: 0,
            closed: false,
            waiting: VecDeque::new(),
        }
    }

    /// Check one receipt. Gives the receipts that are ready, in order.
    fn check(&mut self, receipt: ExecutionReceipt) -> Vec<StreamReceipt> {
        let waiting = self.examine(receipt);
        self.waiting.push_back(waiting);
        self.ready()
    }

    fn examine(&mut self, receipt: ExecutionReceipt) -> Waiting {
        let mut problems = receipt::problems_named(
            &receipt,
            Some(&self.peer_id),
            Some(self.execution.as_execution()),
        );
        if problems.is_empty() && receipt.kind == receipt::KIND_START {
            problems.push("a start receipt in a tunnel stream".into());
        }
        if !problems.is_empty() {
            // Not signed by the node, or not for this token: its counters say nothing.
            return Waiting {
                checked: StreamReceipt {
                    receipt,
                    problems,
                    ordering: vec![],
                    sent_mismatch: false,
                    got_mismatch: false,
                },
                counters: None,
                sent: Some(false),
                got: Some(false),
            };
        }
        let mut ordering = Vec::new();
        if self.closed {
            ordering.push("a receipt after the close of the stream".into());
        }
        match &self.session {
            Some(session) if *session != receipt.session => {
                ordering.push("the session of the stream changes".into());
            }
            Some(_) => {}
            None => self.session = Some(receipt.session.clone()),
        }
        if receipt.seq <= self.last_seq {
            ordering.push(format!(
                "seq {} does not come after seq {}",
                receipt.seq, self.last_seq
            ));
        }
        self.last_seq = self.last_seq.max(receipt.seq);
        if receipt.kind == KIND_CLOSE {
            self.closed = true;
        }
        let counters = (
            [receipt.in_events, receipt.out_events],
            [receipt.in_bytes, receipt.out_bytes],
            [receipt.in_head.clone(), receipt.out_head.clone()],
        );
        Waiting {
            checked: StreamReceipt {
                receipt,
                problems,
                ordering,
                sent_mismatch: false,
                got_mismatch: false,
            },
            counters: Some(counters),
            sent: None,
            got: None,
        }
    }

    /// Check again the checkpoints that wait, and give the ones that are done.
    fn ready(&mut self) -> Vec<StreamReceipt> {
        let mut done = Vec::new();
        while let Some(front) = self.waiting.front_mut() {
            if let Some(([ie, oe], [ib, ob], [ih, oh])) = &front.counters {
                if front.sent.is_none() {
                    front.sent = match self.sent.matches(*ie, *ib, ih) {
                        Match::Yes => Some(false),
                        Match::No => Some(true),
                        Match::Ahead => None,
                    };
                }
                if front.got.is_none() {
                    front.got = match self.got.matches(*oe, *ob, oh) {
                        Match::Yes => Some(false),
                        Match::No => Some(true),
                        Match::Ahead => None,
                    };
                }
            }
            let (Some(sent), Some(got)) = (front.sent, front.got) else {
                break;
            };
            let Some(mut item) = self.waiting.pop_front() else {
                break;
            };
            item.checked.sent_mismatch = sent;
            item.checked.got_mismatch = got;
            done.push(item.checked);
        }
        done
    }

    /// The stream ended: a checkpoint that is still ahead is a mismatch.
    fn finish(&mut self) -> Vec<StreamReceipt> {
        let mut done = self.ready();
        for mut item in self.waiting.drain(..) {
            let (sent, got) = match &item.counters {
                Some(([ie, oe], [ib, ob], [ih, oh])) => (
                    item.sent
                        .unwrap_or_else(|| self.sent.matches(*ie, *ib, ih) != Match::Yes),
                    item.got
                        .unwrap_or_else(|| self.got.matches(*oe, *ob, oh) != Match::Yes),
                ),
                None => (false, false),
            };
            item.checked.sent_mismatch = sent;
            item.checked.got_mismatch = got;
            done.push(item.checked);
        }
        done
    }
}

fn lock(checker: &Mutex<Checker>) -> std::sync::MutexGuard<'_, Checker> {
    checker.lock().unwrap_or_else(PoisonError::into_inner)
}

/// Check the chains of a stream. Does nothing when there is no checker.
fn track(checker: Option<&Arc<Mutex<Checker>>>, f: impl FnOnce(&mut Checker)) {
    if let Some(checker) = checker {
        f(&mut lock(checker));
    }
}

/// The Buffers of the request: the handshake, then the payloads. Empty payloads are not
/// sent (a receiver drops a part with no bytes).
pub fn request_buffers(handshake: &TokenMessage, payloads: &[Vec<u8>]) -> Vec<Buffer> {
    request_buffers_for(&Handshake::Token(handshake.clone()), payloads)
}

/// [`request_buffers`] for any handshake.
pub fn request_buffers_for(handshake: &Handshake, payloads: &[Vec<u8>]) -> Vec<Buffer> {
    let mut out: Vec<Buffer> =
        serialize_part(&Part::new(handshake.index(), handshake.encode())).collect();
    for payload in payloads {
        for piece in payload.chunks(MAX_PAYLOAD) {
            out.extend(piece_buffers(piece));
        }
    }
    out
}

/// The Buffers of one message at index 0. The node sees one message, which is one event
/// of the `in` chain.
fn piece_buffers(piece: &[u8]) -> Vec<Buffer> {
    serialize_part(&Part::new(BYTES, piece.to_vec())).collect()
}

/// Ends the task that sends the request when the call ends.
struct AbortOnDrop(tokio::task::JoinHandle<()>);

impl Drop for AbortOnDrop {
    fn drop(&mut self) {
        self.0.abort();
    }
}

fn status(e: tonic::Status) -> WireError {
    WireError::Call(format!("{:?}: {}", e.code(), e.message()))
}

/// The error for a refusal that came before the first byte of a stream that started with a
/// `DescendantTunnel`. A node with descendants refuses with one of four codes, and each
/// keeps its meaning ([`status`]). Another code, with no transport error under it, is
/// what a node that does not know index 2 gives: [`WireError::NoDescendants`]. This rule
/// is a guess that no node confirmed (`docs/celaut/descendants.md`, section 9).
pub fn descendant_refusal(e: &tonic::Status) -> WireError {
    use std::error::Error;
    use tonic::Code;
    let known = matches!(
        e.code(),
        Code::PermissionDenied
            | Code::ResourceExhausted
            | Code::Unavailable
            | Code::InvalidArgument
    );
    // A time limit and a cancel are not a refusal. A status with a source error comes
    // from the transport (a reset connection), not from the node.
    let not_a_refusal = matches!(
        e.code(),
        Code::Cancelled | Code::DeadlineExceeded | Code::Ok
    ) || e.source().is_some();
    if known || not_a_refusal {
        status(e.clone())
    } else {
        WireError::NoDescendants
    }
}

/// The call. Gives true if it ended because the reader went away (a cancel).
async fn run(
    channel: tonic::transport::Channel,
    handshake: Handshake,
    mut to_rx: mpsc::Receiver<Vec<u8>>,
    from_tx: &mpsc::Sender<Result<Vec<u8>, WireError>>,
    checker: Option<&Arc<Mutex<Checker>>>,
    sink: Option<&ReceiptSink>,
) -> Result<bool, WireError> {
    let (buffer_tx, buffer_rx) = mpsc::channel::<Buffer>(QUEUE);
    let descendant = handshake.is_descendant();
    for buffer in request_buffers_for(&handshake, &[]) {
        buffer_tx
            .send(buffer)
            .await
            .map_err(|_| WireError::Call("the tunnel closed".to_string()))?;
    }
    let sent = checker.cloned();
    let sender = tokio::spawn(async move {
        while let Some(payload) = to_rx.recv().await {
            for piece in payload.chunks(MAX_PAYLOAD) {
                // Into the chain before it goes: a checkpoint never counts a message
                // that this side has not counted yet.
                track(sent.as_ref(), |c| c.sent.push(piece));
                for buffer in piece_buffers(piece) {
                    if buffer_tx.send(buffer).await.is_err() {
                        return;
                    }
                }
            }
        }
        // `buffer_tx` is dropped here: the request ends (half-close).
    });
    let _sender = AbortOnDrop(sender);

    let path = PathAndQuery::from_str("/celaut.Gateway/ServiceTunnel")
        .map_err(|e| WireError::Call(e.to_string()))?;
    let mut client = tonic::client::Grpc::new(channel);
    client
        .ready()
        .await
        .map_err(|e| WireError::Connect(e.to_string()))?;
    let codec = tonic_prost::ProstCodec::<Buffer, Buffer>::default();
    // Set when the transport takes the first Buffer of the request: from then on the node
    // may have got bytes, and an error is not an open that failed.
    let started = Arc::new(AtomicBool::new(false));
    let flag = started.clone();
    let body = ReceiverStream::new(buffer_rx).map(move |buffer| {
        flag.store(true, Ordering::SeqCst);
        buffer
    });
    let mut response = client
        .streaming(tonic::Request::new(body), path, codec)
        .await
        .map_err(|e| {
            // A link that failed before any byte of the request went out: the stream did
            // not open. A refusal of the node (another code) stays a call error.
            if !started.load(Ordering::SeqCst) && e.code() == tonic::Code::Unavailable {
                WireError::Connect(format!("{:?}: {}", e.code(), e.message()))
            } else if descendant {
                descendant_refusal(&e)
            } else {
                status(e)
            }
        })?
        .into_inner();

    // Index 2 is accepted also when the client did not ask for it: a bee-rpc reader
    // refuses an index that it does not know, and the node can send receipts to all.
    let mut parser = Parser::new(ParseOptions::accepting([BYTES, RECEIPT]));
    // True after the first message of the answer: a refusal comes before it.
    let mut answered = false;
    loop {
        let message = tokio::select! {
            message = response.message() => message.map_err(|e| {
                if descendant && !answered {
                    descendant_refusal(&e)
                } else {
                    status(e)
                }
            })?,
            // The reader is gone: dropping the response cancels the call.
            _ = from_tx.closed() => return Ok(true),
        };
        let Some(buffer) = message else { break };
        let first = !answered;
        answered = true;
        let parts = parser.push(buffer).map_err(|e| {
            if descendant && first {
                // An answer that cannot be framed, before any byte.
                WireError::NoDescendants
            } else {
                WireError::Protocol(e.to_string())
            }
        })?;
        if !forward(parts, from_tx, checker, sink).await {
            return Ok(true);
        }
    }
    let parts = parser
        .finish()
        .map_err(|e| WireError::Protocol(e.to_string()))?;
    if !forward(parts, from_tx, checker, sink).await {
        return Ok(true);
    }
    Ok(false)
}

fn emit(sink: Option<&ReceiptSink>, receipts: Vec<StreamReceipt>) {
    if let Some(sink) = sink {
        for checked in receipts {
            sink(ReceiptEvent::Receipt(checked));
        }
    }
}

/// Send the bytes of the parts to the reader, and the receipts to the sink. False when
/// the reader is gone.
async fn forward(
    parts: Vec<Part>,
    to: &mpsc::Sender<Result<Vec<u8>, WireError>>,
    checker: Option<&Arc<Mutex<Checker>>>,
    sink: Option<&ReceiptSink>,
) -> bool {
    for part in parts {
        match part.index {
            BYTES => {
                // Every message that the parser gives is an event of the chain. A
                // checkpoint that counts more waits until this side catches up.
                let ready = checker.map(|checker| {
                    let mut c = lock(checker);
                    c.got.push(&part.data);
                    c.ready()
                });
                emit(sink, ready.unwrap_or_default());
                if !part.data.is_empty() && to.send(Ok(part.data)).await.is_err() {
                    return false;
                }
            }
            RECEIPT => {
                let ready = match ExecutionReceipt::decode(part.data.as_slice()) {
                    Ok(r) => match checker {
                        Some(checker) => lock(checker).check(r),
                        None => vec![],
                    },
                    Err(e) => vec![StreamReceipt {
                        receipt: ExecutionReceipt::default(),
                        problems: vec![format!("cannot read a receipt: {e}")],
                        ordering: vec![],
                        sent_mismatch: false,
                        got_mismatch: false,
                    }],
                };
                emit(sink, ready);
            }
            _ => {}
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_handshake_comes_first_then_the_payloads_at_index_0() {
        let handshake = handshake("tok", 8080);
        assert!(handshake.receipts);
        let big = vec![7u8; MAX_PAYLOAD + 10];
        let buffers = request_buffers(
            &handshake,
            &[b"GET / HTTP/1.1\r\n\r\n".to_vec(), vec![], big],
        );
        let indices: Vec<i32> = buffers
            .iter()
            .map(|b| b.head.as_ref().map(|h| h.index).unwrap())
            .collect();
        // The empty payload is not sent; the big one is two Buffers.
        assert_eq!(indices, vec![1, 0, 0, 0]);
        let first = TokenMessage::decode(buffers[0].chunk.as_deref().unwrap()).unwrap();
        assert_eq!(first, handshake);
        assert!(buffers.iter().all(|b| b.separator == Some(true)));
        assert_eq!(buffers[3].chunk.as_ref().unwrap().len(), 10);
    }

    fn waiting_for(chain: &Chain, in_chain: &Chain) -> Waiting {
        Waiting {
            checked: StreamReceipt {
                receipt: ExecutionReceipt::default(),
                problems: vec![],
                ordering: vec![],
                sent_mismatch: false,
                got_mismatch: false,
            },
            counters: Some((
                [in_chain.events, chain.events],
                [in_chain.bytes, chain.bytes],
                [in_chain.head.clone(), chain.head.clone()],
            )),
            sent: None,
            got: None,
        }
    }

    #[test]
    fn a_checkpoint_ahead_of_the_client_waits_until_the_client_catches_up() {
        let mut checker = Checker::new("peer", ExecutionKey::Token("tok".into()));
        let in_chain = Chain::default();
        let out = receipt::replay_chain([b"one".as_slice(), b"two".as_slice()], DIRECTION_OUT);
        checker.waiting.push_back(waiting_for(&out, &in_chain));
        // The client has seen nothing yet: the checkpoint waits, it is not a mismatch.
        assert!(checker.ready().is_empty());
        checker.got.push(b"one");
        assert!(checker.ready().is_empty());
        checker.got.push(b"two");
        let done = checker.ready();
        assert_eq!(done.len(), 1);
        assert!(!done[0].got_mismatch && !done[0].sent_mismatch);
    }

    #[test]
    fn a_checkpoint_that_stays_ahead_is_a_mismatch_when_the_stream_ends() {
        let mut checker = Checker::new("peer", ExecutionKey::Token("tok".into()));
        let out = receipt::replay_chain([b"one".as_slice(), b"two".as_slice()], DIRECTION_OUT);
        checker
            .waiting
            .push_back(waiting_for(&out, &Chain::default()));
        checker.got.push(b"one");
        assert!(checker.ready().is_empty());
        let done = checker.finish();
        assert_eq!(done.len(), 1);
        assert!(done[0].got_mismatch && !done[0].sent_mismatch);
    }

    #[test]
    fn a_checkpoint_with_another_head_is_a_mismatch_at_once() {
        let mut checker = Checker::new("peer", ExecutionKey::Token("tok".into()));
        let out = receipt::replay_chain([b"zzz".as_slice()], DIRECTION_OUT);
        checker
            .waiting
            .push_back(waiting_for(&out, &Chain::default()));
        checker.got.push(b"one");
        let done = checker.ready();
        assert_eq!(done.len(), 1);
        assert!(done[0].got_mismatch);
    }
}
