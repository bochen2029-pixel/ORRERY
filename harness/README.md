# harness/ — compile-as-verification

The instrument's immune system. Generalizes ASTRA-7's test-suite-as-proof to the whole catalogue: **compile every tool → run every `--selftest` → run every `--golden` → red/green.** A claim that cannot compile or fails its golden is not in the instrument.

## What to build here (for the fresh session, after `someone` exists)
`harness/verify.py` (Python is right here — it's orchestration glue):
1. Discover tools from `tools/*/MODULE.md` (each declares its build command + language).
2. For each: build (via the MODULE build command), run `--selftest` (expect 0), run `--golden` (expect 0).
3. Write a dated report to `../runs/verify_<stamp>.md`: per-tool BUILD/SELFTEST/GOLDEN status.
4. Exit 0 iff all green.

Keep it dependency-light (stdlib + subprocess). Force UTF-8 stdout. Timeouts per tool (selftest < 30s, golden < 5 min).

## Physics throats as gates (later)
Where a theory falsifier can be expressed as a tool gate (a `--golden`-style expected relation), it becomes a CI gate here — e.g. `ratchet` must reproduce the (1−p)ρ=p critical point; `someone` must show mean_pure_gap>0 for normal agents (the G-NO-GAP gate). A red throat-gate is a real signal about the theory, surfaced mechanically.

## Two-pass verification (for citable tools)
Beyond selftest/golden: a fresh cold-context agent, given only the contract + the built binary (NOT the build conversation), re-runs the golden and independently checks contract-conformance. This catches the confident-wrong-but-golden-passing failure (a golden frozen against a subtly wrong impl). RAYFORMER's ADR-007 is why this exists. Record two-pass results in `../runs/`.

## The discipline
`verify.py` green is the precondition for the science trusting any tool. Run it after every tool change and before any release. Slow tools starve the loop — keep selftests fast.
