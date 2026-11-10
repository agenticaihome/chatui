//! The quotes of several nodes for one service, best first (`docs/celaut/balancer.md`).

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use celaut_balancer::{
    cost_mu, next_open, rank_at, schedule_closed, Candidate, Misfit, QuoteCache, QuoteKey,
    Ranked, ServiceAsk, Standing, Weights,
};
use celaut_proto::celaut::Configuration;
use celaut_proto::Message;
use celaut_wire::{Transport, WireError};

use crate::{ClientError, NodeSession};

/// The time limit of one quote, as in nodo.
pub const QUOTE_TIMEOUT: Duration = Duration::from_secs(10);

/// A node that gave no quote.
#[derive(Debug)]
pub struct QuoteFailure {
    /// The identity of the node.
    pub peer_id: String,
    /// Why.
    pub error: ClientError,
}

/// A node that the filter on the advertised resources skipped, with no call to it.
#[derive(Debug, Clone, PartialEq)]
pub struct QuoteSkip {
    /// The identity of the node.
    pub peer_id: String,
    /// Why the service can never run on the node, by its own announcement. Never empty.
    pub misfits: Vec<Misfit>,
}

/// A node that was not asked, because the activity window that it announced
/// (`Peer.activity_window`, nodo#344) says that it is closed now, as nodo's balancer skips
/// a closed peer. The schedule is a hint: a node that gives none, or one that cannot be
/// read, is asked.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuoteClosed {
    /// The identity of the node.
    pub peer_id: String,
    /// The unix time, in seconds, at which its schedule opens next.
    pub opens_at: Option<i64>,
}

/// The answer of [`quotes`].
#[derive(Debug, Default)]
pub struct Quotes {
    /// The quotes, best first.
    pub ranked: Vec<Ranked>,
    /// The nodes that refused, failed or did not answer in time. They are not
    /// candidates.
    pub failures: Vec<QuoteFailure>,
    /// The nodes that were not asked, because their announced resources are below what
    /// the service asks. Always empty without a [`ServiceAsk`] ([`quotes_for`]).
    pub skipped: Vec<QuoteSkip>,
    /// The nodes that were not asked, because their schedule says that they are closed.
    pub closed: Vec<QuoteClosed>,
}

/// The unix time now, in seconds.
fn unix_now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| i64::try_from(d.as_secs()).unwrap_or(i64::MAX))
}

/// Ask each node for the price of the service, all at the same time, and rank the
/// answers. A quote of the last 10 seconds comes from `cache`, so that a repeated
/// question makes no call (the node limits the calls of a client).
///
/// No node is skipped: the client has the hash of the service, not its resources. Use
/// [`quotes_for`] with the resources of the service to skip the nodes that can never
/// run it.
pub async fn quotes<T: Transport>(
    sessions: &[&NodeSession<T>],
    service_id: [u8; 32],
    configuration: &Configuration,
    cache: &Mutex<QuoteCache>,
) -> Quotes {
    quotes_for(sessions, service_id, configuration, cache, None).await
}

/// [`quotes`], with the filter on the advertised resources (`docs/celaut/balancer.md`,
/// Filter). With an `ask`, a node whose last announcement says that it can never run the
/// service gets no call, and goes to [`Quotes::skipped`]. A node that announced nothing
/// is asked, and so is any node when the ask has no known architecture.
pub async fn quotes_for<T: Transport>(
    sessions: &[&NodeSession<T>],
    service_id: [u8; 32],
    configuration: &Configuration,
    cache: &Mutex<QuoteCache>,
    ask: Option<&ServiceAsk>,
) -> Quotes {
    quotes_with(
        sessions,
        service_id,
        configuration,
        cache,
        ask,
        &HashMap::new(),
    )
    .await
}

/// [`quotes_for`], with what the client knows about each node, by peer_id: the priority
/// (reputation) that the user gave it weighs in the score, so a node of higher priority
/// can win over a somewhat cheaper one. A node that is not in `standings` is neutral.
pub async fn quotes_with<T: Transport>(
    sessions: &[&NodeSession<T>],
    service_id: [u8; 32],
    configuration: &Configuration,
    cache: &Mutex<QuoteCache>,
    ask: Option<&ServiceAsk>,
    standings: &HashMap<String, Standing>,
) -> Quotes {
    quotes_weighted(
        sessions,
        service_id,
        configuration,
        cache,
        ask,
        standings,
        &Weights::default(),
    )
    .await
}

