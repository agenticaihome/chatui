//! The execution balancer of a light client (`docs/celaut/balancer.md`): it puts the
//! quotes of several nodes in one unit, scores them as nodo does, and sorts them, best
//! first.
//!
//! - [`erg_rate`] and [`to_nano_erg`]: MU conversion. MU is local to each node; the
//!   `mu_per_unit` of its ERG payment contract says how many of its MU one nanoERG is
//!   worth. The client compares quotes in nanoERG (a client rate of 1 MU per nanoERG,
//!   the default of nodo), rounded up.
//! - [`cost_mu`] and [`score`]: the port of `nodo:src/balancers/estimated_cost_sorter`
//!   and `nodo:src/balancers/scoring.py`.
//! - [`rank`]: the order: the quotes that promise a price bound first (nodo#636), then
//!   the score. A stable sort, so equal scores keep the order of the input.
//! - [`QuoteCache`]: the cache of `nodo:src/utils/tools/query_cache.py` (10 s, 4096
//!   entries).
//!
//! - [`filter`]: the filter on the advertised resources (`nodo:src/utils/cost_functions/
//!   architecture_resources.py`). It skips a node that can never run the service. It
//!   needs the resources of the service ([`ServiceAsk`]), which the client does not
//!   have from a hash alone.
//!
//! - [`Weights`]: how much each term of the score weighs. The user can change them.
//!
//! - [`Standing::priority`]: the reputation that the user gives to a node, a whole number
//!   from [`PRIORITY_MIN`] to [`PRIORITY_MAX`]. [`PRIORITY_NEUTRAL`] adds nothing; the
//!   maximum is "full trust" and adds the most. It weighs in [`score`] with
//!   [`PRIORITY_WEIGHT`], in addition to the price and the other terms.
//!
//! Not in this crate yet: the event log of local reputation. Until then that term is 0.
//!
//! Input from a peer must never make this crate panic.
#![forbid(unsafe_code)]
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

pub mod filter;

pub use filter::{arch_from_tags, ask_of, request_misfit, Misfit, ServiceAsk};

use std::collections::{HashMap, VecDeque};
use std::time::{Duration, Instant};

use celaut_proto::celaut::{Amount, EstimatedCost, Peer};

/// `balancers.COST_AVERAGE_VARIATION` of nodo (default 1).
pub const COST_AVERAGE_VARIATION: f64 = 1.0;
/// `SOCIALIZATION_FACTOR`: the weight of the local reputation.
pub const REPUTATION_WEIGHT: f64 = 2.0;
/// The half credit of the local reputation.
pub const REPUTATION_HALF_CREDIT: f64 = 50.0;
/// The weight of the on-chain reputation.
pub const ONCHAIN_WEIGHT: f64 = 0.3;
/// The weight of the donations.
pub const DONATION_WEIGHT: f64 = 0.3;

/// The least priority (reputation) that the user can give to a node.
pub const PRIORITY_MIN: u8 = 0;
/// The most priority that the user can give to a node. A node of full trust has it.
pub const PRIORITY_MAX: u8 = 100;
/// The priority of a node that the user did not rate: it adds nothing to the score.
pub const PRIORITY_NEUTRAL: u8 = 50;
/// The weight of the priority of the user. At the maximum it is worth a price `e^2` times
/// (about 7.4) lower than that of a node of neutral priority.
pub const PRIORITY_WEIGHT: f64 = 2.0;

/// The weight of the price term, `-ln(cost)`. 1 is nodo's value.
pub const PRICE_WEIGHT: f64 = 1.0;
/// The most that the user can give to one weight.
pub const WEIGHT_MAX: f64 = 10.0;

const HOUR_SECONDS: f64 = 3600.0;

/// An error of the balancer.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum BalancerError {
    /// An amount is not a decimal integer that is 0 or more.
    #[error("the amount {0:?} is not a decimal integer that is 0 or more")]
    BadAmount(String),
    /// An amount is too large for this client.
    #[error("the amount is too large")]
    TooLarge,
    /// The node has no ERG payment contract with a rate, so its MU cannot be compared.
    #[error("the node gives no rate for ERG")]
    NoErgRate,
}

/// The value of an `Amount`. An absent amount is 0.
pub fn amount(value: Option<&Amount>) -> Result<u128, BalancerError> {
    let Some(value) = value else { return Ok(0) };
    let text = value.n.trim();
    if text.is_empty() || !text.bytes().all(|b| b.is_ascii_digit()) {
        return Err(BalancerError::BadAmount(value.n.clone()));
    }
    text.parse::<u128>().map_err(|_| BalancerError::TooLarge)
}

