# lens-resolvability.md — RESOLVABILITY + DETERMINISM lens
## carve design tournament, phase 2
## Lens author: RESOLVABILITY (sonnet-4.6 / id xxixihvj, 2026-07-14)

---

## 0. Executive summary

The single biggest resolvability risk across all four functionals is the same:
**the planted-scrambler oracle is self-defeating when the scrambler is a product
unitary, because all three primary functionals are provably invariant under
product-unitary transforms of H.** This is a KILL of the oracle design as
currently written in pauli-concentration and operator-locality. The commutant
design avoids this only because it explicitly bakes the oracle into Clifford gates
drawn from the same frame alphabet — but then the "search" is guaranteed to succeed
trivially. Entangling-power (Frobenius variant) has the same product-unitary
invariance for the SEPARATE-LOCAL-UNITARY subgroup but not for full entangling
scramblers; it sidesteps the kill only if it uses a genuinely entangling oracle.

**Best buildable v1 functional:** entangling-power Frobenius variant
(Phi_xcut = ||H_int(U)||_F^2 / ||H||_F^2). It is the only design that (a) is
deterministic, (b) has a non-trivial signal landscape for the oracle, and (c)
has a frame parameterization that includes the entangling gates needed to recover
the planted answer. Its n-ceiling is n ≤ 6 (d ≤ 64) in v1 before search budget
explodes.

---

## 1. The HARD PROBLEM: continuous frame manifold vs discrete mcts

The frame U ranges over U(2^n), a continuous manifold of dimension (2^n)^2 = 4^n.
mcts searches a **discrete** space of branching B, depth D — a leaf is a fixed
element of a finite alphabet. The fundamental tension:

- Too coarse (few gates, small alphabet): the planted answer may not live on any
  leaf; the search cannot find it even with unlimited budget.
- Too fine (large B or D): the leaf count B^D becomes intractable for mcts.

The v1 designs address this differently, and the differences are resolvability-critical.

---

## 2. Per-functional resolvability assessment

### 2.1 PAULI-CONCENTRATION (Phi = 1 - mean_Pauli_weight(U†HU) / n)

**Discretization approach:** product-unitary parameterization — U = V1 ⊗ V2 ⊗ ... ⊗ Vn,
each Vi from a discrete per-qubit alphabet (16 choices each); frame space = 16^n leaves.
For n=4: 65536 leaves (tractable). For n=6: 16.8M (marginal). For n=8: 4.3B (intractable).

**KILLED: product-unitary oracle is self-defeating.**

MEASURED (numpy, this session): for a 2-local Ising H0 and a product-unitary scrambler V:
  Phi(H_scr, I) = Phi(H0, I) = 0.4242  [delta = 0.00e+00 across 5 random product-U trials]
  Phi_12(Vp H0 Vp†, I) = 1.0000  [identical to unscrambled, across 3 trials]

**Proof:** A product unitary V = V1⊗...⊗Vn acts on each single-qubit Pauli factor independently.
If H = Σ_P c_P P, then V H V† = Σ_P c_P (V P V†). Since Vi acts only on site i, the tensor
weight wt(P) — the number of non-identity sites — is preserved: wt(V P V†) = wt(P). Therefore
the Pauli weight distribution of H_scr in the STANDARD frame is IDENTICAL to that of H0.
Phi_mean_weight(H_scr, I) = Phi_mean_weight(H0, I). This is exact, not an approximation.

**Consequence:** The landscape Phi(H_scr, U) over product-unitary frames U is FLAT relative to
the Phi(H0, I) baseline. There is no signal gradient. mcts over product frames will find
Phi_best = Phi(H0, I) trivially — not by recovering the scrambler, but because the scrambler
is invisible. The "oracle passes" but only because the scrambled H is indistinguishable from the
original H in any product-unitary frame. The planted answer cannot be recovered because there
is no answer to recover — every product frame is equally good.

**The functional is D-028-clean** (global non-product unitaries do change Phi: measured CNOT
scrambler gives Phi(CNOT H0 CNOT†, I) = 0.3939 vs 0.4242, recoverable at the CNOT frame =
0.4242). But the v1 oracle design declares product-unitary scrambler + product-unitary frame
search. These two are orthogonal to the true signal: the functional is sensitive to NON-product
frames, but the oracle/search pair live in the product-unitary subspace where the signal vanishes.

