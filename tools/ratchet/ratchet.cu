// ratchet.cu — ORRERY tool `ratchet` (v1.0.0)
// Headless, deterministic GPU Monte-Carlo of the recoverability branching ratchet.
// Contract: contracts/ratchet.contract.md v1.0.0 (+ ratchet.schema.json). Contract is authoritative.
//
// Measures a branching-process THRESHOLD (structure); says NOTHING about qualia. §III-sealed.
// Physics: toy_rr_frontier_ratchet.py. GPU MC pattern: criticality_cuda.cu. Envelope/determinism/
// golden discipline: copied from tools/someone (the template).
//
// Build (from tools/ratchet/, see BUILD.md):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 ratchet.cu -o ratchet.exe'

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>

static const char* RATCHET_VERSION = "1.0.0";
static const char* FIREWALL =
    "This measures a branching-process threshold (structure); it says nothing about whether "
    "anything feels (acquaintance) - III-sealed.";

#define CUDA_OK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ \
    fprintf(stderr,"CUDA error %s at %s:%d: %s\n",#call,__FILE__,__LINE__,cudaGetErrorString(_e)); \
    std::exit(2);} } while(0)

// ------------------------------------------------------------------ counter RNG (host+device) [from someone]
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
__host__ __device__ inline double u01(uint64_t h){ return (double)(h >> 11) * (1.0 / 9007199254740992.0); }

// ------------------------------------------------------------------ BLAKE2b-256 (host) [from someone, KAT-validated]
struct Blake2b {
    uint64_t h[8]; uint64_t t[2]; uint8_t buf[128]; size_t buflen; size_t outlen;
    static uint64_t rotr64(uint64_t x, unsigned n){ return (x >> n) | (x << (64 - n)); }
    void init(size_t out){
        static const uint64_t IV[8] = {
            0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
            0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL};
        outlen = out; for(int i=0;i<8;i++) h[i]=IV[i]; h[0]^=0x01010000ULL^(uint64_t)out; t[0]=t[1]=0; buflen=0;
    }
    void compress(const uint8_t* block, bool last){
        static const uint64_t IV[8] = {
            0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
            0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL};
        static const uint8_t S[12][16] = {
            {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},{14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3},
            {11,8,12,0,5,2,15,13,10,14,3,6,7,1,9,4},{7,9,3,1,13,12,11,14,2,6,5,10,4,0,15,8},
            {9,0,5,7,2,4,10,15,14,1,11,12,6,8,3,13},{2,12,6,10,0,11,8,3,4,13,7,5,15,14,1,9},
            {12,5,1,15,14,13,4,10,0,7,6,3,9,2,8,11},{13,11,7,14,12,1,3,9,5,0,15,4,8,6,2,10},
            {6,15,14,9,11,3,0,8,12,2,13,7,1,4,10,5},{10,2,8,4,7,6,1,5,15,11,9,14,3,12,13,0},
            {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},{14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3}};
        uint64_t m[16], v[16];
        for(int i=0;i<16;i++){ m[i]=0; for(int j=0;j<8;j++) m[i]|=(uint64_t)block[i*8+j]<<(8*j); }
        for(int i=0;i<8;i++){ v[i]=h[i]; v[i+8]=IV[i]; }
        v[12]^=t[0]; v[13]^=t[1]; if(last) v[14]^=0xFFFFFFFFFFFFFFFFULL;
        #define G(a,b,c,d,x,y) do{ \
            v[a]=v[a]+v[b]+x; v[d]=rotr64(v[d]^v[a],32); v[c]=v[c]+v[d]; v[b]=rotr64(v[b]^v[c],24); \
            v[a]=v[a]+v[b]+y; v[d]=rotr64(v[d]^v[a],16); v[c]=v[c]+v[d]; v[b]=rotr64(v[b]^v[c],63);}while(0)
        for(int r=0;r<12;r++){ const uint8_t* s=S[r];
            G(0,4,8,12,m[s[0]],m[s[1]]); G(1,5,9,13,m[s[2]],m[s[3]]); G(2,6,10,14,m[s[4]],m[s[5]]);
            G(3,7,11,15,m[s[6]],m[s[7]]); G(0,5,10,15,m[s[8]],m[s[9]]); G(1,6,11,12,m[s[10]],m[s[11]]);
            G(2,7,8,13,m[s[12]],m[s[13]]); G(3,4,9,14,m[s[14]],m[s[15]]); }
        #undef G
        for(int i=0;i<8;i++) h[i]^=v[i]^v[i+8];
    }
    void update(const uint8_t* in, size_t inlen){
        while(inlen>0){ if(buflen==128){ t[0]+=128; if(t[0]<128)t[1]++; compress(buf,false); buflen=0; }
            size_t take=128-buflen; if(take>inlen)take=inlen; memcpy(buf+buflen,in,take); buflen+=take; in+=take; inlen-=take; }
    }
    void final(uint8_t* out){ t[0]+=buflen; if(t[0]<buflen)t[1]++; memset(buf+buflen,0,128-buflen); compress(buf,true);
        for(size_t i=0;i<outlen;i++) out[i]=(uint8_t)(h[i>>3]>>(8*(i&7))); }
};
static std::string blake2b_hex(const std::string& msg, size_t outlen=32){
    Blake2b b; b.init(outlen); b.update((const uint8_t*)msg.data(), msg.size());
    std::vector<uint8_t> o(outlen); b.final(o.data());
    static const char* hx="0123456789abcdef"; std::string s; s.reserve(outlen*2);
    for(size_t i=0;i<outlen;i++){ s.push_back(hx[o[i]>>4]); s.push_back(hx[o[i]&15]); } return s;
}

