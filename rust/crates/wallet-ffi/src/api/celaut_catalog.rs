//! The objective catalog for the app (milestone M4, `docs/celaut/catalog.md`): the objectives
//! that publishers put on Ergo, and the services of an objective, best first.
//!
//! The explorer is fixed to the default of nodo (`NODO_DEFAULT_EXPLORER`), as for the
//! deposits. The ranking is in the `celaut-catalog` crate; this module asks the explorer
//! and gives the app plain types.

use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

use celaut_catalog::fetch::{
    load_declared_services, load_publisher_reputations, load_objective_services, load_objectives,
    CatalogError, Explorer,
};
use celaut_catalog::parse::Objective;
use celaut_catalog::rank::Reputations;
use celaut_catalog::{TypeIds, ERGO_TREE_TEMPLATE_HASH};
use celaut_client::deposit::NODO_DEFAULT_EXPLORER;
use serde_json::{json, Value};

use super::celaut::{CelautError, CelautErrorKind};

/// How long the app waits for one request to the explorer.
const EXPLORER_TIMEOUT: Duration = Duration::from_secs(10);
/// How many times a request is tried. The explorer sometimes does not answer, or says
/// 429 or 5xx, and the next try works.
const ATTEMPTS: u32 = 3;
/// The pause before the second try. The third waits twice as long.
const RETRY_PAUSE: Duration = if cfg!(test) {
    Duration::from_millis(1)
} else {
    Duration::from_millis(600)
};
/// The boxes that one page of the explorer has at most.
const PAGE_SIZE: usize = 100;
/// The most pages that one query reads: 5000 boxes.
const MAX_BOX_PAGES: usize = 50;
/// The most pages that one reputation reads: 2000 boxes.
const MAX_TOKEN_PAGES: usize = 20;
/// How long the app keeps the reputation of a token.
const REPUTATION_TTL: Duration = Duration::from_secs(300);
/// The longest prose that the list of objectives shows, in characters.
const PROSE_CHARS: usize = 200;

/// The reputation of the tokens that were read lately, so that the list of the services
/// of an objective, and then of another one, do not ask for the same publisher again.
static REPUTATIONS: LazyLock<Mutex<HashMap<String, (Instant, f64)>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// How long a list of the catalog is used again before the app asks the explorer. The
/// catalog changes on chain, a few times a day at most; the explorer can take seconds.
const CATALOG_TTL: Duration = Duration::from_secs(300);

/// The last answers of the catalog, by key. A fresh one is given at once. When the explorer
/// fails, the last answer is given again, also an old one: an old list is more useful than
/// an error. Only a key with no answer at all gives the error.
struct CatalogCache<K, V> {
    entries: LazyLock<Mutex<HashMap<K, (Instant, V)>>>,
}

impl<K: std::hash::Hash + Eq + Clone, V: Clone> CatalogCache<K, V> {
    const fn new() -> Self {
        CatalogCache {
            entries: LazyLock::new(|| Mutex::new(HashMap::new())),
        }
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<K, (Instant, V)>> {
        self.entries.lock().unwrap_or_else(|e| e.into_inner())
    }

    fn fresh(&self, key: &K) -> Option<V> {
        let entries = self.lock();
        let (at, value) = entries.get(key)?;
        (at.elapsed() < CATALOG_TTL).then(|| value.clone())
    }

    /// Keep a new answer and give it; on an error, give the last answer if there is one.
    fn settle(&self, key: K, loaded: Result<V, CelautError>) -> Result<V, CelautError> {
        let mut entries = self.lock();
        match loaded {
            Ok(value) => {
                entries.insert(key, (Instant::now(), value.clone()));
                Ok(value)
            }
            Err(e) => match entries.get(&key) {
                Some((_, last)) => Ok(last.clone()),
                None => Err(e),
            },
        }
    }
}

static OBJECTIVES: CatalogCache<CatalogTypeIds, Vec<ObjectiveView>> = CatalogCache::new();
static SERVICES: CatalogCache<(CatalogTypeIds, String), Vec<ObjectiveServiceView>> = CatalogCache::new();

/// The type NFTs of the boxes of the registry. The user sets them in the settings of the app.
/// The objective type has no default value: it is empty, and then the catalog is empty.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CatalogTypeIds {
    /// The type NFT of an objective box: 64 hexadecimal characters, or empty.
    pub objective: String,
    pub coverage: String,
    pub benchmark: String,
    pub result: String,
}

