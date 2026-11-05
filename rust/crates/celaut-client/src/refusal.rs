//! Why a node refuses a request (milestone M4, the feedback of a rejected launch).
//!
//! A node (nodo) refuses a quote or a start with a gRPC error whose message is free text:
//! a Python exception. There is no error code. This module reads the texts that nodo
//! writes and says what they mean, so that the app can tell the user the reason and what
//! to do. The texts are from nodo `src/gateway` (`estimated_cost_iterable.py`,
//! `launch_service.py`, `client_gate.py`, `abstract_input_service_iterable.py`),
//! `src/utils/activity_window.py`, `src/utils/network_policy.py` and
//! `src/virtualizers/architecture.py`. A text that this module does not know gives `None`:
//! the caller then shows the text as it is.
//!
//! The match is on lowercase fragments of the text. If nodo changes a text, the reason is
//! not found and the app shows the original text, so a change in nodo cannot give a wrong
//! reason, only a less precise one.

/// The reason that a node does not run a service.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Refusal {
    /// The node does not know the client id of the app (it forgot it, or never made it).
    ClientUnknown,
    /// The node limits the calls of this client for a time.
    RateLimited,
    /// The node is outside the hours that its operator set (`activity_window`).
    NodeClosed,
    /// The node has not enough free resources for the service now.
    NoRoom,
    /// The node does not have the service and the request does not carry it.
    ServiceMissing,
    /// The policy of the node (a list of domains that the operator allows or refuses)
    /// does not allow the networks that the service declares.
    PolicyRefused,
    /// The service is for an architecture that the node does not run.
    UnsupportedArchitecture,
    /// The request came back to a node that already has it, or it passed the depth limit.
    RecursionLimit,
    /// The client has not enough balance on the node for the start. The app finds this
    /// itself, before it asks the node to start.
    InsufficientCredit,
    /// The node tried to start the service and could not, for a reason that it does not
    /// say as one of the above.
    LaunchFailed,
}

/// The phrases of each reason, in lowercase. The order of the list matters: a launch that
/// fails after other attempts carries the reason of each attempt in one text, so the
/// specific reasons come before `LaunchFailed`.
const PHRASES: [(Refusal, &[&str]); 9] = [
    (
        Refusal::ClientUnknown,
        &["requires a client_id minted by generateclient"],
    ),
    (Refusal::RateLimited, &["temporarily quarantined"]),
    (
        Refusal::NodeClosed,
        &["outside its activity window", "is not accepting new work"],
    ),
    (
        Refusal::NoRoom,
        &[
            "cannot run the service right now",
            "rejected due to insufficient resources",
        ],
    ),
    (
        Refusal::ServiceMissing,
        &[
            "not on local registry",
            "does not have the service",
            "on registry",
        ],
    ),
    (
        Refusal::PolicyRefused,
        &["network policy:", "refuses to run a service"],
    ),
    (
        Refusal::UnsupportedArchitecture,
        &["unsupported architecture"],
    ),
    (
        Refusal::RecursionLimit,
        &["recursion loop", "recursion depth", "recursion token"],
    ),
    (
        Refusal::LaunchFailed,
        &[
            "unable to launch service",
            "error charging",
            "failed to set initial_mu",
        ],
    ),
];

/// The reason in the text of a refusal, or `None` if the text says none that this module
/// knows.
pub fn classify(text: &str) -> Option<Refusal> {
    let lower = text.to_ascii_lowercase();
    PHRASES
        .iter()
        .find(|(_, phrases)| phrases.iter().any(|p| lower.contains(p)))
        .map(|(reason, _)| *reason)
}

/// The reason that a node refuses to hibernate or wake an instance
/// (`ModifyServiceSystemResources`). It is apart from [`Refusal`]: a start and a change
/// of resources have different reasons. The texts are from nodo `src/gateway/gateway.py`
/// and `src/manager/hibernation.py`. A refused call is refunded, except where the text
/// says that the charge failed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ResourceRefusal {
    /// The instance exports or mounts a shared filesystem. The node does not hibernate it.
    SharedFilesystem,
    /// The instance cannot be started again from its own disk. The node does not
    /// hibernate it.
    NotRevivable,
    /// The instance has not enough balance to pay the fee of the call. A top-up of the
    /// instance is the way to continue.
    InstanceBalance,
    /// The node has no room for the resources of the wake. The instance stays hibernated.
    DoesNotFit,
    /// The node has no local instance with that token. The instance runs on a peer of
    /// the node, or it does not exist any more. This call costs nothing.
    NoLocalInstance,
    /// The call did not come from the father of the instance.
    NotTheFather,
    /// The node does not support hibernation: it is older than the `service_token` field
    /// of `ModifyServiceSystemResources`. It has no such RPC, or it ignores the token and
    /// looks for a local instance at the address of the caller. This call costs nothing.
    Unsupported,
}

