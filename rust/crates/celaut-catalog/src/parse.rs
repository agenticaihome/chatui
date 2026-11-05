//! The boxes of the catalog, as the explorer gives them (`docs/celaut/catalog.md`,
//! "Register layout"):
//!
//! | Register | Content |
//! |---|---|
//! | R4 | Type NFT id |
//! | R5 | The subject: the id of the skill or of the benchmark that the box is about |
//! | R9 | UTF-8 JSON (`renderedValue` is its hex) |
//!
//! `assets[0]` is the reputation token of the publisher: the profile of the box.
//!
//! Every parser takes the JSON of one box and returns `None` for a box that it cannot
//! use. A field that is missing or has another type gets its default, as in the
//! dApp of the catalog.

use serde_json::Value;

/// A skill: what the user picks.
#[derive(Debug, Clone, PartialEq)]
pub struct Skill {
    pub box_id: String,
    /// The reputation token of the publisher.
    pub profile: Option<String>,
    pub name: String,
    pub prose: String,
    pub tags: Vec<String>,
    pub domain: String,
    /// The skills that this one extends. Not used by the ranking yet.
    pub extended_skill_boxes: Vec<String>,
    /// The height of the block that has the box ([`height`]); 0 if the explorer gave none.
    pub height: u32,
}

/// A service that a publisher says covers a skill.
#[derive(Debug, Clone, PartialEq)]
pub struct Coverage {
    pub box_id: String,
    pub profile: Option<String>,
    /// The id of the service: 64 hexadecimal characters.
    pub service_id: String,
}

/// One metric of a benchmark.
#[derive(Debug, Clone, PartialEq)]
pub struct Metric {
    pub name: String,
    pub higher_is_better: bool,
}

/// A benchmark of a skill.
#[derive(Debug, Clone, PartialEq)]
pub struct Benchmark {
    /// The box id.
    pub id: String,
    pub profile: Option<String>,
    pub skill_box_id: String,
    pub name: String,
    pub metrics: Vec<Metric>,
}

/// The metric values of one case of a result. A value that is not a number is `None`.
#[derive(Debug, Clone, PartialEq)]
pub struct Case {
    pub metrics_values: Vec<Option<f64>>,
}

/// What a service measured in a benchmark.
#[derive(Debug, Clone, PartialEq)]
pub struct BenchResult {
    /// The box id.
    pub id: String,
    pub profile: Option<String>,
    pub benchmark_id: String,
    pub service_id: String,
    pub cases: Vec<Case>,
}

fn register<'a>(b: &'a Value, name: &str) -> Option<&'a str> {
    b.get("additionalRegisters")?
        .get(name)?
        .get("renderedValue")?
        .as_str()
}

/// The R9 JSON of a box, if it is JSON.
fn content(b: &Value) -> Option<Value> {
    let bytes = hex::decode(register(b, "R9")?).ok()?;
    serde_json::from_slice(&bytes).ok()
}

/// The box id.
pub fn box_id(b: &Value) -> Option<String> {
    let id = b.get("boxId")?.as_str()?;
    (!id.is_empty()).then(|| id.to_string())
}

/// The reputation token of the publisher (`assets[0]`).
pub fn profile(b: &Value) -> Option<String> {
    let token = b.get("assets")?.get(0)?.get("tokenId")?.as_str()?;
    (!token.is_empty()).then(|| token.to_string())
}

/// The height of the block that has the box: `settlementHeight`, or `creationHeight` if the
/// explorer gave no settlement height. 0 if it gave neither.
pub fn height(b: &Value) -> u32 {
    ["settlementHeight", "creationHeight"]
        .iter()
        .find_map(|key| b.get(*key)?.as_u64())
        .and_then(|h| u32::try_from(h).ok())
        .unwrap_or(0)
}

/// The R5 register as a lowercase id, if it has one: the skill or the benchmark that the
/// box is about.
pub fn subject(b: &Value) -> Option<String> {
    let id = register(b, "R5")?;
    (!id.is_empty()).then(|| id.to_ascii_lowercase())
}

