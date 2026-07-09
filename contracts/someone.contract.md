# someone — Contract  v1.1.0

## Purpose
Evolve a population of embodied agents whose recurrent state runs an encoder→bottleneck→decoder→predictor self-model, in a configurable complex world (lights, predators, food, day/night), and measure whether **self-modeling agents (a real bottleneck, k≪N, `pureGap`>0) out-survive/out-reproduce zombie agents (bottleneck bypassed, k=N, gapless)** under stakes (energy depletion, predator death). Tests the functional half of the Someone-Criterion's C2 (gap) and the zombie clause. Seeded from `C:\Users\user\Desktop\DSA\dak_evolution_complex.cu`.

**Scope:** this measures *structure* (does the gap confer fitness), never *acquaintance* (qualia). Say so in output `notes` and MODULE.md.

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --pop | int | 16–8192 | 200 | population size |
| --gens | int | 1–5000 | 500 | generations |
| --steps | int | 100–5000 | 1500 | steps per generation (episode length) |
| --N | int | 32–1024 | 256 | recurrent state dimension |
| --k | int | 1–N | N/4 | bottleneck dimension (the C2 gap; k=N ⇒ gapless) |
| --zombie-frac | float | 0.0–1.0 | 0.5 | fraction initialized as zombies (bottleneck bypassed) |
| --complexity | enum | L0..L3 | L3 | env level: L0 none · L1 predators · L2 moving-lights · L3 full (predators+night+food+moving) |
| --mut-rate | float | 0–1 | 0.02 | per-weight mutation probability |
| --mut-str | float | 0–1 | 0.1 | mutation magnitude |
| --ensemble | int | 1–256 | 1 | independent seeded replicas; results aggregate mean±sd over replicas |
| --seed | int | ≥0 | (required) | base RNG seed (replica r uses seed+r) |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | per-generation series (all replicas) to PATH |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run golden params; hash; exit 0/1 |

## Output (result fields)
| field | type | meaning |
|---|---|---|
| gens_run | int | generations completed |
| normal_fit_final | float | mean final-gen fitness of normal (bottlenecked) agents, over ensemble |
| zombie_fit_final | float | mean final-gen fitness of zombie agents, over ensemble |
| normal_fit_sd | float | sd across ensemble replicas |
| zombie_fit_sd | float | sd across ensemble replicas |
| delta_fit | float | normal_fit_final − zombie_fit_final (the discriminating quantity) |
| normal_alive_final | float | mean count of normal agents alive at final gen |
| zombie_alive_final | float | mean count of zombie agents alive at final gen |
| zombie_extinct_gen | int | mean generation zombies went extinct (−1 if never) |
| mean_pure_gap | float | mean `pureGap` of normal agents (the realized C2 gap; should be >0 for normal, ~0 for zombie) |
| winner | enum | "normal" \| "zombie" \| "tie" (by delta_fit vs tie-band) |
| tie_band | float | \|delta_fit\| below this ⇒ tie (default 0.02) |
| win_rate | float | **[v1.1.0]** fraction of ensemble replicas where normal beats zombie by > tie_band (per-replica delta > tie_band). A per-level "normal wins" claim is licensed only when this is significantly > 0.5. |
| p_value | float | **[v1.1.0]** one-sided sign-test p that normal wins more than half the replicas: P(X≥wins) for X~Binomial(wins+losses, 0.5), counting only non-tie replicas. 1.0 if all replicas tie. |

