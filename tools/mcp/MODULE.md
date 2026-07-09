# MODULE — `mcp`

*The MCP surface (tool #7, D-022): how LLM callers reach the instrument. Read `contracts/mcp.contract.md` (v1.0.0) first — the contract is authoritative.*

**Status: DONE v1.0.0** — built, golden frozen, selftest green (13 checks), cold two-pass pending/complete per RUN_STATE.

## Purpose
A headless **stdio JSON-RPC 2.0 MCP server** exposing six tools to LLM callers: `list_tools`, `describe_contract` (serves `contracts/<t>.schema.json` **verbatim**), `run_tool` (spawns the sacred exe/py, returns the envelope + the D-013 declared hash — **I-12**), `get_run`, `sweep` (builds an `autotune` real-tool invocation), `golden_status` (runs `harness/verify.py`). The science's citation chain becomes machine-checkable end-to-end: every run response carries `declared_blake2b` (recomputed from the envelope text) + `artifact_blake2b`.

## SCOPE GUARD (sacred — the §III firewall)
**A transport/orchestration surface; it computes nothing scientific itself and says nothing about qualia — §III-sealed.** Emitted verbatim in the JSON `notes`. The §2 split is preserved absolutely: `mcp` **subprocesses the sacred executables** — it never links tool internals, never reimplements a computation, never bypasses a contract.

## Contract
`contracts/mcp.contract.md` v1.0.0 (+ `contracts/mcp.schema.json` — covers the tool's own `--json`/`--golden` envelope; the JSON-RPC response shapes are specified in the contract). Code is ephemeral; contract + golden are load-bearing.

## Provenance
D-022 (`docs/PROPOSAL_2026-07-09_wave_plan.md`), adopted Active with this build. Python per D-005: pure IPC bookkeeping (subprocess, JSON, file reads) — no compute/scale/GPU/RNG. A future C++ port must reproduce this contract + golden.

## Internal design (as built)
- **Registry** = `tools/*/MODULE.md` scan (the harness's own discovery rule); per tool: lang (`<t>.py` → python, else `<t>.exe`), contract semver (parsed from `contracts/<t>.contract.md` heading), golden hash (first token of `goldens/<t>/declared.hash`).
- **`run_tool`**: params dict → argv (`--key value`; `true` → bare flag; keys must match `^[a-z0-9-]+$`); `--json` forced unless `golden`/`selftest` requested; `stdin_json` piped for case-driven tools (posit). Subprocess with `cwd=tools/<t>`, absolute artifact path, timeout (default 900 s, cap 3600). Exit mapping: 0→`pass`, 1→`gate-fired`, 2→`error`, timeout→`timeout`.
- **I-12 hash chain**: the declared object is extracted **textually** from the envelope (the substring from `"seed":` to `,"notes":`, re-wrapped in `{}`) — exact by construction since every tool emits the envelope in the lib-pinned fixed order; no float re-canonicalization, no parse round-trip. `blake2b-256` of that text is the same value the tool's own `--golden` computes (selftest KATs this against posit's frozen hash).
- **Run store**: `runs/mcp/<run_id>.json` (gitignored — operational records, not canon; a citable run is promoted by hand into a `result.lock`). `--golden`/`--selftest` write no records (fixed run id, `store=false`) so verification is side-effect-free.
- **MCP protocol**: newline-delimited JSON-RPC 2.0 on stdio; handles `initialize` (echoes the client's `protocolVersion`, else pins `2025-06-18`; capabilities `{tools:{}}`), `notifications/initialized`, `ping`, `tools/list`, `tools/call` (results as `{content:[{type:"text",text:<JSON>}],isError}`). Protocol problems → JSON-RPC error responses, never a crash; stdout carries protocol lines ONLY (diagnostics → stderr).
- **The chain check** (`--json`/`--golden` body): in-process JSON-RPC round-trip + v1-catalogue completeness (the six frozen names) + a REAL `run_tool("posit",{golden:true})` subprocess whose extracted declared hash must equal `goldens/posit/declared.hash`. Envelope/gates per the contract; canonical serialization copied from `posit.py` (the Python template).

## Determinism approach
No RNG; `--seed` inert (echoed). `--json`/`--golden` declared output is byte-identical given the repo at a commit. Non-declared: run ids, durations, timestamps, report paths, live registry listings. **Golden coupling is deliberate and narrow** (posit: exact, no RNG, milliseconds) — see the contract's "Golden coupling" section; if posit re-baselines under review, mcp re-baselines in the same operator-signed commit.

## Selftest (13 checks, all offline-fast; <30 s)
blake2b KAT · declared-extraction KAT (synthetic envelope) · registry finds the six v1 tools with contract+schema+golden · contract-version parse (posit 1.0.x) · describe_contract(posit) serves a parseable schema with `"tool":{"const":"posit"}` · initialize shape · tools/list = the six MCP tools · unknown method → `-32601` + unknown tool → `isError` · **stdio round-trip via a real `--once` subprocess of itself** · **the I-12 chain KAT: `run_tool("posit",{golden:true})` → extracted hash == frozen `7a22dd22…`** · argv-builder unit KATs (bool flag, valued flag, bad key rejected) · run-store round-trip (`run_tool`→`get_run`) · determinism (chain-check declared built twice, byte-identical).

## Build
Python tool — the harness's polyglot build step is a syntax check (fenced block per the template rule):
```
python -m py_compile mcp.py
```
Then: `python mcp.py --selftest` · `python mcp.py --golden` · `python mcp.py --serve` (the operational mode) · `python mcp.py --once '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'`.

## Known issues / caveats
- `golden_status` with `no_build:false` can exceed its default timeout when the full suite rebuilds (someone's ~8-min golden, D-014) — raise `timeout_s` for full verifies.
- The MCP protocol pin is minimal (`initialize`/`tools/*`/`ping`, newline-delimited): rich MCP features (resources, prompts, progress) are out of scope for v1.0.0 — additive MINOR bumps when a caller needs them.
- `run_tool` passes params through **unvalidated** beyond key syntax — by design: the *tool's* contract enforces ranges (its exit 2 surfaces as `exit_class:"error"`). The surface must never grow its own copy of a tool's law.

*Sims prove structure, never acquaintance. The surface serves contracts; it never becomes one of the tools it serves.*
