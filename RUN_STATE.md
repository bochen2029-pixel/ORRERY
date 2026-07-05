# RUN_STATE — ORRERY

## Current state
**Build-up session, `someone` (the template tool). Started 2026-07-05 16:54 CST.**
Toolchain verified live: CUDA 13.1 V13.1.80 · RTX 4070 Ti SUPER 16376 MiB (sm_89) driver 610.47 · git 2.48.1 · MSVC 2022 via vcvars64.

**`someone` is BUILT to the full standard (S0–S6 done). Session goal achieved.**
someone.cu builds clean · `--selftest` green (blake2b KATs + confound-fix proof + gap mechanism + determinism) · contract **v1.1.0** (added win_rate/p_value, D-009; schema.json authored) · golden frozen `aa5b731d`, reproduced **4× byte-identical** · conformance battery ALL PASS (`runs/someone_twopass_verify.md`) → **CONFORMANT**. Confound fixed (D-DAK-RNG) + selftest-asserted. Firewall in notes/MODULE. Perf: golden ~8min bandwidth-bound (D-014, fp32 kept for precision). ARCHITECTURE §8 + tools/README → DONE.

**Science result (S5, `runs/someone_round01_reproduce.md`):** de-confounded n=24 sweep — round-01's per-regime winners **[Z,N,Z,N] → [T,T,T,T]** (all statistical ties). Strong monotone form NOT SUPPORTED (reconfirmed corpus-grade); weak threat/deprivation form NOT significant; "zombie-wins-L0/L2" OVERTURNED. The gap is present everywhere but ≈ fitness-neutral (founder-effect seed variance dominates) — vindicates D-DAK-RNG. Science-handback block written for QUALIA_LAB to paste. **Structure only; §III-sealed.**

