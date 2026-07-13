# shoot — cold-context two-pass verification

**Date:** 2026-07-12 19:43 -05:00 (Central)
**Verifier:** independent cold-context pass (no memory of the build; rebuilt from source, measured everything).
**Tool under test:** `shoot` v1.0.0 (ODE-shooting eigenvalue solver; host-only C++/fp64; TinyUniverse R-6, D-032).
**Method:** ARCHITECTURE.md §9 mandatory two-pass; RAYFORMER ADR-007 discipline (adversarial, source-not-narrative).

---

## OVERALL VERDICT: **CONFORMANT to v1.0.0** — 9/9 checks passed.

Reproduced golden blake2b-256 = `9625b268e8629f2400482ea72cde7efe7fae053e37ccc1998f0066957c39954b` (matches frozen).

One **minor non-blocking nit** (N-1, cosmetic, non-gated) is recorded below. It does not affect the golden,
any eigenvalue, the gate, the verdict, the hash, or any exit code, so it does **not** demote conformance.
Reported (not fixed) per verifier role.

---

## Per-check results

### 1. COLD REBUILD — PASS
- Deleted `tools/shoot/shoot.exe` (confirmed gone).
- Toolchain: `nvcc` release 13.1, V13.1.80.
- Ran the exact MODULE.md `## Build` command from `tools/shoot/`:
  `cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 shoot.cu ../../lib/envelope.cpp -o shoot.exe'`
- Result: clean build, `EXIT=0`, no warnings/errors. `shoot.exe` produced (251392 bytes; SHA256
  `8F7FD1B17D804332A52FCAE2B4BDDC3162000412A9F9072DF7C334C659248A37`).

### 2. GOLDEN (CRITICAL) — PASS
- `.\shoot.exe --golden` run 3×: every run `exit=0`, stderr `GOLDEN OK blake2b=9625b268…c39954b`.
- Printed hash == frozen `goldens/shoot/declared.hash`.
- stdout captured twice → SHA256 identical (`51AD9B73…`): **byte-identical** across runs.
- stdout also matches `goldens/shoot/stdout.txt` verbatim.
- A cold rebuild reproduces the golden exactly. No CRITICAL defect.

### 3. ANTI-STAMP (independent hash recomputation) — PASS
- Wrote an **independent** D-013 serializer in Python (hashlib blake2b, digest_size=32) matching
  `lib/envelope.cpp`: fmt6 = `%.6f` with −0→0 normalization, fmti = `%lld`, arrays element-by-element
  joined by `,`, key order `seed,params,result,gates,verdict`, tool/version/notes excluded.
- Reconstructed the golden declared object from **semantic values** (oracles I computed myself from
  E_j=j+0.5, not read from the tool) → independent blake2b-256 =
  `9625b268…c39954b` == frozen. **The hash is computed from the data, not stamped.**
- Cross-check: my serializer over the tool's own emitted numbers also == frozen (serializer equivalence).
  My semantic reconstruction is byte-identical to the tool-values reconstruction.
- TAMPER: `--levels 5` → declared hash `2624d74e8f4181e7…badaa73` ≠ frozen. Hash is data-sensitive.

### 4. THE PHYSICS (I-11 oracle — core claim) — PASS
Oracle formulas recomputed independently in Python and compared to the tool's **eigenvalues** (not its
"oracles" field):
- **harmonic** (`--levels 6 --xmax 8 --steps 4000 --tol 1e-4`): eigenvalues `[0.5,1.5,2.5,3.5,4.5,5.5]`
  == my E_j=j+0.5 == tool oracles; rel_errs all 0.000000; max_rel_err 0.000000; node_counts `[0,1,2,3,4,5]`;
  G-ORACLE-MISMATCH `fired:false`; verdict pass; exit 0.
- **square L=π** (`--potential square --length 3.141592653589793 --levels 4`): eigenvalues
  `[0.5,2.0,4.5,8.0]` == my E_j=(j+1)²π²/(2L²) (= (j+1)²/2 at L=π) == tool oracles; max_rel_err 0; exit 0.
- Extra robustness (adversarial, non-π length): **square L=1** → eigenvalues `[4.934802,19.739209,44.413220]`
  == independently-computed [π²/2, 2π², 9π²/2]; **harmonic xmax=10** → still exact, node_counts [0..5].
- CSV (`--csv`) exposes the true convergence at %.10f: harmonic E_j = 0.5000000000 … 5.5000000009,
  rel_err ~2.7e-12 … 1.6e-10 — genuine RK4+bisection numerics rounded to 0 at %.6f (matches contract's
  explicit "max_rel_err = 0 at %.6f"). The solver is honestly integrating the ODE, not hardcoding.

### 5. SCHEMA — PASS
- `contracts/shoot.schema.json` (draft-07) validates both harmonic-golden and square-L=π outputs (0 errors).
- `additionalProperties:false` has teeth: an injected extra top-level key is rejected.
- Array typing has teeth: a string element in `result.eigenvalues` is rejected.

