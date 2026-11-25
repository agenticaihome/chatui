# Node directory and service catalog on Ergo

Both use the reputation-system contract `reputation_proof.es`
(github.com/reputation-systems/reputation-system). Every entity is an "opinion box".

**Read path:** Ergo Explorer only:

```
POST {explorer}/api/v1/boxes/unspent/search?offset={o}&limit=100
{"ergoTreeTemplateHash": "<hash>", "registers": {"R4": "<type NFT hex>", "R5": "<hex>"}, "assets": []}
```

Register values are in rendered form (raw hex, no `0e` and length prefix). The template
hash is required. Read all pages, until a page has fewer items than the limit.

## Register layout

| Register | Content |
|---|---|
| R4 | Type NFT id |
| R5 | The subject (peer_id, objective box id, benchmark box id, service id, …) |
| R6 | Locked flag |
| R7 | Owner proposition bytes (`0008cd` + 33-byte key) |
| R8 | Polarity (true = positive) |
| R9 | UTF-8 content (JSON) |

`assets[0]` is the reputation token of the publisher.

## Node directory

There is no registry contract for nodes. The closest thing is the box that a node
publishes about itself (`nodo:src/reputation_system/contracts/ergo/transaction.py`):

- R4 = Celaut node type NFT
  `64060577c3393e0e3cf8938ec8e6a2002ded27ece17750aa5add7d5c3e1227ba`.
- R5 = the node's peer_id.
- R9 = the node's signed `Peer` as protobuf JSON: one URI (IP, port), `public_key`,
  `signature`, `ts`. No payment contracts or resources: get those with GetPeerInfo.
- Only nodes with `SUBMIT_NETWORK_ADDRESS_TO_REPUTATION_PROOF: true` publish an
  address.
- The canonical ErgoTree and address are in `nodo:src/reputation_system/envs.py`.
  Filter boxes on the exact ErgoTree, not only the template.

## Service catalog: Celaut Registry

The Celaut Registry is <https://github.com/celaut-project/registry>. It was named "skills" before.
Its entity "Skill" is now "Objective". The type string is `celaut:objective:v1`. The persisted
JSON fields are `objective_box_id` and `extended_objective_boxes` (before: `skill_box_id` and
`extended_skill_boxes`).

Type NFT ids (mainnet, `registry:src/lib/api.ts`), template hash
`e84b95d84a30df33aa258fe2b9d24c3e75e27a67c6453983c19703029112d147`.
The registry will mint the type NFT of the objectives again, so the app has **no default** for
the Objective id. The user sets it (see "Type ids in the settings"). The other three
are the defaults of the app:

| Entity | Type NFT | R5 | R9 |
|---|---|---|---|
| Objective | set by the user, no default | empty | `{name, prose, formal, tags, domain, extended_objective_boxes, source_hash}` |
| Coverage | `1da6799e…bdf5` | objective box id | `{objective_box_id, benchmark_id, service_id}` |
| Benchmark | `f6480184…f54d` | objective box id | `{name, case_descriptors, performance_metrics[{name, higher_is_better}]}` |
| Result | `49b26dc0…7aef` | benchmark box id | `{benchmark_id, service_id, data[{case_meta, metrics_values}]}` |

- An objective id is its box id. A service id is a 64-hex string (probably the SHA3-256
  service hash of nodo; the repo does not say).
- Services of an objective = Coverage boxes about the objective, plus services that have Results
  in its benchmarks (direct coverages first, deduplicated). Coverages about a benchmark
  are runners; ignore them.
- Profile reputation = sum of `value` (nanoERG) of the unspent boxes that hold the
  profile token (`GET /api/v1/boxes/unspent/byTokenId/{tokenId}`).

**Ranking** (`registry:src/lib/scoreGlobal.ts`):

```
W(r)      = 0.5 + 0.5 * sign(r) * ln(1 + |r|) / ln(1 + N_max)    (0.5 if N_max <= 0)
N(x)      = (x - min) / (max - min)   (inverted if lower is better; 0.5 if max == min)
P_r       = Σ_m (1/M) * N(median of the result's case values for m)
C_r       = 0.4 * W(uploader) + 0.6 * W(result reputation)
P(S, B)   = Σ C_r * P_r / Σ C_r
Perf(S)   = Σ_B W(bench rep) * P(S, B) / Σ_B W(bench rep)
score(S)  = Perf null ? W_S : 0.7 * Perf + 0.3 * W_S     (W_S = W(coverage reputation))
```

Sort by score, then coverage reputation, descending.

