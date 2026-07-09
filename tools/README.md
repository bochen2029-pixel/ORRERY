# tools/ — the modules

Each tool is a module: one directory, one `MODULE.md`, one contract (in `../contracts/`), one golden (in `../goldens/`), a `--selftest`, and a headless `.exe` (or Python where justified). You are never working on "the instrument" — always one tool against its fixed contract.

## Inventory & build order (from ARCHITECTURE §8; decided in DECISIONS D-002)

| Tool | Lang | Status | Dir |
|---|---|---|---|
| **someone** | C++/CUDA | **DONE v1.1.1** (golden `aa5b731d`; det. 3×; **cold two-pass verified** — independent, CONFORMANT; v1.1.1 = liborrery migration, golden bit-identical) | `tools/someone/` |
| ratchet | C++/CUDA | **DONE v1.0.1** (golden `91fce3c4`; det. 3×; MC↔analytic 0.06%; **cold two-pass verified**; v1.0.1 = liborrery migration, golden bit-identical) | `tools/ratchet/` |
| algebra | C++/CUDA (cuSOLVER) | **DONE v1.0.1** (golden `1526918f`; det. 3×; c=1 validated vs receipt; Part-A scoped; **cold two-pass verified**; v1.0.1 = liborrery migration, golden bit-identical) | `tools/algebra/` |
| posit | Python | **DONE v1.0.0** (golden `7a22dd22`; det. exact; the Python-is-right tool, D-005; **cold two-pass verified** — CONFORMANT) | `tools/posit/` |
| mcts | C++/CUDA | **DONE v1.0.1** (golden `6c596a53`; det. 3×; root-parallel UCT; **cold two-pass verified**; v1.0.1 = liborrery migration, golden bit-identical) | `tools/mcts/` |
| autotune | Python (glue) | **DONE v1.0.0** (golden `c79002f2`; det. exact; drives the built tools — found ratchet's ρ_c; **cold two-pass verified** — CONFORMANT) | `tools/autotune/` |
| **mcp** | Python | **DONE v1.0.0** (golden `174ec02d`; det. exact; the MCP surface, D-022 — six JSON-RPC tools, I-12 hash chain; live-smoked driving ratchet on GPU) | `tools/mcp/` |
| **orreryd** | C++20 (host) | **DONE v0.1.0** (golden `86f133bb`; det. exact; the job daemon, D-022 v0 — spool FIFO + budgets + sentinels + status page, on liborrery; live-smoked GPU drain + budget kill) | `tools/orreryd/` |
| lens | CUDA/OptiX | backlog (3D viz first; compute-spike parked) | `tools/lens/` |

All four CUDA tools build against **`lib/` (liborrery, D-020)** — the invariant core (envelope/RNG/reductions), KAT-selftested, extracted verbatim from `someone`. Build commands gain `../../lib/envelope.cpp`; each migration was gated on bit-identical golden reproduction.

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
