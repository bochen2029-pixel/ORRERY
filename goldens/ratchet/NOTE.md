# golden — `ratchet` v1.0.0

## What is frozen
The declared output of the contract's golden invocation:
```
ratchet.exe --p 0.2 --rho 0.5 --R 3 --trials 4000000 --tmax 500 --cap 256 --seed 20260705 --json
```
At p=0.2, ρ=0.5: `q* = min(1, p/((1−p)ρ)) = 0.5`, so analytic `P[unwrite] = q*^R = 0.5³ = 0.125`; supercritical since (1−p)ρ = 0.4 > 0.2 = p. 4M trajectories give ~0.1% sampling error, well inside `--tol 0.02`.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as someone)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — floats `%.6f`, fixed key order. `tool`/`version`/`notes` excluded, so a behavior-preserving reimplementation keeps the golden. `ratchet --golden` recomputes and compares.

## What it proves
1. **Determinism** — same (params, seed) ⇒ byte-identical declared output (verified ≥3× byte-identical on sm_89). Determinism here is *structurally trivial*: every draw is `u01(hash4(seed,traj,step,frag))` and every tally is an **integer** atomic (associative) — no float atomics, no wall-clock.
2. **The (1−p)ρ=p threshold in-silico** — the frozen `p_unwrite_mc ≈ 0.125` matches the analytic `q*^R`, i.e. the GPU MC reproduces the Galton-Watson branching law that *contains* the F13 critical threshold. `G-THEORY-MISMATCH` clear.

## Environment
Recorded in `runs/ratchet_golden.result.lock` (tool semver, binary blake2b, sm_89 + device, CUDA 13.1, host compiler, exact CLI, declared hash, git commit).
