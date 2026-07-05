# MODULE — `someone`

*The first ORRERY tool and the template every later tool copies. Read `contracts/someone.contract.md` (v1.1.0) first — the contract is authoritative; this doc explains the implementation behind it.*

## Purpose
Evolve a population of embodied agents whose recurrent state runs an **encoder → bottleneck → decoder → predictor** self-model, in a configurable world (lights to seek, predators to avoid, food to collect, day/night sensory deprivation), and measure whether **self-modeling ("normal") agents** — a real bottleneck `k ≪ N`, so the self-reconstruction gap `pureGap > 0` — **out-survive "zombie" agents** — bottleneck bypassed, `k = N`, gapless — under stakes (energy depletion, predator death). It tests the **functional** half of the Someone-Criterion's C2 (the gap) and the zombie clause: *does the gap confer fitness?*

## SCOPE GUARD (sacred — the §III firewall)
**This measures whether the gap confers fitness (structure); it says nothing about whether the agent feels (acquaintance) — §III-sealed.** A "normal wins" result supports the *functional* reading of C2 / the zombie clause (the gap is adaptive). It does not show, imply, or hint that the agent has qualia / experience / interiority. That line is sealed from this instrument by construction and forever. The sentence above is emitted verbatim in the JSON `notes` field and repeated in every run write-up. GPU scale does not move this line.

## Contract
`contracts/someone.contract.md` v1.1.0 (+ `contracts/someone.schema.json`). CLI flags, output schema, exit codes, determinism clause, golden params live there. If code and contract ever disagree, the contract wins; changing the contract needs a semver bump + a DECISIONS ADR (MAJOR ⇒ stop + BLOCKER).

## Provenance
Ported from `C:\Users\user\Desktop\DSA\dak_evolution_complex.cu` (≈980 lines, read-only prototype). The prototype's kernels (recurrent `W`, encoder `E`, bottleneck `K`, decoder `D`, predictor `P`, sensory `Ws`, motor `Wm`, delay buffer, `pureGap`, viability, multi-objective fitness, tournament+elite evolution) are the starting material. The port makes it **headless, deterministic, ensembled, complexity-gated, contract-bounded, and golden-frozen** — the graduation from a QUALIA_LAB `gym` sketch to an industrial ORRERY tool. The science that will call it: F6/F8 (established.md), debt **D-DAK-RNG** (debts.md).

## Internal design

### State & networks (per agent)
- Recurrent state `x ∈ ℝ^N`; delay buffer `D_DIM=8` frames of `x`; scalar body state (px, py, angle, speed, energy, predatorDamage, foodCollected).
- Weight matrices (per agent, evolved): `W` (N×N recurrent), `E` (K×N encoder), `D_dec` (N×K decoder, init = Eᵀ), `P` (N×F predictor, F = 2N+K+8), `Ws` (N×8 sensory), `Wm` (2×N motor).
- **Zombie flag**: if set, the bottleneck is bypassed — `s = x[:K]` (identity, no compression) and the decode `Ds = x` — so `pureGap ≡ 0`. Normal: `s = tanh(E·x)`, `Ds = D·s`, and `pureGap = ‖x − Ds‖ / ‖x‖ > 0`.

### Per-step kernel (`simulateStepComplex`) — one CUDA **block per agent**, `BLOCK_SIZE` threads
Stages, each fenced by `__syncthreads()` before its consumers: load state → thread-0 sensory (light/predator/food/energy/night, food collection, energy depletion, death checks) → bottleneck encode `s` → decode `Ds` → build feature vector `[x, xDel, s, sensory]` → recurrent `Wx = W·x` → predict `xPred = P·feat` → homeostasis norm (tree reduction) → sensory drive `Ws·sensory` → state update `xNext = tanh(Wx + 0.08·xDel + 0.12·Ds + correction + sDrive + homeo + noise)` → metrics (prediction error, `gapSum`, next-norm; tree reductions) → thread-0 writes stateNorm/pureGap/viability → write `xNext` back to `x` and the delay buffer → thread-0 motor `Wm·xNext`, integrate position/angle/speed, advance delay pointer. Numeric internals (etas, scales, clamps) match the prototype (charter §2: reasonable internals kept unless the contract says otherwise).

### Fitness (`computeFitnessComplex`) — one thread per agent, no cross-agent reduction
`0.25·survival + 0.25·light + 0.20·food + 0.15·(1−predatorDamage) + 0.15·avgViability` (prototype weights). Dead agents stop accumulating (survival-weighted), so death depresses fitness — the stakes channel.

### Evolution (host) — deterministic
Rank by fitness (ties broken by ascending agent index for portability), elitism (top `max(2, pop/20)`), 3-way tournament selection, per-weight mutation (`--mut-rate`, `--mut-str`). Consumes the host `mt19937_64` in a fixed draw order. The zombie flag is inherited (never mutated) so the two sub-populations stay comparable across generations.

