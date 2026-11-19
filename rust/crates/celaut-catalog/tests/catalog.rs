//! The catalog on real data: the boxes in `tests/fixtures` are answers of the explorer
//! of Ergo (2026-10-15), cut down to the fields that the catalog reads. Most results on
//! chain are test data ("False results, invented"): the tests check the code, not the
//! services.

use std::collections::HashMap;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;

use celaut_catalog::fetch::{
    load_declared_services, load_publisher_reputations, load_reputations, load_objective_data,
    load_objective_services, load_objectives, CatalogError, Explorer, MAX_REPUTATION_TOKENS,
};
use celaut_catalog::parse::{parse_benchmark, parse_coverage, parse_result, parse_objective};
use celaut_catalog::rank::{rank_services, Reputations, ObjectiveData};
use celaut_catalog::{TypeIds, DEFAULT_BENCHMARK_TYPE, DEFAULT_COVERAGE_TYPE, DEFAULT_RESULT_TYPE};
use futures::executor::block_on;
use serde_json::{json, Value};

/// The type ids of the tests. They are not the default ones, so that a test shows that the
/// ids come from the caller.
const OBJECTIVE_TYPE: &str = "0b1ec7110b1ec7110b1ec7110b1ec7110b1ec7110b1ec7110b1ec7110b1ec711";
const COVERAGE_TYPE: &str = "c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0";
const BENCHMARK_TYPE: &str = "bebebebebebebebebebebebebebebebebebebebebebebebebebebebebebebebe";
const RESULT_TYPE: &str = "5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e";

fn types() -> TypeIds {
    TypeIds {
        objective: OBJECTIVE_TYPE.into(),
        coverage: COVERAGE_TYPE.into(),
        benchmark: BENCHMARK_TYPE.into(),
        result: RESULT_TYPE.into(),
    }
}

const OBJECTIVES: &str = include_str!("fixtures/objectives.json");
const COVERAGES: &str = include_str!("fixtures/coverages.json");
const BENCHMARKS: &str = include_str!("fixtures/benchmarks.json");
const RESULTS: &str = include_str!("fixtures/results.json");

/// The token of the publisher of most boxes, and of the objective "Boolean Satisfiability".
const TOKEN_A: &str = "2e7435641bf336bc8b1a3fe54a01bb581d2c906c5fa8e6ad0ffd3044b670bb5d";
const TOKEN_B: &str = "edd0b36908412d55b29d3554a57f427d4cb76dd77c4cf805bcae8d7fe1a209cf";

const SAT_SOLVER: &str = "a09268a8d7594e615ee872900bff8a2784e4c3f003011dda8e746976e851aee5";
const MARKET_STRATEGY: &str = "6c3a3a7f6f5fe8d7b7fb8a78b3eab57fc6e6a7087fbd39fd0cc483a07e207e76";
const PROOF_OF_RESERVES: &str = "f97c838d4ea6fe79e27ed4f94503e72229ad9f9551f4070108919184286109dd";
const SATISFIABILITY: &str = "a35ce1e6918072b60cb496135cdc86b98822b496adcd18cac61fa45c85c58463";

fn items(file: &str) -> Vec<Value> {
    let v: Value = serde_json::from_str(file).unwrap();
    v["items"].as_array().unwrap().clone()
}

/// An explorer that serves the fixtures, and counts what it is asked.
#[derive(Default)]
struct Fixture {
    reputations: HashMap<String, f64>,
    failing_tokens: Vec<String>,
    failing_types: Vec<&'static str>,
    box_calls: AtomicUsize,
    token_calls: Mutex<Vec<String>>,
}

impl Explorer for Fixture {
    async fn boxes(&self, type_nft: &str, subject: Option<&str>) -> Result<Vec<Value>, CatalogError> {
        self.box_calls.fetch_add(1, Ordering::SeqCst);
        if self.failing_types.contains(&type_nft) {
            return Err(CatalogError::Explorer("HTTP 500".into()));
        }
        let file = match type_nft {
            OBJECTIVE_TYPE => OBJECTIVES,
            COVERAGE_TYPE => COVERAGES,
            BENCHMARK_TYPE => BENCHMARKS,
            RESULT_TYPE => RESULTS,
            other => panic!("unexpected type {other}"),
        };
        Ok(items(file)
            .into_iter()
            .filter(|b| match subject {
                Some(id) => b["additionalRegisters"]["R5"]["renderedValue"] == json!(id),
                None => true,
            })
            .collect())
    }

