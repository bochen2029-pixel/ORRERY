# orrery — Contract  v1.1.0

## Purpose
The **ergonomic CLI over the catalogue** (TinyUniverse R-1/R-2/R-3; D-033): plain-flag subcommands to
`list` / `describe` / `run` / `sweep` the ORRERY tools, a one-shot **receipt-verifier** (`verify`), and an
**MCP-registration helper** (`mcp-register`) — so an agent or a shell calls the catalogue with ordinary
flags instead of hand-authoring JSON-RPC. It is a thin front-end that **reuses the vetted `mcp` surface
primitives** (`registry_scan`, `do_run_tool`, `do_describe_contract`, `do_sweep`, `blake2b_hex`,
`extract_declared`) — it does NOT reimplement tool-calling or hashing, so the **I-12 declared-object
blake2b** chain is inherited. Like `mcp`, it is a *caller* of the sacred executables (subprocess), never a
replacement; the §2 science↔instrument split passes through unchanged.

**Scope guard:** a transport/orchestration surface; computes nothing scientific, says nothing about
qualia. §III-sealed. **Language:** Python (D-005: pure IPC bookkeeping — subprocess, JSON, file reads; no
compute/GPU/RNG), the `posit`/`autotune`/`mcp` justification.

## CLI
```
orrery <command> [args]              # subcommands (below)
orrery --json | --selftest | --golden   # meta-modes (self-check envelope)
```

