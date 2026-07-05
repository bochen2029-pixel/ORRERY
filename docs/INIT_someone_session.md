# ORRERY build-up — initialization prompt for the `someone` session

Paste the block below verbatim into a fresh Claude Code session opened in `C:\ORRERY\`.
It is the turnkey hand-off: reading order, mission, the sacred contract, and the three landmines
(determinism, the D-DAK-RNG confound, the round-01 result to reproduce). Written 2026-07-05.

---

````text
# INITIALIZE: ORRERY build-up session — build the `someone` tool

You are Claude Code, opened in `C:\ORRERY\`. You are the **tool-builder** for ORRERY: a headless,
contract-bounded CUDA/C++ **simulation instrument** for a final-theory-of-everything research project.
A previous architect session laid down the COMPLETE spec and canon. Your job is NOT to design or
re-architect — it is to BUILD the first tool against fixed contracts. Everything you need is on disk.

Environment: Windows 11, PowerShell + Bash available. GPU: NVIDIA RTX 4070 Ti SUPER (16 GB), CUDA 13.1,
MSVC 2022. You may run nvcc, cmake, python, git.

════════════════════════════════════════════════════════════════════════
STEP 0 — ORIENT. Read these files IN THIS ORDER before doing ANYTHING:
════════════════════════════════════════════════════════════════════════
 1. C:\ORRERY\CLAUDE.md              ← your operating manual (bootstrap, build loop, hard rules)
 2. C:\ORRERY\ARCHITECTURE.md        ← the spec/product. Internalize §5 invariants, §6 universal tool
                                       contract, §7 language rule, §8 tool catalogue, §9 verification
 3. C:\ORRERY\RUN_STATE.md           ← current state + your next concrete action + "subtleties"
 4. C:\ORRERY\TASKLIST.md            ← your ordered plan. You are doing PHASE 1 (`someone`), tasks S1–S6
 5. C:\ORRERY\DECISIONS.md           ← the 8 locked ADRs. Do NOT relitigate them
 6. C:\ORRERY\AUTONOMY_CHARTER.md    ← what you may/may not do; escalation rules
 7. C:\ORRERY\contracts\README.md    ← the contract discipline + universal envelope
 8. C:\ORRERY\contracts\someone.contract.md  ← THE SACRED CONTRACT you build exactly to (v1.0.0)
 9. C:\ORRERY\BUILD.md               ← the exact compile incantation + determinism checklist
10. C:\Users\user\Desktop\DSA\dak_evolution_complex.cu  ← the prototype you are porting (~980 lines;
                                       its kernels are your starting material — READ IT FULLY)

Optional deep reference (the science side already studied this sim — read if you want the confound
detail in step "BITE #2"): C:\Fable_LLC\QUALIA_LAB\library\debts.md (see D-DAK-RNG) and the confound
receipt C:\Fable_LLC\QUALIA_LAB\gym\receipts\dak_skeptic_rng_confound.py

After reading, RESTATE back to me (in your own words) your understanding of: (a) what ORRERY is and the
science↔instrument split, (b) exactly what the `someone` contract requires, and (c) the mission below —
BEFORE writing any code. This confirms orientation.

════════════════════════════════════════════════════════════════════════
YOUR MISSION THIS SESSION: build `someone` to the FULL ORRERY standard (TASKLIST S1–S6)
════════════════════════════════════════════════════════════════════════
`someone` evolves a population of embodied agents whose recurrent state runs an
encoder→bottleneck→decoder→predictor SELF-MODEL, in a configurable world (lights/predators/food/
day-night), and measures whether self-modeling agents (real bottleneck, k≪N, `pureGap`>0) out-survive
ZOMBIE agents (bottleneck bypassed, k=N, gapless) under stakes (energy depletion, predator death).
It tests the functional half of the Someone-Criterion's C2 (the gap) and the zombie clause.

`someone` is the TEMPLATE every future tool copies — build it IMPECCABLY. Deliverables:
 • tools/someone/someone.cu   — deterministic, headless, honors contracts/someone.contract.md v1.0.0
 • tools/someone/MODULE.md     — the module doc (use the template in tools/README.md)
 • goldens/someone/            — the frozen (params→hash) golden + captured stdout + NOTE.md
 • runs/someone_round01_reproduce.md + a result.lock — the real experiment write-up

════════════════════════════════════════════════════════════════════════
PRIME DIRECTIVES (non-negotiable — from the methodology in CLAUDE.md):
════════════════════════════════════════════════════════════════════════
• CONTRACT IS SACRED. Build EXACTLY to someone.contract.md v1.0.0 — every flag (name/type/range/default),
  the exact JSON output schema, exit codes (0 pass / 1 declared-gate-fired / 2 error). If you think the
  contract needs changing: additive/MINOR → bump semver + note in DECISIONS.md; breaking/MAJOR → STOP,
  file a QUESTION, escalate. Never silently edit the contract.
• DETERMINISTIC OR IT DOESN'T SHIP. Same params + same seed ⇒ byte-identical DECLARED JSON output.
• HEADLESS ONLY. CLI in; JSON to stdout (+ optional --csv) + exit code out. No window, no GUI, no prompt.
  (dak_evolution is already console/headless — good. Do NOT pull in any window code.)
• GOLDEN BEFORE "DONE". Freeze it; make --golden reproduce it; verify twice byte-identical.
• SIMS PROVE STRUCTURE, NEVER QUALIA. `someone` shows whether the gap confers FITNESS. It does NOT show
  the agent FEELS. Put this line in MODULE.md and in the JSON `notes`.

════════════════════════════════════════════════════════════════════════
THE THREE THINGS THAT WILL BITE YOU — read carefully:
════════════════════════════════════════════════════════════════════════
BITE #1 — DETERMINISM (the hard part).
  - Seed every curand state from a deterministic function of (seed + replica_index, agentId).
    The prototype seeds RNG from time(NULL) — REPLACE every wall-clock seed with the passed --seed.
  - NO ATOMICS in any reduction whose sum enters DECLARED output. In-block tree reductions (the
    prototype's s_reduce) are deterministic — fine. But population-level aggregates (mean fitness, etc.)
    must be summed in a FIXED order on the host (sort by agentId or index-order Kahan sum), never atomicAdd.
  - Pin launch config (blocks × threads); don't derive it from a device query in a way that varies output.
  - Host-side RNG for evolution (selection/mutation) AND environment must be seeded + fixed-order.
  - VERIFY: run `--golden` twice → declared JSON must be byte-identical. If not, hunt the bug BEFORE
    proceeding. (Common culprits: atomics, unseeded/time-seeded RNG, race in a reduction.)

BITE #2 — THE RNG CONFOUND (a real scientific-validity bug the science already found: debt D-DAK-RNG).
  In the prototype's runGeneration, the environment RNG is ONE continuous mt19937 stream that draws a
  DIFFERENT NUMBER of values per complexity level (L0≈10, L1≈130, L2/L3≈214 draws per generation, because
  more entities = more draws). Consequence: the base food/light LAYOUT silently DIFFERS across levels — so
  a `--complexity` comparison secretly compares DIFFERENT WORLDS, not the same world at different
  complexity. You MUST fix this so `--complexity` is a FAIR comparison. Two acceptable fixes:
     (a) reseed the env RNG at the TOP OF EACH GENERATION from a level-INDEPENDENT seed, so the base
         layout is identical across levels and only level-specific features (predators/night/moving) are
         added on top; OR
     (b) pre-draw a canonical level-independent layout (light/food positions) and only GATE the
         level-specific dynamics by --complexity.
  Sanity control: L2↔L3 already have identical draw counts (byte-identical but for the night toggle) — so
  L2 vs L3 cleanly isolates the night/deprivation effect. Use it to check your fix. Document the fix in
  MODULE.md and reference D-DAK-RNG.

BITE #3 — THE ROUND-01 FINDING you must REPRODUCE (headless, seeded, ensemble N≥8), and its GUARDS.
  The science's CPU analysis got a WOUNDED result you must reproduce and sharpen:
   • At FULL complexity (L3): normal (self-modeling) wins decisively — zombies extinct ~gen 22, Δfit≈+0.217.
   • BUT the complexity SWEEP is NON-MONOTONE (with the OLD confounded RNG: zombie won L0 & L2, normal won
     L1 & L3). So the STRONG claim "advantage grows monotonically with complexity" is NOT supported
     (wounded); the WEAK claim "the gap wins in threat/deprivation regimes (predators, night)" stands.
   • GUARDS (mandatory): (a) NEVER report the post-extinction normal/zombie fitness RATIO — it's a
     division artifact (~1e10 once a class is extinct); report `delta_fit` + alive-counts (the contract's
     output fields already enforce this). (b) `avgGap→1` is DEFINITIONAL for a saturated bottleneck, not
     evidence. (c) With the RNG confound FIXED + multi-seed, RE-CHECK whether "zombie wins L0/L2" survives
     — it may have been partly the confound. Report honestly which claims reproduce.

════════════════════════════════════════════════════════════════════════
THE BUILD LOOP (do in order; save after each; see CLAUDE.md "the build loop"):
════════════════════════════════════════════════════════════════════════
 S1  Write tools/someone/MODULE.md (purpose, scope-guard, contract link, internal design, determinism
     approach, RNG-confound fix, build command, provenance).
 S2  Implement tools/someone/someone.cu to the contract: CLI parse (ALL flags, ranges, defaults) →
     the sim (port dak kernels: recurrent W, encoder E, bottleneck K, decoder D, predictor P, sensory
     Ws, motor Wm, delay buffer; pureGap = C2 gap; viability = C3 stakes) → --ensemble (replicas seeded
     seed+r) → --complexity L0–L3 with the RNG CONFOUND FIXED → deterministic reductions → the exact JSON
     envelope → --csv → gates (G-ZOMBIE-WINS, G-NO-GAP) → --selftest → --golden.
 S3  Compile per BUILD.md; run --selftest (expect exit 0); run the golden config; confirm determinism
     (run --golden TWICE → identical declared JSON/hash).
 S4  Freeze the golden into goldens/someone/ (canonical-serialized declared JSON + blake2b hash +
     stdout.txt + NOTE.md).
 S5  Run the REAL experiment: --ensemble 8 (or more) across L0–L3 with the FIXED RNG. Write
     runs/someone_round01_reproduce.md + a result.lock. State clearly: does the STRONG form stay wounded?
     does the WEAK form stand? does "zombie-wins-L0/L2" survive de-confounding + multi-seed?
 S6  Cold two-pass self-check: re-read the contract fresh, re-run the golden, confirm conformance.
     Update ARCHITECTURE.md §8 + tools/README.md status → DONE.

COMPILE (single-file, from tools/someone/):
  cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 someone.cu -o someone.exe'
  then:  .\someone.exe --selftest   /   .\someone.exe --golden   /   .\someone.exe <params> --json

════════════════════════════════════════════════════════════════════════
SAVE DISCIPLINE & GUARDRAILS:
════════════════════════════════════════════════════════════════════════
• `git init` LOCALLY at the start for atomic save points. Commit after each completed task (tool +
  contract + golden + MODULE + RUN_STATE + TASKLIST in one commit). Update RUN_STATE.md every save.
• Do NOT create a public GitHub repo or `git push` — operator-gated (charter §3). Local git only.
• DO NOT: re-architect the canon · change the contract without a semver bump + note · ship
  non-deterministic output or skip --selftest/golden · use time(NULL) in any seed path · report the
  post-extinction ratio · claim the RNG-confounded sweep as clean · write Python for this (it's CUDA,
  D-005) · pull in any GUI/window code · claim anything about qualia (structure only).
• IF STUCK: file it (create QUESTIONS.md for reversible-default decisions, BLOCKERS.md for hard stops),
  mark the task DEFERRED, advance to independent work. A determinism bug you can't crack in a few careful
  passes → BLOCKER with exactly what you tried. Never burn the whole run on one sticky problem.

DEFINITION OF DONE (this session): someone.exe builds; --selftest green; golden frozen and --golden
reproduces it TWICE byte-identical; the round-01 finding reproduced with an ensemble and honestly
reported; MODULE.md complete; ARCHITECTURE §8 + tools/README updated; all committed locally; a clean
RUN_STATE.md handoff written. Then stop and report.

Begin now with STEP 0. Read the ten files in order, then restate your understanding of ORRERY, the
`someone` contract, and this mission before writing any code.
````