    async fn token_value(&self, token_id: &str) -> Result<f64, CatalogError> {
        self.token_calls.lock().unwrap().push(token_id.to_string());
        if self.failing_tokens.iter().any(|t| t == token_id) {
            return Err(CatalogError::Explorer("HTTP 429".into()));
        }
        Ok(self.reputations.get(token_id).copied().unwrap_or(0.0))
    }
}

fn with_reputations() -> Fixture {
    Fixture {
        reputations: HashMap::from([(TOKEN_A.to_string(), 3e9), (TOKEN_B.to_string(), 1e9)]),
        ..Default::default()
    }
}

fn close(a: f64, b: f64) -> bool {
    (a - b).abs() < 1e-9
}

fn short(ranked: &[celaut_catalog::rank::ServiceScore]) -> Vec<(&str, f64)> {
    ranked.iter().map(|s| (&s.service_id[..8], s.score)).collect()
}

#[test]
fn every_fixture_box_parses() {
    assert_eq!(items(OBJECTIVES).iter().filter_map(parse_objective).count(), 7);
    assert_eq!(items(COVERAGES).iter().filter_map(parse_coverage).count(), 15);
    assert_eq!(items(BENCHMARKS).iter().filter_map(parse_benchmark).count(), 18);
    assert_eq!(items(RESULTS).iter().filter_map(parse_result).count(), 50);
}

#[test]
fn the_objectives_have_names_and_publishers() {
    let objectives = block_on(load_objectives(&Fixture::default(), &types())).unwrap();
    let names: Vec<&str> = objectives.iter().map(|s| s.name.as_str()).collect();
    assert_eq!(objectives.len(), 7);
    assert!(names.contains(&"Boolean SAT Solver"));
    assert!(names.contains(&"market-strategy"));
    let sat = objectives.iter().find(|s| s.box_id == SAT_SOLVER).unwrap();
    assert_eq!(sat.profile.as_deref(), Some(TOKEN_A));
    assert!(!sat.prose.is_empty());
}

#[test]
fn every_objective_has_the_height_of_its_box() {
    let objectives = block_on(load_objectives(&Fixture::default(), &types())).unwrap();
    let raw = items(OBJECTIVES);
    for s in &objectives {
        let b = raw.iter().find(|b| b["boxId"] == json!(s.box_id)).unwrap();
        assert_eq!(u64::from(s.height), b["creationHeight"].as_u64().unwrap(), "{}", s.name);
        assert!(s.height > 0);
    }
}

#[test]
fn the_declared_services_of_every_objective_come_from_one_query() {
    let explorer = Fixture::default();
    let services = block_on(load_declared_services(&explorer, &types())).unwrap();
    assert_eq!(explorer.box_calls.load(Ordering::SeqCst), 1);
    // The same counts as the coverages of one objective (the_data_of_an_objective_is_its_own).
    assert_eq!(services[MARKET_STRATEGY].len(), 4);
    let per_objective: usize = services.values().map(Vec::len).sum();
    assert_eq!(per_objective, 15);
    for (objective, ids) in &services {
        let data = block_on(load_objective_data(&Fixture::default(), &types(), objective)).unwrap();
        let mut own: Vec<String> = data.coverages.iter().map(|c| c.service_id.to_ascii_lowercase()).collect();
        own.dedup();
        assert_eq!(ids, &own, "{objective}");
        assert!(ids.iter().all(|id| id.len() == 64), "{objective}");
    }
}

#[test]
fn the_declared_services_fail_with_the_explorer() {
    let explorer = Fixture {
        failing_types: vec![COVERAGE_TYPE],
        ..Default::default()
    };
    assert!(block_on(load_declared_services(&explorer, &types())).is_err());
}

#[test]
fn the_reputation_of_the_publishers_asks_once_for_each_token() {
    let explorer = with_reputations();
    let objectives = block_on(load_objectives(&explorer, &types())).unwrap();
    let reputations = block_on(load_publisher_reputations(&explorer, &objectives));
    assert_eq!(reputations.0.len(), 2);
    assert!(close(reputations.0[TOKEN_A], 3e9));
    assert!(close(reputations.0[TOKEN_B], 1e9));
    assert_eq!(explorer.token_calls.lock().unwrap().len(), 2);

    let failing = Fixture {
        failing_tokens: vec![TOKEN_B.to_string()],
        ..with_reputations()
    };
    let reputations = block_on(load_publisher_reputations(&failing, &objectives));
    assert_eq!(reputations.0.len(), 1);
    assert!(!reputations.0.contains_key(TOKEN_B));
}

