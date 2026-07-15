# lens-oracle-honesty.md — ORACLE-HONESTY Lens
**Lens:** ORACLE-HONESTY (D-018 discipline / RAYFORMER analogue)
**Applied across:** pauli-concentration, operator-locality, commutant-algebra, entangling-power
**Date:** 2026-07-14
**Author:** sonnet-4.6 subagent (lens-oracle-honesty), ORRERY Intercom D-034
**Status:** PHASE-2 ADVERSARIAL REVIEW — no contract frozen without operator approval.

---

## Grounding: what ORACLE-HONESTY demands

The charter's ORACLE-HONESTY lens asks three questions for every design:

1. **Real externality:** Is the planted oracle a KNOWN ANSWER that genuinely sits outside the
   functional — something the search must recover, not something the score defines into existence?
   The `trace-born` contract (I-11) is the gold standard: the analytic Gram-overlap oracle is
   computed by a completely independent formula (no state ever built) and must agree with the
   brute-force partial-trace to ~1e-12. The oracle is NOT self-referential.

2. **Failure-mode separation:** Does the oracle + controls actually distinguish:
   - *Search too weak* (planted answer exists, search missed it) from
   - *No preferred factorization* (the H genuinely has no basin)?
   These are the charter's two exits (G-NO-BASIN vs the planted case). If the oracle cannot
   tell them apart, G-NO-BASIN is uninterpretable.

3. **Metamorphic invariances:** Is Φ invariant under exactly the relabeling symmetries it should
   be (qubit permutations, local unitaries on each factor) — and NOT invariant under the
   scrambling group that would make it blind? Must be tested, not argued.

---

## Functional 1: PAULI-CONCENTRATION
**File:** `phase1/pauli-concentration.md`
**Functional:** Φ(H,U) = 1 − μ̄(U)/n, where μ̄(U) is mean Pauli weight of U†HU.

### Oracle quality: SURVIVED (with one declared weakness)

**Is it a real externality?**
Yes. Construction: H₀ is a seeded 2-local Ising chain (standard frame); V is a known,
seed-derived product unitary; H = V H₀ V†. The known answer is U* = V (up to G_sym).
The oracle's Φ-value at the planted answer, Φ(H,V) = Φ(H₀,I), is computable from H₀
alone — independently of the search. This is a genuine external anchor, not circular.

**Does it separate the two failure modes?**
Yes, cleanly — but only if the *random control* is run with true Haar-random scramblers.
The planted oracle has Φ* ≈ 0.82 (2-local Ising, n=4); the Haar-scrambled control has
Φ* ≈ 0.25 (n=4 analytic estimate). Gap ≈ 0.57. The pre-registered pass bar (Φ > 0.70
for the planted case, Φ < 0.40 for the random control) would clearly separate them if
both bars hold. A mcts miss on the planted case (Φ_best < 0.50) is unambiguously
"search too weak" because the true Φ-value is known to be ~0.82. This is the right
discipline — analogous to trace-born's partial-decoherence negative control.

**Metamorphic invariances:**
- G_sym = (SU(2))^n ⋊ S_n (local unitaries + permutations): Φ IS invariant under these.
  This is benign — it correctly identifies an equivalence class of physically identical
  frames. MUST be tested: run carve on H₀ in the standard frame, apply a random L ∈ G_sym,
  verify Φ(H₀, L) = Φ(H₀, I) to 1e-12.
- Global non-product unitaries: Φ is NOT invariant (documented with an explicit example in
  §5.1). This is the key sightedness — must be tested by computing Φ(H₀, CNOT) and
  confirming it differs from Φ(H₀, I).

**Redundant recovery (D-018):**
Two independent observables: (1) Φ(H, U*) = 1 − μ̄(U*)/n; (2) Φ₁₂(H, U*) = fraction of
power in weight-1 and weight-2 strings. Both must be large at the planted answer. This is a
genuine redundancy: if the search found a spurious local max that concentrates weight on
weight-3 strings, primary Φ could be moderate while Φ₁₂ is low. Disagreement = warning.

