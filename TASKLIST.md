# TASKLIST — ORRERY build

Operator brief: build ORRERY into a working, contract-first, headless simulation instrument for the final-theory project. Spec + Laws are laid down; now build the tools. `someone` first, to full standard, as the template.

Status legend: NOT_STARTED · IN_PROGRESS · DONE · SUSPECT · DEFERRED

## Phase 0 — Foundation (DONE, by the founding session 2026-07-05)
- [DONE] ARCHITECTURE.md (spec) · CLAUDE.md (harness) · DECISIONS.md (ADRs) · BUILD.md (runbook)
- [DONE] contracts/README.md (universal contract) · contracts/someone.contract.md (exemplar v1.0.0)
- [DONE] tools/README.md · harness/README.md · goldens/README.md · AUTONOMY_CHARTER.md · RUN_STATE.md

## Phase 1 — `someone` to full standard (the template)  ← IN PROGRESS
- [DONE] S1 · Read contract + prototype + science refs. Wrote `tools/someone/MODULE.md`. Also authored the missing `contracts/someone.schema.json`, bumped the contract to **v1.1.0** (additive win_rate/p_value, D-009), logged D-009..D-013.
- [DONE] S1b · Walking skeleton `someone.cu`: full CLI + minimal deterministic sim + JSON envelope + selftest + golden + self-contained blake2b (KAT-validated). Determinism spine proven (`--golden` 3× byte-identical).
- [DONE] S2 · Full `tools/someone/someone.cu` to the contract: ALL flags (bad input→exit 2), the evolutionary sim (ported dak kernels, dynamic shared mem, coalesced column-major weights, warp-shuffle reductions), `--ensemble`, `--complexity` L0–L3 with the RNG confound FIXED (purpose-keyed splitmix64, selftest-asserted), stateless counter-RNG noise (no float atomics anywhere), JSON envelope, `--csv`, gates, `--selftest` (blake2b KATs + confound-fix proof + gap-mechanism + determinism), `--golden`. Determinism confirmed byte-identical 3× on medium config. **Perf: golden config ~8min, bandwidth-bound — see D-014.**
- [DONE] S3 · Build per BUILD.md (clean); selftest green; golden determinism confirmed **byte-identical 3×** (hash `aa5b731d…`, ~465s each).
- [DONE] S4 · Golden frozen into `goldens/someone/` (declared.hash + stdout.txt + NOTE.md); `--golden` reproduces it (GOLDEN OK) on the rebuilt binary; `runs/someone_golden.result.lock` captured. NB: golden is a determinism anchor, and at L3/n=4 it (de-confounded) shows *zombie* winning — an early hint of the overturn, to be tested rigorously in S5.
- [DONE] S5 · De-confounded n=24 sweep L0–L3 done (`runs/someone_round01_reproduce.md`, `.result.lock`, `analyze_round01.py`, `runs/round01/`). **RESULT: [Z,N,Z,N] → [T,T,T,T]** (all ties, two-sided sign test). Strong monotone form NOT SUPPORTED (reconfirmed corpus-grade); weak threat/deprivation form NOT significant; "zombie-wins-L0/L2" OVERTURNED. D-DAK-RNG(1)+(2) resolvable. Science-handback written.
- [DONE] S6 · Verification (`runs/someone_twopass_verify.md`): golden reproduced byte-identical; full conformance battery ALL PASS → **CONFORMANT to v1.1.0**. **Cold two-pass COMPLETE** — an independent no-build-context subagent rebuilt from source, reproduced golden `aa5b731d` bit-for-bit, and passed 18 conformance checks (CONFORMANT). ARCHITECTURE §8 + tools/README → DONE (cold two-pass verified). **someone fully cleared.**

## Phase 2 — the harness
- [DONE] H1 · `harness/verify.py`: discovers tools from MODULE.md, build+selftest+golden each, dated report, exit 0 iff green. **Ran GREEN** (someone: build/selftest/golden OK — `runs/verify_20260705_190525.md`), independently, from a cold-context subagent. Auto-discovers ratchet too.

