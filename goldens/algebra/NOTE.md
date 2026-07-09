# golden — `algebra` v1.0.0

## What is frozen
The declared output of the contract's golden invocation:
```
algebra.exe --regime critical --max-size 1024 --num-sizes 5 --fit-points 4 --seed 0 --json
```
A critical (massless) free-boson open chain; block = left half; sweep L=[64,128,256,512,1024]. The vacuum block entanglement entropy DIVERGES as ln L, and the fitted slope gives **c_measured = 0.996303** (slope 0.166051 nats over the largest 4 sizes) against the analytic **c = 1** (Calabrese–Cardy). `divergent=true`, `s_at_max_bits=1.515077`, `c_error=0.003697` < tol=0.15 ⇒ G-WRONG-C clear, verdict pass, exit 0.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Ground-truth validation (why this golden is trustworthy)
The tool is validated against the science's own receipt `toy_cp_divergence.py` (Part A): the selftest asserts S(64)=0.85219 bits and S(128)=1.01696 bits (the receipt's exact numbers), and this golden's slope 0.16605 / s_at_max 1.51508 match the receipt's 0.16610 / 1.51508. So the golden freezes a value **checked against analytic ground truth**, not asserted.

## Hash domain (D-013)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — floats `%.6f`, fixed key order; `tool`/`version`/`notes` excluded. `algebra --golden` recomputes and compares.

## What it proves (and its honest limits)
1. **Determinism** — same params ⇒ byte-identical declared output (≥3× byte-identical on sm_89; cuSOLVER is deterministic here). Eigenvalues sorted before the entropy sum.
2. **The receipted c=1 divergence** — the Type-III symptom (UV-divergent absolute block entropy scaling as (c/6)ln L, c=1) reproduced and checked vs Calabrese–Cardy; the massive chain (a separate invocation) gives c≈0 (area-law control).
3. **NOT** the withdrawn Part-B value (§scope). This is the divergence leg only.

## Environment
`runs/algebra_golden.result.lock`. cuSOLVER (double); cross-version last-ULP drift possible (see MODULE.md) — `%.6f` tolerance is above it.

## Migration record
- 2026-07-09 · tool v1.0.1 (liborrery migration, D-020): declared hash **unchanged** `1526918f…` (reproduced bit-identical 3×). The envelope's non-hashed `version` field now prints `1.0.1`; `stdout.txt` remains the v1.0.0 freeze-time capture (the gate is `declared.hash`, D-013).
