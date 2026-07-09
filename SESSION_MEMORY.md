# ORRERY — SESSION MEMORY / CONTINUATION / REHYDRATION  (2026-07-05 → 2026-07-09)

> **This is the reconstitution pointer + the full recollection of the build sessions, written from the inside by the sessions that lived them.** It is a memory dump, a continuation prompt, an "everything we did" recollection, and a self-rehydration prompt in one. Structured by salience (REEL rings): the top is dense and load-bearing; prune from the bottom up under pressure. (2026-07-05/06: the 6-tool catalogue. 2026-07-09: Wave 0 — liborrery + migrations.)

---

## ⟢ RECONSTITUTION POINTER — read this first, in this order, then VERIFY before trusting anything

1. **Read this file's CORE + RING-1 sections** (below) — the goal, the current position, the next action, the constraints, the patterns.
2. **Read on disk, in order:** `CLAUDE.md` (operating manual) → `RUN_STATE.md` (current state) → `ARCHITECTURE.md` §5–§9 (invariants, universal contract, language rule, catalogue, verification) → `DECISIONS.md` (ADRs D-001..D-018) → `TASKLIST.md` → `contracts/README.md`.
3. **VERIFY REALITY (disk/git win over this summary — never resume blind):**
   ```
   cd C:\ORRERY && git log --oneline -30 && git status --short
   # per tool, cold: run its selftest + golden (CUDA needs vcvars64 + nvcc; see each MODULE.md ## Build)
   python harness/verify.py            # builds+selftests+goldens EVERY tool -> OVERALL: GREEN (someone golden ~8min)
   python harness/verify.py --tool ratchet   # or a single fast tool
   ```
4. **Backstop:** the raw session transcript `.jsonl` is in the CCD tasks dir; **grep it** (or use `C:\TRANSPORTER\claude_archive_viewer_v4.html`, Ctrl-K concept search) for any specific this summary dropped. Do NOT re-read it whole.
5. Trust the **files** and the **git history** over this narrative. If they disagree with this doc, the files are right — update this doc.

---

## ◉ CORE (never drop)

