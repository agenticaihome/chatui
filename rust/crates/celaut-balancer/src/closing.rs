//! The activity window of a node (nodo#344): when it closes, what it does with a running
//! instance then, and when it opens again. The port of
//! `nodo:src/balancers/estimated_cost_sorter/interruption.py` and of
//! `schedule_closed_reason` in `nodo:src/utils/cost_functions/architecture_resources.py`.
//!
//! - The quote is the authority for one instance: `EstimatedCost.closes_at` (the unix time
//!   of the next close, in seconds; 0 is no close scheduled) and `on_close`.
//! - `Peer.activity_window` is a hint: the open spans of one repeating day, in minutes
//!   from 00:00 UTC (start included, end not; an end before the start passes midnight).
//!   No message: the node gives no schedule. No spans: always open.
//!
//! Input from a peer must never make this crate panic.

use celaut_proto::celaut::{ActivityWindow, EstimatedCost, OnClose};

use crate::funding::funded_life_seconds;

/// The interruption class of a quote, best first (`interruption.py`): a class, never a
/// term of the score. The sort key of the balancer is the price bound, then this class,
/// then the score.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum Interruption {
    /// 0: `ON_CLOSE_REFUSE`, or no close scheduled.
    None = 0,
    /// 1: a hibernation at or after the end of the funded life.
    HibernateOutsideLife = 1,
    /// 2: a stop at or after the end of the funded life.
    StopOutsideLife = 2,
    /// 3: a hibernation before the end of the funded life.
    HibernateInsideLife = 3,
    /// 4: a stop before the end of the funded life.
    StopInsideLife = 4,
}

/// The `on_close` of a quote. A value that this client does not know is
/// `ON_CLOSE_REFUSE`: the default of the enum, and what an older node reads.
pub fn on_close(quote: &EstimatedCost) -> OnClose {
    OnClose::try_from(quote.on_close).unwrap_or(OnClose::Refuse)
}

/// `interruption_class`: the class of `quote` for a start funded with `initial_mu`
/// (`None`: no `initial_mu`, the default periods of the node), at the unix time `now`.
pub fn interruption_class(quote: &EstimatedCost, initial_mu: Option<u128>, now: i64) -> Interruption {
    let action = on_close(quote);
    if !matches!(action, OnClose::Stop | OnClose::Hibernate) || quote.closes_at <= 0 {
        return Interruption::None;
    }
    let end_of_life = now.saturating_add(funded_life_seconds(quote, initial_mu));
    let outside = quote.closes_at >= end_of_life;
    match (action, outside) {
        (OnClose::Hibernate, true) => Interruption::HibernateOutsideLife,
        (OnClose::Hibernate, false) => Interruption::HibernateInsideLife,
        (_, true) => Interruption::StopOutsideLife,
        (_, false) => Interruption::StopInsideLife,
    }
}

/// The minutes of one day.
const DAY_MINUTES: i32 = 1440;

/// The spans of `window`, or `None` when they say nothing: no window, no spans (always
/// open), or a span that cannot be read (a minute out of 0 to 1439, or two equal edges).
/// The schedule is a hint, so a doubt is never a reason to call a node closed.
fn readable_spans(window: Option<&ActivityWindow>) -> Option<Vec<(i32, i32)>> {
    let window = window?;
    if window.spans.is_empty() {
        return None;
    }
    let mut spans = Vec::with_capacity(window.spans.len());
    for span in &window.spans {
        let (start, end) = (span.start_minute, span.end_minute);
        if !(0..DAY_MINUTES).contains(&start) || !(0..DAY_MINUTES).contains(&end) || start == end {
            return None;
        }
        spans.push((start, end));
    }
    Some(spans)
}

fn in_span(minute: i32, (start, end): (i32, i32)) -> bool {
    if start < end {
        start <= minute && minute < end
    } else {
        minute >= start || minute < end
    }
}

/// `schedule_closed_reason(...) is not None`: whether the announced schedule says that
/// the node is closed at the unix time `now`. False when the schedule says nothing.
pub fn schedule_closed(window: Option<&ActivityWindow>, now: i64) -> bool {
    let Some(spans) = readable_spans(window) else {
        return false;
    };
    let minute = minute_of_day(now);
    !spans.iter().any(|s| in_span(minute, *s))
}

/// The minute of the UTC day of the unix time `t`.
fn minute_of_day(t: i64) -> i32 {
    (t.div_euclid(60).rem_euclid(i64::from(DAY_MINUTES))) as i32
}

/// The unix time, in seconds, at which the announced schedule opens next after `now`,
/// if it says that the node is closed at `now`. `None` when the schedule says nothing or
/// that the node is open. It is a hint, as the schedule is: the node can change it.
pub fn next_open(window: Option<&ActivityWindow>, now: i64) -> Option<i64> {
    if !schedule_closed(window, now) {
        return None;
    }
    let spans = readable_spans(window)?;
    let minute_start = now.div_euclid(60) * 60;
    let day_start = now.div_euclid(86_400) * 86_400;
    let mut best: Option<i64> = None;
    for day in 0..=1_i64 {
        for (start, _) in &spans {
            let t = day_start + day * 86_400 + i64::from(*start) * 60;
            if t > minute_start && best.map_or(true, |b| t < b) {
                best = Some(t);
            }
        }
    }
    best
}
