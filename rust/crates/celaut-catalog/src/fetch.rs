//! Read the catalog from the explorer. The crate makes no HTTP call: the app gives an
//! [`Explorer`] (`wallet-ffi` does, with reqwest) and this module asks it for the boxes
//! and the reputations.
//!
//! The reads are bounded: an objective costs one request for its coverages, one for its
//! benchmarks, one for the results of each benchmark, and at most
//! [`MAX_REPUTATION_TOKENS`] for the reputation of the publishers.

use std::collections::{HashMap, HashSet};
use std::future::Future;

use futures::stream::{self, StreamExt};
use serde_json::Value;

use crate::parse::{
    parse_benchmark, parse_coverage, parse_result, parse_objective, subject, BenchResult, Benchmark,
    Coverage, Objective,
};
use crate::rank::{rank_services, Reputations, ServiceScore, ObjectiveData};
use crate::TypeIds;

/// How many requests run at the same time.
pub const MAX_PARALLEL: usize = 4;

/// The most reputation tokens that one objective reads. A token over the limit has no
/// reputation (0) in the ranking.
pub const MAX_REPUTATION_TOKENS: usize = 64;

/// Why the catalog could not be read.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum CatalogError {
    /// The explorer did not answer, or its answer is not usable.
    #[error("the explorer did not answer: {0}")]
    Explorer(String),
    /// The objective id is not 64 hexadecimal characters.
    #[error("the objective id is not 64 hexadecimal characters")]
    BadObjectiveId,
    /// A type NFT is not 64 hexadecimal characters. It names the kind of the box.
    #[error("the {0} type id is not 64 hexadecimal characters")]
    BadTypeId(String),
}

/// The explorer of Ergo.
pub trait Explorer: Sync {
    /// Every unspent box of the reputation-system contract that has `type_nft` in R4
    /// and, if there is a `subject`, that id in R5. All the pages.
    fn boxes(
        &self,
        type_nft: &str,
        subject: Option<&str>,
    ) -> impl Future<Output = Result<Vec<Value>, CatalogError>> + Send;

    /// The reputation of a profile: the sum of the values, in nanoERG, of the unspent
    /// boxes that hold `token_id`.
    fn token_value(&self, token_id: &str) -> impl Future<Output = Result<f64, CatalogError>> + Send;
}

/// The objectives of the catalog, in the order of the explorer.
///
/// With an empty objective type in `types`, the catalog has no objective: the result is empty
/// and there is no request.
pub async fn load_objectives<E: Explorer>(
    explorer: &E,
    types: &TypeIds,
) -> Result<Vec<Objective>, CatalogError> {
    let types = types.normalized()?;
    if types.objective.is_empty() {
        return Ok(Vec::new());
    }
    let boxes = explorer.boxes(&types.objective, None).await?;
    let mut seen = HashSet::new();
    Ok(boxes
        .iter()
        .filter_map(parse_objective)
        .filter(|s| seen.insert(s.box_id.clone()))
        .collect())
}

/// The services that publishers declared for each objective (the coverage boxes), by the id of
/// the objective, each service once, in the order of the explorer. One query for the whole
/// catalog, not one for each objective. A service that is only in the results of a benchmark
/// is not here: [`load_objective_services`] reads those for one objective.
pub async fn load_declared_services<E: Explorer>(
    explorer: &E,
    types: &TypeIds,
) -> Result<HashMap<String, Vec<String>>, CatalogError> {
    let types = types.normalized()?;
    let mut services: HashMap<String, Vec<String>> = HashMap::new();
    if types.objective.is_empty() {
        return Ok(services);
    }
    for b in explorer.boxes(&types.coverage, None).await? {
        let (Some(objective), Some(coverage)) = (subject(&b), parse_coverage(&b)) else {
            continue;
        };
        let id = coverage.service_id.to_ascii_lowercase();
        let list = services.entry(objective).or_default();
        if !list.contains(&id) {
            list.push(id);
        }
    }
    Ok(services)
}

