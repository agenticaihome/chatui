//! One node and one client id on it (milestone M2).
//!
//! A [`NodeSession`] makes the client id once ([`crate::obtain_client_id`]), checks the
//! advertisement of the node with it, and keeps both. The node gives a new client its
//! free credit (`free_tier.CREDIT_MU_PER_NEW_CLIENT`), so each new session starts with
//! that balance.

use celaut_balancer::{amount, erg_rate};
use celaut_proto::celaut::service::Api;
use celaut_proto::celaut::{
    Configuration, EstimatedCost, ExecutionReceipt, Instance, Payment, Sysresources,
};
use celaut_wire::gateway::{
    generate_deposit_token, get_client_metrics, get_metrics, get_service_estimated_cost,
    get_service_estimated_cost_with_service, get_service_raw, get_service_skippable,
    modify_deposit, modify_system_resources, payable, start_service, stop_service, ServiceRequest,
};
use celaut_wire::{ReceiptSink, Transport, TunnelOpener, WireError};

use celaut_wire::statement::VerifiedStatement;

use crate::deposit::{check_deposit_token, BtcPayment, ErgPayment};
use crate::descendants::{
    self, quote_read, read_statement, DescendantError, DescendantRecord, ReadQuote,
};
use crate::{
    fetch_node_info_as, obtain_client_id, ClientError, NodeInfo, PeerStore, ResourcesError,
};

/// A service instance that this client started.
#[derive(Debug, Clone, PartialEq)]
pub struct StartedInstance {
    /// The instance token. It is a bearer secret: whoever has it can stop the
    /// instance and use its balance.
    pub token: String,
    /// The ports of the instance and their addresses.
    pub instance: Instance,
    /// The start receipt that the node signed (nodo#419), if it gave one. Not checked
    /// here: see [`crate::receipts::check_start`].
    pub receipt: Option<ExecutionReceipt>,
}

impl StartedInstance {
    /// The internal ports of the instance (`Instance.uri_slot[].internal_port`), the
    /// slots that `ServiceTunnel` accepts.
    pub fn slots(&self) -> Vec<u16> {
        self.instance
            .uri_slot
            .iter()
            .filter_map(|s| u16::try_from(s.internal_port).ok())
            .collect()
    }

    /// The slots that follow the chat convention (`docs/celaut/chat.md`, section 3), in
    /// the order of `Service.Api`. The client uses the first one.
    pub fn chat_slots(&self) -> Vec<u16> {
        chat_slots(&self.instance)
    }

    /// The slots that a browser can open (see [`web_slots`]), in the order of `Service.Api`.
    pub fn web_slots(&self) -> Vec<u16> {
        web_slots(&self.instance)
    }
}

/// The resources of an instance that the node answered after a change or a read of
/// `ModifyServiceSystemResources`, and the balance of the instance.
#[derive(Debug, Clone, PartialEq)]
pub struct ResourceChange {
    /// The resources in the answer. After a hibernation, the node sends 0 for the CPU and
    /// the RAM: they are not the resources that the instance had. After a wake, they
    /// are the resources that the instance has now.
    pub sysreq: Sysresources,
    /// The balance of the instance in MU, after the fee of the call.
    pub balance_mu: u128,
}

/// The first of `cpu_quota`, `cpu_period` and `mem_limit` that is not set or is 0.
fn first_unset(sysreq: &Sysresources) -> Option<&'static str> {
    [
        ("cpu_quota", sysreq.cpu_quota),
        ("cpu_period", sysreq.cpu_period),
        ("mem_limit", sysreq.mem_limit),
    ]
    .into_iter()
    .find(|(_, value)| value.is_none_or(|v| v == 0))
    .map(|(name, _)| name)
}

/// The tags of the chat slot, from bottom to top: `http2`, `grpc`, `chat`.
const CHAT_STACK: [&str; 3] = ["http2", "grpc", "chat"];

