# lens v1.1.0 — cold-context two-pass verification

**Date:** 2026-07-12 (Sunday), ~19:15 CST (America/Chicago, CST)
**Verifier:** independent cold-context pass (no memory of the v1.1.0 build; rebuilt from source and measured)
**Tool:** `lens` v1.1.0 (additive MINOR over v1.0.0 — adds scene `bhshadow-geo`)
**Toolchain:** CUDA 13.1 (V13.1.80), `-arch=sm_89` (RTX 4070 Ti SUPER), OptiX SDK 9.1.0, MSVC 2022 (vcvars64)
**Repo state:** branch `master`, HEAD `7001041`; lens working-tree changes present (v1.1.0 not yet committed).

---

## OVERALL VERDICT: **CONFORMANT to v1.1.0 — 0 defects (10 / 10 checks passed)**

The cold rebuild reproduces **both** frozen goldens byte-identical:
- v1.0.0 (`bhshadow`)     `blake2b = 11e545b8dfd19ee2d20429c68dd09ccf0da94157f2a48d9bf5b0348bc6766a2b`
- v1.1.0 (`bhshadow-geo`) `blake2b = 914399280d805f8ab78bab230fc865a025ae1de6d7b75cf3ab6c05b627f63ce8`

Both hashes were **independently recomputed** (a from-scratch D-013 canonical serializer over the parsed
JSON values, `hashlib.blake2b(digest_size=32)`) — not merely read from the tool's own stamp — and match
the frozen files exactly. `lens` is an honest additive minor: the v1.0.0 declared schema and golden
reproduce unchanged; the new `bhshadow-geo` scene genuinely DERIVES the Schwarzschild shadow by
integrating null geodesics and agrees with the analytic silhouette, the OptiX render, and the 27πM²
oracle.

---

## Check 1 — COLD REBUILD  ✅ PASS
Deleted `lens.exe`, `lens_device.ptx`, `lens_device_ptx.h`, then ran the exact `## Build` command from
`tools/lens/MODULE.md` (device→PTX; embed_ptx.py; host+lib link) from `tools/lens/`.
- Build exit code **0**, clean (no warnings/errors).
- `lens.exe` regenerated with a **new** SHA256 `2991e843…` (was `246b2e28…`) — proves a true rebuild.
- `lens_device.ptx` (`d0767ce6…`) and `lens_device_ptx.h` (`70f9ae62…`) regenerated **byte-identical**
  to the prior artifacts — the device code + embedder are deterministic (the PTX that produces
  `hit_pixels_rt` reproduces exactly).

## Check 2 — DUAL GOLDEN  ✅ PASS  (CRITICAL)
`.\lens.exe --golden` → exit **0**, and stderr reported BOTH:
```
GOLDEN OK blake2b=11e545b8dfd19ee2d20429c68dd09ccf0da94157f2a48d9bf5b0348bc6766a2b
GEO GOLDEN OK blake2b=914399280d805f8ab78bab230fc865a025ae1de6d7b75cf3ab6c05b627f63ce8
```
Ran `--golden` 3× — stdout SHA256 `88bca840d5bc3eb40d4bd951e1f7598c22c7a3e58fdaa036c5e01a043ece971d`
byte-identical all three runs, exit 0 each. Both goldens reproduce on a cold rebuild.

## Check 3 — ADDITIVE-MINOR PROOF  ✅ PASS  (CRITICAL)
Independent D-013 hash (reconstructed canonical `{seed,params,result,gates,verdict}` from parsed values,
`%.6f` + −0 normalization, blake2b-256):
- `--scene bhshadow --mass 1.0 --width 1024 --height 1024 --engine both --seed 0 --json`
  → `11e545b8dfd19ee2d20429c68dd09ccf0da94157f2a48d9bf5b0348bc6766a2b` == frozen v1.0.0. ✅ (computed, not stamped)
- `--scene bhshadow-geo … ` → `914399280d805f8ab78bab230fc865a025ae1de6d7b75cf3ab6c05b627f63ce8` == frozen v1.1.0. ✅
- `--scene sphere --radius 1.0 …` → `area_oracle=3.141593` (=π), `area_rel_err=0.000028`, `rt_agrees=1`, verdict pass.
`git diff HEAD -- tools/lens/lens.cu` confirms the compute path change is a single dispatch line
(`R.hit_pixels = (P.scene=="bhshadow-geo") ? geodesic_hits(P) : baseline_hits(P, renderBuf);`) — for
sphere/bhshadow this is identical to the old `baseline_hits(P, renderBuf)`. `baseline_hits`, `rt_hits`,
`resolve`, the oracles, and the serializers are untouched. Sphere/bhshadow behavior is provably unchanged.

## Check 4 — THE GEODESIC DERIVATION  ✅ PASS  (the v1.1.0 claim)
`--scene bhshadow-geo --mass 1.0 --width 1024 --height 1024 --engine both --seed 0`:
- **Triple agreement:** `hit_pixels = 366012` (geodesic-derived via RK4 Binet) `== hit_pixels_rt = 366012`
  (OptiX b_crit silhouette); `rt_baseline_delta = 0`; `rt_agrees = 1`.
