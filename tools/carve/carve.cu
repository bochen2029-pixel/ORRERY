// carve.cu -- ORRERY tool `carve` (v1.0.0). Preferred-factorization basin search (D-026 gear #3).
// Contract: contracts/carve.contract.md v1.0.0 (authoritative). Design: runs/carve_design/ (D-034).
//
// Does a fixed Hamiltonian H on N qubits pick out a preferred tensor-product structure? Score a
// candidate frame U by the k-locality Pauli-weight concentration of U†HU, reported as a GAP over the
// analytic Haar baseline B(N,k); search the discrete gate frame (greedy basin descent) for the max gap.
// Oracle (I-11): the `planted` mode H=V H0 V† carries a KNOWN answer U*=V (un-scramble V†HV=H0), checked
// exactly (oracle_dev) + as a search-recovery target. `haar` = random control (no preferred factorization).
//
// Host-only C++ on liborrery (D-020). Static computation only (no matrix-exp / no dynamics -> determinism).
// Measures STRUCTURE, never acquaintance (qualia). III-sealed.
//
// Build (from tools/carve/):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 carve.cu ../../lib/envelope.cpp -o carve.exe'
#include "../../lib/envelope.h"
#include <complex>
#include <vector>
#include <string>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <algorithm>

using orrery::fmt6; using orrery::fmti; using orrery::die2; using orrery::parse_ll;
using orrery::parse_d; using orrery::st_check; using orrery::declared_object;
using orrery::full_envelope; using orrery::golden_check; using orrery::blake2b_hex;

typedef std::complex<double> cd;
static const char* VERSION = "1.0.0";
static const char* FIREWALL =
  "This measures a structural fact: whether a fixed Hamiltonian prefers a tensor-product factorization "
  "(k-locality concentration gap over the Haar baseline), with a planted-scrambler known-answer oracle. "
  "It says nothing about why any subsystem is experienced - structure, never acquaintance (qualia). III-sealed.";

// ------------------------------------------------------------------- counter RNG (D-012, host)
static inline uint64_t splitmix64(uint64_t x){
    x += 0x9E3779B97F4A7C15ULL;
    uint64_t z = x;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}
static inline uint64_t ckey(uint64_t seed, uint64_t purpose, uint64_t idx){
    return splitmix64(seed*0x100000001B3ULL ^ splitmix64(purpose*0x9E3779B1ULL ^ idx));
}
static inline double u01(uint64_t r){ return (double)((r >> 11) * (1.0/9007199254740992.0)); }
static inline double cgauss(uint64_t seed, uint64_t purpose, uint64_t idx){
    double u1 = u01(ckey(seed,purpose,2*idx)), u2 = u01(ckey(seed,purpose,2*idx+1));
    if(u1 < 1e-300) u1 = 1e-300;
    return std::sqrt(-2.0*std::log(u1)) * std::cos(6.283185307179586*u2);
}

// ------------------------------------------------------------------- dense complex linear algebra
struct Mat { int d; std::vector<cd> a; Mat(int d_=0):d(d_),a((size_t)d_*d_,cd(0,0)){}
    cd& at(int i,int j){ return a[(size_t)i*d+j]; } cd at(int i,int j) const { return a[(size_t)i*d+j]; } };

static Mat matmul(const Mat& A, const Mat& B){
    int d=A.d; Mat C(d);
    for(int i=0;i<d;i++) for(int k=0;k<d;k++){ cd aik=A.at(i,k); if(aik==cd(0,0)) continue;
        for(int j=0;j<d;j++) C.at(i,j)+=aik*B.at(k,j); }
    return C;
}
static Mat dagger(const Mat& A){ int d=A.d; Mat B(d); for(int i=0;i<d;i++) for(int j=0;j<d;j++) B.at(i,j)=std::conj(A.at(j,i)); return B; }

