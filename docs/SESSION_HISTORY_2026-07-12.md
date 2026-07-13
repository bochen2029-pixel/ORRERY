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
