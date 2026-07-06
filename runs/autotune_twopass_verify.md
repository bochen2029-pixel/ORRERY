# autotune — Two-Pass Cold-Context Verification

**Tool:** `autotune` (Python parameter sweep / basin-finder / real-tool driver)
**Contract:** v1.0.0 (`contracts/autotune.contract.md` + `autotune.schema.json`)
**Frozen golden hash:** `goldens/autotune/declared.hash`
**Verifier:** Independent COLD-CONTEXT pass. No knowledge of the build; treated as a BLACK BOX
verified only against the published contract, schema, and frozen golden hash (RAYFORMER ADR-007
discipline — verify behavior, not claims). MODULE.md science claims / RUN_STATE / DECISIONS were
NOT trusted as truth.
**Date:** 2026-07-06 (local, -0500)
**Runner:** `python C:\ORRERY\tools\autotune\autotune.py ...` — all commands run SYNCHRONOUSLY.

---

## Overall verdict: **CONFORMANT**

All contract-mandated behaviors verified. Zero contract violations. One benign platform note
(a bare forward-slash relative exe path on Windows; every other path form works — see below).

---

## STEP 1 — Harness green + golden hash

| item | result |
|---|---|
| `harness/verify.py --tool autotune` | `OVERALL: GREEN`, exit 0 |
| harness row | `build=OK  selftest=OK  golden=OK` |
| `autotune.py --golden` stderr | `GOLDEN OK blake2b=c79002f2...` |
| golden blake2b vs frozen `declared.hash` | **MATCH** — `c79002f23cf236baab5ecdb5753603a7a3853199f750b0139771d4e6cdd55bbe` |
| golden exit code | 0 |

Golden envelope recovers the built-in `peak` obj-center 0.37: `x_located=0.370091`,
`on_target=true`, `verdict=pass`, `G-OFF-TARGET` not fired.

---

## STEP 2 — Conformance battery (against the contract)

| # | check | expected | observed | verdict |
|---|---|---|---|---|
| a | `--selftest` | exit 0 | `SELFTEST PASS`, 6/6 checks green, exit 0 | PASS |
| b | schema-validate golden `--json` | `jsonschema.validate` OK | `SCHEMA VALIDATE OK` | PASS |
| b | firewall fields | tool/version/notes | `tool="autotune"`, `version="1.0.0"`, `notes` present (III-sealed) | PASS |
| c | locator — golden peak | x_located≈0.37, on_target, exit 0 | `x_located=0.370091`, `on_target=true`, no G-OFF-TARGET, exit 0 | PASS |
| c | locator — threshold crossing (center 0.6) | x_located≈0.6, on_target, exit 0 | `x_located=0.600000`, `f_at_located=0.500000`, `on_target=true`, exit 0 | PASS |
| d | GATE off-target (peak 0.37, target 0.90) | on_target=false, G-OFF-TARGET, verdict fail, **exit 1** | `on_target=false`, `G-OFF-TARGET fired=true` (val 0.5299 > tol 0.02), `verdict=fail`, **exit 1** | PASS |
| e | missing `--target` | exit 2 | exit 2 | PASS |
| e | BOTH `--objective` and `--tool` | exit 2 | exit 2 | PASS |
| e | NEITHER `--objective` nor `--tool` | exit 2 | exit 2 | PASS |
| e | `--objective bogus` | exit 2 | exit 2 | PASS |
| e | `--points 2` (below 3) | exit 2 | exit 2 | PASS |
| f | REAL-TOOL MODE — drive ratchet.exe, find ρ_c | x_located≈0.25, on_target, exit 0 | `objective="tool:ratchet.exe"`, `x_located=0.258051` (3.2% of analytic 0.25), `f_at_located=0.900000`, `on_target=true`, exit 0 | PASS |
| g | determinism — golden ×2 | byte-identical | BYTE-IDENTICAL (sha256 `2f0eeb83...` both) | PASS |
| g | data-boundness | different center → different x | center 0.20→x=0.2, center 0.80→x=0.8 | PASS |

**Exit-code discipline (0/1/2 never conflated):** confirmed. Error conditions → 2 (5/5 cases);
a real off-target negative result → 1 (distinct from error); on-target success → 0.

**CSV schema (extra):** `--csv` emits header `x,f` + one row/grid point — conforms to contract §"CSV schema".

---

## Locator numbers (the tool's whole point)

| locate mode | objective | true feature | x_located | error | on_target |
|---|---|---|---|---|---|
| argmax (parabolic) | built-in `peak` C=0.37 | 0.37 | 0.370091 | 0.000091 | yes |
| crossing (interp, level 0.5) | built-in `threshold` C=0.6 | 0.60 | 0.600000 | 0.000000 | yes |
| crossing (interp, level 0.9) | **ratchet.exe** `p_unwrite_mc` | ρ_c=0.25 | **0.258051** | 0.008051 | yes |

The locator recovers built-in centers to ~1e-4 and recovers a **real tool's** critical point to
within a few percent.

---

## Real-tool mode — does it genuinely find ratchet's ρ_c?

**YES.** autotune subprocessed `ratchet.exe` across `rho ∈ [0.15, 0.45]` (13 points), read
`result.p_unwrite_mc` from each run's JSON, and located the level-0.9 crossing at **ρ = 0.258**,
matching ratchet's analytic `rho_c = p/(1−p) = 0.2/0.8 = 0.25` (and ratchet's own reported
`rho_c=0.250000`) within tol 0.05 → `on_target=true`, exit 0. `objective` reported as
`tool:ratchet.exe`. This is not a stub — it truly drives another tool and finds its critical point.
Notably, ratchet itself exits 1 (its own G-THEORY-MISMATCH gate) at these grid points, yet autotune
still correctly parses ratchet's JSON and completes — robust to a non-zero exit from the swept tool.

---

## Observations (non-defects, no contract violation)

1. **Windows relative-exe path quirk (benign).** A *bare forward-slash* relative tool path
   (`tools/ratchet/ratchet.exe`, no leading `./`) fails with `[WinError 2] file not found` → exit 2.
   This is the standard Windows `CreateProcess`/`subprocess` behavior (a bare forward-slash relative
   path is not resolved against cwd). Every other form works from `C:\ORRERY`: absolute
   (`C:/ORRERY/tools/ratchet/ratchet.exe`), explicit relative (`./tools/ratchet/ratchet.exe`), and
   native Windows relative (`tools\ratchet\ratchet.exe`) all run and locate ρ_c=0.258, exit 0. The
   contract makes no promise about slash-style relative resolution on Windows, so this is a usage
   nuance, not a violation. (Cosmetic hardening option: `os.path.abspath()` the `--tool` path before
   subprocess — would make all four forms interchangeable.)
2. **Gate is not gameable by grid coarseness.** A deliberately coarse 5-point grid on a width-0.1
   peak legitimately misses the peak (parabolic refine → 0.33, error 0.040 > tol 0.02) →
   G-OFF-TARGET fires, exit 1. The tool does not fudge on-target — honest behavior.

---

## Failures

**None.** No contract clause was violated.

---

*Independent cold-context two-pass verification against contract v1.0.0. Verdict: **CONFORMANT**.*
