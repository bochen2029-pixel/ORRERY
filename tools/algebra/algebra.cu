// algebra.cu -- ORRERY tool `algebra` (v1.0.1)
// Headless, deterministic cuSOLVER tool: the block entanglement-entropy c-scaling of a free-boson
// chain (the RECEIPTED, ground-truth-checked half of F16/D-CP). Contract: contracts/algebra.contract.md.
//
// Measures an entropy-scaling law (structure/physics), NEVER qualia. III-sealed. Scope is deliberately
// narrow: Part A only (c=1 divergence / c=0 massive control); the WITHDRAWN Part-B value is NOT computed.
// Ports the Part-A leg of QUALIA_LAB gym/receipts/toy_cp_divergence.py.
// v1.0.1 [BEHAVIOR-NEUTRAL, D-020]: envelope/CLI spine now from lib/ (liborrery) instead of local
// copies -- declared output bit-identical, golden 1526918f unchanged. SOLVER_OK stays local (cuSOLVER).
//
// Build (from tools/algebra/, see BUILD.md -- needs cuSOLVER):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 algebra.cu ../../lib/envelope.cpp -o algebra.exe -lcusolver'

#include <cuda_runtime.h>
#include <cusolverDn.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <algorithm>
#include "../../lib/envelope.h"   // blake2b, fmt6/fmti/jesc, golden plumbing, CLI spine, CUDA_OK (D-020)
using namespace orrery;

static const char* ALGEBRA_VERSION = "1.0.1";
static const double LOG2 = 0.6931471805599453;
static const char* FIREWALL =
    "This measures an entropy-scaling law (structure/physics); it says nothing about whether anything "
    "feels (acquaintance) - III-sealed. Finite-dim is Type I: we reproduce the cutoff-running that "
    "forces the crossed product, not the trace-free Type III_1 factor.";

