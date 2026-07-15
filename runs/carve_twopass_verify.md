# carve v1.0.0 — cold two-pass verification (CONFORMANT)

**Date:** 2026-07-14. **Method:** the autonomous N-way cold two-pass (D-034 Intercom's second intended
use) — **two independent no-build-context verifiers, each in an isolated git worktree**, cold-rebuilt
carve from source, reproduced the frozen golden, and ran the full anti-RAYFORMER conformance battery.
Neither had any memory of the build. **Both returned CONFORMANT.**

## Result: CONFORMANT (2/2 independent verifiers, 0 blocking defects)

| check | verifier A | verifier B |
|---|---|---|
| cold rebuild from source (nvcc, per MODULE) | clean compile | clean compile, 0 warnings |
| golden `1373454e…` byte-identical | ✅ | ✅ |
| selftest 12/12 | ✅ | ✅ |
| (a) golden == frozen declared.hash | PASS | PASS |
| (b) schema conformance (all fields/types, both gates) | PASS | PASS |
| (c) exit tri-state 0/1/2 never conflated | PASS | PASS |
| (d) determinism (2× byte-identical) | PASS | PASS |
| (e) I-11 oracle: planted `oracle_dev` < 1e-9 | PASS (0.0 exact) | PASS (0.0 exact) |
| (f) anti-blindness: ising 0.741 ≫ haar 0.023 | PASS (Δ 0.718) | PASS (≈32×; numpy: TF-Ising exactly 2-local = 1.0) |
| (g) hash computed-not-stamped (tamper + closed-form 66/255) | PASS | PASS (recomputed 66/255 independently) |
| (h) firewall verbatim §III-sealed | PASS | PASS |
| (i) no fast-math (D-021/I-13) | PASS | PASS |

**The crucial checks held.** The exit-code tri-state is operative and the two failure modes are genuinely
distinct: `haar` → exit 1 with `G-NO-BASIN` fired (best_gap 0.023 ≤ tol) = "no preferred factorization";
`planted --scrambler-depth 3` → exit 2 with `recovered=0` and `G-NO-BASIN` NOT fired (best_gap 0.598 ≫ tol)
= "search too weak." Verifier B independently reproduced the anti-blindness result in numpy (TF-Ising's
≤2-body Frobenius fraction = 1.0000000000). The score `best_gap = 0.741176` was confirmed derived from the
closed-form `1 − 66/255`, not hard-coded (anti-RAYFORMER).

## Non-blocking observation (both verifiers, independently)
`oracle_tol` (default `1e-9`) serializes into the D-013 hash domain via `fmt6` (`%.6f`) as
`"oracle_tol":0.000000` — so tolerance values in `[0, 5e-7)` are indistinguishable in the declared hash.
Assessed **LOW / non-blocking** by both: it does not invalidate the golden (frozen at the default),
determinism holds (same params → same hash), and it is an inherent property of the instrument's `%.6f`
canonical serialization (D-013), not a carve-specific defect — it affects any sub-1e-6 param on any tool.
Disclosed in `tools/carve/MODULE.md` known-issues for honesty. Not a contract violation.

## Verdict
**carve v1.0.0 is CONFORMANT to its contract** and cleared for the science to cite its declared behavior
(including its honest self-report of search-too-weak via exit 2). The **deciding converge run** (quantifying
the greedy search's recovery boundary) is a v1.1-facing characterization — NOT blocking, precisely because
v1 honestly reports its own search limits rather than faking recovery.

*Two independent cold rebuilds, one golden, zero defects. The functional is not blind; the oracle is exact;
the search reports its own limits. Structure, never acquaintance.*
