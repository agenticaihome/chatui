# Execution balancer (port of nodo)

Source: `nodo:src/balancers/execution_balancer/execution_balancer.py`,
`nodo:src/balancers/estimated_cost_sorter`, `nodo:src/balancers/scoring.py`.

## Pipeline

1. Candidates: every known node. (nodo also adds `local`; the light client does not run
   services, so it has no local candidate.)
2. Skip a node if its announcement says it cannot run the request (filter below), or if the
   activity window that it announced says that it is closed now (nodo#344; see "The
   activity window of a node" below).
3. Ask each remaining node `GetServiceEstimatedCost` (timeout 10 s). Convert the
   configuration to the node's MU before, and the quote to local MU after. A node with no
   shared payment method, an error or a refusal is not a candidate.
4. Score each quote and sort, best first: the quotes that promise a price bound, then the
   better interruption class, then the score (stable sort: equal scores keep insertion
   order).
5. The caller tries the candidates in order and uses the first that launches.

## Filter (`nodo:src/utils/cost_functions/architecture_resources.py`)

**Status.** The filter is ported and tested (`celaut-balancer`, `filter.rs`; the call is
`celaut_client::quotes_for` with a `ServiceAsk`). It is **not used in the real flow yet**:
the app has the hash of a service, not its resources (`resources.at_most`,
`resources.at_init`, the architecture). Without a `ServiceAsk`, `quotes` skips no node.
The filter needs the spec of the service: from a catalog entry or from a package that the
user uploads. Until a caller has it, a node is never skipped by the filter, and the first
check of a node is its own answer to `GetServiceEstimatedCost`.

What the port does, in the order of nodo (`request_misfit`):

- The node announced nothing, or the architecture of the service is unknown: ask the node.
- No entry for the architecture: skip (`NotRun`). The first entry whose tags name the
  architecture is the one that counts.
- `mem_limit` or `disk_space`: skip only if both sides have the value and the ask is more
  than the ceiling. An equal value fits.
- Cores: skip if the ask has a quota, the ceiling has a quota, and the ask is more than the
  ceiling. A period that is absent or 0 is 100000. A ceiling with quota 0 is 0 cores.
- Benchmarks, sorted by key: see below.
- A reason is a typed `Misfit`. A node with no reason is asked.


- `ask` = copy of `resources.at_most` without benchmarks, plus `at_init.benchmark`.
- Announcement = `Peer.resources` (repeated `ArchitectureResources`) from GetPeerInfo.
- Empty announcement or unknown service architecture: do not skip.
- No entry for the architecture: skip ("does not run …").
- Skip if `mem_limit` or `disk_space` is set on both sides and ask > cap.
- Cores = `cpu_quota / (cpu_period or 100000)` (0 if quota is 0). Skip if the cap has
  `cpu_quota`, the ask is not 0 and ask > cap.
- Benchmarks (`nodo:src/utils/benchmark.py`): keys `int_ops_per_sec`,
  `flt_ops_per_sec`, `sha256_hashes_per_sec`, `mem_bandwidth_<N>(kib|mib|gib)_bytes_per_sec`.
  For a memory key with no own score, use the smallest measured working set that is at
  least the required size. Unknown or unmeasured keys are not enforced. Skip if
  score < minimum.
- Architecture tags (`nodo:src/utils/arch_guard.py`): `linux/amd64|amd64|x86_64` →
  `linux/amd64`; `linux/arm64|arm64|arm_64|aarch64` → `linux/arm64`. First known tag wins.

## Score

```
vcnorm(c, v)  = trunc(c * (1 + v * k))                 k = COST_AVERAGE_VARIATION = 1
v             = price_volatility if price_bounded, else 0 (nodo#636; not finite or < 0: 0)
per_hour(a)   = 0 if s <= 0 else trunc(vcnorm(a, v) * 3600 / s)
                s = maintenance_seconds_loop
cost_mu       = trunc(vcnorm(cost, v)
                      + mean(per_hour(init_maintenance_cost), per_hour(max_maintenance_cost)))

score         = +inf if cost_mu <= 0
              = -ln(cost_mu) + W_r * f(r, H_r) + W_o * ô + W_d * d̂
f(x, h)       = x / (|x| + h)
```

Defaults: `W_r = SOCIALIZATION_FACTOR = 2`, `H_r = 50`, `W_o = 0.3`, `H_o = 5 ERG`,
publisher cap 5 ERG, `W_d = 0.3`. A weight W can overcome a price ratio of e^W.

- **r (local reputation):** `score * (1 + ln(index))` from the client's own event log.
  Events in nodo: +10 payment communicated, −100 payment not acknowledged, −1 failed
  payment call, −100 GetPeerInfo failure (once per outage), −100 GetService timeout,
  −1000 wrong hash.
- **ô (on-chain reputation):** for publisher p and subject s:
  `v = Σ ±(box tokens / assigned tokens of p)` (sign from R8),
  `c = cred(p) * sign(v) * min(|v| * burned_ERG(p), CAP)`, `S = Σ_p c`,
  `ô = S / (|S| + H_o)`. `cred(p)` = cosine similarity between p's verdicts and the
  client's own `f(r, H_r)`, clamped to [0, 1]. **Light client change:** while the
  client has no events, `cred(p) = 1`.
- **d̂ (donations):** nodo-specific. The light client uses 0 for now.

## MU conversion (`nodo:src/payment_system/mu_conversion.py`)

- Payment method key: `(ledger tag, sha3_256(contract_type).hex, token_id)`. The first
  method that both sides have is used.
- `convert(amount, from, to)` = `amount * to / from`, integers of any size.
- Configuration sent to a node: round down. Quote received: round up.

## Quote cache (`nodo:src/utils/tools/query_cache.py`)

TTL 10 s, at most 4096 entries, LRU. Key = sha256 over namespace `"peer-quote"`, the
peer id, the configuration in the node's MU and the metadata with sorted hashes
(each part: length as 8-byte big endian, then bytes).

The quotes that promise a price bound (`price_bounded`) come first, then the better
interruption class (nodo#344, below), then the score, as in nodo (#636, G;
`estimated_cost_sorter.py`); the same for the quotes that cannot be compared.

## The start balance of a launch (2026-11-10, issue #119, nodo#636)

The app has no balance of its own: before, it asked every quote with a fixed balance of
1 000 000 MU (the default of a field of the service debug screen) and started with that.
That was about 3 minutes of a service at 18M MU per hour, the same for a small and a large
service, and a parent that starts a child from its balance could run dry first.

A quote is asked with no `initial_mu`. Its `cost` is the builds only (the service and its
initial children; nodo#636), and a node charges `init_maintenance_cost` once each
`maintenance_seconds_loop`, at most `init × (1 + price_volatility)^k` in the volatility period
`k` (`volatility_period_seconds`). The start adds the balance:

- **No time** (the time field empty, or "until I stop it"): the start has no `initial_mu`.
  The node charges `cost` plus the funding of its `deposits.DEFAULT_INITIAL_PERIODS` periods
  (360 by default), as for `nodo execute`. The confirmation shows the build and says that the
  node chooses the balance.
- **A time `T`**: `initial_mu = cost + balance(q, T)` on each node, at the price of that node
  (`launcher.dart`, `startMuFor`). One round of quotes.
- balance(q, T) = funding_sum(ceil(T / loop) + 1), where funding_sum(N) = ceil(Σ_{i=1..N}
  init × (1 + v)^k(i)), k(i) = floor(i × loop / T_v) + 1 (1 when T_v = 0), v = 0 for a quote
  that is not bounded: nodo's `price_bound.funding_sum_mu` (`maintenance_price.dart`). The
  extra period is the one that runs at the end. The float32 `price_volatility` is read as
  the decimal that it was written as (0.1, not 0.10000000149), as nodo's `_rounded`.
- A node that gives no price per period (loop 0, or no amount) gets no `initial_mu`: the
  node chooses its default balance. This is the fallback balance of issue #119.
- The credit check before a start compares the credit of the client with
  `cost + balance(q, T)`, or, when the node chooses, with `cost` plus one period
  (`funding_sum(1)`): the least start of a node (`start_funding.minimum_runtime_mu`). The
  node then adds its own default, which the app cannot know, so a node can still refuse a
  credit above it (issue #129).
- The Rust port of the sum is `celaut_balancer::funding` (`balance_for_periods`,
  `funding_sum_mu`), with vectors made by the nodo code
  (`celaut-balancer/tests/vectors/generate.py`); the app sums in Dart
  (`MaintenancePrice`), and a Dart test checks it against the same vectors. Both sum in
  floating point: the same whole MU as nodo's exact fractions below 2^53 MU, within a
  relative 1e-12 above.
- The service debug screen keeps a balance field, empty by default; a typed balance is added
  to the `cost` of each node (`balanceMu`).
- A node gives back what the instance did not use at the stop.

Open for nodo: with no `initial_mu`, a parent gets `cost + funding_sum(360)` of its own
price, but it starts each initial child with the default of the child, which can be more
(nodo#637 e2e, 2026-11-09: parent 5 586 372 MU, child default 5 747 148 MU → "Insufficient
balance", the child does not start). The app cannot fix this: the quote does not say what
the children take after their builds. A time long enough funds the child.

## The activity window of a node (2026-11-10, issue #129, nodo#344)

A node can take new work only at certain hours (nodo `activity_window` in `config.yaml`).
The protocol says it in three places (nodo `7533a177`):

- **The quote** is the authority for one instance: `EstimatedCost.closes_at` is the unix time
  of the next close, in seconds (0: none scheduled; not a promise of a long life), and
  `on_close` is what the node then does with a running instance: `ON_CLOSE_REFUSE` (0, the
  default and the value of an older node) leaves it running and refuses new work,
  `ON_CLOSE_STOP` stops it and refunds the balance, `ON_CLOSE_HIBERNATE` hibernates it and
  wakes it when the window opens. With no window, a node says REFUSE and 0.
- **`Peer.activity_window`** is a hint: the open spans of one repeating day, in minutes from
  00:00 UTC (0 to 1439; the start is in the span, the end is not; an end before the start
  passes midnight). No message: the node gives no schedule. No spans: always open. The node
  announces a new Peer when it changes. It is part of the signed content digest
  ([wire.md](wire.md)).
- **`CanExecuteReply.opens_at`**, in the answer of `GetResourceAvailability`: the next
  opening when the cause of `can_execute = false` is the window. The app does not call
  `GetResourceAvailability` (nodo calls it between peers), so it reads the opening from
  the schedule of the Peer instead.

What the app does (`celaut_balancer::closing`, a port of nodo's `interruption.py` and of
`schedule_closed_reason` in `architecture_resources.py`):

- **Skip a closed node.** A node whose announced schedule says that it is closed now gets no
  quote call, as nodo's balancer skips it; it is a failure "closed" in the list, with the
  time at which its schedule opens (`QuoteFailureView.opens_at`). A schedule that cannot be
  read (a minute out of range, two equal edges) or no schedule at all is no reason to skip.
  A quote or a start that a node refuses because it is closed also says when it opens
  (`celaut_node_opens_at`): the app asks the node for its current `Peer` (`GetPeerInfo`,
  signature checked), because the `Peer` of the connection can be older than a change of
  the schedule; if that fails, it uses the one of the connection. The skip itself uses the
  `Peer` of the connection.
- **Interruption class.** `funded_life` is how long the balance of the start pays (the quote
  round has no `initial_mu`, so each node funds its default 360 periods, up to 4 days):

  | Class | `on_close` | The close |
  |---|---|---|
  | 0 | REFUSE, or no close | any |
  | 1 | HIBERNATE | at or after the end of the funded life |
  | 2 | STOP | at or after the end of the funded life |
  | 3 | HIBERNATE | before the end of the funded life |
  | 4 | STOP | before the end of the funded life |

  The order is the price bound, then the class (lower first), then the score. The class is
  never a term of the score, and it removes no node.
- **Say it.** The confirmation of a launch says when the best node closes and what it does
  then (STOP or HIBERNATE; nothing for REFUSE), in the color of an error when the close comes
  before the instance would end: the time that the user chose, the default periods of the
  node, or never with "until I stop it". The app keeps `closes_at` and `on_close` with the
  instance (`InstancePricing`); the info page says them, and with keep running on a node that
  stops it, it warns that keep running cannot keep the instance past that time
  ([ui.md](ui.md), Keep running).

## The least time of a launch (2026-10-23, Josemi)

The confirmation of a launch has a field: the least time that the instance must run. The
start balance for that time is balance(q, T) above.
- The time holds at the price of the quote. nodo prices each maintenance period against the
  load of its host at that moment (a scarcity surcharge, up to the `scarcity_max_multiplier`
  that it advertises), and it takes the tunnel connections (`TUNNEL_OPEN_MU`) and their
  traffic (`NET_MU_PER_GIB`) from the same balance. On 2026-10-23, on our node with the
  emulator and a build on the same host, an instance funded for 10 minutes ran out after
  about 7. The confirmation says so; keep running ([ui.md](ui.md), section 4b) is the
  answer for a long conversation.

The app keeps the last time that the user typed (`celaut_min_survival_minutes_v1`). It must
be from 1 minute to 30 days.

## The initial children of a service (2026-11-09, nodo#538)

A service can declare the children that it starts at its start
(`Service.initial_environment_workload`). The parent pays the start of each child from its own
balance. Since nodo#636 the `cost` of a quote is the builds of the parent and of its initial
children, with no balance; the parent funds the balance of each child (its default, when the
parent sends no `initial_mu`) from the balance that the start gave it. There is no separate
field (nodo#635, at Josemi's request: the client has nothing to do with the split). The app
sends `cost + balance(q, T)` for a time, or no `initial_mu`, as for any service (see "The start
balance of a launch", and its open point for nodo). The info page of a service lists the first instances that it starts
(`initial_environment_workload`) apart from the ones that it can start later.

## Priority of the user (node reputation)

The user can give each node a reputation, a whole number from 0 to 100
(`celaut_balancer::PRIORITY_MIN` and `PRIORITY_MAX`). 50 is neutral and a node that was
never rated has it (a database of version 1 migrates to 50). The score adds
`PRIORITY_WEIGHT (2.0) * (p - 50) / 50`, so it goes from -2 to +2: at 100, a node can win
against one that is up to `e^2` (about 7.4) times cheaper, but not against any price, and a
free offer still comes first.

"Fully trusted" (`NodeRecord::trusted`) means the maximum: its effective priority is 100
whatever number is saved, and the number comes back when the mark is taken off. The app
reads `CelautData::standings()` and gives it to `celaut_client::quotes_with`. FFI:
`celaut_set_node_priority(peer_id, priority)`; `KnownNodeView.priority` is the effective
value and `set_priority` the saved number.

## Weights of the score (user setting)

The weights of the terms are a setting of the user (`celaut_balancer::Weights`), and the
app shows them in Settings, Compute, "Balancer weights" (`balancer_screen.dart`):

```
score = -W_price * ln(cost) + W_rep * f(r, H_r) + W_onchain * ô + W_donation * d̂
        + W_priority * (p - 50) / 50
```

| Term | Default | Note |
|---|---|---|
| price | 1 | nodo's value |
| reputation | 2 | `SOCIALIZATION_FACTOR`; the term is 0 until the event log exists |
| onchain | 0.3 | the term is 0 until the app reads it |
| donation | 0.3 | the term is 0 for now |
| priority | 2 | the 0 to 100 priority of each node |

Each weight is from 0 (the term is off) to 10 (`WEIGHT_MAX`); a bad value is limited, and the
FFI refuses a value outside the range. They are kept in the database
(`CelautData::balancer_weights_milli`, thousandths; absent = defaults, so an old database
works) and every real quote uses them (`quotes_weighted`). A free offer is still first
whatever the weights. FFI: `celaut_balancer_weights`, `celaut_balancer_default_weights`,
`celaut_set_balancer_weights`.

### How the screen explains it

Raw numbers say little, so `balancer_screen.dart` (logic in `app/lib/celaut/balancer_model.dart`,
which mirrors `score_with`) shows the weights three ways:

- **Quick setups:** balanced (the defaults), cheapest first (price only) and my nodes first
  (the priority weight x3, so a node of full trust beats one up to e^6, about 400 times,
  cheaper).
- **A sentence from the real formula:** a node of full trust beats a neutral node that is up
  to `e^(W_priority / W_price)` times cheaper (7.4x by default).
- **An example:** three nodes (cheap and neutral; 3x the price and fully trusted; half the
  price and no trust) that change order while a slider is dragged.

Price and priority are the main sliders. The three terms with no data yet are in a closed
section, marked as adding nothing today.
