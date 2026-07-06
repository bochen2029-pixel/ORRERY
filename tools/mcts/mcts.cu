// mcts.cu — ORRERY tool `mcts` (v1.0.0)
// Headless, deterministic root-parallel UCT (Monte-Carlo Tree Search) search engine.
// Contract: contracts/mcts.contract.md v1.0.0 (+ mcts.schema.json). Contract is authoritative.
//
// Measures a search engine's ability to find an optimum in a defined space (an algorithm/mechanism);
// says NOTHING about qualia. §III-sealed. Envelope/determinism/golden discipline copied from someone.
//
// Build (from tools/mcts/, see BUILD.md):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 mcts.cu -o mcts.exe'

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <algorithm>

static const char* MCTS_VERSION = "1.0.0";
static const int MAXD = 16;
static const char* FIREWALL =
    "This measures a search engine's ability to find an optimum in a defined space (an algorithm); "
    "it says nothing about whether anything feels (acquaintance) - III-sealed.";

#define CUDA_OK(call) do { cudaError_t _e=(call); if(_e!=cudaSuccess){ \
    fprintf(stderr,"CUDA error %s at %s:%d: %s\n",#call,__FILE__,__LINE__,cudaGetErrorString(_e)); \
    std::exit(2);} } while(0)

// ------------------------------------------------------------------ counter RNG [from someone/ratchet]
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

// ------------------------------------------------------------------ BLAKE2b-256 (host) [KAT-validated]
struct Blake2b {
    uint64_t h[8]; uint64_t t[2]; uint8_t buf[128]; size_t buflen; size_t outlen;
    static uint64_t rotr64(uint64_t x, unsigned n){ return (x >> n) | (x << (64 - n)); }
    void init(size_t out){
        static const uint64_t IV[8] = {0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
            0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL};
        outlen=out; for(int i=0;i<8;i++) h[i]=IV[i]; h[0]^=0x01010000ULL^(uint64_t)out; t[0]=t[1]=0; buflen=0;
    }
    void compress(const uint8_t* block, bool last){
        static const uint64_t IV[8]={0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
            0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL};
        static const uint8_t S[12][16]={{0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},{14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3},
            {11,8,12,0,5,2,15,13,10,14,3,6,7,1,9,4},{7,9,3,1,13,12,11,14,2,6,5,10,4,0,15,8},
            {9,0,5,7,2,4,10,15,14,1,11,12,6,8,3,13},{2,12,6,10,0,11,8,3,4,13,7,5,15,14,1,9},
            {12,5,1,15,14,13,4,10,0,7,6,3,9,2,8,11},{13,11,7,14,12,1,3,9,5,0,15,4,8,6,2,10},
            {6,15,14,9,11,3,0,8,12,2,13,7,1,4,10,5},{10,2,8,4,7,6,1,5,15,11,9,14,3,12,13,0},
            {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},{14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3}};
        uint64_t m[16],v[16]; for(int i=0;i<16;i++){ m[i]=0; for(int j=0;j<8;j++) m[i]|=(uint64_t)block[i*8+j]<<(8*j); }
        for(int i=0;i<8;i++){ v[i]=h[i]; v[i+8]=IV[i]; } v[12]^=t[0]; v[13]^=t[1]; if(last) v[14]^=0xFFFFFFFFFFFFFFFFULL;
        #define G(a,b,c,d,x,y) do{ v[a]=v[a]+v[b]+x; v[d]=rotr64(v[d]^v[a],32); v[c]=v[c]+v[d]; v[b]=rotr64(v[b]^v[c],24); \
            v[a]=v[a]+v[b]+y; v[d]=rotr64(v[d]^v[a],16); v[c]=v[c]+v[d]; v[b]=rotr64(v[b]^v[c],63);}while(0)
        for(int r=0;r<12;r++){ const uint8_t* s=S[r];
            G(0,4,8,12,m[s[0]],m[s[1]]);G(1,5,9,13,m[s[2]],m[s[3]]);G(2,6,10,14,m[s[4]],m[s[5]]);G(3,7,11,15,m[s[6]],m[s[7]]);
            G(0,5,10,15,m[s[8]],m[s[9]]);G(1,6,11,12,m[s[10]],m[s[11]]);G(2,7,8,13,m[s[12]],m[s[13]]);G(3,4,9,14,m[s[14]],m[s[15]]); }
        #undef G
        for(int i=0;i<8;i++) h[i]^=v[i]^v[i+8];
    }
    void update(const uint8_t* in,size_t inlen){ while(inlen>0){ if(buflen==128){ t[0]+=128; if(t[0]<128)t[1]++; compress(buf,false); buflen=0; }
        size_t take=128-buflen; if(take>inlen)take=inlen; memcpy(buf+buflen,in,take); buflen+=take; in+=take; inlen-=take; } }
    void final(uint8_t* out){ t[0]+=buflen; if(t[0]<buflen)t[1]++; memset(buf+buflen,0,128-buflen); compress(buf,true);
        for(size_t i=0;i<outlen;i++) out[i]=(uint8_t)(h[i>>3]>>(8*(i&7))); }
};
static std::string blake2b_hex(const std::string& msg,size_t outlen=32){ Blake2b b; b.init(outlen);
    b.update((const uint8_t*)msg.data(),msg.size()); std::vector<uint8_t> o(outlen); b.final(o.data());
    static const char* hx="0123456789abcdef"; std::string s; for(size_t i=0;i<outlen;i++){ s.push_back(hx[o[i]>>4]); s.push_back(hx[o[i]&15]); } return s; }

