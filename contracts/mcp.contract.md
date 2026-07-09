# mcp — Contract  v1.0.0

## Purpose
The **MCP surface** (D-022): a headless stdio JSON-RPC server that exposes the ORRERY catalogue to LLM callers — list the tools, serve their contracts verbatim, run them, sweep them, and report harness status. **The sacred CLI executables remain the contract of record; `mcp` is a *caller* of them (subprocess), never a replacement or an in-process shortcut** — the §2 science↔instrument split passes through it unchanged. Per **I-12**, every `run_tool`/`sweep` response embeds the D-013 **declared-object blake2b** recomputed from the tool's envelope (plus the artifact hash), so a caller can cite reproducibly.

**Scope guard:** a transport/orchestration surface; computes nothing scientific itself and says nothing about qualia. §III-sealed.

**Language:** Python (D-005/D-022 — pure IPC bookkeeping: subprocess, JSON parse, file reads; no compute/scale/GPU/RNG). A future C++ port must honor this same contract.

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --serve | flag | | off | run the MCP server on stdio (newline-delimited JSON-RPC 2.0) until EOF |
| --once REQ | str (JSON) | | off | process exactly one JSON-RPC request, print the one response line, exit 0 |
| --seed | int | ≥0 | 0 | inert (no RNG; envelope uniformity, echoed) |
| --json | flag | | off | run the **chain check** (the golden body at its fixed params) and emit the JSON envelope |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | chain check at golden params; hash vs `goldens/mcp/`; exit 0/1 |

Exactly one mode flag is required. `--serve`/`--once` write **only** protocol lines to stdout (diagnostics to stderr).

## The six MCP tools (served via `tools/list` / `tools/call`)
| tool | input | output (declared response fields) |
|---|---|---|
| `list_tools` | `{}` | `{tools:[{name,lang,contract_version,has_contract,has_schema,golden_hash,artifact}],count}` — live registry scan (`tools/*/MODULE.md`) |
| `describe_contract` | `{tool}` | `{tool,schema_json,contract_md,schema_blake2b,contract_blake2b}` — schema/contract served **verbatim** from `contracts/` |
| `run_tool` | `{tool, params?:{flagname→value}, stdin_json?, timeout_s?≤3600}` | `{run_id°,tool,argv,exit_code,exit_class:pass\|gate-fired\|error\|timeout,envelope,declared_blake2b,artifact_blake2b,stderr_tail,duration_s°}` — spawns the sacred exe/py with `--json` forced (unless `golden`/`selftest` passed), extracts the declared object from the envelope text, hashes it (I-12) |
| `get_run` | `{run_id}` | the stored `run_tool` record (from `runs/mcp/<run_id>.json`) |
| `sweep` | `{tool,sweep,metric,lo,hi,target, points?,fixed?,locate?,level?,tol?,timeout_s?}` | a `run_tool`-shaped record of the **autotune** invocation it builds (`--tool <abs artifact> --sweep … --json`) — autotune's contract governs the sweep semantics |
| `golden_status` | `{tool?,no_build?=true,timeout_s?≤3600}` | `{overall:GREEN\|RED,rows:[{tool,build,selftest,golden}],report°}` — runs `harness/verify.py` |

° = **non-declared** fields (run ids, durations, timestamps, report paths): excluded from any determinism claim.

Param keys in `run_tool.params` must match `^[A-Za-z0-9-]+$` (mapped to `--key value`; boolean `true` → bare flag; case-sensitive — the catalogue has uppercase flags like ratchet's `--R` and someone's `--N`); values are passed verbatim — **the tool's own contract enforces ranges (its exit 2 is surfaced as `exit_class:"error"`)**. Unknown registry tool / unknown run_id / malformed input → JSON-RPC error or `isError:true` tool result; the server never crashes on bad input.

## Output (`--json`/`--golden` envelope `result` fields — the chain check)
| field | type | meaning |
|---|---|---|
| jsonrpc_roundtrip_ok | bool | in-process `initialize` → `tools/list` → `tools/call(list_tools)` round-trip is shape-valid |
| tools_exposed | int | number of MCP tools served (6 in v1.0.0) |
| v1_catalogue_complete | bool | the six frozen v1 tools (algebra, autotune, mcts, posit, ratchet, someone) each have contract + schema + golden on disk |
| chain_tool | str | `"posit"` (the canned end-to-end target; exact, no GPU) |
| chain_exit_class | str | exit class of the real subprocess `run_tool("posit",{golden:true})` |
| chain_declared_blake2b | str (64 hex) | the declared hash extracted from posit's envelope through the generic `run_tool` path |
| chain_matches_frozen | bool | `chain_declared_blake2b == goldens/posit/declared.hash` — **the I-12 chain proof** |

Params echoed: `{chain_tool:"posit", v1_catalogue:[the six names], timeout_s:120}` (fixed constants in v1.0.0).

## Gates (declared negative-result conditions → exit 1)
| id | fires when | value |
|---|---|---|
| G-CHAIN-MISMATCH | `chain_exit_class ≠ "pass"` or `chain_matches_frozen = false` — the end-to-end envelope/hash chain drifted | 1.0 fired / 0.0 clear (thr 0) |
| G-REGISTRY-INCOMPLETE | any of the six v1 tools missing contract/schema/golden | count missing (thr 0) |

## Exit codes
`0` pass · `1` a gate fired (chain drift / registry hole — a real finding, surface loudly) · `2` error (bad CLI, malformed `--once` JSON, missing posit artifact, subprocess spawn failure). In `--serve` mode: protocol-level problems are JSON-RPC **error responses**, not process exits; exit 0 on clean stdin EOF.

## Determinism
No RNG anywhere; `--seed` is inert. `--json`/`--golden` declared output is **byte-identical** given the repo at a commit — it depends, deliberately, on the six v1 tools' contract/schema/golden files and on `posit`'s behavior (see Golden coupling below). `--serve`/`--once` responses are deterministic **modulo the non-declared fields** (run ids, durations, timestamps, report paths) and modulo live repo state (the registry scan reflects the catalogue as it grows — that is its job, not drift).

## Golden
params: `python mcp.py --golden`  (chain check at the fixed params above; fixed run id; no run-record write)
recorded: `goldens/mcp/` (declared.hash + stdout.txt + NOTE.md). Hash domain = D-013: blake2b-256 over canonical `{seed,params,result,gates,verdict}`.

**Golden coupling (deliberate, narrow — documented against D-019's self-containment rule):** a surface's entire value *is* the calling of other tools, so a self-contained golden would prove nothing real. The golden therefore runs the **narrowest possible real chain**: `posit --golden` (exact, no RNG, no GPU, milliseconds) through the generic subprocess path, and asserts the extracted declared hash equals posit's frozen `7a22dd22…`. Consequence: **if posit's golden is ever legitimately superseded under review, mcp's golden re-baselines in the same operator-signed commit** (goldens/mcp/NOTE.md carries this).

## Change log
- v1.0.0 — initial contract (D-022 scope: the MCP stdio surface only; `orreryd` v0 and the HTTP API are later Phase-5 items under the same ADR). Six tools: list_tools, describe_contract, run_tool, get_run, sweep, golden_status. I-12 hash embedding on every run response.
