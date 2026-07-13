# golden — `shoot` v1.0.0

## What is frozen
The declared output of the contract's golden invocation:
```
shoot.exe --potential harmonic --levels 6 --xmax 8 --steps 4000 --tol 1e-4 --seed 0 --json
```
The 1D **quantum-harmonic-oscillator** eigenvalue problem `-½ψ'' + ½x²ψ = Eψ`, solved by the shooting
method (fixed-step fp64 RK4 + scan/bisect on E for ψ→0 at ±8). Exact spectrum: **E_j = j + ½**.

Measured: `eigenvalues = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5]` = `oracles` exactly (all `rel_errs = 0` at `%.6f`,
`max_rel_err = 0`), `node_counts = [0,1,2,3,4,5]` (each eigenfunction has exactly j interior nodes in the
classically-allowed region). `G-ORACLE-MISMATCH` clear; `verdict = pass`.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as every ORRERY tool)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — floats
`%.6f`, arrays serialized element-by-element, fixed key order; `tool`/`version`/`notes` excluded, so a
behavior-preserving reimplementation keeps the golden. `shoot --golden` recomputes and compares.

## What it proves
1. **Determinism** — same params ⇒ byte-identical declared output (verified ≥3× byte-identical). No RNG;
   the whole declared path is fixed-step RK4 + fixed-ΔE scan + fixed-iteration bisection using only fp64
   `+,−,*,/` and `sqrt` (all IEEE correctly-rounded) → reproducible AND arch-portable (no transcendentals).
2. **The exact spectrum, in-silico** — the GPU-free shooting solver reproduces the analytic quantum
   harmonic-oscillator ladder `E_j = j + ½` to `max_rel_err = 0` (at `%.6f`), gated against the exact
   oracle (I-11), with correct node-count labeling. This is the reusable eigenvalue core (D-032) the
   leverage suite (`hsmi-stab`/`trace-born`/`carve`) and the TinyUniverse substrate ladder consume.

## Environment
Host-only C++ (fp64), built via `nvcc -O3 -arch=sm_89 shoot.cu ../../lib/envelope.cpp` (no GPU kernel;
`nvcc` compiles the host TU). CUDA 13.1, MSVC 2022. Because the declared path is `+,−,*,/`/`sqrt` only,
the golden is expected to reproduce cross-arch (unlike the transcendental/OptiX tools) — but is recorded
on the pinned toolchain for provenance (`runs/shoot_golden.result.lock`).

## Re-baseline record
- (none — v1.0.0 freeze.)