#define SOLVER_OK(call) do { cusolverStatus_t _s=(call); if(_s!=CUSOLVER_STATUS_SUCCESS){ \
    fprintf(stderr,"cuSOLVER error %s at %s:%d: status %d\n",#call,__FILE__,__LINE__,(int)_s); std::exit(2);} } while(0)

// ------------------------------------------------------------------ device kernels (col-major, n<=nmax)
// X_A[i][j]=0.5 sum_k V[i+kL] V[j+kL]/sqrt(w_k);  P_A[i][j]=0.5 sum_k V[i+kL] V[j+kL]*sqrt(w_k)  (i,j<n)
__global__ void kXAPA(const double* V,const double* w,int L,int n,double* XA,double* PA){
    int i=blockIdx.x*blockDim.x+threadIdx.x, j=blockIdx.y*blockDim.y+threadIdx.y;
    if(i>=n||j>=n) return; double sx=0.0,sp=0.0;
    for(int k=0;k<L;k++){ double vv=V[(long long)i+(long long)k*L]*V[(long long)j+(long long)k*L];
        double sw=sqrt(w[k]>1e-14?w[k]:1e-14); sx+=vv/sw; sp+=vv*sw; }
    XA[i+(long long)j*n]=0.5*sx; PA[i+(long long)j*n]=0.5*sp;
}
__global__ void kZeroUpper(double* A,int n){ int i=blockIdx.x*blockDim.x+threadIdx.x, j=blockIdx.y*blockDim.y+threadIdx.y;
    if(i<n&&j<n&&i<j) A[i+(long long)j*n]=0.0; }                     // keep lower (Cholesky factor)
__global__ void kGemmTN(const double* Lx,const double* PA,int n,double* T){  // T = Lx^T * PA
    int i=blockIdx.x*blockDim.x+threadIdx.x, j=blockIdx.y*blockDim.y+threadIdx.y; if(i>=n||j>=n) return;
    double s=0.0; for(int a=0;a<n;a++) s+=Lx[(long long)a+(long long)i*n]*PA[(long long)a+(long long)j*n]; T[i+(long long)j*n]=s; }
__global__ void kGemmNN(const double* T,const double* Lx,int n,double* M){    // M = T * Lx (then symmetrize)
    int i=blockIdx.x*blockDim.x+threadIdx.x, j=blockIdx.y*blockDim.y+threadIdx.y; if(i>=n||j>=n) return;
    double s=0.0; for(int b=0;b<n;b++) s+=T[(long long)i+(long long)b*n]*Lx[(long long)b+(long long)j*n]; M[i+(long long)j*n]=s; }
__global__ void kSym(double* M,int n){ int i=blockIdx.x*blockDim.x+threadIdx.x, j=blockIdx.y*blockDim.y+threadIdx.y;
    if(i<n&&j<n&&i<j){ double a=M[i+(long long)j*n], b=M[j+(long long)i*n], m=0.5*(a+b); M[i+(long long)j*n]=m; M[j+(long long)i*n]=m; } }

// ------------------------------------------------------------------ cuSOLVER context
static cusolverDnHandle_t g_solver=nullptr;
static void ensure_solver(){ if(!g_solver) SOLVER_OK(cusolverDnCreate(&g_solver)); }

// eigen-decompose symmetric n x n dA (col-major) in place -> dA=eigenvectors, dW=eigenvalues (ascending)
static void dsyevd(int n,double* dA,double* dW){
    int lwork=0; SOLVER_OK(cusolverDnDsyevd_bufferSize(g_solver,CUSOLVER_EIG_MODE_VECTOR,CUBLAS_FILL_MODE_LOWER,n,dA,n,dW,&lwork));
    double* work=nullptr; int* info=nullptr; CUDA_OK(cudaMalloc(&work,(size_t)lwork*sizeof(double))); CUDA_OK(cudaMalloc(&info,sizeof(int)));
    SOLVER_OK(cusolverDnDsyevd(g_solver,CUSOLVER_EIG_MODE_VECTOR,CUBLAS_FILL_MODE_LOWER,n,dA,n,dW,work,lwork,info));
    int hinfo=0; CUDA_OK(cudaMemcpy(&hinfo,info,sizeof(int),cudaMemcpyDeviceToHost)); if(hinfo!=0){ fprintf(stderr,"cuSOLVER syevd info=%d\n",hinfo); std::exit(2); }
    cudaFree(work); cudaFree(info);
}
static void dpotrf(int n,double* dA){   // Cholesky lower: dA -> Lx in lower triangle
    int lwork=0; SOLVER_OK(cusolverDnDpotrf_bufferSize(g_solver,CUBLAS_FILL_MODE_LOWER,n,dA,n,&lwork));
    double* work=nullptr; int* info=nullptr; CUDA_OK(cudaMalloc(&work,(size_t)lwork*sizeof(double))); CUDA_OK(cudaMalloc(&info,sizeof(int)));
    SOLVER_OK(cusolverDnDpotrf(g_solver,CUBLAS_FILL_MODE_LOWER,n,dA,n,work,lwork,info));
    int hinfo=0; CUDA_OK(cudaMemcpy(&hinfo,info,sizeof(int),cudaMemcpyDeviceToHost)); if(hinfo!=0){ fprintf(stderr,"cuSOLVER potrf info=%d\n",hinfo); std::exit(2); }
    cudaFree(work); cudaFree(info);
}

// ------------------------------------------------------------------ block entropy S(L) in nats (left half)
static double block_entropy_nats(int L,double m2){
    ensure_solver();
    int n=L/2;
    // build K on host (symmetric => col-major == row-major), upload
    std::vector<double> hK((size_t)L*L,0.0);
    for(int i=0;i<L;i++){ hK[(size_t)i+(size_t)i*L]=2.0+m2; if(i+1<L){ hK[(size_t)i+(size_t)(i+1)*L]=-1.0; hK[(size_t)(i+1)+(size_t)i*L]=-1.0; } }
    double *dK,*dW,*dXA,*dPA,*dLx,*dT,*dM,*dnu;
    CUDA_OK(cudaMalloc(&dK,(size_t)L*L*sizeof(double))); CUDA_OK(cudaMalloc(&dW,(size_t)L*sizeof(double)));
    CUDA_OK(cudaMalloc(&dXA,(size_t)n*n*sizeof(double))); CUDA_OK(cudaMalloc(&dPA,(size_t)n*n*sizeof(double)));
    CUDA_OK(cudaMalloc(&dLx,(size_t)n*n*sizeof(double))); CUDA_OK(cudaMalloc(&dT,(size_t)n*n*sizeof(double)));
    CUDA_OK(cudaMalloc(&dM,(size_t)n*n*sizeof(double))); CUDA_OK(cudaMalloc(&dnu,(size_t)n*sizeof(double)));
    CUDA_OK(cudaMemcpy(dK,hK.data(),(size_t)L*L*sizeof(double),cudaMemcpyHostToDevice));
    dsyevd(L,dK,dW);                                         // dK -> V, dW -> w (ascending)
    dim3 bs(16,16), gs((n+15)/16,(n+15)/16);
    kXAPA<<<gs,bs>>>(dK,dW,L,n,dXA,dPA); CUDA_OK(cudaGetLastError());
    CUDA_OK(cudaMemcpy(dLx,dXA,(size_t)n*n*sizeof(double),cudaMemcpyDeviceToDevice));
    dpotrf(n,dLx); kZeroUpper<<<gs,bs>>>(dLx,n); CUDA_OK(cudaGetLastError());
    kGemmTN<<<gs,bs>>>(dLx,dPA,n,dT); CUDA_OK(cudaGetLastError());     // T = Lx^T PA
    kGemmNN<<<gs,bs>>>(dT,dLx,n,dM);  CUDA_OK(cudaGetLastError());     // M = T Lx = Lx^T PA Lx (= nu^2)
    kSym<<<gs,bs>>>(dM,n); CUDA_OK(cudaGetLastError());
    dsyevd(n,dM,dnu);                                          // eigenvalues of M = nu^2 (ascending)
    std::vector<double> nu2(n); CUDA_OK(cudaMemcpy(nu2.data(),dnu,(size_t)n*sizeof(double),cudaMemcpyDeviceToHost));
    cudaFree(dK);cudaFree(dW);cudaFree(dXA);cudaFree(dPA);cudaFree(dLx);cudaFree(dT);cudaFree(dM);cudaFree(dnu);
    std::sort(nu2.begin(),nu2.end());                         // fixed order for the sum
    double S=0.0;
    for(int k=0;k<n;k++){ double v=sqrt(nu2[k]>0.25?nu2[k]:0.25); double a=v+0.5, b=v-0.5;
        S += a*log(a); if(b>1e-14) S -= b*log(b); }
    return S;                                                 // nats
}

// ------------------------------------------------------------------ params / result
struct Params {
    int regime=0;              // 0=critical, 1=massive
    double mass2=0.25, tol=0.15; int max_size=1024, num_sizes=5, fit_points=4;
    long long seed=0; bool seed_set=false;
    bool json=false, csv=false, selftest=false, golden=false; std::string csv_path;
};
struct Result {
    double c_expected=1.0, c_measured=0.0, c_error=0.0, slope_nats=0.0, growth_nats=0.0, s_at_max_bits=0.0;
    bool divergent=false; int min_size=0, max_size=0;
    bool g_wrong=false; double g_val=0, g_thr=0;
};

static std::vector<int> sweep_sizes(const Params& P){
    std::vector<int> s; for(int i=P.num_sizes-1;i>=0;i--){ int L=P.max_size>>i; if(L<4) L=4; if((L&1)) L++; s.push_back(L); }
    // dedup ascending
    std::sort(s.begin(),s.end()); s.erase(std::unique(s.begin(),s.end()),s.end()); return s;
}

static Result run_algebra(const Params& P, std::vector<std::string>* csv){
    double m2 = (P.regime==0) ? 1e-8 : P.mass2;
    std::vector<int> sizes=sweep_sizes(P);
    std::vector<double> Snats(sizes.size());
    for(size_t i=0;i<sizes.size();i++){ Snats[i]=block_entropy_nats(sizes[i],m2);
        if(csv){ char b[128]; snprintf(b,sizeof(b),"%d,%s,%s",sizes[i],fmt6(Snats[i]/LOG2).c_str(),fmt6(Snats[i]).c_str()); csv->push_back(std::string(b)); } }
    // least-squares slope of S(nats) vs ln(L) over the largest fit_points
    int fp=std::min((int)sizes.size(),P.fit_points); int start=(int)sizes.size()-fp;
    double sx=0,sy=0,sxx=0,sxy=0; for(int i=start;i<(int)sizes.size();i++){ double x=log((double)sizes[i]),y=Snats[i]; sx+=x;sy+=y;sxx+=x*x;sxy+=x*y; }
    double slope=(fp*sxy-sx*sy)/(fp*sxx-sx*sx);
    Result R; R.c_expected=(P.regime==0)?1.0:0.0; R.slope_nats=slope; R.c_measured=6.0*slope;
    R.c_error=std::fabs(R.c_measured-R.c_expected);
    R.growth_nats=Snats.back()-Snats.front(); R.divergent=(R.growth_nats>0.2);
    R.min_size=sizes.front(); R.max_size=sizes.back(); R.s_at_max_bits=Snats.back()/LOG2;
    R.g_thr=P.tol; R.g_val=R.c_error; R.g_wrong=(R.c_error>P.tol);
    return R;
}

// ------------------------------------------------------------------ serialize [someone shape]
static const char* REG[2]={"critical","massive"};
static std::string params_json(const Params& P){
    return "{" "\"regime\":\""+std::string(REG[P.regime])+"\",\"mass2\":"+fmt6(P.regime==0?1e-8:P.mass2)
         + ",\"max_size\":"+fmti(P.max_size)+",\"num_sizes\":"+fmti(P.num_sizes)+",\"fit_points\":"+fmti(P.fit_points)
         + ",\"tol\":"+fmt6(P.tol)+"}";
}
static std::string result_json(const Params& P,const Result& R){
    return "{" "\"regime\":\""+std::string(REG[P.regime])+"\",\"c_expected\":"+fmt6(R.c_expected)
         + ",\"c_measured\":"+fmt6(R.c_measured)+",\"c_error\":"+fmt6(R.c_error)+",\"slope_nats\":"+fmt6(R.slope_nats)
         + ",\"growth_nats\":"+fmt6(R.growth_nats)+",\"divergent\":"+std::string(R.divergent?"true":"false")
         + ",\"min_size\":"+fmti(R.min_size)+",\"max_size\":"+fmti(R.max_size)+",\"s_at_max_bits\":"+fmt6(R.s_at_max_bits)+"}";
}
static std::string gates_json(const Result& R){
    return "[{\"id\":\"G-WRONG-C\",\"fired\":"+std::string(R.g_wrong?"true":"false")+",\"value\":"+fmt6(R.g_val)+",\"threshold\":"+fmt6(R.g_thr)+"}]";
}
static std::string declared_body(const Params& P,const Result& R,const std::string& v){
    return "\"seed\":"+fmti(P.seed)+",\"params\":"+params_json(P)+",\"result\":"+result_json(P,R)+",\"gates\":"+gates_json(R)+",\"verdict\":\""+v+"\""; }
static std::string declared_object(const Params& P,const Result& R,const std::string& v){ return "{"+declared_body(P,R,v)+"}"; }
static std::string full_envelope(const Params& P,const Result& R,const std::string& v){
    return orrery::full_envelope("algebra", ALGEBRA_VERSION, declared_body(P,R,v), FIREWALL); }

static int run_config(const Params& P,bool do_print,std::string* declared_out){
    std::vector<std::string> csv; std::vector<std::string>* csvp=(do_print&&P.csv)?&csv:nullptr;
    Result R=run_algebra(P,csvp); std::string verdict=R.g_wrong?"fail":"pass";
    if(declared_out) *declared_out=declared_object(P,R,verdict);
    if(do_print){ if(csvp){ FILE* f=fopen(P.csv_path.c_str(),"wb"); if(!f){ fprintf(stderr,"error: cannot open --csv: %s\n",P.csv_path.c_str()); std::exit(2);}
        fprintf(f,"size,S_bits,S_nats\n"); for(auto& r:csv) fprintf(f,"%s\n",r.c_str()); fclose(f); }
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str()); }
    return R.g_wrong?1:0;
}