## Phase 3 — the next tools (copy someone's shape)
- [DONE*] `ratchet` (from criticality_cuda + toy_rr_frontier_ratchet) — branching-ratchet MC; reproduce (1−p)ρ=p at GPU scale.
  - [DONE] R1 · Contract-first: `contracts/ratchet.contract.md` v1.0.0 + `ratchet.schema.json` + `tools/ratchet/MODULE.md` (D-015).
  - [DONE] R2 · Implemented `tools/ratchet/ratchet.cu` (one thread/trajectory grid-stride, exact per-fragment Bernoulli w/ early-escape, integer atomics ⇒ trivial determinism). Builds clean; `--selftest` green (KATs + analytic identities + MC↔analytic super/subcritical + determinism).
  - [DONE] R3 · Golden frozen `91fce3c4` (3× byte-identical, ~0.5s); **MC↔analytic rel_error 0.06%** — the (1−p)ρ=p threshold reproduced in-silico. `result.lock` captured.
  - [DONE] R4 · Cold two-pass (independent no-build-context subagent, `runs/ratchet_twopass_verify.md`). **Caught a real defect** — MODULE.md build command was an inline span, not a fenced block, so `verify.py` couldn't discover it (harness RED). Behavior was fully conformant (golden reproduced shipped+cold-rebuilt, MC↔analytic 0.0004, schema/exit-codes/determinism/firewall all pass). **Fixed** (fenced the build block + template note); re-verified `verify.py --tool ratchet` **GREEN**. ratchet now CONFORMANT. *(scale note: exact-Bernoulli fine to ~1e8 trials; billions want O(1) binomial — golden-superseding, deferred.)*
- [DONE] `posit` (Python port of posit_counter) — parsimony auditor, the Python-is-right tool (D-005/D-016). Contract v1.0.0 + schema + MODULE + `posit.py` + golden `7a22dd22` (3× byte-identical, exact/no-RNG determinism). selftest green (12 checks). Reads audit cases via `--case`/`--stdin`. `harness/verify.py` made polyglot → GREEN. **Cold two-pass DONE** (independent subagent → CONFORMANT, `runs/posit_twopass_verify.md`; golden hand-checked, all guards verified). *(D-POSIT-AGG multi-cluster aggregation deferred to v1.1.0.)*
- [DONE] `algebra` (cuSOLVER) — crossed-product entropy-from-observer, scoped to Part A (D-018). Contract v1.0.0 + schema + MODULE + `algebra.cu` + golden `1526918f` (3× byte-identical). Critical **c=0.9963** (analytic c=1, checked vs Calabrese–Cardy); massive control c≈0. Validated vs the science's own receipt. selftest green (8 checks). **Cold two-pass DONE** (independent subagent → CONFORMANT, 13 checks, **scope confirmed — no withdrawn Part-B value**; `runs/algebra_twopass_verify.md`). *(fixed-site Part-B refit deferred to v1.1.0.)*
- [DONE] `mcts` — generic CUDA root-parallel UCT search engine (D-017). Contract v1.0.0 + schema + MODULE + `mcts.cu` + golden `6c596a53` (3× byte-identical). One tree/thread, index-based node pool, counter-RNG rollouts, deterministic UCB1. Golden: all 1024 trees find the exact optimum of the 4^6 `match` landscape. selftest green (7 checks). **Cold two-pass DONE** (independent subagent → CONFORMANT, `runs/mcts_twopass_verify.md`; incl. an anti-RAYFORMER hash-integrity check). *(deceptive landscape / custom reward deferred to v1.1.0.)*
- [DONE*] `autotune` — parameter sweep / basin-finder, Python glue (D-019). Contract v1.0.0 + schema + MODULE + `autotune.py` + golden `c79002f2` (3× byte-identical; exact/no-RNG). Built-in `peak`/`threshold` objectives (self-contained golden) + real-tool subprocessing (the compounding feature); parabolic-argmax / interpolated-crossing locators; pre-registered `--target` + G-OFF-TARGET. selftest green (6 checks). **Demonstrated compounding:** drives `ratchet` across ρ to locate `(1−p)ρ=p` at 0.2581 (analytic 0.25). Polyglot harness → GREEN. **Cold two-pass DONE** (independent subagent → CONFORMANT, real-tool mode verified driving ratchet; `runs/autotune_twopass_verify.md`). **← completes the buildable catalogue; only `lens` (parked SPIKE, D-004) remains.** *(optional v1.0.1: `abspath()` the `--tool` path so bare forward-slash relative paths work on Windows — flagged by the cold verifier, not a defect.)*

