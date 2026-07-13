// trace-born.cu -- ORRERY tool `trace-born` (v1.0.0)
// Headless, deterministic CUDA + cuSOLVER tool: does the normalized-trace weight over a redundancy-defined
// branch projection reproduce the Born weight |c_i|^2 in a finite DECOHERING model? The mechanical,
// ground-truth-checked core of science F15 (Zurek envariance + quantum Darwinism). Contract:
// contracts/trace-born.contract.md. Sharpens QUALIA_LAB gym/receipts/toy_a1_born_finegrain.py.
//
// Measures a STRUCTURAL fact (the quadratic form is forced by the mechanics); it does NOT derive the one
// premise F15 rests on -- noncontextual credence = f(local state) (D-BORN, Baker 2007) -- which is labeled
// and excluded. Says nothing about why a probability is EXPERIENCED: structure, never acquaintance. III-sealed.
// Extends the `algebra` cuSOLVER machinery (real-symmetric Dsyevd -> complex-Hermitian Zheevd).
//
// Build (from tools/trace-born/, see BUILD.md -- needs cuSOLVER):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 trace-born.cu ../../lib/envelope.cpp -o trace-born.exe -lcusolver'

#include <cuda_runtime.h>
#include <cuComplex.h>
#include <cusolverDn.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <complex>
#include <algorithm>
#include "../../lib/envelope.h"   // blake2b, fmt6/fmti, golden plumbing, CLI spine, CUDA_OK (D-020)
using namespace orrery;

static const char* TRACEBORN_VERSION = "1.0.0";
static const double ORACLE_TOL = 1e-8;   // brute-force vs analytic Gram: above this => SUSPECT (exit 2, I-11)
static const char* FIREWALL =
    "This measures a structural fact: in a finite decohering model the redundant-record trace weight equals "
    "|c_i|^2, and unitary fine-graining forces the quadratic form (science F15, the mechanical core). It does "
    "NOT derive the one premise F15 rests on - noncontextual credence = f(local state) (D-BORN, Baker 2007) - "
    "which is labeled and excluded. It says nothing about why a probability is experienced: structure, never "
    "acquaintance (qualia). III-sealed.";

