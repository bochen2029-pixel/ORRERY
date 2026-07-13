# trace-born — cold-context two-pass verification

**Verifier:** independent adversarial cold-context pass (no memory of the build).
**Date:** 2026-07-13
**Repo HEAD:** `768a2dd70bd56e9afa3efeef037ccb22642157ae` (branch `master`)
**Working tree:** dirty — the tool, contract, schema, golden dir, MODULE.md, and this report are all
**untracked** (`??`) at verification time (`tools/trace-born/`, `contracts/trace-born.*`,
`goldens/trace-born/`). The build was **cold** (exe deleted and rebuilt from source below); nothing under
version control was modified by this verification.
**Tool:** `tools/trace-born/trace-born.cu` v1.0.0 (CUDA 13.1 + cuSOLVER, `-arch=sm_89`, RTX 4070 Ti SUPER).

## OVERALL VERDICT: **CONFORMANT to v1.0.0.**  Scope honest, no overclaim. No defects.

**checks passed: 11/11.**

The frozen golden hash reproduces exactly and — decisively — is **independently recomputable** from the
declared object by a from-scratch Python blake2b (not a stamped constant). The I-11 analytic oracle is a
**genuinely independent** second computation, confirmed by the materialized-state purity/off-diagonal path
tracking the closed-form physics off-golden to 6 decimals. The negative control **discriminates** (a clean
quantum-Darwinism R-sweep drives `born_max_dev`→0 as decoherence completes). The one undischarged premise
(noncontextual credence = f(local state), Baker 2007, **D-BORN**) is labeled and excluded from every claim;
the qualia firewall is carried verbatim in the emitted `notes`. Nothing in the tool claims to "derive the
Born rule" full-stop or to measure experience.

---

## ENGINEERING checks

### Check 1 — cold rebuild from source: **PASS**
Deleted `trace-born.exe`, rebuilt via the exact MODULE.md build command **from `tools/trace-born/`**:
```
cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 trace-born.cu ../../lib/envelope.cpp -o trace-born.exe -lcusolver'
```
- nvcc exit code **0**, no warnings/errors. Produced `trace-born.exe` (343040 bytes — byte-size identical to
  the pre-existing build, a determinism sign).
- Build line confirmed: `-arch=sm_89` ✓, `-lcusolver` ✓ (links cuSOLVER, used for `Zheevd`).
- **No `--use_fast_math`** anywhere. Grep over `tools/trace-born/` for `fast_math|fast-math|ffast|prec-div|
  prec-sqrt|ftz=true` returns only the MODULE.md prose "**fast-math banned**" — the flag appears in neither
  the source nor the build line. Fast-math is BANNED (D-021/I-13) and is honored.

### Check 2 — golden reproduction (CRITICAL): **PASS**
- `.\trace-born.exe --golden` prints
  `GOLDEN OK blake2b=d4e3bf04aef5596635a814a217d8822a5e6a2e1f49fc3f64febe1bdab27c540b` and exits **0**.
- Golden `--json` invocation run **3×**: all three are **byte-identical** (SHA256 of the declared line =
  `0d65e6b06b2b8f4083867f061a1a02df8edf75ba34a2d603edd0db27ac1daee5` for run1, run2, run3, and the
  `--golden` envelope), and each **byte-matches** `goldens/trace-born/stdout.txt` (ordinal `-ceq` = True).

### Check 3 — anti-stamp (hash computed, not hardcoded): **PASS**
- Read the hash path in `lib/envelope.cpp`: `golden_check` computes `blake2b_hex(declared)` on the
  runtime-built declared object and compares to the frozen file — it is not a literal in the tool.
- **Independent recomputation:** extracted `{seed,params,result,gates,verdict}` from the `--json` output and
  re-serialized it canonically **from scratch in Python** (declared key order per the contract; floats
  `%.6f` with −0 normalization; tool/version/notes **excluded** per D-013), then hashed with Python
  `hashlib.blake2b(digest_size=32)`. Result:
  `d4e3bf04aef5596635a814a217d8822a5e6a2e1f49fc3f64febe1bdab27c540b` — **equals the frozen golden hash.**
  This independently confirms both the hash value and the D-013 domain (my reconstruction omitted
  tool/version/notes and still matched).
- **Perturbation:** flipping `born_max_dev` `0.000000`→`0.000001` in the declared object changes the hash to
  `d3eaad900ca2f4f5f3de121503ca666a65609772ffe79de25cee9a1e1fe611ef` — the result fields are genuinely in the
  hash domain; the tool is not ignoring the result.

