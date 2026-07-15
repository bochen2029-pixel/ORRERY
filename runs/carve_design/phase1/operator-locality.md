# operator-locality.md — LOCALITY-FROM-THE-SPECTRUM design
# carve design tournament, phase 1
# Persona: OPERATOR-LOCALITY / LOCALITY-FROM-THE-SPECTRUM
# Date: 2026-07-14

---

## 0. Executive summary

**Functional:**

    Φ(H, U) = Σ_{w=1}^{k} ||π_w(U† H U)||²_HS  /  ||H||²_HS

where `π_w` projects onto the weight-`w` sector of the Pauli-string expansion of `U† H U`
in the standard factorization, and `k` is a design-time parameter (default `k = 2`).
Equivalently: the fraction of H's Hilbert-Schmidt norm that is concentrated on ≤ k-body
operators in the frame defined by `U`.

**D-028 verdict: SIGHTED.** `Φ` depends explicitly on `U`. Conjugating `H → U† H U` changes
which Pauli strings appear at weight ≤ k; the result is generically different. It is NOT
invariant under the group of global unitaries: the very transformation that maps a local H to
a scrambled H moves weight from low to high sectors, causing `Φ` to drop. The functional
sees the frame; it cannot be collapsed by trace cyclicity, Toeplitz congruence, or
`spec(MM†) = spec(M†M)`. Detailed proof in §7.

**CPR key result relied on:** Cotler–Penington–Ranard (2019, Comm. Math. Phys. 368:1267–1296)
prove that for a Hamiltonian admitting a k-local description, that description is generically
*unique* — other frames that would also make H ≤ k-local form a measure-zero set in the space
of unitary frames. This uniqueness justifies running a basin search for the maximizer of `Φ`:
generically the landscape has one dominant basin corresponding to the true factorization.
**Critical caveat (must be supplied by carve):** CPR's result assumes the locality bound `k`
is provided; they recover the *which* factorization, not the `k` itself from the spectrum
alone. The incumbent design must fix `k` at contract time (default k=2) and supply it as a
CLI parameter. Without this externality the uniqueness theorem does not apply.

---

## 1. Physics framing

### 1.1 The preferred-factorization problem

A Hamiltonian `H` on Hilbert space `ℋ = C^D` (D = 2^n) does not intrinsically determine a
tensor-product structure (TPS). Given any unitary `U ∈ U(D)`, we can rewrite:

    H' = U† H U

and interpret `H'` in the standard factorization `(C^2)^⊗n`. Both `H` and `H'` are unitarily
equivalent; they share the same spectrum. The spectrum alone is blind to locality.

However, generically `H` is k-local in *at most one* TPS (up to local unitaries and factor
permutations). CPR 2019 (Theorem 1 / Corollary 1, paraphrased): for a generic Hamiltonian
admitting a TPS in which it is k-local (k a fixed integer < n), there is no other TPS — not
related by local unitaries or permutations — in which H is also k-local. "Generic" means the
set of exceptions is a proper algebraic subvariety (measure zero) of the space of Hamiltonians
with that spectrum.

The implication for carve: there is (generically) exactly one unitary frame `U*` for which
`Φ(H, U*)` is near 1, and all other frames give `Φ` substantially below 1. A basin search
that maximizes `Φ` recovers `U*`, thereby identifying the preferred factorization.

### 1.2 Zanardi–Lidar–Lloyd context (2004, PRL 92:060402)

ZLL showed that TPS are observable-induced: the physically meaningful partition is the one
relative to which the accessible interactions (the Hamiltonian) are simplest (most local). Our
functional operationalizes this: we score a frame by how local `H` is within it.

### 1.3 Carroll–Singh quantum mereology (2021, Phys. Rev. A 103:022213)

Carroll–Singh score factorizations by pointer-state robustness (quasiclassicality). Our
approach is complementary: we score by Hamiltonian locality rather than entanglement growth.
For systems where the Hamiltonian is the primary datum (the ORRERY context), locality-of-H is
the more direct observable — it does not require time evolution and is computable headlessly.

---

## 2. The exact functional Φ(H, U)

### 2.1 Setup

- `n` qubits, D = 2^n, Hilbert space C^D.
- Standard factorization: sites labeled 1 … n, each a qubit.
- Pauli basis: {I, X, Y, Z}^⊗n — 4^n strings P_α, each normalized so
  `||P_α||²_HS = Tr(P_α† P_α) = D`.