#[test]
fn the_data_of_an_objective_is_its_own() {
    let data = block_on(load_objective_data(&Fixture::default(), &types(), MARKET_STRATEGY)).unwrap();
    assert_eq!(data.coverages.len(), 4);
    assert_eq!(data.benchmarks.len(), 5);
    assert_eq!(data.results.len(), 20);
    assert!(data.benchmarks.iter().all(|b| b.objective_box_id == MARKET_STRATEGY));
}

#[test]
fn an_objective_costs_a_bounded_number_of_requests() {
    let explorer = with_reputations();
    block_on(load_objective_services(&explorer, &types(), MARKET_STRATEGY)).unwrap();
    // The coverages, the benchmarks, and the results of each of the 5 benchmarks.
    assert_eq!(explorer.box_calls.load(Ordering::SeqCst), 2 + 5);
    // Every box of this objective has the same publisher: one request, not one for each box.
    assert_eq!(*explorer.token_calls.lock().unwrap(), [TOKEN_A]);
}

#[test]
fn market_strategy_is_ranked_by_what_the_services_measured() {
    let ranked = block_on(load_objective_services(&with_reputations(), &types(), MARKET_STRATEGY)).unwrap();
    let order: Vec<&str> = ranked.iter().map(|s| &s.service_id[..8]).collect();
    assert_eq!(order, ["09c842dd", "ef30134f", "5cbeabc2", "027c8c12"]);
    // The same numbers as an independent implementation of the formula.
    for (got, want) in short(&ranked).iter().zip([
        0.8265363958972352,
        0.629313509544787,
        0.5586880100439422,
        0.5185837320494608,
    ]) {
        assert!(close(got.1, want), "{} {} {}", got.0, got.1, want);
    }
    assert!(ranked.iter().all(|s| s.direct && s.benchmarks == 5 && s.results == 5));
    assert!(close(ranked[0].performance.unwrap(), 0.7521948512817647));
}

#[test]
fn a_service_that_fails_every_check_is_last() {
    let ranked = block_on(load_objective_services(&with_reputations(), &types(), PROOF_OF_RESERVES)).unwrap();
    let order: Vec<&str> = ranked.iter().map(|s| &s.service_id[..8]).collect();
    // The two that are equal keep the order of the coverage boxes.
    assert_eq!(order, ["5aa46cb0", "47616445", "360e60f9"]);
    assert!(close(ranked[0].score, 1.0));
    assert!(close(ranked[2].score, 0.3));
}

#[test]
fn equal_measurements_keep_the_order_of_the_coverages() {
    let ranked = block_on(load_objective_services(&with_reputations(), &types(), SAT_SOLVER)).unwrap();
    let order: Vec<&str> = ranked.iter().map(|s| &s.service_id[..8]).collect();
    assert_eq!(order, ["fda465ad", "4e34c0e2"]);
    assert!(close(ranked[0].score, 0.8454811536905151));
    assert_eq!(ranked[0].score, ranked[1].score);
}

#[test]
fn a_service_that_only_a_result_names_is_in_the_ranking_and_not_direct() {
    let ranked = block_on(load_objective_services(&with_reputations(), &types(), SATISFIABILITY)).unwrap();
    assert_eq!(short(&ranked).len(), 2);
    assert_eq!(&ranked[0].service_id[..8], "fda465ad");
    assert!(ranked[0].direct);
    assert_eq!(&ranked[1].service_id[..8], "1f673d28");
    assert!(!ranked[1].direct);
    assert!(close(ranked[0].score, 0.7497512424153482));
    assert!(close(ranked[1].score, 0.525781653214459));
}

#[test]
fn a_token_that_fails_has_no_reputation_and_the_ranking_still_works() {
    let mut explorer = with_reputations();
    explorer.failing_tokens = vec![TOKEN_A.to_string()];
    let ranked = block_on(load_objective_services(&explorer, &types(), MARKET_STRATEGY)).unwrap();
    assert_eq!(ranked.len(), 4);
    let order: Vec<&str> = ranked.iter().map(|s| &s.service_id[..8]).collect();
    assert_eq!(order, ["09c842dd", "ef30134f", "5cbeabc2", "027c8c12"]);
}

#[test]
fn a_box_query_that_fails_is_an_error() {
    let explorer = Fixture {
        failing_types: vec![RESULT_TYPE],
        ..Default::default()
    };
    let error = block_on(load_objective_services(&explorer, &types(), MARKET_STRATEGY)).unwrap_err();
    assert_eq!(error, CatalogError::Explorer("HTTP 500".into()));
    let explorer = Fixture {
        failing_types: vec![OBJECTIVE_TYPE],
        ..Default::default()
    };
    assert!(block_on(load_objectives(&explorer, &types())).is_err());
}