/// The phrases of each reason, in lowercase.
const RESOURCE_PHRASES: [(ResourceRefusal, &[&str]); 7] = [
    (ResourceRefusal::SharedFilesystem, &["shared filesystem"]),
    (
        ResourceRefusal::NotRevivable,
        &["cannot be started again from its own disk"],
    ),
    (
        ResourceRefusal::InstanceBalance,
        &["error charging for the resource change"],
    ),
    (ResourceRefusal::DoesNotFit, &["could not be woken"]),
    (
        ResourceRefusal::NoLocalInstance,
        &["no local instance with that token"],
    ),
    (
        ResourceRefusal::NotTheFather,
        &["the father of this instance is a client"],
    ),
    // An older node does not read `service_token`. It looks for an instance at the
    // address of the caller (nodo `src/gateway/gateway.py`), or it has no such RPC (a
    // gRPC `Unimplemented` status). The first phrase is the text of nodo. The two other
    // phrases are standard gRPC transport texts: they are not verified against a real
    // old node. This list is only used for the answer to `ModifyServiceSystemResources`.
    (
        ResourceRefusal::Unsupported,
        &[
            "no local instance is registered at",
            "status: unimplemented",
            "method not found",
        ],
    ),
];

/// The reason in the text of a refusal of `ModifyServiceSystemResources`, or `None` if
/// the text says none that this module knows.
pub fn classify_resources(text: &str) -> Option<ResourceRefusal> {
    let lower = text.to_ascii_lowercase();
    RESOURCE_PHRASES
        .iter()
        .find(|(_, phrases)| phrases.iter().any(|p| lower.contains(p)))
        .map(|(reason, _)| *reason)
}

/// True if the text of a refusal says that the node has no instance with the token that
/// the call asked about (`GetMetrics`, nodo `src/manager/metrics.py`): the instance is gone.
/// For an instance that the app hibernated, this means that the node stopped it after the
/// grace for lack of balance.
pub fn is_unknown_token(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    // The only text that nodo raises for a token that is not an instance token
    // (`src/manager/metrics.py`, `get_metrics`). A looser phrase could mark a record as
    // stopped because of an unrelated error.
    lower.contains("invalid token, it should be an instance token")
}