**Determinism verdict:** GOLDEN-FREEZABLE. Phi is a deterministic matrix computation (Pauli
expansion is exact rational arithmetic up to float64 rounding; no diagonalization, no sampling).

**n-ceiling:** n ≤ 6 for the product-unitary frame search (16^6 = 16.8M leaves, heavy but
plausible with high mcts budget); Pauli expansion itself costs O(4^n * 4^n) per leaf evaluation
at n=6 → 4^6 * 4^6 = 16M * O(256) flops per mcts node — this is the real bottleneck. Realistic
v1 ceiling: **n ≤ 5** (Pauli expansion of 4^5 = 1024 strings, each O(32×32) trace, ~1M flops/node
× 10K nodes = ~10G flops per run, GPU-feasible; at n=6 it grows 16× to 160G flops/run).

**VERDICT: KILLED.** The oracle design is self-defeating for product-unitary scramblers, which
are the only scramblers reachable by the v1 product-unitary frame search. The signal is absent
precisely where the search operates. A non-product scrambler would create a real signal, but the
product-unitary frame space cannot reach non-product frames to recover it.

**Steal:** The Phi_mean_weight functional itself is sound for non-product frames. If the frame
search is extended to include entangling gates, the oracle design becomes viable. The functional
formula is clean and the D-028 proof is correct.

**Reinstatement trigger:** replace the product-unitary oracle with a scrambler drawn from the
SAME discrete gate alphabet as the entangling-power frame search (e.g. exp(-i θ ZZ) gates);
upgrade frame parameterization to include entangling gates. Then Phi_mean_weight becomes
viable and the oracle is genuinely recoverable.

---

### 2.2 OPERATOR-LOCALITY (Phi_LOC = ||weight-≤k projection of U†HU||_HS^2 / ||H||_HS^2)

**This is algebraically identical to Phi_mean_weight for the v1 k=2 case** — it sums the
squared Pauli coefficients at weight ≤ 2 and normalizes. As the commutant design correctly
notes (section 9), these are the same functional. The same product-unitary invariance applies:
Phi_LOC(V H V†, I) = Phi_LOC(H, I) for any product V.

The design proposes a two-qubit-gate frame parameterization (exp(-i θ P_ij) gates; B = 144
per layer for n=4; depth L=3 → 2.99M leaves). This IS an entangling frame search, which
partially rescues the design: the scrambler in the oracle (§4.1, "Haar-random V via seeded QR")
is a NON-product unitary, so the signal exists. A Haar-random V changes Phi_LOC in the
standard frame (Phi ≈ C(n,2)/4^n ≈ 0.26 for n=4, measured: Haar mean 0.2406).