**Circularity check:** CLEAN. The oracle's known answer (V) is fixed before the tool runs.
The frame search recovers V. The verification (Φ(H,V) ≈ Φ(H₀,I)) uses the independently-
known H₀, not the search result. No circular dependency.

**Key weakness:** The mcts v1.0.1 does not yet support caller-supplied reward functions.
The oracle experiment is therefore ARGUMENT-GRADE until mcts v1.1.0 ships the
`pauli_locality` landscape. This is declared and not hidden — but it means the oracle has
not yet been demonstrated to actually work as a recover-V test. Correctly flagged.

**Verdict: SURVIVED.** Oracle is a real externality with redundant recovery and clear
failure-mode separation. Declared weakness (mcts landscape gap) is honest and labelled.

---

## Functional 2: OPERATOR-LOCALITY (Locality-from-the-Spectrum)
**File:** `phase1/operator-locality.md`
**Functional:** Φ(H,U) = Σ_{w≤k} |c_α(U)|² / Σ_α |c_α(U)|² (HS-norm fraction at weight ≤ k)

### Oracle quality: SURVIVED (nearly identical to Pauli-Concentration; one extra honesty point)

**Is it a real externality?**
Yes. Construction is essentially the same as Pauli-Concentration but with a Haar-random
scrambler V (not product-unitary restricted). This is a significant distinction: the
operator-locality design admits Haar-random V, while Pauli-Concentration v1 is restricted
to product-unitary V. Haar-random V raises the bar for the frame search (product-unitary
mcts parameterization cannot recover Haar-random V in general) but makes the oracle MORE
externally anchored: V is drawn by a seeded QR on a random Ginibre matrix — a well-defined
external random draw, not constructed to fit the search's parameterization.

**Known answer:** Φ(H_scr, V†) = Φ(H_loc, I) ≈ Φ_loc (close to 1 for sparse 2-local
H_loc). Independently computable from H_loc alone. The design states the exact recovery
criterion: |Φ(H,U_found) − 1| ≤ 0.02. This is a pre-registered bar.

**Does it separate the two failure modes?**
Yes, and more carefully than Pauli-Concentration: the random baseline is computed
analytically as C_{n,k}/4^n (e.g. ≈ 0.26 for n=4, k=2) — this is a PREDICTED value that
can be compared against the search result independently. A miss on the planted case is
"search too weak." A result consistent with the analytic baseline for a random H is
"no preferred factorization." The separation is explicit and pre-registered.

**Critical CPR locality-assumption disclosure:** This design uniquely and honestly
discloses that CPR uniqueness requires k to be *supplied* as an input. The functional
measures "preferred factorization at locality level k" — not "what is the right k?" This
is a genuine constraint the contract must make explicit and is more honest than the other
designs about the scope of the CPR backing.

**Metamorphic invariances:**
Same as Pauli-Concentration: invariant under local unitaries and factor permutations (by
the same weight-preservation argument). The reversibility lemma is proved correctly. The
rotation invariance check (§4.1 of operator-locality) is metamorphic: compute Φ via direct
WHT and via explicit matrix-element enumeration on a small example, require agreement to
1e-12. This IS a second independent computational path — genuine redundant recovery for
the COMPUTATION, not just the physics.

**Redundant recovery (D-018):** Two computation paths (WHT and explicit Pauli decomp) that
must agree to 1e-12. This is a clean D-018 implementation — it catches numerical bugs.

**Circularity check:** CLEAN. V is recorded before construction; Φ_loc is computed from
H_loc before the search. No self-reference.

**Verdict: SURVIVED.** Marginally stronger oracle discipline than Pauli-Concentration
(Haar-random V, explicit CPR-k disclosure, computational redundancy). The Haar-random V
creates a harder search challenge (declared as Doubt-3 in entangling-power) — if the mcts
product-unitary frame parameterization cannot reach Haar-random V, this oracle would fail
as a *search test*, but the oracle *as a target* is more honest.

---

## Functional 3: COMMUTANT-ALGEBRA
**File:** `phase1/commutant-algebra.md`
**Functional:** Φ(H,U) = 1 − ||V(U†HU)||_F / ||H − (Tr[H]/d)·I||_F, where V is the
interaction residual after tensor-sum projection.

