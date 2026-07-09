# golden — `mcp` v1.0.0

## What is frozen
The declared output of the chain check at its fixed params:
```
python mcp.py --golden
```
i.e. `{chain_tool:"posit", v1_catalogue:[algebra,autotune,mcts,posit,ratchet,someone], timeout_s:120}` → in-process JSON-RPC round-trip OK, 6 MCP tools exposed, the six v1 tools complete on disk, and a REAL `run_tool("posit",{golden:true})` subprocess whose extracted declared hash equals posit's frozen golden.

Files: `declared.hash` (blake2b-256 of the canonical declared object = `174ec02d…`), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as every tool)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — fixed key order, gate values `%.6f`. `tool`/`version`/`notes` excluded. `mcp --golden` recomputes and compares; reproduced **3× byte-identical** at freeze (2026-07-09).

## What it proves
1. **The surface serves the protocol** — initialize / tools/list / tools/call round-trip is shape-valid, with the six contract-named MCP tools.
2. **The I-12 chain end-to-end** — a real subprocess through the generic `run_tool` path returns an envelope whose textually-extracted declared object hashes to `7a22dd22…` == `goldens/posit/declared.hash`. The citation chain (envelope → declared hash → frozen golden) is machine-checked in one number.
3. **Registry integrity** — the six v1 tools each have contract + schema + golden on disk (G-REGISTRY-INCOMPLETE clear).

## DELIBERATE COUPLING (read before touching posit's golden)
This golden **intentionally embeds posit's frozen declared hash** (the narrowest exact, no-RNG, no-GPU chain proof — see `contracts/mcp.contract.md` "Golden coupling", contra-D-019 rationale documented there). **If `posit`'s golden is ever legitimately superseded under review, `mcp`'s golden must be re-baselined in the same operator-signed commit** — record old/new hashes for BOTH tools here. Catalogue GROWTH does not touch this golden (the check is over the fixed v1 six, not the live registry).

## Environment
Recorded in `runs/mcp_golden.result.lock` (tool semver, source blake2b, Python, exact CLI, declared hash, chain hash).
