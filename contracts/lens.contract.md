# lens — Contract  v1.0.0

## Purpose (what it measures)

`lens` is ORRERY's **RT-core renderer + oracle-gated geometric-measurement** tool. It renders a
parameterized *physics-scene silhouette* with OptiX (hardware ray tracing on the RTX 4070 Ti SUPER)
and measures the silhouette's **projected cross-section** by orthographic ray casting. The declared
measurement is computed by an **analytic baseline** (pure arithmetic — the deterministic golden
anchor and the I-11 oracle) and independently by the **OptiX RT path**, which must agree with the
baseline within a pre-registered pixel tolerance (I-13 paired-oracle). The two shipped scenes have
exact closed-form cross-sections:

- `sphere` — a sphere of radius `R`; oracle cross-section **π R²** (a calibration/known-answer scene).
- `bhshadow` — the Schwarzschild **photon-capture shadow**: the capture region is the disk of the
  critical impact parameter `b_crit = 3√3·M = √27·M`; oracle capture cross-section **σ = 27π M²**
  (M in geometric units G = c = 1). This is the genuinely relativistic, citable number.

**Honest scope (D-004, binding).** `lens` v1 **renders geometry**; it does **not** integrate curved
null geodesics. It draws the *known* hard-edged capture boundary at `b_crit` and measures its area
against the exact GR oracle. The geodesic-integrated (light-bending) render, and any claim that RT
cores *accelerate* that integration, are the **pre-registered compute-SPIKE** (see "Parked SPIKE"
below) — measured later, never asserted here. The RT path in v1 is used only for the render and as
the I-13 cross-check of the baseline; `lens` makes **no speedup claim**.

`lens` measures geometric/optical **structure** (cross-sections, silhouettes) only. It makes no
acquaintance/qualia claim (§III-sealed).

## CLI

| flag | type | range | default | meaning |
|---|---|---|---|---|
| --scene | enum | {sphere, bhshadow} | sphere | which physics scene to render/measure |
| --radius | double | > 0 | 1.0 | `sphere`: sphere radius R (world units). Ignored for `bhshadow`. |
| --mass | double | > 0 | 1.0 | `bhshadow`: black-hole mass M (geometric units); silhouette radius = √27·M. Ignored for `sphere`. |
| --width | int | 16 … 8192 | 1024 | raster width (pixels) |
| --height | int | 16 … 8192 | 1024 | raster height (pixels) |
| --extent | double | > silhouette_radius | 1.5 × silhouette_radius | orthographic half-extent of the square image plane (world units). Must strictly exceed the silhouette radius or the run is an error (exit 2). |
| --engine | enum | {baseline, both} | both | compute path. `baseline` = analytic CPU path only (no GPU; the portable, driver-independent anchor). `both` = CPU baseline (the declared anchor + I-11 oracle) **and** the OptiX RT path (cross-check via the I-13 agreement gate; requires a working OptiX device + sm_89). The **declared** `hit_pixels`/`area_*` always come from the baseline; RT adds `hit_pixels_rt`. |
| --tol-oracle | double | ≥ 0 | max(1e-3, 8·extent /(width·silhouette_radius)) | relative-error gate on the measured vs. oracle cross-section (resolution-aware default bounds the O(1/width) pixel-discretization error) |
| --tol-rt-px | int | ≥ 0 | 64 | max \|hit_pixels_rt − hit_pixels\| before G-RT-DIVERGE fires |
| --render PATH | path | | off | **opt-in, NON-DECLARED** (Invariant 3): write a binary PPM (P6) image of the shaded silhouette to PATH. Never affects the declared object; never blocks. |
| --seed | int | ≥ 0 | 0 | RNG seed — **reserved**; `lens` uses no RNG (deterministic by construction). Echoed for envelope uniformity. |
| --json | flag | | off | emit the JSON envelope on stdout |
| --csv PATH | path | | off | (reserved; no per-row series in v1.0.0 — flag accepted, writes a single summary row) |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run the frozen golden params; print the canonical hash; exit 0/1 vs `goldens/lens/` |

## Output (result fields; each typed, with meaning)

| field | type | meaning |
|---|---|---|
| scene | string | resolved scene name (`sphere` \| `bhshadow`) |
| silhouette_radius | double | exact silhouette radius: R (sphere) or √27·M (bhshadow), world units |
| image_extent | double | resolved orthographic half-extent |
| width | int | raster width |
| height | int | raster height |
| total_pixels | int | width × height |
| hit_pixels | int | primary rays intersecting the geometry — **analytic baseline** (deterministic integer) |
| hit_fraction | double | hit_pixels / total_pixels |
| area_measured | double | hit_fraction × (2·extent)² — measured projected cross-section (world units²) |
| area_oracle | double | exact analytic cross-section: π R² (sphere) or 27π M² (bhshadow) |
| area_rel_err | double | \|area_measured − area_oracle\| / area_oracle |
| engine | string | which path(s) ran (`baseline` \| `both`) |
| hit_pixels_rt | int | primary rays intersecting via the OptiX RT path; **−1** when RT did not run (engine=baseline) |
| rt_baseline_delta | int | \|hit_pixels_rt − hit_pixels\|; **−1** when RT did not run |
| rt_agrees | int | 1 if RT ran and rt_baseline_delta ≤ tol_rt_px; 0 if RT ran and diverged; **−1** when RT did not run |

Sentinel `−1` (not `null`) keeps every declared field a fixed JSON number for a stable hash domain.

## Gates (declared negative-result conditions → exit 1)