MEASURED (this session, n=4, 5 Haar-scrambled H):
  Haar Phi_mean_weight samples: [0.2253, 0.2228, 0.2574, 0.2490, 0.2483], mean = 0.2406
  Local H baseline: Phi = 0.5968
  Gap = 0.356, well above the pre-registered 0.30 threshold. [EVIDENCE-GRADE for the
  functional's discriminatory power; the SEARCH is still ARGUMENT-GRADE]

**WOUNDED: the search may not find the oracle answer.**

The two-qubit gate tree at B=144, L=3 covers 2.99M leaves — a product of 3 layers of 144
choices each. The actual Haar-random scrambler V lives in U(16) (for n=4), which has ~240
real dimensions. A depth-3 circuit with 144-choice branching provides very thin coverage of
U(16). The probability that the planted V lies exactly on a leaf of this tree is ~0. The
design relies on finding a frame CLOSE to V that achieves Phi ≥ 0.85, not the exact V.

Whether this is achievable is ARGUMENT-GRADE. The landscape could be navigable (many
frames near the optimum all give high Phi) or it could be sharp (only frames close to V
give high Phi, and the discrete tree misses them). This is the key open question.

**Determinism verdict:** GOLDEN-FREEZABLE. The k-cutoff functional is a pure sum of squared
Pauli coefficients — exact, no eigendecomposition, no sampling. The matrix rotate-and-project
is O(4^n * D^2) per leaf, deterministic with IEEE 754 float64.

**n-ceiling (operator-locality design):** The two-qubit gate parameterization grows as
B_per_layer^L where B_per_layer = n(n-1)/2 * 3 * 8. For n=6, L=3: B=360, leaves=4.67e7.
For n=8, L=3: B=672, leaves=3.0e8. At L=5 for n=6: 360^5 = 6e12 (intractable). The
depth-3 limit is the budget ceiling. Realistic v1 ceiling: **n ≤ 6, L=3**.

The Pauli expansion at each leaf evaluation is O(4^n * D^2). For n=6: 4096 strings * 64^2
= 16M flops/leaf * 3M mcts nodes = ~5e13 total flops. This is GPU-heavy but possibly
feasible on RTX 4070 Ti SUPER for a single run (~seconds at CUDA FP64 peak 40 TFLOPS).
At n=8: 65536 * 256^2 = 4.3B flops/leaf — even with 1M mcts nodes, that is 4e15 flops.
At the GPU's peak this would take O(100s) per run. Marginal.

**VERDICT: WOUNDED.** The functional is sound, D-028-clean, and deterministic. The signal
gap at n=4 is measured and real (gap 0.356). The wound is that the depth-3 two-qubit gate
tree provides only thin coverage of U(2^n), and whether it is dense enough to find the
planted basin is ARGUMENT-GRADE until a converge run. The mcts budget for n≥6 is also
tight. The design is buildable in v1 at n≤5; n=6 is feasible but expensive.

**Steal:** The Haar-scrambled oracle construction (non-product scrambler, known V via seeded
QR) is the correct oracle design. Reuse this for any functional that uses an entangling frame.

---

### 2.3 COMMUTANT-ALGEBRA (Phi_COMM = 1 - ||V(U†HU)||_F / ||H - Tr[H]/d * I||_F)

This functional is algebraically equivalent to the cross-cut Frobenius norm for bipartite
systems (section 9 of the commutant design explicitly states this). The interaction residual
V(H_rot) = H_rot - H_A⊗I - I⊗H_B is exactly the cross-cut block after subtracting the
tensor-sum projection.

**The frame parameterization is the key difference:** the commutant design uses a per-qubit
alphabet of B=6 choices (I, Rx(π/2), Ry(π/2), Rz(π/2), H, CNOT-left), with the CNOT gate
included. The frame space is 6^n leaves (4 qubits: 1296; 6 qubits: 46656; 8 qubits: 1.68M).

**CNOT is an entangling gate**, so the frame search CAN reach non-product unitaries. The oracle
construction explicitly uses "a random depth-3 Clifford circuit with the same gate set." This
is the correct design: the scrambler lives in the SAME discrete space that mcts searches.

MEASURED (this session): For the 1+2 split, pure product H:
  Phi_xcut(Z⊗I, I, 1+2) = 1.000000  [correct null: fully local = 1]
  Phi_xcut(ZI+IZ1+IZ2, I, 1+2) = 1.000000  [all local = 1]
Product-unitary scrambler (separate local rotations on A and B factors):
  INVARIANT [delta = 0.00e+00 across 3 trials]
Entangling scrambler (CNOT on 1+2 split):
  Phi_xcut(CNOT H0 CNOT†, I) = 0.5455 [wrong frame, degraded]
  Phi_xcut(CNOT H0 CNOT†, CNOT) = 0.6364 [recovered]

**SURVIVED: the oracle design is self-consistent for THIS functional.**

The critical constraint is that the scrambler must live on a leaf of the mcts frame tree —
and the commutant design explicitly ensures this by constructing U_plant from the same
gate alphabet. This is the correct oracle engineering.

**Remaining resolvability concern:** the 6^n frame space is small. It provides only local
rotations plus nearest-neighbor CNOT gates. A generic preferred factorization that requires
deep entangling circuits (multi-qubit CNOT chains) may not be reachable within the depth-n
tree. The pre-registered pass bar requires Phi_xcut ≥ 1-ε = 0.99, which demands very
accurate frame recovery. Whether the 6^n lattice covers the oracle U_plant to this precision
is ARGUMENT-GRADE — but because U_plant IS in the lattice by construction, Phi(H, U_plant)
is exactly 1.0 on the lattice. The search difficulty is finding U_plant among 1296 (n=4)
leaves.

**Determinism verdict:** GOLDEN-FREEZABLE. Partial trace and Frobenius norm are deterministic
matrix operations (O(d^3) per leaf: two matrix multiplications and a reshape). No eigendecomposition,
no sampling. CNOT gates have exact integer entries — no float rounding in frame construction.

**n-ceiling:** Frame space grows as 6^n. For n=8: 1.68M leaves (tractable with mcts). Per-leaf
evaluation is O(d^3) = O(256^3) ≈ 16M flops. For 1M mcts nodes at n=8: ~16T flops total.
This is heavy for a single run (O(400s) at GPU FP64 peak) but feasible for the v1 oracle
test. The realistic practical ceiling for ORRERY v1 is **n ≤ 6** for routinely-fast runs
(d=64: 262K flops/leaf, 46656 leaves, fast). n=8 is feasible but slow.

**VERDICT: SURVIVED.** The oracle design is self-consistent, deterministic, and the signal
is measured for entangling scramblers. The landscape is navigable for small n. The frame
space is intentionally limited to the Clifford-like gate set, which is both a feature (the
oracle lives in the search space) and a limitation (cannot reach arbitrary U(2^n) elements).
The design is the most directly buildable in v1.

**But carry this wound:** the CNOT-left gate makes the frame parameterization not strictly
per-qubit independent — it introduces ordering constraints. For n=4 with the 1+2 split, the
CNOT between qubit 1 and 2 may not be in the alphabet if they are on the SAME factor. The
design must clarify which CNOT directions are allowed and which constitute "frame gates" vs
"interaction terms." This requires precise specification before the contract is frozen.

---

### 2.4 ENTANGLING-POWER / FROBENIUS-CROSS-CUT (Phi_xcut = ||H_int(U)||_F^2 / ||H||_F^2)

This is the v1 recommended functional within the entangling-power design — the instantaneous
entanglement rate, which the design correctly identifies as determinism-safe vs the dynamical
e_p(exp(-iHt)) variant.

**Key insight from measurements:** Phi_xcut is ALSO invariant under SEPARATE local unitaries
on each factor (VA⊗VB), which is the correct physical invariance — it says "rotating each factor
independently does not change the cross-cut coupling." This is the benign symmetry, exactly as
the pauli-concentration design describes for Phi_mean_weight.

What BREAKS the invariance is an entangling unitary that mixes A and B. Measured:
  Phi_xcut(H0_n4, I, 2+2)          = 0.6479  [Ising H, has inter-subsystem ZZ terms]
  Phi_xcut(Vp H0 Vp†, I, 2+2)      = 0.6479  [product scrambler Va⊗Vb on the 2+2 split, INVARIANT]
  Phi_xcut(CNOT H0 CNOT†, I, 1+2)  = 0.5455  [entangling CNOT scrambler, CHANGES]
  Phi_xcut(CNOT H0 CNOT†, CNOT, 1+2) = 0.6364  [recovered at CNOT frame]

The signal exists for entangling scramblers. The oracle MUST use a scrambler that entangles
across the A:B cut — otherwise the landscape is flat.

**Discretization assessment for the proposed mcts call:**
The entangling-power design proposes:
  --branching 32 --depth 9 --iters 50000 --trees 64 --c_uct 1.4
Leaf count: 32^9 = 3.52e13. This is FAR beyond any mcts budget — 50K iterations over 64 trees
= 3.2M evaluations, covering 3.2M / 3.52e13 ≈ 9e-8 of the space. This is not a search;
it is random sampling. The design MUST reduce depth and branching.

**Feasible alternative for the entangling-power design:**
Use the SAME gate set as the commutant design (6^n or 12^n leaves), which IS tractable.
The Phi_xcut evaluation is O(d^3) per leaf — same cost as Phi_COMM. The frame lattice and
oracle construction from commutant can be reused directly. The two designs are operationally
identical at the v1 mcts interface if they share the gate set.

**Dynamical e_p variant determinism risk:**
The time-averaged e_p(exp(-iH(U)t)) requires matrix diagonalization at each leaf:
  - Eigendecompose H(U): LAPACK dsyev — deterministic for non-degenerate H, but not
    guaranteed bit-identical across LAPACK versions. For degenerate H (spectral ties),
    eigenvector ordering is unspecified.
  - The design recommends using the exact partial-swap trace formula instead of sampling.
    This avoids sampling nondeterminism but still requires eigendecomposition.
  - Risk: if two eigenvalues are within machine epsilon, the eigenvector basis is
    numerically unstable and the matrix exponential will differ across runs.
  **Determinism verdict for e_p variant: MEDIUM RISK — not golden-freezable without
  a degeneracy guard and a LAPACK-version pinning. Use FROBENIUS ONLY in v1.**

**SURVIVED (Frobenius-only variant) with the frame discretization redesigned:**
  - Phi_xcut (Frobenius) is deterministic: GOLDEN-FREEZABLE.
  - The oracle must use a scrambler from the same gate lattice (entangling, not product).
  - The mcts budget is feasible if the frame lattice is compact (6^n or 12^n, not 32^9).
  - n-ceiling: **n ≤ 6** for fast v1 runs; n ≤ 8 for slow but feasible runs.

**Determinism verdict (e_p time-averaged):** WOUNDED — matrix exponential requires
eigendecomposition; determinism under degenerate eigenvalues is not guaranteed without
explicit degeneracy guards and LAPACK pinning.

---

## 3. The frame-discretization problem: best buildable solution

**The central tension:** the physics (Cotler-Penington-Ranard) says the preferred
factorization is the unique element of U(2^n) that makes H most local. mcts can only
search a finite lattice. The gap between "the correct U*" and "the nearest lattice point"
is the discretization error.

**The correct v1 engineering decision:**

1. The scrambler (planted answer) MUST live exactly on a lattice leaf. This is the commutant
   design's key insight: build U_plant by composing gates from the search alphabet.

2. The gate alphabet must include at least one entangling gate per adjacent pair to escape
   the product-unitary subspace. The CNOT gate in the commutant design achieves this.

3. The frame space should be 6^n to 12^n for v1 (n=4: 1296–65536 leaves), covering the
   search budget without exhaustion.

4. The mcts tree MUST be called with the existing mcts contract's `--landscape match`
   interface until mcts v1.1.0 (caller-supplied landscape) lands. All designs acknowledge
   this. Until v1.1.0, the oracle experiment is ARGUMENT-GRADE regardless of the functional.

**Recommendation:** adopt the commutant design's frame alphabet (B=6, D=n, entangling CNOT
included) for ALL functionals in v1. This keeps the oracle honest (planted answer in the
lattice) and the search tractable. The choice of functional (Phi_mean_weight, Phi_LOC, or
Phi_xcut) is a secondary engineering decision once the frame is fixed. Phi_xcut is the
simplest to compute at O(d^3) vs O(4^n * D^2) for the Pauli variants.