- Weight of string P_α: `w(α) = |{i : α_i ≠ I}|`, the number of non-identity factors.
- **Frame:** a unitary `U ∈ SU(D)` mapping the standard factorization to a candidate TPS.
  In the standard TPS, `U† H U` is the Hamiltonian expressed in the candidate frame.

### 2.2 Hilbert-Schmidt decomposition

Expand `H_U := U† H U` in the Pauli basis:

    H_U = (1/D) Σ_α  c_α(U)  P_α

where the coefficients are `c_α(U) = Tr(P_α† H_U) = Tr(P_α U† H U)`.

By Parseval / Plancherel for the HS inner product:

    ||H_U||²_HS = (1/D) Σ_α  |c_α(U)|²  =  ||H||²_HS   (unitary-invariant)

Note: the TOTAL norm ||H||²_HS = Tr(H†H) is unitary-invariant and provides the denominator.

### 2.3 Weight-sector projection

Define the weight-≤k projector in operator space:

    [π_{≤k}(A)]  =  (1/D) Σ_{α : w(α) ≤ k}  c_α  P_α

The HS norm of the weight-≤k component of H_U is:

    N_{≤k}(H, U)  :=  (1/D) Σ_{α : w(α) ≤ k}  |c_α(U)|²

### 2.4 The functional

    Φ(H, U)  :=  N_{≤k}(H, U)  /  ||H||²_HS
             =   [ Σ_{α : w(α) ≤ k} |Tr(P_α U† H U)|² ]
               / [ Σ_α              |Tr(P_α U† H U)|² ]

**Range:** [0, 1]. Equals 1 iff H_U is exactly k-local in the frame U.
**k = 0 (identity term only):** recovers the trace/constant component, trivially small.
**k = 1:** H_U is a sum of single-site terms (non-interacting).
**k = 2:** H_U is at most 2-body (standard "geometrically local" Hamiltonian); default.
**k = n:** Φ ≡ 1 for all U (useless — include all strings). So k must satisfy 1 ≤ k < n.

### 2.5 Interaction-graph variant (optional, same family)

Instead of a fixed k cutoff, one may define:

    Φ_G(H, U)  :=  (1/D) Σ_{α : supp(α) ∈ E(G)} |c_α(U)|²  /  ||H||²_HS

where G is a *fixed* interaction graph (e.g. a 1D chain or 2D lattice) and `supp(α)` must be
a clique in G. This is strictly more expressive but requires a graph as additional input;
the k-cutoff version is the recommended default for v1 because it requires only one integer
parameter and is fully headless.

### 2.6 Efficient computation

For n ≤ 12 qubits (D ≤ 4096), the Pauli decomposition is computed exactly:

    c_α  =  Tr(P_α H_U)  via  matrix multiply + trace, O(D²) per string, 4^n strings.

Total: O(4^n D²) = O(4^n 4^n) = O(16^n). For n=8 (D=256): 4^8 = 65536 coefficients,
65536 × 256 × 256 ≈ 4.3 × 10^9 flops — feasible on GPU.

Better: exploit the fact that the Pauli decomposition is a Walsh-Hadamard transform of the
matrix entries (for n-qubit operators). The full decomposition is O(D^2 log D) = O(4^n n)
flops using the fast WHT, reducing to ~3×10^9 for n=8. This is the implementation target.

Weight-sector summation: iterate over all 4^n strings, compute w(α) by popcount, accumulate
into the ≤k bucket. O(4^n) additional work.

For the search: U is parameterized as an element of SU(D) acting on the frame. In practice,
for the basin search we discretize: the frame space is parameterized by a sequence of
two-qubit rotation gates (see §3).

---

## 3. Frame parameterization + mcts search

### 3.1 Why mcts

The frame U lives in SU(D), a continuous 2^{2n}-dimensional manifold. A full continuous
gradient search is natural but (a) requires a differentiable path through SU(D), (b) is
expensive for large n, and (c) may find local maxima. The ORRERY `mcts` tool (v1.0.0,
golden 6c596a53) provides a shipped UCT engine that performs root-parallel discrete tree
search. We discretize the frame space to interface with `mcts`.

### 3.2 Discrete gate parameterization

