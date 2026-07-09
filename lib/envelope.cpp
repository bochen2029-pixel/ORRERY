// lib/envelope.cpp — liborrery: definitions for envelope.h. See the header for the invariants.
// Blake2b / fmt6 / fmti / jesc / read_golden_hash / golden_check bodies are VERBATIM the template's
// (tools/someone/someone.cu v1.1.0), parameterized only by the tool name where the template
// hardcoded "someone". D-013 hash domain unchanged.

#include "envelope.h"

namespace orrery {

// ------------------------------------------------------------------ BLAKE2b (256-bit)
void Blake2b::init(size_t out){
    static const uint64_t IV[8] = {
        0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
        0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL};
    outlen = out;
    for(int i=0;i<8;i++) h[i]=IV[i];
    h[0] ^= 0x01010000ULL ^ (uint64_t)out;   // no key, outlen bytes
    t[0]=t[1]=0; buflen=0;
}
void Blake2b::compress(const uint8_t* block, bool last){
    static const uint64_t IV[8] = {
        0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
        0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL};
    static const uint8_t S[12][16] = {
        {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},
        {14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3},
        {11,8,12,0,5,2,15,13,10,14,3,6,7,1,9,4},
        {7,9,3,1,13,12,11,14,2,6,5,10,4,0,15,8},
        {9,0,5,7,2,4,10,15,14,1,11,12,6,8,3,13},
        {2,12,6,10,0,11,8,3,4,13,7,5,15,14,1,9},
        {12,5,1,15,14,13,4,10,0,7,6,3,9,2,8,11},
        {13,11,7,14,12,1,3,9,5,0,15,4,8,6,2,10},
        {6,15,14,9,11,3,0,8,12,2,13,7,1,4,10,5},
        {10,2,8,4,7,6,1,5,15,11,9,14,3,12,13,0},
        {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},
        {14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3}};
    uint64_t m[16], v[16];
    for(int i=0;i<16;i++){
        m[i]=0; for(int j=0;j<8;j++) m[i] |= (uint64_t)block[i*8+j] << (8*j);
    }
    for(int i=0;i<8;i++){ v[i]=h[i]; v[i+8]=IV[i]; }
    v[12]^=t[0]; v[13]^=t[1];
    if(last) v[14]^=0xFFFFFFFFFFFFFFFFULL;
    #define G(a,b,c,d,x,y) do{ \
        v[a]=v[a]+v[b]+x; v[d]=rotr64(v[d]^v[a],32); \
        v[c]=v[c]+v[d];   v[b]=rotr64(v[b]^v[c],24); \
        v[a]=v[a]+v[b]+y; v[d]=rotr64(v[d]^v[a],16); \
        v[c]=v[c]+v[d];   v[b]=rotr64(v[b]^v[c],63); }while(0)
    for(int r=0;r<12;r++){
        const uint8_t* s=S[r];
        G(0,4,8,12, m[s[0]], m[s[1]]);
        G(1,5,9,13, m[s[2]], m[s[3]]);
        G(2,6,10,14, m[s[4]], m[s[5]]);
        G(3,7,11,15, m[s[6]], m[s[7]]);
        G(0,5,10,15, m[s[8]], m[s[9]]);
        G(1,6,11,12, m[s[10]], m[s[11]]);
        G(2,7,8,13, m[s[12]], m[s[13]]);
        G(3,4,9,14, m[s[14]], m[s[15]]);
    }
    #undef G
    for(int i=0;i<8;i++) h[i] ^= v[i] ^ v[i+8];
}
void Blake2b::update(const uint8_t* in, size_t inlen){
    while(inlen>0){
        if(buflen==128){
            t[0]+=128; if(t[0]<128) t[1]++;
            compress(buf,false); buflen=0;
        }
        size_t take = 128-buflen; if(take>inlen) take=inlen;
        memcpy(buf+buflen,in,take); buflen+=take; in+=take; inlen-=take;
    }
}
void Blake2b::final(uint8_t* out){
    t[0]+=buflen; if(t[0]<buflen) t[1]++;
    memset(buf+buflen,0,128-buflen);
    compress(buf,true);
    for(size_t i=0;i<outlen;i++) out[i] = (uint8_t)(h[i>>3] >> (8*(i&7)));
}
std::string blake2b_hex(const std::string& msg, size_t outlen){
    Blake2b b; b.init(outlen);
    b.update((const uint8_t*)msg.data(), msg.size());
    std::vector<uint8_t> out(outlen); b.final(out.data());
    static const char* hx="0123456789abcdef";
    std::string s; s.reserve(outlen*2);
    for(size_t i=0;i<outlen;i++){ s.push_back(hx[out[i]>>4]); s.push_back(hx[out[i]&15]); }
    return s;
}

