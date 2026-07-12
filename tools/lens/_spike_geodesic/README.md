# _spike_geodesic — the lens compute-SPIKE (D-004), measurement code

**Status: SPIKE (RAYFORMER SPIKES.md) — measured, RULED. Not a shipped tool; no contract/golden.**
The ruling + numbers are the deliverable: **`runs/lens_spike_geodesic.md`** (+ D-029/D-030). This code
is kept as the **evidence battery + graduation seed** (the hsmi-stab-probe precedent), NOT merged as a
tool. Build artifacts (`*.exe *.ptx *.ppm *.png`) are gitignored.

## What it measured (D-004: RT-cores-as-isomorphic-compute for relativistic geodesics)
- **`geodesic.cu`** — the honest fp64 CUDA baseline: integrates the exact Schwarzschild null-geodesic
  Binet equation `u'' = -u + 3M u²`; **derives** the shadow (σ = 27π M², b_crit = √27 M) validated to
  2.5e-6 against the oracle (v1 hard-coded that silhouette; this derives it), and renders the lensed
  black-hole image (photon ring + celestial lensing).
    - `geodesic.exe --width N --height N` → validate (derive the shadow, check vs 27π M²).
    - `geodesic.exe --render out.ppm --obs-dist 22 --fov 32 --elev 2.5` → the lensed render.
- **`rt_bench.cu`** — raw OptiX trace throughput (reuses the v1 embedded PTX `../lens_device_ptx.h`, so
  rebuild `lens` first). One sphere-trace/ray = the per-segment cost of an RT shell-marcher.

## The ruling
RT throughput 5.89e9 traces/sec; at matched accuracy (K≈6000 traces/ray) → 9.8e5 rays/sec vs the fp64
baseline's 1.013e7 rays/sec → **baseline ~10× faster; the ≥1.5× kill fires → RT-as-compute RETIRED**
for this regime. Reason (ADR-007): the cost is ODE arithmetic (RT can't accelerate it) and the scene
is too trivial for BVH traversal to win. See the memo.

## Graduation note
If graduated to **lens v1.1.0** (an additive `--geodesic` measurement + the lensed render), reimplement
under full discipline (contract-first, on liborrery, deterministic golden, cold two-pass) — this spike
code is the reference, not the shipped source.
