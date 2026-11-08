//! The M2 calls on fixed bee-rpc streams: the order of the request, the guard, the
//! quote, the start, the stop, the balance and the quotes of several nodes.

mod common;

use std::sync::Mutex;

use bee_rpc::buffer::Buffer;
use bee_rpc::frame::Part;
use celaut_balancer::{Misfit, QuoteCache, ServiceAsk};
use celaut_client::session::parse_service_id;
use celaut_client::{
    quotes, quotes_for, ClientError, MemoryPeerStore, NodeSession, ResourceRefusal, ResourcesError,
};
use celaut_proto::celaut::contract::Ledger;
use celaut_proto::celaut::instance::UriSlot;
use celaut_proto::celaut::metadata::hash_tag::Hash;
use celaut_proto::celaut::service::container::Architecture;
use celaut_proto::celaut::{
    Amount, AmountKeyValue, ArchitectureResources, BytesKeyValue, Client, Configuration, Contract,
    ContractRate, EstimatedCost, ExecutionReceipt, Instance, Metrics, ModifyDepositInput,
    ModifyDepositOutput, ModifyServiceSystemResourcesInput, ModifyServiceSystemResourcesOutput,
    Peer, RecursionGuard, Refund, ServiceInstance, Sysresources, TokenMessage,
};
use celaut_wire::gateway::SHA3_256_TYPE;
use celaut_wire::WireError;
use common::{stream_of, FixedStreams};
use prost::Message;
use ring::signature::{Ed25519KeyPair, KeyPair};

const SERVICE: [u8; 32] = [0xab; 32];

fn mu(n: &str) -> Option<Amount> {
    Some(Amount { n: n.into() })
}

fn signal() -> Buffer {
    Buffer {
        signal: Some(true),
        ..Default::default()
    }
}

/// The Peer of the vectors, signed by the key of `seed`, with only an ERG contract at
/// `mu_per_nano_erg` if given, else with no contract. Gives the Peer and its peer_id.
fn peer_of(seed: u8, mu_per_nano_erg: Option<&str>) -> (Peer, String) {
    peer_with(seed, mu_per_nano_erg, None)
}

/// [`peer_of`], with `resources` as `Peer.resources` if given.
fn peer_with(
    seed: u8,
    mu_per_nano_erg: Option<&str>,
    resources: Option<Vec<ArchitectureResources>>,
) -> (Peer, String) {
    let mut peer = common::vectors().peers[0].peer();
    if let Some(resources) = resources {
        peer.resources = resources;
    }
    peer.payment_contracts.clear();
    if let Some(rate) = mu_per_nano_erg {
        peer.payment_contracts = vec![ContractRate {
            contract: Some(Contract {
                ledger: Some(Ledger {
                    tags: vec!["ergo".into()],
                    ..Default::default()
                }),
                xattrs: vec![BytesKeyValue {
                    key: "token_id".into(),
                    value: Some(b"ERG".to_vec()),
                }],
            }),
            mu_per_unit: mu(rate),
        }];
    }
    sign_peer(peer, seed)
}

/// Sign `peer` with the key of `seed`. Gives the Peer and its peer_id.
fn sign_peer(mut peer: Peer, seed: u8) -> (Peer, String) {
    let pair = Ed25519KeyPair::from_seed_unchecked(&[seed; 32]).unwrap();
    peer.public_key = hex::encode(pair.public_key().as_ref());
    let digest = celaut_client::peer::content_digest(&peer);
    let payload = celaut_client::peer::signed_payload(&peer.public_key, peer.ts, &digest);
    peer.signature = hex::encode(pair.sign(payload.as_bytes()).as_ref());
    let id = peer.public_key.clone();
    (peer, id)
}

/// A session with the node of `seed`; `more` are the answers after the opening.
async fn session_of(
    seed: u8,
    rate: Option<&str>,
    more: Vec<Vec<Buffer>>,
) -> NodeSession<FixedStreams> {
    session_with(seed, rate, None, more).await
}

/// [`session_of`], with `resources` as `Peer.resources` if given.
async fn session_with(
    seed: u8,
    rate: Option<&str>,
    resources: Option<Vec<ArchitectureResources>>,
    more: Vec<Vec<Buffer>>,
) -> NodeSession<FixedStreams> {
    let (peer, peer_id) = peer_with(seed, rate, resources);
    open_with(peer, peer_id, more).await
}

/// A session with a node that advertises `rates` (key, MU) in `mu_per_call`.
async fn session_priced(
    rates: &[(&str, &str)],
    more: Vec<Vec<Buffer>>,
) -> NodeSession<FixedStreams> {
    let (mut peer, _) = peer_with(1, None, None);
    peer.mu_per_call = rates
        .iter()
        .map(|(k, v)| AmountKeyValue {
            key: (*k).into(),
            value: mu(v),
        })
        .collect();
    let (peer, peer_id) = sign_peer(peer, 1);
    open_with(peer, peer_id, more).await
}

