//! The funding sum of a start and the funded life of an instance: the port of
//! `nodo:src/utils/cost_functions/price_bound.py` (nodo#636) and
//! `nodo:src/utils/cost_functions/funded_life.py` (nodo#344).
//!
//! A bounded quote promises that the price of one maintenance period rises at most by a
//! factor `(1 + v)` in each volatility period `T`, counted from the launch. The period
//! `i` (1 for the first) is charged at most `init * (1 + v)^k(i)`, with
//! `k(i) = floor(i * maintenance_seconds_loop / T) + 1`, and `k(i) = 1` when `T` is 0
//! (`price_bound.tick_period_index`). A start adds the sum of `N` periods to the `cost`
//! of the quote (the builds), and the node starts nothing with less than one period.
//!
//! nodo sums with exact fractions. This port sums in floating point, as the app's
//! `MaintenancePrice` does: below 2^53 MU the result is the same whole MU; above, it is
//! within a relative 1e-12 (`tests/vectors/funding.json`, made with the nodo code).
//!
//! Input from a peer must never make this crate panic.

use celaut_proto::celaut::EstimatedCost;

use crate::amount;

/// `deposits.DEFAULT_INITIAL_PERIODS` of nodo (default 360): the periods that a node
/// funds for a start that carries no `initial_mu`. A node can set another number; the
/// client cannot know it.
pub const DEFAULT_INITIAL_PERIODS: u64 = 360;

/// `funded_life.HORIZON_SECONDS`: the funded life is counted up to four days. The next
/// close of a window is at most three days away, so a longer life is "longer than any
/// close".
pub const HORIZON_SECONDS: i64 = 4 * 24 * 3600;

/// `ln(10^30)`: a factor `(1 + v)^k` above `10^30` is no limit at all
/// (`price_bound._LARGEST_FACTOR_LOG`).
const LARGEST_FACTOR_LOG: f64 = 69.077_552_789_821_37;

/// The price bound of a quote: the volatility `v` (finite, at least 0) and the period `T`
/// in seconds (at least 0; 0 is one period for the whole life).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PriceBound {
    /// `v`.
    pub volatility: f64,
    /// `T`.
    pub period_seconds: i64,
}

impl PriceBound {
    /// `price_bound.strict`: a volatility that is not a finite number of at least 0 is 0,
    /// and a negative period is 0. The volatility is read as the decimal that it was
    /// written as (a proto `float`: 0.1 arrives as 0.10000000149011612).
    pub fn strict(volatility: f64, period_seconds: i64) -> Self {
        let volatility = if volatility.is_finite() && volatility >= 0.0 {
            as_written(volatility)
        } else {
            0.0
        };
        PriceBound {
            volatility,
            period_seconds: period_seconds.max(0),
        }
    }

    /// `price_bound.of_quote`: the bound that the quote promises, or `None` when it
    /// promises none (`price_bounded` false).
    pub fn of_quote(quote: &EstimatedCost) -> Option<Self> {
        quote.price_bounded.then(|| {
            PriceBound::strict(
                f64::from(quote.price_volatility),
                i64::from(quote.volatility_period_seconds),
            )
        })
    }

    /// `k`, the volatility period of a time `elapsed_seconds` after the launch: 1 for
    /// `T = 0` and for a negative time.
    pub fn period_index(&self, elapsed_seconds: i64) -> u64 {
        if self.period_seconds <= 0 || elapsed_seconds < 0 {
            return 1;
        }
        (elapsed_seconds / self.period_seconds) as u64 + 1
    }

    /// `k(i)`, the volatility period of the maintenance period `i` (1 for the first):
    /// `period_index(i * loop_seconds)`.
    pub fn tick_period_index(&self, i: u64, loop_seconds: i64) -> u64 {
        let elapsed = i128::from(i) * i128::from(loop_seconds.max(0));
        self.period_index(i64::try_from(elapsed).unwrap_or(i64::MAX))
    }

    /// `(1 + v)^k`, or `None` when it is too large to be a limit.
    pub fn factor(&self, k: u64) -> Option<f64> {
        if self.volatility <= 0.0 {
            return Some(1.0);
        }
        if k as f64 * self.volatility.ln_1p() > LARGEST_FACTOR_LOG {
            return None;
        }
        Some((1.0 + self.volatility).powf(k as f64))
    }
}

/// A float of a proto as the decimal with 7 significant digits (`price_bound._rounded`).
fn as_written(value: f64) -> f64 {
    format!("{value:.6e}").parse().unwrap_or(0.0)
}