// single-qubit 2x2 gate applied to identity-extended full operator (for building V as a matrix)
static void gate_1q_into(Mat& U, int q, const cd g[2][2]){
    int d=U.d; Mat R(d);
    for(int r=0;r<d;r++){ int b=(r>>q)&1; int r0=r&~(1<<q), r1=r|(1<<q);
        // (g_q U)_{r,c} = sum_b' g[b][b'] U_{r with qubit q=b', c}
        for(int c=0;c<d;c++) R.at(r,c)= g[b][0]*U.at(r0,c) + g[b][1]*U.at(r1,c);
    }
    U=R;
}
static void cnot_into(Mat& U, int ctrl, int tgt){
    int d=U.d; Mat R(d);
    for(int r=0;r<d;r++){ int rr = ((r>>ctrl)&1) ? (r ^ (1<<tgt)) : r;
        for(int c=0;c<d;c++) R.at(r,c)=U.at(rr,c); }
    U=R;
}

// ------------------------------------------------------------------- the gate alphabet (frames)
enum GType { G_H, G_S, G_SDG, G_CNOT };
struct Gate { GType t; int q0, q1; };
static void gate_matrix(GType t, cd g[2][2]){
    const double s=1.0/std::sqrt(2.0);
    if(t==G_H){ g[0][0]=s; g[0][1]=s; g[1][0]=s; g[1][1]=-s; }
    else if(t==G_S){ g[0][0]=1; g[0][1]=0; g[1][0]=0; g[1][1]=cd(0,1); }
    else /*SDG*/ { g[0][0]=1; g[0][1]=0; g[1][0]=0; g[1][1]=cd(0,-1); }
}
// conjugate M in place by a single gate: M <- g† M g  (frame accumulation; U†HU built incrementally)
static void conj_gate(Mat& M, const Gate& gt){
    int d=M.d;
    if(gt.t==G_CNOT){
        Mat R(d); int c=gt.q0, t=gt.q1;
        for(int i=0;i<d;i++){ int pi=((i>>c)&1)?(i^(1<<t)):i;
            for(int j=0;j<d;j++){ int pj=((j>>c)&1)?(j^(1<<t)):j; R.at(i,j)=M.at(pi,pj); } }
        M=R; return;
    }
    cd g[2][2]; gate_matrix(gt.t,g); int q=gt.q0;
    cd gd[2][2] = {{std::conj(g[0][0]),std::conj(g[1][0])},{std::conj(g[0][1]),std::conj(g[1][1])}};
    // left: L = g†_q M
    Mat L(d);
    for(int c=0;c<d;c++) for(int i0=0;i0<d;i0++){ if((i0>>q)&1) continue; int i1=i0|(1<<q);
        cd m0=M.at(i0,c), m1=M.at(i1,c);
        L.at(i0,c)=gd[0][0]*m0+gd[0][1]*m1; L.at(i1,c)=gd[1][0]*m0+gd[1][1]*m1; }
    // right: M' = L g_q
    for(int i=0;i<d;i++) for(int j0=0;j0<d;j0++){ if((j0>>q)&1) continue; int j1=j0|(1<<q);
        cd l0=L.at(i,j0), l1=L.at(i,j1);
        M.at(i,j0)=l0*g[0][0]+l1*g[1][0]; M.at(i,j1)=l0*g[0][1]+l1*g[1][1]; }
}

