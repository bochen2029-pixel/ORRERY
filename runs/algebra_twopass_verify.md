# algebra — Independent Cold-Context Two-Pass Verification

**Tool:** `algebra` (cuSOLVER free-boson block entanglement-entropy c-scaling)
**Contract:** v1.0.0 (`contracts/algebra.contract.md` + `algebra.schema.json`)
**Pass type:** INDEPENDENT COLD-CONTEXT verifier — black-box, contract-only. No knowledge of build internals; `algebra.cu` NOT read as truth. This is the two-pass-CRITICAL, physics-contested verification (RAYFORMER ADR-007 discipline: skeptical about scope + overclaim).
**Date:** 2026-07-05
**Binary:** `C:\ORRERY\tools\algebra\algebra.exe` (304640 bytes, built 2026-07-05 22:54)

---

## Golden hash

| | value |
|---|---|
| Frozen `goldens/algebra/declared.hash` | `1526918f15ec1f26baee73dcfad539e8943b3d57363f7559ce953857e7e9a89e` |
| `algebra.exe --golden` stderr blake2b | `1526918f15ec1f26baee73dcfad539e8943b3d57363f7559ce953857e7e9a89e` |
| **Match** | **YES — identical** |

---

## Per-check table

| # | Check | Method | Result |
|---|---|---|---|
| S1a | Harness green | `python harness/verify.py --tool algebra` | **PASS** — `build=OK selftest=OK golden=OK`, `OVERALL: GREEN`, exit 0 |
| S1b | Golden hash | `algebra.exe --golden` | **PASS** — stderr `GOLDEN OK blake2b=1526918f…`, exit 0, == frozen hash |
| 2a | Selftest | `algebra.exe --selftest` | **PASS** — exit 0 |
| 2b | Schema (golden) | `jsonschema.validate` (draft-07, additionalProperties:false) | **PASS** — VALID; tool="algebra", version="1.0.0", notes present |
| 2b' | Schema (massive) | same schema | **PASS** — VALID |
| 2c-crit | Physics critical | golden run | **PASS** — c_expected=1.0, c_measured=0.996303, c_error=0.003697<tol(0.15), divergent=true, growth_nats=0.459476>0, G-WRONG-C not fired, verdict pass, exit 0 |
| 2c-mass | Physics massive control | `--regime massive --mass2 0.5 --max-size 512 --seed 0` | **PASS** — c_expected=0.0, c_measured=0.000000 (\|c\|<tol), divergent=false, G-WRONG-C not fired, exit 0 (entropy saturates: correct negative control) |
| 2d | Gate G-WRONG-C = exit 1 | `--regime critical --max-size 128 --num-sizes 3 --fit-points 3 --tol 0.001` | **PASS** — c_measured=0.982808, c_error=0.017192>tol(0.001), G-WRONG-C **fired:true**, verdict **fail**, **exit 1** (distinct from error 2) |
| 2e | **SCOPE discipline** | key-scan of output + notes | **PASS** — see Scope finding below |
| 2f | Exit codes 0/1/2 never conflated | error battery | **PASS** — see below |
| 2g | Determinism | golden ×2 | **PASS** — byte-identical (729 B each), both hash `1526918f…` |
| 2g' | Data-boundness (anti-RAYFORMER) | `--max-size 512` vs golden(1024) | **PASS** — envelope genuinely differs; see below |

---

## Physics numbers

| regime | params | c_expected | c_measured | c_error | divergent | growth_nats | s_at_max_bits |
|---|---|---|---|---|---|---|---|
| critical (golden) | max=1024, n=5, fit=4 | 1.0 | **0.996303** | 0.003697 | true | 0.459476 | 1.515077 |
| critical | max=512 | 1.0 | 0.993359 | 0.006641 | true | 0.457107 | 1.348822 |
| massive (control) | mass2=0.5, max=512 | 0.0 | **0.000000** | 0.000000 | false | 0.000000 | 0.132386 |
| critical (gate-forced) | max=128, n=3, tol=0.001 | 1.0 | 0.982808 | 0.017192 | true | 0.227077 | 1.016959 |

