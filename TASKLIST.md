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
- [IN_PROGRESS] S5 · Reproduce & sharpen round-01 with `--ensemble 24` (n≥20, BITE #3), de-confounded, per level L0–L3 (config in `runs/someone_round01_run.ps1`). Is "gap wins in threat/deprivation (L1/L3)" robust? Is the strong monotone form still unsupported? Does "zombie wins L0/L2" survive, or was it a confound artifact (overturn)? Write `runs/someone_round01_reproduce.md` + `result.lock` + science-handback.
- [NOT_STARTED] S6 · Two-pass cold verify (fresh subagent, contract + binary only). Update ARCHITECTURE §8 + tools/README status → DONE.

## Phase 2 — the harness
- [NOT_STARTED] H1 · `harness/verify.py`: discover tools, build + selftest + golden each, dated report to runs/, exit 0 iff green.

## Phase 3 — the next tools (copy someone's shape)
- [NOT_STARTED] `ratchet` (from criticality_cuda) — branching/phase-transition; reproduce (1−p)ρ=p at GPU scale; gate = critical-point match.
- [NOT_STARTED] `posit` (Python port of posit_counter) — parsimony auditor; contract + golden.
- [NOT_STARTED] `algebra` (cuSOLVER) — crossed-product entropy-from-observer; the divergence-cancellation receipt (D-CP).
- [NOT_STARTED] `mcts` — generic CUDA MCTS the science calls.
- [NOT_STARTED] `autotune` — parameter sweep + basin finder; pre-registered targets.

## Phase 4 — publish
- [NOT_STARTED] Git init, public GitHub repo (standalone). README from ARCHITECTURE intro.
- [NOT_STARTED] `/lab` page on finaltheoryofeverything.org: catalogue + contracts + example results + phase diagrams; link the repo. (The site builder lives in `C:\Websites\finaltheoryofeverything.org\`.)

## Critical tools (two-pass required before any science citation)
someone, algebra (results feed the theory's F16/F6 claims).
