# MODULE — `autotune`

*The sixth ORRERY tool — the last non-backlog one; the parameter sweep / basin-finder. Python glue. Copies `someone`'s envelope/determinism/golden/two-pass shape. Read `contracts/autotune.contract.md` (v1.0.0) first — the contract is authoritative.*

**Status: DONE v1.0.0** — built, golden frozen (`c79002f2`, 3× byte-identical, exact/no-RNG), selftest green (6 checks). Real-tool mode demonstrated: it drives `ratchet` to locate its own `(1−p)ρ=p` critical point (x_located=0.2581 vs analytic 0.25).

## Purpose
Sweep one parameter over a range, evaluate an **objective** at each grid point, and **locate** a feature — an **argmax** (band/basin peak, parabolic-refined) or a **level-crossing** (threshold / critical point, linearly interpolated) — vs a **pre-registered `--target`** with a gate. The objective is EITHER a built-in analytic function (self-contained; the golden uses this) OR a real ORRERY tool subprocessed across the sweep (the compounding feature). This is the tool that makes the others compound: it drives `ratchet`/`someone`/`mcts`/`algebra` and reads a JSON metric to answer "where is the band / the critical point?" mechanically.

## SCOPE GUARD (sacred — the §III firewall)
**This locates a feature of a swept curve (a search/orchestration mechanism); it says nothing about whether anything feels (acquaintance) — §III-sealed.** Emitted verbatim in the JSON `notes`.

## Contract
`contracts/autotune.contract.md` v1.0.0 (+ `contracts/autotune.schema.json`).

## Provenance & language
New implementation (orchestration glue). **Python is right (D-019):** subprocess tools, parse JSON, locate a feature — no compute/scale/GPU, no RNG. The second Python tool (after `posit`). Reuses `posit`'s canonical-serialization / hashlib-blake2b spine.

## Internal design (as built)
- **Grid:** `x_i = lo + i·(hi−lo)/(points−1)`, i=0..points−1 (inclusive of both bounds).
- **Objective:** built-in `peak` (`exp(−((x−C)/W)²)`) or `threshold` (logistic, crosses 0.5 at C); or real-tool — `subprocess.run([tool] + fixed.split() + ["--"+sweep, x, "--json"])`, take the **last stdout line** as JSON, read `result.<metric>` (dotted lookup). A tool exit 2 (error) → autotune exit 2; exit 0 or 1 (both emit a valid envelope) → read the metric.
- **Locate:** `argmax` → the max grid index (lowest-index tie-break) with **parabolic 3-point refinement** for sub-grid precision (recovers a Gaussian center to ~4 decimals); `crossing` → the first sign-change of `f−level` with **linear interpolation** (else closest approach, so the gate catches a genuine miss).
- **Verdict:** `located_error = |x_located − target|`; `on_target = error ≤ tol`; gate `G-OFF-TARGET` fires (exit 1) when the located feature is off the pre-registered target.

## Determinism approach
Total and trivial: **no RNG, no wall-clock** in autotune. The grid is fixed; the built-in objective is exact; real-tool metrics are deterministic per the swept tool (all ORRERY tools are). `--seed` is inert for autotune itself. blake2b via `hashlib`; canonical serialization (fixed key order, `%.6f`) hand-built; hash domain {seed,params,result,gates,verdict} (D-013). Real-tool *runtime/order* is nondeclared. Verified `--golden` 3× byte-identical.

## Selftest (green — 6 checks)
blake2b KAT; `peak` argmax recovers center 0.37 (on_target, exit 0) + f_max near 1.0; `threshold` crossing-0.5 recovers center 0.62; a wrong pre-registered target → G-OFF-TARGET fires (exit 1); determinism (×2 identical). (All built-in — self-contained, no external tool needed.)

## Golden
`autotune.exe --objective peak --obj-center 0.37 --obj-width 0.12 --lo 0 --hi 1 --points 41 --locate argmax --target 0.37 --tol 0.02 --seed 0 --json` → x_located=0.370091 (parabolic-refined), on_target, exit 0. Self-contained. Frozen `c79002f2` in `goldens/autotune/`; `result.lock` in `runs/autotune_golden.result.lock`.

## Build
Python (no compile). Fenced so `harness/verify.py extract_build_cmd` discovers it:
```
python -m py_compile autotune.py
```
Then: `python autotune.py --selftest` · `python autotune.py --golden` · `python autotune.py --objective peak --target 0.37 --json` · (real tool) `python autotune.py --tool ../ratchet/ratchet.exe --sweep rho --metric p_unwrite_mc --fixed "--p 0.2 --R 3 --trials 1000000 --seed 7" --lo 0.15 --hi 0.45 --locate crossing --level 0.9 --target 0.25 --json`.

## Known issues / caveats
- `--sweep` is the flag NAME **without dashes** (`rho`, not `--rho`) — autotune prepends `--`; this sidesteps argparse rejecting a `--`-prefixed value.
- Real-tool mode runs the given exe N times (one per grid point); sweeping a slow tool (e.g. `someone`, ~8 min/point) is expensive — sweep the fast tools, or use few points. The tool's binary/source hash belongs in the *experiment's* `result.lock`, not autotune's golden (which is self-contained).
- v1.0.0 sweeps ONE parameter; multi-parameter basin maps + more locators are a planned MINOR (v1.1.0).

*Sims/searches prove structure (a located feature), never acquaintance. Build one tool right; freeze its golden; let the science call it.*
