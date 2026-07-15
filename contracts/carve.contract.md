# carve — Contract  v1.0.0

## Purpose (what it measures)

`carve` is ORRERY's **preferred-factorization basin-search instrument** (Wave-1 gear #3, D-026 order
book, Layer-2/P2). It asks: **does a fixed Hamiltonian `H` on `N` qubits pick out a preferred tensor-
product structure (a preferred "carving" into subsystems), or not?** It scores a candidate factorization
frame `U` by the **k-locality concentration** of `H` in that frame — the fraction of `H`'s traceless
Hilbert–Schmidt weight carried by **≤k-body Pauli operators** — reported as a **GAP over the analytic
Haar baseline**, and searches the discrete gate frame for the basin (the frame maximizing the gap).

Its design was selected by an adversarial design tournament (`runs/carve_design/`, D-034 Intercom) that
**caught, pre-contract, a circular oracle and a decaying score** — the failure mode that PARKED
`hsmi-stab`. The decisions that survived that tournament are frozen here.

**The functional** (fixed reference TPS = the standard qubit basis; `P_a` = the `4^N` Pauli strings,
`wt(a)` = its body-count; `c_a(U) = Tr(P_a · U†HU)/2^N`, real since `H` is Hermitian):

```
Phi_k(H,U) = [ sum_{a != 0, wt(a) <= k} c_a(U)^2 ] / [ sum_{a != 0} c_a(U)^2 ]         in [0,1]
B(N,k)     = [ sum_{w=1..k} C(N,w) 3^w ] / (4^N - 1)          the analytic Haar baseline (Weingarten)
gap(U)     = Phi_k(H,U) - B(N,k)          the reported SCORE (kills the n-decay trap; the science reads a separation)
```

`carve` measures **structure** — whether `H` prefers a factorization — NEVER acquaintance/qualia
(§III-sealed). It is not a claim about the continuum/thermodynamic preferred factorization; it measures
the finite-N shadow at a **supplied k**.

## CLI

| flag | type | range | default | meaning |
|---|---|---|---|---|
| --qubits | int | 2 … 6 | 4 | number of qubits N (Hilbert dim 2^N; operator dim 4^N) |
| --k | int | 1 … N−1 | 2 | locality order: concentration on ≤k-body Pauli strings (**supplied — CPR: uniqueness is *which* factorization at a given k, not *what* k**) |
| --hamiltonian | enum | {planted, ising, product, haar} | ising | which H to test (see §Hamiltonians); default = the clean positive control (the golden config) |
| --scrambler-depth | int | 0 … 12 | 3 | `planted`: depth of the ON-LATTICE ENTANGLING scrambler V (0 ⇒ no scramble) |
| --search-depth | int | 0 … 12 | 6 | max layers of the greedy frame descent (the candidate U circuit depth) |
| --budget | int | 1 … 4096 | 512 | max frame evaluations the search may spend |
| --tol | double | ≥ 0 | 0.30 | G-NO-BASIN threshold: min gap for a basin to count (the pre-registered margin) |
| --multi-eps | double | ≥ 0 | 0.02 | G-MULTI-BASIN: a distinct frame within eps of the best gap is a co-basin |
| --recover-tol | double | ≥ 0 | 0.02 | `planted`: \|phi_best − phi_planted\| ≤ this ⇒ the search RECOVERED the known answer |
| --oracle-tol | double | ≥ 0 | 1e-9 | `planted`: metamorphic un-scramble check tolerance (exit 2 SUSPECT if exceeded) |
| --seed | int | ≥ 0 | 20260714 | RNG seed (deterministic counter-RNG: builds `haar` H, the planted V, random couplings) |
| --json | flag | | off | emit the JSON envelope on stdout |
| --csv PATH | path | | off | write the per-frame search trace (step, gate, phi, gap) to PATH |
| --selftest | flag | | off | internal battery incl. the three-control gauntlet + metamorphic invariances; exit 0/1 |
| --golden | flag | | off | run the frozen golden params; print the canonical hash; exit 0/1 vs `goldens/carve/` |

## Hamiltonians (the H under test — and the oracle)

- `ising` — transverse-field Ising on a line (`H = -Σ Z_i Z_{i+1} - g Σ X_i`, g=1): a genuinely **2-local**
  H → has a preferred factorization; `Phi_2(H,I)` is high, gap large. The positive control.