**Known gaps in the registry:** the dApp reads only the first 100 boxes per query; "Run" only
copies `nodo execute <id>`; no package source works today (the file-source lookup has
its arguments swapped and no source boxes exist for the live services). The app can
launch a catalog service only on nodes that have it or can get it from their peers.

## Implemented in the app (M4)

The objective catalog is in the crate `celaut-catalog` (`rust/crates/celaut-catalog`) and in the
FFI module `celaut_catalog` (`rust/crates/wallet-ffi/src/api/celaut_catalog.rs`). The debug
service screen has "Pick an objective".

| Part | What it does |
|---|---|
| `parse` | Turns the JSON of an explorer box into an objective, a coverage, a benchmark or a result. A box that cannot be read is left out, never an error. A coverage with no service id, and a coverage of a benchmark (a runner), are left out. A metric that is a bare string, or has `higher_is_better` or `higherIsBetter`, is read; a missing direction means higher is better |
| `rank` | The ranking above, as `scoreGlobal.ts` has it. `W(r)`, `N(x)`, the median of the cases, `C_r`, `P(S, B)`, `Perf(S)`, and `score(S)`. The services are the coverages (in the order of the explorer) and then the services that only a result names. Equal scores keep that order |
| `fetch` | Asks an `Explorer` (a trait) for the boxes and the reputations. Per objective: one request for the coverages, one for the benchmarks, one for the results of each benchmark, and at most 64 for the reputation of the publishers. 4 requests at the same time |
| FFI | `celaut_objectives(types)` and `celaut_objective_services(types, objective_box_id)`. `types` is a `CatalogTypeIds`. `celaut_default_catalog_type_ids()` gives the defaults. The explorer is the fixed `https://api.ergoplatform.com`. Each request has a 10 s timeout and 3 tries (a transport error, 429 and 5xx are tried again). The reputation of a token is kept for 5 minutes |

### Type ids in the settings

The four type ids are not constants of the crate. The caller gives them (`celaut_catalog::TypeIds`,
in the FFI `CatalogTypeIds`):

- The Objective id is empty by default. With an empty Objective id the catalog is empty, and the
  crate sends no request. The Run screen and the objective picker then show "No objective type
  id" and a button that opens the settings.
- The Benchmark, Coverage and Result ids have the defaults in the table above
  (`DEFAULT_BENCHMARK_TYPE`, `DEFAULT_COVERAGE_TYPE` and `DEFAULT_RESULT_TYPE`).
- An id must be 64 hexadecimal characters (the Objective id can also be empty). The crate refuses
  another id with `CatalogError::BadTypeId`, before any request. The app also checks the input.
- Settings, Compute, "Celaut Registry" (`app/lib/ui/settings/registry_settings_page.dart`) shows
  the four ids. Each field has "Restore default". The ids are in lower case, in SharedPreferences
  (`celaut_registry_type_objective`, `_benchmark`, `_coverage`, `_result`), and
  `app/lib/celaut/catalog_types.dart` (`catalogTypes`) holds them.
- The cache of the FFI is by type ids, so a new id never shows the list of the old ones.

The reputation of a profile is the sum of the values, in nanoERG, of the unspent boxes that
hold its token (`GET /api/v1/boxes/unspent/byTokenId/{token}`, at most 2000 boxes). `N_max` is
the largest reputation in the objective. The uploader of a result and the result are the same
profile here, so `W(uploader)` and `W(result)` use the same reputation.

The tests use real explorer answers of 2026-10-15 (`tests/fixtures`): 7 objectives, 15 coverages,
18 benchmarks and 50 results, and an independent implementation of the formula gave the same
scores. `CELAUT_OBJECTIVE_TYPE=<64 hex> cargo test -p wallet-ffi the_real_catalog -- --ignored --nocapture`
asks the real explorer.

### Known limits

- Most results on chain are test data (one says "False results, invented. Don't trust
  them"). A high score is not a proof that a service works. The screen says so.
- A reputation that the explorer does not give (a failed request, or a token over the limit of
  64) counts as 0. The ranking then has less information. It does not fail.
- `extended_objective_boxes` (an objective that extends another) is read but not used: the coverages
  and the benchmarks of the extended objectives are not merged.
- Only unspent boxes count, and the reputation is the value of boxes, not the
  `calculate_reputation` of the `reputation-system` library, which the dApp uses.
- The read has no cache for the boxes: each time the user picks an objective, the app asks the
  explorer. The explorer is slow at times (an objective takes a few seconds, the whole catalog up to
  a minute).
- The catalog has no filter by architecture: a service that the nodes cannot run is in the list.
  The launch then fails on every node, and the screen says why.
- The node must already have the service, or get it from its peers (see "Known gaps in
  objectives").
