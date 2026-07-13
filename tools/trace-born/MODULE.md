# trace-born — Module

## Purpose (2 sentences)
`trace-born` measures whether the **normalized-trace weight over a redundancy-defined branch projection**
reproduces the **Born weight** `|c_i|²` in a finite **decohering** model — the mechanical, ground-truth-checked
core of science **F15 · Born from noncontextual credence** `[DERIVATION]` (Zurek envariance + quantum
Darwinism; receipt `toy_a1_born_finegrain.py`). It computes the weight by **brute-force full-state
construction + partial trace** and cross-checks it against the exact **analytic Gram-overlap oracle** (I-11),
adding the STEP-A envariance and STEP-B fine-graining witnesses and a partial-decoherence negative control.

## Scope guard (structure not qualia)
A passing run shows a **structural** fact: in this finite decohering model, the redundant-record trace-weight
equals `|c_i|²`, and unitary fine-graining forces the quadratic form. It does **NOT** derive the one premise
F15 rests on — **noncontextual credence = f(local state alone)** (envariance→equal-credence; Baker 2007's
circularity objection; science debt **D-BORN** `[OPEN/W]`). That premise is *labeled, carried in `notes`, and
excluded from every claim* — the honest residue (the `algebra` Part-B analogue). It says **nothing about why a
probability is experienced** — sims prove **structure, never acquaintance** (qualia). **§III-sealed.**

## Contract: ../../contracts/trace-born.contract.md  (v1.0.0)
Schema: ../../contracts/trace-born.schema.json. Gate `G-BORN-MISMATCH` (born_max_dev > tol → the C-TRACE gun)
+ `G-NOT-DECOHERED` (offdiag_max > coh-tol → coherent-state false-pass guard). Exit 0/1/2 per the universal
envelope; exit 2 also on `oracle_max_dev > 1e-8` (brute force disagrees with the analytic oracle ⇒ SUSPECT,
I-11).

## Internal design (kernels, data layout, the reduction-determinism approach)
- **Records:** `d` real record vectors `r_i` (rows of the Cholesky factor of the Gram `G=(1−s)I+sJ`), so
  `<r_i|r_j> = G_{ij}` (`s = overlap`; `s=0` ⇒ `r_i = e_i`, complete decoherence). Amplitudes
  `c_i = √(w_i/M)·e^{i·i·phase}` (complex-Hermitian path when `phase≠0`; golden `phase=0`).
- **State (device):** `kBuildState` materializes the dense `|Ψ⟩ = Σ_i c_i |i⟩|r_i⟩^{⊗R}` (`d^{R+1}` complex
  doubles) — the un-shortcut computation. Guard: `d^{R+1} ≤ 2^26` (die 2 otherwise; the golden is `2^7`).
- **Partial trace (device):** `kRhoS` — one thread per `(a,b)`, an **ordered serial sum** over the `d^R`
  environment configurations of `Ψ[a,E]·conj(Ψ[b,E])` → `ρ_S` (d×d). No atomics, fixed order ⇒ deterministic.
- **Trace weights (device):** `kOverlap` — one thread per `(i,a)`, ordered sum over `E` of
  `(Π_k r_i[e_k])·Ψ[a,E]` → `overlap[i][a]`; `num_i = Σ_a |overlap[i][a]|²`; `w_i^{trace} = num_i/Σ num`.
  The single-fragment read `num1_i` (objectivity) uses the same kernel with the projector on fragment 0 only.
- **Spectrum (cuSOLVER):** `Zheevd` (double-complex Hermitian — the extension of `algebra`'s `Dsyevd`)
  diagonalizes `ρ_S`; `rho_purity = Σ λ_k²` (eigenvalues sorted before the sum, fixed order).
- **Host, exact, deterministic:** the **analytic Gram oracle** `B_{ia}=G_{ia}^{2R}` → `w^{analytic}` →
  `oracle_max_dev`; the **fine-graining** `U_E` (block equal-superposition + Gram–Schmidt completion, cap
  `M ≤ 512` in v1.0.0 — the O(M³) witness) → `unitarity_dev`, `microbranch_flat_dev`; the **envariance** 4×4 swap/counterswap →
  `envariance_residual` (equal moduli) + `envariance_break` (run moduli); `flat_dev = max_i|1/d − |c_i|²|`.
- **Determinism:** no RNG in the declared path (`--seed` inert), no float atomics, **fast-math banned**
  (D-021/I-13), sm_89 pin. Declared floats `%.6f` (D-013). Envelope/CLI/hash spine from `lib/` (liborrery).

## Build command (exact; see ../../BUILD.md) — run from `tools/trace-born/`; needs cuSOLVER
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 trace-born.cu ../../lib/envelope.cpp -o trace-born.exe -lcusolver'
```

## Selftest: what --selftest checks
blake2b KAT (via lib); the **analytic 2-branch oracle** (weights `2,3` full ⇒ `w=[0.4,0.6]`, born_max_dev &
oracle_max_dev ~1e-12; the receipt's numbers); brute-force == analytic Gram on a complex `d=3` case;
fine-graining equalizes to `1/√M` (`microbranch_flat_dev`, `unitarity_dev` ~1e-14); envariance residual ~0 at
equal moduli and > 0 at unequal moduli; the **partial-decoherence control** fires both gates
(born_max_dev > tol, offdiag_max > coh-tol); determinism (declared object identical across two runs).

## Golden: params + where recorded
`trace-born.exe --branches 2 --weights 2,3 --redundancy 6 --regime full --seed 0 --json` — Born `[0.4,0.6]`
reproduced (born_max_dev≈0, oracle_max_dev≈0, offdiag_max=0, rho_purity=0.52, microbranch_flat_dev≈0, exit 0).
Recorded in `../../goldens/trace-born/` (declared.hash + stdout.txt + NOTE.md). Frozen 3× byte-identical.

## Known issues / caveats
- v1.0.0's golden is a small canonical anchor (`2^7` state); the tool is CUDA because its **reason to exist**
  is the exponential `d^{R+1}` regime (large redundancy `R`, the objectivity scaling) that Python cannot reach
  and that reuses `algebra`'s exact-GPU-linear-algebra + I-13 determinism. The per-`(a,b)` ordered reduction
  is compute-bound for large `R` (a v1.1 tiling target).
- The **noncontextual-credence premise is NOT derived** (D-BORN, §III-sealed) — see Scope guard. A `pass`
  requires an actually-decohered state (`G-NOT-DECOHERED` guards coherent false-passes).
- cuSOLVER `Zheevd` last-few-ULP cross-version drift is far below the `%.6f` declared precision.

## Provenance (what prototype it was seeded from)
Sharpens QUALIA_LAB `gym/receipts/toy_a1_born_finegrain.py` (Zurek envariance STEP A + fine-graining STEP B)
into a seeded, GPU-scaled, decohering-model measurement; extends the `algebra` cuSOLVER machinery
(real-symmetric `Dsyevd` → complex-Hermitian `Zheevd`). Design de-risked in `_prototype/born_proto.py` (kept
as evidence — every declared quantity validated in numpy before a line of CUDA).