// ------------------------------------------------------------------- Pauli decomposition (precomputed)
struct PauliTab {
    int N, d, npauli; std::vector<int> sig;   // sig[a*d+m] = sigma(a,m)
    std::vector<cd> phi;                        // phi[a*d+m] = phase(a,m)
    std::vector<int> wt;                        // wt[a]
    void build(int N_){
        N=N_; d=1<<N; npauli=1<<(2*N);
        sig.assign((size_t)npauli*d,0); phi.assign((size_t)npauli*d,cd(1,0)); wt.assign(npauli,0);
        for(int a=0;a<npauli;a++){
            int w=0; for(int q=0;q<N;q++){ int dg=(a>>(2*q))&3; if(dg) w++; } wt[a]=w;
            for(int m=0;m<d;m++){ int s=m; cd ph(1,0);
                for(int q=0;q<N;q++){ int dg=(a>>(2*q))&3; int b=(m>>q)&1;
                    if(dg==1){ s^=(1<<q); }                          // X
                    else if(dg==2){ s^=(1<<q); ph*= (b==0)?cd(0,1):cd(0,-1); } // Y
                    else if(dg==3){ ph*= (b==0)?cd(1,0):cd(-1,0); }  // Z
                }
                sig[(size_t)a*d+m]=s; phi[(size_t)a*d+m]=ph;
            }
        }
    }
    // Phi_k(M) = sum_{0<wt<=k} c_a^2 / sum_{wt>0} c_a^2, c_a = Re Tr(P_a M)/2^N; tr = sum_m phi(a,m) M_{m,sigma(a,m)}
    double phi_k(const Mat& M, int k) const {
        double num=0, den=0;
        for(int a=1;a<npauli;a++){
            cd tr(0,0); const int* sg=&sig[(size_t)a*d]; const cd* ph=&phi[(size_t)a*d];
            for(int m=0;m<d;m++) tr += ph[m]*M.at(m,sg[m]);
            double r=tr.real(); double v=r*r; den+=v; if(wt[a]<=k) num+=v;
        }
        return (den>0)? num/den : 0.0;
    }
};

// analytic Haar baseline B(N,k) = sum_{w=1..k} C(N,w) 3^w / (4^N - 1)
static double haar_baseline(int N, int k){
    double num=0; long long C=1; // C(N,0)
    for(int w=1; w<=k; w++){ C = C*(N-w+1)/w; double p3=1; for(int i=0;i<w;i++) p3*=3.0; num += (double)C*p3; }
    double tot = std::pow(4.0,N)-1.0; return num/tot;
}

// ------------------------------------------------------------------- Hamiltonians
static Mat H_ising(int N, double g=1.0){
    int d=1<<N; Mat H(d);
    for(int x=0;x<d;x++){ double diag=0; for(int i=0;i+1<N;i++){ int zi=((x>>i)&1)?-1:1, zj=((x>>(i+1))&1)?-1:1; diag += -(double)(zi*zj); }
        H.at(x,x)=cd(diag,0); }
    for(int x=0;x<d;x++) for(int i=0;i<N;i++){ int y=x^(1<<i); H.at(x,y)+=cd(-g,0); } // -g X_i
    return H;
}
static Mat H_product(int N){ // H_A x I + I x H_B across the middle cut (both ising) -> exact tensor sum
    int nA=N/2, nB=N-nA, d=1<<N, dB=1<<nB; Mat H(d);
    Mat HA=H_ising(nA), HB=H_ising(nB);
    for(int x=0;x<d;x++){ int xa=x>>nB, xb=x&(dB-1);
        for(int ya=0;ya<(1<<nA);ya++){ cd v=HA.at(xa,ya); if(v!=cd(0,0)) H.at(x,(ya<<nB)|xb)+=v; }
        for(int yb=0;yb<dB;yb++){ cd v=HB.at(xb,yb); if(v!=cd(0,0)) H.at(x,(xa<<nB)|yb)+=v; }
    }
    return H;
}
static Mat H_haar(int N, uint64_t seed){ // GUE: (A+A†)/2, A complex Gaussian
    int d=1<<N; Mat A(d);
    uint64_t idx=0;
    for(int i=0;i<d;i++) for(int j=0;j<d;j++){ A.at(i,j)=cd(cgauss(seed,101,idx),cgauss(seed,102,idx)); idx++; }
    Mat H(d); for(int i=0;i<d;i++) for(int j=0;j<d;j++) H.at(i,j)=0.5*(A.at(i,j)+std::conj(A.at(j,i)));
    return H;
}
// build the planted scrambler V (a matrix) as a fixed pseudo-random circuit of self-inverse gates {H,CNOT}
static Mat build_V(int N, int depth, uint64_t seed, std::vector<Gate>* glist=nullptr){
    int d=1<<N; Mat V(d); for(int i=0;i<d;i++) V.at(i,i)=cd(1,0);
    uint64_t idx=0;
    for(int layer=0; layer<depth; layer++){
        for(int q=0;q<N;q++){ if(u01(ckey(seed,201,idx++))<0.5){ cd g[2][2]; gate_matrix(G_H,g); gate_1q_into(V,q,g); if(glist) glist->push_back({G_H,q,0}); } }
        for(int q=0;q+1<N;q++){ if(u01(ckey(seed,202,idx++))<0.5){ cnot_into(V,q,q+1); if(glist) glist->push_back({G_CNOT,q,q+1}); } }
    }
    return V;
}