### Oracle quality: WOUNDED

**Is it a real externality?**
Mostly yes. Construction: H_local = H_A ⊗ I_B + I_A ⊗ H_B (exact tensor sum, Φ = 1.0
exactly); U_plant is a seed-derived Clifford circuit; H_oracle = U_plant H_local U_plant†.
The known answer Φ(H_oracle, U_plant) = 1.0 exactly, by algebra. This is a genuine
external anchor — the answer is 1.0 by construction, independent of any search.

**The WOUND: oracle is too easy at Φ = 1.0 exactly.**
The oracle's known answer is Φ = 1.0 EXACTLY (H_local is a perfect tensor sum by
construction). This means the oracle discriminator is: did the search find ANY frame where
the residual is zero? For H_local = H_A ⊗ I + I ⊗ H_B, the interaction residual V = 0
in the correct frame. But this is an idealized case — physical Hamiltonians with nearly-
but-not-exactly tensor-sum structure (the interesting regime) will have V ≈ small but
nonzero, and the oracle says nothing about how the functional behaves near Φ = 1.

**Failure-mode separation:**
The design acknowledges both failure modes:
- G-NO-BASIN: max Φ < Φ_threshold = 0.5 (no preferred factorization)
- G-MULTI-BASIN: degenerate basins with frame distance > 0.3

The separation is present but the random control's predicted value (E[Φ*(H_scramble)] ≈
1/d_A ≈ 0.25 for n_A=2) is ARGUMENT-GRADE and backed by an incomplete derivation (the
design explicitly says "Weingarten calculation not done"). This is the primary wound: the
baseline is not pinned analytically, so the pre-registered margin of 0.4 is not formally
established. The oracle can fail to separate the two modes if the actual scrambled baseline
turns out to be higher than 0.25 (which would shrink the gap and make spurious basins
harder to exclude).

**Metamorphic invariances:**
The design correctly identifies the required invariances (local-unitary-on-A relabeling,
global phase, rescaling). HOWEVER, the key metamorphic check — that Φ(H', U') = Φ(H, U)
when H' = (V_A ⊗ I) H (V_A† ⊗ I) and U' = U (V_A ⊗ I) — is marked [ARGUMENT-GRADE]:
"must be verified algebraically in the implementation." This is correctly flagged but means
the benign-symmetry claim is not yet proven for the partial-trace formula specifically.

**Hidden G-MULTI-BASIN concern:**
The design notes that for scalar H = (c/d)·I, the functional gives 0/0 (undefined
denominator). This is a non-trivial edge case that must be gated before the oracle runs —
if the denominator is near zero, the functional is degenerate. The handling is declared
(detect denominator < ε) but the edge case reveals that the "pure interaction null" (H =
a·σ_x⊗σ_x + a·σ_y⊗σ_y) gives Φ = 0 for ALL frames — which fires G-NO-BASIN even though
this H is *not* scrambled in the Haar sense, it simply has no tensor-sum component. This
could conflate "H is a pure interaction" with "H has no preferred factorization" — the two
are physically distinct. The commutant algebra lens conflates them.

**Circularity check:** CLEAN. H_plant is constructed from H_local and U_plant; the oracle
answer (Φ=1) is set before the search runs.

**The functional equivalence admission (§9):** The design honestly states that
Φ_COMMUTANT and Pauli-weight concentration are equivalent for bipartite systems. This is
a correct mathematical observation. It weakens the case for COMMUTANT as a separate
functional but is an honest disclosure.

**Verdict: WOUNDED.** Oracle is a real externality and not circular, but: (1) the Φ=1.0
exact oracle is too idealized — it doesn't exercise the functional near its discriminating
regime; (2) the scrambled control baseline is not analytically pinned (Weingarten gap);
(3) the pure-interaction / no-basin conflation is a semantic wound; (4) the key metamorphic
invariance is argument-grade. Survives as a contributing design but not as the primary.

---

