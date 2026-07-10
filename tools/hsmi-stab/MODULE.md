# MODULE — `hsmi-stab`

*Wave-1 tool #1 — the K1 probe (F-K1, "first by dignity"). Read `contracts/hsmi-stab.contract.md` (v1.0.0) first — the contract is authoritative. This MODULE carries the full math spec so a cold session implements against it with zero re-derivation.*

**Status: MODEL RETURNED TO DRAFT (D-027, 2026-07-10) → FUNCTIONAL RETURNED TO DRAFT TOO (D-028, 2026-07-10) → DEFERRED-ON-QUESTION (Q-001).** The walking skeleton is built and its infrastructure battery is green (blake2b KAT · covariance projector · many-body ground-energy cross-check 1e−9 · **Fock oracle vs Gaussian engine 3e−12 (fixed this session)** · negative control · determinism both families). D-027's probe proved the v1.0.0 *model* arrow-blind; the v1.1 session's probe battery then proved/measured the *functional* (and its natural successors) blind as well — **the leak-norm δ± is identically ±t-symmetric for every model** (`spec(MM†)=spec(M†M)`; one-sided subspace containment does not exist in finite D), the Frobenius ax+b witness dies by trace cyclicity, the spectral ax+b witness by the flip×conj congruence of Toeplitz windows, the transport element by PH self-conjugacy of the half-filled chiral sea, and the literal Wiesbrock `minspec(K̂_A−K̂_N)` is generically asymmetric (T-invariant control ratio 66 > chiral 38 — nesting monotonicity, not the arrow). Full chain: **D-028**; the replacement choice is the operator's: **QUESTIONS.md Q-001**. **No golden exists; nothing citable.** The probes stay in the code as the evidence battery (env `HSMI_PROBE=1..6`: 1 = the D-027 leak ±t table · 2 = log-lattice kernel spill+flow · 3 = Borchers spectral split · 4 = ax+b witness (Frobenius + spectral) · 5 = transport element · 6 = many-body Wiesbrock minspec).

**SESSION LOG 2026-07-10 (v1.1 session):** (1) **DONE** — the Fock-vs-Gaussian discrepancy was a back-rotation index bug in the oracle's exact-flow assembly (the σ_t back-rotation right-multiplied by `V` instead of `Vᵀ`, computing `V·ỹ·V`; one buffer index in the `xt2` loop). Printed first, per the discipline: fock=0.956152 vs gauss=0.461491 (err 4.9e−1, ±t-symmetric and nearly t-independent — the signature of a scrambled back-rotation; even at t=0 it reconstructs `c₁V²`). Post-fix: err **1.8e−12** (t=±0.7) / **3.4e−12** (t=±1.3) vs tol 1e−8 — the parity-twist suspect (a) was a red herring; the naive partial trace is exact for a number-conserving global state (parity-block-diagonal ρ_A). (2) **SUPERSEDED BY D-028/Q-001** — the model-candidate evaluation produced the functional kill-chain instead of a model (probe data below); steps (3)–(5) of the handoff are void until the operator rules on Q-001.

**Probe data (2026-07-10, the D-028 evidence — reproduce with `HSMI_PROBE=<k>`):**
- **P2 log-lattice kernel** (a∈{0.25,0.5,1.0} × m∈{32..256}): eigen-margins 0.039/0.076/0.118 inside [0,1] (clamp never active; min_c = 1−max_c exactly — PH spectrum), flow leak ±t-equal to 4 digits at every point, t-profile **m-independent** (0.0465, 0.0928, 0.1843, 0.3591 @ t=0.05..0.4 for a=0.25 at ALL m) — UV mangled, no continuum anchor.
- **P3 Borchers spectral split** (constant-free): t-inv control negsum≡possum exactly (pipeline-validating); chiral arrow 1.17→1.04 **shrinking** with n∈{16..128} — weak and wrong-shadow (constants missing).
- **P4 ax+b witness**: Frobenius `|R+|=|R−|` to 4+ digits both models all n (cyclicity theorem); spectral `|H₊|=|H₋|`, `tr(H₊³)=−tr(H₋³)` **exactly** both models all n (Toeplitz flip×conj congruence) — e.g. chiral n=128: tr(H³)=∓3.973e3.
- **P5 transport element** `|⟨e₀|U(±t)|e₁⟩|`: equal to 6 digits, chiral and t-inv, n∈{32,128} (max 0.462329/0.462329 at n=128) — PH self-conjugacy of half filling.
- **P6 Wiesbrock minspec** (constants included): chiral n=128: −0.7295 vs −27.8683 (ratio 38.2, deficit GROWING with n); **t-inv control: −0.4375 vs −28.8885 (ratio 66.0, flat)** — generic nesting monotonicity, not the arrow.

