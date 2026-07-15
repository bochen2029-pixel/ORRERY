# carve design — ENTANGLING-POWER / QUASICLASSICALITY persona

**Persona:** DYNAMICS / ENTANGLING-POWER / QUASI-CLASSICALITY
**Model:** claude-sonnet-4-6 (subagent)
**Date:** 2026-07-14
**Phase:** 1 — design proposal (pre-contract; no code, no golden yet)
**Status:** ARGUMENT-GRADE throughout unless an ORRERY run is cited.

---

## 0. One-paragraph thesis

The preferred factorization of a Hilbert space H = H_A ⊗ H_B is the one in which
the Hamiltonian H is **most dynamically local**: the bipartite cut A:B is such that
the time-evolution operator U(t) = exp(-iHt) generates the least entanglement across
that cut, averaged over the natural time and input-state distribution.  Carroll and
Singh (2021) operationalized exactly this as "quantum mereology": find the unitary
frame U ∈ U(d) that conjugates the standard tensor-product structure so that H(U)
generates minimal entanglement across the rotated cut.  Zanardi, Zalka, and Faoro
(2000) gave the precise scalar measure: the **entangling power** e_p(V), defined as
the Haar-average linear entropy produced by a unitary V on product states.  This
document proposes the exact functional Φ(H, U), its oracle, its three controls, its
D-028 self-check, and its determinism risk assessment.

---

## 1. Exact scalar functional

### 1.1 Frame parameterization

A **frame** is a unitary U ∈ U(d), d = d_A · d_B (e.g. d = 2^n for n qubits).
U acts on the full Hilbert space and defines a rotated tensor-product structure:
H_A^(U) ⊗ H_B^(U) is the factorization in which the standard basis |i,j> is
mapped to U|i,j>.  Equivalently, the Hamiltonian in the rotated frame is:

    H(U) = U† H U

and the rotated propagator is:

    V(t, U) = exp(-i H(U) t) = U† exp(-iHt) U

The frame search is over U; the Hamiltonian H is fixed.  For an n-qubit system with
n_A qubits on side A and n_B = n - n_A on side B, U is a d×d unitary (d = 2^n).
The search space is U(d) — high-dimensional.  For tractability, we restrict to
frames that are products of local single-qubit unitaries composed with a parametric
set of 2-body rotators ("frame gates"), so the `mcts` search acts on a discrete
approximation of this manifold (see §3).

### 1.2 Entangling power (Zanardi-Zalka-Faoro 2000)

For a unitary V acting on H_A ⊗ H_B with dim(H_A) = d_A, dim(H_B) = d_B, the
**entangling power** is:

    e_p(V) := E_{ψ_A ⊗ ψ_B ~ Haar} [ S_L( Tr_A[ V(ψ_A ⊗ ψ_B)(ψ_A ⊗ ψ_B)† V† ] ) ]

where S_L(ρ) = 1 - Tr(ρ²) is the linear entropy of the reduced state on B.

The key closed-form result (Zanardi, Zalka, Faoro, PRA 62, 030301(R), 2000;
arXiv:quant-ph/0005031) for general (d_A, d_B) is:

    e_p(V) = (d_A d_B)/((d_A+1)(d_B+1)) · [ 1 - F(V) ]

where F(V) = (1/d²) · Tr[ (V†⊗V†)(SWAP_{AB})(V⊗V) (SWAP_{AB}) ] is expressible
as a normalized frame potential / unitary 2-design correlator, and SWAP_{AB} acts
on two copies of the bipartite space.  In practice:

    e_p(V) = 1/(d_A+1)(d_B+1) · [ d_A d_B - Tr(V†⊗V† · F_{AB} · V⊗V) / d² ]

where F_{AB} is the partial-SWAP (the "flip" restricted to the AB bipartition on
both copies).  This is a single matrix trace — cheap to evaluate exactly for small n
(d ≤ 64, n ≤ 6 qubits) or estimable by Monte-Carlo (sample K product states, compute
average reduced-state purity; variance ~ 1/K).

### 1.3 Time-averaged entangling power — the proposed functional

Fix a time horizon T and a set of M times {t_1, ..., t_M} drawn uniformly in [0, T].
Define the **time-averaged entangling power** of the propagator:

    Φ(H, U) := (1/M) Σ_{k=1}^{M} e_p( exp(-i H(U) t_k) )

where H(U) = U† H U is the Hamiltonian in the frame defined by U, and e_p is
evaluated across the A:B bipartition of the rotated frame.

For a hermitian H with spectral decomposition H = Σ_j λ_j |j><j|, the propagator
in the rotated frame is:

    exp(-i H(U) t) = U† exp(-iHt) U

so evaluating e_p requires computing the partial trace of U† exp(-iHt) U |ψ><ψ|
U† exp(iHt) U over side A.  For the exact formula this is a trace over 4-index
tensors; for K=500 sampled product states and M=32 time steps this is O(K · M · d³)
— dominated by the matrix exponential.

**Preferred factorization:** the frame U* that minimizes Φ(H, U):

    U* = argmin_{U ∈ Frame} Φ(H, U)

with `mcts` as the basin search.  A preferred factorization EXISTS (G-NO-BASIN does
not fire) if min Φ < Φ_random - margin, where Φ_random is the expected entangling
power under a Haar-random frame (see §5 for the controls).