// ------------------------------------------------------------------ golden / selftest
static Params golden_params(){ Params P; P.regime=0; P.max_size=1024; P.num_sizes=5; P.fit_points=4; P.tol=0.15; P.seed=0; P.json=true; P.seed_set=true; return P; }
static int run_golden(){ Params P=golden_params(); Result R=run_algebra(P,nullptr); std::string v=R.g_wrong?"fail":"pass";
    return golden_check("algebra", declared_object(P,R,v), full_envelope(P,R,v)); }

static bool st(const char* n,bool ok){ return st_check(n, ok); }
static int run_selftest(){
    bool ok=true; fprintf(stderr,"algebra --selftest (v%s)\n",ALGEBRA_VERSION);
    ok &= st("blake2b-256(\"abc\") KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // ground truth vs the QUALIA_LAB receipt (toy_cp_divergence.py Part A): S(L) in bits
    { double s64=block_entropy_nats(64,1e-8)/LOG2, s128=block_entropy_nats(128,1e-8)/LOG2;
      ok &= st("S(64) ~= 0.85219 bits (receipt ground truth)", std::fabs(s64-0.85219)<0.005);
      ok &= st("S(128) ~= 1.01696 bits (receipt ground truth)", std::fabs(s128-1.01696)<0.005); }
    // critical: c ~= 1, divergent
    { Params P=golden_params(); Result R=run_algebra(P,nullptr);
      ok &= st("critical c_measured ~= 1.0 (|c-1|<0.05)", std::fabs(R.c_measured-1.0)<0.05);
      ok &= st("critical divergent + G-WRONG-C clear + verdict pass", R.divergent && !R.g_wrong); }
    // massive negative control: c ~= 0, saturates
    { Params P; P.regime=1; P.mass2=0.5; P.max_size=512; P.num_sizes=5; P.fit_points=4; P.tol=0.15; P.seed_set=true;
      Result R=run_algebra(P,nullptr);
      ok &= st("massive c_measured ~= 0 (|c|<0.15) + not divergent", std::fabs(R.c_measured)<0.15 && !R.divergent);
      ok &= st("massive G-WRONG-C clear (c matches expected 0)", !R.g_wrong); }
    // determinism
    { Params P=golden_params(); std::string a,b; run_config(P,false,&a); run_config(P,false,&b); ok &= st("declared object identical across two runs", a==b); }
    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n"); return ok?0:1;
}

// ------------------------------------------------------------------ CLI
static long long p_ll(const char* s,const char* f){ return parse_ll(s,f); }
static double p_d(const char* s,const char* f){ return parse_d(s,f); }

int main(int argc,char** argv){
    Params P;
    for(int i=1;i<argc;i++){ std::string a=argv[i];
        auto val=[&](const char* f)->const char*{ if(i+1>=argc) die2(std::string("missing value for ")+f); return argv[++i]; };
        if(a=="--regime"){ std::string r=val("--regime"); if(r=="critical")P.regime=0; else if(r=="massive")P.regime=1; else die2("bad --regime (critical|massive): "+r); }
        else if(a=="--mass2") P.mass2=p_d(val("--mass2"),"--mass2");
        else if(a=="--max-size") P.max_size=(int)p_ll(val("--max-size"),"--max-size");
        else if(a=="--num-sizes") P.num_sizes=(int)p_ll(val("--num-sizes"),"--num-sizes");
        else if(a=="--fit-points") P.fit_points=(int)p_ll(val("--fit-points"),"--fit-points");
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
    if(P.regime!=0 && P.regime!=1) die2("bad regime");
    if(P.mass2<1e-6||P.mass2>10.0) die2("--mass2 out of range [1e-6,10]");
    if(P.max_size<32||P.max_size>4096) die2("--max-size out of range [32,4096]");
    if(P.num_sizes<3||P.num_sizes>12)  die2("--num-sizes out of range [3,12]");
    if(P.fit_points<2||P.fit_points>12) die2("--fit-points out of range [2,12]");
    if(P.tol<0.0||P.tol>1.0)           die2("--tol out of range [0,1]");
    if(P.seed<0)                       die2("--seed must be >=0");
    if(!P.json && !P.csv)              P.json=true;
    return run_config(P,true,nullptr);
}
