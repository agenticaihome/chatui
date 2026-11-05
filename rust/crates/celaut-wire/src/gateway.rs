//! The typed Gateway calls of milestones M1, M2 and M3.
//!
//! Indices come from `nodo:protos/gateway_bee.py` (`GATEWAY_RPCS`).

use std::time::Duration;

use bee_rpc::frame::Part;
use celaut_proto::celaut::metadata::hash_tag::Hash;
use celaut_proto::celaut::{
    Amount, Client, Configuration, EstimatedCost, Metrics, ModifyDepositInput, ModifyDepositOutput,
    ModifyServiceSystemResourcesInput, ModifyServiceSystemResourcesOutput, Payment, Peer,
    PoWRequired, RecursionGuard, Refund, ServiceInstance, Sysresources, TokenMessage,
};
use prost::Message;

use crate::{Transport, WireError};

/// The type id of SHA3-256: the digest of the empty input
/// (`nodo:src/utils/hashing.py`). The registry of a node uses it.
pub const SHA3_256_TYPE: [u8; 32] = [
    0xa7, 0xff, 0xc6, 0xf8, 0xbf, 0x1e, 0xd7, 0x66, 0x51, 0xc1, 0x47, 0x56, 0xa0, 0x61, 0xd6, 0x62,
    0xf5, 0x80, 0xff, 0x4d, 0xe4, 0x3b, 0x49, 0xfa, 0x82, 0xd8, 0x0a, 0x4b, 0x80, 0xf8, 0x43, 0x4a,
];

/// The time limit of `StartService`. The node can build the service and boot it before
/// it answers, and it stops an instance whose call ended before the answer (nodo #487).
pub const START_TIMEOUT: Duration = Duration::from_secs(600);

/// What `GenerateClient` answers.
#[derive(Debug, Clone, PartialEq)]
pub enum GenerateClientReply {
    /// A new client (index 1).
    Client(Client),
    /// The node asks for a proof of work first (index 2).
    PowRequired(PoWRequired),
}

fn decode<M: Message + Default>(part: &Part, what: &str) -> Result<M, WireError> {
    M::decode(part.data.as_slice())
        .map_err(|e| WireError::Protocol(format!("{what} does not decode: {e}")))
}

/// `GenerateClient`: send one `Client` (index 1), get a `Client` (1) or a
/// `PoWRequired` (2).
pub async fn generate_client<T: Transport>(
    transport: &T,
    request: &Client,
) -> Result<GenerateClientReply, WireError> {
    let parts = vec![Part::new(1, request.encode_to_vec())];
    let answer = transport.call("GenerateClient", parts, &[1, 2]).await?;
    // The first part with a message index. Index 0 is raw bytes: not used here.
    for part in &answer {
        match part.index {
            1 => return Ok(GenerateClientReply::Client(decode(part, "the Client")?)),
            2 => {
                return Ok(GenerateClientReply::PowRequired(decode(
                    part,
                    "the PoWRequired",
                )?));
            }
            _ => {}
        }
    }
    Err(WireError::Protocol(
        "GenerateClient gave no Client and no PoWRequired".to_string(),
    ))
}

/// `GetPeerInfo`: send a `Client` that has the id (index 1), get a `Peer` (1).
///
/// The caller must check the signature of the `Peer`. This function does not.
pub async fn get_peer_info<T: Transport>(
    transport: &T,
    client_id: &str,
) -> Result<Peer, WireError> {
    let client = Client {
        client_id: client_id.to_string(),
        ..Default::default()
    };
    let parts = vec![Part::new(1, client.encode_to_vec())];
    let answer = transport.call("GetPeerInfo", parts, &[1]).await?;
    match answer.iter().find(|p| p.index == 1) {
        Some(part) => decode(part, "the Peer"),
        None => Err(WireError::Protocol("GetPeerInfo gave no Peer".to_string())),
    }
}

/// The request of `GetServiceEstimatedCost` and `StartService` for a service that the
/// node already has: the client, the recursion guard, the configuration and the hash.
#[derive(Debug, Clone, PartialEq)]
pub struct ServiceRequest {
    /// The client id on this node.
    pub client_id: String,
    /// The SHA3-256 of the service (the service id), 32 bytes.
    pub service_id: [u8; 32],
    /// The configuration. All-default means "the defaults of the node".
    pub configuration: Configuration,
}

