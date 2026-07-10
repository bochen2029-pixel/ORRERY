# ORRERY — SESSION MEMORY / STATUS / CONTINUATION / REHYDRATION
**Written 2026-07-10 13:54 −05:00 (Friday), from inside the hsmi-stab witness session, at save point `87b8730`.**

> **This is the reconstitution pointer + comprehensive project status + continuation prompt + handoff in one**, superseding the 2026-07-05/09 edition of this file (its content is folded in below). Structured by salience (REEL rings): the top is dense and load-bearing; prune from the bottom under pressure. Trust the **files + git** over this narrative — if they disagree, the files are right; update this doc.

---

## ⟢ RECONSTITUTION POINTER — read this first, in this order, then VERIFY before trusting anything

1. Read this file's **CORE + RING 1** (below).
2. Read on disk, in order: `CLAUDE.md` (operating manual) → `RUN_STATE.md` (current state + next action) → `ARCHITECTURE.md` §5–§9 (invariants I-1..I-14, universal contract, language rule, catalogue, verification) → `DECISIONS.md` (D-001..**D-028**) → `QUESTIONS.md` (Q-001/Q-002, both RULED) → `TASKLIST.md` → `contracts/README.md`.
3. **VERIFY REALITY (never resume blind):**
   ```
   cd C:\ORRERY ; git log --oneline -15 ; git status --short
   # fast cold checks (from tools/ratchet):  .\ratchet.exe --selftest ; .\ratchet.exe --golden
   # lib KATs (from repo root):              .\lib\orrery_selftest.exe
   # full battery (someone golden ~8 min):   python harness/verify.py
   ```
4. Backstop: session transcripts are in the CCD tasks dir; grep them (or `C:\TRANSPORTER\claude_archive_viewer_v4.html`) for anything this summary dropped. Do NOT re-read whole.
5. Session INIT prompts live in `docs/INIT_*.md`. **If a pasted INIT contradicts RUN_STATE/git (it happened 2026-07-10: the long-completed `INIT_someone_session.md` was re-pasted), trust the repo, cold-verify, surface the mismatch, and ask** — the newest committed INIT is the intended session.

---

## ◉ CORE (never drop)

