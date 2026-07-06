# mcts — Contract  v1.0.0

## Purpose
A generic **root-parallel UCT** (Monte-Carlo Tree Search) engine the science calls to search a decision/parameter space for a high-reward action sequence. It searches a depth-`D`, branching-`B` tree (a leaf is a path in `{0..B-1}^D`, i.e. a point in a `B^D` space) to maximize a leaf **reward**, running `P` independent trees in parallel (root parallelization — the GPU-natural MCTS) and aggregating. To be self-verifying, v1.0.0 searches a **built-in reward landscape with a known optimum**; a caller-supplied landscape is a planned extension. It reports the best path/reward found, whether the known optimum was reached, and search-effort/robustness statistics.

**Scope:** measures a *search engine's* ability to find an optimum in a defined space (an algorithm/mechanism); says nothing about qualia. §III-sealed. Seeded from a new implementation (the standard UCT algorithm); no prototype.

## The algorithm (each of P trees, independently)
Standard UCT: **Selection** (descend from root by UCB1 `W_c/N_c + c·√(ln N / N_c)`, unvisited children first, ties by lowest index) → **Expansion** (add the `B` children of the selected leaf) → **Simulation** (complete the path to depth `D` with counter-RNG random actions; evaluate the leaf reward) → **Backprop** (add the reward and a visit to every node on the path). Each tree tracks the best leaf it ever evaluated. The tool aggregates the `P` trees' bests.

## Reward landscape (built-in; the "supplied space")
`--landscape match` (v1.0.0): a hidden target `t ∈ {0..B-1}^D` derived deterministically from `--seed`; `reward(leaf) = (#{d : leaf[d]==t[d]}) / D ∈ [0,1]`, with a unique **optimum 1.0** at `leaf==t`. (Additional landscapes — e.g. a deceptive `needle` — are a planned MINOR extension.)

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --branching | int | 2–32 | 4 | actions per node (`B`) |
| --depth | int | 1–16 | 6 | path length / tree depth (`D`); leaves = `B^D` |
| --iters | int | 16–1000000 | 2000 | MCTS iterations per tree |
| --trees | int | 1–1048576 | 1024 | independent root-parallel trees (`P`) |
| --c-uct | float | 0.0–4.0 | 1.414214 | UCB1 exploration constant |
| --max-nodes | int | 64–1048576 | 8192 | node-pool capacity per tree (expansion stops if full; a bounded-memory guard) |
| --landscape | enum | match | match | built-in reward landscape (v1.0.0: match) |
| --tol | float | 0.0–1.0 | 0.001 | gap-to-optimum tolerance for the found-optimum gate |
| --seed | int | ≥0 | (required) | seeds the hidden target AND all rollout RNG |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | per-tree row (tree, best_reward, nodes, iters_effective) to PATH |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run golden params; hash; exit 0/1 |

## Output (result fields)
| field | type | meaning |
|---|---|---|
| branching | int | echoed `B` |
| depth | int | echoed `D` |
| trees | int | echoed `P` |
| iters | int | echoed iterations/tree |
| optimum | float | the known landscape optimum (1.0 for `match`) |
| best_reward | float | best leaf reward found across all `P` trees (the search result) |
| gap_to_optimum | float | `optimum − best_reward` |
| found_optimum | bool | `gap_to_optimum ≤ tol` |
| best_path | int[] | the lexicographically-smallest leaf (length `D`) achieving `best_reward` (deterministic tie-break) |
| mean_best_reward | float | mean over trees of each tree's own best reward (robustness) |
| frac_trees_optimal | float | fraction of trees whose best reached the optimum (within tol) |
| mean_tree_nodes | float | mean nodes expanded per tree (search effort) |

**Guard:** `best_reward` is a max over independent trees (order-independent ⇒ deterministic); `best_path` is the lexicographically-smallest optimal leaf so ties are resolved deterministically. Report `best_reward` + `found_optimum` + `frac_trees_optimal`, never a bare "MCTS solved it" without the gap and the robustness fraction.

## CSV schema (--csv)
`tree,best_reward,nodes,iters` — one row per tree (its own best reward, nodes expanded, iterations run).

## Gates (declared negative-result conditions → exit 1)
| id | fires when | field |
|---|---|---|
| G-SUBOPTIMAL | gap_to_optimum > tol — the search did NOT reach the known optimum (hard landscape, or insufficient iters/trees budget) | gap_to_optimum |

Exit `0` when the optimum is found within tol; exit `1` when G-SUBOPTIMAL fires (a genuine result — the engine/budget did not solve this instance); exit `2` on bad params/CUDA error.

## Determinism
Declared output is a deterministic function of (all params, seed). Rollout actions and the hidden target are counter-based `u01(hash4(seed, tree, iter, depth))` / `hash4(seed, d, ...)` — **no per-thread RNG state, no wall-clock**. UCB1 selection is deterministic (unvisited-first, then strict-`>` max with lowest-index tie-break). Each tree owns its node pool (no cross-thread contention ⇒ each node's visit/value accumulate in a fixed per-tree order). Aggregation is a max/mean over trees in fixed (index) order; `best_path` is the lex-min optimal leaf. **No float atomics.** Byte-identical declared output on sm_89.

## Golden
params: `mcts.exe --branching 4 --depth 6 --iters 2000 --trees 1024 --c-uct 1.414214 --landscape match --seed 20260705 --json`
(`B^D = 4^6 = 4096` leaves; the `match` landscape is findable, so the ensemble reaches the optimum ⇒ best_reward=1.0, found_optimum=true, exit 0. Fast — root-parallel, small trees.)
recorded: `goldens/mcts/` (declared hash + stdout + NOTE). Hash domain = {seed, params, result, gates, verdict}, floats `%.6f` (D-013).

## Change log
- v1.0.0 — initial contract. Root-parallel UCT over a `B^D` space with a built-in `match` landscape (known optimum), root-parallel `P` trees, per-tree bounded node pool. Copies `someone`'s envelope/determinism/golden discipline. Planned MINOR (v1.1.0): additional landscapes (deceptive `needle`), a caller-supplied reward (via a spec), and root-action aggregation stats.
