# SCIENCE-HANDBACK — hsmi-stab / F-K1: the finite-D witness family is measured blind (a negative result about the falsifier's projection, not about the theory)

**From:** ORRERY tool-builder session, 2026-07-10 (Q-002 ruled: handback)
**Status of this document:** instrument-side finding chain. **No golden exists; no tool envelope was
ever frozen; nothing here is a `result.lock`-grade tool output.** The citable objects are (a) two
theorems, verifiable by reading, and (b) deterministic probe measurements, reproducible bit-for-bit
from the committed source (provenance below). The someone-S5 handback pattern applies: every claim
below is labeled by its kind.

---

## 1 · What F-K1 asked the instrument

Essay-v5 Problem P1 / F-K1: given a finite-dimensional proxy of a standard half-sided modular
inclusion (𝒩 ⊂ 𝒜, Ω), measure the half-sidedness violation δ± and its growth δ₋(ε) off the
symmetric locus — verdict graceful vs snap; snap = the theory's own internal falsifier fires.
The v1.0.0 contract projected this onto: a critical free-fermion lattice proxy, the modular flow
`U(t) = e^{ik_A t}` from `k_A = log((1−C_A)/C_A)`, and δ± = the max leak norm
`‖P_out U(±t) P_𝒩‖` over a t-grid.

## 2 · What the instrument found, claim by claim

**[THEOREM — D-027, prior session]** The v1.0.0 *model* (real hopping chain) is arrow-blind:
T-invariance gives `U(−t) = conj(U(t))`, so every site-basis leak norm is direction-symmetric.

**[THEOREM — D-028.1, this session]** The v1.0.0 *functional* is blind for **every** model: with
`P_𝒩 = P_out^⊥`, `‖P_out U(t) P_𝒩‖² = 1 − λ_min(MM†)` for `M = P_out U(t) P_out`, the reverse
direction gives `M†`, and `spec(MM†) = spec(M†M)` for square matrices. δ₊ ≡ δ₋ identically.
Corollary: **a finite-dimensional unitary that maps a subspace into itself maps it onto itself** —
one-sided containment, the defining property of a half-sided inclusion, has no finite-D existence
at the subspace level. D-027's measured symmetry was over-determined.

**[THEOREM — D-028.3]** The ax+b commutator witness `‖[k_A,k_𝒩] ∓ 2πi(k_𝒩−k_A)‖_F` is blind by
trace cyclicity (the Frobenius cross-term vanishes identically).

**[MEASURED, mechanism identified — D-028.4]** Its spectral form is exactly blind on any
Toeplitz-window model: flip×conjugation fixes every Hermitian Toeplitz covariance (a PCT-like
congruence), and chirality *forces* translation invariance (a boundary reflects the chiral branch).
Measured: `spec(H₊) = −spec(H₋)` exactly, both models, all n.

**[MEASURED — D-028.5/6 + probes P5, P6]** The mode-referenced transport element is ±symmetric to
≥6 digits on the half-filled chiral sea (PH self-conjugacy up to a rank-2, odd-distance-vanishing
1/L term). The literal Wiesbrock positivity `minspec(K̂_A − K̂_𝒩)` (constants included) is strongly
asymmetric **in both models** — T-invariant control ratio 66 > chiral 38 — i.e. it measures nesting
monotonicity, not the arrow, and the chiral deficit grows with n.

**[MEASURED — P7/P8/P9, this session, under the operator-ruled index/winding direction]**
- P7: the compression's site-basis symbol shows **zero winding** wherever its gap is open (the flow
  disperses in site space); windings appear only on collapsed-gap curves (numerical junk).
- P8: the 𝒜/𝒩 modular ladders align increasingly with n (overlap λ-spread 1.04→0.35) with **zero
  directional displacement** (frac(δ_j>0) ≈ 0.50, both models).
- P9 (Wiesbrock cocycle `V(t) = U_𝒩(t)U_𝒜(−t)`; true hsm ⟺ eigenphases one-signed): the
  T-invariant control is **exactly ±symmetric to 5 digits** — the named theorem (staggering ×
  conjugation maps V → conj V unitarily; `SkS = −k` for both half-filled generators) — and the
  random nested control is symmetric; the chiral candidate is **not one-sided**: half its phases are
  negative at every n, and the entire asymmetry is the trace drift
  `arg det V = t·(tr k_𝒩 − tr k_A)`, which **shrinks with n** (sided 1.06 → 1.04 → 1.03).
  The UV/IR sector diagnostic: eigenphase sign is uncorrelated with modular-UV weight — no hidden
  one-sided IR sector.

