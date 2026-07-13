# trace-born — Contract  v1.0.0

## Purpose
Reproduce the **ground-truth-checked, mechanical core** of the Born rule from environment-assisted
redundancy (science **F15 · Born from noncontextual credence** `[DERIVATION]`; Zurek envariance +
quantum Darwinism): in a **decohering finite model** where a system's branches are redundantly recorded
across `R` environment fragments, the **normalized-trace weight over the redundancy-defined branch
projection** `w_i = Tr(Π_i ρ)/Z` reproduces the **Born weight** `|c_i|² = |⟨i|ψ⟩|²`. Two mechanical legs
are measured and cross-checked: **(Darwinism)** the redundant record read-out equals Born once decoherence
completes (off-diagonal coherence suppressed as `s^{2R}`), and **(envariance / fine-graining)** unitary
refinement of unequal *rational* weights into `M` equal-modulus micro-branches forces the coarse weight to
`w_i/M` — the receipted STEP-A/STEP-B of `toy_a1_born_finegrain.py`, sharpened, seeded, and GPU-scaled.

**SCOPE — read before use (deliberately narrow, to NOT overclaim — the `algebra` Part-A discipline):**
- ✅ v1.0.0 measures the **mechanical, analytically-anchored core**: (a) the normalized redundancy-trace
  weight reproduces `|c_i|²` at full decoherence, computed by **brute-force full-state construction +
  partial trace** and cross-checked against the exact **Gram-overlap oracle** (I-11); (b) unitary
  fine-graining genuinely equalizes unequal rational weights to `1/√M` micro-branches (the STEP-B
  construction, verified unitary); (c) at **partial decoherence** the record read-out **departs from Born**
  by a declared margin (the negative control — reproduction is *contingent on decoherence*, not automatic).
- ❌ v1.0.0 does **NOT** derive the **premise** F15 rests on — **noncontextual credence = f(local state
  alone)** (the envariance→equal-credence step; Baker 2007's circularity objection, science debt
  **D-BORN** `[OPEN/W]`). That premise is *labeled, carried in `notes` + MODULE.md, and excluded from every
  claim* — the honest residue, exactly analogous to `algebra`'s withdrawn Part-B value. This tool shows the
  **quadratic form is forced by the mechanics**; it does not show *why credence is a function of the local
  state*, and it says nothing about why a probability is *experienced*.
- **Firewall (confabulation guard, in `notes` + MODULE.md):** measuring that a trace-weight equals `|c_i|²`
  is a **structural** fact about a finite decohering model. Sims prove **structure, never acquaintance**
  (qualia). F15's placement in the theory stays [DERIVATION-with-labeled-premise]; the felt-probability
  identification stays [BRIDGE], **§III-sealed**.

## Method (exact, deterministic — brute force checked against an analytic oracle)
- **System** `S`: `d` orthonormal pointer/branch states `|i⟩`, integer weights `w_0..w_{d-1}` (counts),
  `M = Σ w_i`, amplitudes `c_i = √(w_i/M)·e^{iφ_i}` (φ from `--phase`; the golden is real, φ=0). Born target
  `p_i = w_i/M = |c_i|²`.
- **Environment** `E = R` fragments, each a `d`-level meter. Fragment records for branch `i`/`j` have inner
  product `⟨r_i|r_j⟩ = s` for `i≠j`, `1` for `i=j` (record-overlap `s = --overlap`; **`s=0` ⇒ orthonormal
  records ⇒ complete decoherence**, the `full` regime). Record vectors realized from the Gram
  `G=(1−s)I+sJ` by its exact Cholesky/eigen factor (deterministic).
- **Global decohered state** `|Ψ⟩ = Σ_i c_i |i⟩_S ⊗ |r_i⟩^{⊗R}` — a dense `d^{R+1}` complex vector, built
  explicitly (**the un-shortcut computation a skeptic trusts**; this is the GPU-scale declared path).
- **Reduced state** `ρ_S = Tr_E |Ψ⟩⟨Ψ|` by brute-force partial trace over the `d^R` environment
  configurations (fixed-order reduction, no atomics). `ρ_S[a,b] = |c_a|²δ_{ab} + c_a c_b^* s^{R}·(1−δ_{ab})`.
- **Redundancy-defined branch projection** `Π_i = I_S ⊗ |r_i⟩⟨r_i|^{⊗R}` (the objective, redundant record
  of branch `i`). **Normalized-trace weight** `w_i^{trace} = Tr(Π_i |Ψ⟩⟨Ψ|) / Σ_j Tr(Π_j |Ψ⟩⟨Ψ|)`.
