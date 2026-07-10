# hsmi-stab — Contract  v1.0.0 — **MODEL RETURNED TO DRAFT (2026-07-10; no golden was ever frozen, no caller exists — revision is safe per the D-009 precedent)**

> **D-027:** the v1.0.0 model section below is **structurally blind to the arrow it must measure** — for a real (time-reversal-invariant) Hamiltonian, `U(−t) = conj(U(t))`, so the site-basis leak norm is *provably identical* in both flow directions (measured: symmetric to 4+ decimals at every t and n). Half-sidedness is a chirality phenomenon; the proxy must break T. The v1.1.0 draft (next session) replaces the model with a **chirality-broken standard pair** — leading candidate: the chiral-fermion vacuum kernel sampled on a **logarithmic lattice** (where dilation = lattice shift; covariance becomes complex Hermitian; positivity spill must be checked against the declared clamp). Everything else in this contract — the δ± functional shape, deformation families, pre-registered gates, the Fock-oracle requirement, the Type-I scope guard — carries forward. Do not freeze any golden against the v1.0.0 model.


## Purpose
The **K1 probe** (F-K1, "first by dignity"; essay v5 Problem P1): given a finite-dimensional proxy of a standard half-sided modular inclusion, measure the **half-sidedness violation** δ±(state) and its growth **δ₋(ε)** as the state is deformed off the symmetric locus — verdict **graceful vs snap**. Rigidity (snap) is the theory's own internal falsifier: "half-sided modular position exists only exactly at maximal symmetry" would kill the construction with no experiment required.

**SCOPE (the honest Type-I boundary — the `algebra` Part-A discipline applied to K1):** true half-sided modular inclusions exist **only in Type III₁ factors**; no finite-dimensional algebra can host one. This tool therefore measures the **finite-D shadow**: on a lattice proxy whose *continuum limit* is the real structure (the Bisognano–Wichmann dilation flow of the chiral free fermion, under which the translated half-line algebra is genuinely half-sided), it quantifies (a) how nearly one-sided the finite-D modular flow already is (**the arrow**), and (b) how that near-one-sidedness **degrades under state deformation**. It answers P1's finite-D projection — the *scaling behavior* δ₋(ε) — never the Type III₁ statement itself. P1's deformation-topology freedom is owned by declaring two explicit families. Sims prove structure, never acquaintance; §III-sealed.

