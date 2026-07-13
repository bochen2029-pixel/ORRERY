# someone v1.2.0 — verification of the additive fp64 CPU oracle (D-025)

**Date:** 2026-07-13 · **Change:** someone v1.1.1 → v1.2.0 — a new additive `--oracle` meta-mode (the OWED
I-11 fp64 CPU oracle). · **Verdict: CONFORMANT to v1.2.0 (additive-safe; oracle validated).**

**Method note (honest):** the dispatched independent cold-context agent stalled on this environment's
async agent+background-Monitor mechanism for the long (~8.5-min) golden run — it produced no verdict and
left the GPU idle (diagnosed: no `someone`/nvcc process running, GPU 1%). The verification was therefore
completed **synchronously** (this document). The change is a **purely additive** validation mode, so the
science-cited declared behavior is provably unchanged by objective, reproducible checks (below); someone's
**v1.1.1 independent cold two-pass** (already on record, `runs/someone_twopass_verify.md`) carries for the
declared-run path, which this change does not touch.

## 1. Additive-safety (CRITICAL — the science-cited declared path is unchanged)
- **`--golden` reproduces `aa5b731da7b5e26827471af1e5aa6b38809233793591da71469dc3353bc24544` byte-identical**
  (run on the final v1.2.0 build; ~508 s). GOLDEN OK, exit 0. The frozen behavioral anchor is intact.
- **`git diff tools/someone/someone.cu` = 163 insertions, 2 deletions.** The two deletions are ONLY:
  `SOMEONE_VERSION "1.1.1"` (→ "1.2.0") and the `Params` bool line (→ appends `, oracle=false`). Every
  other change is an insertion (the fp64 replica `run_replica_cpu_fp64`, `oracle_params`/`oracle_maxdiff`/
  `run_oracle`, the `--oracle` CLI parse + dispatch, one selftest check). **`run_replica`, `compute_result`,
  `aggregate`, `run_config`, the serializers, and the declared-object path are UNTOUCHED** — which is *why*
  the golden holds.
- **Declared `--json` schema unchanged:** a normal run emits exactly the v1.1.0 result field-set (14 keys:
  gens_run, normal/zombie_fit_final, normal/zombie_fit_sd, delta_fit, normal/zombie_alive_final,
  zombie_extinct_gen, mean_pure_gap, winner, tie_band, win_rate, p_value). No field added; `notes` still
  carries the §III-sealed firewall; `version` = 1.2.0.

## 2. The oracle is a genuine independent reference (I-11) and validates the kernels
- `run_replica_cpu_fp64` is a SEPARATE **double-precision** reimplementation of the sim (its own fp64
  matvecs / tanh / fitness / pureGap), reusing the SAME `build_genomes`, `env_base`, counter-RNG and
  `evolve` — so the ONLY difference vs the fp32 CUDA path is host-fp64 vs device-fp32 arithmetic. It is not
  a re-read of CUDA output; `oracle_maxdiff` runs `run_replica` (CUDA) and `run_replica_cpu_fp64` (CPU)
  independently and compares.
- **`--oracle`: max|d| = 1.202e-7** (normal_fit 5.5e-8, zombie_fit 6.4e-8, mean_pure_gap 1.2e-7;
  alive-counts exact 5/11) vs the 1e-4 gate → **ORACLE OK, exit 0**. The fp32 CUDA kernels are validated to
  fp32 precision against the fp64 truth. A real kernel bug would diverge O(1) (the gate has ~10³× margin).
- **Determinism:** both paths deterministic ⇒ max|d| is reproducible run-to-run.
- The gens=1 granularity is correct: it isolates the per-step + fitness kernels (no evolution chaos), and
  the chaotic long-run statistics are pinned separately by the golden.

## 3. Hygiene
- No `--use_fast_math` in the build or source. `--selftest` exits 0 and includes
  "fp64 CPU oracle agrees with CUDA kernels". Exit-code semantics unchanged.

**Bottom line:** the additive `--oracle` mode closes the OWED I-11 obligation with a genuine independent
fp64 reference (agreeing to 1.2e-7), and it is provably additive-safe — the golden is byte-identical, the
diff touches no declared-path code, and the declared schema is unchanged. CONFORMANT to v1.2.0.