// ------------------------------------------------------------------ canonical serialization [from someone]
static std::string fmt6(double x){ if(std::fabs(x)<0.5e-6) x=0.0; char b[64]; snprintf(b,sizeof(b),"%.6f",x); return std::string(b); }
static std::string fmti(long long x){ char b[32]; snprintf(b,sizeof(b),"%lld",x); return std::string(b); }
static std::string jesc(const std::string& s){ std::string o; for(char c:s){ switch(c){
    case '"':o+="\\\"";break; case '\\':o+="\\\\";break; case '\n':o+="\\n";break; case '\t':o+="\\t";break; case '\r':o+="\\r";break; default:o.push_back(c);} } return o; }

// ------------------------------------------------------------------ params / result
struct Params {
    double p=0.2, rho=0.5, tol=0.02;
    int R=3, tmax=1000, cap=256;
    long long trials=1000000; long long seed=0; bool seed_set=false;
    bool json=false, csv=false, selftest=false, golden=false; std::string csv_path;
};
struct Result {
    double q_star=0, p_unwrite_mc=0, p_unwrite_analytic=0, rel_error=0, rho_c=0, escaped_frac=0, mean_survival_steps=-1;
    std::string regime="critical";
    bool g_mismatch=false; double g_val=0, g_thr=0;
};

// ------------------------------------------------------------------ branching-ratchet MC kernel (one trajectory/thread, grid-stride)
// Offspring per fragment from one uniform u: u<p -> 0 (unwrite); u<thr1 -> 1; else -> 2. thr1 = p+(1-p)(1-rho).
// Determinism: every draw is u01(hash4(seed,traj,step,frag)); tallies are INTEGER atomics (associative). No float atomics.
__global__ void ratchetKernel(uint64_t seed, unsigned long long trials, double p, double thr1,
                              int R, int tmax, int cap,
                              unsigned long long* extinct, unsigned long long* escaped,
                              unsigned long long* survSum, unsigned long long* hist){
    unsigned long long stride = (unsigned long long)gridDim.x * blockDim.x;
    for(unsigned long long traj = (unsigned long long)blockIdx.x*blockDim.x + threadIdx.x;
        traj < trials; traj += stride){
        int n = R; int outcome = 0; int survStep = -1;   // 0 persist, 1 extinct, 2 escape
        for(int step=0; step<tmax; step++){
            int next = 0;
            for(int i=0;i<n;i++){
                double u = u01(hash4(seed, traj, (uint64_t)step, (uint64_t)i));
                if(u < p){}                 // 0 offspring (fragment unwrites)
                else if(u < thr1) next += 1;// survives
                else next += 2;             // survives + re-broadcasts
                if(next >= cap) break;      // supercritical escape imminent (deterministic early-out)
            }
            n = next;
            if(n == 0){ outcome=1; survStep=step+1; break; }
            if(n >= cap){ outcome=2; break; }
        }
        if(outcome==1){ atomicAdd(extinct,1ULL); atomicAdd(survSum,(unsigned long long)survStep); atomicAdd(&hist[survStep],1ULL); }
        else          { atomicAdd(escaped, (outcome==2)?1ULL:0ULL); atomicAdd(&hist[0],1ULL); } // hist[0]=survived (escape+persist)
    }
}

