# INIT — hsmi-stab v1.1.0-draft session (authored 2026-07-10 at the D-027 save point)

Paste everything below the line as the first message of a fresh session in `C:\ORRERY`.

---

OPERATOR BRIEF — `hsmi-stab` v1.1.0-draft: fix the oracle, break the symmetry, then freeze.

Run your standard bootstrap first (CLAUDE.md order): ARCHITECTURE.md → RUN_STATE.md →
TASKLIST.md → DECISIONS.md (through **D-027**) → contracts/README.md → `git log --oneline -15`
+ `git status` → cold-verify reality before trusting recall: one fast tool
(`.\ratchet.exe --selftest && .\ratchet.exe --golden` from tools/ratchet) and the lib KATs
(`.\lib\orrery_selftest.exe` from the repo root). Files and git win over any recalled narrative.

Then read IN FULL, in this order — this is the tool's whole state:
1. `contracts/hsmi-stab.contract.md` — v1.0.0 under a **MODEL RETURNED TO DRAFT** banner. The
   *law that carries forward*: the δ± violation-functional shape, the two deformation families,
   the pre-registered gates (G-NO-ARROW / G-RIGID / G-SOFT-EXPONENT), the Fock-oracle requirement,
   the Type-I scope guard. Only the MODEL section is dead.
2. `tools/hsmi-stab/MODULE.md` — status, the probe data table, and this same step list.
3. `DECISIONS.md` **D-027** — the one-line theorem that killed the v1.0.0 model: a REAL hopping
   Hamiltonian gives a T-invariant state, so `U(−t) = conj(U(t))`, and every site-basis leak norm
   is provably identical in both flow directions. Half-sidedness is a **chirality** phenomenon;
   the proxy must break T. (Measured: violation symmetric to 4+ decimals at every t and n.)
4. `tools/hsmi-stab/hsmi-stab.cu` — the walking skeleton. Infrastructure battery is GREEN
   (blake2b KAT · covariance projector · many-body ground-energy cross-check 1e−9 · negative
   control · determinism both families). Keep: eigensolver plumbing, envelope/CLI spine, negative
   control, the Fock machinery, and the `HSMI_PROBE=1` diagnostic (it caught the blindness).

STATE: contract committed; **NO GOLDEN EXISTS — nothing from this tool is citable.** The selftest
currently FAILS honestly: the Fock-oracle check (real discrepancy, magnitude never printed) and
the two arrow checks (the model is blind — expected, now explained by D-027).

EXECUTE, in this order — each step gates the next; do not reorder:

1. **Print the Fock-vs-Gaussian oracle numbers first.** Add temporary prints inside
   `fock_oracle_max_err`, run `--selftest`, look at the two values per (t, direction). Diagnose
   and fix. Suspects, in order: (a) the region-internal JW ↔ global-mode identification (the
   B-parity twist `P_B` between global modes `c_{n+m}` and region-internal operators); (b) a
   residual conjugation/index error in the oracle's Gaussian comparator (it was already fixed once:
   generator-level leak is the single element `|⟨e_0|U(t)e_1⟩|`, NOT the row norm). The many-body
   ground-energy check passes at 1e−9, so the Fock construction itself is sound. **Do not proceed
   while the oracle disagrees** — it is the conventions anchor for everything after.
2. **Design the chirality-broken standard pair.** Leading candidate (D-027): sample the chiral
   fermion vacuum two-point kernel on a **logarithmic lattice** `x_k = e^{ak}` on the half-line —
   dilation = lattice shift, so 𝒩 = the shifted modes is the natural hsm candidate, and the
   covariance becomes **complex Hermitian** (T broken ⇒ the leak norm can finally see the arrow).
   HARD CHECK before adopting: the sampled C's eigenvalues must lie in [0,1] within the declared
   clamp γ=1e−12 (pick the quadrature/normalization that makes it so, or reject and evaluate the
   named alternatives: complex-hopping chain — check whether Nielsen–Ninomiya doubling restores an
   effective T first — or momentum-space chiral projection of the doubled chain). The Fock oracle
   must be re-derivable for the new model (complex Gaussian ⇒ `Zheevd` or a real-imaginary
   embedding of the Hermitian eigenproblem).
3. **Re-derive the t-scale empirically** with `HSMI_PROBE`: the arrow lives at small dilations
   only (the v1.0 probe measured saturation by t≈0.4 even for the blind functional; the old
   default 6.283 corresponds to a dilation of e^{39} — absurd on any lattice). Set the `--t-max`
   default from measurement; record the probe table in MODULE.md.
4. **Amend contract + schema + MODULE → v1.1.0** (changelog: model replaced per D-027; no golden
   ever existed, so this is the safe D-009-precedent path). Keep the pre-registered-threshold
   SEMANTICS; revalidate the default VALUES of `k-min`/`snap-frac`/`arrow-min` against the new
   model's locus behavior and set them BEFORE running any deformation sweep — they are
   predictions, not fits.
5. **Only then, the full loop:** selftest green (new-model Fock oracle + negative control +
   continuum anchor [δ₋ falls as n doubles at the locus] + determinism 2× both families) →
   golden 3× byte-identical → freeze `goldens/hsmi-stab/` (declared.hash + stdout.txt + NOTE.md)
   + `runs/hsmi-stab_golden.result.lock` → `python harness/verify.py --tool hsmi-stab` GREEN →
   **cold two-pass** (independent no-build-context subagent; citable-class, mandatory — this is
   the keystone's tool) → ARCHITECTURE §8 row + tools/README + TASKLIST → a science-handback memo
   (the someone-S5 pattern) ONLY if the physics came out clean at the pre-registered thresholds.

RULES (unchanged, never violate): `mass` family stays RNG-free; `noise` via the lib counter-RNG
only; no float atomics; fast-math banned (D-021/I-13); exit 1 = a gate fired (**G-RIGID firing IS
F-K1 firing — the loudest real result this instrument can produce, never a bug**) vs exit 2 =
error; both scope guards verbatim in `notes` (structure never acquaintance; the Type-I boundary —
measure the shadow and its scaling, never the Type III₁ claim); atomic commits (code + canon,
Invariant 10); save-point pushes are routine sync now, but creating NEW public artifacts still
asks first.

TIME-BOX SANITY: if step 1 (oracle agreeing) + step 2 (model chosen with positivity verified) is
all that fits, that is a successful session — freeze nothing premature, hand off at a clean save
point with this file's pattern. Durable over fast. Any mismatch against anything frozen = STOP,
mark SUSPECT, log a DECISION with the diff — never force, never re-baseline.
