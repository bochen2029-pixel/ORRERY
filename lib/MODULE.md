# MODULE — lib/ (liborrery v1.0.0)

**What it is:** the invariant core of every ORRERY tool, extracted VERBATIM from `tools/someone/someone.cu` (the template, v1.1.0) so the doctrine (D-012 RNG, D-013 hash domain, the universal envelope, deterministic reductions) is *code that cannot drift*, not convention that can. ADR: **D-020** (`DECISIONS.md`). Class: [ADDITIVE] introduction; consumer migrations are [BEHAVIOR-NEUTRAL] gated on bit-identical golden reproduction.

**This is NOT a tool.** No contract, no golden, no CLI. It is instrument infrastructure with a KAT selftest. The harness does not discover it (`harness/verify.py` scans `tools/*/MODULE.md` only); its verification is `orrery_selftest.exe` below + every consumer tool's golden.

## Files (exactly and only — D-020)

| file | contents | consumers |
|---|---|---|
| `envelope.h/.cpp` | Blake2b-256 (golden hasher) + SHA-256 (sidecars/I-14), `fmt6`/`fmti`/`jesc` canonical serializers, `declared_object`/`full_envelope`, `read_golden_hash`/`golden_check`, `die2`/`parse_ll`/`parse_d`, `st_check`, `write_result_lock`, `CUDA_OK` | all tools |
| `rng.cuh` | D-012 kit: `splitmix64` (purpose-keying), `hash4` counter hash, `u01`, `counter_uniform`, `counter_gauss` (stateless Box–Muller), `h_u01`/`h_normal` (host mt19937_64 idiom) | CUDA tools |
| `reduce.cuh` | `blockReduceSum`/`blockReduceSum3` (fixed-order warp-shuffle), `kahan_add` (host index-order), fixed-point uint64 atomic accumulator (order-invariant scatter), `stable_gather_sum` (sort-then-gather host reference) | CUDA tools |
| `regime.h` | derived-only composable regime bitmask (ASTRA-7 pattern) — for wave-1+ tools | future tools |
| `ckpt.h` | raw dump + `.sha256` sidecar + verified resume (buddhabrot B7 rule) — for long-runners | future tools |
| `selftest.cu` | the KAT battery (42 checks) → `orrery_selftest.exe` | CI / sessions |

## Invariants (violate = golden-superseding for every consumer)

1. **Verbatim rule:** `rng.cuh`/`reduce.cuh`/serializer bodies are byte-for-byte the template's algorithms. The selftest's **ref-namespace cross-check** (a frozen copy of the originals compared bit-for-bit over a 1000-point sweep) enforces this mechanically. Any semantic change requires two-pass + operator sign-off and supersedes every consumer golden.
2. **D-013 hash domain unchanged:** blake2b-256 over canonical `{seed,params,result,gates,verdict}`, floats `%.6f` (with `-0` normalization), tool/version/notes excluded.
3. **Host≠device libm, pinned per side:** `counter_gauss(20260705,7,11,13)` measures a REAL 1-ULP divergence (host MSVC `...9d3b` vs device CUDA `...9d3a`). The selftest pins host and device values SEPARATELY — never assert host==device for transcendental paths. The device pins are the drift detector: a CUDA toolkit update that shifts device `log`/`cos` fires this selftest *before* it silently breaks a tool golden (someone's kernels draw gauss on device).
4. **No float atomics** in any declared reduction (the sanctioned shapes are in `reduce.cuh`). The fixed-point accumulator's *quantization* (2⁻³² at |v|<2³¹) is declared behavior — document per tool (I-13).
5. Sims prove **structure**, never **acquaintance** (qualia). §III-sealed. (Carried by every consumer tool's notes; restated here because lib is where envelopes come from.)

## Build

```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 selftest.cu envelope.cpp -o orrery_selftest.exe'
```

Run **from the repo root** (the `read_golden_hash` integration check resolves `goldens/` from there):

```
.\lib\orrery_selftest.exe     # 42 KAT checks; exit 0 PASS / 1 FAIL
```

Consumer tools build with one extra arg: `nvcc -O3 -arch=sm_89 <tool>.cu ../../lib/envelope.cpp -o <tool>.exe` (+ `-lcusolver` where needed). The CMake preset (D-021, `CMakePresets.json`) additionally builds `orrery.lib` + `orrery_selftest` for multi-file futures; the bare-nvcc path above stays the golden path.

## Internal design notes

- Namespace `orrery`; tools open it with `using namespace orrery;` so migration diffs are deletions, not rewrites. `CUDA_OK` is macro (guarded `__CUDACC__`, only defined for device TUs).
- KAT ground truth harvested 2026-07-09 on the pinned toolchain (CUDA 13.1 V13.1.80, MSVC 2022, sm_89, RTX 4070 Ti SUPER); integer/u01 pins independently cross-computed in Python; `splitmix64(0)` equals Vigna's published vector `e220a8397b1dcdaf`.
- `golden_check` reproduces the template's `--golden` tail byte-for-byte (stdout envelope, stderr `GOLDEN OK/MISMATCH/NOT FROZEN` formats), parameterized by tool name.

## Known limitations (honest scope, v1.0.0)

- **sort-then-gather** ships as a host reference implementation only (correct + deterministic by stable-sort construction). The device-optimized version (atomic histogram → prefix scan → ordered runs, the YOSO pattern) lands with the first tool that needs it — lib carries no untested device code.
- **`regime.h`/`ckpt.h`/`write_result_lock` have no v1 consumers** (frozen contracts don't stamp regimes; no v1 tool runs long enough to checkpoint; locks are still hand-authored in `runs/`). They ship KAT-tested for wave-1+ (D-026 pre-contracts).
- An fp64 CPU **oracle** module (`lib/oracle/`, someone's I-11 obligation) is D-025 territory — PROPOSED, not yet built.