/// The reputation of the publishers of `objectives` (their profile tokens). Bounded as
/// [`load_reputations`]: a token over [`MAX_REPUTATION_TOKENS`], or one that the explorer
/// does not answer for, is left out.
pub async fn load_publisher_reputations<E: Explorer>(explorer: &E, objectives: &[Objective]) -> Reputations {
    let mut tokens: Vec<String> = Vec::new();
    let mut seen = HashSet::new();
    for token in objectives.iter().filter_map(|s| s.profile.as_ref()) {
        if tokens.len() < MAX_REPUTATION_TOKENS && seen.insert(token.clone()) {
            tokens.push(token.clone());
        }
    }
    token_values(explorer, tokens).await
}

/// The coverages, the benchmarks and the results of an objective.
pub async fn load_objective_data<E: Explorer>(
    explorer: &E,
    types: &TypeIds,
    objective_box_id: &str,
) -> Result<ObjectiveData, CatalogError> {
    let types = types.normalized()?;
    let id = objective_id(objective_box_id)?;
    let coverages: Vec<Coverage> = explorer
        .boxes(&types.coverage, Some(&id))
        .await?
        .iter()
        .filter_map(parse_coverage)
        .collect();
    let benchmarks: Vec<Benchmark> = explorer
        .boxes(&types.benchmark, Some(&id))
        .await?
        .iter()
        .filter_map(parse_benchmark)
        .filter(|b| b.objective_box_id == id)
        .collect();
    // Owned ids, not references: a closure over `&Benchmark` makes the future fail the
    // `Send` check of flutter_rust_bridge ("implementation of `FnOnce` is not general
    // enough").
    let ids: Vec<String> = benchmarks.iter().map(|b| b.id.clone()).collect();
    let result_type = types.result.as_str();
    let per_benchmark: Vec<Result<Vec<Value>, CatalogError>> = stream::iter(ids)
        .map(|id| async move { explorer.boxes(result_type, Some(&id)).await })
        .buffered(MAX_PARALLEL)
        .collect()
        .await;
    let mut results: Vec<BenchResult> = Vec::new();
    for boxes in per_benchmark {
        results.extend(boxes?.iter().filter_map(parse_result));
    }
    Ok(ObjectiveData {
        coverages,
        benchmarks,
        results,
    })
}

/// The reputation of the publishers in `data`. A token that the explorer does not
/// answer for, and a token over [`MAX_REPUTATION_TOKENS`], is left out: it has 0.
pub async fn load_reputations<E: Explorer>(explorer: &E, data: &ObjectiveData) -> Reputations {
    let mut tokens: Vec<String> = Vec::new();
    let mut seen = HashSet::new();
    let profiles = data
        .coverages
        .iter()
        .map(|c| &c.profile)
        .chain(data.benchmarks.iter().map(|b| &b.profile))
        .chain(data.results.iter().map(|r| &r.profile));
    for token in profiles.flatten() {
        if tokens.len() < MAX_REPUTATION_TOKENS && seen.insert(token.clone()) {
            tokens.push(token.clone());
        }
    }
    token_values(explorer, tokens).await
}

/// The value of each token, [`MAX_PARALLEL`] at a time. A token that fails is left out.
async fn token_values<E: Explorer>(explorer: &E, tokens: Vec<String>) -> Reputations {
    let values: Vec<(String, Result<f64, CatalogError>)> = stream::iter(tokens)
        .map(|token| async move {
            let value = explorer.token_value(&token).await;
            (token, value)
        })
        .buffer_unordered(MAX_PARALLEL)
        .collect()
        .await;
    Reputations(
        values
            .into_iter()
            .filter_map(|(token, value)| Some((token, value.ok()?)))
            .collect(),
    )
}

/// The services of an objective with their scores, best first.
pub async fn load_objective_services<E: Explorer>(
    explorer: &E,
    types: &TypeIds,
    objective_box_id: &str,
) -> Result<Vec<ServiceScore>, CatalogError> {
    let data = load_objective_data(explorer, types, objective_box_id).await?;
    let reputations = load_reputations(explorer, &data).await;
    Ok(rank_services(&data, &reputations))
}

fn objective_id(id: &str) -> Result<String, CatalogError> {
    let id = id.trim().to_ascii_lowercase();
    if id.len() == 64 && id.bytes().all(|b| b.is_ascii_hexdigit()) {
        Ok(id)
    } else {
        Err(CatalogError::BadObjectiveId)
    }
}