// ------------------------------------------------------------------ canonical serialization
static std::string fmt6(double x){ if(std::fabs(x)<0.5e-6) x=0.0; char b[64]; snprintf(b,sizeof(b),"%.6f",x); return std::string(b); }
static std::string fmti(long long x){ char b[32]; snprintf(b,sizeof(b),"%lld",x); return std::string(b); }
static std::string jesc(const std::string& s){ std::string o; for(char c:s){ switch(c){
    case '"':o+="\\\"";break; case '\\':o+="\\\\";break; case '\n':o+="\\n";break; case '\t':o+="\\t";break; case '\r':o+="\\r";break; default:o.push_back(c);} } return o; }

// ------------------------------------------------------------------ params / result
struct Params {
    int branching=4, depth=6, trees=1024, max_nodes=8192; long long iters=2000;
    double c_uct=1.414214, tol=0.001; long long seed=0; bool seed_set=false;
    int landscape=0; // 0=match
    bool json=false, csv=false, selftest=false, golden=false; std::string csv_path;
};
struct Result {
    double optimum=1.0, best_reward=0, gap_to_optimum=0, mean_best_reward=0, frac_trees_optimal=0, mean_tree_nodes=0;
    bool found_optimum=false; std::vector<int> best_path;
    bool g_subopt=false; double g_val=0, g_thr=0;
};

