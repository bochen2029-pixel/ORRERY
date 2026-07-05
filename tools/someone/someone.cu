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

// ================================================================== THE SIM (ported dak kernels)
// One CUDA block per agent; encoder->bottleneck->decoder->predictor self-model + delay buffer +
// sensory/motor, in a complexity-gated world. Determinism: no device RNG state (stateless counter
// Gaussian noise), fixed-order shared-memory tree reductions, no float atomics. See MODULE.md.
static const int   D_DIM = 8, NUM_LIGHTS = 3, NUM_PRED = 2, NUM_FOOD = 2, BLOCK_THREADS = 256;
static const int   NIGHT_DURATION = 200, NIGHT_FREQ = 500, LIGHT_MOVE_FREQ = 100, PRED_MOVE_FREQ = 50;
// counter-RNG purpose salts (independent stateless streams — decouples env features, D-DAK-RNG)
static const uint64_t S_RESET_X=0x1111111111111111ULL, S_RESET_P=0x2222222222222222ULL;
static const uint64_t S_LIGHT_INIT=0xAAAA0001ULL, S_PRED_INIT=0xAAAA0002ULL, S_FOOD_INIT=0xAAAA0003ULL;
static const uint64_t S_LIGHT_MOVE=0xBBBB0001ULL, S_PRED_MOVE=0xBBBB0002ULL;
static const uint64_t S_INIT=0xC0FFEE01ULL, S_EVO=0xC0FFEE02ULL;

struct Environment {
    float lightX[NUM_LIGHTS], lightY[NUM_LIGHTS];
    float predX[NUM_PRED],   predY[NUM_PRED];
    float foodX[NUM_FOOD],   foodY[NUM_FOOD];
    int   isNight, predatorsActive, stepInGen;
};
static inline float clampf(float v,float lo,float hi){ return v<lo?lo:(v>hi?hi:v); }

// Base layout keyed by (rseed, gen) ONLY — LEVEL-INDEPENDENT. All entities drawn at every level
// (predators drawn even at L0, just inactive). This is the confound fix (BITE #2 / D-DAK-RNG).
static Environment env_base(uint64_t rseed, int gen, int level){
    Environment e;
    for(int i=0;i<NUM_LIGHTS;i++){
        e.lightX[i]=15.0f+70.0f*(float)counter_uniform(rseed^S_LIGHT_INIT,(uint64_t)gen,(uint64_t)(2*i),0);
        e.lightY[i]=15.0f+70.0f*(float)counter_uniform(rseed^S_LIGHT_INIT,(uint64_t)gen,(uint64_t)(2*i+1),0);
    }
    for(int i=0;i<NUM_PRED;i++){
        e.predX[i]=15.0f+70.0f*(float)counter_uniform(rseed^S_PRED_INIT,(uint64_t)gen,(uint64_t)(2*i),0);
        e.predY[i]=15.0f+70.0f*(float)counter_uniform(rseed^S_PRED_INIT,(uint64_t)gen,(uint64_t)(2*i+1),0);
    }
    for(int i=0;i<NUM_FOOD;i++){
        e.foodX[i]=15.0f+70.0f*(float)counter_uniform(rseed^S_FOOD_INIT,(uint64_t)gen,(uint64_t)(2*i),0);
        e.foodY[i]=15.0f+70.0f*(float)counter_uniform(rseed^S_FOOD_INIT,(uint64_t)gen,(uint64_t)(2*i+1),0);
    }
    e.predatorsActive = (level>=1)?1:0; e.isNight=0; e.stepInGen=0;
    return e;
}
// hash of the gen-0 base POSITIONS only (not flags) — the selftest asserts this is level-invariant.
static std::string base_layout_hash(uint64_t rseed, int gen, int level){
    Environment e = env_base(rseed,gen,level);
    std::string s;
    for(int i=0;i<NUM_LIGHTS;i++) s+=fmt6(e.lightX[i])+","+fmt6(e.lightY[i])+";";
    for(int i=0;i<NUM_PRED;i++)   s+=fmt6(e.predX[i]) +","+fmt6(e.predY[i]) +";";
    for(int i=0;i<NUM_FOOD;i++)   s+=fmt6(e.foodX[i]) +","+fmt6(e.foodY[i]) +";";
    return blake2b_hex(s);
}

