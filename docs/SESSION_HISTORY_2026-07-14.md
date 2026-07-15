# ORRERY — session memory / continuation (2026-07-14, −05:00)

**Written at save point `8dd4ad8` (pushed).** A comprehensive record of the 2026-07-14 session +
continuation pointer, structured by salience (prune from the bottom under pressure). **Trust the files
+ git over this narrative;** verify with `git log/status` and a tool's `--selftest`/`--golden` before
resuming. Canonical rehydration order stays: `CLAUDE.md` → `RUN_STATE.md` → `ARCHITECTURE.md` §5–§9 →
`DECISIONS.md` → this file. `SESSION_MEMORY.md` (2026-07-10) is older; RUN_STATE is current.

---

## ◉ CORE — where the instrument is now

- **14 golden-frozen tools** + `hsmi-stab` parked (no golden) + **ORRERY Intercom** (infrastructure).
  Wave 0 published (repo public + `/lab` live). **Wave 1's make-or-break trio is COMPLETE:** hsmi-stab
  PARKED (D-028 blindness, science-handback delivered), **trace-born** shipped (C-TRACE), **carve**
  shipped + cold-two-pass-verified (Layer-2/P2). Catalogue: someone · ratchet · algebra · posit · mcts ·
  autotune · mcp · orreryd · lens · shoot · orrery · trace-born · **carve** (+ Intercom).
- **All committed + pushed; tree clean at `8dd4ad8`.** github.com/bochen2029-pixel/ORRERY.
- **DOCTRINE (unchanged):** the spec is the product; the contract is sacred; the golden is load-bearing;
  the code is ephemeral. Every tool measures STRUCTURE, never ACQUAINTANCE (qualia); §III-sealed.
  Determinism or it doesn't ship. Exit 0 pass / 1 a declared negative / 2 error — never conflate.

---

## ● THIS SESSION'S ARC (7 commits: `53cc8f9` → `8dd4ad8`)

The operator surfaced four external precedents (generic Intercom `C:\Intercom` v0.1.1 +
`C:\everywhere\Intercom` v0.2.0-exp converge/router/scheduler; tournament corpora
`C:\the_brain\tournament` argument-judged + `C:\TinyUniverse\tournament\gamma` ORRERY-armed) and drove
a four-part build:

1. **ORRERY Intercom v1.0.0** (`C:\ORRERY\Intercom\`, D-034, `53cc8f9`) — an **ASIC coordination bus**,
   specialized to ORRERY, not general. The distinguishing move: **the falsifier IS an ORRERY tool
   contract, run by the coordinator, scored from the DECLARED output.** It **imports `tools/mcp/mcp.py`**
   (`do_run_tool`/`blake2b_hex`; the D-033 reuse pattern) so the I-12 hash chain + exit-class tri-state
   are inherited. Falsifier modes `golden`|`target`|`gate`; tournament modes `converge` (oracle-judged) +
   `rounds` (argument-judged design tournament, ORRERY refuter lenses incl. **D-028 blindness**). ASIC
   guards each an ORRERY law made mechanical: coordinator-run falsifier (agents never self-score),
   exit-tri-state preserved (error→INVALID not a zero), **pre-registration mandatory** (`converge-open`
   refuses without `--hypothesis`), provenance→`result.lock`, firewall stamped, graveyard needs a
   reinstatement trigger, `arm` = the hardwired 12-tool block. Dropped the generic parts (cross-harness
   routing, multi-machine bridge, `SCORE=` shell falsifier, capability ads). `--selftest` 12/12;
   `--golden fb722929` 3× byte-identical (posit-golden-match; re-baselines with posit; instant/no-GPU).
   `--set key=value` added (`5772694`) — the R-1 no-JSON lesson.
2. **First LIVE autonomous multi-agent tournament** (`ac86b8f`) — 3 real sonnet subagents, coordinating
   ONLY through the bus (reading a shared board), bisected to find rho≈0.315 where ratchet's
   `p_unwrite_mc`=0.50, judged by ratchet on the GPU, no human in the loop; CONVERGED at k=3 in 6
   proposals. Proof the bus works with real agents. `runs/intercom_live1_demo.*`.
3. **carve's design tournament** (`26c0b06`, `runs/carve_design/`) — the bus's intended purpose: choose
   carve's measurement functional BEFORE code. 4 design personas → 3 adversarial lenses (running live
   numpy). **It fired — caught PRE-CONTRACT the hsmi-stab failure mode:** a circular oracle
   (product-unitary planted scrambler leaves Pauli weight invariant → Φ-gap **0.0000**, verified) + a
   decaying raw score. Decision-ready `RECOMMENDATION.md` reconciled the lenses.
4. **carve v1.0.0** (`dd37df1`) + **cold two-pass CONFORMANT 2/2** (`8dd4ad8`). Built from the
   tournament's design: k-locality Pauli-weight concentration `Phi_k(H,U)` scored as a **GAP over the
   analytic Haar baseline** `B(N,k)=Σ_{w≤k}C(N,w)3^w/(4^N−1)` (kills the n-decay trap); k a supplied
   param (CPR); host C++ fp64 on liborrery, N≤6; greedy discrete-frame descent (mcts-subprocess deferred
   v1.1 — no caller-landscape hook). Oracle (I-11): `planted H=V H0 V†`, V an **on-lattice entangling**
   scrambler (non-circular AND recoverable — the blindness×resolvability reconciliation), metamorphic
   un-scramble `oracle_dev`<1e-9. `haar`→G-NO-BASIN (best_gap 0.023). Golden `1373454e` = ising positive
   control (best_gap 0.741176 = 1−66/255). Selftest 12/12; harness GREEN; **cold two-pass CONFORMANT 2/2
   via two isolated-worktree cold verifiers, 0 defects** (`runs/carve_twopass_verify.md`).

---

## ▪ KEY LEARNINGS (permanent)

- **The design tournament is the hsmi-stab antidote, and it works.** Running an adversarial,
  D-028-guarded functional-selection tournament BEFORE contract-freeze caught a circular oracle in an
  hour that would have cost weeks post-contract (exactly what parked the keystone). The pattern:
  N proposers → adversarial lenses (esp. BLINDNESS: check the functional against the identity list +
  the three-control gauntlet) → synthesize → operator gate. **Use it for any make-or-break functional.**
- **The anti-confabulation loop, autonomous.** Intercom's thesis = ORRERY's thesis: the proposer is
  stochastic (agents), the judge is deterministic (a golden/oracle run by the coordinator). Keep that
  split clean; it's what makes an autonomous swarm safe from RAYFORMER.
- **honest-scope shipping (algebra Part-A discipline).** carve v1's greedy search is honestly limited
  (recovers strong basins, not deep scrambles → exit 2 = search-too-weak, kept DISTINCT from exit-1
  no-basin). Shipping the honest limit + naming the v1.1 upgrade beats faking recovery.
- **fmt6 `%.6f` hash-domain floor:** sub-1e-6 params serialize to `0.000000` (both carve verifiers
  flagged `oracle_tol`). Inherent to D-013 canonical serialization; non-blocking; disclosed.
- **Build/verify gotchas (carried):** builds run from PowerShell (the `cmd /c …vcvars64…` line no-ops
  under bash); `.exe`/`.obj`/`.lib`/`.exp` are gitignored (only `.cu` + MODULE tracked); the cold
  two-pass via `isolation:"worktree"` agents is clean + genuinely independent (no clobber).

---

## ★ CONTINUATION — the fork now (operator-gated)

1. **Wave 2 (Phase 7)** — the D-026 order book continues: `ratchet-v2` (DP exponents) → `clifford/mipt`
   → `everpresent` (I-14 frozen DESI data) → `someone-v2` → `modfluc` (F-SEAM) → `fork` (F-BMV) →
   `prequent` → `algebra` v1.1. Each opens contract-first; **now with the design-tournament option** for
   any make-or-break functional (the carve pattern).
2. **carve v1.1** — the stronger search the honest v1 scope named: the `mcts`-subprocess integration
   (needs an `mcts` custom-landscape hook) or a continuous frame optimizer (Riemannian U(2^N) descent +
   convergence certificate); + the CUDA `4^N` kernel for N>6; + the deciding converge run to quantify the
   recovery boundary. Would upgrade `recovered` from "honest exit-2 on deep scrambles" to real recovery.
3. **Intercom next tier** — the doorbell (no push yet: a Claude Code Stop-hook or a `-wal` watcher to
   wake agents), `orrery run --cache` in the falsifier (dedup fan-outs), a two-tier LLM-judge→falsifier
   verifier, a one-command `campaign` driver. All deferred, all named in `Intercom/NOTES.md`.
4. **hsmi-stab** stays PARKED until the science answers the handback memo's §4 (a pre-registered witness
   passing the three-control gauntlet). Do not resume without it.

**Hygiene:** bootstrap per CLAUDE.md; cold-verify before trusting recall; atomic commits (code+canon);
push at save points (routine — the publish gate is spent; NEW public artifacts still ask first).

---

## ⟢ TAIL — this session, replay-condensed (most recent first)
Operator: "continue, then write memory to disk and pause" → carve cold two-pass (2 isolated-worktree
verifiers, CONFORMANT 2/2, 0 defects) → this file. ← "go" (open carve contract-first) → carve v1.0.0
built + golden `1373454e` + harness GREEN. ← carve design tournament ruling → ran it → caught the
circular oracle → RECOMMENDATION for the gate. ← "go with your best recommendation, ambitious" →
explained the jargon, ran the first live autonomous tournament, recommended carve's design tournament.
← "it's nested in ORRERY so it publishes with it" → pushed Intercom. ← "build one INSIDE C:\ORRERY\
Intercom, ASIC-specialized for ORRERY" → built ORRERY Intercom v1.0.0. ← "look into these two [Intercom
+ tournament] and brainstorm how they help ORRERY" → the analysis. ← "awaken, bootstrap" → verified
green cold (12 tools then).

*The keystone got measured, not asserted. The tournament caught a landmine the way hsmi-stab wished
someone had. Structure, never acquaintance; the register holds the doubt; the judge is a golden.*