/// The MU per nanoERG of the node: the `mu_per_unit` of its first payment contract on
/// the ledger `ergo` with the asset `ERG`.
pub fn erg_rate(peer: &Peer) -> Result<u128, BalancerError> {
    for rate in &peer.payment_contracts {
        let Some(contract) = &rate.contract else {
            continue;
        };
        let on_ergo = contract
            .ledger
            .as_ref()
            .and_then(|l| l.tags.first())
            .is_some_and(|t| t == "ergo");
        let erg = contract
            .xattrs
            .iter()
            .any(|e| e.key == "token_id" && e.value.as_deref() == Some(b"ERG".as_slice()));
        if on_ergo && erg {
            let mu = amount(rate.mu_per_unit.as_ref())?;
            if mu > 0 {
                return Ok(mu);
            }
        }
    }
    Err(BalancerError::NoErgRate)
}

/// `mu` of a node with `mu_per_nano_erg` as nanoERG, rounded up (an amount that the
/// client owes). The rate must not be 0.
pub fn to_nano_erg(mu: u128, mu_per_nano_erg: u128) -> u128 {
    if mu_per_nano_erg == 0 {
        return mu;
    }
    mu.div_ceil(mu_per_nano_erg)
}

/// nanoERG as MU of a node, rounded down (an amount that the client gives).
pub fn to_node_mu(nano_erg: u128, mu_per_nano_erg: u128) -> Result<u128, BalancerError> {
    nano_erg
        .checked_mul(mu_per_nano_erg)
        .ok_or(BalancerError::TooLarge)
}

/// `trunc(cost * (1 + volatility * k))`, as `volatility_cost_normalization` of nodo.
fn vcnorm(cost: u128, volatility: f64) -> f64 {
    (cost as f64 * (1.0 + volatility * COST_AVERAGE_VARIATION)).trunc()
}

/// The volatility of a quote, read strictly as nodo's `price_bound.strict` (nodo#636): the
/// `price_volatility` of a bounded quote, and 0 for one that is not bounded or that is not
/// a finite number of at least 0.
pub fn volatility(quote: &EstimatedCost) -> f64 {
    let v = f64::from(quote.price_volatility);
    if quote.price_bounded && v.is_finite() && v > 0.0 {
        v
    } else {
        0.0
    }
}

/// The cost of a quote for the comparison, in the unit of its amounts:
/// `trunc(vcnorm(cost) + mean(per_hour(init), per_hour(max)))`, where
/// `per_hour(a) = trunc(vcnorm(a) * 3600 / maintenance_seconds_loop)`, or 0 when the loop
/// is 0 or less. As in nodo, the arithmetic is in floating point.
pub fn cost_mu(quote: &EstimatedCost) -> Result<f64, BalancerError> {
    let volatility = volatility(quote);
    let per_hour = |a: Option<&Amount>| -> Result<f64, BalancerError> {
        let seconds = quote.maintenance_seconds_loop;
        if seconds <= 0 {
            return Ok(0.0);
        }
        Ok((vcnorm(amount(a)?, volatility) * HOUR_SECONDS / f64::from(seconds)).trunc())
    };
    let init = per_hour(quote.init_maintenance_cost.as_ref())?;
    let max = per_hour(quote.max_maintenance_cost.as_ref())?;
    Ok((vcnorm(amount(quote.cost.as_ref())?, volatility) + (init + max) / 2.0).trunc())
}

/// `x / (|x| + half)`.
pub fn reputation_factor(reputation: f64, half_credit: f64) -> f64 {
    let half = if half_credit == 0.0 {
        REPUTATION_HALF_CREDIT
    } else {
        half_credit.abs()
    };
    reputation / (reputation.abs() + half)
}

/// The priority term: from -1 at [`PRIORITY_MIN`] to 0 at [`PRIORITY_NEUTRAL`] and 1 at
/// [`PRIORITY_MAX`]. A value above the maximum counts as the maximum.
pub fn priority_factor(priority: u8) -> f64 {
    let p = f64::from(priority.min(PRIORITY_MAX));
    let half = f64::from(PRIORITY_MAX - PRIORITY_NEUTRAL);
    (p - f64::from(PRIORITY_NEUTRAL)) / half
}

/// What the client knows about a node besides its price. All neutral by default.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Standing {
    /// Local reputation, from the events of this client.
    pub reputation: f64,
    /// On-chain reputation, already in (-1, 1).
    pub onchain: f64,
    /// Donation bonus, already in [0, 1).
    pub donation: f64,
    /// The reputation that the user gave to the node, from [`PRIORITY_MIN`] to
    /// [`PRIORITY_MAX`]. [`PRIORITY_MAX`] is full trust.
    pub priority: u8,
}