**Probe data (2026-07-10, the arrow-blindness measurement):** viol(+t)=viol(−t) to 4+ decimals at every point; e.g. n=128: t=0.05→0.1558 · 0.1→0.3042 · 0.2→0.5569 · 0.4→0.8501 · 0.8→0.9870 · 1.6→0.9984 · 3.2→0.9808 · 6.28→0.9945 (both signs identical). Also note the t-scale: leakage is O(1) by t≈0.4 even ignoring symmetry — the eventual v1.1 t_max default must be ≪ 6.28.

## Purpose
Measure the finite-D **half-sidedness violation** δ± of a standard-pair proxy and its deformation scaling δ₋(ε): the finite-dimensional projection of essay-v5 **Problem P1** — *is half-sided modular position structurally stable under deformation of the state?* Snap ⇒ **G-RIGID** fires ⇒ the theory's own falsifier F-K1 fires (exit 1: a real result, the loudest one this instrument can produce).

## SCOPE GUARD (sacred — two of them here)
1. **§III firewall:** measures an operator-algebraic stability property (structure); says nothing about whether anything feels. Verbatim in `notes`.
2. **The Type-I boundary (the `algebra` discipline):** true hsm inclusions exist ONLY in Type III₁. This tool measures the finite-D **shadow** — the violation functional on a lattice whose continuum limit carries the real structure — and the **scaling** of that shadow under deformation. It never claims the Type III₁ statement; P1's deformation-topology freedom is owned by two declared families (`mass`, `noise`).

