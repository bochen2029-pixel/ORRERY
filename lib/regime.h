// lib/regime.h — liborrery: derived-only composable regime bitmask (the ASTRA-7 pattern). D-020.
//
// A Regime is a set of named condition bits COMPUTED from run state at envelope-build time —
// never parsed from input, never settable by a caller. The single mutation path, derive(), takes
// the computed condition; there is no setter that takes a value from outside the computation.
// A tool that adopts it declares its bit names in the contract and stamps regime into `result`.
//
// ADOPTION NOTE (frozen contracts): the four migrated v1 tools do NOT stamp regimes — their
// contracts/goldens are frozen and adding a declared field is a MINOR contract bump they don't
// need. regime.h is for wave-1+ tools (hsmi-stab onward, D-026 pre-contracts). ratchet's string
// `regime` field (supercritical/subcritical/critical) is the same idea in scalar form.

#pragma once
#include <cstdint>
#include <string>

namespace orrery {

class Regime {
    uint32_t bits_ = 0;
public:
    // The only mutation path: bit <- computed condition. Call once per bit, from derived state.
    void derive(int bit, bool condition){ if(condition) bits_ |= (1u<<bit); else bits_ &= ~(1u<<bit); }
    bool test(int bit) const { return (bits_>>bit)&1u; }
    uint32_t raw() const { return bits_; }
    // Canonical JSON: {"mask":M,"set":["name",...]} — names[i] labels bit i, fixed order.
    std::string to_json(const char* const* names, int n) const {
        std::string s = "{\"mask\":" + std::to_string((unsigned long long)bits_) + ",\"set\":[";
        bool first=true;
        for(int i=0;i<n;i++) if(test(i)){ if(!first) s+=","; s+="\""; s+=names[i]; s+="\""; first=false; }
        return s+"]}";
    }
};

} // namespace orrery
