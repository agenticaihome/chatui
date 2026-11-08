//! What a service says about itself (`docs/celaut/service-info.md`): its prose, the
//! architecture and the resources that it needs, the environment variables, the interface,
//! the networks that it declares, and whether its interface is the chat convention of the
//! app (`docs/celaut/chat.md`).
//!
//! The app reads these from the `Service` part as a stream, from the file of the service
//! in the library or from a node that has it, and never keeps the filesystem of the
//! container (`celaut_client::service_info`).

use std::path::PathBuf;

use celaut_client::service_info::{read_service_info, read_service_info_of_file, ServiceInfo};
use celaut_proto::celaut::service::api::{Protocol, Slot};
use celaut_proto::celaut::service::{Clause, Network};
use celaut_proto::celaut::{AmountKeyValue, Sysresources, Uint64KeyValue};

use super::celaut::{error_of, invalid, CelautError};
use super::celaut_db::db;
use super::celaut_env::DeclaredVariableView;
use super::celaut_package::package_error;
use super::celaut_service::{forget_if_broken, service_id, session, NodeAddress};

/// The most that the app reads from a node to describe a service, in bytes. The app asks
/// the node to skip the block of the filesystem, so a service is a few kilobytes plus what
/// was on the way when the request arrived. This is for a node that does not skip, which
/// sends the filesystem before the interface and the networks: a larger service is then
/// described only by what comes before it.
pub(crate) const NODE_READ_LIMIT: u64 = 128 * 1024 * 1024;

/// A protocol of an interface or of a network.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProtocolView {
    /// The names of the protocol, for example `http`.
    pub tags: Vec<String>,
    /// The text that explains it (empty if the service gives none).
    pub prose: String,
}

/// A name and a value, as text.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NamedValueView {
    pub key: String,
    pub value: String,
}

/// The resources of one instance. A value that the service does not set is none.
#[derive(Debug, Clone, PartialEq)]
pub struct SysresourcesView {
    /// The cores: the CPU quota divided by the CPU period (100 000 if absent).
    pub cpu_cores: Option<f64>,
    /// The memory, in bytes.
    pub mem_bytes: Option<u64>,
    /// The disk space, in bytes.
    pub disk_bytes: Option<u64>,
    /// The block I/O weight, from 10 to 1000.
    pub blkio_weight: Option<u64>,
    /// The scores of one core on named operations (`int_ops_per_sec`, …).
    pub benchmark: Vec<NamedValueView>,
}

/// One port of the interface of the service.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ApiSlotView {
    /// The port inside the container.
    pub port: i32,
    /// The tags of the transport, for example `tcp`.
    pub transport: Vec<String>,
    /// The protocols on the transport, bottom to top.
    pub protocol_stack: Vec<ProtocolView>,
    /// MU for each call, by method name. Only for information.
    pub mu_per_call: Vec<NamedValueView>,
    /// True if this port follows the chat convention.
    pub chat: bool,
}

/// A domain where the instances of the service find their peers.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetworkView {
    /// The names of the domain: a host name, `pow:ergo`, or `*` for every address.
    pub tags: Vec<String>,
    pub prose: String,
    /// The parameters, as `key=value` lines (empty if there are none).
    pub formal: String,
    /// The protocols that the peers of the domain must speak.
    pub protocol_stack: Vec<ProtocolView>,
}

/// Identical descendant instances that the service declares (nodo#538). The service
/// needs every clause; in a clause it uses one group; a group runs all its workloads.
#[derive(Debug, Clone, PartialEq)]
pub struct WorkloadView {
    /// True for instances that the service starts at its start
    /// (`initial_environment_workload`). The start funds them
    /// (`EstimatedCost.children_initial_cost`). False for instances that it can start
    /// later (`possible_environment_workload`).
    pub initial: bool,
    /// The clause, from 0, in its field.
    pub clause: u32,
    /// The group, from 0, in its clause.
    pub group: u32,
    /// How many groups the clause has. With more than 1, the service uses one of them.
    pub groups: u32,
    pub count: u32,
    /// The resources at the start of the service of the workload, if it gives them.
    pub resources: Option<SysresourcesView>,
    /// True if the workload is for a service (with its hash or its specification).
    pub has_dependency: bool,
}

/// The workloads of the clauses of one field, in order.
fn workload_views(clauses: &[Clause], initial: bool) -> Vec<WorkloadView> {
    let mut views = Vec::new();
    for (c, clause) in clauses.iter().enumerate() {
        for (g, group) in clause.any_of.iter().enumerate() {
            for w in &group.workloads {
                let service = w.dependency.as_ref().and_then(|d| d.service.as_ref());
                let resources = service
                    .and_then(|s| s.container.as_ref())
                    .and_then(|c| c.resources.as_ref())
                    .and_then(|r| r.at_init.as_ref());
                views.push(WorkloadView {
                    initial,
                    clause: c as u32,
                    group: g as u32,
                    groups: clause.any_of.len() as u32,
                    count: w.count,
                    resources: resources.map(resources_view),
                    has_dependency: w.dependency.is_some(),
                });
            }
        }
    }
    views
}