/// The ports of `api` that follow the chat convention: a slot with the transport `tcp`,
/// and a protocol stack that has `http2`, above it `grpc`, and above it `chat` (the stack
/// is written bottom to top), in the order of the interface (`docs/celaut/chat.md`,
/// section 3). A slot with the stack `http`, `chat` does not count. The reachability of a
/// port is not checked here: for a service that is not running, there is no instance yet.
pub fn api_chat_ports(api: &Api) -> Vec<u16> {
    let has = |tags: &[String], tag: &str| tags.iter().any(|t| t == tag);
    let mut found = Vec::new();
    for slot in &api.slot {
        let tcp = slot.transport.as_ref().is_some_and(|t| has(&t.tags, "tcp"));
        let mut wanted = CHAT_STACK.iter().peekable();
        for p in &slot.protocol_stack {
            if wanted.peek().is_some_and(|tag| has(&p.tags, tag)) {
                wanted.next();
            }
        }
        let follows = wanted.peek().is_none();
        let Ok(port) = u16::try_from(slot.port) else {
            continue;
        };
        if tcp && follows && !found.contains(&port) {
            found.push(port);
        }
    }
    found
}

/// The slots of `instance` that follow the chat convention (see [`api_chat_ports`]). A
/// slot counts only if the instance has that port, because `ServiceTunnel` accepts only
/// the ports of the instance.
pub fn chat_slots(instance: &Instance) -> Vec<u16> {
    let Some(api) = instance.api.as_ref() else {
        return Vec::new();
    };
    api_chat_ports(api)
        .into_iter()
        .filter(|port| {
            instance
                .uri_slot
                .iter()
                .any(|u| u16::try_from(u.internal_port) == Ok(*port))
        })
        .collect()
}

/// The ports of `api` that a browser can open: a slot with the transport `tcp` and a
/// protocol `http` in its stack, and no `chat` protocol (a service of the chat convention
/// has its own screen, and an old revision of it speaks JSON, not pages). Another
/// protocol above `http` that a browser does not speak (`grpc`, `http2`) does not count.
pub fn api_web_ports(api: &Api) -> Vec<u16> {
    let has = |tags: &[String], tag: &str| tags.iter().any(|t| t == tag);
    let mut found = Vec::new();
    for slot in &api.slot {
        let tcp = slot.transport.as_ref().is_some_and(|t| has(&t.tags, "tcp"));
        let stack = &slot.protocol_stack;
        let web = stack.iter().any(|p| has(&p.tags, "http"))
            && !stack
                .iter()
                .any(|p| has(&p.tags, "chat") || has(&p.tags, "grpc"));
        let Ok(port) = u16::try_from(slot.port) else {
            continue;
        };
        if tcp && web && !found.contains(&port) {
            found.push(port);
        }
    }
    found
}

/// The slots of `instance` that a browser can open (see [`api_web_ports`]). As for the
/// chat, a slot counts only if the instance has that port.
pub fn web_slots(instance: &Instance) -> Vec<u16> {
    let Some(api) = instance.api.as_ref() else {
        return Vec::new();
    };
    api_web_ports(api)
        .into_iter()
        .filter(|port| {
            instance
                .uri_slot
                .iter()
                .any(|u| u16::try_from(u.internal_port) == Ok(*port))
        })
        .collect()
}

/// A client on one node.
#[derive(Debug)]
pub struct NodeSession<T: Transport> {
    transport: T,
    client_id: String,
    info: NodeInfo,
}

impl<T: Transport> NodeSession<T> {
    /// Make a client id on the node and check its advertisement. `peer_id` is the
    /// identity that the TLS certificate proved.
    pub async fn open(
        transport: T,
        peer_id: &str,
        store: &dyn PeerStore,
    ) -> Result<Self, ClientError> {
        let client_id = obtain_client_id(&transport).await?;
        let info = fetch_node_info_as(&transport, &client_id, peer_id, store).await?;
        Ok(NodeSession {
            transport,
            client_id,
            info,
        })
    }

    /// A session with the client id that the app already has on the node, so that its
    /// balance on the node stays usable. The advertisement is checked as in
    /// [`NodeSession::open`].
    pub async fn resume(
        transport: T,
        peer_id: &str,
        client_id: String,
        store: &dyn PeerStore,
    ) -> Result<Self, ClientError> {
        let info = fetch_node_info_as(&transport, &client_id, peer_id, store).await?;
        Ok(NodeSession {
            transport,
            client_id,
            info,
        })
    }

