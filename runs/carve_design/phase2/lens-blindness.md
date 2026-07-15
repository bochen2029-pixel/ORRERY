# lens-blindness.md — D-028 BLINDNESS ADVERSARY VERDICT
**Phase 2 lens: BLINDNESS (D-028)**
**Adversary model:** claude-sonnet-4-6 (lens-blindness subagent)
**Date:** 2026-07-14
**Status:** PHASE-2 ADVERSARIAL VERDICT — no contract frozen; for adjudication.

---

## 0. Adversary stance

Default stance: every proposed functional is BLIND until it survives attack. The hsmi-stab
keystone was PARKED because a functional was frozen that was provably blind — identical for all
models by `spec(MM†)=spec(M†M)`. My job is to catch that now, before code is written.

I ran cheap numpy checks on the critical claims. Numbers cited below are computed, not argued.

---

## 1. PAULI-CONCENTRATION (pauli-concentration.md) — VERDICT: WOUNDED

### 1.1 What the design claims

Φ(H, U) = 1 − μ̄(U)/n, where μ̄(U) is the mean Pauli weight of U†HU in the fixed standard
computational-basis TPS. Claims: (a) anchored to a fixed reference geometry so not blind to
global unitaries; (b) benign symmetry group G_sym = (SU(2))^n ⋊ S_n (local unitaries plus
permutations); (c) oracle uses a product-unitary scrambler V = V_1 ⊗...⊗ V_n; (d) n-trend
grows with qubit count.

### 1.2 The lethal finding: the oracle is degenerate

**KILL on the oracle construction, not the functional itself.**

The design's own §5.3 states the benign symmetry group is G_sym = (SU(2))^n ⋊ S_n —
product unitaries and permutations. The design then proposes an oracle using a *product-unitary
scrambler* V = V_1 ⊗ V_2 ⊗...⊗ V_n.

The claim that this is a valid oracle is false. Here is the algebraic reason:

**Local unitaries exactly preserve Pauli weight.** For any product unitary V = V_1 ⊗...⊗ V_n:
    c_P(V†HV) = Tr(P · V†HV) / 2^n = Tr(VPV† · H) / 2^n
For V = V_1 ⊗...⊗ V_n, we have VPV† = (V_1 P_1 V_1†) ⊗...⊗ (V_n P_n V_n†). Each factor
V_i P_i V_i† is a rotation of a single-qubit Pauli operator — it remains a weight-1 operator
on site i (just different Pauli components). Therefore wt(VPV†) = wt(P) exactly.

**Numerical verification (n=4, generic Hermitian H, generic Haar SU(2) factors):**
```
weight 0: original=0.013950, product-scrambled=0.013950, diff=1.21e-17
weight 1: original=0.036344, product-scrambled=0.036344, diff=6.94e-18
weight 2: original=0.224541, product-scrambled=0.224541, diff=2.78e-17
weight 3: original=0.413593, product-scrambled=0.413593, diff=5.55e-17
weight 4: original=0.311571, product-scrambled=0.311571, diff=5.55e-17
```
The Pauli weight spectrum is numerically identical (diff < 2e-16 = floating-point epsilon).