/// The guard that a light client sends: a new tree (no token), and one hop. The node
/// runs the service itself and does not delegate it, because a delegated instance has
/// no path for a phone (ServiceTunnel accepts only local instances).
pub fn no_delegation_guard() -> RecursionGuard {
    RecursionGuard {
        token: String::new(),
        remaining_hops: Some(1),
    }
}

impl ServiceRequest {
    /// The parts in the order that the node needs: Client (1), RecursionGuard (2) and
    /// Configuration (3) before the Hash (4). The node starts the work on the Hash of a
    /// service that it has, and ignores a Configuration or a guard that comes later
    /// (`nodo:src/gateway/iterables/abstract_input_service_iterable.py`).
    ///
    /// An all-default Configuration has no bytes. A receiver drops a part with no bytes,
    /// so it is not sent.
    pub fn parts(&self) -> Vec<Part> {
        let client = Client {
            client_id: self.client_id.clone(),
            ..Default::default()
        };
        let hash = Hash {
            r#type: SHA3_256_TYPE.to_vec(),
            value: self.service_id.to_vec(),
        };
        let mut parts = vec![
            Part::new(1, client.encode_to_vec()),
            Part::new(2, no_delegation_guard().encode_to_vec()),
        ];
        let configuration = self.configuration.encode_to_vec();
        if !configuration.is_empty() {
            parts.push(Part::new(3, configuration));
        }
        parts.push(Part::new(4, hash.encode_to_vec()));
        parts
    }
}

/// The first part with index `index`, decoded.
fn find<M: Message + Default>(answer: &[Part], index: i32, what: &str) -> Result<M, WireError> {
    match answer.iter().find(|p| p.index == index) {
        Some(part) => decode(part, what),
        None => Err(WireError::Protocol(format!("the node gave no {what}"))),
    }
}

/// The time limit of a call that moves a whole service (`GetService`, and a quote that
/// carries the service). A service can be large, and a phone can be slow.
pub const SERVICE_TRANSFER_TIMEOUT: Duration = Duration::from_secs(3600);

/// `GetService`: the service with the id `service_id`, as the Buffers of the answer:
/// the hashes (index 4), the Metadata (5) and the Service (6) with its blocks. These are
/// the indices of `StartService`, so the Buffers can go to another node as they are.
/// A node that does not have the service answers nothing.
pub async fn get_service_raw<T: Transport>(
    transport: &T,
    client_id: &str,
    service_id: [u8; 32],
) -> Result<crate::transport::Buffers, WireError> {
    let hash = Hash {
        r#type: SHA3_256_TYPE.to_vec(),
        value: service_id.to_vec(),
    };
    let client = Client {
        client_id: client_id.to_string(),
        ..Default::default()
    };
    let parts = vec![
        Part::new(1, hash.encode_to_vec()),
        Part::new(2, client.encode_to_vec()),
    ];
    transport
        .call_raw("GetService", parts, SERVICE_TRANSFER_TIMEOUT)
        .await
}

/// [`get_service_raw`], with a way to ask the node to skip a block: for a reader that
/// describes the service and does not need the filesystem of its container.
pub async fn get_service_skippable<T: Transport>(
    transport: &T,
    client_id: &str,
    service_id: [u8; 32],
) -> Result<crate::transport::RawAnswer, WireError> {
    let hash = Hash {
        r#type: SHA3_256_TYPE.to_vec(),
        value: service_id.to_vec(),
    };
    let client = Client {
        client_id: client_id.to_string(),
        ..Default::default()
    };
    let parts = vec![
        Part::new(1, hash.encode_to_vec()),
        Part::new(2, client.encode_to_vec()),
    ];
    transport
        .call_raw_skippable("GetService", parts, SERVICE_TRANSFER_TIMEOUT)
        .await
}

