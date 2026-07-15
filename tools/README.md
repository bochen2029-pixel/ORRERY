# tools/ — the modules

Each tool is a module: one directory, one `MODULE.md`, one contract (in `../contracts/`), one golden (in `../goldens/`), a `--selftest`, and a headless `.exe` (or Python where justified). You are never working on "the instrument" — always one tool against its fixed contract.

## Inventory & build order (from ARCHITECTURE §8; decided in DECISIONS D-002)

| Tool | Lang | Status | Dir |
|---|---|---|---|
| **someone** | C++/CUDA | **DONE v1.2.0** (golden `aa5b731d`; det. 3×; **cold two-pass verified**; v1.2.0 = the OWED I-11 fp64 CPU oracle `--oracle` — fp32 kernels vs an independent fp64 CPU replica agree ~1.2e-7, golden byte-identical, D-025; v1.1.1 = liborrery migration) | `tools/someone/` |
| ratchet | C++/CUDA | **DONE v1.0.1** (golden `91fce3c4`; det. 3×; MC↔analytic 0.06%; **cold two-pass verified**; v1.0.1 = liborrery migration, golden bit-identical) | `tools/ratchet/` |
| algebra | C++/CUDA (cuSOLVER) | **DONE v1.0.1** (golden `1526918f`; det. 3×; c=1 validated vs receipt; Part-A scoped; **cold two-pass verified**; v1.0.1 = liborrery migration, golden bit-identical) | `tools/algebra/` |
| posit | Python | **DONE v1.0.0** (golden `7a22dd22`; det. exact; the Python-is-right tool, D-005; **cold two-pass verified** — CONFORMANT) | `tools/posit/` |
| mcts | C++/CUDA | **DONE v1.0.1** (golden `6c596a53`; det. 3×; root-parallel UCT; **cold two-pass verified**; v1.0.1 = liborrery migration, golden bit-identical) | `tools/mcts/` |
| autotune | Python (glue) | **DONE v1.0.0** (golden `c79002f2`; det. exact; drives the built tools — found ratchet's ρ_c; **cold two-pass verified** — CONFORMANT) | `tools/autotune/` |
| **mcp** | Python | **DONE v1.0.0** (golden `174ec02d`; det. exact; the MCP surface, D-022 — six JSON-RPC tools, I-12 hash chain; live-smoked driving ratchet on GPU) | `tools/mcp/` |
| **orreryd** | C++20 (host) | **DONE v0.1.0** (golden `86f133bb`; det. exact; the job daemon, D-022 v0 — spool FIFO + budgets + sentinels + status page, on liborrery; live-smoked GPU drain + budget kill) | `tools/orreryd/` |
| **orrery** | Python | **DONE v1.1.0** (golden `43977185`; det. 3×; the ergonomic CLI over the catalogue, D-033 / TinyUniverse R-1+R-2+R-3+R-5 — `list`/`describe`/`run`/`sweep` + one-shot receipt-`verify` (MATCH/MISMATCH exit 0/1) + `mcp-register` + a content-addressed run `cache` (v1.1.0, additive-safe); reuses the `mcp` primitives, I-12 chain inherited; cold two-pass CONFORMANT — v1.0.0 core 11/11 + v1.1.0 cache 8/8 [MISS/HIT byte-identical, HIT doesn't spawn, binary-hash invalidation, errors never cached]) | `tools/orrery/` |
| **trace-born** | C++/CUDA (cuSOLVER) | **DONE v1.0.0** (golden `d4e3bf04`; det. 3×; the Born-from-redundancy tool, D-026/C-TRACE — does the normalized-trace weight over a redundancy-defined branch projection reproduce Born \|c_i\|² in a decohering S⊗E^R model? brute-force full-state + partial trace, I-11-checked against the analytic Gram oracle; STEP-A envariance + STEP-B fine-graining witnesses; partial-decoherence negative control fires both gates. Reproduces F15's mechanical core; the D-BORN premise is labeled + excluded, §III-sealed. Extends `algebra`'s cuSOLVER Dsyevd→Zheevd; **cold two-pass CONFORMANT 11/11, scope honest**) | `tools/trace-born/` |
| **shoot** | C++ (host, fp64) | **DONE v1.0.0** (golden `9625b268`; det. 3× + arch-portable; the ODE-shooting eigenvalue instrument, D-032 / TinyUniverse R-6 — 1D Schrödinger spectrum via shooting; harmonic E_j=j+½ + square E_j=(j+1)²π²/2L² reproduced exactly vs the analytic oracle; cold two-pass CONFORMANT) | `tools/shoot/` |
| **lens** | CUDA/OptiX | **DONE v1.1.0** (goldens `11e545b8` silhouette + `914399` geodesic; det. 3× on the sm_89+OptiX 9.1.0+drv 610.47 pin; OptiX RT-core render + I-11 oracle 27π M² / πR²; `bhshadow-geo` DERIVES the shadow by null-geodesic integration, triple-validated delta=0 + lensed render; D-004 SPIKE RUN+RETIRED D-030; **cold two-pass CONFORMANT v1.0.0 & v1.1.0**) | `tools/lens/` |
| **carve** | C++ (host, fp64) | **DONE v1.0.0** (golden `1373454e` = ising positive control; det. 3×; the preferred-factorization basin search, D-026 gear #3 / Layer-2-P2 — does a fixed H prefer a tensor-product structure? k-locality Pauli-weight concentration scored as a **gap over the analytic Haar baseline**; greedy discrete-frame descent; gates G-NO-BASIN / G-MULTI-BASIN. **Design selected by the `runs/carve_design/` Intercom design tournament (D-034), which caught a circular oracle + a decaying score PRE-CONTRACT** — the hsmi-stab antidote. Planted-scrambler I-11 oracle (on-lattice entangling V; metamorphic un-scramble oracle_dev<1e-9); `haar` random control → G-NO-BASIN; selftest 12/12 incl. the three-control gauntlet + anti-blindness sightedness. Greedy search-recovery honestly scoped (exit 2 = search-too-weak, distinct from no-basin) → v1.1 mcts/continuous optimizer. §III-sealed) | `tools/carve/` |

The CUDA tools build against **`lib/` (liborrery, D-020)** — the invariant core (envelope/RNG/reductions), KAT-selftested, extracted verbatim from `someone`. Build commands gain `../../lib/envelope.cpp`; each migration was gated on bit-identical golden reproduction.

## Language rule (ARCHITECTURE §7, DECISIONS D-005)
CUDA/C++ for compute/scale; Python only for symbolic/accounting/glue, justification in `DECISIONS.md`. `posit` is the only Python-is-right tool so far.

## MODULE.md template (copy for a new tool)
```markdown
# <tool> — Module

## Purpose (2 sentences)
## Scope guard (structure not qualia; what a passing run does and does NOT show)
## Contract: ../../contracts/<tool>.contract.md  (vX.Y.Z)
## Internal design (kernels, data layout, the reduction-determinism approach)
## Build command (exact; see ../../BUILD.md) — MUST be a fenced ``` code block (not an inline span) with the full command; `harness/verify.py` discovers it by extracting the first fenced block after "## Build". An inline span → `NO-BUILD-CMD` → harness RED (the ratchet cold two-pass caught exactly this).
## Selftest: what --selftest checks
## Golden: params + where recorded
## Known issues / caveats
## Provenance (what prototype it was seeded from)
```

## Rules
- Contract before code. Golden before "done". `--selftest` + `--golden` always.
- Deterministic or it doesn't ship.
- A tool the science will cite gets a cold-context two-pass verify.
- Borrow kernels freely from the reference engines (`C:\Users\user\Desktop\DSA\`, `C:\ASTRA-7`, `C:\RAYFORMER`, `C:\buddhabrot-main`) — but the *contract* is ORRERY's, not the prototype's.
