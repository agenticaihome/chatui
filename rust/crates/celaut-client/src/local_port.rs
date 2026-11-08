//! A TCP port on 127.0.0.1 for one port of an instance.
//!
//! Each TCP connection to the local port opens one `ServiceTunnel` stream and relays
//! the bytes both ways. The node charges `TUNNEL_OPEN_MU` for each stream, so the
//! caller keeps its connections alive (HTTP keep-alive) and does not open one per
//! request. The stream opens with the first bytes of the connection, not with the
//! connection: a browser opens spare connections that never send, and those cost
//! nothing.
//!
//! The end of the data from the local connection half-closes the stream, and the end
//! of the stream closes the local connection. An error of the stream (for example a
//! refusal of the node) closes the local connection and is kept in
//! [`LocalPort::last_error`].
//!
//! The receipts of each stream go to the [`ReceiptSink`] of the port, if it has one.

use std::collections::VecDeque;
use std::net::{Ipv4Addr, SocketAddr};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use celaut_wire::tunnel::MAX_PAYLOAD;
use celaut_wire::{ReceiptSink, Tunnel, TunnelOpener};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio::task::{JoinHandle, JoinSet};

#[derive(Debug)]
struct Shared {
    streams: AtomicU64,
    /// The most streams that the port opens in all. `u64::MAX` is no limit.
    limit: AtomicU64,
    last_error: Mutex<Option<String>>,
}

/// What a local port limits. The default is the limit of a port to an instance: no limit
/// on the streams, and [`OPEN_RETRIES`] new tries for a stream that fails to open.
///
/// A port that spends MU the user did not confirm one by one (a tunnel to a descendant)
/// sets `max_streams` to what the confirmed budget pays for, and `retries` to 0: a try
/// again can open, and so charge, a stream that the user did not count.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PortLimits {
    /// The most streams that the port opens in all. A connection after it is closed with
    /// no stream and no cost.
    pub max_streams: Option<u64>,
    /// How many times a stream that failed to open is opened again.
    pub retries: u32,
}

impl Default for PortLimits {
    fn default() -> Self {
        PortLimits {
            max_streams: None,
            retries: OPEN_RETRIES,
        }
    }
}

/// What a connection needs to open its stream. The opener can be replaced while the port
/// stays (see [`LocalPort::set_opener`]).
struct Target {
    opener: Mutex<Arc<dyn TunnelOpener>>,
    token: String,
    slot: u16,
    receipts: Option<ReceiptSink>,
    retries: u32,
}

impl std::fmt::Debug for Target {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Target")
            .field("slot", &self.slot)
            .finish_non_exhaustive()
    }
}

impl Target {
    fn open(&self) -> Tunnel {
        let opener = self
            .opener
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone();
        opener.open_tunnel(&self.token, self.slot, self.receipts.clone())
    }
}

/// A local port for one slot of one instance. Dropping it closes the port and every
/// connection on it.
#[derive(Debug)]
pub struct LocalPort {
    port: u16,
    shared: Arc<Shared>,
    target: Arc<Target>,
    task: JoinHandle<()>,
}

impl LocalPort {
    /// Listen on `127.0.0.1` and a free port. The receipts of the streams go to
    /// `receipts`. Must be called inside a Tokio runtime.
    pub async fn bind(
        opener: Arc<dyn TunnelOpener>,
        token: String,
        slot: u16,
        receipts: Option<ReceiptSink>,
    ) -> std::io::Result<LocalPort> {
        Self::bind_preferred(opener, token, slot, receipts, None).await
    }

    /// Like [`LocalPort::bind`], but tries `preferred` first, and takes a free port if
    /// that one is taken. The same port each time keeps the origin of a web page (its
    /// cookies and its local storage) from one start to the next.
    pub async fn bind_preferred(
        opener: Arc<dyn TunnelOpener>,
        token: String,
        slot: u16,
        receipts: Option<ReceiptSink>,
        preferred: Option<u16>,
    ) -> std::io::Result<LocalPort> {
        Self::bind_limited(
            opener,
            token,
            slot,
            receipts,
            preferred,
            PortLimits::default(),
        )
        .await
    }

