# PROPOSAL — liborrery · orreryd · surfaces · scale · the v5 order book

**Date:** 2026-07-09 · **Status: PROPOSED — operator-gated.** Nothing in this document changes any frozen contract, golden, or invariant until adopted per §0.
**Author:** Claude Fable 5, at Bo Chen's commission (authored from the Websites session that shipped essay v5; full canon read + two-agent survey of `C:\Users\user\Desktop\DSA` CUDA corpus, `C:\RAYFORMER`, `C:\ASTRA-7` (+ textverse, visualizers), `C:\buddhabrot-main`, `C:\Buddhabrot_CUDA`).
**Scope:** the architecture evolution of ORRERY from a folder of verified exes into an institution: shared core, daemon + LLM surfaces, scale doctrine, rigor upgrades, and the build queue for the eleven gears the science (essay v5, THE INSTRUMENT section) has ordered.

---

## 0 · Adoption protocol (rigor mechanics)

1. Each numbered section below is a **draft ADR** (D-020…D-026). Adopt one by copying it into `DECISIONS.md` with `Status: Active`, **in the same commit as the first code it governs** (Invariant 10). Un-adopted sections have no force.
2. Every proposed change is classed:
   - **[ADDITIVE]** — no existing contract/golden touched; MINOR-at-most semver anywhere.
   - **[BEHAVIOR-NEUTRAL]** — implementation swap; the acceptance test IS bit-identical reproduction of the existing golden ("the code is ephemeral" exercised for real).
   - **[GOLDEN-SUPERSEDING]** — declared output changes; requires two-pass + operator sign-off (per D-014's own precedent).
   - **[NEW-TOOL]** — full build loop (contract-first → MODULE → implement → golden → cold two-pass → register).
3. Proposed **new invariants** (adopt into ARCHITECTURE §5 if their ADRs are adopted):
   - **I-11 (oracle):** every CUDA tool names its oracle — the independent CPU/analytic reference its correctness is judged against — in ARCHITECTURE §8 and its MODULE.md. A gate failure against the oracle sets run-state **SUSPECT**, never a silent fallback. *(RAYFORMER RF-ORACLE / ADR-007 lesson.)*
   - **I-12 (traceability):** no numeric token in any science-facing output is citable unless it traces to a verified tool call; every surface (CLI/MCP/API) response embeds the `result.lock` hash. *(textverse calculator-binding rule.)*
   - **I-13 (unbiased acceleration):** every performance path (mixed precision, importance sampling, batching, graphs) ships with a proof or paired-oracle test that the declared quantity's expectation is unchanged within a declared tolerance — or it does not ship. *(Buddhabrot v4 exact-weighting rule.)*
   - **I-14 (frozen external data):** any external dataset a tool consumes (e.g. the DESI chain) is frozen into the repo with sha256 + provenance note; the golden covers the hash. No live fetches in declared paths.

---

## D-020 (draft) · `liborrery` — extract the invariant core as a static C++/CUDA library

**Class: [BEHAVIOR-NEUTRAL] migrations after an [ADDITIVE] introduction.**
**Context:** every tool re-implements the envelope (canonical JSON, blake2b, CLI spine, exit semantics), the D-012 RNG kit, and the deterministic reductions by copying `someone`'s shape. Convention is not enforcement; the corpus survey found the exact races (criticality's `idx % (N/4)` curand aliasing; DAK's shared-curandState write-back) that D-012 exists to forbid — they must become *unwritable*, not just forbidden.
**Decision:** create `lib/` (static library `orrery.lib` + headers), containing exactly and only:
- `envelope.h/.cpp` — canonical serializer (fixed key order, `%.6f`), blake2b (KAT-gated), `--selftest/--golden/--json/--csv` spine, exit 0/1/2, `result.lock` writer. Hash domain unchanged (D-013).
- `rng.cuh` — splitmix64 purpose-keying; stateless counter Gaussian (splitmix64→Box–Muller) keyed `(seed, replica, entity, step)`; host mt19937_64 helpers with fixed draw-order idioms. (D-012 as code.)
- `reduce.cuh` — fixed-order tree reduction; warp `__shfl_xor_sync` hierarchy; **uint64/fixed-point atomic accumulators** (order-invariant scatter, the nebulabrot pattern); **sort-then-gather** (atomic histogram → warp prefix scan → contiguous ordered runs, the YOSO pattern) as the sanctioned replacement wherever float-atomic scatter would appear.
- `regime.h` — a **derived-only** composable regime bitmask: computed from state, never settable, stamped into every result envelope. *(ASTRA-7 pattern.)*
- `ckpt.h` — raw device-state dump + `.sha256` sidecar + `--resume-from`; **no derived artifact without the raw dump first** (buddhabrot B7).
**Acceptance (the whole point):** migrate `someone`, `ratchet`, `algebra`, `mcts` one at a time; each migration must reproduce that tool's existing golden **bit-for-bit**. A migration that changes any golden is rejected. This is the strongest possible in-vivo test of "the code is ephemeral."
**Rationale:** new tools start at ~200 lines instead of ~1000; the doctrine becomes a type system; wave-1/2 tools inherit correctness instead of copying it.
**Alternatives rejected:** header-only copy-paste blessed snippets (drift returns); a Rust core (splits the toolchain against D-005 for no measured gain).
**Consequences:** `lib/` gets its own MODULE.md + KAT selftest; contracts and goldens of migrated tools are untouched by definition.

## D-021 (draft) · Build system — CMake preset, fat binary, fast-math ban

**Class: [ADDITIVE]** (BUILD.md gains a preset; the bare `nvcc` single-file path remains supported).
**Decision:** repo-level `CMakePresets.json`: `CMAKE_CUDA_ARCHITECTURES 89;90;120` **+ embedded PTX** (fat binary, future-GPU JIT), static cudart + static MSVC runtime (single-exe deployment — the ASTRA_VISUALIZER_02 recipe), host flags via `-Xcompiler=`, CUDA C++17, separable compilation where multi-file.
**Fast-math is OFF by default and stays off.** Any kernel that wants it must opt in per-kernel, with its own golden and an I-13 paired-oracle bound — ASTRA ships `--use_fast_math` for visuals; a scientific instrument inverts that default.
**Golden portability:** goldens remain **hardware-pinned** (sm_89). Adopt ASTRA's re-baseline protocol: a golden re-baselined on new hardware requires an operator-signed NOTE.md entry recording old/new hash + arch + reason. Cross-arch tolerance stays documented per tool (§11).

## D-022 (draft) · `orreryd` + three surfaces — how LLMs call the instrument

**Class: [ADDITIVE] · [NEW-TOOL]×2** (`orreryd`, `mcp`). The sacred CLI exes remain the contract of record; the daemon and surfaces are *callers* of them, never replacements.
**Decision:**
- **`orreryd`** (C++20, single toolchain): a long-lived host daemon owning GPU tenancy — a job queue serializing compute tenants; **two prioritized CUDA streams** (compute free-runs low-priority; telemetry/status high-priority; zero device-wide syncs in the monitor path — Buddhabrot v4's never-block loop); per-launch wall-clock budgets (Windows TDR discipline, buddhabrot B11); watchdog sentinels (`.stop`/`.DONE`) + a served `status.html` for unattended runs.
- **MCP server v1** (`tools/mcp/mcp.py`, **Python — D-005-justified**: pure IPC bookkeeping, no compute; port to C++ later without touching any contract): stdio JSON-RPC exposing `list_tools`, `describe_contract` (serves `contracts/<tool>.schema.json` **verbatim** — they already exist and are machine-checkable), `run_tool` (spawns the sacred exe, returns the envelope + lock hash), `get_run`, `sweep` (drives `autotune`), `golden_status` (runs the harness). Responses deterministic modulo run-ids/timestamps, which are declared non-declared.
- **HTTP API v2** (later, behind `orreryd`): localhost REST `/run`, `/status/:id`, `/result/:id`; the `/lab` page and remote fleets read the same registry.
**Integrity (I-12):** every surface response embeds the `result.lock` hash; the science's citation chain becomes machine-checkable end-to-end.
**Rigor:** the MCP server is itself contract-bounded (`contracts/mcp.contract.md` v1.0.0 + schema), with `--selftest` (KATs + schema round-trip) and a golden (a canned `posit` run — fast, exact, no GPU).
**Alternatives rejected:** MCP wrapping in-process lib calls (couples surface to internals; subprocess of the sacred exe keeps the split of §2 absolute); a general multi-tenant GPU scheduler (premature — one queue, one tenant, FIFO).

## D-023 (draft) · Scale doctrine for `someone` (and every heavy tool after it)

Three gated stages, in order:
- **S-A · Ensemble-in-grid [BEHAVIOR-NEUTRAL by design]:** fold replicas into a grid dimension so `--ensemble 24` is one launch. Design constraint: per-replica RNG keying and per-replica aggregation order are *unchanged*, so the declared JSON is bit-identical and the golden survives. Acceptance: golden reproduces; n=24 S5-class sweep wall-clock ÷ ≥10.
- **S-B · CUDA Graph capture [BEHAVIOR-NEUTRAL]:** capture the fixed inner loop (800 steps × fixed launch config — the determinism checklist already mandates fixedness; DAK proved 1000+ sync-free queued launches). Acceptance: golden bit-identical; launch overhead measured before/after in MODULE.md.
- **S-C · fp16/bf16 weight *storage*, fp32 accumulate [ADDITIVE flag, not golden-superseding]:** D-014 measured `someone` bandwidth-bound (~30% of 672 GB/s; weights re-read per agent-step). Rather than supersede the fp32 golden, add `--precision fp16` as a MINOR additive flag with its **own secondary golden**; the default and the primary golden stay fp32. I-13 gate: paired fp32-oracle run at the golden config, rel-L2 ≤ 1e-3 on declared fields, recorded in MODULE.md. Expected ~2× on the bandwidth wall (≈8 min → ≈4 min).
- **S-D · Tensor cores [SPIKE, pre-registered kill]:** batch per-agent matvecs across the population into real GEMMs (200×[256×256] is `mma.sync`/WMMA territory; RAYFORMER has working fp16 tensor-core matmul + refine-to-3e-7 code to harvest). Honest baseline = the S-C kernel; measure; retire if it does not beat it (ADR-007 protocol). Determinism note: fixed-order K-accumulation or hand-rolled WMMA with fixed tiling; cuBLASLt only if pinned to a deterministic algo.
**RT cores:** ADR-007's verdict stands — RT for genuinely-3D work only (`lens`); OptiX via function-table dispatch against the driver DLL with compile-out fallback (Buddhabrot v4 recipe), so the instrument never *requires* the SDK.

## D-024 (draft) · Campaign harness — checkpoints, unattended runs, the cloud rung

**Class: [ADDITIVE]** (library + docs; applies to wave-1/2 tools that run long).
**Decision:** import the buddhabrot campaign doctrine wholesale:
- **B7 rule:** no derived artifact without a raw checkpoint (`cpNNNN` + `.sha256`) and a `--resume-from` path, at a declared cadence; checkpoint overhead ≤5% of run time.
- **Unattended-run harness:** watchdog + `.state/.attempt` files + `.stop`/`.DONE` sentinels + served `status.html` (via `orreryd`).
- **Error taxonomy + testing tiers:** E-class error codes; three tiers (unit ~30 s / integration ~5 min / paid e2e) — **paid GPU time never debugs**.
- **RUNBOOK template** for rented hardware (rent → screen → bootstrap → launch → checkpoint-watch → sync artifacts → verify sha → destroy), for the day `hsmi-stab` or `ratchet-v2` wants H100-class hours.

## D-025 (draft) · Rigor upgrades as CI

**Class: [ADDITIVE].**
- **Oracle column** in ARCHITECTURE §8 (I-11): someone → fp64 CPU replica at tiny config (to be written once, in `lib/oracle/`); ratchet → Galton–Watson analytic (already); algebra → Calabrese–Cardy (already); mcts → exhaustive small landscape (already implicit — make explicit); autotune → built-in objectives (already); posit → hand-checked cases (already).
- **SUSPECT state** in `harness/verify.py`: a gate/oracle failure marks the tool SUSPECT in the report (distinct from RED=won't build/golden-broke); SUSPECT tools are un-citable until cleared.
- **NFR table as hard gates** (harness-checked where measurable): selftest <30 s; MCP round-trip overhead <2 s over bare exe; checkpoint overhead ≤5%; golden-suite budget re-declared per wave (the ~8 min `someone` exception stands per D-014 until S-C lands).
- **Adversarial dual-judge** (`max(0, pro − anti)`, textverse Sculptor pattern) reserved as the evaluation shape for any future LLM-in-the-loop tool — including the theory's dissent pipeline if it ever routes through ORRERY.

## D-026 (draft) · The v5 order book — pre-contracts for the leverage suite

**Class: [NEW-TOOL] × 11.** Contract-first still applies — these are *pre-contracts*: enough for a fresh build session to open the full build loop. Two-pass mandatory for every tool here (all are citable-class). Falsifier links refer to essay v5 §10.

| tool | lang (D-005 test) | measures | oracle / anchor | gates | gun |
|---|---|---|---|---|---|
| **hsmi-stab** | CUDA fp64 (cuSOLVER `Dsyevd`, matrix log/exp in eigenbasis) | finite-D proxy of K1: given a standard pair + candidate inclusion, the half-sidedness violation δ(ε) as the state is deformed by ε; verdict *graceful vs snap* | exact small-D brute force (D=2,3); negative control: a non-hsm inclusion must show O(1) violation | `G-RIGID` (declared threshold/exponent on δ(ε)) | **F-K1** — first by dignity |
| **trace-born** | CUDA (extends `algebra` machinery) | normalized-trace weights over redundancy-defined branch projections vs Born $\|\langle i\|\psi\rangle\|^2$ in a decohering finite model | analytic 2-branch case | `G-BORN-MISMATCH` (declared tol) | C-TRACE |
| **carve** | CUDA + `mcts` (subprocess v1; lib-link later) | factorization basins: candidate frames scored by Pauli-weight concentration of a fixed H; deterministic basin search | **planted scrambler** (known answer) separating "search too weak" from "no preferred factorization" | `G-NO-BASIN` / `G-MULTI-BASIN` (both outcomes declared, both informative) | Layer-2 / P2 |
| **everpresent** | lang decided at build (≥1e5 histories → CUDA; else Python, logged) | stochastic Λ ~ ±1/√V histories → Friedmann → w(z) → log-likelihood ratio Λ-A vs Λ-B against the **frozen, hashed** DESI DR2 chain (I-14) | ΛCDM limit reproduces analytic distances | `G-FIT-FAIL` | **F-Λ** |
| **ratchet-v2** | CUDA (uint64 occupation counters) | spatial 1+1D absorbing-state inscription: β, ν, z by finite-size scaling | DP anchors β≈0.276486, z≈1.5807 | `G-UNIVERSALITY` (DP within declared CI, or declared-distinct) | F-BATTERY (ratchet plank) |
| **clifford/mipt** | C++ bit-packed stabilizer (CHP), GPU if scale demands | measurement-induced transition: p_c + exponents in monitored Clifford circuits | published critical rates (anchor cited in contract) | `G-CLASS-MISMATCH` | §6 threshold plank |
| **fork** | Python (grid evaluation of closed forms — justify in ADR) | Oppenheim decoherence-vs-diffusion exclusion map vs experimental bounds | published tradeoff inequality endpoints | `G-EXCLUDED` | **F-BMV** barrel 2 |
| **prequent** | Python (symbolic log-loss bookkeeping) | prequential log-loss divergence, ordered vs fluctuation hypotheses | closed-form toy streams | `G-DIVERGENCE-SIGN` | §2 Boltzmann kill |
| **someone-v2** | CUDA (extends `someone` post S-A/S-B) | variable k with metabolic price c(k); can selection buy the gap away? vs matched feed-forward null | `someone` v1.1.0 at c=0 must reproduce | `G-GAP-CLOSABLE` | §7 genesis |
| **modfluc** | CUDA (free-boson chain machinery from `algebra`) | ⟨ΔK²⟩ vs ⟨K⟩ across diamond sizes; the seam relation | CFT vacuum capacity=entropy known cases | `G-SEAM` | F-SEAM |
| **algebra v1.1** | CUDA | the fixed-site relative-entropy refit (the withdrawn Part-B, done right per D-018's deferral) | cutoff-stability itself is the test | `G-CUTOFF-RUN` | §5 entropy-gauge |

## TASKLIST addendum (proposed Phases 5–8)

- **Phase 5 — Infrastructure (Wave 0):** [ ] `lib/` per D-020 with KAT selftest → [ ] migrate ratchet (smallest golden) → mcts → algebra → someone, each bit-identical → [ ] CMake preset (D-021) → [ ] `mcp` v1.0.0 full build loop (D-022) → [ ] `orreryd` v0 (queue + budgets + status page) → [ ] Phase-4 publish unblocked: `/lab` page reads the registry (site builder lives in `C:\Websites\finaltheoryofeverything.org\`).
- **Phase 6 — Wave 1 (the make-or-break physics):** [ ] `hsmi-stab` → [ ] `trace-born` → [ ] `carve`. Each: full loop, oracle named, two-pass, science-handback memo (the `someone` S5 pattern).
- **Phase 7 — Wave 2:** [ ] `ratchet-v2` → [ ] `clifford/mipt` → [ ] `everpresent` (I-14 frozen data) → [ ] `someone-v2` → [ ] `modfluc` → [ ] `fork` → [ ] `prequent` → [ ] `algebra` v1.1.
- **Phase 8 — Scale (as needed, gated by demand):** [ ] `someone` S-C fp16 flag → [ ] S-D tensor-core SPIKE (pre-registered kill) → [ ] campaign harness (D-024) → [ ] cloud RUNBOOK dry-run.

**Sequencing rationale:** infrastructure first *because* Wave 1 is citable-class — `hsmi-stab` deserves to be born into the library, the oracle column, and the MCP surface, not retrofitted. `hsmi-stab` precedes everything else in Wave 1 by the theory's own ranking: it is the one falsifier the instrument can run against the theory from inside this machine.

---

*Proposed in full awareness of the canon: Invariants 1–10 untouched; D-005 language rule applied per tool; D-013 hash domain unchanged; D-014's precedent for golden-superseding changes honored by preferring additive flags with secondary goldens. The spec is the product. Adopt by ADR, build one tool right, freeze its golden, let the science call it. Repeat.*