### 6. EXIT CODES (never conflated) — PASS
| case | expected | observed |
|---|---|---|
| good config | 0 / pass | exit 0, verdict pass, JSON |
| forced mismatch `--steps 200 --tol 1e-9` | 1 / gate fired | exit 1, JSON, G-ORACLE-MISMATCH `fired:true`, value 2.5e-5 > thr, verdict fail |
| `--potential bogus` | 2 | exit 2, `error: --potential must be harmonic|square`, no JSON |
| `--levels 0` | 2 | exit 2, `error: --levels out of range [1,64]` |
| `--levels 65` (extra) | 2 | exit 2, `--levels out of range [1,64]` |
| `--steps 50` | 2 | exit 2, `error: --steps out of range [100,4000000]` |
| impossible `--levels 40 --xmax 3` | 2 (scan-failed) | exit 2, `error: scan failed to bracket --levels eigenvalues…`, no hang, no wrong answer |

- exit 1 is a **real declared negative**: coarse RK4 produces genuinely drifted eigenvalues
  (1.500003, 2.500014, …, 5.500140 — monotone error signature), not a crash. Never conflated with exit 2.

### 7. DETERMINISM + ARCH-PORTABILITY — PASS
- Declared output byte-identical across repeated runs (SHA256 equal).
- `--seed 0` vs `--seed 999`: only the echoed `seed` field differs; result+gates+verdict block byte-identical
  (physics is seed-independent; "no RNG" claim holds). NB: seed *is* in the hash domain, so the golden
  correctly pins seed=0.
- Grep of `shoot.cu`: **zero transcendentals** (no sin/cos/exp/log/pow/tanh/… ). Only `sqrt`
  (node-region limit √(2E), line 71) and `fabs` — both IEEE correctly-rounded. Declared path is
  `+,−,*,/,sqrt` only → arch-portability claim substantiated. (Square oracle uses PI constant × arithmetic;
  no runtime transcendental.)

### 8. HYGIENE — PASS
- No `--use_fast_math` / `--fmad` / `ffast-math` / `__fdividef` in source or the MODULE.md build command
  (plain `nvcc -O3 -arch=sm_89`). D-021/I-13 honored.
- Firewall present: `FIREWALL` constant (shoot.cu L26–28) echoed in every envelope `notes`
  (structure-not-acquaintance, §III-sealed).

### 9. SELFTEST — PASS
- `.\shoot.exe --selftest` → exit 0, `SELFTEST PASS`, all 14 sub-checks green (blake2b KATs, both oracle
  formulas, both spectra reproduced, node labeling, determinism, gate-teeth forced exit-1).

---

## N-1 (minor, non-blocking, cosmetic) — `square` node_counts labeling

- **Observation:** for `square` **L=π**, `node_counts` = `[1,2,3,4]`, but the contract (line 49) and
  MODULE.md state node count "**must equal j**" → expected `[0,1,2,3]`.
- **Mechanism:** in `shoot_endpoint`, the classically-allowed region limit is `1e300` for `square`
  (shoot.cu L71), so every sign change is counted — including the boundary zero of ψ at x=L, where RK4
  overshoot registers a spurious extra node. It is **L-dependent**: at **L=1** node_counts came back
  correct `[0,1,2]` (dx aligns differently with the endpoint zero).
- **Scope / impact:** `node_counts` is a **reported, non-gated** field. Eigenvalues, oracle match,
  max_rel_err, the G-ORACLE-MISMATCH gate, verdict, the D-013 hash, and all exit codes are **unaffected**;
  eigenvalue labeling-by-ascending-scan remains correct. The frozen golden is **harmonic**, whose
  node_counts are correct `[0..5]` at all tested xmax (8, 10). Therefore this is a cosmetic robustness nit
  in the square-well node heuristic, **not** a conformance failure.
- **Suggested (for the theory/builder, not applied here):** a v1.0.1 could exclude the final integration
  step (the enforced endpoint zero) from the `square` node count, or set a finite allowed-region limit for
  `square` mirroring the harmonic turning-point clamp. Contract line 49's "must equal j" wording could also
  be qualified for the `square` boundary case. Non-urgent.

---

## Reproducibility record
- Binary: SHA256 `8F7FD1B17D804332A52FCAE2B4BDDC3162000412A9F9072DF7C334C659248A37`, 251392 bytes,
  built 2026-07-12 19:42:41 via `nvcc -O3 -arch=sm_89 shoot.cu ../../lib/envelope.cpp` (CUDA 13.1, MSVC 2022 vcvars64).
- Golden declared blake2b-256: `9625b268e8629f2400482ea72cde7efe7fae053e37ccc1998f0066957c39954b` (reproduced ×3, byte-identical).
- No tool source, contract, or golden was modified during verification (verifier role).
