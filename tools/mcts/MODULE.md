# MODULE — `mcts`

*The fourth ORRERY tool — a generic search engine, copying `someone`'s envelope/determinism/golden/two-pass shape. Read `contracts/mcts.contract.md` (v1.0.0) first — the contract is authoritative.*

**Status: DONE v1.0.0** — built, golden frozen (`6c596a53`, 3× byte-identical, ~fast), selftest green (7 checks). All 1024 golden trees find the exact optimum.

## Purpose
A generic **root-parallel UCT** (Monte-Carlo Tree Search) engine the science calls to search a decision/parameter space for a high-reward action sequence. Searches a depth-`D`, branching-`B` tree (a leaf = a point in `B^D`) to maximize a leaf reward, running `P` independent trees in parallel and aggregating. v1.0.0 searches a built-in `match` landscape with a known optimum (so the tool self-verifies it actually finds the answer).

## SCOPE GUARD (sacred — the §III firewall)
**This measures a search engine's ability to find an optimum in a defined space (an algorithm); it says nothing about whether anything feels (acquaintance) — §III-sealed.** Emitted verbatim in the JSON `notes`.

## Contract
`contracts/mcts.contract.md` v1.0.0 (+ `contracts/mcts.schema.json`).

## Provenance
New implementation of the standard UCT algorithm (Kocsis–Szepesvári UCB1 for trees); no prototype. Reuses `someone`/`ratchet`'s validated blake2b / counter-RNG / JSON / CLI spine — the template propagating.

## Internal design (as built)
- **One tree per GPU thread** (root parallelization — the GPU-natural MCTS; `P` independent trees), grid `(P+127)/128 × 128`.
- **Index-based node pool** in global memory, SoA: `N[]` (visits, int), `W[]` (value sum, float), `childBase[]` (index of the node's first child, or −1 if unexpanded). Each tree owns the slice `[tree·max_nodes .. +nodeCount)`; `nodeCount` is a per-thread register starting at 1 (node 0 = root). The pool is zero/`-1` initialized by `cudaMemset` (`0xFF` bytes ⇒ int −1 for `childBase`).
- **Per iteration:** SELECTION (descend from root by UCB1 `W_c/N_c + c·√(ln N/N_c)`, **unvisited children first**, then strict-`>` max with lowest-index tie-break) → EXPANSION (allocate `B` children of the selected leaf, descend into child 0; stops if the pool is full — the `--max-nodes` guard) → SIMULATION (complete the path to depth `D` with counter-RNG actions; reward = `#{d: leaf[d]==target[d]}/D`) → BACKPROP (add reward + a visit to every node on the path). Each tree tracks the best leaf it ever evaluated.
- **Landscape `match`:** hidden target `t[d] = hash4(seed^salt, d) % B`, optimum 1.0 at `leaf==t`. Computed on host, uploaded.
- **Aggregation (host):** `best_reward` = max over trees (order-independent); `best_path` = the lexicographically-smallest optimal leaf (deterministic tie-break); `mean_best_reward`/`mean_tree_nodes` via index-order Kahan; `frac_trees_optimal` = fraction within `--tol` of the optimum.

## Determinism approach
Same (params, seed) ⇒ byte-identical declared output. Rollout actions and the hidden target are **counter-based** (`u01(hash4(seed,tree,iter,depth))`); UCB1 selection is deterministic (unvisited-first, strict-max, lowest-index tie); **each tree owns its pool** so a node's visit/value accumulate in a fixed per-tree order (no cross-thread contention, no float atomics). Aggregation is fixed-order. No wall-clock. Verified `--golden` ≥3× byte-identical (`6c596a53`).

## Selftest (green — 7 checks)
blake2b KAT; optimum found on a small instance (best_reward=1.0); best_path length == depth; G-SUBOPTIMAL clear when found; **best_path == the derived hidden target** when found (the engine truly solves it); G-SUBOPTIMAL fires on a starved budget (the exit-1 finding path); determinism (×2 identical).

## Golden
`mcts.exe --branching 4 --depth 6 --iters 2000 --trees 1024 --c-uct 1.414214 --landscape match --seed 20260705 --json` → 4^6=4096-leaf space; all 1024 trees reach the optimum ⇒ best_reward=1.0, found_optimum=true, exit 0. Frozen `6c596a53` in `goldens/mcts/`; `result.lock` in `runs/mcts_golden.result.lock`.

## Build
Single-file CUDA, from `tools/mcts/` (see `BUILD.md`). Fenced so `harness/verify.py` can extract it:
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 mcts.cu -o mcts.exe'
```
Then: `.\mcts.exe --selftest` · `.\mcts.exe --golden` · `.\mcts.exe <params> --json`.

## Known issues / caveats
- v1.0.0 has ONE built-in landscape (`match`, a findable known-optimum). A deceptive `needle`, a caller-supplied reward spec, and root-action aggregation stats are planned MINOR extensions (v1.1.0). The `match` landscape is position-separable, so it is an *engine correctness* test (does UCT find the optimum) rather than a hard search benchmark.
- Per-thread node pools live in global memory (uncoalesced by nature of per-thread trees); fine at the contract's `P`/`max_nodes` ranges. Very large `P × max_nodes` can exhaust device memory → a clean CUDA OOM mapped to exit 2.
- `best_reward` is a max over independent trees; a larger `--trees`/`--iters` budget monotonically helps (report `frac_trees_optimal` for robustness, not just the max).

*Sims/searches prove structure (an algorithm's reach), never acquaintance. Build one tool right; freeze its golden; let the science call it.*