    /// The identity of the node.
    pub fn peer_id(&self) -> &str {
        &self.info.peer_id
    }

    /// The checked advertisement of the node.
    pub fn info(&self) -> &NodeInfo {
        &self.info
    }

    /// The client id on this node. A bearer secret, as an instance token.
    pub fn client_id(&self) -> &str {
        &self.client_id
    }

    /// The transport to the node.
    pub fn transport(&self) -> &T {
        &self.transport
    }

    /// The MU per nanoERG of the node, if it gives a rate for ERG.
    pub fn mu_per_nano_erg(&self) -> Option<u128> {
        erg_rate(&self.info.peer).ok()
    }

    /// The request for a service, with the guard of a light client (no delegation).
    pub fn request(&self, service_id: [u8; 32], configuration: Configuration) -> ServiceRequest {
        ServiceRequest {
            client_id: self.client_id.clone(),
            service_id,
            configuration,
        }
    }

    /// `GetServiceEstimatedCost`.
    pub async fn quote(
        &self,
        service_id: [u8; 32],
        configuration: Configuration,
    ) -> Result<EstimatedCost, ClientError> {
        let request = self.request(service_id, configuration);
        Ok(get_service_estimated_cost(&self.transport, &request).await?)
    }

    /// `GetService`: the Buffers of the service, as the node sends them, for another
    /// node (`crate::package`). A node that does not have the service gives nothing.
    pub async fn get_service(
        &self,
        service_id: [u8; 32],
    ) -> Result<celaut_wire::Buffers, ClientError> {
        Ok(get_service_raw(&self.transport, &self.client_id, service_id).await?)
    }

    /// `GetService` for a reader that describes the service and does not need its
    /// filesystem: the Buffers, and a way to ask the node to skip the block that holds it
    /// (`crate::service_info`). Not for a transfer to another node, which needs it all.
    pub async fn get_service_skippable(
        &self,
        service_id: [u8; 32],
    ) -> Result<celaut_wire::RawAnswer, ClientError> {
        Ok(get_service_skippable(&self.transport, &self.client_id, service_id).await?)
    }

    /// `GetServiceEstimatedCost` with the service: the node stores `service`, and gives
    /// the price. After it, the node has the service, and the other calls need only its
    /// hash. `skips` takes the blocks that the node says it holds: wrap `service` with
    /// [`celaut_wire::Skips::wrap`] to stop them.
    pub async fn quote_with_service(
        &self,
        service_id: [u8; 32],
        configuration: Configuration,
        service: celaut_wire::Buffers,
        skips: &celaut_wire::Skips,
    ) -> Result<EstimatedCost, ClientError> {
        let request = self.request(service_id, configuration);
        Ok(
            get_service_estimated_cost_with_service(&self.transport, &request, service, skips)
                .await?,
        )
    }

    /// `StartService`. The node charges the cost to the balance of this client.
    pub async fn start(
        &self,
        service_id: [u8; 32],
        configuration: Configuration,
    ) -> Result<StartedInstance, ClientError> {
        let request = self.request(service_id, configuration);
        let answer = start_service(&self.transport, &request).await?;
        Ok(StartedInstance {
            token: answer.token,
            instance: answer.instance.unwrap_or_default(),
            receipt: answer.receipt,
        })
    }

    /// `StopService`. Gives the refund in MU of the node: the unused balance of the
    /// instance, which goes back to this client.
    pub async fn stop(&self, token: &str) -> Result<u128, ClientError> {
        let refund = stop_service(&self.transport, token, &self.client_id).await?;
        Ok(amount(refund.amount.as_ref())?)
    }

    /// `ModifyServiceSystemResources` with no change: read the resources that the instance
    /// has now (`cpu_quota`, `cpu_period`, `mem_limit`, `disk_space`) and its balance.
    /// The node has no free read. This call costs the instance one fee for a change of
    /// resources, and it changes nothing. Call it just before [`Self::hibernate`], and
    /// store the result: these are the resources that [`Self::wake`] must send.
    ///
    /// An error if `cpu_quota`, `cpu_period` or `mem_limit` is 0 or not set: the
    /// instance is hibernated (by this client or by itself), and there is nothing to store
    /// ([`ResourcesError::NotReadable`]). Do not use the launch resources of
    /// `StartService` in place of this read: the instance may have a different size now.
    pub async fn current_resources(&self, token: &str) -> Result<ResourceChange, ClientError> {
        let change = self.change_resources(token, None).await?;
        if let Some(field) = first_unset(&change.sysreq) {
            return Err(ResourcesError::NotReadable(field).into());
        }
        Ok(change)
    }

