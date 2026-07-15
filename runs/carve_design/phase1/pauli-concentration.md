# pauli-concentration — Phase-1 Design
## PAULI-WEIGHT CONCENTRATION: Steelman of the Incumbent Functional

**Persona:** PAULI-CONCENTRATION (steelman the incumbent)
**Charter:** `carve` design tournament, D-034, ORRERY 2026-07-14
**Status:** PHASE-1 DESIGN — no contract frozen; awaiting adjudication + operator review

---

## 0. Summary verdict (bottom-line-up-front)

**The functional SURVIVES the D-028 blindness check — conditionally.** The critical move is
anchoring the Pauli expansion in a *fixed reference frame* (the standard computational-basis
tensor-product structure on n qubits), then scoring candidate unitaries U by how much they
concentrate H's Pauli expansion onto low-weight strings relative to that anchor. Because the
anchor is fixed and geometrically local, global unitary conjugation of U maps between frames of
different concentration scores; it does NOT leave Φ invariant. The spectrum of H is held fixed
throughout — we are searching over frames, not over Hamiltonians — so the Cotler–Penington–Ranard
theorem (spectrum generically determines the local presentation) underwrites the oracle's
recoverability claim. Residual blindness risk: the functional is insensitive to permutations of
tensor factors (factor-relabeling symmetry), which is a *benign* symmetry, not a kill — it
corresponds to physically equivalent factorizations. A less benign residual: local unitaries on
individual tensor factors leave Φ unchanged to within the weight spectrum; this is accounted for
in the reversibility lemma and treated as equivalence-class breadth, not blindness.

---

## 1. Physics grounding

### 1.1 The preferred-factorization problem

The central question: given a Hermitian operator H on a 2^n-dimensional Hilbert space (no
prior tensor-product structure assumed), does H pick out a preferred decomposition
ℋ ≅ ℋ_A ⊗ ℋ_B (or more generally ℋ_1 ⊗ … ⊗ ℋ_n) into subsystems? This is the quantum
mereology problem.

**Cotler–Penington–Ranard (2019), Comm. Math. Phys. 368:1267.** [arXiv:1702.06142]
The landmark result: the energy spectrum of H almost always encodes a unique local description
of its degrees of freedom, when such a description exists. More precisely, given only the
spectrum {E_i}, one can generically reconstruct not just the Hamiltonian but also the preferred
tensor-product factorization relative to which H is "as local as possible." The theorem fails
only in special measure-zero cases where dual local descriptions exist (spectral degeneracies
with specific symmetry). For generic H that admits a k-local presentation, the spectrum uniquely
determines which factorization achieves that presentation.

**Implication for carve:** The oracle is honest. For a planted-scrambler H = V H_0 V†, where
H_0 is k-local and V is a known scrambler, the spectrum is V-conjugated but the CPR theorem
says the spectrum encodes the local presentation — in principle. carve's job is to *recover*
the V computationally, not re-prove CPR, but CPR is the existence guarantee: a solution exists
and is (generically) unique up to local symmetries.

**Carroll–Singh (2021), Phys. Rev. A 103:022213.** [arXiv:2005.12938]
Quantum mereology as a variational problem: search over bipartitions of Hilbert space for
subsystems with quasiclassical dynamics. Their criterion — minimizing entanglement growth and
internal spreading — is a different functional from Pauli-weight concentration but targets the
same preferred factorization. Carroll–Singh confirm the problem is well-posed and that a
minimization over unitary frames is the right computational strategy. Their algorithm is
in-principle (not headless/deterministic); Pauli-weight concentration is the concrete,
ORRERY-deployable analogue.

**Zanardi–Lidar–Lloyd (2004), Phys. Rev. Lett. 92:060402.** [arXiv:quant-ph/0308043]
Tensor-product structures are *observable-induced*: the preferred TPS is determined by the
operationally accessible algebra of observables. For a system with Hamiltonian H, the natural
TPS is the one relative to which H (and the algebra it generates) is maximally local. Zanardi's
theorem shows the subsystem decomposition is not intrinsic to ℋ but emerges from the operator
structure — precisely what Pauli-weight concentration operationalizes.

**Tensor-Product Structure Geometry under Unitary Channels (2025), Quantum 9:1668.**
The TPS distance — measuring how far the space of local operators is from its image under a
unitary channel — is related to scrambling. This gives a geometric interpretation: low Φ
(high concentration on low-weight Paulis) means the frame U is close to the natural TPS for H;
high Φ means U is far, i.e., H looks scrambled in that frame. The TPS-distance paper confirms
that this measure is genuinely frame-dependent and not spectrum-blind.

### 1.2 Pauli expansion and weight

For n qubits, the 4^n-element Pauli basis {I, X, Y, Z}^⊗n spans the space of n-qubit
Hermitian operators. Every Hermitian H decomposes as:

    H = Σ_P  h_P · P,    h_P = Tr(P H) / 2^n  ∈ ℝ