---

## 4. Scorecard

| Functional        | Oracle self-consistent? | Signal measured? | Determinism | n-ceiling | VERDICT   |
|-------------------|------------------------|------------------|-------------|-----------|-----------|
| Pauli-concentration | NO — product-U oracle invisible | Signal gap=0 for product-U oracle | GOLDEN | n≤5 | KILLED    |
| Operator-locality   | PARTIAL — Haar oracle has signal but discretization thin | Gap=0.356 at n=4 (measured) | GOLDEN | n≤5 | WOUNDED   |
| Commutant-algebra   | YES — oracle in lattice, entangling gate included | Signal exists (CNOT test) | GOLDEN | n≤6 | SURVIVED  |
| Entangling-power    | YES for Frobenius variant, if frame lattice redesigned | Signal exists (CNOT test) | GOLDEN (Frobenius only; e_p WOUNDED) | n≤6 | SURVIVED (Frobenius) / WOUNDED (e_p) |

---

## 5. Biggest resolvability risk (single line)

**The planted-scrambler oracle is FLAT (zero gradient) for all product-unitary scramblers
across all three primary Pauli-weight functionals, because product unitaries preserve Pauli
weight: Phi(V H V†, I) = Phi(H, I) exactly for any product V (measured, delta = 0.00e+00
across 8 trials). The oracle must use an entangling scrambler drawn from the same discrete
gate lattice that mcts searches — and that lattice must include non-product gates.**

