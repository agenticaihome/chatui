//! The ranking of the services of an objective (`docs/celaut/catalog.md`, "Ranking"). It
//! follows `registry:src/lib/scoreGlobal.ts`:
//!
//! ```text
//! W(r)      = 0.5 + 0.5 * sign(r) * ln(1 + |r|) / ln(1 + N_max)    (0.5 if N_max <= 0)
//! N(x)      = (x - min) / (max - min)   (inverted if lower is better; 0.5 if max == min)
//! P_r       = sum over the metrics m of (1/M) * N(median of the case values for m)
//! C_r       = 0.4 * W(uploader) + 0.6 * W(result reputation)
//! P(S, B)   = sum of C_r * P_r / sum of C_r
//! Perf(S)   = sum over B of W(bench rep) * P(S, B) / sum of W(bench rep)
//! score(S)  = Perf null ? W_S : 0.7 * Perf + 0.3 * W_S     (W_S = W(coverage reputation))
//! ```
//!
//! A reputation is the value in nanoERG of the boxes that hold the reputation token of
//! the publisher (see [`crate::fetch`]). The uploader of a result and the result are
//! the same profile here, so both weights use the same reputation.

use std::collections::{HashMap, HashSet};

use crate::parse::{BenchResult, Benchmark, Coverage};

/// `alpha`: how much the uploader counts against the result itself.
const ALPHA: f64 = 0.4;
/// `beta`: how much the measured performance counts against the service reputation.
const BETA: f64 = 0.7;

/// What the ranking reads about one objective.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ObjectiveData {
    /// The coverage boxes about the objective, in the order of the explorer.
    pub coverages: Vec<Coverage>,
    /// The benchmarks of the objective.
    pub benchmarks: Vec<Benchmark>,
    /// The results of those benchmarks.
    pub results: Vec<BenchResult>,
}

/// The reputation of each profile token, in nanoERG. A token that is not here has 0.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Reputations(pub HashMap<String, f64>);

impl Reputations {
    fn of(&self, profile: &Option<String>) -> f64 {
        profile
            .as_ref()
            .and_then(|p| self.0.get(p))
            .copied()
            .unwrap_or(0.0)
    }
}

/// A service of an objective with its score.
#[derive(Debug, Clone, PartialEq)]
pub struct ServiceScore {
    pub service_id: String,
    /// The score, from 0 to 1. The best service has the highest.
    pub score: f64,
    /// The measured performance, from 0 to 1, if the service has usable results.
    pub performance: Option<f64>,
    /// `W_S`: the weight of the reputation of the service.
    pub service_weight: f64,
    /// The reputation of the service, in nanoERG (the tie-break).
    pub reputation: f64,
    /// True if a coverage box names the service. False if only a result does.
    pub direct: bool,
    /// The benchmarks in which the service has usable results.
    pub benchmarks: usize,
    /// The results behind the performance.
    pub results: usize,
}

/// `W(r)`, from 0 to 1. A reputation that is not a number, or no reputation at all in
/// the objective (`n_max` is 0), gives the neutral 0.5.
pub fn confidence_weight(reputation: f64, n_max: f64) -> f64 {
    if !reputation.is_finite() || !(n_max > 0.0) {
        return 0.5;
    }
    let scale = n_max.ln_1p();
    if scale == 0.0 {
        return 0.5;
    }
    let part = 0.5 * reputation.abs().ln_1p() / scale;
    if reputation >= 0.0 {
        0.5 + part
    } else {
        0.5 - part
    }
}

/// `N(x)`: bring `x` onto 0 to 1, with the direction of the metric. 0.5 if the range
/// is one value.
fn normalize(x: f64, min: f64, max: f64, higher_is_better: bool) -> f64 {
    if max == min {
        return 0.5;
    }
    let n = if higher_is_better {
        (x - min) / (max - min)
    } else {
        (max - x) / (max - min)
    };
    n.clamp(0.0, 1.0)
}

