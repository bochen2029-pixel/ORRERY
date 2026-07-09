# RUN_STATE — ORRERY

> 🧠 **REHYDRATION / FULL RECOLLECTION:** for the complete session memory + continuation prompt + rehydration procedure, read **[`SESSION_MEMORY.md`](SESSION_MEMORY.md)** first. Trust the files + git over any recalled narrative; verify with `git log/status` and a tool's `--selftest`/`--golden` before resuming. History of the 6-tool build (2026-07-05/06): git log + `runs/*_twopass_verify.md`.

## Current state
**Wave-0 (Phase 5) session, 2026-07-09.** Operator adopted the wave plan (`docs/PROPOSAL_2026-07-09_wave_plan.md`): D-020 (liborrery) + D-021 (CMake preset/fat binary/fast-math ban) ACTIVE; I-11..I-14 in ARCHITECTURE §5; Phase 5–8 addendum in TASKLIST. D-022..D-026 stay PROPOSED until their phases open.

**Bootstrap verification (this session, before any change):** all 6 tools cold-green — selftests exit 0 (someone, ratchet, posit, mcts, algebra, autotune) and goldens exit 0 (ratchet, mcts, algebra, posit, autotune fast; someone `aa5b731d` reproduced in ~8 min, GOLDEN OK).

**`lib/` (liborrery v1.0.0) BUILT + KAT-GREEN (D-020).** envelope.h/.cpp (blake2b + sha256 + canonical serializers + golden plumbing + CLI spine + lock writer; D-013 hash domain unchanged), rng.cuh (D-012 kit), reduce.cuh (fixed-order reductions + order-invariant fixed-point atomics + sort-then-gather host ref), regime.h (derived-only bitmask), ckpt.h (B7: dump + sha256 sidecar + verified resume), MODULE.md, selftest.cu → `orrery_selftest.exe` **42/42 PASS** (run from repo root). Extraction is VERBATIM from someone v1.1.0, enforced mechanically by a ref-namespace cross-check + pinned host/device RNG bit patterns (integer/u01 pins independently confirmed in Python; splitmix64(0) = Vigna's published vector).

**Measured finding, now pinned:** host (MSVC) vs device (CUDA) libm diverge by **1 ULP** on `counter_gauss(20260705,7,11,13)` (`...9d3b` vs `...9d3a`). Never assert host==device on transcendental paths; the device pins are a CUDA-toolkit drift detector that fires before a tool golden silently breaks.

**CMake preset (D-021) VERIFIED:** `cmake --preset windows-sm89-fat` + build green (CMake 4.3.3 + VS Ninja under vcvars64); cuobjdump shows sm_89+sm_90+sm_120 SASS + sm_120 PTX; CMake-built selftest passes. Bare-nvcc stays the golden path; `build/` gitignored.

## Migrations: ALL FOUR GREEN (2026-07-09, one commit each)
**ratchet v1.0.1** golden `91fce3c4` ✓ bit-identical 3× · **mcts v1.0.1** `6c596a53` ✓ 3× · **algebra v1.0.1** `1526918f` ✓ 3× · **someone v1.1.1** `aa5b731d` ✓ (~8-min full-precision run, byte-for-byte). Zero mismatches — no SUSPECT, no re-baseline. Harness `verify.py --tool` GREEN for ratchet/mcts/algebra; posit/autotune untouched and re-confirmed golden-green. **D-020's acceptance criterion ("the code is ephemeral", in vivo) is fully met.** Net: each tool lost its ~80–220 lines of duplicated core; the doctrine now lives in one KAT-pinned place.

## `mcp` v1.0.0 BUILT + VERIFIED (tool #7, D-022 adopted Active) — the instrument is LLM-callable
Contract v1.0.0 + schema + MODULE + `mcp.py` (stdio JSON-RPC 2.0; six tools: list_tools, describe_contract-verbatim, run_tool, get_run, sweep→autotune, golden_status). **I-12 live:** every run response embeds the D-013 declared blake2b (textual extraction from the fixed-order envelope) + artifact blake2b. Golden `174ec02d` (3× byte-identical; the canned-posit chain — deliberate narrow coupling, re-baseline protocol in goldens/mcp/NOTE.md). Selftest 13/13. Polyglot harness GREEN. Live smoke drove a real ratchet GPU run through --serve. Pre-commit smoke caught + fixed a real defect (param keys rejected the catalogue's uppercase --R/--N). **Cold two-pass: CONFORMANT 10/10, no defects** (`runs/mcp_twopass_verify.md`).

## Next concrete action
Phase 5 remainder (next session): **`orreryd` v0** (queue + budgets + status page — under the already-Active D-022), then the `/lab` registry page (**publish itself stays OPERATOR-GATED** — no `git push`/public repo without explicit confirmation). Also candidate: `someone`'s owed fp64 CPU oracle (I-11/D-025). Wave 1 (`hsmi-stab` first, D-026 pre-contract adopted at open) starts after Phase 5 closes.

## Guards (never violate)
- Contracts and goldens are FROZEN; migrations are [BEHAVIOR-NEUTRAL] by definition or they are rejected.
- Determinism or it doesn't ship. No float atomics in declared reductions. Fast-math banned (D-021/I-13).
- Never conflate exit 1 (gate fired = real result) with exit 2 (error).
- Sims prove STRUCTURE, never ACQUAINTANCE (qualia). §III-sealed.
- Atomic commits: code + canon together (Invariant 10).

## Pointers
Spec: ARCHITECTURE.md (§5 invariants now 1–14; §8 has the I-11 oracle column) · Plan: TASKLIST.md (Phase 5 = current) · Decisions: DECISIONS.md (D-020/D-021 newest) · Wave plan: docs/PROPOSAL_2026-07-09_wave_plan.md · Lib: lib/MODULE.md · Runbook: BUILD.md · Harness: harness/verify.py (tools only; lib selftest runs standalone from repo root).
