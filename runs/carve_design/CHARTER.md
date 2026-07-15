# carve — design tournament CHARTER (measurement-functional selection, contract-gate)

**Run by:** ORRERY Intercom (D-034), coordinated by the build agent (opus-4.8), human-in-the-loop at
the contract gate. **Status: DESIGN EXPLORATION — no contract freezes without operator review.** This
is the first use of the bus for its intended purpose: choose `carve`'s measurement functional *before*
a line of its code, and do it as an adversarial, D-028-guarded tournament so the hsmi-stab failure
mode cannot recur.

## The question (neutral)

`carve` is the last Wave-1 science gear (D-026 order book, Layer-2/P2). Its job: **does a fixed
Hamiltonian `H` on a finite Hilbert space pick out a PREFERRED factorization into subsystems** — a
preferred "carving" of the world into system ⊗ environment / A ⊗ B — or not? The pre-contract names the
mechanism: *candidate factorization frames scored by **Pauli-weight concentration** of `H`;
deterministic **basin search**; oracle = a **planted scrambler** (known answer) separating "search too
weak" from "no preferred factorization"; gates `G-NO-BASIN` / `G-MULTI-BASIN`, both informative.*

**The tournament's job is NOT to build carve.** It is to answer one make-or-break design question:

> **What EXACT scalar functional `Φ(H, frame)` should score a candidate factorization — and is it
> provably NOT blind (does it actually distinguish a genuinely-local H from a scrambled one, and does
> its planted-scrambler oracle have a recoverable known answer)?**

## Why this fork first — it is the hsmi-stab antidote

`hsmi-stab` (F-K1, the keystone) is PARKED because a measurement functional was frozen into a contract
and only *later* proven **blind** — identically ±t-symmetric for every model, dead by the identity
`spec(MM†)=spec(M†M)`; the natural successors each died by trace cyclicity, Toeplitz congruence, or a
control that out-signalled the real effect (D-028). Weeks of work measured proxy-design facts, not F-K1.
**The lesson (RUN_STATE, standing): check the functional against the D-028 identity list and design its
negative controls BEFORE freezing.** This tournament operationalizes exactly that check for carve.

## The fixed constraints (the box every design must live in — ORRERY doctrine, non-negotiable)

1. **Determinism-or-it-doesn't-ship** — (params, seed) → byte-identical declared output; a frozen
   `(params)→blake2b` golden. No wall-clock seeds, no float atomics in declared reductions, fast-math
   banned (I-13/D-021).
2. **Golden-gated + honest (the algebra Part-A / RAYFORMER discipline)** — a reported number is backed
   by an anchor (the planted-scrambler known answer), metamorphic relations (invariances it SHOULD
   have), and redundant recovery, or it is declared, never asserted. Measure structure; if a premise is
   undischarged, label and EXCLUDE it (no overclaim).
3. **Headless** — CLI in, one JSON envelope + CSV out, exit `0` pass / `1` a declared gate fired (a REAL
   result: G-NO-BASIN or G-MULTI-BASIN) / `2` error. Never conflate 1 and 2.
4. **Language:** C++/CUDA by default (D-005); `mcts` (the shipped UCT engine) is the basin search's
   subprocess in v1. Python only with a justification.
5. **The firewall** — carve measures STRUCTURE (does H prefer a factorization), NEVER acquaintance
   (qualia). §III-sealed, verbatim in `notes`.

## The candidate you must beat, and the graveyard

- **Incumbent (steelman it):** the pre-contract's **Pauli-weight concentration** — expand `H` in the
  Pauli basis relative to a candidate tensor-product structure (a frame = a unitary `U` conjugating the
  standard factorization), score by concentration on **low-weight (few-body) strings**; a basin = a
  local optimum of locality; search `U` with `mcts`.
- **Graveyard (seeded, respect it):** any functional that is **basis/unitarily blind** — invariant
  under a transformation that ALSO relates a local H to a scrambled H (it cannot, even in principle,
  see the effect). Re-proposal requires a NEW argument, not a restatement.

## The four refuter lenses (phase-2 worldviews; each states what counts as a KILL)