// ------------------------------------------------------------------- greedy basin descent (frame search)
struct SearchOut { double phi_best; int frames; };
static SearchOut greedy_search(const Mat& H, const PauliTab& pt, int N, int k, int search_depth, int budget){
    Mat M=H; double best=pt.phi_k(M,k); int frames=1;
    // alphabet: H,S,SDG on each qubit; CNOT on adjacent pairs (both orders)
    std::vector<Gate> alpha;
    for(int q=0;q<N;q++){ alpha.push_back({G_H,q,0}); alpha.push_back({G_S,q,0}); alpha.push_back({G_SDG,q,0}); }
    for(int q=0;q+1<N;q++){ alpha.push_back({G_CNOT,q,q+1}); alpha.push_back({G_CNOT,q+1,q}); }
    for(int step=0; step<search_depth; step++){
        double bestimp=0; int bi=-1;
        for(int gi=0; gi<(int)alpha.size(); gi++){
            if(frames>=budget) break;
            Mat T=M; conj_gate(T,alpha[gi]); double p=pt.phi_k(T,k); frames++;
            if(p > best + bestimp + 1e-12){ bestimp = p - best; bi = gi; }
        }
        if(bi<0 || bestimp<=1e-9) break;
        conj_gate(M,alpha[bi]); best += bestimp;
        if(frames>=budget) break;
    }
    return {best, frames};
}

// ------------------------------------------------------------------- one full measurement
struct Result {
    int N,k; std::string ham; double haar_b, phi_id, phi_best, best_gap, phi_planted, planted_gap;
    int recovered; double oracle_dev; int frames, multi;
    std::vector<double> n_trend;
};
static double measure_gap(int N, int k, const std::string& ham, int sdepth, int search_depth, int budget,
                          uint64_t seed, PauliTab& pt, double* phi_id_out=nullptr, double* phi_best_out=nullptr,
                          double* phi_planted_out=nullptr, double* oracle_dev_out=nullptr, int* frames_out=nullptr){
    pt.build(N);
    Mat H, H0, V;
    if(ham=="ising") H=H_ising(N);
    else if(ham=="product") H=H_product(N);
    else if(ham=="haar") H=H_haar(N,seed);
    else { H0=H_ising(N); V=build_V(N,sdepth,seed); H=matmul(matmul(V,H0),dagger(V)); }
    double B=haar_baseline(N,k);
    double phi_id=pt.phi_k(H,k);
    SearchOut so=greedy_search(H,pt,N,k,search_depth,budget);
    if(phi_id_out)*phi_id_out=phi_id; if(phi_best_out)*phi_best_out=so.phi_best; if(frames_out)*frames_out=so.frames;
    if(ham=="planted"){
        Mat un=matmul(matmul(dagger(V),H),V);          // V†HV should equal H0
        double phi_pl=pt.phi_k(un,k); double phi_h0=pt.phi_k(H0,k);
        if(phi_planted_out)*phi_planted_out=phi_pl;
        if(oracle_dev_out)*oracle_dev_out=std::fabs(phi_pl-phi_h0);
    } else { if(phi_planted_out)*phi_planted_out=0.0; if(oracle_dev_out)*oracle_dev_out=0.0; }
    return so.phi_best - B;
}

