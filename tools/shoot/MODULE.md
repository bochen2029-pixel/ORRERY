# MODULE — `shoot` (v1.0.0)

**Purpose.** ORRERY's **ODE-shooting eigenvalue instrument** (TinyUniverse R-6; D-032). v1.0.0 solves the
1D Schrödinger / Sturm–Liouville eigenvalue problem `ψ'' = 2(V(x)−E)ψ` by the shooting method and returns
the first `--levels` eigenvalues, gated against the potential's **exact analytic spectrum** (I-11 oracle).
The reusable eigenvalue core the leverage suite (`hsmi-stab`/`trace-born`/`carve`) and the TinyUniverse
substrate ladder consume.

**Contract:** [`contracts/shoot.contract.md`](../../contracts/shoot.contract.md) (+ `shoot.schema.json`).
Contract is authoritative.

**Firewall.** Measures the **spectrum of a linear differential operator** (structure/mathematics); says
nothing about qualia — §III-sealed.

## Invariants
1. **Oracle-gated (I-11):** every result is checked against the exact closed-form spectrum — `harmonic`
   E_j = j+½, `square` E_j = (j+1)²π²/2L² — via `G-ORACLE-MISMATCH` on `max_rel_err`. Never a self-asserted
   spectrum.
2. **Determinism (no RNG, arch-portable):** fixed-step RK4 + fixed-ΔE (0.1) energy scan + fixed-iteration
   (80) bisection, using only fp64 `+,−,*,/` and `sqrt` (all IEEE correctly-rounded) — byte-identical AND
   reproducible cross-arch (no transcendentals in the declared path). `--seed` reserved.
3. **No fast-math** (D-021/I-13).

## Internal design
- **Shooting** (`shoot_endpoint`): integrate `ψ''=2(V−E)ψ` as the system `(ψ,φ=ψ')` with RK4 from one
  boundary (ψ=0, ψ'=1); ψ is magnitude-rescaled when it exceeds 1e6 (positive rescale → sign/node
  structure preserved) so the forbidden-region growth never overflows; only the **sign** of the endpoint ψ
  is used for bracketing. Interior **node count** is taken only in the classically-allowed region
  (|x| < √(2E) for harmonic) — the exponentially-small tails carry numerical sign-wiggles that are not
  physical nodes.
- **Eigenvalue search** (`find_eigs`): scan E upward with ΔE=0.1 from 0.02 to `oracle(levels)·1.25+2`;
  each sign flip of the endpoint ψ brackets an eigenvalue → 80-iteration bisection → E to ~1e-15. The
  scan returns eigenvalues ascending; node count labels each (must equal j). Fewer than `--levels`
  bracketed → exit 2.
- **Potentials:** `harmonic` V=½x² on [−xmax,xmax]; `square` V=0 on [0,L] (infinite walls). Adding
  potentials with known spectra (Morse, Pöschl–Teller, Coulomb) is an additive MINOR.
- **Envelope/hash/CLI spine** from `lib/` (liborrery, D-020): `fmt6`/`fmti`, `declared_object`/
  `full_envelope`, `golden_check`, `die2`/`parse_*`, `blake2b` — D-013 hash domain unchanged. Arrays
  (`eigenvalues`/`oracles`/`rel_errs`/`node_counts`) are serialized element-by-element.

## Build
Host-only C++ (no GPU kernel; `nvcc` compiles the host TU), from `tools/shoot/`:
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 shoot.cu ../../lib/envelope.cpp -o shoot.exe'
```
```
.\shoot.exe --selftest
.\shoot.exe --golden
.\shoot.exe --potential harmonic --levels 6 --seed 0 --json
.\shoot.exe --potential square --length 3.14159265 --levels 4 --seed 0 --json
```

## Oracle (I-11) & golden
- Oracle: exact analytic spectra — `harmonic` E_j=j+½, `square` E_j=(j+1)²π²/2L² — asserted in `--selftest`.
- Golden: `--potential harmonic --levels 6 --xmax 8 --steps 4000 --tol 1e-4 --seed 0`; declared blake2b
  `9625b268…`; reproduced byte-identical ≥3×. `eigenvalues=[0.5..5.5]` = oracles (max_rel_err 0),
  `node_counts=[0..5]`. See `goldens/shoot/NOTE.md`.

## Known issues / scope (honest, v1.0.0 — deferred, per D-032)
- **Schrödinger-form only.** No arbitrary supplied ODE RHS (an expression DSL / compiled plugin) — v2.
- **No regular-singular-point (Fuchsian) crossing** (the sonic line the TinyUniverse critical-collapse
  build needed) — v1 integrates smooth potentials on a finite domain.
- **No multi-parameter / complex-plane root-find** (R-7 basin/eigenvalue-in-the-plane), no Floquet /
  generalized (A,B) eigenproblems.
- **Two built-in potentials** (`harmonic`, `square`); more (Morse, Pöschl–Teller, Coulomb) with their
  analytic spectra are additive MINORs.
- `--xmax` must be large enough to bind the requested levels (else higher levels miss the oracle or the
  scan fails → exit 2); the golden's xmax=8 binds 6 harmonic levels comfortably.