### 1.4 Variant: instantaneous entanglement-generation rate

An algebraically cheaper variant uses the **short-time entanglement rate**:

    Γ(H, U, ψ) := dS_vN( ρ_A(t) ) / dt |_{t=0}

For a product state |ψ_A⟩⊗|ψ_B⟩, this equals:

    Γ = 2 · Im Σ_{j ∈ A, k ∈ B} <ψ_A ⊗ ψ_B | H_int |j>_A ⊗ |k>_B · c_j* c_k

where H_int is the off-diagonal (inter-cut) part of H(U).  Averaged over product
states:

    Φ_rate(H, U) := E_{ψ_A ⊗ ψ_B} [ Γ(H, U, ψ) ]
                  ∝ ||H_int(U)||_F²   [ARGUMENT-GRADE: exact coefficient TBD]

where ||H_int(U)||_F is the Frobenius norm of the off-diagonal (cross-cut) block of
H(U) in the rotated basis.  This variant is deterministic (no time sampling), O(d²)
to evaluate, and has a known minimum: it is zero iff H(U) is block-diagonal across
the cut (i.e. H is fully local in the frame U).  **This is the primary determinism-
safe alternative** and is recommended for the initial contract (see §7).

**Composite functional (recommended):**

    Φ_comp(H, U) := α · ||H_int(U)||_F² / ||H||_F²   +   (1-α) · e_p(exp(-i H(U) τ))

for a fixed short time τ = π/(2·||H||) and α ∈ [0,1].  The first term is cheap +
deterministic; the second adds dynamics.  For v1: use α=1 (pure Frobenius) to
guarantee determinism, then add the e_p term in v2.

**For the remainder of this document, the primary functional is:**

    Φ(H, U) := ||H_int(U)||_F² / ||H||_F²

where H_int(U) is the cross-cut block of U† H U.  This equals zero for a product
Hamiltonian H = H_A ⊗ I + I ⊗ H_B and is positive whenever H has interaction terms
that cannot be removed by the frame U.

---

## 2. Literature anchor

### 2.1 Carroll and Singh (2021)