/// `price_bound.funding_sum_mu`: the balance that funds `periods` maintenance periods
/// of `init_mu` each, in MU, rounded up: the sum for `i` from 1 to `periods` of
/// `init_mu * (1 + v)^k(i)`. With no bound, or a volatility of 0, it is
/// `init_mu * periods`. 0 when `init_mu` or `periods` is 0. `None` when a factor is too
/// large to fund, or when the sum does not fit in 128 bits.
pub fn funding_sum_mu(
    init_mu: u128,
    loop_seconds: i64,
    bound: Option<&PriceBound>,
    periods: u64,
) -> Option<u128> {
    if init_mu == 0 || periods == 0 {
        return Some(0);
    }
    let bound = match bound {
        Some(b) if b.volatility > 0.0 => b,
        _ => return init_mu.checked_mul(u128::from(periods)),
    };
    let loop_seconds = loop_seconds.max(0);
    let mut total = 0.0_f64;
    let mut i = 1_u64;
    while i <= periods {
        let k = bound.tick_period_index(i, loop_seconds);
        // The last period with the same k: i * loop < k * T.
        let last = if bound.period_seconds <= 0 || loop_seconds == 0 {
            periods
        } else {
            let end = i128::from(k) * i128::from(bound.period_seconds) - 1;
            let last = end / i128::from(loop_seconds);
            u64::try_from(last).unwrap_or(u64::MAX).clamp(i, periods)
        };
        let factor = bound.factor(k)?;
        total += init_mu as f64 * factor * (last - i + 1) as f64;
        if last == u64::MAX {
            break;
        }
        i = last + 1;
    }
    // Rounded up, as nodo's exact sum; a sum within a relative 1e-12 of a whole MU is that
    // MU, so the error of the floating point (1.1 * 1000 = 1100.0000000000002) adds none.
    let rounded = (total * (1.0 - 1e-12)).ceil();
    if !rounded.is_finite() || rounded >= u128::MAX as f64 {
        return None;
    }
    Some(rounded as u128)
}

/// The funding sum of `n` periods with the numbers of a quote, as the issue chatui#129
/// names it: `balance_for_periods(init_maintenance, price_volatility,
/// volatility_period_seconds, maintenance_seconds_loop, n)`. The volatility and the
/// period are read strictly ([`PriceBound::strict`]): a value that is not finite, or
/// below 0, counts as 0. For a quote that is not bounded, pass a volatility of 0.
pub fn balance_for_periods(
    init_maintenance_mu: u128,
    price_volatility: f64,
    volatility_period_seconds: i64,
    maintenance_seconds_loop: i64,
    n: u64,
) -> Option<u128> {
    let bound = PriceBound::strict(price_volatility, volatility_period_seconds);
    funding_sum_mu(init_maintenance_mu, maintenance_seconds_loop, Some(&bound), n)
}

/// `funded_life.funded_life_seconds`: the seconds that a start with `initial_mu` pays at
/// the price of `quote`, at most [`HORIZON_SECONDS`]. `None` is a start with no
/// `initial_mu`: the node funds [`DEFAULT_INITIAL_PERIODS`] periods. 0 when the balance
/// (`initial_mu` less the `cost`) does not pay one period. A quote that cannot be read has
/// no known life: it gets the horizon.
pub fn funded_life_seconds(quote: &EstimatedCost, initial_mu: Option<u128>) -> i64 {
    let loop_seconds = i64::from(quote.maintenance_seconds_loop);
    if loop_seconds <= 0 {
        return HORIZON_SECONDS;
    }
    let Some(initial_mu) = initial_mu else {
        return (DEFAULT_INITIAL_PERIODS as i64)
            .saturating_mul(loop_seconds)
            .min(HORIZON_SECONDS);
    };
    let Ok(cost) = amount(quote.cost.as_ref()) else {
        return HORIZON_SECONDS;
    };
    let balance = initial_mu.saturating_sub(cost);
    if balance == 0 {
        return 0;
    }
    let init_mu = match amount(quote.init_maintenance_cost.as_ref()) {
        Ok(0) | Err(_) => return HORIZON_SECONDS,
        Ok(init) => init,
    };
    let bound = PriceBound::of_quote(quote);
    periods_paid(balance, init_mu, loop_seconds, bound.as_ref()) as i64 * loop_seconds
}

/// `funded_life._periods_paid`: the most periods whose summed charge fits in `balance`,
/// counted up to the horizon.
fn periods_paid(balance: u128, init_mu: u128, loop_seconds: i64, bound: Option<&PriceBound>) -> u64 {
    let most = (HORIZON_SECONDS + loop_seconds - 1) / loop_seconds;
    let most = most.max(0) as u64;
    let bound = match bound {
        Some(b) if b.volatility > 0.0 => b,
        _ => return u64::try_from(balance / init_mu).unwrap_or(u64::MAX).min(most),
    };
    let mut total = 0.0_f64;
    let mut factors: std::collections::HashMap<u64, Option<f64>> = Default::default();
    for i in 1..=most {
        let k = bound.tick_period_index(i, loop_seconds);
        let factor = *factors.entry(k).or_insert_with(|| bound.factor(k));
        let Some(factor) = factor else {
            return i - 1;
        };
        total += init_mu as f64 * factor;
        if total > balance as f64 {
            return i - 1;
        }
    }
    most
}
