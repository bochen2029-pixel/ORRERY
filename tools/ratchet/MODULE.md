# MODULE — `ratchet`

*The second ORRERY tool — copies `someone`'s shape (envelope, determinism, golden, two-pass). Read `contracts/ratchet.contract.md` (v1.0.0) first — the contract is authoritative.*

**Status: DONE v1.0.0** — built, golden frozen (`91fce3c4`, 3× byte-identical), selftest green, cold two-pass in progress. MC↔analytic rel_error 0.06% at the golden.

## Purpose
GPU Monte-Carlo of the recoverability-frontier **branching ratchet**, verifying the redundancy critical threshold **(1−p)ρ = p** (science F13, throat T-RATE) at billions of trajectories. A record in R independent fragments is rewritten; each fragment per step dies w.p. p (Crooks price) or re-broadcasts w.p. ρ. This is a Galton-Watson process with per-lineage extinction `q* = min(1, p/((1−p)ρ))` and P[record ever unwritten] = `q*^R`; supercritical iff (1−p)ρ > p. The tool measures P[unwrite] and checks it against this analytic law (which *contains* the threshold).

## SCOPE GUARD (sacred — the §III firewall)
**This measures a branching-process threshold (structure); it says nothing about whether anything feels (acquaintance) — §III-sealed.** Emitted verbatim in the JSON `notes` and every write-up.

## Contract
`contracts/ratchet.contract.md` v1.0.0 (+ `contracts/ratchet.schema.json`). Code is ephemeral; the contract + golden are load-bearing.

## Provenance
Physics from `C:\Fable_LLC\QUALIA_LAB\gym\receipts\toy_rr_frontier_ratchet.py` (the branching-ratchet model + the analytic `q*` / (1−p)ρ=p threshold, CPU MC of 60k trajectories, PASSES). GPU Monte-Carlo scaffolding pattern from `C:\Users\user\Desktop\DSA\criticality_cuda.cu`. `ratchet` is the industrial, billions-of-trials, golden-gated graduation of the toy.

## Internal design (as built)
- **One thread per trajectory**, grid-stride over `--trials` (fixed 4096×256 launch; embarrassingly parallel — the natural GPU shape, unlike `someone`'s one-block-per-agent). A trajectory holds a fragment count `n` (start R). Per step, loop the `n` fragments; each draws one uniform `u = u01(hash4(seed,traj,step,frag))` and the offspring law maps it: `u<p` → 0 (unwrite), `u<p+(1−p)(1−ρ)` → 1, else → 2. Sum to `next`; **early-escape** breaks the fragment loop the instant `next ≥ cap` (the trajectory escapes regardless of remaining fragments — deterministic, and it bounds the per-step work to ≤cap). Loop until `n=0` (extinct: record survival step) / `n≥cap` (escape) / `step=tmax` (persist).
- **Sampling:** exact per-fragment Bernoulli (not an approximation), so a MC↔analytic mismatch means a *real* deviation, not sampler error. With `cap=256` the per-trajectory work is ~1.5k draws; the golden's 4M trajectories run in ~0.5 s. *(Scale note: for billions of trials, O(1) binomial sampling — `Binomial(n,1−p)` survivors then `Binomial(survivors,ρ)` rebroadcasters — would replace the O(n) fragment loop; that changes RNG consumption ⇒ a golden-superseding optimization, deferred. D-015.)*
- **RNG:** counter-based (reuses `someone`'s splitmix64/`hash4`/`u01`), keyed by (seed, trajectory, step, fragment). No per-thread RNG state, no wall-clock.
- **Reductions:** the extinction/escape tallies, survival-step sum, and survival-time histogram are all **integer** `atomicAdd`s (associative ⇒ order-independent ⇒ deterministic — this is why ratchet's determinism is *structurally trivial* where `someone`'s needed care). `p_unwrite_mc` = extinct/trials (int/int). **No float atomics anywhere.**
- **Analytic:** `q_star`, `p_unwrite_analytic`, `rho_c`, `regime` computed exactly on the host from (p, ρ, R); the gate compares MC vs analytic.

## Determinism approach
Trivial vs `someone`: every random value is a pure function of (seed, trajectory, step) (counter RNG), and every reduction is an integer count (order-independent). No float atomics, no wall-clock, pinned launch config ⇒ byte-identical declared output. `--golden` ≥3× byte-identical is the gate (copy `someone`'s verification discipline).

## Selftest (as built — green)
- blake2b KATs (reuse `someone`'s validated hasher).
- **Analytic identities:** `q_star(0.2,0.5)=0.5`; `P_analytic(R=3)=0.125`; `rho_c(0.2)=0.25`.
- **MC-vs-analytic** supercritical (p=0.2,ρ=0.5,R=3): rel_error < 0.05, regime=supercritical.
- **Subcritical** (p=0.4,ρ=0.3): q*=1, p_unwrite_mc>0.99, regime=subcritical.
- Determinism: same (params,seed) → identical declared object twice.

## Golden
`ratchet.exe --p 0.2 --rho 0.5 --R 3 --trials 4000000 --tmax 500 --cap 256 --seed 20260705 --json` → analytic P[unwrite]=0.125; MC = 0.125075 (rel_error 0.06%). Fast (~0.5 s — no `someone`-style bandwidth wall; trajectory state is a single integer). Frozen `91fce3c4` in `goldens/ratchet/` (`declared.hash` + `stdout.txt` + `NOTE.md`); `result.lock` in `runs/ratchet_golden.result.lock`.

## Build
Single-file CUDA, from `tools/ratchet/` (see `BUILD.md`):
`cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 ratchet.cu -o ratchet.exe'`

## Known issues / caveats
- The model assumes **independent fragments** (per the toy's carried caveat); confounded redundancy would degrade the effective exponent — a v-next modeling extension, not a v1.0.0 concern.
- Classical Markov branching model (not a quantum decoherence/recoherence instantiation); the science reads it as the *threshold structure*, not a full QD dynamics.
- Sampling is exact per-fragment Bernoulli (O(n)/step with early-escape at cap); fine to ~1e8 trials. Billions-scale wants O(1) binomial sampling — a golden-superseding optimization (D-015), deferred.

*Sims prove structure, never acquaintance. Build one tool right; freeze its golden; let the science call it.*