**OWED (honest):** a genuine **fresh-SESSION cold two-pass** (this session's verification is thorough but single-agent; an independent cold-subagent pass stalled on async handoff). Mark `someone` results **single-agent-verified, cold-two-pass-pending** until then.

## Next concrete action (for the next session)
1. Run the fresh-session cold two-pass on `someone` (contract + binary only; re-run `--golden`, re-check conformance) → then drop the "cold-two-pass-pending" caveat.
2. Then Phase 2 (harness/verify.py is written — run it green) and Phase 3 (next tool: `ratchet`, copying someone's shape). Optionally: a full N=256 n≥20 confirmation of the S5 overturn for heavy-arm parity (~2–3 h).

---

## ORIENTATION (own-words restatement — the STEP 0 gate) — 2026-07-05

### (a) What ORRERY is, and the science↔instrument split
ORRERY is the **instrument**: a catalogue of prebuilt, **headless, deterministic, contract-bounded** simulation executables. The **science** (the final-theory project: THE_UNFINISHED_MIRROR, the QUALIA_LAB canon) is a separate system on a separate clock that **calls** these tools and reads structured results. The two are coupled through **exactly one thing: the tool contract** (CLI flags + JSON/CSV output schema + exit-code semantics + determinism clause, semver'd). The science never sees a CUDA kernel; it only ever depends on a tool's *contract* and its *golden*. That is what lets both compound for years: a smarter agent in 2028 can rewrite `someone`'s kernels and **not one experiment breaks**, because nothing depended on the code — only the contract and the golden. Doctrine: **the spec is the product; the contract is sacred; the golden is load-bearing; the code is ephemeral.** Discipline *tightens* with model capability (confident-wrong output scales with capability) → golden-gate everything, two-pass anything the science cites.

### (b) What the `someone` contract requires (building to v1.1.0 — see DECISION below; v1.0.0 is the frozen base + an additive MINOR bump)
**Flags** (name · type · range · default · meaning):
- `--pop` int 16–8192 def 200 — population size
- `--gens` int 1–5000 def 500 — generations
- `--steps` int 100–5000 def 1500 — steps per generation (episode length)
- `--N` int 32–1024 def 256 — recurrent state dimension
- `--k` int 1–N def N/4 — bottleneck dimension (C2 gap; k=N ⇒ gapless)
- `--zombie-frac` float 0.0–1.0 def 0.5 — fraction initialized as zombies (bottleneck bypassed)
- `--complexity` enum L0|L1|L2|L3 def L3 — env level (see ladder in MODULE.md)
- `--mut-rate` float 0–1 def 0.02 — per-weight mutation probability
- `--mut-str` float 0–1 def 0.1 — mutation magnitude
- `--ensemble` int 1–256 def **1** — independent seeded replicas (replica r uses seed+r); results aggregate mean±sd
- `--seed` int ≥0 **required** — base RNG seed
- `--json` flag — emit JSON envelope on stdout
- `--csv PATH` path — per-generation series (all replicas) to PATH
- `--selftest` flag — internal battery; exit 0/1
- `--golden` flag — run golden params; hash; exit 0/1

**Output `result` fields** (typed):
gens_run:int · normal_fit_final:float · zombie_fit_final:float · normal_fit_sd:float · zombie_fit_sd:float · delta_fit:float (normal−zombie) · normal_alive_final:float · zombie_alive_final:float · zombie_extinct_gen:int (−1 if never) · mean_pure_gap:float · winner:enum(normal|zombie|tie) · tie_band:float(0.02) · **[v1.1.0 additive]** win_rate:float (fraction of replicas normal beats zombie by >tie_band) · p_value:float (one-sided sign-test that normal wins >½).

**Envelope**: `{tool,version,seed,params,result,verdict,gates,notes}`. `notes` is NON-declared (excluded from golden hash) and carries the structure/acquaintance firewall sentence.

**Gates → exit 1**: G-ZOMBIE-WINS (delta_fit < −tie_band) · G-NO-GAP (mean_pure_gap < 0.01).
**Exit codes**: 0 = pass (normal wins or ties with a real gap) · 1 = a declared gate fired (a REAL negative result / finding) · 2 = error (bad input, out-of-range, CUDA failure). Never conflate 1 and 2.

**Determinism clause**: declared output (tool,version,seed,params,result,verdict,gates) is a byte-identical function of (all params, seed) on sm_89. curand-free per-neuron noise keyed by (seed+replica, agentId, neuronId, step); host mt19937_64 for evolution/init seeded (seed+r) in fixed draw order; env layout via purpose-keyed splitmix64. No float atomics in any declared reduction (prototype already uses shared-mem tree reductions + host index-order sums — kept). notes/timing nondeclared.

**Golden params**: `--pop 200 --gens 200 --steps 800 --N 256 --k 64 --zombie-frac 0.5 --complexity L3 --ensemble 4 --seed 20260705 --json`. Golden hash domain = canonical JSON of {seed, params, result, gates, verdict} (blake2b); tool/version/notes excluded from the hash so a pure kernel rewrite that reproduces behavior keeps the golden.

### (c) The mission & definition of done
Build `someone` to the FULL ORRERY standard as the reference template every later tool copies: deterministic, headless, contract-exact, golden-gated, documented. DONE = someone.exe builds; `--selftest` green (incl. the fair-layout-across-levels assertion); golden frozen and `--golden` reproduces it ≥3× byte-identical; the round-01 finding reproduced with an ensemble (n≥20, fixed RNG) and reported per level with stats + strong/weak/overturn verdict; MODULE.md with the firewall line; science-handback block; result.lock; ARCHITECTURE §8 + tools/README → DONE; committed locally; clean RUN_STATE handoff.

### (d) The four things I expect to bite me + plan
1. **Determinism.** Prototype nondeterminism is narrower than feared: NO float atomics (reductions are shared-mem trees + host index-order sums — deterministic). Real bugs = (i) wall-clock seeds (lines 545 `steady_clock`, 590 `time(NULL)`), (ii) per-neuron noise race (all threads load the same agent randState L185, draw independently, all write back L507 → last-writer race + identical noise). PLAN: kill both — host `mt19937_64` seeded (seed+r) for init/evolution; **stateless counter-based Gaussian** for per-step neuron noise keyed by (seed+r, agent, neuron, step) (no state, no race, no memory). Keep the deterministic reductions; add host Kahan for the ensemble mean. Verify `--golden` ≥3× byte-identical before advancing (a race can pass 2 by luck).
2. **RNG confound (D-DAK-RNG, CONFIRMED).** Prototype's env RNG is one continuous mt19937(42) whose per-gen draw count differs by level → base layout silently differs across levels → `--complexity` compares different worlds. PLAN (fix option **b**: pre-draw canonical level-independent layout, gate dynamics): generate env via **purpose-keyed splitmix64** — base light/food/predator positions keyed by (seed+r, gen) ONLY (drawn for ALL levels incl. inactive predators at L0), light/predator MOVES and night keyed/derived independently so toggling a feature shifts no other stream. `--selftest` asserts the gen-0 base-layout hash is byte-identical across L0/L1/L2/L3 at a fixed seed — that assertion IS the proof. Keep L2↔L3 as the clean night A/B.
3. **Statistical validity (BITE #3).** Round-01's fatal flaw was N=1/level. PLAN: contract keeps `--ensemble` default 1, but S5 runs n≥20/level; add (v1.1.0) `win_rate` + `p_value` (one-sided sign test) to the declared output so a per-level claim is licensed only when win-rate significantly >50% (else TIE). Golden uses n=4 (fast); real experiment n≥20.
4. **Structure/acquaintance firewall (BITE #4).** `someone` measures whether the gap confers FITNESS (structure); it says NOTHING about whether the agent FEELS (acquaintance, §III-sealed). PLAN: the exact firewall sentence goes in the JSON `notes`, MODULE.md, and every write-up. Never report the post-extinction fitness ratio (report delta_fit + alive-counts); never cite avgGap→1 as evidence (definitional).

---

## Reversible decisions locked this session (logged; see DECISIONS.md D-009..D-013)
- **D-009 v1.1.0 additive bump**: add `win_rate`,`p_value` to output (MINOR; per BITE #3 + the science's citability bar). v1.0.0 had no golden/caller, so this is safe and models correct semver discipline for the template.
- **D-010 `--ensemble` default stays 1** (contract-faithful; changing a default is behavior-breaking). BITE #3's "≥20" is satisfied by the S5 invocation, not a default change.
- **D-011 Complexity ladder is CUMULATIVE**: L0 base(static lights+food+energy) · L1 +predators · L2 +moving-lights · L3 +night(=full). Makes L2↔L3 the clean night A/B the science (D-DAK-RNG) relies on; matches contract L3="full" and round-01 regime labels.
- **D-012 RNG architecture**: host mt19937_64 (init/evolution, seed+r) · stateless counter Gaussian (device per-step noise) · purpose-keyed splitmix64 (env layout). No curand (removes the state-writeback race by construction).
- **D-013 Golden hash domain** = canonical JSON of {seed,params,result,gates,verdict}, floats at %.6f, blake2b; excludes tool/version/notes so a behavior-preserving kernel rewrite keeps the golden.

## Next concrete action
S1: write `tools/someone/MODULE.md`; author `contracts/someone.schema.json` (the founding session left it unwritten — the machine-checkable half of the contract) at v1.1.0; update `contracts/someone.contract.md` (v1.1.0 fields + changelog); add DECISIONS D-009..D-013. Commit. Then S1b: walking-skeleton `someone.cu` (CLI + minimal 1-replica/1-level sim + JSON envelope + trivial selftest + golden), compile, prove determinism ≥3×, commit. Then S2 full sim.

## Guards (never violate — from the contract + BITEs)
- Never report the post-extinction normal/zombie fitness RATIO (≈1e10 artifact); report delta_fit + alive-counts.
- avgGap→1 is DEFINITIONAL for a saturated bottleneck, not evidence.
- Sims prove STRUCTURE (does the gap confer fitness), never ACQUAINTANCE (qualia). §III-sealed. In every MODULE.md + output notes.
- Determinism or it doesn't ship. `--golden` ≥3× byte-identical.

## Pointers
Spec: ARCHITECTURE.md · Build loop + rules: CLAUDE.md · Plan: TASKLIST.md · Contract: contracts/someone.contract.md (+ .schema.json) · Runbook: BUILD.md · Charter: AUTONOMY_CHARTER.md · Decisions: DECISIONS.md
Prototype ported: `C:\Users\user\Desktop\DSA\dak_evolution_complex.cu` (read-only). Science (context, not dependency): `C:\Fable_LLC\QUALIA_LAB\` (F6/F8 in established.md; D-DAK-RNG in debts.md; confound receipt in gym/receipts/dak_skeptic_rng_confound.py).