static Result run_measure(int N,int k,const std::string& ham,int sdepth,int search_depth,int budget,
                          double recover_tol,uint64_t seed){
    Result R; R.N=N; R.k=k; R.ham=ham; R.haar_b=haar_baseline(N,k);
    PauliTab pt;
    R.best_gap = measure_gap(N,k,ham,sdepth,search_depth,budget,seed,pt,&R.phi_id,&R.phi_best,&R.phi_planted,&R.oracle_dev,&R.frames);
    R.planted_gap = (ham=="planted")? (R.phi_planted - R.haar_b) : 0.0;
    R.recovered = (ham=="planted" && std::fabs(R.phi_best - R.phi_planted)<=recover_tol)?1:0;
    // multi-basin (v1 coarse): restart greedy from a few seeded random frames; count distinct top gaps
    R.multi=1;
    { std::vector<double> tops; tops.push_back(R.best_gap);
      for(int rs=0; rs<3; rs++){
          PauliTab p2; p2.build(N);
          Mat H;
          if(ham=="ising")H=H_ising(N); else if(ham=="product")H=H_product(N);
          else if(ham=="haar")H=H_haar(N,seed); else { Mat H0=H_ising(N),V=build_V(N,sdepth,seed); H=matmul(matmul(V,H0),dagger(V)); }
          // seeded random start frame
          std::vector<Gate> st; uint64_t idx=0;
          for(int L=0;L<2;L++){ for(int q=0;q<N;q++) if(u01(ckey(seed,900+rs,idx++))<0.5){ st.push_back({G_H,q,0}); }
                                for(int q=0;q+1<N;q++) if(u01(ckey(seed,910+rs,idx++))<0.5) st.push_back({G_CNOT,q,q+1}); }
          Mat M=H; for(auto&gt:st) conj_gate(M,gt);
          SearchOut so=greedy_search(M,p2,N,k,search_depth,budget); double gp=so.phi_best - R.haar_b;
          bool distinct = (gp > R.best_gap - 1e-9) && (std::fabs(gp - R.best_gap) > 1e-6) ;
          if(distinct){ bool seen=false; for(double t:tops) if(std::fabs(t-gp)<1e-6) seen=true; if(!seen) tops.push_back(gp); }
      }
      R.multi=(int)tops.size();
    }
    // n-trend: best_gap at N'=2..N (same family/k)
    for(int Np=2; Np<=N; Np++){ int kk = std::min(k, Np-1); PauliTab p3; double g=measure_gap(Np,kk,ham,sdepth,search_depth,budget,seed,p3); R.n_trend.push_back(g); }
    return R;
}