Critical c→1 (0.9924 at L=128 → 0.9934 at L=512 → 0.9963 at L=1024): correct Calabrese–Cardy finite-size convergence toward the analytic central charge c=1. Massive regime saturates (c_eff→0). Ground-truth-checked, not asserted — `c_measured` is compared against analytic `c_expected`.

## Exit-code battery (2f)

| invocation | exit | expect |
|---|---|---|
| `--regime bogus` | 2 | 2 ✓ |
| `--max-size 5` (below 32) | 2 | 2 ✓ |
| unknown flag `--frobnicate` | 2 | 2 ✓ |
| `--num-sizes 2` (below 3) | 2 | 2 ✓ |
| `--max-size 4097` (above 4096) | 2 | 2 ✓ |
| `--num-sizes 13` (above 12) | 2 | 2 ✓ |
| `--tol 1.5` (above 1.0) | 2 | 2 ✓ |
| valid critical (`--max-size 256`) | 0 | 0 ✓ |
| forced c-mismatch (tol 0.001) | 1 | 1 ✓ |

0 (pass), 1 (real negative result / G-WRONG-C), and 2 (param/error) are cleanly separated. A real physics-negative (gate) is exit 1, never conflated with a usage error (exit 2).

## Data-boundness (2g', anti-RAYFORMER)

golden(1024): c_measured=0.996303, growth_nats=0.459476, s_at_max_bits=1.515077
diff(512):    c_measured=0.993359, growth_nats=0.457107, s_at_max_bits=1.348822

Changing `--max-size` produces a different declared envelope that moves in the physically correct direction (larger L → c_measured closer to 1, larger block entropy). The declared result is genuinely computed from the cuSOLVER eigendecomposition, not a stamped constant. Golden is simultaneously byte-reproducible (determinism) and parameter-sensitive (data-bound) — the two properties RAYFORMER lacked.

---

## SCOPE FINDING (the decisive check for this contested tool)

The science **WITHDREW** a "Part-B relative-entropy value" ("16.23 bits") as a fraction-of-box-bump artifact (debt D-CP). The contract v1.0.0 is Part-A only. Verification:

- **No withdrawn value emitted.** Full result-key set is exactly the absolute-entropy c-scaling: `regime, c_expected, c_measured, c_error, slope_nats, growth_nats, divergent, min_size, max_size, s_at_max_bits`. There is **NO** relative-entropy / Part-B / bits-value field. String scan of the serialized envelope: `"16.23"` absent, `"relative"` absent.
- **Firewall carried.** `notes` = *"This measures an entropy-scaling law (structure/physics); it says nothing about whether anything feels (acquaintance) - III-sealed. Finite-dim is Type I: we reproduce the cutoff-running that forces the crossed product, not the trace-free Type III_1 factor."* This carries **both** the qualia/§III firewall **and** the Type-I / III₁ caveat (it does NOT claim to instantiate the trace-free Type III₁ factor).
- **Contract Scope section matches the tool's actual output.** The tool reports the divergence as a *symptom* (`divergent`, `growth_nats`, `c_measured`+`c_error` vs analytic ground truth) and nothing more. No overclaim beyond the stated Part-A scope was observed.

**Scope: CORRECT.** The tool is disciplined to exactly its narrow contract; it does not resurrect the withdrawn number and it flags its own Type-I limitation.

---

## OVERALL VERDICT: **CONFORMANT**

All 13 checks pass. Independent cold-context black-box verification against contract v1.0.0:
- Harness GREEN (build/selftest/golden OK).
- Golden blake2b matches the frozen `declared.hash` exactly.
- Physics correct and ground-truth-checked: critical c=0.996≈1 (divergent), massive c=0 (saturates).
- Gate G-WRONG-C is a genuine exit-1 negative result, distinct from exit-2 errors; exit codes 0/1/2 never conflated.
- Deterministic (byte-identical) AND data-bound (parameter-sensitive) — passes the anti-RAYFORMER test.
- **Scope discipline holds:** no withdrawn Part-B/relative-entropy value anywhere; the qualia firewall and the III₁/Type-I caveat are carried in `notes`; contract Scope matches actual output.

No contract violations and no overclaim beyond the stated scope were found.
