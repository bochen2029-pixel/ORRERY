# ratchet — Contract  v1.0.0

## Purpose
Monte-Carlo the recoverability-frontier **branching ratchet** at GPU scale and verify the redundancy critical threshold **(1−p)ρ = p** (the science's F13, throat T-RATE). A record held in **R** independent fragment-bits is rewritten repeatedly; per rewrite step each fragment **unwrites** (dies) with probability **p** (the Crooks fluctuation price of reversing its inscription, dS₁ = ln(1/p)) or, surviving, **re-broadcasts** a fresh copy with probability **ρ** (quantum-Darwinism redundancy growth). Per-fragment offspring law: 0 w.p. p · 1 w.p. (1−p)(1−ρ) · 2 w.p. (1−p)ρ — a Galton-Watson process. Per-lineage extinction `q* = min(1, p/((1−p)ρ))`; the record is ever unwritten with probability **q\*^R**. The frontier **propagates (is supercritical) iff (1−p)ρ > p**. The tool measures P[unwritten] over billions of trajectories and checks it against this analytic law (which *contains* the (1−p)ρ=p threshold via q\*).

**Scope:** measures a branching-process *threshold* (structure/mechanism); says nothing about qualia. State so in `notes` and MODULE.md. Seeded from `toy_rr_frontier_ratchet.py` (physics) + `criticality_cuda.cu` (GPU Monte-Carlo pattern).

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --p | float | 0.0<p<1.0 | 0.2 | per-fragment unwrite probability (Crooks price; dS₁=ln(1/p)) |
| --rho | float | 0.0<ρ<1.0 | 0.5 | per-fragment re-broadcast (redundancy) probability |
| --R | int | 1–4096 | 3 | number of independent fragments the record is held in (redundancy) |
| --trials | int | 1000–4000000000 | 1000000 | Monte-Carlo trajectories (the scale) |
| --tmax | int | 10–100000 | 1000 | max rewrite steps before a surviving trajectory is declared persistent |
| --cap | int | 16–65536 | 256 | offspring cap; a trajectory reaching it is a supercritical escape (record persists). 256 suffices (q\*^256≈0 above threshold; matches the toy) and keeps exact per-fragment sampling fast |
| --tol | float | 0.0–1.0 | 0.02 | relative-error tolerance for the theory-match gate |
| --seed | int | ≥0 | (required) | base RNG seed |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | per-trajectory-length histogram (survival-time distribution) to PATH |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run golden params; hash; exit 0/1 |

## Output (result fields)
| field | type | meaning |
|---|---|---|
| p | float | echoed |
| rho | float | echoed |
| R | int | echoed |
| trials | int | echoed (trajectories run) |
| q_star | float | analytic per-lineage extinction `min(1, p/((1−p)ρ))` |
| p_unwrite_mc | float | measured P[record ever unwritten] = extinct_trials / trials |
| p_unwrite_analytic | float | `q_star^R` |
| rel_error | float | \|p_unwrite_mc − p_unwrite_analytic\| / max(p_unwrite_analytic, 1/trials) |
| regime | enum | "supercritical" ((1−p)ρ>p) \| "critical" (=) \| "subcritical" (<) |
| rho_c | float | theoretical critical ρ at this p: `p/(1−p)` (the (1−p)ρ=p threshold) |
| escaped_frac | float | fraction of trajectories that hit `--cap` (supercritical escapes) |
| mean_survival_steps | float | mean steps to extinction over extinct trajectories (−1 if none) |

**Guard:** report `p_unwrite_mc` and `rel_error`, never a raw "match ratio" that blows up when the analytic is ~0. Near/at criticality the analytic → 1 and finite-trial MC → 1 by construction; do not over-interpret the trivial equality there (report the regime).

## CSV schema (--csv)
`survival_steps,count` — histogram of trajectory extinction times (how many of `trials` went extinct at each step; the final row aggregates escapes as `survival_steps=-1`).

## Gates (declared negative-result conditions → exit 1)
| id | fires when | field |
|---|---|---|
| G-THEORY-MISMATCH | rel_error > tol (the GPU MC does NOT reproduce the analytic branching law — an impl bug, insufficient trials, or a real deviation from F13) | rel_error |

Exit `0` when the MC reproduces the analytic law within `--tol` (the (1−p)ρ=p threshold is confirmed in-silico); exit `1` when G-THEORY-MISMATCH fires (a genuine result — surface loudly, it touches F13/T-RATE); exit `2` on bad params/CUDA error.

## Determinism
Declared output is a deterministic function of (all params, seed). Per-trajectory RNG is counter-based, keyed by (seed, trajectory_id, step, fragment_index) — **no per-thread RNG state, no wall-clock**. The extinction tally is an **integer** count (`atomicAdd` on int is associative ⇒ order-independent ⇒ deterministic); `p_unwrite_mc` = integer/integer. **No float atomics anywhere.** Pin the launch config. The survival-time histogram uses integer atomics per bin. Byte-identical declared output on sm_89.

## Golden
params: `ratchet.exe --p 0.2 --rho 0.5 --R 3 --trials 4000000 --tmax 500 --cap 256 --seed 20260705 --json`
(At p=0.2, ρ=0.5: q\*=0.5, analytic P[unwrite]=0.5³=0.125, supercritical since (1−p)ρ=0.4>0.2. 4M trajectories ⇒ ~0.1% sampling error, well inside tol=0.02. Fast: a few seconds — trajectory state is a single integer; escapes stop at cap=256.)
recorded: `goldens/ratchet/` (canonical-serialized declared JSON + blake2b hash + captured stdout). Hash domain = {seed, params, result, gates, verdict} (as `someone`, D-013).

## Change log
- v1.0.0 — initial contract. GPU Monte-Carlo of the Galton-Watson branching ratchet; single-point verification of P[unwrite]=q\*^R (which embeds the (1−p)ρ=p threshold). Copies `someone`'s envelope/determinism/golden discipline. Planned MINOR (v1.1.0): an optional `--scan-rho` mode that sweeps ρ across the threshold and locates the empirical critical ρ_c vs p/(1−p) (an additive field + CSV curve).
