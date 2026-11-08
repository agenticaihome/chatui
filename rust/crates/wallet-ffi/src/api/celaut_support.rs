//! The support chat with the operator of a node (`docs/celaut/support-chat.md`).
//!
//! A text thread between this app, as a client of the node, and the operator of the
//! node, for a problem. It is the `Chat` and `GetChatThread` RPCs of the Gateway. The node
//! keeps the thread; the app keeps nothing. Only the client id is needed.
//!
//! A node that does not have the RPCs gives `supported: false`: the screen says that the
//! node has no support chat. That is not an error.

use celaut_client::MAX_SUPPORT_MESSAGE_BYTES;

use super::celaut::{error_of, invalid, CelautError};
use super::celaut_service::{forget_if_broken, session, NodeAddress};

/// One message of the thread.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SupportMessageView {
    /// The position in the thread, from 1.
    pub sequence: u64,
    /// The time that the node stored it, in Unix seconds.
    pub ts: i64,
    /// True if the operator wrote it.
    pub from_operator: bool,
    pub body: String,
}

/// The thread of the app with the operator of a node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SupportThreadView {
    /// False if the node has no support chat.
    pub supported: bool,
    /// The messages with a sequence more than the one asked for, in order.
    pub messages: Vec<SupportMessageView>,
    /// The sequence of the last message of the thread. 0 if it is empty.
    pub latest: u64,
}

/// The result of a send.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SupportSendView {
    /// False if the node has no support chat.
    pub supported: bool,
    /// True if the node stored the message.
    pub stored: bool,
    /// Why the node did not store it, in the words of the node. Empty if it did.
    pub reason: String,
}

/// The messages of the thread with a sequence more than `after_sequence` (0 for all).
#[flutter_rust_bridge::frb]
pub async fn celaut_support_thread(
    node: NodeAddress,
    after_sequence: u64,
) -> Result<SupportThreadView, CelautError> {
    let session = session(&node).await?;
    match session.support_thread(after_sequence).await {
        Ok(Some(thread)) => Ok(SupportThreadView {
            supported: true,
            messages: thread
                .entries
                .into_iter()
                .map(|e| SupportMessageView {
                    sequence: e.sequence,
                    ts: e.ts,
                    from_operator: e.from_operator,
                    body: e.body,
                })
                .collect(),
            latest: thread.latest,
        }),
        Ok(None) => Ok(SupportThreadView {
            supported: false,
            messages: Vec::new(),
            latest: 0,
        }),
        Err(e) => {
            forget_if_broken(&node, &e);
            Err(error_of(e))
        }
    }
}

/// Send a message to the operator of the node. The text cannot be empty or only spaces,
/// and cannot be more than 4096 bytes (the limit of nodo).
#[flutter_rust_bridge::frb]
pub async fn celaut_support_send(
    node: NodeAddress,
    body: String,
) -> Result<SupportSendView, CelautError> {
    let body = body.trim().to_string();
    if body.is_empty() {
        return Err(invalid("The message is empty."));
    }
    if body.len() > MAX_SUPPORT_MESSAGE_BYTES {
        return Err(invalid("The message is too long."));
    }
    let session = session(&node).await?;
    match session.support_send(&body).await {
        Ok(Some(ack)) => Ok(SupportSendView {
            supported: true,
            stored: ack.stored,
            reason: ack.reason,
        }),
        Ok(None) => Ok(SupportSendView {
            supported: false,
            stored: false,
            reason: String::new(),
        }),
        Err(e) => {
            forget_if_broken(&node, &e);
            Err(error_of(e))
        }
    }
}