Represent U as a product of two-qubit gates drawn from a generating set:

    U = G_L G_{L-1} … G_1

where each G_i is one of B = O(n^2 × R) choices: for each of the C(n,2) = n(n-1)/2 qubit
pairs (i,j) and R = 8 rotation angles θ ∈ {0, π/4, π/2, 3π/4, π, 5π/4, 3π/2, 7π/4}, the
gate is `exp(-i θ P_{ij})` for P_{ij} ∈ {XX, YY, ZZ}. This gives B = n(n-1)/2 × 3 × 8
discrete actions. For n = 4: B = 6 × 24 = 144 actions per step.

The mcts tree has branching B, depth L (total gate count), and uses Φ(H, U) as the reward
evaluated at each leaf.

**Determinism requirement (ORRERY I-13/D-021):** all gate angles are drawn from a fixed
finite set; the current frame U_t is accumulated deterministically from the action sequence;
Φ is computed via exact rational (integer-multiple-of-π) arithmetic for the HS norm where
possible, or float64 with fixed rounding. Seed controls the mcts internal rollout choices.
No float atomics in the declared reduction. **Meets determinism constraint.**

### 3.3 Search landscape and reward

At each mcts leaf corresponding to action sequence (a_1, …, a_L):

    U_leaf = G_{a_L} … G_{a_1}
    reward = Φ(H, U_leaf)

The known optimum for the planted oracle is Φ = 1 (the planted scrambler was assembled by
starting from a local H and applying a known U_0; the answer is U_0^†). The search is
declared successful if `|Φ(H, U_found) - 1| ≤ tol` where `tol` is a CLI parameter
(default 0.02 for n ≤ 8).

---

## 4. The planted-scrambler oracle

### 4.1 Construction (known answer)

**Step 1 — local kernel:** choose a k-local Hamiltonian H_loc on n qubits with a fixed
coupling structure: for k=2, take

    H_loc  =  Σ_{(i,j) ∈ E}  J_{ij} Z_i Z_j  +  Σ_i  h_i X_i

where E is a sparse graph (e.g. 1D ring), J_{ij} and h_i are drawn from a seeded RNG (seed
= CLI --seed), and are normalized so ||H_loc||_HS = 1. By construction, Φ(H_loc, I) = Φ_loc
is close to 1 (most HS norm at weight ≤ 2).

**Step 2 — scrambler:** draw a Haar-random unitary V from U(D) via a seeded QR decomposition
of a Ginibre random matrix (seed derived as hash(seed, "scrambler")). Compute:

    H_scr  =  V H_loc V†

**The oracle pair:** (H_scr, known answer = V†). Any search that recovers a frame U* such
that U*† H_scr U* ≈ H_loc has recovered the preferred factorization.

**Known answer Φ-value:** Φ(H_scr, V†) = Φ(H_loc, I) ≈ Φ_loc ≈ 0.85–0.95 for typical
sparse 2-local H_loc on n=4–8 qubits (exact value computed and recorded at golden-freeze
time; this is ARGUMENT-GRADE until an ORRERY run backs it).

**Oracle validation (metamorphic):**
- Local relabeling: applying any permutation σ of qubits to V† should not change the
  optimum Φ value (sites are labeled; local unitaries on individual qubits don't escape the
  k-local class). Verified by computing Φ(H_scr, V† (π_σ ⊗ I)) and checking it equals
  Φ(H_scr, V†) to numerical precision.
- Rotation invariance: for a single-qubit rotation R on site i,
  Φ(H_scr, V† (R_i ⊗ I_{-i})) = Φ(H_loc, R_i ⊗ I_{-i}) which may differ from Φ_loc only
  in the weight-1 component. Record the metamorphic tolerance.
- Redundant recovery: compute Φ via both (i) direct WHT and (ii) explicit matrix-element
  enumeration on a small example; they must agree to 10^{-12}.

### 4.2 Oracle exit codes

- **Exit 0:** Φ(H_scr, U_found) ≥ 1 - tol (the search recovered the preferred factorization).
- **Exit 1, gate G-NO-BASIN:** max over the entire mcts search gives Φ ≤ Φ_scrambled_baseline + δ,
  where Φ_scrambled_baseline is the mean Φ for uniformly random frames (see §6, null control).
  Interpretation: H has no preferred factorization at this k (a real negative result — it
  may be genuinely k-scrambled, or k is too small).