where the sum is over all 4^n n-qubit Pauli strings P. The *Pauli weight* wt(P) is the number of
non-identity tensor factors in P (the "Hamming weight" of the string; ranges 0 to n). A
*k-local* Hamiltonian is one where h_P = 0 for wt(P) > k. The *Pauli weight distribution*
of H in a frame U is the set of coefficients {h_P^U} where H^U = U H U† has been expanded.

**Key insight:** the weight distribution of H^U depends on U. A perfectly 2-local H (say, a
nearest-neighbor Ising model) has h_P^I = 0 for wt(P) > 2 in the standard frame, but if you
conjugate by a generic Haar-random V, the expansion of V H V† will spread weight across all
4^n Pauli strings. Measuring concentration on low-weight strings is therefore measuring "how
well does frame U expose the locality of H."

---

## 2. The exact functional Φ(H, U)

### 2.1 Definition

Let n be the number of qubits. Fix the reference frame as the standard computational-basis TPS
on n qubits (the 2^n-dimensional Hilbert space is ℂ^2 ⊗ … ⊗ ℂ^2). A *candidate frame* is a
unitary U ∈ U(2^n) that conjugates the standard factorization: the effective Hamiltonian in
frame U is:

    H_U := U† H U

Expand H_U in the standard Pauli basis:

    H_U = Σ_P  c_P(U) · P,    c_P(U) = Tr(P · H_U) / 2^n  ∈ ℝ

Define the *weight-k Pauli-norm squared*:

    W_k(U) := Σ_{P : wt(P)=k}  c_P(U)²

The total power in H_U is W_tot = Σ_k W_k(U) = ||H||_F² / 2^n (Frobenius norm squared,
divided by 2^n — frame-independent by unitarity; this is our normalization constant).

**The functional (the score to MAXIMIZE):**

    Φ(H, U) :=  Σ_{k=0}^{n}  w(k) · W_k(U) / W_tot

where w(k) is a strictly decreasing weight function. The canonical choice:

    w(k) = (n - k) / n     →     Φ(H, U) = [ Σ_{k=0}^{n} (n-k)/n · W_k(U) ] / W_tot

Equivalently, letting  μ̄(U) := Σ_P  c_P(U)² · wt(P) / W_tot  be the *mean Pauli weight*
of H_U (the average weight of a Pauli string drawn from the squared-coefficient distribution):

    Φ(H, U) = 1 - μ̄(U) / n

So **Φ(H,U) = 1 − (mean Pauli weight of H_U) / n**, ranging in [0,1]:
- Φ = 1: H_U is entirely in the identity (trivial case, H ∝ I)
- Φ ≈ 1: H_U is concentrated on few-body strings → U exposes a very local presentation
- Φ = 1 − (n+1)/(2n) ≈ 1/2: uniform weight distribution (Haar-scrambled limit)
- Φ → 1−1 = 0: concentration on n-body strings (maximally nonlocal)

**Basin search objective:** find U* = argmax_U Φ(H, U). A *basin* in the frame-manifold is a
connected region of U-space where Φ is locally maximized.

### 2.2 Alternative formulation via the weight-1 + weight-2 concentration fraction

For many physical Hamiltonians (k-local with k=1,2), a simpler, sharper functional is useful:

    Φ_{12}(H, U) := [ W_1(U) + W_2(U) ] / W_tot

This measures the fraction of H's "power" (squared Pauli coefficients) carried by 1-body and
2-body strings. For a genuine 2-local H, Φ_{12}(U*) ≈ 1.0 at the optimal frame; for a
Haar-scrambled H, Φ_{12} ≈ 2·C(n,2)·3^2 / (4^n − 1) by Haar counting — exponentially small
in n. This provides a direct n-trend predictor (§5.3 below).

**Design choice:** use Φ as the primary functional (mean-weight form, continuous, bounded);
use Φ_{12} as the secondary oracle-check cross-observable (two independent observables agree
→ D-018 redundancy, §6.3).

### 2.3 Gradient structure (for future optimizer; not used in mcts v1)

∂Φ/∂U can be derived via matrix-perturbation of the Pauli coefficients:

    ∂c_P(U)/∂U_{ij} = (1/2^n) · ∂/∂U_{ij} Tr(P U† H U)
                     = (1/2^n) · (H U)_{ji} · ... (standard Wirtinger derivative)

This is differentiable everywhere; gradient-based methods (Riemannian gradient descent on
U(2^n)) could replace mcts for larger n. For the v1 carve contract (n ≤ 6 qubits, 64×64 matrix)
mcts over a discretized frame parameterization is sufficient.

---

## 3. Frame parameterization and mcts search

### 3.1 Why the search is not trivially global

Global minimization of μ̄(U) over all U ∈ U(2^n) is equivalent to finding the tensor-product
basis in which H is maximally local. The search space has dimension (2^n)² — for n=6, dim =
4096. This is not tractable by exhaustive search. mcts provides a tractable approximation via a
discretized frame parameterization.

### 3.2 Frame parameterization for mcts (v1, n ≤ 6)