- `area_measured = 84.820667`, `area_oracle = 84.823002` (= 27π = 84.8230016), `area_rel_err = 0.000028`
  (≈ 2.8e-5) — G-ORACLE-MISMATCH clear.
- **M² law** (`--mass 2.0`): `area_oracle = 339.292007` (= 27π·4 = 339.2920066); `silhouette_radius =
  10.392305` (= √27·2); `hit_pixels = hit_pixels_rt = 366012`, delta 0, rt_agrees 1 (scale-invariant disk
  fraction; `area_measured=339.282669` tracks the M²-scaled oracle to rel_err 2.8e-5).
The shadow is DERIVED from the metric and equals the analytic silhouette + OptiX render.

## Check 5 — SCHEMA  ✅ PASS
Validated bhshadow-geo, bhshadow, sphere, and geo-M2 `--json` envelopes against
`contracts/lens.schema.json` (jsonschema 4.26.0, Draft7) — all **valid**.
- `params.scene` and `result.scene` enums now include `"bhshadow-geo"` (`["sphere","bhshadow","bhshadow-geo"]`).
- `additionalProperties:false` present at top-level, params, and result; adversarially confirmed —
  injecting a bogus field at each level is rejected.
- Declared field-set **identical to v1.0.0**: params = 9 fields, result = 15 fields, unchanged for every
  scene. `git diff` of the schema = exactly two lines, both adding the enum value. No new params/result fields.

## Check 6 — EXIT CODES  ✅ PASS  (never conflated)
- good config (bhshadow-geo, defaults) → exit **0**, verdict `pass`.
- forced oracle mismatch `--tol-oracle 1e-10` on bhshadow-geo → exit **1**, verdict `fail`,
  `{"id":"G-ORACLE-MISMATCH","fired":true,"value":0.000191,"threshold":0.000000}`.
- bad input `--scene bogus` → exit **2**, `error: --scene must be sphere|bhshadow|bhshadow-geo`.
- `--extent 1.0` (≤ silhouette 5.196) → exit **2**, `error: --extent must strictly exceed the silhouette radius`.
Exit 1 (declared negative) and exit 2 (input error) are cleanly separated.

## Check 7 — DETERMINISM  ✅ PASS
bhshadow-geo declared object byte-identical across 3 runs (declared SHA256 `e3baed8e…` all three).
`--seed 0` vs `--seed 12345`: the ONLY difference is the echoed `"seed":N` field (required by the schema,
"echoed for envelope uniformity"); seed-normalized declared objects are identical — nothing *computed*
depends on the seed. The geodesic integration is deterministic; RNG is genuinely reserved/unused.

## Check 8 — RENDER  ✅ PASS
`--scene bhshadow-geo --render out.ppm --width 256 --height 256` → exit **0**, no error. Output is a valid
**P6** PPM: header `P6\n256 256\n255\n` + binary RGB; file size 196623 B = 15 B header + 256·256·3 = 196608 B
pixel data. Non-declared (JSON unaffected).

## Check 9 — HYGIENE  ✅ PASS
- **No `--use_fast_math`** in the build (MODULE.md line 60) or source; the only occurrences are comments
  stating it is NOT used. No `-ftz`/`-prec-div`/`-prec-sqrt` overrides.
- The geodesic **classifier** `lens_integrate_capture` uses only fp64 `+,−,*,/` and comparisons — **zero
  transcendentals** (IEEE-deterministic, arch-portable). (The grid-driver kernel calls `sqrt` for the
  impact parameter `b`; `sqrt` is IEEE correctly-rounded, so determinism holds — consistent with the
  contract's classifier-scoped wording.)
- Firewall present in the emitted `notes` of every envelope: structure-not-acquaintance (III-sealed) +
  the D-030 RT-as-compute-RETIRED scope ("~10x slower … RT is used only for the render and the I-13
  silhouette cross-check").

## Check 10 — SELFTEST  ✅ PASS
`.\lens.exe --selftest` → all 19 assertions PASS, exit **0**. Independently corroborates: blake2b RFC-7693
KATs, exact oracles (b_crit=√27·M, 27πM², πR²), RT↔baseline I-13 agreement, RT/geo determinism, geo
derives 27πM² and matches the OptiX silhouette, and G-ORACLE-MISMATCH gate teeth.

---

## Notes (NOT defects)
- **RT arm toolchain-pinned by design** (`goldens/lens/NOTE.md`): `hit_pixels_rt` (the bhshadow-geo
  cross-check) is pinned to sm_89 + OptiX 9.1.0 + driver 610.47. It reproduced byte-identical here on the pin.
- **Cosmetic:** `contracts/lens.schema.json` still carries `"description": "... Matches ... v1.0.0."` and
  has no top-level version stamp; the schema *content* is correct (enum + additive). Purely descriptive.
- **Cleanup:** temporary verification scratch (`_v_*.json`, `_indep_hash.py`, `_schema_check.py`,
  `_v_geo_render.ppm`) were created under `runs/` during measurement and deleted; no tool source,
  contract, or golden was modified. The freshly-built `lens.exe` / `lens_device.ptx` / `lens_device_ptx.h`
  are (gitignored) build artifacts left in place.
