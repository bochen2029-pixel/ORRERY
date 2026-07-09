# RUN_STATE — ORRERY

> 🧠 **REHYDRATION / FULL RECOLLECTION:** for the complete session memory + continuation prompt + rehydration procedure, read **[`SESSION_MEMORY.md`](SESSION_MEMORY.md)** first. Trust the files + git over any recalled narrative; verify with `git log/status` and a tool's `--selftest`/`--golden` before resuming. History of the 6-tool build (2026-07-05/06): git log + `runs/*_twopass_verify.md`.

## Current state
**Wave-0 (Phase 5) session, 2026-07-09.** Operator adopted the wave plan (`docs/PROPOSAL_2026-07-09_wave_plan.md`): D-020 (liborrery) + D-021 (CMake preset/fat binary/fast-math ban) ACTIVE; I-11..I-14 in ARCHITECTURE §5; Phase 5–8 addendum in TASKLIST. D-022..D-026 stay PROPOSED until their phases open.

**Bootstrap verification (this session, before any change):** all 6 tools cold-green — selftests exit 0 (someone, ratchet, posit, mcts, algebra, autotune) and goldens exit 0 (ratchet, mcts, algebra, posit, autotune fast; someone `aa5b731d` reproduced in ~8 min, GOLDEN OK).

**`lib/` (liborrery v1.0.0) BUILT + KAT-GREEN (D-020).** envelope.h/.cpp (blake2b + sha256 + canonical serializers + golden plumbing + CLI spine + lock writer; D-013 hash domain unchanged), rng.cuh (D-012 kit), reduce.cuh (fixed-order reductions + order-invariant fixed-point atomics + sort-then-gather host ref), regime.h (derived-only bitmask), ckpt.h (B7: dump + sha256 sidecar + verified resume), MODULE.md, selftest.cu → `orrery_selftest.exe` **42/42 PASS** (run from repo root). Extraction is VERBATIM from someone v1.1.0, enforced mechanically by a ref-namespace cross-check + pinned host/device RNG bit patterns (integer/u01 pins independently confirmed in Python; splitmix64(0) = Vigna's published vector).

**Measured finding, now pinned:** host (MSVC) vs device (CUDA) libm diverge by **1 ULP** on `counter_gauss(20260705,7,11,13)` (`...9d3b` vs `...9d3a`). Never assert host==device on transcendental paths; the device pins are a CUDA-toolkit drift detector that fires before a tool golden silently breaks.

**CMake preset (D-021) VERIFIED:** `cmake --preset windows-sm89-fat` + build green (CMake 4.3.3 + VS Ninja under vcvars64); cuobjdump shows sm_89+sm_90+sm_120 SASS + sm_120 PTX; CMake-built selftest passes. Bare-nvcc stays the golden path; `build/` gitignored.

## Next concrete action
**Migrate the four CUDA tools to lib, ONE COMMIT EACH, in order: ratchet (91fce3c4) → mcts (6c596a53) → algebra (1526918f) → someone (aa5b731d).**
HARD GATE per tool: existing golden reproduces **bit-identical** post-migration (`--golden` exit 0, hash match; ratchet/mcts/algebra 3×, someone ≥1× at ~8 min). Update the tool's MODULE.md fenced build block (`+ ../../lib/envelope.cpp`). `verify.py --tool <name>` green. On ANY mismatch: STOP that migration, mark SUSPECT, log a DECISION with the diff, move on or halt — never force, never re-baseline.
Then (later sessions, Phase 5 remainder): `mcp` v1.0.0 (adopt D-022 in that commit) → `orreryd` v0 → `/lab` registry page (publish itself OPERATOR-GATED).

## Guards (never violate)
- Contracts and goldens are FROZEN; migrations are [BEHAVIOR-NEUTRAL] by definition or they are rejected.
- Determinism or it doesn't ship. No float atomics in declared reductions. Fast-math banned (D-021/I-13).
- Never conflate exit 1 (gate fired = real result) with exit 2 (error).
- Sims prove STRUCTURE, never ACQUAINTANCE (qualia). §III-sealed.
- Atomic commits: code + canon together (Invariant 10).

## Pointers
Spec: ARCHITECTURE.md (§5 invariants now 1–14; §8 has the I-11 oracle column) · Plan: TASKLIST.md (Phase 5 = current) · Decisions: DECISIONS.md (D-020/D-021 newest) · Wave plan: docs/PROPOSAL_2026-07-09_wave_plan.md · Lib: lib/MODULE.md · Runbook: BUILD.md · Harness: harness/verify.py (tools only; lib selftest runs standalone from repo root).