fn text(content: &Value, key: &str) -> String {
    content
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn texts(content: &Value, key: &str) -> Vec<String> {
    content
        .get(key)
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default()
}

/// A skill box. A box whose content is not JSON is still a skill, with no name.
pub fn parse_skill(b: &Value) -> Option<Skill> {
    let content = content(b).unwrap_or(Value::Null);
    let name = text(&content, "name");
    Some(Skill {
        box_id: box_id(b)?,
        profile: profile(b),
        name: if name.is_empty() {
            "Unnamed Skill".to_string()
        } else {
            name
        },
        prose: text(&content, "prose"),
        tags: texts(&content, "tags"),
        domain: text(&content, "domain"),
        extended_skill_boxes: texts(&content, "extended_skill_boxes"),
        height: height(b),
    })
}

/// A coverage box about a skill. A coverage with no service id, or one that is about a
/// benchmark (a runner, not a solution), is left out.
pub fn parse_coverage(b: &Value) -> Option<Coverage> {
    let content = content(b)?;
    let service_id = text(&content, "service_id");
    let runner = !text(&content, "benchmark_id").is_empty();
    if service_id.is_empty() || runner {
        return None;
    }
    Some(Coverage {
        box_id: box_id(b)?,
        profile: profile(b),
        service_id,
    })
}

fn metric(raw: &Value) -> Option<Metric> {
    match raw {
        Value::String(name) => Some(Metric {
            name: name.clone(),
            higher_is_better: true,
        }),
        Value::Object(_) => {
            let direction = raw.get("higherIsBetter").or_else(|| raw.get("higher_is_better"));
            Some(Metric {
                name: text(raw, "name"),
                higher_is_better: match direction {
                    Some(Value::Bool(b)) => *b,
                    Some(Value::Number(n)) => n.as_f64().is_some_and(|n| n != 0.0),
                    _ => true,
                },
            })
        }
        _ => None,
    }
}

/// A benchmark box.
pub fn parse_benchmark(b: &Value) -> Option<Benchmark> {
    let content = content(b)?;
    let skill_box_id = subject(b).or_else(|| Some(text(&content, "skill_box_id")).filter(|s| !s.is_empty()))?;
    let name = text(&content, "name");
    Some(Benchmark {
        id: box_id(b)?,
        profile: profile(b),
        skill_box_id,
        name: if name.is_empty() {
            "Unnamed Benchmark".to_string()
        } else {
            name
        },
        metrics: content
            .get("performance_metrics")
            .and_then(Value::as_array)
            .map(|items| items.iter().filter_map(metric).collect())
            .unwrap_or_default(),
    })
}

fn number(raw: &Value) -> Option<f64> {
    match raw {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.trim().parse().ok(),
        _ => None,
    }
    .filter(|n| n.is_finite())
}

/// A result box. A result with no service id is left out.
pub fn parse_result(b: &Value) -> Option<BenchResult> {
    let content = content(b)?;
    let service_id = text(&content, "service_id");
    if service_id.is_empty() {
        return None;
    }
    let benchmark_id = subject(b).or_else(|| Some(text(&content, "benchmark_id")).filter(|s| !s.is_empty()))?;
    let cases = content
        .get("data")
        .and_then(Value::as_array)
        .map(|cases| {
            cases
                .iter()
                .map(|case| Case {
                    metrics_values: case
                        .get("metrics_values")
                        .and_then(Value::as_array)
                        .map(|values| values.iter().map(number).collect())
                        .unwrap_or_default(),
                })
                .collect()
        })
        .unwrap_or_default();
    Some(BenchResult {
        id: box_id(b)?,
        profile: profile(b),
        benchmark_id,
        service_id,
        cases,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    /// A box of the explorer with these registers. `r9` is the JSON of R9.
    fn explorer_box(id: &str, token: Option<&str>, r5: Option<&str>, r9: Option<&str>) -> Value {
        let mut registers = serde_json::Map::new();
        if let Some(r5) = r5 {
            registers.insert("R5".into(), json!({"renderedValue": r5}));
        }
        if let Some(r9) = r9 {
            registers.insert("R9".into(), json!({"renderedValue": hex::encode(r9)}));
        }
        json!({
            "boxId": id,
            "value": 1000000,
            "assets": token.map(|t| vec![json!({"tokenId": t, "amount": 1})]).unwrap_or_default(),
            "additionalRegisters": registers,
        })
    }

    #[test]
    fn a_skill_has_its_name_tags_and_publisher() {
        let b = explorer_box(
            "aa",
            Some("tok"),
            Some(""),
            Some(r#"{"name":"Sat","prose":"p","tags":["a",5,"b"],"domain":"d","extended_skill_boxes":["x"]}"#),
        );
        let s = parse_skill(&b).unwrap();
        assert_eq!(s.box_id, "aa");
        assert_eq!(s.profile.as_deref(), Some("tok"));
        assert_eq!((s.name.as_str(), s.prose.as_str(), s.domain.as_str()), ("Sat", "p", "d"));
        assert_eq!(s.tags, ["a", "b"]);
        assert_eq!(s.extended_skill_boxes, ["x"]);
    }

    #[test]
    fn the_height_of_a_box_is_its_settlement_then_its_creation() {
        let mut b = explorer_box("aa", None, None, None);
        assert_eq!(height(&b), 0);
        b["creationHeight"] = json!(1816212);
        assert_eq!(height(&b), 1816212);
        assert_eq!(parse_skill(&b).unwrap().height, 1816212);
        b["settlementHeight"] = json!(1816213);
        assert_eq!(height(&b), 1816213);
        b["settlementHeight"] = json!("x");
        assert_eq!(height(&b), 1816212);
        b["creationHeight"] = json!(u64::MAX);
        assert_eq!(height(&b), 0);
    }

    #[test]
    fn a_skill_whose_content_is_not_json_has_no_name_but_is_kept() {
        let b = explorer_box("aa", None, None, Some("plain text"));
        let s = parse_skill(&b).unwrap();
        assert_eq!(s.name, "Unnamed Skill");
        assert_eq!(s.profile, None);
        let b = explorer_box("bb", None, None, None);
        assert_eq!(parse_skill(&b).unwrap().name, "Unnamed Skill");
    }

    #[test]
    fn a_box_with_no_id_or_not_a_box_is_left_out() {
        assert!(parse_skill(&json!({})).is_none());
        assert!(parse_skill(&json!("text")).is_none());
        assert!(parse_skill(&json!({"boxId": ""})).is_none());
        assert!(parse_coverage(&Value::Null).is_none());
        assert!(parse_benchmark(&Value::Null).is_none());
        assert!(parse_result(&Value::Null).is_none());
    }

    #[test]
    fn a_coverage_needs_a_service_and_is_not_a_runner() {
        let ok = explorer_box("c", Some("t"), Some("ab"), Some(r#"{"service_id":"s1"}"#));
        assert_eq!(parse_coverage(&ok).unwrap().service_id, "s1");
        let none = explorer_box("c", None, None, Some(r#"{"service_id":""}"#));
        assert!(parse_coverage(&none).is_none());
        let no_json = explorer_box("c", None, None, Some("nope"));
        assert!(parse_coverage(&no_json).is_none());
        let runner = explorer_box("c", None, None, Some(r#"{"service_id":"s","benchmark_id":"b"}"#));
        assert!(parse_coverage(&runner).is_none());
    }

    #[test]
    fn a_benchmark_reads_metrics_in_every_shape() {
        let b = explorer_box(
            "bm",
            Some("t"),
            Some("ABCD"),
            Some(
                r#"{"name":"N","performance_metrics":[
                    "plain",
                    {"name":"snake","higher_is_better":false},
                    {"name":"camel","higherIsBetter":false},
                    {"name":"none"},
                    {"name":"num","higher_is_better":0},
                    7]}"#,
            ),
        );
        let bm = parse_benchmark(&b).unwrap();
        assert_eq!(bm.skill_box_id, "abcd");
        let metrics: Vec<(&str, bool)> = bm
            .metrics
            .iter()
            .map(|m| (m.name.as_str(), m.higher_is_better))
            .collect();
        assert_eq!(
            metrics,
            [("plain", true), ("snake", false), ("camel", false), ("none", true), ("num", false)]
        );
    }

    #[test]
    fn a_benchmark_takes_the_skill_from_r9_when_r5_is_empty() {
        let b = explorer_box("bm", None, Some(""), Some(r#"{"skill_box_id":"s9"}"#));
        assert_eq!(parse_benchmark(&b).unwrap().skill_box_id, "s9");
        let lost = explorer_box("bm", None, None, Some(r#"{"name":"x"}"#));
        assert!(parse_benchmark(&lost).is_none());
    }

    #[test]
    fn a_result_keeps_the_numbers_and_drops_the_rest() {
        let r = explorer_box(
            "r",
            Some("t"),
            Some("bench"),
            Some(
                r#"{"service_id":"s","data":[
                    {"case_meta":[1],"metrics_values":[1.5,"2",null,"x",true]},
                    {"metrics_values":"bad"},
                    5]}"#,
            ),
        );
        let result = parse_result(&r).unwrap();
        assert_eq!(result.benchmark_id, "bench");
        assert_eq!(result.service_id, "s");
        assert_eq!(result.cases.len(), 3);
        assert_eq!(
            result.cases[0].metrics_values,
            [Some(1.5), Some(2.0), None, None, None]
        );
        assert!(result.cases[1].metrics_values.is_empty());
        assert!(result.cases[2].metrics_values.is_empty());
    }

    #[test]
    fn a_result_with_no_service_or_no_benchmark_is_left_out() {
        let no_service = explorer_box("r", None, Some("b"), Some(r#"{"data":[]}"#));
        assert!(parse_result(&no_service).is_none());
        let no_benchmark = explorer_box("r", None, None, Some(r#"{"service_id":"s"}"#));
        assert!(parse_result(&no_benchmark).is_none());
        let from_r9 = explorer_box("r", None, None, Some(r#"{"service_id":"s","benchmark_id":"b9"}"#));
        assert_eq!(parse_result(&from_r9).unwrap().benchmark_id, "b9");
    }

    #[test]
    fn bad_hex_in_r9_is_not_a_panic() {
        let mut b = explorer_box("c", None, Some("x"), None);
        b["additionalRegisters"]["R9"] = json!({"renderedValue": "zz-not-hex"});
        assert!(parse_coverage(&b).is_none());
        assert_eq!(parse_skill(&b).unwrap().name, "Unnamed Skill");
    }
}