impl From<CatalogTypeIds> for TypeIds {
    fn from(t: CatalogTypeIds) -> Self {
        TypeIds {
            objective: t.objective,
            coverage: t.coverage,
            benchmark: t.benchmark,
            result: t.result,
        }
    }
}

impl From<TypeIds> for CatalogTypeIds {
    fn from(t: TypeIds) -> Self {
        CatalogTypeIds {
            objective: t.objective,
            coverage: t.coverage,
            benchmark: t.benchmark,
            result: t.result,
        }
    }
}

/// The default type NFTs: the objective is empty, the other three have the ids of the
/// registry.
#[flutter_rust_bridge::frb(sync)]
pub fn celaut_default_catalog_type_ids() -> CatalogTypeIds {
    TypeIds::default().into()
}

/// An objective that the user can pick.
#[derive(Debug, Clone, PartialEq)]
pub struct ObjectiveView {
    /// The id of the objective: its box id on Ergo.
    pub box_id: String,
    pub name: String,
    /// The start of the text that explains the objective.
    pub prose: String,
    pub tags: Vec<String>,
    /// The field of the objective, as its publisher wrote it ("finance", "nlp"...); empty if
    /// none. The app groups the objectives by it.
    pub domain: String,
    /// The height of the block that has the objective box; 0 if unknown. The store shows the
    /// newest objectives by it.
    pub height: u32,
    /// The services that publishers declared for the objective (its coverage boxes), each once,
    /// in lower case. Empty if there is none, or if the explorer did not answer. A service
    /// that is only in the results of a benchmark is not here.
    pub service_ids: Vec<String>,
    /// The reputation of the publisher of the objective: the value in nanoERG of the boxes that
    /// hold its profile token. 0 if unknown.
    pub publisher_reputation: f64,
}

/// A service that covers an objective.
#[derive(Debug, Clone, PartialEq)]
pub struct ObjectiveServiceView {
    /// The id of the service: 64 hexadecimal characters.
    pub service_id: String,
    /// The score of the service in the objective, from 0 to 1. The best has the highest.
    pub score: f64,
    /// True if a publisher declared that the service covers the objective. False if the
    /// service is only in the results of a benchmark of the objective.
    pub direct: bool,
}

/// The objectives of the catalog, in the order of the explorer, with what the store sorts
/// them by: the height of the box, the services that publishers declared, and the
/// reputation of the publisher. These cost one more query and one request for each
/// publisher, not one for each objective.
#[flutter_rust_bridge::frb]
///
/// With an empty objective type in `types`, the list is empty and the app asks nothing.
pub async fn celaut_objectives(types: CatalogTypeIds) -> Result<Vec<ObjectiveView>, CelautError> {
    let key = types.clone();
    let types: TypeIds = types.into();
    if types.objective.trim().is_empty() {
        return Ok(Vec::new());
    }
    if let Some(fresh) = OBJECTIVES.fresh(&key) {
        return Ok(fresh);
    }
    let explorer = HttpExplorer::new(NODO_DEFAULT_EXPLORER);
    let objectives = match load_objectives(&explorer, &types).await {
        Ok(objectives) => objectives,
        Err(e) => return OBJECTIVES.settle(key, Err(error_of(e))),
    };
    let declared = load_declared_services(&explorer, &types).await;
    let reputations = load_publisher_reputations(&explorer, &objectives).await;
    let views = objective_views(objectives, declared.as_ref().ok(), &reputations);
    match declared {
        Ok(_) => OBJECTIVES.settle(key, Ok(views)),
        // The objectives are still listed, but with no services the store has no "featured"
        // and no "popular". The list is not kept, so the next read asks again; a full list
        // from before is better.
        Err(e) => OBJECTIVES.settle(key, Err(error_of(e))).or(Ok(views)),
    }
}

