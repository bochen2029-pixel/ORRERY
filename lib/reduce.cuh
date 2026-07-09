// lib/reduce.cuh — liborrery: deterministic reductions (header-only, device+host).
// blockReduceSum / blockReduceSum3 EXTRACTED VERBATIM from tools/someone/someone.cu (D-020).
//
// INVARIANT: no float atomics may appear in any reduction whose value enters declared output
// (ARCHITECTURE §5 / BUILD.md determinism checklist). The sanctioned shapes are:
//   1. blockReduceSum/3   — warp-shuffle + one shared exchange; FIXED reduction order ⇒ bit-stable.
//   2. kahan_add          — host index-order compensated summation (the ensemble-aggregate idiom).
//   3. FixedPointAcc      — uint64 fixed-point atomic accumulator: integer atomicAdd is associative
//                           and commutative, so the result is ORDER-INVARIANT (the nebulabrot
//                           pattern) — deterministic scatter-add without sorting.
//   4. stable_gather_sum  — sort-then-gather HOST REFERENCE: stable-partition values by key, then
//                           sum each key's run in index order (the YOSO pattern, host form).
//                           A device-optimized version (atomic histogram → prefix scan → ordered
//                           runs) is deliberately NOT shipped until a tool needs it — lib carries
//                           no untested device code. See lib/MODULE.md "Known limitations".
//
// Any semantic change to 1. is GOLDEN-SUPERSEDING for consumer tools (two-pass + operator sign-off).

#pragma once
#include <cstdint>
#include <vector>
#include <algorithm>

namespace orrery {

// ------------------------------------------------------------------ deterministic block reductions
// warp-shuffle + one shared exchange: fixed reduction ORDER (hence bit-stable run-to-run) with far
// fewer __syncthreads than a full tree reduction. All blockDim threads must participate.
__device__ inline float blockReduceSum(float v, float* sh){
    int lane=threadIdx.x&31, wid=threadIdx.x>>5, nw=(blockDim.x+31)>>5;
    for(int o=16;o>0;o>>=1) v+=__shfl_down_sync(0xffffffffu,v,o);
    if(lane==0) sh[wid]=v; __syncthreads();
    float r=0.0f;
    if(wid==0){ r=(lane<nw)?sh[lane]:0.0f; for(int o=16;o>0;o>>=1) r+=__shfl_down_sync(0xffffffffu,r,o); if(lane==0) sh[0]=r; }
    __syncthreads(); return sh[0];
}
__device__ inline float3 blockReduceSum3(float3 v, float* sh){   // three sums, two barriers total
    int lane=threadIdx.x&31, wid=threadIdx.x>>5, nw=(blockDim.x+31)>>5;
    for(int o=16;o>0;o>>=1){ v.x+=__shfl_down_sync(0xffffffffu,v.x,o); v.y+=__shfl_down_sync(0xffffffffu,v.y,o); v.z+=__shfl_down_sync(0xffffffffu,v.z,o); }
    if(lane==0){ sh[wid]=v.x; sh[32+wid]=v.y; sh[64+wid]=v.z; } __syncthreads();
    if(wid==0){
        float x=(lane<nw)?sh[lane]:0.0f, y=(lane<nw)?sh[32+lane]:0.0f, z=(lane<nw)?sh[64+lane]:0.0f;
        for(int o=16;o>0;o>>=1){ x+=__shfl_down_sync(0xffffffffu,x,o); y+=__shfl_down_sync(0xffffffffu,y,o); z+=__shfl_down_sync(0xffffffffu,z,o); }
        if(lane==0){ sh[0]=x; sh[1]=y; sh[2]=z; }
    }
    __syncthreads(); return make_float3(sh[0],sh[1],sh[2]);
}

// ------------------------------------------------------------------ host Kahan (index-order)
// The someone/mcts aggregate idiom as a named helper. Iterate in a FIXED index order.
inline void kahan_add(double& sum, double& comp, double y){
    double t=sum, yy=y-comp, tt=t+yy; comp=(tt-t)-yy; sum=tt;
}

// ------------------------------------------------------------------ fixed-point order-invariant accumulator
// Scatter-add without order sensitivity: encode value*2^32 into int64, atomicAdd as unsigned
// (two's-complement wraparound is well-defined); integer addition is associative+commutative so
// ANY thread order yields the identical bit pattern. Precision: |value| < 2^31 with 2^-32 quantum;
// the QUANTIZATION (not the order) is the declared behavior — document per tool (I-13).
// scale = 2^32 (literal in both functions: a namespace-scope host constant is invisible to device code)
__host__ __device__ inline long long fixed_encode(double v){ return (long long)(v * 4294967296.0); }
__host__ __device__ inline double     fixed_decode(long long q){ return (double)q / 4294967296.0; }
__device__ inline void fixed_atomic_add(unsigned long long* acc, double v){
    atomicAdd(acc, (unsigned long long)fixed_encode(v));
}

// ------------------------------------------------------------------ sort-then-gather (host reference)
// Deterministic per-key float sums: stable_sort by key (ties keep index order), then each key's
// contiguous run is summed in that fixed order. Reference implementation + the pattern's contract;
// the device version lands with the first tool that needs it.
inline std::vector<double> stable_gather_sum(const std::vector<int>& keys,
                                             const std::vector<double>& values, int num_keys){
    std::vector<size_t> idx(keys.size());
    for(size_t i=0;i<idx.size();i++) idx[i]=i;
    std::stable_sort(idx.begin(), idx.end(), [&](size_t a, size_t b){ return keys[a]<keys[b]; });
    std::vector<double> out((size_t)num_keys, 0.0);
    for(size_t i=0;i<idx.size();i++) out[(size_t)keys[idx[i]]] += values[idx[i]];
    return out;
}

} // namespace orrery
