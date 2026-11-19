//! The objective catalog of Celaut (`docs/celaut/catalog.md`): objectives, the services that
//! cover them, and the ranking of those services.
//!
//! The data is on Ergo, in "opinion boxes" of the reputation-system contract
//! (celaut-project/registry publishes and reads them):
//!
//! - [`parse`] turns the JSON of a box of the explorer into a [`parse::Objective`],
//!   [`parse::Coverage`], [`parse::Benchmark`] or [`parse::BenchResult`]. A box that cannot
//!   be read is left out: it is never an error.
//! - [`rank`] gives the services of an objective a score, as `registry:src/lib/scoreGlobal.ts`
//!   does.
//! - [`fetch`] asks an [`fetch::Explorer`] for the boxes and the reputations, and puts
//!   the two together. The crate makes no HTTP call itself: the app implements
//!   [`fetch::Explorer`].

pub mod fetch;
pub mod parse;
pub mod rank;

/// The fixed template hash of the reputation-system contract
/// (`docs/celaut/catalog.md`).
pub const ERGO_TREE_TEMPLATE_HASH: &str =
    "e84b95d84a30df33aa258fe2b9d24c3e75e27a67c6453983c19703029112d147";

/// The default type NFT of a coverage box (`registry:src/lib/api.ts`).
pub const DEFAULT_COVERAGE_TYPE: &str = "1da6799e935cbb0fb14d359f06f23854c3d1bd509508948cc01b7b018dbbbdf5";
/// The default type NFT of a benchmark box.
pub const DEFAULT_BENCHMARK_TYPE: &str = "f6480184daf3b7750a58e58319e12adc5266bd986eec0f57ac451c995a30f54d";
/// The default type NFT of a result box.
pub const DEFAULT_RESULT_TYPE: &str = "49b26dc06b1680769477264d2e8e9bf561005236cde3097630bffcff631b7aef";

/// The type NFTs of the boxes of the registry (R4). The user can change them in the
/// settings of the app. The registry has new type NFTs when it is minted again.
///
/// The objective type has no default: it is empty. With an empty objective type the
/// catalog is empty, and the crate sends no request.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct TypeIds {
    /// The type NFT of an objective box. Empty: the catalog has no objective.
    pub objective: String,
    /// The type NFT of a coverage box.
    pub coverage: String,
    /// The type NFT of a benchmark box.
    pub benchmark: String,
    /// The type NFT of a result box.
    pub result: String,
}

impl Default for TypeIds {
    fn default() -> Self {
        TypeIds {
            objective: String::new(),
            coverage: DEFAULT_COVERAGE_TYPE.to_string(),
            benchmark: DEFAULT_BENCHMARK_TYPE.to_string(),
            result: DEFAULT_RESULT_TYPE.to_string(),
        }
    }
}

/// True if `id` is 64 hexadecimal characters (spaces around it are not allowed).
pub fn is_type_id(id: &str) -> bool {
    id.len() == 64 && id.bytes().all(|b| b.is_ascii_hexdigit())
}

impl TypeIds {
    /// The type NFTs in lowercase, with no spaces around them. The objective type can be
    /// empty. The other three must be 64 hexadecimal characters.
    pub fn normalized(&self) -> Result<TypeIds, fetch::CatalogError> {
        let clean = |id: &str| id.trim().to_ascii_lowercase();
        let ids = TypeIds {
            objective: clean(&self.objective),
            coverage: clean(&self.coverage),
            benchmark: clean(&self.benchmark),
            result: clean(&self.result),
        };
        let bad = [
            ("objective", !ids.objective.is_empty() && !is_type_id(&ids.objective)),
            ("coverage", !is_type_id(&ids.coverage)),
            ("benchmark", !is_type_id(&ids.benchmark)),
            ("result", !is_type_id(&ids.result)),
        ];
        match bad.iter().find(|(_, bad)| *bad) {
            Some((name, _)) => Err(fetch::CatalogError::BadTypeId((*name).to_string())),
            None => Ok(ids),
        }
    }
}
