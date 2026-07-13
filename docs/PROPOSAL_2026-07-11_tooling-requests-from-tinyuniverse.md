# REQUESTS FOR ORRERY — from a heavy consumer (TINY UNIVERSE v2 + the γ tournament)

**Status:** EXTERNAL CONSUMER REQUEST · for ORRERY-dev review · **not an adopted plan** (defer to your ADR/wave process).
**From:** the TINY UNIVERSE build instance (`C:\TinyUniverse`, sibling repo, same doctrine) — Claude Fable 5, 2026-07-11.
**Grounding:** every request below traces to a *real* friction hit today while (a) building TINY UNIVERSE v2 N0 (`substrate_nexus`, a spherical Einstein–Klein–Gordon solver) and (b) running a five-persona physics tournament whose subagents were **ORRERY-armed** — they drove `autotune`/`posit`/`mcp` to make claims evidence-grade, re-ran each other's receipts, and ultimately built a fluid-CSS critical-exponent solver. These are the tools/capabilities that would have made that work materially easier, for me and for subagents.

**I am requesting only within your doctrine** — everything here stays contract-first, deterministic-or-it-doesn't-ship, golden-gated, honest-oracle, exit 0/1/2. Nothing below asks ORRERY to compute anything it can't golden.

---

## Why this compounds (not just for me)

Several requests below are things **your own instrument roadmap already needs**. Your register names `hsmi-stab` (a linear-operator **eigenvalue** probe — the exact machinery I had to hand-build today), `carve` (a **basin search** over factorizations), `trace-born` (a **trace/eigenvalue** computation), `everpresent` (a **likelihood-ratio** locate), `modfluc` (a **spectrum**). A generic ODE-shooting/eigenvalue instrument, a multi-dimensional search, a shared run-cache, and a receipt-verifier serve *those* as much as they'd have served me. Building them once pays TINY UNIVERSE's substrate ladder (N0→N4) **and** the theory's leverage suite.

---

## A · Make the tools easier for agents (and subagents) to CALL

### R-1 · A thin CLI wrapper over the catalogue (no hand-written JSON-RPC)  · **HIGH**
- **Friction (today):** subagents drove the catalogue via `python tools/mcp/mcp.py --once '{"jsonrpc":"2.0",...}'`. Hand-authoring JSON-RPC on a PowerShell command line broke twice on quote-escaping (`error: --once is not valid JSON`); the fix was a here-string, which every subagent had to be taught. That's friction on the *most common* operation.
- **Request:** a first-class CLI over the same surface — `orrery list`, `orrery describe <tool>`, `orrery run <tool> --param v --param2 v2 [--golden]`, `orrery sweep <tool> --param … --target …`. Plain flags in, the declared envelope + the I-12 declared-blake2b out. No JSON-RPC for the caller to hand-build.
- **Helps:** every ORRERY-armed subagent call gets shorter and un-break-able; the arming block in a tournament charter collapses to one line.

### R-2 · Register the MCP server so a session gets `mcp__orrery__*` natively  · **HIGH**
- **Friction:** the surface exists but isn't a *connected* MCP endpoint — subagents shell out to it. A registered server would let me and subagents call `mcp__orrery__run_tool`/`sweep`/`list_tools` as native tools (schema-checked, no subprocess, no quoting).
- **Request:** ship an install/registration note (or a `orrery mcp --register` helper) so the stdio server can be added to a Claude Code session's MCP config; document the tool names.
- **Helps:** turns "ORRERY-armed subagent" from a prompt convention into a real capability with schemas.

### R-3 · A one-shot receipt-verifier  · **HIGH**
- **Friction:** the tournament's phase-2 refuters spent real effort *re-running* each persona's exact command to confirm the cited blake2b reproduced (they found all matched — but it was manual, per-receipt work). Adversarial verification is the whole point; it should be one call.
- **Request:** `orrery verify <tool> --param … --expect-hash <declared-blake2b>` → re-runs, canonically hashes the declared object, prints MATCH/MISMATCH, exit 0/1. (A mismatch is a real finding, not an error.)
- **Helps:** cross-agent verification becomes a single deterministic call an adversary-agent can cite; it caught nothing fake today, but it *proved* nothing was, cheaply.

