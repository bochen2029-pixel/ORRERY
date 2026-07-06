# tools/ — the modules

Each tool is a module: one directory, one `MODULE.md`, one contract (in `../contracts/`), one golden (in `../goldens/`), a `--selftest`, and a headless `.exe` (or Python where justified). You are never working on "the instrument" — always one tool against its fixed contract.

## Inventory & build order (from ARCHITECTURE §8; decided in DECISIONS D-002)

| Tool | Lang | Status | Dir |
|---|---|---|---|
| **someone** | C++/CUDA | **DONE v1.1.0** (golden `aa5b731d`; det. 3×; conformance-verified; fresh-session cold two-pass owed) | `tools/someone/` |
| ratchet | C++/CUDA | **contract-first** (v1.0.0 contract+schema+MODULE done; impl next) | `tools/ratchet/` |
| algebra | C++/CUDA (cuSOLVER) | planned | `tools/algebra/` |
| posit | Python | port | `tools/posit/` |
| mcts | C++/CUDA | planned | `tools/mcts/` |
| autotune | C++/Py glue | planned | `tools/autotune/` |
| lens | CUDA/OptiX | backlog (3D viz first; compute-spike parked) | `tools/lens/` |

## Language rule (ARCHITECTURE §7, DECISIONS D-005)
CUDA/C++ for compute/scale; Python only for symbolic/accounting/glue, justification in `DECISIONS.md`. `posit` is the only Python-is-right tool so far.

## MODULE.md template (copy for a new tool)
```markdown
# <tool> — Module

## Purpose (2 sentences)
## Scope guard (structure not qualia; what a passing run does and does NOT show)
## Contract: ../../contracts/<tool>.contract.md  (vX.Y.Z)
## Internal design (kernels, data layout, the reduction-determinism approach)
## Build command (exact; see ../../BUILD.md)
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