**[METHODOLOGICAL EXHIBIT — P9 random control]** At n=32 the *random* subspace shows a spurious
IR-sector one-sidedness of 6.9 that vanishes at n=128. Unregistered sector-mining manufactures
false arrows. Any future witness must be pre-registered before it is evaluated (D-026 discipline).

**Synthesis:** across eight functional families, every chirality-sensitive signal that survives the
exact blindness identities is a trace / free-energy-scale scalar that decays or saturates with n.
Nothing exhibits the hsm signature — one-sidedness persisting or strengthening toward the
continuum. The half-sided arrow is carried by structures a finite symmetric truncation erases
(the Fredholm index of the half-infinite compression; the semigroup property of the cocycle), not
approximates.

## 3 · What this does and does not say

- It does **NOT** falsify K1, P1, or any Type III₁ statement. The continuum structure is untouched;
  the Bisognano–Wichmann half-sided inclusion is a theorem there.
- It says: **F-K1's finite-D projection, as formulated — a single-particle modular functional of a
  symmetric finite window state — is not a well-posed witness of the arrow.** The deformation
  verdict (graceful vs snap) cannot be measured through a functional that is identically
  direction-blind, and the natural successor functionals fail their controls or fade with n.
- The Type-I scope guard stands: this instrument measures shadows and their scaling, never the
  Type III₁ claim. Structure, never acquaintance; §III-sealed.

## 4 · What a reformulation needs (the handback asks)

1. **A theory-side statement of what F-K1 firing means at finite D.** Candidates the evidence
   permits: (a) a *scaling* statement over a sequence of proxies (the witness is the n-trend, not
   any single-n number — e.g. δ₋(n) failing to decrease under deformation), with the trend's
   estimator pre-registered; (b) a **many-body / nonlinear** witness class (higher correlators,
   relative-entropy monotones along the flow) — the single-particle level is provably too
   symmetric; (c) a **pre-registered** mode-referenced form on a PH-asymmetric chiral state
   (partial right-branch filling) — possible, but the burden is to state, before measuring, why the
   asymmetry it reads is the hsm arrow and not designed-in.
2. **A model whose discretization provably carries the structure being probed** — the naive
   Nyström sampling of the Cauchy kernel destroys the UV (bounded k, m-independent spectra); a
   proper cell-projected compression is the minimum bar for any log-lattice reformulation.
3. Whichever form is chosen: it must pass the three controls this session established as the
   gauntlet — the T-invariant model exactly null *by a nameable symmetry*, the random nested
   subspace null, and the signal non-decreasing with n.

## 5 · Reproduction (deterministic; no RNG outside fixed counter-RNG seeds)

- Repo: `github.com/bochen2029-pixel/ORRERY`, commit **`c9ceedb`**; source
  `tools/hsmi-stab/hsmi-stab.cu` (git blob `f6e7c9a10b05e87be46356ada82209409ed30065`).
- Environment: RTX 4070 Ti SUPER (sm_89), CUDA 13.1 (V13.1.80), MSVC 2022 via vcvars64.
- Build (from `tools/hsmi-stab/`):
  `nvcc -O3 -arch=sm_89 hsmi-stab.cu ../../lib/envelope.cpp -o hsmi-stab.exe -lcusolver`
- Run: `HSMI_PROBE=k ./hsmi-stab.exe` for k = 1 (D-027 leak table) · 2 (log-lattice spill+flow) ·
  3 (Borchers spectral split) · 4 (ax+b witness) · 5 (transport element) · 6 (Wiesbrock minspec) ·
  7 (site-basis winding) · 8 (ladder diagnostic) · 9 (cocycle eigenphase flow + UV/IR sectors).
  Probe outputs are stderr tables; the numbers quoted above appear verbatim.
- The Fock-space oracle (fixed this session, agreement 3.4e−12) pins every Gaussian-engine
  convention these probes rely on: `./hsmi-stab.exe --selftest` (exits 1 — the two arrow checks
  fail honestly per D-027; the oracle and infrastructure checks pass).

*The instrument did its job: it measured the proxy family the theory proposed and returned a sharp,
reproducible "not this way." That is the anti-confabulation loop working — the keystone gets
measured, not asserted.*
