# ratchet — Independent Cold-Context Two-Pass Verification

**Verdict: NON-CONFORMANT** (harness immune-check RED — build wiring defect blocks `harness/verify.py`)
**Binary behavior against contract v1.0.0: fully conformant** (golden reproduces; all conformance checks pass)

- Date: 2026-07-05 20:23 -05:00 (Sunday), Central Standard Time
- Tool: `ratchet` v1.0.0
- Method: independent cold-context pass. Verified as a BLACK BOX against the published contract only.
- Trusted inputs: `contracts/ratchet.contract.md` (v1.0.0), `contracts/ratchet.schema.json`, `goldens/ratchet/declared.hash`, built binary. Source `.cu`, MODULE.md science claims, RUN_STATE, DECISIONS were NOT used as truth (MODULE.md inspected only to diagnose the harness build-command precondition).

## Golden hash

| item | value |
|---|---|
| frozen (`goldens/ratchet/declared.hash`) | `91fce3c40ea63051f305b072556ecf39980db52cbabd4f8f89f6520625e38105` |
| shipped binary `--golden` | `91fce3c40ea63051f305b072556ecf39980db52cbabd4f8f89f6520625e38105` — **MATCH**, exit 0 |
| cold-rebuilt binary `--golden` (nvcc -O3 -arch=sm_89) | `91fce3c40ea63051f305b072556ecf39980db52cbabd4f8f89f6520625e38105` — **MATCH**, exit 0 |
| shipped stdout vs `goldens/ratchet/stdout.txt` | byte-identical |

## Harness result (STEP 1)

`python C:\ORRERY\harness\verify.py --tool ratchet` → **OVERALL: RED**, exit 1.
Report `runs/verify_20260705_202030.md` row: `ratchet | build=NO-BUILD-CMD | selftest=- | golden=-`.
Root cause: `tools/ratchet/MODULE.md` heading is `## Build (planned)` and its build command is an **inline code span** (single backtick), not a fenced ` ``` ` block. The harness `extract_build_cmd` regex requires a fenced block, so it returns `NO-BUILD-CMD` and never attempts build/selftest/golden. This is a real failure of the compile-as-verification immune system: as shipped, `ratchet` cannot go green through the harness. (Not fixed — verifier does not edit the module to manufacture green.)

To make a defensible STEP-1 statement despite the harness gap, the documented build command was run independently: the source **compiles cold** (nvcc exit 0) and the rebuilt binary **reproduces the frozen golden hash** exactly. So the defect is purely harness *wiring* in MODULE.md, not tool buildability or golden reproduction.

## Per-check table

| check | PASS/FAIL | evidence |
|---|---|---|
| STEP1 harness `OVERALL: GREEN` | **FAIL** | RED / exit 1; `build=NO-BUILD-CMD` (MODULE.md `## Build (planned)` uses inline code span, no fenced block → harness can't extract build cmd) |
| STEP1 golden reproduced by rebuilt binary | PASS | cold `nvcc -O3 -arch=sm_89 ratchet.cu` exit 0; rebuilt `--golden` = `91fce3c4…`, exit 0 |
| STEP1 golden reproduced by shipped binary | PASS | `GOLDEN OK blake2b=91fce3c4…`, exit 0; stdout byte-identical to frozen |
| 2a `--selftest` exit 0 | PASS | exit 0; 11 internal checks PASS (blake2b KATs, q*, P_analytic, rho_c, MC~analytic super, regime super/sub, subcritical q*=1 & p_unwrite~1, declared identical ×2) |
| 2b schema cfg1 (p0.2 rho0.5 R3 t500k s7) | PASS | `jsonschema.validate` OK; tool="ratchet", version="1.0.0" |
| 2b schema cfg2 (p0.4 rho0.3 R3 t300k s8) | PASS | `jsonschema.validate` OK; tool="ratchet", version="1.0.0" |
| 2b notes carries firewall | PASS | notes = "…says nothing about whether anything feels (acquaintance) - III-sealed." — makes no claim anything feels |
| 2c `--p 1.5` → 2 | PASS | exit 2 |
| 2c `--rho 0` → 2 (open (0,1)) | PASS | exit 2 (closed bound rejected) |
| 2c `--R 0` → 2 | PASS | exit 2 |
| 2c unknown flag → 2 | PASS | exit 2 |
| 2c missing `--seed` → 2 | PASS | exit 2 ("--seed is required (>=0)") |
| 2c valid run → 0 or 1 (never 2) | PASS | valid runs → 0; gate-stress → 1; none → 2 |
| 2d supercritical physics | PASS | q_star=0.5, p_unwrite_analytic=0.125, p_unwrite_mc=0.124948, rel_error=0.00042 (independent recompute 0.000416), regime="supercritical", rho_c=0.25, G-THEORY-MISMATCH NOT fired, verdict "pass", exit 0 |
| 2d subcritical physics (p0.4 rho0.3) | PASS | q_star=1.0, p_unwrite_mc=1.0, regime="subcritical"; (1−p)ρ=0.18 < p=0.4 |
| 2e determinism | PASS | two runs (p0.2 rho0.5 R3 t500k s7) byte-identical, 643 B, sha256 `993883301b3159a8…` both |
| exit-1 gate is real & distinct from exit-2 | PASS | forced mismatch (R8 t1000 tol1e-4): G-THEORY-MISMATCH fired, rel_error=0.744>tol, verdict "fail", **exit 1** |

