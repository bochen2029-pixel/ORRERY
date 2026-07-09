// ratchet.cu — ORRERY tool `ratchet` (v1.0.1)
// Headless, deterministic GPU Monte-Carlo of the recoverability branching ratchet.
// Contract: contracts/ratchet.contract.md (+ ratchet.schema.json). Contract is authoritative.
//
// Measures a branching-process THRESHOLD (structure); says NOTHING about qualia. §III-sealed.
// Physics: toy_rr_frontier_ratchet.py. GPU MC pattern: criticality_cuda.cu.
// v1.0.1 [BEHAVIOR-NEUTRAL, D-020]: envelope/RNG/CLI spine now from lib/ (liborrery) instead of
// local copies — declared output bit-identical, golden 91fce3c4 unchanged.
//
// Build (from tools/ratchet/, see BUILD.md):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 ratchet.cu ../../lib/envelope.cpp -o ratchet.exe'

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include "../../lib/envelope.h"   // blake2b, fmt6/fmti/jesc, golden plumbing, CLI spine, CUDA_OK (D-020)
#include "../../lib/rng.cuh"      // splitmix64 / hash4 / u01 (the D-012 kit)
using namespace orrery;

static const char* RATCHET_VERSION = "1.0.1";
static const char* FIREWALL =
    "This measures a branching-process threshold (structure); it says nothing about whether "
    "anything feels (acquaintance) - III-sealed.";

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
    return orrery::full_envelope("ratchet", RATCHET_VERSION, declared_body(P,R,v), FIREWALL);
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
static int run_golden(){
    Params P=golden_params(); Result R=run_mc(P,nullptr);
    std::string verdict = R.g_mismatch?"fail":"pass";
    return golden_check("ratchet", declared_object(P,R,verdict), full_envelope(P,R,verdict));
}

// ------------------------------------------------------------------ selftest
static bool st(const char* n, bool ok){ return st_check(n, ok); }
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
static long long p_ll(const char* s,const char* f){ return parse_ll(s,f); }
static double p_d(const char* s,const char* f){ return parse_d(s,f); }

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
