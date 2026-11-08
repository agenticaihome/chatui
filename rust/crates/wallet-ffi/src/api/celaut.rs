//! Celaut nodes: connect to a node and read its advertisement (milestone M1).
//!
//! One async call. It opens a TLS connection, checks the identity in the certificate
//! of the node, uses the client id of the app on that node (or makes one), asks for the
//! `Peer` and checks its signature (see `celaut-client`). The client id and the
//! advertisement go into the database of the app (`celaut_db`). The answer is plain
//! data for the debug screen.

use celaut_client::{
    connect_and_fetch, ClientError, DepositError, FilePeerStore, NodeInfo, PeerError, Refusal,
};
use celaut_proto::celaut::peer::Uri;
use celaut_proto::celaut::{ArchitectureResources, Contract, ContractRate, Sysresources};
use celaut_wire::{ConnectOptions, Connection, IdentityError, WireError};

/// One key and its value, as text.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KeyValueView {
    pub key: String,
    pub value: String,
}

/// One address of the node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodeUriView {
    pub ip: String,
    pub port: u32,
    /// Unix time in seconds after which the address can become wrong. 0 means no
    /// estimate.
    pub expiry_unix_timestamp: i64,
    /// For example `tcp`.
    pub transport: String,
    /// The first tag of each layer above the transport, bottom to top.
    pub protocols: Vec<String>,
}

/// One payment contract of the node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PaymentContractView {
    /// The tags of the ledger, for example `ergo`.
    pub ledger: String,
    /// The MU for one base unit of the asset, as a decimal integer.
    pub mu_per_unit: String,
    /// The values that are specific to the ledger (for example `script`, `token_id`).
    /// Text when the bytes are printable text, else lowercase hex.
    pub details: Vec<KeyValueView>,
}

/// The most that the node supports for one architecture.
#[derive(Debug, Clone, PartialEq)]
pub struct NodeResourcesView {
    pub architecture: String,
    /// `cpu_quota / cpu_period` (the period is 100000 when absent).
    pub cpu_cores: Option<f64>,
    pub mem_limit_bytes: Option<i64>,
    pub disk_space_bytes: Option<i64>,
    /// The benchmark scores. An entry with no value shows an empty value.
    pub benchmark: Vec<KeyValueView>,
}

/// The advertisement of a node, after the checks of `celaut-client`.
#[derive(Debug, Clone, PartialEq)]
pub struct PeerInfoView {
    /// The identity of the node: 64 lowercase hex characters.
    pub peer_id: String,
    /// The time of the advertisement, in Unix seconds.
    pub ts: i64,
    pub uris: Vec<NodeUriView>,
    /// The rates of the node (`mu_per_call`), in MU, sorted by key.
    pub rates: Vec<KeyValueView>,
    pub payment_contracts: Vec<PaymentContractView>,
    pub resources: Vec<NodeResourcesView>,
    /// How many reputation proofs the advertisement has. M1 does not check them.
    pub reputation_proofs: u32,
}

/// What went wrong. The screen shows its own text for each kind.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CelautErrorKind {
    /// The host or the port is not valid.
    InvalidInput,
    /// No connection (DNS, TCP, TLS or HTTP/2).
    Unreachable,
    /// The node did not answer in time.
    Timeout,
    /// The node is not the expected one, or the advertisement is for another node.
    IdentityMismatch,
    /// The certificate has no valid identity.
    BadCertificate,
    /// The signature of the advertisement is missing or wrong.
    BadSignature,
    /// The advertisement is older than one that was accepted before.
    StaleTimestamp,
    /// The node signs with a scheme that the app does not support.
    UnsupportedScheme,
    /// The node asks for a proof of work that the app refuses or the node rejects.
    ProofOfWork,
    /// The node refused a call or sent an answer that cannot be used.
    Protocol,
    /// The file with the last advertisements failed.
    Storage,
    /// A deposit would pass the limit of the node.
    LimitReached,
    /// The wallet cannot make the transaction, for example with too little ERG.
    Wallet,
    /// The node does not know the client id of the app: it forgot it. The app asks the
    /// user: a new client (the old balance is lost) or a retry later.
    ClientUnknown,
    /// The node is outside the hours that its operator set: it takes no new work now.
    NodeClosed,
    /// The node has not enough free resources for the service now.
    NoRoom,
    /// The node does not have the service.
    ServiceMissing,
    /// The policy of the node does not allow the networks that the service declares.
    PolicyRefused,
    /// The node does not run the architecture of the service.
    UnsupportedArchitecture,
    /// The node limits the calls of this client for a time.
    RateLimited,
    /// The node refused the request because it went round, or too deep.
    RecursionLimit,
    /// The balance of the client on the node is less than the price. The app finds this
    /// before it asks the node to start the service.
    InsufficientCredit,
    /// The node tried to start the service and could not, and says no other reason.
    LaunchFailed,
    /// The transfer of a service stopped: the file could not be read, it is cut, or the
    /// user cancelled it. The node refused the cut service.
    TransferFailed,
    /// The node does not know descendants (`DescendantTunnel` or the `instance_ref` of a
    /// balance statement).
    NoDescendants,
}