    /// Hibernate the instance: `ModifyServiceSystemResources` with `cpu_quota` and
    /// `mem_limit` at 0. After it the instance costs its disk only. The node sends the
    /// answer before it stops the VM, and the answer has no resources of before: read
    /// them with [`Self::current_resources`] and store them first. The instance pays the
    /// fee. The node refuses an instance with a shared filesystem or one that it cannot
    /// start again from its own disk ([`crate::ResourceRefusal`]).
    pub async fn hibernate(&self, token: &str) -> Result<ResourceChange, ClientError> {
        let zero = Sysresources {
            cpu_quota: Some(0),
            mem_limit: Some(0),
            ..Default::default()
        };
        self.change_resources(token, Some(zero)).await
    }

    /// Wake a hibernated instance with `resources`. `cpu_quota`, `cpu_period` and
    /// `mem_limit` must be set and above 0: the node keeps 0 for a field that is not set,
    /// and a wake with one field cannot work. If one is missing, this gives
    /// [`ResourcesError::WakeIncomplete`] and makes no call. Only these three fields go
    /// to the node, whatever else `resources` has. The wake runs the entrypoint again:
    /// the state of the process is lost, and the address and the ports stay. The answer
    /// has the resources that the instance has now. If the node has no room, the instance
    /// stays hibernated and the call is refunded ([`crate::ResourceRefusal::DoesNotFit`]).
    pub async fn wake(
        &self,
        token: &str,
        resources: &Sysresources,
    ) -> Result<ResourceChange, ClientError> {
        if let Some(field) = first_unset(resources) {
            return Err(ResourcesError::WakeIncomplete(field).into());
        }
        let request = Sysresources {
            cpu_quota: resources.cpu_quota,
            cpu_period: resources.cpu_period,
            mem_limit: resources.mem_limit,
            ..Default::default()
        };
        self.change_resources(token, Some(request)).await
    }

    async fn change_resources(
        &self,
        token: &str,
        max_sysreq: Option<Sysresources>,
    ) -> Result<ResourceChange, ClientError> {
        let answer =
            modify_system_resources(&self.transport, token, &self.client_id, max_sysreq).await?;
        Ok(ResourceChange {
            sysreq: answer.sysreq.unwrap_or_default(),
            balance_mu: amount(answer.balance.as_ref())?,
        })
    }

    /// `ModifyDeposit`: move `mu` MU of the credit of this client on the node to the
    /// instance `token`. Nothing goes on a ledger. An error if the node did not move it.
    pub async fn top_up(&self, token: &str, mu: u128) -> Result<(), ClientError> {
        let answer = modify_deposit(&self.transport, token, &self.client_id, mu).await?;
        if answer.success {
            Ok(())
        } else {
            Err(ClientError::Protocol(format!(
                "the node did not move the credit: {}",
                answer.message
            )))
        }
    }

    /// `GetClientMetrics` for this client: its balance in MU of the node. A node that
    /// does not know the RPC is partially incompatible, and there is no fallback.
    pub async fn balance(&self) -> Result<u128, ClientError> {
        let metrics = get_client_metrics(&self.transport, &self.client_id)
            .await
            .map_err(missing_client_metrics)?;
        Ok(amount(metrics.balance.as_ref())?)
    }

    /// `GetMetrics` for an instance: its balance in MU of the node.
    pub async fn instance_balance(&self, token: &str) -> Result<u128, ClientError> {
        let metrics = get_metrics(&self.transport, token).await?;
        Ok(amount(metrics.balance.as_ref())?)
    }

    /// The ERG payment contract of the node, from the checked advertisement.
    pub fn erg_payment(&self) -> Result<ErgPayment, ClientError> {
        Ok(ErgPayment::of(&self.info.peer)?)
    }