### Check 4 — selftest: **PASS**
`.\trace-born.exe --selftest` exits **0** — `SELFTEST PASS`, **16 checks**:
blake2b KAT; 9 golden invariants (Born reproduced <1e-9; trace weights == receipt [0.4,0.6]; brute==analytic
oracle <1e-10; cuSOLVER purity == 0.52 = Σ|c_i|⁴; fully decohered offdiag <1e-12; fine-graining flat +
unitary <1e-10; envariance residual ~0 at equal moduli AND break ∈(0.19,0.21) at unequal moduli; verdict
pass + born_reproduced); complex-Hermitian d=3 path (Born + oracle agree <1e-9); the 4-part
partial-decoherence negative control (both gates fire, brute STILL == analytic <1e-9, objectivity_dev>0);
determinism (declared object identical across two runs).

### Check 5 — schema conformance: **PASS**
jsonschema 4.26.0, Draft7. Schema is itself a valid Draft7 schema. Both the golden and a partial-regime
`--json` output **validate cleanly**. Adversarial injection rejected in all three positions
(`additionalProperties:false` enforced): extra top-level key → *"Additional properties are not allowed
('EXTRA_KEY' was unexpected)"*; extra `result` key → rejected at `['result']`; extra `params` key → rejected
at `['params']`.

### Check 6 — exit codes 0/1/2: **PASS**
Full matrix — exit 1 (a real finding) is never conflated with exit 2 (an error):

| case | expected | got |
|---|---|---|
| PASS (golden params) | 0 | **0** |
| GATE fires (`--regime partial --overlap 0.5 --redundancy 2`) | 1 | **1** |
| single branch `--weights 2` | 2 | **2** (`--weights must list 2..8 branches`) |
| `--redundancy 99` (range) | 2 | **2** (`--redundancy out of range [1,24]`) |
| state too large `--weights 1,1,1,1,1,1,1,1 --redundancy 24` | 2 | **2** (`state too large: d^R exceeds 2^26`) |
| unknown flag `--frobnicate` | 2 | **2** (`unknown flag: --frobnicate`) |
| bad `--regime sideways` | 2 | **2** (`bad --regime (full|partial)`) |
| `--overlap 1.5` (range) | 2 | **2** (`--overlap out of range [0,0.99]`) |
| `--weights 2,3 --branches 3` mismatch | 2 | **2** (`--branches != number of --weights`) |

The G-BORN-MISMATCH gate fires with a genuine result (exit 1) in the partial regime; the SUSPECT path
(`oracle_max_dev > 1e-8` → exit 2, I-11) is wired at trace-born.cu:236 (present and correct; not reachable
without corrupting the tool, since brute==analytic to ~0 everywhere tested).

### Check 7 — determinism / `--seed` inert: **PASS**
`--seed 0` vs `--seed 999`: with the (legitimately echoed) seed field removed, the declared envelopes are
byte-identical — `--seed` does not change the declared output. Additionally, a **non-golden** complex config
(d=3, R=4, partial, overlap=0.3, phase=1.1, seed=42) is byte-identical across 3 runs, confirming determinism
is not special-cased to the golden.

---

## PHYSICS-SCOPE honesty (checks 8–11) — the RAYFORMER lesson

### Check 8 — is the I-11 oracle real (two genuinely independent computations)? **PASS**
Source-read: the two paths are structurally different.
- **Brute force:** `kBuildState` materializes the dense `|Ψ⟩ = Σ_i c_i|i⟩|r_i⟩^{⊗R}` (dim `d^{R+1}`);
  `kOverlap` contracts `num_i = Σ_a |Σ_E (Π_k r_i[e_k])·Ψ[a,E]|²` over all `d^R` environment configs;
  `kRhoS` reduces `ρ_S` by ordered partial trace; cuSOLVER `Zheevd` gives the purity. **A state is built and
  reduced.**
- **Analytic (I-11):** a closed-form host loop `num_i = Σ_a |c_a|²·(G_{ia})^{2R}` — **no state ever built.**