## Functional 4: ENTANGLING-POWER (Frobenius cross-cut / quasiclassicality)
**File:** `phase1/entangling-power.md`
**Functional (primary):** Φ(H,U) = ||H_int(U)||_F² / ||H||_F², where H_int(U) is the
off-diagonal (cross-cut) block of U†HU.

### Oracle quality: WOUNDED (two wounds; one potentially serious)

**Is it a real externality?**
Yes. Construction: H_local is a product Hamiltonian (single-qubit terms only, Φ = 0
exactly); W_plant is a seeded random circuit (non-product); H_plant = W_plant H_local
W_plant†. Known answer: Φ(H_plant, W_plant) = 0 exactly (because W_plant† H_plant W_plant
= H_local, which has zero cross-cut terms). This is a genuine external anchor.

**WOUND 1: Oracle is too easy at Φ = 0 exactly (same issue as COMMUTANT).**
The planted oracle tests recovery of an exact zero, not a near-minimum. The functional's
discrimination power in the interesting near-zero regime (almost-but-not-quite product H)
is untested. More critically, the pass criterion is:
  Φ(H_plant, U_found) < 0.01  OR  ||U_found - W_plant||_F < tol_U

The OR is a design choice but it means the oracle can pass if EITHER condition holds.
If Φ is near zero for multiple frames (not just W_plant), the OR condition could give
a false pass via a different frame that accidentally has low cross-cut norm. The AND
would be a stronger oracle; the OR is weaker.

**WOUND 2 (potentially serious): n-trend scaling calculation is inconsistent.**
The design attempts to compute the expected Φ for a Haar-random H and gets confused.
In §5 (Control 3), the design states:
  "The cross-cut block has d_A × d_B elements... fraction = 2 d_A d_B / (d_A d_B)² = 2/(d_A d_B)"

This is a calculation of the block-dimension fraction, NOT the expected Frobenius fraction
for a Haar-random H. For a GUE Hamiltonian, the expected ||H_int||_F²/||H||_F² equals the
fraction of off-diagonal (cross-cut) indices in the full matrix, which is approximately
2 d_A d_B / d² (since the Frobenius norm distributes uniformly over all matrix elements
under GUE). For a balanced split d_A = d_B = d/2: this is 2 (d/2)² / d² = 1/2, not
tending to zero. The design then says this "DECREASING with n" and labels it a "SCALING
ISSUE" — but then partially corrects itself. The n-trend analysis is confused and the
predicted GUE baseline is unreliable. This is a genuine oracle weakness: if the random
control baseline is not correctly predicted, the failure-mode separation is not established.

**Failure-mode separation:**
For the product-H planted case, separation is clear: min Φ = 0 for the planted answer
vs. min Φ > threshold for a Haar-random H (if the GUE baseline is correctly computed).
But the GUE baseline confusion (Wound 2) means the random control threshold is not
reliably established. A control that predicts Φ_GUE ≈ 0.5 is fine; one that predicts
Φ_GUE → 0 with n would be a near-collapse of the signal.

**Metamorphic invariances:**
Correctly identified: invariant under joint (H,U) global rotation, NOT invariant under H
only (sighted). The relabeling invariance within each factor (permuting qubits on side A)
is correctly identified and testable. Time-reversal invariance Φ(-H,U) = Φ(H,U) is correct
(squares remove sign). These are sound.

**Redundant recovery (D-018):**
The design provides a secondary check: ||exp(-iH_plant t) - U_found exp(-iH_local t) U_found†||_F < 0.1.
This is a genuine second observable — the propagators must approximately commute, confirming
U_found is dynamically correct, not just numerically coincidentally near Φ=0. This is a
strong D-018 implementation. The warning when primary passes but redundant fails is correct
protocol.

**Circularity check:** CLEAN. H_plant is constructed from H_local and W_plant; the oracle
answer (Φ=0) is set by construction before the search.

**Functional equivalence to Commutant-Algebra:**
Entangling-Power's Frobenius cross-cut variant (Φ = ||H_int||_F²/||H||_F²) is exactly
the COMMUTANT functional in disguise: the interaction residual ||V||_F² = ||H_int||_F²
for a bipartite split. The commutant §9 makes this equivalence explicit. Both designs are
mathematically the same functional expressed in two languages. This is honest but means
the tournament has two proposals for one functional; the Pauli-weight designs are a third
and fourth expression of yet another (equivalent) functional.

