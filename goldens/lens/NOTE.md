# golden — `lens` v1.0.0

## What is frozen
The declared output of the contract's golden invocation:
```
lens.exe --scene bhshadow --mass 1.0 --width 1024 --height 1024 --engine both --seed 0 --json
```
(derived `extent = 1.5·√27 ≈ 7.794229`, `tol_oracle = 8·extent/(1024·√27) ≈ 0.011719`, `tol_rt_px = 64`.)

Physics: the **Schwarzschild photon-capture shadow** at the critical impact parameter
`b_crit = 3√3·M = √27·M ≈ 5.196152` (M = 1, geometric units G = c = 1). Exact capture
cross-section oracle `σ = 27π M² ≈ 84.823002`. Measured (baseline) `area_measured ≈ 84.820667`,
`area_rel_err ≈ 2.8e-5` — the pixel-discretization residual at 1024², far inside `tol_oracle`.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as every ORRERY tool)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — floats
`%.6f`, fixed key order. `tool`/`version`/`notes` excluded, so a behavior-preserving reimplementation
keeps the golden. `lens --golden` recomputes and compares.

## What it proves
1. **Determinism** — same params ⇒ byte-identical declared output (verified ≥3× byte-identical on
   the pinned toolchain). `lens` uses no RNG (`--seed` reserved); the CPU baseline `hit_pixels` is a
   pure integer pixel count (order-independent), and the OptiX RT `hit_pixels_rt` is byte-identical
   run-to-run on the pin (below).
2. **The exact GR cross-section, in-silico** — the analytic baseline reproduces the Schwarzschild
   capture cross-section `27π M²` to `area_rel_err ≈ 2.8e-5` (`G-ORACLE-MISMATCH` clear). This is the
   citable relativistic number; it is CPU-computed and **driver-independent**.
3. **RT ↔ baseline agreement (I-13 paired-oracle)** — the hardware OptiX render and the analytic
   baseline agree exactly: `hit_pixels_rt = hit_pixels = 366012`, `rt_baseline_delta = 0`,
   `rt_agrees = 1` (`G-RT-DIVERGE` clear). The RT path is trustworthy at this config.

## Honest scope (D-004) — what this golden does NOT claim
`lens` v1 **renders geometry**; it does **not** integrate curved null geodesics, and it makes **no
RT-speedup claim**. The RT path is used for the render + the I-13 cross-check only. The
geodesic-integrated (light-bending) render and the "do RT cores *accelerate* geodesic integration?"
question are the **pre-registered compute-SPIKE** in `contracts/lens.contract.md` (kill criterion:
retire the isomorphism claim if RT does not beat the fp64 CUDA baseline by ≥1.5× at matched accuracy).

## Toolchain pin (LOAD-BEARING for this golden — RT is in the declared object)
The declared object includes `hit_pixels_rt`, an OptiX hardware result. Unlike the CPU baseline it is
**toolchain-pinned**:
```
GPU arch : sm_89 (RTX 4070 Ti SUPER, 16 GB)
OptiX    : 9.1.0
driver   : 610.47
CUDA     : 13.1 (V13.1.80)
host     : MSVC 2022 (vcvars64)
```
`hit_pixels_rt` was verified byte-identical across ≥3 runs on this pin. A **driver / OptiX / GPU-arch
change may shift `hit_pixels_rt` by a few edge pixels** and legitimately fire `--golden` (exit 1) —
that is the pin's drift detector working, not a tool bug. Re-baselining requires an **operator-signed
entry below** (old hash → new hash + the new pin + reason), the same protocol as the CMake fat-binary
and cuSOLVER sm_89 pins. The CPU baseline (`hit_pixels`, `area_*`) is NOT affected by such a change.
If only the RT arm drifts, re-run with `--engine baseline` to confirm the physics is intact.

## Environment
Recorded in `runs/lens_golden.result.lock` (tool semver, binary blake2b, sm_89 + device, OptiX/CUDA
versions, host compiler, exact CLI, declared hash, git commit).

## Re-baseline record
- (none yet — v1.0.0 freeze on the pin above.)