- **DETERMINISM** — buildable as a deterministic, golden-freezable C++/CUDA tool in budget? A design
  needing a nondeterministic optimizer, an unbounded search, or float-atomic reductions in the declared
  path is a kill of the claim leaning on it.
- **RESOLVABILITY** — can the functional + the `mcts` search **actually recover the planted answer** —
  measured, not argued? A pre-registered pass-bar (recovers the planted un-scrambling to tol; separates
  a genuinely-local H from a Haar-scrambled one by a stated margin at the studied qubit count) that no
  buildable instance reaches is a kill. **This is where a converge run drives carve later.**
- **ORACLE-HONESTY** — is the planted-scrambler oracle a REAL externality (a known answer the tool
  recovers), metamorphic-stable (invariant under relabeling/local-unitary-on-a-factor it should be), and
  redundantly recovered (two independent observables agree)? A number that is search-noise dressed as a
  basin is a kill (the D-018 discipline).
- **BLINDNESS (D-028) — THE MAKE-OR-BREAK LENS.** Before any design is admitted, it MUST survive the
  identity check. Ask of `Φ(H, U)`:
  - Is `Φ` invariant under a group that **also maps a local H to a scrambled H**? (e.g. global unitary
    conjugation with NO locality reference → blind: every H is "as local as" its scramble.)
  - Does `Φ` collapse by an algebraic identity (trace cyclicity, `spec(MM†)=spec(M†M)`, a Toeplitz/PH
    congruence, unitary-invariance of the spectrum) so it cannot depend on the frame at all?
  - **The three-control gauntlet (mandatory, from the hsmi-stab handback):** every candidate must name
    (1) a **null-by-a-nameable-symmetry** control (a case where Φ MUST be flat for a stated reason),
    (2) a **random/scrambled control** (Haar-scrambled H — Φ must NOT prefer a factorization), and
    (3) an **n-trend** (the signal must not decay/saturate to noise as qubit count grows). A design that
    cannot state all three, or whose real effect does not exceed its random control, is KILLED.

## Adjudication (phase 3)

- Rule every fork with a reason; never average functionals. Respect the graveyard; every deletion ships
  a **pre-registered reinstatement trigger**. **Steal list:** a good idea from a losing design is
  harvested regardless of its fate. **Internal agreement is weak evidence** — the recommended functional
  is `[ARGUMENT-GRADE]` until its pre-registered deciding experiment (a carve converge run on the
  planted oracle) is run; the register holds the doubt.

## Deliverables

- **phase1/`<persona>`.md** — one rigorous design per approach persona: the EXACT functional `Φ(H,U)`,
  the frame parameterization + `mcts` search, the planted-scrambler oracle construction with its known
  answer, the two gates, a reversibility lemma, its own D-028 blindness self-check + the three controls,
  cited literature, and any cheap ORRERY experiment it can run now.
- **phase2/lens-`<lens>`.md** — each lens applied across ALL designs: KILLED / WOUNDED / SURVIVED
  (mechanism-precise), a steal list, a weighted scorecard.
- **RECOMMENDATION.md** — the build agent's synthesis: the chosen `Φ` + why, the graveyard with
  reinstatement triggers, the concrete oracle + three-control design, and a **proposed carve contract
  sketch** — handed to the operator for the D-026 contract gate. **No contract is frozen here.**

## Arming (every subagent gets this)

Read-only ORRERY (`python C:\ORRERY\Intercom\intercom.py arm` prints the calling block). Literature to
ground the physics (verify via web search; cite precisely): the **preferred-factorization / quantum
mereology** problem — Cotler–Penington–Ranard "Locality from the Spectrum" (2019); Carroll–Singh
"Quantum Mereology" (2021); Zanardi et al. on tensor-product structures & operator locality; the
essay's Layer-2/P2. Every quantitative claim is backed by an ORRERY run (tool + params + declared
blake2b) or flagged `[ARGUMENT-GRADE]`.

*Structure, never acquaintance. The register holds the doubt. Check the identity list before you fall in love with a functional.*