**Verdict: WOUNDED.** Two wounds: (1) exact-zero oracle is too easy; (2) the n-trend
GUE baseline calculation is confused and must be corrected before the random control can
establish reliable failure-mode separation. The propagator redundancy check is a genuine
D-018 strength. Fix the GUE baseline calculation (Weingarten average or explicit sampling)
before the contract gate.

---

## Cross-cutting findings

### Does any design's oracle truly separate "search too weak" from "no basin"?

| Design | Separation? | How? | Weakness |
|--------|-------------|------|----------|
| Pauli-Concentration | YES (best) | Planted Φ ≈ 0.82, Haar Φ ≈ 0.25, gap ≈ 0.57; pre-registered bars | Bars are ARGUMENT-GRADE until mcts v1.1.0 + Pauli expansion tool |
| Operator-Locality | YES (strong) | Same mechanism; analytic Haar baseline C_{n,k}/4^n | CPR-k must be supplied; bars argument-grade |
| Commutant-Algebra | PARTIAL | Φ=1 oracle vs Φ≈0.25 random; but random baseline not proven | Weingarten gap; pure-interaction conflation |
| Entangling-Power | PARTIAL | Φ=0 oracle vs GUE baseline; but GUE baseline confused | n-trend calculation inconsistent |

### G-MULTI-BASIN across all designs

All four designs correctly identify G-MULTI-BASIN (multiple degenerate basins) as a real
negative result (exit 1), not an error. This is important: CPR's uniqueness theorem has
measure-zero exceptions (dual local descriptions), and a well-formed oracle must be able
to fire G-MULTI-BASIN and mean it. The planted-scrambler oracle, by construction, has a
UNIQUE planted answer (planted with a specific V). A G-MULTI-BASIN result on the planted
oracle means either: (a) H has accidental extra symmetry (the specific H₀ was degenerate
— must be excluded in oracle construction by verifying non-degenerate coupling constants),
or (b) the search found a spurious second basin due to search noise. The oracle design
MUST guard against (a) by construction: use generic (non-degenerate) J,h coefficients.
Only Pauli-Concentration and Operator-Locality explicitly state this guard.

### Metamorphic invariances the carve contract MUST test

1. **Local-unitary invariance:** Φ(H, UL) = Φ(H, U) for all L ∈ G_sym = (SU(2))^n ⋊ S_n.
   Test: apply a random product-unitary to the optimal frame and verify Φ is unchanged to 1e-12.

2. **Factor-permutation invariance:** Φ(H, U π_σ) = Φ(H, U) for any qubit permutation σ.
   Test: permute qubit labels 1↔2, verify Φ* is unchanged.

3. **Global phase:** Φ(e^{iθ} H, U) = Φ(H, U). Trivial but must be confirmed in code.

4. **Scale invariance:** Φ(λH, U) = Φ(H, U) for λ ≠ 0. Confirmed by the Frobenius
   normalization; must be tested.

5. **Sightedness (anti-metamorphic check):** Φ(V H V†, U) ≠ Φ(H, U) for a non-product V
   with U fixed. This is the ESSENTIAL test — confirm the functional IS NOT invariant under
   the scrambling group. If this test fails, the functional is blind.

### The single most important oracle-design requirement for the contract gate

**The oracle must exercise the functional in its DISCRIMINATING REGIME, not at a trivial
extreme.** Pauli-Concentration's Φ ≈ 0.82 planted oracle is better than Commutant-
Algebra's Φ = 1.0 exactly, because 0.82 < 1 means the search genuinely has to score and
discriminate — it cannot trivially pass by finding any frame where the residual is zero.
The contract gate requirement:

> **Pre-register TWO oracle points: (1) the planted answer's Φ-value (must be large
> but not trivially 1.0 or 0.0), computed analytically from H₀ alone BEFORE the search;
> (2) the random-baseline Φ-value, pinned analytically or by 100+ Haar samples BEFORE
> the search. The gap must be > 0.3. Both values must be evidence-grade (not
> argument-grade) at the contract gate.**