- `product` — `H = H_A ⊗ I + I ⊗ H_B` (exact tensor sum across the middle cut): the **null control** —
  perfectly factorized in the standard frame; used for the nameable-symmetry gauntlet leg.
- `haar` — a seeded GUE-random Hermitian: the **random control** — generically NO preferred factorization;
  `Phi_k(H,U) ≈ B(N,k)` for every frame, gap ≈ 0.
- `planted` — **the oracle** (I-11): `H = V H0 V†` with `H0` = `ising` (known local) and `V` = an
  **on-lattice entangling scrambler** built from the SAME gate alphabet the search uses, at
  `--scrambler-depth` (a Haar-random V would be off-lattice and unrecoverable — a killed design; a
  product V would be circular — a killed design; this V is non-circular AND recoverable). The **known
  answer** is `U* = V†` (up to the frame's local+permutation symmetry): `Phi_k(H, V†) = Phi_k(H0, I)`,
  which is the metamorphic anchor and the recovery target.

## Output (result fields; each typed, with meaning)

| field | type | meaning |
|---|---|---|
| qubits | int | N |
| k | int | locality order used |
| hamiltonian | string | resolved H mode |
| haar_baseline | double | `B(N,k)` — the analytic Haar baseline (search-independent) |
| phi_identity | double | `Phi_k(H, I)` — concentration in the standard frame (H as given) |
| phi_best | double | best `Phi_k` found by the search |
| best_gap | double | `phi_best − haar_baseline` — **the score** |
| phi_planted | double | `planted` only: `Phi_k(H, V†)` — the KNOWN-answer anchor (0 for other modes) |
| planted_gap | double | `planted` only: `phi_planted − haar_baseline` (0 otherwise) |
| recovered | int (0/1) | `planted` only: search reached the known answer (\|phi_best−phi_planted\| ≤ recover-tol) |
| oracle_dev | double | `planted` only: \|`Phi_k(H,V†)` − `Phi_k(H0,I)`\| — the metamorphic un-scramble check (I-11) |
| frames_evaluated | int | number of frames the search scored |
| multi_basin_count | int | # distinct frames within `multi-eps` of the best gap |
| n_trend | array[double] | `best_gap` at N′ = 2…N (same H family, k) — must be non-decreasing (the anti-hsmi-stab gate) |

Doubles serialize `%.6f` (−0 normalized); ints `%lld`; arrays element-by-element inside `[]`. All are in
the D-013 hash domain except tool/version/notes.

## Gates (declared negative-result conditions → exit 1; both informative)

| id | fires when | field | meaning |
|---|---|---|---|
| G-NO-BASIN | best_gap ≤ tol | best_gap | H has **no preferred factorization** at this k (the search found no frame beating the Haar baseline by the margin) — a REAL result (this is what `haar` should do) |
| G-MULTI-BASIN | multi_basin_count > 1 | multi_basin_count | **multiple** inequivalent preferred factorizations tie at the top — degenerate; a REAL result, distinguished from search-failure by the planted oracle's known answer |

`verdict` = `pass` iff no gate fired (a single clear basin above threshold), else `fail`.

## Exit-code semantics (never conflate — the tournament's crux)

- `0` — a single preferred factorization found above the margin (basin found; both gates quiet).
- `1` — a gate fired: **G-NO-BASIN** (no preferred factorization — the honest negative, expected for
  `haar`) or **G-MULTI-BASIN** (degenerate). A declared measurement, not a crash.
- `2` — **error OR search-too-weak**: a bad/out-of-range param; `oracle_dev > oracle-tol` (the metamorphic
  un-scramble check failed ⇒ SUSPECT engine, I-11); or `planted` with `recovered = 0` (the search failed
  to find a KNOWN answer ⇒ the search is too weak — NOT a physics negative). Keeping "search too weak"
  (exit 2) distinct from "no preferred factorization" (exit 1, G-NO-BASIN) is the oracle's whole job.

## Determinism

Declared object = `{seed, params, result, gates, verdict}` canonically serialized (D-013: floats `%.6f`,
−0 normalized; tool/version/notes excluded), blake2b-256.

- **Static computation only** — `Phi_k` is a pure `O(d³)` complex matmul (`U†HU`) + Pauli decomposition
  (`c_a` via signed-permutation traces) + real sums, all fp64. **No matrix exponential / no dynamics** in
  the declared path (the dynamical entangling-power variant was BURIED for v1: not bit-identical under
  spectral degeneracy). No float atomics; no fast-math (D-021/I-13).
- **RNG:** the seeded counter-RNG (D-012) builds `haar` H, the planted `V`, and any random couplings —
  a pure function of `(seed, coordinates)`, no wall-clock. The **search is deterministic** (greedy descent
  with a fixed gate-evaluation order and index tie-breaks).
- Same params + seed ⇒ byte-identical declared output.

## The search (v1: self-contained greedy basin descent)

The candidate frame `U` is a circuit over a fixed discrete alphabet (single-qubit `{H, S, T-free rational
rotations}` chosen for determinism + one entangler `CNOT`). v1 does a **deterministic greedy descent**:
from `U=I`, at each layer evaluate every alphabet gate on every qubit/pair, apply the one that most
increases `Phi_k`, repeat to `--search-depth` or until no gate improves by `> multi-eps`, within
`--budget` evaluations; ties broken by lowest (gate,qubit) index. G-MULTI-BASIN restarts the descent from
a small fixed set of seeded frames and counts distinct top-gap basins. **The `mcts`-subprocess search
(pre-contract) is DEFERRED to v1.1** — `mcts` v1 searches only its built-in `match` landscape, not a
caller-supplied one (resolvability lens finding); a `carve`-driving `mcts` needs a custom-landscape hook.

## Golden (the `ising` positive control — a clean, search-independent pass)

params: `--hamiltonian ising --qubits 4 --k 2 --search-depth 6 --budget 512 --seed 20260714 --json`.
The golden is the **positive control**: `ising` is exactly 2-local, so `phi_identity = phi_best = 1.0`
and `best_gap = 1 − B(4,2) = 0.741176` (the standard frame is the basin — the answer does NOT depend on
the greedy search converging), `n_trend = [0.267, 0.429, 0.741]` non-decreasing, no gate fired, exit 0.
Declared blake2b `1373454e…`; reproduced byte-identical ≥3×. Recorded: `goldens/carve/`.

**The `planted` oracle is validated separately** (not the golden, because it exercises the search): the
metamorphic un-scramble `oracle_dev < 1e-9` is asserted exactly in `--selftest` (I-11, search-independent);
the **search-recovery** claim (greedy reaching the known answer) is the `[ARGUMENT-GRADE]` part — the
pre-registered **deciding converge run** (Intercom `target` mode: falsifier = `carve` planted, must show
`recovered=1` at a stated scrambler depth). v1's greedy descent recovers strong basins (measured
`best_gap ≈ 0.60` on a depth-3 scramble) but does NOT fully recover deep scrambles → it honestly reports
`recovered=0` ⇒ exit 2 (search-too-weak), kept distinct from `G-NO-BASIN`; a stronger search
(mcts-subprocess / continuous optimizer) is the named v1.1 upgrade. The register holds the doubt.

