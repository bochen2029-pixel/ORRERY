# ORRERY — Architecture

### A headless, contract-bounded, deterministic simulation instrument for the final-theory-of-everything project.

**Version:** 0.1.0 (spec-first; no tools built yet) · Founded 2026-07-05 · Owner: Bo Chen · Built with Claude (Opus).

> An orrery is a built mechanical model of the cosmos: you turn the crank and watch the model move. This ORRERY is the software equivalent — a set of prebuilt, headless simulations that a *scientist* (a reasoning agent, or Bo) calls as tools to test the claims of the final theory, replacing mental guesses with measured results.

---

## 1 · System Intent

ORRERY is the **instrument**. The *final-theory-of-everything project* (`THE_UNFINISHED_MIRROR`, the QUALIA_LAB canon, the fleet) is the **science** that uses it. They are two systems on two clocks, coupled through exactly one thing: **tool contracts.**

A scientist agent does not reason about physics from memory and it does not write simulation code on the fly. It **calls a prebuilt headless executable with parameters and reads structured, deterministic results** — `someone.exe --pop 200 --k 64 --seed 7 --json`. The instrument does the physics and math; the science does the interpretation.

The instrument exists so that:
1. Claims of the theory that *can* be simulated are tested by a real, reproducible run, not asserted (the anti-confabulation half of the science's own methodology, in silicon).
2. The tools **compound** — a smarter agent in 2028 reworks a tool's internals without breaking a single experiment the science ran, because the science only ever depended on the tool's *contract* and *golden*, never its implementation.
3. Scale is a tool call — a subagent gets billions-of-trials results by invoking an `.exe`, not by writing CUDA it cannot verify.

**Success = a growing catalogue of contract-stable, golden-gated, headless tools that the science can call for years, plus a compile-as-verification harness that keeps them honest.**

## 2 · The Split (the top-level contract)

```
  THE SCIENCE  (final-theory project)          THE INSTRUMENT  (this repo, ORRERY)
  ────────────────────────────────             ──────────────────────────────────
  reasons, derives, interprets                 simulates, measures, renders
  calls tools ───────────────────► tool CONTRACT (CLI + I/O schema + exit code + determinism)
  reads structured results ◄─────── deterministic JSON/CSV out, exit 0/1/2
  NEVER sees a CUDA kernel                      internals free to change under the contract
```

The science depends on ORRERY **only** through published tool contracts. It must never import ORRERY source, hardcode a kernel assumption, or parse anything but the declared output schema. This is what lets both evolve independently forever. **Break this and you break the compounding.**

## 3 · The Doctrine (from `How_to_Vibe_Code_an_Enterprise_System_v6`, adopted)

> **The spec is the product. The contract is sacred. The golden is load-bearing. The code is ephemeral.**

You do not rewrite ORRERY. You rewrite a **tool**, and if the new implementation honors the contract and reproduces the golden (or supersedes it under review), it is a drop-in replacement. A tool is a **module** in the DonorFlow sense: it fits in a reasoning budget, has its own `MODULE.md`, its own contract, its own golden, and can be built/replaced independently. **You are never working on "the instrument." You are always working on one tool against its fixed contract.**

Corollary (Ch. 28, the load-bearing truth): **discipline tightens as models get more capable, because confident-wrong output scales with capability.** More capable future agents building tools here need *more* golden-gating and two-pass verification, not less. RAYFORMER is the proof — a beautiful "attention IS ray tracing, faster" claim that only *measurement* (ADR-007) retired. Every isomorphism/performance claim in ORRERY is spike-de-risked against an honest baseline before it is believed.

## 4 · Glossary (canonical; forbidden synonyms in parens)

| Term | Definition |
|---|---|
| **Tool** | A headless executable (or, where justified, a Python script) exposing one simulation/measurement behind a sacred CLI contract. (not: "script", "toy", "sim" loosely) |
| **Contract** | The sacred, semver'd interface of a tool: CLI flags + types + ranges, output schema, exit-code semantics, determinism clause. Lives in `contracts/<tool>.contract.md` + a machine-checkable `<tool>.schema.json`. |
| **Golden** | A frozen `(params → output-hash)` record proving a tool's stable behavior. A rewrite must reproduce it or supersede it under review. (not: "test" loosely) |
| **Selftest** | A tool's built-in `--selftest` mode: runs its internal battery, exits 0 (pass) / 1 (fail). The compile-as-verification unit. |
| **Verdict** | A tool's exit code: `0` = pass/expected, `1` = a declared gate fired (a real negative result), `2` = error (bad input, crash). Never conflate 1 and 2. |
| **Determinism clause** | Same params + same seed ⇒ byte-identical declared output. Non-negotiable; enables goldens. |
| **result.lock** | Per-experiment reproducibility manifest: tool version + binary hash, GPU arch, CUDA version, seeds, params. (the `marrow.lock` pattern.) |
| **The Science** | The final-theory project that calls ORRERY. External client. |
| **Scientist agent** | A reasoning agent that *calls* tools. It does not write tool code. |
| **Tool-builder agent** | The only agent that writes/edits tool source, under the full methodology (contract-first, golden-gated, two-pass). |

## 5 · Invariants (system physics — always hold)

1. **Every tool has a sacred contract**: CLI + output schema + exit-code semantics + determinism clause, semver'd, in `contracts/`.
2. **Every tool is deterministic**: same params + seed ⇒ identical declared output. (Wall-clock timings and progress logs are explicitly non-declared and excluded from goldens.)
3. **Every tool is headless**: no window, no GUI, no interactive prompt. Input = CLI/stdin; output = stdout (JSON/CSV) + files + exit code. (Visualizers, if ever built, are a separate opt-in `--render` path writing to a file, never a blocking window.)
4. **Every tool has a golden** in `goldens/<tool>/`, reproduced by CI.
5. **Every tool has `--selftest`** returning 0/1; CI compiles all tools and runs all selftests + goldens.
6. **Contracts change only by semver bump + review.** A breaking output-schema change is a MAJOR bump and requires updating the golden and any science that reads it.
7. **Scientists call, never code.** Only the tool-builder agent touches `tools/` source, and only against a fixed contract.
8. **Default language is C/C++/CUDA. Python only where justified** (§7), with the justification in `DECISIONS.md`.
9. **Every result the science cites carries a `result.lock`.** No lock, not citable.
10. **The Canon and the contract are updated in the same commit as the tool.** Spec never lags code.

## 6 · The Universal Tool Contract (the shape every tool obeys)

Every tool, whatever it simulates, presents the same envelope so the science can call any tool the same way:

```
<tool>.exe  [--param VALUE ...]  --seed N  [--json | --csv PATH]  [--selftest]  [--golden]

stdout (with --json): a single JSON object matching contracts/<tool>.schema.json, e.g.
  { "tool":"someone", "version":"1.2.0", "seed":7, "params":{...},
    "result":{ ...declared fields... }, "verdict":"pass|fail", "notes":"..." }

exit code: 0 pass · 1 declared-gate-fired (real negative result) · 2 error
--selftest : run internal battery, print PASS/FAIL, exit 0/1
--golden   : run the frozen golden params, print the output hash, exit 0/1 vs recorded
determinism: (params, seed) -> identical JSON (excluding the non-declared "notes"/timing)
```

The full template lives in `contracts/README.md`. `someone` (§8) is the exemplar every later tool copies.

## 7 · Language rule (C/C++/CUDA first; Python only where right)

| Use | Language |
|---|---|
| Anything compute-heavy or scaled: Monte-Carlo, evolution, dense linear algebra at size, MCTS, sweeps, rendering | **C++/CUDA** (headless `.exe`) |
| Small *exact* symbolic/accounting work; small exact linear algebra where dim stays tiny; glue/orchestration; fetch/chunk helpers | **Python** (still contract-bounded: CLI in, JSON out, exit code, deterministic) |

The test: *does it need the GPU or C++ speed/scale, or is it symbolic bookkeeping?* Compute → CUDA/C++. Bookkeeping → Python. Every Python tool records *why Python* in `DECISIONS.md`. The `posit_counter` (parsimony accounting) is the canonical Python-is-right case; `someone`/`ratchet`/`algebra`/`lens`/`mcts`/`autotune` are the CUDA cases.

## 8 · Tool Inventory (the catalogue; build order in `TASKLIST.md`)

Seeded from Bo's existing engines (`C:\Users\user\Desktop\DSA\`, `C:\ASTRA-7`, `C:\RAYFORMER`, `C:\buddhabrot-main`) and the QUALIA_LAB receipts.

| Tool | Lang | What it measures | Seeded from | Status |
|---|---|---|---|---|
| **someone** | C++/CUDA | Evolutionary Someone-Criterion: encoder/bottleneck/decoder/predictor agents (C2 gap = `pureGap`), viability/stakes/death (C3), zombie-vs-normal ablation; sweep k → is the band an *evolved* optimum? | `dak_evolution_complex.cu` | **DONE v1.1.0** (golden `aa5b731d`, det. 3×, cold two-pass verified; the template) |
| **ratchet** | C++/CUDA | Branching / phase transition; the (1−p)ρ=p critical point at billions of trials | `criticality_cuda.cu`, `toy_rr_frontier_ratchet.py` | planned |
| **algebra** | C++/CUDA (cuSOLVER) | Crossed-product entropy-from-observer (F16); the receipted c=1 divergence (Part A) vs cutoff | `toy_cp_divergence.py` | **DONE v1.0.0** (golden `1526918f`, cold two-pass verified; Part-A scoped, D-018) |
| **posit** | Python | Parsimony auditor (Q3); physics-layer vs overlay posit budget | `posit_counter.py` | **DONE v1.0.0** (golden `7a22dd22`, cold two-pass verified; the Python-is-right tool, D-005) |
| **mcts** | C++/CUDA | Generic MCTS over a supplied action/parameter space; the search engine the science calls | new | **DONE v1.0.0** (golden `6c596a53`, cold two-pass verified; root-parallel UCT) |
| **autotune** | Python (glue) | Sweep any tool's params; find the band / basin-of-someone; pre-registered targets | new | **DONE v1.0.0** (golden `c79002f2`, cold two-pass verified; drives the built tools, D-019) |
| **lens** | CUDA/OptiX | RT-core render of the physics geometry (3D, honestly scoped per ADR-007) | `RAYFORMER`, buddhabrot | backlog |

**Parked SPIKE (pre-registered kill):** *RT-cores as isomorphic compute* for the intrinsically-low-D physics (geodesics, light-cones) — the Carmack move that might win *here* where it lost at high-D attention. Build an honest baseline, measure, retire if it doesn't beat it (RAYFORMER ADR-007 protocol). Not a first build.

## 9 · Verification model (compile-as-proof)

`harness/` holds the CI: **compile every tool → run every `--selftest` → run every `--golden` → red/green.** This is ASTRA-7's test-suite-as-proof generalized to the whole instrument. Where a physics *throat* (the theory's falsifiers: BMV, w=−1, ratchet-rate, band-ordering) can be expressed as a tool gate, it becomes a CI gate. A claim that cannot compile or fails its golden is not in the instrument.