/// Whether the interface of the service is the chat convention of the app.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChatSupportView {
    /// A port follows the convention: `tcp`, then `http2`, `grpc` and `chat` above it.
    Supported,
    /// The interface is known and no port follows the convention.
    Unsupported,
    /// The app could not read the interface (the service was too large to read from a
    /// node, or the interface was too large to decode). It is not the same as unsupported.
    Unknown,
}

/// What the service says about itself.
#[derive(Debug, Clone, PartialEq)]
pub struct ServiceInfoView {
    pub prose: String,
    /// The names of the architecture, for example `linux/arm64`.
    pub architecture: Vec<String>,
    /// The size of the filesystem of the container, in bytes. The app does not read it.
    pub filesystem_bytes: u64,
    /// The path of the executable that the node starts.
    pub entry_path: Vec<String>,
    /// The resources that the instance needs at the start.
    pub resources_at_init: Option<SysresourcesView>,
    /// The most that the instance can use.
    pub resources_at_most: Option<SysresourcesView>,
    /// The path of the configuration file in the container.
    pub config_path: Vec<String>,
    /// The protocols that the service expects from the node.
    pub node_protocols: Vec<ProtocolView>,
    /// The environment variables that the service declares.
    pub environment: Vec<DeclaredVariableView>,
    pub slots: Vec<ApiSlotView>,
    pub networks: Vec<NetworkView>,
    pub workloads: Vec<WorkloadView>,
    /// How many clauses were too large to read, because they carry a whole service.
    pub workloads_skipped: u32,
    /// How many other parts were too large to read. Each is unknown, not absent.
    pub parts_skipped: u32,
    /// True if the interface was too large to read, so the chat check cannot tell.
    pub api_skipped: bool,
    pub chat: ChatSupportView,
    /// The first port that follows the chat convention.
    pub chat_port: Option<u16>,
    /// True if the service was too large to read from a node. What is after the
    /// filesystem (the interface, the networks, the environment variables, the resources)
    /// is then unknown, not empty.
    pub truncated: bool,
}

fn protocol_view(p: &Protocol) -> ProtocolView {
    ProtocolView {
        tags: p.tags.clone(),
        prose: p.prose.clone(),
    }
}

fn amounts(list: &[AmountKeyValue]) -> Vec<NamedValueView> {
    list.iter()
        .map(|e| NamedValueView {
            key: e.key.clone(),
            value: e.value.as_ref().map(|a| a.n.clone()).unwrap_or_default(),
        })
        .collect()
}

fn scores(list: &[Uint64KeyValue]) -> Vec<NamedValueView> {
    list.iter()
        .filter_map(|e| {
            e.value.map(|v| NamedValueView {
                key: e.key.clone(),
                value: v.to_string(),
            })
        })
        .collect()
}

fn resources_view(r: &Sysresources) -> SysresourcesView {
    let period = r.cpu_period.filter(|p| *p > 0).unwrap_or(100_000);
    SysresourcesView {
        cpu_cores: r.cpu_quota.map(|q| q as f64 / period as f64),
        mem_bytes: r.mem_limit,
        disk_bytes: r.disk_space,
        blkio_weight: r.blkio_weight,
        benchmark: scores(&r.benchmark),
    }
}

fn slot_view(s: &Slot, chat_ports: &[u16]) -> ApiSlotView {
    ApiSlotView {
        port: s.port,
        transport: s
            .transport
            .as_ref()
            .map(|t| t.tags.clone())
            .unwrap_or_default(),
        protocol_stack: s.protocol_stack.iter().map(protocol_view).collect(),
        mu_per_call: amounts(&s.mu_per_call),
        chat: u16::try_from(s.port).is_ok_and(|p| chat_ports.contains(&p)),
    }
}

fn network_view(n: &Network) -> NetworkView {
    NetworkView {
        tags: n.tags.clone(),
        prose: n.prose.clone(),
        formal: String::from_utf8_lossy(&n.formal).trim().to_string(),
        protocol_stack: n.protocol_stack.iter().map(protocol_view).collect(),
    }
}

