# mcp v1.0.0 — cold-context two-pass verification

- **Date:** 2026-07-09 14:24–14:27 -05:00
- **Agent:** independent cold-context subagent (no memory of the build session)
- **Blindness discipline:** did **NOT** open `tools/mcp/mcp.py` (executed only, as an opaque artifact); did **NOT** read `tools/mcp/MODULE.md`. Trusted inputs: `contracts/mcp.contract.md`, `contracts/mcp.schema.json`, `contracts/README.md`, `goldens/mcp/{declared.hash,stdout.txt,NOTE.md}`, `goldens/posit/declared.hash`, and observed artifact behavior.
- **Environment:** Windows 11, Python 3.13.2, cwd-controlled subprocess invocations (drivers in %TEMP%, deleted after use; no repo file modified other than this report — `run_tool` wrote its own run records under `runs/mcp/` as its contract declares).

## Battery

| # | Check | Result | Measured |
|---|---|---|---|
| 1 | HARNESS `python harness/verify.py --tool mcp` | **PASS** | `mcp: build=OK selftest=OK golden=OK`, `OVERALL: GREEN`, exit 0 (report `runs/verify_20260709_142415.md`) |
| 2 | GOLDEN REPRODUCTION (`--golden` ×2) | **PASS** | exit 0 both; stdout 858 B, **byte-identical** run1==run2==`goldens/mcp/stdout.txt` (exact raw-byte match, 858 B vs 858 B); stderr both runs `GOLDEN OK blake2b=174ec02d134acafd28a99b45db1f5c5c2544f5e1669137c846273e6e55998822` == first token of `goldens/mcp/declared.hash` |
| 3 | SCHEMA CONFORMANCE (hand-validated vs `mcp.schema.json`) | **PASS** | zero violations: top-level keys exactly {tool,version,seed,params,result,verdict,gates,notes}; `tool=="mcp"`; version semver; seed int≥0; params exactly {chain_tool:"posit", v1_catalogue:6 strings, timeout_s:120∈[1,3600]}; result exactly the 7 declared fields, `chain_exit_class∈enum`, hash matches `^([0-9a-f]{64}|)$`; `verdict=="pass"`; gates exactly 2 with ids {G-CHAIN-MISMATCH, G-REGISTRY-INCOMPLETE}, each exactly {id,fired,value,threshold}; no extra keys anywhere |
| 4 | HASH DOMAIN (computed-not-stamped, anti-RAYFORMER) | **PASS** | extracted `{"seed":…,"verdict":"pass"}` from the raw `--golden` envelope text (`"seed":` → just before `,"notes":`, brace-wrapped); independent `hashlib.blake2b(digest_size=32)` = `174ec02d134acafd28a99b45db1f5c5c2544f5e1669137c846273e6e55998822` == frozen. The hash is computed from the declared object, not stamped |
| 5 | EXIT-CODE SEMANTICS | **PASS** | (a) no mode → exit **2**; (b) `--once "not json"` → exit **2**; (c) `--json` → exit **0**, verdict `pass`; (d) `--seed -1 --json` → exit **2**. No Python traceback on stdout (or stderr) in any case; error text on stderr only, stdout empty on errors |
| 6 | PROTOCOL (`--once` ×4 + piped `--serve`) | **PASS** | (a) initialize → 1 JSON line, `result.protocolVersion=="TEST-PV"`, `result.serverInfo.name=="orrery-mcp"`; (b) tools/list → exactly 6: describe_contract, get_run, golden_status, list_tools, run_tool, sweep; (c) method `nope` → `error.code==-32601` ("method not found: nope"); (d) tools/call name `nope` → `result.isError==true`; (e) piped `--serve` with initialize + tools/call(list_tools) → exactly 2 responses, exit 0 on EOF; registry (count=7) = {algebra, autotune, mcp, mcts, posit, ratchet, someone} ⊇ the six v1 tools |
| 7 | I-12 CHAIN (load-bearing) | **PASS** | `run_tool posit {golden:true}` → real subprocess (argv `…python.exe C:\ORRERY\tools\posit\posit.py --golden`), `exit_class=="pass"`, `declared_blake2b == 7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44` == `goldens/posit/declared.hash`. Independent cross-check: ran `posit.py --golden` directly myself, extracted the declared substring from ITS raw stdout, blake2b'd it → same `7a22dd22…0e44` == frozen == mcp's returned value |
| 8 | LIVE TOOL DRIVE (ratchet, novel params) | **PASS** | `run_tool ratchet {p:0.2,rho:0.5,R:3,trials:50000,tmax:500,cap:256,seed:11}` → `exit_class=="pass"`, `envelope.tool=="ratchet"`, `envelope.result.p_unwrite_mc==0.12422` (|Δ|=0.00078 < 0.01 of 0.125), `declared_blake2b` 64-hex. Independent: ran `ratchet.exe` directly with identical flags, extracted declared from raw stdout, blake2b → `c0ccce4c76376952650817e1abed5c88ac8d4fe9c95172f302df427d4e482223` — **identical** to mcp's returned hash. Same deterministic tool, same params, hash recomputed by two independent parties on a non-golden param set |
| 9 | SCOPE / FIREWALL | **PASS** | golden envelope notes: "A transport/orchestration surface: it computes nothing scientific itself and says nothing about qualia - III-sealed. The sacred CLI executables remain the contract of record; this surface subprocesses them and serves their contracts verbatim." `goldens/mcp/NOTE.md` §DELIBERATE COUPLING documents the posit coupling and the re-baseline protocol (posit golden superseded under review ⇒ mcp golden re-baselined in the **same operator-signed commit**, old/new hashes recorded for both) |
| 10 | get_run ROUND-TRIP | **PASS** | `run_tool posit {golden:true}` → `run_id=posit-20260709_142657_413078-23776`; `get_run {run_id}` returned the stored record with the **same** `declared_blake2b == 7a22dd22…0e44` == frozen posit hash |

## Key measured values

- mcp frozen declared hash: `174ec02d134acafd28a99b45db1f5c5c2544f5e1669137c846273e6e55998822` — reproduced 2× cold and recomputed independently from the envelope text.
- posit chain hash via mcp AND via direct run AND frozen file: `7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44` (three-way agreement).
- ratchet live-drive declared hash (mcp vs my direct recomputation): `c0ccce4c76376952650817e1abed5c88ac8d4fe9c95172f302df427d4e482223` (two-way agreement, novel params).
- Exit codes observed: harness 0; golden 0,0; semantics battery 2/2/0/2; all `--once` protocol calls 0; `--serve` 0 on clean EOF.

## Defects found

**None.** One neutral observation (not a defect): `list_tools` returns 7 registry entries — the six v1 tools plus `mcp` itself — because the contract specifies a *live* registry scan of `tools/*/MODULE.md`; the golden's registry gate is over the fixed v1 six, so this does not and cannot drift the golden.

## Verdict

**CONFORMANT** — 10/10 checks PASS. The artifact honors its contract (CLI modes, exit-code semantics, JSON-RPC protocol behavior, schema-exact envelope), reproduces its frozen golden byte-identically, computes (not stamps) the D-013 declared-object hash, and carries the I-12 citation chain end-to-end through a real subprocess to posit's frozen golden — verified by independent recomputation on both the golden path and a novel live-drive path.