fn median(values: &mut [f64]) -> Option<f64> {
    if values.is_empty() {
        return None;
    }
    values.sort_by(f64::total_cmp);
    let mid = values.len() / 2;
    Some(if values.len() % 2 == 0 {
        (values[mid - 1] + values[mid]) / 2.0
    } else {
        values[mid]
    })
}

/// The values of metric `m` in the cases of a result that are numbers.
fn case_values(result: &BenchResult, m: usize) -> Vec<f64> {
    result
        .cases
        .iter()
        .filter_map(|c| c.metrics_values.get(m).copied().flatten())
        .collect()
}

/// The smallest and the largest value of each metric over every result of a benchmark.
fn metric_ranges(benchmark: &Benchmark, results: &[&BenchResult]) -> Vec<(f64, f64)> {
    (0..benchmark.metrics.len())
        .map(|m| {
            let values = results.iter().flat_map(|r| case_values(r, m));
            let (min, max) = values.fold((f64::INFINITY, f64::NEG_INFINITY), |(lo, hi), v| {
                (lo.min(v), hi.max(v))
            });
            if min.is_finite() {
                (min, max)
            } else {
                (0.0, 0.0)
            }
        })
        .collect()
}

/// `P(S, B)`, and how many results are behind it. None if the service has no usable
/// result in the benchmark.
fn performance_in(
    benchmark: &Benchmark,
    results: &[&BenchResult],
    service_id: &str,
    n_max: f64,
    reps: &Reputations,
) -> Option<(f64, usize)> {
    if benchmark.metrics.is_empty() {
        return None;
    }
    let ranges = metric_ranges(benchmark, results);
    let weight = 1.0 / benchmark.metrics.len() as f64;
    let (mut numerator, mut denominator, mut count) = (0.0, 0.0, 0);
    for result in results.iter().filter(|r| r.service_id == service_id) {
        let mut quality = 0.0;
        let mut contributed = false;
        for (m, metric) in benchmark.metrics.iter().enumerate() {
            let Some(median) = median(&mut case_values(result, m)) else {
                continue;
            };
            let (min, max) = ranges[m];
            quality += weight * normalize(median, min, max, metric.higher_is_better);
            contributed = true;
        }
        if !contributed {
            continue;
        }
        let reputation = reps.of(&result.profile);
        let confidence = ALPHA * confidence_weight(reputation, n_max)
            + (1.0 - ALPHA) * confidence_weight(reputation, n_max);
        numerator += confidence * quality;
        denominator += confidence;
        count += 1;
    }
    (count > 0 && denominator > 0.0).then(|| (numerator / denominator, count))
}

