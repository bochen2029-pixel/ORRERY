# ORRERY Intercom — implementation notes / log

## 2026-07-14 — v1.0.0 shipped and green [Opus 4.8]

Built the ASIC coordination bus inside `C:\ORRERY\Intercom`, tailored ONLY to ORRERY. Operator brief:
"take the best of both/all worlds (`C:\Intercom` v0.1.1 + `C:\everywhere\Intercom` v0.2.0-exp) but
implement a version that is strictly better FOR ORRERY — ASIC specialization, not generalized; borrow
code/ideas, don't reinvent the wheel."

### What was borrowed vs. what was specialized
- **Borrowed wholesale (plumbing):** SQLite-WAL bus, alea ids, cursor-in-DB, append-only `messages`,
  the barrier `rounds` tournament, the converge/MCTS-champion/UCB1-schedule machinery.
- **The ASIC specializations (the point):**
  1. **The falsifier IS an ORRERY contract, coordinator-run.** `orrery_falsifier` imports
     `tools/mcp/mcp.py` `do_run_tool` (the D-033 reuse pattern) → derives the score from the tool's
     DECLARED output. Three modes: `golden` (declared-hash match — the two-pass/reproduction judge),
     `target` (a declared metric vs a pre-registered target+tol — autotune's discipline), `gate` (a
     named gate must not fire). The proposer submits **params**; the **coordinator** runs the tool and
     scores. An agent can never self-score a tool-backed run.
  2. **Exit tri-state preserved (0/1/2), never collapsed.** An error/timeout candidate is **INVALID**
     (excluded from convergence stats), not a zero score — the ASIC-correct behavior the generic bus
     gets wrong (it collapses any nonzero exit to 0.0).
  3. **Pre-registration mandatory:** `converge-open` refuses without `--hypothesis` + a pinned
     falsifier (the hsmi-stab / D-028 lesson; the P9 random-control false sector-arrow is why).
  4. **Provenance first-class:** every candidate carries `declared_blake2b · exit_class · params ·
     seed · metric_value`; a converged champion emits an ORRERY `result.lock` (`lock` verb, D-008).
  5. **The firewall** is stamped verbatim into every goal/converged/lock body (§III-sealed).
  6. **The graveyard** refuses a burial without a reinstatement trigger (reversibility as discipline).
  7. **`arm`** prints the hardwired ORRERY 12-tool calling block + the cite-the-blake2b-or-flag rule.
- **Dropped (deliberately, as un-ORRERY generalization):** cross-harness routing, multi-machine
  bridge, the pluggable `SCORE=` shell falsifier, generic capability advertising. ORRERY is one
  machine, one GPU tenant (orreryd arbitrates it), a fixed catalogue. Kept a *specialized* lease for
  build/GPU locks only.

### Verified (this session)
- **`--selftest` 12/12 PASS**: mcp-reuse KATs; falsifier golden-match (posit → 1.0, hash==frozen);
  golden-mismatch → reject (a real negative, not an error); tri-state (bad input → INVALID, score
  None); pre-registration refusal (registered agent, no --hypothesis → exit 2); full converge loop +
  determinism (byte-identical declared object across two runs); CONVERGED on the champion reproducing
  posit's golden; INVALID excluded (invalid==1, no_improve==k); result.lock carries the hash + firewall;
  bus round-trip; arm block.
- **`--golden` 3× byte-identical** → `fb722929cde142b8ebd5f9f2baf1203bce50fb8df92068eb44f91cf942411c84`
  (posit-golden-match converge scenario; re-baselines with posit).
- **Live end-to-end through the real CLI** (posit golden mode): init → join(coordinator+subagent, alea
  ids) → converge-open(pre-registered) → propose ×4 [INVALID decoy excluded; {golden:true} champion;
  converge at k=2] → champion/board → `lock` with full provenance. Clean.
- **Live GPU target-mode** driving real `ratchet` runs: search rho for `p_unwrite_mc≈0.6`; rho=0.30 hit
  it (score 1.0, champion — the pre-registered hypothesis held), rho=0.40 graded 0.11 (search
  gradient), 0.50/0.70 rejected — each candidate its own distinct declared blake2b from a real GPU run,
  all scored by the coordinator from declared output.

### One bug caught + fixed pre-commit
`converge-open`'s `fdesc` dict evaluated all three mode f-strings eagerly; the golden branch did
`a.expect_hash[:12]` → `None[:12]` TypeError in target mode. Guarded with `(a.expect_hash or '')`.
(The selftest golden path never hit it — the live GPU target-mode smoke did. Same value as `mcp`/
`orreryd`'s pre-commit smokes catching real defects.)

### Not done yet (ranked; deferred)
1. **The doorbell** — no push; agents `poll`. Claude Code `Stop`-hook (drain + inject) or a `-wal`
   watcher. The one missing piece for true real-time collab.
2. **`orrery run --cache` in the falsifier** — dedup identical fan-out runs (R-5). Clean MINOR.
3. **Two-tier verifier** — a cheap LLM-judge prior before the expensive falsifier (EVOI).
4. **First real use:** drive `carve`'s design tournament (rounds, the D-028 blindness lens wired in),
   then its converge run once a candidate functional exists — the make-or-break Wave-1 gear this was
   built to serve. Also: an autonomous N-way cold two-pass (converge, golden mode, roster = cold
   rebuilders) as a stronger anti-RAYFORMER check.

*The judge is a golden; the proposer never scores itself; the register holds the doubt; structure,
never acquaintance.*