- **I-11 oracle (independent, analytic):** the same weights from the closed-form Gram overlaps,
  `Tr(Π_i|Ψ⟩⟨Ψ|) = |c_i|² + s^{2R} Σ_{a≠i}|c_a|²`, with no state ever built. `oracle_max_dev` =
  max\|brute-force − analytic\| (must be ~1e-12; pins the partial-trace/projection conventions).
- **Envariance (STEP A)** `envariance_residual = ‖ C_E · S_S |Φ_eq⟩ − |Φ_eq⟩ ‖` for a canonical
  **equal-modulus** 2-branch sub-state `|Φ_eq⟩` (system swap `S_S` undone by an environment counterswap
  `C_E` carrying the phase back → ~0: the swap is *remotely erasable*). Reported alongside
  `envariance_break` = the same residual at the run's (generally **unequal**) moduli (> 0: not erasable) —
  envariance singles out equal moduli, it is not vacuous.
- **Fine-graining (STEP B)** `microbranch_flat_dev`: a genuine unitary `U_E` (block equal-superposition +
  Gram–Schmidt completion) refines the `d` branches into `M` micro-branches; the moduli must all equal
  `1/√M` (deviation `microbranch_flat_dev`) and `U_E` must be unitary (`unitarity_dev`). Equal credence per
  micro-branch (the labeled premise) then forces coarse `w_i/M = |c_i|²`.
