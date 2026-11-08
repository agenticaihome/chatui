//! The balancer: MU conversion, cost, score, order and quote cache.

use std::time::{Duration, Instant};

use celaut_balancer::*;
use celaut_proto::celaut::contract::Ledger;
use celaut_proto::celaut::{Amount, BytesKeyValue, Contract, ContractRate, EstimatedCost, Peer};

fn mu(n: &str) -> Option<Amount> {
    Some(Amount { n: n.into() })
}

fn quote(cost: &str, init: &str, max: &str, seconds: i32, variance: f32) -> EstimatedCost {
    EstimatedCost {
        cost: mu(cost),
        init_maintenance_cost: mu(init),
        max_maintenance_cost: mu(max),
        maintenance_seconds_loop: seconds,
        variance,
        children_initial_cost: None,
    }
}

fn flat(cost: &str) -> EstimatedCost {
    quote(cost, "0", "0", 0, 0.0)
}

fn candidate(peer: &str, quote: EstimatedCost, rate: Option<u128>) -> Candidate {
    Candidate {
        peer_id: peer.into(),
        quote,
        mu_per_nano_erg: rate,
        standing: Standing::default(),
    }
}

fn order(ranked: &[Ranked]) -> Vec<&str> {
    ranked
        .iter()
        .map(|r| r.candidate.peer_id.as_str())
        .collect()
}

#[test]
fn amounts_are_decimal_integers() {
    assert_eq!(amount(None), Ok(0));
    assert_eq!(amount(mu("0").as_ref()), Ok(0));
    assert_eq!(amount(mu("4500000").as_ref()), Ok(4_500_000));
    for bad in ["", "-1", "1e5", "1.5", " "] {
        assert!(matches!(
            amount(mu(bad).as_ref()),
            Err(BalancerError::BadAmount(_))
        ));
    }
    let huge = "9".repeat(60);
    assert_eq!(amount(mu(&huge).as_ref()), Err(BalancerError::TooLarge));
}

#[test]
fn cost_is_the_nodo_formula() {
    // vcnorm(1000, 0.5) = 1500. per_hour(100) = trunc(150 * 3600 / 60) = 9000,
    // per_hour(300) = 27000, mean 18000. Total 19500.
    assert_eq!(cost_mu(&quote("1000", "100", "300", 60, 0.5)), Ok(19_500.0));
    // No loop: only the cost.
    assert_eq!(cost_mu(&quote("1000", "100", "300", 0, 0.0)), Ok(1000.0));
    // Truncation at each step: vcnorm(7, 0.1) = trunc(7.7) = 7.
    // per_hour(1) = trunc(1 * 3600 / 7) = 514, per_hour(2) = trunc(7200 / 7) = 1028,
    // mean 771.
    assert_eq!(cost_mu(&quote("7", "1", "2", 7, 0.1)), Ok(778.0));
    assert!(cost_mu(&quote("x", "0", "0", 0, 0.0)).is_err());
}

#[test]
fn the_start_adds_children_initial_cost() {
    // nodo#538: the parent pays the start of its initial children; `cost` excludes them.
    let mut q = quote("1000", "100", "300", 60, 0.5);
    q.children_initial_cost = mu("500");
    assert_eq!(start_mu(&q), Ok(1500));
    // vcnorm(1500, 0.5) = 2250, plus the mean of 9000 and 27000.
    assert_eq!(cost_mu(&q), Ok(20_250.0));
    // An old node does not send the field: 0.
    q.children_initial_cost = None;
    assert_eq!(start_mu(&q), Ok(1000));
    q.children_initial_cost = mu("x");
    assert!(start_mu(&q).is_err());
}

#[test]
fn a_node_with_children_is_dearer_than_its_cost_says() {
    // Same cost, but `a` also asks for the start of its children: `b` comes first.
    let mut with_children = flat("1000");
    with_children.children_initial_cost = mu("5000");
    let ranked = rank(vec![
        candidate("a", with_children, Some(1)),
        candidate("b", flat("2000"), Some(1)),
    ]);
    assert_eq!(order(&ranked), ["b", "a"]);
}

#[test]
fn score_is_minus_ln_cost_plus_the_standing() {
    assert_eq!(score(0.0, Standing::default()), f64::INFINITY);
    let e = std::f64::consts::E;
    assert!((score(e, Standing::default()) + 1.0).abs() < 1e-12);
    let trusted = Standing {
        reputation: 50.0,
        ..Default::default()
    };
    // f(50, 50) = 0.5, times the weight 2.
    assert!((score(e, trusted) - 0.0).abs() < 1e-12);
    let all = Standing {
        reputation: -50.0,
        onchain: 1.0,
        donation: 1.0,
        ..Default::default()
    };
    assert!((score(1.0, all) - (-1.0 + 0.3 + 0.3)).abs() < 1e-12);
}