async fn open_with(
    peer: Peer,
    peer_id: String,
    more: Vec<Vec<Buffer>>,
) -> NodeSession<FixedStreams> {
    let mut answers = vec![
        stream_of(
            1,
            &Client {
                client_id: "c11e47000000400080000000000000aa".into(),
                ..Default::default()
            },
        ),
        stream_of(1, &peer),
    ];
    answers.extend(more);
    NodeSession::open(
        FixedStreams::new(answers),
        &peer_id,
        &MemoryPeerStore::new(),
    )
    .await
    .expect("open")
}

async fn session(more: Vec<Vec<Buffer>>) -> NodeSession<FixedStreams> {
    session_of(1, None, more).await
}

fn quote(cost: &str) -> EstimatedCost {
    EstimatedCost {
        cost: mu(cost),
        init_maintenance_cost: mu("0"),
        max_maintenance_cost: mu("0"),
        maintenance_seconds_loop: 0,
        variance: 0.0,
    }
}

/// The answer of GetServiceEstimatedCost and StartService: the signal, then the reply.
fn after_signal(message: &impl Message) -> Vec<Buffer> {
    let mut out = vec![signal()];
    out.extend(stream_of(1, message));
    out
}

fn indices(parts: &[Part]) -> Vec<i32> {
    parts.iter().map(|p| p.index).collect()
}