// ------------------------------------------------------------------ run the MC -> Result (+ optional histogram out)
static Result run_mc(const Params& P, std::vector<unsigned long long>* histOut){
    double thr1 = P.p + (1.0-P.p)*(1.0-P.rho);
    unsigned long long *d_ext,*d_esc,*d_surv,*d_hist;
    size_t histN = (size_t)P.tmax + 1;   // hist[0]=survived; hist[1..tmax]=extinct-at-step
    CUDA_OK(cudaMalloc(&d_ext,sizeof(unsigned long long)));
    CUDA_OK(cudaMalloc(&d_esc,sizeof(unsigned long long)));
    CUDA_OK(cudaMalloc(&d_surv,sizeof(unsigned long long)));
    CUDA_OK(cudaMalloc(&d_hist,histN*sizeof(unsigned long long)));
    CUDA_OK(cudaMemset(d_ext,0,sizeof(unsigned long long)));
    CUDA_OK(cudaMemset(d_esc,0,sizeof(unsigned long long)));
    CUDA_OK(cudaMemset(d_surv,0,sizeof(unsigned long long)));
    CUDA_OK(cudaMemset(d_hist,0,histN*sizeof(unsigned long long)));
    int threads=256, blocks=4096;   // fixed launch; grid-stride covers all trials
    ratchetKernel<<<blocks,threads>>>((uint64_t)P.seed,(unsigned long long)P.trials,P.p,thr1,P.R,P.tmax,P.cap,d_ext,d_esc,d_surv,d_hist);
    CUDA_OK(cudaGetLastError()); CUDA_OK(cudaDeviceSynchronize());
    unsigned long long ext=0,esc=0,surv=0;
    CUDA_OK(cudaMemcpy(&ext,d_ext,sizeof(ext),cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(&esc,d_esc,sizeof(esc),cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(&surv,d_surv,sizeof(surv),cudaMemcpyDeviceToHost));
    if(histOut){ histOut->resize(histN); CUDA_OK(cudaMemcpy(histOut->data(),d_hist,histN*sizeof(unsigned long long),cudaMemcpyDeviceToHost)); }
    cudaFree(d_ext); cudaFree(d_esc); cudaFree(d_surv); cudaFree(d_hist);

    Result R;
    R.q_star = fmin(1.0, P.p/((1.0-P.p)*P.rho));
    R.p_unwrite_analytic = pow(R.q_star,(double)P.R);
    R.p_unwrite_mc = (double)ext/(double)P.trials;
    R.rho_c = P.p/(1.0-P.p);
    R.escaped_frac = (double)esc/(double)P.trials;
    R.mean_survival_steps = ext>0 ? (double)surv/(double)ext : -1.0;
    double denom = fmax(R.p_unwrite_analytic, 1.0/(double)P.trials);
    R.rel_error = fabs(R.p_unwrite_mc - R.p_unwrite_analytic)/denom;
    double lhs=(1.0-P.p)*P.rho;
    R.regime = (lhs > P.p+1e-12) ? "supercritical" : (lhs < P.p-1e-12) ? "subcritical" : "critical";
    R.g_thr = P.tol; R.g_val = R.rel_error; R.g_mismatch = (R.rel_error > P.tol);
    return R;
}

// ------------------------------------------------------------------ serialize (declared body + envelope) [someone shape]
static std::string params_json(const Params& P){
    return "{\"p\":"+fmt6(P.p)+",\"rho\":"+fmt6(P.rho)+",\"R\":"+fmti(P.R)+",\"trials\":"+fmti(P.trials)
         + ",\"tmax\":"+fmti(P.tmax)+",\"cap\":"+fmti(P.cap)+",\"tol\":"+fmt6(P.tol)+"}";
}
static std::string result_json(const Params& P, const Result& R){
    return "{\"p\":"+fmt6(P.p)+",\"rho\":"+fmt6(P.rho)+",\"R\":"+fmti(P.R)+",\"trials\":"+fmti(P.trials)
         + ",\"q_star\":"+fmt6(R.q_star)+",\"p_unwrite_mc\":"+fmt6(R.p_unwrite_mc)
         + ",\"p_unwrite_analytic\":"+fmt6(R.p_unwrite_analytic)+",\"rel_error\":"+fmt6(R.rel_error)
         + ",\"regime\":\""+R.regime+"\",\"rho_c\":"+fmt6(R.rho_c)
         + ",\"escaped_frac\":"+fmt6(R.escaped_frac)+",\"mean_survival_steps\":"+fmt6(R.mean_survival_steps)+"}";
}
static std::string gates_json(const Result& R){
    return "[{\"id\":\"G-THEORY-MISMATCH\",\"fired\":"+std::string(R.g_mismatch?"true":"false")
         + ",\"value\":"+fmt6(R.g_val)+",\"threshold\":"+fmt6(R.g_thr)+"}]";
}
static std::string declared_body(const Params& P, const Result& R, const std::string& v){
    return "\"seed\":"+fmti(P.seed)+",\"params\":"+params_json(P)+",\"result\":"+result_json(P,R)
         + ",\"gates\":"+gates_json(R)+",\"verdict\":\""+v+"\"";
}
static std::string declared_object(const Params& P, const Result& R, const std::string& v){ return "{"+declared_body(P,R,v)+"}"; }
static std::string full_envelope(const Params& P, const Result& R, const std::string& v){
    return "{\"tool\":\"ratchet\",\"version\":\""+std::string(RATCHET_VERSION)+"\","+declared_body(P,R,v)
         + ",\"notes\":\""+jesc(FIREWALL)+"\"}";
}

// ------------------------------------------------------------------ run one config
static int run_config(const Params& P, bool do_print, std::string* declared_out){
    std::vector<unsigned long long> hist;
    Result R = run_mc(P, (do_print && P.csv) ? &hist : nullptr);
    std::string verdict = R.g_mismatch ? "fail" : "pass";
    if(declared_out) *declared_out = declared_object(P,R,verdict);
    if(do_print){
        if(P.csv){
            FILE* f=fopen(P.csv_path.c_str(),"wb");
            if(!f){ fprintf(stderr,"error: cannot open --csv path: %s\n",P.csv_path.c_str()); std::exit(2); }
            fprintf(f,"survival_steps,count\n");
            for(int s=1;s<=P.tmax;s++) if(hist[s]) fprintf(f,"%d,%llu\n",s,hist[s]);
            fprintf(f,"-1,%llu\n",hist[0]);   // survived/escaped
            fclose(f);
        }
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str());
    }
    return R.g_mismatch ? 1 : 0;
}

// ------------------------------------------------------------------ golden
static Params golden_params(){
    Params P; P.p=0.2; P.rho=0.5; P.R=3; P.trials=4000000; P.tmax=500; P.cap=256; P.tol=0.02;
    P.seed=20260705; P.json=true; P.seed_set=true; return P;
}
static bool read_golden_hash(std::string& out){
    const char* paths[]={"goldens/ratchet/declared.hash","../../goldens/ratchet/declared.hash","../../../goldens/ratchet/declared.hash"};
    for(const char* p:paths){ FILE* f=fopen(p,"rb");
        if(f){ char b[256]; size_t n=fread(b,1,sizeof(b)-1,f); fclose(f); b[n]=0; std::string s(b);
            while(!s.empty()&&(s.back()=='\n'||s.back()=='\r'||s.back()==' '||s.back()=='\t')) s.pop_back();
            size_t sp=s.find_first_of(" \t\r\n"); if(sp!=std::string::npos) s=s.substr(0,sp); out=s; return true; } }
    return false;
}
static int run_golden(){
    Params P=golden_params(); std::string declared; Result R=run_mc(P,nullptr);
    std::string verdict = R.g_mismatch?"fail":"pass"; declared=declared_object(P,R,verdict);
    std::string hash=blake2b_hex(declared);
    printf("%s\n", full_envelope(P,R,verdict).c_str());
    std::string frozen;
    if(read_golden_hash(frozen)){
        if(hash==frozen){ fprintf(stderr,"GOLDEN OK blake2b=%s\n",hash.c_str()); return 0; }
        fprintf(stderr,"GOLDEN MISMATCH\n  got   %s\n  want  %s\n",hash.c_str(),frozen.c_str()); return 1;
    }
    fprintf(stderr,"GOLDEN NOT FROZEN (bootstrap) blake2b=%s\n  freeze into goldens/ratchet/declared.hash\n",hash.c_str());
    return 0;
}

// ------------------------------------------------------------------ selftest
static bool st(const char* n, bool ok){ fprintf(stderr,"  [%s] %s\n",ok?"PASS":"FAIL",n); return ok; }
static int run_selftest(){
    bool ok=true; fprintf(stderr,"ratchet --selftest (v%s)\n",RATCHET_VERSION);
    ok &= st("blake2b-256(\"\") KAT", blake2b_hex("")=="0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8");
    ok &= st("blake2b-256(\"abc\") KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // analytic identities
    { double qs=fmin(1.0,0.2/((1.0-0.2)*0.5)); ok &= st("q*(0.2,0.5)=0.5", fabs(qs-0.5)<1e-12);
      ok &= st("P_analytic(R=3)=0.125", fabs(pow(qs,3.0)-0.125)<1e-12);
      ok &= st("rho_c(0.2)=0.25", fabs(0.2/(1.0-0.2)-0.25)<1e-12); }
    // MC reproduces analytic: supercritical point
    { Params P; P.p=0.2; P.rho=0.5; P.R=3; P.trials=1000000; P.tmax=500; P.cap=256; P.seed=1; P.seed_set=true;
      Result R=run_mc(P,nullptr); ok &= st("MC~analytic supercritical (rel_error<0.05)", R.rel_error<0.05);
      ok &= st("regime=supercritical", R.regime=="supercritical"); }
    // subcritical point: (1-p)rho < p -> q*=1 -> P_unwrite~1
    { Params P; P.p=0.4; P.rho=0.3; P.R=3; P.trials=300000; P.tmax=500; P.cap=256; P.seed=2; P.seed_set=true;
      Result R=run_mc(P,nullptr); ok &= st("subcritical q*=1", fabs(R.q_star-1.0)<1e-12);
      ok &= st("subcritical P_unwrite_mc~1 (>0.99)", R.p_unwrite_mc>0.99);
      ok &= st("regime=subcritical", R.regime=="subcritical"); }
    // determinism
    { Params P=golden_params(); P.trials=500000; std::string a,b; run_config(P,false,&a); run_config(P,false,&b);
      ok &= st("declared identical across 2 runs", a==b); }
    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n"); return ok?0:1;
}

// ------------------------------------------------------------------ CLI
static void die2(const std::string& m){ fprintf(stderr,"error: %s\n",m.c_str()); std::exit(2); }
static long long p_ll(const char* s,const char* f){ char* e=nullptr; long long v=strtoll(s,&e,10); if(e==s||*e!=0) die2(std::string("bad integer for ")+f+": "+s); return v; }
static double p_d(const char* s,const char* f){ char* e=nullptr; double v=strtod(s,&e); if(e==s||*e!=0) die2(std::string("bad number for ")+f+": "+s); return v; }

int main(int argc,char** argv){
    Params P;
    for(int i=1;i<argc;i++){ std::string a=argv[i];
        auto val=[&](const char* f)->const char*{ if(i+1>=argc) die2(std::string("missing value for ")+f); return argv[++i]; };
        if(a=="--p") P.p=p_d(val("--p"),"--p");
        else if(a=="--rho") P.rho=p_d(val("--rho"),"--rho");
        else if(a=="--R") P.R=(int)p_ll(val("--R"),"--R");
        else if(a=="--trials") P.trials=p_ll(val("--trials"),"--trials");
        else if(a=="--tmax") P.tmax=(int)p_ll(val("--tmax"),"--tmax");
        else if(a=="--cap") P.cap=(int)p_ll(val("--cap"),"--cap");
        else if(a=="--tol") P.tol=p_d(val("--tol"),"--tol");
        else if(a=="--seed"){ P.seed=p_ll(val("--seed"),"--seed"); P.seed_set=true; }
        else if(a=="--json") P.json=true;
        else if(a=="--csv"){ P.csv=true; P.csv_path=val("--csv"); }
        else if(a=="--selftest") P.selftest=true;
        else if(a=="--golden") P.golden=true;
        else die2("unknown flag: "+a);
    }
    if(P.selftest) return run_selftest();
    if(P.golden)   return run_golden();
    if(!(P.p>0.0 && P.p<1.0))       die2("--p out of range (0,1)");
    if(!(P.rho>0.0 && P.rho<1.0))   die2("--rho out of range (0,1)");
    if(P.R<1||P.R>4096)             die2("--R out of range [1,4096]");
    if(P.trials<1000||P.trials>4000000000LL) die2("--trials out of range [1000,4e9]");
    if(P.tmax<10||P.tmax>100000)    die2("--tmax out of range [10,100000]");
    if(P.cap<16||P.cap>65536)       die2("--cap out of range [16,65536]");
    if(P.tol<0.0||P.tol>1.0)        die2("--tol out of range [0,1]");
    if(!P.seed_set)                 die2("--seed is required (>=0)");
    if(P.seed<0)                    die2("--seed must be >=0");
    if(!P.json && !P.csv)           P.json=true;
    return run_config(P,true,nullptr);
}