### Subcommands
| command | usage | behavior |
|---|---|---|
| `list` | `orrery list [--json]` | list the live registry (name, lang, contract version, golden hash). Table by default; `--json` emits the raw registry array. Exit 0. |
| `describe` | `orrery describe <tool>` | print the tool's machine schema + human contract **verbatim** (+ their blake2b). Unknown tool → exit 2. |
| `run` | `orrery run <tool> [--flag val ...] [--golden] [--json] [--cache]` | run the tool with plain flags (mapped to `--flag val`; bare `--flag` → boolean). Prints the tool's declared envelope + the **I-12** `declared_blake2b` + `artifact_blake2b` (to stderr). Exit mirrors the tool: **0** pass · **1** gate-fired · **2** error/timeout. **[v1.1.0]** `--cache` consults/stores a content-addressed run cache (below) — a hit returns the stored declared output WITHOUT re-running (stderr tags `[CACHE HIT]`/`[CACHE MISS]`). |
| `cache` | `orrery cache [--clear \| --get <key>]` | **[v1.1.0]** inspect the run cache: default prints stats + entries; `--clear` empties it; `--get <key>` prints one cached record. Exit 0. |
| `sweep` | `orrery sweep <tool> --sweep NAME --metric FIELD --lo L --hi H --target T [--points N] [--fixed "..."] [--locate peak\|threshold] [--level V] [--tol T]` | drive `autotune` in real-tool mode against a **pre-registered** `--target` (autotune's contract governs semantics); prints the autotune record + hashes. Exit 0/1/2. |
| `verify` | `orrery verify <tool> [--flag val ...] --expect-hash <64-hex>` | **R-3:** re-run the tool, canonically hash its declared object (I-12), compare to `--expect-hash`. Prints `MATCH`/`MISMATCH` + both hashes. Exit **0** MATCH · **1** MISMATCH (a real finding, not an error) · **2** error. |
| `mcp-register` | `orrery mcp-register [--json]` | **R-2:** print the exact `claude mcp add` command + the raw MCP-config JSON to register the `mcp` stdio server as `mcp__orrery__*` in a Claude Code session, and the tool names it exposes. Exit 0. |

### Meta-modes
| flag | meaning |
|---|---|
| --json | run the self-check (below) and emit orrery's JSON envelope on stdout |
| --selftest | internal battery; exit 0/1 |
| --golden | self-check at golden params; hash vs `goldens/orrery/`; exit 0/1 |
| --seed | inert (no RNG; echoed for envelope uniformity) |

Flag parsing for `run`/`verify`/`sweep`: everything after `<tool>` is passed through — `--key value` →
`params["key"]="value"`; a bare `--flag` (next arg is another `--flag` or end) → `params["flag"]=true`.
Keys must match `^[A-Za-z0-9-]+$` (the catalogue has uppercase flags: ratchet `--R`, someone `--N`). The
tool's own contract enforces value ranges (its exit 2 surfaces as orrery exit 2). `--expect-hash` is
consumed by `verify`, not forwarded to the tool.

## Output (`--json`/`--golden` envelope `result` fields — the self-check)
| field | type | meaning |
|---|---|---|
| chain_tool | str | `"posit"` (the canned end-to-end target; exact, no GPU/RNG) |
| chain_exit_class | str | exit class of `run posit --golden` through the generic run path |
| chain_declared_blake2b | str (64 hex) | the declared hash extracted from posit's envelope (I-12) |
| chain_matches_frozen | bool | `chain_declared_blake2b == goldens/posit/declared.hash` — the I-12 chain proof |
| verify_ok | bool | `verify posit --golden --expect-hash <posit-frozen>` returns MATCH **and** a deliberately-wrong hash returns MISMATCH (the R-3 verifier works both ways) |
| v1_catalogue_complete | bool | the six v1 tools (algebra, autotune, mcts, posit, ratchet, someone) each have contract + schema + golden |

Params echoed: `{chain_tool:"posit", timeout_s:120}` (fixed constants in v1.0.0). Non-declared: run ids,
durations, the live registry count (grows with the catalogue — reported by `list`, not in the golden).

## Gates (declared negative-result conditions → exit 1)
| id | fires when | value |
|---|---|---|
| G-CHAIN-MISMATCH | `chain_exit_class ≠ "pass"` or `chain_matches_frozen = false` — the I-12 envelope/hash chain drifted | 1 fired / 0 clear |
| G-VERIFY-BROKEN | `verify_ok = false` or `v1_catalogue_complete = false` — the receipt-verifier or the v1 registry is broken | 1 fired / 0 clear |

## Exit codes
`0` pass · `1` a gate fired (chain drift / verifier broken — a real finding) · `2` error (unknown command,
bad flags, missing posit artifact, subprocess failure). Subcommand exits are per their rows above.

## Determinism
No RNG; `--seed` inert. `--json`/`--golden` declared output is **byte-identical** given the repo at a
commit — it depends, deliberately, on `posit`'s golden and the six v1 tools' contract/schema/golden files
(same narrow coupling as `mcp`). Subcommand output over live data (`list`) reflects the catalogue as it
grows — that is its job, not drift. Declared hash domain = D-013.

## Run cache (R-5, v1.1.0) — content-addressed, NON-declared
`run --cache` keys a store (`runs/cache/<key>.json`, gitignored) by **`blake2b(tool + canonical-params +
tool-binary-blake2b)`**. Because the tools are deterministic (same params ⇒ byte-identical declared output)
a cache hit is safe; because the key includes the **binary hash**, a rebuilt tool automatically MISSES
(invalidation needs no manual step). A hit returns the stored `{envelope, declared_blake2b, exit_class}`
without spawning the tool — so an agent verifies another's claim by *lookup*, and a fan-out stops re-paying
for identical runs. Only declared-output runs are cached (errors/timeouts are not). The cache is
operational/NON-declared — it never enters any golden or determinism claim; `--golden`/`--json` never touch it.

## Golden
params: `python orrery.py --golden` (self-check at the fixed params above; no run-record write).
recorded: `goldens/orrery/` (declared.hash + stdout.txt + NOTE.md).
**Golden coupling (deliberate, narrow — same rationale as `mcp`, D-019/D-022):** a surface's value IS the
calling, so the golden runs the narrowest real chain — `posit --golden` through the generic run path — and
asserts the extracted hash equals posit's frozen `7a22dd22…`, plus that the `verify` command MATCHes the
right hash and MISMATCHes a wrong one. **If posit's golden is legitimately superseded, orrery re-baselines
in the same operator-signed commit** (`goldens/orrery/NOTE.md`).

## Change log
- **v1.1.0** — 2026-07-13 (MINOR, additive; TinyUniverse **R-5**). Adds the content-addressed **run cache**:
  `run --cache` (consult/store) + the `cache` subcommand (stats/clear/get). No existing flag/output/exit
  changed; the cache is NON-declared and the self-check golden `43977185` reproduces byte-identical.
- v1.0.0 — initial contract (D-033; TinyUniverse R-1 CLI + R-2 mcp-register + R-3 verify). Subcommands
  list/describe/run/sweep/verify/mcp-register over the reused `mcp` primitives; posit-chain self-check golden.
