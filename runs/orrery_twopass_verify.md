# orrery — two-pass cold-context verification

**Date:** 2026-07-13
**Verifier:** independent cold-context two-pass (ARCHITECTURE.md §9); adversarial; no memory of build
**Repo HEAD:** `75cd439378937268c6284677df78ea60d9b3782a`
**Tool:** `tools/orrery/orrery.py` (Python CLI over the catalogue; reuses `tools/mcp/mcp.py`)
**Contract:** `contracts/orrery.contract.md` v1.0.0 · **Schema:** `contracts/orrery.schema.json`

## OVERALL VERDICT: CONFORMANT to v1.0.0

All 11 mandated checks pass. Golden reproduced byte-identical 3×. The declared hash is
**recomputed, not stamped**. The I-12 receipt chain through the CLI is **genuine** (verified
end-to-end against a direct posit run that bypasses orrery+mcp entirely). The `mcp` reuse is
**genuine** — orrery contains zero spawning/hashing logic of its own. No defects.

Note (not a defect): the `orrery` tool tree is untracked (`?? tools/orrery/`, `?? contracts/orrery.*`,
`?? goldens/orrery/`) — expected for a fresh pre-commit build under verification.

---

## Per-check results

### 1. BUILD — PASS
`python -m py_compile tools/orrery/orrery.py` → exit 0, clean (no syntax/compile errors).

### 2. GOLDEN (CRITICAL) — PASS
`python tools/orrery/orrery.py --golden` run **3×**:
- Every run: exit 0, stderr `GOLDEN OK blake2b=439771854c718fd460a2282c49f763856564c807455c74bc3b25531e289141c0`.
- stdout sha256 identical across all 3 runs (`b8c48ed7…`), and `diff` byte-identical.
- stdout matches frozen `goldens/orrery/stdout.txt` exactly (`MATCHES_FROZEN_STDOUT`).
- Reproduced hash == frozen `goldens/orrery/declared.hash` = `439771854c718fd460a2282c49f763856564c807455c74bc3b25531e289141c0`.

### 3. ANTI-STAMP — PASS (hash computed, not stamped)
Ran `orrery --json`, extracted `{seed,params,result,gates,verdict}`, independently re-serialized
(D-013 domain; tool/version/notes excluded) and hashed with an independent `hashlib.blake2b(digest_size=32)`.
- INDEPENDENT_HASH = `439771854c718fd460a2282c49f763856564c807455c74bc3b25531e289141c0`
- == FROZEN → `ANTI_STAMP_MATCH = True`. Confirmed `tool`/`version`/`notes` present in envelope but excluded from the hashed domain.

### 4. THE I-12 CHAIN THROUGH THE CLI — PASS (genuine)
`orrery run posit --golden`:
- stdout = posit's real declared envelope (case `seed_cluster`, verdict `pass`).
- stderr: `[orrery] exit_class=pass  declared_blake2b=7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44  artifact_blake2b=0f27f736…`
- `declared_blake2b` == posit's frozen golden `goldens/posit/declared.hash` = `7a22dd22…`.
- **End-to-end anti-fake:** ran `posit --golden` DIRECTLY (bypassing orrery+mcp), sliced its declared
  object, hashed independently → `7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44` == frozen.
  The chain reproduces the exact receipt an agent would cite, from the tool's live stdout — not a copied constant.

### 5. R-3 VERIFY BOTH WAYS — PASS
- `orrery verify posit --golden --expect-hash 7a22dd22…9e6f5a20e44` → `MATCH  tool=posit  got=7a22dd22…  expect=7a22dd22…`, **exit 0**.
- `orrery verify posit --golden --expect-hash 0000…(64 zeros)` → `MISMATCH  tool=posit  got=7a22dd22…  expect=0000…`, **exit 1** (a finding, NOT error 2). Confirmed exit 1, not 2.