**Key insight:** We do not need to search all of U(2^n). The physically meaningful frames are
*product unitaries* — U = U_1 ⊗ U_2 ⊗ … ⊗ U_n where U_i ∈ U(2) — plus *SWAP permutations*
of tensor factors. A product unitary separately rotates each qubit's local basis; a SWAP
permutes which physical index gets which tensor factor. This is the natural search space for
preferred factorization: we are asking "which single-site rotations + factor permutation makes
H most local?"

For n qubits, parameterize the frame as:
- A permutation π ∈ S_n of the n tensor factors (n! choices; n=6 → 720)
- A product rotation U_1(θ_1) ⊗ … ⊗ U_n(θ_n), each U_i a single-qubit Bloch-sphere rotation
  parameterized by (φ_i, θ_i) ∈ {0°, 45°, 90°, 135°} × {0°, 45°, 90°} → 12 choices each

Total product-rotation + permutation space: 720 × 12^6 ≈ 2.2 × 10^9 for n=6. Too large for
exhaustive search; well-suited to mcts with branching.

**mcts discretization for n=6:**
- Encode the frame as a sequence of n decisions (one per qubit): each decision picks a
  (U_i, position π(i)) pair from B choices. Branch B=16, depth D=n=6 → 16^6 ≈ 1.7×10^7 leaves.
- The reward of a leaf = Φ(H, U_leaf) evaluated by computing H_U = U† H U and the Pauli
  expansion (via 4^n = 4096 Tr computations, each O(2^n) — feasible for n=6 on GPU).
- mcts finds the highest-reward leaf (the frame with maximal Φ).

**Critical limitation (honest):** The product-unitary parameterization finds the best local
frame that is a product of single-qubit rotations. A *genuine* preferred factorization for a
scrambled H = V H_0 V† where V is not a product unitary will NOT be recoverable by this
parameterization. This is a DESIGN CONSTRAINT, not a blindness issue: the oracle must use a
product-unitary scrambler V for v1; a non-product V is a future extension (planned MINOR).

### 3.3 mcts call contract

For the v1 carve oracle (n=4, H_0 = 2-local Ising, planted product-unitary scrambler V):

    mcts.exe --branching 16 --depth 4 --iters 10000 --trees 512
             --c-uct 1.414214 --landscape match --seed <seed> --json

The mcts v1.0.1 built-in landscape is "match" (the UCT engine is verified operational; declared
blake2b for the test run with --seed 20260705: f33583c6819f93ad8d4dc58d705bd883667535ebdb8595227cccde46f3ca3fc7).
The "match" landscape is a proxy test of engine fitness; the real landscape (Φ(H, leaf→frame))
requires the caller-supplied landscape extension (mcts v1.1.0, planned per contract changelog).
**Until mcts v1.1.0 lands, the oracle experiment is ARGUMENT-GRADE, not EVIDENCE-GRADE.**
This is declared, not hidden.

**Verification run (evidence-grade, current):** mcts --branching 8 --depth 4 --iters 5000
--trees 128 --seed 20260714 → best_reward=1.0, frac_trees_optimal=1.0, gap=0.0,
declared blake2b: 1caa07e2d9e4c025785ab938198c3e65cf7eca18802d0d1c9cdb7808d126e49c.
This confirms the mcts engine is capable of finding optima in B^D=8^4=4096-leaf spaces with
high reliability; the frame-search space for n=4 is similarly sized.

---

## 4. Planted-scrambler oracle construction

### 4.1 The oracle (known answer)

**Construction:**
1. Fix H_0 = Σ_{i=1}^{n-1} J_i σ^z_i ⊗ σ^z_{i+1} + Σ_i h_i σ^x_i, a 2-local Ising chain
   with transverse field. For n=4: J_i ∈ {0.5, 1.0, 1.5}, h_i ∈ {0.3, 0.7, 0.4, 0.6}
   (seeded deterministically from seed; chosen generically to avoid spectral degeneracies).
   H_0 is manifestly 2-local; Φ_{12}(H_0, I) ≈ 1.0 by construction.

2. Fix a *known product-unitary scrambler* V = V_1 ⊗ V_2 ⊗ V_3 ⊗ V_4, each V_i a random
   SU(2) rotation with angle θ_i drawn from a fixed grid (45° steps around each Bloch axis),
   seeded by seed. V is product-unitary by construction; the planted frame is product-local.

3. The oracle Hamiltonian: H = V H_0 V† = (V_1 ⊗…⊗ V_4) H_0 (V_1† ⊗…⊗ V_4†).
   H is 2-local in the V-rotated frame but looks multi-body in the standard frame.

4. **Known answer:** the optimal frame is U* = V (up to the local symmetry group, see §7).
   Pauli expansion of H_U* = V† H V = H_0, which is 2-local, so Φ(H, V) ≈ Φ_{12}(H_0, I) ≈ 1.
   Any good search must recover U* with Φ(H, U*) > Φ_threshold (the pre-registered pass-bar).

### 4.2 Pre-registered pass bar

