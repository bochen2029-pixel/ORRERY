// lib/rng.cuh — liborrery: the D-012 deterministic RNG kit (header-only, host+device).
// EXTRACTED VERBATIM from tools/someone/someone.cu (the template, v1.1.0) — see D-020.
//
// INVARIANT: these bodies are byte-for-byte the template's algorithms. Any semantic change here is
// a GOLDEN-SUPERSEDING change for every consumer tool and requires two-pass + operator sign-off.
// lib/selftest.cu pins them with KATs AND a reference-namespace cross-check (lib == template).
//
// The kit (D-012):
//   splitmix64        — the mixer; also the purpose-keying primitive (seed ^ PURPOSE_SALT).
//   hash4             — 4-coordinate counter hash: every random value is a pure function of its
//                       integer coordinates. No state, no race, no wall-clock entropy.
//   u01               — uniform [0,1) from the top 53 bits.
//   counter_uniform   — u01 ∘ hash4 keyed (seed, a, b, c).
//   counter_gauss     — stateless counter-based Gaussian (two salted streams → Box–Muller),
//                       keyed (seed, a, b, c); e.g. (seed+replica, entity, dim, step).
//   h_u01 / h_normal  — HOST-side helpers over std::mt19937_64 (init/evolution draws, fixed order).
//
// Usage: #include this from a .cu tool (needs nvcc for __host__ __device__). Host-only TUs must
// not include it; envelope.h carries the host-only pieces.

#pragma once
#include <cstdint>
#include <cmath>
#include <random>

namespace orrery {

// ------------------------------------------------------------------ counter-based RNG (host+device)
// Stateless: every random value is a pure function of its integer coordinates. No shared state,
// hence no race and no wall-clock entropy (D-012). Deterministic on host and device.
__host__ __device__ inline uint64_t splitmix64(uint64_t x){
    x += 0x9E3779B97F4A7C15ULL;
    x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ULL;
    x = (x ^ (x >> 27)) * 0x94D049BB133111EBULL;
    return x ^ (x >> 31);
}
__host__ __device__ inline uint64_t hash4(uint64_t a, uint64_t b, uint64_t c, uint64_t d){
    uint64_t h = splitmix64(a);
    h = splitmix64(h ^ (b + 0x9E3779B97F4A7C15ULL));
    h = splitmix64(h ^ (c + 0x7F4A7C15A5A5A5A5ULL));
    h = splitmix64(h ^ (d + 0xD1B54A32D192ED03ULL));
    return h;
}
__host__ __device__ inline double u01(uint64_t h){          // uniform [0,1) from top 53 bits
    return (double)(h >> 11) * (1.0 / 9007199254740992.0);
}
__host__ __device__ inline double counter_uniform(uint64_t seed, uint64_t a, uint64_t b, uint64_t c){
    return u01(hash4(seed, a, b, c));
}
// Box-Muller gaussian from two independent hashed streams (salted seeds).
__host__ __device__ inline double counter_gauss(uint64_t seed, uint64_t a, uint64_t b, uint64_t c){
    double u1 = u01(hash4(seed ^ 0xA5A5A5A5A5A5A5A5ULL, a, b, c));
    double u2 = u01(hash4(seed ^ 0x5A5A5A5A5A5A5A5AULL, a, b, c));
    if (u1 < 1e-12) u1 = 1e-12;
    const double TWO_PI = 6.283185307179586476925286766559;
    return sqrt(-2.0 * log(u1)) * cos(TWO_PI * u2);
}

// ------------------------------------------------------------------ host mt19937_64 helpers
// Fixed-draw-order idiom: seed with hash4(rseed, PURPOSE_SALT, ...) and draw in one documented
// order; replica r uses rseed = seed + r. (someone's build_genomes/evolve pattern.)
inline double h_u01(std::mt19937_64& g){ return (double)(g()>>11)*(1.0/9007199254740992.0); }
inline double h_normal(std::mt19937_64& g){ double u1=h_u01(g),u2=h_u01(g); if(u1<1e-12)u1=1e-12;
    return sqrt(-2.0*log(u1))*cos(6.283185307179586*u2); }

} // namespace orrery
