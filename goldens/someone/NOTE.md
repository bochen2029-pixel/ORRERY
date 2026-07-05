# golden — `someone` v1.1.0

## What is frozen
The declared output of the contract's golden invocation:
```
someone.exe --pop 200 --gens 200 --steps 800 --N 256 --k 64 --zombie-frac 0.5 --complexity L3 --ensemble 4 --seed 20260705 --json
```

Files in this directory:
- **`declared.hash`** — the `blake2b-256` hex digest of the *canonical declared object* (below). `someone --golden` recomputes this and exits 0 iff it matches.
- **`stdout.txt`** — the full JSON envelope printed by that run (human-readable; includes `tool`/`version`/`notes`, which are NOT in the hash domain).

## Hash domain (exactly what is hashed) — D-013
`blake2b-256` over the canonical serialization of **`{seed, params, result, gates, verdict}`** only — with floats formatted `%.6f` and object keys in the fixed declared order. **Excluded** from the hash: `tool`, `version`, `notes`, and all timing/progress (non-declared). This makes the golden a hash of *behavior*, not of labels: a future kernel rewrite that reproduces the results (and may bump `version`) still reproduces this golden. See `contracts/someone.contract.md` §Determinism.

## What it proves
1. **Determinism** — same (params, seed) ⇒ byte-identical declared output. Verified byte-identical across ≥3 independent `--golden` runs on this machine (sm_89) before freezing.
2. **A stable behavioral anchor** — any reimplementation of `someone` must reproduce this hash (or supersede it under two-pass review). The science depends on the contract + this golden, never on the CUDA.

## Why these params
A *fast-ish* representative slice of the real experiment: L3 (full complexity, where round-01 found the decisive normal-win), a small ensemble (n=4) for CI-affordability, seed = the founding date `20260705`. It is NOT the citable science run — that is `runs/someone_round01_reproduce.md` (n≥20). Golden runtime is bandwidth-bound (~8 min); see DECISIONS D-014. Regenerating the golden after an intended, reviewed change: run the invocation above, confirm ≥3× byte-identical, overwrite `declared.hash` + `stdout.txt`, and note the supersession (never silently).

## Environment of the freeze
Recorded in `runs/someone_golden.result.lock` (tool semver, binary blake2b, GPU arch sm_89 + device, CUDA 13.1, host compiler, the exact CLI, the declared hash, git commit).