// ------------------------------------------------------------------- declared object / gates / envelope
struct Gates { bool no_basin, multi_basin; double best_gap, multi_val, tol; };
static std::string params_json(int N,int k,const std::string& ham,int sd,int srd,int bud,double tol,double meps,double rtol,double otol){
    std::string s="{"; s+="\"qubits\":"+fmti(N)+",\"k\":"+fmti(k)+",\"hamiltonian\":\""+ham+"\",";
    s+="\"scrambler_depth\":"+fmti(sd)+",\"search_depth\":"+fmti(srd)+",\"budget\":"+fmti(bud)+",";
    s+="\"tol\":"+fmt6(tol)+",\"multi_eps\":"+fmt6(meps)+",\"recover_tol\":"+fmt6(rtol)+",\"oracle_tol\":"+fmt6(otol)+"}";
    return s;
}
static std::string result_json(const Result& R){
    std::string s="{"; s+="\"qubits\":"+fmti(R.N)+",\"k\":"+fmti(R.k)+",\"hamiltonian\":\""+R.ham+"\",";
    s+="\"haar_baseline\":"+fmt6(R.haar_b)+",\"phi_identity\":"+fmt6(R.phi_id)+",\"phi_best\":"+fmt6(R.phi_best)+",";
    s+="\"best_gap\":"+fmt6(R.best_gap)+",\"phi_planted\":"+fmt6(R.phi_planted)+",\"planted_gap\":"+fmt6(R.planted_gap)+",";
    s+="\"recovered\":"+fmti(R.recovered)+",\"oracle_dev\":"+fmt6(R.oracle_dev)+",\"frames_evaluated\":"+fmti(R.frames)+",";
    s+="\"multi_basin_count\":"+fmti(R.multi)+",\"n_trend\":[";
    for(size_t i=0;i<R.n_trend.size();i++){ if(i)s+=","; s+=fmt6(R.n_trend[i]); } s+="]}";
    return s;
}
static std::string gates_json(const Gates& g){
    std::string s="[";
    s+="{\"id\":\"G-NO-BASIN\",\"fired\":"; s+=(g.no_basin?"true":"false");
    s+=",\"value\":"+fmt6(g.best_gap)+",\"threshold\":"+fmt6(g.tol)+"},";
    s+="{\"id\":\"G-MULTI-BASIN\",\"fired\":"; s+=(g.multi_basin?"true":"false");
    s+=",\"value\":"+fmt6(g.multi_val)+",\"threshold\":"+fmt6(1.0)+"}]";
    return s;
}
static std::string declared_body(long long seed,const std::string& pj,const std::string& rj,const std::string& gj,const std::string& verdict){
    return "\"seed\":"+fmti(seed)+",\"params\":"+pj+",\"result\":"+rj+",\"gates\":"+gj+",\"verdict\":\""+verdict+"\"";
}