    /// The Bitcoin networks on which the node takes BTC, from the checked advertisement.
    pub fn btc_networks(&self) -> Vec<String> {
        BtcPayment::networks(&self.info.peer)
    }

    /// The BTC payment contract of the node on the Bitcoin network `network`, from the
    /// checked advertisement.
    pub fn btc_payment(&self, network: &str) -> Result<BtcPayment, ClientError> {
        Ok(BtcPayment::of(&self.info.peer, network)?)
    }

    /// `GenerateDepositToken` for this client. The node only writes the token in its
    /// database; nothing goes on a ledger. The token is checked before it is given,
    /// because the wallet writes it on the ledger.
    pub async fn deposit_token(&self) -> Result<String, ClientError> {
        let token = generate_deposit_token(&self.transport, &self.client_id).await?;
        check_deposit_token(&token)?;
        Ok(token)
    }

    /// `Payable` for this client. The node checks a deposit token once only: call it
    /// when the deposit box is visible on the explorer of the node.
    pub async fn payable(&self, payment: &Payment) -> Result<(), ClientError> {
        Ok(payable(&self.transport, &self.client_id, payment).await?)
    }
}

impl<T: Transport> NodeSession<T> {
    /// The quote for the next read of the statement of `record` on this node: the most MU
    /// that it can cost. It sends nothing. Show it to the user and read only after a yes.
    pub fn quote_statement(
        &self,
        record: &DescendantRecord,
        remaining_hops: u32,
    ) -> Result<ReadQuote, DescendantError> {
        quote_read(
            record,
            descendants::rates_of(&self.info.peer),
            remaining_hops,
        )
    }

    /// The quote for the streams of a tunnel to `record`: the most MU that one stream can
    /// cost to open. It sends nothing. Show it to the user and open the tunnel only after
    /// a yes ([`descendants::TunnelQuote::streams_for`]).
    pub fn quote_tunnel(
        &self,
        record: &DescendantRecord,
        remaining_hops: u32,
    ) -> Result<descendants::TunnelQuote, DescendantError> {
        descendants::quote_tunnel(record, &self.info.peer, remaining_hops)
    }

    /// Read one statement of `record` (`GetBalanceStatement` with `instance_ref`). This is
    /// one paid call: it never repeats, and the caller must ask the user for each read.
    /// `max_mu` is the budget that the user confirmed. If the maximum cost of `quote` is
    /// above it, nothing is sent ([`DescendantError::OverBudget`]).
    pub async fn read_statement(
        &self,
        record: &DescendantRecord,
        quote: &ReadQuote,
        max_mu: u128,
    ) -> Result<VerifiedStatement, DescendantError> {
        read_statement(
            &self.transport,
            &self.info.peer_id,
            &self.client_id,
            record,
            quote,
            max_mu,
            unix_now(),
        )
        .await
    }
}

impl<T: Transport + TunnelOpener> NodeSession<T> {
    /// Open a tunnel to port `slot` of the descendant `record`, through the token of the
    /// held instance (`DescendantTunnel`). The receipts go to `receipts`: use
    /// [`descendants::receipt_sink`] to keep them with the descendant. A node that does
    /// not know descendants ends the stream with `WireError::NoDescendants`. The call
    /// goes on the transport of the session, so with Tor on it uses the route of the app.
    ///
    /// `remaining_hops`, if given, is limited to [`descendants::MAX_REMAINING_HOPS`]. The
    /// tunnel costs the opening fee, and the app asks the user as for a normal tunnel.
    pub fn open_descendant_tunnel(
        &self,
        record: &DescendantRecord,
        slot: u16,
        remaining_hops: Option<u32>,
        receipts: Option<ReceiptSink>,
    ) -> Result<celaut_wire::Tunnel, DescendantError> {
        if record.depth == 0 {
            return Err(DescendantError::NotADescendant);
        }
        if record.peer_id != self.info.peer_id {
            return Err(DescendantError::OtherNode);
        }
        if let Some(hops) = remaining_hops {
            if hops == 0 || hops > descendants::MAX_REMAINING_HOPS {
                return Err(DescendantError::BadHops {
                    hops,
                    max: descendants::MAX_REMAINING_HOPS,
                });
            }
        }
        Ok(self.transport.open_descendant_tunnel(
            &record.parent_token,
            &record.instance_ref,
            slot,
            remaining_hops,
            receipts,
        ))
    }
}