impl Default for Standing {
    fn default() -> Self {
        Standing {
            reputation: 0.0,
            onchain: 0.0,
            donation: 0.0,
            priority: PRIORITY_NEUTRAL,
        }
    }
}

/// How much each term of the [`score`] weighs. The user can change them (`docs/celaut/
/// balancer.md`, "Weights of the score"): a higher weight makes that term count more
/// against the others. A weight of 0 switches the term off. [`Weights::default`] is the
/// parametrization of nodo plus the priority of the user.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Weights {
    /// Of `-ln(cost)`: how much the price counts. Default [`PRICE_WEIGHT`].
    pub price: f64,
    /// Of the local reputation. Default [`REPUTATION_WEIGHT`].
    pub reputation: f64,
    /// Of the on-chain reputation. Default [`ONCHAIN_WEIGHT`].
    pub onchain: f64,
    /// Of the donations. Default [`DONATION_WEIGHT`].
    pub donation: f64,
    /// Of the priority that the user gave to the node. Default [`PRIORITY_WEIGHT`].
    pub priority: f64,
}

impl Default for Weights {
    fn default() -> Self {
        Weights {
            price: PRICE_WEIGHT,
            reputation: REPUTATION_WEIGHT,
            onchain: ONCHAIN_WEIGHT,
            donation: DONATION_WEIGHT,
            priority: PRIORITY_WEIGHT,
        }
    }
}

impl Weights {
    /// The same weights with each one made finite and put between 0 and [`WEIGHT_MAX`]
    /// (NaN becomes 0), so a bad value cannot make the order meaningless.
    pub fn sanitized(self) -> Self {
        let fix = |w: f64| {
            if w.is_nan() {
                0.0
            } else {
                w.clamp(0.0, WEIGHT_MAX)
            }
        };
        Weights {
            price: fix(self.price),
            reputation: fix(self.reputation),
            onchain: fix(self.onchain),
            donation: fix(self.donation),
            priority: fix(self.priority),
        }
    }

    /// The weights as whole thousandths, in the order price, reputation, on-chain,
    /// donation, priority (for storage; a weight is rounded to 0.001).
    pub fn to_milli(self) -> [u32; 5] {
        let w = self.sanitized();
        [w.price, w.reputation, w.onchain, w.donation, w.priority]
            .map(|x| (x * 1000.0).round() as u32)
    }

    /// The inverse of [`Weights::to_milli`].
    pub fn from_milli(m: [u32; 5]) -> Self {
        let f = |x: u32| f64::from(x) / 1000.0;
        Weights {
            price: f(m[0]),
            reputation: f(m[1]),
            onchain: f(m[2]),
            donation: f(m[3]),
            priority: f(m[4]),
        }
        .sanitized()
    }
}

/// `-W_c * ln(cost) + W_r * f(r, H_r) + W_o * o + W_d * d + W_p * p` with the default
/// [`Weights`].
pub fn score(cost: f64, standing: Standing) -> f64 {
    score_with(cost, standing, &Weights::default())
}

/// [`score`] with the weights of the user. `p` is the [`priority_factor`] of the node. A
/// cost of 0 or less is `+inf` (a free offer is the best one). Higher is better.
pub fn score_with(cost: f64, standing: Standing, weights: &Weights) -> f64 {
    if cost <= 0.0 {
        return f64::INFINITY;
    }
    let w = weights.sanitized();
    -w.price * cost.ln()
        + w.reputation * reputation_factor(standing.reputation, REPUTATION_HALF_CREDIT)
        + w.onchain * standing.onchain
        + w.donation * standing.donation
        + w.priority * priority_factor(standing.priority)
}

/// One quote of one node.
#[derive(Debug, Clone, PartialEq)]
pub struct Candidate {
    /// The identity of the node.
    pub peer_id: String,
    /// The answer of `GetServiceEstimatedCost`, in the MU of the node.
    pub quote: EstimatedCost,
    /// The MU per nanoERG of the node. `None` if the node gives no ERG rate.
    pub mu_per_nano_erg: Option<u128>,
    /// What the client knows about the node.
    pub standing: Standing,
}

/// A candidate after the score.
#[derive(Debug, Clone, PartialEq)]
pub struct Ranked {
    /// The candidate.
    pub candidate: Candidate,
    /// The cost for the comparison ([`cost_mu`]) in nanoERG. `None` when the node has no
    /// ERG rate: then its price cannot be compared with the others.
    pub cost_nano_erg: Option<f64>,
    /// The score. `None` with `cost_nano_erg`.
    pub score: Option<f64>,
}

