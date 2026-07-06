# golden — `posit` v1.0.0

## What is frozen
The declared output of the embedded golden case (the **seed cluster**), i.e. `python posit.py --golden --json`:
targets {arrow_of_time, measurement_classicality, low_entropy_start}; patchwork physics budget 4.0; unified physics budget 3.2 ⇒ **delta_physics = +0.8** at equal reach, no floating ⇒ parsimony **"win"**, verdict pass, exit 0. (overlay +1.0, total −0.2 — the overlay bridge buys nothing, by design.) This is the corpus-grade banked D-POSIT win.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as the CUDA tools)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — floats `%.6f`, fixed key order; `tool`/`version`/`notes` excluded. `params` pins the input by `case_blake2b` (a hash of the canonical case) rather than re-echoing the whole case. `python posit.py --golden` recomputes and compares.

## What it proves
1. **Determinism** — same input ⇒ byte-identical declared output (verified ≥3× byte-identical). Determinism here is *total and trivial*: exact symbolic accounting, no RNG, no wall-clock, fixed-order float sums of {1.0, 0.2, 0.0}.
2. **The Q3 parsimony instrument** — the seed cluster's +0.8 physics-layer reduction at equal reach, with the confabulation guards live (bridge cost == posit cost; no floating derivations; same reach required). `G-NO-PARSIMONY` and `G-FLOATING` both clear.

## Environment
Recorded in `runs/posit_golden.result.lock` (tool semver, source blake2b, python, the exact invocation, declared hash, git commit). Python is right here (D-005): exact symbolic accounting, no GPU.
