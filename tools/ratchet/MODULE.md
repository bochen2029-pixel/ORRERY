# MODULE — `ratchet`

*The second ORRERY tool — copies `someone`'s shape (envelope, determinism, golden, two-pass). Read `contracts/ratchet.contract.md` (v1.0.0) first — the contract is authoritative.*

**Status: CONTRACT-FIRST (spec written; implementation is the next build step — S-ratchet-2+).**

## Purpose
GPU Monte-Carlo of the recoverability-frontier **branching ratchet**, verifying the redundancy critical threshold **(1−p)ρ = p** (science F13, throat T-RATE) at billions of trajectories. A record in R independent fragments is rewritten; each fragment per step dies w.p. p (Crooks price) or re-broadcasts w.p. ρ. This is a Galton-Watson process with per-lineage extinction `q* = min(1, p/((1−p)ρ))` and P[record ever unwritten] = `q*^R`; supercritical iff (1−p)ρ > p. The tool measures P[unwrite] and checks it against this analytic law (which *contains* the threshold).

## SCOPE GUARD (sacred — the §III firewall)
**This measures a branching-process threshold (structure); it says nothing about whether anything feels (acquaintance) — §III-sealed.** Emitted verbatim in the JSON `notes` and every write-up.

## Contract
`contracts/ratchet.contract.md` v1.0.0 (+ `contracts/ratchet.schema.json`). Code is ephemeral; the contract + golden are load-bearing.

## Provenance
Physics from `C:\Fable_LLC\QUALIA_LAB\gym\receipts\toy_rr_frontier_ratchet.py` (the branching-ratchet model + the analytic `q*` / (1−p)ρ=p threshold, CPU MC of 60k trajectories, PASSES). GPU Monte-Carlo scaffolding pattern from `C:\Users\user\Desktop\DSA\criticality_cuda.cu`. `ratchet` is the industrial, billions-of-trials, golden-gated graduation of the toy.

## Internal design (planned)
- **One thread per trajectory** (embarrassingly parallel; the natural GPU shape, unlike `someone`'s one-block-per-agent). A trajectory holds a fragment count `n` (start R); per step, sample each of `n` fragments' offspring (0/1/2 by the law) and sum — but sampling `n` Bernoullis per step is O(n); since only the COUNT matters, draw the two survival/rebroadcast counts as **binomials** (Binomial(n, 1−p) survivors, then Binomial(survivors, ρ) rebroadcasters ⇒ next n = survivors + rebroadcasters), so each step is O(1) RNG regardless of n. Loop until n=0 (extinct: tally + record survival step) or n≥cap (escape: tally) or step=tmax (persist).
- **RNG:** counter-based (reuse `someone`'s splitmix64/`counter_uniform`), keyed by (seed, trajectory_id, step). Binomial sampling via inversion or BTPE from counter-uniforms — deterministic. No per-thread RNG state, no wall-clock.
- **Reductions:** the extinction tally and the survival-time histogram are **integer** `atomicAdd`s (associative ⇒ deterministic — this is why ratchet's determinism is trivial where `someone`'s needed care). `p_unwrite_mc` = extinct_count / trials (int/int). Escapes counted as integers. **No float atomics.**
- **Analytic:** `q_star`, `p_unwrite_analytic`, `rho_c`, `regime` computed exactly on the host from (p, ρ, R).

## Determinism approach
Trivial vs `someone`: every random value is a pure function of (seed, trajectory, step) (counter RNG), and every reduction is an integer count (order-independent). No float atomics, no wall-clock, pinned launch config ⇒ byte-identical declared output. `--golden` ≥3× byte-identical is the gate (copy `someone`'s verification discipline).

## Selftest (planned)
- blake2b KATs (reuse `someone`'s validated hasher).
- **Analytic identities:** `q_star(0.2,0.5)=0.5`; `rho_c(0.2)=0.25`; regime boundary at (1−p)ρ=p.
- **MC-vs-analytic** at a few (p,ρ,R) with modest trials (both a supercritical point and a subcritical point), rel_error < a loose selftest tol — the branching law reproduces.
- **Threshold sanity:** at fixed p, a ρ below ρ_c gives p_unwrite≈1 (subcritical); above gives <1 (supercritical). Fast/small.
- Determinism: same (params,seed) → identical declared object twice.

## Golden
`ratchet.exe --p 0.2 --rho 0.5 --R 3 --trials 4000000 --tmax 500 --cap 4096 --seed 20260705 --json` → analytic P[unwrite]=0.125; MC matches within tol. Fast (<1 min — no `someone`-style bandwidth wall; the state is a single integer per trajectory). Frozen in `goldens/ratchet/`.

## Build (planned)
Single-file CUDA, from `tools/ratchet/` (see `BUILD.md`):
`cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 ratchet.cu -o ratchet.exe'`

## Known issues / caveats
- The model assumes **independent fragments** (per the toy's carried caveat); confounded redundancy would degrade the effective exponent — a v-next modeling extension, not a v1.0.0 concern.
- Classical Markov branching model (not a quantum decoherence/recoherence instantiation); the science reads it as the *threshold structure*, not a full QD dynamics.
- Binomial sampling must be exact/deterministic across the parameter range (validate the sampler in selftest against small-n direct Bernoulli sums).

*Sims prove structure, never acquaintance. Build one tool right; freeze its golden; let the science call it.*
