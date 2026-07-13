# MODULE — `orrery` (v1.1.0)

**Purpose.** The ergonomic **CLI over the catalogue** (TinyUniverse R-1/R-2/R-3; D-033): plain-flag
subcommands to `list` / `describe` / `run` / `sweep` the tools, a one-shot **receipt-verifier** (`verify`),
and an **MCP-registration helper** (`mcp-register`) — so an agent or shell calls the catalogue with ordinary
flags instead of hand-authoring JSON-RPC (the friction R-1 named).

**Contract:** [`contracts/orrery.contract.md`](../../contracts/orrery.contract.md) (+ `orrery.schema.json`).
Contract is authoritative.

**Firewall.** A transport/orchestration surface: computes nothing scientific, says nothing about qualia —
§III-sealed. **Language:** Python (D-005 — pure IPC bookkeeping; the `posit`/`autotune`/`mcp` case).

## Design — reuse, don't reimplement
`orrery` **imports the vetted `mcp` surface primitives** (`registry_scan`, `do_run_tool`,
`do_describe_contract`, `do_sweep`, `blake2b_hex`, `extract_declared`, `V1_CATALOGUE`, `jstr`/`fmt6`) from
`tools/mcp/mcp.py` — it does NOT reimplement tool-calling or hashing, so the **I-12** declared-object
blake2b chain is inherited and there is no duplicated logic to drift (the D-020 principle). It is a *caller*
of the sacred executables (subprocess), never an in-process shortcut; the §2 split passes through unchanged.

## Commands (see the contract for full flags)
- `orrery list [--json]` — the live registry (name, lang, version, golden hash).
- `orrery describe <tool>` — schema + contract verbatim (+ their blake2b).
- `orrery run <tool> [--flag val ...] [--golden] [--cache]` — run with plain flags; prints the tool's
  envelope + the I-12 `declared_blake2b`/`artifact_blake2b`; exit mirrors the tool (0 pass · 1 gate-fired ·
  2 error). **[v1.1.0]** `--cache` consults/stores the content-addressed run cache (below).
- `orrery cache [--clear | --get <key>]` — **[v1.1.0]** inspect/clear the run cache.
- `orrery sweep <tool> --sweep NAME --metric FIELD --lo L --hi H --target T [...]` — drive `autotune`.
- `orrery verify <tool> [--flag val ...] --expect-hash <hex>` — **R-3**: re-run, hash the declared object,
  MATCH/MISMATCH, exit 0/1 (a mismatch is a finding, not an error).
- `orrery mcp-register [--json]` — **R-2**: print the `claude mcp add` command + MCP-config JSON to expose
  the `mcp` stdio server as `mcp__orrery__*`.
- `orrery --json | --selftest | --golden` — the self-check envelope (the posit chain).

## Build
Pure Python (no compile); the polyglot harness runs it as `python orrery.py`:
```
python -m py_compile orrery.py
```
```
python orrery.py --selftest
python orrery.py --golden
python orrery.py list
python orrery.py run ratchet --R 3 --seed 1
python orrery.py verify posit --golden --expect-hash 7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44
python orrery.py mcp-register
```
(Windows console is cp1252 — the tool forces UTF-8 stdout.)

## Oracle & golden
- Golden: `python orrery.py --golden` — the posit-chain self-check; declared blake2b `43977185…`
  (reproduced ≥3×). Coupling: posit's golden (re-baselines with it, like `mcp`). See `goldens/orrery/NOTE.md`.
- Selftest: blake2b KAT, collect_params KATs, registry completeness, `describe`, the `verify` receipt-check
  BOTH ways, the self-check verdict, determinism.

## Run cache (R-5, v1.1.0)
`run --cache` keys `runs/cache/<key>.json` (gitignored) by `blake2b(tool + canonical-params +
binary-blake2b)`. Deterministic tools ⇒ a hit is safe; the binary hash in the key ⇒ a rebuilt tool
auto-misses. A hit returns the stored declared output without spawning the tool (agents verify by lookup;
fan-outs stop re-paying for identical runs). Only declared-output runs are cached; NON-declared — the golden
never touches it. `cache` (stats) / `cache --clear` / `cache --get <key>` manage it.

## Known issues / scope (honest, v1.1.0)
- **Imports `mcp.py`** — `orrery` needs `tools/mcp/mcp.py` present (a committed tool). A future refactor could
  lift the shared registry/run/hash core into `lib/`; v1 reuses `mcp` directly (no duplication).
- **R-2 is a helper, not an auto-installer** — `mcp-register` prints the exact command/config; the operator
  runs `claude mcp add` (adding an MCP server is a session-config act).
- `run`/`verify` force the tool's own flags through; range validation is the tool's job (its exit 2 surfaces
  as orrery exit 2). `sweep` coerces `lo/hi/target/tol/level`→float, `points/seed`→int.