| id | fires when | field | meaning |
|---|---|---|---|
| G-ORACLE-MISMATCH | area_rel_err > tol_oracle | area_rel_err | the rendered silhouette does not reproduce the exact cross-section within tolerance → the measurement is **SUSPECT** (I-11), not trustworthy at this config |
| G-RT-DIVERGE | engine = both and rt_baseline_delta > tol_rt_px | rt_baseline_delta | the OptiX RT path disagrees with the analytic baseline beyond tolerance → RT render **SUSPECT** (I-13 paired-oracle failed; re-verify toolchain) |

`verdict` = `pass` iff no gate fired, else `fail`. A fired gate is a real, declared measurement about
the render's fidelity — never a silent fallback (I-11).

## Exit-code semantics (never conflate)
- `0` — measured; both gates pass (silhouette reproduced the oracle and, if RT ran, RT agrees).
- `1` — a declared gate fired (G-ORACLE-MISMATCH or G-RT-DIVERGE): a real SUSPECT result.
- `2` — error: bad/out-of-range param, `extent ≤ silhouette_radius`, or CUDA/OptiX failure. Invalid run.

## Determinism

Declared object = `{tool?, seed, params, result, gates, verdict}` canonically serialized (D-013:
floats `%.6f` with −0 normalization; tool/version/notes excluded), blake2b-256 hashed.

- **No RNG** — `--seed` is reserved and changes nothing declared; determinism is by construction
  (like `posit`). Same params ⇒ byte-identical declared output.
- The **baseline** `hit_pixels` is a pure integer pixel count (order-independent integer sum) — fully
  reproducible on any host, driver-independent.
- The **OptiX RT** `hit_pixels_rt` is deterministic on the **pinned toolchain**: `-arch=sm_89`
  (RTX 4070 Ti SUPER) + OptiX 9.1.0 + driver 610.47 — measured byte-identical across ≥3 runs. It is
  toolchain-pinned like every CUDA golden; a driver/OptiX/arch change may shift it and requires an
  operator-signed re-baseline (`goldens/lens/NOTE.md`), exactly the sm_89-pin protocol used elsewhere.
- No fast-math (D-021/I-13): the OptiX-IR/PTX and host are compiled without `--use_fast_math`.
- `--render` output, wall-clock timings, and the RT-vs-baseline wall-time (the SPIKE's future input)
  are NON-declared and excluded from the golden.

## Golden

params: `--scene bhshadow --mass 1.0 --width 1024 --height 1024 --engine both --seed 0 --json`
(derived `extent = 1.5·√27 ≈ 7.794229`; the Schwarzschild capture cross-section, rendered + RT-checked)
recorded: `goldens/lens/` (declared.hash + captured stdout + NOTE.md with the toolchain pin)

Expected physics (informative, not the hash): `area_oracle = 27π ≈ 84.823002`; `area_rel_err ≲ 3e-4`;
`rt_agrees = 1`. The hash covers the exact declared integers/floats.

## Parked SPIKE (D-004 — pre-registered, NOT claimed in v1)

**Question:** does RT-core-accelerated **curved null-geodesic** rendering (polyline rays integrated
through the Schwarzschild metric against a BVH of the discretized geometry) reproduce the shadow at
**lower wall-time** than an fp64 CUDA geodesic-integrator baseline, at **matched** shadow-radius
accuracy? **Honest baseline:** the fp64 CUDA geodesic integrator (same declared shadow measurement).
**Success/graduates:** a measured speedup ⇒ a `lens` MINOR adding a `--geodesic` engine + its own
golden. **Kill criterion (pre-registered):** if RT does not beat the baseline by **≥ 1.5×** at
matched accuracy, **retire the RT-as-isomorphic-compute claim for relativistic geodesics** and record
it (the RAYFORMER ADR-007 protocol). Until run and graduated, `lens` asserts no speedup; RT is used
only for the render and the I-13 cross-check.

**RESOLUTION (2026-07-12, measured — D-030): the SPIKE was RUN and RETIRED.** The fp64 CUDA geodesic
baseline integrates the Schwarzschild null-geodesic Binet equation and *derives* the shadow
(σ = 27π M², b_crit = √27 M, validated to 2.5e-6) at ~1.01×10⁷ ray-integrations/sec; an RT shell-marcher
at matched accuracy (≈6000 traces/ray at 5.89×10⁹ traces/sec) manages only ~9.8×10⁵ rays/sec — the
baseline is ~10× faster, so the ≥1.5× kill fires. RT-cores-as-compute is retired for relativistic
geodesic rendering (the cost is fp64 ODE arithmetic, not ray-geometry intersection). The geodesic
baseline itself validated and is a candidate v1.1.0 MINOR. Memo: `runs/lens_spike_geodesic.md`.
`lens` v1.0.0 behavior/golden are UNCHANGED by this resolution.

## Change log
- v1.0.0 — initial contract. Scenes `sphere` (oracle π R²) + `bhshadow` (oracle 27π M², b_crit=√27 M);
  orthographic cross-section measurement; baseline + OptiX RT engines with the I-13 agreement gate;
  D-004 honest scope (render only; geodesic compute-SPIKE pre-registered with a kill). Golden =
  `bhshadow` at 1024².
- 2026-07-12 (no version bump — v1.0.0 behavior/CLI/schema/golden UNCHANGED) — the pre-registered
  compute-SPIKE was RUN and **RETIRED** (measured ~10× loss at matched accuracy; D-030,
  `runs/lens_spike_geodesic.md`). The fp64 geodesic baseline validated (derives 27π M² from the metric)
  and is a candidate v1.1.0 MINOR. See the RESOLUTION note in "Parked SPIKE" above.