/// `GetServiceEstimatedCost` with the service: the request parts, then `service` (the
/// Buffers of a service with the `StartService` indices 4, 5 and 6). The node stores the
/// service, so later calls need only its hash. If `service` fails, the node refuses the
/// request and the error is [`WireError::Relay`].
///
/// A node that already has the service answers after the hash, and the transport then
/// stops sending the service ([`Transport::call_with_service`]). A node that has only some
/// of its blocks can ask for them to be skipped: wrap `service` with [`crate::Skips::wrap`]
/// to stop them. Wrap `service` in a [`crate::SendCounter`] to know how much of it went,
/// after that wrap.
pub async fn get_service_estimated_cost_with_service<T: Transport>(
    transport: &T,
    request: &ServiceRequest,
    service: crate::transport::Buffers,
    skips: &crate::Skips,
) -> Result<EstimatedCost, WireError> {
    let answer = transport
        .call_with_service(
            "GetServiceEstimatedCost",
            request.parts(),
            service,
            &[1],
            SERVICE_TRANSFER_TIMEOUT,
            skips,
        )
        .await?;
    find(&answer, 1, "EstimatedCost")
}

/// `GetServiceEstimatedCost`: the price of the service on this node.
pub async fn get_service_estimated_cost<T: Transport>(
    transport: &T,
    request: &ServiceRequest,
) -> Result<EstimatedCost, WireError> {
    let answer = transport
        .call("GetServiceEstimatedCost", request.parts(), &[1])
        .await?;
    find(&answer, 1, "EstimatedCost")
}

/// `StartService`: start the service. The node charges the cost to the client. The
/// answer has the instance token: keep it, it is the only way to stop the instance.
pub async fn start_service<T: Transport>(
    transport: &T,
    request: &ServiceRequest,
) -> Result<ServiceInstance, WireError> {
    let answer = transport
        .call_with_timeout("StartService", request.parts(), &[1], START_TIMEOUT)
        .await?;
    let instance: ServiceInstance = find(&answer, 1, "ServiceInstance")?;
    if instance.token.is_empty() {
        return Err(WireError::Protocol(
            "the node gave an instance with no token".to_string(),
        ));
    }
    Ok(instance)
}

fn token_part(token: &str) -> Vec<Part> {
    let message = TokenMessage {
        token: token.to_string(),
        slot: None,
        receipts: false,
    };
    vec![Part::new(1, message.encode_to_vec())]
}

/// `StopService`: stop the instance. The node gives the unused balance of the instance
/// back to the client and answers with that amount. The call has the instance token
/// (index 1) and the `Client` (index 2): the node accepts it only from the client that
/// started the instance.
///
/// A receiver drops an all-default message (it has no bytes), so no part means a
/// refund of 0.
pub async fn stop_service<T: Transport>(
    transport: &T,
    token: &str,
    client_id: &str,
) -> Result<Refund, WireError> {
    let mut parts = token_part(token);
    parts.push(client_part(2, client_id));
    let answer = transport.call("StopService", parts, &[1]).await?;
    match answer.iter().find(|p| p.index == 1) {
        Some(part) => decode(part, "the Refund"),
        None => Ok(Refund::default()),
    }
}

/// `GetMetrics`: the balance of an instance (`token` = instance token). No part means a
/// balance of 0, as in [`stop_service`]. The balance of a client is
/// [`get_client_metrics`].
pub async fn get_metrics<T: Transport>(transport: &T, token: &str) -> Result<Metrics, WireError> {
    let answer = transport
        .call("GetMetrics", token_part(token), &[1])
        .await?;
    match answer.iter().find(|p| p.index == 1) {
        Some(part) => decode(part, "the Metrics"),
        None => Ok(Metrics::default()),
    }
}

/// `GetClientMetrics`: send the `Client` (index 1), get the `Metrics` (1) with the balance
/// of the client. It is free. No part means a balance of 0.
pub async fn get_client_metrics<T: Transport>(
    transport: &T,
    client_id: &str,
) -> Result<Metrics, WireError> {
    let answer = transport
        .call("GetClientMetrics", vec![client_part(1, client_id)], &[1])
        .await?;
    match answer.iter().find(|p| p.index == 1) {
        Some(part) => decode(part, "the Metrics"),
        None => Ok(Metrics::default()),
    }
}