// ------------------------------------------------------------------ device population
struct DevPop {
    float *x,*delayBuf; int *bufPtr;
    float *W,*E,*Ddec,*P,*Ws,*Wm; int *isZombie;
    float *px,*py,*angle,*speed;
    float *cumLight,*cumViability,*viability,*pureGap,*stateNorm,*fitness,*energy,*predatorDamage,*foodCollected;
    int *stepCount,*alive;
};
static void dp_alloc(DevPop& d,int pop,int N,int K,int F){
    long long WN=(long long)N*N, EN=(long long)K*N, DN=(long long)N*K, PN=(long long)N*F, WsN=(long long)N*8, WmN=(long long)2*N;
    CUDA_OK(cudaMalloc(&d.x, (size_t)pop*N*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.delayBuf, (size_t)pop*D_DIM*N*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.bufPtr, (size_t)pop*sizeof(int)));
    CUDA_OK(cudaMalloc(&d.W, (size_t)pop*WN*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.E, (size_t)pop*EN*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.Ddec, (size_t)pop*DN*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.P, (size_t)pop*PN*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.Ws, (size_t)pop*WsN*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.Wm, (size_t)pop*WmN*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.isZombie, (size_t)pop*sizeof(int)));
    float** f1[]={&d.px,&d.py,&d.angle,&d.speed,&d.cumLight,&d.cumViability,&d.viability,&d.pureGap,
                  &d.stateNorm,&d.fitness,&d.energy,&d.predatorDamage,&d.foodCollected};
    for(float** pp: f1) CUDA_OK(cudaMalloc(pp,(size_t)pop*sizeof(float)));
    CUDA_OK(cudaMalloc(&d.stepCount,(size_t)pop*sizeof(int)));
    CUDA_OK(cudaMalloc(&d.alive,(size_t)pop*sizeof(int)));
}
static void dp_free(DevPop& d){
    void* ptrs[]={d.x,d.delayBuf,d.bufPtr,d.W,d.E,d.Ddec,d.P,d.Ws,d.Wm,d.isZombie,d.px,d.py,d.angle,d.speed,
        d.cumLight,d.cumViability,d.viability,d.pureGap,d.stateNorm,d.fitness,d.energy,d.predatorDamage,
        d.foodCollected,d.stepCount,d.alive};
    for(void* p: ptrs) cudaFree(p);
}

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

// ------------------------------------------------------------------ kernels
__global__ void resetAgents(DevPop pop,int n,int N,uint64_t rseed,int gen){
    int a=blockIdx.x*blockDim.x+threadIdx.x; if(a>=n) return;
    for(int i=0;i<N;i++) pop.x[(long long)a*N+i]=0.1f*(float)counter_gauss(rseed^S_RESET_X,(uint64_t)a,(uint64_t)i,(uint64_t)gen);
    for(int i=0;i<D_DIM*N;i++) pop.delayBuf[(long long)a*D_DIM*N+i]=0.0f;
    pop.bufPtr[a]=0;
    pop.px[a]   =10.0f+80.0f*(float)counter_uniform(rseed^S_RESET_P,(uint64_t)a,0,(uint64_t)gen);
    pop.py[a]   =10.0f+80.0f*(float)counter_uniform(rseed^S_RESET_P,(uint64_t)a,1,(uint64_t)gen);
    pop.angle[a]=6.2831853f*(float)counter_uniform(rseed^S_RESET_P,(uint64_t)a,2,(uint64_t)gen);
    pop.speed[a]=0.0f; pop.cumLight[a]=0.0f; pop.cumViability[a]=0.0f; pop.viability[a]=0.5f;
    pop.pureGap[a]=0.0f; pop.stateNorm[a]=0.0f; pop.stepCount[a]=0; pop.energy[a]=1.0f;
    pop.predatorDamage[a]=0.0f; pop.foodCollected[a]=0.0f; pop.alive[a]=1;
}