Empirical independence: `oracle_max_dev` = 0.000000 on the golden AND on two off-golden partial cases
(R=2 s=0.5; complex d=3 R=3 s=0.7 phase=0.5), while the *physics being measured swings substantially*
(`born_max_dev` 0→0.0476, `offdiag_max` 0→0.140). If the brute force were the analytic formula in disguise,
the `offdiag_max`/`rho_purity` path (driven by `kRhoS` + cuSOLVER, which the num-formula never feeds) could
not independently track `s` and `R`. **Independent numpy cross-check** of the R=2 s=0.5 case reproduces every
declared quantity to 6 decimals from the materialized-state physics:
`offdiag_max = |c₀||c₁|s^R = 0.122474` ✓ · `rho_purity = Σ|c_i|⁴ + 2(|c₀||c₁|s^R)² = 0.550000` ✓ ·
`born_max_dev = 0.011765` ✓ · `objectivity_dev = 0.028235` ✓. The oracle is genuinely independent.

### Check 9 — "Born reproduction": honest claim or tautology? **PASS (honest)**
- **(a) The undischarged premise is labeled and excluded.** The contract SCOPE (❌ bullet), MODULE.md scope
  guard, the source `FIREWALL` string, and the golden NOTE all name it: **noncontextual credence = f(local
  state alone)** (envariance→equal-credence; **Baker 2007's circularity objection**; science debt **D-BORN
  [OPEN/W]**), *excluded from every claim*. The contract keeps F15's placement at
  `[DERIVATION-with-labeled-premise]` and the felt-probability identification at `[BRIDGE]`, §III-sealed.
- **(b) The negative control is present and honest** (verified live in check 10): at partial decoherence Born
  is NOT reproduced.
- Every occurrence of "derive" in the tool's canon is a **negation** ("does NOT derive the one premise").
  There is **no** bare "derives the Born rule" claim anywhere. Not a tautology: at full decoherence
  `Tr(Π_i ρ)=|c_i|²` is *forced by the mechanics* and cross-checked two ways; off-decoherence it demonstrably
  fails. The `born_reproduced` bool is guarded by `G-NOT-DECOHERED` so a coherent-state false-pass cannot
  masquerade as a decoherence result.

### Check 10 — does the negative control actually discriminate? **PASS**
`--regime partial --overlap 0.5 --redundancy 2 --weights 2,3`: `born_max_dev = 0.011765 > tol`
(G-BORN-MISMATCH fires) and `offdiag_max = 0.122474 > coh_tol` (G-NOT-DECOHERED fires); exit 1.
**Quantum-Darwinism R-sweep at fixed s=0.5** (objectivity completing):

| R | born_max_dev | offdiag_max (≈ s^R) | G-BORN | G-NOT-DEC | exit |
|---|---|---|---|---|---|
| 1 | 0.040000 | 0.244949 | fire | fire | 1 |
| 2 | 0.011765 | 0.122474 | fire | fire | 1 |
| 3 | 0.003077 | 0.061237 | fire | fire | 1 |
| 5 | 0.000195 | 0.015309 | fire | fire | 1 |
| 8 | 0.000003 | 0.001914 | — | fire | 1 |
| 10 | 0.000000 | 0.000478 | — | fire | 1 |
| 12 | 0.000000 | 0.000120 | — | fire | 1 |

`born_max_dev` decays monotonically to 0 and `offdiag_max` halves per R (exact `0.5^R`) — increasing
redundancy drives the record read-out back to Born (the objectivity result). The control tracks the physics;
it is not a rubber stamp.

### Check 11 — firewall / qualia line: **PASS**
The `FIREWALL` string is emitted **verbatim in the `notes`** of every `--json` envelope (seen in the golden
output) and reproduced in MODULE.md and the contract: *"…It says nothing about why a probability is
experienced: structure, never acquaintance (qualia). III-sealed."* Nothing in the tool measures or claims
experience/acquaintance. The "structure not qualia" / §III-sealed line is carried on every surface
(source comment header, `FIREWALL` const, envelope `notes`, MODULE.md scope guard, contract firewall,
golden NOTE).

---

## Defects / overclaim findings
**None.** No engineering defect; scope is honest (no "derives the Born rule" claim; premise labeled+excluded;
negative control discriminates; qualia firewall present). One incidental note (not a defect): the **prototype**
`_prototype/born_proto.py` computes its "brute-force" `w_trace` via the closed-form `(r_i·r_a)^{2R}` shortcut
(lines 40–48) rather than contracting the materialized `psi` — so the *prototype's* BF/analytic paths are not
mutually independent. This does **not** affect the tool: the CUDA `kOverlap` performs the real contraction
over the materialized `Ψ`, and check 8 confirms empirically (via the independent purity/offdiag physics) that
the tool's two paths are genuinely independent. The prototype is design evidence, not the shipped path.

## checks passed: 11/11