- **WHO/WHAT:** I am the **ORRERY tool-builder agent**. ORRERY (`C:\ORRERY`, public at github.com/bochen2029-pixel/ORRERY) is a **headless, contract-bounded, deterministic simulation instrument** for the final-theory-of-everything project. The **science** (`C:\Fable_LLC\QUALIA_LAB\`, THE_UNFINISHED_MIRROR, essay v5) *calls* tools and reads declared JSON; it never sees code. Coupling = **the contract** (CLI + schema + exit codes + determinism) + **the golden**. That split is the compounding.
- **DOCTRINE:** *The spec is the product. The contract is sacred. The golden is load-bearing. The code is ephemeral.* Discipline tightens with model capability. Golden-gate everything; cold two-pass anything citable. RAYFORMER is the cautionary tale; hsmi-stab (below) is now the in-house proof the discipline works.
- **CURRENT POSITION (2026-07-10 13:54):**
  - **Wave 0 COMPLETE + PUBLISHED:** 8 tools DONE + golden-frozen + cold-two-pass CONFORMANT (someone v1.1.1 `aa5b731d` · ratchet v1.0.1 `91fce3c4` · algebra v1.0.1 `1526918f` · posit v1.0.0 `7a22dd22` · mcts v1.0.1 `6c596a53` · autotune v1.0.0 `c79002f2` · mcp v1.0.0 `174ec02d` · orreryd v0.1.0 `86f133bb`) + `lib/` (liborrery, 42 KATs) + CMake fat-binary preset + harness. Repo public; `/lab` LIVE at finaltheoryofeverything.org/lab. **Publish gate SPENT: save-point pushes are routine sync; NEW public artifacts (repos/pages) still ask first.**
  - **Wave 1: `hsmi-stab` (F-K1, the keystone) is PARKED by Q-002 ruling after a full honest negative arc** — see RING 1. Its Fock oracle is FIXED (3e−12); its contract v1.0.0 stands under a DRAFT-RETURNED banner (D-027 + D-028); **NO GOLDEN EXISTS; nothing from it is citable as a tool result.** The citable output is the negative-result chain + science-handback memo `runs/hsmi-stab_k1_witness_handback.md`.
  - All of 2026-07-10's work: commits `e4c7e97 → 87b8730` (7 commits), pushed; tree clean at `87b8730`.
- **THE NEXT ACTION (operator-facing choice, my recommendation in RING R below):** open **`trace-born`** (C-TRACE, next in the D-026 order book) contract-first in a fresh full-budget session — or the short-session side item, **someone's owed fp64 CPU oracle** (I-11/D-025). hsmi-stab stays parked until the science reformulates F-K1's finite-D projection (memo §4 lists the asks).
- **HARD CONSTRAINTS (violate none):** contract before code; golden before done (≥3× byte-identical); `--selftest` always; semver bump + ADR for any contract change (MAJOR ⇒ STOP + QUESTION); determinism or it doesn't ship (no wall-clock seeds, **no float atomics** in declared reductions, fast-math BANNED, D-021/I-13); exit 0 pass · 1 = declared gate fired (a REAL result) · 2 = error — never conflate; **THE FIREWALL:** every tool measures STRUCTURE, never ACQUAINTANCE (qualia), §III-sealed, verbatim in every `notes`; hsmi-class tools also carry the Type-I boundary guard (shadow + scaling, never the Type III₁ claim); atomic commits (code + canon, Invariant 10); never modify outside `C:\ORRERY` (reference engines + science are read-only).
- **SOURCE-OF-TRUTH MAP:** per tool: `contracts/<t>.contract.md` + `.schema.json` (law) · `tools/<t>/` (code + MODULE.md) · `goldens/<t>/` (declared.hash + stdout.txt + NOTE.md) · `runs/<t>_golden.result.lock` + `runs/<t>_twopass_verify.md`. Global: RUN_STATE · DECISIONS · QUESTIONS · TASKLIST · ARCHITECTURE · `harness/verify.py` · `docs/INIT_*.md` (session handoffs) · `docs/PROPOSAL_2026-07-09_wave_plan.md` (waves).
- **TOOLCHAIN (verified live 2026-07-10):** CUDA 13.1 (V13.1.80), `-arch=sm_89` (RTX 4070 Ti SUPER 16 GB), MSVC 2022 via `vcvars64.bat`, cuSOLVER (`-lcusolver` for eigensolve tools), Python 3.13, git. Build incantations: `BUILD.md` + each MODULE.md's fenced block. **Builds run from PowerShell** (the `cmd /c '…vcvars64…'` line silently no-ops under bash).

---

## ● RING 1 — the 2026-07-10 session (hsmi-stab): what happened, what was learned, what transfers

### The arc (7 commits, each atomic)
1. **Stale-INIT catch:** the pasted INIT was the completed Phase-1 `someone` mission; verified reality (someone golden reproduced byte-identical cold ~8 min, ratchet+lib green), surfaced, operator confirmed the real session (the D-027 hsmi-stab handoff).
2. **`e4c7e97` — Fock oracle FIXED (handoff step 1).** Printed the numbers first: fock 0.956 vs gauss 0.4615, err 4.9e−1, ±t-symmetric, ~t-independent = the scrambled-back-rotation signature. Bug: the oracle's σ_t back-rotation right-multiplied by `V` instead of `Vᵀ` (one buffer index; even t=0 reconstructed `c₁V²`). Post-fix agreement **1.8e−12/3.4e−12** vs tol 1e−8, both t's, both directions. The parity-twist suspect was a red herring (naive partial trace is exact for a number-conserving fixed-N state — ρ_A is parity-block-diagonal).
3. **`b2cfeb3` — D-028: the blindness kill-chain; Q-001 filed.** Step 2 (chirality-broken model) uncovered that the *functional*, not just the model, is blind — see the theorem list below.
4. **`bcda4ab` — Q-001 RULED (operator): index/winding witness.** Iteration 1 (P7, site-basis symbol winding): honest negative (flow disperses in site space; windings only on collapsed-gap junk).
5. **`bf36f9b`** — authored `docs/INIT_hsmi-stab_witness_session.md` (the P8/P9 handoff), which the operator then invoked in-session.
6. **`c9ceedb` — P8+P9 measured, both NEGATIVE; Q-002 filed.** Controls theorem-exact (see below).
7. **`87b8730` — Q-002 RULED (operator): science-handback.** Memo delivered: `runs/hsmi-stab_k1_witness_handback.md` (claim-by-claim, reformulation asks, reproduction pinned to commit `c9ceedb`, source blob `f6e7c9a1`). hsmi-stab → DEFERRED/parked.

### The findings (D-028 + probes; the permanent knowledge)
- **[THEOREM] Leak-norm blindness:** `‖P_out U(t) P_𝒩‖` with `P_𝒩 = P_out^⊥` is identically ±t-symmetric for EVERY model: `spec(MM†)=spec(M†M)` (square M). Corollary: **one-sided subspace containment does not exist in finite D** (`U(𝒩)⊆𝒩 ⇒ U(𝒩)=𝒩`). D-027's T-invariance explanation was true but epiphenomenal.
- **[THEOREM] Frobenius ax+b witness blindness:** cross-term `tr([k_A,k_N](k_N−k_A))=0` by cyclicity.
- **[MEASURED, mechanism] Spectral ax+b witness blind on any Toeplitz window:** flip×conj fixes every Hermitian Toeplitz covariance (PCT-like congruence); chirality FORCES translation invariance (a boundary reflects the chiral branch; Nielsen–Ninomiya-adjacent), so symmetric truncations of chiral states always carry it.
- **[MEASURED] Transport element** `|⟨e_out|U(±t)|e_bnd⟩|` symmetric to 6 digits at half filling (PH self-conjugacy up to rank-2, odd-distance-vanishing 1/L term). **[MEASURED] Wiesbrock minspec (with constants)** is strongly asymmetric in BOTH models (control 66 > chiral 38) = nesting monotonicity, not the arrow. **[MEASURED] Naive Nyström sampling of the log-lattice Cauchy kernel** is positivity-clean (margins .04–.12; Toeplitz section ⊂ symbol range) but UV-mangled (bounded k; spectra/flow m-independent).
- **[MEASURED] P8:** the 𝒜/𝒩 modular ladders ALIGN with n (spread 1.04→0.35) with ZERO directional displacement. **[MEASURED] P9 (Wiesbrock cocycle `V(t)=U_𝒩(t)U_𝒜(−t)`; hsm ⟺ one-signed eigenphases):** t-inv control EXACTLY symmetric to 5 digits (**named theorem: staggering×conjugation maps V→conj V unitarily, `SkS=−k` for both half-filled k's**); random nested control symmetric; chiral NOT one-sided — the entire asymmetry is the trace drift `arg det V = t(tr k_𝒩 − tr k_𝒜)`, shrinking with n (1.06→1.03). UV/IR sector diagnostic: phase sign uncorrelated with modular-UV weight — and the n=32 **random control shows a spurious IR-sector arrow (6.9 → 1.0 at n=128): unregistered sector-mining manufactures false arrows.** That exhibit is why mining stopped.
- **SYNTHESIS:** across 8 functional families, every chirality signal surviving the exact identities is a trace/free-energy scalar decaying/saturating with n. The half-sided arrow is carried by structures finite symmetric truncations ERASE (infinite-volume Fredholm index; semigroup one-sidedness). **F-K1's finite-D projection as a single-particle modular functional is not well-posed — returned to the theory** with three reformulation routes + the mandatory **three-control gauntlet** for any future witness: (1) T-invariant model null BY A NAMEABLE SYMMETRY, (2) random nested subspace null, (3) signal non-decreasing with n. **Do not resume hsmi-stab without a science-side pre-registered witness that passes all three.**

### What remains reusable in tools/hsmi-stab/ (keep, don't rebuild)
The skeleton is a working complex-Gaussian modular laboratory on liborrery: `Dsyevd`/`Zheevd` host wrappers (COL-MAJOR fill — see gotchas), covariance→modular pipeline (clamp γ=1e−12), the FIXED Fock oracle (pins σ_t conventions to 3e−12), negative controls, determinism checks, and the probe battery `HSMI_PROBE=1..9` (leak table · log-lattice spill · Borchers split · ax+b Frobenius+spectral · transport · minspec · site winding · ladder · cocycle+UV/IR). Also designed-but-unbuilt, recorded in MODULE: thermofield-purification Fock oracle for mixed complex Gaussians (`C_pure=[[C,D],[D,1−C]]`, `D=√(C(1−C))`), convex-mix deformation families (positivity free), eigenphase extraction via `H_α` + Rayleigh certificate.

### NEW gotchas from this session (add to the permanent list)
- **Complex Hermitian into cuSOLVER: fill COL-MAJOR.** A row-major-filled Hermitian buffer read col-major is the transpose = the CONJUGATE model (opposite chirality). (Real symmetric never exposed this.)
- **The back-rotation bug class:** `V·ỹ·V` vs `V·ỹ·Vᵀ` — forward and inverse similarity transforms need DIFFERENT index patterns on a col-major eigenvector buffer; copy-pasting the forward pattern is the trap. Diagnostic signature: residual ~t-independent and wrong even at t=0.
- **Eigenphases of a unitary (probe-grade):** diagonalize `H_α = cosα·(V+V†)/2 + sinα·(V−V†)/2i` (α=0.3737 splits ±θ), then `θ_j = arg(v†Vv)`; `min|v†Vv|` is the no-mixing certificate (must be ≈1). A shipped tool would do the two-stage cluster solve.
- **Check any new witness against the D-028 identity list BEFORE implementing:** square-block singular values (blind), unitarily-invariant norms (blind), Frobenius forms with commutator cross-terms (cyclicity), Toeplitz-window spectral functionals (flip×conj), half-filled PH self-conjugacy, nesting-monotonic scalars (control-positive).
- **Pre-register or it's mining:** the P9 random control's fake sector-arrow is the permanent exhibit.
- (Carried from earlier sessions: MODULE.md `## Build` must be a FENCED block; host≠device libm 1 ULP — pin per side; `--golden` ≥3×; never assert host==device transcendentals; cp1252 console → force UTF-8 in Python tools; commit selectively while subagents write runs/*; nvcc dual-pass: no `#ifdef __CUDA_ARCH__` around `__device__` helpers; PowerShell/bash share cwd per session.)

---

## ▪ RING 2 — the instrument (verifiable from git/goldens; unchanged 2026-07-09→10 except hsmi-stab)

| tool | lang | golden | measures | status |
|---|---|---|---|---|
| someone | CUDA | `aa5b731d` | evolutionary Someone-Criterion: gap (pureGap) vs zombies under stakes | DONE v1.1.1; **fp64 CPU oracle OWED (D-025)** |
| ratchet | CUDA | `91fce3c4` | Galton–Watson unwrite threshold (1−p)ρ=p; MC↔analytic 0.06% | DONE v1.0.1 |
| algebra | cuSOLVER | `1526918f` | critical c=1 entropy divergence (Part A ONLY; withdrawn Part-B excluded, D-018) | DONE v1.0.1; Part-B refit deferred |
| posit | Python | `7a22dd22` | parsimony auditor (Q3) | DONE v1.0.0 |
| mcts | CUDA | `6c596a53` | root-parallel UCT engine (known-optimum golden) | DONE v1.0.1 |
| autotune | Python | `c79002f2` | sweep/basin-finder; drives real tools (found ρ_c=0.258 vs 0.25) | DONE v1.0.0 |
| mcp | Python | `174ec02d` | stdio JSON-RPC surface; I-12 hashes on every run | DONE v1.0.0 |
| orreryd | C++20 | `86f133bb` | file-spool GPU-tenant job daemon; budgets/sentinels/status | DONE v0.1.0 |
| **hsmi-stab** | CUDA/cuSOLVER | **none** | F-K1 half-sidedness probe | **PARKED (D-027/D-028, Q-002): handback delivered; awaiting science reformulation** |
| lens | CUDA/OptiX | — | RT visualization | backlog (parked SPIKE, D-004) |

Plus `lib/` (liborrery, D-020, 42 KATs — the determinism spine: counter-RNG, fixed-order reductions, envelope/blake2b/golden plumbing) and `harness/verify.py` (polyglot build+selftest+golden CI).

**Science results produced so far:** (1) someone S5 (n=24, de-confounded): round-01's [Z,N,Z,N] → **[T,T,T,T]** — strong form unsupported, weak form not significant, zombie-wins overturned; gap ≈ fitness-neutral (`runs/someone_round01_reproduce.md`). (2) hsmi-stab: the D-028 negative chain — F-K1's finite-D witness family measured blind (`runs/hsmi-stab_k1_witness_handback.md`). Both honest negatives; both are the instrument working as designed.

---

## ▫ RING 3 — background (prune first)

- **Wave plan (adopted 2026-07-09):** Phase 6 = Wave 1: hsmi-stab (parked) → **trace-born** (C-TRACE) → **carve** (Layer-2/P2); D-026 order book = 11 pre-contracted gears, each opening contract-first with mandatory cold two-pass + science-handback. Phase 7 = Wave 2 (ratchet-v2, clifford/mipt, everpresent [I-14 frozen DESI data], someone-v2, modfluc, fork, prequent, algebra v1.1). Phase 8 = scale (D-023/D-024 when opened).
- **Reference engines (read-only):** `C:\Users\user\Desktop\DSA\` (dak/criticality), `C:\ASTRA-7`, `C:\RAYFORMER` (ADR-007), `C:\buddhabrot-main`. **Science canon (context, not dependency):** `C:\Fable_LLC\QUALIA_LAB\` (debts/established/receipts), the essay.
- **AUTONOMY_CHARTER:** modify only `C:\ORRERY`; reversible-default → log DECISION and proceed; breaking-contract/impossible-determinism/non-reproducing-golden/qualitative-non-reproduction → QUESTIONS.md/BLOCKERS.md + DEFER + advance. ≤15 active `// SPECULATION:` tags.
- **Local tooling:** `C:\everything\search.py` (locate), `C:\chunker\` (big files), `C:\imguard\`, `C:\earshot\`; archive viewer `C:\TRANSPORTER\claude_archive_viewer_v4.html`. Env memory: `C:\Users\user\.claude\projects\C--ORRERY\memory\`.
- **Operator interaction pattern that works:** restate-and-confirm checkpoints at session start; AskUserQuestion at genuine forks (Q-001/Q-002 both got prompt rulings); INIT docs authored at every save point; commits pushed as routine sync.

---

## ★ RECOMMENDATIONS — how to resume, and the optimal sequence (my judgment, 2026-07-10)

1. **Next session: open `trace-born` (C-TRACE), contract-first, fresh full budget.** It is the D-026 order book's next row and keeps Wave 1 moving while the keystone waits on the science. Copy the established loop exactly: pre-contract → contract v1.0.0 + schema + MODULE (with the oracle NAMED, I-11, and BOTH scope guards if applicable) → skeleton on liborrery → selftest battery → golden 3× → harness → cold two-pass → science-handback memo. **Apply the hsmi-stab lesson at contract time: before freezing the measurement functional, check it against the D-028 identity list and design its negative controls (nameable-symmetry null + random-control null + n-trend) into the selftest.** That check is cheap and would have saved hsmi-stab's v1.0.0 contract.
2. **Short-session alternative (or warm-up): someone's fp64 CPU oracle (I-11/D-025).** Bounded, pre-authorized, closes the one OWED item on the flagship. Tiny config replica in fp64 on host, gate vs the CUDA path with a declared tolerance, register in §8. Good first session for a fresh instance learning the codebase.
3. **hsmi-stab: do NOT resume until the science answers the memo's §4.** Any resumed witness must be pre-registered and pass the three-control gauntlet before implementation. If the science instead accepts the negative as final, a v1.1.0 could be re-scoped to what IS measurable (e.g. the deformation scaling of well-posed non-arrow quantities) — but that is a new D-026 opening decision, not a continuation.
4. **Hygiene each session:** bootstrap per CLAUDE.md (2-minute target); cold-verify before trusting recall; atomic commits; push at save points; author `docs/INIT_<next>_session.md` at the closing save point; update this file when the position changes materially.
5. **Watch-items:** someone's ~8-min golden makes full `harness/verify.py` slow — run the fast tools + lib KATs per-session and the full battery at wave boundaries; cuSOLVER determinism is sm_89-pinned — re-verify 3× after any driver/CUDA update (the lib device-pin KATs fire first); the `/lab` page regenerates via `_build_lab.py` + operator-run `npx wrangler deploy` — refresh it when trace-born lands (it renders from the live mcp registry; hsmi-stab, having no golden, correctly does not appear).

---

## ⟢ TAIL — this session verbatim-condensed (most recent first; replay to re-seed)

- **[2026-07-10, this session]** OPERATOR: pasted the stale someone INIT → I caught it, verified (someone golden byte-identical cold), asked → ruling: hsmi-stab session. Step 1: oracle fixed (back-rotation index bug; 3e−12). Step 2 → D-028 kill-chain (leak-norm theorem + Frobenius-cyclicity theorem + Toeplitz-congruence + transport-PH + minspec-generic + log-lattice-UV-mangled) → Q-001 filed → OPERATOR ruled: index/winding → P7 negative (site-basis dispersal) → INIT authored → OPERATOR: "paste INIT and run P8/P9" → P8 negative (aligned ladders, zero displacement), P9 negative (control exactly symmetric by S∘J theorem; chiral = shrinking trace drift; UV/IR closes cut-junk; random control's fake sector-arrow exhibit) → Q-002 filed → OPERATOR ruled: science-handback → memo written + hsmi-stab parked → OPERATOR: "push all" (verified: already synced at `87b8730`) → OPERATOR: "write the comprehensive handoff" (→ this file).
- **[2026-07-09]** Wave 0: lib/ built (42 KATs, 1-ULP host/device pin) + 4 bit-identical migrations + CMake fat preset + mcp v1.0.0 + orreryd v0.1.0 + /lab page → PUBLISHED by explicit operator instruction (repo + /lab live; publish gate spent). Then Wave 1 opened: hsmi-stab contract v1.0.0 frozen → same-day RETURNED TO DRAFT by its own probe (D-027).
- **[2026-07-05/06]** The 6-tool catalogue built to full standard (someone the template: contract v1.1.0, D-DAK-RNG confound fixed, S5 overturn [T,T,T,T], cold two-pass; then ratchet, posit, mcts, algebra, autotune — every one golden-frozen + CONFORMANT; harness polyglot).

*The spec is the product; the contract is sacred; the golden is load-bearing; the code is ephemeral. Structure, never acquaintance. The keystone got measured, not asserted — keep it that way.*