## Phase 4 — publish
- [NOT_STARTED] Git init, public GitHub repo (standalone). README from ARCHITECTURE intro.
- [NOT_STARTED] `/lab` page on finaltheoryofeverything.org: catalogue + contracts + example results + phase diagrams; link the repo. (The site builder lives in `C:\Websites\finaltheoryofeverything.org\`.)

## Critical tools (two-pass required before any science citation)
someone, algebra (results feed the theory's F16/F6 claims).

---

# Wave-plan addendum (adopted 2026-07-09 per operator ruling; source: `docs/PROPOSAL_2026-07-09_wave_plan.md`)

Adoption state: **D-020, D-021 ACTIVE** (this commit); D-022..D-026 remain PROPOSED — each adopts when its build phase opens (proposal §0 protocol). Invariants I-11..I-14 adopted into ARCHITECTURE §5.

## Phase 5 — Infrastructure (Wave 0)  ← CURRENT
- [DONE] `lib/` per D-020 (envelope.h/.cpp, rng.cuh, reduce.cuh, regime.h, ckpt.h) + MODULE.md + KAT selftest (42 checks green, incl. ref-namespace verbatim cross-check + pinned host/device RNG bit patterns; measured 1-ULP MSVC↔CUDA libm divergence pinned per side). D-013 hash domain unchanged.
- [DONE] CMake preset (D-021): fat binary verified via cuobjdump (sm_89+sm_90 SASS, compute_120 PTX), static runtimes, fast-math ban; CMake-built selftest green; bare-nvcc path unchanged.
- [IN_PROGRESS] Migrate to lib, one tool per commit, HARD GATE = existing golden reproduces BIT-IDENTICAL (mismatch ⇒ STOP, SUSPECT, log DECISION — never force/re-baseline): [ ] ratchet (91fce3c4) → [ ] mcts (6c596a53) → [ ] algebra (1526918f) → [ ] someone (aa5b731d).
- [NOT_STARTED] `mcp` v1.0.0 full build loop (D-022 — adopt D-022 in that commit).
- [NOT_STARTED] `orreryd` v0: queue + budgets + status page (D-022).
- [NOT_STARTED] Phase-4 publish unblocked: `/lab` page reads the registry (site builder: `C:\Websites\finaltheoryofeverything.org\`). Publish itself stays OPERATOR-GATED.

## Phase 6 — Wave 1 (the make-or-break physics; adopt D-026 pre-contract per tool)
- [NOT_STARTED] `hsmi-stab` (F-K1; first by dignity) → [NOT_STARTED] `trace-born` (C-TRACE) → [NOT_STARTED] `carve` (Layer-2/P2). Each: full loop, oracle named (I-11), two-pass, science-handback memo (the someone S5 pattern).

## Phase 7 — Wave 2
- [NOT_STARTED] `ratchet-v2` (DP exponents) → `clifford/mipt` → `everpresent` (I-14 frozen DESI data) → `someone-v2` (metabolic k) → `modfluc` (F-SEAM) → `fork` (F-BMV) → `prequent` → `algebra` v1.1 (the owed fixed-site Part-B refit, D-018 deferral).

## Phase 8 — Scale (as needed, gated by demand; adopt D-023/D-024 when opened)
- [NOT_STARTED] `someone` S-A ensemble-in-grid → S-B CUDA graphs (both BEHAVIOR-NEUTRAL, golden-gated) → S-C fp16 storage flag (ADDITIVE, secondary golden, I-13 paired-oracle) → S-D tensor-core SPIKE (pre-registered kill, ADR-007 protocol) → campaign harness (D-024) → cloud RUNBOOK dry-run.
