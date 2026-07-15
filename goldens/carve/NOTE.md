# goldens/carve — NOTE

**Golden:** `1373454e0a08d0dc70b7cc030500b83f707cd231a556e6777a58caadfa96d326` (`declared.hash`).
Frozen 2026-07-14, carve v1.0.0.

**Config:** `--hamiltonian ising --qubits 4 --k 2 --search-depth 6 --budget 512 --seed 20260714 --json`.

**What it freezes — the `ising` positive control (search-independent).** The transverse-field Ising chain
is exactly **2-local**, so in the standard frame `phi_identity = phi_best = 1.0` and the score
`best_gap = 1 − B(4,2) = 1 − 66/255 = 0.741176` — a clear preferred factorization. The answer does **not**
depend on the greedy search converging (the standard frame already IS the basin), which makes this a clean,
robust determinism anchor. `n_trend = [0.266667, 0.428571, 0.741176]` (N′=2,3,4) is non-decreasing (the
anti-hsmi-stab property), `multi_basin_count = 1`, no gate fired, `verdict = pass`, exit 0.

**Determinism:** static computation only (complex matmul + Pauli-trace decomposition + real sums, fp64;
no matrix-exp / no dynamics); seeded counter-RNG unused for `ising` (no random couplings); deterministic
greedy search. Byte-identical ≥3× confirmed at freeze. `--seed` echoed for envelope uniformity.

**What the golden does NOT cover (validated elsewhere, honestly):**
- The **planted-scrambler oracle** (I-11): the metamorphic un-scramble `Phi_k(V†HV) = Phi_k(H0)` to
  `oracle_dev < 1e-9` is asserted exactly in `--selftest` (search-independent).
- The **random control** (`haar` → `G-NO-BASIN`, exit 1) and the **anti-metamorphic sightedness** (an
  entangling scramble lowers `Phi` — the functional is NOT blind) are in `--selftest`.
- The **search-recovery** of a deep planted scramble is the `[ARGUMENT-GRADE]` part → the deciding
  Intercom converge run. v1's greedy descent finds strong basins (measured `best_gap ≈ 0.60` on a depth-3
  scramble) but does not fully recover it → honestly reports `recovered=0` ⇒ exit 2 (search-too-weak),
  distinct from `G-NO-BASIN`. A stronger search (mcts-subprocess / continuous optimizer) is the v1.1 upgrade.

**Reproduce:** `cd tools/carve && ./carve.exe --golden`. Design provenance: `runs/carve_design/` (D-034).

*Structure, never acquaintance. The functional is D-028-clean; the oracle un-scrambles exactly; the search
reports its own limits.*