#[test]
fn rank_compares_in_nano_erg_best_first() {
    let ranked = rank(vec![
        // 1000 MU at 1 MU/nanoERG: 1000 nanoERG.
        candidate("a", flat("1000"), Some(1)),
        // 3000 MU at 10 MU/nanoERG: 300 nanoERG, cheaper than a.
        candidate("b", flat("3000"), Some(10)),
        // No ERG rate: after all the others.
        candidate("c", flat("1"), None),
        // Free: the best offer.
        candidate("d", flat("0"), Some(1)),
        // The same price as a: after a (stable).
        candidate("e", flat("1000"), Some(1)),
        // An amount that cannot be read: dropped.
        candidate("f", flat("-5"), Some(1)),
    ]);
    assert_eq!(order(&ranked), vec!["d", "b", "a", "e", "c"]);
    assert_eq!(ranked[1].cost_nano_erg, Some(300.0));
    assert_eq!(ranked[4].score, None);
}

#[test]
fn reputation_can_beat_a_higher_price() {
    // e^2 is the most that the local reputation can make up. With f = 0.5 (r = 50),
    // a node that asks e times more still wins.
    let mut good = candidate("good", flat("2700"), Some(1));
    good.standing.reputation = 50.0;
    let cheap = candidate("cheap", flat("1000"), Some(1));
    assert_eq!(order(&rank(vec![cheap, good])), vec!["good", "cheap"]);
}

fn ergo_rate(token: &str, rate: &str) -> ContractRate {
    ContractRate {
        contract: Some(Contract {
            ledger: Some(Ledger {
                tags: vec!["ergo".into()],
                ..Default::default()
            }),
            xattrs: vec![BytesKeyValue {
                key: "token_id".into(),
                value: Some(token.as_bytes().to_vec()),
            }],
        }),
        mu_per_unit: mu(rate),
    }
}

#[test]
fn the_erg_rate_comes_from_the_ergo_contract_with_erg() {
    let peer = Peer {
        payment_contracts: vec![ergo_rate("03faf2", "7"), ergo_rate("ERG", "2")],
        ..Default::default()
    };
    assert_eq!(erg_rate(&peer), Ok(2));
    let zero = Peer {
        payment_contracts: vec![ergo_rate("ERG", "0")],
        ..Default::default()
    };
    assert_eq!(erg_rate(&zero), Err(BalancerError::NoErgRate));
    assert_eq!(erg_rate(&Peer::default()), Err(BalancerError::NoErgRate));
}

#[test]
fn conversion_rounds_against_the_client() {
    // What the client owes rounds up, what it gives rounds down.
    assert_eq!(to_nano_erg(5, 2), 3);
    assert_eq!(to_nano_erg(4, 2), 2);
    assert_eq!(to_node_mu(3, 2), Ok(6));
    assert_eq!(to_node_mu(u128::MAX, 2), Err(BalancerError::TooLarge));
}

fn key(peer: &str) -> QuoteKey {
    QuoteKey {
        peer_id: peer.into(),
        service_id: [1; 32],
        configuration: vec![],
    }
}

#[test]
fn the_cache_keeps_a_quote_for_ten_seconds() {
    let t0 = Instant::now();
    let mut cache = QuoteCache::new();
    cache.put(key("a"), flat("5"), t0);
    assert_eq!(
        cache.get(&key("a"), t0 + Duration::from_secs(9)),
        Some(flat("5"))
    );
    assert_eq!(cache.get(&key("a"), t0 + QUOTE_TTL), None);
    assert_eq!(cache.get(&key("b"), t0), None);
    // Another configuration is another quote.
    let mut other = key("a");
    other.configuration = vec![1];
    assert_eq!(cache.get(&other, t0), None);
    // A new quote for the same key replaces the old one and keeps it alive.
    cache.put(key("a"), flat("6"), t0 + Duration::from_secs(8));
    cache.put(key("b"), flat("7"), t0 + Duration::from_secs(12));
    assert_eq!(
        cache.get(&key("a"), t0 + Duration::from_secs(12)),
        Some(flat("6"))
    );
    assert_eq!(cache.len(), 2);
    // An expired entry goes on the next put.
    cache.put(key("c"), flat("8"), t0 + Duration::from_secs(30));
    assert_eq!(cache.len(), 1);
}