__global__ void simulateStep(DevPop pop, Environment env, int numAgents, int N, int K,
                             uint64_t rseed, uint64_t gstep){
    int agent=blockIdx.x; if(agent>=numAgents) return; if(pop.alive[agent]==0) return;
    int tid=threadIdx.x; int F=2*N+K+8;
    extern __shared__ float sh[];
    float* s_x=sh; float* s_xDel=s_x+N; float* s_s=s_xDel+N; float* s_Ds=s_s+K;
    float* s_Wx=s_Ds+N; float* s_xNext=s_Wx+N; float* s_xPred=s_xNext+N; float* s_sDrive=s_xPred+N;
    float* s_feat=s_sDrive+N; float* s_sensory=s_feat+F; float* s_motor=s_sensory+8; float* s_reduce=s_motor+2;
    int isZ=pop.isZombie[agent]; int bufPtr=pop.bufPtr[agent];
    long long aN=(long long)agent*N;

    for(int i=tid;i<N;i+=blockDim.x){ s_x[i]=pop.x[aN+i]; s_xDel[i]=pop.delayBuf[(long long)agent*D_DIM*N+(long long)bufPtr*N+i]; }
    __syncthreads();

    if(tid==0){
        float px=pop.px[agent],py=pop.py[agent],ang=pop.angle[agent],en=pop.energy[agent];
        float bestLightDist=1000.0f,bestLightAngle=0.0f,totalLight=0.0f;
        if(env.isNight==0){
            for(int i=0;i<NUM_LIGHTS;i++){ float dx=env.lightX[i]-px,dy=env.lightY[i]-py;
                float dist=sqrtf(dx*dx+dy*dy)+0.01f; float light=fmaxf(0.0f,1.0f-dist/25.0f); totalLight+=light;
                if(dist<bestLightDist){ bestLightDist=dist; float toL=atan2f(dy,dx); bestLightAngle=toL-ang;
                    while(bestLightAngle>3.14159f)bestLightAngle-=6.28318f; while(bestLightAngle<-3.14159f)bestLightAngle+=6.28318f; } }
            pop.cumLight[agent]+=totalLight;
        }
        float predatorDanger=0.0f,predatorAngle=0.0f;
        if(env.predatorsActive){
            for(int i=0;i<NUM_PRED;i++){ float dx=env.predX[i]-px,dy=env.predY[i]-py;
                float dist=sqrtf(dx*dx+dy*dy)+0.01f;
                if(dist<15.0f){ float danger=1.0f-dist/15.0f; predatorDanger+=danger;
                    if(dist<8.0f) pop.predatorDamage[agent]+=0.01f*(1.0f-dist/8.0f);
                    float away=atan2f(-dy,-dx); predatorAngle=away-ang;
                    while(predatorAngle>3.14159f)predatorAngle-=6.28318f; while(predatorAngle<-3.14159f)predatorAngle+=6.28318f; } }
        }
        float foodSignal=0.0f,foodAngle=0.0f;
        for(int i=0;i<NUM_FOOD;i++){ float dx=env.foodX[i]-px,dy=env.foodY[i]-py;
            float dist=sqrtf(dx*dx+dy*dy)+0.01f;
            if(dist<20.0f){ foodSignal=fmaxf(foodSignal,1.0f-dist/20.0f);
                if(dist<5.0f){ pop.energy[agent]=fminf(1.0f,pop.energy[agent]+0.02f); pop.foodCollected[agent]+=0.02f; }
                float toF=atan2f(dy,dx); foodAngle=toF-ang;
                while(foodAngle>3.14159f)foodAngle-=6.28318f; while(foodAngle<-3.14159f)foodAngle+=6.28318f; } }
        pop.energy[agent]-=0.001f;
        if(pop.energy[agent]<=0.0f || pop.predatorDamage[agent]>0.5f) pop.alive[agent]=0;
        s_sensory[0]=env.isNight?0.0f:totalLight;
        s_sensory[1]=env.isNight?0.0f:bestLightAngle/3.14159f;
        s_sensory[2]=predatorDanger;
        s_sensory[3]=predatorAngle/3.14159f;
        s_sensory[4]=en;
        s_sensory[5]=foodSignal;
        s_sensory[6]=foodAngle/3.14159f;
        s_sensory[7]=env.isNight?1.0f:0.0f;
    }
    __syncthreads();

    // matvecs read weights COLUMN-MAJOR + __ldg (read-only cache) => coalesced global access
    const float* __restrict__ Wc = pop.W  + (long long)agent*N*N;
    const float* __restrict__ Ec = pop.E  + (long long)agent*K*N;
    const float* __restrict__ Dc = pop.Ddec + (long long)agent*N*K;
    const float* __restrict__ Pc = pop.P  + (long long)agent*N*F;
    const float* __restrict__ Sc = pop.Ws + (long long)agent*N*8;
    for(int i=tid;i<K;i+=blockDim.x){
        if(isZ){ s_s[i]=(i<N)?s_x[i]:0.0f; }
        else{ float sum=0.0f; for(int j=0;j<N;j++) sum+=__ldg(&Ec[(long long)j*K+i])*s_x[j]; s_s[i]=tanhf(sum); }
    }
    __syncthreads();
    for(int i=tid;i<N;i+=blockDim.x){
        if(isZ){ s_Ds[i]=s_x[i]; }
        else{ float sum=0.0f; for(int j=0;j<K;j++) sum+=__ldg(&Dc[(long long)j*N+i])*s_s[j]; s_Ds[i]=sum; }
    }
    __syncthreads();
    for(int i=tid;i<N;i+=blockDim.x){ s_feat[i]=s_x[i]; s_feat[N+i]=s_xDel[i]; }
    __syncthreads();
    for(int i=tid;i<K;i+=blockDim.x) s_feat[2*N+i]=s_s[i];
    if(tid<8) s_feat[2*N+K+tid]=s_sensory[tid];
    __syncthreads();
    for(int i=tid;i<N;i+=blockDim.x){ float sum=0.0f; for(int j=0;j<N;j++) sum+=__ldg(&Wc[(long long)j*N+i])*s_x[j]; s_Wx[i]=sum; }
    __syncthreads();
    for(int i=tid;i<N;i+=blockDim.x){ float sum=0.0f; for(int j=0;j<F;j++) sum+=__ldg(&Pc[(long long)j*N+i])*s_feat[j]; s_xPred[i]=sum; }
    __syncthreads();
    // homeostasis norm (warp-shuffle block reduction; fixed order => deterministic)
    float localSum=0.0f; for(int i=tid;i<N;i+=blockDim.x) localSum+=s_x[i]*s_x[i];
    float curNorm=sqrtf(blockReduceSum(localSum,s_reduce))+1e-10f; float normErr=3.0f-curNorm;
    for(int i=tid;i<N;i+=blockDim.x){ float sum=0.0f; for(int j=0;j<8;j++) sum+=__ldg(&Sc[(long long)j*N+i])*s_sensory[j]; s_sDrive[i]=sum; }
    __syncthreads();
    float eta=0.30f;
    for(int i=tid;i<N;i+=blockDim.x){
        float correction=0.15f*(tanhf(s_xPred[i])-s_x[i]);
        float homeo=eta*normErr*s_x[i]/curNorm; homeo=fmaxf(-0.5f,fminf(0.5f,homeo));
        float noise=(float)counter_gauss(rseed,(uint64_t)agent,(uint64_t)i,gstep)*0.02f;
        float input=s_Wx[i]+0.08f*s_xDel[i]+0.12f*s_Ds[i]+correction+s_sDrive[i]+homeo+noise;
        s_xNext[i]=tanhf(input);
    }
    __syncthreads();
    // prediction error, self-reconstruction gap, next-state norm — one fused pass, one reduction
    float errLocal=0.0f,gapLocal=0.0f,nextLocal=0.0f;
    for(int i=tid;i<N;i+=blockDim.x){
        float d=s_xNext[i]-tanhf(s_xPred[i]); errLocal+=d*d;
        float g=s_x[i]-s_Ds[i]; gapLocal+=g*g;
        nextLocal+=s_xNext[i]*s_xNext[i];
    }
    float3 red=blockReduceSum3(make_float3(errLocal,gapLocal,nextLocal),s_reduce);
    float errSum=red.x, gapSum=red.y, nextNormSq=red.z, xNormSq=curNorm*curNorm;
    if(tid==0){
        float stateNormVal=sqrtf(nextNormSq);
        float pureGapVal=isZ?0.0f:fminf(1.0f,sqrtf(gapSum)/(sqrtf(xNormSq)+1e-10f));
        float predErr=sqrtf(errSum/N); float normDev=stateNormVal-3.0f;
        float normHealth=expf(-normDev*normDev/1.5f); float errHealth=expf(-predErr*2.5f);
        float viabilityVal=fmaxf(0.0f,fminf(1.0f,normHealth*errHealth));
        pop.stateNorm[agent]=stateNormVal; pop.pureGap[agent]=pureGapVal; pop.viability[agent]=viabilityVal;
        pop.cumViability[agent]+=viabilityVal; pop.stepCount[agent]++;
    }
    __syncthreads();
    for(int i=tid;i<N;i+=blockDim.x){ pop.x[aN+i]=s_xNext[i]; pop.delayBuf[(long long)agent*D_DIM*N+(long long)bufPtr*N+i]=s_xNext[i]; }
    // motor: parallel dot products across the block (was a thread-0 serial matvec) + reduction
    { float m0=0.0f,m1=0.0f;
      for(int j=tid;j<N;j+=blockDim.x){ float xn=s_xNext[j];
          m0+=__ldg(&pop.Wm[(long long)agent*2*N+j])*xn; m1+=__ldg(&pop.Wm[(long long)agent*2*N+N+j])*xn; }
      float3 mred=blockReduceSum3(make_float3(m0,m1,0.0f),s_reduce);
      if(tid==0){ s_motor[0]=tanhf(mred.x); s_motor[1]=tanhf(mred.y); } }
    if(tid==0){
        float ang=pop.angle[agent],sp=pop.speed[agent],px=pop.px[agent],py=pop.py[agent];
        ang+=s_motor[1]*0.15f; sp=sp*0.9f+s_motor[0]*2.5f*0.1f; sp=fmaxf(-2.0f,fminf(3.0f,sp));
        px+=cosf(ang)*sp; py+=sinf(ang)*sp;
        if(px<5){px=5;sp*=-0.5f;} if(px>95){px=95;sp*=-0.5f;} if(py<5){py=5;sp*=-0.5f;} if(py>95){py=95;sp*=-0.5f;}
        pop.angle[agent]=ang; pop.speed[agent]=sp; pop.px[agent]=px; pop.py[agent]=py;
        pop.bufPtr[agent]=(bufPtr+1)%D_DIM;
    }
}

