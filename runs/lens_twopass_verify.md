# lens — two-pass cold-context verification report

**Date:** 2026-07-12 18:11:27 -05:00 (Sunday)
**Verifier:** independent cold-context pass (no build memory; rebuilt from source, measured everything)
**Tool under test:** `lens` v1.0.0 (OptiX RT-core renderer + oracle-gated geometric measurement)
**Toolchain:** CUDA 13.1 (V13.1.80), `-arch=sm_89` (RTX 4070 Ti SUPER), OptiX SDK 9.1.0, MSVC 2022 (vcvars64)
**Ground truth:** `contracts/lens.contract.md` v1.0.0 + `lens.schema.json`; golden `goldens/lens/declared.hash`

---

## OVERALL VERDICT: **CONFORMANT to v1.0.0**

All 7 build/golden/anti-stamp steps and all 7 conformance-battery sub-checks (4a–4g) PASS.
**0 defects.** The cold rebuild reproduces the golden byte-identical; the hash is computed (not
stamped); tamper propagates correctly; every contract clause measured holds.

**Reproduced golden hash:** `11e545b8dfd19ee2d20429c68dd09ccf0da94157f2a48d9bf5b0348bc6766a2b`
**Checks passed:** 14 / 14 (steps 1–4g) + step-5 pin comprehension confirmed.

---

## Step 1 — COLD REBUILD — PASS

Deleted `tools/lens/{lens.exe, lens_device.ptx, lens_device_ptx.h}` (confirmed gone: only
`.gitignore, embed_ptx.py, lens_device.cu, lens_params.h, lens.cu, MODULE.md` remained).

