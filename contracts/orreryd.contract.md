# orreryd — Contract  v0.1.0

## Purpose
The **GPU-tenancy job daemon** (D-022, second surface): a headless file-spool serializer that runs catalogue tools **one at a time** (one GPU tenant, FIFO) under per-job wall-clock budgets, with `.stop`/`.DONE` sentinels and an atomically-updated `status.html`/`status.json` — the unattended-run harness (buddhabrot pattern) for campaigns and long sweeps. **The sacred CLI executables remain the contract of record; `orreryd` is a *caller* (subprocess), never a replacement.** Per **I-12**, every job record embeds the D-013 declared-object blake2b + the artifact blake2b.

**Scope guard:** a scheduling/orchestration surface; computes nothing scientific itself and says nothing about qualia. §III-sealed.

**Language:** C++20 (D-022) on **liborrery** (`lib/envelope.h` — blake2b, canonical serializers, golden plumbing, CLI spine). No CUDA in the daemon itself (it spawns exes); no RNG.

**v0 scope (deliberate):** process-level serialization only. Explicitly OUT: in-process CUDA-stream tenancy (meaningless for subprocess tools; waits for a daemon-hosted tool mode), the HTTP API (D-022 v2), mcp↔orreryd integration (a later MINOR bump), multi-tenant scheduling (premature per D-022).

## The spool (the operational interface)
```
<spool>/pending/<job>.json     caller drops jobs here; processed in LEXICOGRAPHIC filename order
<spool>/running/<job>.json     the claimed job (exactly 0 or 1 file; claim = atomic rename)
<spool>/done/<job>.result.json the job record (see below)
<spool>/status.json + status.html   rewritten atomically (tmp+rename) at every transition
<spool>/.stop                  operator sentinel: finish the current job, write status, exit 0 (deleted on acknowledge)
<spool>/.DONE                  written by --drain when pending empties (campaign-complete marker)
```
**Job file** (same shape as mcp's `run_tool` arguments): `{"tool":str, "params"?:{flag→value}, "stdin_json"?:any, "timeout_s"?:num≤3600}`. Param keys `^[A-Za-z0-9-]+$`; boolean `true` → bare flag; `--json` forced unless `golden`/`selftest` present; the tool's own contract enforces ranges. A malformed job becomes an `error` record — it never crashes or stalls the queue.

**Job record:** `{job, tool, argv, exit_code, exit_class: pass|gate-fired|error|timeout, envelope, declared_blake2b, artifact_blake2b, stderr_tail, duration_s°, started°, finished°}` (° = non-declared).

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --spool DIR | path | | (required for --daemon) | spool root (subdirs created if absent) |
| --daemon | flag | | off | run the queue loop (watch mode: poll forever until `.stop`) |
| --drain | flag | | off | with `--daemon`: exit 0 and write `.DONE` when pending empties |
| --poll-ms | int | 50–60000 | 500 | pending-scan interval in watch mode |
| --budget-s | int | 1–3600 | 900 | default per-job wall-clock budget (a job's `timeout_s` may override, ≤3600) |
| --seed | int | ≥0 | 0 | inert (no RNG; envelope uniformity) |
| --json | flag | | off | one-shot **canned drain** (the golden body, in a fresh temp spool) → envelope on stdout |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | canned drain at golden params; hash vs `goldens/orreryd/`; exit 0/1 |

Exactly one of `--daemon | --json | --selftest | --golden`.

## Output (`--json`/`--golden` envelope `result` fields — the canned drain)
Three fixed jobs in a fresh temp spool: `j1` = posit `--golden` · `j2` = unknown tool (**must** become an `error` record and NOT stall the queue) · `j3` = posit `--golden` again.
| field | type | meaning |
|---|---|---|
| jobs_submitted | int | 3 |
| jobs_completed | int | records written to done/ (must be 3) |
| order_ok | bool | processed exactly j1, j2, j3 (lexicographic FIFO proof) |
| exit_classes | array[str] | per job, in order — must be `["pass","error","pass"]` |
| chain_declared_blake2b | str (64 hex or "") | j1's declared hash through the generic subprocess path |
| chain_matches_frozen | bool | == `goldens/posit/declared.hash` (the I-12 chain proof) |
| done_sentinel | bool | `.DONE` written when the drain emptied |

Params echoed: `{chain_tool:"posit", jobs_submitted:3, budget_s:120}` (fixed constants in v0.1.0).

## Gates (declared negative-result conditions → exit 1)
| id | fires when | value |
|---|---|---|
| G-CHAIN-MISMATCH | j1 or j3 not `pass` with the frozen posit hash | count of chain jobs wrong (thr 0) |
| G-DRAIN-INCOMPLETE | jobs_completed ≠ 3, order violated, j2 not `error`, or `.DONE` missing | 1.0 fired / 0.0 (thr 0) |

## Exit codes
`0` pass / clean daemon exit (`.stop` honored or `--drain` complete) · `1` a gate fired (canned-drain drift — a real finding) · `2` error (bad CLI, spool unreachable, posit artifact missing). Job failures are **records**, not daemon exits.

## Determinism
No RNG; `--seed` inert. `--json`/`--golden` declared output is **byte-identical** given the repo at a commit (the same deliberate narrow posit coupling as mcp — see Golden). Daemon-mode behavior is deterministic in *ordering* (lexicographic FIFO, one tenant) but its records carry non-declared timestamps/durations; `status.*` files are entirely non-declared (operational UI).

## Golden
params: `orreryd.exe --golden`  (the canned 3-job drain; fresh temp spool; fixed job names; no timestamps in declared)
recorded: `goldens/orreryd/` (declared.hash + stdout.txt + NOTE.md). Hash domain = D-013.
**Golden coupling:** same protocol as mcp (`goldens/mcp/NOTE.md`): deliberately coupled to posit's frozen golden — narrowest exact no-GPU chain. If posit re-baselines under review, orreryd re-baselines in the same operator-signed commit. Catalogue growth cannot break this golden (fixed canned jobs, not a live registry check).

## Change log
- v0.1.0 — initial contract (D-022 v0 scope: file-spool serializer — queue + budgets + sentinels + status page). Versioned 0.x deliberately: the daemon's spool/job interface may still evolve before a 1.0 freeze; the envelope/golden discipline is already at full standard.