__global__ void computeFitness(DevPop pop,int n,int steps){
    int a=blockIdx.x*blockDim.x+threadIdx.x; if(a>=n) return;
    int st=pop.stepCount[a];
    float survival=(float)st/(float)steps;
    float lightScore=pop.cumLight[a]/(float)(st+1);
    float avgViab=(st>0)?pop.cumViability[a]/st:0.0f;
    float foodScore=pop.foodCollected[a];
    float damageScore=1.0f-fminf(1.0f,pop.predatorDamage[a]*2.0f);
    pop.fitness[a]=0.25f*survival+0.25f*lightScore+0.20f*foodScore+0.15f*damageScore+0.15f*avgViab;
}

// ------------------------------------------------------------------ host genome build / upload / evolve
struct Genomes { std::vector<float> W,E,Ddec,P,Ws,Wm; std::vector<int> isZombie; long long WN,EN,DN,PN,WsN,WmN; };
static double h_u01(std::mt19937_64& g){ return (double)(g()>>11)*(1.0/9007199254740992.0); }
static double h_normal(std::mt19937_64& g){ double u1=h_u01(g),u2=h_u01(g); if(u1<1e-12)u1=1e-12;
    return sqrt(-2.0*log(u1))*cos(6.283185307179586*u2); }

static void build_genomes(Genomes& G,const Params& P,uint64_t rseed){
    int N=P.N,K=P.k,F=2*N+K+8,pop=P.pop;
    G.WN=(long long)N*N; G.EN=(long long)K*N; G.DN=(long long)N*K; G.PN=(long long)N*F; G.WsN=(long long)N*8; G.WmN=(long long)2*N;
    G.W.resize((size_t)pop*G.WN); G.E.resize((size_t)pop*G.EN); G.Ddec.resize((size_t)pop*G.DN);
    G.P.resize((size_t)pop*G.PN); G.Ws.resize((size_t)pop*G.WsN); G.Wm.resize((size_t)pop*G.WmN); G.isZombie.resize(pop);
    std::mt19937_64 g(hash4(rseed,S_INIT,0,0));
    float w_scale=0.5f/sqrtf((float)N), e_scale=1.0f/sqrtf((float)N);
    // Weight matrices are stored COLUMN-MAJOR (transposed) so the kernel matvecs read global memory
    // COALESCED (consecutive threads -> consecutive addresses). A transpose of an i.i.d. random
    // matrix is still i.i.d., so W/E/P/Ws/Wm are filled linearly; Ddec is derived as E^T (initial
    // decode ~ inverse of encode -> small initial gap, matching the prototype). Layout convention:
    //   W col-major Wcm[j*N+i]=W[i][j];  E col-major Ecm[j*K+i]=E[i][j];  Ddec Dcm[j*N+i]=D[i][j].
    for(int i=0;i<pop;i++){
        G.isZombie[i]=(h_u01(g)<P.zombie_frac)?1:0;
        for(long long w=0;w<G.WN;w++) G.W[(size_t)i*G.WN+w]=(float)h_normal(g)*w_scale;
        for(long long w=0;w<G.EN;w++) G.E[(size_t)i*G.EN+w]=(float)h_normal(g)*e_scale;   // Ecm (col-major)
        // Ddec = E^T (column-major): Dcm[j*N+i] = Ecm[i*K+j]
        for(int ii=0;ii<N;ii++) for(int jj=0;jj<K;jj++)
            G.Ddec[(size_t)i*G.DN+(long long)jj*N+ii]=G.E[(size_t)i*G.EN+(long long)ii*K+jj];
        for(long long w=0;w<G.PN;w++) G.P[(size_t)i*G.PN+w]=(float)h_normal(g)*0.005f;
        for(long long w=0;w<G.WsN;w++) G.Ws[(size_t)i*G.WsN+w]=(float)h_normal(g)*0.3f;
        for(long long w=0;w<G.WmN;w++) G.Wm[(size_t)i*G.WmN+w]=(float)h_normal(g)*0.3f;
    }
}
static void upload_genomes(DevPop& d,const Genomes& G,int pop){
    CUDA_OK(cudaMemcpy(d.W,G.W.data(),G.W.size()*sizeof(float),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(d.E,G.E.data(),G.E.size()*sizeof(float),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(d.Ddec,G.Ddec.data(),G.Ddec.size()*sizeof(float),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(d.P,G.P.data(),G.P.size()*sizeof(float),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(d.Ws,G.Ws.data(),G.Ws.size()*sizeof(float),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(d.Wm,G.Wm.data(),G.Wm.size()*sizeof(float),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(d.isZombie,G.isZombie.data(),pop*sizeof(int),cudaMemcpyHostToDevice));
}
// deterministic evolution: rank (tie by index), elite, 3-way tournament, per-weight mutation.
static void evolve(Genomes& G,const std::vector<float>& fit,const Params& P,uint64_t rseed,int gen){
    int pop=P.pop;
    std::vector<int> idx(pop); for(int i=0;i<pop;i++) idx[i]=i;
    std::sort(idx.begin(),idx.end(),[&](int a,int b){ if(fit[a]!=fit[b]) return fit[a]>fit[b]; return a<b; });
    Genomes NG; NG.WN=G.WN;NG.EN=G.EN;NG.DN=G.DN;NG.PN=G.PN;NG.WsN=G.WsN;NG.WmN=G.WmN;
    NG.W.resize(G.W.size());NG.E.resize(G.E.size());NG.Ddec.resize(G.Ddec.size());
    NG.P.resize(G.P.size());NG.Ws.resize(G.Ws.size());NG.Wm.resize(G.Wm.size());NG.isZombie.resize(pop);
    int elite=std::max(2,pop/20);
    auto copyGenome=[&](int dst,int src){
        std::copy(G.W.begin()+(size_t)src*G.WN, G.W.begin()+(size_t)(src+1)*G.WN, NG.W.begin()+(size_t)dst*G.WN);
        std::copy(G.E.begin()+(size_t)src*G.EN, G.E.begin()+(size_t)(src+1)*G.EN, NG.E.begin()+(size_t)dst*G.EN);
        std::copy(G.Ddec.begin()+(size_t)src*G.DN, G.Ddec.begin()+(size_t)(src+1)*G.DN, NG.Ddec.begin()+(size_t)dst*G.DN);
        std::copy(G.P.begin()+(size_t)src*G.PN, G.P.begin()+(size_t)(src+1)*G.PN, NG.P.begin()+(size_t)dst*G.PN);
        std::copy(G.Ws.begin()+(size_t)src*G.WsN, G.Ws.begin()+(size_t)(src+1)*G.WsN, NG.Ws.begin()+(size_t)dst*G.WsN);
        std::copy(G.Wm.begin()+(size_t)src*G.WmN, G.Wm.begin()+(size_t)(src+1)*G.WmN, NG.Wm.begin()+(size_t)dst*G.WmN);
        NG.isZombie[dst]=G.isZombie[src];
    };
    for(int i=0;i<elite;i++) copyGenome(i,idx[i]);
    std::mt19937_64 eg(hash4(rseed,S_EVO,(uint64_t)gen,0));
    for(int i=elite;i<pop;i++){
        int a=(int)(h_u01(eg)*pop), b=(int)(h_u01(eg)*pop), c=(int)(h_u01(eg)*pop);
        if(a>=pop)a=pop-1; if(b>=pop)b=pop-1; if(c>=pop)c=pop-1;
        int win=a; if(fit[b]>fit[win])win=b; if(fit[c]>fit[win])win=c;
        copyGenome(i,win);
        auto mut=[&](std::vector<float>& v,long long base,long long len){
            for(long long w=0;w<len;w++){ if(h_u01(eg)<P.mut_rate) v[(size_t)base+w]+=(float)h_normal(eg)*(float)P.mut_str; } };
        mut(NG.W,(long long)i*G.WN,G.WN); mut(NG.E,(long long)i*G.EN,G.EN); mut(NG.Ddec,(long long)i*G.DN,G.DN);
        mut(NG.P,(long long)i*G.PN,G.PN); mut(NG.Ws,(long long)i*G.WsN,G.WsN); mut(NG.Wm,(long long)i*G.WmN,G.WmN);
    }
    G.W.swap(NG.W); G.E.swap(NG.E); G.Ddec.swap(NG.Ddec); G.P.swap(NG.P); G.Ws.swap(NG.Ws); G.Wm.swap(NG.Wm); G.isZombie.swap(NG.isZombie);
}

// ------------------------------------------------------------------ per-gen stats
struct GenStats { double avgFit,maxFit,normalFit,zombieFit,avgGap,avgViab,normalGap; int normalN,zombieN,normalAlive,zombieAlive; };
static GenStats gen_stats(const std::vector<float>& fit,const std::vector<float>& gap,const std::vector<float>& viab,
                          const std::vector<int>& alive,const std::vector<int>& isZ,int pop){
    GenStats s{}; s.maxFit=-1e30;
    double af=0,afc=0,nf=0,nfc=0,zf=0,zfc=0,ag=0,agc=0,av=0,avc=0,ng=0,ngc=0;
    auto kah=[](double& sum,double& comp,double y){ double t=sum,yy=y-comp,tt=t+yy; comp=(tt-t)-yy; sum=tt; };
    for(int i=0;i<pop;i++){
        double f=fit[i]; kah(af,afc,f); if(f>s.maxFit)s.maxFit=f;
        kah(ag,agc,(double)gap[i]); kah(av,avc,(double)viab[i]);
        if(isZ[i]){ kah(zf,zfc,f); s.zombieN++; if(alive[i])s.zombieAlive++; }
        else{ kah(nf,nfc,f); s.normalN++; if(alive[i])s.normalAlive++; kah(ng,ngc,(double)gap[i]); }
    }
    s.avgFit=af/pop; s.avgGap=ag/pop; s.avgViab=av/pop;
    s.normalFit=s.normalN?nf/s.normalN:0.0; s.zombieFit=s.zombieN?zf/s.zombieN:0.0;
    s.normalGap=s.normalN?ng/s.normalN:0.0;
    return s;
}

struct ReplicaOut { double normalMean, zombieMean, normalGap, normalAlive, zombieAlive; int extinctGen; };

static ReplicaOut run_replica(const Params& P, int replica, std::vector<std::string>* csvRows){
    uint64_t rseed=(uint64_t)P.seed+(uint64_t)replica;
    int N=P.N,K=P.k,F=2*N+K+8,pop=P.pop,steps=P.steps,gens=P.gens,level=P.complexity;
    Genomes G; build_genomes(G,P,rseed);
    DevPop dp; dp_alloc(dp,pop,N,K,F); upload_genomes(dp,G,pop);
    size_t shBytes=((size_t)9*N+2*K+BLOCK_THREADS+18)*sizeof(float);
    CUDA_OK(cudaFuncSetAttribute(simulateStep,cudaFuncAttributeMaxDynamicSharedMemorySize,(int)shBytes));
    int rblocks=(pop+255)/256;
    std::vector<float> fit(pop),gap(pop),viab(pop); std::vector<int> alive(pop);
    ReplicaOut ro{}; ro.extinctGen=-1; bool extinctSet=false; int gen0ZombieN=-1;
    for(int gen=0;gen<gens;gen++){
        resetAgents<<<rblocks,256>>>(dp,pop,N,rseed,gen); CUDA_OK(cudaGetLastError());
        Environment e=env_base(rseed,gen,level);
        for(int step=0;step<steps;step++){
            if(level>=3){ int cp=step%(NIGHT_FREQ+NIGHT_DURATION); e.isNight=(cp>=NIGHT_FREQ)?1:0; } else e.isNight=0;
            if(level>=2 && step>0 && step%LIGHT_MOVE_FREQ==0){
                for(int i=0;i<NUM_LIGHTS;i++){
                    e.lightX[i]+=((15.0f+70.0f*(float)counter_uniform(rseed^S_LIGHT_MOVE,(uint64_t)gen,(uint64_t)step,(uint64_t)(2*i)))-50.0f)*0.3f;
                    e.lightY[i]+=((15.0f+70.0f*(float)counter_uniform(rseed^S_LIGHT_MOVE,(uint64_t)gen,(uint64_t)step,(uint64_t)(2*i+1)))-50.0f)*0.3f;
                    e.lightX[i]=clampf(e.lightX[i],10.0f,90.0f); e.lightY[i]=clampf(e.lightY[i],10.0f,90.0f); } }
            if(level>=1 && step>0 && step%PRED_MOVE_FREQ==0){
                for(int i=0;i<NUM_PRED;i++){
                    e.predX[i]+=((15.0f+70.0f*(float)counter_uniform(rseed^S_PRED_MOVE,(uint64_t)gen,(uint64_t)step,(uint64_t)(2*i)))-50.0f)*0.4f;
                    e.predY[i]+=((15.0f+70.0f*(float)counter_uniform(rseed^S_PRED_MOVE,(uint64_t)gen,(uint64_t)step,(uint64_t)(2*i+1)))-50.0f)*0.4f;
                    e.predX[i]=clampf(e.predX[i],10.0f,90.0f); e.predY[i]=clampf(e.predY[i],10.0f,90.0f); } }
            e.stepInGen=step; uint64_t gstep=(uint64_t)gen*(uint64_t)steps+(uint64_t)step;
            simulateStep<<<pop,BLOCK_THREADS,shBytes>>>(dp,e,pop,N,K,rseed,gstep);
        }
        CUDA_OK(cudaGetLastError());
        computeFitness<<<rblocks,256>>>(dp,pop,steps); CUDA_OK(cudaGetLastError()); CUDA_OK(cudaDeviceSynchronize());
        CUDA_OK(cudaMemcpy(fit.data(),dp.fitness,pop*sizeof(float),cudaMemcpyDeviceToHost));
        CUDA_OK(cudaMemcpy(gap.data(),dp.pureGap,pop*sizeof(float),cudaMemcpyDeviceToHost));
        CUDA_OK(cudaMemcpy(viab.data(),dp.viability,pop*sizeof(float),cudaMemcpyDeviceToHost));
        CUDA_OK(cudaMemcpy(alive.data(),dp.alive,pop*sizeof(int),cudaMemcpyDeviceToHost));
        GenStats gs=gen_stats(fit,gap,viab,alive,G.isZombie,pop);
        if(gen==0) gen0ZombieN=gs.zombieN;
        if(!extinctSet && gen0ZombieN>0 && gs.zombieN==0){ ro.extinctGen=gen; extinctSet=true; }
        if(csvRows){
            char b[256]; snprintf(b,sizeof(b),"%d,%d,%s,%s,%s,%s,%d,%d,%d,%d,%s,%s",
                replica,gen,fmt6(gs.avgFit).c_str(),fmt6(gs.maxFit).c_str(),fmt6(gs.normalFit).c_str(),
                fmt6(gs.zombieFit).c_str(),gs.normalN,gs.zombieN,gs.normalAlive,gs.zombieAlive,
                fmt6(gs.avgGap).c_str(),fmt6(gs.avgViab).c_str());
            csvRows->push_back(std::string(b));
        }
        if(gen==gens-1){ ro.normalMean=gs.normalFit; ro.zombieMean=gs.zombieFit; ro.normalGap=gs.normalGap;
                         ro.normalAlive=gs.normalAlive; ro.zombieAlive=gs.zombieAlive; }
        if(gen<gens-1) evolve(G,fit,P,rseed,gen), upload_genomes(dp,G,pop);
    }
    dp_free(dp);
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
static const char* CSV_HEADER =
    "replica,gen,avg_fit,max_fit,normal_fit,zombie_fit,normal_n,zombie_n,normal_alive,zombie_alive,avg_gap,avg_viability";
static Result compute_result(const Params& P, std::vector<std::string>* csvPtr){
    std::vector<ReplicaOut> reps; reps.reserve(P.ensemble);
    for(int r=0;r<P.ensemble;r++) reps.push_back(run_replica(P,r,csvPtr));
    return aggregate(P, reps);
}
static int run_config(const Params& P, bool do_print, std::string* declared_out){
    std::vector<std::string> csvRows;
    std::vector<std::string>* csvPtr = (do_print && P.csv) ? &csvRows : nullptr;
    Result R = compute_result(P, csvPtr);
    bool gate_fired = R.g_zombie || R.g_nogap;
    std::string verdict = gate_fired ? "fail" : "pass";
    if(declared_out) *declared_out = declared_object(P,R,verdict);
    if(do_print){
        if(csvPtr){
            FILE* f=fopen(P.csv_path.c_str(),"wb");
            if(!f){ fprintf(stderr,"error: cannot open --csv path: %s\n",P.csv_path.c_str()); std::exit(2); }
            fprintf(f,"%s\n",CSV_HEADER);
            for(const auto& row: csvRows) fprintf(f,"%s\n",row.c_str());
            fclose(f);
        }
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
// small fast config for the sim-based selftests (keeps --selftest well under 30 s)
static Params small_params(){
    Params P; P.pop=48; P.gens=4; P.steps=150; P.N=48; P.k=12; P.zombie_frac=0.5;
    P.complexity=3; P.ensemble=2; P.seed=123; P.mut_rate=0.02; P.mut_str=0.1; P.seed_set=true;
    return P;
}
static int run_selftest(){
    bool ok=true;
    fprintf(stderr,"someone --selftest (v%s)\n", SOMEONE_VERSION);
    // 1. blake2b known-answer vectors (proves the hasher is correct)
    ok &= st_check("blake2b-256(\"\") KAT",
        blake2b_hex("")=="0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8");
    ok &= st_check("blake2b-256(\"abc\") KAT",
        blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // 2. THE CONFOUND FIX PROOF (BITE #2 / D-DAK-RNG): base layout is byte-identical across all four
    //    complexity levels at a fixed seed/gen (only the dynamics are gated, never the base world).
    { bool fair=true;
      for(uint64_t seed : {7ULL, 20260705ULL, 999ULL}){
        std::string h0=base_layout_hash(seed,0,0);
        for(int L=1;L<4;L++) if(base_layout_hash(seed,0,L)!=h0) fair=false;
        // and it must actually vary across gens (a live layout, not a constant)
        if(base_layout_hash(seed,1,0)==h0) fair=false;
      }
      ok &= st_check("base layout identical across L0..L3, varies by gen (confound fixed)", fair); }
    // 3. determinism smoke: same params+seed -> byte-identical declared object, twice (small config)
    { Params P=small_params(); std::string a,b; run_config(P,false,&a); run_config(P,false,&b);
      ok &= st_check("declared object identical across two runs (determinism smoke)", a==b); }
    // 4. gap mechanism: all-normal has a real gap (>0.01); all-zombie is gapless (<0.01, G-NO-GAP fires)
    { Params Pn=small_params(); Pn.zombie_frac=0.0; Result Rn=compute_result(Pn,nullptr);
      ok &= st_check("all-normal population has pureGap > 0.01", Rn.mean_pure_gap>0.01);
      Params Pz=small_params(); Pz.zombie_frac=1.0; Result Rz=compute_result(Pz,nullptr);
      ok &= st_check("all-zombie population is gapless (G-NO-GAP fires)", Rz.g_nogap && Rz.mean_pure_gap<0.01); }
    // 5. sign test sanity
    ok &= st_check("sign_test_p(4,0) == 0.0625", std::fabs(sign_test_p(4,0)-0.0625)<1e-12);
    ok &= st_check("sign_test_p(0,0) == 1.0", std::fabs(sign_test_p(0,0)-1.0)<1e-12);
    // 6. counter-RNG determinism (host)
    ok &= st_check("counter_gauss deterministic",
        counter_gauss(123,4,5,6)==counter_gauss(123,4,5,6));
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