/// The view for the screen of a [`ServiceInfo`].
pub(crate) fn view_of(info: ServiceInfo) -> ServiceInfoView {
    let chat_ports = info.chat_ports();
    let chat = if !info.interface_known() {
        ChatSupportView::Unknown
    } else if chat_ports.is_empty() {
        ChatSupportView::Unsupported
    } else {
        ChatSupportView::Supported
    };
    let container = info.resources.as_ref();
    ServiceInfoView {
        prose: info.prose,
        architecture: info
            .architecture
            .as_ref()
            .map(|a| a.tags.clone())
            .unwrap_or_default(),
        filesystem_bytes: info.filesystem_bytes,
        entry_path: info
            .init
            .as_ref()
            .map(|i| i.entry_path.clone())
            .unwrap_or_default(),
        resources_at_init: container
            .and_then(|r| r.at_init.as_ref())
            .map(resources_view),
        resources_at_most: container
            .and_then(|r| r.at_most.as_ref())
            .map(resources_view),
        config_path: info
            .config
            .as_ref()
            .map(|c| c.path.clone())
            .unwrap_or_default(),
        node_protocols: info.node_protocol_stack.iter().map(protocol_view).collect(),
        environment: info
            .environment
            .into_iter()
            .map(|d| DeclaredVariableView {
                name: d.name,
                tags: d.tags,
                prose: d.prose,
            })
            .collect(),
        slots: info
            .api
            .as_ref()
            .map(|a| a.slot.iter().map(|s| slot_view(s, &chat_ports)).collect())
            .unwrap_or_default(),
        networks: info.networks.iter().map(network_view).collect(),
        workloads: workload_views(&info.initial_workloads, true)
            .into_iter()
            .chain(workload_views(&info.workloads, false))
            .collect(),
        workloads_skipped: info.workloads_skipped,
        parts_skipped: info.parts_skipped,
        api_skipped: info.api_skipped,
        chat,
        chat_port: chat_ports.first().copied(),
        truncated: info.truncated,
    }
}

/// What the service `service_id_hex` says about itself. The app reads it from the file of
/// the service in the library if it has one. If not, from `node` (a node that has the
/// service), which is asked to skip the block of the filesystem, so the read takes a few
/// kilobytes. A node that does not skip sends the whole service: the app stops after
/// 128 MiB and gives what came before, with `truncated` set. The app never keeps the
/// filesystem, so the memory that this takes does not depend on the size of the service.
#[flutter_rust_bridge::frb]
pub async fn celaut_service_info(
    service_id_hex: String,
    node: Option<NodeAddress>,
) -> Result<ServiceInfoView, CelautError> {
    Ok(view_of(read_info(&service_id_hex, node).await?))
}

/// The [`ServiceInfo`] of [`celaut_service_info`], before the view.
pub(crate) async fn read_info(
    service_id_hex: &str,
    node: Option<NodeAddress>,
) -> Result<ServiceInfo, CelautError> {
    let id = service_id(service_id_hex)?;
    let library = db()
        .read(|d| {
            d.packages
                .get(&hex::encode(id))
                .map(|p| PathBuf::from(&p.path))
        })
        .filter(|p| p.is_file());
    let info = if let Some(path) = library {
        read_service_info_of_file(&path)
            .await
            .map_err(package_error)?
    } else {
        let node = node.ok_or_else(|| invalid("There is no node to read the service from."))?;
        let s = session(&node).await?;
        // The node is asked to skip the block that holds the filesystem: the app needs the
        // parts around it, and not its hundreds of megabytes. A node that does not skip sends
        // it, and the limit stops the read.
        let answer = s.get_service_skippable(id).await.map_err(|e| {
            forget_if_broken(&node, &e);
            error_of(e)
        })?;
        read_service_info(answer.buffers, Some(NODE_READ_LIMIT), answer.skipper)
            .await
            .map_err(package_error)?
    };
    Ok(info)
}

#[cfg(test)]
mod tests {
    use super::*;
    use celaut_client::service_info::Declared;
    use celaut_proto::celaut::service::api::Slot;
    use celaut_proto::celaut::service::container::{Architecture, Init, Resources};
    use celaut_proto::celaut::service::Api;
    use celaut_proto::celaut::Amount;

    fn protocol(tags: &[&str]) -> Protocol {
        Protocol {
            tags: tags.iter().map(|t| t.to_string()).collect(),
            prose: String::new(),
            formal: Vec::new(),
        }
    }

    fn chat_slot(port: i32) -> Slot {
        Slot {
            port,
            transport: Some(protocol(&["tcp"])),
            protocol_stack: vec![
                protocol(&["http2"]),
                protocol(&["grpc"]),
                protocol(&["chat"]),
            ],
            mu_per_call: vec![AmountKeyValue {
                key: "send".into(),
                value: Some(Amount { n: "5".into() }),
            }],
        }
    }