    /// Like [`LocalPort::bind_preferred`], with the [`PortLimits`] of the port.
    pub async fn bind_limited(
        opener: Arc<dyn TunnelOpener>,
        token: String,
        slot: u16,
        receipts: Option<ReceiptSink>,
        preferred: Option<u16>,
        limits: PortLimits,
    ) -> std::io::Result<LocalPort> {
        let listener = match preferred {
            Some(p) => match TcpListener::bind(SocketAddr::from((Ipv4Addr::LOCALHOST, p))).await {
                Ok(listener) => listener,
                Err(_) => TcpListener::bind(SocketAddr::from((Ipv4Addr::LOCALHOST, 0))).await?,
            },
            None => TcpListener::bind(SocketAddr::from((Ipv4Addr::LOCALHOST, 0))).await?,
        };
        let port = listener.local_addr()?.port();
        let shared = Arc::new(Shared {
            streams: AtomicU64::new(0),
            limit: AtomicU64::new(limits.max_streams.unwrap_or(u64::MAX)),
            last_error: Mutex::new(None),
        });
        let target = Arc::new(Target {
            opener: Mutex::new(opener),
            token,
            slot,
            receipts,
            retries: limits.retries,
        });
        let task = tokio::spawn(accept(listener, target.clone(), shared.clone()));
        Ok(LocalPort {
            port,
            shared,
            target,
            task,
        })
    }

    /// Open the next streams with `opener` (a new connection to the node, after the old
    /// one broke). The connections that are open keep their streams. The last error is
    /// cleared: it was of the old opener.
    pub fn set_opener(&self, opener: Arc<dyn TunnelOpener>) {
        *self.target.opener.lock().unwrap_or_else(|e| e.into_inner()) = opener;
        if let Ok(mut last) = self.shared.last_error.lock() {
            *last = None;
        }
    }

    /// Allow `more` streams after the ones that the port may open now. A port with no
    /// limit stays with no limit. Call it only after the user confirmed a budget for them.
    pub fn allow_streams(&self, more: u64) {
        update(&self.shared.limit, |limit| {
            (limit != u64::MAX).then(|| limit.saturating_add(more))
        });
    }

    /// False if the task of the port ended, so that the port accepts nothing.
    pub fn is_alive(&self) -> bool {
        !self.task.is_finished()
    }

    /// The local port.
    pub fn port(&self) -> u16 {
        self.port
    }

    /// How many `ServiceTunnel` streams this port opened: one per TCP connection.
    pub fn streams_opened(&self) -> u64 {
        self.shared.streams.load(Ordering::Relaxed)
    }

    /// The last error of a stream, if any.
    pub fn last_error(&self) -> Option<String> {
        self.shared.last_error.lock().ok().and_then(|e| e.clone())
    }
}

impl Drop for LocalPort {
    fn drop(&mut self) {
        // The connections are in the JoinSet of the task: they end with it.
        self.task.abort();
    }
}

async fn accept(listener: TcpListener, target: Arc<Target>, shared: Arc<Shared>) {
    let mut connections = JoinSet::new();
    loop {
        tokio::select! {
            accepted = listener.accept() => {
                let Ok((socket, _)) = accepted else {
                    // For example no file descriptors left: wait a little, do not spin.
                    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                    continue;
                };
                let _ = socket.set_nodelay(true);
                connections.spawn(relay(socket, target.clone(), shared.clone()));
            }
            // Collect the ended connections, so that the set does not grow.
            Some(_) = connections.join_next(), if !connections.is_empty() => {}
        }
    }
}

/// Set `counter` to `f(counter)` in one step, if `f` gives a value. Gives true if it did.
fn update(counter: &AtomicU64, f: impl Fn(u64) -> Option<u64>) -> bool {
    let mut current = counter.load(Ordering::SeqCst);
    loop {
        let Some(next) = f(current) else {
            return false;
        };
        match counter.compare_exchange_weak(current, next, Ordering::SeqCst, Ordering::SeqCst) {
            Ok(_) => return true,
            Err(seen) => current = seen,
        }
    }
}

/// Aborts a task when dropped.
struct AbortOnDrop(JoinHandle<()>);

impl Drop for AbortOnDrop {
    fn drop(&mut self) {
        self.0.abort();
    }
}

/// How many times a stream that failed to open is opened again.
const OPEN_RETRIES: u32 = 3;
/// The most bytes kept to send again to a new stream. A request longer than this (an
/// upload) is not sent again: its start is gone.
const REPLAY_LIMIT: usize = 1 << 20;

/// An error of the open of a stream that says nothing reached the service: no connection
/// to the node (a broken link, a circuit of Tor that died), or a time limit before the
/// node took the call. `celaut-wire` gives `Connect` also for an error of the call before
/// any byte of the request went out. An error of a stream that was open (`Unavailable`, a
/// transport error of the keepalive) is not one: the service may have the request and
/// still work on it, so it is not sent again. A refusal (wrong token, no balance) is not
/// one either: it would fail again.
fn is_transient(error: &celaut_wire::WireError) -> bool {
    use celaut_wire::WireError;
    matches!(error, WireError::Connect(_) | WireError::Timeout)
}

