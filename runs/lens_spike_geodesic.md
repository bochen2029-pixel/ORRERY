# SPIKE result — lens compute-isomorphism (D-004): RT-cores-as-compute for relativistic geodesics

**Date:** 2026-07-12 · **Tool:** `lens` · **Pre-registration:** `contracts/lens.contract.md` "Parked SPIKE",
D-004. · **Protocol:** RAYFORMER SPIKES.md (time-boxed throwaway code; the deliverable is validated
numbers + the ruling). · **Verdict: RETIRE** (measured, decisive). Spike code: `tools/lens/_spike_geodesic/`.

## The pre-registered question
Does RT-core-accelerated **curved null-geodesic** rendering (polyline rays integrated through the
Schwarzschild metric against a BVH of the discretized geometry) reproduce the shadow at **lower
wall-time** than an fp64 CUDA geodesic-integrator baseline, at **matched shadow-radius accuracy**?
**Kill criterion:** if RT does not beat the baseline by **≥ 1.5×** at matched accuracy, retire the
RT-as-isomorphic-compute claim for relativistic geodesics (the RAYFORMER ADR-007 pattern).

## Method + the honest baseline (which validates against the exact oracle)
`geodesic.cu` (fp64 CUDA, one thread/ray) integrates the **exact** Schwarzschild null-geodesic Binet
equation `u'' = -u + 3M u²` (u = 1/r) with fixed-step RK4, classifying each ray captured (r→2M) vs
escaped (turning point). It is deterministic (fp64, fixed φ-steps, integer captured count).

**Physics validation (the baseline derives what v1 hard-coded):** integrating actual geodesics on an
orthographic impact-parameter grid classifies exactly the same shadow:
- 1024²: captured **366012** pixels (identical to v1's silhouette count), cross-section **84.820667**
  vs oracle **27π M² = 84.823002** (rel_err **2.75e-5**); b_crit derived **5.196081** vs √27 = 5.196152.
- 4096²: b_crit derived **5.196139** (rel_err **2.49e-6**). **RESULT: PASS.**

The keystone honesty check: v1 rendered the *known* b_crit silhouette; this baseline *derives* b_crit =
√27 M and σ = 27π M² by integrating the metric — same answer, from first principles. It also renders
the gravitationally-lensed image (photon ring + Einstein-ring lensing of a celestial background;
`lensed.ppm`, 1000² in 104 ms).

## The measurement (RTX 4070 Ti SUPER, sm_89, OptiX 9.1.0, driver 610.47)
- **RT trace throughput** (`rt_bench.cu`, the v1 OptiX pipeline, 1 sphere-trace/ray, 4096²×30 iters):
  **5.89×10⁹ traces/sec** (2.848 ms per 16.78M rays). This is the per-segment cost an RT shell-marcher
  pays.
- **fp64 CUDA baseline** (`geodesic.cu`, 4096² = 16.78M rays fully integrated, 6000 RK4 steps →
  b_crit rel_err 2.49e-6): **1656 ms** → **1.013×10⁷ full ray-integrations/sec**.

## The ruling (matched accuracy)
An RT "shell-marcher" approximates each geodesic as a polyline of straight segments, one `optixTrace`
per segment. To match the baseline's accuracy (b_crit to 2.5e-6, reached by 6000 4th-order RK4 steps),
a 1st-order shell-marcher needs **K ≳ 6000 segments/ray** (conservatively equal; realistically more).

| path | rays/sec at matched accuracy |
|---|---|
| fp64 CUDA baseline (6000 RK4 steps) | **1.013×10⁷** |
| RT shell-marcher (K = 6000 traces/ray = 5.89e9 / K) | **9.8×10⁵** |

**The baseline is ~10× FASTER.** For RT to even *tie* it needs K ≤ 581 traces/ray; to pass the **≥1.5×**
kill, K ≤ 387 — i.e. match 6000 RK4 steps' accuracy in < 387 linear segments, implausible for the
strongly-bent near-photon-sphere rays that set b_crit. **The kill criterion fires by a ~15× margin.**

**The RETIRE, and why (the RAYFORMER lesson, confirmed in-house for low-D):** the baseline's cost is
fp64 **ODE arithmetic** (RK4 steps), which RT cores do **not** accelerate — RT cores accelerate
ray-geometry **intersection** against complex BVH scenes. Here the "scene" is trivial (concentric
shells / one sphere), so BVH traversal wins nothing while adding per-trace launch/traversal overhead on
top of the *same* integration work. RT-as-compute loses exactly where the work isn't
intersection-shaped — precisely ADR-007, now measured for the intrinsically-low-D relativistic case
D-004 hypothesized "might win here." It does not.

## What survives (the keeper)
- **RETIRED:** RT-cores-as-isomorphic-compute for relativistic geodesic rendering. D-004's parked
  SPIKE is resolved — measured, not asserted.
- **KEPT (candidate lens v1.1.0 MINOR):** the fp64 CUDA geodesic integrator — it *derives* the shadow
  (27π M², b_crit=√27 M, validated to 2.5e-6) and renders the lensed black-hole image. A clean additive
  MINOR (a `--geodesic` measurement + the lensed render), oracle-gated and deterministic, whenever the
  operator wants it graduated to full standard (contract + golden + selftest + cold two-pass).

## Reproduction
```
# baseline (validate: derive the shadow, check vs 27 pi M^2)
nvcc -O3 -arch=sm_89 tools/lens/_spike_geodesic/geodesic.cu -o geodesic.exe -diag-suppress 177
geodesic.exe --width 4096 --height 4096            # b_crit rel_err 2.49e-6, 1656 ms
geodesic.exe --render lensed.ppm --width 1000 --height 1000 --obs-dist 22 --fov 32 --elev 2.5
# RT throughput (reuses v1 embedded PTX; rebuild lens first so lens_device_ptx.h exists)
nvcc -O3 -arch=sm_89 -std=c++17 -I"<OptiX>\include" tools/lens/_spike_geodesic/rt_bench.cu -o rt_bench.exe -lcuda -ladvapi32
rt_bench.exe 4096 30                                # 5.89e9 traces/sec
```
Numbers are wall-time (non-declared, hardware-pinned); the physics (b_crit, σ) is deterministic and
oracle-gated. This memo + D-030 + the contract's SPIKE-resolution note are the durable deliverables.
