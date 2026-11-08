//! A `DescendantTunnel` stream (nodo#631), against an in-process gRPC server.
//!
//! The honest node reads the handshake at index 2, echoes each message, and signs
//! checkpoints that name the execution by the `instance_ref`. The tests also check what
//! the client sends, a node that names the execution by a token, the refusals that keep
//! their meaning, and a node that does not know index 2.

use std::convert::Infallible;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};
use std::time::Duration;

use bee_rpc::buffer::Buffer;
use bee_rpc::frame::{serialize_part, ParseOptions, Parser, Part};
use celaut_proto::celaut::{Amount, DescendantTunnel, ExecutionReceipt};
use celaut_wire::receipt::{self, Chain, DIRECTION_IN, DIRECTION_OUT};
use celaut_wire::tunnel::open_descendant;
use celaut_wire::{ReceiptEvent, ReceiptSink, StreamReceipt, WireError};
use prost::Message;
use tokio::sync::mpsc;
use tokio_stream::wrappers::{ReceiverStream, TcpListenerStream};
use tokio_stream::Stream;
use tonic::codegen::{http, Body, BoxFuture, Service, StdError};
use tonic::{Status, Streaming};

const KEY: [u8; 32] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
    26, 27, 28, 29, 30, 31,
];
const PEER_ID: &str = "03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8";
const TOKEN: &str = "parent-token-1";
// instance_ref("child-token-1"), from docs/celaut/descendants.md, section 10.
const CHILD: &str = "407e5db0b61e39e7eeeef075270dbf0d1f60f8cb6f9a56493fca5a6f464cfa61";
const SESSION: &str = "00112233445566778899aabbccddeeff";

type Reply = Pin<Box<dyn Stream<Item = Result<Buffer, Status>> + Send>>;

#[derive(Debug, Clone, Copy, PartialEq)]
enum Node {
    /// Echoes, and names the execution by the instance_ref.
    Honest,
    /// Echoes, and names the execution by a token, as a plain tunnel does.
    NamesByToken,
    /// Refuses with this code before any byte.
    Refuses(tonic::Code),
}

fn part(index: i32, data: Vec<u8>) -> Vec<Buffer> {
    serialize_part(&Part::new(index, data)).collect()
}

fn receipt(kind: &str, seq: u64, by_token: bool, ins: &Chain, outs: &Chain) -> Vec<Buffer> {
    let name = if by_token {
        receipt::execution_name(TOKEN, PEER_ID)
    } else {
        receipt::execution_name_by_ref(CHILD, PEER_ID)
    };
    let mut r = ExecutionReceipt {
        kind: kind.into(),
        execution_name: name.unwrap(),
        ts: 1798329600,
        plane: receipt::PLANE_TUNNEL.into(),
        session: SESSION.into(),
        slot: "8080".into(),
        seq,
        in_events: ins.events,
        in_bytes: ins.bytes,
        in_head: ins.head.clone(),
        out_events: outs.events,
        out_bytes: outs.bytes,
        out_head: outs.head.clone(),
        mu_charged: Some(Amount { n: "10000".into() }),
        coverage: receipt::COVERAGE_CLIENT_TUNNEL.into(),
        ..Default::default()
    };
    receipt::sign_with_seed(&mut r, &KEY).unwrap();
    part(2, r.encode_to_vec())
}

type Seen = Arc<Mutex<Option<DescendantTunnel>>>;