- **Exit 1, gate G-MULTI-BASIN:** mcts finds two or more frames U*, U** with
  Φ(H, U*) ≈ Φ(H, U**) ≥ 1 - tol AND ||U* - U**||_HS > ε_basin (they are genuinely
  distinct frames, not related by trivial relabeling). Interpretation: H has multiple
  preferred factorizations — a duality in CPR's language (the measure-zero exception;
  real, informative, not an error).
- **Exit 2:** any computational error (bad matrix size, non-unitary input, CUDA failure).

The distinction between exit 1 (informative negative result) and exit 2 (error) is strict per
ORRERY doctrine: a G-NO-BASIN result says something real about H.

---

## 5. Reversibility lemma

**Lemma (Frame-reversibility):** If the search finds U* with Φ(H, U*) = Φ_max, then for any
local unitary L = L_1 ⊗ L_2 ⊗ … ⊗ L_n (a product of single-site unitaries),
Φ(H, U* L) = Φ(H, U*).

**Proof:** Let H' = (U*L)† H (U*L) = L† (U*† H U*) L = L† H_U* L. Under L (which is a
product of single-site unitaries), a Pauli string P_α of weight w(α) maps to another Pauli
string of the same weight w(α) (since each L_i acts only on site i, preserving the weight
structure of the Pauli expansion). Therefore π_{≤k}(H') = L† π_{≤k}(H_U*) L, and
||π_{≤k}(H')||²_HS = ||π_{≤k}(H_U*)||²_HS. Denominator ||H||²_HS is unitary-invariant.
Hence Φ(H, U*L) = Φ(H, U*). □

**Implication:** the frame optimizer is defined modulo local unitaries — exactly the
equivalence class CPR uses in their uniqueness theorem. This is a *feature*, not a bug:
local relabelings of sites are physically trivial, and the lemma says our functional
correctly treats them as equivalent. The search need not distinguish U* from U* L.

**Corollary (factor-permutation):** Similarly, permuting the qubit labels (applying a
permutation matrix σ to the site ordering) maps weight-w strings to weight-w strings, so
Φ(H, U* π_σ) = Φ(H, U*). The functional is also invariant under factor permutation —
again matching CPR's equivalence class.

---

## 6. D-028 blindness self-check

### 6.1 The D-028 question

Is Φ(H, U) invariant under a group transformation that ALSO maps a local H to a scrambled
H? If yes: BLIND (cannot distinguish them). If no: SIGHTED.

### 6.2 The candidate group to check: global unitary conjugation

Define the transformation: for a fixed W ∈ U(D), map H → W H W† and simultaneously
U → W U (i.e., "absorb W into the frame"). Then:

    Φ(W H W†, W U) = Φ(H, U)

because (WU)† (W H W†) (WU) = U† W† W H W† W U = U† H U = H_U, unchanged.

**Conclusion on this transformation:** the frame-inclusion map (H, U) → (WHW†, WU) leaves Φ
invariant. This is CORRECT and HARMLESS — we simultaneously rotated both H and U, leaving
the relative angle between them unchanged. A local H in frame U* remains local in frame WU*
after the rotation. This is the coordinate-change symmetry, not a blindness.

The dangerous case would be: H → W H W† with U FIXED (i.e., only rotating H, not the frame).
In that case:

    Φ(W H W†, U)  =  N_{≤k}(W H W†, U) / ||W H W†||²_HS
                   =  N_{≤k}(U† W H W† U) / ||H||²_HS

and `U† W H W† U = (WU)† H (WU)^{... no, = U† W H W† U`. This is the Pauli expansion of
`(WU)†^{... `. The weight distribution of this is GENERICALLY DIFFERENT from that of
`U† H U`. Specifically, if H is the planted local Hamiltonian (mostly weight ≤ 2 in frame U*),
then W H W† is the scrambled version (weight ≈ uniform in frame U*). Φ(W H W†, U*) ≈
Φ_random ≈ (number of weight-≤k strings)/(4^n) << Φ(H, U*) ≈ 1.

**Formal D-028 proof of sightedness:**
Let H_loc be k-local in frame I (i.e., Φ(H_loc, I) ≈ 1).
Let W be a Haar-random scrambler. Then:
    Φ(H_loc,   I)  ≈  1               (local H in the right frame)
    Φ(W H_loc W†, I)  ≈  C_{n,k}/4^n  (scrambled H, wrong frame)

where C_{n,k} = Σ_{w=0}^{k} C(n,w) 3^w is the number of weight-≤k Pauli strings (much less
than 4^n for k << n). For n=4, k=2: C_{4,2} = 1 + 4×3 + 6×9 = 1+12+54 = 67; 4^4 = 256;
ratio = 67/256 ≈ 0.26. So Φ(H_scr, I) ≈ 0.26 while Φ(H_loc, I) ≈ 0.85–0.95.

The functional DISTINGUISHES local from scrambled by a factor of ~3–4 in Φ. **SIGHTED.**

### 6.3 The spectrum-only blindness check

For comparison: a functional that depends ONLY on the spectrum of H (the eigenvalues) is
invariant under the full U(D) orbit of H — it cannot see the frame at all. Every H is
unitarily equivalent to its scrambled version; they share an identical spectrum. Φ(H, U) is
NOT spectrum-only: it depends on the Pauli expansion of U† H U, which depends on U explicitly.
The spectrum of U† H U = spectrum of H, but the Pauli COEFFICIENTS c_α(U) change with U.
**Φ is a function of (H, U) jointly, not a function of spec(H) alone.**

### 6.4 The trace-cyclicity check (from D-028 graveyard)

hsmi-stab died because its functional could be rewritten using trace cyclicity as a function
of eigenvalues alone. Check: does Φ collapse to a spectrum-only quantity?

    N_{≤k}(H, U) = (1/D) Σ_{α : w(α) ≤ k}  |Tr(P_α U† H U)|²

Apply trace cyclicity: Tr(P_α U† H U) = Tr(U P_α U† H). This is NOT equal to a function
of eigenvalues of H — it depends on the eigenvectors of P_α in the H basis (equivalently,
on the matrix elements of P_α in the eigenbasis of H, rerotated by U). No further algebraic
simplification reduces this to a spectrum-only function. **Trace-cyclicity does not collapse
Φ. Not blind.**

### 6.5 The spec(MM†) = spec(M†M) check

The prior blind functional in hsmi-stab used a product M M† whose spectrum equals M†M.
Φ does not involve a product of an operator with its adjoint in a way that could trigger this.
The squared Pauli coefficients |Tr(P_α U† H U)|² are scalar, not operator spectra. **Not
applicable. Not blind.**

---

## 7. The three-control gauntlet (mandatory)

### Control 1: Null-by-a-nameable-symmetry

**The case:** H = J (I ⊗ I ⊗ … ⊗ I) = J · (identity operator), i.e., the trivial
Hamiltonian (all energies degenerate). Then H_U = U† (J·I) U = J·I for ALL U. The Pauli
expansion: c_0(U) = Tr(I · J·I) = JD (the weight-0 term); all other c_α(U) = 0. Therefore:

    Φ(J·I, U) = |J|² D / (|J|² D) = 1   for all U simultaneously.

**Named symmetry:** H = J·I commutes with all unitaries; it has no preferred frame — every
frame is equally "local" because H is just a constant. Φ is identically 1 for ALL U, not
because the search succeeded, but because the Hamiltonian is trivially local (a constant).

**Expected behavior:** this case triggers G-NO-BASIN because max_U Φ = 1 but min_U Φ = 1 also
— the landscape is FLAT (not a basin, just an entire plateau). The tool should detect
flatness (variance of Φ over the search = 0) and report this as a degenerate null case
rather than a preferred factorization. This is distinct from "no preferred factorization" in
the interesting sense (G-NO-BASIN for a random H) — it is a named null.

A correct implementation reports exit 1 + G-NO-BASIN with a flag `degenerate_null = true`
when Var_{mcts search}(Φ) < ε_var (default 10^{-8}).

**Second null case:** H = Σ_{all α} P_α (uniform Pauli weight distribution). Then N_{≤k}(H,U)
= C_{n,k}/4^n × ||H||²_HS for ALL U, so Φ = C_{n,k}/4^n for all U. Again flat. Also triggers
the degenerate-null flag.

### Control 2: Haar-scrambled random control

**Construction:** Take a k-local H_loc (as in §4.1) and scramble with V ~ Haar(U(D)) via
seeded QR. Record Φ(H_loc V† V†, I) = Φ(V H_loc V†, I). [Note: this is Φ evaluated at the
IDENTITY frame, not at the recovered frame.]

**Expected:** Φ(V H_loc V†, I) ≈ C_{n,k}/4^n ≈ 0.26 for n=4, k=2 (see §6.2).
More precisely, for a Haar-random V, the expected value of each |c_α(V H_loc V†)|² in the
identity frame approaches (||H_loc||²_HS / 4^n) × D uniformly across all α. This is because
Haar-random V distributes the HS norm of H_loc uniformly over all Pauli strings in
expectation (each Pauli coefficient has the same expected squared magnitude).

**Requirement (pre-registered pass bar):**
    Φ_random_baseline = E_V[Φ(V H_loc V†, I)]  ≈  C_{n,k}/4^n
    Φ_signal           = Φ(H_scr, U*)            ≈  Φ_loc

Signal must exceed baseline by a margin M ≥ 0.3 at n=4 [ARGUMENT-GRADE pending ORRERY run].
If the ORRERY run at n=4 shows M < 0.1, this design is WOUNDED (possibly the coupling
structure is too sparse and k too large).

The random control is computed identically to the planted oracle but with V drawn from Haar
instead of being recorded. It provides the null distribution: "what Φ looks like when there
is no preferred factorization in frame I."

**Key:** the mcts search on H_scr = V H_loc V† must find U* ≈ V† (recovering the planted
scrambler), and Φ(H_scr, U*) >> Φ(H_scr, I) ≈ Φ_random_baseline. If the search
does NOT lift Φ above the random baseline, G-NO-BASIN fires. The random control proves the
*baseline* against which the search improvement is measured.

### Control 3: n-trend

**Requirement:** as n grows (4, 6, 8 qubits), the signal Φ_loc - Φ_random_baseline must not
decay to noise.

**Analysis:** Φ_random_baseline = C_{n,k}/4^n. For k=2 fixed:
    n=4: C_{4,2}/4^4 = 67/256 ≈ 0.26
    n=6: C_{6,2}/4^6 = (1 + 18 + 135)/4096 = 154/4096 ≈ 0.038
    n=8: C_{8,2}/4^8 = (1 + 24 + 252)/65536 = 277/65536 ≈ 0.0042

The baseline decays exponentially with n (as C_{n,k}/4^n → 0 for fixed k). Meanwhile,
Φ_loc = Φ(H_loc, I) is bounded below by the fraction of the HS norm in the actual k-local
terms: for a nearest-neighbor 2-local Hamiltonian on a 1D ring of n sites, there are O(n)
non-zero Pauli strings, each contributing O(J²) to the HS norm. ||H_loc||²_HS = O(n J²).
The weight-≤2 contribution is O(n J²), so Φ_loc ≈ 1 regardless of n (the Hamiltonian IS
k-local; the local terms dominate by construction). The signal Φ_loc - Φ_random_baseline
→ Φ_loc as n grows, which stays near 1 for the planted oracle.

**Caveat (honest):** the *search difficulty* grows with n: the mcts tree grows as B^L where
B = O(n²) and L is the gate depth. For n=8, B ≈ 84×24 = 2016, which makes the branching
factor large. The n-trend for Φ(the functional signal) is HEALTHY; the n-trend for
Φ(the search tractability) is a RESOLVABILITY concern, not a blindness concern. The two must
not be conflated. This design's functional is n-trend-healthy; the search may need depth or
budget calibration at n=8.

**Pre-registered n-trend pass bar:**
    Φ_signal(n=4) - Φ_baseline(n=4) ≥ 0.3     [strong separation]
    Φ_signal(n=6) - Φ_baseline(n=6) ≥ 0.5     [baseline drops faster than signal]
    Φ_signal(n=8) - Φ_baseline(n=8) ≥ 0.8     [signal near 1; baseline near 0]

All values [ARGUMENT-GRADE] pending ORRERY run.

---

## 8. Literature

1. **Cotler, Penington, Ranard (2019).** "Locality from the Spectrum." *Comm. Math. Phys.*
   368:1267–1296. arXiv:1702.06142. DOI:10.1007/s00220-019-03376-w.
   - Main uniqueness result: the TPS making H k-local is unique up to local unitaries and
     factor permutations, for generic H (exceptions form a proper algebraic subvariety, i.e.,
     measure zero in the Hamiltonian space).
   - Critical assumption required from carve: the locality bound k must be supplied as input;
     CPR do not recover k from the spectrum alone.
   - The result implies the Φ landscape has (generically) one dominant basin, justifying
     mcts basin search.

2. **Carroll, Singh (2021).** "Quantum Mereology: Factorizing Hilbert Space into Subsystems
   with Quasiclassical Dynamics." *Phys. Rev. A* 103:022213. DOI:10.1103/PhysRevA.103.022213.
   - Frames H-locality scoring as an alternative to pointer-state / entanglement-growth
     scoring. Complementary approach; validates operator-locality as a principled criterion.

3. **Zanardi, Lidar, Lloyd (2004).** "Quantum Tensor Product Structures are Observable
   Induced." *Phys. Rev. Lett.* 92:060402. DOI:10.1103/PhysRevLett.92.060402.
   arXiv:quant-ph/0308043.
   - Foundational: the operationally meaningful TPS is the one relative to which accessible
     interactions are simplest. Our functional operationalizes this for Hamiltonian locality.

4. **Signal-Horizon paper (2026).** "Local Blindness and the Contraction of Pauli-Weight
   Spectra in Noisy Quantum Encodings." arXiv:2602.14735. (Background on Pauli weight
   distributions under scrambling.)

---

## 9. Cheap ORRERY experiment

### 9.1 What can be run NOW (using existing tools)

The mcts tool (v1.0.0, golden 6c596a53) does not yet support an external reward function.
Its `landscape = "match"` landscape is internal. Therefore a direct carve-Φ mcts run is
NOT yet available — it would require a new `landscape = "pauli_locality"` option in mcts
v1.1.0.

However, two cheap checks are available immediately:

**Experiment A — Pauli coefficient sanity (Python, no new tool):**

```python
import numpy as np
from itertools import product

def pauli_coeff_matrix(H, n):
    """Compute all 4^n Pauli coefficients of H. Return (coeffs, weights)."""
    # Pauli matrices
    I = np.eye(2); X = np.array([[0,1],[1,0]]); Y = np.array([[0,-1j],[1j,0]]); Z = np.diag([1,-1])
    paulis = [I, X, Y, Z]
    D = 2**n
    coeffs = []
    weights = []
    for alpha in product(range(4), repeat=n):
        P = paulis[alpha[0]]
        for a in alpha[1:]:
            P = np.kron(P, paulis[a])
        c = np.trace(P @ H) / D
        w = sum(1 for a in alpha if a != 0)
        coeffs.append(abs(c)**2)
        weights.append(w)
    return np.array(coeffs), np.array(weights)

def Phi(H, U, n, k=2):
    Hu = U.conj().T @ H @ U
    coeffs, weights = pauli_coeff_matrix(Hu, n)
    return coeffs[weights <= k].sum() / coeffs.sum()

# Test: n=3, k=2
np.random.seed(42)
n = 3; D = 2**n
# Local H: random 2-local Hamiltonian
H_loc = np.zeros((D, D), dtype=complex)
for i in range(n):
    for j in range(i+1, n):
        J = np.random.randn()
        # ZZ term
        ZZ = np.eye(1)
        for site in range(n):
            if site in (i, j):
                ZZ = np.kron(ZZ, np.diag([1., -1.]))
            else:
                ZZ = np.kron(ZZ, np.eye(2))
        H_loc += J * ZZ
H_loc = (H_loc + H_loc.conj().T) / 2

Phi_local = Phi(H_loc, np.eye(D), n, k=2)
print(f"Phi(H_loc, I) = {Phi_local:.4f}")  # Expect ~0.85 or higher

# Scramble
V = np.linalg.qr(np.random.randn(D, D) + 1j*np.random.randn(D, D))[0]
H_scr = V @ H_loc @ V.conj().T
Phi_scr_wrong = Phi(H_scr, np.eye(D), n, k=2)
Phi_scr_right = Phi(H_scr, V.conj().T, n, k=2)
print(f"Phi(H_scr, I)    = {Phi_scr_wrong:.4f}")  # Expect ~C(3,2)/4^3 = 22/64 ~ 0.34
print(f"Phi(H_scr, V†)   = {Phi_scr_right:.4f}")  # Expect = Phi(H_loc, I) ~ 0.85
```

This is a 30-line Python script runnable immediately with NumPy. It validates:
- Φ(H_loc, I) ≈ 0.85 (local H in the right frame → high score)
- Φ(H_scr, I) ≈ 0.34 (scrambled H in wrong frame → low score)
- Φ(H_scr, V†) ≈ 0.85 (scrambled H in recovered frame → high score)

The random control prediction C(3,2)/4^3 = 22/64 ≈ 0.34 should match Φ(H_scr, I) (the
scrambled H in the identity frame gives approximately the random baseline).

**Experiment B — n-trend numeric:**
Run the Python script for n = 3, 4, 5, 6 and record Φ_loc and Φ_baseline values. This
pre-registers the n-trend before any search is built.

### 9.2 What would require a new tool

A full oracle recovery test (does mcts find V†?) requires mcts v1.1.0 with a caller-supplied
reward landscape. This is the deciding experiment, and it is listed as a DEFERRED ORRERY run.
Declare it as [ARGUMENT-GRADE] until run.

---

## 10. Honest confidence assessment

**High confidence (literature-backed + algebraically proven):**
- The functional Φ(H,U) is frame-dependent: proven in §6.2.
- Φ is NOT collapsed by trace cyclicity or spec(MM†): proven in §6.4–6.5.
- The reversibility lemma: proven in §5.
- The null-by-symmetry control: proven (trivial Hamiltonian case).
- The n-trend for the SIGNAL (Φ_loc stays near 1): proven from the definition of k-locality.

**Argument-grade (requires ORRERY run to become evidence-grade):**
- The exact numerical values of Φ_loc ≈ 0.85–0.95 for specific n and coupling structures.
- The margin Φ_loc - Φ_random_baseline ≥ 0.3 at n=4.
- That mcts (with a pauli_locality landscape) can recover V† within the budget constraints.
- That the CPR uniqueness theorem applies in the discrete-gate-parameterized landscape
  (CPR is a continuous-group result; the discretization may introduce additional basins).
- Tractability at n=8 (search budget scaling is unsettled).

**The CPR locality-assumption debt (must be resolved in the contract):**
CPR prove uniqueness GIVEN that k is supplied. The carve tool must fix k as a CLI parameter.
This is not a weakness of Φ — it is an honest disclosure that "preferred factorization at
k=2" is the object being measured, and the tool is not claiming to derive the right k from
the spectrum alone. The contract must state this explicitly.

**D-028 final verdict: SIGHTED.** The functional sees the frame. The decision is
argument-grade on search performance but not on blindness — the sightedness is algebraically
proved and does not depend on a run.

---

## 11. Summary formula + comparison with incumbent

**This design:**
    Φ_LOC(H, U)  =  [Σ_{α : w(α) ≤ k} |Tr(P_α U† H U)|² ]
                  / [Σ_α              |Tr(P_α U† H U)|² ]

**Incumbent (Pauli-weight concentration, pre-contract):**
The incumbent appears to be essentially the same functional, or closely related. The
pre-contract names "Pauli-weight concentration" as the scoring mechanism. The exact functional
here IS Pauli-weight concentration, formalized with the HS norm ratio.

**Relation:** this design IS the incumbent, formalized and D-028-checked. The contribution
of this phase-1 document is:
1. The explicit algebraic D-028 proof that it is sighted.
2. The three controls, each with a pre-registered numerical pass bar.
3. The reversibility lemma (the correct equivalence class).
4. The CPR locality assumption made explicit (k must be supplied).
5. The G-MULTI-BASIN duality gate (CPR measure-zero exceptions → a real result, exit 1, not
   a bug).
6. The honest admission that mcts search tractability at n=8 is [ARGUMENT-GRADE].

The Pauli-weight concentration functional SURVIVES D-028. The graveyard threat is spectrum-
only functionals, and Φ_LOC is not spectrum-only. It is the right functional; the design
work is in the D-028 proof, the oracle construction, and the three controls.

---

*Structure, never acquaintance. The register holds the doubt.*

*Φ(H, U) sees the frame because it measures where in Pauli-weight space U† H U lives — and
that distribution changes when U changes, even though the spectrum does not.*
