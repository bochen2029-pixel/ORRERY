# posit — Independent Cold-Context Two-Pass Verification

**Tool:** `posit` (Python — the parsimony auditor)
**Contract verified against:** `contracts/posit.contract.md` **v1.0.0** + `contracts/posit.schema.json`
**Frozen golden hash:** `goldens/posit/declared.hash` = `7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44`
**Verifier stance:** Independent cold-context pass. Tool treated as a BLACK BOX. Behavior checked against the published contract only — no build-side knowledge, no science write-ups, no MODULE/RUN_STATE/DECISIONS trusted as truth.
**Date:** 2026-07-05

---

## Overall: **CONFORMANT**

- Harness: `OVERALL: GREEN`, exit 0; posit row `build=OK selftest=OK golden=OK`.
- Golden hash observed = `7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44` — **matches frozen exactly**.
- delta_physics observed (golden) = **+0.8** (patchwork 4.0 − unified 3.2), same_reach=true, no floating, parsimony="win", exit 0.
- No contract violations found across schema, accounting, confabulation guards, exit-code discipline, and determinism.

---

## Per-check results

| # | Check | PASS/FAIL | Evidence |
|---|---|---|---|
| 1a | Harness `verify.py --tool posit` GREEN, exit 0 | PASS | stdout `OVERALL: GREEN`, EXIT=0; report `runs/verify_20260705_204543.md` posit row `OK/OK/OK` |
| 1b | `--golden` stderr `GOLDEN OK`, hash == frozen, exit 0 | PASS | `GOLDEN OK blake2b=7a22dd22…a20e44`, EXIT=0; equals `declared.hash` |
| 2a | `--selftest` exit 0 | PASS | `SELFTEST PASS` (12/12 [PASS]), EXIT=0 |
| 2b | Schema validate `--golden --json`; tool/version/notes | PASS | jsonschema 4.26.0 `SCHEMA_VALID: True`; tool='posit', version='1.0.0'; notes carries firewall ("makes no claim either account is true, and nothing about qualia — the overlay layer is III-sealed") |
| 2c | Golden envelope accounting law | PASS | patchwork.physics=4.0, unified.physics=3.2, delta_physics=+0.8, same_reach=true, unified.floating=[], parsimony="win", verdict="pass", exit 0 |
| 2c* | Hand-check weights reproduce 4.0 / 3.2 from contract | PASS | See "Accounting hand-check" below |
| 2d-i | Derived `via` → non-existent id ⇒ floating, G-FLOATING, exit 1 | PASS | unified.floating=["d2"], G-FLOATING fired=true, parsimony="reject", EXIT=1 (blocks a win that delta=1.0 would otherwise license) |
| 2d-ii | Equal physics budgets at equal reach ⇒ reject, G-NO-PARSIMONY, exit 1 | PASS | delta_physics=0.0, same_reach=true, G-NO-PARSIMONY fired=true, parsimony="reject", EXIT=1 |
| 2d-iii | Cheaper but covers fewer targets ⇒ same_reach=false, not a win, exit 1 | PASS | unified covered=1, missing=["t2"], same_reach=false, parsimony="reject", EXIT=1 |
| 2d-iv | Relabel posit→bridge does NOT lower budget (bridge==posit) | PASS | un.physics=1.0 in both cases (posit: posits=1/bridges=0; bridge: posits=0/bridges=1) |
| 2e-1 | Malformed JSON → exit 2 | PASS | `error: Expecting property name…`, EXIT=2, no envelope |
| 2e-2 | Unknown `kind` → exit 2 | PASS | `error: unified.items[0].kind 'assumption' not in [...]`, EXIT=2 |
| 2e-3 | Missing `--case`/`--stdin` → exit 2 | PASS | `error: one of --case PATH or --stdin is required`, EXIT=2 |
| 2e-4 | Valid win → exit 0 | PASS | clean-win case EXIT=0 |
| 2e-5 | Gate case → exit 1 | PASS | all three 2d gate cases EXIT=1 |
| 2f | Determinism: same case twice → byte-identical stdout | PASS | 1032 bytes each, SHA-256 identical (`b4a1098971…`) |
| + | `--seed` inert to result, echoed in envelope (contract §Language) | PASS | seed 0 vs 999 → result-invariant envelopes; seed field echoes 999 |

Exit-code separation (0 pass / 1 gate / 2 error) is honored throughout — exit 1 (real negative result) and exit 2 (bad input) are never conflated.

---

## Accounting hand-check (from contract weight table only)

Contract weights: `posit=1.0, bridge=1.0, import=0.2, derived=0.0`; layers `physics` | `overlay` (overlay never counted as a win).

Golden envelope counts:
- **Patchwork**: posits=4, bridges=0, imports=0, derived=0, overlay=0.0
  → physics = 4×1.0 = **4.0** ✓ (matches reported patchwork.physics=4.0)
- **Unified**: posits=2, bridges=2, imports=1, derived=2; overlay=1.0 (⇒ one bridge sits in the overlay layer)
  → physics-layer = 2×1.0 (posits) + 0.2 (import) + 1×1.0 (the physics-layer bridge) + 2×0.0 (derived) = **3.2** ✓
  → overlay-layer = 1×1.0 (the overlay bridge) = **1.0** ✓ (buys no parsimony, by design)
- delta_physics = 4.0 − 3.2 = **+0.8** ✓ ; delta_overlay = 1.0 ; delta_total = 4.0 − 4.2 = **−0.2** ✓

The reported budgets reproduce exactly from the contract's stated law by hand. The overlay bridge correctly adds to total (making unified nominally more expensive: −0.2) yet the citable **physics** delta is a genuine +0.8 reduction at equal reach with no floating — a real parsimony win, not relabeling.

---

## Notes / observations

- The G-FLOATING guard correctly dominates: in case 2d-i the physics delta (+1.0) would license a win, but the floating derivation forces `parsimony="reject"` and exit 1. Confabulation ("deriving from nothing") is caught even when the budget looks favorable — the core RAYFORMER/ADR-007-style honesty discipline holds.
- Errors are emitted as `error: …` on stderr with a clean stdout (no partial JSON envelope) — safe for machine consumers keying on exit code.
- `notes` field is present and identical across all runs, sealing the qualia/overlay firewall in every envelope.

**Verdict: CONFORMANT to `posit.contract.md` v1.0.0.** No failures.