/// Score the candidates and sort them, best first. A quote whose amounts cannot be
/// read is dropped. Candidates with no ERG rate come after all the others, in their
/// input order: the client can still use them (M2 runs on free credit), but it cannot
/// compare their price.
pub fn rank(candidates: Vec<Candidate>) -> Vec<Ranked> {
    rank_with(candidates, &Weights::default())
}

/// [`rank`] with the weights of the user.
pub fn rank_with(candidates: Vec<Candidate>, weights: &Weights) -> Vec<Ranked> {
    let mut priced = Vec::new();
    let mut unpriced = Vec::new();
    for candidate in candidates {
        let Ok(cost) = cost_mu(&candidate.quote) else {
            continue;
        };
        match candidate.mu_per_nano_erg.filter(|r| *r > 0) {
            Some(rate) => {
                let cost = (cost / rate as f64).ceil();
                let score = score_with(cost, candidate.standing, weights);
                priced.push(Ranked {
                    candidate,
                    cost_nano_erg: Some(cost),
                    score: Some(score),
                });
            }
            None => unpriced.push(Ranked {
                candidate,
                cost_nano_erg: None,
                score: None,
            }),
        }
    }
    // The quotes that promise a price bound go first, as in nodo (#636, G); inside each
    // group, the order of the score. Stable: equal scores keep the input order. NaN
    // cannot come from the arithmetic above, but it would sort last.
    priced.sort_by(|a, b| {
        let bounded = b.candidate.quote.price_bounded.cmp(&a.candidate.quote.price_bounded);
        let (a, b) = (a.score.unwrap_or(f64::NAN), b.score.unwrap_or(f64::NAN));
        bounded.then_with(|| {
            b.partial_cmp(&a)
                .unwrap_or_else(|| a.is_nan().cmp(&b.is_nan()))
        })
    });
    // The same for the quotes that cannot be compared: bounded first, in the input order.
    unpriced.sort_by(|a, b| b.candidate.quote.price_bounded.cmp(&a.candidate.quote.price_bounded));
    priced.extend(unpriced);
    priced
}

/// The time that a quote stays in the cache.
pub const QUOTE_TTL: Duration = Duration::from_secs(10);
/// The most quotes in the cache.
pub const QUOTE_CACHE_SIZE: usize = 4096;

/// The key of a quote: the node, the service and the configuration as sent (bytes).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct QuoteKey {
    /// The identity of the node.
    pub peer_id: String,
    /// The service id.
    pub service_id: [u8; 32],
    /// The encoded `Configuration`, in the MU of the node.
    pub configuration: Vec<u8>,
}

/// Quotes for [`QUOTE_TTL`], at most [`QUOTE_CACHE_SIZE`]. When it is full, the oldest
/// entry goes. A cache stops repeated calls (the node puts a client that makes more than
/// 120 calls in 60 s in quarantine).
#[derive(Debug, Default)]
pub struct QuoteCache {
    entries: HashMap<QuoteKey, (Instant, EstimatedCost)>,
    order: VecDeque<(Instant, QuoteKey)>,
}

impl QuoteCache {
    /// An empty cache.
    pub fn new() -> Self {
        Self::default()
    }

    /// The quote for `key`, if it is younger than [`QUOTE_TTL`] at `now`.
    pub fn get(&self, key: &QuoteKey, now: Instant) -> Option<EstimatedCost> {
        self.entries
            .get(key)
            .filter(|(at, _)| now.saturating_duration_since(*at) < QUOTE_TTL)
            .map(|(_, quote)| quote.clone())
    }

    /// Keep `quote` for `key` from `now`.
    pub fn put(&mut self, key: QuoteKey, quote: EstimatedCost, now: Instant) {
        self.entries.insert(key.clone(), (now, quote));
        self.order.push_back((now, key));
        // Drop the stale entries of the queue, and the oldest when the cache is full.
        while let Some((at, key)) = self.order.front() {
            let current = self.entries.get(key).map(|(t, _)| *t);
            let replaced = current != Some(*at);
            let expired = now.saturating_duration_since(*at) >= QUOTE_TTL;
            let full = self.entries.len() > QUOTE_CACHE_SIZE;
            if !(replaced || expired || full) {
                break;
            }
            if !replaced {
                self.entries.remove(key);
            }
            self.order.pop_front();
        }
    }

    /// How many quotes are in the cache.
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// True when the cache is empty.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}
