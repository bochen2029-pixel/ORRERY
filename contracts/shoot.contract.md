# shoot — Contract  v1.0.0

## Purpose (what it measures)

`shoot` is ORRERY's **ODE-shooting eigenvalue instrument** (TinyUniverse R-6; D-032). v1.0.0 solves the
1D time-independent **Schrödinger / Sturm–Liouville eigenvalue problem** by the **shooting method**:
it integrates `ψ'' = 2·(V(x) − E)·ψ` (ℏ = m = 1) with fixed-step fp64 RK4, scans and bisects on the
energy `E` to satisfy the boundary condition `ψ → 0` at both ends, and returns the first `--levels`
eigenvalues, indexed by node count. The built-in potentials have **exact closed-form spectra** that are
the I-11 oracle the result is gated against:

- `harmonic` — V(x) = ½ x²; oracle **E_j = j + ½** (j = 0,1,2,…). Domain [−`xmax`, `xmax`].
- `square` — the infinite square well on [0, `length`] (V = 0 inside, ∞ walls); oracle
  **E_j = (j+1)²·π² / (2·length²)** (j = 0,1,2,…). Domain [0, `length`].

`shoot` measures the **spectrum of a linear differential operator** (structure/mathematics) — it says
nothing about qualia (§III-sealed). It is the reusable eigenvalue core the leverage suite
(`hsmi-stab`, `trace-born`, `carve`) and the TinyUniverse substrate ladder consume.

## CLI

| flag | type | range | default | meaning |
|---|---|---|---|---|
| --potential | enum | {harmonic, square} | harmonic | the potential V(x); selects the exact-spectrum oracle |
| --levels | int | 1 … 64 | 6 | number of eigenvalues to find (indexed by node count j = 0 … levels−1) |
| --xmax | double | > 0 | 8.0 | `harmonic`: half-domain; integrate [−xmax, xmax] with ψ→0 at ±xmax. Ignored for `square`. |
| --length | double | > 0 | 3.141592653589793 | `square`: well width L; domain [0, L]. Ignored for `harmonic`. |
| --steps | int | 100 … 4000000 | 4000 | fixed RK4 steps across the domain (dx = domain/steps) |
| --tol | double | ≥ 0 | 1e-4 | G-ORACLE-MISMATCH gate: max relative eigenvalue error allowed |
| --seed | int | ≥ 0 | 0 | RNG seed — **reserved**; `shoot` uses no RNG (deterministic by construction). Echoed for envelope uniformity. |
| --json | flag | | off | emit the JSON envelope on stdout |
| --csv PATH | path | | off | write per-level rows (j, eigenvalue, oracle, rel_err) to PATH |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run the frozen golden params; print the canonical hash; exit 0/1 vs `goldens/shoot/` |

## Output (result fields; each typed, with meaning)

| field | type | meaning |
|---|---|---|
| potential | string | resolved potential (`harmonic` \| `square`) |
| levels | int | number of eigenvalues found |
| xmax | double | resolved half-domain (harmonic; echoed as given) |
| length | double | resolved well width (square; echoed as given) |
| steps | int | RK4 steps used |
| eigenvalues | array[double] | the `levels` computed eigenvalues E_j (ascending, indexed by node count j) |
| oracles | array[double] | the exact analytic eigenvalues for the potential |
| rel_errs | array[double] | \|E_j − oracle_j\| / \|oracle_j\| per level |
| max_rel_err | double | the worst rel_err over the levels — the gate value |
| node_counts | array[int] | interior node count of each returned eigenfunction (must equal j — the labeling check) |

Arrays are canonically serialized element-by-element (`%.6f` for doubles, `%lld` for ints) inside `[]`;
they are part of the D-013 hash domain.

## Gates (declared negative-result conditions → exit 1)

| id | fires when | field | meaning |
|---|---|---|---|
| G-ORACLE-MISMATCH | max_rel_err > tol | max_rel_err | the shot spectrum does not reproduce the exact analytic spectrum within tolerance → **SUSPECT** (I-11); the solver/discretization is not trustworthy at this config |

`verdict` = `pass` iff no gate fired, else `fail`.

## Exit-code semantics (never conflate)
- `0` — the spectrum reproduced the exact oracle within `tol`.
- `1` — G-ORACLE-MISMATCH fired: a real, declared measurement that the shot spectrum missed the oracle
  (e.g. `--steps` too coarse, `--xmax` too small to bind the higher levels). A result, not a crash.
- `2` — error: bad/out-of-range param, or the scan failed to bracket `--levels` eigenvalues in the
  domain (raise `--xmax`/`--levels` sanity). Invalid run.

## Determinism

Declared object = `{tool?, seed, params, result, gates, verdict}` canonically serialized (D-013: floats
`%.6f` with −0 normalization; tool/version/notes excluded), blake2b-256 hashed.

- **No RNG** — `--seed` is reserved. Determinism is by construction: fixed-step RK4 + a fixed-ΔE energy
  scan + fixed-iteration bisection, all pure fp64 `+,−,*,/` and `sqrt` (IEEE correctly-rounded) —
  reproducible **and arch-portable** (no transcendentals in the declared path). Same params ⇒
  byte-identical declared output.
- Overflow safety: ψ is magnitude-rescaled during integration (a positive rescale preserves the
  endpoint sign and node structure the bracketing relies on) — the rescale does not enter the declared
  eigenvalues.
- No fast-math (D-021/I-13).

## Golden

params: `--potential harmonic --levels 6 --xmax 8 --steps 4000 --tol 1e-4 --seed 0 --json`
recorded: `goldens/shoot/` (declared.hash + captured stdout + NOTE.md)

Expected physics (informative, not the hash): `eigenvalues ≈ [0.5, 1.5, 2.5, 3.5, 4.5, 5.5]`
(the harmonic-oscillator ladder), `node_counts = [0,1,2,3,4,5]`, `max_rel_err` well under `tol` — the
GPU-free shooting solver reproduces the exact quantum-harmonic-oscillator spectrum E_j = j + ½.

## Deferred (honest scope — named v1.1+/v2 extensions, NOT in v1.0.0)
- Arbitrary supplied ODE RHS (an expression DSL or compiled plugin) — v1 is Schrödinger-form only.
- Two-sided shooting through a **Fuchsian / regular-singular point** (the sonic line the TinyUniverse
  critical-collapse build needed) — v1 integrates smooth potentials on a finite domain.
- Multi-parameter / complex-plane root-find (the R-7 basin/eigenvalue-in-the-plane locate).
- Floquet / periodic and generalized (A,B) eigenproblems; more potentials (Morse, Pöschl–Teller,
  Coulomb) with their analytic spectra as additional oracles.

## Change log
- v1.0.0 — initial contract. Sturm–Liouville shooting eigensolver; potentials `harmonic` (E_j=j+½) +
  `square` (E_j=(j+1)²π²/2L²); node-count labeling; G-ORACLE-MISMATCH vs the exact spectrum. Golden =
  harmonic, 6 levels.
