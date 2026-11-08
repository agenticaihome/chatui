//! Errors of the crate.

/// The certificate of a node does not prove an identity.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum IdentityError {
    /// The bytes are not an X.509 certificate that this crate can read.
    #[error("the certificate cannot be read: {0}")]
    BadCertificate(&'static str),
    /// No Celaut identity extension (or more than one).
    #[error("the certificate has no Celaut identity extension")]
    NoExtension,
    /// The contents of the extension are not `<public key hex>:<signature hex>`.
    #[error("the identity extension is malformed: {0}")]
    BadExtension(&'static str),
    /// The public key is not 64 lowercase hexadecimal characters.
    #[error("the identity extension holds a public key that is not in canonical form")]
    NonCanonicalKey,
    /// The signature of the extension is wrong for this certificate.
    #[error("the identity key {0} did not sign this certificate")]
    BadSignature(String),
    /// The node is not the node that the caller expected.
    #[error("the node has the identity {actual}, not the expected {expected}")]
    PeerMismatch {
        /// The peer_id that the caller expected.
        expected: String,
        /// The peer_id that the certificate proves.
        actual: String,
    },
}

/// Every error of a call to a node.
#[derive(Debug, thiserror::Error)]
pub enum WireError {
    /// The certificate of the node was refused.
    #[error(transparent)]
    Identity(#[from] IdentityError),
    /// No connection: DNS, TCP, TLS or HTTP/2.
    #[error("cannot connect: {0}")]
    Connect(String),
    /// A time limit passed.
    #[error("the node did not answer in time")]
    Timeout,
    /// The call failed: a gRPC status or a bee-rpc error.
    #[error("the call failed: {0}")]
    Call(String),
    /// The answer has the wrong shape (a missing or undecodable message).
    #[error("unexpected answer: {0}")]
    Protocol(String),
    /// The node does not know `DescendantTunnel` (index 2 of `ServiceTunnel`): a stream
    /// that used it failed before the first byte, in a way that no refusal of a node with
    /// descendants has (`docs/celaut/descendants.md`, section 9).
    #[error("node does not support descendants")]
    NoDescendants,
    /// The input of a relay failed (a file or another call). The node got markers that
    /// make it refuse the request.
    #[error("the service could not be read: {0}")]
    Relay(String),
}
