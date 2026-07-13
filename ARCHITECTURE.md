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
11. **Every CUDA tool names its oracle** — the independent CPU/analytic reference its correctness is judged against — in §8 and its MODULE.md. A gate failure against the oracle sets run-state **SUSPECT**, never a silent fallback. *(RAYFORMER RF-ORACLE / ADR-007 lesson. Adopted 2026-07-09 with D-020/D-021; oracle column in §8. `someone`'s fp64 CPU replica is named as OWED pending D-025.)*
12. **Traceability:** no numeric token in any science-facing output is citable unless it traces to a verified tool call; every surface response embeds the `result.lock` hash. *(textverse calculator-binding rule. Adopted 2026-07-09. Scope note: for the bare exe, the lock references the envelope hash — the existing D-008/Invariant-9 mechanism, envelopes unchanged; MCP/API surfaces embed the lock hash in-band when built, D-022.)*
13. **Unbiased acceleration:** every performance path (mixed precision, importance sampling, batching, graphs) ships with a proof or paired-oracle test that the declared quantity's expectation is unchanged within a declared tolerance — or it does not ship. *(Buddhabrot v4 exact-weighting rule. Adopted 2026-07-09; the fast-math ban in D-021 and the fixed-point quantization note in `lib/reduce.cuh` are its first enforcements.)*
14. **Frozen external data:** any external dataset a tool consumes (e.g. the DESI chain) is frozen into the repo with sha256 + provenance note; the golden covers the hash. No live fetches in declared paths. *(Adopted 2026-07-09; no current tool consumes external data — binds `everpresent` and later.)*

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

| Tool | Lang | What it measures | Seeded from | Oracle (I-11) | Status |
|---|---|---|---|---|---|
| **someone** | C++/CUDA | Evolutionary Someone-Criterion: encoder/bottleneck/decoder/predictor agents (C2 gap = `pureGap`), viability/stakes/death (C3), zombie-vs-normal ablation; sweep k → is the band an *evolved* optimum? | `dak_evolution_complex.cu` | fp64 CPU replica at a tiny config — **BUILT** (`--oracle`, D-025; fp32 kernels vs an independent fp64 CPU replica agree ~1.2e-7 vs a 1e-4 gate) | **DONE v1.2.0** (golden `aa5b731d`, det. 3×, cold two-pass verified; the template; fp64 oracle added, golden byte-identical) |
| **ratchet** | C++/CUDA | Branching / phase transition; the (1−p)ρ=p critical point at billions of trials | `criticality_cuda.cu`, `toy_rr_frontier_ratchet.py` | Galton–Watson analytic `q*^R` (in-tool gate G-THEORY-MISMATCH; MC↔analytic 0.06%) | **DONE v1.0.0** (golden `91fce3c4`, cold two-pass verified; D-015) |
| **algebra** | C++/CUDA (cuSOLVER) | Crossed-product entropy-from-observer (F16); the receipted c=1 divergence (Part A) vs cutoff | `toy_cp_divergence.py` | Calabrese–Cardy c=1 analytic + the receipt's S(64)/S(128) values (selftest-asserted) | **DONE v1.0.0** (golden `1526918f`, cold two-pass verified; Part-A scoped, D-018) |
| **posit** | Python | Parsimony auditor (Q3); physics-layer vs overlay posit budget | `posit_counter.py` | hand-checked audit cases (selftest, 12 checks) | **DONE v1.0.0** (golden `7a22dd22`, cold two-pass verified; the Python-is-right tool, D-005) |
| **mcts** | C++/CUDA | Generic MCTS over a supplied action/parameter space; the search engine the science calls | new | derived-target known optimum (golden asserts all 1024 trees find it) | **DONE v1.0.0** (golden `6c596a53`, cold two-pass verified; root-parallel UCT) |
| **autotune** | Python (glue) | Sweep any tool's params; find the band / basin-of-someone; pre-registered targets | new | built-in analytic objectives (`peak`/`threshold`, known optima) | **DONE v1.0.0** (golden `c79002f2`, cold two-pass verified; drives the built tools, D-019) |
| **mcp** | Python | The MCP surface (D-022): stdio JSON-RPC server exposing the catalogue to LLM callers — list/describe-verbatim/run/sweep/status, every run response carrying the I-12 declared+artifact hashes | new (D-022) | canned-posit end-to-end chain vs posit's frozen golden (in the golden itself) | **DONE v1.0.0** (golden `174ec02d`, 3× byte-identical; live-smoked driving a real ratchet GPU run) |
| **orreryd** | C++20 (host) | The job daemon (D-022 v0): file-spool serializer — one GPU tenant FIFO, per-job wall-clock budgets (timeout→kill), `.stop`/`.DONE` sentinels, atomic status page; I-12 hashes on every record | new (D-022; buddhabrot unattended pattern) | canned 3-job drain (posit chain + error containment + `.DONE`) in the golden itself | **DONE v0.1.0** (golden `86f133bb`, 3× byte-identical; live-smoked: real GPU drain + 2s budget kill) |
| **shoot** | C++ (host, fp64) | ODE-shooting **eigenvalue** solver (TinyUniverse R-6): the 1D Schrödinger/Sturm–Liouville spectrum via shooting; potentials `harmonic` (E_j=j+½) + `square` (E_j=(j+1)²π²/2L²) | new (D-032) | exact analytic spectra (per-level, in-tool) | **DONE v1.0.0** (golden `9625b268`, det. 3× + arch-portable — no transcendentals; cold two-pass CONFORMANT) |
| **orrery** | Python | The ergonomic **CLI over the catalogue** (TinyUniverse R-1/R-2/R-3/R-5): `list`/`describe`/`run`/`sweep` + one-shot receipt-`verify` + `mcp-register` + a content-addressed run `cache`; reuses the `mcp` primitives so the I-12 hash chain is inherited | new (D-033) | posit-chain self-check (narrow coupling like `mcp`; re-baselines with posit) | **DONE v1.1.0** (golden `43977185`, det. 3×; R-3 verifier both ways; R-5 run cache additive-safe; cold two-pass CONFORMANT — v1.0.0 core 11/11 + v1.1.0 cache 8/8) |
| **lens** | CUDA/OptiX | RT-core silhouette render + oracle-gated projected cross-section of physics geometry (orthographic; `sphere` πR², `bhshadow` Schwarzschild capture 27π M² at b_crit=√27 M); honestly scoped per D-004; `bhshadow-geo` DERIVES the shadow via null-geodesic integration (v1.1.0, D-031) | `RAYFORMER/render.cu` (OptiX pipeline) | exact analytic cross-section (πR² / 27π M²); RT↔baseline I-13 paired-oracle; geodesic-derived shadow = silhouette = OptiX (triple-validated) | **DONE v1.1.0** (goldens `11e545b8` silhouette + `914399` geodesic; det. 3× on sm_89+OptiX 9.1.0+drv 610.47; compute-SPIKE RUN+RETIRED D-030; cold two-pass CONFORMANT v1.0.0 & v1.1.0) |
| **trace-born** | C++/CUDA (cuSOLVER) | Born-from-redundancy (F15 mechanical core; order-book **C-TRACE**): does the normalized-trace weight over a redundancy-defined branch projection reproduce Born \|c_i\|² in a **decohering** finite S⊗E^R model? brute-force full-state + partial trace; STEP-A envariance + STEP-B fine-graining witnesses; partial-decoherence negative control. The undischarged premise (D-BORN) is labeled + excluded, §III-sealed | `toy_a1_born_finegrain.py` (Zurek envariance); extends `algebra` cuSOLVER (Dsyevd→Zheevd) | analytic Gram overlap `Σ\|c_a\|²(G_ia)^{2R}` (brute==analytic → `oracle_max_dev`; SUSPECT ⇒ exit 2) + the receipt's 0.4/0.6 | **DONE v1.0.0** (golden `d4e3bf04`, det. 3×; both control gates fire; **cold two-pass CONFORMANT 11/11 — scope honest, no overclaim**; D-026 lineage) |

Shared infrastructure (not tools): **`lib/` — liborrery** (D-020), the invariant core every tool includes (envelope/RNG/reductions/regime/ckpt), KAT-selftested (42 checks), verbatim-extracted from `someone`; consumer migrations are gated on bit-identical golden reproduction.

**Parked SPIKE (pre-registered kill), now homed in `lens`:** *RT-cores as isomorphic compute* for the intrinsically-low-D physics (curved geodesics, light-cones) — the Carmack move that might win *here* where it lost at high-D attention. `lens` v1.0.0 shipped the honest *render* arm (RT's ADR-007 home — a deterministic, exact-oracle-gated silhouette cross-section) with the OptiX RT path cross-checked against an analytic baseline (I-13). The compute-speedup question — *does RT-accelerated curved-geodesic integration beat the fp64 CUDA baseline?* — is **pre-registered in `contracts/lens.contract.md` with a ≥1.5× kill criterion** (build honest baseline, measure, retire if it doesn't beat it). Measured later, never asserted.

## 9 · Verification model (compile-as-proof)

`harness/` holds the CI: **compile every tool → run every `--selftest` → run every `--golden` → red/green.** This is ASTRA-7's test-suite-as-proof generalized to the whole instrument. Where a physics *throat* (the theory's falsifiers: BMV, w=−1, ratchet-rate, band-ordering) can be expressed as a tool gate, it becomes a CI gate. A claim that cannot compile or fails its golden is not in the instrument.

Two-pass verification (Ch. 16) is mandatory for any tool whose result the science will *cite*: a fresh cold-context agent re-derives the contract-conformance and re-runs the golden with no memory of the build conversation. RAYFORMER's lesson is the whole reason.

## 10 · Tech decisions (ADRs in `DECISIONS.md`)

- **CUDA 13.1, `-arch=sm_89`** (RTX 4070 Ti SUPER, 16 GB). Compile via MSVC 2022 host (vcvars64) — see `BUILD.md`.
- **Single-file `.cu` per tool where possible; CMake for multi-file** (pattern from `C:\buddhabrot-main`, `C:\ASTRA-7`).
- **Shared invariant core: `lib/` (liborrery, D-020)** — envelope/RNG/reductions extracted verbatim from the template, KAT-gated; tools compile `../../lib/envelope.cpp` alongside. **Repo CMake preset (D-021):** fat binary (sm_89+sm_90 SASS, compute_120 PTX), static cudart + static MSVC runtime, **fast-math banned**; goldens stay hardware-pinned to sm_89 (re-baseline = operator-signed NOTE.md entry).
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