/// The error of [`celaut_peer_info`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CelautError {
    pub kind: CelautErrorKind,
    /// The technical reason, in English.
    pub message: String,
}

/// The kind of error for a reason that a node gave (`celaut_client::refusal`).
fn kind_of_refusal(reason: Refusal) -> CelautErrorKind {
    use CelautErrorKind as K;
    match reason {
        Refusal::ClientUnknown => K::ClientUnknown,
        Refusal::RateLimited => K::RateLimited,
        Refusal::NodeClosed => K::NodeClosed,
        Refusal::NoRoom => K::NoRoom,
        Refusal::ServiceMissing => K::ServiceMissing,
        Refusal::PolicyRefused => K::PolicyRefused,
        Refusal::UnsupportedArchitecture => K::UnsupportedArchitecture,
        Refusal::RecursionLimit => K::RecursionLimit,
        Refusal::InsufficientCredit => K::InsufficientCredit,
        Refusal::LaunchFailed => K::LaunchFailed,
    }
}

pub(crate) fn error_of(e: ClientError) -> CelautError {
    use CelautErrorKind as K;
    // A refusal of the node is a text that says why. If the app knows the reason, the
    // error has its own kind, and the message is the text of the node without the
    // wrapper of the transport.
    if let ClientError::Wire(WireError::Call(text)) = &e {
        if let Some(reason) = celaut_client::refusal::classify(text) {
            return CelautError {
                kind: kind_of_refusal(reason),
                message: celaut_client::refusal::message_of(text),
            };
        }
    }
    let kind = match &e {
        e if e.is_unknown_client() => K::ClientUnknown,
        ClientError::Wire(WireError::Identity(IdentityError::PeerMismatch { .. })) => {
            K::IdentityMismatch
        }
        ClientError::Wire(WireError::Identity(_)) => K::BadCertificate,
        ClientError::Wire(WireError::Connect(_)) => K::Unreachable,
        ClientError::Wire(WireError::Timeout) => K::Timeout,
        ClientError::Wire(WireError::NoDescendants) => K::NoDescendants,
        ClientError::Wire(WireError::Call(_) | WireError::Protocol(_)) => K::Protocol,
        ClientError::Wire(WireError::Relay(_)) => K::TransferFailed,
        ClientError::Peer(PeerError::KeyMismatch { .. }) => K::IdentityMismatch,
        ClientError::Peer(PeerError::StaleTs { .. }) => K::StaleTimestamp,
        ClientError::Peer(PeerError::UnsupportedScheme) => K::UnsupportedScheme,
        ClientError::Peer(_) => K::BadSignature,
        ClientError::Store(_) => K::Storage,
        ClientError::PowTooHard(_) | ClientError::PowRejected => K::ProofOfWork,
        ClientError::Protocol(_) | ClientError::Random | ClientError::Amount(_) => K::Protocol,
        ClientError::Deposit(DepositError::BadAmount(_)) => K::InvalidInput,
        ClientError::Deposit(_) => K::Protocol,
        ClientError::Resources(_) => K::InvalidInput,
    };
    CelautError {
        kind,
        message: e.to_string(),
    }
}

pub(crate) fn invalid(message: &str) -> CelautError {
    CelautError {
        kind: CelautErrorKind::InvalidInput,
        message: message.to_string(),
    }
}

/// Text when the bytes are printable UTF-8, else lowercase hex.
fn show_bytes(bytes: &[u8]) -> String {
    match std::str::from_utf8(bytes) {
        Ok(text) if !text.is_empty() && !text.chars().any(char::is_control) => text.to_string(),
        _ => hex_text(bytes),
    }
}

