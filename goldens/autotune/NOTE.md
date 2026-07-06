# golden — `autotune` v1.0.0

## What is frozen
The declared output of the contract's golden invocation:
```
autotune.exe --objective peak --obj-center 0.37 --obj-width 0.12 --lo 0 --hi 1 --points 41 --locate argmax --target 0.37 --tol 0.02 --seed 0 --json
```
A Gaussian basin peaked at C=0.37; the parabolic-refined argmax recovers **x_located=0.370091** (sub-grid), `located_error=0.000091` < tol=0.02 ⇒ `on_target=true`, G-OFF-TARGET clear, verdict pass, exit 0. Self-contained (a built-in objective — no external tool needed).

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — floats `%.6f`, fixed key order; `tool`/`version`/`notes` excluded. `python autotune.py --golden` recomputes and compares.

## What it proves
1. **Determinism** — same params ⇒ byte-identical declared output (≥3× byte-identical). Total/trivial: no RNG, no wall-clock; fixed grid; exact objective.
2. **The locator works** — the parabolic-refined argmax recovers a known peak center to ~4 decimals. (The `crossing` locator + real-tool mode are exercised outside the golden — e.g. autotune drives `ratchet` to locate its own `(1−p)ρ=p` critical point at 0.2581 vs analytic 0.25.)

## Environment
`runs/autotune_golden.result.lock` (tool semver, source blake2b, python, exact CLI, declared hash). Python is right here (D-019): orchestration glue, no GPU/RNG. The golden is self-contained; real-tool sweeps carry the swept tool's hash in the *experiment's* lock, not here.