async fn node(
    kind: Node,
    mut request: Streaming<Buffer>,
    tx: mpsc::Sender<Result<Buffer, Status>>,
    seen: Seen,
) {
    // The handshake is index 2: a plain tunnel reader would refuse it.
    let mut parser = Parser::new(ParseOptions::accepting([0, 2]));
    let (mut ins, mut outs, mut seq) = (Chain::default(), Chain::default(), 0);
    let by_token = kind == Node::NamesByToken;
    while let Ok(Some(buffer)) = request.message().await {
        for p in parser.push(buffer).unwrap() {
            if p.index == 2 {
                *seen.lock().unwrap() = Some(DescendantTunnel::decode(p.data.as_slice()).unwrap());
                continue;
            }
            ins.push(DIRECTION_IN, &p.data);
            outs.push(DIRECTION_OUT, &p.data);
            seq += 1;
            let mut out = part(0, p.data.clone());
            out.extend(receipt(
                receipt::KIND_CHECKPOINT,
                seq,
                by_token,
                &ins,
                &outs,
            ));
            for b in out {
                if tx.send(Ok(b)).await.is_err() {
                    return;
                }
            }
        }
    }
    for b in receipt(receipt::KIND_CLOSE, seq + 1, by_token, &ins, &outs) {
        let _ = tx.send(Ok(b)).await;
    }
}

#[derive(Clone)]
struct Server(Node, Seen);

impl tonic::server::NamedService for Server {
    const NAME: &'static str = "celaut.Gateway";
}

struct Method(Node, Seen);

impl tonic::server::StreamingService<Buffer> for Method {
    type Response = Buffer;
    type ResponseStream = Reply;
    type Future = BoxFuture<tonic::Response<Reply>, Status>;

    fn call(&mut self, request: tonic::Request<Streaming<Buffer>>) -> Self::Future {
        if let Node::Refuses(code) = self.0 {
            return Box::pin(async move { Err(Status::new(code, "refused")) });
        }
        let (tx, rx) = mpsc::channel(64);
        tokio::spawn(node(self.0, request.into_inner(), tx, self.1.clone()));
        let reply: Reply = Box::pin(ReceiverStream::new(rx));
        Box::pin(async move { Ok(tonic::Response::new(reply)) })
    }
}

impl<B> Service<http::Request<B>> for Server
where
    B: Body + Send + 'static,
    B::Error: Into<StdError> + Send + 'static,
{
    type Response = http::Response<tonic::body::Body>;
    type Error = Infallible;
    type Future = BoxFuture<Self::Response, Self::Error>;

    fn poll_ready(&mut self, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        Poll::Ready(Ok(()))
    }

    fn call(&mut self, request: http::Request<B>) -> Self::Future {
        let (kind, seen) = (self.0, self.1.clone());
        Box::pin(async move {
            let codec = tonic_prost::ProstCodec::<Buffer, Buffer>::default();
            let mut grpc = tonic::server::Grpc::new(codec);
            Ok(grpc.streaming(Method(kind, seen), request).await)
        })
    }
}

async fn serve(kind: Node) -> (tonic::transport::Channel, Seen) {
    let seen = Arc::new(Mutex::new(None));
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(
        tonic::transport::Server::builder()
            .add_service(Server(kind, seen.clone()))
            .serve_with_incoming(TcpListenerStream::new(listener)),
    );
    let channel = tonic::transport::Endpoint::from_shared(format!("http://{addr}"))
        .unwrap()
        .connect()
        .await
        .unwrap();
    (channel, seen)
}

fn sink() -> (ReceiptSink, Arc<Mutex<Vec<ReceiptEvent>>>) {
    let events = Arc::new(Mutex::new(Vec::new()));
    let kept = events.clone();
    (Arc::new(move |e| kept.lock().unwrap().push(e)), events)
}

async fn ended(events: &Arc<Mutex<Vec<ReceiptEvent>>>) -> Vec<StreamReceipt> {
    for _ in 0..500 {
        {
            let events = events.lock().unwrap();
            if matches!(events.last(), Some(ReceiptEvent::Ended { .. })) {
                return events
                    .iter()
                    .filter_map(|e| match e {
                        ReceiptEvent::Receipt(r) => Some(r.clone()),
                        ReceiptEvent::Ended { .. } => None,
                    })
                    .collect();
            }
        }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }
    panic!("the stream did not end");
}