#[test]
fn an_objective_id_that_is_not_a_box_id_is_refused_before_any_request() {
    let explorer = Fixture::default();
    for bad in ["", "abc", &"g".repeat(64), &"a".repeat(63)] {
        assert_eq!(
            block_on(load_objective_services(&explorer, &types(), bad)).unwrap_err(),
            CatalogError::BadObjectiveId
        );
    }
    assert_eq!(explorer.box_calls.load(Ordering::SeqCst), 0);
    // Capital letters are the same id.
    assert!(block_on(load_objective_data(&explorer, &types(), &MARKET_STRATEGY.to_uppercase())).is_ok());
}

#[test]
fn the_reputation_tokens_that_an_objective_reads_are_bounded() {
    // 100 publishers, each with one coverage.
    let coverages = (0..100)
        .map(|i| {
            celaut_catalog::parse::Coverage {
                box_id: format!("c{i}"),
                profile: Some(format!("token-{i}")),
                service_id: format!("s{i}"),
            }
        })
        .collect();
    let data = ObjectiveData {
        coverages,
        ..Default::default()
    };
    let explorer = Fixture::default();
    let reputations = block_on(load_reputations(&explorer, &data));
    assert_eq!(explorer.token_calls.lock().unwrap().len(), MAX_REPUTATION_TOKENS);
    assert_eq!(reputations.0.len(), MAX_REPUTATION_TOKENS);
    // The services over the limit are still ranked, with no reputation.
    assert_eq!(rank_services(&data, &reputations).len(), 100);
}

#[test]
fn no_reputation_still_ranks_by_measurement() {
    let data = block_on(load_objective_data(&Fixture::default(), &types(), MARKET_STRATEGY)).unwrap();
    let ranked = rank_services(&data, &Reputations::default());
    let order: Vec<&str> = ranked.iter().map(|s| &s.service_id[..8]).collect();
    assert_eq!(order, ["09c842dd", "ef30134f", "5cbeabc2", "027c8c12"]);
}

#[test]
fn the_default_types_have_no_objective_and_the_known_ids_of_the_others() {
    let types = TypeIds::default();
    assert_eq!(types.objective, "");
    assert_eq!(types.coverage, DEFAULT_COVERAGE_TYPE);
    assert_eq!(types.benchmark, DEFAULT_BENCHMARK_TYPE);
    assert_eq!(types.result, DEFAULT_RESULT_TYPE);
    assert!(types.normalized().is_ok());
}

#[test]
fn with_no_objective_type_the_catalog_is_empty_and_makes_no_request() {
    let explorer = Fixture::default();
    let none = TypeIds {
        objective: "  ".into(),
        ..types()
    };
    assert!(block_on(load_objectives(&explorer, &none)).unwrap().is_empty());
    assert!(block_on(load_declared_services(&explorer, &none)).unwrap().is_empty());
    assert_eq!(explorer.box_calls.load(Ordering::SeqCst), 0);
}

#[test]
fn the_catalog_asks_for_the_type_ids_that_the_caller_gives() {
    // The fixture panics on a type that it does not know: the default ids are unknown.
    let objectives = block_on(load_objectives(&Fixture::default(), &types())).unwrap();
    assert!(!objectives.is_empty());
    let other = TypeIds {
        objective: OBJECTIVE_TYPE.to_uppercase(),
        ..types()
    };
    assert_eq!(block_on(load_objectives(&Fixture::default(), &other)).unwrap().len(), objectives.len());
}

#[test]
fn a_type_id_that_is_not_64_hexadecimal_characters_is_refused_before_any_request() {
    let explorer = Fixture::default();
    let bad = [
        ("objective", TypeIds { objective: "abc".into(), ..types() }),
        ("coverage", TypeIds { coverage: "".into(), ..types() }),
        ("benchmark", TypeIds { benchmark: "g".repeat(64), ..types() }),
        ("result", TypeIds { result: "a".repeat(63), ..types() }),
    ];
    for (name, ids) in bad {
        let expected = CatalogError::BadTypeId(name.into());
        assert_eq!(block_on(load_objectives(&explorer, &ids)).unwrap_err(), expected);
        assert_eq!(block_on(load_declared_services(&explorer, &ids)).unwrap_err(), expected);
        assert_eq!(
            block_on(load_objective_services(&explorer, &ids, MARKET_STRATEGY)).unwrap_err(),
            expected
        );
    }
    assert_eq!(explorer.box_calls.load(Ordering::SeqCst), 0);
}
