// lib/ckpt.h — liborrery: raw checkpoint dump + sha256 sidecar + resume (buddhabrot B7 rule). D-020.
//
// THE B7 RULE: no derived artifact without the raw state dump first. A long-running tool
// checkpoints its RAW state (device buffers, counters) at a declared cadence; every checkpoint
// gets a .sha256 sidecar; a --resume-from path re-reads and VERIFIES before continuing.
// Checkpoint overhead must stay ≤5% of run time (D-024 NFR, when adopted).
//
// ADOPTION NOTE: no current v1 tool runs long enough to need checkpoints (someone's ~8-min golden
// is the ceiling). ckpt.h ships for wave-1/2 long-runners (hsmi-stab sweeps, ratchet-v2 FSS,
// everpresent history ensembles). The sidecar format is one line: "<sha256-hex>  <filename>\n"
// (sha256sum-compatible, so external tooling can verify).

#pragma once
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
#include "envelope.h"   // sha256_hex

namespace orrery {

inline std::string ckpt_sidecar_path(const std::string& path){ return path + ".sha256"; }

inline std::string ckpt_basename(const std::string& path){
    size_t s = path.find_last_of("/\\");
    return (s==std::string::npos) ? path : path.substr(s+1);
}

// Write raw bytes + the .sha256 sidecar. Returns false on any I/O failure (caller decides policy;
// a failed checkpoint must never corrupt the run — write is to the final path only after full
// buffer assembly here, no partial in-place mutation of a previous checkpoint).
inline bool ckpt_write(const std::string& path, const void* data, size_t n){
    FILE* f = fopen(path.c_str(), "wb");
    if(!f) return false;
    size_t w = fwrite(data, 1, n, f);
    fclose(f);
    if(w != n) return false;
    std::string h = sha256_hex(data, n);
    FILE* s = fopen(ckpt_sidecar_path(path).c_str(), "wb");
    if(!s) return false;
    fprintf(s, "%s  %s\n", h.c_str(), ckpt_basename(path).c_str());
    fclose(s);
    return true;
}

// Read a checkpoint and verify it against its sidecar. Returns false if the file or sidecar is
// missing/unreadable or the hash does not match (a corrupt checkpoint is an ERROR-class event,
// exit 2 at the tool level — never silently resumed).
inline bool ckpt_read_verified(const std::string& path, std::vector<uint8_t>& out){
    FILE* f = fopen(path.c_str(), "rb");
    if(!f) return false;
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    if(sz < 0){ fclose(f); return false; }
    out.resize((size_t)sz);
    size_t r = fread(out.data(), 1, (size_t)sz, f);
    fclose(f);
    if(r != (size_t)sz) return false;
    FILE* s = fopen(ckpt_sidecar_path(path).c_str(), "rb");
    if(!s) return false;
    char line[160]; size_t n = fread(line, 1, sizeof(line)-1, s); fclose(s); line[n]=0;
    std::string want(line);
    size_t sp = want.find_first_of(" \t\r\n");
    if(sp != std::string::npos) want = want.substr(0, sp);
    return sha256_hex(out.data(), out.size()) == want;
}

#ifdef __CUDACC__
// Device-state convenience: D2H copy then ckpt_write. sync-copies (checkpoint cadence is coarse).
inline bool ckpt_write_device(const std::string& path, const void* dptr, size_t n){
    std::vector<uint8_t> h(n);
    if(cudaMemcpy(h.data(), dptr, n, cudaMemcpyDeviceToHost) != cudaSuccess) return false;
    return ckpt_write(path, h.data(), n);
}
#endif

} // namespace orrery