/// Send `messages`, half-close, and read to the end. The last item is the error, if any.
async fn exchange(
    kind: Node,
    messages: &[&[u8]],
    hops: Option<u32>,
    sink: Option<ReceiptSink>,
) -> (Vec<u8>, Option<WireError>, Seen) {
    let (channel, seen) = serve(kind).await;
    let mut tunnel = open_descendant(channel, PEER_ID, TOKEN, CHILD, 8080, hops, sink);
    for m in messages {
        let _ = tunnel.to_service.send(m.to_vec()).await;
    }
    drop(tunnel.to_service);
    let (mut got, mut error) = (Vec::new(), None);
    while let Some(item) = tunnel.from_service.recv().await {
        match item {
            Ok(bytes) => got.extend(bytes),
            Err(e) => error = Some(e),
        }
    }
    (got, error, seen)
}

#[tokio::test]
async fn the_handshake_is_a_descendant_tunnel_at_index_2() {
    let (got, error, seen) = exchange(Node::Honest, &[b"hello"], Some(5), None).await;
    assert!(error.is_none(), "{error:?}");
    assert_eq!(got, b"hello");
    let handshake = seen.lock().unwrap().clone().expect("the node got index 2");
    assert_eq!(
        handshake,
        DescendantTunnel {
            token: TOKEN.into(),
            instance_ref: CHILD.into(),
            slot: "8080".into(),
            receipts: true,
            remaining_hops: Some(5),
        }
    );
}

#[tokio::test]
async fn an_absent_hop_budget_stays_absent() {
    let (_, _, seen) = exchange(Node::Honest, &[b"x"], None, None).await;
    assert_eq!(seen.lock().unwrap().clone().unwrap().remaining_hops, None);
}

#[tokio::test]
async fn receipts_named_by_the_instance_ref_are_good() {
    let (sink, events) = sink();
    let (got, error, _) = exchange(Node::Honest, &[b"hello", b"world"], None, Some(sink)).await;
    assert!(error.is_none());
    assert_eq!(got, b"helloworld");
    let rs = ended(&events).await;
    assert_eq!(rs.len(), 3);
    assert!(rs.iter().all(StreamReceipt::is_good), "{rs:?}");
}

#[tokio::test]
async fn receipts_named_by_a_token_do_not_verify_for_a_descendant() {
    let (sink, events) = sink();
    exchange(Node::NamesByToken, &[b"x"], None, Some(sink)).await;
    let rs = ended(&events).await;
    assert!(!rs.is_empty());
    assert!(rs.iter().all(|r| r
        .problems
        .contains(&"execution_name is not the name of this descendant on this node".to_string())));
}

#[tokio::test]
async fn the_refusals_of_a_node_with_descendants_keep_their_meaning() {
    for code in [
        tonic::Code::PermissionDenied,
        tonic::Code::ResourceExhausted,
        tonic::Code::InvalidArgument,
    ] {
        let (_, error, _) = exchange(Node::Refuses(code), &[], None, None).await;
        match error {
            Some(WireError::Call(text)) => {
                assert!(text.starts_with(&format!("{code:?}:")), "{text}")
            }
            other => panic!("{code:?} gave {other:?}"),
        }
    }
    // UNAVAILABLE before any byte is a link that failed, as for a plain tunnel.
    let (_, error, _) = exchange(Node::Refuses(tonic::Code::Unavailable), &[], None, None).await;
    assert!(
        matches!(error, Some(WireError::Call(_) | WireError::Connect(_))),
        "{error:?}"
    );
}

#[tokio::test]
async fn a_node_that_does_not_know_index_2_gives_a_clear_error() {
    for code in [
        tonic::Code::Unknown,
        tonic::Code::Internal,
        tonic::Code::Unimplemented,
    ] {
        let (_, error, _) = exchange(Node::Refuses(code), &[], None, None).await;
        match error {
            Some(e @ WireError::NoDescendants) => {
                assert_eq!(e.to_string(), "node does not support descendants")
            }
            other => panic!("{code:?} gave {other:?}"),
        }
    }
}
