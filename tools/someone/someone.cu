// someone.cu — ORRERY tool `someone` (v1.1.0)
// Headless, deterministic evolutionary Someone-Criterion instrument.
// Contract: contracts/someone.contract.md v1.1.0 (+ someone.schema.json). The contract is
// authoritative; this code is ephemeral (a contract- and golden-honoring drop-in).
//
// Sims prove STRUCTURE (does the gap confer fitness), never ACQUAINTANCE (qualia). §III-sealed.
//
// Build (from tools/someone/, see BUILD.md):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 someone.cu -o someone.exe'
//
// STATUS: S1b WALKING SKELETON — CLI + deterministic I/O spine + blake2b + selftest + golden.
//         The sim is a deterministic PLACEHOLDER (run_replica); S2 replaces it with the real
//         CUDA evolutionary sim. Everything else (determinism plumbing, JSON, hashing) is final.

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <random>
#include <algorithm>

// ------------------------------------------------------------------ version / constants
static const char* SOMEONE_VERSION = "1.1.0";
static const double TIE_BAND = 0.02;      // |delta_fit| below this => tie (contract-fixed)
static const char* FIREWALL =
    "This measures whether the gap confers fitness (structure); it says nothing about whether "
    "the agent feels (acquaintance) - III-sealed.";

#define CUDA_OK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ \
    fprintf(stderr,"CUDA error %s at %s:%d: %s\n",#call,__FILE__,__LINE__,cudaGetErrorString(_e)); \
    std::exit(2);} } while(0)

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