Two-pass verification (Ch. 16) is mandatory for any tool whose result the science will *cite*: a fresh cold-context agent re-derives the contract-conformance and re-runs the golden with no memory of the build conversation. RAYFORMER's lesson is the whole reason.

## 10 · Tech decisions (ADRs in `DECISIONS.md`)

- **CUDA 13.1, `-arch=sm_89`** (RTX 4070 Ti SUPER, 16 GB). Compile via MSVC 2022 host (vcvars64) — see `BUILD.md`.
- **Single-file `.cu` per tool where possible; CMake for multi-file** (pattern from `C:\buddhabrot-main`, `C:\ASTRA-7`).
- **Output = JSON to stdout** (machine-parseable, schema-checked). CSV for time-series bulk.
- **Determinism via seeded curand + fixed launch config**; document any non-associative-reduction caveats.
- **Repo is standalone** (separate from the theory repo); public on GitHub; a `/lab` page on finaltheoryofeverything.org presents the catalogue + results.

## 11 · Non-functional requirements

- **Reproducibility:** any cited result reconstructable from its `result.lock` + repo at that commit.
- **Cold-start build:** a fresh agent can compile any tool from `BUILD.md` alone in one pass.
- **Selftest speed:** `--selftest` < 30 s per tool (keeps CI fast); full golden suite < 5 min.
- **Contract stability:** no breaking contract change without a MAJOR semver bump and a migration note.
- **Determinism:** bit-identical declared output across runs on the same GPU arch; documented tolerance if cross-arch.

## 12 · What this is NOT

- Not a proof of the theory. Sims test **structure** (mechanisms — the falsifiable physics layer), never **acquaintance** (qualia — §III-sealed). A `someone` run shows whether the gap confers fitness; it never shows the agent *feels*. GPU power must not seduce anyone past that line.
- Not a place for scientists to write code. It is a place they *call*.
- Not coupled to the theory's current state. Tools measure mechanisms; the theory's interpretation of them lives in the science, not here.

*The spec is the product. Build the contracts, gate the goldens, and let the tools compound.*