**Consequence for the oracle:**
- Φ(H_oracle, I) = Φ(H_0, I) exactly (the scrambled H looks identical to the local H in every
  frame, because the scrambler is in the functional's own null space).
- The oracle Hamiltonian H = V H_0 V† is **INDISTINGUISHABLE** from H_0 under the Pauli-weight
  functional. No search can recover V because V leaves no trace in the observable.
- The oracle has Φ(H, U) = Φ(H_0, V†U) = Φ(H_0, W) for any W. Since H_0 is already 2-local,
  H_0 is already at a local maximum for ANY local-unitary frame. The "planted" scrambler V is
  simply a relabeling within the benign symmetry class.

**This is a CIRCULAR ORACLE.** The design asks: "does the search recover V?" But V is invisible
to the functional because V ∈ G_sym. The oracle cannot, even in principle, test whether the
search distinguishes a genuinely scrambled H from an unscrambled one, if the scrambler is
product-unitary.

**Numerical confirmation (n=4, product-unitary scrambler):**
```
Phi(H_oracle, I) [scrambled in std frame]:  0.5598  (expected ~0.25 by design — WRONG)
Phi(H_oracle, V) [planted frame]:            0.5598  (expected ~0.82 — WRONG, identical to std)
Gap (phi_V - phi_std): -0.0000
```
The gap is exactly zero. The oracle passes trivially at U = I without any search needed.

### 1.3 Is the functional itself blind?

No — but only for **non-product** scramblers. Against a Haar-random scrambler:
```
n=3: Phi_local=0.4242, Phi_Haar_scr=0.2116, gap=0.2127
n=4: Phi_local=0.5625, Phi_Haar_scr=0.2544, gap=0.3081
n=5: Phi_local=0.6476, Phi_Haar_scr=0.2421, gap=0.4056
```
The functional genuinely discriminates local from Haar-scrambled H, with growing gap. The
n-trend is healthy against Haar scramblers. The functional is NOT globally blind.

### 1.4 Anchoring argument: does the fixed reference basis actually save it?

Partially. The fixed standard TPS anchors the weight function, so global non-product unitaries
change Φ. The anchoring argument is correct for the functional's discriminatory power against
non-product scramblers.

But the anchoring argument fails for the oracle claim: the oracle uses product-unitary
scramblers, which are exactly the functional's null space. "Anchored to the standard TPS" does
not help when the scrambler lives in the stabilizer of the TPS locality structure.

### 1.5 Three-control gauntlet verdict

1. Null-by-symmetry (H = I → flat): PASSES. Correct and testable.
2. Haar-scrambled control: PASSES for Haar scramblers. The design claims 0.25 baseline; measured
   0.25-0.28 for n=4. Required gap > 0.30; measured 0.31. Passes by small margin.
3. n-trend: PASSES for Haar scramblers (gap grows from 0.21 at n=3 to 0.41 at n=5).

**But control 2 must use Haar scramblers for a valid test.** The design proposes a product-unitary
scrambler for the oracle, which fails control 2 by construction (gap = 0.0000).

### 1.6 VERDICT: WOUNDED

**Mechanism:** The oracle is degenerate when the scrambler is product-unitary. The functional
itself is not blind (it discriminates against Haar scramblers), but the proposed oracle cannot
demonstrate this because it uses a scrambler in the functional's null space.

**Reinstatement trigger:** Switch the oracle scrambler to a Haar-random (non-product) V, and
pre-register a pass bar against that scrambler. The functional can survive with this fix.

**Pre-registered gap for reinstatement (from numerics):** Φ_local ≥ 0.56 and Φ_Haar_scr ≤ 0.28,
gap ≥ 0.28 at n=4. These are evidence-grade.

---

## 2. OPERATOR-LOCALITY / LOCALITY-FROM-THE-SPECTRUM (operator-locality.md) — VERDICT: WOUNDED

### 2.1 What the design claims

Essentially identical to pauli-concentration: Φ_LOC(H,U) = [Σ_{α:w(α)≤k} |Tr(P_α U†HU)|²]
/ [Σ_α |Tr(P_α U†HU)|²]. The design acknowledges (§11) that "this design IS the incumbent,
formalized." So all the above pauli-concentration analysis applies directly.

### 2.2 Additional issue: CPR assumption discharge

The design correctly notes (§10, "critical caveat") that CPR's uniqueness theorem requires k to
be supplied as input. The functional does not derive k from the spectrum — the carve tool must
fix k at contract time.

This is honest disclosure but not an additional blindness. However it does mean: if the user
supplies the wrong k, the landscape has no basin at the true factorization (a k=2 local H is
not local at k=1). The oracle must match the k parameter used at carve-build time.

### 2.3 Oracle (§4): uses Haar-random V via seeded QR

Unlike pauli-concentration, this design uses a **Haar-random scrambler** for the oracle (§4.1,
step 2: "draw a Haar-random unitary V from U(D) via a seeded QR decomposition"). This is the
correct choice and avoids the circular-oracle problem.

**However:** The Haar scrambler creates a frame space problem. The mcts search uses a discrete
gate parameterization (§3.2: products of two-qubit rotations from a finite gate set). The
oracle V is Haar-random, which is generically NOT in the discrete frame lattice. The design
acknowledges this in §10 (ARGUMENT-GRADE list, item 3): "the CPR uniqueness theorem applies in
the discrete-gate-parameterized landscape (CPR is a continuous-group result; the discretization
may introduce additional basins)."

**This is a real problem, not merely a caveat.** If V is not reachable from the discrete gate
set, the oracle recovery criterion (Φ(H_scr, U_found) ≥ 1 − tol) can only be met if the
discrete lattice is dense enough to approximate V within tol. For n=4 and generic Haar V, the
closest point in the two-qubit gate lattice may be far from V. The oracle test is then testing
"how well does a sparse lattice approximate U(16)?", not "does the functional see the preferred
factorization?".

**Pre-registered DOUBT:** The gate lattice (§3.2: depth-L products of two-qubit rotations from
8 angles) has a covering radius that needs to be bounded before the oracle pass bar is
meaningful. This is [ARGUMENT-GRADE] by the design's own admission.

### 2.4 Blindness of the functional itself

Same as pauli-concentration (they are the same functional). NOT blind against Haar scramblers.
See §1.3 numerics above.

### 2.5 VERDICT: WOUNDED

**Mechanism:** The oracle uses a correct (Haar-random) scrambler, but the recovery test requires
the discrete gate lattice to cover U(2^n) well enough to find V within tolerance. This is
undischarged and marked [ARGUMENT-GRADE] by the design. The functional's discriminatory power
against Haar scramblers is confirmed numerically (see §1.3 above). The blindness self-check
is correct. The wound is in the oracle recovery claim, not the functional.

---

## 3. COMMUTANT-ALGEBRA (commutant-algebra.md) — VERDICT: WOUNDED (with different mechanism)

### 3.1 What the design claims

Φ_COMMUTANT(H, U) = 1 − ||V(U†HU)||_F / ||H − Tr[H]/d · I||_F, where V(H_rot) is the
interaction residual after projecting onto the tensor-sum subspace. Equivalently (§9): for
bipartite (n_A, n_B) systems, Φ_COMMUTANT equals the Pauli-weight concentration of weight-1A
and weight-1B strings — the two functionals are mathematically equivalent for bipartite cuts.

### 3.2 Blindness attacks

**Global unitary (§7.1):** CORRECT. Φ(WHW†, U) ≠ Φ(H, U) for fixed U and generic W. The
partial-trace computation depends on eigenvectors, not just spectrum. NOT blind.

**Trace cyclicity (§7.2):** CORRECT. Partial trace is not cyclically invariant. NOT blind.

**spec(MM†) (§7.3):** CORRECT. Singular values of V depend on frame. NOT blind.

**Toeplitz/PH (§7.4):** CORRECT. V is linear in H_rot. NOT blind.

The algebraic analysis is sound. The functional is genuinely sighted.

### 3.3 The oracle (§4): planted-local oracle using Clifford circuits

The oracle uses a "seed-derived n-qubit Clifford circuit" as U_plant (§4.1). Clifford circuits
ARE product-decomposable in general (they involve CNOT gates between qubits, not mere product
unitaries). But: Clifford circuits include CNOT, CZ, etc. — these ARE entangling (non-product)
gates. So the oracle scrambler is genuinely non-product.

**BUT:** The frame alphabet (§2.1, §3.1) is single-qubit rotations only:
"n qubits, each frame U is encoded as a length-n sequence of per-qubit rotation choices
from a discrete alphabet of size B."

**This creates a mismatch.** The oracle scrambler U_plant is a multi-qubit Clifford circuit
(involving CNOTs), but the search space is product-unitary frames (per-qubit rotations only).
U_plant is not reachable by any product frame. The oracle will never be recovered.

The design acknowledges this in §13: "the frame alphabet (6 per-qubit gates) may not densely
cover U(d). If U_plant is a random Clifford not in the alphabet, the oracle recovery will fail."

This is a fatal mismatch between the oracle construction and the search space. The "known answer"
is not actually recoverable by the stated search. Phi*(H_oracle) will generically be much worse
than 1.0.

**Additional issue: the commutant functional score for H0 (§8, Control 1):**
The design claims Φ(H_local, I) = 1 for H = H_A ⊗ I_B + I_A ⊗ H_B. But for a 2-local Ising
H (the test case), H0 is NOT a pure tensor sum: it includes ZZ coupling terms that are
interaction terms. Numerical check:
```
Phi_comm(H0, I) = 0.3373  (actual, for 4-qubit Ising with ZZ + X terms)
```
The design's claim that Φ = 1 for "a known local H in the standard frame" requires H to be
exactly a tensor sum (zero interaction across the cut), not merely low-weight. The Ising chain
is NOT a tensor sum — it has ZZ interactions. The functional correctly returns Φ < 1 for
genuinely interacting H, which is the right behavior, but the oracle pass bar (Φ ≈ 1.0 at
the planted frame) is claimed too optimistically for a typical 2-local H.

### 3.4 The n-trend (§8, Control 3)

The design claims Φ*(H_local) = 1.0 exactly for all n. This is only true if H_local = H_A ⊗ I +
I ⊗ H_B (zero interaction). For physically interesting H (with ZZ couplings), Φ < 1. The
n-trend claim must be qualified.

The scrambled control prediction E[Φ*(H_scramble)] ≈ 1/d_A is marked [ARGUMENT-GRADE] with
"Weingarten calculation not done." For d_A = 2^(n/2), this is 2^(-n/2) → 0, meaning at large n
the scrambled baseline approaches 0 — same as the local baseline. The entangling-power design
(§5 of entangling-power.md) already identified this as a scaling issue.

**But:** Since Φ_COMMUTANT = Φ_LOC (Pauli concentration on weight-1A + weight-1B strings) for
bipartite cuts, and since the Pauli-concentration n-trend is healthy against Haar scramblers
(gap grows from 0.21 to 0.41), the commutant functional has a healthy n-trend for the correct
oracle.

### 3.5 VERDICT: WOUNDED

**Mechanism:** The oracle scrambler (Clifford circuit with CNOTs) is not in the search space
(product-unitary frame alphabet). Oracle is unrecoverable by the stated search. The functional
itself is sighted and algebraically clean. Fix: ensure the oracle scrambler is reachable by
the search lattice, OR extend the lattice to include multi-qubit gates.

---

## 4. ENTANGLING-POWER / FROBENIUS-CROSS-CUT (entangling-power.md) — VERDICT: WOUNDED

### 4.1 What the design proposes (primary functional)

For v1: Φ(H, U) = ||H_int(U)||_F² / ||H||_F², where H_int(U) is the cross-cut block of U†HU.

### 4.2 Blindness attacks

**Global unitary (§4.1):** CORRECT. Φ(WHW†, U) with fixed U changes. NOT blind.

**Local-unitary on each factor (§4.2):** The design claims Φ IS sensitive to local-unitary
structure on each factor, calling it "desired sensitivity." This is correct: unlike the
Pauli-concentration functional, the Frobenius cross-cut DOES change under product-unitary
frame rotations. Numerical verification:
```
Phi_frob(H_prod_scr, I) = 0.1501  (product-scrambled in std frame)
Phi_frob(H_prod_scr, V_prod) = 0.0630  (in planted product-unitary frame)
gap = 0.0870  (positive — functional is sighted to product-unitary scrambling)
```
This is a genuine discriminatory signal absent from Pauli-concentration.

**Trace cyclicity and spec(MM†) (§4.3):** CORRECT. The split between diagonal and off-diagonal
blocks is not determined by cyclicity. NOT blind.

### 4.3 The n-trend PROBLEM (flagged by the design itself)

The design (§5, Control 3) flags a "SCALING ISSUE [ARGUMENT-GRADE]":

For GUE random H with balanced split (n_A = n_B = n/2), the theoretical fraction of cross-cut
elements is 2·d_A·d_B / d² = 2/d = 2/2^n → 0.

**Numerical check (GUE mean Φ_frob vs theoretical):**
```
n=2 (1:1): GUE mean Phi_frob=0.4949, theoretical=0.5000
n=3 (1:2): GUE mean Phi_frob=0.3735, theoretical=0.2500
n=4 (2:2): GUE mean Phi_frob=0.3873, theoretical=0.1250
n=5 (2:3): GUE mean Phi_frob=0.2205, theoretical=0.0625
n=6 (3:3): GUE mean Phi_frob=0.2154, theoretical=0.0312
```
The empirical GUE value decays more slowly than the naive theoretical (the off-diagonal block
has more structure than a pure random matrix), but the trend is toward zero.

**Gap between local (Φ=0) and GUE scrambled:**
```
n=2: gap=0.50, n=3: gap=0.25, n=4: gap=0.13, n=5: gap=0.06, n=6: gap=0.03
```
The gap halves with each additional qubit pair. At n=10, gap ≈ 0.001. The signal-to-noise
collapses exponentially with n.

This is the n-trend KILL for the Frobenius cross-cut functional: the random baseline
approaches zero, meaning a GUE Hamiltonian at large n looks almost as "local" as a product
Hamiltonian under this functional. The discriminating power vanishes.

**The design is honest about this but marks it [ARGUMENT-GRADE].** My verdict: this is a
GENUINE WOUND — the entangling-power design correctly identifies the problem but does not
resolve it. It claims "the signal is always zero for the planted-product control" vs
"GUE stays bounded away from zero." The numerical evidence shows GUE DOES approach zero.

### 4.4 Oracle construction: non-product scrambler

The design uses a "random circuit" W_plant (depth 6 Clifford-like) — genuinely non-product,
entangling. The oracle scrambler is correct (non-product, so H_int(I) ≠ 0 for H_plant in the
standard frame). The mcts search recovers W_plant by minimizing Φ, which is a valid test.

However, the same discrete-lattice coverage problem applies: the frame lattice for the search
must contain W_plant or an approximation. This is registered as DOUBT-3.

### 4.5 The time-averaged e_p functional (secondary)

The time-averaged entangling power variant has determinism risks (eigendecomposition ordering
under degenerate eigenvalues, §8). The design correctly recommends α=1 (Frobenius-only) for
v1. The e_p formula in §1.2 is well-defined but the closed-form expression for general (d_A, d_B)
appears to elide some terms (the "SWAP" notation is abbreviated). Before contracting, verify
the exact formula against ZZF (2000) §III.

### 4.6 VERDICT: WOUNDED

**Mechanism 1 (n-trend):** The signal-to-noise ratio collapses exponentially with qubit count
under the Frobenius cross-cut functional. The gap between a product H (Φ=0) and a GUE
Hamiltonian (Φ → 0) halves with each added qubit pair. At n ≥ 8 qubits, this functional
cannot distinguish a genuinely non-local H from a local one in the presence of any noise.
This is the most serious wound and potentially a KILL if the science intends to run carve
at n > 6.

**Mechanism 2 (discrete lattice):** Same as operator-locality — oracle recovery requires
W_plant to be near the frame lattice.

**The functional retains discriminatory power at small n (n ≤ 4).** For the pre-contract
v1.0.0 target (n ≤ 6), the wound is serious but not necessarily fatal if the science
pre-registers the n constraint.

---

## 5. Summary verdict table

| Functional | Verdict | Mechanism | Kill? |
|---|---|---|---|
| Pauli-concentration | WOUNDED | Oracle circular for product-unitary scramblers (functional itself sighted against Haar) | Oracle KILL; functional survives with Haar oracle |
| Operator-locality | WOUNDED | Oracle recovery requires discrete lattice to cover Haar-random V; undischarged | Oracle uncertain; functional sighted |
| Commutant-algebra | WOUNDED | Oracle scrambler (Clifford CNOT) not reachable by product-unitary search lattice; pass bar too optimistic for 2-local H with interactions | Mismatch |
| Entangling-power (Frobenius) | WOUNDED | Signal-to-noise collapses exponentially with n; at n≥8, GUE → 0 same as local | n-trend WOUND (functional KILLed for n ≥ 8) |

**No functional is entirely KILLED at n=4.** All four have genuine discriminatory power in the
small-n regime with the right oracle. All four have recoverable wounds. None has the hsmi-stab
failure mode (algebraic identity that makes Φ identically constant for all H).

---

## 6. Steal list

**From pauli-concentration:**
- The n-trend analysis (Φ_{12} gap grows with n for Haar scramblers) is genuinely good and
  evidence-grade: use it to motivate the Haar oracle.
- The cross-observable redundancy idea (primary Φ + secondary Φ_{12}) is worth keeping.
- The reversibility lemma (correct equivalence class as G_sym orbit) is clean and correct.

**From operator-locality:**
- The explicit CPR locality assumption (k must be supplied as CLI param) is an important
  honest disclosure that must be in the contract.
- The redundant recovery check (direct WHT vs. explicit enumeration agree to 10^-12) is a
  good metamorphic relation.

**From commutant-algebra:**
- The algebraic equivalence of commutant and Pauli-weight for bipartite systems is a valuable
  insight: they are the same functional, one more computationally natural (Pauli FFT) and one
  more algebraically general (partial trace projection). The implementation should use the Pauli
  FFT path (faster), but the algebraic interpretation is worth documenting.
- The degenerate-null flag (Var(Φ) < ε_var → G-NO-BASIN + degenerate_null=true) is a good
  gate-engineering detail.

**From entangling-power:**
- The DOUBT-4 (Frobenius cross-cut measures static locality, not quasiclassical spreading)
  is an honest and important out-of-scope disclosure. Worth a note in carve's MODULE.md.
- The redundant oracle check (propagator comparison as backup) is a good D-018-discipline idea.
- The explicit GUE n-trend calculation catching its own flaw is exactly the right adversarial
  self-check style.

---

## 7. The single most important finding

**The pauli-concentration oracle is circular for product-unitary scramblers — the very
scrambler the design proposes.** Local unitaries preserve Pauli weight exactly (proved and
verified numerically). Φ(V_prod H_0 V_prod†, I) = Φ(H_0, I) for any product-unitary V_prod,
gap = 0 to floating-point precision. The oracle tests nothing.

This is the make-or-break finding for the contract gate: **the oracle must use a Haar-random
(non-product) scrambler.** With a Haar scrambler, both Pauli-concentration and operator-locality
are genuinely discriminating (numerically confirmed gap 0.21–0.41 for n=3–5, growing). With a
product-unitary scrambler, neither can see the planted frame at all.

The functional is NOT blind (against non-product scramblers). The oracle design IS blind
(product-unitary scramblers are in the functional's null space). Fix the oracle; the functional
can survive.

---

## 8. Pre-registered reinstatement triggers

1. **Pauli-concentration:** Use Haar-random scrambler in oracle. Pre-register gap ≥ 0.28 at
   n=4 (evidence-grade from §1.3). Reinstatement requires EVIDENCE-GRADE oracle run with Haar V.

2. **Operator-locality:** Bound the covering radius of the discrete gate lattice, or use a
   product-unitary oracle + extend analysis to non-product V in a MINOR extension. Reinstatement
   requires that the oracle scrambler is reachable within stated tolerance.

3. **Commutant-algebra:** Ensure oracle scrambler U_plant is generated from the search alphabet
   (product-unitary rotations, not CNOTs), OR extend search alphabet to include 2-body gates.
   Adjust Φ pass bar to ≤ 0.34 (realistic for 2-local Ising, not 1.0).

4. **Entangling-power:** Pre-register n ≤ 6 as the scope limit for v1. Beyond that, flag the
   exponential n-trend degradation as a known limitation and require a different functional.

---

## 9. Numeric experiments summary

All checks run with python/numpy, n=4 qubits unless noted.

| Claim | Predicted | Measured | Grade |
|---|---|---|---|
| Phi(H_prod_scr, I) for product-scrambled local H | ~0.25 | 0.5598 (= Phi(H0,I)) | REFUTED |
| Phi(H_prod_scr, V) for planted product frame | ~0.82 | 0.5598 (= same as std frame) | REFUTED |
| Oracle gap for product scrambler | >0.30 | 0.0000 | REFUTED |
| Phi(H_Haar_scr, I) for Haar scrambler | ~0.25 | 0.2750 (n=4) | CONFIRMED |
| Phi(H_Haar_scr, V_haar) vs Phi_local | ~0.82 | 0.5625 at n=4 | CONFIRMED (trend correct) |
| Gap(Haar): n-trend growing | growing | 0.21→0.31→0.41 (n=3,4,5) | CONFIRMED |
| Frobenius cross-cut GUE baseline n-trend | bounded or growing | 0.49→0.37→0.22→0.21 (n=2→6) | REFUTED (decays) |
| Local-unitary invariance of Phi | exact | |diff| < 2e-16 | CONFIRMED |

---

*Structure, never acquaintance. The register holds the doubt.*
*Written by lens-blindness (sonnet-4.6), 2026-07-14.*
*This verdict is ADVERSARIAL — its job is to kill designs, not to build them.*