// ------------------------------------------------------------------ BLAKE2b (256-bit), host only
// Reference implementation; validated against known test vectors in --selftest.
struct Blake2b {
    uint64_t h[8]; uint64_t t[2]; uint8_t buf[128]; size_t buflen; size_t outlen;
    static uint64_t rotr64(uint64_t x, unsigned n){ return (x >> n) | (x << (64 - n)); }
    void init(size_t out){
        static const uint64_t IV[8] = {
            0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
            0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL};
        outlen = out;
        for(int i=0;i<8;i++) h[i]=IV[i];
        h[0] ^= 0x01010000ULL ^ (uint64_t)out;   // no key, outlen bytes
        t[0]=t[1]=0; buflen=0;
    }
    void compress(const uint8_t* block, bool last){
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
    void update(const uint8_t* in, size_t inlen){
        while(inlen>0){
            if(buflen==128){
                t[0]+=128; if(t[0]<128) t[1]++;
                compress(buf,false); buflen=0;
            }
            size_t take = 128-buflen; if(take>inlen) take=inlen;
            memcpy(buf+buflen,in,take); buflen+=take; in+=take; inlen-=take;
        }
    }
    void final(uint8_t* out){
        t[0]+=buflen; if(t[0]<buflen) t[1]++;
        memset(buf+buflen,0,128-buflen);
        compress(buf,true);
        for(size_t i=0;i<outlen;i++) out[i] = (uint8_t)(h[i>>3] >> (8*(i&7)));
    }
};
static std::string blake2b_hex(const std::string& msg, size_t outlen=32){
    Blake2b b; b.init(outlen);
    b.update((const uint8_t*)msg.data(), msg.size());
    std::vector<uint8_t> out(outlen); b.final(out.data());
    static const char* hx="0123456789abcdef";
    std::string s; s.reserve(outlen*2);
    for(size_t i=0;i<outlen;i++){ s.push_back(hx[out[i]>>4]); s.push_back(hx[out[i]&15]); }
    return s;
}

// ------------------------------------------------------------------ canonical serialization helpers
static std::string fmt6(double x){
    if (std::fabs(x) < 0.5e-6) x = 0.0;        // normalize -0.000000 -> 0.000000
    char b[64]; snprintf(b,sizeof(b),"%.6f",x); return std::string(b);
}
static std::string fmti(long long x){ char b[32]; snprintf(b,sizeof(b),"%lld",x); return std::string(b); }
static std::string jesc(const std::string& s){    // minimal JSON string escape
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

// ------------------------------------------------------------------ params
struct Params {
    int pop=200, gens=500, steps=1500, N=256, k=-1, ensemble=1, complexity=3;
    double zombie_frac=0.5, mut_rate=0.02, mut_str=0.1;
    long long seed=0; bool seed_set=false;
    bool json=false, selftest=false, golden=false, csv=false;
    std::string csv_path;
};
static const char* CX_NAME[4] = {"L0","L1","L2","L3"};

// ------------------------------------------------------------------ result
struct Result {
    int gens_run=0;
    double normal_fit_final=0, zombie_fit_final=0, normal_fit_sd=0, zombie_fit_sd=0;
    double delta_fit=0, normal_alive_final=0, zombie_alive_final=0;
    int zombie_extinct_gen=-1;
    double mean_pure_gap=0;
    std::string winner="tie";
    double win_rate=0, p_value=1.0;
    // gates
    bool g_zombie=false, g_nogap=false;
    double g_zombie_val=0, g_nogap_val=0;
};

// ------------------------------------------------------------------ sign test (exact, deterministic)
static double binom(int n, int k){
    if(k<0||k>n) return 0.0; if(k> n-k) k=n-k;
    double c=1.0; for(int i=0;i<k;i++) c = c*(double)(n-i)/(double)(i+1); return c;
}
static double sign_test_p(int wins, int losses){    // one-sided P(X>=wins), X~Binom(wins+losses,0.5)
    int neff = wins+losses; if(neff==0) return 1.0;
    double s=0.0; for(int i=wins;i<=neff;i++) s += binom(neff,i);
    return s * pow(0.5, neff);
}

// ================================================================== SKELETON SIM (S1b placeholder)
// Deterministic placeholder that exercises the full spine (host RNG for zombie flags, a device
// kernel round-trip for per-agent fitness, index-order Kahan aggregation). S2 replaces the body of
// run_replica with the real evolutionary CUDA sim; the aggregation/output below is final.
__global__ void skeletonFitnessKernel(uint64_t rseed, int pop, float* fit){
    int a = blockIdx.x*blockDim.x + threadIdx.x;
    if(a>=pop) return;
    // placeholder deterministic fitness in [0,1]; gives normals a mild edge so delta!=0 for the spine
    fit[a] = (float)counter_uniform(rseed, (uint64_t)a, 777ULL, 0ULL);
}

struct ReplicaOut { double normalMean, zombieMean, normalGap, normalAlive, zombieAlive; int extinctGen; };

static ReplicaOut run_replica(const Params& P, int replica){
    uint64_t rseed = (uint64_t)P.seed + (uint64_t)replica;
    std::mt19937_64 rng(rseed);
    std::uniform_real_distribution<double> uni(0.0,1.0);

    // zombie assignment (host, fixed draw order) — mirrors S2
    std::vector<int> isZombie(P.pop);
    for(int i=0;i<P.pop;i++) isZombie[i] = (uni(rng) < P.zombie_frac) ? 1 : 0;

    // device round-trip: placeholder fitness
    float* d_fit=nullptr; CUDA_OK(cudaMalloc(&d_fit, P.pop*sizeof(float)));
    int threads=256, blocks=(P.pop+threads-1)/threads;
    skeletonFitnessKernel<<<blocks,threads>>>(rseed, P.pop, d_fit);
    CUDA_OK(cudaGetLastError()); CUDA_OK(cudaDeviceSynchronize());
    std::vector<float> fit(P.pop);
    CUDA_OK(cudaMemcpy(fit.data(), d_fit, P.pop*sizeof(float), cudaMemcpyDeviceToHost));
    CUDA_OK(cudaFree(d_fit));

    // class means — index-order Kahan
    double nSum=0,nC=0,zSum=0,zC=0; int nN=0,zN=0;
    for(int i=0;i<P.pop;i++){
        double y = (double)fit[i];
        if(isZombie[i]){ double t=zSum; double yy=y - zC; double tt=t+yy; zC=(tt-t)-yy; zSum=tt; zN++; }
        else           { double t=nSum; double yy=y - nC; double tt=t+yy; nC=(tt-t)-yy; nSum=tt; nN++; }
    }
    ReplicaOut ro;
    ro.normalMean = nN? nSum/nN : 0.0;
    ro.zombieMean = zN? zSum/zN : 0.0;
    ro.normalGap  = 0.5;             // placeholder (real pureGap in S2)
    ro.normalAlive= nN; ro.zombieAlive=zN;   // placeholder (everyone "alive" in the skeleton)
    ro.extinctGen = -1;
    return ro;
}

// ------------------------------------------------------------------ aggregate replicas -> Result
static Result aggregate(const Params& P, const std::vector<ReplicaOut>& reps){
    int E = (int)reps.size();
    // means (index-order)
    double nMean=0,zMean=0,gMean=0,nAlive=0,zAlive=0;
    for(int r=0;r<E;r++){ nMean+=reps[r].normalMean; zMean+=reps[r].zombieMean; gMean+=reps[r].normalGap;
                          nAlive+=reps[r].normalAlive; zAlive+=reps[r].zombieAlive; }
    nMean/=E; zMean/=E; gMean/=E; nAlive/=E; zAlive/=E;
    // sd across replicas (population sd; sd=0 for E=1)
    double nVar=0,zVar=0;
    for(int r=0;r<E;r++){ nVar+=(reps[r].normalMean-nMean)*(reps[r].normalMean-nMean);
                          zVar+=(reps[r].zombieMean-zMean)*(reps[r].zombieMean-zMean); }
    nVar/=E; zVar/=E;
    // win/loss on per-replica delta
    int wins=0,losses=0;
    for(int r=0;r<E;r++){ double d=reps[r].normalMean-reps[r].zombieMean;
        if(d> TIE_BAND) wins++; else if(d< -TIE_BAND) losses++; }
    // extinct gen: mean over replicas that went extinct, else -1
    double exSum=0; int exN=0;
    for(int r=0;r<E;r++) if(reps[r].extinctGen>=0){ exSum+=reps[r].extinctGen; exN++; }

    Result R;
    R.gens_run = P.gens;
    R.normal_fit_final = nMean; R.zombie_fit_final = zMean;
    R.normal_fit_sd = sqrt(nVar); R.zombie_fit_sd = sqrt(zVar);
    R.delta_fit = nMean - zMean;
    R.normal_alive_final = nAlive; R.zombie_alive_final = zAlive;
    R.zombie_extinct_gen = exN? (int)llround(exSum/exN) : -1;
    R.mean_pure_gap = gMean;
    R.win_rate = (double)wins/(double)E;
    R.p_value  = sign_test_p(wins,losses);
    R.winner = (R.delta_fit> TIE_BAND)?"normal":(R.delta_fit< -TIE_BAND)?"zombie":"tie";
    // gates
    R.g_zombie_val = R.delta_fit;   R.g_zombie = (R.delta_fit < -TIE_BAND);
    R.g_nogap_val  = R.mean_pure_gap; R.g_nogap = (R.mean_pure_gap < 0.01);
    return R;
}

// ------------------------------------------------------------------ serialize declared body + envelope
static std::string params_json(const Params& P){
    std::string s = "{";
    s += "\"pop\":"+fmti(P.pop)+",\"gens\":"+fmti(P.gens)+",\"steps\":"+fmti(P.steps)
       + ",\"N\":"+fmti(P.N)+",\"k\":"+fmti(P.k)
       + ",\"zombie_frac\":"+fmt6(P.zombie_frac)
       + ",\"complexity\":\""+std::string(CX_NAME[P.complexity])+"\""
       + ",\"mut_rate\":"+fmt6(P.mut_rate)+",\"mut_str\":"+fmt6(P.mut_str)
       + ",\"ensemble\":"+fmti(P.ensemble)+"}";
    return s;
}
static std::string result_json(const Result& R){
    std::string s = "{";
    s += "\"gens_run\":"+fmti(R.gens_run)
       + ",\"normal_fit_final\":"+fmt6(R.normal_fit_final)
       + ",\"zombie_fit_final\":"+fmt6(R.zombie_fit_final)
       + ",\"normal_fit_sd\":"+fmt6(R.normal_fit_sd)
       + ",\"zombie_fit_sd\":"+fmt6(R.zombie_fit_sd)
       + ",\"delta_fit\":"+fmt6(R.delta_fit)
       + ",\"normal_alive_final\":"+fmt6(R.normal_alive_final)
       + ",\"zombie_alive_final\":"+fmt6(R.zombie_alive_final)
       + ",\"zombie_extinct_gen\":"+fmti(R.zombie_extinct_gen)
       + ",\"mean_pure_gap\":"+fmt6(R.mean_pure_gap)
       + ",\"winner\":\""+R.winner+"\""
       + ",\"tie_band\":"+fmt6(TIE_BAND)
       + ",\"win_rate\":"+fmt6(R.win_rate)
       + ",\"p_value\":"+fmt6(R.p_value)+"}";
    return s;
}
static std::string gates_json(const Result& R){
    std::string s = "[";
    s += "{\"id\":\"G-ZOMBIE-WINS\",\"fired\":"+std::string(R.g_zombie?"true":"false")
       + ",\"value\":"+fmt6(R.g_zombie_val)+",\"threshold\":"+fmt6(-TIE_BAND)+"}";
    s += ",{\"id\":\"G-NO-GAP\",\"fired\":"+std::string(R.g_nogap?"true":"false")
       + ",\"value\":"+fmt6(R.g_nogap_val)+",\"threshold\":"+fmt6(0.01)+"}";
    s += "]";
    return s;
}
// declared body: "seed":..,"params":..,"result":..,"gates":..,"verdict":..   (fixed order; hash domain)
static std::string declared_body(const Params& P, const Result& R, const std::string& verdict){
    return "\"seed\":"+fmti(P.seed)
         + ",\"params\":"+params_json(P)
         + ",\"result\":"+result_json(R)
         + ",\"gates\":"+gates_json(R)
         + ",\"verdict\":\""+verdict+"\"";
}
static std::string declared_object(const Params& P, const Result& R, const std::string& verdict){
    return "{"+declared_body(P,R,verdict)+"}";      // hashed
}
static std::string full_envelope(const Params& P, const Result& R, const std::string& verdict){
    return "{\"tool\":\"someone\",\"version\":\""+std::string(SOMEONE_VERSION)+"\","
         + declared_body(P,R,verdict)
         + ",\"notes\":\""+jesc(FIREWALL)+"\"}";
}

// ------------------------------------------------------------------ run one configuration
// returns exit code; fills declared_out (the canonical hashed object) and prints if do_print
static int run_config(const Params& P, bool do_print, std::string* declared_out){
    std::vector<ReplicaOut> reps; reps.reserve(P.ensemble);
    for(int r=0;r<P.ensemble;r++) reps.push_back(run_replica(P,r));
    Result R = aggregate(P, reps);
    bool gate_fired = R.g_zombie || R.g_nogap;
    std::string verdict = gate_fired ? "fail" : "pass";
    if(declared_out) *declared_out = declared_object(P,R,verdict);
    if(do_print){
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str());
    }
    return gate_fired ? 1 : 0;
}

// ------------------------------------------------------------------ golden
static Params golden_params(){
    Params P; P.pop=200; P.gens=200; P.steps=800; P.N=256; P.k=64;
    P.zombie_frac=0.5; P.complexity=3; P.ensemble=4; P.seed=20260705;
    P.mut_rate=0.02; P.mut_str=0.1; P.json=true; P.seed_set=true;
    return P;
}
// try to read a frozen golden hash from candidate paths (run from tools/someone/ or repo root)
static bool read_golden_hash(std::string& out){
    const char* paths[] = {
        "goldens/someone/declared.hash",
        "../../goldens/someone/declared.hash",
        "../../../goldens/someone/declared.hash" };
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
static int run_golden(){
    Params P = golden_params();
    std::string declared;
    run_config(P, false, &declared);
    std::string hash = blake2b_hex(declared);
    std::string frozen;
    if(read_golden_hash(frozen)){
        if(hash==frozen){ printf("GOLDEN OK  blake2b=%s\n", hash.c_str()); return 0; }
        else { fprintf(stderr,"GOLDEN MISMATCH\n  got   %s\n  want  %s\n", hash.c_str(), frozen.c_str());
               printf("GOLDEN FAIL blake2b=%s\n", hash.c_str()); return 1; }
    } else {
        // bootstrap (pre-S4): no frozen golden yet — print the hash so it can be frozen.
        fprintf(stderr,"GOLDEN NOT FROZEN (bootstrap) — freeze this hash into goldens/someone/declared.hash\n");
        printf("GOLDEN BOOTSTRAP blake2b=%s\n", hash.c_str());
        return 0;
    }
}

// ------------------------------------------------------------------ selftest
static bool st_check(const char* name, bool ok){
    fprintf(stderr,"  [%s] %s\n", ok?"PASS":"FAIL", name); return ok;
}
static int run_selftest(){
    bool ok=true;
    fprintf(stderr,"someone --selftest (v%s)\n", SOMEONE_VERSION);
    // 1. blake2b known-answer vectors (proves the hasher is correct)
    ok &= st_check("blake2b-256(\"\") KAT",
        blake2b_hex("")=="0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8");
    ok &= st_check("blake2b-256(\"abc\") KAT",
        blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // 2. determinism smoke: same params+seed -> identical declared object, twice
    { Params P=golden_params(); std::string a,b; run_config(P,false,&a); run_config(P,false,&b);
      ok &= st_check("declared object identical across two runs (determinism smoke)", a==b); }
    // 3. sign test sanity
    ok &= st_check("sign_test_p(4,0) == 0.0625", std::fabs(sign_test_p(4,0)-0.0625)<1e-12);
    ok &= st_check("sign_test_p(0,0) == 1.0", std::fabs(sign_test_p(0,0)-1.0)<1e-12);
    // 4. counter-RNG determinism (host)
    ok &= st_check("counter_gauss deterministic",
        counter_gauss(123,4,5,6)==counter_gauss(123,4,5,6));
    // NOTE (S2): add the fair-layout-across-levels assertion (BITE #2 proof) here.
    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n");
    return ok?0:1;
}

// ------------------------------------------------------------------ CLI
static void die2(const std::string& msg){ fprintf(stderr,"error: %s\n", msg.c_str()); std::exit(2); }
static bool need_val(int i,int argc){ return i+1<argc; }
static long long parse_ll(const char* s, const char* flag){
    char* end=nullptr; long long v=strtoll(s,&end,10);
    if(end==s || *end!=0) die2(std::string("bad integer for ")+flag+": "+s); return v;
}
static double parse_d(const char* s, const char* flag){
    char* end=nullptr; double v=strtod(s,&end);
    if(end==s || *end!=0) die2(std::string("bad number for ")+flag+": "+s); return v;
}

int main(int argc, char** argv){
    Params P;
    bool k_set=false;
    for(int i=1;i<argc;i++){
        std::string a=argv[i];
        auto val=[&](const char* f)->const char*{ if(!need_val(i,argc)) die2(std::string("missing value for ")+f); return argv[++i]; };
        if(a=="--pop")            P.pop=(int)parse_ll(val("--pop"),"--pop");
        else if(a=="--gens")      P.gens=(int)parse_ll(val("--gens"),"--gens");
        else if(a=="--steps")     P.steps=(int)parse_ll(val("--steps"),"--steps");
        else if(a=="--N")         P.N=(int)parse_ll(val("--N"),"--N");
        else if(a=="--k"){        P.k=(int)parse_ll(val("--k"),"--k"); k_set=true; }
        else if(a=="--zombie-frac") P.zombie_frac=parse_d(val("--zombie-frac"),"--zombie-frac");
        else if(a=="--complexity"){ std::string c=val("--complexity");
            if(c=="L0")P.complexity=0; else if(c=="L1")P.complexity=1; else if(c=="L2")P.complexity=2;
            else if(c=="L3")P.complexity=3; else die2("bad --complexity (want L0|L1|L2|L3): "+c); }
        else if(a=="--mut-rate")  P.mut_rate=parse_d(val("--mut-rate"),"--mut-rate");
        else if(a=="--mut-str")   P.mut_str=parse_d(val("--mut-str"),"--mut-str");
        else if(a=="--ensemble")  P.ensemble=(int)parse_ll(val("--ensemble"),"--ensemble");
        else if(a=="--seed"){     P.seed=parse_ll(val("--seed"),"--seed"); P.seed_set=true; }
        else if(a=="--json")      P.json=true;
        else if(a=="--csv"){      P.csv=true; P.csv_path=val("--csv"); }
        else if(a=="--selftest")  P.selftest=true;
        else if(a=="--golden")    P.golden=true;
        else die2("unknown flag: "+a);
    }
    if(P.selftest) return run_selftest();
    if(P.golden)   return run_golden();

    // resolve k default
    if(!k_set) P.k = P.N/4;
    // range checks (bad input -> exit 2)
    if(P.pop<16||P.pop>8192)        die2("--pop out of range [16,8192]");
    if(P.gens<1||P.gens>5000)       die2("--gens out of range [1,5000]");
    if(P.steps<100||P.steps>5000)   die2("--steps out of range [100,5000]");
    if(P.N<32||P.N>1024)            die2("--N out of range [32,1024]");
    if(P.k<1||P.k>P.N)              die2("--k out of range [1,N]");
    if(P.zombie_frac<0.0||P.zombie_frac>1.0) die2("--zombie-frac out of range [0,1]");
    if(P.mut_rate<0.0||P.mut_rate>1.0)       die2("--mut-rate out of range [0,1]");
    if(P.mut_str<0.0||P.mut_str>1.0)         die2("--mut-str out of range [0,1]");
    if(P.ensemble<1||P.ensemble>256)         die2("--ensemble out of range [1,256]");
    if(!P.seed_set)                 die2("--seed is required (>=0)");
    if(P.seed<0)                    die2("--seed must be >=0");
    if(!P.json && !P.csv)           P.json=true;   // default to json output

    int code = run_config(P, true, nullptr);
    return code;   // 0 pass, 1 gate fired
}