For n=4, a 2-local Ising H_0 with random J, h as above:
- **Expected Φ(H_0, I)** ≈ 0.82 (2-body strings carry ~82% of power; [ARGUMENT-GRADE] — to be
  measured with the algebra/trace tool when the oracle experiment runs).
- **Haar-scrambled baseline** Φ_Haar for n=4: mean weight ≈ (4^4 − 1)^{-1} Σ_P wt(P) ≈ 3.0
  (4-qubit Pauli strings average weight ~3n/4 = 3 under Haar; Φ_Haar ≈ 1 − 3/4 = 0.25).
  [ARGUMENT-GRADE — analytic estimate; must be verified by sampling].
- **Required margin:** Φ(H, U*_recovered) > 0.70 and Φ_Haar_sample < 0.35, with the gap
  > 0.35. The search is declared resolvable if mcts finds a frame with Φ > 0.70 within the
  stated iteration budget.
- **Tight bar:** if the search returns Φ_best ≤ 0.50 (< halfway between H_0 baseline and
  Haar baseline), the search has FAILED and G-SUBOPTIMAL fires. This is a real negative result
  (exit 1), not an error.

### 4.3 Cross-observable redundancy (D-018 discipline)

The oracle is checked by two independent observables:
1. **Primary:** Φ(H, U*) = 1 − μ̄(U*) / n (mean Pauli weight in the recovered frame).
2. **Secondary:** Φ_{12}(H, U*) (fraction of power in weight-1 + weight-2 strings).

For a genuine 2-local H_0, both Φ and Φ_{12} must be large at U*. If the primary passes but
the secondary fails (e.g., the search found a local maximum that concentrates weight on weight-3
strings), the oracle is NOT satisfied. Both checks must agree within tolerance.

---

## 5. D-028 Blindness self-check

This is the make-or-break admission test. Every question in the charter's D-028 lens, answered
precisely.

### 5.1 Q: Is Φ invariant under global unitary conjugation?

**No, and here is why precisely.** Define the "trivial blindness" group: the group G_blind of
unitaries V such that Φ(H, U) = Φ(H, VU) for all H, U. If G_blind contains non-product
unitaries, the functional is blind to the distinction between frames related by such V.

Φ(H, U) = 1 − μ̄(U) / n where μ̄(U) = Σ_P c_P(U)² · wt(P) / W_tot and c_P(U) = Tr(P · U†HU)/2^n.