/// The services of an objective with their scores, best first. The services are the ones
/// that a coverage box names (in the order of the boxes) and then the ones that only a
/// result names. Equal scores are ordered by the reputation of the service, and then by
/// that order.
///
/// A coverage of a benchmark is not in [`ObjectiveData`]: it is a runner, not a solution.
pub fn rank_services(data: &ObjectiveData, reps: &Reputations) -> Vec<ServiceScore> {
    let benchmark_ids: HashSet<&str> = data.benchmarks.iter().map(|b| b.id.as_str()).collect();
    let results: Vec<&BenchResult> = data
        .results
        .iter()
        .filter(|r| benchmark_ids.contains(r.benchmark_id.as_str()))
        .collect();

    // The services, direct coverages first, once each. The reputation of a service is
    // the one of its coverage box, or of its first result if no coverage names it.
    let mut services: Vec<(String, f64, bool)> = Vec::new();
    let mut seen: HashSet<&str> = HashSet::new();
    for coverage in &data.coverages {
        if seen.insert(coverage.service_id.as_str()) {
            services.push((coverage.service_id.clone(), reps.of(&coverage.profile), true));
        }
    }
    for result in &results {
        if seen.insert(result.service_id.as_str()) {
            services.push((result.service_id.clone(), reps.of(&result.profile), false));
        }
    }

    // N_max: the largest reputation in the objective.
    let n_max = services
        .iter()
        .map(|(_, r, _)| *r)
        .chain(data.benchmarks.iter().map(|b| reps.of(&b.profile)))
        .chain(results.iter().map(|r| reps.of(&r.profile)))
        .filter(|r| r.is_finite())
        .fold(0.0_f64, |max, r| max.max(r.abs()));

    let mut scores: Vec<ServiceScore> = services
        .into_iter()
        .map(|(service_id, reputation, direct)| {
            let service_weight = confidence_weight(reputation, n_max);
            let (mut sum, mut weights, mut benchmarks, mut count) = (0.0, 0.0, 0, 0);
            for benchmark in &data.benchmarks {
                let in_benchmark: Vec<&BenchResult> = results
                    .iter()
                    .copied()
                    .filter(|r| r.benchmark_id == benchmark.id)
                    .collect();
                let Some((value, n)) =
                    performance_in(benchmark, &in_benchmark, &service_id, n_max, reps)
                else {
                    continue;
                };
                let weight = confidence_weight(reps.of(&benchmark.profile), n_max);
                sum += weight * value;
                weights += weight;
                benchmarks += 1;
                count += n;
            }
            let performance = (weights > 0.0).then(|| sum / weights);
            let score = match performance {
                None => service_weight,
                Some(p) => BETA * p + (1.0 - BETA) * service_weight,
            };
            ServiceScore {
                service_id,
                score,
                performance,
                service_weight,
                reputation,
                direct,
                benchmarks,
                results: count,
            }
        })
        .collect();
    // A stable sort: equal services keep the order of the list above.
    scores.sort_by(|a, b| {
        b.score
            .total_cmp(&a.score)
            .then(b.reputation.total_cmp(&a.reputation))
    });
    scores
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parse::{Case, Metric};

    fn metric(name: &str, higher_is_better: bool) -> Metric {
        Metric {
            name: name.into(),
            higher_is_better,
        }
    }

    fn benchmark(id: &str, profile: Option<&str>, metrics: Vec<Metric>) -> Benchmark {
        Benchmark {
            id: id.into(),
            profile: profile.map(str::to_string),
            objective_box_id: "objective".into(),
            name: id.into(),
            metrics,
        }
    }

    /// A result with one case per entry of `cases`.
    fn result(id: &str, benchmark: &str, service: &str, cases: &[&[Option<f64>]]) -> BenchResult {
        BenchResult {
            id: id.into(),
            profile: Some(format!("tok-{id}")),
            benchmark_id: benchmark.into(),
            service_id: service.into(),
            cases: cases
                .iter()
                .map(|c| Case {
                    metrics_values: c.to_vec(),
                })
                .collect(),
        }
    }

    fn coverage(service: &str, profile: Option<&str>) -> Coverage {
        Coverage {
            box_id: format!("cov-{service}"),
            profile: profile.map(str::to_string),
            service_id: service.into(),
        }
    }

    fn reps(list: &[(&str, f64)]) -> Reputations {
        Reputations(list.iter().map(|(k, v)| (k.to_string(), *v)).collect())
    }

    fn close(a: f64, b: f64) -> bool {
        (a - b).abs() < 1e-12
    }

    #[test]
    fn the_weight_follows_the_formula() {
        assert_eq!(confidence_weight(0.0, 0.0), 0.5);
        assert_eq!(confidence_weight(5.0, 0.0), 0.5);
        assert_eq!(confidence_weight(f64::NAN, 10.0), 0.5);
        assert_eq!(confidence_weight(0.0, 10.0), 0.5);
        assert!(close(confidence_weight(10.0, 10.0), 1.0));
        assert!(close(confidence_weight(-10.0, 10.0), 0.0));
        // ln(1 + 3) / ln(1 + 15) = 0.5, so 0.5 + 0.5 * 0.5.
        assert!(close(confidence_weight(3.0, 15.0), 0.75));
        assert!(close(confidence_weight(-3.0, 15.0), 0.25));
    }

    #[test]
    fn a_metric_is_normalized_with_its_direction() {
        assert!(close(normalize(5.0, 0.0, 10.0, true), 0.5));
        assert!(close(normalize(2.0, 0.0, 10.0, true), 0.2));
        assert!(close(normalize(2.0, 0.0, 10.0, false), 0.8));
        assert_eq!(normalize(3.0, 3.0, 3.0, true), 0.5);
        assert_eq!(normalize(99.0, 0.0, 10.0, true), 1.0);
    }

    #[test]
    fn the_median_is_the_middle_value() {
        assert_eq!(median(&mut []), None);
        assert_eq!(median(&mut [3.0, 1.0, 2.0]), Some(2.0));
        assert_eq!(median(&mut [4.0, 1.0, 3.0, 2.0]), Some(2.5));
    }

    #[test]
    fn services_with_no_results_are_ranked_by_reputation() {
        let data = ObjectiveData {
            coverages: vec![
                coverage("low", Some("t-low")),
                coverage("high", Some("t-high")),
                coverage("none", None),
            ],
            ..Default::default()
        };
        let ranked = rank_services(&data, &reps(&[("t-low", 10.0), ("t-high", 1000.0)]));
        let order: Vec<&str> = ranked.iter().map(|s| s.service_id.as_str()).collect();
        assert_eq!(order, ["high", "low", "none"]);
        assert!(close(ranked[0].score, 1.0));
        assert!(close(ranked[2].score, 0.5));
        assert!(ranked.iter().all(|s| s.performance.is_none() && s.direct));
    }

    #[test]
    fn no_reputation_at_all_gives_every_service_the_same_neutral_score() {
        let data = ObjectiveData {
            coverages: vec![coverage("a", None), coverage("b", None)],
            ..Default::default()
        };
        let ranked = rank_services(&data, &Reputations::default());
        assert!(ranked.iter().all(|s| s.score == 0.5));
        // Equal scores keep the order of the coverages.
        assert_eq!(ranked[0].service_id, "a");
    }

    #[test]
    fn the_better_measurement_wins_and_the_direction_counts() {
        let data = ObjectiveData {
            coverages: vec![coverage("slow", None), coverage("fast", None)],
            benchmarks: vec![benchmark("b", None, vec![metric("ms", false)])],
            results: vec![
                result("r1", "b", "slow", &[&[Some(100.0)]]),
                result("r2", "b", "fast", &[&[Some(10.0)]]),
            ],
        };
        let ranked = rank_services(&data, &Reputations::default());
        assert_eq!(ranked[0].service_id, "fast");
        assert_eq!(ranked[0].performance, Some(1.0));
        assert_eq!(ranked[1].performance, Some(0.0));
        // No reputation: W_S is 0.5, so 0.7 * 1 + 0.3 * 0.5.
        assert!(close(ranked[0].score, 0.85));
        assert!(close(ranked[1].score, 0.15));
        assert_eq!((ranked[0].benchmarks, ranked[0].results), (1, 1));
    }

    #[test]
    fn a_service_that_only_a_result_names_counts_and_is_not_direct() {
        let data = ObjectiveData {
            coverages: vec![coverage("covered", None)],
            benchmarks: vec![benchmark("b", None, vec![metric("x", true)])],
            results: vec![
                result("r1", "b", "covered", &[&[Some(1.0)]]),
                result("r2", "b", "found", &[&[Some(2.0)]]),
                result("r3", "b", "found", &[&[Some(2.0)]]),
            ],
        };
        let ranked = rank_services(&data, &Reputations::default());
        assert_eq!(ranked.len(), 2);
        let found = ranked.iter().find(|s| s.service_id == "found").unwrap();
        assert!(!found.direct);
        assert_eq!(found.results, 2);
        assert!(ranked.iter().find(|s| s.service_id == "covered").unwrap().direct);
    }

    #[test]
    fn a_result_of_a_benchmark_that_is_not_of_the_objective_is_ignored() {
        let data = ObjectiveData {
            coverages: vec![coverage("a", None)],
            benchmarks: vec![benchmark("b", None, vec![metric("x", true)])],
            results: vec![result("r", "other", "stranger", &[&[Some(1.0)]])],
        };
        let ranked = rank_services(&data, &Reputations::default());
        assert_eq!(ranked.len(), 1);
        assert_eq!(ranked[0].service_id, "a");
    }

    #[test]
    fn a_result_of_a_reputable_publisher_weighs_more() {
        // Two results for the service "s": one good from a trusted profile, one bad
        // from a profile with no reputation.
        let data = ObjectiveData {
            coverages: vec![coverage("s", None), coverage("anchor", None)],
            benchmarks: vec![benchmark("b", None, vec![metric("x", true)])],
            results: vec![
                result("good", "b", "s", &[&[Some(10.0)]]),
                result("bad", "b", "s", &[&[Some(0.0)]]),
                result("anchor", "b", "anchor", &[&[Some(5.0)]]),
            ],
        };
        let trusted = rank_services(&data, &reps(&[("tok-good", 1000.0)]));
        let flat = rank_services(&data, &Reputations::default());
        let performance = |r: &[ServiceScore]| {
            r.iter()
                .find(|s| s.service_id == "s")
                .unwrap()
                .performance
                .unwrap()
        };
        assert!(close(performance(&flat), 0.5));
        assert!(performance(&trusted) > 0.5);
    }

    #[test]
    fn a_benchmark_with_no_metrics_and_values_that_are_not_numbers_give_no_performance() {
        let data = ObjectiveData {
            coverages: vec![coverage("a", None)],
            benchmarks: vec![
                benchmark("empty", None, vec![]),
                benchmark("nan", None, vec![metric("x", true)]),
            ],
            results: vec![
                result("r1", "empty", "a", &[&[Some(1.0)]]),
                result("r2", "nan", "a", &[&[None], &[]]),
            ],
        };
        let ranked = rank_services(&data, &Reputations::default());
        assert_eq!(ranked[0].performance, None);
        assert_eq!(ranked[0].score, 0.5);
    }

    #[test]
    fn the_median_of_the_cases_is_used_and_a_missing_metric_is_skipped() {
        let data = ObjectiveData {
            coverages: vec![coverage("a", None), coverage("b", None)],
            benchmarks: vec![benchmark("b", None, vec![metric("m0", true), metric("m1", true)])],
            results: vec![
                // The median of m0 is 3. m1 has no value.
                result("r1", "b", "a", &[&[Some(1.0)], &[Some(3.0)], &[Some(100.0)]]),
                result("r2", "b", "b", &[&[Some(100.0), Some(4.0)]]),
            ],
        };
        let ranked = rank_services(&data, &Reputations::default());
        let a = ranked.iter().find(|s| s.service_id == "a").unwrap();
        // m0: range 1..100, median 3 gives 2/99; m1 is skipped. Weight 1/2.
        assert!(close(a.performance.unwrap(), 0.5 * (2.0 / 99.0)));
    }

    #[test]
    fn the_same_service_in_two_coverages_is_listed_once() {
        let data = ObjectiveData {
            coverages: vec![coverage("s", Some("t1")), coverage("s", Some("t2"))],
            ..Default::default()
        };
        let ranked = rank_services(&data, &reps(&[("t1", 1.0), ("t2", 100.0)]));
        assert_eq!(ranked.len(), 1);
        // The first coverage wins.
        assert_eq!(ranked[0].reputation, 1.0);
    }
}