## The model (fixed in v1.0.0)
- **Lattice:** open free-fermion hopping chain of L = 2n sites, `H = −Σ_j (c†_j c_{j+1} + h.c.) + deformation`, half-filled ground state (critical ⇒ the massless-fermion / BW shadow). Global state = ground-state Gaussian covariance `C_global = Σ_{E_k<0} v_k v_kᵀ`.
- **Region / algebras:** 𝒜 = CAR of region A = sites [n, 2n) (the right half-line); candidate 𝒩 = CAR of A minus its first `shift` sites (the translated half-line — the canonical hsm candidate).
- **Modular flow (Gaussian):** `C_A` = restriction of C_global to A; single-particle modular generator `k_A = log((1−C_A)/C_A)` (eigenvalues clamped to [γ, 1−γ], γ = 1e−12, declared); flow `U(t) = exp(i·k_A·t)` on the single-particle space of A. The many-body flow on generators is `σ_t(c(v)) = c(U(t)v)` — **pinned against an exact Fock-space computation in the selftest** (the oracle fixes all sign/transpose conventions).
- **Violation functional:** `viol(t) = σ_max( U(t) restricted to rows ∉ 𝒩, columns ∈ 𝒩 )` — the operator norm of the flow's leakage out of 𝒩's single-particle subspace. `δ_a = max over the t-grid of viol(a·t)` for each direction a ∈ {+1, −1}; **delta_minus = min(δ₊, δ₋), delta_plus = max(δ₊, δ₋)**, with the contained direction reported as `flow_sign` (convention-free: the theory needs *an* arrow, not a sign).
- **Deformations (state moves off the locus via the Hamiltonian's ground state — always a valid state):**
  - `mass`: staggered mass `+ε·Σ_j (−1)^j c†_j c_j` (the symmetric/gap direction; deterministic, no RNG — the analogue of `algebra`'s massive control).
  - `noise`: seeded local disorder `+ε·(Σ_j η_j c†_j c_j + Σ_j ν_j (c†_j c_{j+1}+h.c.))`, η, ν ~ counter-RNG standard Gaussians keyed (seed, j, ·, ·) (the generic direction; deterministic given seed — lib D-012 kit).
- **The fit:** `y(ε) = delta_minus(ε) − delta_minus(0)` on the ε-grid; points with y ≤ 1e−12 dropped (declared floor); `k_fit`, `c_fit` = least-squares slope/intercept of log y vs log ε; `growth_monotone` = y nondecreasing on the grid.

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --sites | int | 8–2048 | 128 | n = region-A size (chain length L = 2n) |
| --shift | int | 1–n/4 | 1 | 𝒩 = A minus its first `shift` sites |
| --family | enum | mass\|noise | mass | deformation family (P1's topology freedom, owned) |
| --eps-max | float | (0, 0.5] | 0.2 | largest deformation strength |
| --eps-points | int | 3–64 | 8 | ε-grid points: **linear grid** ε_i = i·eps-max/eps-points, i = 1…eps-points (plus the ε=0 locus, always evaluated) |
| --t-max | float | (0, 20] | 6.283185 | modular-time sweep bound per direction |
| --t-points | int | 8–512 | 64 | t-grid points per direction (uniform, endpoint inclusive) |
| --k-min | float | [0, 8] | 0.5 | **pre-registered** graceful-exponent floor |
| --snap-frac | float | (0, 1] | 0.5 | snap criterion: `delta_minus(ε_1) ≥ snap-frac · delta_plus(0)` at the smallest ε |
| --arrow-min | float | ≥1 | 10.0 | locus validity: `arrow_ratio = delta_plus(0)/delta_minus(0)` must reach this |
| --seed | int | ≥0 | (required) | RNG seed (drives `noise`; inert for `mass` — envelope uniformity) |
| --json / --csv PATH / --selftest / --golden | | | | universal envelope |

## Output (`result` fields)
| field | type | meaning |
|---|---|---|
| sites, shift | int | echoed geometry |
| family | str | mass \| noise |
| flow_sign | int | which flow direction (+1/−1) was the contained one at the locus |
| delta_minus_0, delta_plus_0 | float | violation at the locus (ε=0), contained / violating direction |
| arrow_ratio | float | delta_plus_0 / delta_minus_0 (the finite-D arrow witness) |
| delta_minus_eps1, delta_minus_max | float | δ₋ at the smallest and largest ε |
| k_fit, c_fit | float | power-law fit of the δ₋ increment (c_fit = log-intercept); 0/0 if <2 usable points |
| fit_points | int | points surviving the increment floor |
| growth_monotone | bool | increment nondecreasing across the grid |
| verdict_kind | enum | graceful \| snap \| soft (soft = not snap, but k_fit < k-min or non-monotone) |

## CSV schema (--csv)
`eps,delta_minus,delta_plus` — one row per grid point, ε=0 first.

## Gates (declared negative-result conditions → exit 1)
| id | fires when | value |
|---|---|---|
| G-NO-ARROW | arrow_ratio < arrow-min at the locus — the finite-D proxy failed to exhibit half-sidedness at all (a real finding about the shadow, not an error) | arrow_ratio (thr arrow-min) |
| G-RIGID | the snap criterion: delta_minus(ε₁) ≥ snap-frac·delta_plus_0 — **the F-K1 finding**; surface loudly, it touches the keystone | delta_minus_eps1/delta_plus_0 (thr snap-frac) |
| G-SOFT-EXPONENT | not snap, but k_fit < k-min or growth non-monotone — degradation exists but fails the pre-registered graceful form (a wound, distinct from the kill) | k_fit (thr k-min) |

## Exit codes
`0` graceful (all gates clear) · `1` a gate fired (a REAL negative result — G-RIGID especially is the falsifier firing, not a bug) · `2` error (bad input, CUDA/cuSOLVER failure). Never conflate 1 and 2.

## Determinism
Declared output is a byte-identical function of (params, seed) on sm_89. `mass` family has **no RNG at all**; `noise` uses the lib counter-RNG (pure function of coordinates). cuSOLVER `Dsyevd` deterministic on sm_89 (the `algebra` precedent; re-verify 3×). Fixed t/ε grids; eigenvalue clamp γ and increment floor are declared constants. Floats `%.6f`; hash domain D-013.

## Oracle (I-11)
1. **Exact Fock-space cross-check (in `--selftest`):** at L=6 (region n=3), build the full 64-dim many-body ground state, the exact 8×8 reduced density matrix ρ_A, and the exact modular flow σ_t(x) = ρ_A^{it} x ρ_A^{−it}; the generator-level violation of c₁ against the linear span of 𝒩's generators must equal the Gaussian single-particle number (tol 1e−8, two t values, both directions). **This pins every convention in the Gaussian engine against an independent computation path.**
2. **Negative control (in `--selftest`):** a seeded random `shift`-codimension subspace in place of 𝒩 must show O(1) violation in BOTH directions (no arrow) — separating "the functional discriminates" from "the functional is trivially small".
3. **Continuum anchor (in `--selftest`):** at the critical locus, delta_minus_0 decreases as n doubles (the shadow approaches the true hsm), while delta_plus_0 stays O(1).

## Golden
params: `hsmi-stab.exe --sites 128 --shift 1 --family mass --eps-max 0.2 --eps-points 8 --t-max 6.283185 --t-points 64 --k-min 0.5 --snap-frac 0.5 --arrow-min 10 --seed 20260710 --json`
recorded: `goldens/hsmi-stab/` (declared.hash + stdout.txt + NOTE.md). Hash domain = D-013.

## Change log
- v1.0.0 — initial contract (D-026 pre-contract opened; Wave 1 tool #1). Fixed free-fermion proxy; two deformation families; pre-registered k-min/snap-frac/arrow-min; Fock oracle + negative control + continuum anchor in the selftest. Planned MINOR (v1.1.0): 𝒩 re-optimization within ε (P1's (ε,δ)-tower allows the sub-algebra to move), additional deformation families, `--scan-n` finite-size scaling output.