async fn relay(socket: TcpStream, target: Arc<Target>, shared: Arc<Shared>) {
    let (mut reader, mut writer) = socket.into_split();
    let mut buffer = vec![0u8; MAX_PAYLOAD];
    // The stream opens (and the node charges it) when the first bytes come. A connection
    // that closes before that never opens one.
    let first = match reader.read(&mut buffer).await {
        Ok(0) | Err(_) => return,
        Ok(n) => n,
    };
    let first_chunk = buffer[..first].to_vec();
    // The limit counts the streams that the port opens. A connection over it opens none.
    let counted = update(&shared.streams, |n| {
        (n < shared.limit.load(Ordering::SeqCst)).then(|| n + 1)
    });
    if !counted {
        if let Ok(mut last) = shared.last_error.lock() {
            *last = Some("the budget for the streams of this port is used up".into());
        }
        let _ = writer.shutdown().await;
        return;
    }
    let Tunnel {
        to_service,
        mut from_service,
    } = target.open();
    let mut to_service = Some(to_service);

    // The local reader feeds this channel, so that the loop below can open the stream
    // again (a node that cannot be reached right now) and send what was read.
    let (up_tx, mut up_rx) = mpsc::channel::<Vec<u8>>(4);
    // Aborted when the relay ends or is aborted (the port is dropped).
    let _up = AbortOnDrop(tokio::spawn(async move {
        loop {
            match reader.read(&mut buffer).await {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    if up_tx.send(buffer[..n].to_vec()).await.is_err() {
                        break;
                    }
                }
            }
        }
        // `up_tx` is dropped here: the end of the local data.
    }));

    // What waits to go to the stream.
    let mut queue: VecDeque<Vec<u8>> = VecDeque::new();
    queue.push_back(first_chunk);
    // What went since the stream opened, while no byte came back: to send again.
    let mut replay: Vec<Vec<u8>> = Vec::new();
    let mut replay_bytes = 0usize;
    let mut replayable = true;
    let mut local_ended = false;
    let mut answered = false;
    let mut retries = 0u32;

    loop {
        // The end of the local data half-closes the stream, once all has been sent.
        if local_ended && queue.is_empty() {
            to_service = None;
        }
        // A clone for the wait for room: the select must not borrow `to_service`.
        let room = to_service.clone().filter(|_| !queue.is_empty());
        let has_room = room.is_some();
        tokio::select! {
            chunk = up_rx.recv(), if !local_ended && queue.len() < 4 => match chunk {
                Some(chunk) => queue.push_back(chunk),
                None => local_ended = true,
            },
            permit = async {
                match room {
                    Some(room) => room.reserve_owned().await,
                    None => std::future::pending().await,
                }
            }, if has_room => {
                let Ok(permit) = permit else {
                    // The stream is closed: its error, if any, comes from the other side.
                    queue.clear();
                    to_service = None;
                    continue;
                };
                let chunk = queue.pop_front().unwrap_or_default();
                if !answered {
                    replay_bytes += chunk.len();
                    if replay_bytes > REPLAY_LIMIT {
                        replayable = false;
                        replay.clear();
                    } else {
                        replay.push(chunk.clone());
                    }
                }
                let _ = permit.send(chunk);
            }
            item = from_service.recv() => match item {
                Some(Ok(data)) => {
                    answered = true;
                    replay.clear();
                    if writer.write_all(&data).await.is_err() {
                        break;
                    }
                }
                Some(Err(e)) => {
                    if !answered && replayable && retries < target.retries && is_transient(&e) {
                        retries += 1;
                        // A short wait, longer each time: the link may be coming back.
                        tokio::time::sleep(std::time::Duration::from_millis(250 * u64::from(retries))).await;
                        let tunnel = target.open();
                        from_service = tunnel.from_service;
                        to_service = Some(tunnel.to_service);
                        // What was sent goes first, then what waited.
                        let mut again: VecDeque<Vec<u8>> = std::mem::take(&mut replay).into();
                        again.append(&mut queue);
                        queue = again;
                        replay_bytes = 0;
                        continue;
                    }
                    if let Ok(mut last) = shared.last_error.lock() {
                        *last = Some(e.to_string());
                    }
                    break;
                }
                None => break,
            },
        }
    }
    // The stream ended. The end of the relay stops the reading too, which closes the
    // local connection.
    let _ = writer.shutdown().await;
}