## Deferred (honest scope — named v1.1+/v2, NOT in v1.0.0)

- **`mcts`-subprocess frame search** (the pre-contract's v1 plan) — awaits an `mcts` custom-landscape
  hook; v1 uses a self-contained greedy descent.
- **Continuous frame optimizer** (Riemannian descent on U(2^N) with a convergence certificate) — v1
  searches the discrete gate lattice only.
- **N > 6 / GPU** — v1 is host C++ at N ≤ 6 (the `4^N` Pauli expansion is the CUDA case, a v1.1 kernel).
- **k-sweep** (auto-locate the smallest k with a basin) and **arbitrary supplied H from file** beyond the
  built-ins.
- The **theory-facing claim** (that a preferred factorization means emergent classicality) is the
  science's to make from carve's structural output — carve measures the shadow, never asserts the moral.

## Change log
- v1.0.0 — initial contract. k-locality Pauli-weight concentration scored as a gap over the analytic
  Haar baseline; on-lattice entangling planted-scrambler oracle (I-11 known answer + metamorphic
  un-scramble check); greedy discrete-frame basin descent; gates G-NO-BASIN / G-MULTI-BASIN; the
  three-control gauntlet + metamorphic invariances in `--selftest`; golden gated on the deciding converge
  run. Design selected by the `runs/carve_design/` tournament (D-034).