### 6. R-1 SUBCOMMANDS — PASS
- `orrery list` → 12 tools (>=11), table incl. `someone v1.2.0` (golden `aa5b731d…`), `shoot` (`9625b268…`), `lens v1.1.0` (`11e545b8…`), plus algebra/autotune/hsmi-stab/mcp/orrery/orreryd/mcts/posit/ratchet. Exit 0.
- `orrery describe posit` → posit's `schema.json` verbatim (with blake2b `36d88785…`) + contract.md verbatim; 10872 bytes. Exit 0.
- `orrery describe no-such-tool` → `error: unknown tool 'no-such-tool'`, exit 2.
- `orrery run no-such-tool` → `error: unknown tool 'no-such-tool' (not in the registry)`, exit 2.
- `orrery frobnicate` (bad command) → usage + exit 2.
- `orrery` (no args) → usage + exit 2.

### 7. R-2 mcp-register — PASS
`orrery mcp-register` prints:
- `claude mcp add orrery -- python "C:\ORRERY\tools\mcp\mcp.py" --serve`
- MCP-config JSON (`{"mcpServers":{"orrery":{"command":"python","args":["…mcp.py","--serve"]}}}`)
- names six tools: `list_tools, describe_contract, run_tool, get_run, sweep, golden_status`. Exit 0.

### 8. REUSE (adversarial) — PASS (genuine, not reimplemented)
Read `tools/orrery/orrery.py` and `tools/mcp/mcp.py`:
- orrery.py line 23 `import mcp`; calls `mcp.registry_scan`, `mcp.do_run_tool`, `mcp.do_describe_contract`,
  `mcp.do_sweep`, `mcp.blake2b_hex`, `mcp.read_first_token`, `mcp.V1_CATALOGUE`, `mcp.jstr`, `mcp.fmt6`.
- grep for `subprocess|hashlib|def blake2b|def extract_declared|def do_run_tool|def registry_scan|def do_describe_contract|def do_sweep` in orrery.py → **No matches**. orrery has NO spawning/hashing of its own.
- The I-12 `declared_blake2b` originates inside `mcp.do_run_tool` (mcp.py:154): it `subprocess.run`s the real
  tool (:171), `extract_declared`s the declared sub-object from live stdout (:195), `blake2b_hex`es it (:197),
  returns `rec["declared_blake2b"]` (:209). orrery's `_run_record`/`do_verify` merely consume that field.
- **Verdict: the I-12 chain is genuine — the hash is recomputed from the tool's real output, not copied.**

### 9. SCHEMA — PASS
Validated `orrery --json` against `contracts/orrery.schema.json` with `jsonschema` 4.26.0 (Draft7):
`SCHEMA_VALID = True`. Adversarially injected an extra key → rejected (`additionalProperties:false` enforced).

### 10. SELFTEST — PASS
`orrery --selftest` → exit 0, `SELFTEST PASS`; all 9 checks PASS incl. blake2b KAT (via mcp),
collect_params KATs, v1-registry completeness, `describe posit` schema const, verify-BOTH-ways
(MATCH on frozen / MISMATCH on wrong), self-check verdict==pass, and determinism (two self-checks byte-identical).

### 11. HYGIENE / FIREWALL — PASS
Envelope `notes` (and contract/MODULE) carry the §III-sealed firewall verbatim: *"A transport/orchestration
CLI surface: it computes nothing scientific and says nothing about qualia - III-sealed. It calls the sacred
executables and serves their contracts verbatim."* Language justification (D-005: pure IPC bookkeeping) present.

---

## Reproduced golden hash
`orrery` declared blake2b-256 = **`439771854c718fd460a2282c49f763856564c807455c74bc3b25531e289141c0`** (== frozen)
`posit` chain hash (I-12) = **`7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44`** (== frozen)

## Incidental observation (NOT a defect)
`orrery list` reports `ratchet` at contract version 1.0.0 (from `contracts/ratchet.contract.md`), but the
running `ratchet.exe` emits `"version":"1.0.1"` in its envelope. This is ratchet's own internal versioning
surfaced through orrery's transparent pass-through — orrery serves whatever the executable emits and does not
gate on it; ratchet's contract governs. Flagged for the ratchet owner, out of scope for orrery.

## Checks passed: 11 / 11 — CONFORMANT to orrery v1.0.0
