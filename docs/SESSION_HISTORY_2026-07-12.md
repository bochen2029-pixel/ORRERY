# ORRERY — session history log (2026-07-12 → 2026-07-13)

**What this is:** a running log of the build-agent's own work this session, plus the backup/versioning
protocol the operator asked for (2026-07-13). Trust **git + the goldens** over this narrative; this log is
an audit trail, not a source of truth.

## Backup / versioning protocol (established 2026-07-13, at operator request)
1. **Git is the per-file versioning.** Every logical unit of work is an atomic commit on `master` (tool +
   contract + golden + MODULE + canon together, Invariant 10). Any changed file is recoverable/diffable
   from history. Commits are pushed to `origin` (github.com/bochen2029-pixel/ORRERY) at each save point.
2. **Off-repo full-history snapshots:** `git bundle` files in **`C:\ORRERY_snapshots\`** (a sibling dir,
   NOT in the repo), named `ORRERY-<YYYYMMDD_HHMMSS>-<shorthash>.bundle`. Restore with
   `git clone ORRERY-*.bundle <dir>` or `git fetch <bundle>`. Refreshed at each pushed milestone.
3. **Site (finaltheoryofeverything.org) files are NOT git** → versioned snapshots in the site's
   `_backups\` (LIVE-page snapshot before every deploy = rollback point; staged page + builder versioned by
   timestamp). Every deploy is logged in the site `BUILD_LOG.md`.
4. **Before proceeding after any pause,** re-scan: `git fetch; git status; git log` (detect a parallel
   committer), a process/mtime scan (detect a parallel editor). This log records each such scan.
5. **Subagent (two-pass) isolation:** verifier subagents may create git worktrees under `.claude/worktrees/`
   on `claude/*` branches — isolated from `master`, they never push. Harmless; not a parallel session.

## State scan — 2026-07-13 ~01:24 CST (before continuing)
- `git`: HEAD = origin/master = **`ef75fb2`**, ahead/behind **0/0**. All 8 recent commits authored by the
  Bo Chen build-agent identity (this session's arc). Working tree clean but for the untracked
  `docs/PROPOSAL_2026-07-11_tooling-requests-from-tinyuniverse.md` (an external consumer note, intentionally
  untracked). **No parallel committer.**
- Processes/files: no non-me process editing `C:\ORRERY`; recent file mtimes are all my edits; the site
  files (`lab.html`, `BUILD_LOG.md`, `_build_lab.py`) are my 2026-07-13 00:56 orrery-deploy edits. The 12
  Python processes running are the operator's unrelated `C:\Katherine_Chat\go_*_mcp.py` servers.
- Worktree: `.claude/worktrees/pedantic-driscoll-e0b0ce` @ `75cd439` on branch `claude/…` — an isolated dead
  verifier-subagent checkout; not on master, does not push. Left in place (harmless).
- Snapshot: `C:\ORRERY_snapshots\ORRERY-20260713_012356-ef75fb2.bundle` (verified OK).
- **Conclusion: up to date, no collision risk. Safe to proceed.**

## Work this session (chronological; commit → what)
| commit | when (CST) | what |
|---|---|---|
| `d7baff7` | 07-12 18:06 | **lens v1.0.0** — OptiX RT-core silhouette renderer + oracle-gated cross-section (Schwarzschild shadow 27π M²); contract+golden `11e545b8`+MODULE (D-029). |
| `d10f631` | 07-12 18:14 | lens **cold two-pass CONFORMANT** (0 defects); registered. |
| `7001041` | 07-12 18:56 | **lens compute-SPIKE (D-004) RULED** — geodesic baseline validated (derives 27π M²); RT-as-compute **RETIRED** (~10× loss, measured); D-004 resolved (D-030). |
| `472c1e8` | 07-12 19:22 | **lens v1.1.0** — scene `bhshadow-geo` DERIVES the shadow by null-geodesic integration (additive-safe; 2nd golden `914399…`); cold two-pass CONFORMANT (D-031). |
| `ccc0c53` | 07-12 19:51 | **shoot v1.0.0** — ODE-shooting eigenvalue instrument (TinyUniverse R-6); golden `9625b268`; cold two-pass CONFORMANT (D-032). |
| `75cd439` | 07-13 00:33 | **someone v1.2.0** — the OWED I-11 fp64 CPU oracle `--oracle` (D-025 closed); golden `aa5b731d` byte-identical (additive-safe). Verified synchronously (agent-based two-pass hung on the async GPU-golden mechanism). |
| `ef75fb2` | 07-13 00:56 | **orrery v1.0.0** — the ergonomic CLI over the catalogue (TinyUniverse R-1/R-2/R-3); golden `43977185`; cold two-pass CONFORMANT (D-033). |

Also (not commits): `/lab` regenerated + **deployed 3×** (wrangler `b01e25e6` → `8f7311df` → `5ca99437`;
10→11 tools), each backup-first; memory pointer kept current.

**Net:** 6 tool builds/versions; 2 long-standing debts closed (**D-004** the parked RT-compute SPIKE,
**D-025** the owed flagship oracle); catalogue at **11 golden-frozen tools** (+ parked hsmi-stab), `/lab`
live at 11, all pushed. Lesson banked: long-GPU-golden two-passes must run FOREGROUND in a subagent (the
async background-Monitor mechanism hangs on them).

## Continuing (2026-07-13) — entries appended below as work proceeds
- 2026-07-13 ~01:24 — state scan (above) + first `git bundle` snapshot + this log created. Next: continue
  the TinyUniverse DX asks (operator-chosen direction).
- 2026-07-13 ~01:44 — **orrery v1.1.0** (R-5 content-addressed run cache) landed → commit **`a1942bc`**,
  pushed (`bfa13ed..a1942bc`), snapshot `ORRERY-20260713_014414-a1942bc.bundle`.
  - Feature: `orrery run <tool> --cache` + `orrery cache` (stats/--get/--clear). Key =
    `blake2b(tool + canonical-params + tool-binary-hash)` → a rebuilt binary invalidates stale entries;
    only declared-output runs stored; errors never cached; lives under `runs/cache/` (gitignored).
  - **Additive-safe:** declared golden **`43977185` UNCHANGED**, reproduced byte-identical; the 7 source
    deletions are pure wiring (no declared-output logic removed).
  - **Cold two-pass** (`runs/orrery_v1_1_0_cache_twopass_verify.md`, foreground-only per the banked lesson):
    **CONFORMANT to v1.1.0, 8/8, no cache defects** — MISS/HIT/no-cache stdout byte-identical, HIT proven
    to NOT spawn the tool (spawn-counter instrumented), binary-hash invalidation confirmed, errors never
    cached. It also **caught a re-freeze-hygiene gap**: `goldens/orrery/stdout.txt` was one byte stale (the
    `version` envelope field `1.0.0`→`1.1.0`, which lives outside the D-013 hashed domain) — re-frozen here,
    `declared.hash` untouched. Corrected a canon overclaim: cold two-pass now stated precisely as
    **v1.0.0 core 11/11 + v1.1.0 cache 8/8** (was a blanket "11/11").
  - Value of the two-pass: it converted a silent stale-snapshot + an imprecise canon claim into an honest,
    measured record. The cache — the class of feature most prone to silent corruption — was proven
    transparent (a HIT is byte-equal to a fresh run) rather than merely asserted so.
- 2026-07-13 ~04:27 — **trace-born v1.0.0** (C-TRACE, Wave-1 science gear #2; operator-chosen "next
  ambitious stuff") landed → commit **`dac00dd`**, pushed (`768a2dd..dac00dd`), snapshot
  `ORRERY-20260713_042652-dac00dd.bundle`. **The 12th golden-frozen tool** (13th contract; hsmi-stab is parked, no golden).
  - What it is: the **Born-from-redundancy** tool — does the normalized-trace weight over a
    redundancy-defined branch projection reproduce Born `|c_i|²` in a **decohering** finite `S⊗E^R` model
    (the F15 mechanical core; Zurek envariance + quantum Darwinism)? Brute-force full-state construction +
    partial trace (the un-shortcut `d^{R+1}` GPU path) cross-checked against the analytic **Gram oracle**
    (I-11). Extends `algebra`'s cuSOLVER (Dsyevd→**Zheevd**, complex-Hermitian).
  - Golden `d4e3bf04` (weights 2,3, R=6, full ⇒ Born [0.4,0.6], born_max_dev=0, purity 0.52; det. 3×).
    Declared witnesses: STEP-A envariance (non-vacuous) + STEP-B fine-graining (`1/√M`). Control: partial
    decoherence fires both gates + objectivity_dev>0. Selftest 16/16; harness GREEN.
  - **Honest scope (algebra Part-A discipline):** the one undischarged premise — noncontextual credence =
    f(local state), science debt **D-BORN** [OPEN/W] (Baker 2007) — is **labeled and excluded**; no "derives
    Born"; §III-sealed. **Cold two-pass CONFORMANT 11/11, scope honest, no overclaim**
    (`runs/trace-born_twopass_verify.md`) — verifier adversarially confirmed the two oracle paths are
    genuinely independent and the control discriminates via an R-sweep. Science-handback delivered
    (`runs/trace-born_c-trace_handback.md`, F15/D-BORN-facing).
  - **Process win — measure-first paid off:** the physics was fully de-risked in a numpy prototype
    (`tools/trace-born/_prototype/born_proto.py`) BEFORE a line of CUDA → the .cu passed **16/16 selftest on
    the first build**. One bug (a Bash-mangled `cmd /c` quoting) cost one round-trip; the fix was to run the
    build through the PowerShell tool. One harness gotcha caught + fixed: the MODULE build command must use
    tool-dir-relative paths (`../../lib/…`), since `harness/verify.py` builds with `cwd=tools/<tool>/`.
  - Next Wave-1 gear = **`carve`** (Layer-2/P2), the last of the make-or-break trio.