/// The time of the app in Unix seconds, for the date check of a statement.
fn unix_now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| i64::try_from(d.as_secs()).unwrap_or(i64::MAX))
}

/// A service id from 64 hexadecimal characters.
pub fn parse_service_id(text: &str) -> Option<[u8; 32]> {
    let text = text.trim();
    if text.len() != 64 {
        return None;
    }
    let bytes = hex::decode(text.to_ascii_lowercase()).ok()?;
    bytes.try_into().ok()
}

#[cfg(test)]
mod chat_slot_tests {
    use super::*;
    use celaut_proto::celaut::instance::UriSlot;
    use celaut_proto::celaut::service::api::{Protocol, Slot};
    use celaut_proto::celaut::service::Api;

    fn protocol(tags: &[&str]) -> Protocol {
        Protocol {
            tags: tags.iter().map(|t| t.to_string()).collect(),
            ..Default::default()
        }
    }

    fn slot(port: i32, transport: &str, stack: &[&[&str]]) -> Slot {
        Slot {
            port,
            transport: Some(protocol(&[transport])),
            protocol_stack: stack.iter().map(|tags| protocol(tags)).collect(),
            ..Default::default()
        }
    }

    /// An instance with these `Service.Api` slots, and every port in `uri_slot`.
    fn instance(slots: Vec<Slot>) -> Instance {
        let uri_slot = slots
            .iter()
            .map(|s| UriSlot {
                internal_port: s.port,
                uri: Vec::new(),
            })
            .collect();
        Instance {
            api: Some(Api {
                slot: slots,
                ..Default::default()
            }),
            uri_slot,
        }
    }

    #[test]
    fn tcp_http_is_a_web_slot() {
        let i = instance(vec![slot(80, "tcp", &[&["http"]])]);
        assert_eq!(web_slots(&i), vec![80]);
        assert!(chat_slots(&i).is_empty());
    }

    #[test]
    fn a_service_can_have_a_chat_slot_and_a_web_slot() {
        let i = instance(vec![
            slot(8080, "tcp", &[&["http2"], &["grpc"], &["chat"]]),
            slot(3000, "tcp", &[&["http"]]),
        ]);
        assert_eq!(chat_slots(&i), vec![8080]);
        assert_eq!(web_slots(&i), vec![3000]);
    }

    #[test]
    fn grpc_chat_and_udp_are_not_web_slots() {
        let grpc = instance(vec![slot(1, "tcp", &[&["http2"], &["grpc"]])]);
        let old_chat = instance(vec![slot(2, "tcp", &[&["http"], &["chat"]])]);
        let udp = instance(vec![slot(3, "udp", &[&["http"]])]);
        let absent = Instance {
            api: Some(Api {
                slot: vec![slot(4, "tcp", &[&["http"]])],
                ..Default::default()
            }),
            uri_slot: Vec::new(),
        };
        for i in [grpc, old_chat, udp, absent] {
            assert!(web_slots(&i).is_empty());
        }
    }

    #[test]
    fn http2_grpc_chat_is_a_chat_slot() {
        let i = instance(vec![slot(8080, "tcp", &[&["http2"], &["grpc"], &["chat"]])]);
        assert_eq!(chat_slots(&i), vec![8080]);
    }

    #[test]
    fn the_slots_keep_the_order_of_the_api_and_other_slots_are_left_out() {
        let i = instance(vec![
            slot(22, "tcp", &[&["ssh"]]),
            slot(
                9000,
                "tcp",
                &[&["http2", "h2c"], &["grpc", "proto"], &["chat", "text"]],
            ),
            slot(8080, "tcp", &[&["tls"], &["http2"], &["grpc"], &["chat"]]),
            slot(8081, "tcp", &[&["http2"], &["grpc"]]),
        ]);
        assert_eq!(chat_slots(&i), vec![9000, 8080]);
    }

