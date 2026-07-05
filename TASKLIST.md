# TASKLIST — ORRERY build

Operator brief: build ORRERY into a working, contract-first, headless simulation instrument for the final-theory project. Spec + Laws are laid down; now build the tools. `someone` first, to full standard, as the template.

Status legend: NOT_STARTED · IN_PROGRESS · DONE · SUSPECT · DEFERRED

## Phase 0 — Foundation (DONE, by the founding session 2026-07-05)
- [DONE] ARCHITECTURE.md (spec) · CLAUDE.md (harness) · DECISIONS.md (ADRs) · BUILD.md (runbook)
- [DONE] contracts/README.md (universal contract) · contracts/someone.contract.md (exemplar v1.0.0)
- [DONE] tools/README.md · harness/README.md · goldens/README.md · AUTONOMY_CHARTER.md · RUN_STATE.md

## Phase 1 — `someone` to full standard (the template)  ← IN PROGRESS
- [DONE] S1 · Read contract + prototype + science refs. Wrote `tools/someone/MODULE.md`. Also authored the missing `contracts/someone.schema.json`, bumped the contract to **v1.1.0** (additive win_rate/p_value, D-009), logged D-009..D-013.
- [IN_PROGRESS] S1b · Walking skeleton `someone.cu`: CLI parse (all flags) + minimal 1-replica/1-level short sim + JSON envelope + trivial `--selftest` + `--golden`, deterministic (`--golden` ≥3× byte-identical on the stripped config). Compile + prove determinism on the skeleton before enriching.
- [NOT_STARTED] S2 · Implement the FULL `tools/someone/someone.cu` to the contract: CLI parse (all flags), the evolutionary sim (port dak kernels), `--ensemble`, `--complexity` L0–L3 with the RNG confound fixed, deterministic reductions (NO atomics in the declared-output reduction path), the JSON envelope, `--csv`, gates (G-ZOMBIE-WINS, G-NO-GAP), `--selftest` (incl. fair-layout assertion), `--golden`.
- [NOT_STARTED] S3 · Build per BUILD.md; run selftest; run the golden config; confirm determinism (run `--golden` twice → identical hash).
- [NOT_STARTED] S4 · Freeze the golden into `goldens/someone/`. 
- [NOT_STARTED] S5 · Reproduce & sharpen the round-01 finding with `--ensemble ≥8`: is "gap wins in threat/deprivation (L1/L3)" robust across seeds? Is the strong "advantage grows monotonically with complexity" still NOT supported? Write `runs/someone_round01_reproduce.md` + a `result.lock`.
- [NOT_STARTED] S6 · Two-pass cold verify (fresh agent, contract + binary only). Update ARCHITECTURE §8 + tools/README status → DONE.

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
