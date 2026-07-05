# BUILD.md — how to compile and verify any ORRERY tool (cold-start runbook)

A fresh agent must be able to build any tool from this file alone, in one pass.

## Toolchain (verified 2026-07-05 on this machine)
- GPU: NVIDIA RTX 4070 Ti SUPER, 16 GB → **`-arch=sm_89`** (Ada Lovelace).
- CUDA 13.1 (`nvcc`). Host compiler: **MSVC 2022 Community** — `nvcc` needs `cl.exe` in PATH.
- vcvars: `C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat`

## Single-file CUDA tool (the default for most tools)
From the tool's directory, in ONE `cmd` call (vcvars sets the MSVC env, then nvcc):
```
cmd /c '"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 someone.cu -o someone.exe'
```
Then run (note the `.\` on PowerShell/cmd):
```
.\someone.exe --selftest
.\someone.exe --golden
.\someone.exe --pop 200 --gens 200 --steps 800 --N 256 --k 64 --zombie-frac 0.5 --complexity L3 --ensemble 4 --seed 20260705 --json
```

## Multi-file tool (use CMake)
Copy the `CMakeLists.txt` pattern from `C:\buddhabrot-main` or `C:\ASTRA-7`. Configure + build:
```
cmd /c '"...\vcvars64.bat" >nul 2>&1 && cmake -S . -B build -DCMAKE_CUDA_ARCHITECTURES=89 && cmake --build build --config Release'
```

## Python tool (only where justified, per ARCHITECTURE §7)
```
python posit.py --selftest        # exit 0/1
python posit.py --golden          # hash vs goldens/posit/
python posit.py <params> --json   # JSON envelope on stdout; force UTF-8 stdout on Windows
```
(Windows console is cp1252 — Python tools must `sys.stdout.reconfigure(encoding="utf-8")` if they print non-ASCII.)

## cuSOLVER/cuBLAS tools (e.g. `algebra`)
Add `-lcusolver -lcublas` to the nvcc line (libs ship with CUDA 13.1). Determinism: pin the solver's algorithm where the API allows; document any non-reproducible eigen-ordering in MODULE.md.

## The verification loop (what CI / the harness does)
1. Build every tool (per its MODULE.md build command).
2. `--selftest` each → must exit 0.
3. `--golden` each → must exit 0 (hash matches `goldens/<tool>/`).
4. Green = the instrument is coherent. Red = a tool broke its golden or won't compile → that tool's claims are unsupported until fixed.

`harness/` holds the runner that does this (see `harness/README.md`). Keep every `--selftest` under 30 s and the whole golden suite under 5 min so the loop stays fast.

## Determinism checklist (every CUDA tool)
- Seed all curand per-thread from (seed[, replica], globalThreadId).
- Fixed launch config (blocks × threads) not derived from wall-clock or device query in a way that varies output.
- No atomics in any reduction whose sum enters the declared output — use a fixed-order tree reduction, or sort before reducing.
- Host-side RNG (evolution, env) seeded and fixed-order.
- Run `--golden` twice; declared JSON must be byte-identical.