/// The objectives for the app. With no `declared` (the explorer did not answer), every objective
/// has no service.
fn objective_views(
    objectives: Vec<Objective>,
    declared: Option<&HashMap<String, Vec<String>>>,
    reputations: &Reputations,
) -> Vec<ObjectiveView> {
    objectives
        .into_iter()
        .map(|s| ObjectiveView {
            service_ids: declared
                .and_then(|d| d.get(&s.box_id.to_ascii_lowercase()))
                .cloned()
                .unwrap_or_default(),
            publisher_reputation: s
                .profile
                .as_ref()
                .and_then(|token| reputations.0.get(token))
                .copied()
                .filter(|r| r.is_finite())
                .unwrap_or(0.0),
            box_id: s.box_id,
            name: s.name,
            prose: short(&s.prose),
            tags: s.tags,
            domain: s.domain,
            height: s.height,
        })
        .collect()
}

/// The services of an objective, best first. The score follows `docs/celaut/catalog.md`: the
/// measured performance of the service in the benchmarks of the objective, and the
/// reputation of its publisher, weighted by the reputation of who published each result.
#[flutter_rust_bridge::frb]
pub async fn celaut_objective_services(
    types: CatalogTypeIds,
    objective_box_id: String,
) -> Result<Vec<ObjectiveServiceView>, CelautError> {
    let key = (types.clone(), objective_box_id);
    if let Some(fresh) = SERVICES.fresh(&key) {
        return Ok(fresh);
    }
    let explorer = HttpExplorer::new(NODO_DEFAULT_EXPLORER);
    let ranked = match load_objective_services(&explorer, &types.into(), &key.1).await {
        Ok(ranked) => ranked,
        Err(e) => return SERVICES.settle(key, Err(error_of(e))),
    };
    let views: Vec<ObjectiveServiceView> = ranked
        .into_iter()
        .map(|s| ObjectiveServiceView {
            service_id: s.service_id,
            score: s.score,
            direct: s.direct,
        })
        .collect();
    SERVICES.settle(key, Ok(views))
}

fn error_of(e: CatalogError) -> CelautError {
    let kind = match e {
        CatalogError::Explorer(_) => CelautErrorKind::Unreachable,
        CatalogError::BadObjectiveId | CatalogError::BadTypeId(_) => CelautErrorKind::InvalidInput,
    };
    CelautError {
        kind,
        message: e.to_string(),
    }
}

/// The first [`PROSE_CHARS`] characters of `text`, with "…" if it is longer.
fn short(text: &str) -> String {
    let text = text.trim();
    match text.char_indices().nth(PROSE_CHARS) {
        Some((end, _)) => format!("{}…", text[..end].trim_end()),
        None => text.to_string(),
    }
}

/// The explorer of Ergo over HTTP.
struct HttpExplorer {
    base: String,
}

impl HttpExplorer {
    fn new(base: &str) -> Self {
        Self {
            base: base.trim().trim_end_matches('/').to_string(),
        }
    }

    fn client() -> Result<reqwest::Client, CatalogError> {
        wallet_net::http::client_builder()
            .timeout(EXPLORER_TIMEOUT)
            .build()
            .map_err(describe)
    }
}

/// The error with its causes: "error sending request" alone does not say why.
fn describe(error: impl std::error::Error) -> CatalogError {
    let mut text = error.to_string();
    let mut source = error.source();
    while let Some(cause) = source {
        text.push_str(": ");
        text.push_str(&cause.to_string());
        source = cause.source();
    }
    CatalogError::Explorer(text)
}

/// One request, tried up to [`ATTEMPTS`] times. A transport error, 429 and 5xx are tried
/// again; any other status is the answer.
async fn request(
    client: &reqwest::Client,
    build: impl Fn(&reqwest::Client) -> reqwest::RequestBuilder,
) -> Result<Value, CatalogError> {
    let mut last = CatalogError::Explorer("no try".into());
    for attempt in 0..ATTEMPTS {
        if attempt > 0 {
            tokio::time::sleep(RETRY_PAUSE * attempt).await;
        }
        match build(client).send().await {
            Err(e) => last = describe(e),
            Ok(response) if response.status().is_success() => {
                return response.json::<Value>().await.map_err(describe);
            }
            Ok(response) => {
                let status = response.status();
                last = CatalogError::Explorer(format!("HTTP {status}"));
                if status.as_u16() != 429 && !status.is_server_error() {
                    return Err(last);
                }
            }
        }
    }
    Err(last)
}

