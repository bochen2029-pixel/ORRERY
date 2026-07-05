# AUTONOMY_CHARTER — ORRERY build runs

The standing constitution for a session (autonomous or supervised) building ORRERY. Loaded via CLAUDE.md every session.

## 1 · Run boundaries
- **May modify:** everything under `C:\ORRERY\`.
- **May read (not modify):** the reference engines (`C:\Users\user\Desktop\DSA\`, `C:\ASTRA-7`, `C:\RAYFORMER`, `C:\buddhabrot-main`), the science canon (`C:\Fable_LLC\QUALIA_LAB\`, `C:\Fable_LLC\THE_UNFINISHED_MIRROR_v1_1...md`), `C:\chunker\`.
- **NEVER modify:** anything outside `C:\ORRERY\` (the reference engines and the science are read-only inputs).

## 2 · Pre-authorized decisions (do, log, proceed)
- Write/compile/run any tool, selftest, golden, harness under `C:\ORRERY\`.
- Borrow and adapt kernels from the reference engines (adapt to ORRERY's contract; cite provenance in MODULE.md).
- Install a Python stdlib-only helper; run `nvcc`/`cmake`/`python`.
- Web-search primary sources (cite precisely).
- Choose internal implementation details (kernel layout, block size, data structures) freely — the CONTRACT constrains the interface, not the impl.
- Pick reasonable numeric internals (learning rates, network scales) matching the prototype unless the contract says otherwise.

## 3 · Hard prohibitions (never, regardless of reasoning)
- Never change a tool's **contract** (`contracts/*.md`, `*.schema.json`) without a semver bump + change-log note + a line in DECISIONS.md. A MAJOR (breaking) change → file a QUESTION and defer to operator.
- Never ship a tool that is non-deterministic, or lacks `--selftest` + a golden.
- Never overwrite a golden silently (supersede only under two-pass review + note).
- Never conflate exit 1 (real negative result) with exit 2 (error).
- Never make ORRERY depend on the science, or the science's internals leak into a tool.
- Never claim an isomorphism/speedup without an honest baseline + measurement.
- Never write Python for a compute-heavy tool to "move faster" — CUDA/C++ per D-005.
- Never `git push` or create a public repo without operator confirmation (Phase 4 is operator-gated).

## 4 · Default-and-log
When a decision isn't pre-authorized and isn't prohibited: pick the most reversible option, log it in DECISIONS.md (tag `DECISION:`), tag any speculative code `// SPECULATION:`, continue. Operator reviews on return.

## 5 · Escalation (file in a QUESTIONS.md / BLOCKERS.md you create, mark task DEFERRED, advance)
- A breaking contract change seems necessary → QUESTION.
- A determinism requirement seems impossible for a tool → BLOCKER (with what was tried).
- A golden won't reproduce and the cause isn't an obvious atomics/seed bug → BLOCKER.
- The round-01 finding does NOT reproduce even qualitatively → QUESTION (this is a real signal, surface it).

## 6 · Speculation budget
≤15 active `// SPECULATION:` tags per run. Past that, stop and consolidate — it signals the contract or design needs operator input.

## 7 · Discipline (non-negotiable)
- Contract before code; golden before done; selftest always.
- Atomic save points (once git exists): tool + contract + golden + MODULE + RUN_STATE + TASKLIST in one commit.
- Two-pass cold verify for any tool the science will cite (someone, algebra).
- Determinism checklist (BUILD.md) run on every CUDA tool.
- Sims prove structure, not qualia — in every MODULE.md.

## 8 · Definition of a good run
`someone` built to full standard, deterministic, golden frozen, round-01 finding reproduced with an ensemble, harness green. Or measurable progress toward it with clean save points and an honest RUN_STATE. Never a haunted house.