// ------------------------------------------------------------------- selftest
static int run_selftest(){
    int fails=0;
    fprintf(stderr,"carve --selftest (v%s)\n",VERSION);
    if(!st_check("blake2b KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")) fails++;
    // 1. analytic baseline closed form: B(4,2)=66/255
    if(!st_check("haar_baseline(4,2) == 66/255", std::fabs(haar_baseline(4,2)-66.0/255.0)<1e-12)) fails++;
    // 2. ising is 2-local: Phi_2(ising, I) == 1.0 exactly
    { PauliTab pt; pt.build(4); Mat H=H_ising(4); double p=pt.phi_k(H,2);
      if(!st_check("ising is 2-local: Phi_2(H_ising,I) == 1.0", std::fabs(p-1.0)<1e-9)) fails++; }
    // 3. ising has a basin: best_gap large (>= 0.30)
    { Result R=run_measure(4,2,"ising",0,6,512,0.02,20260714);
      if(!st_check("ising best_gap >= 0.30 (a preferred factorization)", R.best_gap>=0.30)) fails++; }
    // 4. RANDOM CONTROL (gauntlet-2): haar has NO preferred factorization: best_gap small
    { Result R=run_measure(4,2,"haar",0,6,512,0.02,20260714);
      if(!st_check("haar random control: best_gap < 0.30 (G-NO-BASIN)", R.best_gap<0.30)) fails++; }
    // 5. PLANTED ORACLE (I-11): metamorphic un-scramble V†HV == H0 exactly (oracle_dev ~ 0)
    { Result R=run_measure(4,2,"planted",3,6,512,0.02,20260714);
      if(!st_check("planted oracle metamorphic un-scramble: oracle_dev < 1e-9", R.oracle_dev<1e-9)) fails++;
      // and the planted answer is genuinely local (phi_planted high) while scrambled identity is lower
      if(!st_check("planted: phi_planted > phi_identity (scramble lowered locality)", R.phi_planted > R.phi_id + 1e-6)) fails++; }
    // 6. NULL-BY-SYMMETRY (gauntlet-1): a scalar H = c*I has no traceless part -> Phi undefined-> treat den=0 => phi 0; use product null instead:
    //    product H is an exact tensor sum -> highly local in the standard frame (a clean basin, gap large).
    { Result R=run_measure(4,2,"product",0,6,512,0.02,20260714);
      if(!st_check("product (tensor-sum) is local: best_gap >= 0.30", R.best_gap>=0.30)) fails++; }
    // 7. METAMORPHIC invariances: Phi invariant under a local unitary on one qubit
    { PauliTab pt; pt.build(4); Mat H=H_ising(4); double p0=pt.phi_k(H,2);
      Mat M=H; conj_gate(M,{G_S,1,0}); conj_gate(M,{G_SDG,1,0}); double p1=pt.phi_k(M,2); // S then S† = identity (sanity)
      Mat M2=H; conj_gate(M2,{G_H,2,0}); double p2=pt.phi_k(M2,2);                          // a local H on one qubit
      // ising has X and ZZ terms; a Hadamard on one site maps X<->Z, staying 1- and 2-local -> Phi_2 unchanged (==1)
      if(!st_check("local-unitary invariance: Phi_2 stays 1.0 under a 1q gate on ising", std::fabs(p2-1.0)<1e-9 && std::fabs(p1-p0)<1e-12)) fails++; }
    // 8. ANTI-METAMORPHIC sightedness: a NON-product (entangling) scramble MUST change Phi (not blind)
    { PauliTab pt; pt.build(4); Mat H0=H_ising(4); Mat V=build_V(4,3,20260714); Mat H=matmul(matmul(V,H0),dagger(V));
      double p_scr=pt.phi_k(H,2), p_loc=pt.phi_k(H0,2);
      if(!st_check("anti-metamorphic sightedness: entangling scramble lowers Phi_2 (NOT blind)", p_loc - p_scr > 0.05)) fails++; }
    // 9. n-trend non-decreasing for the positive control (ising)
    { Result R=run_measure(4,2,"ising",0,6,512,0.02,20260714); bool nd=true;
      for(size_t i=1;i<R.n_trend.size();i++) if(R.n_trend[i] < R.n_trend[i-1]-1e-6) nd=false;
      if(!st_check("ising n_trend non-decreasing (anti-hsmi-stab)", nd)) fails++; }
    // 10. determinism: two identical runs -> identical declared result
    { Result A=run_measure(4,2,"planted",3,6,512,0.02,20260714), B=run_measure(4,2,"planted",3,6,512,0.02,20260714);
      if(!st_check("determinism: declared result identical across two runs", result_json(A)==result_json(B))) fails++; }
    fprintf(stderr, fails? "SELFTEST FAIL (%d)\n":"SELFTEST PASS\n", fails);
    return fails?1:0;
}

// ------------------------------------------------------------------- CLI / main
static void emit(const Result& R, long long seed,int sd,int srd,int bud,double tol,double meps,double rtol,double otol,int* exit_code){
    Gates g; g.best_gap=R.best_gap; g.tol=tol; g.no_basin=(R.best_gap<=tol);
    g.multi_val=(double)R.multi; g.multi_basin=(R.multi>1);
    bool err=false;
    if(R.ham=="planted"){ if(R.oracle_dev>otol) err=true; if(!R.recovered) err=true; }
    std::string verdict = (g.no_basin||g.multi_basin)? "fail":"pass";
    std::string pj=params_json(R.N,R.k,R.ham,sd,srd,bud,tol,meps,rtol,otol);
    std::string rj=result_json(R); std::string gj=gates_json(g);
    std::string body=declared_body(seed,pj,rj,gj,verdict);
    printf("%s\n", full_envelope("carve",VERSION,body,FIREWALL).c_str());
    if(err) *exit_code=2; else *exit_code=(g.no_basin||g.multi_basin)?1:0;
}