Ran the EXACT build command from `tools/lens/MODULE.md` "## Build" block, from `tools/lens/`:
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -ptx -arch=sm_89 -std=c++17 -I"C:\ProgramData\NVIDIA Corporation\OptiX SDK 9.1.0\include" lens_device.cu -o lens_device.ptx && python embed_ptx.py lens_device.ptx lens_device_ptx.h && nvcc -O3 -arch=sm_89 -std=c++17 -I"C:\ProgramData\NVIDIA Corporation\OptiX SDK 9.1.0\include" lens.cu ../../lib/envelope.cpp -o lens.exe -lcuda -ladvapi32'
```
**Result:** nvcc exit 0. All 3 steps ran clean (device→PTX 2370 B; embed→`lens_device_ptx.h` 12407 B;
host+lib link→`lens.exe` 277504 B). No warnings surfaced beyond the routine cudafe TU echo.

## Step 2 — GOLDEN REPRODUCTION — PASS (CRITICAL check)

`.\lens.exe --golden` ran **3×**:
- Run 1: exit **0**, `GOLDEN OK blake2b=11e545b8dfd19ee2d20429c68dd09ccf0da94157f2a48d9bf5b0348bc6766a2b`
- Run 2: exit **0**, same hash
- Run 3: exit **0**, same hash

Printed hash **== `goldens/lens/declared.hash`**, byte-identical across all 3 runs. `hit_pixels_rt=366012`
stable each run (RT determinism on the pin). A cold rebuild reproduces the golden byte-identical — the
CRITICAL gate is GREEN.

## Step 3 — ANTI-STAMP / ANTI-RAYFORMER — PASS

**Computed, not stamped.** Captured stdout of the golden invocation
(`--scene bhshadow --mass 1.0 --width 1024 --height 1024 --engine both --seed 0 --json`). Independently
extracted the canonical declared object — the exact substring from `"seed":` through the close of
`verdict` (excluding tool/version/notes, per D-013) — directly from the emitted bytes, and computed
`hashlib.blake2b(..., digest_size=32)`:
```
INDEPENDENT blake2b-256 : 11e545b8dfd19ee2d20429c68dd09ccf0da94157f2a48d9bf5b0348bc6766a2b
goldens/declared.hash   : 11e545b8dfd19ee2d20429c68dd09ccf0da94157f2a48d9bf5b0348bc6766a2b   MATCH
```
Declared keys extracted in order: `['seed','params','result','gates','verdict']`. The hash covers the
emitted bytes and is genuinely computed.

**TAMPER (`--mass 2.0`)** — PASS on all three sub-assertions:
- (a) declared hash CHANGED: `ac49adf27035aaf475164d8e5868584fa7ed08394cd66de8c465fef773ac2c4a` ≠ golden.
- (b) `area_oracle = 339.292007` ≈ **27π·M² = 27π·4 = 339.29201** — the M² law holds.
- (c) `area_measured = 339.282669` tracks the oracle (`area_rel_err = 0.000028`). `silhouette_radius`
  scaled to `√27·2 = 10.392305`, `extent` to `15.588457`; `hit_pixels` invariant (366012) because the
  scene is self-similar under M-scaling — physically correct, and the area still recovers the oracle.

## Step 4 — CONFORMANCE BATTERY vs the contract

### 4a — SCHEMA — PASS
Validated the golden `--json` output against `contracts/lens.schema.json` with the Python `jsonschema`
Draft7 validator: **VALID**, zero errors. `additionalProperties:false` enforced — injected extra fields
were rejected at top level, inside `params`, and inside `result`. `gates` array has exactly 2 items
(`G-ORACLE-MISMATCH`, `G-RT-DIVERGE`), satisfying `minItems:2`.

### 4b — EXIT CODES (never conflated) — PASS
| invocation | expected | observed |
|---|---|---|
| golden good config | exit 0, verdict `pass` | **exit 0**, `pass` |
| `--tol-oracle 0.0000000001` (bhshadow, baseline) | exit 1, `fail`, G-ORACLE-MISMATCH fired | **exit 1**, `fail`, gate `fired:true` (value 0.000028 > threshold 0.0) — a REAL declared negative, full JSON still emitted |
| `--scene bogus` | exit 2 | **exit 2** `error: --scene must be sphere\|bhshadow` |
| `--extent 5.0` (≤ silhouette 5.196) | exit 2 | **exit 2** `error: --extent must strictly exceed the silhouette radius` |
| `--width 999999` | exit 2 | **exit 2** `error: --width out of range [16,8192]` |

0 (measured), 1 (declared gate), 2 (invalid input) are cleanly separated.

### 4c — I-11 ORACLE — PASS
- bhshadow M=1: `area_oracle = 84.823002 = 27π`, `area_rel_err = 0.000028` (< tol_oracle 0.011719).
- sphere R=2: `area_oracle = 12.566371 = 4π`, `area_rel_err = 0.000028` (< tol).

The measured cross-section reproduces the analytic oracle in both scenes.

### 4d — I-13 PAIRED-ORACLE — PASS
- `--engine both` (bhshadow M=1): `hit_pixels_rt = 366012` (≥ 0), `rt_baseline_delta = 0` (small),
  `rt_agrees = 1`. OptiX RT agrees with the CPU baseline.
- `--engine baseline`: runs with no GPU dependency; `hit_pixels_rt = -1`, `rt_baseline_delta = -1`,
  `rt_agrees = -1` (sentinels, not null); G-RT-DIVERGE `value:-1, fired:false`. Exit 0.

### 4e — DETERMINISM — PASS
`--seed 0` vs `12345` vs `999` (bhshadow, engine both): `result`, `gates`, `verdict` **byte-identical**;
only the echoed `seed` field differs (contract: "reserved; echoed for envelope uniformity"). Same
params (sphere R=1.5, 512², engine both, seed 7) → **byte-identical full stdout** across 2 runs.
lens uses no RNG.

### 4f — FIREWALL + HONEST SCOPE — PASS
`notes` field carries BOTH statements:
- Firewall (§III-sealed): "…it says nothing about whether anything feels (acquaintance) - III-sealed."
- D-004 honest scope: "renders geometry, does NOT integrate curved null geodesics; the geodesic render
  and any RT speedup claim are the pre-registered compute-SPIKE, not asserted here."

Substring checks: `III-sealed`, `acquaintance`, `feels`, `D-004`, `does NOT integrate curved null
geodesics`, `SPIKE`, `speedup` all present.

### 4g — BUILD HYGIENE (no fast-math) — PASS
The MODULE.md build command I ran contains **no `--use_fast_math`** on either the `nvcc -ptx` (device)
or the host compile. Grep of `tools/lens/` finds `use_fast_math` only in negating comments/docs;
`lib/envelope.cpp` has 0 occurrences. Hardware-level confirmation: emitted `lens_device.ptx` targets
`.target sm_89` and contains no `.approx` / `.ftz` instructions (fast-math tells). `-O3` is standard
optimization, not fast-math. Clean per D-021/I-13.

### (belt-and-suspenders) `--selftest` — PASS
`.\lens.exe --selftest` → exit 0, **16/16 [PASS]**: blake2b KATs, exact scene oracles (b_crit=√27·M,
27π M², π R²), extent/tol derivation, baseline edge cases, convergence @512, RT ran + RT↔baseline
agreement, no-gate-at-good-config, RT-deterministic-across-2-runs, and G-ORACLE-MISMATCH gate teeth
(exit 1). Independently corroborates I-11 / I-13 / determinism / gate teeth.

## Step 5 — TOOLCHAIN PIN (NOT a defect) — UNDERSTOOD

Per `goldens/lens/NOTE.md`, the declared `hit_pixels_rt` is an OptiX hardware result that is
**toolchain-pinned by design** (sm_89 + OptiX 9.1.0 + driver 610.47). A driver/OptiX/arch change may
drift it by a few edge pixels and legitimately fire `--golden` (exit 1) — that is the pin's drift
detector, not a tool bug. On this verification host it matched the golden exactly (366012,
`rt_baseline_delta = 0`). The CPU baseline physics (`hit_pixels`, `area_*`) is driver-independent;
`--engine baseline` recovers it if only the RT arm drifts. Confirmed intended, not a defect.

---

## Summary
- Build: clean (3 steps, exit 0). Golden: reproduced byte-identical 3× (exit 0). Hash: computed (D-013,
  independent blake2b match) and tamper-sensitive (M² law verified). Schema: valid + closed. Exit codes:
  0/1/2 distinct. Oracles (I-11) reproduced; RT↔baseline (I-13) agrees; determinism holds; firewall +
  D-004 honest scope present; no fast-math.
- **VERDICT: CONFORMANT to lens v1.0.0. No defects found.**
- No tool source, contract, or golden was modified by this verification.