**Statistical licensing (v1.1.0, from D-DAK-RNG / the science's citability bar):** a single-invocation result is one complexity level over `--ensemble` seeded replicas. Report `winner` from `delta_fit` vs `tie_band`, but treat the level's verdict as **corpus-grade only when `p_value < 0.05`** (or the ensemble sd-based CI on `delta_fit` excludes 0); otherwise the honest per-level verdict is **TIE**. `--ensemble 1` yields a point estimate with no significance (win_rate∈{0,1}, p_value∈{0.5,1.0}) — not citable; the science calls `--ensemble ≥20` for a claim.

**Guard (from the round-01 analysis, mandatory):** do NOT report the raw `normal/zombie` fitness *ratio* — post-extinction it is a division artifact (~1e10). Report `delta_fit` and alive-counts. Do not treat `avgGap→1` as evidence; it is definitional for a saturated bottleneck.

## CSV schema (--csv)
`replica,gen,avg_fit,max_fit,normal_fit,zombie_fit,normal_n,zombie_n,normal_alive,zombie_alive,avg_gap,avg_viability`

## Gates (declared negative-result conditions → exit 1)
| id | fires when | field |
|---|---|---|
| G-ZOMBIE-WINS | delta_fit < −tie_band (zombies beat self-modelers) | delta_fit |
| G-NO-GAP | mean_pure_gap < 0.01 for normal agents (the bottleneck isn't producing a gap — impl bug or degenerate) | mean_pure_gap |

Exit `0` when normal wins or ties with a real gap; exit `1` when a gate fires (a genuine result: e.g. at L0 the round-01 analysis found zombie-wins — that is exit 1, a *finding*, not an error); exit `2` on bad params/CUDA error.

## Determinism
Declared output is a deterministic function of (all params, seed). The RNG *mechanism* is an implementation detail (not contract-pinned); the *guarantee* is: same (params, seed) ⇒ byte-identical declared output on sm_89. The v1.1.0 implementation uses a seeded host `std::mt19937_64` for init/evolution (replica r uses seed+r, fixed draw order) and a **stateless counter-based Gaussian** for per-step neuron noise keyed by (seed+replica, agentId, neuronId, step); env layout via a purpose-keyed splitmix64. Pin block/grid config. **Caveat:** GPU floating-point reduction order is fixed (no float atomics in any reduction feeding declared output — fixed-order shared-memory tree reduction on device, index-order Kahan sum on host) so declared output is bit-stable on sm_89. Any residual cross-arch tolerance is documented in MODULE.md. Timing and progress logs are nondeclared.

**Golden hash domain (v1.1.0):** the golden hash is `blake2b` over the *canonical serialization* of `{seed, params, result, gates, verdict}` only — `tool`, `version`, and `notes` are excluded so a behavior-preserving kernel rewrite (which may bump `version`) still reproduces the golden. Floats are serialized at fixed `%.6f`; object keys emit in a fixed declared order. This canonical form is what `--golden` recomputes and compares.

## Golden
params: `someone.exe --pop 200 --gens 200 --steps 800 --N 256 --k 64 --zombie-frac 0.5 --complexity L3 --ensemble 4 --seed 20260705 --json`
recorded: `goldens/someone/` (canonical-serialized declared JSON + its blake2b hash + captured stdout). A rewrite must reproduce this hash or supersede it under two-pass review.
(Note: the golden is a *fast* config — gens 200, steps 800 — so `--golden` runs in well under the CI budget. The science calls larger configs for real experiments; those carry their own `result.lock`.)

## Change log
- v1.1.1 — [BEHAVIOR-NEUTRAL, D-020] internal: RNG kit, blake2b, serializers, reductions, CLI/golden spine migrated to `lib/` (liborrery — itself extracted verbatim FROM this tool and KAT-pinned); no flag, field, gate, or exit-code change; golden `aa5b731d` reproduced bit-identical post-migration (PATCH per semver rules).
- **v1.1.0** — 2026-07-05 (first implementation; MINOR, additive; see DECISIONS D-009). Adds two additive `result` fields — `win_rate` and `p_value` (one-sided sign test) — so a per-level verdict carries its significance in the declared output (the science's citability bar, D-DAK-RNG; round-01's fatal flaw was N=1/level with no significance). Old v1.0.0 callers are unaffected (superset output). Also (clarifications, non-behavioral): the Determinism section is made RNG-mechanism-neutral to match the impl (host mt19937_64 + stateless counter Gaussian + purpose-keyed splitmix64, no curand — removes the prototype's per-neuron state-writeback race by construction) and the **golden hash domain** is pinned to `{seed,params,result,gates,verdict}`. v1.0.0 was never implemented/frozen (no golden, no caller), so this bump is safe and models correct semver discipline for the template. The golden is frozen at v1.1.0.
- v1.0.0 — initial contract (founding session, spec-only, unimplemented). Ports dak_evolution_complex.cu to the headless envelope; adds `--ensemble`, `--complexity` enum, `--k` sweepable, deterministic reductions, gates, JSON schema. The round-01 wounded result (strong "advantage grows with complexity" NOT supported; weaker "gap wins in threat/deprivation regimes" stands) is the behavior to reproduce and sharpen with ensembles.
