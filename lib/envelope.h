// lib/envelope.h — liborrery: the universal-envelope core (host-only interface).
// EXTRACTED VERBATIM from tools/someone/someone.cu (the template, v1.1.0) — see D-020.
//
// INVARIANT (D-013, unchanged): the golden hash domain is blake2b-256 over the canonical
// serialization of {seed, params, result, gates, verdict}, floats at fixed %.6f, keys in the
// contract's declared order, EXCLUDING tool/version/notes. These helpers ARE that serialization;
// any semantic change here is GOLDEN-SUPERSEDING for every consumer tool (two-pass + operator
// sign-off). lib/selftest.cu pins behavior with KATs + a reference-namespace cross-check.
//
// What lives here (and only here):
//   Blake2b / blake2b_hex   — the golden hasher (KAT-gated: RFC 7693 vectors).
//   sha256_hex              — sidecar/provenance hashing (ckpt.h, I-14 frozen data). KAT-gated.
//   fmt6 / fmti / jesc      — the canonical serializers (%.6f with -0 normalization, %lld, JSON escape).
//   declared_object         — wraps a declared body "seed:..,params:..,result:..,gates:..,verdict:.."
//   full_envelope           — adds tool/version/notes around the declared body (non-hashed fields).
//   read_golden_hash        — reads goldens/<tool>/declared.hash from the standard path candidates.
//   golden_check            — the whole --golden verdict: hash, print, compare, report, exit code.
//   die2 / parse_ll / parse_d — the CLI spine (bad input -> exit 2).
//   st_check                — the selftest [PASS]/[FAIL] line.
//   write_result_lock       — the D-008 result.lock skeleton writer (runs/ manifests).
//
// Tool-specific things (params/result/gates field lists, gate logic, main()) stay in the tool:
// the contract belongs to the tool; the envelope belongs to the instrument.

#pragma once
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>

namespace orrery {

// ------------------------------------------------------------------ BLAKE2b (256-bit), host only
// Reference implementation; validated against known test vectors in the lib selftest (and every
// consumer tool's --selftest KATs).
struct Blake2b {
    uint64_t h[8]; uint64_t t[2]; uint8_t buf[128]; size_t buflen; size_t outlen;
    static uint64_t rotr64(uint64_t x, unsigned n){ return (x >> n) | (x << (64 - n)); }
    void init(size_t out);
    void compress(const uint8_t* block, bool last);
    void update(const uint8_t* in, size_t inlen);
    void final(uint8_t* out);
};
std::string blake2b_hex(const std::string& msg, size_t outlen=32);

// ------------------------------------------------------------------ SHA-256 (host) — sidecars/provenance
std::string sha256_hex(const void* data, size_t n);
std::string sha256_hex(const std::string& s);

// ------------------------------------------------------------------ canonical serialization helpers
std::string fmt6(double x);                 // %.6f with -0.000000 -> 0.000000 normalization
std::string fmti(long long x);              // %lld
std::string jesc(const std::string& s);     // minimal JSON string escape

// ------------------------------------------------------------------ envelope assembly
// declared body = "\"seed\":..,\"params\":..,\"result\":..,\"gates\":..,\"verdict\":\"..\"" (tool-built,
// fixed order per contract). declared_object wraps it (the D-013 hash input); full_envelope adds
// the non-hashed identity/notes fields.
std::string declared_object(const std::string& declared_body);
std::string full_envelope(const char* tool, const char* version,
                          const std::string& declared_body, const std::string& notes);

// ------------------------------------------------------------------ golden plumbing
// Reads goldens/<tool>/declared.hash trying the standard relative paths (tool dir or repo root).
bool read_golden_hash(const char* tool, std::string& out);
// The universal --golden tail: hash the declared object, print the full envelope on stdout,
// compare against the frozen hash, report on stderr. Returns the exit code (0 ok / 1 mismatch;
// 0 with a bootstrap note if no hash is frozen yet).
int golden_check(const char* tool, const std::string& declared, const std::string& envelope);

// ------------------------------------------------------------------ CLI spine (bad input -> exit 2)
[[noreturn]] void die2(const std::string& msg);
long long parse_ll(const char* s, const char* flag);
double parse_d(const char* s, const char* flag);

// ------------------------------------------------------------------ selftest line
bool st_check(const char* name, bool ok);

// ------------------------------------------------------------------ result.lock writer (D-008)
// Writes the runs/ manifest skeleton in the established key-value format. Free-text sections
// (finding/notes) are the caller's; this pins the reproducibility fields.
struct ResultLockInfo {
    std::string tool, version, result_kind;
    std::string binary_blake2b, gpu_arch, gpu_device, cuda, host_compiler, build_cmd;
    std::string seed, params, cli;
    std::string declared_blake2b, determinism, hash_domain, result, finding, run_marker, notes;
};
bool write_result_lock(const char* path, const ResultLockInfo& L);

} // namespace orrery

// ------------------------------------------------------------------ CUDA error spine (device TUs only)
// Verbatim the template's macro: any CUDA failure is an ERROR (exit 2), never a result.
#if defined(__CUDACC__) && !defined(CUDA_OK)
#define CUDA_OK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ \
    fprintf(stderr,"CUDA error %s at %s:%d: %s\n",#call,__FILE__,__LINE__,cudaGetErrorString(_e)); \
    std::exit(2);} } while(0)
#endif