- **WHO/WHAT:** I am the **ORRERY tool-builder agent**. ORRERY (`C:\ORRERY`, local git, NOT pushed) is a **headless, contract-bounded, deterministic simulation instrument** for a final-theory-of-everything project. The **science** (`C:\Fable_LLC\QUALIA_LAB\`, `THE_UNFINISHED_MIRROR`) *calls* ORRERY tools as `.exe`/`.py` and reads structured JSON; it never sees the code. They couple through **exactly one thing: the tool contract** (CLI + JSON schema + exit codes + determinism). That split is why both compound for years.
- **DOCTRINE (non-negotiable):** *The spec is the product. The contract is sacred. The golden is load-bearing. The code is ephemeral.* Discipline **tightens** with model capability (confident-wrong scales with capability) → golden-gate everything, two-pass anything cited. RAYFORMER is the cautionary tale (a beautiful "attention IS ray tracing" claim only measurement retired).
- **CURRENT POSITION (updated 2026-07-09):** **SIX tools built + verified (unchanged)** AND **Wave 0 (Phase 5) opened and its core landed**: the operator adopted the wave plan (`docs/PROPOSAL_2026-07-09_wave_plan.md`) — **D-020 (liborrery) + D-021 (CMake preset/fat binary/fast-math ban) are ACTIVE; I-11..I-14 are in ARCHITECTURE §5; TASKLIST has Phases 5–8** (D-022..D-026 stay PROPOSED until their phases open). **`lib/` is built + KAT-green (42 checks)** — the invariant core extracted VERBATIM from someone, pinned by a ref-namespace cross-check + host/device RNG bit KATs. **All four CUDA tools migrated to lib, one commit each, each golden BIT-IDENTICAL:** ratchet v1.0.1 (`91fce3c4` 3×) · mcts v1.0.1 (`6c596a53` 3×) · algebra v1.0.1 (`1526918f` 3×) · someone v1.1.1 (`aa5b731d`, the ~8-min run, byte-for-byte). Zero mismatches; posit/autotune untouched, still green. `lens` still parked (D-004). **`mcp` v1.0.0 (tool #7) + `orreryd` v0.1.0 (tool #8) BUILT + two-pass CONFORMANT** — both D-022 surfaces: the catalogue is LLM-callable (mcp, golden `174ec02d`) and campaign-runnable unattended (orreryd: spool FIFO + budgets + sentinels + status, golden `86f133bb`, C++20 on liborrery). Both goldens = the canned-posit chain (deliberate narrow coupling, NOTE.md re-baseline protocols).
- **THE SINGLE NEXT ACTION:** **PHASE 5 IS COMPLETE (2026-07-09: lib + 4 bit-identical migrations + CMake + mcp + orreryd + /lab page). Wave 1 opens with `hsmi-stab`** — fresh full-budget session; adopt its D-026 pre-contract in the opening commit; oracle = exact small-D brute force + non-hsm negative control; two-pass + science-handback. Side item: someone's fp64 oracle (I-11/D-025). **Publish stays OPERATOR-GATED (no `git push`/public repo/`wrangler deploy` without explicit confirmation — AUTONOMY_CHARTER §3); the /lab page is BUILT locally in the site folder (`_upload/lab.html`, live-registry-driven via the mcp surface) awaiting that human act.**
- **HARD CONSTRAINTS (violate none):**
  - Contract before code; golden before "done"; `--selftest` + `--golden` always. Change a contract only by **semver bump + DECISIONS ADR** (MINOR = additive; MAJOR = STOP + BLOCKER).
  - **Determinism or it doesn't ship**: same (params, seed) ⇒ byte-identical *declared* output; verify `--golden` ≥3× byte-identical. No wall-clock seeds, **no float atomics** in any declared reduction.
  - **Exit codes:** `0` pass · `1` a declared gate fired (a REAL negative result / finding) · `2` error (bad input/CUDA). **Never conflate 1 and 2.**
  - **THE FIREWALL (sacred):** every tool measures **STRUCTURE**, never **ACQUAINTANCE (qualia)**. The exact firewall sentence lives in every tool's JSON `notes` + MODULE.md. §III-sealed. Never claim anything feels.
- **WHERE SOURCE-OF-TRUTH LIVES:** the `C:\ORRERY` repo. Per-tool: `contracts/<t>.contract.md` + `.schema.json` (the law), `tools/<t>/<t>.{cu,py}` + `MODULE.md`, `goldens/<t>/{declared.hash,stdout.txt,NOTE.md}`, `runs/<t>_golden.result.lock` + `runs/<t>_twopass_verify.md`. Global: `RUN_STATE.md`, `DECISIONS.md`, `TASKLIST.md`, `ARCHITECTURE.md`, `harness/verify.py`.
- **TOOLCHAIN (verified live):** CUDA 13.1 (V13.1.80), `-arch=sm_89` (RTX 4070 Ti SUPER, 16 GB), MSVC 2022 via `vcvars64.bat`, Python 3.13.2, git 2.48.1. Build incantation in `BUILD.md`; each tool's exact fenced command in its `MODULE.md ## Build`.

---

## ● RING 1 — active state, patterns, decisions + WHY (the reusable knowledge)

### The build loop (per tool — copy this shape, it's the template)
1. **Contract-first:** write `contracts/<t>.contract.md` (CLI table w/ types/ranges/defaults, output schema, exit codes, determinism clause, golden params, change log) + `<t>.schema.json` (draft-07, `additionalProperties:false`). Semver from 1.0.0.
2. **MODULE.md:** purpose · the §III scope-guard · contract link · internal design (kernels/layout) · determinism approach · selftest list · golden · build command (**MUST be a fenced ``` block** — see gotcha) · provenance · known issues.
3. **Implement** (CUDA default; Python only where justified, D-005). Reuse someone's validated spine.
4. **Compile** per BUILD.md. **Golden:** run golden params, bootstrap-print the hash, freeze `goldens/<t>/declared.hash` + `stdout.txt` + `NOTE.md`, confirm `--golden` reproduces it **≥3× byte-identical**.
5. **result.lock** in `runs/<t>_golden.result.lock` (tool+semver, binary/source blake2b, GPU arch+device, CUDA, host compiler, exact CLI, declared hash).
6. **Register:** ARCHITECTURE §8 row + tools/README row → DONE; DECISIONS ADR; TASKLIST.
7. **Cold two-pass:** spawn a **general-purpose subagent with NO build knowledge** (tell it: trust ONLY the contract+schema+golden+binary, do NOT read the `.cu/.py` or MODULE science claims; run SYNCHRONOUSLY, no Monitor/background; run `harness/verify.py --tool <t>` + a conformance battery + physics/behavior check + scope check; write `runs/<t>_twopass_verify.md`). This SATISFIES the two-pass (the prompt allows a no-build-context subagent). It has caught real defects.
8. **Commit atomically** (tool + contract + golden + MODULE + result.lock + status docs). End messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

### Wave 0 (2026-07-09): liborrery + migrations — the NEW facts a resuming agent needs
- **`lib/` (D-020) is now the single home of the invariant core:** `envelope.h/.cpp` (blake2b + sha256 + `fmt6/fmti/jesc` + `declared_object`/`full_envelope(tool,ver,body,notes)` + `read_golden_hash(tool)`/`golden_check(tool,declared,envelope)` + `die2/parse_ll/parse_d` + `st_check` + `write_result_lock` + `CUDA_OK`), `rng.cuh` (the D-012 kit incl. `h_u01`/`h_normal`), `reduce.cuh` (`blockReduceSum/3`, `kahan_add`, order-invariant fixed-point uint64 atomics, `stable_gather_sum` host ref), `regime.h`, `ckpt.h` (B7: dump + `.sha256` sidecar + verified resume). Namespace `orrery`; tools do `#include "../../lib/envelope.h"` (+ `rng.cuh`/`reduce.cuh` as needed) + `using namespace orrery;`. **Build commands gained `../../lib/envelope.cpp`** (in every migrated MODULE.md fenced block).
- **The lib selftest is the drift detector:** `lib/selftest.cu` → `orrery_selftest.exe` (build per lib/MODULE.md, **run from repo root**), 42 KATs incl. a `namespace ref` frozen copy of the template's RNG (lib==template bit-for-bit, 1000-pt sweep) and **separately pinned host vs device** `counter_gauss` bits — because MSVC and CUDA libm REALLY diverge by 1 ULP on `counter_gauss(20260705,7,11,13)` (`…9d3b` host vs `…9d3a` device; measured, permanent). If a CUDA update shifts device log/cos, this fires BEFORE a golden silently breaks.
- **Migration discipline (D-020 acceptance, all met):** one tool per commit; HARD GATE = existing golden bit-identical post-migration (3× for fast tools; someone's ~8-min run once); PATCH version bump + contract changelog line + goldens/NOTE.md migration record (per contracts/README semver: a reproducing rewrite is a PATCH; D-013 excludes version from the hash, and `stdout.txt` stays the freeze-time capture). Mismatch policy (never triggered): STOP, SUSPECT, log DECISION, never force/re-baseline.
- **CMake preset (D-021):** `cmake --preset windows-sm89-fat` from a vcvars64 shell (ninja ships in VS 2022) → `orrery.lib` + fat-binary selftest; cuobjdump verified sm_89+sm_90+sm_120 SASS + sm_120 PTX. **Fast-math is BANNED project-wide.** Goldens stay hardware-pinned to sm_89 (re-baseline = operator-signed NOTE.md entry). Bare-nvcc stays the golden path; `build/` gitignored.

### The determinism spine (now IN `lib/` — was shared verbatim by every CUDA tool)
- **Counter-based RNG (stateless):** `splitmix64` → `hash4(a,b,c,d)` → `u01(h)` → `counter_uniform`/`counter_gauss`. Every random value is a pure function of its integer coordinates (seed, agent/tree/traj, index, step). **No device RNG state ⇒ no writeback race** (this is how someone's prototype bug was fixed by construction). No `curand`.
- **No float atomics in declared reductions.** someone: shared-mem warp-shuffle reductions + host index-order Kahan. ratchet/mcts: **integer** atomics only (associative ⇒ deterministic — trivially). algebra: cuSOLVER + sorted eigenvalues before the entropy sum.
- **Self-contained BLAKE2b-256** (host), KAT-validated in every selftest against `blake2b("")=0e5751c0…` and `blake2b("abc")=bddd813c…`. Python uses `hashlib.blake2b`.
- **Canonical JSON hash domain (D-013):** `blake2b` over `{seed, params, result, gates, verdict}` only — floats `%.6f`, fixed key order; **exclude** `tool`/`version`/`notes` so a behavior-preserving rewrite keeps the golden. `--golden` recomputes + compares; also prints the full envelope to stdout (for `stdout.txt` capture) and the verdict to stderr.
- **JSON envelope:** `{tool,version,seed,params,result,verdict,gates,notes}`. `verdict` = "pass"/"fail"; `gates` = array of `{id,fired,value,threshold}`.

### The DECISIONS made this session (D-009..D-019) — the WHY  [D-019 = autotune: Python glue, self-contained built-in golden + real-tool subprocessing; completes the buildable catalogue]
- **D-009** someone contract v1.0.0→**v1.1.0**: added `win_rate`+`p_value` (one-sided sign test) — a per-level claim needs significance, not a point delta (the science's D-DAK-RNG bar). MINOR/additive; authored the missing `someone.schema.json` too.
- **D-010** someone `--ensemble` default stays **1** (changing a default is behavior-breaking); use ≥20 in the real experiment, not by changing the default.
- **D-011** someone complexity ladder is **cumulative** (L0 base · L1 +predators · L2 +moving-lights · L3 +night) so L2↔L3 is the clean night A/B the science relies on.
- **D-012** RNG architecture (counter RNG + host mt19937_64 for evolution + purpose-keyed splitmix64 for env) — removes the prototype's race by construction.
- **D-013** golden hash domain (above).
- **D-014** someone golden is **~8 min, bandwidth-bound** (reads ~900KB weights/agent/step; confirmed NOT occupancy/barrier-bound — coalescing gave the only win, 1.8×). **Kept fp32** for scientific precision over fp16 speed; fp16 would be a golden-superseding change. This exceeds the <5min NFR, documented.
- **D-015** ratchet v1.0.0 = single-point branching-MC verifier; scan deferred to v1.1.0. Exact per-fragment Bernoulli + early-escape (O(1) binomial for billions-scale is a golden-superseding v-next).
- **D-016** posit built (Python, D-005); **`harness/verify.py` made POLYGLOT** — detects `<name>.py` → runs `python <name>.py`, else `.exe`.
- **D-017** mcts = **root-parallel UCT** (one independent tree per thread ⇒ embarrassingly parallel AND deterministic; per-tree node pools, integer visits). Built-in `match` landscape w/ known optimum so the golden verifies it FINDS the answer.
- **D-018** algebra scoped to **Part A ONLY** (the c=1 divergence, checked vs Calabrese–Cardy) + massive c≈0 control; **explicitly does NOT compute the science's WITHDRAWN Part-B value** ("16.23 bits" retracted as a fraction-of-box artifact). This is the key discipline for the most contested tool — the cold verifier confirmed it holds.

### GOTCHAS learned (do not re-learn the hard way)
- **The `## Build` command in MODULE.md MUST be a fenced ``` block**, not an inline single-backtick span — `harness/verify.py extract_build_cmd` requires a fenced block; an inline span → `NO-BUILD-CMD` → harness RED. The ratchet cold two-pass CAUGHT this. Template note is now in `tools/README.md`.
- **Host≠device libm (1 ULP, real):** never assert host==device for transcendental counter-RNG values; pin KATs per side (lib/selftest.cu does). Integer + `u01` paths ARE bit-identical host↔device.
- **nvcc dual-pass parsing:** don't guard `__device__` helpers with `#ifdef __CUDA_ARCH__` (kernel bodies parse in the HOST pass too → "no member" errors); plain `__device__ inline` is correct. Namespace-scope `static const double` is invisible to device code — inline the literal or use a constexpr function.
- **BUILD.md's `cmd /c '…'` incantation only works from PowerShell** (the harness's shell). From bash it silently drops the command (banner-only cmd). Use the PowerShell tool for builds. Also: PowerShell `cd` and Bash cwd are SHARED per session — a bash `./x.exe` may run from wherever PowerShell last `cd`'d.
- **Determinism verification via `--golden` 3×** can pass 2 by luck if there's a rare race — always do ≥3×.
- **cuSOLVER is deterministic on sm_89** (verified 3× byte-identical) but can drift last-ULP across CUDA/driver versions — `%.6f` tolerance is above it; re-verify on a toolchain change.
- **someone's golden at L3/n=4 shows ZOMBIE winning** (a noisy point) — that's the frozen anchor, NOT a claim; the science conclusion is the n=24 S5 run.
- **Never report the post-extinction fitness ratio** (≈1e10 artifact); `avgGap→1` is definitional, not evidence. (someone guards, from D-DAK-RNG.)
- Windows console is cp1252 — Python tools must force UTF-8 stdout; avoid non-ASCII in `.ps1`/emitted text (an em-dash broke the S5 runner once).
- Commit **selectively** while subagents are mid-run (they write `runs/*_twopass_verify.md` + `runs/verify_*.md`); don't `git add -A` over their in-flight files.

### Open / next (v1.1.0 deepenings, all optional)
- `autotune` (the next tool — sweep/basin-finder driving the built tools; self-contained golden via a built-in benchmark, real-tool sweeping as a feature).
- algebra **fixed-site Part-B** relative-entropy (the owed D-CP-CLOCK refit; Casini–Huerta kernel validated vs Fock — the 2×-too-large first draft is the cautionary tale).
- mcts deceptive landscape / caller-supplied reward; posit **D-POSIT-AGG** (de-duplicated global budget); ratchet `--scan-rho` + O(1) binomial; a full **N=256, n≥20** confirmation of the someone overturn (~2–3 h) for heavy-arm parity.
- Phase 4 publish (public GitHub + `/lab` on finaltheoryofeverything.org) — **operator-gated, do NOT push without confirmation** (AUTONOMY_CHARTER §3).

---

## ▪ RING 2 — completed work (terse; verifiable from git/goldens)

**The five tools (all DONE v1.x, golden-frozen, cold-two-pass CONFORMANT):**

| tool | lang | golden hash | what it measures | key result / scope |
|---|---|---|---|---|
| **someone** | CUDA | `aa5b731da7b5e268…` | evolutionary Someone-Criterion: self-modeling agents (gap `pureGap`) vs gapless zombies under stakes; does the gap confer FITNESS? | v1.1.0. Golden L3/n=4 (noisy). Confound (D-DAK-RNG) fixed + selftest-asserted. **~8min golden** (D-014). |
| **ratchet** | CUDA | `91fce3c40ea63051…` | Galton-Watson branching ratchet; `P[unwrite]=q*^R`, `q*=min(1,p/((1−p)ρ))`; the **(1−p)ρ=p** threshold (F13/T-RATE) | MC↔analytic **rel_error 0.06%**. Integer atomics ⇒ trivial determinism. ~0.5s golden. Cold-pass caught the build-fence defect. |
| **posit** | **Python** | `7a22dd229a42ce46…` | parsimony auditor (Q3): posit/bridge/import/derived budgets, physics vs overlay, confabulation guard (bridge cost==posit cost) | v1.0.0. Seed cluster **Δphysics=+0.8 win** (D-POSIT banked). Exact, no RNG. Reads audit cases via `--case`/`--stdin`. |
| **mcts** | CUDA | `6c596a53f44543f2…` | generic root-parallel UCT search engine over a `B^D` space; built-in `match` landscape (known optimum) | All 1024 golden trees find the exact target. `G-SUBOPTIMAL` fires on starved budget. |
| **algebra** | cuSOLVER | `1526918f15ec1f26…` | crossed-product entropy (F16/D-CP): critical free-boson block-entropy **c=1** UV-divergence (vs Calabrese–Cardy) + massive c≈0 control | **c_measured=0.9963**. Validated vs receipt (S(64)=0.85219, S(128)=1.01696 bits). **Scoped: NO withdrawn Part-B value** (D-018). |
| **autotune** | **Python** | `c79002f23cf236ba…` | sweep/basin-finder: sweep a param, locate a feature (parabolic argmax / interp crossing) vs a **pre-registered `--target`**; built-in objective OR **real-tool subprocessing** (D-019) | Golden = built-in `peak`, x_located=0.370091. **Drives ratchet** → finds (1−p)ρ=p at 0.2581 (analytic 0.25). The tool that makes the others compound. |

**The harness:** `harness/verify.py` — discovers tools from `MODULE.md`, builds→selftest→golden each, dated `runs/verify_*.md`, exit 0 iff green, flags NFR budget. **Polyglot** (CUDA+`.exe` / Python+`.py`). Ran GREEN on all.

**The science result (someone S5 — the citable run, `runs/someone_round01_reproduce.md`):** de-confounded, n=24 sweep. Round-01's per-regime winners **[Z,N,Z,N] → [T,T,T,T]** (all statistical ties, two-sided sign test). Strong "advantage grows with complexity" form NOT supported (reconfirmed corpus-grade); weak threat/deprivation form NOT significant; "zombie-wins-L0/L2" **OVERTURNED**. The gap is present everywhere (`mean_pure_gap` 0.33–0.58) but **≈ fitness-neutral** — dominated by founder-effect seed variance, vindicating D-DAK-RNG. Science-handback block written for QUALIA_LAB to paste (F6/F8/D-DAK-RNG vocabulary). Structure only, §III-sealed.

**Cold two-pass highlights:** ratchet's pass caught a real harness defect (fixed→GREEN). mcts + algebra passes did anti-RAYFORMER data-boundness checks (off-by-one input → different hash, proving computed-not-stamped). algebra's pass confirmed the **scope discipline** (no withdrawn value, Type-I/III₁ caveat present).

**Commit arc (git log):** S0 orientation → S1 contract v1.1.0+schema+MODULE → S1b skeleton → S2 full sim → S3+S4 golden → S5 overturn → S6 two-pass → harness/D-014 → ratchet R1/R2+R3/R4(defect fix) → posit+polyglot → posit two-pass → mcts → mcts two-pass → algebra → algebra two-pass. Each atomic.

**Wave-0 arc (2026-07-09):** `033542b` lib+preset+canon (D-020/D-021 Active, I-11..I-14, Phases 5–8, proposal committed) → `e320dd5` ratchet v1.0.1 → `504d663` mcts v1.0.1 → `3789db8` algebra v1.0.1 → `3a22298` someone v1.1.1 — every migration golden-bit-identical (net ~−420 duplicated lines); save-point commit closes the session. Tool versions now: someone 1.1.1 · ratchet/mcts/algebra 1.0.1 · posit/autotune 1.0.0 (untouched).

---

## ▫ RING 3 — background (prune first under pressure)

- **Reference engines (read-only inputs):** `C:\Users\user\Desktop\DSA\dak_evolution_complex.cu` (someone's prototype), `criticality_cuda.cu` (ratchet MC pattern), `C:\ASTRA-7` (compile-verify), `C:\RAYFORMER` (ADR-007 lesson), `C:\buddhabrot-main` (CMake). NEVER modify outside `C:\ORRERY`.
- **Science canon (context, not dependency):** `C:\Fable_LLC\QUALIA_LAB\gym\posit_counter.py` (posit model), `gym/receipts/toy_rr_frontier_ratchet.py` (ratchet physics), `gym/receipts/toy_cp_divergence.py` (algebra Part-A ground truth — validated against), `gym/receipts/dak_skeptic_rng_confound.py` (the confound), `library/{debts,established}.md` (D-DAK-RNG, F6/F8, F13, F16/D-CP).
- **AUTONOMY_CHARTER:** may modify everything under `C:\ORRERY`; may read reference engines + science; **NEVER `git push` / create public repo without operator confirmation** (Phase 4 gated). Reversible defaults → log in DECISIONS, proceed. BLOCKER for irreversible/contract-breaking.
- **Local tooling (`C:\Users\user\.claude\CLAUDE.md`):** `C:\everything\search.py` (locate), `C:\chunker\` (big files), `C:\imguard\`, `C:\earshot\`. Archive viewer for transcript grep: `C:\TRANSPORTER\claude_archive_viewer_v4.html`.
- **Env memory dir:** `C:\Users\user\.claude\projects\C--ORRERY\memory\` + `MEMORY.md` (separate from this repo doc).

---

## ⟢ TAIL — the last few turns, verbatim (highest-fidelity recent context; replay most-recent-first if re-seeding)

**[most recent, 2026-07-09] OPERATOR BRIEF:** adopt the wave plan (`docs/PROPOSAL_2026-07-09_wave_plan.md`, authored from a full canon read + engine survey), start Wave 0 (Phase 5). Ruling: D-020+D-021 adopt Active in the same commit as their code (Invariant 10) + I-11..I-14 into §5; D-022..D-026 stay PROPOSED until their phases open; append Phase 5–8 to TASKLIST; migrate ratchet→mcts→algebra→someone, HARD GATE bit-identical goldens, mismatch = STOP+SUSPECT+DECISION, never force/re-baseline; atomic commits; "lib/ + ratchet alone is a successful session; durable over fast." → **DONE IN FULL:** bootstrap cold-verified all 6 tools first; lib/ built + 42-KAT green (with the 1-ULP host/device finding pinned); CMake fat-binary preset verified by cuobjdump; canon adopted atomically (`033542b`); all four migrations green bit-identical (`e320dd5` ratchet, `504d663` mcts, `3789db8` algebra, `3a22298` someone). Zero golden mismatches. THEN (same session, operator chose via question): **`mcp` v1.0.0 built to the full loop** — tool #7, D-022 adopted Active (`e91f666`): stdio JSON-RPC MCP surface, six tools, I-12 declared+artifact hashes on every run, golden `174ec02d` = the canned-posit chain (deliberate narrow coupling, NOTE.md re-baseline protocol), 13-check selftest, live GPU smoke (ratchet through --serve), pre-commit smoke caught+fixed the uppercase-flag defect (--R/--N), **cold two-pass CONFORMANT 10/10**. The instrument is now LLM-callable. THEN (operator: "proceed directly"): **`orreryd` v0.1.0 built to the full loop** — tool #8 (`8895703`): C++20-on-liborrery file-spool daemon (one GPU tenant FIFO, budgets w/ live-proven 2s kill, .stop/.DONE, atomic status, I-12 records), golden `86f133bb`, selftest 13/13, live GPU drain smoke, **cold two-pass CONFORMANT 13/13 incl. cold rebuild**. FINALLY (operator: "go for it, proceed"): the **/lab page** built in the site folder from the LIVE registry via the mcp surface (_build_lab.py; structural battery ALL PASS; NOT deployed -- wrangler deploy is a human act; site BUILD_LOG.md entry) -- **PHASE 5 COMPLETE**. Commits end `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` (current harness model).

**[earlier, 2026-07-06 @ ~89% ctx] USER:** asked to build `autotune` + clarify whether `lens` is "parked" (done vs carved-out). → I confirmed **lens = carved-out / deliberately deferred** (a parked SPIKE w/ a pre-registered kill, D-004; operator-gated, NOT done), then **built `autotune` end-to-end** (tool #6, Python glue D-019, golden `c79002f2`, real-tool mode drives ratchet to find ρ_c=0.258) and **cold-two-pass verified it CONFORMANT**. Then the user re-asked for this memory refresh at ~89% ctx. **STATE NOW: all 6 tools built + golden-frozen + cold-two-pass verified; NOTHING OWED; buildable catalogue COMPLETE; only lens remains (parked); Phase 4 publish is OPERATOR-GATED (no push without confirmation).** Decisions are now D-009..**D-019** (see DECISIONS.md; D-019 = autotune Python-glue + self-contained-golden-vs-real-tool-mode).

**[earlier] USER (2026-07-05, first pause):** asked for this memory doc (memory dump + continuation + recollection + rehydration in one massive md). *(→ this file was created then, updated since.)*

**[prior] ASSISTANT (milestone summary):** Presented "Five tools built and cold-two-pass verified — the catalogue is (nearly) complete." Table of all 5 tools + golden hashes + what each establishes. Noted: template propagated; two languages one contract; the cold two-pass earns its keep (caught ratchet defect, confirmed algebra scope); a real scientific result (someone overturn); firewall held everywhere. **Recommended pausing at this strong point; offered to build `autotune` (last non-backlog tool) if the user says the word.**

**[prior] USER:** "Four tools are built and cold-two-pass verified. Continue, and if so with which?" → chose **algebra** (via AskUserQuestion). Then algebra was built + cold-two-pass verified CONFORMANT (scope confirmed).

**[prior] pattern:** User repeatedly said "proceed"/"continue" and chose next tools via AskUserQuestion (mcts, then algebra). Consistent intent to build the catalogue. Now: **pausing**, wants this memory doc.

**IMMEDIATE NEXT MOVE on resume:** run the RECONSTITUTION POINTER verify commands (git log/status; a fast tool's selftest+golden; `.\lib\orrery_selftest.exe` from repo root), then open the Phase-5 remainder: **`mcp` v1.0.0 contract-first (adopt D-022 in that commit)** → `orreryd` v0 → `/lab` registry page. Do NOT push to GitHub (operator-gated). Keep the firewall in every notes field.

---
*Written from inside the session that built it, 2026-07-05. Trust the files + git over this narrative; grep the `.jsonl` for anything dropped. The spec is the product; the contract is sacred; the golden is load-bearing; the code is ephemeral.*
