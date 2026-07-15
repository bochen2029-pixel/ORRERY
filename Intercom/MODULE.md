# MODULE — ORRERY Intercom

**Purpose.** An ASIC coordination bus so ORRERY subagents run tournament-style experiments and
converge against an executable ORRERY oracle with no human relaying. Not a general agent bus — soldered
to the ORRERY catalogue. Contract: [INTERCOM.contract.md](INTERCOM.contract.md) (authoritative).

**Language: Python (D-005 / D-034).** Justified: pure orchestration/glue/accounting — SQLite, JSON,
subprocess. No compute, no RNG in the declared path. Matches its siblings `orrery` / `mcp` / `autotune`,
and — critically — it **imports `tools/mcp/mcp.py`** (`do_run_tool`, `blake2b_hex`, `registry_scan`),
so the I-12 declared-hash chain and exit-class tri-state are inherited, not re-implemented (the D-020
"one place for the doctrine" principle; the D-033 reuse-not-reimplement pattern).

**Location.** `C:\ORRERY\Intercom\` (a sibling of `tools/`, `lib/`, `harness/` — infrastructure, like
the bus it descends from, not a `tools/<name>/` science tool). Therefore it is NOT auto-discovered by
`harness/verify.py`; its gates run standalone: `python intercom.py --selftest` / `--golden`.

## Invariants
- The falsifier is an ORRERY tool run by the **coordinator**; the proposer never self-scores (the
  anti-confabulation split, RAYFORMER's lesson).
- Exit tri-state preserved: 0 pass · 1 a real declared negative · 2 error; error/timeout ⇒ INVALID,
  excluded from convergence (NOT a zero score).
- Pre-registration mandatory (`--hypothesis` + a pinned falsifier) — the register holds the doubt.
- Every candidate carries its declared blake2b; a converged champion emits an ORRERY result.lock.
- The firewall is stamped verbatim into every goal/converged/lock body: **sims prove STRUCTURE, never
  ACQUAINTANCE (qualia); §III-sealed.**

## Internal design
- **`orrery_falsifier(run, params)`** — the heart. `mcp.do_run_tool` → score from the declared object
  by mode (golden hash-match | target metric-vs-pre-registered-target | gate-must-not-fire). Tri-state
  → INVALID on error/timeout/missing-field.
- **converge** (`converge_runs`/`candidates`/`branches`) — MCTS champion + UCB1 arm scheduling, the
  verifier-driven convergence borrowed from `C:\everywhere\Intercom` v0.2.0-exp and re-wired to the
  ORRERY oracle. **rounds** (`runs`/`messages`) — the barrier design-tournament from v0.1.1, with the
  ORRERY refuter lenses (determinism / resolvability / oracle-honesty / **blindness**-D-028).
- **bus** — SQLite WAL, append-only `messages`, cursor-in-DB (survives compaction), alea ids.
- **graveyard** (reinstatement-trigger-gated), **leases** (build/GPU locks; expire, steal-on-expiry),
  **lock** (result.lock emission to `runs/intercom_<run>.result.lock`).

## Build / run
```
python C:\ORRERY\Intercom\intercom.py --selftest      # 12 checks (falsifier modes, tri-state, pre-reg, converge, determinism, lock, bus, arm)
python C:\ORRERY\Intercom\intercom.py --golden        # freeze/verify the posit-golden-match scenario -> blake2b fb722929...
python C:\ORRERY\Intercom\intercom.py arm             # print the hardwired ORRERY arming block for a subagent
```
Golden: `goldens/intercom/declared.hash` = `fb722929cde142b8ebd5f9f2baf1203bce50fb8df92068eb44f91cf942411c84`
(re-baselines with `posit`; a posit rebuild that changes its declared hash re-baselines this — correct).

## Known issues / deferred (see NOTES.md)
- **The doorbell** (no push): agents see messages only when they `poll`. A Claude Code `Stop`-hook or a
  `-wal` watcher is the wake mechanism — deferred (as in the reference).
- **Two-tier verifier** (a cheap LLM-judge prior before spending the expensive falsifier / EVOI) — not
  built; today every `propose` runs the full falsifier (fine, and the R-5 run-cache dedups repeats).
- **`orrery run --cache` integration** — the falsifier goes through `mcp.do_run_tool` directly; wiring
  the content-addressed cache so fan-outs stop re-paying identical runs is a clean MINOR.
- Compiled single-binary client (cold-start win on the hook path) — deferred; the protocol is the
  product, the client is swappable.

*Structure, never acquaintance. The judge is a golden; the register holds the doubt.*
