//! The funding sum, the funded life, the interruption class and the closed schedule
//! against the known answers of the nodo code (`tests/vectors/generate.py`).

use celaut_balancer::{
    balance_for_periods, funded_life_seconds, funding_sum_mu, interruption_class, next_open,
    schedule_closed, Interruption, PriceBound,
};
use celaut_proto::celaut::activity_window::Span;
use celaut_proto::celaut::{ActivityWindow, Amount, EstimatedCost};
use serde_json::Value;

fn vectors() -> Value {
    serde_json::from_str(include_str!("vectors/funding.json")).expect("funding.json")
}

fn mu(v: &Value) -> Option<u128> {
    v.as_str().map(|s| s.parse().expect("an amount"))
}

fn quote(f: &Value) -> EstimatedCost {
    let amount = |n: &str| Some(Amount { n: n.to_string() });
    let init = f["init"].as_str().unwrap();
    EstimatedCost {
        cost: amount(f["cost"].as_str().unwrap()),
        init_maintenance_cost: amount(init),
        max_maintenance_cost: amount(&(init.parse::<u128>().unwrap() * 2).to_string()),
        maintenance_seconds_loop: f["loop"].as_i64().unwrap() as i32,
        price_bounded: f["bounded"].as_bool().unwrap(),
        price_volatility: f["v"].as_f64().unwrap() as f32,
        volatility_period_seconds: f["T"].as_i64().unwrap() as i32,
        on_close: f["on_close"].as_i64().unwrap() as i32,
        closes_at: f["closes_at"].as_i64().unwrap(),
        ..Default::default()
    }
}

/// Exact below 2^53 MU; above, within a relative 1e-12 (the port sums in floating point).
fn same_mu(ours: u128, nodo: u128) -> bool {
    if nodo < (1 << 53) {
        return ours == nodo;
    }
    (ours as f64 - nodo as f64).abs() <= nodo as f64 * 1e-12
}

#[test]
fn the_funding_sum_equals_nodo() {
    let v = vectors();
    let cases = v["funding"].as_array().unwrap();
    assert!(cases.len() >= 10);
    for c in cases {
        let (init, vol) = (u128::from(c["init"].as_u64().unwrap()), c["v"].as_f64().unwrap());
        let (t, lp, n) = (c["T"].as_i64().unwrap(), c["loop"].as_i64().unwrap(), c["n"].as_u64().unwrap());
        let ours = balance_for_periods(init, f64::from(vol as f32), t, lp, n);
        match mu(&c["sum"]) {
            None => assert_eq!(ours, None, "{c}"),
            Some(nodo) => assert!(same_mu(ours.unwrap(), nodo), "{c}: {ours:?}"),
        }
        let unbounded = funding_sum_mu(init, lp, None, n).unwrap();
        assert_eq!(Some(unbounded), mu(&c["unbounded"]), "{c}");
    }
}

#[test]
fn a_value_that_is_not_finite_or_below_zero_counts_as_zero() {
    for bad in [f64::NAN, f64::INFINITY, -0.5] {
        assert_eq!(balance_for_periods(1000, bad, 3600, 60, 10), Some(10_000));
    }
    // A negative period is one period for the whole life: k = 1 for every tick.
    assert_eq!(balance_for_periods(1000, 0.1, -5, 60, 10), Some(11_000));
    assert_eq!(PriceBound::strict(0.1, -5).period_seconds, 0);
}

#[test]
fn the_funded_life_equals_nodo() {
    let v = vectors();
    for c in v["life"].as_array().unwrap() {
        let q = quote(&c["quote"]);
        let ours = funded_life_seconds(&q, mu(&c["initial_mu"]));
        assert_eq!(ours, c["life"].as_i64().unwrap(), "{c}");
    }
}

#[test]
fn the_interruption_class_equals_nodo() {
    let v = vectors();
    let cases = v["class"].as_array().unwrap();
    for c in cases {
        let q = quote(&c["quote"]);
        let ours = interruption_class(&q, mu(&c["initial_mu"]), c["now"].as_i64().unwrap());
        assert_eq!(ours as i64, c["class"].as_i64().unwrap(), "{c}");
    }
    // Every class is in the vectors.
    for class in 0..=4 {
        assert!(cases.iter().any(|c| c["class"].as_i64() == Some(class)));
    }
    assert!(Interruption::StopOutsideLife < Interruption::HibernateInsideLife);
}

fn window(spans: &Value) -> Option<ActivityWindow> {
    let spans = spans.as_array()?;
    Some(ActivityWindow {
        spans: spans
            .iter()
            .map(|s| Span {
                start_minute: s[0].as_i64().unwrap() as i32,
                end_minute: s[1].as_i64().unwrap() as i32,
            })
            .collect(),
        ..Default::default()
    })
}

/// 2026-11-10 00:00:30 UTC: the vectors use 30 s after each minute of that day.
const DAY: i64 = 1_794_268_830;

#[test]
fn the_closed_schedule_equals_nodo() {
    let v = vectors();
    let cases = v["closed"].as_array().unwrap();
    for c in cases {
        let w = window(&c["spans"]);
        let now = DAY + c["minute"].as_i64().unwrap() * 60;
        assert_eq!(schedule_closed(w.as_ref(), now), c["closed"].as_bool().unwrap(), "{c}");
    }
    assert!(cases.iter().any(|c| c["closed"].as_bool() == Some(true)));
}

#[test]
fn next_open_is_the_next_start_after_a_closed_minute() {
    let w = window(&serde_json::json!([[600, 720], [1320, 60]])).unwrap();
    // 08:00:30 UTC: closed; opens at 10:00 the same day.
    assert_eq!(next_open(Some(&w), DAY + 8 * 3600), Some(DAY - 30 + 600 * 60));
    // 13:00:30: closed; the span over midnight opens at 22:00.
    assert_eq!(next_open(Some(&w), DAY + 13 * 3600), Some(DAY - 30 + 1320 * 60));
    // 23:00:30 and 10:30:30: open, so no opening to give.
    assert_eq!(next_open(Some(&w), DAY + 23 * 3600), None);
    assert_eq!(next_open(Some(&w), DAY + 10 * 3600 + 1800), None);
    // One span: at 13:00:30 the next opening is 10:00 the next day.
    let w2 = window(&serde_json::json!([[600, 720]])).unwrap();
    assert_eq!(next_open(Some(&w2), DAY + 13 * 3600), Some(DAY - 30 + 86_400 + 600 * 60));
    // No schedule, always open, or a span that cannot be read: nothing to say.
    assert_eq!(next_open(None, DAY), None);
    assert_eq!(next_open(Some(&ActivityWindow::default()), DAY), None);
    let bad = window(&serde_json::json!([[600, 1440]])).unwrap();
    assert_eq!(next_open(Some(&bad), DAY), None);
}
