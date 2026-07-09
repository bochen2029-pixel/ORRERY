# algebra — Contract  v1.0.0

## Purpose
Reproduce the **ground-truth-checked, receipted half** of the crossed-product entropy story (science F16 / debt **D-CP**): the **UV-divergence** of the vacuum block entanglement entropy of a **critical (massless) free-boson chain**, verified against the exact CFT law `S = (c/6)·ln(chord) + const` with **central charge c = 1** (Calabrese–Cardy), with a **massive (gapped) chain as the negative control** (entropy saturates, c_eff → 0). Computed exactly (cuSOLVER eigendecomposition of the Gaussian correlators; Casini–Huerta / Bombelli–Koul–Lee–Sorkin bosonic symplectic eigenvalues) — **no Monte Carlo, no RNG**. Ports the Part-A leg of `C:\Fable_LLC\QUALIA_LAB\gym\receipts\toy_cp_divergence.py`.

**SCOPE — read before use (this tool is deliberately narrow, to NOT overclaim):**
- ✅ v1.0.0 measures the **absolute block entropy scaling** (the Type-III *symptom*: it diverges as ln L, coefficient = c/6, c=1 checked vs analytic). This is the leg the receipt checks against ground truth.
- ❌ v1.0.0 does **NOT** compute the **Part-B relative-entropy value** (the "16.23 bits"): the science **WITHDREW** that number as a *fraction-of-box-bump artifact* under its own skeptics (D-CP). The fixed-**site** relative-entropy refit (the owed fix, D-CP-CLOCK) is a planned, carefully-scoped **v1.1.0** extension — not a v1.0.0 claim.
- **III₁ caveat (confabulation guard, in `notes` + MODULE.md):** every finite-dim algebra is **Type I** (it HAS a trace and a finite entropy). This tool reproduces the cutoff-**running** signature that *forces* the crossed product; it does NOT instantiate the trace-free Type III₁ factor. F16's physics stays [PLACEMENT] (CLPW own the theorem); the qualia identification stays [BRIDGE], §III-sealed.

**Scope guard:** measures an entropy-scaling law (structure/physics), never qualia.

## Method (exact, deterministic)
Open chain `K = (−Laplacian, Dirichlet) + m²·I` (L×L). Vacuum correlators `X = ½K^(−½)`, `P = ½K^(½)` from an eigendecomposition of `K` (cuSOLVER `Dsyevd`). For the left-half block A, the bosonic symplectic eigenvalues `ν_k` are `√eig(X_A P_A)` — computed stably as `√eig(X_A^{½} P_A X_A^{½})` (a symmetric matrix; two more `Dsyevd`s, no non-symmetric eigensolve). Block entropy `S = Σ_k [(ν_k+½)ln(ν_k+½) − (ν_k−½)ln(ν_k−½)]` (nats; reported in bits). Sweep chain sizes, fit the slope `dS/d(ln L)` over the largest points ⇒ `c_measured = 6·slope`.

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --regime | enum | critical\|massive | critical | critical = massless (m²=IR regulator 1e-8), c_expected=1; massive = gapped (m²=--mass2), c_expected=0 |
| --mass2 | float | 1e-6–10.0 | 0.25 | mass² for the massive regime (ignored in critical, which pins m²=1e-8) |
| --max-size | int | 32–4096 | 1024 | largest chain length L in the sweep |
| --num-sizes | int | 3–12 | 5 | geometric sweep points (L = max/2^(n−1) … max) |
| --fit-points | int | 2–12 | 4 | number of largest sizes used for the c-fit |
| --tol | float | 0.0–1.0 | 0.15 | \|c_measured − c_expected\| gate tolerance |
| --seed | int | ≥0 | 0 | accepted for envelope uniformity; **inert** (no RNG) |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | per-size series (size, S_bits, S_nats) to PATH |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run golden params; hash; exit 0/1 |

## Output (result fields)
| field | type | meaning |
|---|---|---|
| regime | enum | echoed |
| c_expected | float | 1.0 (critical) or 0.0 (massive) |
| c_measured | float | central charge from the entropy-scaling slope (`6·dS/dlnL`) |
| c_error | float | \|c_measured − c_expected\| |
| slope_nats | float | fitted `dS/d(ln L)` in nats |
| growth_nats | float | S(max_size) − S(min_size) in nats (divergence magnitude over the sweep) |
| divergent | bool | growth_nats > 0.2 (critical: true; massive: false) |
| min_size | int | smallest L in the sweep |
| max_size | int | largest L |
| s_at_max_bits | float | block entropy at the largest L (bits) |

**Guard:** `c_measured` is checked against the *analytic* `c_expected` (ground truth), never asserted. Report `c_measured` + `c_error` + `divergent`; the divergence is a *symptom*, not the withdrawn Part-B value.

## CSV schema (--csv)
`size,S_bits,S_nats` — one row per swept chain size.

## Gates (declared negative-result conditions → exit 1)
| id | fires when | field |
|---|---|---|
| G-WRONG-C | c_error > tol — the entropy scaling does NOT match the expected central charge (mis-modelled physics, insufficient sizes, or a bug) | c_error |

Exit `0` when `c_measured` matches `c_expected` within tol (the receipted c=1 divergence / c=0 saturation reproduced); exit `1` when G-WRONG-C fires; exit `2` on bad params/CUDA/cuSOLVER error.

## Determinism
Declared output is a deterministic function of (all params). **No RNG, no wall-clock.** `K` is built exactly; cuSOLVER `Dsyevd` (double) is deterministic on sm_89 (no atomics in the declared path); eigenvalues are sorted before the entropy sum (fixed order). The c-fit is an exact least-squares slope. Byte-identical declared output on sm_89. **Caveat:** cuSOLVER results can differ in the last few ULP across CUDA/driver versions; declared floats are `%.6f` (a tolerance well above that), and any residual cross-version drift is documented in MODULE.md.

## Golden
params: `algebra.exe --regime critical --max-size 1024 --num-sizes 5 --fit-points 4 --seed 0 --json`
(critical free-boson chain, L up to 1024 ⇒ `c_measured ≈ 1.0` within tol, divergent ⇒ exit 0. cuSOLVER on ≤1024² symmetric matrices — fast.)
recorded: `goldens/algebra/` (declared hash + stdout + NOTE). Hash domain = {seed, params, result, gates, verdict}, floats `%.6f` (D-013).

## Change log
- v1.0.1 — [BEHAVIOR-NEUTRAL, D-020] internal: envelope/CLI spine migrated to `lib/` (liborrery); no flag, field, gate, or exit-code change; golden `1526918f` reproduced bit-identical 3× post-migration (PATCH per semver rules). Scope unchanged: Part A only; the withdrawn Part-B value remains excluded (D-018).
- v1.0.0 — initial contract. Part-A only: absolute block entropy c-scaling (critical c=1 divergence, verified vs Calabrese–Cardy; massive c≈0 negative control) via cuSOLVER. Explicitly excludes the withdrawn Part-B value. Planned MINOR (v1.1.0): the fixed-**site** relative-entropy finiteness (the owed D-CP refit) with the Casini–Huerta modular kernel validated against a Fock-space ground truth (the mechanism-completing leg).