#[test]
fn the_cache_has_a_size_limit() {
    let t0 = Instant::now();
    let mut cache = QuoteCache::new();
    for i in 0..QUOTE_CACHE_SIZE + 5 {
        cache.put(key(&i.to_string()), flat("1"), t0);
    }
    assert_eq!(cache.len(), QUOTE_CACHE_SIZE);
    // The oldest went.
    assert_eq!(cache.get(&key("0"), t0), None);
    assert!(cache
        .get(&key(&(QUOTE_CACHE_SIZE + 4).to_string()), t0)
        .is_some());
}

fn with_priority(peer: &str, cost: &str, priority: u8) -> Candidate {
    Candidate {
        standing: Standing {
            priority,
            ..Default::default()
        },
        ..candidate(peer, flat(cost), Some(1))
    }
}

#[test]
fn priority_factor_runs_from_minus_one_to_one() {
    assert_eq!(priority_factor(PRIORITY_MIN), -1.0);
    assert_eq!(priority_factor(PRIORITY_NEUTRAL), 0.0);
    assert_eq!(priority_factor(PRIORITY_MAX), 1.0);
    // More than the maximum counts as the maximum.
    assert_eq!(priority_factor(255), 1.0);
}

#[test]
fn neutral_priority_changes_nothing() {
    let e = std::f64::consts::E;
    assert_eq!(Standing::default().priority, PRIORITY_NEUTRAL);
    assert!((score(e, Standing::default()) + 1.0).abs() < 1e-12);
}

#[test]
fn priority_adds_its_weight_to_the_score() {
    let at = |priority| {
        score(
            1.0,
            Standing {
                priority,
                ..Default::default()
            },
        )
    };
    assert!((at(PRIORITY_MAX) - PRIORITY_WEIGHT).abs() < 1e-12);
    assert!((at(PRIORITY_MIN) + PRIORITY_WEIGHT).abs() < 1e-12);
    assert!(at(75) > at(50) && at(50) > at(25));
}

#[test]
fn a_higher_priority_wins_at_the_same_price() {
    let ranked = rank(vec![
        with_priority("low", "1000", 10),
        with_priority("neutral", "1000", PRIORITY_NEUTRAL),
        with_priority("full", "1000", PRIORITY_MAX),
    ]);
    assert_eq!(order(&ranked), ["full", "neutral", "low"]);
}

#[test]
fn priority_can_beat_a_moderately_lower_price_but_not_any_price() {
    // Full trust at 5 times the price still wins (5 < e^2).
    let ranked = rank(vec![
        with_priority("cheap", "1000", PRIORITY_NEUTRAL),
        with_priority("trusted", "5000", PRIORITY_MAX),
    ]);
    assert_eq!(order(&ranked), ["trusted", "cheap"]);
    // At 100 times the price it does not: the price still counts.
    let ranked = rank(vec![
        with_priority("cheap", "1000", PRIORITY_NEUTRAL),
        with_priority("trusted", "100000", PRIORITY_MAX),
    ]);
    assert_eq!(order(&ranked), ["cheap", "trusted"]);
}

#[test]
fn a_free_offer_still_comes_first() {
    let ranked = rank(vec![
        with_priority("full", "1000", PRIORITY_MAX),
        with_priority("free", "0", PRIORITY_MIN),
    ]);
    assert_eq!(order(&ranked), ["free", "full"]);
}

#[test]
fn the_weights_of_the_user_change_what_counts() {
    use celaut_balancer::{rank_with, score_with, Weights};
    let e = std::f64::consts::E;
    assert!((score_with(e, Standing::default(), &Weights::default()) + 1.0).abs() < 1e-12);
    let no_price = Weights {
        price: 0.0,
        ..Weights::default()
    };
    assert!(score_with(e, Standing::default(), &no_price).abs() < 1e-12);
    let double = Weights {
        price: 2.0,
        ..Weights::default()
    };
    assert!((score_with(e, Standing::default(), &double) + 2.0).abs() < 1e-12);
    assert_eq!(
        score_with(0.0, Standing::default(), &no_price),
        f64::INFINITY
    );
    let bad = Weights {
        price: f64::NAN,
        reputation: -3.0,
        onchain: 99.0,
        ..Weights::default()
    }
    .sanitized();
    assert_eq!((bad.price, bad.reputation, bad.onchain), (0.0, 0.0, 10.0));
    let w = Weights {
        price: 1.5,
        reputation: 0.25,
        onchain: 0.0,
        donation: 3.0,
        priority: 7.125,
    };
    assert_eq!(Weights::from_milli(w.to_milli()), w);
    let _ = rank_with(vec![], &w);
}