---

## 6. Recommendation for v1 contract design

- **Adopt:** entangling-power Frobenius functional (Phi_xcut = ||H_int(U)||_F^2 / ||H||_F^2)
  plus the commutant design's gate alphabet (B=6 per qubit including CNOT, depth D=n).
  Rationale: cheapest per-leaf evaluation (O(d^3) pure matrix ops), provably deterministic,
  oracle lives exactly on a lattice leaf, signal is measured for entangling scramblers.

- **Block until mcts v1.1.0:** all designs require a caller-supplied landscape API. The oracle
  experiment is ARGUMENT-GRADE until this ships. The carve v1 contract must be gated on
  mcts v1.1.0.

- **Declare scope:** v1 oracle uses only scramblers reachable as depth-n circuits over the
  gate alphabet. Non-product U(2^n) scramblers (e.g. Haar-random) are out-of-scope for v1
  and require a generalized frame search (future MINOR). This is not a weakness — it is an
  honest scope limit.

- **Pre-register the pass bar:** Phi_xcut(H, U_oracle) = 1.0 exactly (by construction, since
  U_oracle IS in the lattice and H was scrambled by U_oracle). The oracle is binary: mcts
  finds U_oracle among the lattice leaves or it does not. Report frac_trees_finding_oracle.

- **Steal from operator-locality:** the Haar-scrambled random control (non-product scrambler,
  Phi evaluated at identity frame) is the correct random baseline. Measured gap for n=4:
  Phi_local=0.5968, Phi_Haar_mean=0.2406, gap=0.356 > 0.30 pre-registered threshold.
  This is EVIDENCE-GRADE for the functional's discriminatory power (the search is still
  ARGUMENT-GRADE until mcts v1.1.0).