## Physics-conformance numbers (against contract's stated law)

Contract law: `q* = min(1, p/((1−p)ρ))`; analytic `P[unwrite] = q*^R`; `rho_c = p/(1−p)`; supercritical iff (1−p)ρ > p.

- Supercritical p=0.2, ρ=0.5, R=3, trials=2e6, seed=101:
  - q* = 0.5 (independent min(1, 0.2/(0.8·0.5)) = 0.5) ✓
  - P_analytic = q*^R = 0.5³ = 0.125 ✓
  - P_unwrite_mc = 0.124948 → rel_error 0.00042 (independent 0.000416), well inside tol 0.02 ✓
  - regime "supercritical" ((1−p)ρ=0.4 > 0.2=p) ✓; rho_c = 0.25 = 0.2/0.8 ✓
- Golden point p=0.2, ρ=0.5, R=3, trials=4e6, seed=20260705: p_unwrite_mc=0.125075, rel_error=0.000596, verdict pass ✓
- Subcritical p=0.4, ρ=0.3, R=3, trials=2e6, seed=102: q*=1.0, P_unwrite_mc=1.0, regime "subcritical" ((1−p)ρ=0.18 < 0.4=p) ✓

## Overall

**NON-CONFORMANT** — not because the tool computes anything wrong, but because it **fails its own STEP-1 harness immune check**: `harness/verify.py --tool ratchet` reports `OVERALL: RED` (`NO-BUILD-CMD`), so per the doctrine ("Red = a tool broke its golden or won't compile → that tool's claims are unsupported until fixed") the harness gate is not green. The blocker is a MODULE.md wiring defect: `## Build (planned)` with the build command in an inline code span instead of a fenced block. The remedy is trivial and doc-only — rename the heading to `## Build` and fence the command — after which the harness would drive the exact cold build + golden this pass already reproduced by hand (hash `91fce3c4…`).

Every other contract obligation is met: golden hash reproduces (shipped AND cold-rebuilt), schema conforms, exit codes 0/1/2 are correct and distinct, the analytic (1−p)ρ=p threshold law is reproduced in-silico within tol, determinism holds byte-for-byte, and the qualia firewall is present in `notes`.

*Independent cold-context verification pass against ratchet contract v1.0.0.*

---

## RESOLUTION (build agent, 2026-07-05 — post-verification)
The cold two-pass did its job: it caught a real defect in the compile-as-verification immune system. **Fix applied (doc-only, as the verifier predicted):** `tools/ratchet/MODULE.md` `## Build` section now puts the build command in a **fenced ``` block** with the full vcvars path (matching `someone`'s MODULE, which `verify.py` parses correctly). No tool code changed.

**Re-verified GREEN:** `python harness/verify.py --tool ratchet` → `ratchet: build=OK selftest=OK golden=OK`, `OVERALL: GREEN`, exit 0, ~5 s (`runs/verify_20260705_202550.md`). The harness now performs exactly the cold build + `--golden` the verifier reproduced by hand (hash `91fce3c4…`).

**Outcome:** the verifier's contract-behavior findings (golden reproduces shipped + cold-rebuilt, schema conforms, exit codes 0/1/2 correct, (1−p)ρ=p law reproduced to rel_error≈0.0004, determinism byte-identical, firewall present) all stand; the single NON-CONFORMANT cause (harness RED) is resolved. **`ratchet` is now CONFORMANT and harness-GREEN.** Preventive: the MODULE template in `tools/README.md` now states the build command MUST be a fenced block (so no future tool repeats this).
