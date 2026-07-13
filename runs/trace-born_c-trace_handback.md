# SCIENCE-HANDBACK — trace-born / C-TRACE (F15): the Born-rule mechanical core reproduces in a decohering finite model; the one premise stays owed (D-BORN)

**From:** ORRERY tool-builder session, 2026-07-13 (Wave-1 gear #2, C-TRACE, opened + shipped)
**To:** QUALIA_LAB — F15 (`Born from noncontextual credence` `[DERIVATION]`), debt D-BORN (`Born from within` `[OPEN/W]`), throat T-Sorkin.
**Status of this document:** instrument-side finding. **This one has a golden** (`d4e3bf04`, a `result.lock`-grade tool output — unlike the hsmi-stab handback). Every claim below is labeled by its kind (the someone-S5 pattern). Reproduction provenance at the end.

---

## 1 · What C-TRACE asked the instrument

Essay-v5 / order-book **C-TRACE** (F15's mechanical leg): in a decohering finite model, do the
**normalized-trace weights over redundancy-defined branch projections** equal the **Born weights**
`|c_i|² = |⟨i|ψ⟩|²`? — with the analytic 2-branch case as the anchor and `G-BORN-MISMATCH` as the gun.
The v1.0.0 contract projected this onto: a system of `d` branches (weights `w_i`, `M=Σw_i`,
`c_i=√(w_i/M)e^{iφ_i}`) redundantly recorded across `R` environment fragments (records with pairwise
overlap `s`; `s=0` ⇒ complete decoherence); the redundancy-defined projection `Π_i = I_S⊗|r_i⟩⟨r_i|^{⊗R}`;
the weight `w_i^{trace} = Tr(Π_i|Ψ⟩⟨Ψ|)/Z`; compared to `|c_i|²`.

## 2 · What the instrument found, claim by claim

**[MEASURED — golden `d4e3bf04`, result.lock-grade]** In the fully-decohered regime (`s=0`, `R=6`,
weights `2,3`), the redundancy-trace weight reproduces Born to machine precision:
`w^{trace} = [0.400000, 0.600000] = |c_i|²`, `born_max_dev = 0`. Computed by **brute-force construction of
the full `d^{R+1}` state + partial trace** — the un-shortcut computation — not the closed form.

**[MEASURED — I-11 cross-check]** The brute-force weight equals the independent **analytic Gram-overlap**
`w_i ∝ Σ_a |c_a|²(G_{ia})^{2R}` to `oracle_max_dev = 0` on the golden, and to `<1e-9` off it (partial
decoherence, complex phases, `d=3`). The two paths are genuinely independent (verified adversarially in the
cold two-pass): a disagreement `>1e-8` forces exit 2 (SUSPECT — the tool is wrong, not the physics).

**[MEASURED — STEP B, envariance's engine]** Unitary fine-graining refines the `d` unequal-weight branches
into `M` micro-branches all at modulus `1/√M` (`microbranch_flat_dev = 0`, `unitarity_dev = 0`); equal
credence per micro-branch then forces the coarse weight `w_i/M = |c_i|²`. This is Zurek STEP B, reproduced
exactly (the receipt's `2,3 → 0.4,0.6`).

**[MEASURED — STEP A, envariance is non-vacuous]** At **equal** moduli the system swap is remotely erasable
by an environment counterswap (`envariance_residual = 0`); at the run's **unequal** moduli it is not
(`envariance_break = 0.201018`). Envariance genuinely singles out equal moduli — it is not a tautology.

**[MEASURED — the decohered-state spectrum route]** cuSOLVER `Zheevd` on `ρ_S` gives
`rho_purity = Σλ_k² = 0.52 = Σ|c_i|⁴`, and the spectrum equals `{|c_i|²}` — a *second, independent* recovery
of the Born weights as the eigenvalues of the decohered reduced state. `offdiag_max = 0` (fully decohered).

## 3 · The negative control — reproduction is contingent on decoherence, not automatic

**[MEASURED — control, both gates fire]** At **partial** decoherence (`s=0.5`, `R=2`): `born_max_dev = 0.0118 >
tol` (`G-BORN-MISMATCH` fires, exit 1) and `offdiag_max = 0.122 > coh-tol` (`G-NOT-DECOHERED` fires).
`objectivity_dev = 0.028` — a single fragment's record disagrees with the redundant majority. **[MEASURED —
Darwinism scaling]** Holding `s` fixed and increasing `R`, `born_max_dev → 0` monotonically and
`offdiag_max → 0` as `s^{2R}` — objectivity sharpens with redundancy. So the Born match is a *property of the
completed decoherence*, not a trivial identity: without redundant, orthogonal records, the trace weight is
not Born.

## 4 · What stays OWED to the science (the honest residue)

**[LABELED PREMISE — NOT discharged; D-BORN `[OPEN/W]`]** The instrument reproduces the *mechanics* that
force the quadratic form (STEP A + STEP B), but **not** the premise the whole route rests on:
**noncontextual credence = f(local state alone)** — the step from "envariance-invariant" to "equal
probability." Baker 2007's circularity objection lives exactly here. This premise is *labeled in the tool's
envelope `notes`, carried in MODULE.md, and excluded from every claim* (the `algebra` Part-B discipline). The
tool shows the form is forced *given* the premise; it does not close the premise, and it says **nothing about
why a probability is experienced** — structure, never acquaintance (qualia). §III-sealed.

**[THROAT — empirical, external]** T-Sorkin: third-order interference `κ₃` (triple-slit) remains consistent
with 0, so exact Born holds empirically — the instrument's structural reproduction is consistent with the
current experimental bound, and does not itself constrain `κ₃`.

**[DEFERRED — v1.1.0, if the science wants it]** the redundancy **scaling exponent** of `born_max_dev(R)`
(the quantum-Darwinism analogue of `algebra`'s `c`-fit — an objectivity critical rate); complex/random seeded
records; `d>8`. These are new-scope items, not a continuation.

## 5 · Bottom line for the theory

C-TRACE's finite, GPU-checkable core is **confirmed**: given the labeled credence premise, redundancy +
decoherence + unitary fine-graining reproduce Born `|c_i|²` exactly and by two independent routes (record
trace + decohered-state spectrum), and the reproduction demonstrably *fails* without decoherence. F15's status
as a **`[DERIVATION]` with one labeled premise** is the honest placement — the instrument does not upgrade it
to premise-free, and D-BORN stays `[OPEN/W]`. What the science can now cite as a reproducible tool result is
the *mechanical core*, hash-pinned; what it must not cite is a from-nothing derivation of credence.

---

## Reproduction provenance
- Tool `trace-born` v1.0.0, golden declared blake2b `d4e3bf04aef5596635a814a217d8822a5e6a2e1f49fc3f64febe1bdab27c540b`.
- Golden: `trace-born.exe --branches 2 --weights 2,3 --redundancy 6 --regime full --seed 0 --json` (det. 3×, sm_89).
- Control: `--regime partial --overlap 0.5 --redundancy 2 --weights 2,3` (both gates fire, exit 1).
- Contract `contracts/trace-born.contract.md` v1.0.0; cold two-pass `runs/trace-born_twopass_verify.md` (CONFORMANT 11/11, scope honest). Ports/sharpens `C:\Fable_LLC\QUALIA_LAB\gym\receipts\toy_a1_born_finegrain.py`.
- Reproducible bit-for-bit from the committing commit of this file (the trace-born landing commit on `master`).
