# mcts — Two-Pass Cold-Context Verification

**Tool:** `mcts` (CUDA root-parallel UCT search engine)
**Contract:** v1.0.0 (`contracts/mcts.contract.md` + `mcts.schema.json`)
**Pass type:** INDEPENDENT COLD-CONTEXT verification — black-box, against the published contract only. The verifier did **not** read `tools/mcts/mcts.cu` or treat MODULE.md science claims / RUN_STATE / DECISIONS as truth. Behavior was verified, not claims (the RAYFORMER ADR-007 lesson).
**Date:** 2026-07-05
**Binary:** `C:\ORRERY\tools\mcts\mcts.exe`

## Overall verdict: **CONFORMANT**

Every contract-declared behavior was reproduced. No failures.

---

## Golden hash

| item | value |
|---|---|
| frozen (`goldens/mcts/declared.hash`) | `6c596a53f44543f2149ebfe7bc33ac9ce19e5443f214255f24212559344d8000` |
| observed (`mcts.exe --golden`, stderr) | `6c596a53f44543f2149ebfe7bc33ac9ce19e5443f214255f24212559344d8000` |
| **match** | **YES** — identical; reproduced 3× byte-stable |

Live golden stdout is byte-identical to the frozen `goldens/mcts/stdout.txt`.

**Hash integrity (anti-RAYFORMER check):** the emitted hash is genuinely data-bound, not a stamped constant — running the exact golden params with an off-by-one seed (20260706) produced a *different* declared envelope (`best_path` [0,2,0,2,2,1] vs golden [2,2,2,3,2,1]; `mean_tree_nodes` 2083.88 vs 1998.67), and `GOLDEN OK` fired **only** on the exact frozen seed 20260705.

## Harness

`python C:\ORRERY\harness\verify.py --tool mcts` → final line `OVERALL: GREEN`, exit 0.
Report `runs/verify_20260705_223935.md`: mcts row = `build=OK selftest=OK golden=OK`.

## Golden engine-correctness numbers (from `--golden --json`)

| field | value | contract-required | ok |
|---|---|---|---|
| result.optimum | 1.0 | 1.0 | ✓ |
| result.best_reward | 1.0 | 1.0 | ✓ |
| result.gap_to_optimum | 0.0 | 0.0 | ✓ |
| result.found_optimum | true | true | ✓ |
| result.frac_trees_optimal | 1.0 | 1.0 | ✓ |
| result.best_path | [2,2,2,3,2,1] | array len==depth(6), entries in [0,branching=4) | ✓ |
| G-SUBOPTIMAL fired | false | not fired | ✓ |
| verdict | pass | pass | ✓ |
| exit code | 0 | 0 | ✓ |

---

## Per-check conformance battery

| check | PASS/FAIL | evidence |
|---|---|---|
| **STEP1** harness GREEN | PASS | `OVERALL: GREEN`, exit 0; report row `build=OK selftest=OK golden=OK` |
| **STEP1** golden hash + `GOLDEN OK` | PASS | stderr `GOLDEN OK blake2b=6c596a53…4d8000`, exit 0; equals frozen hash |
| **2a** `--selftest` | PASS | 7/7 checks `[PASS]`, `SELFTEST PASS`, exit 0 |
| **2b** schema valid | PASS | `jsonschema.validate` OK against `mcts.schema.json`; `tool`="mcts", `version`="1.0.0" |
| **2b** notes firewall | PASS | notes = "…it says nothing about whether anything feels (acquaintance) - III-sealed." (says nothing about qualia/feeling) |
| **2c** golden engine correctness | PASS | optimum=best_reward=1.0, gap=0.0, found_optimum=true, frac_trees_optimal=1.0, best_path len 6 in [0,4), G-SUBOPTIMAL not fired, verdict pass, exit 0 |
| **2c** fresh findable instance | PASS | `--branching 3 --depth 4 --iters 500 --trees 256 --seed 42 --json` → found_optimum=true, best_reward=1.0, gap=0.0, exit 0 |
| **2d** GATE on starved instance | PASS | `--branching 8 --depth 12 --iters 16 --trees 1 --max-nodes 256 --seed 3 --json` → found_optimum=false, gap=0.666667>tol, G-SUBOPTIMAL fired=true, verdict fail, **exit 1** (declared result, not error 2) |
| **2e** `--depth 99` → 2 | PASS | exit 2 |
| **2e** `--branching 1` → 2 | PASS | exit 2 |
| **2e** `--landscape bogus` → 2 | PASS | exit 2 |
| **2e** unknown flag → 2 | PASS | exit 2 (`--frobnicate`) |
| **2e** missing `--seed` → 2 | PASS | exit 2 |
| **2e** valid run ∈ {0,1} never 2 | PASS | findable→0, starved→1 |
| **2f** determinism byte-identical | PASS | `--branching 4 --depth 5 --iters 800 --trees 128 --seed 99` run twice → byte-identical (711 B) |
| **2f** bonus: seed moves target | PASS | seed 99 best_path [3,2,1,2,3] ≠ seed 100 best_path [3,1,2,3,0] |
| hash is data-derived (not constant) | PASS | off-by-one seed yields different envelope; GOLDEN OK only on frozen seed |

**Failures:** none.

---

## Exit-code hygiene (0/1/2 never conflated) — confirmed

- **0** = optimum found within tol (golden, fresh findable).
- **1** = G-SUBOPTIMAL fired — a genuine negative result (starved instance), distinct from error.
- **2** = bad params / unknown flag / missing required seed.

## Determinism — confirmed

Same (params, seed) ⇒ byte-identical declared output; different seed ⇒ different hidden target (best_path moves). Consistent with the contract's counter-RNG / no-wall-clock / no-float-atomics determinism claim (verified behaviorally, not by source inspection).

---

*Independent cold-context two-pass verification against contract v1.0.0. Verdict: **CONFORMANT**.*
