# golden — `mcts` v1.0.0

## What is frozen
The declared output of the contract's golden invocation:
```
mcts.exe --branching 4 --depth 6 --iters 2000 --trees 1024 --c-uct 1.414214 --landscape match --seed 20260705 --json
```
A `4^6 = 4096`-leaf search space with the `match` landscape (hidden target derived from the seed; optimum 1.0 at `leaf==target`). All 1024 root-parallel UCT trees reach the optimum ⇒ `best_reward=1.0`, `best_path=[2,2,2,3,2,1]` (== the derived target), `found_optimum=true`, `frac_trees_optimal=1.0`, `mean_tree_nodes≈1998.7`. G-SUBOPTIMAL clear, verdict pass, exit 0.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — floats `%.6f`, fixed key order; `tool`/`version`/`notes` excluded. `mcts --golden` recomputes and compares.

## What it proves
1. **Determinism** — same (params, seed) ⇒ byte-identical declared output (≥3× byte-identical on sm_89). Counter-RNG rollouts + a deterministic hidden target + per-tree pools (no cross-thread contention, no float atomics) + fixed-order aggregation.
2. **The engine works** — root-parallel UCT reliably finds the exact optimum of a `B^D` landscape (all 1024 trees reach it, `best_path` equals the hidden target). The gate `G-SUBOPTIMAL` (not fired here) would flag any instance/budget the engine fails to solve.

## Environment
Recorded in `runs/mcts_golden.result.lock` (tool semver, binary blake2b, sm_89 + device, CUDA 13.1, host compiler, exact CLI, declared hash, git commit).