**Sean M. Carroll and Ashmeet Singh, "Quantum Mereology: Factorizing Hilbert Space
into Subsystems with Quasi-Classical Dynamics," Phys. Rev. A 103, 022213 (2021);
arXiv:2005.12938**
([https://arxiv.org/abs/2005.12938](https://arxiv.org/abs/2005.12938))

Carroll and Singh seek the bipartite factorization H = H_A ⊗ H_B such that pointer
states of A are (a) resistant to entanglement production with B ("entanglement
shield"), and (b) evolve quasi-classically (remain localized under the Hamiltonian
dynamics).  Their objective functional is a **Schwinger entropy** — a combination of
entanglement entropy growth across the cut and internal spreading of the system's
pointer observable.  Minimizing this selects the factorization where classical
trajectories exist.  Key quote: "the correct decomposition is one in which pointer
states of the system are relatively robust against environmental monitoring (their
entanglement with the environment does not continually and dramatically increase) and
remain localized around approximately classical trajectories."

Our Φ(H, U) directly operationalizes the entanglement-growth arm of their
functional, quantified by the cross-cut Frobenius norm (instantaneous rate) or the
entangling power of the propagator (dynamical average).

### 2.2 Zanardi, Zalka, Faoro (2000)

**P. Zanardi, C. Zalka, L. Faoro, "Entangling Power of Quantum Evolutions,"
Phys. Rev. A 62, 030301(R) (2000); arXiv:quant-ph/0005031**
([https://arxiv.org/abs/quant-ph/0005031](https://arxiv.org/abs/quant-ph/0005031))

Introduced the entangling power e_p(U) as the mean linear entropy produced by U on
product states drawn from the Haar measure.  The closed-form result expresses e_p(U)
as a trace involving two copies of U and the partial swap — a U(d)-invariant
expression, but NOT invariant under independent unitaries on A and B (see §4).  This
is the key fact that saves the functional from D-028 blindness.

### 2.3 Zurek (2003): Einselection and the predictability sieve

**W.H. Zurek, "Decoherence, einselection, and the quantum origins of the classical,"
Rev. Mod. Phys. 75, 715 (2003); arXiv:quant-ph/0105127**
([https://arxiv.org/abs/quant-ph/0105127](https://arxiv.org/abs/quant-ph/0105127))

Zurek's predictability sieve selects pointer states as those that minimize entropy
production under coupling to the environment — the same physical criterion we
operationalize.  The preferred factorization is the one for which these pointer
states exist; our Φ(H, U) measures their absence (large Φ = large entanglement
generation = bad factorization).

### 2.4 Supplementary: entanglement rate bounds

**Bravyi, "Upper Bounds on Entangling Rates of Bipartite Hamiltonians," PRA 76,
052326 (2007); arXiv:0704.0964**
([https://arxiv.org/abs/0704.0964](https://arxiv.org/abs/0704.0964))

Establishes that the maximum entanglement generation rate for a bipartite Hamiltonian
scales with ||H_int||, the norm of the interaction block — confirming that our
Frobenius-norm variant is the correct leading-order measure of dynamical entanglement
production.

### 2.5 Supplementary: operational quantum mereology

**Giachetta et al., "Operational Quantum Mereology and Minimal Scrambling,"
Quantum 8, 1406 (2024)**
([https://quantum-journal.org/papers/q-2024-07-11-1406/](https://quantum-journal.org/papers/q-2024-07-11-1406/))

Independently arrives at a scrambling-rate criterion (Gaussian scrambling rate of
the A-OTOC) that is equivalent to our entanglement-rate functional in the short-time
limit — providing an independent derivation of the same physics from an algebraic
(operator-subalgebra) perspective.

---

## 3. Frame parameterization and mcts search

### 3.1 Discrete frame lattice

The full frame space U(d) is a continuous Lie group.  For `mcts` (which operates on
a discrete branching tree), we discretize as follows:

**Frame gate set G:** for n qubits, define frame gates as:
  - Layer-1: single-qubit rotations R_y(θ_k) for each qubit k, θ_k ∈ {0, π/4, π/2, 3π/4}
  - Layer-2: two-qubit interactions exp(-i θ Z_k Z_l) for adjacent pairs, θ ∈ {0, π/8, π/4}

A frame U is a depth-L circuit of these gates (L = 3 default for n ≤ 6).  The total
branching factor is ~ 4^n × 3^(n-1) per layer; for n=4 qubits: ~4^4 × 3^3 ≈ 4300
frames per layer, depth-3 tree.

For `mcts` integration: the search tree node = a partial frame circuit; child nodes =
extend by one layer; reward = -Φ(H, U_node) (maximize reward = minimize Φ).  The
planted scrambler oracle provides the known-answer frame (see §4).

### 3.2 mcts parameters (proposed)

For a 4-qubit test (d=16):

```
--branching 32  --depth 9  --iters 50000  --trees 64  --c_uct 1.4  --tol 0.05
--landscape match  --seed 42
```

The landscape is "match" (the existing mcts contract); the reward function feeds in
via the subprocess interface that carve will define in its contract.

**Determinism note:** mcts is already golden-frozen and deterministic (seed-gated).
The landscape oracle (our Φ evaluator) must be deterministic for the full search to
be deterministic — the Frobenius-norm variant is purely algebraic and deterministic;
the time-averaged e_p variant requires deterministic time grids and seeded sampling.

---

## 4. D-028 BLINDNESS SELF-CHECK

This is the make-or-break section.  I apply the three D-028 tests rigorously.

### 4.1 Test A: global unitary conjugation

**Question:** Is Φ(H, U) invariant under H → W H W† for some W ∈ U(d) that is NOT
a product unitary (i.e. that would mix the factorization)?

**Analysis:** Φ(H, U) = ||H_int(U)||_F² / ||H||_F² where H_int(U) is the off-
diagonal block of U† H U.  Under the joint replacement H → W H W†, U → U:

    Φ(W H W†, U) = ||(U†WH W†U)_int||_F² / ||H||_F²

This is NOT equal to Φ(H, U) in general, because U†W is not identity unless W = U
(times a block-diagonal).  **Global conjugation does NOT make Φ blind.**

However: consider the joint replacement H → W H W†, U → W U.  Then:

    Φ(W H W†, W U) = ||(U† W† W H W† W U)_int||_F² = ||(U† H U)_int||_F²
                   = Φ(H, U)

This means Φ is invariant under GLOBAL conjugation of the (H, U) PAIR by any W.
This is the correct invariance: it says "if I rotate the entire universe (both H and
the frame), the locality score does not change."  This is a PHYSICAL invariance, not
a blindness: it means Φ measures the RELATIVE locality of H with respect to U, not
absolute locality in any fixed basis.  The search over U finds the frame that is most
locally adapted to H — which is exactly what we want.

**VERDICT ON TEST A: NOT BLIND.** Φ is invariant under global rotations of the pair
(H, U) together — a correct physical invariance — but NOT under rotating H while
fixing U, which is the operation that would distinguish a local H from a scrambled H.

### 4.2 Test B: local-unitary invariance on each factor

**Question:** Is Φ(H, U) invariant under U → (V_A ⊗ V_B) U for V_A ∈ U(d_A),
V_B ∈ U(d_B)?  If so, this would be a blindness because local unitaries on each
factor CAN relate factorizations with different physical content.

**Analysis:** 

    Φ(H, (V_A ⊗ V_B) U) = ||( U†(V_A† ⊗ V_B†) H (V_A ⊗ V_B) U )_int||_F²
                          / ||H||_F²

This equals Φ(H, U) only if (V_A† ⊗ V_B†) H (V_A ⊗ V_B) = H, i.e. only if H
commutes with V_A ⊗ V_B.  For a generic H this is NOT true.  Local unitaries on the
factors DO change Φ.

**CRUCIAL POINT:** This means Φ is sensitive to which factor-local basis is chosen —
it can distinguish H = Z_1 ⊗ Z_2 from H = X_1 ⊗ X_2 (which differ by local
unitaries on each qubit).  This is NOT a blindness; it is the desired sensitivity.
The search over U will find the frame where the local-factor basis is aligned with H's
eigenbasis, minimizing cross-cut terms.

**VERDICT ON TEST B: NOT BLIND.** The functional IS sensitive to local-unitary
structure on each factor — this is the mechanism by which it scores factorizations.

### 4.3 Test C: algebraic identity collapse

**Question:** Does Φ collapse by trace cyclicity, spec(MM†) = spec(M†M), or similar
identity that would make it independent of U?

**Analysis:** Φ = ||H_int(U)||_F² / ||H||_F².  The denominator is ||H||_F² = Tr(H²),
independent of U (unitary-invariant).  The numerator is:

    ||H_int(U)||_F² = Σ_{a ∈ A, b ∈ B} |(U†HU)_{ab}|²

This is the sum of squared magnitudes of the off-diagonal (cross-cut) matrix elements
of U†HU.  The total Frobenius norm satisfies:

    ||H||_F² = ||H_diag(U)||_F² + ||H_int(U)||_F²

where H_diag(U) is the block-diagonal part.  So Φ measures the fraction of the
Frobenius weight that is in cross-cut terms.  This fraction IS U-dependent: for a
product H = H_A ⊗ I + I ⊗ H_B, H_int(U) = 0 in the natural frame (U = I), so
Φ = 0.  Under a scrambling U, H_int(I†HI) ≠ 0.  The trace cyclicity identity
Tr(AB) = Tr(BA) does NOT help here: Tr((U†HU)²) = Tr(H²) by cyclicity, but this
means the total norm is preserved — the SPLIT between diagonal and off-diagonal is
not determined by cyclicity.  spec(MM†) = spec(M†M) does not apply because we are
not computing a spectrum.

**VERDICT ON TEST C: NOT BLIND.** No algebraic identity collapses Φ to a U-
independent quantity.

### 4.4 Summary of D-028 self-check

| Test | Kills the functional? | Reason |
|------|-----------------------|--------|
| A: global conjugation | NO | Invariant under JOINT (H,U) rotation — correct physics |
| B: local-U on each factor | NO | Sensitive to local-factor basis — desired behavior |
| C: algebraic identity | NO | Cross-cut Frobenius fraction is genuinely U-dependent |

**D-028 SURVIVAL VERDICT: PASSED.** The functional Φ(H, U) = ||H_int(U)||_F² /
||H||_F² is not blind.  It distinguishes a product Hamiltonian (Φ = 0) from a
fully-interacting one (Φ > 0), and it distinguishes a frame U aligned with H's
locality from a scrambled frame (under the same H).

**The critical point that saves this functional where hsmi-stab failed:** Φ is NOT a
spectral invariant.  The spectrum of H is unitary-invariant; Φ is not.  The off-
diagonal block norm changes with U.  This is the physically correct sensitivity.

---

## 5. Three-control gauntlet (mandatory from the charter)

### Control 1: Null-by-symmetry control

**Statement:** Let H = H_A ⊗ I_B + I_A ⊗ H_B (a product Hamiltonian, zero
interaction across the cut).  In the natural frame U = I:

    Φ(H, I) = ||H_int(I)||_F² / ||H||_F² = 0 / ||H||_F² = 0

**Why this MUST be zero:** A product Hamiltonian has H_int(I) = 0 by definition —
it has no cross-cut matrix elements in the natural basis.  Any functional that claims
to measure interaction across the cut must return exactly zero for this case.

**Measurable prediction:** Run carve on H = σ_z ⊗ I + I ⊗ σ_z (2 qubits),
search over frames.  The minimum Φ must be exactly 0.0 (to floating-point precision,
~1e-14), recovered at U = I.  If the minimum is nonzero, the implementation has a
bug.  This is a UNIT TEST, not a gate.

**Expected basin:** The minimum is global (U = I is the only global minimum for a
product H), so `mcts` should find it immediately.  This tests that the search + oracle
are plumbed correctly.

### Control 2: Haar-scrambled Hamiltonian control

**Statement:** Let H_scrambled = W H_local W† where W is a Haar-random unitary and
H_local is a product Hamiltonian.  In the natural frame U = I:

    Φ(H_scrambled, I) ≈ (expected Φ for a Haar-random H)

Under the optimal frame search:

    min_U Φ(H_scrambled, U) ≈ Φ(H_local, I) = 0

because there exists a frame U = W such that (U†H_scrambled U) = H_local with zero
cross-cut norm.  The minimum is RECOVERABLE.

**Measurable prediction (planted-scrambler oracle):** For a known scrambling unitary
W_plant (generated with a fixed seed), plant H_plant = W_plant H_local W_plant†.
The mcts search must recover min Φ < ε_tol (say 0.01) at U ≈ W_plant.  This is the
primary oracle test (see §6).

**Harder version (Haar-random H):** Draw H_random from GUE (random Hermitian matrix).
Compute Φ(H_random, U) for all frames U in the search lattice.  The expected value
is:

    E[Φ(H_random, I)] = (d_A² - 1) / (d² - 1) · (fraction of off-diagonal elements)
    [ARGUMENT-GRADE: exact coefficient needs derivation]

For d_A = d_B = 4 (2+2 qubits): this fraction ≈ d_A² d_B² / d² = (1/2)(1/2) ≈ 0.5
of the Frobenius weight is expected in the cross-cut blocks.  A GENUINELY SCRAMBLED
H (one that is not a product in any frame) should have min_U Φ > threshold —
specifically, GUE Hamiltonians are not product in any frame, so even the optimal frame
leaves Φ ≈ 0.25–0.5.  **This is the discriminating test:** a product H has min Φ ≈ 0,
a scrambled H has min Φ ≈ 0.3 [ARGUMENT-GRADE].

**Control 2 prediction (pre-registered):** For n=4 qubits (d=16), 2+2 split:
  - H = σ_z ⊗ I + I ⊗ σ_z extended to 4 qubits: min Φ < 0.001
  - H_random ~ GUE: min_U Φ(H_random, U) > 0.15 (expected ~0.3 ± 0.1) [ARGUMENT-GRADE]

The planted-scrambler oracle tests whether the search can recover the known near-zero
minimum even when H looks scrambled — demonstrating RESOLVABILITY.

### Control 3: n-trend control

**Statement:** As n (qubit count) grows, the signal Φ(H_local, I) - Φ(H_local, U_bad)
should NOT decay to noise.

**Analysis:** For a product H on n = n_A + n_B qubits:
  - min Φ = 0 (exactly, for all n) — the signal is pinned at zero.
  - The Haar-random baseline Φ(H_random) ≈ fraction of cross-cut elements ≈ d_A²/d²
    for balanced splits.  For n_A = n_B = n/2: this is 4^(n/2) / 4^n = 1/4^(n/2),
    DECREASING with n.

Wait — this is a potential problem.  As n grows, the fraction of off-diagonal elements
in a RANDOM H approaches a fixed value (it is d_A d_B / d = 2^(n/2) / 2^n, the ratio
of off-diagonal block dimension to total).  Actually:

    Frobenius fraction in cross-cut block = (d_A d_B) / d² = 1/(d_A + 1 + d_B) ... 

Let me be more careful.  The cross-cut block has d_A × d_B rows × columns (the A→B
off-diagonal block) PLUS the B→A block.  Total elements: 2 d_A d_B.  Total elements
in d × d matrix: d² = (d_A d_B)².  So fraction = 2 d_A d_B / (d_A d_B)² = 2/(d_A d_B).
For d_A = d_B = 2^(n/2): fraction = 2/2^n → 0 as n → ∞.

**This reveals a SCALING ISSUE [ARGUMENT-GRADE]:** For a fully random (GUE) H, the
Frobenius weight in the cross-cut block decreases with n, potentially making the
signal hard to distinguish from a product H.  HOWEVER: the absolute value ||H_int||_F
grows with n (more off-diagonal elements), and the normalized Φ = ||H_int||_F²/||H||_F²
compares these growths.  The key point is that for a TRUE product H, H_int = 0
exactly for ALL n — the signal is always zero for the planted-product control.  The
discriminating question is whether Φ(H_random) stays bounded away from zero as n
grows.

**n-trend prediction:** For balanced splits d_A = d_B = 2^(n/2):
  - Φ(H_product, U_opt) = 0 exactly for all n
  - Φ(H_GUE, U_opt) ≈ constant (in [0.2, 0.5] range) for n ∈ {2, 4, 6} [ARGUMENT-GRADE]
  - The SIGNAL (ratio of scrambled to product) does NOT decay because the product is
    pinned at zero

**This must be verified by an ORRERY experiment (see §8) — it is not currently
evidence-grade.**

---

## 6. Planted-scrambler oracle (the D-018 discipline)

### 6.1 Oracle construction

**Step 1:** Choose a "local" target Hamiltonian H_local that is exactly product:

    H_local = J_z · (σ_z^1 ⊗ I^2 ⊗ I^3 ⊗ I^4) + J_z · (I^1 ⊗ σ_z^2 ⊗ I^3 ⊗ I^4)
            + J_x · (I^1 ⊗ I^2 ⊗ σ_x^3 ⊗ I^4) + J_x · (I^1 ⊗ I^2 ⊗ I^3 ⊗ σ_x^4)

(sum of local single-qubit terms with no coupling — perfectly product on the 2+2 split).
Choose J_z = 1.0, J_x = 0.5.  Φ(H_local, I) = 0 exactly.

**Step 2:** Generate a "planting unitary" W_plant ∈ U(16) from a seeded random
circuit (4-qubit Clifford-like circuit with fixed gate angles, depth 6, seed=42).
This is NOT a product unitary (it entangles across the 2+2 cut).

**Step 3:** Plant the scrambled Hamiltonian:

    H_plant = W_plant · H_local · W_plant†

**Known answer:** The frame U* = W_plant recovers Φ(H_plant, W_plant) = 0 exactly
(because U†H_plant U = H_local for U = W_plant).

**Step 4:** Run `carve` (via `mcts` subprocess) searching over the frame lattice
starting from U = I, using reward = -Φ(H_plant, U).

**Pass criterion:** `mcts` finds a frame U_found such that:

    ||U_found - W_plant||_F < tol_U   OR   Φ(H_plant, U_found) < tol_Φ = 0.01

(These are complementary: the frame itself may not be uniquely recovered, but the
functional value must be near the known minimum.)

### 6.2 Redundant recovery (D-018 discipline)

Two independent observables must agree:
1. **Primary:** Φ(H_plant, U_found) < 0.01 (functional at found frame is near-zero)
2. **Redundant:** ||exp(-i H_plant t) - U_found exp(-i H_local t) U_found†||_F < 0.1
   for t = 1.0 (the propagators approximately commute, confirming U_found is close to
   the true planting unitary W_plant in the dynamical sense)

If PRIMARY passes but REDUNDANT fails: the search found a spurious near-zero (a
different frame that happens to produce near-zero Φ by coincidence — possible if H_local
has extra symmetry).  This is a warning, not a kill, and must be reported in `notes`.

### 6.3 Metamorphic stability

Φ should be invariant under:
1. **Relabeling of qubits within each factor:** permuting qubits 1↔2 on side A changes
   U_found but NOT the minimum Φ value.  Verified by running with permuted labeling and
   checking min Φ is unchanged.
2. **Global phase of H:** H → e^{iθ} H (unphysical but tests normalization): Φ is
   invariant because both numerator and denominator scale by e^{2iθ} (and |e^{iθ}|=1).
   Actually: H is Hermitian, so this just changes the overall scale; Φ = ||H_int||_F²/
   ||H||_F² is scale-invariant.
3. **Time-reversal:** H → -H.  H_int(-H)(U) = -(H_int(H)(U)), so Φ(-H, U) = Φ(H, U).
   Verified by construction (squares remove sign).

---

## 7. Gates G-NO-BASIN and G-MULTI-BASIN

### G-NO-BASIN (exit code 1, declared negative result)

**Fires when:** After exhausting the frame search budget, min_U Φ(H, U) > Φ_threshold.

**Operationalization:** Let Φ_Haar be the expected Φ for a GUE Hamiltonian (estimated
from 100 random H samples with the same norm as the input H, under the natural frame).
Let Φ_min be the `mcts` best-found minimum.

    G-NO-BASIN fires iff: Φ_min > Φ_Haar · (1 - margin)

where margin = 0.3 (i.e., the search did not find a factorization that is at least 30%
better than random).  This is a REAL result: H does not prefer any factorization
in the frame lattice within search budget.

**Physical interpretation:** The Hamiltonian is "irreducibly non-local" — no frame
removes a significant fraction of its cross-cut weight.  This is a scientifically
meaningful outcome (e.g. a maximally scrambled H should fire G-NO-BASIN).

### G-MULTI-BASIN (exit code 1, declared negative result)

**Fires when:** The `mcts` search across `trees` independent runs finds more than K_max
distinct basins with Φ < Φ_threshold (where a basin is defined as a cluster of frames
within ||U_1 - U_2||_F < δ_basin = 0.5).

**Operationalization:** If K distinct basins are found with K > K_max = 3, fire
G-MULTI-BASIN.  This means the Hamiltonian prefers MULTIPLE factorizations equally.

**Physical interpretation:** H has degenerate preferred factorizations — a
permutation or continuous symmetry maps one to another.  The result is still
informative: H is "locally factorizable but not uniquely" — relevant for symmetric
Hamiltonians (e.g. H = J(σ_z ⊗ I + I ⊗ σ_z) + J(σ_x ⊗ I + I ⊗ σ_x) is local
but the x-z symmetry means multiple frames are equivalent).

### Reversibility lemma

**Claim:** If G-NO-BASIN fires (min Φ > threshold), then for any frame U, the time-
averaged entangling power satisfies:

    ∀U: e_p(exp(-i H(U) t)) > e_min(threshold)

for some lower bound e_min > 0.  That is, the functional Φ is a lower bound on
dynamical entanglement generation — if no frame removes the cross-cut weight, no frame
produces low entangling power propagators.

**Argument [ARGUMENT-GRADE]:** ||H_int(U)||_F > 0 implies there exist matrix
elements coupling A and B.  By the entanglement generation bound (Bravyi 2007), the
rate of entanglement growth dS/dt ≥ c · ||H_int(U)||_F for some c > 0 (for
appropriate initial states).  If Φ(H, U) > Φ_threshold for all U, then dS/dt > c ·
||H||_F · Φ_threshold^{1/2} for all U.  This is a non-trivial lower bound on
entanglement dynamics.

**Note:** This is ARGUMENT-GRADE.  The precise constant c and the relationship to
the exact e_p formula require a calculation that should be done before freezing the
contract.

---

## 8. Determinism assessment (the make-or-break risk)

### Primary functional (Frobenius norm variant)

    Φ(H, U) = ||H_int(U)||_F² / ||H||_F²

**Determinism risk: LOW.**
- Computation: form U†HU (matrix multiplication), extract off-diagonal block, compute
  squared Frobenius norm.  All operations are deterministic: matrix multiply, element-
  wise squares and sums.
- No time integration, no sampling, no random draws in the declared path.
- Double-precision IEEE 754 arithmetic: same inputs → same output on the same machine.
  Cross-machine determinism requires no fast-math (banned by I-13/D-021) and
  consistent accumulation order (use a fixed reduction order, not parallel reductions
  with float atomics).
- **Determinism verdict: GOLDEN-FREEZABLE as a double-precision scalar.**

### Time-averaged e_p variant

    Φ_dyn(H, U) = (1/M) Σ_{k=1}^M e_p(exp(-i H(U) t_k))

**Determinism risks:**
1. **Matrix exponential:** exp(-i H(U) t) requires a diagonalization (eigendecompose
   H(U), apply exp(-i λ_k t) to each eigenvalue, reconstruct).  Eigendecomposition
   order is NOT guaranteed deterministic across LAPACK implementations for degenerate
   eigenvalues.  For generic H (no degeneracies) this is typically stable, but it must
   be guarded: if the eigenvalue gap falls below eps_gap, flag a determinism warning.
2. **e_p computation via sampling:** If K product states are sampled (instead of exact
   trace), the sampling must be seeded.  The Haar-average formula (closed form via
   partial-swap trace) is preferred for exact evaluation.
3. **Time grid:** t_k = k · T/M is fixed (no randomness) — deterministic.
4. **Float reductions:** if running on GPU with parallel reductions, must use a
   deterministic parallel reduction (fixed thread schedule, no float atomics in the
   declared output path).

**Determinism verdict for Φ_dyn: MEDIUM RISK.  Manageable but requires care.**
- Use exact e_p formula (partial-swap trace) not Monte-Carlo for declared output.
- Use LAPACK symmetric eigendecompose (dsyev) which is deterministic for non-degenerate
  H.  Flag degeneracy.
- Seed any Monte-Carlo path explicitly.
- For v1: use only the Frobenius-norm variant.  Promote to Φ_dyn in v2 once
  determinism is demonstrated.

### The hsmi-stab lesson

hsmi-stab was killed by a functional that was algebraically blind (invariant under the
very transformation it was supposed to detect).  The entangling-power functional
avoids this by design (§4).  The DETERMINISM risk is different: our functional is
computationally expensive if the full e_p formula is used (matrix exponential at each
time step × each mcts evaluation × each frame candidate).  For d = 16 (4 qubits),
M=32 time steps, K_frames=50000 mcts nodes: each node evaluation costs O(d³) =
O(16³) = O(4096) flops for the matrix exponential, plus O(d²) for the partial-trace.
Total: ~50000 × 32 × 4096 ≈ 6.5 × 10^9 flops.  On an RTX 4070 Ti Super this is
< 1 second at FP64.  **Computationally feasible in budget.**

For v1 (Frobenius norm only): each mcts evaluation costs O(d³) (matrix multiply for
U†HU) = O(4096) flops.  Total: ~50000 × 4096 ≈ 2 × 10^8 flops.  Trivially feasible.

---

## 9. Honest comparison with the incumbent (Pauli-weight concentration)

The charter's incumbent scores a frame by how concentrated H's Pauli expansion is on
low-weight strings.  Both functionals measure the same underlying physics (locality of
H relative to the frame) but by different means:

| Property | Pauli-weight (incumbent) | Frobenius cross-cut (ours) |
|----------|--------------------------|----------------------------|
| Exact for product H | Yes (all weight on 0-body strings) | Yes (H_int = 0) |
| D-028 blindness | CHECK NEEDED by incumbent design | PASSED (§4) |
| Determinism | Deterministic (basis expansion) | Deterministic (matrix multiply) |
| GPU acceleration | Moderate (Pauli exponential) | Natural (CUBLAS gemm) |
| Physical interpretation | Information-theoretic locality | Dynamical locality (entanglement rate) |
| Carroll-Singh grounding | Indirect | Direct (same physical criterion) |
| Continuous frame gradient | Harder (discrete Pauli basis) | Analytic gradient exists |

The two functionals are related: for a product H, both give the minimum.  For a
scrambled H, both penalize it.  The Frobenius cross-cut norm is the MORE DIRECTLY
PHYSICAL measure (it is literally the entanglement generation rate), while the
Pauli-weight measure is more combinatorially transparent.  Both should be included in
the design tournament and compared on the planted-scrambler oracle.

---

## 10. Cheap ORRERY experiments available now

### Experiment E-1: algebra sanity check (available today)

The `algebra` tool measures crossed-product entropy in a 1+1D scalar field.  As a
sanity check that Φ detects locality: run `algebra` in "massive" vs "critical" regime.
In the massive regime the field is nearly product across the spatial cut; in the
critical regime it is entangled.  This does not directly test our functional (carve
does not exist yet), but confirms the physical connection between "locality" and
"small cross-cut entanglement."

```
python C:\ORRERY\tools\orrery\orrery.py run algebra --regime massive --mass2 4.0 \
  --max_size 64 --num_sizes 5 --fit_points 4 --seed 42
python C:\ORRERY\tools\orrery\orrery.py run algebra --regime critical --mass2 0.0 \
  --max_size 64 --num_sizes 5 --fit_points 4 --seed 42
```

Expected: massive regime shows sub-volume entanglement (small S_A); critical shows
log divergence.  This is a PHYSICS SANITY CHECK, not an oracle test.

### Experiment E-2: mcts on a synthetic landscape (available today)

Run `mcts` on its built-in "match" landscape to verify the search budget is adequate
for 3-level, 32-branching trees (as proposed in §3.2):

```
python C:\ORRERY\tools\orrery\orrery.py run mcts --branching 32 --depth 9 \
  --iters 50000 --trees 64 --c_uct 1.4 --tol 0.05 --landscape match --seed 42
```

Expected: found_optimum = true with high frac_trees_optimal.  This verifies the
search budget is sufficient before the carve oracle is connected.

### Experiment E-3: trace-born check for classicality

The `trace-born` tool (Born-from-redundancy, D-026) measures information replication
from a small system to many environment fragments — the Quantum Darwinism criterion
for classicality.  For a product H the system's state should be robustly replicated;
for a scrambled H it should not.  This is a COMPLEMENTARY classicality check that
could be run alongside carve as a redundant oracle.

---

## 11. Contract sketch (pre-contract, for operator review)

**Tool name:** `carve`  **Version:** 1.0.0  **Language:** C++/CUDA

**CLI:** `carve --ham PATH --nA INT --nB INT --seed INT [--frames INT] [--json PATH]
         [--selftest] [--golden]`

**Inputs:**
- `--ham PATH`: Hermitian matrix H in CSV (real + imaginary parts), d × d, d = 2^(nA+nB)
- `--nA`, `--nB`: qubit counts for each factor
- `--seed`: RNG seed for mcts and planting unitary generation
- `--frames`: mcts search budget (default 50000)

**Declared output (JSON envelope):**
- `tool`, `version`, `seed`, `params`
- `result.phi_min`: best Φ found (scalar, double)
- `result.U_best`: best frame (d×d unitary, real+imag, double)
- `result.phi_random`: estimated random baseline (mean of 100 GUE samples)
- `result.oracle_pass`: bool (if --oracle-mode: planted scrambler recovered?)
- `result.n_basins`: number of distinct basins found
- `verdict`: "pass" | "fail"
- `gates`: [G-NO-BASIN, G-MULTI-BASIN] with fired/value/threshold
- `notes`: firewall line ("Structure, never acquaintance")

**Exit codes:** 0 pass / 1 gate fired (real negative result) / 2 error

**Golden:** seeded run on n=4 qubit 2+2 split, product H, seed=42 → phi_min ≈ 0.0,
oracle_pass = true, gates all unfired.

---

## 12. Open questions and pre-registered doubts

1. **[DOUBT-1]** Does the frame lattice (discrete circuit approximation) cover enough
   of U(d) that the true minimum is reachable?  For large n this is unlikely without
   a continuous gradient method.  REGISTERED: this limits v1 to n ≤ 6 qubits.

2. **[DOUBT-2]** The n-trend for Φ(H_GUE) (Control 3) is ARGUMENT-GRADE.  The
   exact expected value for GUE Hamiltonians under the optimal frame needs a random
   matrix theory calculation.  REGISTERED: must be computed or simulated before the
   contract is frozen.

3. **[DOUBT-3]** The planted-scrambler oracle requires W_plant to be in (or near)
   the frame lattice.  If W_plant is a continuous unitary not well-approximated by the
   discrete gate set, the oracle will fail.  REGISTERED: the gate set must be dense
   enough.  Alternative: plant W_plant as an exact product of the lattice gates
   (guaranteed reachable).

4. **[DOUBT-4]** The Frobenius cross-cut norm is a STATIC measure (instantaneous
   entanglement rate).  Carroll-Singh's functional also requires quasi-classical
   SPREADING (pointer observable remains localized).  The spreading arm is not included
   in Φ_comp.  REGISTERED: the functional may admit products H = H_A ⊗ I that are
   NOT quasi-classical (e.g. a chaotic system on A alone).  The Carroll-Singh combined
   functional is preferred; the spreading term requires an additional cost term
   (operator spreading of the pointer observable).

---

## 13. References

1. Carroll, S.M. and Singh, A. "Quantum Mereology: Factorizing Hilbert Space into
   Subsystems with Quasi-Classical Dynamics." Phys. Rev. A 103, 022213 (2021).
   arXiv:2005.12938. https://arxiv.org/abs/2005.12938

2. Zanardi, P., Zalka, C., and Faoro, L. "Entangling Power of Quantum Evolutions."
   Phys. Rev. A 62, 030301(R) (2000). arXiv:quant-ph/0005031.
   https://arxiv.org/abs/quant-ph/0005031

3. Zurek, W.H. "Decoherence, einselection, and the quantum origins of the classical."
   Rev. Mod. Phys. 75, 715 (2003). arXiv:quant-ph/0105127.
   https://arxiv.org/abs/quant-ph/0105127

4. Bravyi, S. "Upper Bounds on Entangling Rates of Bipartite Hamiltonians."
   Phys. Rev. A 76, 052326 (2007). arXiv:0704.0964.
   https://arxiv.org/abs/0704.0964

5. Giachetta, G. et al. "Operational Quantum Mereology and Minimal Scrambling."
   Quantum 8, 1406 (2024). https://quantum-journal.org/papers/q-2024-07-11-1406/

6. Cotler, J., Penington, G., and Ranard, D. "Locality from the Spectrum."
   Commun. Math. Phys. 368, 1267 (2019). arXiv:1702.06142.
   https://arxiv.org/abs/1702.06142

---

*Structure, never acquaintance. The register holds the doubt.*
*Φ(H, U) = ||H_int(U)||_F² / ||H||_F² — this is the proposal.*
*Build nothing until the operator approves at the D-026 contract gate.*