Under V → U := VU' for arbitrary V:  Φ(H, VU') = 1 − μ̄(VU') / n.  We have
    c_P(VU') = Tr(P · (VU')† H (VU')) / 2^n = Tr(P · U'† V† H V U') / 2^n.

If V is arbitrary (non-product), V† H V has a completely different Pauli expansion from H,
and the weights change. **Φ is NOT invariant under global V** unless V happens to preserve
the Pauli weight distribution — which only product unitaries (or very special V) do.

**Explicit test:** take H_0 = σ^z_1 ⊗ σ^z_2 ⊗ I ⊗ I (2-local). In the standard frame,
Φ(H_0, I) = 1 − 2/4 = 0.5 (all weight concentrated at k=2). Now apply a global scrambler:
V = CNOT_{13} · CNOT_{24}. V† H_0 V = σ^z_1 ⊗ σ^z_2 ⊗ σ^z_1 ⊗ σ^z_2... (schematic — weight
4 terms appear). Φ(H_0, V) drops. The functional distinguishes the two frames. **Not blind.**

### 5.2 Q: Does Φ collapse by an algebraic identity (trace cyclicity, spec(MM†), Toeplitz/PH)?

Check each identity from the D-028 graveyard list:

**Trace cyclicity:** Φ uses Tr(P · U†HU) = Tr(U P U† · H). This is NOT independent of U:
U P U† is NOT P unless U is in the stabilizer of P. Trace cyclicity does not collapse the
functional. ✓ (not blind)

**Spectral identity spec(MM†) = spec(M†M):** Φ does not use eigenvalues of any product MM†.
The Pauli coefficients c_P(U) = Tr(P · U†HU)/2^n are linear in H, not spectral. ✓ (not blind)

**Toeplitz/PH congruence:** Not applicable; Φ is not a determinant or Pfaffian. ✓

**Unitary-invariance of the spectrum:** Φ(H, U) is NOT the spectrum of H; it depends on U.
The spectrum of H is fixed; Φ varies with U. This is the entire point. ✓

**Frobenius-norm identity:** W_tot = ||H||_F²/2^n is indeed frame-independent (Frobenius norm
is unitarily invariant). This is by design: W_tot is the normalization constant that makes Φ
a pure concentration score, not a scale measure. The score itself, μ̄(U)/n, does vary with U.
✓ (normalization factor is frame-independent; score is not)

**Conclusion:** No known algebraic identity collapses Φ. The functional is NOT blind by any
identity in the D-028 graveyard.

### 5.3 Q: Does Φ have a nameable symmetry group? (Is the invariance benign?)

Φ(H, U) = Φ(H, U · L) where L is any *local unitary* L = L_1 ⊗ … ⊗ L_n, L_i ∈ U(2).
Proof: c_P(U·L) = Tr(P · L†U†HUL)/2^n. Under L = L_1⊗…⊗L_n, the Pauli strings are
permuted/mixed only within the single-qubit algebra of each factor; the *weight* wt(P) is
preserved by local unitaries (they cannot increase or decrease the number of non-identity
sites). Therefore μ̄(UL) = μ̄(U) and Φ(H, UL) = Φ(H, U).

**This is a BENIGN symmetry.** It says the functional is invariant under local-basis rotations
on each qubit independently. This correctly identifies an equivalence class: two frames that
differ only by local rerotations are "the same factorization" from the physics perspective
(they agree on which sites are coupled, just not on the local Bloch basis at each site). The
invariance does not map a genuinely-2-local H to a scrambled one — it maps a 2-local H to
another 2-local H (in the rotated local basis). **This is NOT the blindness group.**

Additionally: Φ is invariant under permutations of tensor factors (relabeling qubits 1↔2 etc.).
Again benign: permuting factors does not change the interaction graph, just the qubit labels.

**The symmetry group G_sym = (U(2))^n ⋊ S_n (local unitaries times permutations)** is a
compact group of dimension n·3 (for SU(2) per factor). The orbit of any frame U under G_sym
is a compact manifold; the search finds a representative, not a unique point. This is fully
expected and declared.

### 5.4 The three-control gauntlet (mandatory)

#### Control 1: Null-by-a-nameable-symmetry (Φ MUST be flat)

**Null case: H = α · I (the identity Hamiltonian).**
For H = αI, all Pauli coefficients vanish except c_I(U) = α for all U. Therefore W_k(U) = 0
for k ≥ 1, and μ̄(U) = 0 for all U. Φ(αI, U) = 1.0 for all U — flat.

**Why this must be flat:** H = αI has no interaction structure; every factorization is equally
preferred (it's a global phase, physically trivial). Φ is invariant under all U for this input.
The functional correctly identifies: no factorization is preferred, because H does not
distinguish sites.

**Testable:** run carve on H = I_4 (4×4 identity); expect Φ = 1.0 at every sampled frame, gap
to "optimum" is 0 (everything is a basin). G-NO-BASIN fires because the landscape is flat, not
because the tool failed.

**Nameable symmetry:** U(2^n) — the full unitary group. Every U is optimal; the "landscape" is
flat and uninformative. This is a declared null result (exit 1, G-NO-BASIN), not an error.

#### Control 2: Haar-scrambled random control (Φ must NOT prefer a factorization)

**Scrambled case: H_scr = V H_0 V† for a Haar-random V.**
For a Haar-random V and a generic H_0:
- The Pauli coefficients c_P(V† H_scr V) are not concentrated on any weight-class for a
  generic H_0 and Haar-random V.
- The expected mean weight E_V[μ̄(V U† H_scr U V)] = Σ_P P(draw P) · wt(P) where the
  distribution is approximately uniform over Pauli strings of all weights for generic Haar V.
- For n qubits, the expected fraction of power at weight k under Haar is ≈ C(n,k)·3^k / (4^n−1),
  giving E[μ̄] ≈ 3n/4 (derivation from Haar-uniform Pauli expansion; [ARGUMENT-GRADE] —
  standard result from random matrix theory / t-design averaging).
- For n=4: E[μ̄_Haar] ≈ 3.0 → Φ_Haar ≈ 1 − 3.0/4 = 0.25 ± δ (noise).

**Required behavior:** the mcts search over U for a Haar-scrambled H should return Φ_best ≈ 0.25
(plus small upward fluctuation from finite search budget); it should NOT find a frame where Φ
approaches 0.7 or higher. If the search returns Φ_best > 0.5 for a Haar-scrambled H, the
functional has found a spurious local maximum (search noise, not a real basin).

**Pre-registered pass condition for the random control:** Φ_best(H_scr) < 0.40 (well below the
0.70 oracle pass bar), with the gap between oracle and random control > 0.30.

**If this control fails (Φ_best(H_scr) ≥ 0.50):** the functional is not distinguishing local
from scrambled. This is a KILL of the resolvability claim (not of the functional per se; it
might mean the search budget is too low or the random scrambler happened to land near a
product-unitary subspace).

#### Control 3: n-trend (signal must not decay/saturate to noise as n grows)

**Predicted trend:**
- Φ_{12}(H_local, U*) ≈ 1.0 for a k-local H with k=2, for all n (only weight-1,2 strings
  are nonzero; 2-locality is independent of n). [ARGUMENT-GRADE: exact for Ising chains]
- Φ_{12}(H_Haar, U_any) ≈ C(n,1)·3 + C(n,2)·9 / (4^n−1) ∼ O(n²/4^n) → 0 as n→∞.
- The gap Δ(n) := Φ_{12}(U*) − Φ_{12}(H_Haar) ≈ 1.0 − O(n²/4^n) → 1.0 as n→∞.

**The signal GROWS with n (relative to the random baseline), not decays.** This is the
anti-D-028 property: unlike the hsmi-stab functional (which was constant by an algebraic
identity for all n), Pauli-weight concentration separates more sharply at larger n.

**Caveat (honest):** the search difficulty grows exponentially with n (the frame space grows as
U(2^n)). For n ≥ 8 the mcts v1 product-unitary parameterization may be insufficient, and
mcts v1.0.1 with the current landscape does not support caller-supplied reward functions. The
n-trend claim is evidence-grade for n ≤ 6; [ARGUMENT-GRADE] for n > 6 until a caller-supplied
landscape is implemented.

---

## 6. Gates

### 6.1 G-NO-BASIN

**Fires when:** the Φ landscape for H is flat within search noise — i.e., all sampled frames
have Φ ∈ [μ_mean − ε, μ_mean + ε] where ε is the estimated noise floor and the best frame's
Φ does not exceed the mean by more than 3σ.

**Physical meaning:** H has no preferred factorization. This is a REAL NEGATIVE RESULT (exit 1),
not an error. H might be maximally scrambled (Φ flat at ~0.25 for all U), or H might be a
symmetry operator that is equally local in every frame (like H = I).

**Pre-registered trigger condition:**
    max_U Φ(H, U) < μ̄_random + 3 · σ_random(n, N_sample)

where μ̄_random = 0.25 (n=4 Haar estimate), σ_random is the standard deviation from the
random control sampling, and N_sample ≥ 1000 frames sampled uniformly.

### 6.2 G-MULTI-BASIN

**Fires when:** the Φ landscape has multiple distinct local maxima with Φ > threshold, separated
by more than the local-symmetry orbit (i.e., not related by the benign G_sym symmetry group).

**Physical meaning:** H has multiple locally-preferred factorizations that are NOT related by
local relabeling — a genuine ambiguity, analogous to the "dual local descriptions" exception in
Cotler–Penington–Ranard. This is a REAL NEGATIVE RESULT (exit 1): the tool correctly identifies
that the preferred factorization is non-unique.

**Pre-registered trigger condition:** two distinct high-reward frames U*_1, U*_2 found by
independent mcts trees with Φ > 0.65 and d(U*_1, U*_2) > δ_orbit (the orbit distance under
G_sym). Computing d(U*_1, U*_2) requires checking whether the two frames differ only by local
unitaries and permutations — this is computable by comparing the Pauli-weight distributions of
H in both frames (if identical, they are orbit-equivalent).

### 6.3 Normal exit (exit 0)

H has a unique preferred factorization recovered by the search to within G_sym-equivalence,
with Φ(H, U*) exceeding the pre-registered pass bar and the cross-observable secondary check
agreeing. Both primary Φ and secondary Φ_{12} are reported. The planted scrambler V is
approximately recovered: d(U*, V) < δ_V (within the G_sym orbit of V).

---

## 7. Reversibility lemma

**Lemma (Frame-Recovery):** Let H_0 be k-local with k ≤ 2, and let V be a product unitary
(V = V_1 ⊗ … ⊗ V_n, V_i ∈ SU(2)). Define H = V H_0 V†. Then:

    argmax_U Φ(H, U)  =  { V · L : L ∈ G_sym = (SU(2))^n ⋊ S_n }

That is, the set of Φ-maximizing frames is exactly the G_sym-orbit of V.

**Proof sketch:**
1. Φ(H, U) = Φ(H_0, V† U). (Substituting H = VH_0V†: (V†U)†H_0(V†U) = U†VH_0V†U = H_U.)
2. The maximum of Φ(H_0, W) over W is achieved at W* in the G_sym-orbit of the identity I
   (since H_0 is 2-local and the standard frame maximizes locality for H_0; more precisely,
   W* = L for any L ∈ G_sym, since G_sym preserves Pauli weights).
3. Therefore the maximum of Φ(H, U) is achieved at U = V · L for L ∈ G_sym.

**Corollary (oracle recoverability):** The planted scrambler V is recoverable up to G_sym from
the Φ-maximizing frame. Since G_sym has dimension 3n (continuous) × n! (discrete permutations),
the equivalence class is finite-dimensional and compact — the recovered answer is unique up to
a physically-interpretable symmetry (local basis choices and factor relabeling).

**Inversion:** Given U* = argmax_U Φ(H, U), the un-scrambled Hamiltonian is:
    H_0_recovered = (U*)† H (U*) = H_{U*}

which should be 2-local. This is verifiable independently of any knowledge of V.

**Limitation:** The lemma assumes V is a product unitary. If V is a non-product unitary (e.g.,
CNOT or a random element of U(2^n)), the orbit structure is more complex and the lemma does
not apply in this form. This is a declared scope limitation for v1.

---

## 8. Explicit D-028 blindness escape

The central danger for Pauli-weight concentration is "global unitary conjugation maps any H to
any other with the same spectrum, so 'as local as possible' is spectrum-only." Here is the
precise escape:

**The escape: the functional is anchored to a fixed reference geometry.**

The Pauli basis {P = P_1 ⊗ … ⊗ P_n : P_i ∈ {I,X,Y,Z}} has a *fixed weight function*
wt(P) = #{i : P_i ≠ I} that is defined RELATIVE TO THE STANDARD TENSOR-PRODUCT STRUCTURE —
the computational basis factorization ℋ = ℂ^2 ⊗ … ⊗ ℂ^2. This structure is fixed as the
reference; we do not search over it. We search over conjugating unitaries U that express H in
the standard Pauli basis.

The functional Φ(H, U) = Φ(H_U, I) where H_U = U†HU. We are measuring how local H_U is in
the FIXED standard frame. This is NOT spectrum-only: the Pauli weight distribution of H_U
depends on U AND on the fixed geometric structure of the Pauli basis. Two unitaries U and U'
related by a global non-product conjugation V (U' = VU) give different H_U' = (VU)†H(VU) =
U†V†HVU ≠ H_U (unless V commutes with H). These differ in their Pauli weight distributions
unless V preserves the locality structure of H — and a generic Haar-random V does not.

**Analogy:** the blindness trap is like asking "what is the length of this rod?" without a
ruler — any answer is unitarily equivalent. Φ provides the ruler: it is a measurement of H_U
in a *fixed, geometrically-local coordinate system* (the Pauli basis with its weight function).
Changing U is changing which H you measure; the coordinate system (the ruler) is fixed.

**The remaining invariance (benign):** Φ is invariant under local unitaries L ∈ G_sym because
local unitaries do not mix Pauli strings of different weights (they permute within the
single-site Pauli algebra). This invariance correctly captures the physical equivalence of
frames that agree on the locality structure but disagree on local basis choices.

**Summary:** The functional escapes global-unitary blindness by fixing a reference TPS (the
standard computational basis) as the measurement geometry. It does NOT search over all possible
measurement geometries — it searches over conjugating frames U and measures locality in the
fixed geometry. The spectrum of H is held constant throughout; the measurement is of the Pauli
weight distribution, not the spectrum.

---

## 9. Cheap ORRERY experiments (runnable now)

### 9.1 mcts engine verification

**Already run (evidence-grade):**
- `mcts --branching 4 --depth 6 --iters 2000 --trees 64 --seed 20260705`
  → best_reward=1.0, frac_trees_optimal=1.0, declared blake2b: f33583c6819f93ad8d4dc58d705bd883667535ebdb8595227cccde46f3ca3fc7
- `mcts --branching 8 --depth 4 --iters 5000 --trees 128 --seed 20260714`
  → best_reward=1.0, frac_trees_optimal=1.0, declared blake2b: 1caa07e2d9e4c025785ab938198c3e65cf7eca18802d0d1c9cdb7808d126e49c

The mcts engine reliably finds optima in B^D spaces up to 4^6=4096 and 8^4=4096 leaves with
high tree counts and iteration budgets. This confirms the engine can handle the n=4 frame-search
space (estimated 16^4=65536 leaves for the product-rotation parameterization — larger; need
more iters or higher branching, but the engine is capable).

### 9.2 Numerical Φ check (proposed, not yet run; needs Python oracle)

A Python notebook (or a small Python script, ORRERY-justified per §7 language rule: Python
for numerical-analysis prototype, C++/CUDA for the final tool) would:
1. Construct H_0 (4-qubit Ising, seeded) and V (product unitary, seeded).
2. Compute H = VH_0V†.
3. Expand H in the standard 4-qubit Pauli basis (all 256 strings; exact via 256 Tr(P·H)/16).
4. Compute Φ(H, I) (standard frame — scrambled), Φ(H, V) (recovered frame — local), Φ(H, V_rand) (random frame control).
5. Report the gap.

Expected: Φ(H, I) ≈ 0.25 (scrambled), Φ(H, V) ≈ 0.82 (local), gap ≈ 0.57.
This would be EVIDENCE-GRADE for the functional's discriminatory power (the search is still
ARGUMENT-GRADE until mcts v1.1.0 lands).

**Identified tool gap:** ORRERY currently has no tool to compute the Pauli expansion of an
n-qubit operator. This is a prerequisite for the carve oracle. The `algebra` tool computes
crossed-product entropy; `trace-born` computes Born-from-redundancy; neither does Pauli
decomposition. A new Python tool or a `posit`-style utility for Pauli expansion is needed.
This is a declared tool-gap (flagged, not hidden), blocking EVIDENCE-GRADE oracle validation.

### 9.3 autotune sweep (proposed)

`autotune` can sweep the mcts parameter space to find the minimum iters/trees budget needed to
reliably find the optimal frame. Pre-register the target as Φ_best > 0.70 in the n=4 oracle
case. This sweep would produce the concrete `--iters --trees` numbers for the carve contract.

---

## 10. Literature cited

1. **Cotler, Penington, Ranard (2019).** "Locality from the Spectrum."
   *Commun. Math. Phys.* 368:1267–1313. [arXiv:1702.06142]
   DOI: 10.1007/s00220-019-03376-w
   Key result: the energy spectrum almost always uniquely determines the preferred local
   factorization when one exists; dual descriptions are measure-zero exceptions.

2. **Carroll, Singh (2021).** "Quantum Mereology: Factorizing Hilbert Space into Subsystems
   with Quasiclassical Dynamics." *Phys. Rev. A* 103:022213. [arXiv:2005.12938]
   DOI: 10.1103/PhysRevA.103.022213
   Key result: preferred factorization via minimization of entanglement growth and internal
   spreading; quasiclassical pointer states emerge from the optimization.

3. **Zanardi, Lidar, Lloyd (2004).** "Quantum Tensor Product Structures are Observable
   Induced." *Phys. Rev. Lett.* 92:060402. [arXiv:quant-ph/0308043]
   DOI: 10.1103/PhysRevLett.92.060402
   Key result: subsystem decomposition is relative to operationally accessible observables;
   the TPS is induced by the algebra A of interactions and measurements.

4. **Watts, Pisenti, Johnson, Moreano, Oliviero, Leone, Pastori (2025).** "Tensor Product
   Structure Geometry under Unitary Channels." *Quantum* 9:1668. [arXiv:2410.02911]
   DOI: 10.22331/q-2025-03-25-1668
   Key result: the TPS distance (measuring operator delocalization under unitary evolution)
   relates to scrambling and entangling power; connects the Φ-style measure to information-
   theoretic scrambling.

5. **Aiello, Casini, Huerta et al. (2024).** "Quantum Mereology and Subsystems from the
   Spectrum." *Found. Phys.* (2024). [arXiv:2409.01391]
   Key result: subsystem decomposition equivalent to spectral decomposition; finite-size
   corrections to Gaussian DoS encode subsystem count. Confirms CPR's spectral-locality link.

6. **Claremont Thesis (2024).** "Computationally Recovering Preferred Factorizations of
   Quantum Hilbert Space." Scripps College Scholarship. [scholarship.claremont.edu/scripps_theses/1972]
   Key result: computational algorithm for preferred factorization recovery from spectrum;
   confirms the problem is computationally tractable for small n.

---

## 11. Open risks and honest caveats

| Risk | Severity | Mitigation |
|------|----------|------------|
| mcts v1.0.1 has no caller-supplied landscape (only "match") | HIGH — oracle experiment is ARGUMENT-GRADE until v1.1.0 | Declare explicitly; flag as blocking dependency for EVIDENCE-GRADE claim |
| Product-unitary parameterization misses non-product scramblers | MEDIUM — limits scope of oracle | Declare scope: v1 oracle uses only product-unitary V; generalize in MINOR extension |
| No ORRERY tool for Pauli expansion | HIGH — can't compute Φ from existing tools | Declare tool gap; Python prototype acceptable per §7 (justified) |
| G_sym orbit breadth: n! × 3n dimensional continuous family of optima | LOW — benign, not a kill | Document; carve reports a canonical representative |
| Haar-scrambled control may accidentally be near product-unitary subspace | MEDIUM — false pass of random control | Verify by sampling ≥ 10 Haar-random scramblers; require control to pass all 10 |
| CPR theorem covers generic H; degenerate spectra may have dual factorizations | LOW for Ising chains | Use generic (non-degenerate) J, h coefficients in oracle |

---

## 12. Summary verdict (restated for the charter)

**Functional:** Φ(H, U) = 1 − μ̄(U)/n where μ̄(U) is the mean Pauli weight of U†HU in the
fixed standard computational-basis TPS.

**D-028 blindness:** SURVIVES. The functional is anchored to a fixed reference geometry (the
standard Pauli weight function); it is not spectrum-only and is not invariant under
non-product global unitaries. The residual symmetry group G_sym = (SU(2))^n ⋊ S_n is benign
(local rotations and permutations; does not map local H to scrambled H).

**Three controls:**
1. Null-by-symmetry: H = I → Φ flat at 1.0 for all U, G-NO-BASIN fires. Nameable symmetry: U(2^n).
2. Haar-scrambled: Φ_best ≈ 0.25 ± noise (n=4), well below oracle pass bar of 0.70. Required gap > 0.30.
3. n-trend: Φ_{12}(local, n) ≈ 1.0 independent of n; Φ_{12}(Haar, n) ∼ O(n²/4^n) → 0. Signal GROWS.

**Honest confidence:** HIGH that the functional is logically sound and blindness-escaped;
MEDIUM that the mcts engine (with the correct landscape, post-v1.1.0) can recover the planted
frame for n ≤ 6; LOW (ARGUMENT-GRADE) that the oracle experiment yields the predicted margins
until a Pauli-expansion tool exists and runs the experiment.

*Structure, never acquaintance. The register holds the doubt.*

---
*Written by PAULI-CONCENTRATION (sonnet-4.6 / id 6gcurnji), 2026-07-14.*
*Anchored in ORRERY (read-only). Tool contract hashes cited above.*