// ------------------------------------------------------------------ UCT kernel (one tree per thread)
// Node pool (SoA), slice [tree*max_nodes .. +nodeCount). childBase=-1 => unexpanded leaf. Landscape=match:
// reward = (# positions leaf[d]==target[d]) / D, optimum 1.0 at leaf==target. Determinism: counter-RNG
// rollouts, unvisited-first + strict-max UCB1 (lowest-index tie), per-tree pool (no cross-thread races).
__global__ void mctsKernel(int P, int B, int D, long long iters, int max_nodes, float c_uct,
                           uint64_t seed, const int* __restrict__ target,
                           int* N, float* W, int* childBase,
                           float* outBest, int* outPath, int* outNodes){
    int tree = blockIdx.x*blockDim.x + threadIdx.x; if(tree>=P) return;
    long long base = (long long)tree*max_nodes;
    int nodeCount = 1;                                  // node 0 = root (pre-initialized)
    float treeBest = -1.0f; int bestPath[MAXD];
    int pathNodes[MAXD+2]; int pathAct[MAXD+2]; int leaf[MAXD];
    for(long long it=0; it<iters; it++){
        int cur=0, dep=0, pnLen=0;
        pathNodes[pnLen++]=0;                           // root (no action)
        // SELECTION
        while(dep < D){
            long long ci=base+cur; int cb=childBase[ci];
            if(cb < 0) break;                           // unexpanded leaf
            int Ncur=N[ci]; int besta=-1; float bestv=-1e30f;
            for(int a=0;a<B;a++){
                long long chi=base+(cb+a); int nc=N[chi];
                if(nc==0){ besta=a; break; }            // unvisited -> first
                float uct = W[chi]/nc + c_uct*sqrtf(logf((float)Ncur)/(float)nc);
                if(uct>bestv){ bestv=uct; besta=a; }
            }
            cur = cb+besta; dep++; pathNodes[pnLen]=cur; pathAct[pnLen]=besta; pnLen++;
        }
        // EXPANSION
        {
            long long ci=base+cur;
            if(dep<D && childBase[ci]<0 && nodeCount+B<=max_nodes){
                int cb=nodeCount; childBase[ci]=cb;
                for(int a=0;a<B;a++){ long long chi=base+(cb+a); N[chi]=0; W[chi]=0.0f; childBase[chi]=-1; }
                nodeCount+=B;
                cur=cb; dep++; pathNodes[pnLen]=cur; pathAct[pnLen]=0; pnLen++;   // descend into child 0
            }
        }
        // SIMULATION (rollout): partial actions = pathAct[1..dep], then random to depth D
        for(int d=0; d<dep; d++) leaf[d]=pathAct[d+1];
        for(int d=dep; d<D; d++){ int a=(int)(u01(hash4(seed,(uint64_t)tree,(uint64_t)it,(uint64_t)d))*B); if(a>=B)a=B-1; leaf[d]=a; }
        int matches=0; for(int d=0; d<D; d++) if(leaf[d]==target[d]) matches++;
        float reward=(float)matches/(float)D;
        // BACKPROP
        for(int k=0;k<pnLen;k++){ long long ni=base+pathNodes[k]; N[ni]+=1; W[ni]+=reward; }
        // track best leaf ever evaluated
        if(reward>treeBest){ treeBest=reward; for(int d=0;d<D;d++) bestPath[d]=leaf[d]; }
    }
    outBest[tree]=treeBest; outNodes[tree]=nodeCount;
    for(int d=0;d<D;d++) outPath[(long long)tree*D+d]=bestPath[d];
}