## Determinism approach (BITE #1) — the pattern later tools copy
Same (params, seed) ⇒ **byte-identical declared output** on sm_89. Sources of nondeterminism in the prototype and their fixes:
1. **Wall-clock seeds** (prototype lines 545 `steady_clock`, 590 `time(NULL)`) → **removed**. All randomness is a pure function of `--seed` (replica r uses `seed+r`).
2. **Per-neuron noise race** (prototype loads one agent `curandState` into every thread, each draws independently, all write back to one slot → last-writer race + identical noise) → **removed by dropping device RNG state entirely**. Per-step neuron noise is a **stateless counter-based Gaussian**: `splitmix64(hash(seed+replica, agentId, neuronId, step))` → two uniforms → Box–Muller. No shared state ⇒ no race; each noise value is a pure function of its coordinates (D-012).
3. **Float reductions** → already deterministic in the prototype (fixed-order shared-memory tree reductions within a block; host `getStats` sums in index order). **No float `atomicAdd` anywhere.** Kept as-is; the host ensemble aggregation additionally uses **index-order Kahan summation** for the mean. Integer counts (alive, extinct) are exact.
4. **Launch config pinned**: block size fixed (power of two, ≥ enough for the tree reduction); grid = one block per agent for the step kernel. Not derived from any runtime device query in a way that affects output.
5. **Host RNG**: `std::mt19937_64` seeded `seed+r`, fixed consumption order (same branches ⇒ same draw count ⇒ same stream) for init/evolution/zombie-assignment.

**Verification gate:** `--golden` is run ≥3× and the declared JSON/hash must be byte-identical every time (a rare race can survive 2 runs by luck). Cross-arch: declared bit-stability is asserted only for sm_89; other arches may differ in the last ULP (documented tolerance, not yet measured — this machine is the reference).

## RNG-confound fix (BITE #2 · D-DAK-RNG) — proven, not asserted
The prototype's env RNG is one continuous `mt19937(42)` whose **per-generation draw count differs by complexity level** (more entities/motion ⇒ more draws), so the base food/light layout silently diverges across levels — a `--complexity` comparison secretly compares *different worlds* (receipt `dak_skeptic_rng_confound.py`, CONFOUND CONFIRMED).

**Fix (option b — pre-draw a canonical, level-independent layout; gate only the dynamics):** the environment is generated by a **purpose-keyed splitmix64**, not a shared stream. The base layout (initial light, food, **and predator** positions) is keyed by `(seed+replica, gen)` **only** — *not* by complexity — and **all** entities are drawn at **every** level (predators are drawn even at L0, just left inactive), so the base layout is byte-identical across L0/L1/L2/L3 at a fixed seed. The level-specific dynamics — predator activity (L1+), light motion (L2+), night (L3) — are each keyed in an independent namespace (or, for night, a pure function of `step`), so toggling any feature shifts **no other stream**.

**Proof, not promise:** `--selftest` computes a hash of the gen-0 base layout at a fixed seed for all four levels and **asserts they are identical**. That assertion *is* the receipt that the confound is fixed. The clean **L2↔L3** A/B (byte-identical worlds but for the night toggle) is preserved and used as the deprivation isolator.

### Complexity ladder (D-011 — cumulative)
| level | predators | lights move | night | notes |
|---|---|---|---|---|
| L0 | — | — | — | base survival economy (static lights, food, energy depletion) |
| L1 | ✓ | — | — | + predator threat |
| L2 | ✓ | ✓ | — | + moving lights (tracking/memory: old light info goes stale) |
| L3 | ✓ | ✓ | ✓ | full: + night (sensory deprivation) |
Food/energy is always on (the base stake, so normal-vs-zombie is meaningful at every level). L2↔L3 isolates night.

## Ensemble statistics protocol (BITE #3)
One invocation = one complexity level over `--ensemble` seeded replicas (replica r uses `seed+r`). Per replica, measure each class's final-gen mean fitness; the declared output aggregates over replicas:
- `normal_fit_final`, `zombie_fit_final` = mean over replicas; `normal_fit_sd`, `zombie_fit_sd` = sd over replicas; `delta_fit` = normal − zombie.
- **`win_rate`** = fraction of replicas with per-replica `delta > tie_band`; **`p_value`** = one-sided sign test `P(X ≥ wins)`, `X ~ Binomial(wins+losses, 0.5)` (non-tie replicas only; 1.0 if all tie). Computed with exact integer binomial coefficients in double — deterministic.
- **Licensing:** a level's "normal wins"/"zombie wins" is corpus-grade only when `p_value < 0.05`; otherwise report **TIE**. `--ensemble 1` is a non-citable point estimate. The golden uses n=4 (fast, for CI); the real experiment (S5) uses n≥20.
- `zombie_extinct_gen`: per replica, first gen with 0 zombies alive (else −1); reported = round(mean over replicas that went extinct), or −1 if none did.

**Guards (mandatory):** never report the post-extinction normal/zombie fitness **ratio** (≈1e10 division artifact once a class hits zero) — report `delta_fit` + alive-counts (the contract enforces this: there is no ratio field). `avgGap → 1` is **definitional** for a saturated bottleneck, never cited as evidence.

## Build
Single-file CUDA, from `tools/someone/` (see `BUILD.md`):
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 someone.cu -o someone.exe'
```
Then: `.\someone.exe --selftest` · `.\someone.exe --golden` · `.\someone.exe <params> --json`.

## Known issues / caveats
- **F8 viability is a LOOSE C3 carrier** (established.md F8 note): the in-code `viability` proxy anti-correlates with fitness; selection runs through the behavioral-survival (death) channel, not the viability scalar. This tool reports `mean_pure_gap` and survival/alive-counts as the real signal; `avg_viability` appears only in the CSV, not as a headline verdict.
- Extreme contract configs (e.g. `--pop 8192 --N 1024`) exceed 16 GB device memory (`W` alone is ~34 GB) → a clean CUDA OOM mapped to **exit 2**, never a crash. Realistic science configs fit easily.
- Cross-arch determinism beyond sm_89 is unmeasured (this machine is the reference).

*Sims prove structure, never acquaintance. Build one tool right; freeze its golden; let the science call it.*
