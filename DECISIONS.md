# ORRERY — Decision Log (ADRs)

Append-only. Each: context, decision, rationale, alternatives rejected, consequences. `Status: Active | Superseded`.

---

## D-001 · ORRERY is a standalone repo, separate from the theory
Date: 2026-07-05 · Status: Active
**Context:** The instrument (sims) and the science (the final theory) evolve on different clocks. **Decision:** ORRERY is its own repo/folder (`C:\ORRERY`), public on GitHub, versioned independently. **Rationale:** It is a *reusable general instrument*; coupling it into the theory repo would entangle two lifecycles and defeat the compounding. The science depends on ORRERY only through tool contracts. **Alternatives rejected:** live inside the theory repo (entangles versioning); a monorepo (premature). **Consequences:** the science imports nothing from ORRERY; it shells out to tool `.exe`s and reads declared output.

## D-002 · `someone` is the first tool and the template
Date: 2026-07-05 · Status: Active
**Context:** Need one tool built to the *full* standard as the exemplar all others copy. **Decision:** Build `someone` first (generalize `dak_evolution_complex.cu`). **Rationale:** it is the crown (the Someone-Criterion made an evolutionary experiment), it already exists in prototype, and an earlier analysis produced a real *wounded* result (honest signal the approach discriminates). Getting one tool perfectly contract-first + golden-gated establishes the pattern. **Alternatives rejected:** `ratchet` first (simpler but less load-bearing); `lens` first (highest risk). **Consequences:** later tools copy `someone`'s contract/golden/MODULE shape.

## D-003 · Spec-and-contracts first, before any tool code
Date: 2026-07-05 · Status: Active
**Context:** v6 methodology Hour-1 rule: build the durable substrate before code. **Decision:** ARCHITECTURE + contracts + golden harness + BUILD runbook are written before a single kernel. **Rationale:** "the spec is the product"; contracts are the precondition for everything downstream and for replaceability. **Consequences:** the fresh build session's first coding act is `someone` *against a fixed contract*, not a blank file.

## D-004 · RT-cores-as-isomorphic-compute is a parked SPIKE, not a first build
Date: 2026-07-05 · Status: Active
**Context:** The Carmack-style "physics IS ray tracing" idea is high-wow, high-risk; RAYFORMER's ADR-007 retired the analogous high-D claim by measurement. **Decision:** park it as a named backlog SPIKE with a pre-registered kill (build honest baseline, measure, retire if it doesn't beat it). **Rationale:** the physics here is intrinsically low-D (geodesics, light-cones) so it *might* win where high-D lost — but belief waits on measurement. **Consequences:** `lens` starts as 3D visualization only; the compute-spike is a discrete future experiment.

## D-005 · C/C++/CUDA default; Python only where justified
Date: 2026-07-05 · Status: Active
**Context:** Operator preference + performance/scale needs. **Decision:** compute-heavy/scaled tools are C++/CUDA `.exe`; Python only for symbolic/accounting/glue (ARCHITECTURE §7). Every Python tool records its justification here. **Rationale:** CUDA/C++ gives the scale that makes tool-calls beat mental guesses; Python is right only where it's bookkeeping. **Consequences:** `posit` is Python (parsimony accounting — justified: symbolic, no compute); all sims are CUDA.

## D-006 · Output is JSON-to-stdout, schema-checked; CSV for bulk time-series
Date: 2026-07-05 · Status: Active
**Decision:** every tool emits one JSON object (matching `contracts/<tool>.schema.json`) on stdout with `--json`; large per-step series go to a `--csv PATH`. **Rationale:** machine-parseable, schema-validatable, greppable; scientists parse only the declared schema. **Consequences:** the golden hashes the canonical-serialized declared fields (excluding timing/notes).

## D-007 · CUDA target sm_89, MSVC 2022 host
Date: 2026-07-05 · Status: Active
**Decision:** `-arch=sm_89` (RTX 4070 Ti SUPER); compile through `vcvars64.bat` + `nvcc`. **Rationale:** the machine's actual GPU/toolchain (verified). **Consequences:** `BUILD.md` documents the exact incantation; cross-arch determinism tolerance noted per tool.

## D-008 · Reproducibility via `result.lock` per cited experiment
Date: 2026-07-05 · Status: Active
**Decision:** any result the science cites ships a `result.lock` (tool version + binary hash, GPU arch, CUDA version, seeds, params). **Rationale:** the `marrow.lock` pattern; "how was this produced?" must have an answer. **Consequences:** `runs/` holds locks alongside outputs.
