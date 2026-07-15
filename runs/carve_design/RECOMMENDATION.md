# carve — design tournament RECOMMENDATION (for the D-026 contract gate)

**From:** the build agent (opus-4.8), synthesizing the Intercom-coordinated design tournament.
**To:** the operator, for the carve contract-open decision. **Status: PROPOSAL — no contract frozen.**
**Headline:** the tournament did its one job — it **caught a circular oracle and a decaying-signal
score before a line of carve code**, the precise failure that PARKED hsmi-stab. Recommendation below is
decision-ready; the numbers marked ⚑ are `[ARGUMENT-GRADE]` and become the tool's first converge run.

## What ran
4 design personas (round 1) → 3 adversarial lenses (round 2, each ran live numpy checks), coordinated
through ORRERY Intercom (room `carve-design`, append-log is the transcript). Artifacts:
`phase1/{pauli-concentration,operator-locality,commutant-algebra,entangling-power}.md`,
`phase2/lens-{blindness,resolvability,oracle-honesty}.md`.

## The scorecard (design × lens)

| design | BLINDNESS | RESOLVABILITY | ORACLE-HONESTY | net |
|---|---|---|---|---|
| pauli-concentration | wounded (oracle circular) | **KILLED** (flat landscape) | survived | functional OK, **oracle dead** |
| operator-locality | wounded (lattice coverage) | wounded (Haar V off-lattice) | **survived (strongest oracle)** | **winning ideas** |
| commutant-algebra | wounded (oracle/search mismatch) | **SURVIVED (most buildable)** | wounded (Φ=1 idealized) | **winning engineering** |
| entangling-power | **self-kills at scale** (n-trend) | survived static / killed dynamic | wounded (Φ=0 idealized) | steal the redundancy check |

**The decisive finding (verified numerically, not argued):** all four functionals are *the same
functional in different languages* — Pauli-weight concentration ≡ commutant tensor-sum projection ≡
low-order cross-cut norm. **None is algebraically blind** (no collapse by trace cyclicity /
spec(MM†)=spec(M†M) / Toeplitz congruence — the hsmi-stab killers do not apply). The danger was never
the functional; it was **the oracle and the scaling**:

1. **Circular oracle (KILL, measured).** A *product-unitary* planted scrambler `V=V₁⊗…⊗Vₙ` leaves Φ
   exactly invariant — local unitaries are the functional's null space (Pauli-weight-preserving;
   measured Φ-gap `= 0.0000`, weight-spectrum diff `1e-17`). The "planted answer" leaves no trace and
   the search landscape is flat. **The scrambler MUST be entangling (non-product).**
2. **Off-lattice oracle (WOUND).** A *Haar-random* entangling `V` is non-circular but lies on no `mcts`
   search leaf (a depth-3 gate tree covers ~9e-8 of U(16)) → recovery becomes unreachable/argument-grade.
3. **Decaying signal (KILL at scale — the hsmi-stab trap).** The raw cross-cut/Frobenius score's random
   baseline decays as ~`2/2^{n/2}` (measured `0.49→0.37→0.22→0.21`, n=2→6); by n≥8 a scrambled H looks
   as "product-like" as a real product H. **A raw score self-destructs; the score must be a GAP over the
   analytic random baseline, pre-registered non-decreasing in n.**

## The recommended design (the reconciliation)

A single functional, with the three lens-findings folded in as the reconciliation the tournament earned:

- **Functional.** `Φ_k(H, U) = ‖ P_{≤k}[ U†HU ] ‖_F² / ‖H_traceless‖_F²` — the fraction of `H`'s
  (traceless) Hilbert–Schmidt norm carried by **≤k-body Pauli strings** in the candidate tensor-product
  structure defined by frame `U`, relative to a **fixed reference TPS** (the anchor that escapes D-028).
  `k` is a **supplied CLI parameter** (CPR: uniqueness is *which* factorization at a given `k`, not *what*
  `k` — operator-locality's honesty point, adopted).
- **The reported score is the GAP, not Φ.** `score = Φ_k(H, U*) − B(n,k)` where `B(n,k)=C(n,k)/4^n·(…)`
  is the **analytic Haar baseline** (Weingarten-pinned, search-independent). This kills the decay trap:
  the gauntlet's n-trend control is a *first-class output*, and the science reads a separation, never a
  raw fraction.
- **Frame search.** `mcts` over a **discrete gate alphabet** (fixed 1-qubit set + CNOT, depth ~n — the
  commutant/resolvability alphabet, `6ⁿ` leaves ≈ 1296 at n=4, within budget).
- **Planted-scrambler oracle (the reconciliation of blindness × resolvability).** Build `V` by composing
  **entangling gates from the SAME search alphabet** at **moderate, tunable depth D**. This is
  simultaneously: **non-product** (non-circular — it moves Φ), **on-lattice** (exactly recoverable —
  `Φ_k(H,U_plant)` is achievable by an `mcts` leaf), and **tunable to sit strictly interior** (planted
  gap between the random baseline and the max, per oracle-honesty — *not* the idealized Φ=1.0/0.0).
- **Gates (both informative, per the pre-contract).** `G-NO-BASIN` (best gap ≤ τ ⇒ H has no preferred
  factorization at this k) · `G-MULTI-BASIN` (≥2 frames tie within ε at the top gap ⇒ degenerate —
  distinguished from search-failure by the planted oracle's *known* answer). A planted run that misses a
  known answer ⇒ `exit 2` search-too-weak (an error, not a negative) — the two failure modes kept
  distinct.
- **Determinism.** Static Pauli-weight / Frobenius computation only (pure `O(d³)` matrix ops,
  golden-freezable). **The dynamical entangling-power / matrix-exponential variant is BANNED in v1**
  (not bit-identical under spectral degeneracy — resolvability).

## The three-control gauntlet (baked into `--selftest`, not optional)

1. **Null-by-a-nameable-symmetry:** `H ∝ I` (or an exact product `H_A⊗I+I⊗H_B`) ⇒ Φ flat / gap ≈ 0 for
   a stated reason (symmetry = U(2ⁿ) / no cross-cut term); `G-NO-BASIN` fires as the correct null.
2. **Haar-scrambled random control:** a genuinely scrambled H ⇒ best gap < τ; the real planted signal
   MUST exceed this by the pre-registered margin (≥ 0.30 ⚑) — measured `0.356` at n=4 (blindness lens,
   Haar V), above threshold.
3. **n-trend:** the planted-minus-random GAP must be **non-decreasing** in n (the anti-hsmi-stab gate).
   This is the single most important scaling check and a declared result field.

Plus the **metamorphic invariances** carve MUST assert (oracle-honesty): `Φ(H,UL)=Φ(H,U)` for local
`L`; `Φ(H,Uπ)=Φ(H,U)` for factor permutation; and the **anti-metamorphic sightedness test**
`Φ(VHV†,U)≠Φ(H,U)` for non-product `V` — all to 1e-12.

## Graveyard (each with a pre-registered reinstatement trigger)

- **Product-unitary planted scrambler** — BURIED (circular; Φ-gap = 0 measured). *Reinstate iff* a
  functional provably sensitive to local unitaries is proposed (none in this class is).
- **Raw (un-normalized) Φ as the reported score** — BURIED (n-trend decays to noise). *Reinstate iff*
  expressed as a gap over a search-independent baseline.
- **Dynamical entangling-power (matrix-exp) score** — BURIED for v1 (nondeterministic under degeneracy).
  *Reinstate iff* a bit-identical, degeneracy-safe propagator lands (a v2 candidate).
- **Haar-random (off-lattice) oracle scrambler** — BURIED (recovery unreachable by `mcts` v1).
  *Reinstate iff* the search moves to a continuous frame optimizer with a convergence certificate.

## Steal list (harvested regardless of each design's fate)
- operator-locality: **k as a supplied CLI parameter** + the **analytic Haar baseline** `C(n,k)/4ⁿ`
  (the honest, search-independent failure-mode separator).
- commutant-algebra: the **on-lattice oracle** (build `U_plant` from the search alphabet) + the
  transparent partial-trace D-028 proof.
- entangling-power: the **propagator-commutation redundancy check** (a second observable that must agree
  at the found frame — D-018 redundant recovery) + the honest determinism triage.
- pauli-concentration: the **fixed-reference-basis anchoring** argument (the D-028 escape) + the
  secondary `Φ₁₂` observable.

## Proposed carve contract sketch (for the gate — NOT frozen)
```
carve --qubits N --k K --hamiltonian {planted|haar|product|ising|file} [--scrambler-depth D]
      --search-budget B --seed S [--json|--csv PATH] [--selftest] [--golden]
  result: {best_gap, best_frame, planted_gap(if planted), haar_baseline, n_trend[], multi_basin_eps,
           recovered_vs_planted, redundancy_agree}   gates: G-NO-BASIN, G-MULTI-BASIN
  exit 0 basin found | 1 a gate fired (no-basin / multi-basin — a REAL result) | 2 search-too-weak/error
  determinism: static Pauli-weight, fp64, no matrix-exp, fixed mcts seed; oracle on-lattice.
  I-11 oracle: planted-scrambler known answer + analytic Haar baseline (Weingarten).  §III-sealed.
```
**Open questions for you (the gate):** (a) v1 qubit ceiling — resolvability says n≤6 comfortable, ≤8
slow; (b) is `k=2` the default, or expose a k-sweep; (c) language — CUDA per the pre-contract (the `4ⁿ`
Pauli expansion is the GPU case) vs. a C++/Eigen v1 at n≤6 then CUDA at scale; (d) whether the deciding
converge run (below) should be a build-gate before the golden freezes.

## The pre-registered deciding experiment (run once carve exists)
An Intercom **converge run** (`target` mode): falsifier = `carve` on the **planted** oracle, metric =
`recovered_vs_planted`, pre-registered pass = recovers the known frame AND `planted_gap − haar_baseline
≥ 0.30` with a non-decreasing n-trend to n=6. Until that runs, the recommendation is `[ARGUMENT-GRADE]` —
the register holds the doubt.

*The tournament caught a circular oracle the way hsmi-stab wished someone had. Structure, never
acquaintance. The register holds the doubt.*