#[tokio::test]
async fn client_guard_and_configuration_come_before_the_hash() {
    let s = session(vec![after_signal(&quote("5")), after_signal(&quote("5"))]).await;
    let configuration = Configuration {
        initial_mu: mu("1000"),
        ..Default::default()
    };
    s.quote(SERVICE, configuration.clone()).await.unwrap();
    let (method, parts) = s.transport().request(2);
    assert_eq!(method, "GetServiceEstimatedCost");
    assert_eq!(indices(&parts), vec![1, 2, 3, 4]);
    assert_eq!(
        Client::decode(parts[0].data.as_slice()).unwrap().client_id,
        s.client_id()
    );
    assert_eq!(
        Configuration::decode(parts[2].data.as_slice()).unwrap(),
        configuration
    );
    let hash = Hash::decode(parts[3].data.as_slice()).unwrap();
    assert_eq!(hash.r#type, SHA3_256_TYPE.to_vec());
    assert_eq!(hash.value, SERVICE.to_vec());

    // An all-default configuration has no bytes and is not sent; the order stays.
    s.quote(SERVICE, Configuration::default()).await.unwrap();
    let (_, parts) = s.transport().request(3);
    assert_eq!(indices(&parts), vec![1, 2, 4]);
}

#[tokio::test]
async fn the_guard_asks_for_no_delegation() {
    let s = session(vec![after_signal(&quote("5"))]).await;
    s.quote(SERVICE, Configuration::default()).await.unwrap();
    let (_, parts) = s.transport().request(2);
    let guard = RecursionGuard::decode(parts[1].data.as_slice()).unwrap();
    assert_eq!(
        guard,
        RecursionGuard {
            token: String::new(),
            remaining_hops: Some(1),
        }
    );
    // `remaining_hops` is optional: 1 must be on the wire, not left out.
    assert!(!parts[1].data.is_empty());
}

#[tokio::test]
async fn start_gives_the_token_and_the_slots() {
    let instance = ServiceInstance {
        token: "instance-token".into(),
        instance: Some(Instance {
            api: None,
            uri_slot: vec![UriSlot {
                internal_port: 3030,
                uri: vec![],
            }],
        }),
        receipt: Some(ExecutionReceipt {
            kind: "start".into(),
            ..Default::default()
        }),
    };
    let s = session(vec![after_signal(&instance)]).await;
    let started = s.start(SERVICE, Configuration::default()).await.unwrap();
    assert_eq!(started.token, "instance-token");
    assert_eq!(started.slots(), vec![3030]);
    // The start receipt comes with it, for the app to check.
    assert_eq!(started.receipt.map(|r| r.kind).as_deref(), Some("start"));
    let (method, parts) = s.transport().request(2);
    assert_eq!(method, "StartService");
    assert_eq!(indices(&parts), vec![1, 2, 4]);
}

#[tokio::test]
async fn an_instance_with_no_token_is_refused() {
    let instance = ServiceInstance {
        token: String::new(),
        instance: Some(Instance::default()),
        receipt: None,
    };
    let s = session(vec![after_signal(&instance)]).await;
    let err = s
        .start(SERVICE, Configuration::default())
        .await
        .unwrap_err();
    assert!(
        matches!(err, ClientError::Wire(WireError::Protocol(_))),
        "{err:?}"
    );
}

#[tokio::test]
async fn stop_gives_the_refund_and_metrics_the_balance() {
    let s = session(vec![
        stream_of(1, &Refund { amount: mu("123") }),
        stream_of(
            1,
            &Metrics {
                balance: mu("4500000"),
                ..Default::default()
            },
        ),
        // A Refund with no amount has no bytes: nothing arrives, and that is 0.
        vec![],
    ])
    .await;
    assert_eq!(s.stop("instance-token").await.unwrap(), 123);
    let (method, parts) = s.transport().request(2);
    assert_eq!(method, "StopService");
    let token = TokenMessage::decode(parts[0].data.as_slice()).unwrap();
    assert_eq!(token.token, "instance-token");
    assert_eq!(token.slot, None);
    // The father client goes at index 2.
    assert_eq!(parts.len(), 2);
    assert_eq!(parts[1].index, 2);
    assert_eq!(
        Client::decode(parts[1].data.as_slice()).unwrap().client_id,
        s.client_id()
    );

    assert_eq!(s.balance().await.unwrap(), 4_500_000);
    let (method, parts) = s.transport().request(3);
    assert_eq!(method, "GetClientMetrics");
    assert_eq!(parts.len(), 1);
    assert_eq!(parts[0].index, 1);
    assert_eq!(
        Client::decode(parts[0].data.as_slice()).unwrap().client_id,
        s.client_id()
    );
    assert_eq!(s.stop("other").await.unwrap(), 0);
}

#[tokio::test]
async fn a_top_up_moves_credit_to_the_instance_with_modify_deposit() {
    let s = session(vec![
        stream_of(
            1,
            &ModifyDepositOutput {
                success: true,
                message: "Deposit modified correctly".into(),
            },
        ),
        stream_of(
            1,
            &ModifyDepositOutput {
                success: false,
                message: "Error charging the father".into(),
            },
        ),
    ])
    .await;
    s.top_up("instance-token", 250_000).await.unwrap();
    let (method, parts) = s.transport().request(2);
    assert_eq!(method, "ModifyDeposit");
    assert_eq!(parts.len(), 2);
    assert_eq!(parts[0].index, 1);
    assert_eq!(parts[1].index, 2);
    assert_eq!(
        Client::decode(parts[1].data.as_slice()).unwrap().client_id,
        s.client_id()
    );
    let input = ModifyDepositInput::decode(parts[0].data.as_slice()).unwrap();
    assert_eq!(input.service_token, "instance-token");
    assert_eq!(input.difference.unwrap().n, "250000");
    // The node refuses: the client has less credit than that.
    let err = s.top_up("instance-token", 9).await.unwrap_err();
    assert!(
        err.to_string().contains("Error charging the father"),
        "{err}"
    );
}

fn resources(quota: Option<u64>, period: Option<u64>, mem: Option<u64>) -> Sysresources {
    Sysresources {
        cpu_quota: quota,
        cpu_period: period,
        mem_limit: mem,
        ..Default::default()
    }
}

fn change_answer(sysreq: Sysresources, balance: &str) -> Vec<Buffer> {
    stream_of(
        1,
        &ModifyServiceSystemResourcesOutput {
            sysreq: Some(sysreq),
            balance: mu(balance),
        },
    )
}

/// The request of the call `n`: the input (index 1) and the father Client (index 2).
fn resource_request(s: &NodeSession<FixedStreams>, n: usize) -> ModifyServiceSystemResourcesInput {
    let (method, parts) = s.transport().request(n);
    assert_eq!(method, "ModifyServiceSystemResources");
    assert_eq!(indices(&parts), vec![1, 2]);
    assert_eq!(
        Client::decode(parts[1].data.as_slice()).unwrap().client_id,
        s.client_id()
    );
    ModifyServiceSystemResourcesInput::decode(parts[0].data.as_slice()).unwrap()
}

#[tokio::test]
async fn the_read_of_the_resources_sends_the_token_and_no_change() {
    let live = resources(Some(50_000), Some(100_000), Some(1 << 30));
    let s = session(vec![
        change_answer(
            Sysresources {
                disk_space: Some(7),
                ..live.clone()
            },
            "900",
        ),
        // A hibernated instance: all zero.
        change_answer(resources(Some(0), Some(0), Some(0)), "800"),
    ])
    .await;
    let now = s.current_resources("instance-token").await.unwrap();
    assert_eq!(now.sysreq.cpu_quota, Some(50_000));
    assert_eq!(now.sysreq.cpu_period, Some(100_000));
    assert_eq!(now.sysreq.mem_limit, Some(1 << 30));
    assert_eq!(now.balance_mu, 900);
    let input = resource_request(&s, 2);
    assert_eq!(input.service_token, "instance-token");
    assert_eq!(input.max_sysreq, None);
    assert_eq!(input.min_sysreq, None);

    // All zero: nothing to store for a wake.
    let err = s.current_resources("instance-token").await.unwrap_err();
    assert!(
        matches!(
            err,
            ClientError::Resources(ResourcesError::NotReadable("cpu_quota"))
        ),
        "{err:?}"
    );
}

#[tokio::test]
async fn hibernate_sets_cpu_quota_and_mem_limit_to_zero() {
    let s = session(vec![change_answer(
        Sysresources {
            disk_space: Some(7),
            ..resources(Some(0), Some(0), Some(0))
        },
        "700",
    )])
    .await;
    let done = s.hibernate("instance-token").await.unwrap();
    assert_eq!(done.sysreq.mem_limit, Some(0));
    assert_eq!(done.balance_mu, 700);
    let input = resource_request(&s, 2);
    assert_eq!(input.service_token, "instance-token");
    let max = input.max_sysreq.unwrap();
    // A 0 that is set is sent: the field has a presence bit.
    assert_eq!(max.cpu_quota, Some(0));
    assert_eq!(max.mem_limit, Some(0));
    assert_eq!(max.cpu_period, None);
}

#[tokio::test]
async fn wake_sends_the_three_fields_and_gives_the_resources_now() {
    let stored = Sysresources {
        disk_space: Some(7),
        blkio_weight: Some(3),
        ..resources(Some(50_000), Some(100_000), Some(1 << 30))
    };
    let s = session(vec![
        change_answer(resources(Some(50_000), Some(100_000), Some(1 << 30)), "600"),
        // The node has no answer part: an all-default answer.
        vec![],
    ])
    .await;
    let done = s.wake("instance-token", &stored).await.unwrap();
    assert_eq!(done.sysreq.cpu_quota, Some(50_000));
    assert_eq!(done.balance_mu, 600);
    let input = resource_request(&s, 2);
    assert_eq!(input.service_token, "instance-token");
    let max = input.max_sysreq.unwrap();
    assert_eq!(max.cpu_quota, Some(50_000));
    assert_eq!(max.cpu_period, Some(100_000));
    assert_eq!(max.mem_limit, Some(1 << 30));
    // Only the three fields go to the node.
    assert_eq!(max.disk_space, None);
    assert_eq!(max.blkio_weight, None);
    // No part: balance 0 and no resources, not an error.
    let empty = s.wake("instance-token", &stored).await.unwrap();
    assert_eq!(empty.balance_mu, 0);
    assert_eq!(empty.sysreq, Sysresources::default());
}

#[tokio::test]
async fn wake_refuses_with_a_field_missing_or_zero_and_makes_no_call() {
    let s = session(vec![]).await;
    let calls = s.transport().calls();
    let cases = [
        (resources(None, Some(1), Some(1)), "cpu_quota"),
        (resources(Some(0), Some(1), Some(1)), "cpu_quota"),
        (resources(Some(1), None, Some(1)), "cpu_period"),
        (resources(Some(1), Some(0), Some(1)), "cpu_period"),
        (resources(Some(1), Some(1), None), "mem_limit"),
        (resources(Some(1), Some(1), Some(0)), "mem_limit"),
        (Sysresources::default(), "cpu_quota"),
    ];
    for (r, field) in cases {
        let err = s.wake("t", &r).await.unwrap_err();
        assert!(
            matches!(&err, ClientError::Resources(ResourcesError::WakeIncomplete(f)) if *f == field),
            "{field}: {err:?}"
        );
    }
    assert_eq!(s.transport().calls(), calls);
}

#[test]
fn the_refusals_of_a_resource_change_are_classified() {
    let refused = |text: &str| {
        ClientError::Wire(WireError::Call(format!(
            "status: Unknown, message: \"Exception calling application: {text}\", details: []"
        )))
    };
    assert_eq!(
        refused("The instance could not be woken: it stays hibernated.").resource_refusal(),
        Some(ResourceRefusal::DoesNotFit)
    );
    assert_eq!(
        refused("This instance exports or mounts a shared filesystem, and hibernating it would take that share away from the guests that use it.").resource_refusal(),
        Some(ResourceRefusal::SharedFilesystem)
    );
    assert_eq!(
        ClientError::Wire(WireError::Timeout).resource_refusal(),
        None
    );
}

#[tokio::test]
async fn a_bad_amount_is_an_error() {
    let s = session(vec![stream_of(1, &Refund { amount: mu("-1") })]).await;
    let err = s.stop("t").await.unwrap_err();
    assert!(matches!(err, ClientError::Amount(_)), "{err:?}");
}

#[tokio::test]
async fn quotes_rank_the_nodes_and_use_the_cache() {
    // a: 900 MU at 10 MU per nanoERG = 90 nanoERG. c: 100 MU at 1 = 100 nanoERG.
    let a = session_of(1, Some("10"), vec![after_signal(&quote("900"))]).await;
    // b: an answer that cannot be parsed. The node failed and is not a candidate.
    let b = session_of(
        2,
        Some("1"),
        vec![vec![Buffer {
            chunk: Some(vec![1, 2, 3]),
            head: Some(bee_rpc::buffer::buffer::Head {
                index: 9,
                partitions: vec![],
            }),
            separator: Some(true),
            ..Default::default()
        }]],
    )
    .await;
    let c = session_of(3, Some("1"), vec![after_signal(&quote("100"))]).await;
    // d: no ERG rate, so its price cannot be compared: last, even if it is cheap.
    let d = session_of(4, None, vec![after_signal(&quote("1"))]).await;
    let cache = Mutex::new(QuoteCache::new());
    let config = Configuration::default();

    let first = quotes(&[&d, &c, &b, &a], SERVICE, &config, &cache).await;
    let order: Vec<&str> = first
        .ranked
        .iter()
        .map(|r| r.candidate.peer_id.as_str())
        .collect();
    assert_eq!(order, vec![a.peer_id(), c.peer_id(), d.peer_id()]);
    assert_eq!(first.ranked[0].cost_nano_erg, Some(90.0));
    assert_eq!(first.failures.len(), 1);
    assert_eq!(first.failures[0].peer_id, b.peer_id());
    assert!(first.skipped.is_empty());
    assert_eq!(a.transport().calls(), 3);

    // Within 10 s the same question makes no call.
    let again = quotes(&[&a, &c], SERVICE, &config, &cache).await;
    assert_eq!(again.ranked.len(), 2);
    assert_eq!(a.transport().calls(), 3);
    assert_eq!(c.transport().calls(), 3);
}

const GIB: u64 = 1 << 30;

/// One announced entry for `tag` with a memory ceiling.
fn announced(tag: &str, mem_limit: u64) -> ArchitectureResources {
    ArchitectureResources {
        architecture: Some(Architecture {
            tags: vec![tag.into()],
            ..Default::default()
        }),
        resources: Some(Sysresources {
            mem_limit: Some(mem_limit),
            ..Default::default()
        }),
    }
}

#[tokio::test]
async fn quotes_for_skips_the_nodes_that_can_never_run_the_service_and_does_not_call_them() {
    let answer = || vec![after_signal(&quote("100"))];
    // Big enough, too small, another architecture only, and a node that announced nothing.
    let big = session_with(
        1,
        Some("1"),
        Some(vec![announced("amd64", 4 * GIB)]),
        answer(),
    )
    .await;
    let small = session_with(2, Some("1"), Some(vec![announced("x86_64", GIB)]), answer()).await;
    let arm = session_with(
        3,
        Some("1"),
        Some(vec![announced("arm64", 8 * GIB)]),
        answer(),
    )
    .await;
    let silent = session_with(4, Some("1"), Some(vec![]), answer()).await;
    let ask = ServiceAsk {
        architecture: Some("linux/amd64"),
        resources: Sysresources {
            mem_limit: Some(2 * GIB),
            ..Default::default()
        },
    };
    let cache = Mutex::new(QuoteCache::new());
    let config = Configuration::default();

    let answer = quotes_for(
        &[&big, &small, &arm, &silent],
        SERVICE,
        &config,
        &cache,
        Some(&ask),
    )
    .await;

    let mut asked: Vec<&str> = answer
        .ranked
        .iter()
        .map(|r| r.candidate.peer_id.as_str())
        .collect();
    asked.sort();
    let mut expected = vec![big.peer_id(), silent.peer_id()];
    expected.sort();
    assert_eq!(asked, expected);
    assert!(answer.failures.is_empty());
    let skipped: Vec<&str> = answer.skipped.iter().map(|s| s.peer_id.as_str()).collect();
    assert_eq!(skipped, vec![small.peer_id(), arm.peer_id()]);
    assert!(matches!(
        answer.skipped[0].misfits.as_slice(),
        [Misfit::MemLimit { .. }]
    ));
    assert!(matches!(
        answer.skipped[1].misfits.as_slice(),
        [Misfit::NotRun { .. }]
    ));
    // The opening is 2 calls. A node that was asked has one more; a skipped one has none.
    assert_eq!(big.transport().calls(), 3);
    assert_eq!(silent.transport().calls(), 3);
    assert_eq!(small.transport().calls(), 2);
    assert_eq!(arm.transport().calls(), 2);
}

#[tokio::test]
async fn quotes_for_with_no_ask_or_no_known_architecture_skips_no_node() {
    let answer = || vec![after_signal(&quote("100"))];
    let small = session_with(2, Some("1"), Some(vec![announced("amd64", 1)]), answer()).await;
    let config = Configuration::default();
    let no_ask = quotes_for(
        &[&small],
        SERVICE,
        &config,
        &Mutex::new(QuoteCache::new()),
        None,
    )
    .await;
    assert_eq!(no_ask.ranked.len(), 1);
    assert!(no_ask.skipped.is_empty());

    let small = session_with(2, Some("1"), Some(vec![announced("amd64", 1)]), answer()).await;
    let unknown = ServiceAsk {
        architecture: None,
        resources: Sysresources {
            mem_limit: Some(u64::MAX),
            ..Default::default()
        },
    };
    let no_arch = quotes_for(
        &[&small],
        SERVICE,
        &config,
        &Mutex::new(QuoteCache::new()),
        Some(&unknown),
    )
    .await;
    assert_eq!(no_arch.ranked.len(), 1);
    assert!(no_arch.skipped.is_empty());
}

#[test]
fn service_ids_are_64_hex_characters() {
    let text = "ab".repeat(32);
    assert_eq!(parse_service_id(&text), Some(SERVICE));
    assert_eq!(parse_service_id(&text.to_uppercase()), Some(SERVICE));
    assert_eq!(parse_service_id(&format!(" {text} ")), Some(SERVICE));
    assert_eq!(parse_service_id(&text[2..]), None);
    assert_eq!(parse_service_id(&"zz".repeat(32)), None);
}

#[tokio::test]
async fn a_resumed_session_keeps_the_client_id_and_makes_no_new_client() {
    let (peer, peer_id) = peer_of(1, None);
    let store = celaut_client::CelautDb::in_memory();
    let session = NodeSession::resume(
        FixedStreams::new(vec![stream_of(1, &peer)]),
        &peer_id,
        "c11e47000000400080000000000000bb".into(),
        &store,
    )
    .await
    .expect("resume");
    assert_eq!(session.client_id(), "c11e47000000400080000000000000bb");
    // One call only: GetPeerInfo, not GenerateClient.
    assert_eq!(session.transport().calls(), 1);
    assert_eq!(session.transport().request(0).0, "GetPeerInfo");
    // The advertisement went into the database of the app.
    assert!(store.read(|d| d.seen.contains_key(&peer_id)));
}

// The record of a hibernation (`celaut_client::hibernation`).

mod hibernation_record {
    use super::*;
    use celaut_client::db::{
        CelautDb, HibernatedPrice, InstancePricing, InstanceRecord, Resources, ResourcesSource,
    };
    use celaut_client::hibernation::{self, HibernationError};

    const LAUNCH: Resources = Resources {
        cpu_quota: 25_000,
        cpu_period: 100_000,
        mem_limit: 512 << 20,
    };
    const NOW: Resources = Resources {
        cpu_quota: 50_000,
        cpu_period: 100_000,
        mem_limit: 1 << 30,
    };

    fn db_with(record: InstanceRecord) -> CelautDb {
        let db = CelautDb::in_memory();
        db.update(|d| d.instances.insert("i1".into(), record))
            .unwrap();
        db
    }

    fn running(awake: Option<Resources>) -> InstanceRecord {
        InstanceRecord {
            token: "instance-token".into(),
            awake_resources: awake,
            awake_source: awake.map(|_| ResourcesSource::LastKnown),
            ..Default::default()
        }
    }

    fn hibernated() -> InstanceRecord {
        InstanceRecord {
            hibernated_at: Some(5),
            awake_source: Some(ResourcesSource::ReadFromNode),
            ..running(Some(NOW))
        }
    }

    fn record(db: &CelautDb) -> InstanceRecord {
        db.read(|d| d.instances["i1"].clone())
    }

    fn zero() -> Vec<Buffer> {
        change_answer(resources(Some(0), Some(0), Some(0)), "700")
    }

    #[tokio::test]
    async fn hibernate_stores_the_resources_of_now_not_the_launch_ones() {
        // The record holds the launch size; the node says it was resized since.
        let db = db_with(running(Some(LAUNCH)));
        let s = session(vec![change_answer(NOW.to_sysresources(), "900"), zero()]).await;
        let done = hibernation::hibernate(&s, &db, "i1", 42).await.unwrap();
        assert_eq!(
            (done.resources, done.source),
            (NOW, ResourcesSource::ReadFromNode)
        );
        assert_eq!(done.balance_mu, 700);
        let r = record(&db);
        assert_eq!(r.awake_resources, Some(NOW));
        assert_eq!(r.awake_source, Some(ResourcesSource::ReadFromNode));
        assert_eq!(r.hibernated_at, Some(42));
        assert_eq!(r.stopped_at, None);
        // The read comes first, and has no change; then the zeroing request.
        assert_eq!(resource_request(&s, 2).max_sysreq, None);
        assert_eq!(
            resource_request(&s, 3).max_sysreq.unwrap().mem_limit,
            Some(0)
        );
    }

    #[tokio::test]
    async fn a_failed_hibernation_leaves_the_record_as_it_was() {
        let before = running(Some(LAUNCH));
        let db = db_with(before.clone());
        // The read works; the node gives no answer to the hibernation request.
        let s = session(vec![change_answer(NOW.to_sysresources(), "900")]).await;
        let err = hibernation::hibernate(&s, &db, "i1", 42).await.unwrap_err();
        assert!(matches!(err, HibernationError::Client(_)), "{err:?}");
        assert_eq!(record(&db), before);
    }

    #[tokio::test]
    async fn an_answer_that_is_not_zero_is_not_a_hibernation() {
        let before = running(Some(LAUNCH));
        let db = db_with(before.clone());
        let s = session(vec![
            change_answer(NOW.to_sysresources(), "900"),
            change_answer(NOW.to_sysresources(), "800"),
        ])
        .await;
        let err = hibernation::hibernate(&s, &db, "i1", 42).await.unwrap_err();
        assert!(matches!(err, HibernationError::NotConfirmed), "{err:?}");
        assert_eq!(record(&db), before);
    }

    #[tokio::test]
    async fn a_failed_read_uses_the_last_known_values_and_marks_them() {
        let db = db_with(running(Some(LAUNCH)));
        let s = session(vec![
            // The read: an all-zero answer is "not readable", so the last known values
            // are used. Then the hibernation works.
            zero(),
            zero(),
        ])
        .await;
        let done = hibernation::hibernate(&s, &db, "i1", 7).await.unwrap();
        assert_eq!(
            (done.resources, done.source),
            (LAUNCH, ResourcesSource::LastKnown)
        );
        let r = record(&db);
        assert_eq!(r.awake_source, Some(ResourcesSource::LastKnown));
        assert_eq!(r.hibernated_at, Some(7));
    }

    #[tokio::test]
    async fn with_no_value_at_all_it_refuses_and_changes_nothing() {
        let before = running(None);
        let db = db_with(before.clone());
        let s = session(vec![zero()]).await;
        let err = hibernation::hibernate(&s, &db, "i1", 7).await.unwrap_err();
        assert!(matches!(err, HibernationError::NoResources), "{err:?}");
        assert_eq!(record(&db), before);
        // Only the read was sent: the zeroing request was not.
        assert_eq!(s.transport().calls(), 3);
    }

    #[tokio::test]
    async fn wake_sends_all_the_fields_and_clears_the_hibernation() {
        let db = db_with(hibernated());
        let s = session(vec![change_answer(NOW.to_sysresources(), "600")]).await;
        let done = hibernation::wake(&s, &db, "i1").await.unwrap();
        assert_eq!(done.resources, NOW);
        let max = resource_request(&s, 2).max_sysreq.unwrap();
        assert_eq!(
            (max.cpu_quota, max.cpu_period, max.mem_limit),
            (Some(50_000), Some(100_000), Some(1 << 30))
        );
        let r = record(&db);
        assert_eq!(r.hibernated_at, None);
        assert_eq!(r.awake_resources, Some(NOW));
    }

    #[tokio::test]
    async fn a_failed_wake_keeps_the_instance_hibernated() {
        let before = hibernated();
        let db = db_with(before.clone());
        // No answer: the call fails.
        let s = session(vec![]).await;
        let err = hibernation::wake(&s, &db, "i1").await.unwrap_err();
        assert!(matches!(err, HibernationError::Client(_)), "{err:?}");
        assert_eq!(record(&db), before);
        // An instance that is not hibernated has nothing to wake, and no call is made.
        let db = db_with(running(Some(NOW)));
        let calls = s.transport().calls();
        let err = hibernation::wake(&s, &db, "i1").await.unwrap_err();
        assert!(matches!(err, HibernationError::NotHibernated), "{err:?}");
        assert_eq!(s.transport().calls(), calls);
    }

    const RATES: [(&str, &str); 3] = [
        ("disk_mu_per_gib_second", "27"),
        ("scarcity_max_multiplier", "10"),
        ("modify_resources_mu", "10000"),
    ];

    fn priced(awake_mu: &str) -> InstanceRecord {
        InstanceRecord {
            pricing: Some(InstancePricing {
                maintenance_mu: awake_mu.into(),
                maintenance_seconds: 60,
                variance: "0".into(),
            }),
            ..running(Some(LAUNCH))
        }
    }

    fn read_with_disk(gib: u64) -> Vec<Buffer> {
        let mut sysreq = NOW.to_sysresources();
        sysreq.disk_space = Some(gib << 30);
        change_answer(sysreq, "900")
    }

    #[tokio::test]
    async fn hibernate_keeps_the_price_of_the_disk_and_the_wake_fee() {
        let db = db_with(priced("1000000"));
        let s = session_priced(&RATES, vec![read_with_disk(10), zero()]).await;
        hibernation::hibernate(&s, &db, "i1", 42).await.unwrap();
        // (27 + 1) MU per GiB and second, times 10 for scarcity, 10 GiB, 60 seconds.
        assert_eq!(
            record(&db).hibernated_price,
            Some(HibernatedPrice {
                disk_maintenance_mu: "168000".into(),
                wake_fee_mu: "10000".into(),
            })
        );
    }

    #[tokio::test]
    async fn the_price_of_the_disk_is_never_more_than_the_awake_price() {
        let db = db_with(priced("50000"));
        let s = session_priced(&RATES, vec![read_with_disk(10), zero()]).await;
        hibernation::hibernate(&s, &db, "i1", 42).await.unwrap();
        assert_eq!(
            record(&db).hibernated_price.unwrap().disk_maintenance_mu,
            "50000"
        );
    }

    #[tokio::test]
    async fn no_disk_rate_or_no_pricing_gives_no_hibernated_price() {
        // The node advertises no disk rate.
        let db = db_with(priced("1000000"));
        let s = session_priced(
            &[("modify_resources_mu", "10000")],
            vec![read_with_disk(10), zero()],
        )
        .await;
        hibernation::hibernate(&s, &db, "i1", 42).await.unwrap();
        assert_eq!(record(&db).hibernated_price, None);
        // The record has no price of the start.
        let db = db_with(running(Some(LAUNCH)));
        let s = session_priced(&RATES, vec![read_with_disk(10), zero()]).await;
        hibernation::hibernate(&s, &db, "i1", 42).await.unwrap();
        assert_eq!(record(&db).hibernated_price, None);
        assert_eq!(record(&db).hibernated_at, Some(42));
    }

    #[tokio::test]
    async fn a_wake_clears_the_hibernated_price() {
        let mut r = hibernated();
        r.hibernated_price = Some(HibernatedPrice {
            disk_maintenance_mu: "1".into(),
            wake_fee_mu: "2".into(),
        });
        let db = db_with(r);
        let s = session(vec![change_answer(NOW.to_sysresources(), "500")]).await;
        hibernation::wake(&s, &db, "i1").await.unwrap();
        assert_eq!(record(&db).hibernated_price, None);
        assert_eq!(record(&db).hibernated_at, None);
    }
}

#[tokio::test]
async fn support_chat_sends_with_the_client_only_and_reads_the_thread() {
    use celaut_proto::celaut::{ChatAck, ChatEntry, ChatMessage, ChatThread, ChatThreadRequest};
    let thread = ChatThread {
        entries: vec![
            ChatEntry {
                sequence: 1,
                ts: 10,
                from_operator: false,
                body: "hello".into(),
            },
            ChatEntry {
                sequence: 2,
                ts: 20,
                from_operator: true,
                body: "hi".into(),
            },
        ],
        latest: 2,
    };
    let s = session(vec![
        stream_of(1, &ChatAck { stored: true, reason: String::new() }),
        // A refusal has a reason.
        stream_of(1, &ChatAck { stored: false, reason: "too long".into() }),
        stream_of(1, &thread),
        // An empty thread has no bytes.
        vec![],
    ])
    .await;

    let ack = s.support_send("hello").await.unwrap().unwrap();
    assert!(ack.stored);
    let (method, parts) = s.transport().request(2);
    assert_eq!(method, "Chat");
    assert_eq!(parts.len(), 1);
    assert_eq!(parts[0].index, 1);
    let sent = ChatMessage::decode(parts[0].data.as_slice()).unwrap();
    assert_eq!(sent.client_id, s.client_id());
    assert_eq!(sent.body, "hello");
    assert_eq!(sent.conversation_id, None);

    let ack = s.support_send("x").await.unwrap().unwrap();
    assert!(!ack.stored);
    assert_eq!(ack.reason, "too long");

    let got = s.support_thread(0).await.unwrap().unwrap();
    assert_eq!(got, thread);
    let (method, parts) = s.transport().request(4);
    assert_eq!(method, "GetChatThread");
    assert_eq!(parts.len(), 2);
    assert_eq!(parts[0].index, 1);
    assert_eq!(
        ChatThreadRequest::decode(parts[0].data.as_slice()).unwrap().after_sequence,
        0
    );
    assert_eq!(parts[1].index, 2);
    assert_eq!(
        Client::decode(parts[1].data.as_slice()).unwrap().client_id,
        s.client_id()
    );

    let empty = s.support_thread(2).await.unwrap().unwrap();
    assert!(empty.entries.is_empty());
    assert_eq!(empty.latest, 0);
}