/// [`quotes_with`], with the weights of the score that the user set (`docs/celaut/
/// balancer.md`, "Weights of the score").
pub async fn quotes_weighted<T: Transport>(
    sessions: &[&NodeSession<T>],
    service_id: [u8; 32],
    configuration: &Configuration,
    cache: &Mutex<QuoteCache>,
    ask: Option<&ServiceAsk>,
    standings: &HashMap<String, Standing>,
    weights: &Weights,
) -> Quotes {
    let mut skipped = Vec::new();
    let mut closed = Vec::new();
    let mut to_ask = Vec::new();
    let now = unix_now();
    for session in sessions {
        let cached = session.info().peer.activity_window.as_ref();
        if schedule_closed(cached, now) {
            // The Peer of the connection can be older than a change of the schedule: read
            // the current one before the skip, and skip only if it says closed too. If it
            // cannot be read, the one of the connection decides.
            let fresh = tokio::time::timeout(QUOTE_TIMEOUT, session.fresh_activity_window()).await;
            let current = match fresh {
                Ok(Ok(window)) => window,
                _ => cached.cloned(),
            };
            if schedule_closed(current.as_ref(), now) {
                closed.push(QuoteClosed {
                    peer_id: session.peer_id().to_string(),
                    opens_at: next_open(current.as_ref(), now),
                });
                continue;
            }
        }
        let misfits = ask
            .map(|a| a.misfits(&session.info().peer.resources))
            .unwrap_or_default();
        if misfits.is_empty() {
            to_ask.push(*session);
        } else {
            skipped.push(QuoteSkip {
                peer_id: session.peer_id().to_string(),
                misfits,
            });
        }
    }
    let encoded = configuration.encode_to_vec();
    let asks = to_ask.iter().map(|session| {
        let key = QuoteKey {
            peer_id: session.peer_id().to_string(),
            service_id,
            configuration: encoded.clone(),
        };
        async move {
            let cached = cache.lock().ok().and_then(|c| c.get(&key, Instant::now()));
            let quote = match cached {
                Some(quote) => Ok(quote),
                None => {
                    let ask = session.quote(service_id, configuration.clone());
                    match tokio::time::timeout(QUOTE_TIMEOUT, ask).await {
                        Err(_) => Err(ClientError::Wire(WireError::Timeout)),
                        Ok(Err(e)) => Err(e),
                        Ok(Ok(quote)) => {
                            if let Ok(mut c) = cache.lock() {
                                c.put(key, quote.clone(), Instant::now());
                            }
                            Ok(quote)
                        }
                    }
                }
            };
            (session, quote)
        }
    });
    let answers = futures::future::join_all(asks).await;

    let mut candidates = Vec::new();
    let mut failures = Vec::new();
    for (session, answer) in answers {
        match answer {
            Ok(quote) => match cost_mu(&quote) {
                Err(e) => failures.push(QuoteFailure {
                    peer_id: session.peer_id().to_string(),
                    error: ClientError::Amount(e),
                }),
                Ok(_) => candidates.push(Candidate {
                    peer_id: session.peer_id().to_string(),
                    quote,
                    mu_per_nano_erg: session.mu_per_nano_erg(),
                    standing: standings
                        .get(session.peer_id())
                        .copied()
                        .unwrap_or_default(),
                }),
            },
            Err(error) => failures.push(QuoteFailure {
                peer_id: session.peer_id().to_string(),
                error,
            }),
        }
    }
    // The balance of the start, if the quote carries one: with it the order knows the
    // funded life of each quote (nodo#344). None: each node funds its default periods.
    let initial_mu = configuration
        .initial_mu
        .as_ref()
        .and_then(|a| a.n.parse::<u128>().ok())
        .filter(|m| *m > 0);
    Quotes {
        ranked: rank_at(candidates, weights, initial_mu, now),
        failures,
        skipped,
        closed,
    }
}