// ------------------------------------------------------------------ SHA-256 (FIPS 180-4)
// Compact reference implementation; KAT-gated in lib/selftest.cu (empty-string + "abc" vectors).
namespace {
struct Sha256 {
    uint32_t h[8]; uint64_t len; uint8_t buf[64]; size_t buflen;
    static uint32_t rotr(uint32_t x, unsigned n){ return (x>>n)|(x<<(32-n)); }
    void init(){
        h[0]=0x6a09e667u;h[1]=0xbb67ae85u;h[2]=0x3c6ef372u;h[3]=0xa54ff53au;
        h[4]=0x510e527fu;h[5]=0x9b05688cu;h[6]=0x1f83d9abu;h[7]=0x5be0cd19u;
        len=0; buflen=0;
    }
    void compress(const uint8_t* p){
        static const uint32_t K[64]={
            0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
            0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
            0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
            0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
            0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
            0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
            0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
            0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u};
        uint32_t w[64];
        for(int i=0;i<16;i++) w[i]=((uint32_t)p[4*i]<<24)|((uint32_t)p[4*i+1]<<16)|((uint32_t)p[4*i+2]<<8)|(uint32_t)p[4*i+3];
        for(int i=16;i<64;i++){
            uint32_t s0=rotr(w[i-15],7)^rotr(w[i-15],18)^(w[i-15]>>3);
            uint32_t s1=rotr(w[i-2],17)^rotr(w[i-2],19)^(w[i-2]>>10);
            w[i]=w[i-16]+s0+w[i-7]+s1;
        }
        uint32_t a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],hh=h[7];
        for(int i=0;i<64;i++){
            uint32_t S1=rotr(e,6)^rotr(e,11)^rotr(e,25);
            uint32_t ch=(e&f)^((~e)&g);
            uint32_t t1=hh+S1+ch+K[i]+w[i];
            uint32_t S0=rotr(a,2)^rotr(a,13)^rotr(a,22);
            uint32_t mj=(a&b)^(a&c)^(b&c);
            uint32_t t2=S0+mj;
            hh=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
        }
        h[0]+=a;h[1]+=b;h[2]+=c;h[3]+=d;h[4]+=e;h[5]+=f;h[6]+=g;h[7]+=hh;
    }
    void update(const uint8_t* in, size_t n){
        len += (uint64_t)n*8;
        while(n>0){
            if(buflen==64){ compress(buf); buflen=0; }
            size_t take=64-buflen; if(take>n) take=n;
            memcpy(buf+buflen,in,take); buflen+=take; in+=take; n-=take;
        }
    }
    void final(uint8_t out[32]){
        if(buflen==64){ compress(buf); buflen=0; }
        buf[buflen++]=0x80;
        if(buflen>56){ memset(buf+buflen,0,64-buflen); compress(buf); buflen=0; }
        memset(buf+buflen,0,56-buflen);
        for(int i=0;i<8;i++) buf[56+i]=(uint8_t)(len>>(56-8*i));
        compress(buf);
        for(int i=0;i<8;i++){ out[4*i]=(uint8_t)(h[i]>>24); out[4*i+1]=(uint8_t)(h[i]>>16); out[4*i+2]=(uint8_t)(h[i]>>8); out[4*i+3]=(uint8_t)h[i]; }
    }
};
} // anonymous namespace
std::string sha256_hex(const void* data, size_t n){
    Sha256 s; s.init(); s.update((const uint8_t*)data,n);
    uint8_t out[32]; s.final(out);
    static const char* hx="0123456789abcdef";
    std::string r; r.reserve(64);
    for(int i=0;i<32;i++){ r.push_back(hx[out[i]>>4]); r.push_back(hx[out[i]&15]); }
    return r;
}
std::string sha256_hex(const std::string& s){ return sha256_hex(s.data(), s.size()); }

// ------------------------------------------------------------------ canonical serialization helpers
std::string fmt6(double x){
    if (std::fabs(x) < 0.5e-6) x = 0.0;        // normalize -0.000000 -> 0.000000
    char b[64]; snprintf(b,sizeof(b),"%.6f",x); return std::string(b);
}
std::string fmti(long long x){ char b[32]; snprintf(b,sizeof(b),"%lld",x); return std::string(b); }
std::string jesc(const std::string& s){    // minimal JSON string escape
    std::string o; o.reserve(s.size()+2);
    for(char c: s){
        switch(c){
            case '"': o+="\\\""; break; case '\\': o+="\\\\"; break;
            case '\n': o+="\\n"; break; case '\t': o+="\\t"; break; case '\r': o+="\\r"; break;
            default: o.push_back(c);
        }
    }
    return o;
}

// ------------------------------------------------------------------ envelope assembly
std::string declared_object(const std::string& declared_body){ return "{"+declared_body+"}"; }
std::string full_envelope(const char* tool, const char* version,
                          const std::string& declared_body, const std::string& notes){
    return "{\"tool\":\""+std::string(tool)+"\",\"version\":\""+std::string(version)+"\","
         + declared_body
         + ",\"notes\":\""+jesc(notes)+"\"}";
}

