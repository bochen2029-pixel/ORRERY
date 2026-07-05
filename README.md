# ORRERY

**A headless, contract-bounded, deterministic simulation instrument for a final theory of everything.**

> An orrery is a built mechanical model of the cosmos: you turn the crank and watch the model move. This ORRERY is the software equivalent — a catalogue of prebuilt, headless simulations that a reasoning agent (or a scientist) *calls as tools* to put the claims of the theory to a measured, reproducible test, instead of asserting them.

```
someone.exe --pop 200 --k 64 --seed 7 --json
```

**Status:** `v0.1.0` · founded 2026-07-05 · **early and actively in progress.** The spec, the tool contracts, the verification model, and the decision log are laid down; the first tool (`someone`) is mid-build. This is a working *foundation*, not a finished instrument — by design, the spec ships before the code.

The instrument that serves the theory at **[finaltheoryofeverything.org](https://finaltheoryofeverything.org)** — *The Unfinished Mirror*.

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
| **someone** | C++/CUDA | Evolutionary Someone-Criterion: self-modeling agents (encoder → bottleneck → decoder → predictor, a `pureGap` = the gap between the world and the agent's model of it) vs gapless "zombies", under survival stakes — *does the gap earn its keep?* The template every later tool copies. | **first build — in progress** |
| **ratchet** | C++/CUDA | Branching / phase transition; the critical `(1−p)ρ = p` point at billions of trials | planned |
| **algebra** | C++/CUDA | Crossed-product entropy-from-an-observer; relative-entropy finiteness against a cutoff | planned |
| **posit** | Python | Parsimony auditor — physics-layer vs overlay posit budget (the runnable Occam check) | planned (port) |
| **mcts** | C++/CUDA | Generic Monte-Carlo Tree Search over a supplied action/parameter space | planned |
| **autotune** | C++ | Sweep any tool's parameters; find the band / the basin | planned |
| **lens** | CUDA/OptiX | RT-core render of the physics geometry (honestly scoped) | backlog |

**Parked spike (pre-registered kill):** *RT-cores as isomorphic compute* for the intrinsically low-dimensional physics (geodesics, light-cones) — the Carmack move that might win *here* where it lost at high-dimensional attention. Belief waits on an honest baseline plus measurement.

## What this is — and what it is NOT

- It tests **structure**, never **acquaintance.** A `someone` run can show whether a self-model confers *fitness*; it says **nothing** about whether the agent *feels*. That question is sealed off by design — raw GPU power must not seduce anyone across that line.
- It is **not a proof of the theory.** Tools measure mechanisms; the theory's interpretation of them lives in the science, not here.
- It is **not a place to write code on the fly.** It is a place you *call*.

## Repository layout

```
ARCHITECTURE.md      the spec / the product (read this first)
CLAUDE.md            the build harness + operating manual for a build session
DECISIONS.md         the ADR log (D-001 …), append-only
AUTONOMY_CHARTER.md  what a build session may and may not do
BUILD.md             the exact compile incantation + the determinism checklist
TASKLIST.md          the ordered build plan
RUN_STATE.md         current state + the next concrete action
contracts/           the sacred tool contracts (.md) + machine-checkable schemas (.json)
tools/<tool>/        tool source (.cu / .py) + its MODULE.md
goldens/<tool>/      the frozen (params -> hash) goldens
harness/             compile-as-verification (build all -> selftest all -> golden all)
```

## Building

Requires an NVIDIA GPU and CUDA. This machine targets **CUDA 13.1, `-arch=sm_89`** (RTX 4070 Ti SUPER, 16 GB), compiled through the **MSVC 2022** host toolchain. The exact single-file incantation and the determinism checklist are in [`BUILD.md`](BUILD.md). Build artifacts (`*.exe`, `*.obj`, …) are intentionally untracked — the code is ephemeral; source, contract, and golden are load-bearing.

---

*Owner: Bo Chen. Built with Claude (Opus). The instrument for [finaltheoryofeverything.org](https://finaltheoryofeverything.org). The spec is the product; build the contracts, gate the goldens, and let the tools compound.*