fn hex_text(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn uri_view(uri: &Uri) -> NodeUriView {
    let first_tag = |tags: &[String]| tags.first().cloned().unwrap_or_default();
    NodeUriView {
        ip: uri.ip.clone(),
        port: u32::try_from(uri.port).unwrap_or_default(),
        expiry_unix_timestamp: uri.expiry_unix_timestamp,
        transport: uri
            .transport
            .as_ref()
            .map(|t| first_tag(&t.tags))
            .unwrap_or_default(),
        protocols: uri
            .protocol_stack
            .iter()
            .map(|p| first_tag(&p.tags))
            .collect(),
    }
}

fn contract_view(rate: &ContractRate) -> PaymentContractView {
    let contract: Contract = rate.contract.clone().unwrap_or_default();
    let ledger = contract.ledger.unwrap_or_default();
    let mut details: Vec<KeyValueView> = contract
        .xattrs
        .iter()
        .map(|e| KeyValueView {
            key: e.key.clone(),
            value: show_bytes(e.value.as_deref().unwrap_or_default()),
        })
        .collect();
    details.sort_by(|a, b| a.key.cmp(&b.key));
    PaymentContractView {
        ledger: ledger.tags.join(", "),
        mu_per_unit: rate.mu_per_unit.clone().unwrap_or_default().n,
        details,
    }
}

fn to_i64(value: Option<u64>) -> Option<i64> {
    value.map(|v| i64::try_from(v).unwrap_or(i64::MAX))
}

fn resources_view(entry: &ArchitectureResources) -> NodeResourcesView {
    let architecture = entry.architecture.clone().unwrap_or_default().tags;
    let r: Sysresources = entry.resources.clone().unwrap_or_default();
    let period = r.cpu_period.filter(|p| *p > 0).unwrap_or(100_000);
    NodeResourcesView {
        architecture: architecture.first().cloned().unwrap_or_default(),
        cpu_cores: r.cpu_quota.map(|q| q as f64 / period as f64),
        mem_limit_bytes: to_i64(r.mem_limit),
        disk_space_bytes: to_i64(r.disk_space),
        benchmark: r
            .benchmark
            .iter()
            .map(|e| KeyValueView {
                key: e.key.clone(),
                value: e.value.map(|v| v.to_string()).unwrap_or_default(),
            })
            .collect(),
    }
}

fn view_of(info: &NodeInfo) -> PeerInfoView {
    let peer = &info.peer;
    let mut rates: Vec<KeyValueView> = peer
        .mu_per_call
        .iter()
        .map(|e| KeyValueView {
            key: e.key.clone(),
            value: e.value.clone().unwrap_or_default().n,
        })
        .collect();
    rates.sort_by(|a, b| a.key.cmp(&b.key));
    PeerInfoView {
        peer_id: info.peer_id.clone(),
        ts: peer.ts,
        uris: peer.uri.iter().map(uri_view).collect(),
        rates,
        payment_contracts: peer.payment_contracts.iter().map(contract_view).collect(),
        resources: peer.resources.iter().map(resources_view).collect(),
        reputation_proofs: u32::try_from(peer.reputation_proofs.len()).unwrap_or(u32::MAX),
    }
}

/// Connect to a Celaut node and read its advertisement.
///
/// `host` is a name or an IP address without brackets. `expected_peer_id` is the
/// identity that the node must prove, if the caller knows it. With `store_path` (a test
/// file for the last accepted advertisements), the check uses a new client and nothing
/// goes into the database of the app. With `None`, the node goes into the database.
#[flutter_rust_bridge::frb]
pub async fn celaut_peer_info(
    host: String,
    port: u16,
    expected_peer_id: Option<String>,
    store_path: Option<String>,
) -> Result<PeerInfoView, CelautError> {
    let host = host.trim().to_string();
    if host.is_empty() || host.contains(|c: char| c.is_whitespace() || c == '/') {
        return Err(invalid(
            "The host is empty or has characters that a host cannot have.",
        ));
    }
    if port == 0 {
        return Err(invalid("The port must be from 1 to 65535."));
    }
    let expected = expected_peer_id
        .map(|id| id.trim().to_string())
        .filter(|id| !id.is_empty());
    let options = ConnectOptions {
        expected_peer_id: expected,
        ..Default::default()
    };
    if let Some(path) = store_path {
        return connect_and_fetch(&host, port, options, &FilePeerStore::new(path))
            .await
            .map(|info| view_of(&info))
            .map_err(error_of);
    }
    let connection = Connection::connect(&host, port, options)
        .await
        .map_err(|e| error_of(e.into()))?;
    let session =
        super::celaut_service::open_session(connection, &format!("{host}:{port}")).await?;
    Ok(view_of(session.info()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn call(message: &str) -> ClientError {
        ClientError::Wire(WireError::Call(format!(
            "status: Unknown, message: \"Exception calling application: {message}\", details: [], metadata: MetadataMap {{ headers: {{}} }}"
        )))
    }

    #[test]
    fn a_refusal_of_a_node_has_its_own_kind_and_the_text_without_the_wrapper() {
        let cases = [
            ("This node is not accepting new work.", CelautErrorKind::NodeClosed),
            (
                "This node cannot run the service right now: not enough memory.",
                CelautErrorKind::NoRoom,
            ),
            ("Service ab not on local registry.", CelautErrorKind::ServiceMissing),
            (
                "Network policy: this node refuses to run a service that reaches 'x'.",
                CelautErrorKind::PolicyRefused,
            ),
            ("Unsupported architecture 'riscv64'.", CelautErrorKind::UnsupportedArchitecture),
            ("Client c is calling too fast and is temporarily quarantined.", CelautErrorKind::RateLimited),
            ("Unable to launch service ab: no eligible local executor or peer was available at this time.", CelautErrorKind::LaunchFailed),
            (
                "This RPC requires a client_id minted by GenerateClient first. Wrong or missing client_id: 'x'",
                CelautErrorKind::ClientUnknown,
            ),
        ];
        for (text, kind) in cases {
            let e = error_of(call(text));
            assert_eq!(e.kind, kind, "{text}");
            assert_eq!(e.message, text, "the wrapper is removed");
        }
    }

    #[test]
    fn a_refusal_that_the_app_does_not_know_stays_a_protocol_error_with_the_whole_text() {
        let e = error_of(call("something new that nodo says"));
        assert_eq!(e.kind, CelautErrorKind::Protocol);
        assert!(e.message.contains("something new that nodo says"));
    }

    #[test]
    fn bytes_show_as_text_or_hex() {
        assert_eq!(show_bytes(b"ERG"), "ERG");
        assert_eq!(show_bytes(&[0x00, 0x08, 0xcd]), "0008cd");
        assert_eq!(show_bytes(&[]), "");
        assert_eq!(show_bytes(b"a\nb"), "610a62");
    }

    #[tokio::test]
    async fn bad_input_is_refused_before_any_connection() {
        let err = celaut_peer_info(" ".into(), 80, None, None)
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        let err = celaut_peer_info("a/b".into(), 80, None, None)
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
        let err = celaut_peer_info("localhost".into(), 0, None, None)
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::InvalidInput);
    }

    #[tokio::test]
    async fn a_closed_port_is_unreachable() {
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();
        drop(listener);
        let err = celaut_peer_info("127.0.0.1".into(), port, None, None)
            .await
            .unwrap_err();
        assert_eq!(err.kind, CelautErrorKind::Unreachable);
    }

    #[test]
    fn errors_get_a_kind() {
        let e = error_of(ClientError::Peer(PeerError::StaleTs { ts: 1, last: 2 }));
        assert_eq!(e.kind, CelautErrorKind::StaleTimestamp);
        let e = error_of(ClientError::Wire(WireError::Identity(
            IdentityError::PeerMismatch {
                expected: "a".into(),
                actual: "b".into(),
            },
        )));
        assert_eq!(e.kind, CelautErrorKind::IdentityMismatch);
        let e = error_of(ClientError::Wire(WireError::Identity(
            IdentityError::NoExtension,
        )));
        assert_eq!(e.kind, CelautErrorKind::BadCertificate);
        let e = error_of(ClientError::Peer(PeerError::BadSignature));
        assert_eq!(e.kind, CelautErrorKind::BadSignature);
        let e = error_of(ClientError::Wire(WireError::Timeout));
        assert_eq!(e.kind, CelautErrorKind::Timeout);
        let e = error_of(ClientError::Wire(WireError::Call(
            "This RPC requires a client_id minted by GenerateClient first.".into(),
        )));
        assert_eq!(e.kind, CelautErrorKind::ClientUnknown);
        let e = error_of(ClientError::Wire(WireError::Call("other".into())));
        assert_eq!(e.kind, CelautErrorKind::Protocol);
    }
}
