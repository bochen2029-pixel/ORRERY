# INIT — hsmi-stab witness-iteration session (authored 2026-07-10 at the Q-001-ruled save point)

Paste everything below the line as the first message of a fresh session in `C:\ORRERY`.

---

OPERATOR BRIEF — `hsmi-stab` v1.1.0-draft, witness iteration: make the ruled-in index/winding
witness actually see the arrow, or kill it honestly.

Run the standard bootstrap first (CLAUDE.md order): ARCHITECTURE.md → RUN_STATE.md → TASKLIST.md →
DECISIONS.md (through **D-028**) → **QUESTIONS.md Q-001 (RULED)** → `git log --oneline -15` +
`git status` → cold-verify: `.\ratchet.exe --selftest && .\ratchet.exe --golden` from tools/ratchet
and `.\lib\orrery_selftest.exe` from the repo root. Files and git win over any recalled narrative.

Then read IN FULL:
1. `DECISIONS.md` **D-028** — the blindness kill-chain (two theorems, four measurements). Internalize
   WHY every unitarily-invariant functional of `(U(t), 𝒩)` is blind: `spec(MM†)=spec(M†M)`; trace
   cyclicity; Toeplitz flip×conj congruence; PH self-conjugacy of half filling; minspec measures
   nesting monotonicity. Any witness you design must dodge ALL of these — check each new candidate
   against the list BEFORE implementing.
2. `tools/hsmi-stab/MODULE.md` — status, the P2–P7 probe data, and the two pre-analyzed iterations.
3. `tools/hsmi-stab/hsmi-stab.cu` — the skeleton + probe battery (`HSMI_PROBE=1..7`). The Fock
   oracle is FIXED (3e−12) and pins every Gaussian-engine convention. Keep all probes.

STATE: contract v1.0.0 under the D-027/D-028 DRAFT banner; **NO GOLDEN EXISTS; nothing citable.**
Q-001 is RULED: index/winding witness primary, mode-referenced transport secondary. P7 iteration-1
(site-basis center-row symbol winding) was an honest negative: the flow disperses in site space;
winding readouts are junk once the symbol gap collapses.

EXECUTE, in this order:

1. **Ladder-basis winding (P8).** Order k_A's eigenbasis by eigenvalue (the modular ladder ≈ the
   rapidity lattice; the true flow is a ladder SHIFT by construction — U(t) is diagonal there, so
   the arrow must be read in the interplay: express 𝒩's projector / k_N's ladder in 𝒜's ladder
   basis and read the shift/winding structure of the overlap or compression there). Control first:
   the T-invariant chain must read exactly 0 by a symmetry you can name; then chiral across
   n ∈ {32, 64, 128}: the reading must be sign-stable, integer-quantized, and n-robust.
2. **Wiesbrock cocycle (P9).** `V(t) = U_𝒩(t)·U_𝒜(−t)` (embed `U_𝒩 ⊕ 1`). `V(−t) ≠ V(t)†` — no
   blindness identity applies. For a true hsm `V(t) = e^{2πitG}`, `G ≥ 0` ⟺ ALL eigenphases flow one
   way. Witness candidates: signed eigenphase-flow asymmetry at small t; winding of `det V(t)` along
   the ladder; the negative-flow weight as δ₋. V is unitary ⇒ normal ⇒ diagonalize via the Hermitian
   pair `(V+V†)/2, (V−V†)/2i` (they commute; watch degenerate blocks) or via `Zheevd` on
   `−i log V` built from a Schur-free eigenbasis. Control must be exactly symmetric; name the
   symmetry.
3. **Clamp-hardening.** The γ=1e−12 clamp caps |λ| at 27.6 and may distort ladder tails. Check
   witness stability under γ ∈ {1e−10, 1e−12, 1e−14} — a declared-constant sensitivity beyond
   tolerance is a design defect.
4. **Only if a witness discriminates chiral-vs-control cleanly and n-robustly:** define the
   deformation families for the chiral model (convex kernel mixes keep positivity for free:
   `(1−ε)C + ε·X`, X ∈ {conj(C) [de-chiralization, RNG-free], seeded random contraction [D-012
   counter-RNG]}), pre-register thresholds (the gates keep their G-NO-ARROW / G-RIGID /
   G-SOFT-EXPONENT semantics with the winding/gap in place of the leak norm), amend contract +
   schema + MODULE → v1.1.0, THEN the full loop: selftest (Fock oracle re-derived for the complex
   model via thermofield purification — `C_pure = [[C, D],[D, 1−C]]`, `D = √(C(1−C))`, Slater-build
   the 2m-mode pure state, naive partial trace is exact for the fixed-N Slater state) → golden 3× →
   harness → cold two-pass → science-handback.

RULES (unchanged): determinism or it doesn't ship; no float atomics; fast-math banned (D-021/I-13);
exit 1 = gate fired (G-RIGID IS F-K1 firing) vs exit 2 = error; both scope guards verbatim in
`notes`; atomic commits (Invariant 10); save-point pushes are routine sync, NEW public artifacts ask
first. Check every new witness against the D-028 kill-list before building it.

TIME-BOX SANITY: a session that ends with "P8/P9 both negative, here is the theorem or measurement
that killed each" is a SUCCESSFUL session — the keystone's honest output so far is proxy-design
theorems. Freeze nothing premature. Any mismatch against anything frozen = STOP, SUSPECT, DECISION.