// ------------------------------------------------------------------ golden plumbing
bool read_golden_hash(const char* tool, std::string& out){
    char p0[256],p1[256],p2[256];
    snprintf(p0,sizeof(p0),"goldens/%s/declared.hash",tool);
    snprintf(p1,sizeof(p1),"../../goldens/%s/declared.hash",tool);
    snprintf(p2,sizeof(p2),"../../../goldens/%s/declared.hash",tool);
    const char* paths[] = { p0, p1, p2 };
    for(const char* p: paths){
        FILE* f=fopen(p,"rb");
        if(f){ char b[256]; size_t n=fread(b,1,sizeof(b)-1,f); fclose(f); b[n]=0;
               std::string s(b); // trim whitespace/newlines
               while(!s.empty() && (s.back()=='\n'||s.back()=='\r'||s.back()==' '||s.back()=='\t')) s.pop_back();
               // take first token (in case of "hash  filename")
               size_t sp=s.find_first_of(" \t\r\n"); if(sp!=std::string::npos) s=s.substr(0,sp);
               out=s; return true; }
    }
    return false;
}
int golden_check(const char* tool, const std::string& declared, const std::string& envelope){
    std::string hash = blake2b_hex(declared);
    // stdout = the full declared envelope (so `--golden >stdout.txt` captures goldens/<tool>/stdout.txt).
    printf("%s\n", envelope.c_str());
    // stderr = the reproduction verdict. Exit 0 = golden reproduced (hash matches), 1 = mismatch.
    std::string frozen;
    if(read_golden_hash(tool, frozen)){
        if(hash==frozen){ fprintf(stderr,"GOLDEN OK blake2b=%s\n", hash.c_str()); return 0; }
        fprintf(stderr,"GOLDEN MISMATCH\n  got   %s\n  want  %s\n", hash.c_str(), frozen.c_str());
        return 1;
    }
    fprintf(stderr,"GOLDEN NOT FROZEN (bootstrap) blake2b=%s\n  freeze into goldens/%s/declared.hash\n", hash.c_str(), tool);
    return 0;
}

// ------------------------------------------------------------------ CLI spine
void die2(const std::string& msg){ fprintf(stderr,"error: %s\n", msg.c_str()); std::exit(2); }
long long parse_ll(const char* s, const char* flag){
    char* end=nullptr; long long v=strtoll(s,&end,10);
    if(end==s || *end!=0) die2(std::string("bad integer for ")+flag+": "+s); return v;
}
double parse_d(const char* s, const char* flag){
    char* end=nullptr; double v=strtod(s,&end);
    if(end==s || *end!=0) die2(std::string("bad number for ")+flag+": "+s); return v;
}

// ------------------------------------------------------------------ selftest line
bool st_check(const char* name, bool ok){
    fprintf(stderr,"  [%s] %s\n", ok?"PASS":"FAIL", name); return ok;
}

// ------------------------------------------------------------------ result.lock writer (D-008)
bool write_result_lock(const char* path, const ResultLockInfo& L){
    FILE* f=fopen(path,"wb"); if(!f) return false;
    fprintf(f,"# result.lock — %s %s\n\n", L.tool.c_str(), L.result_kind.c_str());
    fprintf(f,"tool:            %s\n", L.tool.c_str());
    fprintf(f,"version:         %s\n", L.version.c_str());
    fprintf(f,"result_kind:     %s\n\n", L.result_kind.c_str());
    fprintf(f,"# --- binary / toolchain ---\n");
    fprintf(f,"binary_blake2b:  %s\n", L.binary_blake2b.c_str());
    fprintf(f,"gpu_arch:        %s\n", L.gpu_arch.c_str());
    fprintf(f,"gpu_device:      %s\n", L.gpu_device.c_str());
    fprintf(f,"cuda:            %s\n", L.cuda.c_str());
    fprintf(f,"host_compiler:   %s\n", L.host_compiler.c_str());
    fprintf(f,"build_cmd:       %s\n\n", L.build_cmd.c_str());
    fprintf(f,"# --- invocation ---\n");
    fprintf(f,"seed:            %s\n", L.seed.c_str());
    fprintf(f,"params:          %s\n", L.params.c_str());
    fprintf(f,"cli:             %s\n\n", L.cli.c_str());
    fprintf(f,"# --- declared output ---\n");
    fprintf(f,"declared_blake2b: %s\n", L.declared_blake2b.c_str());
    fprintf(f,"determinism:      %s\n", L.determinism.c_str());
    fprintf(f,"hash_domain:      %s\n", L.hash_domain.c_str());
    if(!L.result.empty())     fprintf(f,"result:           %s\n", L.result.c_str());
    if(!L.finding.empty())    fprintf(f,"finding:          %s\n", L.finding.c_str());
    if(!L.run_marker.empty()) fprintf(f,"run_marker:       %s\n", L.run_marker.c_str());
    if(!L.notes.empty())      fprintf(f,"notes:            %s\n", L.notes.c_str());
    fclose(f);
    return true;
}

} // namespace orrery
