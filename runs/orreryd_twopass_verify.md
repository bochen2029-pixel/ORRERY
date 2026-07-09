# orreryd v0.1.0 — cold-context two-pass verification

- **Date:** 2026-07-09 (verification run ~14:46–14:55 local)
- **Agent:** independent cold-context subagent (no knowledge of the build session)
- **Blind protocol honored:** did NOT read `tools/orreryd/orreryd.cpp` (exe treated as an opaque artifact, execute-only). Did NOT use `tools/orreryd/MODULE.md` design claims as evidence — read ONLY its fenced `## Build` command (lines 39–44), per the harness rule. Trusted only: `contracts/orreryd.contract.md` v0.1.0, `contracts/orreryd.schema.json`, `contracts/README.md`, `goldens/orreryd/` (declared.hash, stdout.txt, NOTE.md), `goldens/posit/declared.hash`, and observed behavior.

## Battery

| # | test | verdict | measured |
|---|------|---------|----------|
| 1 | HARNESS `python harness/verify.py --tool orreryd` | **PASS** | build=OK selftest=OK golden=OK, OVERALL: GREEN, exit 0 (report `runs/verify_20260709_144617.md`) |
| 2 | COLD REBUILD from source via fenced MODULE.md command, then `--golden` on the rebuilt exe | **PASS** | MSVC build exit 0 (fresh exe 430080 B, 14:46:41); `--golden` exit 0, stderr `GOLDEN OK blake2b=86f133bb0a676ce7f3f7737aaa30eb46567371cf468bf8c7c5377b123e1b3ef8` == frozen `goldens/orreryd/declared.hash` |
| 3 | GOLDEN REPRODUCTION (`--golden` ×2, raw-byte capture) | **PASS** | run1 == run2 == frozen `stdout.txt`: all three SHA256 `255EC0D2ADA036D2DA683BE54F1BA32F88CA9193D747C737BBBCB620D6873551`, 822 bytes; stderr `GOLDEN OK` both runs |
| 4 | SCHEMA CONFORMANCE (hand-validated, no jsonschema lib) | **PASS** | exactly the 8 required top-level keys, no extras at any level (top/params/result/gates); `tool=="orreryd"`, version `0.1.0` semver, seed 0 ≥ 0; params `{chain_tool:"posit", jobs_submitted:3, budget_s:120}`; gates exactly `[G-CHAIN-MISMATCH, G-DRAIN-INCOMPLETE]` with id/fired/value/threshold only; verdict `pass`; `exit_classes == ["pass","error","pass"]` |
| 5 | HASH DOMAIN (computed-not-stamped) | **PASS** | `{"seed":…}` substring (506 chars, `"seed":` → before `,"notes":`) blake2b-256 (hashlib, digest_size=32) = `86f133bb0a676ce7f3f7737aaa30eb46567371cf468bf8c7c5377b123e1b3ef8` == frozen declared.hash |
| 6 | EXIT CODES | **PASS** | (a) no mode → 2 (`error: exactly one of --daemon \| --json \| --selftest \| --golden`); (b) `--daemon` no `--spool` → 2 (`error: --daemon requires --spool DIR`); (c) `--drain --json` → 2 (`error: --drain requires --daemon`); (d) `--json` → 0. Clean one-line errors, no crashes/tracebacks |
| 7a | SPOOL FIFO + records (a1 posit-golden, a2 `__bogus__`, a3 posit-golden; `--daemon --drain`) | **PASS** | drain exit 0; done/ has exactly 3 `.result.json`; a1/a3 `exit_class:"pass"` with `declared_blake2b=7a22dd229a42ce46a6c102f0545f83022b975dc39d5f1794cd6019e6f5a20e44` == frozen posit hash; a2 `exit_class:"error"`, `error_reason:"unknown tool '__bogus__' (not in the registry)"`; `.DONE` present; `status.json` parses, `state:"drained"`; `status.html` present |
| 7b | I-12 independence (my own `python tools/posit/posit.py --golden`) | **PASS** | independently computed declared blake2b `7a22dd22…0e44` — three-way agreement: my run == frozen `goldens/posit/declared.hash` == daemon records a1/a3 |
| 7c | BUDGET KILL (ratchet 3e9 trials, `timeout_s:2`) | **PASS** | drain exit 0; record `exit_class:"timeout"`, exit_code 258, `duration_s=2.078` (within ~2–10 s) |
| 7d | `.stop` sentinel (watch mode, pre-created `.stop`, pending posit job, NO `--drain`) | **PASS** | daemon exit 0 in **0.06 s**; `pending/s1.json` still present (job NOT run, done/ empty); `.stop` deleted; stderr `orreryd: .stop honored, exiting` |
| 8 | LIVE GPU JOB (ratchet 200k trials, seed 42) | **PASS** | record `exit_class:"pass"`, exit_code 0; `envelope.result.p_unwrite_mc=0.12623` (|Δ| from 0.125 = 0.00123 ≤ 0.01); `artifact_blake2b=67e306a942069c34fea77659dd0f57a13faa65c9392b28b83e1a7db5bc7b7a19` (64 hex) |
| 9 | SCOPE / FIREWALL | **PASS** | `--golden` notes contain "computes nothing scientific" + "III-sealed" (and "says nothing about qualia"); `goldens/orreryd/NOTE.md` has "DELIBERATE COUPLING" section naming posit with the "same operator-signed commit" re-baseline protocol |
| 10 | DETERMINISM (`--json` ×2) | **PASS** | declared substrings byte-identical; both hash to `86f133bb…3ef8` == frozen golden; full stdout also byte-identical |

## Defects found

None.

## Notes

- The daemon's `--json`/`--golden` canned drain, the live spool drains, the budget kill, and the `.stop` path all exited with the contract's declared codes; job failures were records, never daemon exits — exactly as `contracts/orreryd.contract.md` §Exit codes requires.
- The I-12 chain was verified through three independent paths (frozen file, daemon subprocess records, this agent's own posit run) — all `7a22dd22…0e44`.
- All temp spools (`_tp_spool`, `_tp_spool_kill`, `_tp_spool_stop`, `_tp_spool_gpu`) and scratch capture files were deleted after the battery. No repo file other than this report was modified.

## Verdict

**CONFORMANT** — 13/13 checks PASS (10 battery items; item 7 comprises 4 sub-tests).
