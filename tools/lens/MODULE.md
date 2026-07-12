# MODULE — `lens` (v1.0.0)

**Purpose.** ORRERY's RT-core renderer + oracle-gated geometric-measurement tool. It renders a
parameterized *physics-scene silhouette* with **OptiX** (hardware ray tracing) and measures its
projected **cross-section** by orthographic ray casting. Two engines compute the *same* declared
quantity: an **analytic CPU baseline** (pure fp64 arithmetic — the deterministic golden anchor and
the I-11 oracle) and the **OptiX RT path** (cross-checked against the baseline, I-13 paired-oracle).
Shipped scenes have exact closed-form cross-sections: `sphere` (π R²) and `bhshadow` (the Schwarzschild
photon-capture shadow at `b_crit = √27·M`, oracle **σ = 27π M²**).

**Contract:** [`contracts/lens.contract.md`](../../contracts/lens.contract.md) (+ `lens.schema.json`).
The contract is authoritative; this file documents the implementation.

**Firewall (in every MODULE).** `lens` measures the geometric/optical **structure** of a silhouette
(cross-sections); it says **nothing** about whether anything *feels* (acquaintance) — §III-sealed.

**Honest scope (D-004, binding).** v1 **renders geometry**; it does **not** integrate curved null
geodesics, and makes **no RT-speedup claim**. The curved-ray (light-bending) render and the
"do RT cores *accelerate* geodesic integration?" question are the **pre-registered compute-SPIKE** in
the contract (kill criterion: retire the RT-isomorphism claim if RT does not beat the fp64 CUDA
baseline by ≥1.5× at matched accuracy — the RAYFORMER ADR-007 protocol). The RT path in v1 exists only
for the render and the I-13 cross-check.

## Invariants (violate ⇒ golden-superseding)
1. **Declared measurement = the CPU baseline.** `hit_pixels`/`hit_fraction`/`area_*` always come from
   the analytic baseline (driver-independent, pure integer pixel count). RT only *adds* `hit_pixels_rt`.
2. **Determinism.** No RNG (`--seed` reserved). Baseline is an order-independent integer count. The
   OptiX RT `hit_pixels_rt` is byte-identical run-to-run on the pinned toolchain (sm_89 + OptiX 9.1.0 +
   driver 610.47) — verified ≥3×. That field is toolchain-pinned; a driver/OptiX/arch change may shift
   it and legitimately fire `--golden` (re-baseline protocol in `goldens/lens/NOTE.md`).
3. **No fast-math** (D-021/I-13): both the OptiX PTX (`nvcc -ptx`, no `--use_fast_math`) and the host
   are compiled without fast-math.
4. **I-11 oracle = the exact analytic cross-section** (π R² / 27π M²), asserted in `--selftest`. A
   gate failure against the oracle (`G-ORACLE-MISMATCH`) sets the run **SUSPECT** — never a silent pass.
5. **I-13 paired-oracle = RT ↔ baseline agreement** within `tol_rt_px` (`G-RT-DIVERGE` else). The RT
   render is not trusted unless it reproduces the baseline count.
6. `--render` output, wall-clock timing, and RT-vs-baseline wall-time are **NON-declared** (Invariant 3).

## Internal design
- **Orthographic measurement.** Parallel rays (dir +z) from an image plane `[-extent,extent]²` at
  `z=-100·extent` strike the origin-centered silhouette sphere (radius `R` or `√27·M`). Orthographic
  projection makes the hit area an *exact* cross-section: `area = hit_fraction·(2·extent)²`, oracle
  `π R²` / `27π M²`. Default `extent = 1.5·silhouette_radius` (validated `> silhouette_radius`, else
  exit 2).
- **Baseline** (`lens.cu` `baseline_hits`): CPU fp64 predicate `u²+v² ≤ silR²` per pixel-center ray.
- **OptiX RT** (`lens.cu` `rt_hits` + `lens_device.cu`): a single-sphere GAS (built-in SPHERE
  primitive) + orthographic raygen writing a 1-bit hit payload per pixel; host counts hits. Pipeline
  mirrors `C:\RAYFORMER\src\render.cu` (the ADR-007-proven OptiX pattern). The device programs are
  compiled to **PTX** and **embedded** into `lens.exe` by `embed_ptx.py` (`lens_device_ptx.h`) — the
  exe is self-contained (no runtime .ptx dependency).
- **`bhshadow` honesty:** the capture cross-section is `π b_crit² = 27π M²` with `b_crit = √27·M` the
  *known* critical impact parameter; `lens` renders that hard-edged silhouette. It does **not** derive
  `b_crit` by integrating geodesics (that is the SPIKE).
- **Envelope/hash/CLI spine** from `lib/` (liborrery, D-020): `fmt6`/`fmti`, `declared_object`/
  `full_envelope`, `golden_check`, `die2`/`parse_*`, `blake2b` — declared hash domain unchanged (D-013).

## Build
Three chained steps (device→PTX, embed, host+lib link), from `tools/lens/`, in one command:
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -ptx -arch=sm_89 -std=c++17 -I"C:\ProgramData\NVIDIA Corporation\OptiX SDK 9.1.0\include" lens_device.cu -o lens_device.ptx && python embed_ptx.py lens_device.ptx lens_device_ptx.h && nvcc -O3 -arch=sm_89 -std=c++17 -I"C:\ProgramData\NVIDIA Corporation\OptiX SDK 9.1.0\include" lens.cu ../../lib/envelope.cpp -o lens.exe -lcuda -ladvapi32'
```
Link notes: `-lcuda` (CUDA driver API, for `optixInit`), `-ladvapi32` (OptiX's DLL-loader stubs call
the Windows registry). No `--use_fast_math`. `lens_device.ptx` and `lens_device_ptx.h` are build
artifacts (gitignored); the build regenerates them.
```
.\lens.exe --selftest
.\lens.exe --golden
.\lens.exe --scene bhshadow --mass 1.0 --engine both --seed 0 --json
.\lens.exe --scene bhshadow --mass 1.0 --render shadow.ppm --seed 0     # opt-in image (NON-declared)
```

## Oracle (I-11) & golden
- Oracle: the exact analytic cross-section — `sphere` π R², `bhshadow` 27π M² (b_crit=√27 M).
  Cross-checked in `--selftest` (constants, convergence, RT↔baseline agreement, determinism, gate teeth).
- Golden: `--scene bhshadow --mass 1.0 --width 1024 --height 1024 --engine both --seed 0`; declared
  blake2b `11e545b8…6766a2b`; reproduced byte-identical ≥3× on the pin. `area_rel_err ≈ 2.8e-5`;
  `hit_pixels_rt = hit_pixels = 366012`, `rt_baseline_delta = 0`. See `goldens/lens/NOTE.md`.

## Known issues / scope (honest, v1.0.0)
- **Render-only** (D-004): no curved-geodesic render; the geodesic + RT-speedup experiment is the
  pre-registered SPIKE (contract). No speedup is claimed.
- **RT arm is toolchain-pinned** (in the golden). A driver/OptiX/arch change can drift `hit_pixels_rt`;
  re-baseline is operator-signed (`goldens/lens/NOTE.md`). `--engine baseline` gives the
  driver-independent physics if only the RT arm drifts.
- **Orthographic only** in v1 (clean exact oracle). A perspective/celestial-backdrop pretty render and
  finite-observer Synge shadow are candidate MINORs.
- **`--csv`** writes a single summary row (no per-step series in v1).
- Scenes limited to `sphere` (calibration) + `bhshadow`. More scenes (light-cone mesh, isosurfaces)
  are additive MINORs.