// ------------------------------------------------------------------ run the search -> Result
static Result run_mcts(const Params& P, std::vector<std::string>* csvRows){
    int B=P.branching, D=P.depth, T=P.trees, mn=P.max_nodes;
    std::vector<int> target(D);
    for(int d=0; d<D; d++) target[d]=(int)(hash4((uint64_t)P.seed ^ 0x7A46E77ULL,(uint64_t)d,0,0) % (uint64_t)B);
    int *d_target,*d_N,*d_cb,*d_outPath,*d_outNodes; float *d_W,*d_outBest;
    CUDA_OK(cudaMalloc(&d_target, D*sizeof(int)));
    CUDA_OK(cudaMalloc(&d_N, (size_t)T*mn*sizeof(int)));
    CUDA_OK(cudaMalloc(&d_W, (size_t)T*mn*sizeof(float)));
    CUDA_OK(cudaMalloc(&d_cb, (size_t)T*mn*sizeof(int)));
    CUDA_OK(cudaMalloc(&d_outBest, (size_t)T*sizeof(float)));
    CUDA_OK(cudaMalloc(&d_outPath, (size_t)T*D*sizeof(int)));
    CUDA_OK(cudaMalloc(&d_outNodes, (size_t)T*sizeof(int)));
    CUDA_OK(cudaMemcpy(d_target, target.data(), D*sizeof(int), cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemset(d_N, 0, (size_t)T*mn*sizeof(int)));
    CUDA_OK(cudaMemset(d_W, 0, (size_t)T*mn*sizeof(float)));
    CUDA_OK(cudaMemset(d_cb, 0xFF, (size_t)T*mn*sizeof(int)));      // childBase = -1 everywhere
    int threads=128, blocks=(T+threads-1)/threads;
    mctsKernel<<<blocks,threads>>>(T,B,D,P.iters,mn,(float)P.c_uct,(uint64_t)P.seed,d_target,d_N,d_W,d_cb,d_outBest,d_outPath,d_outNodes);
    CUDA_OK(cudaGetLastError()); CUDA_OK(cudaDeviceSynchronize());
    std::vector<float> outBest(T); std::vector<int> outPath((size_t)T*D), outNodes(T);
    CUDA_OK(cudaMemcpy(outBest.data(), d_outBest, T*sizeof(float), cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(outPath.data(), d_outPath, (size_t)T*D*sizeof(int), cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(outNodes.data(), d_outNodes, T*sizeof(int), cudaMemcpyDeviceToHost));
    cudaFree(d_target);cudaFree(d_N);cudaFree(d_W);cudaFree(d_cb);cudaFree(d_outBest);cudaFree(d_outPath);cudaFree(d_outNodes);

    Result R; R.optimum=1.0;
    // best_reward = max over trees; best_path = lex-min path among trees achieving it (fixed-order scan)
    float best=-1.0f; for(int t=0;t<T;t++) if(outBest[t]>best) best=outBest[t];
    std::vector<int> bp; bool have=false;
    for(int t=0;t<T;t++){
        if(outBest[t]==best){
            std::vector<int> pth(outPath.begin()+(size_t)t*D, outPath.begin()+(size_t)t*D+D);
            if(!have || pth<bp){ bp=pth; have=true; }
        }
    }
    R.best_reward=best; R.best_path=bp;
    R.gap_to_optimum=R.optimum-best; R.found_optimum=(R.gap_to_optimum<=P.tol);
    // means (index-order Kahan)
    double sB=0,cB=0,sN=0,cN=0; long long optCount=0;
    auto kah=[](double& s,double& c,double y){ double t=s,yy=y-c,tt=t+yy; c=(tt-t)-yy; s=tt; };
    for(int t=0;t<T;t++){ kah(sB,cB,outBest[t]); kah(sN,cN,(double)outNodes[t]);
        if(R.optimum-outBest[t] <= P.tol) optCount++; }
    R.mean_best_reward=sB/T; R.mean_tree_nodes=sN/T; R.frac_trees_optimal=(double)optCount/(double)T;
    R.g_thr=P.tol; R.g_val=R.gap_to_optimum; R.g_subopt=(R.gap_to_optimum>P.tol);
    if(csvRows){ for(int t=0;t<T;t++){ char b[128]; snprintf(b,sizeof(b),"%d,%s,%d,%lld",t,fmt6(outBest[t]).c_str(),outNodes[t],P.iters); csvRows->push_back(std::string(b)); } }
    return R;
}

// ------------------------------------------------------------------ serialize [someone shape]
static const char* LAND[1]={"match"};
static std::string params_json(const Params& P){
    return "{" "\"branching\":"+fmti(P.branching)+",\"depth\":"+fmti(P.depth)+",\"iters\":"+fmti(P.iters)
         + ",\"trees\":"+fmti(P.trees)+",\"c_uct\":"+fmt6(P.c_uct)+",\"max_nodes\":"+fmti(P.max_nodes)
         + ",\"landscape\":\""+LAND[P.landscape]+"\",\"tol\":"+fmt6(P.tol)+"}";
}
static std::string path_json(const std::vector<int>& p){ std::string s="["; for(size_t i=0;i<p.size();i++){ if(i)s+=","; s+=fmti(p[i]); } return s+"]"; }
static std::string result_json(const Params& P,const Result& R){
    return "{" "\"branching\":"+fmti(P.branching)+",\"depth\":"+fmti(P.depth)+",\"trees\":"+fmti(P.trees)
         + ",\"iters\":"+fmti(P.iters)+",\"optimum\":"+fmt6(R.optimum)+",\"best_reward\":"+fmt6(R.best_reward)
         + ",\"gap_to_optimum\":"+fmt6(R.gap_to_optimum)+",\"found_optimum\":"+std::string(R.found_optimum?"true":"false")
         + ",\"best_path\":"+path_json(R.best_path)+",\"mean_best_reward\":"+fmt6(R.mean_best_reward)
         + ",\"frac_trees_optimal\":"+fmt6(R.frac_trees_optimal)+",\"mean_tree_nodes\":"+fmt6(R.mean_tree_nodes)+"}";
}
static std::string gates_json(const Result& R){
    return "[{\"id\":\"G-SUBOPTIMAL\",\"fired\":"+std::string(R.g_subopt?"true":"false")
         + ",\"value\":"+fmt6(R.g_val)+",\"threshold\":"+fmt6(R.g_thr)+"}]";
}
static std::string declared_body(const Params& P,const Result& R,const std::string& v){
    return "\"seed\":"+fmti(P.seed)+",\"params\":"+params_json(P)+",\"result\":"+result_json(P,R)
         + ",\"gates\":"+gates_json(R)+",\"verdict\":\""+v+"\"";
}
static std::string declared_object(const Params& P,const Result& R,const std::string& v){ return "{"+declared_body(P,R,v)+"}"; }
static std::string full_envelope(const Params& P,const Result& R,const std::string& v){
    return "{\"tool\":\"mcts\",\"version\":\""+std::string(MCTS_VERSION)+"\","+declared_body(P,R,v)+",\"notes\":\""+jesc(FIREWALL)+"\"}";
}

// ------------------------------------------------------------------ run config
static int run_config(const Params& P, bool do_print, std::string* declared_out){
    std::vector<std::string> csv; std::vector<std::string>* csvp=(do_print&&P.csv)?&csv:nullptr;
    Result R=run_mcts(P,csvp);
    std::string verdict=R.g_subopt?"fail":"pass";
    if(declared_out) *declared_out=declared_object(P,R,verdict);
    if(do_print){
        if(csvp){ FILE* f=fopen(P.csv_path.c_str(),"wb"); if(!f){ fprintf(stderr,"error: cannot open --csv: %s\n",P.csv_path.c_str()); std::exit(2); }
            fprintf(f,"tree,best_reward,nodes,iters\n"); for(auto& r:csv) fprintf(f,"%s\n",r.c_str()); fclose(f); }
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str());
    }
    return R.g_subopt?1:0;
}

// ------------------------------------------------------------------ golden
static Params golden_params(){
    Params P; P.branching=4; P.depth=6; P.iters=2000; P.trees=1024; P.c_uct=1.414214; P.max_nodes=8192;
    P.landscape=0; P.tol=0.001; P.seed=20260705; P.json=true; P.seed_set=true; return P;
}
static bool read_golden_hash(std::string& out){
    const char* paths[]={"goldens/mcts/declared.hash","../../goldens/mcts/declared.hash","../../../goldens/mcts/declared.hash"};
    for(const char* p:paths){ FILE* f=fopen(p,"rb"); if(f){ char b[256]; size_t n=fread(b,1,sizeof(b)-1,f); fclose(f); b[n]=0; std::string s(b);
        while(!s.empty()&&(s.back()=='\n'||s.back()=='\r'||s.back()==' '||s.back()=='\t')) s.pop_back();
        size_t sp=s.find_first_of(" \t\r\n"); if(sp!=std::string::npos) s=s.substr(0,sp); out=s; return true; } }
    return false;
}
static int run_golden(){
    Params P=golden_params(); Result R=run_mcts(P,nullptr); std::string v=R.g_subopt?"fail":"pass";
    std::string declared=declared_object(P,R,v); std::string h=blake2b_hex(declared);
    printf("%s\n", full_envelope(P,R,v).c_str());
    std::string frozen;
    if(read_golden_hash(frozen)){ if(h==frozen){ fprintf(stderr,"GOLDEN OK blake2b=%s\n",h.c_str()); return 0; }
        fprintf(stderr,"GOLDEN MISMATCH\n  got   %s\n  want  %s\n",h.c_str(),frozen.c_str()); return 1; }
    fprintf(stderr,"GOLDEN NOT FROZEN (bootstrap) blake2b=%s\n  freeze into goldens/mcts/declared.hash\n",h.c_str());
    return 0;
}

// ------------------------------------------------------------------ selftest
static bool st(const char* n,bool ok){ fprintf(stderr,"  [%s] %s\n",ok?"PASS":"FAIL",n); return ok; }
static int run_selftest(){
    bool ok=true; fprintf(stderr,"mcts --selftest (v%s)\n",MCTS_VERSION);
    ok &= st("blake2b-256(\"abc\") KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // small findable instance: the ensemble reaches the optimum
    { Params P; P.branching=3; P.depth=4; P.iters=500; P.trees=256; P.max_nodes=2048; P.tol=0.001; P.seed=1; P.seed_set=true;
      Result R=run_mcts(P,nullptr);
      ok &= st("optimum found on small instance (best_reward=1.0)", R.found_optimum && std::fabs(R.best_reward-1.0)<1e-6);
      ok &= st("best_path length == depth", (int)R.best_path.size()==P.depth);
      ok &= st("G-SUBOPTIMAL clear when found", !R.g_subopt); }
    // best_path actually matches the target (reward is 1.0 only at leaf==target)
    { Params P; P.branching=4; P.depth=5; P.iters=800; P.trees=256; P.max_nodes=4096; P.tol=0.001; P.seed=7; P.seed_set=true;
      std::vector<int> tgt(P.depth); for(int d=0;d<P.depth;d++) tgt[d]=(int)(hash4((uint64_t)P.seed^0x7A46E77ULL,(uint64_t)d,0,0)%(uint64_t)P.branching);
      Result R=run_mcts(P,nullptr);
      ok &= st("best_path == derived target when optimum found", R.found_optimum && R.best_path==tgt); }
    // gate fires when the budget cannot reach the optimum (tiny iters, hard-ish)
    { Params P; P.branching=8; P.depth=12; P.iters=16; P.trees=1; P.max_nodes=256; P.tol=0.001; P.seed=3; P.seed_set=true;
      Result R=run_mcts(P,nullptr);
      ok &= st("G-SUBOPTIMAL fires on starved budget (exit-1 path)", R.g_subopt && !R.found_optimum); }
    // determinism
    { Params P=golden_params(); P.iters=400; P.trees=256; std::string a,b; run_config(P,false,&a); run_config(P,false,&b);
      ok &= st("declared object identical across two runs", a==b); }
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
        if(a=="--branching") P.branching=(int)p_ll(val("--branching"),"--branching");
        else if(a=="--depth") P.depth=(int)p_ll(val("--depth"),"--depth");
        else if(a=="--iters") P.iters=p_ll(val("--iters"),"--iters");
        else if(a=="--trees") P.trees=(int)p_ll(val("--trees"),"--trees");
        else if(a=="--c-uct") P.c_uct=p_d(val("--c-uct"),"--c-uct");
        else if(a=="--max-nodes") P.max_nodes=(int)p_ll(val("--max-nodes"),"--max-nodes");
        else if(a=="--landscape"){ std::string l=val("--landscape"); if(l=="match") P.landscape=0; else die2("bad --landscape (want: match): "+l); }
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
    if(P.branching<2||P.branching>32) die2("--branching out of range [2,32]");
    if(P.depth<1||P.depth>MAXD)       die2("--depth out of range [1,16]");
    if(P.iters<16||P.iters>1000000)   die2("--iters out of range [16,1000000]");
    if(P.trees<1||P.trees>1048576)    die2("--trees out of range [1,1048576]");
    if(P.c_uct<0.0||P.c_uct>4.0)      die2("--c-uct out of range [0,4]");
    if(P.max_nodes<64||P.max_nodes>1048576) die2("--max-nodes out of range [64,1048576]");
    if(P.tol<0.0||P.tol>1.0)          die2("--tol out of range [0,1]");
    if(!P.seed_set)                   die2("--seed is required (>=0)");
    if(P.seed<0)                      die2("--seed must be >=0");
    if(!P.json && !P.csv)             P.json=true;
    return run_config(P,true,nullptr);
}
