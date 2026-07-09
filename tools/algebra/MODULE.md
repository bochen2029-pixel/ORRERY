# MODULE — `algebra`


**v1.0.1 (2026-07-09): migrated to `lib/` (liborrery, D-020) — [BEHAVIOR-NEUTRAL], golden `1526918f` reproduced bit-identical 3× post-migration; envelope/CLI spine now `lib/envelope.h` (KAT-pinned; no RNG in this tool). SOLVER_OK stays local (cuSOLVER-specific).**

*The fifth ORRERY tool, and the second two-pass-critical citable one. cuSOLVER. Copies `someone`'s envelope/determinism/golden/two-pass shape. Read `contracts/algebra.contract.md` (v1.0.0) first — the contract is authoritative.*

**Status: DONE v1.0.0** — built, golden frozen (`1526918f`, 3× byte-identical), selftest green (8 checks, validated against the science's own receipt). Critical c=0.9963; massive control c=0.0.

## Purpose
Reproduce the **ground-truth-checked, receipted half** of the crossed-product entropy story (F16 / debt D-CP): the UV-**divergence** of the vacuum block entanglement entropy of a **critical free-boson chain**, verified against the exact CFT law `S=(c/6)ln(chord)+const` with **c=1** (Calabrese–Cardy), with a **massive chain as the negative control** (S saturates, c≈0). Computed exactly via cuSOLVER — no Monte Carlo, no RNG.

## SCOPE GUARD (sacred — the §III firewall AND the confabulation guard)
**This measures an entropy-scaling law (structure/physics); it says nothing about qualia — §III-sealed.** Two further guards, both in the JSON `notes`:
- **Deliberately narrow scope (do NOT overclaim):** v1.0.0 computes ONLY the absolute-entropy c-scaling (the leg the receipt checks against ground truth). It does **NOT** compute the Part-B relative-entropy *value* — the science **withdrew** "16.23 bits" as a fraction-of-box-bump artifact (D-CP). The fixed-**site** relative-entropy refit (the owed D-CP-CLOCK fix) is a carefully-scoped **v1.1.0** extension, not a v1.0.0 claim.
- **III₁ caveat:** every finite-dim algebra is Type I (has a trace + finite entropy). This tool reproduces the cutoff-**running** signature that *forces* the crossed product; it does NOT instantiate the trace-free Type III₁ factor. F16 stays [PLACEMENT]; the qualia bridge stays [BRIDGE], sealed.

## Contract
`contracts/algebra.contract.md` v1.0.0 (+ `contracts/algebra.schema.json`).

## Provenance
Ports the Part-A leg of `C:\Fable_LLC\QUALIA_LAB\gym\receipts\toy_cp_divergence.py`. **Validated against it:** the selftest asserts S(64)=0.85219 bits and S(128)=1.01696 bits (the receipt's exact numbers), and the golden reproduces c_measured=0.9963 / slope 0.16605 / s_at_max 1.51508 — matching the receipt's 0.16610 / 1.51508. Reuses `someone`'s validated blake2b/JSON/CLI spine.

## Internal design (as built)
Open chain `K = (−Laplacian, Dirichlet) + m²I`. Per swept size L:
1. `cusolverDnDsyevd(K)` → eigenvalues `w`, eigenvectors `V` (col-major).
2. Custom kernel `kXAPA`: `X_A[i][j]=½Σ_k V[i,k]V[j,k]/√w_k`, `P_A=½Σ_k V[i,k]V[j,k]√w_k` (block = left half, n=L/2).
3. `cusolverDnDpotrf(X_A)` → Cholesky `Lx` (lower; upper zeroed by `kZeroUpper`).
4. Custom kernels `kGemmTN`+`kGemmNN`: `M = Lxᵀ P_A Lx` (symmetric; `= X_A^{½}P_A X_A^{½}` in spectrum, so `eig(M)=ν²`, avoiding a non-symmetric eigensolve).
5. `cusolverDnDsyevd(M)` → `ν²`; `S = Σ_k[(ν+½)ln(ν+½) − (ν−½)ln(ν−½)]` (ν=√max(ν²,¼); nats→bits).
Sweep → least-squares slope of S(nats) vs ln L over the largest `--fit-points` → `c_measured = 6·slope`. cuSOLVER for the numerical core; small custom kernels for the products (I control the col-major indexing, avoiding cuBLAS transpose pitfalls).

## Determinism approach
No RNG, no wall-clock. `K` exact; `cusolverDnDsyevd`/`Dpotrf` (double) are deterministic on sm_89 (verified `--golden` 3× byte-identical, `1526918f`); eigenvalues are **sorted** before the entropy sum (fixed order); the c-fit is an exact least-squares slope. Declared floats `%.6f`. **Cross-version caveat:** cuSOLVER can differ in the last few ULP across CUDA/driver versions; `%.6f` is a tolerance well above that, but a cross-version rebuild should re-verify (or supersede the golden under review).

## Selftest (green — 8 checks)
blake2b KAT; **S(64)==0.85219 & S(128)==1.01696 bits vs the receipt** (the physics is right, checked against ground truth); critical c≈1 (|c−1|<0.05) + divergent + gate clear; massive control c≈0 (|c|<0.15) + not-divergent + gate clear; determinism (×2 identical).

## Golden
`algebra.exe --regime critical --max-size 1024 --num-sizes 5 --fit-points 4 --seed 0 --json` → c_measured=0.9963, divergent, exit 0. Frozen `1526918f` in `goldens/algebra/`; `result.lock` in `runs/algebra_golden.result.lock`.

## Build
Single-file CUDA + cuSOLVER, from `tools/algebra/` (see `BUILD.md`). Fenced so `harness/verify.py` can extract it (note the `-lcusolver`):
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 algebra.cu ../../lib/envelope.cpp -o algebra.exe -lcusolver'
```
Then: `.\algebra.exe --selftest` · `.\algebra.exe --golden` · `.\algebra.exe --regime {critical|massive} <params> --json`.

## Known issues / caveats
- **Perf:** the products `X_A`/`P_A` are custom `O(n²L)` kernels and the two gemms `O(n³)`; fine to `--max-size ~2048`. Very large L wants cuBLAS `Dgemm`/batched cuSOLVER — a v-next optimization (golden-preserving if the numerics match). Extreme `--max-size` can exhaust device memory (K is L² doubles) → clean CUDA OOM → exit 2.
- **The withdrawn value:** v1.0.0 intentionally does not produce the Part-B relative-entropy number; anyone needing it must build the fixed-site v1.1.0 leg with the Casini–Huerta kernel validated against a Fock ground truth (the mechanism-completing, non-artifact refit).
- cuSOLVER cross-version last-ULP drift (see Determinism).

*Sims/computations prove structure (an entropy law), never acquaintance. Build one tool right; freeze its golden; let the science call it.*