    #[test]
    fn a_wrong_or_incomplete_stack_is_not_a_chat_slot() {
        let i = instance(vec![
            slot(1, "tcp", &[&["chat"], &["grpc"], &["http2"]]),
            slot(2, "tcp", &[&["chat"]]),
            slot(3, "tcp", &[&["grpc"], &["chat"]]),
            slot(4, "tcp", &[&["http"], &["chat"]]),
            slot(5, "tcp", &[&["http"], &["grpc"], &["chat"]]),
            slot(6, "tcp", &[&["http2"], &["chat"]]),
            slot(7, "tcp", &[&["http2"], &["chat"], &["grpc"]]),
        ]);
        assert!(chat_slots(&i).is_empty());
    }

    #[test]
    fn a_udp_slot_is_not_a_chat_slot() {
        let i = instance(vec![slot(8080, "udp", &[&["http2"], &["grpc"], &["chat"]])]);
        assert!(chat_slots(&i).is_empty());
        let mut no_transport = slot(8080, "tcp", &[&["http2"], &["grpc"], &["chat"]]);
        no_transport.transport = None;
        assert!(chat_slots(&instance(vec![no_transport])).is_empty());
    }

    #[test]
    fn a_port_that_the_instance_does_not_have_is_left_out() {
        let mut i = instance(vec![slot(8080, "tcp", &[&["http2"], &["grpc"], &["chat"]])]);
        i.uri_slot.clear();
        assert!(chat_slots(&i).is_empty());
    }

    #[test]
    fn a_port_that_is_not_a_u16_is_left_out() {
        let i = instance(vec![
            slot(0x1_0000, "tcp", &[&["http2"], &["grpc"], &["chat"]]),
            slot(-1, "tcp", &[&["http2"], &["grpc"], &["chat"]]),
        ]);
        assert!(chat_slots(&i).is_empty());
    }

    #[test]
    fn a_repeated_port_counts_once() {
        let i = instance(vec![
            slot(8080, "tcp", &[&["http2"], &["grpc"], &["chat"]]),
            slot(8080, "tcp", &[&["http2"], &["grpc"], &["chat"]]),
        ]);
        assert_eq!(chat_slots(&i), vec![8080]);
    }

    #[test]
    fn an_instance_with_no_api_has_no_chat_slot() {
        let i = Instance {
            api: None,
            uri_slot: Vec::new(),
        };
        assert!(chat_slots(&i).is_empty());
    }

    #[test]
    fn started_instance_gives_its_chat_slots() {
        let started = StartedInstance {
            token: "t".into(),
            instance: instance(vec![slot(8080, "tcp", &[&["http2"], &["grpc"], &["chat"]])]),
            receipt: None,
        };
        assert_eq!(started.chat_slots(), vec![8080]);
        assert_eq!(started.slots(), vec![8080]);
    }
}

/// The texts of a node that has no `GetClientMetrics`: a gRPC "unimplemented" status or a
/// bee-rpc "method not found".
const MISSING_RPC_TEXTS: [&str; 3] = ["unimplemented", "method not found", "unknown method"];

/// Says what is wrong when the node has no `GetClientMetrics`. It does not tell the user
/// to update the node.
fn missing_client_metrics(error: WireError) -> ClientError {
    if let WireError::Call(text) = &error {
        let lower = text.to_ascii_lowercase();
        if MISSING_RPC_TEXTS.iter().any(|t| lower.contains(t)) {
            return ClientError::Protocol(
                "the node interface is partially incompatible: it has no GetClientMetrics"
                    .to_string(),
            );
        }
    }
    error.into()
}

#[cfg(test)]
mod missing_rpc_tests {
    use super::*;

    #[test]
    fn a_node_with_no_get_client_metrics_is_called_partially_incompatible() {
        let err = missing_client_metrics(WireError::Call(
            "status: Unimplemented, message: \"Method not found: GetClientMetrics\"".into(),
        ));
        let text = err.to_string();
        assert!(text.contains("partially incompatible"), "{text}");
        assert!(!text.to_ascii_lowercase().contains("update"), "{text}");
    }

    #[test]
    fn other_errors_pass_unchanged() {
        let err = missing_client_metrics(WireError::Timeout);
        assert!(matches!(err, ClientError::Wire(WireError::Timeout)));
    }
}