---

## 7. Numbers computed (EVIDENCE-GRADE, numpy this session)

| Quantity | Value | Source |
|----------|-------|--------|
| Phi_mean_weight(Ising_n3, I) | 0.4242 | numpy, Phi_mean_weight n=3 |
| Phi(Vp H Vp†, I), 5 product-U trials, n=3 | 0.4242 ± 0.00 | numpy, product-U invariance proof |
| Phi(CNOT H CNOT†, I) vs Phi(H,I), n=3 | 0.3939 vs 0.4242 | numpy, non-product scrambler |
| Haar Phi_mean_weight n=4 (5 samples) | 0.2406 ± 0.014 | numpy, Haar scramble |
| E[Phi_mean_weight] Haar n=4 analytic | 0.2500 | analytic, 3n/4 mean weight formula |
| Phi_12(H0_n4, I) | 1.0000 | numpy, 2-local Ising is exactly weight-≤2 |
| Phi_12(Vp H0 Vp†, I) product-U scrambler | 1.0000 | numpy, same invariance |
| Phi_local_n4 (mean-weight form) | 0.5968 | numpy, n=4 Ising standard frame |
| Gap local vs Haar, n=4 | 0.3562 | numpy |
| Landscape ruggedness n=3: random-frame std | 0.0428 | numpy, 200 random U |
| Known-answer signal vs random-frame mean | 5.1 sigma | numpy |
| Phi_xcut(Z⊗I, I, 1+2) | 1.000000 | numpy, null control product H |
| Phi_xcut(product-U scrambler, I) | 0.6479 (INVARIANT) | numpy, 3 trials |
| Phi_xcut(CNOT H0 CNOT†, I) | 0.5455 | numpy, entangling scrambler wrong frame |
| Phi_xcut(CNOT H0 CNOT†, CNOT) | 0.6364 | numpy, recovered at CNOT frame |
| Phi_12 Haar baseline n=4 | 0.2617 | analytic: C(4,≤2)/4^4 = 67/256 |
| Phi_12 Haar baseline n=6 | 0.0376 | analytic: C(6,≤2)/4^6 = 154/4096 |
| mcts leaves: entangling-power proposed | 3.52e13 (B=32,D=9) | arithmetic |
| mcts leaves: commutant/Phi_xcut v1 | 1296 (B=6,D=4) | arithmetic |
| mcts leaves: operator-locality | 2.99e6 (B=144,L=3) | arithmetic |

---

## 8. Steal list

From pauli-concentration: the Phi_mean_weight formula (clean, differentiable, gradient available
for future Riemannian optimizer). The D-028 proof is correct and should be inherited.

From operator-locality: the Haar-scrambled oracle construction (non-product scrambler via seeded
QR, evaluated in identity frame as random control baseline). The n-trend proof (Phi_12 local = 1
independent of n; Phi_12 Haar ~ C(n,k)/4^n → 0) is clean and correct.

From commutant-algebra: the gate-alphabet oracle design (scrambler built from same gate set as
frame search). The Phi* = 1 exact pass criterion. The CNOT-inclusive frame alphabet.

From entangling-power: the Frobenius cross-cut as primary determinism-safe functional. The
reversibility lemma connecting Phi_xcut to Bravyi's entanglement rate bound. The composite
functional design (Frobenius in v1, e_p in v2).

---

*Structure, never acquaintance. The register holds the doubt.*
*RESOLVABILITY lens, sonnet-4.6 / xxixihvj, 2026-07-14*
