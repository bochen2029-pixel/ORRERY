# autotune — Contract  v1.0.0

## Purpose
The **parameter sweep / basin-finder**: sweep one parameter over a range, evaluate an **objective** at each grid point, and **locate** a feature of the resulting curve — an **argmax** (a band/basin peak) or a **level-crossing** (a threshold / critical point) — reporting the located value against a **pre-registered target** with a gate. The objective is EITHER a built-in analytic function (self-contained; the golden uses this) OR a real ORRERY tool subprocessed across the sweep (the compounding feature: it drives `someone`/`ratchet`/`mcts`/`algebra` etc. and reads a JSON metric). Answers "where is the band / where is the critical point?" mechanically, with a pre-registered target so a hit is a real result, not a fit.

**Scope guard:** locates a feature of a swept curve (a search/orchestration mechanism); says nothing about qualia. §III-sealed.

**Language:** Python (D-019 — orchestration glue: subprocess tools, parse JSON, locate a feature; no compute/scale/GPU). Deterministic: the built-in objective is exact and RNG-free; real-tool mode is deterministic iff the swept tool is (all ORRERY tools are); the sweep is a fixed grid. `--seed` is inert for autotune itself.

## Objective source (exactly one)
- **Built-in** `--objective peak|threshold` with `--obj-center C`, `--obj-width W`:
  - `peak`: `f(x) = exp(-((x−C)/W)²)` — a Gaussian basin peaked at `x=C` (locate with `argmax`; parabolic-refined).
  - `threshold`: `f(x) = 1/(1+exp(−(x−C)/W))` — a logistic that crosses 0.5 at `x=C` (locate with `crossing --level 0.5`; linearly interpolated).
- **Real tool** `--tool PATH --sweep NAME --metric FIELD [--fixed "ARGS"]`: for each grid value `x`, run `PATH ARGS --NAME x --json`, parse stdout JSON, read `result.FIELD` (dotted paths allowed). `--sweep` is the flag **name without dashes** (e.g. `rho`); autotune prepends `--`. Deterministic per the tool's own determinism; the tool's binary/source hash belongs in the experiment's `result.lock`.

## CLI
| flag | type | range | default | meaning |
|---|---|---|---|---|
| --objective | enum | peak\|threshold | (one of objective/tool) | built-in analytic objective |
| --obj-center | float | −1e6–1e6 | 0.5 | built-in objective center C (the true feature location) |
| --obj-width | float | 1e-6–1e6 | 0.1 | built-in objective width W |
| --tool | path | | (one of objective/tool) | an ORRERY tool exe/py to subprocess as the objective |
| --sweep | str | | (req. with --tool) | the tool flag NAME to sweep, **without dashes** (e.g. `rho`; autotune prepends `--`) |
| --metric | str | | (req. with --tool) | the result field to read (e.g. `p_unwrite_mc`; dotted ok) |
| --fixed | str | | "" | fixed args passed to the tool every run (include its `--seed`) |
| --lo | float | −1e6–1e6 | 0.0 | sweep lower bound |
| --hi | float | −1e6–1e6 | 1.0 | sweep upper bound (must be > lo) |
| --points | int | 3–4096 | 41 | grid points (inclusive of lo and hi) |
| --locate | enum | argmax\|crossing | argmax | locate the peak (argmax) or a level-crossing |
| --level | float | −1e6–1e6 | 0.5 | target level for `--locate crossing` |
| --target | float | −1e6–1e6 | (required) | the PRE-REGISTERED expected location (the falsifiable prediction) |
| --tol | float | 0.0–1e6 | 0.02 | \|located − target\| gate tolerance |
| --seed | int | ≥0 | 0 | inert for autotune (envelope uniformity) |
| --json | flag | | off | emit JSON envelope on stdout |
| --csv PATH | path | | off | the full sweep (x, f) to PATH |
| --selftest | flag | | off | internal battery; exit 0/1 |
| --golden | flag | | off | run golden params; hash; exit 0/1 |

## Output (result fields)
| field | type | meaning |
|---|---|---|
| objective | str | the built-in name, or `tool:<basename>` |
| locate | enum | argmax \| crossing |
| points | int | grid points evaluated |
| lo, hi | float | sweep bounds (echoed) |
| x_located | float | the located parameter value (parabolic-refined argmax / interpolated crossing) |
| f_at_located | float | objective value at x_located (for crossing: ≈ level) |
| target | float | the pre-registered expected location |
| located_error | float | \|x_located − target\| |
| on_target | bool | located_error ≤ tol |
| f_min | float | min objective over the sweep |
| f_max | float | max objective over the sweep |

**Guard:** `--target` is **pre-registered** (declared before the run), so `on_target` is a genuine prediction hit, not a curve-fit. Report `x_located` + `located_error` + `on_target`; a locate with no target is not a licensed "found the band" claim.

## CSV schema (--csv)
`x,f` — one row per grid point (the swept value and the objective there).

## Gates (declared negative-result conditions → exit 1)
| id | fires when | field |
|---|---|---|
| G-OFF-TARGET | located_error > tol — the located feature is NOT at the pre-registered target (the prediction fails, or the sweep/objective is mis-specified) | located_error |

Exit `0` when the located feature matches the pre-registered target within tol; exit `1` when G-OFF-TARGET fires (a genuine result — the band/threshold is elsewhere than predicted); exit `2` on bad params, a tool subprocess failure, or unparseable metric.

## Determinism
Declared output is a deterministic function of (all params) — **no RNG, no wall-clock**. The grid is fixed; the built-in objective is exact; real-tool metrics are deterministic per the tool. Floats `%.6f`; hash domain = {seed, params, result, gates, verdict} (D-013). (Real-tool runtime/order is nondeclared.)

## Golden
params: `autotune.exe --objective peak --obj-center 0.37 --obj-width 0.12 --lo 0 --hi 1 --points 41 --locate argmax --target 0.37 --tol 0.02 --seed 0 --json`
(a Gaussian basin peaked at 0.37; parabolic-refined argmax recovers ≈0.37 ⇒ on_target ⇒ exit 0. Self-contained — no external tool needed.)
recorded: `goldens/autotune/` (declared hash + stdout + NOTE).

## Change log
- v1.0.0 — initial contract. Built-in `peak`/`threshold` objectives (self-contained golden) + real-tool subprocessing (the compounding feature); argmax (parabolic) / crossing (interpolated) locators; pre-registered `--target` + G-OFF-TARGET. Python glue (D-019). Planned MINOR: multi-parameter sweeps / basin maps; additional locators.