## Contract
`contracts/hsmi-stab.contract.md` v1.0.0 + `contracts/hsmi-stab.schema.json`. Pre-contract lineage: D-026 (adopted Active for this tool's opening). Gates: G-NO-ARROW · **G-RIGID** · G-SOFT-EXPONENT; thresholds `--arrow-min/--snap-frac/--k-min` are **pre-registered** (set before running the science sweep, so a verdict is a prediction hit/miss, not a fit).

## The math, exactly (implement this; the oracle pins conventions)

**Geometry.** Open hopping chain, L = 2n sites indexed 0…L−1. Region A = sites [n, 2n). 𝒩's single-particle subspace V_N = span{e_{n+shift}, …, e_{2n−1}} within A's space C^n (site basis). Complement rows in A = the first `shift` site vectors of A.

**Hamiltonian (single-particle, real symmetric L×L).**
- Base (critical): `h[j,j+1] = h[j+1,j] = −1`, zeros elsewhere.
- `mass` family: `h[j,j] += ε·(−1)^j`.
- `noise` family: `h[j,j] += ε·η_j`, `h[j,j+1] += ε·ν_j` (symmetrized), with `η_j = counter_gauss(seed, j, 0, 0)`, `ν_j = counter_gauss(seed, j, 1, 0)` (lib D-012 kit; pure function of coordinates).

**Global state.** `Dsyevd(h) → (E_k, v_k)`; occupied = `E_k < 0` (open chain, L even ⇒ no exact zeros at ε=0; if any |E_k| < 1e−13 under deformation, occupy exactly L/2 lowest — declared tie rule). `C_global = Σ_occ v_k v_kᵀ` (real symmetric projector).

**Region + modular flow.** `C_A = C_global[n:2n, n:2n]` (n×n). `Dsyevd(C_A) → (c_i, W)`; clamp `c_i ← min(max(c_i, γ), 1−γ)`, γ = 1e−12. Modular single-particle generator `k_A = W · diag(log((1−c_i)/c_i)) · Wᵀ`; flow `U(t) = W · diag(exp(i·λ_i·t)) · Wᵀ` with `λ_i = log((1−c_i)/c_i)` (complex unitary from real eigendata — form as needed, never store all t).

**Violation.** For direction a ∈ {+1,−1}: `viol_a(t) = σ_max(B)`, `B = [rows: first shift sites of A] × [cols: V_N] of U(a·t)`, over the uniform t-grid t_j = j·t_max/(t_points−1), j=0…t_points−1 (t=0 gives 0). `δ_a = max_j viol_a(t_j)`. **delta_minus = min(δ₊,δ₋), delta_plus = max(δ₊,δ₋), flow_sign = the a achieving the min** (ties → +1; declared). For shift=1, B is a 1×(n−1) row ⇒ σ_max = its 2-norm; general shift ≤ n/4 ⇒ σ_max via the shift×shift Gram matrix's largest eigenvalue (Dsyevd or direct 1×1/2×2).

**Sweep + fit.** ε_i = i·eps_max/eps_points (i=1…eps_points) + the ε=0 locus. `y_i = delta_minus(ε_i) − delta_minus(0)`; drop y_i ≤ 1e−12 (declared floor); `fit_points` = survivors; if ≥2: least-squares of ln y on ln ε → slope `k_fit`, intercept `c_fit`; else k_fit = c_fit = 0. `growth_monotone` = y nondecreasing over the FULL grid (pre-drop). Gates per the contract.

**Determinism notes.** All heavy math is `Dsyevd` on real symmetric matrices (deterministic on sm_89 — `algebra` precedent, re-verify 3×); grids fixed; `mass` has no RNG; `noise` is counter-RNG. No float atomics anywhere (no reductions beyond eigensolver + max over a fixed grid, taken in index order).

## Oracle (I-11) — all inside `--selftest`
1. **Fock cross-check (pins conventions):** L=6, n=3, ε=0. Build the 64×64 many-body H via Jordan–Wigner from h (number-conserving ⇒ real symmetric in occupation basis; adjacent hops have trivial strings), `Dsyevd` → unique ground vector; ρ_A = partial trace over sites 0–2 (8×8, real symmetric); `Dsyevd(ρ_A)` → exact flow `σ_t(x) = ρ_A^{it} x ρ_A^{−it}`. Take x = c₁ (annihilator on region-site 1 under region-internal JW, an 8×8 real matrix); violation = HS-norm distance of σ_t(c₁) from span{c₁_ops of V_N} … precisely: `‖(1−P_span)σ_t(c₁)‖_HS / ‖c₁‖_HS` where the span is the complex linear span of {c_{n+shift},…,c_{2n−1}} region-JW annihilators. Must equal the Gaussian `‖(1−P_{V_N}) U(±t) e₁‖₂` at t ∈ {0.7, 1.3}, both directions, tol 1e−8. Assert no clamping was active (min margin of c_i from {0,1} > 1e−6 at this size). **If the sign/transpose conventions in `k_A`/`U(t)` are wrong, this check fails — that is its job.**
2. **Negative control:** replace V_N by a seeded random (n−shift)-dim subspace (counter-RNG rotation); both directions must show violation ≥ 0.2 and arrow_ratio < 2 (no arrow) at n=32.
3. **Continuum anchor:** at ε=0, delta_minus_0(n=64) < delta_minus_0(n=32) while delta_plus_0 stays within [0.5, 1] of its n=32 value ×(0.5…2) — the shadow approaches the true hsm as n grows.
4. Plus: blake2b KAT · determinism (small config, declared object identical 2×) · exit-2 range checks live in main.

## Internal design (planned; CUDA fp64 + cuSOLVER on liborrery)
Single file `hsmi-stab.cu`, the `algebra.cu` shape: host drives; `Dsyevd`/small custom kernels for the complex U(t) block products (or host-side complex BLAS-free loops at n ≤ 2048 if profiling says the GPU adds nothing at these sizes — decide at implementation, document here; determinism either way). lib: envelope/golden/CLI spine + `rng.cuh` counter-gauss. `--csv`: `eps,delta_minus,delta_plus`.

## Golden
Per the contract: `--sites 128 --shift 1 --family mass --eps-points 8 --seed 20260710 --json` (L=256 eigensolves × 9 states — seconds). Freeze after 3× byte-identical; `result.lock`; cold two-pass mandatory (citable-class — this is the keystone's tool).

## Build
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 hsmi-stab.cu ../../lib/envelope.cpp -o hsmi-stab.exe -lcusolver'
```

## Known issues / caveats
- The finite-D arrow is an approximation: delta_minus_0 > 0 always (only Type III₁ reaches 0). The tool's claims are about ratios and scaling, never "δ = 0".
- v1 keeps 𝒩 FIXED under deformation; P1's (ε,δ)-tower allows 𝒩 to move within ε — re-optimization is the planned v1.1.0 MINOR (it can only make "graceful" easier, so v1's verdict is conservative in the falsifier's favor: if v1 says graceful, re-optimization agrees; a v1 snap must be re-tested under v1.1 before the science cites it as F-K1 fired).
- Deformation families are two directions in an infinite-dimensional space of deformations; a graceful verdict is evidence, not proof, of neighborhood stability (P1 is stated in the appendix as the real theorem target).

*Sims prove structure, never acquaintance. The keystone gets measured, not asserted.*