/// `ModifyDeposit`: move `difference_mu` MU from the parent of the instance (the client
/// that started it) to the instance of the token `token`. The call has the
/// `ModifyDepositInput` (index 1) and the `Client` (2), which must be that parent. The
/// node moves nothing if the
/// parent has less (`nodo:src/manager/manager.py`, `modify_deposit`): then `success` is
/// false and `message` says why. Nothing goes on a ledger: this moves credit that the
/// client already has on the node.
pub async fn modify_deposit<T: Transport>(
    transport: &T,
    token: &str,
    client_id: &str,
    difference_mu: u128,
) -> Result<ModifyDepositOutput, WireError> {
    let input = ModifyDepositInput {
        difference: Some(Amount {
            n: difference_mu.to_string(),
        }),
        service_token: token.to_string(),
    };
    let answer = transport
        .call(
            "ModifyDeposit",
            vec![
                Part::new(1, input.encode_to_vec()),
                client_part(2, client_id),
            ],
            &[1],
        )
        .await?;
    match answer.iter().find(|p| p.index == 1) {
        Some(part) => decode(part, "the ModifyDepositOutput"),
        // A false bool and an empty text have no bytes.
        None => Ok(ModifyDepositOutput::default()),
    }
}

/// `ModifyServiceSystemResources`: change the resources of the instance of the token
/// `token`, or read them. The call has the `ModifyServiceSystemResourcesInput` (index 1)
/// with `service_token` set, and the `Client` (2), which must be the father of the
/// instance. The answer (1) holds the resources that the instance has after the call and
/// its balance.
///
/// `max_sysreq` is the request. A field that is not set keeps the value of the node. A
/// `cpu_quota` or `mem_limit` of 0 hibernates the instance. Both above 0 on a
/// hibernated instance wake it: send `cpu_quota`, `cpu_period` and `mem_limit` together.
/// With `None` the request changes nothing and the answer holds the current resources.
/// The instance pays the fee of the call, not the client. A hibernation answer holds 0
/// for the CPU and the RAM: the node sends it before it stops the instance.
///
/// A receiver drops an all-default message (it has no bytes), so no part means an empty
/// answer.
pub async fn modify_system_resources<T: Transport>(
    transport: &T,
    token: &str,
    client_id: &str,
    max_sysreq: Option<Sysresources>,
) -> Result<ModifyServiceSystemResourcesOutput, WireError> {
    let input = ModifyServiceSystemResourcesInput {
        max_sysreq,
        service_token: token.to_string(),
        ..Default::default()
    };
    let answer = transport
        .call(
            "ModifyServiceSystemResources",
            vec![
                Part::new(1, input.encode_to_vec()),
                client_part(2, client_id),
            ],
            &[1],
        )
        .await?;
    match answer.iter().find(|p| p.index == 1) {
        Some(part) => decode(part, "the ModifyServiceSystemResourcesOutput"),
        None => Ok(ModifyServiceSystemResourcesOutput::default()),
    }
}

fn client_part(index: i32, client_id: &str) -> Part {
    let client = Client {
        client_id: client_id.to_string(),
        ..Default::default()
    };
    Part::new(index, client.encode_to_vec())
}

/// `GenerateDepositToken`: send the `Client` (index 1), get a `TokenMessage` (1) with a
/// new deposit token.
///
/// The node only writes the token in its database, as `pending` for this client
/// (`nodo:src/payment_system/payment_process.py`, `generate_deposit_token`). Nothing
/// goes on a ledger. The token is the text of a UUID4 with hyphens, and it expires
/// after one hour (`DEPOSIT_TOKEN_TTL`).
pub async fn generate_deposit_token<T: Transport>(
    transport: &T,
    client_id: &str,
) -> Result<String, WireError> {
    let answer = transport
        .call(
            "GenerateDepositToken",
            vec![client_part(1, client_id)],
            &[1],
        )
        .await?;
    let message: TokenMessage = find(&answer, 1, "TokenMessage")?;
    if message.token.is_empty() {
        return Err(WireError::Protocol(
            "the node gave an empty deposit token".to_string(),
        ));
    }
    Ok(message.token)
}

/// `Payable`: send the `Payment` (index 1) and the `Client` (2). The node accepts the
/// payment with an OK status and an empty answer (index 1 is `buffer.Empty`). It refuses
/// it with an error status.
///
/// The node makes one check per deposit token: after it, the token is `payed` or
/// `rejected` (`nodo:src/payment_system/payment_process.py`, `validate_payment_process`).
/// Call it only when the payment is visible to the node.
pub async fn payable<T: Transport>(
    transport: &T,
    client_id: &str,
    payment: &Payment,
) -> Result<(), WireError> {
    let parts = vec![
        Part::new(1, payment.encode_to_vec()),
        client_part(2, client_id),
    ];
    transport.call("Payable", parts, &[1]).await?;
    Ok(())
}
