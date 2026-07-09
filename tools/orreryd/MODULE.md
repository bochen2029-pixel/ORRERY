# MODULE — `orreryd`

*The GPU-tenancy job daemon (surface #2 of D-022). Read `contracts/orreryd.contract.md` (v0.1.0) first — the contract is authoritative.*

**Status: DONE v0.1.0** — built, golden frozen, selftest green, cold two-pass per RUN_STATE.

## Purpose
A headless **file-spool serializer**: callers drop job JSON files into `<spool>/pending/`; the daemon claims them in lexicographic order and runs the catalogue tools **one at a time** (one GPU tenant, FIFO) under per-job wall-clock budgets (timeout → kill → `exit_class:"timeout"` — the TDR/B11 discipline at process level), honoring `.stop`/`.DONE` sentinels and atomically rewriting `status.html`/`status.json` at every transition (the buddhabrot unattended-run pattern). Every job record embeds the D-013 declared-object blake2b + artifact blake2b (**I-12**).

## SCOPE GUARD (sacred — the §III firewall)
**A scheduling/orchestration surface; it computes nothing scientific itself and says nothing about qualia — §III-sealed.** Emitted verbatim in the JSON `notes`. The §2 split is preserved absolutely: `orreryd` **subprocesses the sacred executables** — never links tool internals, never reimplements a computation, never grows its own copy of a tool's parameter law.

## Contract
`contracts/orreryd.contract.md` v0.1.0 (+ `contracts/orreryd.schema.json` — covers the tool's own `--json`/`--golden` envelope; job records and status files are operational, specified in the contract). Versioned 0.x deliberately: the spool/job interface may evolve before a 1.0 freeze; the envelope/golden discipline is already at full standard.

## Provenance
D-022 (Active). The unattended-run doctrine (sentinels, status page, budgets) is the buddhabrot campaign pattern (B7/B11 lineage; D-024 imports the rest when adopted). **First new-tool consumer of `lib/` (liborrery, D-020)** — the envelope spine (blake2b, serializers, golden plumbing, CLI helpers) is inherited, not copied.

## v0 scope (deliberate; documented exclusions)
Process-level serialization ONLY. Out of v0: in-process CUDA-stream tenancy (meaningless for subprocess tools — waits for a daemon-hosted tool mode with a real demand), the HTTP API (D-022 v2), an mcp `enqueue` tool (later MINOR bump), multi-tenant scheduling (premature per D-022's own ruling: one queue, one tenant, FIFO).

## Internal design (as built)
- **C++20, no threads**: the poll loop is the scheduler; the per-job `WaitForSingleObject(hProcess, budget_ms)` is the watchdog. Status updates happen at transitions (idle→running→idle), atomically via write-tmp + `MoveFileEx(REPLACE_EXISTING)`.
- **Spool protocol**: claim = atomic rename `pending/X.json → running/X.json` (a failed rename means a producer is mid-write — skip this poll; **producers must write-then-rename into `pending/`**). Record → `done/X.result.json`; the raw tool envelope is embedded verbatim as the `envelope` value (JSON-in-JSON, lossless). Malformed jobs and unknown tools become `error` records — the queue never stalls or crashes.
- **Subprocess (Win32)**: `CreateProcessA` with stdout/stderr redirected to temp files in the spool, optional stdin from a temp file (`stdin_json`), `cwd` = the tool's directory, absolute artifact paths; Python tools run as `python <abs>.py …` (PATH-resolved, same as the harness). Timeout → `TerminateProcess` → class `timeout`.
- **Minimal JSON parser** (recursive-descent, ~130 lines, KAT-gated in the selftest): objects preserve key order (vector of pairs) so argv construction is deterministic given the job file bytes. Standard escapes incl. `\uXXXX` (BMP → UTF-8).
- **liborrery**: `blake2b_hex`, `fmt6`/`fmti`/`jesc`, `read_golden_hash`, `golden_check`, `die2`/`parse_ll`, `st_check` — all from `lib/envelope.h`; declared extraction is the same textual `"seed":`…`,"notes":` rule as mcp (exact, because the envelope key order is lib-pinned).
- **The canned drain** (`--json`/`--golden` body): a fresh local temp spool `_golden_spool_<pid>/` (removed afterwards) with three fixed jobs — `j1` posit `--golden`, `j2` unknown tool (must become `error` and not stall), `j3` posit `--golden` — run through the REAL drain loop; declared result = counts, order, exit classes, the I-12 chain hash vs posit's frozen golden, and the `.DONE` sentinel. Same deliberate narrow posit coupling as mcp (re-baseline protocol in `goldens/orreryd/NOTE.md`).

## Determinism approach
No RNG; `--seed` inert. `--json`/`--golden` declared output byte-identical given the repo at a commit. Non-declared: timestamps, durations, spool paths, status files (operational UI). Daemon-mode ordering is deterministic (lexicographic FIFO, single tenant); its record *contents* carry non-declared timing fields.

## Selftest (11 checks; a few seconds — posit subprocess is ms-fast)
blake2b KAT · JSON-parser KATs (escapes, numbers, malformed→reject) · declared-extraction KAT · argv/cmdline builder KATs (bool flag, valued flag, uppercase `--R`-style key, bad key rejected, spaced-path quoting) · registry resolution (posit, ratchet; unknown→null) · end-to-end mini-drain (2 posit jobs → both `pass`, order ok, `.DONE`, chain hash == frozen posit) · error-continuation (`[pass,error,pass]`) · `.stop` honored (pre-dropped sentinel → exit without running the pending job; sentinel deleted) · malformed job → `error` record, queue continues · status.json written+parseable · determinism (canned-drain declared twice, byte-identical).

## Golden
`orreryd.exe --golden` → the canned 3-job drain. Frozen in `goldens/orreryd/` (declared.hash + stdout.txt + NOTE.md), 3× byte-identical at freeze. `result.lock` in `runs/orreryd_golden.result.lock`.

## Build
C++20 host-only (no CUDA), on liborrery, via MSVC (fenced block — harness rule):
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && cl /nologo /O2 /std:c++20 /EHsc orreryd.cpp ../../lib/envelope.cpp /Fe:orreryd.exe'
```
Then: `.\orreryd.exe --selftest` · `.\orreryd.exe --golden` · `.\orreryd.exe --spool RUNDIR --daemon [--drain]`.

## Known issues / caveats
- Paths are handled via the ANSI Win32 APIs — keep spool/repo paths ASCII (true for `C:\ORRERY`; documented, not enforced).
- One daemon per spool is assumed (single tenant is the point); running two against one spool is unsupported (claims won't corrupt — rename is atomic — but budgets/serialization guarantees are per-daemon).
- Producers that copy files directly into `pending/` (instead of write-then-rename) can race the claim; the daemon skips unclaimable files until the next poll, so the failure mode is a delay, not corruption.

*Sims prove structure, never acquaintance. The daemon serializes the instrument; it never becomes one of the tools it runs.*
