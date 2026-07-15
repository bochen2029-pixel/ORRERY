# MODULE — `carve` (v1.0.0)

**Purpose.** ORRERY's **preferred-factorization basin-search instrument** (Wave-1 gear #3, D-026;
Layer-2/P2). Does a fixed Hamiltonian `H` on `N` qubits pick out a preferred tensor-product structure?
It scores a candidate frame `U` by the **k-locality Pauli-weight concentration** of `H`, reported as a
**gap over the analytic Haar baseline**, and searches the discrete gate frame for the basin.

**Contract:** [`contracts/carve.contract.md`](../../contracts/carve.contract.md) (+ `carve.schema.json`).
Authoritative. **Design provenance:** `runs/carve_design/` — the D-034 Intercom design tournament that
selected this functional + oracle and **caught a circular oracle + a decaying score pre-contract** (the
hsmi-stab failure mode).

**Firewall.** Measures **structure** — whether `H` prefers a factorization — never acquaintance/qualia.
§III-sealed.

## Invariants
1. **Oracle-gated (I-11):** the `planted` mode carries a KNOWN answer `U*=V†` (`V` on-lattice), checked
   two ways — the metamorphic **un-scramble** `Phi_k(H,V†)=Phi_k(H0,I)` (`oracle_dev`>tol ⇒ exit 2
   SUSPECT) and **recovery** (the search must reach it; `recovered=0` ⇒ exit 2 search-too-weak). The
   `haar` random control + the analytic baseline `B(N,k)` anchor "no preferred factorization".
2. **The score is a GAP over the analytic baseline** `B(N,k)=Σ_{w≤k}C(N,w)3^w/(4^N−1)`, never a raw
   fraction — so the signal does not decay to noise with N (the anti-hsmi-stab property; `n_trend` is a
   declared non-decreasing gate).
3. **Determinism:** static computation only (complex matmul + Pauli-trace decomposition + real sums,
   fp64); **no matrix exponential / no dynamics** (the dynamical variant was BURIED for v1 —
   degeneracy-nondeterministic). Seeded counter-RNG (D-012) for `haar`/`V`; deterministic greedy search.
   No float atomics, no fast-math (D-021/I-13).
4. **Exit tri-state kept distinct:** 0 basin · 1 a gate fired (G-NO-BASIN / G-MULTI-BASIN — a REAL
   negative) · 2 error OR search-too-weak. Never conflate "no preferred factorization" with "search too
   weak" — that separation is the oracle's whole job.
5. **k is a supplied parameter** (CPR: uniqueness is *which* factorization at a given k, not *what* k).

## Internal design
- **State.** `H` = dense `2^N × 2^N` `std::complex<double>` Hermitian. Frame `U` = a circuit over a fixed
  discrete alphabet (deterministic single-qubit gates + `CNOT`); `U†HU` by two dense complex matmuls
  (N≤6 ⇒ ≤ 64³ trivial), or gate-by-gate conjugation.
- **The functional.** `c_a = Tr(P_a · M)/2^N` for each of the `4^N` Pauli strings `P_a` (real, `M`
  Hermitian), via the signed-permutation action of a Pauli string (`Tr(P_a M)=Σ_l phase_l · M_{perm(l),l}`,
  `O(2^N)` per string). Bin `c_a²` by body-weight `wt(a)`; `Phi_k = Σ_{0<wt≤k}c_a² / Σ_{wt>0}c_a²`.
- **Baseline.** `B(N,k)` closed form (binomial × 3^w). `gap = Phi_k − B`.
- **Hamiltonians.** `ising` (−ΣZZ−gΣX, 2-local, positive control); `product` (H_A⊗I+I⊗H_B, null);
  `haar` (seeded GUE, random control); `planted` (`V H_ising V†`, `V` on-lattice at `--scrambler-depth`).
- **Search.** deterministic greedy basin descent from `U=I` (best-improving alphabet gate per layer,
  index tie-break, to `--search-depth`/`--budget`); G-MULTI-BASIN restarts from a fixed seeded set.
- **Envelope/hash/CLI** from `lib/` (liborrery, D-020): `fmt6`/`fmti`, `declared_object`/`full_envelope`,
  `golden_check`, `die2`/`parse_*`, `blake2b`. D-013 hash domain unchanged; arrays element-by-element.

## Build
Host-only C++ (no GPU kernel in v1; `nvcc` compiles the host TU), from `tools/carve/`:
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 carve.cu ../../lib/envelope.cpp -o carve.exe'
```
```
.\carve.exe --selftest
.\carve.exe --hamiltonian ising --qubits 4 --k 2 --seed 20260714 --json
.\carve.exe --hamiltonian haar  --qubits 4 --k 2 --seed 20260714 --json     # G-NO-BASIN expected
.\carve.exe --hamiltonian planted --qubits 4 --k 2 --scrambler-depth 3 --json
.\carve.exe --golden        # only meaningful AFTER the deciding converge run + freeze
```

## Oracle (I-11) & golden
- Oracle: the `planted` KNOWN answer (`V†`, metamorphic un-scramble to 1e-9) + the analytic Haar baseline
  `B(N,k)`, both asserted in `--selftest`; the three-control gauntlet (product-null / haar-random /
  n-trend) + the metamorphic invariances (local-unitary, permutation, anti-metamorphic sightedness).
- Golden: the **`ising` positive control** — `--hamiltonian ising --qubits 4 --k 2 --search-depth 6
  --budget 512 --seed 20260714`; declared blake2b `1373454e…`; `best_gap=0.741176` (=1−66/255),
  `phi_best=1.0`, `n_trend=[0.267,0.429,0.741]`, exit 0; reproduced byte-identical ≥3× (search-independent
  — the standard frame is the basin). The `planted` search-recovery is the separate deciding converge run.

## Known issues / scope (honest, v1.0.0 — deferred)
- **`mcts`-subprocess frame search** (pre-contract's v1) deferred to v1.1 — `mcts` v1 searches only its
  built-in `match` landscape, not a caller-supplied one (the resolvability-lens finding); needs a
  custom-landscape hook.
- **Continuous frame optimizer** (Riemannian U(2^N) descent + convergence certificate) — v1 is the
  discrete gate lattice; the greedy descent can get stuck (a real negative reported honestly, not hidden).
- **N ≤ 6, host C++** — the `4^N` Pauli expansion is the CUDA case (v1.1 kernel).
- **No k-sweep**, no arbitrary-H-from-file beyond the built-ins.
- **Sub-1e-6 tolerances serialize to `0.000000`** in the declared hash (the D-013 `%.6f` domain): `oracle_tol`
  default `1e-9` shows as `"oracle_tol":0.000000`, so tolerances in `[0, 5e-7)` are indistinguishable in the
  hash. Inherent to the instrument's canonical serialization, not carve-specific; determinism holds and the
  golden pins the config. Flagged by both cold-two-pass verifiers (non-blocking). `runs/carve_twopass_verify.md`.
- Sims prove STRUCTURE, never qualia — the emergent-classicality moral is the science's to draw.
