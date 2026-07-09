# ORRERY — repo-level CMake (D-021). The bare-nvcc single-file path (BUILD.md) remains fully
# supported and IS the golden path for the existing tools; this build exists for lib/ (orrery.lib),
# multi-file futures (orreryd, mcp), and the fat-binary deployment recipe.
#
# D-021 decisions encoded here:
#   - FAT BINARY: SASS for sm_89 (the pinned golden arch) + sm_90; embedded PTX (compute_120) so a
#     future GPU JITs instead of failing to load. Goldens stay HARDWARE-PINNED to sm_89 — running
#     on another arch is expected to work but NOT expected to reproduce goldens (re-baseline
#     protocol: operator-signed NOTE.md entry with old/new hash + arch + reason).
#   - STATIC RUNTIMES: static cudart + static MSVC runtime (single-exe deployment, the
#     ASTRA_VISUALIZER_02 recipe).
#   - FAST-MATH IS BANNED BY DEFAULT AND STAYS OFF (I-13). No --use_fast_math in this project.
#     A kernel that wants it must opt in per-kernel with its own golden and a paired-oracle
#     error bound — no global flag will ever be added here.
#   - CUDA C++17; separable compilation only where a target actually needs it.

cmake_minimum_required(VERSION 3.25)
project(orrery LANGUAGES CXX CUDA)

if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
  set(CMAKE_CUDA_ARCHITECTURES "89-real;90-real;120")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_RUNTIME_LIBRARY Static)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Host flags reach MSVC through -Xcompiler= automatically via CMake's CUDA support.

# --- liborrery: the invariant core (D-020) ---
add_library(orrery STATIC lib/envelope.cpp)
target_include_directories(orrery PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/lib)

# --- the lib KAT selftest (run from the repo root: .\build\<preset>\orrery_selftest.exe) ---
add_executable(orrery_selftest lib/selftest.cu)
target_link_libraries(orrery_selftest PRIVATE orrery)