#define SOLVER_OK(call) do { cusolverStatus_t _s=(call); if(_s!=CUSOLVER_STATUS_SUCCESS){ \
    fprintf(stderr,"cuSOLVER error %s at %s:%d: status %d\n",#call,__FILE__,__LINE__,(int)_s); std::exit(2);} } while(0)

// ---------------------------------------------------------------- device kernels (ordered, no atomics)
// |Psi>[a,E] = c_a * prod_k r[a][e_k]   (E decoded base-d into digits e_k; state as (re,im) arrays)
__global__ void kBuildState(const double* r,const double* cre,const double* cim,int d,int R,long long envN,
                            double* psre,double* psim){
    long long g=(long long)blockIdx.x*blockDim.x+threadIdx.x; long long total=(long long)d*envN; if(g>=total) return;
    int a=(int)(g/envN); long long E=g%envN; double prod=1.0; long long e=E;
    for(int k=0;k<R;k++){ int ek=(int)(e%d); e/=d; prod*=r[a*d+ek]; }
    psre[g]=cre[a]*prod; psim[g]=cim[a]*prod;
}
// rho_S[a,b] = sum_E Psi[a,E] conj(Psi[b,E])   (one thread per (a,b); ordered serial sum)
__global__ void kRhoS(const double* psre,const double* psim,int d,long long envN,double* rre,double* rim){
    int t=blockIdx.x*blockDim.x+threadIdx.x; if(t>=d*d) return; int a=t/d,b=t%d;
    const double* par=psre+(long long)a*envN; const double* pai=psim+(long long)a*envN;
    const double* pbr=psre+(long long)b*envN; const double* pbi=psim+(long long)b*envN;
    double sre=0.0,sim=0.0;
    for(long long E=0;E<envN;E++){ double ar=par[E],ai=pai[E],br=pbr[E],bi=pbi[E];
        sre+=ar*br+ai*bi; sim+=ai*br-ar*bi; }              // a*conj(b)
    rre[t]=sre; rim[t]=sim;
}
// overlap[i,a] = <r_i^{(x)R}|Psi_a> = sum_E (prod_k r[i][e_k]) Psi[a,E]   (num_i = sum_a |overlap[i,a]|^2)
__global__ void kOverlap(const double* psre,const double* psim,const double* r,int d,int R,long long envN,
                         double* ovre,double* ovim){
    int t=blockIdx.x*blockDim.x+threadIdx.x; if(t>=d*d) return; int i=t/d,a=t%d;
    const double* par=psre+(long long)a*envN; const double* pai=psim+(long long)a*envN;
    double sre=0.0,sim=0.0;
    for(long long E=0;E<envN;E++){ double pf=1.0; long long e=E;
        for(int k=0;k<R;k++){ int ek=(int)(e%d); e/=d; pf*=r[i*d+ek]; }
        sre+=pf*par[E]; sim+=pf*pai[E]; }
    ovre[t]=sre; ovim[t]=sim;
}

// ---------------------------------------------------------------- cuSOLVER (complex-Hermitian; extends algebra)
static cusolverDnHandle_t g_solver=nullptr;
static void ensure_solver(){ if(!g_solver) SOLVER_OK(cusolverDnCreate(&g_solver)); }
static void zheevd_evals(int n,cuDoubleComplex* dA,double* dW){   // eigenvalues of Hermitian dA (ascending)
    ensure_solver();
    int lwork=0; SOLVER_OK(cusolverDnZheevd_bufferSize(g_solver,CUSOLVER_EIG_MODE_NOVECTOR,CUBLAS_FILL_MODE_LOWER,n,dA,n,dW,&lwork));
    cuDoubleComplex* work=nullptr; int* info=nullptr; CUDA_OK(cudaMalloc(&work,(size_t)lwork*sizeof(cuDoubleComplex))); CUDA_OK(cudaMalloc(&info,sizeof(int)));
    SOLVER_OK(cusolverDnZheevd(g_solver,CUSOLVER_EIG_MODE_NOVECTOR,CUBLAS_FILL_MODE_LOWER,n,dA,n,dW,work,lwork,info));
    int hinfo=0; CUDA_OK(cudaMemcpy(&hinfo,info,sizeof(int),cudaMemcpyDeviceToHost)); if(hinfo!=0){ fprintf(stderr,"cuSOLVER zheevd info=%d\n",hinfo); std::exit(2); }
    cudaFree(work); cudaFree(info);
}

// ---------------------------------------------------------------- host: records, fine-graining, envariance
static void cholesky_records(int d,double s,std::vector<double>& r){   // r[i*d+e] = L[i][e], <r_i|r_j>=G_ij
    std::vector<double> L((size_t)d*d,0.0);
    for(int i=0;i<d;i++) for(int j=0;j<=i;j++){
        double sum=(i==j)?1.0:s; for(int k=0;k<j;k++) sum-=L[i*d+k]*L[j*d+k];
        if(i==j) L[i*d+j]=sqrt(sum>0.0?sum:0.0); else L[i*d+j]=sum/L[j*d+j];
    }
    r.assign((size_t)d*d,0.0); for(int i=0;i<d;i++) for(int e=0;e<d;e++) r[i*d+e]=L[i*d+e];
}
static void finegrain(const std::vector<int>& w,const std::vector<double>& cre,const std::vector<double>& cim,
                      int M,double& unit_dev,double& flat_dev){
    int d=(int)w.size();
    std::vector<std::vector<double>> cols;
    int off=0; for(int i=0;i<d;i++){ std::vector<double> col(M,0.0); for(int k=0;k<w[i];k++) col[off+k]=1.0/sqrt((double)w[i]); cols.push_back(col); off+=w[i]; }
    for(int j=0;j<M && (int)cols.size()<M;j++){ std::vector<double> v(M,0.0); v[j]=1.0;
        for(auto& u:cols){ double ip=0; for(int k=0;k<M;k++) ip+=u[k]*v[k]; for(int k=0;k<M;k++) v[k]-=ip*u[k]; }
        double nv=0; for(int k=0;k<M;k++) nv+=v[k]*v[k]; nv=sqrt(nv);
        if(nv>1e-9){ for(int k=0;k<M;k++) v[k]/=nv; cols.push_back(v); } }
    unit_dev=0.0; int nc=(int)cols.size();
    for(int i=0;i<nc;i++) for(int j=0;j<nc;j++){ double ip=0; for(int k=0;k<M;k++) ip+=cols[i][k]*cols[j][k]; double t=(i==j)?1.0:0.0; unit_dev=std::max(unit_dev,fabs(ip-t)); }
    flat_dev=0.0; double target=1.0/sqrt((double)M);
    for(int mu=0;mu<M;mu++){ double fre=0,fim=0; for(int i=0;i<d;i++){ fre+=cols[i][mu]*cre[i]; fim+=cols[i][mu]*cim[i]; }
        double mag=sqrt(fre*fre+fim*fim); if(mag>1e-12) flat_dev=std::max(flat_dev,fabs(mag-target)); }
}
static double env_residual(double a,double b,double phase){   // STEP A: ||CSWAP_E SWAP_S |psi> - |psi>||
    using cd=std::complex<double>; cd ph(cos(phase),sin(phase));
    cd psi[4]={cd(a,0),cd(0,0),cd(0,0),b*ph};
    cd s[4]={psi[2],psi[3],psi[0],psi[1]};                    // SWAP_S: 0<->2, 1<->3
    cd out[4]={std::conj(ph)*s[1], ph*s[0], std::conj(ph)*s[3], ph*s[2]};   // CSWAP_E carrying the phase back
    double r=0; for(int k=0;k<4;k++) r+=std::norm(out[k]-psi[k]); return sqrt(r);
}

// ---------------------------------------------------------------- params / result
struct Params {
    std::vector<int> weights={2,3}; int branches=2; bool branches_set=false;
    int redundancy=6; int regime=0;            // 0=full, 1=partial
    double overlap=0.0, phase=0.0, tol=1e-4, coh_tol=1e-6;
    long long seed=0; bool seed_set=false;
    bool json=false, csv=false, selftest=false, golden=false; std::string csv_path;
};
struct Result {
    int total_M=0;
    double born_max_dev=0, oracle_max_dev=0, rho_purity=0, offdiag_max=0;
    double microbranch_flat_dev=0, unitarity_dev=0, envariance_residual=0, envariance_break=0;
    double flat_dev=0, objectivity_dev=0; bool born_reproduced=false;
    bool g_born=false, g_nd=false; double gb_val=0,gb_thr=0,gn_val=0,gn_thr=0;
    std::vector<double> trace_w, born_w;
};

static void run_traceborn(const Params& P, Result& R, std::vector<std::string>* csv){
    int d=(int)P.weights.size(); int Rn=P.redundancy;
    double s=(P.regime==0)?0.0:P.overlap;
    int M=0; for(int w:P.weights) M+=w; R.total_M=M;
    // amplitudes c_i = sqrt(w_i/M) e^{i*i*phase}
    std::vector<double> cre(d),cim(d),born(d);
    for(int i=0;i<d;i++){ double mag=sqrt((double)P.weights[i]/(double)M); double ang=i*P.phase;
        cre[i]=mag*cos(ang); cim[i]=mag*sin(ang); born[i]=mag*mag; }
    // records via Cholesky of G=(1-s)I+sJ
    std::vector<double> r; cholesky_records(d,s,r);
    long long envN=1; for(int k=0;k<Rn;k++) envN*=d; long long total=envN*(long long)d;
    // ---- device: build state, partial trace, projector overlaps ----
    double *dr,*dcre,*dcim,*psre,*psim,*drre,*drim,*dovre,*dovim;
    CUDA_OK(cudaMalloc(&dr,(size_t)d*d*sizeof(double)));   CUDA_OK(cudaMalloc(&dcre,(size_t)d*sizeof(double))); CUDA_OK(cudaMalloc(&dcim,(size_t)d*sizeof(double)));
    CUDA_OK(cudaMalloc(&psre,(size_t)total*sizeof(double))); CUDA_OK(cudaMalloc(&psim,(size_t)total*sizeof(double)));
    CUDA_OK(cudaMalloc(&drre,(size_t)d*d*sizeof(double)));  CUDA_OK(cudaMalloc(&drim,(size_t)d*d*sizeof(double)));
    CUDA_OK(cudaMalloc(&dovre,(size_t)d*d*sizeof(double))); CUDA_OK(cudaMalloc(&dovim,(size_t)d*d*sizeof(double)));
    CUDA_OK(cudaMemcpy(dr,r.data(),(size_t)d*d*sizeof(double),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(dcre,cre.data(),(size_t)d*sizeof(double),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy(dcim,cim.data(),(size_t)d*sizeof(double),cudaMemcpyHostToDevice));
    int bs=256; long long gs=(total+bs-1)/bs;
    kBuildState<<<(unsigned)gs,bs>>>(dr,dcre,dcim,d,Rn,envN,psre,psim); CUDA_OK(cudaGetLastError());
    kRhoS<<<1,d*d>>>(psre,psim,d,envN,drre,drim); CUDA_OK(cudaGetLastError());
    kOverlap<<<1,d*d>>>(psre,psim,dr,d,Rn,envN,dovre,dovim); CUDA_OK(cudaGetLastError());
    std::vector<double> hrre(d*d),hrim(d*d),hovre(d*d),hovim(d*d);
    CUDA_OK(cudaMemcpy(hrre.data(),drre,(size_t)d*d*sizeof(double),cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(hrim.data(),drim,(size_t)d*d*sizeof(double),cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(hovre.data(),dovre,(size_t)d*d*sizeof(double),cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(hovim.data(),dovim,(size_t)d*d*sizeof(double),cudaMemcpyDeviceToHost));
    // ---- brute-force trace weights (headline) ----
    std::vector<double> num(d,0.0); double numsum=0.0;
    for(int i=0;i<d;i++){ double acc=0.0; for(int a=0;a<d;a++){ double re=hovre[i*d+a],im=hovim[i*d+a]; acc+=re*re+im*im; } num[i]=acc; numsum+=acc; }
    std::vector<double> wtr(d); for(int i=0;i<d;i++) wtr[i]=num[i]/numsum;
    R.born_max_dev=0.0; for(int i=0;i<d;i++) R.born_max_dev=std::max(R.born_max_dev,fabs(wtr[i]-born[i]));
    // ---- analytic Gram oracle (I-11): num_i = sum_a |c_a|^2 (G_ia)^{2R} ; single-fragment: (G_ia)^2 ----
    auto Gij=[&](int i,int j){ return (i==j)?1.0:s; };
    std::vector<double> numA(d,0.0),num1(d,0.0); double numAsum=0.0,num1sum=0.0;
    for(int i=0;i<d;i++){ double aA=0,a1=0; for(int a=0;a<d;a++){ double g=Gij(i,a); double g2R=pow(g,2.0*Rn); double g2=g*g; aA+=born[a]*g2R; a1+=born[a]*g2; } numA[i]=aA; num1[i]=a1; numAsum+=aA; num1sum+=a1; }
    R.oracle_max_dev=0.0; R.objectivity_dev=0.0;
    for(int i=0;i<d;i++){ double wA=numA[i]/numAsum, w1=num1[i]/num1sum; R.oracle_max_dev=std::max(R.oracle_max_dev,fabs(wtr[i]-wA)); R.objectivity_dev=std::max(R.objectivity_dev,fabs(wtr[i]-w1)); }
    // ---- offdiag coherence remnant ----
    R.offdiag_max=0.0; for(int a=0;a<d;a++) for(int b=0;b<d;b++) if(a!=b){ double m=sqrt(hrre[a*d+b]*hrre[a*d+b]+hrim[a*d+b]*hrim[a*d+b]); R.offdiag_max=std::max(R.offdiag_max,m); }
    // ---- purity via cuSOLVER Zheevd on rho_S ----
    std::vector<cuDoubleComplex> hrho(d*d); for(int a=0;a<d;a++) for(int b=0;b<d;b++) hrho[a+(size_t)b*d]=make_cuDoubleComplex(hrre[a*d+b],hrim[a*d+b]); // col-major
    cuDoubleComplex* dRho=nullptr; double* dW=nullptr; CUDA_OK(cudaMalloc(&dRho,(size_t)d*d*sizeof(cuDoubleComplex))); CUDA_OK(cudaMalloc(&dW,(size_t)d*sizeof(double)));
    CUDA_OK(cudaMemcpy(dRho,hrho.data(),(size_t)d*d*sizeof(cuDoubleComplex),cudaMemcpyHostToDevice));
    zheevd_evals(d,dRho,dW); std::vector<double> ev(d); CUDA_OK(cudaMemcpy(ev.data(),dW,(size_t)d*sizeof(double),cudaMemcpyDeviceToHost));
    std::sort(ev.begin(),ev.end()); R.rho_purity=0.0; for(double l:ev) R.rho_purity+=l*l;
    cudaFree(dRho); cudaFree(dW);
    cudaFree(dr);cudaFree(dcre);cudaFree(dcim);cudaFree(psre);cudaFree(psim);cudaFree(drre);cudaFree(drim);cudaFree(dovre);cudaFree(dovim);
    // ---- fine-graining (STEP B), envariance (STEP A), democratic control ----
    finegrain(P.weights,cre,cim,M,R.unitarity_dev,R.microbranch_flat_dev);
    R.envariance_residual=env_residual(1.0/sqrt(2.0),1.0/sqrt(2.0),P.phase);
    { double m0=sqrt((double)P.weights[0]/(double)(P.weights[0]+P.weights[1]));
      double m1=sqrt((double)P.weights[1]/(double)(P.weights[0]+P.weights[1]));
      R.envariance_break=env_residual(m0,m1,P.phase); }
    R.flat_dev=0.0; for(int i=0;i<d;i++) R.flat_dev=std::max(R.flat_dev,fabs(1.0/(double)d-born[i]));
    // ---- gates / verdict ----
    R.gb_thr=P.tol; R.gb_val=R.born_max_dev; R.g_born=(R.born_max_dev>P.tol);
    R.gn_thr=P.coh_tol; R.gn_val=R.offdiag_max; R.g_nd=(R.offdiag_max>P.coh_tol);
    R.born_reproduced=(R.born_max_dev<=P.tol)&&(R.offdiag_max<=P.coh_tol);
    R.trace_w=wtr; R.born_w=born;
    if(csv){ for(int i=0;i<d;i++){ char b[160]; snprintf(b,sizeof(b),"%d,%s,%s,%s",i,fmt6(born[i]).c_str(),fmt6(wtr[i]).c_str(),fmt6(fabs(wtr[i]-born[i])).c_str()); csv->push_back(std::string(b)); } }
}

// ---------------------------------------------------------------- serialize
static const char* REG[2]={"full","partial"};
static std::string iarr(const std::vector<int>& v){ std::string s="["; for(size_t i=0;i<v.size();i++){ if(i) s+=","; s+=fmti(v[i]); } return s+"]"; }
static std::string params_json(const Params& P){
    int d=(int)P.weights.size(); double s=(P.regime==0)?0.0:P.overlap;
    return "{\"branches\":"+fmti(d)+",\"weights\":"+iarr(P.weights)+",\"redundancy\":"+fmti(P.redundancy)
         + ",\"regime\":\""+REG[P.regime]+"\",\"overlap\":"+fmt6(s)+",\"phase\":"+fmt6(P.phase)
         + ",\"tol\":"+fmt6(P.tol)+",\"coh_tol\":"+fmt6(P.coh_tol)+"}";
}
static std::string result_json(const Params& P,const Result& R){
    int d=(int)P.weights.size(); double s=(P.regime==0)?0.0:P.overlap;
    return "{\"branches\":"+fmti(d)+",\"weights\":"+iarr(P.weights)+",\"total_M\":"+fmti(R.total_M)
         + ",\"redundancy\":"+fmti(P.redundancy)+",\"regime\":\""+REG[P.regime]+"\",\"overlap\":"+fmt6(s)
         + ",\"born_max_dev\":"+fmt6(R.born_max_dev)+",\"oracle_max_dev\":"+fmt6(R.oracle_max_dev)
         + ",\"rho_purity\":"+fmt6(R.rho_purity)+",\"offdiag_max\":"+fmt6(R.offdiag_max)
         + ",\"microbranch_flat_dev\":"+fmt6(R.microbranch_flat_dev)+",\"unitarity_dev\":"+fmt6(R.unitarity_dev)
         + ",\"envariance_residual\":"+fmt6(R.envariance_residual)+",\"envariance_break\":"+fmt6(R.envariance_break)
         + ",\"flat_dev\":"+fmt6(R.flat_dev)+",\"objectivity_dev\":"+fmt6(R.objectivity_dev)
         + ",\"born_reproduced\":"+std::string(R.born_reproduced?"true":"false")+"}";
}
static std::string gates_json(const Result& R){
    return "[{\"id\":\"G-BORN-MISMATCH\",\"fired\":"+std::string(R.g_born?"true":"false")+",\"value\":"+fmt6(R.gb_val)+",\"threshold\":"+fmt6(R.gb_thr)+"},"
           "{\"id\":\"G-NOT-DECOHERED\",\"fired\":"+std::string(R.g_nd?"true":"false")+",\"value\":"+fmt6(R.gn_val)+",\"threshold\":"+fmt6(R.gn_thr)+"}]";
}
static std::string declared_body(const Params& P,const Result& R,const std::string& v){
    return "\"seed\":"+fmti(P.seed)+",\"params\":"+params_json(P)+",\"result\":"+result_json(P,R)+",\"gates\":"+gates_json(R)+",\"verdict\":\""+v+"\""; }
static std::string declared_object(const Params& P,const Result& R,const std::string& v){ return "{"+declared_body(P,R,v)+"}"; }
static std::string full_envelope(const Params& P,const Result& R,const std::string& v){
    return orrery::full_envelope("trace-born", TRACEBORN_VERSION, declared_body(P,R,v), FIREWALL); }

static int run_config(const Params& P,bool do_print,std::string* declared_out){
    std::vector<std::string> csv; std::vector<std::string>* csvp=(do_print&&P.csv)?&csv:nullptr;
    Result R; run_traceborn(P,R,csvp); std::string verdict=(R.g_born||R.g_nd)?"fail":"pass";
    if(declared_out) *declared_out=declared_object(P,R,verdict);
    if(do_print){ if(csvp){ FILE* f=fopen(P.csv_path.c_str(),"wb"); if(!f){ fprintf(stderr,"error: cannot open --csv: %s\n",P.csv_path.c_str()); std::exit(2);}
            fprintf(f,"branch,born_weight,trace_weight,dev\n"); for(auto& row:csv) fprintf(f,"%s\n",row.c_str()); fclose(f); }
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str()); }
    if(R.oracle_max_dev>ORACLE_TOL){ fprintf(stderr,"SUSPECT: brute force disagrees with analytic oracle (oracle_max_dev=%.3e > %.0e) -- the tool is wrong, not the physics (I-11)\n",R.oracle_max_dev,ORACLE_TOL); return 2; }
    return (R.g_born||R.g_nd)?1:0;
}

// ---------------------------------------------------------------- golden / selftest
static Params golden_params(){ Params P; P.weights={2,3}; P.branches=2; P.redundancy=6; P.regime=0; P.overlap=0.0; P.phase=0.0; P.tol=1e-4; P.coh_tol=1e-6; P.seed=0; P.seed_set=true; P.json=true; return P; }
static int run_golden(){ Params P=golden_params(); Result R; run_traceborn(P,R,nullptr); std::string v=(R.g_born||R.g_nd)?"fail":"pass";
    return golden_check("trace-born", declared_object(P,R,v), full_envelope(P,R,v)); }

static bool st(const char* n,bool ok){ return st_check(n,ok); }
static int run_selftest(){
    bool ok=true; fprintf(stderr,"trace-born --selftest (v%s)\n",TRACEBORN_VERSION);
    ok &= st("blake2b-256(\"abc\") KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // analytic 2-branch oracle (the receipt): weights 2,3 full -> Born [0.4,0.6]
    { Params P=golden_params(); Result R; run_traceborn(P,R,nullptr);
      ok &= st("golden Born reproduced (born_max_dev<1e-9)", R.born_max_dev<1e-9);
      ok &= st("golden trace weights == [0.4,0.6] (receipt)", fabs(R.trace_w[0]-0.4)<1e-9 && fabs(R.trace_w[1]-0.6)<1e-9);
      ok &= st("golden brute==analytic oracle (oracle_max_dev<1e-10)", R.oracle_max_dev<1e-10);
      ok &= st("golden purity == 0.52 = Sum|c_i|^4 (cuSOLVER Zheevd)", fabs(R.rho_purity-0.52)<1e-6);
      ok &= st("golden fully decohered (offdiag_max<1e-12)", R.offdiag_max<1e-12);
      ok &= st("golden fine-graining flat (microbranch_flat_dev<1e-10, unitarity<1e-10)", R.microbranch_flat_dev<1e-10 && R.unitarity_dev<1e-10);
      ok &= st("golden envariance residual ~0 (equal moduli remotely erasable)", R.envariance_residual<1e-12);
      ok &= st("golden envariance break >0 (unequal moduli NOT erasable)", R.envariance_break>0.19 && R.envariance_break<0.21);
      ok &= st("golden verdict pass (no gate) + born_reproduced", !R.g_born && !R.g_nd && R.born_reproduced); }
    // complex-Hermitian path: d=3 weights 1,2,3 R=4 phase=0.5 -> brute==analytic, Born reproduced
    { Params P; P.weights={1,2,3}; P.redundancy=4; P.regime=0; P.phase=0.5; P.tol=1e-4; P.coh_tol=1e-6; P.seed_set=true; Result R; run_traceborn(P,R,nullptr);
      ok &= st("complex d=3 Born reproduced + oracle agrees (<1e-9)", R.born_max_dev<1e-9 && R.oracle_max_dev<1e-9); }
    // NEGATIVE CONTROL: partial decoherence s=0.5, R=2 -> BOTH gates fire
    { Params P; P.weights={2,3}; P.redundancy=2; P.regime=1; P.overlap=0.5; P.tol=1e-4; P.coh_tol=1e-6; P.seed_set=true; Result R; run_traceborn(P,R,nullptr);
      ok &= st("partial control: G-BORN-MISMATCH fires (born_max_dev>tol)", R.g_born && R.born_max_dev>1e-4);
      ok &= st("partial control: G-NOT-DECOHERED fires (offdiag_max>coh_tol)", R.g_nd && R.offdiag_max>1e-6);
      ok &= st("partial control: brute STILL == analytic oracle (<1e-9)", R.oracle_max_dev<1e-9);
      ok &= st("partial control: objectivity_dev>0 (single fragment disagrees with full)", R.objectivity_dev>1e-4); }
    // determinism
    { Params P=golden_params(); std::string a,b; run_config(P,false,&a); run_config(P,false,&b); ok &= st("declared object identical across two runs", a==b); }
    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n"); return ok?0:1;
}

// ---------------------------------------------------------------- CLI
int main(int argc,char** argv){
    Params P;
    for(int i=1;i<argc;i++){ std::string a=argv[i];
        auto val=[&](const char* f)->const char*{ if(i+1>=argc) die2(std::string("missing value for ")+f); return argv[++i]; };
        if(a=="--weights"){ std::string w=val("--weights"); P.weights.clear(); std::string cur;
            for(char ch:w){ if(ch==','){ if(!cur.empty()){ P.weights.push_back((int)parse_ll(cur.c_str(),"--weights")); cur.clear(); } } else cur+=ch; }
            if(!cur.empty()) P.weights.push_back((int)parse_ll(cur.c_str(),"--weights")); }
        else if(a=="--branches"){ P.branches=(int)parse_ll(val("--branches"),"--branches"); P.branches_set=true; }
        else if(a=="--redundancy") P.redundancy=(int)parse_ll(val("--redundancy"),"--redundancy");
        else if(a=="--regime"){ std::string r=val("--regime"); if(r=="full")P.regime=0; else if(r=="partial")P.regime=1; else die2("bad --regime (full|partial): "+r); }
        else if(a=="--overlap") P.overlap=parse_d(val("--overlap"),"--overlap");
        else if(a=="--phase") P.phase=parse_d(val("--phase"),"--phase");
        else if(a=="--tol") P.tol=parse_d(val("--tol"),"--tol");
        else if(a=="--coh-tol") P.coh_tol=parse_d(val("--coh-tol"),"--coh-tol");
        else if(a=="--seed"){ P.seed=parse_ll(val("--seed"),"--seed"); P.seed_set=true; }
        else if(a=="--json") P.json=true;
        else if(a=="--csv"){ P.csv=true; P.csv_path=val("--csv"); }
        else if(a=="--selftest") P.selftest=true;
        else if(a=="--golden") P.golden=true;
        else die2("unknown flag: "+a);
    }
    if(P.selftest) return run_selftest();
    if(P.golden)   return run_golden();
    // validation
    int d=(int)P.weights.size();
    if(d<2||d>8) die2("--weights must list 2..8 branches");
    if(P.branches_set && P.branches!=d) die2("--branches != number of --weights");
    int M=0; for(int w:P.weights){ if(w<1) die2("--weights entries must be >=1"); M+=w; }
    if(M>512) die2("total weight M=Sum(weights) exceeds v1.0.0 fine-graining cap 512");
    if(P.redundancy<1||P.redundancy>24) die2("--redundancy out of range [1,24]");
    if(P.regime!=0&&P.regime!=1) die2("bad regime");
    if(P.overlap<0.0||P.overlap>0.99) die2("--overlap out of range [0,0.99]");
    if(P.phase<0.0||P.phase>=6.283185307179587) die2("--phase out of range [0,2pi)");
    if(P.tol<0.0||P.tol>1.0) die2("--tol out of range [0,1]");
    if(P.coh_tol<0.0||P.coh_tol>1.0) die2("--coh-tol out of range [0,1]");
    if(P.seed<0) die2("--seed must be >=0");
    // state-size guard d^(R+1) <= 2^26
    { long long envN=1; for(int k=0;k<P.redundancy;k++){ envN*=d; if(envN>(1LL<<26)) die2("state too large: d^R exceeds 2^26 -- reduce --redundancy/--branches (v1.0.0)"); }
      if(envN*(long long)d>(1LL<<26)) die2("state too large: d^(R+1) exceeds 2^26 -- reduce --redundancy/--branches (v1.0.0)"); }
    if(!P.json && !P.csv) P.json=true;
    return run_config(P,true,nullptr);
}