This is the direct extension of trace-born's I-11 analytic Gram oracle: two independent
computations must agree, and both must be computable without ever running the search.

---

## Steal list

From each wounded or killed design, harvest what is reusable:

- **COMMUTANT:** The algebraic equivalence proof (Pauli-weight = tensor-sum residual for
  bipartite systems) is a correct theorem and should appear in the winning design's
  MODULE.md as a confirmation that the Pauli decomposition approach has an algebraically
  transparent tensor-product interpretation.

- **ENTANGLING-POWER:** The propagator-redundancy check (secondary observable =
  ||exp(-iH_plant t) - U_found exp(-iH_local t) U_found†||_F) is a strong D-018 addition
  that can be incorporated into Pauli-Concentration as a third oracle check (in addition
  to primary Φ and secondary Φ₁₂).

- **OPERATOR-LOCALITY:** The CPR-k disclosure (locality level k must be an explicit CLI
  parameter) is a contract-gate requirement that ALL designs must adopt. The winning
  design's contract must state k explicitly and not claim to derive it from the spectrum.

---

## Weighted oracle-honesty scorecard

| Design | Externality | Failure-mode separation | Metamorphic | Redundancy | Circularity | Overall |
|--------|------------|------------------------|-------------|------------|-------------|---------|
| Pauli-Concentration | STRONG | STRONG (0.57 gap, bars declared) | SOUND (argued) | GOOD (Φ+Φ₁₂) | CLEAN | **SURVIVED** |
| Operator-Locality | STRONG | STRONG + analytic Haar baseline | SOUND (proved) | STRONG (dual computation) | CLEAN | **SURVIVED** |
| Commutant-Algebra | MODERATE | PARTIAL (Weingarten gap) | PARTIAL (ARGUMENT-GRADE) | ABSENT | CLEAN | **WOUNDED** |
| Entangling-Power | MODERATE | PARTIAL (GUE baseline confused) | SOUND | GOOD (propagator check) | CLEAN | **WOUNDED** |

---

## Per-functional verdict summary

- **Pauli-Concentration:** SURVIVED — oracle is a genuine external anchor (planted product-unitary
  scrambler, independently-computable Φ at the planted frame); failure-mode separation clear with
  pre-registered bars; G_sym benign symmetry correctly identified; two independent observables
  (Φ and Φ₁₂); not circular. Declared weakness: mcts landscape gap means oracle experiment is
  argument-grade until v1.1.0.

- **Operator-Locality:** SURVIVED — oracle as above but with Haar-random V (harder and more
  honest search challenge); analytic Haar baseline C_{n,k}/4^n is the strongest failure-mode
  separator of any design; computational redundancy (WHT vs explicit Pauli decomp) is clean D-018;
  CPR-k disclosure is an honesty point no other design makes explicit.

- **Commutant-Algebra:** WOUNDED — oracle too easy (Φ=1.0 exact idealization); scrambled-control
  baseline not analytically established (Weingarten calculation missing); pure-interaction null
  conflates with Haar-scrambled null; benign metamorphic invariance is argument-grade.

- **Entangling-Power:** WOUNDED — oracle too easy (Φ=0.0 exact); n-trend GUE baseline calculation
  confused and internally inconsistent; propagator secondary observable is a genuine strength; GUE
  baseline must be corrected before oracle can establish failure-mode separation reliably.

---

## The single most important oracle requirement for the contract gate

The planted oracle must have a known Φ-value that is **strictly between the random baseline
and the theoretical maximum** — not AT the maximum. Both the planted-frame value and the
random baseline must be computed by formulas independent of the search, and the gap between
them must be ≥ 0.3, with all values evidence-grade (measured, not just argued) before
the contract is frozen. The two independent observables (primary Φ and secondary Φ₁₂ or
propagator check) must agree at the planted frame to confirm the basin is real, not
a single self-referential number.

---

*Structure, never acquaintance. The register holds the doubt.*
*Written by sonnet-4.6 lens-oracle-honesty subagent, 2026-07-14.*
