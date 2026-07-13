# golden — `trace-born` v1.0.0

## What is frozen
The declared output of
`trace-born.exe --branches 2 --weights 2,3 --redundancy 6 --regime full --seed 0 --json`
— the `toy_a1_born_finegrain` canonical case: a `d=2` system with integer weights `2,3` (Born target
`[0.4, 0.6]`), redundantly recorded across `R=6` environment fragments with **orthonormal records** (`s=0`,
complete decoherence).

Measured: the **normalized-trace weight over the redundancy-defined branch projection reproduces Born** —
`born_max_dev = 0`, cross-checked against the analytic Gram oracle `oracle_max_dev = 0` (I-11); the state is
fully decohered (`offdiag_max = 0`, `rho_purity = 0.4²+0.6² = 0.520000` from cuSOLVER Zheevd); the STEP-B
fine-graining equalizes to `1/√5` (`microbranch_flat_dev = 0`, `unitarity_dev = 0`); STEP-A envariance is
non-vacuous (`envariance_residual = 0` at equal moduli — remotely erasable; `envariance_break = 0.201018` at
the unequal run moduli — not erasable); the democratic control margin `flat_dev = 0.100000`; both gates clear;
`verdict = pass`, exit 0. Declared blake2b:
`d4e3bf04aef5596635a814a217d8822a5e6a2e1f49fc3f64febe1bdab27c540b`.

Files: `declared.hash` (blake2b-256 of the canonical declared object), `stdout.txt` (full JSON envelope).

## Hash domain (D-013, same as every ORRERY tool)
`blake2b-256` over the canonical serialization of `{seed, params, result, gates, verdict}` — `tool`/
`version`/`notes` excluded. `trace-born --golden` recomputes and compares.

## What it proves
1. **Determinism** — no RNG in the declared path (`--seed` inert), no float atomics, fast-math banned; the
   declared object is byte-identical across runs on the sm_89 pin (verified 3×).
2. **The F15 mechanical core (structure)** — in a finite decohering model, the redundant-record trace weight
   equals the Born weight `|c_i|²`, computed by brute-force full-state construction + partial trace and
   confirmed against the closed-form Gram oracle (I-11). Unitary fine-graining forces the quadratic form.
3. **The negative control discriminates** (selftest, not the golden) — at partial decoherence (`s=0.5, R=2`)
   both `G-BORN-MISMATCH` and `G-NOT-DECOHERED` fire: the reproduction is *contingent on decoherence*, not
   automatic. `objectivity_dev > 0` there — a single fragment disagrees with the redundant majority.

## What it does NOT prove (the honest residue — §III-sealed)
The **noncontextual-credence premise** F15 rests on — *credence = f(local state alone)* (the envariance→
equal-credence step; Baker 2007's circularity objection; science debt **D-BORN** `[OPEN/W]`) — is **labeled,
carried in `notes`, and excluded from every claim**. This tool shows the mechanics force `|c_i|²`; it does not
derive the premise, and says **nothing about why a probability is experienced** (qualia). Sims prove
structure, never acquaintance.

## Golden coupling (deliberate, narrow)
A small canonical anchor (`2^7` state) that reproduces the receipt exactly. The tool is CUDA because its
reason to exist is the exponential `d^{R+1}` regime (large redundancy / objectivity scaling) that Python
cannot reach; the golden is the fast unit-anchor, not the scale demonstration. Re-baseline only under an
operator-signed NOTE entry (old/new hash + reason).

## Environment
CUDA 13.1 + cuSOLVER, RTX 4070 Ti SUPER, `-arch=sm_89`, MSVC 2022. Determinism is fp64 + fixed-order
reductions; cuSOLVER `Zheevd` last-few-ULP cross-version drift is far below the `%.6f` declared precision.

## Re-baseline record
- (none — v1.0.0 freeze.)