/// The message of a gRPC error as nodo wrote it, with the wrapper of the transport
/// removed. tonic shows an error as
/// `status: Unknown, message: "Exception calling application: <text>", details: [], ...`.
pub fn message_of(text: &str) -> String {
    let mut body = text;
    if let Some(start) = text.find("message: \"") {
        let rest = &text[start + "message: \"".len()..];
        body = match rest.find("\", details:") {
            Some(end) => &rest[..end],
            None => rest.trim_end_matches('"'),
        };
    }
    let body = body
        .replace("\\n", "\n")
        .replace("\\\"", "\"")
        .replace("\\\\", "\\");
    body.strip_prefix("Exception calling application: ")
        .unwrap_or(&body)
        .trim()
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The error that tonic shows for an exception of nodo.
    fn grpc(message: &str) -> String {
        format!(
            "status: Unknown, message: \"Exception calling application: {message}\", details: [], metadata: MetadataMap {{ headers: {{}} }}"
        )
    }

    #[test]
    fn each_text_of_nodo_gives_its_reason() {
        let cases = [
            (
                "This RPC requires a client_id minted by GenerateClient first. Wrong or missing client_id: 'x'",
                Refusal::ClientUnknown,
            ),
            (
                "Client abc is calling too fast and is temporarily quarantined.",
                Refusal::RateLimited,
            ),
            ("This node is not accepting new work.", Refusal::NodeClosed),
            (
                "This node is outside its activity window: it accepts new work between 09:00 and 18:00 local time (SCHEDULE in config.yaml).",
                Refusal::NodeClosed,
            ),
            (
                "Unable to launch service ab12: This node is outside its activity window: it accepts new work between 09:00 and 18:00 local time (SCHEDULE in config.yaml).",
                Refusal::NodeClosed,
            ),
            (
                "This node cannot run the service right now: not enough memory.",
                Refusal::NoRoom,
            ),
            (
                "Service ab12 not on local registry.",
                Refusal::ServiceMissing,
            ),
            (
                "This node does not have the service ab12, and the request does not contain it.",
                Refusal::ServiceMissing,
            ),
            (
                "No service ab12 on registry",
                Refusal::ServiceMissing,
            ),
            (
                "Network policy: this node refuses to run a service for service ab12 that reaches 'example.org'.\n  declared networks:\n    #1: example.org",
                Refusal::PolicyRefused,
            ),
            (
                "Unsupported architecture 'riscv64'.\nSupported architectures: ['linux/amd64', 'linux/arm64'].",
                Refusal::UnsupportedArchitecture,
            ),
            (
                "Block recursion loop, recursion token: t",
                Refusal::RecursionLimit,
            ),
            (
                "Unable to launch service ab12. Attempt details: local preflight: x | peer p: Exception: y",
                Refusal::LaunchFailed,
            ),
            (
                "Unable to launch service ab12: no eligible local executor or peer was available at this time.",
                Refusal::LaunchFailed,
            ),
            ("Launch service error charging abc", Refusal::LaunchFailed),
        ];
        for (text, expected) in cases {
            assert_eq!(classify(text), Some(expected), "{text}");
            assert_eq!(classify(&grpc(text)), Some(expected), "wrapped: {text}");
        }
    }

    #[test]
    fn each_text_of_a_resource_change_gives_its_reason() {
        let cases = [
            (
                "This instance exports or mounts a shared filesystem, and hibernating it would take that share away from the guests that use it.",
                ResourceRefusal::SharedFilesystem,
            ),
            (
                "This instance cannot be started again from its own disk, so it cannot be hibernated.",
                ResourceRefusal::NotRevivable,
            ),
            (
                "Error charging for the resource change of abc",
                ResourceRefusal::InstanceBalance,
            ),
            (
                "The instance could not be woken: it stays hibernated.",
                ResourceRefusal::DoesNotFit,
            ),
            (
                "This node has no local instance with that token.",
                ResourceRefusal::NoLocalInstance,
            ),
            (
                "The father of this instance is a client, and this call must come from it.",
                ResourceRefusal::NotTheFather,
            ),
            (
                "No local instance is registered at 10.0.0.2: only a local instance can call this.",
                ResourceRefusal::Unsupported,
            ),
            (
                "status: Unimplemented, message: \"Method not found!\"",
                ResourceRefusal::Unsupported,
            ),
        ];
        for (text, expected) in cases {
            assert_eq!(classify_resources(text), Some(expected), "{text}");
            assert_eq!(
                classify_resources(&grpc(text)),
                Some(expected),
                "wrapped: {text}"
            );
        }
        assert_eq!(classify_resources("something broke"), None);
    }

    #[test]
    fn the_text_of_an_unknown_token_is_found() {
        assert!(is_unknown_token(&grpc(
            "Invalid token, it should be an instance token.  token: abc"
        )));
        assert!(!is_unknown_token("Internal service abc"));
        assert!(!is_unknown_token(
            "This node has no local instance with that token."
        ));
        assert!(!is_unknown_token(
            "status: Unavailable, message: \"connection reset\""
        ));
    }

    #[test]
    fn a_launch_that_failed_for_a_known_reason_gives_that_reason() {
        let text = "Unable to launch service ab12. Attempt details: local preflight: This node cannot run the service right now: not enough memory.";
        assert_eq!(classify(text), Some(Refusal::NoRoom));
    }

    #[test]
    fn a_text_that_nodo_did_not_write_before_gives_no_reason() {
        for text in [
            "",
            "something broke",
            "status: Unavailable, message: \"connection reset\"",
        ] {
            assert_eq!(classify(text), None, "{text}");
        }
    }

    #[test]
    fn the_case_of_the_text_does_not_matter() {
        assert_eq!(
            classify("THIS NODE IS NOT ACCEPTING NEW WORK."),
            Some(Refusal::NodeClosed)
        );
    }

    #[test]
    fn the_wrapper_of_the_transport_is_removed() {
        assert_eq!(
            message_of(&grpc("This node is not accepting new work.")),
            "This node is not accepting new work."
        );
        // Line breaks and quotes that the debug format escaped come back.
        assert_eq!(
            message_of(&grpc("Network policy: it refuses '\\\"x\\\"'.\\n  rule: r")),
            "Network policy: it refuses '\"x\"'.\n  rule: r"
        );
        // A text with no wrapper stays as it is.
        assert_eq!(message_of("plain text"), "plain text");
        assert_eq!(message_of("Exception calling application: plain"), "plain");
        assert_eq!(message_of(""), "");
    }
}
