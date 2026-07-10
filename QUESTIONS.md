# QUESTIONS — operator decisions needed (charter §5)

Reversible-default decisions are logged in DECISIONS.md and proceed; entries here are the ones the
operator must rule on. Newest first.

---

## Q-001 · hsmi-stab: what is the finite-D witness of the half-sided arrow? (2026-07-10 — BLOCKS v1.1.0-draft)

**Status: RULED (operator, 2026-07-10) — option (a): index/winding witness adopted as the primary
target, (b) mode-referenced transport as the measured cross-check.** hsmi-stab v1.1.0-draft is
UNBLOCKED in that direction. First implementation iteration (probe `HSMI_PROBE=7`, center-row
site-basis symbol winding of the compression) measured NEGATIVE — chiral winding 0 in the clean-gap
regime; the flow disperses in site space rather than translating at the probed scales; control
winding appears only where the gap has collapsed (junk). Named next iterations (MODULE.md): read the
winding in the rapidity / modular-ladder basis, and the Wiesbrock cocycle `V(t)=U_𝒩(t)U_𝒜(−t)`
eigenphase flow (order-asymmetric under t→−t — no blindness identity applies; G≥0 ⟺ one-way phase
flow). The pre-registration of exact thresholds happens at contract-amendment time, per D-026.

**The situation** (full evidence: DECISIONS.md **D-028**; reproducible probes in
`tools/hsmi-stab/hsmi-stab.cu`, `HSMI_PROBE=2..6`): the v1.0.0 leak-norm functional is
**identically direction-blind for every model** — `spec(MM†)=spec(M†M)` makes δ₊≡δ₋ a linear-algebra
identity, and one-sided subspace containment does not exist in finite dimensions at all. The natural
successor functionals were each evaluated this session and each is blind on the natural chiral
models: the Frobenius ax+b witness (trace cyclicity — theorem), the spectral ax+b witness (exact
flip×conj congruence of any Toeplitz window — measured, mechanism identified), the mode-referenced
transport element (PH self-conjugacy of the half-filled chiral sea — measured to 6 digits), and the
literal Wiesbrock many-body positivity `minspec(K̂_A−K̂_N)` (strong asymmetry but the T-invariant
CONTROL shows it even more strongly — it measures nesting monotonicity, not the arrow).

**Why this is yours to rule on:** the choice of replacement witness *re-defines what F-K1 firing
means* at finite D. Pre-registration of the falsifier's form is a science-side act (D-026
citable-class discipline); building a golden against a witness the science hasn't adopted would
manufacture the RAYFORMER failure mode.

**The options on the table** (D-028 synthesis):
- **(a) Index/winding witness** — the arrow as the Fredholm index of the half-infinite
  modular-symbol compression; finite shadow = exponentially-split near-zero modes whose eigenvector
  END-LOCALIZATION carries the direction (SSH-edge-mode pattern). Deepest ("why III₁" made
  measurable), integer-valued so pre-registration is cleanest; most design work.
- **(b) PH-asymmetric chiral state × mode-referenced transport** — partial right-branch filling
  breaks the last measured congruence; functional = directional boundary-transport profile; the
  existing Fock oracle pins it verbatim. Cheapest path; risk: "we measured an asymmetry we designed
  in", and the partial-filled sea's continuum hsm meaning needs a science-side statement.
- **(c) 𝒩-re-optimized (ε,δ)-tower forms** — move the sub-algebra with the deformation (the P1
  appendix form). Changes the measurement's shape substantially; unprobed.
- **(d) Return F-K1 to the science for reformulation** of its finite-D projection before any further
  instrument work.

**Recommendation:** (a) as the primary target with (b) as the measured cross-check — an
integer-valued, end-localization-signed witness is the strongest pre-registrable falsifier form, and
(b) alone is vulnerable to the designed-in-asymmetry objection. If the science prefers (d), the
D-028 kill-chain is itself a citable negative result about F-K1's finite-D testability.

**Until ruled:** hsmi-stab is DEFERRED-ON-QUESTION (TASKLIST Phase 6); no golden exists; nothing
from this tool is citable. Independent work continues (side item: `someone`'s owed fp64 oracle,
D-025).
