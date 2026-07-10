# ORRERY

**A headless, contract-bounded, deterministic simulation instrument for a final theory of everything.**

> An orrery is a built mechanical model of the cosmos: you turn the crank and watch the model move. This ORRERY is the software equivalent — a catalogue of prebuilt, headless simulations that a reasoning agent (or a scientist) *calls as tools* to put the claims of the theory to a measured, reproducible test, instead of asserting them.

```
someone.exe --pop 200 --k 64 --seed 7 --json
```

**Status:** founded 2026-07-05 · **eight tools built, golden-frozen, and each independently cold-two-pass verified**; the compile-as-verification harness is green across CUDA, C++, *and* Python. Wave 0 (2026-07-09) extracted the invariant core into **`lib/` (liborrery)** — all four CUDA tools were migrated onto it with their goldens reproduced **bit-identically** ("the code is ephemeral," exercised for real) — and added the two **surfaces**: an MCP server (`mcp`) so LLM callers can drive the catalogue, and a job daemon (`orreryd`) for unattended GPU campaigns. Only `lens` remains (a deliberately parked, pre-registered SPIKE). Every tool went contract-first → golden → two-pass; every citable result is reproducible from its `result.lock`.

The instrument that serves the theory at **[finaltheoryofeverything.org](https://finaltheoryofeverything.org)** — *The Unfinished Mirror*. The live catalogue page: **[finaltheoryofeverything.org/lab](https://finaltheoryofeverything.org/lab)** (generated from this repo's registry via the `mcp` surface).

---

## The idea: two systems, one seam

ORRERY is the **instrument**. The *final-theory project* — [THE UNFINISHED MIRROR](https://finaltheoryofeverything.org) and its research canon — is the **science** that uses it. They are two systems on two clocks, coupled through exactly one thing: **the tool contract.**

A scientist agent does not reason about physics from memory, and it does not write simulation code on the fly. It **calls a prebuilt headless executable with parameters and reads structured, deterministic results.** The instrument does the physics and the math; the science does the interpretation. The science never sees a CUDA kernel — only a tool's *contract* and its *golden*.

```
  THE SCIENCE  (final-theory project)          THE INSTRUMENT  (this repo)
  --------------------------------             --------------------------
  reasons, derives, interprets                 simulates, measures, renders
  calls tools  ------------------->  tool CONTRACT (CLI + I/O schema + exit code + determinism)
  reads structured results  <------  deterministic JSON/CSV out, exit 0/1/2
  never sees a kernel                          internals free to change under the contract
```

Break that seam and you break the compounding — which is the whole point:

- **Claims get tested, not asserted.** Anything the theory says that *can* be simulated is checked by a real, reproducible run. (The anti-confabulation half of the science's own method, in silicon.)
- **Tools compound.** A more capable agent in 2028 can rewrite a tool's internals and *not one prior experiment breaks*, because the science only ever depended on the contract and the golden, never the code.
- **Scale is a tool call.** A subagent gets billions-of-trials results by invoking an `.exe`, not by writing CUDA it cannot verify.

## The doctrine

> **The spec is the product. The contract is sacred. The golden is load-bearing. The code is ephemeral.**

You never work on "the instrument." You work on **one tool against its fixed contract.** A tool is a module: it fits in a reasoning budget, carries its own `MODULE.md`, its own semver'd contract, and its own frozen golden, and can be rebuilt or replaced independently. If a new implementation honors the contract and reproduces the golden, it is a drop-in replacement.

Corollary: **discipline tightens as models get more capable**, because confident-wrong output scales with capability. More capable future builders need *more* golden-gating and two-pass verification, not less. (The cautionary tale is RAYFORMER — a gorgeous "attention *is* ray tracing, faster" claim that only *measurement* retired. Every isomorphism/speedup claim here is spike-de-risked against an honest baseline before it is believed.)

## The universal tool contract

Every tool, whatever it simulates, presents the same envelope, so the science can call any of them the same way:

```
<tool>.exe  [--param VALUE ...]  --seed N  [--json | --csv PATH]  [--selftest]  [--golden]

stdout (--json): one JSON object matching contracts/<tool>.schema.json
  { "tool":"someone", "version":"1.1.0", "seed":7, "params":{...},
    "result":{ ...declared fields... }, "verdict":"pass|fail", "gates":[...], "notes":"..." }

exit code : 0 pass · 1 a declared gate fired (a real negative result) · 2 error
--selftest : run the internal battery, exit 0/1     (the compile-as-verification unit)
--golden   : run the frozen golden params, hash the declared output, exit 0/1 vs record
determinism: (params, seed) -> byte-identical declared output
```

## The catalogue

Seeded from existing GPU/engineering engines (the `dak_evolution`, `criticality`, RAYFORMER, and buddhabrot work) and the theory's research receipts. Build order lives in [`TASKLIST.md`](TASKLIST.md).

| Tool | Lang | What it measures | Status |
|---|---|---|---|
| **someone** | CUDA | Evolutionary Someone-Criterion: self-modeling agents (encoder → bottleneck → decoder → predictor, a `pureGap` = the gap between the world and the agent's model of it) vs gapless "zombies", under survival stakes — *does the gap earn its keep?* The template every later tool copies. | **DONE** (v1.1.1, golden `aa5b731d`, cold two-pass ✓) |
| **ratchet** | CUDA | Branching / phase transition; the critical `(1−p)ρ = p` point at billions of trials (MC↔analytic to 0.06%) | **DONE** (v1.0.1, golden `91fce3c4`, cold two-pass ✓) |
| **algebra** | CUDA (cuSOLVER) | Crossed-product entropy-from-an-observer; the receipted `c=1` block-entropy divergence vs Calabrese–Cardy, plus a massive `c≈0` control (deliberately scoped — a value the theory itself withdrew is excluded by contract) | **DONE** (v1.0.1, golden `1526918f`, cold two-pass ✓) |
| **posit** | Python | Parsimony auditor — physics-layer vs overlay posit budget (the runnable Occam check) | **DONE** (v1.0.0, golden `7a22dd22`, cold two-pass ✓) |
| **mcts** | CUDA | Generic root-parallel Monte-Carlo Tree Search over a supplied action/parameter space | **DONE** (v1.0.0, golden `6c596a53`, cold two-pass ✓) |
| **autotune** | Python (glue) | Sweep any tool's parameters against a **pre-registered** target; find the band / the basin (it located ratchet's critical point blind: `ρ_c = 0.2581` vs analytic `0.25`) | **DONE** (v1.0.0, golden `c79002f2`, cold two-pass ✓) |
| **mcp** | Python | **Surface #1:** stdio JSON-RPC MCP server — LLM callers list, inspect (contracts served verbatim), and run the catalogue; every response embeds the declared-output hash | **DONE** (v1.0.0, golden `174ec02d`, cold two-pass ✓) |
| **orreryd** | C++20 | **Surface #2:** file-spool job daemon — one GPU tenant, FIFO, per-job wall-clock budgets, `.stop`/`.DONE` sentinels, a status page; unattended campaigns | **DONE** (v0.1.0, golden `86f133bb`, cold two-pass ✓) |
| **lens** | CUDA/OptiX | RT-core render of the physics geometry (honestly scoped) | backlog (parked SPIKE) |

**The shared core (`lib/`, liborrery):** the universal envelope (canonical serialization + BLAKE2b golden hashing), the stateless counter-RNG kit, and the deterministic reductions — extracted *verbatim* from the template and pinned by a 42-check KAT selftest (including separately-pinned host/device RNG bit patterns: MSVC and CUDA libm really do diverge by 1 ULP, and the pin fires before that could ever silently break a golden). All four CUDA tools build against it; each migration was gated on **bit-identical** golden reproduction.

**Parked spike (pre-registered kill):** *RT-cores as isomorphic compute* for the intrinsically low-dimensional physics (geodesics, light-cones) — the Carmack move that might win *here* where it lost at high-dimensional attention. Belief waits on an honest baseline plus measurement.

## Verify it yourself

Every claim above is checkable from a clone (GPU tools need CUDA + sm_89-class hardware; `posit`/`autotune`/`mcp` run anywhere Python does):

```
python tools/posit/posit.py --selftest      # any machine: the internal battery, exit 0
python tools/posit/posit.py --golden        # recompute the frozen golden hash, exit 0
python harness/verify.py                    # the whole instrument: build -> selftest -> golden, every tool
python tools/mcp/mcp.py --once "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"
```

Independent verification verdicts live in [`runs/`](runs/) (`*_twopass_verify.md`) — each written by a cold-context agent that never read the tool's source.

## What this is — and what it is NOT

- It tests **structure**, never **acquaintance.** A `someone` run can show whether a self-model confers *fitness*; it says **nothing** about whether the agent *feels*. That question is sealed off by design — raw GPU power must not seduce anyone across that line.
- It is **not a proof of the theory.** Tools measure mechanisms; the theory's interpretation of them lives in the science, not here.
- It is **not a place to write code on the fly.** It is a place you *call*.

## Repository layout

```
ARCHITECTURE.md      the spec / the product (read this first; §5 = the 14 invariants)
CLAUDE.md            the build harness + operating manual for a build session
DECISIONS.md         the ADR log (D-001 …), append-only
AUTONOMY_CHARTER.md  what a build session may and may not do
BUILD.md             the exact compile incantations + the determinism checklist
TASKLIST.md          the ordered build plan (Phases 0–5 complete; Wave 1 next)
RUN_STATE.md         current state + the next concrete action
docs/                adopted proposals (the wave plan that opened Phases 5–8)
contracts/           the sacred tool contracts (.md) + machine-checkable schemas (.json)
lib/                 liborrery — the KAT-pinned invariant core every tool builds on
tools/<tool>/        tool source (.cu / .cpp / .py) + its MODULE.md
goldens/<tool>/      the frozen (params -> hash) goldens
runs/                result.locks + independent cold-two-pass verification verdicts
harness/             compile-as-verification (build all -> selftest all -> golden all)
CMakePresets.json    fat-binary preset (sm_89+sm_90 SASS, PTX for the future; fast-math banned)
```

## Building

CUDA tools require an NVIDIA GPU and CUDA. This machine targets **CUDA 13.1, `-arch=sm_89`** (RTX 4070 Ti SUPER, 16 GB), compiled through the **MSVC 2022** host toolchain; tools build with one command each (`nvcc … <tool>.cu ../../lib/envelope.cpp …` — the exact fenced incantation lives in each tool's `MODULE.md`, and the determinism checklist in [`BUILD.md`](BUILD.md)). A repo-level CMake preset builds fat binaries (sm_89 + sm_90 SASS, embedded PTX for future GPUs); **fast-math is banned project-wide** — an accelerated path ships with a paired-oracle error bound or it does not ship. Goldens are hardware-pinned to sm_89; re-baselining on other hardware is an operator-signed act. Build artifacts (`*.exe`, `*.obj`, …) are intentionally untracked — the code is ephemeral; source, contract, and golden are load-bearing.

---

*Owner: Bo Chen. Built with Claude (Opus 4 founded it; Fable 5 built Wave 0 and the surfaces). The instrument for [finaltheoryofeverything.org](https://finaltheoryofeverything.org) · live catalogue at [/lab](https://finaltheoryofeverything.org/lab). The spec is the product; build the contracts, gate the goldens, and let the tools compound.*