fn items(page: &Value) -> Vec<Value> {
    page.get("items")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

impl Explorer for HttpExplorer {
    async fn boxes(
        &self,
        type_nft: &str,
        subject: Option<&str>,
    ) -> Result<Vec<Value>, CatalogError> {
        let client = Self::client()?;
        let mut registers = serde_json::Map::new();
        registers.insert("R4".into(), json!(type_nft));
        if let Some(subject) = subject {
            registers.insert("R5".into(), json!(subject));
        }
        let body = json!({
            "ergoTreeTemplateHash": ERGO_TREE_TEMPLATE_HASH,
            "registers": registers,
            "assets": [],
        });
        let mut boxes = Vec::new();
        for page in 0..MAX_BOX_PAGES {
            let url = format!(
                "{}/api/v1/boxes/unspent/search?offset={}&limit={PAGE_SIZE}",
                self.base,
                page * PAGE_SIZE
            );
            let page_items = items(&request(&client, |c| c.post(&url).json(&body)).await?);
            let last = page_items.len() < PAGE_SIZE;
            boxes.extend(page_items);
            if last {
                break;
            }
        }
        Ok(boxes)
    }

    async fn token_value(&self, token_id: &str) -> Result<f64, CatalogError> {
        let cached = REPUTATIONS
            .lock()
            .ok()
            .and_then(|c| c.get(token_id).copied())
            .filter(|(at, _)| at.elapsed() < REPUTATION_TTL);
        if let Some((_, value)) = cached {
            return Ok(value);
        }
        let client = Self::client()?;
        let mut total = 0.0_f64;
        for page in 0..MAX_TOKEN_PAGES {
            let url = format!(
                "{}/api/v1/boxes/unspent/byTokenId/{token_id}?offset={}&limit={PAGE_SIZE}",
                self.base,
                page * PAGE_SIZE
            );
            let page_items = items(&request(&client, |c| c.get(&url)).await?);
            total += page_items
                .iter()
                .filter_map(|b| b.get("value").and_then(Value::as_u64))
                .map(|v| v as f64)
                .sum::<f64>();
            if page_items.len() < PAGE_SIZE {
                break;
            }
        }
        if let Ok(mut cache) = REPUTATIONS.lock() {
            cache.insert(token_id.to_string(), (Instant::now(), total));
        }
        Ok(total)
    }
}

#[cfg(test)]
mod cache_tests {
    use super::*;

    fn error() -> CelautError {
        CelautError {
            kind: super::super::celaut::CelautErrorKind::Unreachable,
            message: "the explorer did not answer".into(),
        }
    }

    #[test]
    fn a_fresh_answer_is_used_again_and_an_error_gives_the_last_answer() {
        let cache: CatalogCache<String, Vec<u32>> = CatalogCache::new();
        assert_eq!(cache.fresh(&"a".into()), None);
        // No answer yet: the error goes to the caller.
        assert!(cache.settle("a".into(), Err(error())).is_err());
        assert_eq!(cache.settle("a".into(), Ok(vec![1, 2])).unwrap(), vec![1, 2]);
        assert_eq!(cache.fresh(&"a".into()), Some(vec![1, 2]));
        // The explorer fails later: the last list is given, not the error.
        assert_eq!(cache.settle("a".into(), Err(error())).unwrap(), vec![1, 2]);
        // Another key has its own answer.
        assert_eq!(cache.fresh(&"b".into()), None);
        assert!(cache.settle("b".into(), Err(error())).is_err());
    }

    #[test]
    fn an_old_answer_is_not_fresh_but_still_helps_when_the_explorer_fails() {
        let cache: CatalogCache<(), Vec<u32>> = CatalogCache::new();
        let old = Instant::now() - CATALOG_TTL - Duration::from_secs(1);
        cache.lock().insert((), (old, vec![7]));
        assert_eq!(cache.fresh(&()), None);
        assert_eq!(cache.settle((), Err(error())).unwrap(), vec![7]);
        // A new answer replaces it and is fresh.
        cache.settle((), Ok(vec![8])).unwrap();
        assert_eq!(cache.fresh(&()), Some(vec![8]));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    /// A local HTTP server. `answer` gets the request line and the body, and returns the
    /// status and the JSON body.
    async fn serve<F>(answer: F) -> (String, Arc<AtomicUsize>)
    where
        F: Fn(&str, &str) -> (u16, String) + Send + Sync + 'static,
    {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        let calls = Arc::new(AtomicUsize::new(0));
        let counter = calls.clone();
        let answer = Arc::new(answer);
        tokio::spawn(async move {
            loop {
                let (mut socket, _) = listener.accept().await.unwrap();
                let (answer, counter) = (answer.clone(), counter.clone());
                tokio::spawn(async move {
                    let mut buf = Vec::new();
                    let mut chunk = [0u8; 4096];
                    let (head, body) = loop {
                        let n = socket.read(&mut chunk).await.unwrap_or(0);
                        if n == 0 {
                            return;
                        }
                        buf.extend_from_slice(&chunk[..n]);
                        let text = String::from_utf8_lossy(&buf).to_string();
                        if let Some(split) = text.find("\r\n\r\n") {
                            let head = text[..split].to_string();
                            let length = head
                                .lines()
                                .find_map(|l| {
                                    l.to_ascii_lowercase()
                                        .strip_prefix("content-length:")
                                        .map(|v| v.trim().parse::<usize>().unwrap_or(0))
                                })
                                .unwrap_or(0);
                            if text.len() >= split + 4 + length {
                                break (head, text[split + 4..split + 4 + length].to_string());
                            }
                        }
                    };
                    counter.fetch_add(1, Ordering::SeqCst);
                    let (status, reply) = answer(head.lines().next().unwrap_or(""), &body);
                    let response = format!(
                        "HTTP/1.1 {status} X\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{reply}",
                        reply.len()
                    );
                    let _ = socket.write_all(response.as_bytes()).await;
                });
            }
        });
        (base, calls)
    }

    fn boxes(count: usize) -> String {
        let items: Vec<Value> = (0..count).map(|i| json!({"boxId": format!("b{i}"), "value": 1000})).collect();
        json!({"items": items, "total": count}).to_string()
    }

    #[tokio::test]
    async fn the_search_posts_the_query_and_reads_every_page() {
        let (base, calls) = serve(|line, body| {
            assert!(line.starts_with("POST /api/v1/boxes/unspent/search?"), "{line}");
            let query: Value = serde_json::from_str(body).unwrap();
            assert_eq!(query["ergoTreeTemplateHash"], ERGO_TREE_TEMPLATE_HASH);
            assert_eq!(query["registers"]["R4"], "nft");
            assert_eq!(query["registers"]["R5"], "subject");
            assert_eq!(query["assets"], json!([]));
            if line.contains("offset=0&") {
                (200, boxes(PAGE_SIZE))
            } else if line.contains("offset=100&") {
                (200, boxes(PAGE_SIZE))
            } else {
                assert!(line.contains("offset=200&"), "{line}");
                (200, boxes(7))
            }
        })
        .await;
        let found = HttpExplorer::new(&base).boxes("nft", Some("subject")).await.unwrap();
        assert_eq!(found.len(), 207);
        assert_eq!(calls.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn a_search_with_no_subject_has_no_r5() {
        let (base, _) = serve(|_, body| {
            let query: Value = serde_json::from_str(body).unwrap();
            assert!(query["registers"].get("R5").is_none());
            (200, boxes(0))
        })
        .await;
        assert!(HttpExplorer::new(&base).boxes("nft", None).await.unwrap().is_empty());
    }

    #[tokio::test]
    async fn a_search_that_the_explorer_refuses_is_an_error() {
        let (base, calls) = serve(|_, _| (500, "{}".into())).await;
        let error = HttpExplorer::new(&base).boxes("nft", None).await.unwrap_err();
        assert!(error.to_string().contains("HTTP 500"), "{error}");
        assert_eq!(calls.load(Ordering::SeqCst), ATTEMPTS as usize);
        let (base, _) = serve(|_, _| (200, "not json".into())).await;
        assert!(HttpExplorer::new(&base).boxes("nft", None).await.is_err());
    }

    #[tokio::test]
    async fn a_request_that_fails_for_a_moment_is_tried_again() {
        let tries = Arc::new(AtomicUsize::new(0));
        let counter = tries.clone();
        let (base, _) = serve(move |_, _| match counter.fetch_add(1, Ordering::SeqCst) {
            0 => (429, "{}".into()),
            1 => (503, "{}".into()),
            _ => (200, boxes(3)),
        })
        .await;
        let found = HttpExplorer::new(&base).boxes("nft", None).await.unwrap();
        assert_eq!(found.len(), 3);
        assert_eq!(tries.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn a_refusal_of_the_query_is_not_tried_again() {
        let (base, calls) = serve(|_, _| (400, "{}".into())).await;
        let error = HttpExplorer::new(&base).boxes("nft", None).await.unwrap_err();
        assert!(error.to_string().contains("HTTP 400"), "{error}");
        assert_eq!(calls.load(Ordering::SeqCst), 1);
    }

    #[tokio::test]
    async fn a_search_stops_at_the_page_limit() {
        let (base, calls) = serve(|_, _| (200, boxes(PAGE_SIZE))).await;
        let found = HttpExplorer::new(&base).boxes("nft", None).await.unwrap();
        assert_eq!(calls.load(Ordering::SeqCst), MAX_BOX_PAGES);
        assert_eq!(found.len(), MAX_BOX_PAGES * PAGE_SIZE);
    }

    #[tokio::test]
    async fn the_reputation_is_the_sum_of_the_values_and_it_is_cached() {
        let token = "token-for-the-sum-test";
        let (base, calls) = serve(move |line, _| {
            assert!(
                line.starts_with(&format!("GET /api/v1/boxes/unspent/byTokenId/{token}?")),
                "{line}"
            );
            if line.contains("offset=0&") {
                (200, boxes(PAGE_SIZE))
            } else {
                (200, json!({"items": [{"value": 5}, {"value": "bad"}, {}]}).to_string())
            }
        })
        .await;
        let explorer = HttpExplorer::new(&base);
        let value = explorer.token_value(token).await.unwrap();
        assert_eq!(value, (PAGE_SIZE * 1000 + 5) as f64);
        assert_eq!(calls.load(Ordering::SeqCst), 2);
        // The second read does not ask again.
        assert_eq!(explorer.token_value(token).await.unwrap(), value);
        assert_eq!(calls.load(Ordering::SeqCst), 2);
    }

    #[tokio::test]
    async fn a_reputation_that_fails_is_not_cached() {
        let token = "token-for-the-failure-test";
        let (base, _) = serve(|_, _| (429, "{}".into())).await;
        assert!(HttpExplorer::new(&base).token_value(token).await.is_err());
        assert!(!REPUTATIONS.lock().unwrap().contains_key(token));
    }

    fn objective(id: &str, profile: Option<&str>) -> Objective {
        Objective {
            box_id: id.into(),
            profile: profile.map(Into::into),
            name: format!("objective {id}"),
            prose: " text ".into(),
            tags: vec!["t".into()],
            domain: "d".into(),
            extended_objective_boxes: vec![],
            height: 7,
        }
    }

    #[test]
    fn an_objective_view_has_its_services_and_the_reputation_of_its_publisher() {
        let declared = HashMap::from([("aa".to_string(), vec!["s1".to_string(), "s2".to_string()])]);
        let reputations = Reputations(HashMap::from([
            ("tok".to_string(), 3e9),
            ("nan".to_string(), f64::NAN),
        ]));
        let objectives = vec![
            objective("AA", Some("tok")),
            objective("bb", None),
            objective("cc", Some("other")),
            objective("dd", Some("nan")),
        ];
        let views = objective_views(objectives.clone(), Some(&declared), &reputations);
        assert_eq!(views[0].service_ids, ["s1", "s2"]);
        assert_eq!(views[0].publisher_reputation, 3e9);
        assert_eq!((views[0].height, views[0].prose.as_str()), (7, "text"));
        assert!(views[1].service_ids.is_empty());
        assert_eq!(views[1].publisher_reputation, 0.0);
        assert_eq!(views[2].publisher_reputation, 0.0);
        assert_eq!(views[3].publisher_reputation, 0.0);
        // No answer for the services: the objectives are there, with none.
        let views = objective_views(objectives, None, &reputations);
        assert_eq!(views.len(), 4);
        assert!(views.iter().all(|v| v.service_ids.is_empty()));
    }

    #[test]
    fn the_prose_is_cut_at_a_character_and_not_inside_one() {
        assert_eq!(short("  short  "), "short");
        let long = "á".repeat(PROSE_CHARS + 5);
        let cut = short(&long);
        assert_eq!(cut.chars().count(), PROSE_CHARS + 1);
        assert!(cut.ends_with('…'));
        assert_eq!(short(&"a".repeat(PROSE_CHARS)), "a".repeat(PROSE_CHARS));
    }

    #[test]
    fn the_errors_have_the_kinds_that_the_screen_knows() {
        assert_eq!(
            error_of(CatalogError::BadObjectiveId).kind,
            CelautErrorKind::InvalidInput
        );
        let e = error_of(CatalogError::Explorer("HTTP 500".into()));
        assert_eq!(e.kind, CelautErrorKind::Unreachable);
        assert!(e.message.contains("HTTP 500"));
    }

    #[tokio::test]
    async fn a_bad_objective_id_is_refused_without_a_request() {
        let types = celaut_default_catalog_type_ids();
        let error = celaut_objective_services(types, "not an id".into()).await.unwrap_err();
        assert_eq!(error.kind, CelautErrorKind::InvalidInput);
    }

    #[test]
    fn the_default_type_ids_have_no_objective() {
        let types = celaut_default_catalog_type_ids();
        assert_eq!(types.objective, "");
        assert_eq!(types.coverage, celaut_catalog::DEFAULT_COVERAGE_TYPE);
        assert_eq!(types.benchmark, celaut_catalog::DEFAULT_BENCHMARK_TYPE);
        assert_eq!(types.result, celaut_catalog::DEFAULT_RESULT_TYPE);
    }

    #[tokio::test]
    async fn with_no_objective_type_id_the_list_is_empty_without_a_request() {
        let objectives = celaut_objectives(celaut_default_catalog_type_ids()).await.unwrap();
        assert!(objectives.is_empty());
    }

    #[tokio::test]
    async fn a_bad_type_id_is_refused_without_a_request() {
        let types = CatalogTypeIds {
            objective: "abc".into(),
            ..celaut_default_catalog_type_ids()
        };
        let error = celaut_objectives(types).await.unwrap_err();
        assert_eq!(error.kind, CelautErrorKind::InvalidInput);
        assert!(error.message.contains("objective"));
    }

    /// Ask the real explorer of Ergo. The objective type has no default: set it in
    /// `CELAUT_OBJECTIVE_TYPE`. Run it with
    /// `CELAUT_OBJECTIVE_TYPE=<64 hex> cargo test -p wallet-ffi the_real_catalog -- --ignored --nocapture`.
    #[tokio::test]
    #[ignore = "asks the real explorer of Ergo"]
    async fn the_real_catalog_has_objectives_with_ranked_services() {
        let types = CatalogTypeIds {
            objective: std::env::var("CELAUT_OBJECTIVE_TYPE").expect("set CELAUT_OBJECTIVE_TYPE"),
            ..celaut_default_catalog_type_ids()
        };
        let objectives = celaut_objectives(types.clone()).await.unwrap();
        assert!(!objectives.is_empty());
        for objective in &objectives {
            let services = celaut_objective_services(types.clone(), objective.box_id.clone()).await.unwrap();
            println!("{} ({}): {} services", objective.name, &objective.box_id[..8], services.len());
            for s in &services {
                println!("  {} {:.4} direct={}", &s.service_id[..8], s.score, s.direct);
            }
            assert!(services.windows(2).all(|w| w[0].score >= w[1].score));
            assert!(services.iter().all(|s| (0.0..=1.0).contains(&s.score)));
        }
    }
}