int main(int argc,char**argv){
    int N=4,k=2,sd=3,srd=6,bud=512; std::string ham="ising";   // default = the clean positive control (matches the golden)
    double tol=0.30,meps=0.02,rtol=0.02,otol=1e-9; long long seed=20260714;
    bool do_json=false,do_self=false,do_gold=false; const char* csv=nullptr;
    for(int i=1;i<argc;i++){ std::string f=argv[i];
        auto need=[&](const char*fl)->const char*{ if(i+1>=argc) die2(std::string("missing value for ")+fl); return argv[++i]; };
        if(f=="--qubits") N=(int)parse_ll(need("--qubits"),"--qubits");
        else if(f=="--k") k=(int)parse_ll(need("--k"),"--k");
        else if(f=="--hamiltonian") ham=need("--hamiltonian");
        else if(f=="--scrambler-depth") sd=(int)parse_ll(need("--scrambler-depth"),"--scrambler-depth");
        else if(f=="--search-depth") srd=(int)parse_ll(need("--search-depth"),"--search-depth");
        else if(f=="--budget") bud=(int)parse_ll(need("--budget"),"--budget");
        else if(f=="--tol") tol=parse_d(need("--tol"),"--tol");
        else if(f=="--multi-eps") meps=parse_d(need("--multi-eps"),"--multi-eps");
        else if(f=="--recover-tol") rtol=parse_d(need("--recover-tol"),"--recover-tol");
        else if(f=="--oracle-tol") otol=parse_d(need("--oracle-tol"),"--oracle-tol");
        else if(f=="--seed"){ seed=parse_ll(need("--seed"),"--seed"); if(seed<0) die2("--seed must be >= 0"); }
        else if(f=="--json") do_json=true; else if(f=="--selftest") do_self=true; else if(f=="--golden") do_gold=true;
        else if(f=="--csv") csv=need("--csv");
        else die2("unknown flag "+f);
    }
    if(do_self) return run_selftest();
    if(do_gold){ N=4;k=2;ham="ising";sd=0;srd=6;bud=512;tol=0.30;meps=0.02;rtol=0.02;otol=1e-9;seed=20260714;
        Result R=run_measure(N,k,ham,sd,srd,bud,rtol,seed);
        Gates g; g.best_gap=R.best_gap; g.tol=tol; g.no_basin=(R.best_gap<=tol); g.multi_val=(double)R.multi; g.multi_basin=(R.multi>1);
        std::string verdict=(g.no_basin||g.multi_basin)?"fail":"pass";
        std::string body=declared_body(seed,params_json(N,k,ham,sd,srd,bud,tol,meps,rtol,otol),result_json(R),gates_json(g),verdict);
        return golden_check("carve", declared_object(body), full_envelope("carve",VERSION,body,FIREWALL));
    }
    if(N<2||N>6) die2("--qubits in [2,6]"); if(k<1||k>=N) die2("--k in [1,N-1]");
    if(ham!="planted"&&ham!="ising"&&ham!="product"&&ham!="haar") die2("--hamiltonian in {planted,ising,product,haar}");
    if(sd<0||sd>12||srd<0||srd>12) die2("depths in [0,12]"); if(bud<1||bud>4096) die2("--budget in [1,4096]");
    Result R=run_measure(N,k,ham,sd,srd,bud,rtol,seed);
    if(csv){ FILE*f=fopen(csv,"w"); if(f){ fprintf(f,"Np,best_gap\n"); for(size_t i=0;i<R.n_trend.size();i++) fprintf(f,"%zu,%.6f\n",i+2,R.n_trend[i]); fclose(f);} }
    if(!do_json){ /* human */ fprintf(stderr,"carve %s N=%d k=%d ham=%s: best_gap=%.4f (baseline %.4f) recovered=%d oracle_dev=%.2e multi=%d\n",
        VERSION,N,k,ham.c_str(),R.best_gap,R.haar_b,R.recovered,R.oracle_dev,R.multi); }
    int ec=0; emit(R,seed,sd,srd,bud,tol,meps,rtol,otol,&ec); return ec;
}
