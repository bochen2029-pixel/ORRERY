# CLAUDE.md — ORRERY build harness

You are building **ORRERY**, a headless, contract-bounded simulation instrument for the final-theory-of-everything project. Read this first, every session. It is the operational entry point; `ARCHITECTURE.md` is the spec.

## What ORRERY is (one paragraph)

ORRERY is the **instrument**; the final-theory project is the **science** that calls it. Tools are prebuilt headless executables with sacred CLI contracts. A scientist agent calls `someone.exe --pop 200 --seed 7 --json` and reads deterministic results; it never writes simulation code. Your job in this repo is to **build and maintain the tools** — contract-first, golden-gated, C/C++/CUDA by default, Python only where justified — so they compound: a smarter agent years from now reworks a tool's internals without breaking any experiment, because the science only ever depended on the *contract* and the *golden*.

## Bootstrap (do this at every session start)

1. Read `ARCHITECTURE.md` — the spec, the invariants (§5 = system physics), the universal tool contract (§6), the language rule (§7), the tool inventory (§8).
2. Read `RUN_STATE.md` — current task + next concrete action.
3. Read `TASKLIST.md` — the build plan and status.
4. Read `DECISIONS.md` (open/active) and `contracts/README.md` (the contract discipline).
5. `git status` and `git log --oneline -15` — ground truth. Then **run the current tool's `--selftest` and `--golden` cold** to verify reality matches claimed state before proceeding.

Time-to-productivity target: under 2 minutes.

## The doctrine you build under (from the v6 enterprise methodology)

- **The spec is the product. The contract is sacred. The golden is load-bearing. The code is ephemeral.** You rewrite *tools*, never the instrument. A tool that honors its contract + reproduces its golden is a drop-in replacement.
- **Contract-first.** No tool source is written until `contracts/<tool>.contract.md` + `<tool>.schema.json` exist and are reviewed. The contract is the decision; the CUDA is implementation.
- **Discipline tightens with capability.** More capable models produce *convincing* wrong code. Golden-gate everything; two-pass any tool the science will cite (a fresh cold-context pass re-runs the golden with no memory of the build). RAYFORMER (a beautiful, measured-false claim) is why.
- **Determinism or it doesn't ship.** Same params + seed ⇒ identical declared output. Seed all RNG. Exclude timing/progress from declared output.
- **Never wait, always log; durable over fast; future-me is a stranger; measure first.** When blocked, log a DECISION and proceed; commit atomically; write for a fresh agent; inspect resource size before consuming (use `C:\chunker\` for big files).

## The build loop (per tool)

1. **Contract** — write `contracts/<tool>.contract.md` (from `contracts/README.md` template) + `contracts/<tool>.schema.json`. Semver from `1.0.0`.
2. **MODULE.md** — write `tools/<tool>/MODULE.md`: purpose, contract link, invariants, internal design, build command, known issues.
3. **Implement** — write the tool (C++/CUDA by default; Python only per `ARCHITECTURE.md` §7, justification in `DECISIONS.md`). Headless: CLI in, JSON/CSV + exit code out. Implement `--selftest` and `--golden`.
4. **Build** — compile per `BUILD.md` (CUDA: vcvars64 + nvcc `-arch=sm_89`). Commit the build command.
5. **Golden** — run the frozen golden params, record `(params → output-hash)` in `goldens/<tool>/`. This freezes the behavior.
6. **Verify** — `harness/` runs selftest + golden green. For a citable tool, dispatch a cold-context two-pass verifier.
7. **Register** — update the tool's row in `ARCHITECTURE.md` §8 and `tools/README.md`. Commit Canon + code together.
8. **Save point** — `git commit` atomic (tool + contract + golden + MODULE.md + RUN_STATE + TASKLIST); update `RUN_STATE.md`.

## The build order (decided)

1. **`someone`** first — generalize `C:\Users\user\Desktop\DSA\dak_evolution_complex.cu` into the first *perfectly* contract-first, golden-gated, headless module. It is the **template** every later tool copies. Get it exactly right. (An earlier CPU-side analysis, `dak_analyze.py`, already produced a real *wounded* result — the strong "advantage grows with complexity" form NOT supported, the weaker "gap wins in threat/deprivation regimes" stands. That is the honest signal the approach works; the `someone` tool must reproduce and sharpen it, headless and seeded, with an N>1 ensemble.)
2. Then `ratchet`, `algebra`, `posit` (Python port), `mcts`, `autotune`. `lens` and the RT-isomorphic SPIKE are backlog.

## Hard rules (never violate)

- Never write a tool without its contract first.
- Never ship a non-deterministic tool, or one without `--selftest` + a golden.
- Never make a breaking contract change without a MAJOR semver bump + migration note.
- Never let a scientist-facing tool depend on internals — only on the declared output schema.
- Never claim an isomorphism/speedup without an honest baseline + measurement (spike-de-risk).
- Never conflate exit 1 (a real negative result) with exit 2 (an error).
- Sims prove structure, never qualia. Keep that line in every MODULE.md.

## Capabilities available to you

- **CUDA 13.1 + RTX 4070 Ti SUPER** (`-arch=sm_89`); MSVC 2022 host via `vcvars64` — see `BUILD.md`.
- **Web search** for primary sources (cite precisely, hunt killers).
- **`C:\chunker\`** for oversized files (measure-first).
- Reference engines to borrow kernels from: `C:\Users\user\Desktop\DSA\` (dak, criticality, nbody, buddhabrot variants), `C:\ASTRA-7` (compile-verify spec pattern), `C:\RAYFORMER` (RT + the ADR-007 lesson), `C:\buddhabrot-main` (CMake + large-scale render pattern).
- The science's canon (for context, not dependency): `C:\Fable_LLC\QUALIA_LAB\` and `C:\Fable_LLC\THE_UNFINISHED_MIRROR_v1_1_by_fable5_2026-07-04.md`.

## Definition of done for the whole instrument (never "finished", always compounding)

A growing catalogue of contract-stable, golden-gated, headless tools + a green compile-as-verification harness + a `/lab` presence on GitHub and finaltheoryofeverything.org. Every tool the science calls is reproducible from its `result.lock`. When a better agent arrives, it reworks a tool's kernels and the goldens still pass — that is the whole point.

*Build one tool right. Freeze its golden. Let the science call it. Repeat.*