    fn info() -> ServiceInfo {
        ServiceInfo {
            prose: "p".into(),
            architecture: Some(Architecture {
                tags: vec!["linux/amd64".into()],
                ..Default::default()
            }),
            filesystem_bytes: 123,
            init: Some(Init {
                entry_path: vec!["bin".into(), "run".into()],
                xattrs: Vec::new(),
            }),
            resources: Some(Resources {
                at_init: Some(Sysresources {
                    cpu_quota: Some(150_000),
                    mem_limit: Some(1 << 20),
                    benchmark: vec![
                        Uint64KeyValue {
                            key: "int_ops_per_sec".into(),
                            value: Some(7),
                        },
                        Uint64KeyValue {
                            key: "unset".into(),
                            value: None,
                        },
                    ],
                    ..Default::default()
                }),
                at_most: None,
            }),
            environment: vec![Declared {
                name: "KEY".into(),
                tags: vec!["text".into()],
                prose: "a key".into(),
            }],
            api: Some(Api {
                slot: vec![
                    Slot {
                        port: 53,
                        transport: Some(protocol(&["udp"])),
                        ..Default::default()
                    },
                    chat_slot(8080),
                ],
                payment_contracts: Vec::new(),
            }),
            networks: vec![Network {
                tags: vec!["*".into()],
                formal: b"pow.chain=ergo\n".to_vec(),
                ..Default::default()
            }],
            ..Default::default()
        }
    }

    #[test]
    fn the_view_has_every_part_and_the_chat_port() {
        let v = view_of(info());
        assert_eq!(v.architecture, ["linux/amd64"]);
        assert_eq!(v.filesystem_bytes, 123);
        assert_eq!(v.entry_path, ["bin", "run"]);
        let at_init = v.resources_at_init.unwrap();
        assert_eq!(at_init.cpu_cores, Some(1.5));
        assert_eq!(at_init.mem_bytes, Some(1 << 20));
        assert_eq!(
            at_init.benchmark,
            vec![NamedValueView {
                key: "int_ops_per_sec".into(),
                value: "7".into()
            }]
        );
        assert!(v.resources_at_most.is_none());
        assert_eq!(v.environment[0].name, "KEY");
        assert_eq!(v.slots.len(), 2);
        assert!(!v.slots[0].chat && v.slots[1].chat);
        assert_eq!(v.slots[1].mu_per_call[0].value, "5");
        assert_eq!(v.networks[0].formal, "pow.chain=ergo");
        assert_eq!(v.chat, ChatSupportView::Supported);
        assert_eq!(v.chat_port, Some(8080));
        assert!(!v.truncated);
    }

    #[test]
    fn a_known_interface_without_the_convention_is_unsupported_and_an_unknown_one_is_not() {
        let mut none = info();
        none.api.as_mut().unwrap().slot.remove(1);
        let v = view_of(none);
        assert_eq!(v.chat, ChatSupportView::Unsupported);
        assert_eq!(v.chat_port, None);
        // No interface at all is unsupported too: there is no port to talk to.
        let mut empty = ServiceInfo::default();
        assert_eq!(view_of(empty.clone()).chat, ChatSupportView::Unsupported);
        // A service that was too large to read says nothing about its interface.
        empty.truncated = true;
        let v = view_of(empty);
        assert_eq!(v.chat, ChatSupportView::Unknown);
        assert!(v.truncated);
        // Nor does one whose interface was too large to decode: it is not "unsupported".
        let skipped = ServiceInfo {
            api_skipped: true,
            parts_skipped: 1,
            ..Default::default()
        };
        let v = view_of(skipped);
        assert_eq!(v.chat, ChatSupportView::Unknown);
        assert!(v.api_skipped && !v.truncated);
        assert_eq!(v.parts_skipped, 1);
    }

    #[test]
    fn the_cpu_period_defaults_and_a_zero_period_is_not_a_division_by_zero() {
        let v = resources_view(&Sysresources {
            cpu_quota: Some(50_000),
            cpu_period: Some(0),
            ..Default::default()
        });
        assert_eq!(v.cpu_cores, Some(0.5));
        let v = resources_view(&Sysresources {
            cpu_quota: Some(400_000),
            cpu_period: Some(200_000),
            ..Default::default()
        });
        assert_eq!(v.cpu_cores, Some(2.0));
        assert_eq!(resources_view(&Sysresources::default()).cpu_cores, None);
    }

    #[tokio::test]
    async fn without_a_library_file_or_a_node_there_is_nothing_to_read() {
        let e = celaut_service_info("ab".repeat(32), None)
            .await
            .unwrap_err();
        assert_eq!(e.kind, super::super::celaut::CelautErrorKind::InvalidInput);
        let e = celaut_service_info("xyz".into(), None).await.unwrap_err();
        assert_eq!(e.kind, super::super::celaut::CelautErrorKind::InvalidInput);
    }
}