- **cuSOLVER** `Zheevd` (complex-Hermitian — the extension of `algebra`'s real-symmetric `Dsyevd`)
  diagonalizes `ρ_S`: `rho_purity = Tr(ρ_S²) = Σ λ_k²` (the decoherence witness: → `Σ|c_i|⁴` mixed at full
  decoherence, → 1 pure at none).

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --branches | int | 2–8 | 2 | number of system branches `d` |
| --weights | int[] | each ≥1, Σ ≤ 512 | 2,3 | comma list of `d` integer branch weights `w_i` (rationals `w_i/M`; exact fine-graining). `M=Σw_i ≤ 512` in v1.0.0 (the O(M³) fine-graining witness) |
| --redundancy | int | 1–24 | 6 | number of environment record fragments `R` (Quantum-Darwinism redundancy) |
| --regime | enum | full\|partial | full | full = orthonormal records (`s=0`, complete decoherence); partial = overlapping records |
| --overlap | float | [0, 0.99] | 0.0 | record inner product `s` for the partial regime (ignored in full, which pins `s=0`) |
| --phase | float | [0, 2π) | 0.0 | common branch phase spacing φ_i = i·phase (exercises the complex-Hermitian path; golden = 0) |
| --tol | float | 0.0–1.0 | 1e-4 | `born_max_dev` gate tolerance |
| --coh-tol | float | 0.0–1.0 | 1e-6 | decoherence guard: max allowed `offdiag_max` for a `pass` |
| --seed | int | ≥0 | (required) | RNG seed; **inert** in v1.0.0 (records/weights are deterministic) — envelope uniformity |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | per-branch series (i, born_weight, trace_weight, dev) to PATH |
| --selftest | flag | | off | internal battery incl. the analytic 2-branch oracle; exit 0/1 |
| --golden | flag | | off | run golden params; hash; exit 0/1 |

## Output (`result` fields; each typed, with meaning)
| field | type | meaning |
|---|---|---|
| branches | int | `d`, echoed |
| weights | int[] | `[w_i]`, echoed |
| total_M | int | `M = Σ w_i` |
| redundancy | int | `R`, echoed |
| regime | enum | full \| partial |
| overlap | float | record overlap `s` used (0 in full) |
| born_max_dev | float | **headline** — `max_i \|w_i^{trace} − |c_i|²\|` (the redundancy-trace weight vs Born) |
| oracle_max_dev | float | brute-force vs analytic Gram oracle (I-11); ~0 or the run is SUSPECT |
| rho_purity | float | `Tr(ρ_S²)` (decoherence witness: `Σ|c_i|⁴` at full decoherence) |
| offdiag_max | float | `max_{i≠j}\|ρ_S[i,j]\|` = coherence remnant `\|c_i c_j\| s^R` (0 at full decoherence) |
| microbranch_flat_dev | float | STEP-B: `max_μ \| |amp_μ| − 1/√M \|` after fine-graining (~0 ⇒ equalized) |
| unitarity_dev | float | max deviation of the fine-graining `U_E` from unitary (~0) |
| envariance_residual | float | STEP-A: swap–counterswap residual at equal moduli (~0 ⇒ remotely erasable) |
| envariance_break | float | the same residual at the run's moduli (> 0 for unequal ⇒ envariance is non-vacuous) |
| flat_dev | float | control: `max_i \|1/d − |c_i|²\|` (democratic counter-hypothesis margin; O(1) for unequal weights) |
| objectivity_dev | float | `max_i \|w_i^{(1 fragment)} − w_i^{(all R)}\|` (redundancy objectivity; 0 at full decoherence) |
| born_reproduced | bool | `born_max_dev ≤ tol AND offdiag_max ≤ coh-tol` |

**Guard:** `w_i^{trace}` is compared to the *analytic* Born weight `|c_i|²` (ground truth), never asserted;
`oracle_max_dev` independently confirms the brute-force pipeline against the closed form (I-11). A `pass`
requires the state to be **actually decohered** (`offdiag_max ≤ coh-tol`) — a Born match on a non-decohered
(coherent) state does not count (`G-NOT-DECOHERED`).

## CSV schema (--csv)
`branch,born_weight,trace_weight,dev` — one row per system branch `i`.

## Gates (declared negative-result conditions → exit 1)
| id | fires when | value (threshold) |
|---|---|---|
| G-BORN-MISMATCH | `born_max_dev > tol` — the normalized redundancy-trace weight does **NOT** reproduce Born (a real finding: e.g. incomplete decoherence/redundancy in the `partial` regime; **the C-TRACE gun**) | born_max_dev (tol) |
| G-NOT-DECOHERED | `offdiag_max > coh-tol` — the model is not in the objective-record regime, so any Born match is not a *decoherence* result (guards against a coherent-state false pass) | offdiag_max (coh-tol) |

Exit `0` when Born is reproduced **on a decohered state** (`born_max_dev ≤ tol` and `offdiag_max ≤ coh-tol`);
exit `1` when a gate fires (a real, informative result); exit `2` on bad params / CUDA / cuSOLVER error, or
if `oracle_max_dev` exceeds the internal SUSPECT bound `1e-8` (the brute-force path disagrees with the
analytic oracle ⇒ the tool, not the physics, is wrong — I-11).

## Determinism
Declared output is a deterministic function of (all params). **No RNG in the declared path, no wall-clock**
(`--seed` is inert in v1.0.0). The global state, partial trace, and record projectors are built exactly;
the partial-trace and trace-weight reductions use a **fixed index order (no float atomics)**; cuSOLVER
`Zheevd` (double complex) is deterministic on sm_89 in the declared path; eigenvalues are sorted before the
purity sum. **Fast-math is banned (D-021/I-13).** Byte-identical declared output on the sm_89 pin. Declared
floats are `%.6f` (D-013); any last-few-ULP cuSOLVER cross-version drift is well below that and documented in
MODULE.md.

## Golden
params: `trace-born.exe --branches 2 --weights 2,3 --redundancy 6 --regime full --seed 0 --json`
(the `toy_a1_born_finegrain` canonical case: `d=2`, weights `2,3` ⇒ Born `[0.4, 0.6]`, orthonormal records
⇒ complete decoherence. Expect `born_max_dev ≈ 0`, `oracle_max_dev ≈ 0`, `offdiag_max = 0`,
`rho_purity = 0.4²+0.6² = 0.52`, `microbranch_flat_dev ≈ 0` over `M=5` micro-branches, `born_reproduced =
true`, exit 0. Brute force on a `2^7`-dim state — fast.)
recorded: `goldens/trace-born/` (declared hash + stdout + NOTE). Hash domain = {seed, params, result, gates,
verdict}, floats `%.6f` (D-013).

## Change log
- v1.0.0 — initial contract. The F15 mechanical core only: (a) normalized redundancy-trace weight vs Born
  at full decoherence via brute-force state + partial trace, I-11-checked against the analytic Gram oracle;
  (b) the STEP-A/STEP-B envariance/fine-graining witnesses; (c) the partial-decoherence negative control.
  Explicitly **excludes** the labeled noncontextual-credence premise (D-BORN, §III-sealed). Deferred to a
  planned MINOR (v1.1.0): an explicit **redundancy sweep** returning the objectivity/decoherence **scaling
  exponent** of `born_max_dev(R)` (the quantum-Darwinism analogue of `algebra`'s `c`-fit); complex/random
  seeded records; `d>8`.