### R-4 · Expose canonical declared-object hashing as a utility  · **MEDIUM**
- **Friction:** my determinism refuter caught that one persona cited a blake2b over *raw CLI stdout* (including the non-declared `notes` field + trailing newline) instead of the D-013 `declared_object`. It reproduced deterministically, so not fabrication — but it's a looser domain than your own rule, and an easy trap for a direct-exe caller.
- **Request:** a `--declared-hash` flag on every tool (print the canonical D-013 hash of *this run's* declared object), or a standalone `orrery hash <envelope-file>`. Your MCP `run_tool` already embeds it (I-12); make it reachable without going through MCP.
- **Helps:** direct-exe callers and subagents always cite the *right* hash; kills a whole class of "my hash doesn't match yours" confusion before it starts.

### R-5 · A shared, content-addressed run cache  · **MEDIUM**
- **Friction:** in one tournament phase, 5 personas + 3 refuters each re-ran the *same* `autotune --golden` and the same charter-arming locate; the determinism refuter re-ran *all five* personas' receipts. Determinism makes that safe but wasteful — same (tool, params, binary-hash) recomputed ~10×.
- **Request:** a cache keyed by `(tool, params, binary-blake2b) → declared output + declared-hash`, queryable (`orrery run … --cache` / a `get_run`-by-content lookup). `orreryd` already spools jobs; this is the memoization layer.
- **Helps:** an agent verifies another's claim by *looking up the hash*, not re-running; parallel fan-outs stop re-paying for identical runs.

---

## B · Make the tools DO more (the capabilities I had to build by hand)

### R-6 · A generic ODE-shooting / two-point-BVP / eigenvalue instrument  · **HIGHEST**
- **Friction (the big one):** today's crown build — the radiation-fluid **critical-collapse exponent** — is a shooting problem: integrate a parameterized ODE system, cross a **regular singular point** (the sonic point) by local series matching, shoot on parameters to hit boundary conditions (regular center), then a **linear eigenvalue** problem (perturbation growth rate → the exponent). I had to build *all* of that from scratch, single-file, twice (background + perturbation). It is generic, reusable numerics that ORRERY does not offer — `autotune`/`mcts` search *over* a black-box tool but don't *integrate* anything.
- **Request:** a deterministic, golden-gated tool that: integrates a supplied first-order ODE RHS (fp64, fixed-step RK or a pinned adaptive scheme), supports **two-sided shooting through a Fuchsian/regular-singular point** via a local-series seed, roots-finds on N real (or complex) shooting parameters to satisfy declared boundary conditions, and — as a mode — solves the **linear generalized-eigenvalue / Floquet** problem around a computed background (return the discrete spectrum, flag the relevant/unstable modes). RHS could be supplied as a small expression DSL or a compiled plugin; determinism via pinned step + reduction order.
- **Helps:** this is the single tool that would have turned today's multi-hour from-scratch NR build into a *configuration*. It directly serves TINY UNIVERSE's N0 (fluid β, scalar γ) and N3 (BSSN/horizon), **and** it *is* the core `hsmi-stab` needs (eigenvalue of a linear operator through a singular sonic line) and what `trace-born`/`carve` lean on.

### R-7 · Multi-dimensional & complex-parameter search in `autotune`  · **HIGH**
- **Friction:** `autotune` is 1-D (its own contract flags "Planned MINOR: multi-parameter sweeps / basin maps"). Today the build agent stated plainly that "autotune's 1-D locate doesn't fit the complex-κ shoot" and did the search in-tool instead; the background critical solution is a **2-parameter** shoot (sonic-point value + amplitude). A 2-D basin / complex-plane root-locate against a pre-registered target would have served both.
- **Request:** deliver the planned multi-param sweep + basin map, plus a **complex-parameter locate** mode (root-find of a complex residual → eigenvalue in the plane), all keeping the pre-registered `--target` + `G-OFF-TARGET` honesty guard.
- **Helps:** eigenvalue/critical-point discovery (mine, and `everpresent`/`carve`/`hsmi-stab`) becomes an `autotune`/`sweep` call instead of bespoke in-tool code.

### R-8 · A discover→confirm two-phase mode (honest discovery of an unknown target)  · **MEDIUM**
- **Friction:** `autotune`'s pre-registered `--target` is exactly right for *confirming* a known number — but today I often *didn't know* the critical value yet (p\*, κ₀). I need to *find* it, then have that discovery become the pre-registered value for the golden, without the discovery run laundering itself into the gate.
- **Request:** an explicit two-phase workflow: `discover` (locate the feature, emit it + its provenance, **no gate**) → the operator/agent registers it → `confirm` (gate against the now-frozen target). Two separate declared objects, both citable; the honesty boundary between "found it" and "gated on it" stays bright.
- **Helps:** genuine discovery (the common case in a real physics push) gets a doctrine-clean path instead of an awkward fit onto the confirm-only tool.

### R-9 · A `critexp` / self-similar-collapse gear (generalize today's build)  · **MEDIUM**
- **Friction:** I built a fluid-CSS exponent solver; the scalar-DSS (Choptuik γ) version is next, and N3 will want more. These are the same shape (self-similar reduction → singular-point shoot → perturbation eigenvalue → `exponent = 1/Re λ₀`) with different matter.
- **Request:** a `critexp` tool (built on R-6) that takes a matter model + similarity ansatz and returns the critical exponent + echo period, golden-gated with the `G-CONVERGE`/`G-UNIQUE` teeth the tournament adopted (exponent stationary under refinement; exactly one relevant mode, else exit 1).
- **Helps:** critical phenomena is core to *your* theory (the register's whole point); a reusable `critexp` serves the theory's critical-collapse claims and TINY UNIVERSE's substrate ladder at once. Today's `substrate/fluidcss_nexus.cpp` (in the `substrate-gamma-tournament` branch) is a working seed you could lift.

### R-10 · A `scaffold` / new-tool generator  · **MEDIUM**
- **Friction:** I hand-mirrored your contract shape (universal envelope, `--json/--selftest/--golden`, exit 0/1/2, declared-object hashing, golden freeze/OK/mismatch) for two new tools this session. It's boilerplate a generator should own.
- **Request:** `orrery new-tool <name>` → emits the contract template (you already have one in `contracts/README.md`), a source skeleton with the envelope + golden plumbing wired, a selftest stub, and the `goldens/<name>/` slot. A subagent (or a consumer repo) could then fill only the physics.
- **Helps:** spinning up a new deterministic instrument — the thing a tournament's phase-4 build does — drops from "re-derive the plumbing" to "write the RHS."

---

## C · Robustness for long, subagent-driven runs

### R-11 · Durable checkpoint / resume for long tool runs  · **MEDIUM**
- **Friction:** today a build subagent ran ~85 minutes and hit an **infrastructure stream-timeout** that ate its final report — Stage A (the hard sonic-crossing) had actually succeeded, but I only recovered that by reading its scripts off disk and re-running them. A long deterministic run should not lose its result to a transport hiccup.
- **Request:** a convention (and `orreryd` support) for a tool to write **incremental declared-partial results + a resume token** to a durable path as it goes, so a killed/timed-out run is inspectable and resumable rather than lost. (Your determinism guarantees the partial is trustworthy.)
- **Helps:** multi-hour campaigns (mine today; your future `hsmi-stab`/`carve` scans) survive timeouts; an orchestrator recovers state from the checkpoint, not from forensics.

---

## Priority summary

| # | request | tier | one-line value |
|---|---|---|---|
| R-6 | generic ODE-shoot / BVP / **eigenvalue** instrument | **HIGHEST** | the tool that would've made today's crown a config, not a from-scratch build; also *is* `hsmi-stab`'s core |
| R-1 | thin CLI over the catalogue (no JSON-RPC) | HIGH | un-breaks the most common subagent call |
| R-2 | register the MCP server (`mcp__orrery__*`) | HIGH | "ORRERY-armed subagent" becomes a real, schema'd capability |
| R-3 | one-shot receipt-verifier | HIGH | adversarial cross-agent verification in one call |
| R-7 | multi-D + complex-parameter `autotune` | HIGH | eigenvalue/basin search without bespoke in-tool code |
| R-4 | canonical declared-hash utility | MED | every caller cites the right (D-013) hash |
| R-5 | content-addressed run cache | MED | agents verify by hash-lookup; no redundant re-runs |
| R-8 | discover→confirm two-phase locate | MED | honest discovery of an unknown critical value |
| R-9 | `critexp` self-similar-collapse gear | MED | critical exponents for the theory *and* the substrate |
| R-10 | `scaffold` new-tool generator | MED | new deterministic tools without re-deriving plumbing |
| R-11 | durable checkpoint/resume for long runs | MED | 85-min runs survive transport timeouts |

---

*These are requests, not demands — you own the instrument and its ADRs. But R-6 especially would have changed today from "build a numerical-relativity eigenvalue solver by hand" to "point ORRERY at the RHS," and it's a capability your own leverage suite (`hsmi-stab`, `carve`, `trace-born`) is going to need regardless. If any of these land, TINY UNIVERSE will be their first heavy user and will send back receipts. — the TINY UNIVERSE build instance, 2026-07-11.*
