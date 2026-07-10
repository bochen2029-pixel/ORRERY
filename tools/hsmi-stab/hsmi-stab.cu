// hsmi-stab.cu -- ORRERY tool `hsmi-stab` (v1.0.0). The K1 probe (F-K1, first by dignity).
// Contract: contracts/hsmi-stab.contract.md v1.0.0. The contract is authoritative; MODULE.md
// carries the math spec this implements.
//
// Measures the finite-D SHADOW of half-sided modular position (structure) and its deformation
// scaling -- never the Type III_1 statement, never qualia. III-sealed twice (see contract SCOPE).
//
// Engine decision (recorded in MODULE): cuSOLVER Dsyevd (fp64) for every eigensolve (the cost
// center); flow/violation assembly in host fp64 complex (deterministic, trivial at n<=2048).
//
// Build (from tools/hsmi-stab/, see BUILD.md):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 hsmi-stab.cu ../../lib/envelope.cpp -o hsmi-stab.exe -lcusolver'

#include <cuda_runtime.h>
#include <cusolverDn.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <complex>
#include <string>
#include <vector>
#include <algorithm>
#include "../../lib/envelope.h"   // blake2b, fmt6/fmti/jesc, golden plumbing, CLI spine, CUDA_OK (D-020)
#include "../../lib/rng.cuh"      // counter_gauss (the D-012 kit; drives the noise family)
using namespace orrery;
typedef std::complex<double> cd;

static const char* HSMI_VERSION = "1.0.0";
static const char* FIREWALL =
    "This measures an operator-algebraic stability property of a finite-D proxy (structure); it "
    "says nothing about whether anything feels (acquaintance) - III-sealed. Finite dimensions "
    "cannot host a true half-sided modular inclusion (Type III_1 only): this tool measures the "
    "SHADOW - the violation functional and its deformation scaling - never the Type III_1 claim.";
static const double CLAMP_G = 1e-12;    // eigenvalue clamp gamma (declared)
static const double Y_FLOOR = 1e-12;    // fit increment floor (declared)

#define SOLVER_OK(call) do { cusolverStatus_t _s=(call); if(_s!=CUSOLVER_STATUS_SUCCESS){ \
    fprintf(stderr,"cuSOLVER error %s at %s:%d: status %d\n",#call,__FILE__,__LINE__,(int)_s); std::exit(2);} } while(0)

// ------------------------------------------------------------------ cuSOLVER eigensolve (ascending)
static cusolverDnHandle_t g_solver=nullptr;
static void ensure_solver(){ if(!g_solver) SOLVER_OK(cusolverDnCreate(&g_solver)); }
// symmetric NxN row-major==col-major (symmetric) A -> eigenvalues w (ascending) + eigenvectors in A's columns
static void dsyevd_host(int N, std::vector<double>& A, std::vector<double>& w){
    ensure_solver();
    double *dA=nullptr,*dW=nullptr; int lwork=0,*info=nullptr;
    CUDA_OK(cudaMalloc(&dA,(size_t)N*N*sizeof(double)));
    CUDA_OK(cudaMalloc(&dW,(size_t)N*sizeof(double)));
    CUDA_OK(cudaMemcpy(dA,A.data(),(size_t)N*N*sizeof(double),cudaMemcpyHostToDevice));
    SOLVER_OK(cusolverDnDsyevd_bufferSize(g_solver,CUSOLVER_EIG_MODE_VECTOR,CUBLAS_FILL_MODE_LOWER,N,dA,N,dW,&lwork));
    double* work=nullptr; CUDA_OK(cudaMalloc(&work,(size_t)lwork*sizeof(double))); CUDA_OK(cudaMalloc(&info,sizeof(int)));
    SOLVER_OK(cusolverDnDsyevd(g_solver,CUSOLVER_EIG_MODE_VECTOR,CUBLAS_FILL_MODE_LOWER,N,dA,N,dW,work,lwork,info));
    int hinfo=0; CUDA_OK(cudaMemcpy(&hinfo,info,sizeof(int),cudaMemcpyDeviceToHost));
    if(hinfo!=0){ fprintf(stderr,"cuSOLVER syevd info=%d\n",hinfo); std::exit(2); }
    w.resize(N);
    CUDA_OK(cudaMemcpy(A.data(),dA,(size_t)N*N*sizeof(double),cudaMemcpyDeviceToHost));   // columns = eigenvectors (col-major)
    CUDA_OK(cudaMemcpy(w.data(),dW,(size_t)N*sizeof(double),cudaMemcpyDeviceToHost));
    cudaFree(dA); cudaFree(dW); cudaFree(work); cudaFree(info);
}

// complex Hermitian NxN, buffer COL-MAJOR (element (r,c) at c*N+r) -> eigenvalues w (ascending)
// + eigenvectors in the buffer's columns. NOTE: a row-major-filled Hermitian buffer would hand
// cuSOLVER the transpose = the CONJUGATE matrix (opposite chirality); fill col-major.
static void zheevd_host(int N, std::vector<cd>& A, std::vector<double>& w){
    ensure_solver();
    cuDoubleComplex *dA=nullptr; double *dW=nullptr; int lwork=0,*info=nullptr;
    CUDA_OK(cudaMalloc(&dA,(size_t)N*N*sizeof(cuDoubleComplex)));
    CUDA_OK(cudaMalloc(&dW,(size_t)N*sizeof(double)));
    CUDA_OK(cudaMemcpy(dA,A.data(),(size_t)N*N*sizeof(cuDoubleComplex),cudaMemcpyHostToDevice));
    SOLVER_OK(cusolverDnZheevd_bufferSize(g_solver,CUSOLVER_EIG_MODE_VECTOR,CUBLAS_FILL_MODE_LOWER,N,dA,N,dW,&lwork));
    cuDoubleComplex* work=nullptr; CUDA_OK(cudaMalloc(&work,(size_t)lwork*sizeof(cuDoubleComplex))); CUDA_OK(cudaMalloc(&info,sizeof(int)));
    SOLVER_OK(cusolverDnZheevd(g_solver,CUSOLVER_EIG_MODE_VECTOR,CUBLAS_FILL_MODE_LOWER,N,dA,N,dW,work,lwork,info));
    int hinfo=0; CUDA_OK(cudaMemcpy(&hinfo,info,sizeof(int),cudaMemcpyDeviceToHost));
    if(hinfo!=0){ fprintf(stderr,"cuSOLVER zheevd info=%d\n",hinfo); std::exit(2); }
    w.resize(N);
    CUDA_OK(cudaMemcpy(A.data(),dA,(size_t)N*N*sizeof(cuDoubleComplex),cudaMemcpyDeviceToHost));
    CUDA_OK(cudaMemcpy(w.data(),dW,(size_t)N*sizeof(double),cudaMemcpyDeviceToHost));
    cudaFree(dA); cudaFree(dW); cudaFree(work); cudaFree(info);
}

// ------------------------------------------------------------------ v1.1 model candidate: chiral log-lattice kernel
// Chiral-fermion vacuum two-point kernel <psi^dag(x)psi(y)> = (1/2pi i)/((y-x)-i0), sampled on the
// log lattice x_k = e^{ak} with cell weights w_k = a x_k. sqrt(w_i w_j)/(x_j-x_i) telescopes to
// a/(2 sinh(a(j-i)/2)) -- the kernel is TOEPLITZ in j-i: log-translation = dilation, so the shifted
// mode set IS the canonical half-sided candidate. Diagonal = 1/2 (the delta half; PV part odd).
// Complex Hermitian (T broken) => U(-t) != conj(U(t)): the D-027 obstruction is lifted.
static const double HS_PI = 3.14159265358979323846;
static void build_chiral_CA(int m, double a, std::vector<cd>& C){   // col-major fill
    C.assign((size_t)m*m, cd(0,0));
    for(int j=0;j<m;j++) for(int i=0;i<m;i++){
        if(i==j) C[(size_t)j*m+i] = cd(0.5, 0.0);
        else     C[(size_t)j*m+i] = cd(0.0, -a/(4.0*HS_PI*std::sinh(a*(j-i)*0.5)));
    }
}
struct ModularC { int n; std::vector<cd> W; std::vector<double> lam; double min_c, max_c; };
static ModularC modular_of_c(std::vector<cd> CA, int n){            // CA col-major, consumed
    ModularC M; M.n=n;
    std::vector<double> w;
    zheevd_host(n, CA, w);
    M.W = CA; M.lam.resize(n); M.min_c=1e9; M.max_c=-1e9;
    for(int i=0;i<n;i++){
        double c = w[i];
        M.min_c = std::min(M.min_c, c); M.max_c = std::max(M.max_c, c);
        c = std::min(std::max(c, CLAMP_G), 1.0-CLAMP_G);
        M.lam[i] = std::log((1.0-c)/c);
    }
    return M;
}
// U(t) = W diag(e^{i lam t}) W^dagger; leakage block B[r][c] = <e_r|U(t)|e_{s+c}>
// = sum_i W[r,i] e^{i lam_i t} conj(W[s+c,i]); sigma_max via the s x s Gram (complex Hermitian).
static double viol_at_c(const ModularC& M, double t, int s){
    int n=M.n, m=n-s;
    std::vector<cd> B((size_t)s*m, cd(0,0));
    for(int i=0;i<n;i++){
        cd ph = std::polar(1.0, M.lam[i]*t);
        for(int r=0;r<s;r++){
            cd f = M.W[(size_t)i*n+r] * ph;
            if(f==cd(0,0)) continue;
            for(int c=0;c<m;c++) B[(size_t)r*m+c] += f * std::conj(M.W[(size_t)i*n+(s+c)]);
        }
    }
    if(s==1){ double acc=0; for(int c=0;c<m;c++) acc += std::norm(B[c]); return std::sqrt(acc); }
    std::vector<cd> G((size_t)s*s, cd(0,0));                        // Gram of rows: B B^dagger (col-major fill; Hermitian)
    for(int r2=0;r2<s;r2++) for(int r1=0;r1<s;r1++){
        cd acc(0,0);
        for(int c=0;c<m;c++) acc += B[(size_t)r1*m+c]*std::conj(B[(size_t)r2*m+c]);
        G[(size_t)r2*s+r1] = acc;
    }
    std::vector<double> wg; zheevd_host(s, G, wg);
    return std::sqrt(std::max(0.0, wg[s-1]));
}

// chiral state on a uniform periodic chain by momentum projection: occupy the right-movers
// k_q = 2 pi q / L, q = 1..L/2-1 (group velocity sin k > 0; k=0,pi excluded). C is a spectral
// projector => window restriction has eigenvalues in [0,1] by construction. Complex Hermitian.
static void build_chiral_window(int L, int n, std::vector<cd>& CA){   // col-major
    CA.assign((size_t)n*n, cd(0,0));
    for(int j=0;j<n;j++) for(int i=0;i<n;i++){
        cd acc(0,0);
        for(int q=1;q<=L/2-1;q++){
            double ph = 2.0*HS_PI*q*(double)(i-j)/(double)L;
            acc += cd(std::cos(ph), std::sin(ph));
        }
        CA[(size_t)j*n+i] = acc/(double)L;
    }
}
// K = W diag(lam) W^dagger from modular eigendata (col-major, Hermitian)
static void kmat_from(const ModularC& M, std::vector<cd>& K){
    int n=M.n; K.assign((size_t)n*n, cd(0,0));
    for(int i=0;i<n;i++) for(int r=0;r<n;r++){
        cd wl = M.W[(size_t)i*n+r]*M.lam[i];
        for(int c=0;c<n;c++) K[(size_t)c*n+r] += wl*std::conj(M.W[(size_t)i*n+c]);
    }
}
struct GParts { double negsum, possum, mineig, maxeig; int nneg; };
static GParts g_parts(std::vector<cd>& G, int n){                     // consumes G
    std::vector<double> w; zheevd_host(n, G, w);
    GParts P{0,0,w[0],w[n-1],0};
    for(int i=0;i<n;i++){ if(w[i]<0){ P.negsum -= w[i]; P.nneg++; } else P.possum += w[i]; }
    return P;
}
// Borchers-generator probe for a window covariance CA (col-major n x n), sub-window = drop first s
static void probe_G_of(const char* tag, const std::vector<cd>& CA, int n, int s){
    ModularC MA = modular_of_c(CA, n);
    std::vector<cd> KA; kmat_from(MA, KA);
    int m = n - s;
    std::vector<cd> CN((size_t)m*m);
    for(int c=0;c<m;c++) for(int r=0;r<m;r++) CN[(size_t)c*m+r] = CA[(size_t)(s+c)*n+(s+r)];
    ModularC MN = modular_of_c(CN, m);
    std::vector<cd> KN; kmat_from(MN, KN);
    const double TP = 2.0*HS_PI;
    std::vector<cd> Gf((size_t)n*n), Gr((size_t)m*m);                 // full (KN embedded) and N-restricted
    for(int c=0;c<n;c++) for(int r=0;r<n;r++){
        cd kn = (r>=s && c>=s) ? KN[(size_t)(c-s)*m+(r-s)] : cd(0,0);
        Gf[(size_t)c*n+r] = (KA[(size_t)c*n+r] - kn)/TP;
    }
    for(int c=0;c<m;c++) for(int r=0;r<m;r++)
        Gr[(size_t)c*m+r] = (KA[(size_t)(s+c)*n+(s+r)] - KN[(size_t)c*m+r])/TP;
    GParts pf = g_parts(Gf, n), pr = g_parts(Gr, m);
    fprintf(stderr,"%s n=%3d s=%d  minmarg=%.1e | G_full: min=%+.4f negsum=%.4f possum=%.4f nneg=%d"
                   " | G_restr: min=%+.4f negsum=%.4f possum=%.4f nneg=%d arrow=%.2f\n",
            tag, n, s, std::min(MA.min_c, 1.0-MA.max_c),
            pf.mineig, pf.negsum, pf.possum, pf.nneg,
            pr.mineig, pr.negsum, pr.possum, pr.nneg,
            pr.negsum>0 ? pr.possum/pr.negsum : 1e12);
}

// ------------------------------------------------------------------ params / result
struct Params {
    int sites=128, shift=1, eps_points=8, t_points=64;
    int family=0;                       // 0=mass, 1=noise
    double eps_max=0.2, t_max=6.283185, k_min=0.5, snap_frac=0.5, arrow_min=10.0;
    long long seed=0; bool seed_set=false;
    bool json=false, csv=false, selftest=false, golden=false; std::string csv_path;
};
struct Result {
    int sites=0, shift=0, family=0, flow_sign=1, fit_points=0;
    double delta_minus_0=0, delta_plus_0=0, arrow_ratio=0;
    double delta_minus_eps1=0, delta_minus_max=0, k_fit=0, c_fit=0;
    bool growth_monotone=true;
    std::string verdict_kind="graceful";
    bool g_noarrow=false, g_rigid=false, g_soft=false;
    double g_noarrow_v=0, g_rigid_v=0, g_soft_v=0;
};

// ------------------------------------------------------------------ model: Hamiltonian -> covariance -> modular data
static void build_h(std::vector<double>& h, int L, int family, double eps, uint64_t seed){
    h.assign((size_t)L*L, 0.0);
    for(int j=0;j+1<L;j++){ h[(size_t)j*L+(j+1)] = -1.0; h[(size_t)(j+1)*L+j] = -1.0; }
    if(eps != 0.0){
        if(family==0){                                          // mass: staggered on-site
            for(int j=0;j<L;j++) h[(size_t)j*L+j] += eps * ((j&1)? -1.0 : 1.0);
        } else {                                                // noise: seeded local disorder (D-012 kit)
            for(int j=0;j<L;j++)   h[(size_t)j*L+j] += eps * counter_gauss(seed,(uint64_t)j,0,0);
            for(int j=0;j+1<L;j++){ double v = eps * counter_gauss(seed,(uint64_t)j,1,0);
                h[(size_t)j*L+(j+1)] += v; h[(size_t)(j+1)*L+j] += v; }
        }
    }
}
// ground-state covariance C = sum_{occ} v v^T; occupied = E<0 (tie rule: lowest L/2 if any |E|<1e-13)
static void ground_cov(const std::vector<double>& h_in, int L, std::vector<double>& C){
    std::vector<double> A=h_in, w;
    dsyevd_host(L, A, w);
    int nocc=0; bool tie=false;
    for(int k=0;k<L;k++){ if(std::fabs(w[k])<1e-13) tie=true; if(w[k]<0) nocc++; }
    if(tie) nocc = L/2;
    C.assign((size_t)L*L, 0.0);
    for(int k=0;k<nocc;k++)
        for(int i=0;i<L;i++){ double vik=A[(size_t)k*L+i];       // col-major column k
            for(int j=0;j<L;j++) C[(size_t)i*L+j] += vik * A[(size_t)k*L+j]; }
}
struct Modular { int n; std::vector<double> W; std::vector<double> lam; double min_margin; };
// region A = sites [n,2n): restrict, eigendecompose, lambda_i = log((1-c)/c) with clamp
static Modular modular_of(const std::vector<double>& C, int L, int n){
    Modular M; M.n=n;
    std::vector<double> CA((size_t)n*n);
    for(int i=0;i<n;i++) for(int j=0;j<n;j++) CA[(size_t)i*n+j] = C[(size_t)(n+i)*L+(n+j)];
    std::vector<double> w;
    dsyevd_host(n, CA, w);
    M.W = CA;                                                    // columns = eigenvectors (col-major)
    M.lam.resize(n); M.min_margin = 1e9;
    for(int i=0;i<n;i++){
        double c = w[i];
        M.min_margin = std::min(M.min_margin, std::min(c, 1.0-c));
        c = std::min(std::max(c, CLAMP_G), 1.0-CLAMP_G);
        M.lam[i] = std::log((1.0-c)/c);
    }
    return M;
}
// violation at one t, one direction, for the subspace with basis Qn (n x (n-s), col-major) and
// complement Qp (n x s): sigma_max( Qp^T U(t) Qn ), U(t) = W diag(e^{i lam t}) W^T.
// Site-basis default: Qn = columns e_s..e_{n-1}, Qp = e_0..e_{s-1} (passed as index lists).
static double viol_at(const Modular& M, double t, const std::vector<double>* Qn,
                      const std::vector<double>* Qp, int s){
    int n = M.n;
    // rowsW[r][i] = (Qp^T W)[r][i];  colsW[c][i] = (W^T Qn)[i][c] pre-contract to G[r][c](t)
    // B[r][c] = sum_i rowsW[r][i] * e^{i lam_i t} * colsW[i][c]
    int m = n - s;
    std::vector<cd> B((size_t)s*m, cd(0,0));
    for(int i=0;i<n;i++){
        cd ph = std::polar(1.0, M.lam[i]*t);
        for(int r=0;r<s;r++){
            double wr = Qp ? 0.0 : M.W[(size_t)i*n + r];                 // site basis: row r = site r of A
            if(Qp){ double acc=0; for(int a=0;a<n;a++) acc += (*Qp)[(size_t)r*n+a]*M.W[(size_t)i*n+a]; wr=acc; }
            if(wr==0.0) continue;
            cd f = ph * wr;
            for(int c=0;c<m;c++){
                double wc = Qn ? 0.0 : M.W[(size_t)i*n + (s+c)];
                if(Qn){ double acc=0; for(int a=0;a<n;a++) acc += (*Qn)[(size_t)c*n+a]*M.W[(size_t)i*n+a]; wc=acc; }
                B[(size_t)r*m+c] += f * wc;
            }
        }
    }
    // sigma_max via s x s Gram (s is tiny: <= n/4, typically 1)
    if(s==1){ double acc=0; for(int c=0;c<m;c++) acc += std::norm(B[c]); return std::sqrt(acc); }
    std::vector<double> G((size_t)s*s,0.0);
    for(int r1=0;r1<s;r1++) for(int r2=0;r2<s;r2++){
        cd acc(0,0);
        for(int c=0;c<m;c++) acc += B[(size_t)r1*m+c]*std::conj(B[(size_t)r2*m+c]);
        G[(size_t)r1*s+r2] = acc.real();                        // Gram of rows: B B^dagger, real symmetric
    }
    std::vector<double> wg; dsyevd_host(s, G, wg);
    return std::sqrt(std::max(0.0, wg[s-1]));
}
// max violation over the t-grid for direction a
static double viol_dir(const Modular& M, double a, double t_max, int t_points,
                       const std::vector<double>* Qn, const std::vector<double>* Qp, int s){
    double best=0;
    for(int j=0;j<t_points;j++){
        double t = a * (t_max * j / (double)(t_points-1));
        best = std::max(best, viol_at(M, t, Qn, Qp, s));
    }
    return best;
}
struct DeltaPair { double dminus, dplus; int sign; };
static DeltaPair deltas(const Modular& M, const Params& P,
                        const std::vector<double>* Qn=nullptr, const std::vector<double>* Qp=nullptr){
    double dp = viol_dir(M, +1.0, P.t_max, P.t_points, Qn, Qp, P.shift);
    double dm = viol_dir(M, -1.0, P.t_max, P.t_points, Qn, Qp, P.shift);
    DeltaPair D;
    if(dp <= dm){ D.dminus=dp; D.dplus=dm; D.sign=+1; } else { D.dminus=dm; D.dplus=dp; D.sign=-1; }
    return D;
}
static DeltaPair deltas_at_eps(const Params& P, double eps){
    int n=P.sites, L=2*n;
    std::vector<double> h, C;
    build_h(h, L, P.family, eps, (uint64_t)P.seed);
    ground_cov(h, L, C);
    Modular M = modular_of(C, L, n);
    return deltas(M, P);
}

// ------------------------------------------------------------------ the measurement
static Result run_probe(const Params& P, std::vector<std::string>* csv){
    Result R; R.sites=P.sites; R.shift=P.shift; R.family=P.family;
    DeltaPair D0 = deltas_at_eps(P, 0.0);
    R.flow_sign=D0.sign; R.delta_minus_0=D0.dminus; R.delta_plus_0=D0.dplus;
    R.arrow_ratio = D0.dminus>0 ? D0.dplus/D0.dminus : 1e12;
    if(csv){ char b[128]; snprintf(b,sizeof(b),"%s,%s,%s",fmt6(0.0).c_str(),fmt6(D0.dminus).c_str(),fmt6(D0.dplus).c_str()); csv->push_back(b); }
    std::vector<double> epss, ys;
    bool mono=true; double prev=-1;
    for(int i=1;i<=P.eps_points;i++){
        double eps = P.eps_max * i / (double)P.eps_points;
        DeltaPair D = deltas_at_eps(P, eps);
        double y = D.dminus - R.delta_minus_0;
        if(csv){ char b[128]; snprintf(b,sizeof(b),"%s,%s,%s",fmt6(eps).c_str(),fmt6(D.dminus).c_str(),fmt6(D.dplus).c_str()); csv->push_back(b); }
        if(i==1) R.delta_minus_eps1 = D.dminus;
        if(i==P.eps_points) R.delta_minus_max = D.dminus;
        if(prev>=0 && y < prev - 1e-15) mono=false;
        prev=y;
        if(y > Y_FLOOR){ epss.push_back(eps); ys.push_back(y); }
    }
    R.growth_monotone = mono;
    R.fit_points = (int)ys.size();
    if(R.fit_points >= 2){
        double sx=0,sy=0,sxx=0,sxy=0; int m=R.fit_points;
        for(int i=0;i<m;i++){ double x=std::log(epss[i]), y=std::log(ys[i]); sx+=x; sy+=y; sxx+=x*x; sxy+=x*y; }
        R.k_fit = (m*sxy - sx*sy)/(m*sxx - sx*sx);
        R.c_fit = (sy - R.k_fit*sx)/m;
    }
    // gates (contract order)
    R.g_noarrow_v = R.arrow_ratio;                 R.g_noarrow = (R.arrow_ratio < P.arrow_min);
    R.g_rigid_v   = R.delta_plus_0>0 ? R.delta_minus_eps1/R.delta_plus_0 : 1e12;
    R.g_rigid     = (R.g_rigid_v >= P.snap_frac);
    R.g_soft_v    = R.k_fit;
    R.g_soft      = (!R.g_rigid) && (R.fit_points>=2) && (R.k_fit < P.k_min || !R.growth_monotone);
    R.verdict_kind = R.g_rigid ? "snap" : (R.g_soft ? "soft" : "graceful");
    return R;
}

// ------------------------------------------------------------------ serialize [someone shape]
static const char* FAM[2]={"mass","noise"};
static std::string params_json(const Params& P){
    return "{" "\"sites\":"+fmti(P.sites)+",\"shift\":"+fmti(P.shift)+",\"family\":\""+FAM[P.family]+"\""
         + ",\"eps_max\":"+fmt6(P.eps_max)+",\"eps_points\":"+fmti(P.eps_points)
         + ",\"t_max\":"+fmt6(P.t_max)+",\"t_points\":"+fmti(P.t_points)
         + ",\"k_min\":"+fmt6(P.k_min)+",\"snap_frac\":"+fmt6(P.snap_frac)+",\"arrow_min\":"+fmt6(P.arrow_min)+"}";
}
static std::string result_json(const Result& R){
    return "{" "\"sites\":"+fmti(R.sites)+",\"shift\":"+fmti(R.shift)+",\"family\":\""+FAM[R.family]+"\""
         + ",\"flow_sign\":"+fmti(R.flow_sign)
         + ",\"delta_minus_0\":"+fmt6(R.delta_minus_0)+",\"delta_plus_0\":"+fmt6(R.delta_plus_0)
         + ",\"arrow_ratio\":"+fmt6(R.arrow_ratio)
         + ",\"delta_minus_eps1\":"+fmt6(R.delta_minus_eps1)+",\"delta_minus_max\":"+fmt6(R.delta_minus_max)
         + ",\"k_fit\":"+fmt6(R.k_fit)+",\"c_fit\":"+fmt6(R.c_fit)+",\"fit_points\":"+fmti(R.fit_points)
         + ",\"growth_monotone\":"+std::string(R.growth_monotone?"true":"false")
         + ",\"verdict_kind\":\""+R.verdict_kind+"\"}";
}
static std::string gates_json(const Result& R, const Params& P){
    return "[{\"id\":\"G-NO-ARROW\",\"fired\":"+std::string(R.g_noarrow?"true":"false")
         + ",\"value\":"+fmt6(R.g_noarrow_v)+",\"threshold\":"+fmt6(P.arrow_min)+"}"
         + ",{\"id\":\"G-RIGID\",\"fired\":"+std::string(R.g_rigid?"true":"false")
         + ",\"value\":"+fmt6(R.g_rigid_v)+",\"threshold\":"+fmt6(P.snap_frac)+"}"
         + ",{\"id\":\"G-SOFT-EXPONENT\",\"fired\":"+std::string(R.g_soft?"true":"false")
         + ",\"value\":"+fmt6(R.g_soft_v)+",\"threshold\":"+fmt6(P.k_min)+"}]";
}
static std::string declared_body(const Params& P, const Result& R, const std::string& v){
    return "\"seed\":"+fmti(P.seed)+",\"params\":"+params_json(P)+",\"result\":"+result_json(R)
         + ",\"gates\":"+gates_json(R,P)+",\"verdict\":\""+v+"\"";
}
static std::string declared_object(const Params& P, const Result& R, const std::string& v){ return "{"+declared_body(P,R,v)+"}"; }
static std::string full_envelope(const Params& P, const Result& R, const std::string& v){
    return orrery::full_envelope("hsmi-stab", HSMI_VERSION, declared_body(P,R,v), FIREWALL);
}

static int run_config(const Params& P, bool do_print, std::string* declared_out){
    std::vector<std::string> csv; std::vector<std::string>* csvp=(do_print&&P.csv)?&csv:nullptr;
    Result R = run_probe(P, csvp);
    bool fired = R.g_noarrow || R.g_rigid || R.g_soft;
    std::string verdict = fired ? "fail" : "pass";
    if(declared_out) *declared_out = declared_object(P,R,verdict);
    if(do_print){
        if(csvp){ FILE* f=fopen(P.csv_path.c_str(),"wb"); if(!f){ fprintf(stderr,"error: cannot open --csv: %s\n",P.csv_path.c_str()); std::exit(2); }
            fprintf(f,"eps,delta_minus,delta_plus\n"); for(auto& r:csv) fprintf(f,"%s\n",r.c_str()); fclose(f); }
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str());
    }
    return fired ? 1 : 0;
}

// ------------------------------------------------------------------ golden
static Params golden_params(){
    Params P; P.sites=128; P.shift=1; P.family=0; P.eps_max=0.2; P.eps_points=8;
    P.t_max=6.283185; P.t_points=64; P.k_min=0.5; P.snap_frac=0.5; P.arrow_min=10.0;
    P.seed=20260710; P.json=true; P.seed_set=true; return P;
}
static int run_golden(){
    Params P=golden_params();
    Result R=run_probe(P,nullptr);
    bool fired = R.g_noarrow || R.g_rigid || R.g_soft;
    std::string v = fired ? "fail" : "pass";
    return golden_check("hsmi-stab", declared_object(P,R,v), full_envelope(P,R,v));
}

// ================================================================== ORACLE: exact Fock cross-check (L=6, n=3)
// Region-internal everything: basis index bit m = occupation of region-relative site m (0..2 local,
// global sites offset). Global chain L=6; region A = sites 3,4,5.
static int popcount_below(int state, int m){ int c=0; for(int k=0;k<m;k++) if(state>>k & 1) c++; return c; }
// many-body H (dim x dim) from single-particle h (LxL), JW with site-order = bit-order
static void many_body_h(const std::vector<double>& h, int L, std::vector<double>& H){
    int dim = 1<<L;
    H.assign((size_t)dim*dim, 0.0);
    for(int s=0;s<dim;s++){
        for(int j=0;j<L;j++){
            if(h[(size_t)j*L+j]!=0.0 && (s>>j & 1)) H[(size_t)s*dim+s] += h[(size_t)j*L+j];
            for(int k=0;k<L;k++){
                if(k==j) continue;
                double t = h[(size_t)j*L+k];
                if(t==0.0) continue;                              // c_j^dag c_k
                if(!(s>>k & 1) || (s>>j & 1)) continue;
                int s2 = (s & ~(1<<k)) | (1<<j);
                int sgn = ((popcount_below(s,k) + popcount_below(s & ~(1<<k), j)) & 1) ? -1 : 1;
                H[(size_t)s2*dim+s] += t * sgn;
            }
        }
    }
}
// region-internal JW annihilator c_m on nA local sites (dim 2^nA), real matrix
static void jw_c(int nA, int m, std::vector<double>& Cop){
    int dim=1<<nA; Cop.assign((size_t)dim*dim,0.0);
    for(int s=0;s<dim;s++){
        if(!(s>>m & 1)) continue;
        int s2 = s & ~(1<<m);
        int sgn = (popcount_below(s,m)&1)? -1 : 1;
        Cop[(size_t)s2*dim+s] = sgn;
    }
}
// returns max abs discrepancy between Fock and Gaussian generator-level violation at given t values
static double fock_oracle_max_err(double* out_energy_err){
    const int L=6, n=3, s=1, dimF=1<<L, dimA=1<<n;
    std::vector<double> h; build_h(h, L, 0, 0.0, 0);
    // single-particle side
    std::vector<double> hs=h, ws; dsyevd_host(L, hs, ws);
    double e_sp=0; for(int k=0;k<L;k++) if(ws[k]<0) e_sp+=ws[k];
    std::vector<double> C; ground_cov(h, L, C);
    Modular M = modular_of(C, L, n);
    if(M.min_margin < 1e-6){ if(out_energy_err) *out_energy_err=1e9; return 1e9; }  // clamp active: oracle invalid
    // many-body side
    std::vector<double> H; many_body_h(h, L, H);
    std::vector<double> wF; dsyevd_host(dimF, H, wF);            // H's columns now eigenvectors
    if(out_energy_err) *out_energy_err = std::fabs(wF[0] - e_sp);
    // rho_A from ground vector: index = a*8 + b?  bit m = site m; region = sites 3..5 = HIGH bits => a = s>>3
    std::vector<double> psi(dimF);
    for(int i=0;i<dimF;i++) psi[i] = H[(size_t)0*dimF + i];      // column 0
    std::vector<double> rho((size_t)dimA*dimA, 0.0);
    for(int a1=0;a1<dimA;a1++) for(int a2=0;a2<dimA;a2++){
        double acc=0;
        for(int b=0;b<dimA;b++){
            // JW string sign: tracing out the LOW bits (sites 0..2) of a product state region ordering:
            // global JW order = bit order; A-operators carry strings over B... for the REDUCED STATE
            // itself no operator strings are needed: rho_A[a1,a2] = sum_b psi[a1<<3|b] psi[a2<<3|b]
            // is correct iff parity of b is equal in both terms -- enforced automatically only when
            // a1,a2 have equal particle number parity; cross-parity terms vanish in a parity-super-
            // selected ground state of a number-conserving H (fixed N sector), so the naive trace is exact.
            acc += psi[(size_t)(a1<<3|b)] * psi[(size_t)(a2<<3|b)];
        }
        rho[(size_t)a1*dimA+a2]=acc;
    }
    std::vector<double> rw, rV=rho; dsyevd_host(dimA, rV, rw);   // rho = V diag(rw) V^T
    // modular flow sigma_t(x) = rho^{it} x rho^{-it}; clamp tiny eigenvalues
    for(int i=0;i<dimA;i++) rw[i] = std::max(rw[i], 1e-14);
    // generators of N (region-local sites 1,2) and the probe c_1... wait: N = A minus first `shift`
    // sites = local sites 1,2. Probe x = c_1 (IN N) -- flow leaks it toward site 0.
    std::vector<double> c1, c2; jw_c(n, 1, c1); jw_c(n, 2, c2);
    // HS-orthonormal basis of span{c1,c2} (they are HS-orthogonal by construction, same norm)
    double nrm = 0; for(double v: c1) nrm += v*v; nrm = std::sqrt(nrm);
    double maxerr = 0;
    for(double tt : {0.7, 1.3}) for(int dir=0; dir<2; dir++){
        double t = dir? -tt : tt;
        // U_rho^{it} in rho-eigenbasis: x_t = V diag(rw^{it}) V^T x V diag(rw^{-it}) V^T
        std::vector<cd> xt((size_t)dimA*dimA, cd(0,0));
        // form y = V^T c1 V (real), then y_t[i][j] = (rw_i/rw_j)^{it} y[i][j], back-rotate
        std::vector<double> y((size_t)dimA*dimA,0.0), tmp((size_t)dimA*dimA,0.0);
        for(int i=0;i<dimA;i++) for(int j=0;j<dimA;j++){ double acc=0;
            for(int a=0;a<dimA;a++) acc += rV[(size_t)i*dimA+a]*c1[(size_t)a*dimA+j]; tmp[(size_t)i*dimA+j]=acc; }
        for(int i=0;i<dimA;i++) for(int j=0;j<dimA;j++){ double acc=0;
            for(int a=0;a<dimA;a++) acc += tmp[(size_t)i*dimA+a]*rV[(size_t)j*dimA+a]; y[(size_t)i*dimA+j]=acc; }
        std::vector<cd> yt((size_t)dimA*dimA);
        for(int i=0;i<dimA;i++) for(int j=0;j<dimA;j++){
            double ph = t*(std::log(rw[i]) - std::log(rw[j]));
            yt[(size_t)i*dimA+j] = std::polar(1.0, ph) * y[(size_t)i*dimA+j];
        }
        for(int i=0;i<dimA;i++) for(int j=0;j<dimA;j++){ cd acc(0,0);
            for(int a=0;a<dimA;a++) acc += rV[(size_t)a*dimA+i]*yt[(size_t)a*dimA+j]; xt[(size_t)i*dimA+j]=acc; }
        std::vector<cd> xt2((size_t)dimA*dimA);
        // back-rotation is x_t = V yt V^T: the right factor is V^T (buffer index a*dimA+j),
        // unlike the forward y = (V^T c1) V step above whose right factor is V (j*dimA+a)
        for(int i=0;i<dimA;i++) for(int j=0;j<dimA;j++){ cd acc(0,0);
            for(int a=0;a<dimA;a++) acc += xt[(size_t)i*dimA+a]*rV[(size_t)a*dimA+j]; xt2[(size_t)i*dimA+j]=acc; }
        // distance from complex span{c1,c2} in HS inner product
        cd p1(0,0), p2(0,0); double nn=nrm*nrm;
        for(size_t k=0;k<xt2.size();k++){ p1 += c1[k]*xt2[k]; p2 += c2[k]*xt2[k]; }
        p1/=nn; p2/=nn;
        double res2=0;
        for(size_t k=0;k<xt2.size();k++){ cd r = xt2[k] - p1*c1[k] - p2*c2[k]; res2 += std::norm(r); }
        double viol_fock = std::sqrt(res2)/nrm;
        // Gaussian: || (1-P_V) U(t') e_local1 ||, matching direction resolved by taking the min over
        // both signs pairing (the oracle pins |value|; sign pairing asserted by requiring BOTH t and -t
        // to match one of the two Gaussian directions consistently)
        // GENERATOR-level Gaussian leak: probe is c(e_1), so the Fock residual equals |<e_0|U(t')e_1>|
        // (the single matrix element), NOT the row norm (that is the subspace functional).
        double vg_p = 0, vg_m = 0;
        { double a1r=0,a1i=0;
          for(int i=0;i<n;i++){
              double w0=M.W[(size_t)i*n+0], w1=M.W[(size_t)i*n+1];
              a1r += w0*std::cos(M.lam[i]*t)*w1; a1i += w0*std::sin(M.lam[i]*t)*w1;
          }
          vg_p = std::sqrt(a1r*a1r+a1i*a1i);
          a1r=a1i=0;
          for(int i=0;i<n;i++){
              double w0=M.W[(size_t)i*n+0], w1=M.W[(size_t)i*n+1];
              a1r += w0*std::cos(-M.lam[i]*t)*w1; a1i += w0*std::sin(-M.lam[i]*t)*w1;
          }
          vg_m = std::sqrt(a1r*a1r+a1i*a1i);
        }
        double err = std::min(std::fabs(viol_fock - vg_p), std::fabs(viol_fock - vg_m));
        fprintf(stderr,"  [oracle] t=%+.2f  fock=%.12f  gauss(+)=%.12f  gauss(-)=%.12f  err=%.3e\n",
                t, viol_fock, vg_p, vg_m, err);
        maxerr = std::max(maxerr, err);
    }
    return maxerr;
}

// ------------------------------------------------------------------ selftest
static bool st(const char* nm, bool ok){ return st_check(nm, ok); }
static int run_selftest(){
    bool ok=true; fprintf(stderr,"hsmi-stab --selftest (v%s)\n",HSMI_VERSION);
    ok &= st("blake2b-256(\"abc\") KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // covariance sanity: pure global state => C is a projector (C^2=C) at small L
    { int L=8; std::vector<double> h,C; build_h(h,L,0,0.0,0); ground_cov(h,L,C);
      double err=0; for(int i=0;i<L;i++) for(int j=0;j<L;j++){ double acc=0;
          for(int k=0;k<L;k++) acc += C[(size_t)i*L+k]*C[(size_t)k*L+j];
          err = std::max(err, std::fabs(acc - C[(size_t)i*L+j])); }
      ok &= st("global covariance is a projector (C^2=C, err<1e-10)", err<1e-10); }
    // THE FOCK ORACLE (pins the Gaussian engine's conventions against an independent path)
    { double e_err=0; double merr = fock_oracle_max_err(&e_err);
      ok &= st("Fock oracle: many-body ground energy == sum of negative modes (<1e-9)", e_err<1e-9);
      ok &= st("Fock oracle: exact modular violation == Gaussian engine (<1e-8, 2 t's x 2 dirs)", merr<1e-8); }
    // the arrow at the locus (n=32): contained direction much smaller than violating direction
    { Params P; P.sites=32; P.shift=1; P.t_points=64; P.t_max=6.283185; P.seed=0; P.seed_set=true;
      DeltaPair D = deltas_at_eps(P, 0.0);
      ok &= st("locus arrow exists (delta_plus/delta_minus > 3 at n=32)", D.dplus > 3.0*D.dminus); }
    // continuum anchor: delta_minus falls as n doubles; delta_plus stays O(1)
    { Params P32; P32.sites=32; P32.shift=1; P32.t_points=64; P32.seed=0; P32.seed_set=true;
      Params P64=P32; P64.sites=64;
      DeltaPair a = deltas_at_eps(P32,0.0), b = deltas_at_eps(P64,0.0);
      ok &= st("continuum anchor: delta_minus(n=64) < delta_minus(n=32)", b.dminus < a.dminus);
      ok &= st("continuum anchor: delta_plus stays O(1) (within x2)", b.dplus > 0.5*a.dplus && b.dplus < 2.0*a.dplus); }
    // negative control: seeded random subspace shows O(1) violation BOTH directions (no arrow)
    { int n=32; Params P; P.sites=n; P.shift=1; P.t_points=64; P.seed=0; P.seed_set=true;
      std::vector<double> hh,CC; build_h(hh,2*n,0,0.0,0); ground_cov(hh,2*n,CC);
      Modular M = modular_of(CC,2*n,n);
      // random orthogonal Q via seeded Gram-Schmidt (fixed order)
      std::vector<double> Q((size_t)n*n);
      for(int c=0;c<n;c++){
          for(int r2=0;r2<n;r2++) Q[(size_t)c*n+r2] = counter_gauss(424242,(uint64_t)c,(uint64_t)r2,7);
          for(int p=0;p<c;p++){ double d=0; for(int r2=0;r2<n;r2++) d+=Q[(size_t)p*n+r2]*Q[(size_t)c*n+r2];
              for(int r2=0;r2<n;r2++) Q[(size_t)c*n+r2]-=d*Q[(size_t)p*n+r2]; }
          double nn=0; for(int r2=0;r2<n;r2++) nn+=Q[(size_t)c*n+r2]*Q[(size_t)c*n+r2];
          nn=std::sqrt(nn); for(int r2=0;r2<n;r2++) Q[(size_t)c*n+r2]/=nn; }
      std::vector<double> Qp(Q.begin(), Q.begin()+n);                       // first column = complement (s=1)
      std::vector<double> Qn(Q.begin()+n, Q.end());                         // remaining n-1 columns
      double dp = viol_dir(M,+1.0,P.t_max,P.t_points,&Qn,&Qp,1);
      double dm = viol_dir(M,-1.0,P.t_max,P.t_points,&Qn,&Qp,1);
      double lo=std::min(dp,dm), hi=std::max(dp,dm);
      ok &= st("negative control: random subspace O(1) violation both dirs, no arrow (lo>0.2, hi/lo<2)",
               lo>0.2 && hi < 2.0*lo); }
    // determinism: small config declared object identical 2x (mass + noise)
    { Params P; P.sites=24; P.shift=1; P.eps_points=3; P.t_points=32; P.seed=7; P.seed_set=true;
      std::string a,b; run_config(P,false,&a); run_config(P,false,&b);
      Params Q2=P; Q2.family=1; std::string c,d; run_config(Q2,false,&c); run_config(Q2,false,&d);
      ok &= st("declared object identical across two runs (mass and noise families)", a==b && c==d); }
    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n"); return ok?0:1;
}

// ------------------------------------------------------------------ CLI
static long long p_ll(const char* s2,const char* f){ return parse_ll(s2,f); }
static double p_d(const char* s2,const char* f){ return parse_d(s2,f); }

int main(int argc,char** argv){
    Params P;
    for(int i=1;i<argc;i++){ std::string a=argv[i];
        auto val=[&](const char* f)->const char*{ if(i+1>=argc) die2(std::string("missing value for ")+f); return argv[++i]; };
        if(a=="--sites") P.sites=(int)p_ll(val("--sites"),"--sites");
        else if(a=="--shift") P.shift=(int)p_ll(val("--shift"),"--shift");
        else if(a=="--family"){ std::string v=val("--family"); if(v=="mass")P.family=0; else if(v=="noise")P.family=1; else die2("bad --family (mass|noise): "+v); }
        else if(a=="--eps-max") P.eps_max=p_d(val("--eps-max"),"--eps-max");
        else if(a=="--eps-points") P.eps_points=(int)p_ll(val("--eps-points"),"--eps-points");
        else if(a=="--t-max") P.t_max=p_d(val("--t-max"),"--t-max");
        else if(a=="--t-points") P.t_points=(int)p_ll(val("--t-points"),"--t-points");
        else if(a=="--k-min") P.k_min=p_d(val("--k-min"),"--k-min");
        else if(a=="--snap-frac") P.snap_frac=p_d(val("--snap-frac"),"--snap-frac");
        else if(a=="--arrow-min") P.arrow_min=p_d(val("--arrow-min"),"--arrow-min");
        else if(a=="--seed"){ P.seed=p_ll(val("--seed"),"--seed"); P.seed_set=true; }
        else if(a=="--json") P.json=true;
        else if(a=="--csv"){ P.csv=true; P.csv_path=val("--csv"); }
        else if(a=="--selftest") P.selftest=true;
        else if(a=="--golden") P.golden=true;
        else die2("unknown flag: "+a);
    }
    if(P.selftest) return run_selftest();
    if(P.golden)   return run_golden();
    if(getenv("HSMI_PROBE") && atoi(getenv("HSMI_PROBE"))==7){   // v1.1 WITNESS probe (Q-001 ruling): winding/index
        // M(t) = P_N U(t) P_N; bulk symbol phi(theta) = sum_d M[j0][j0+d] e^{i d theta} from the
        // center row; winding(phi) = the finite shadow of the Fredholm index of the half-infinite
        // compression; gap = min|phi|. T-invariant k (real symmetric) => U complex-symmetric =>
        // phi(theta)=phi(-theta) => winding == 0 BY T-INVARIANCE. Sign of winding = the arrow.
        auto run7 = [&](const char* tag, const std::vector<cd>& CA, int n, int s, double t){
            ModularC M = modular_of_c(CA, n);
            int m2 = n - s;
            // U(t) block [s..,s..]: U_{xy} = sum_i W[x,i] e^{i lam_i t} conj(W[y,i])
            std::vector<cd> Ub((size_t)m2*m2, cd(0,0));
            for(int i=0;i<n;i++){
                cd ph = std::polar(1.0, M.lam[i]*t);
                for(int x=0;x<m2;x++){
                    cd f = M.W[(size_t)i*n+(s+x)]*ph;
                    if(f==cd(0,0)) continue;
                    for(int y=0;y<m2;y++) Ub[(size_t)x*m2+y] += f*std::conj(M.W[(size_t)i*n+(s+y)]);
                }
            }
            int j0 = m2/2, D = std::min(16, j0-1);
            const int K = 512;
            double wind = 0, gmin = 1e300, gmax = 0;
            cd prev(0,0);
            for(int k2=0;k2<=K;k2++){
                double th = 2.0*HS_PI*k2/K;
                cd ph2(0,0);
                for(int d=-D; d<=D; d++)
                    ph2 += Ub[(size_t)j0*m2 + (j0+d)] * std::polar(1.0, d*th);
                gmin = std::min(gmin, std::abs(ph2)); gmax = std::max(gmax, std::abs(ph2));
                if(k2>0){ double da = std::arg(ph2/prev); wind += da; }
                prev = ph2;
            }
            wind /= 2.0*HS_PI;
            fprintf(stderr,"%s n=%3d t=%+.4f  winding=%+.3f  gap=%.3e  max|phi|=%.3f%s\n",
                    tag, n, t, wind, gmin, gmax, gmin<1e-6? "  [GAP~0: winding ill-defined]" : "");
        };
        for(int n : {32, 128}){
            std::vector<cd> CA; build_chiral_window(4*n, n, CA);
            for(double tt : {0.005, 0.01, 0.02, 0.05, 0.1, 0.2}){ run7("chiral", CA, n, 1, +tt); run7("chiral", CA, n, 1, -tt); }
            fprintf(stderr,"\n");
        }
        for(int n : {32, 128}){
            int L=2*n; std::vector<double> h,C; build_h(h,L,0,0.0,0); ground_cov(h,L,C);
            std::vector<cd> CA((size_t)n*n);
            for(int c=0;c<n;c++) for(int r=0;r<n;r++) CA[(size_t)c*n+r] = cd(C[(size_t)(n+r)*L+(n+c)],0.0);
            for(double tt : {0.01, 0.05, 0.1, 0.2}){ run7("t-inv ", CA, n, 1, +tt); run7("t-inv ", CA, n, 1, -tt); }
        }
        return 0;
    }
    if(getenv("HSMI_PROBE") && atoi(getenv("HSMI_PROBE"))==6){   // v1.1 FUNCTIONAL probe: many-body Borchers positivity
        // Wiesbrock criterion verbatim: hsm <=> K_A - K_N = 2 pi P >= 0 (MANY-BODY, constants included).
        // minspec(K_A - K_N) = c0 + sum_{mu<0} mu, with mu = eig(k_A - k_N(+)0) and
        // c0 = sum_A log(1+e^{-lam}) - sum_N log(1+e^{-lam}) (the -log Z normalizations).
        auto run6 = [&](const char* tag, const std::vector<cd>& CA, int n, int s){
            ModularC MA = modular_of_c(CA, n);
            std::vector<cd> KA; kmat_from(MA, KA);
            int m2=n-s;
            std::vector<cd> CN((size_t)m2*m2);
            for(int c=0;c<m2;c++) for(int r=0;r<m2;r++) CN[(size_t)c*m2+r] = CA[(size_t)(s+c)*n+(s+r)];
            ModularC MN = modular_of_c(CN, m2);
            std::vector<cd> KNs; kmat_from(MN, KNs);
            std::vector<cd> B((size_t)n*n);
            for(int c=0;c<n;c++) for(int r=0;r<n;r++){
                cd kn = (r>=s&&c>=s)? KNs[(size_t)(c-s)*m2+(r-s)] : cd(0,0);
                B[(size_t)c*n+r] = KA[(size_t)c*n+r] - kn;
            }
            std::vector<double> mu; zheevd_host(n, B, mu);
            double negs=0, poss=0; for(int i=0;i<n;i++){ if(mu[i]<0) negs+=mu[i]; else poss+=mu[i]; }
            double c0=0;
            for(int i=0;i<n;i++)  c0 += std::log(1.0+std::exp(-MA.lam[i]));
            for(int j=0;j<m2;j++) c0 -= std::log(1.0+std::exp(-MN.lam[j]));
            double msp = c0 + negs;                                  // minspec(K_A - K_N)
            double msm = -c0 - poss;                                 // minspec(K_N - K_A)
            fprintf(stderr,"%s n=%3d s=%d  c0=%+.4f negs=%+.4f poss=%+.4f | minspec(KA-KN)=%+.4f minspec(KN-KA)=%+.4f ratio=%.2f\n",
                    tag, n, s, c0, negs, poss, msp, msm,
                    std::min(std::fabs(msp),std::fabs(msm))>1e-12 ? std::max(std::fabs(msp),std::fabs(msm))/std::min(std::fabs(msp),std::fabs(msm)) : 1e12);
        };
        for(int n : {16, 32, 64, 128}){ std::vector<cd> CA; build_chiral_window(4*n, n, CA); run6("chiral", CA, n, 1); }
        for(int n : {16, 32, 64, 128}){
            int L=2*n; std::vector<double> h,C; build_h(h,L,0,0.0,0); ground_cov(h,L,C);
            std::vector<cd> CA((size_t)n*n);
            for(int c=0;c<n;c++) for(int r=0;r<n;r++) CA[(size_t)c*n+r] = cd(C[(size_t)(n+r)*L+(n+c)],0.0);
            run6("t-inv ", CA, n, 1);
        }
        return 0;
    }
    if(getenv("HSMI_PROBE") && atoi(getenv("HSMI_PROBE"))==5){   // v1.1 FUNCTIONAL probe: directional transport element
        // |<e_0|U(t)|e_1>|: mode-referenced (NOT unitarily invariant) => no blindness identity applies.
        // The modular flow's transport from the boundary N-mode into the dropped mode, per direction.
        auto run5 = [&](const char* tag, const std::vector<cd>& CA, int n){
            ModularC M = modular_of_c(CA, n);
            fprintf(stderr,"%s n=%3d  t:", tag, n);
            double dp=0, dm=0;
            for(double t : {0.05,0.1,0.2,0.4,0.8,1.6,3.2}){
                cd ap(0,0), am(0,0);
                for(int i=0;i<n;i++){
                    cd w0 = M.W[(size_t)i*n+0], w1c = std::conj(M.W[(size_t)i*n+1]);
                    ap += w0*std::polar(1.0, M.lam[i]*t)*w1c;
                    am += w0*std::polar(1.0,-M.lam[i]*t)*w1c;
                }
                dp=std::max(dp,std::abs(ap)); dm=std::max(dm,std::abs(am));
                fprintf(stderr," [%.2f %+.4f/%+.4f]", t, std::abs(ap), std::abs(am));
            }
            fprintf(stderr,"\n%s n=%3d  max+=%.6f max-=%.6f asym=%.4f\n", tag, n, dp, dm,
                    std::max(dp,dm)/std::max(1e-300,std::min(dp,dm)));
        };
        for(int n : {32, 128}){ std::vector<cd> CA; build_chiral_window(4*n, n, CA); run5("chiral", CA, n); }
        for(int n : {32, 128}){
            int L=2*n; std::vector<double> h,C; build_h(h,L,0,0.0,0); ground_cov(h,L,C);
            std::vector<cd> CA((size_t)n*n);
            for(int c=0;c<n;c++) for(int r=0;r<n;r++) CA[(size_t)c*n+r] = cd(C[(size_t)(n+r)*L+(n+c)],0.0);
            run5("t-inv ", CA, n);
        }
        return 0;
    }
    if(getenv("HSMI_PROBE") && atoi(getenv("HSMI_PROBE"))==4){   // v1.1 FUNCTIONAL probe: ax+b commutator witness
        // true +/-hsm: [K_A, K_N] = -/+ 2 pi i (K_N - K_A). Constants drop out of commutators;
        // orientation IS the sign. J-conjugation maps R+ <-> R- for a REAL k (T-invariant control).
        auto run = [&](const char* tag, const std::vector<cd>& CA, int n, int s){
            ModularC MA = modular_of_c(CA, n);
            std::vector<cd> KA; kmat_from(MA, KA);
            int m2 = n - s;
            std::vector<cd> CN((size_t)m2*m2);
            for(int c=0;c<m2;c++) for(int r=0;r<m2;r++) CN[(size_t)c*m2+r] = CA[(size_t)(s+c)*n+(s+r)];
            ModularC MN = modular_of_c(CN, m2);
            std::vector<cd> KNs; kmat_from(MN, KNs);
            std::vector<cd> KN((size_t)n*n, cd(0,0));                 // embed k_N (+0 on the dropped modes)
            for(int c=0;c<m2;c++) for(int r=0;r<m2;r++) KN[(size_t)(s+c)*n+(s+r)] = KNs[(size_t)c*m2+r];
            std::vector<cd> Cm((size_t)n*n, cd(0,0)), D((size_t)n*n); // Cm=[KA,KN], D=KN-KA
            for(int c=0;c<n;c++) for(int r=0;r<n;r++){
                cd acc(0,0);
                for(int a2=0;a2<n;a2++)
                    acc += KA[(size_t)a2*n+r]*KN[(size_t)c*n+a2] - KN[(size_t)a2*n+r]*KA[(size_t)c*n+a2];
                Cm[(size_t)c*n+r]=acc;
                D[(size_t)c*n+r]=KN[(size_t)c*n+r]-KA[(size_t)c*n+r];
            }
            const double TP=2.0*HS_PI;
            double np=0, nm=0, ncm=0, nd=0;
            for(size_t k2=0;k2<Cm.size();k2++){
                cd rp = Cm[k2] - cd(0,TP)*D[k2];                      // R+ = [KA,KN] - 2 pi i (KN-KA)
                cd rm = Cm[k2] + cd(0,TP)*D[k2];
                np += std::norm(rp); nm += std::norm(rm); ncm += std::norm(Cm[k2]); nd += std::norm(D[k2]);
            }
            np=std::sqrt(np); nm=std::sqrt(nm); ncm=std::sqrt(ncm); nd=TP*std::sqrt(nd);
            // Frobenius is provably blind (tr(Cm D)=0 by cyclicity) -- print it as the identity check;
            // the discriminator is the SPECTRUM of the Hermitian pair H+- = i[KA,KN] +- 2pi(KN-KA)
            // (for a true -/+hsm one of them is EXACTLY zero; only even moments are forced equal).
            std::vector<cd> Hp((size_t)n*n), Hm((size_t)n*n);
            for(int c=0;c<n;c++) for(int r=0;r<n;r++){
                cd ic = cd(0,1)*Cm[(size_t)c*n+r];
                Hp[(size_t)c*n+r] = ic + cd(TP,0)*D[(size_t)c*n+r];
                Hm[(size_t)c*n+r] = ic - cd(TP,0)*D[(size_t)c*n+r];
            }
            std::vector<double> wp, wm;
            zheevd_host(n, Hp, wp); zheevd_host(n, Hm, wm);
            double op_p = std::max(std::fabs(wp[0]), std::fabs(wp[n-1]));
            double op_m = std::max(std::fabs(wm[0]), std::fabs(wm[n-1]));
            double t3p=0, t3m=0; for(int i2=0;i2<n;i2++){ t3p += wp[i2]*wp[i2]*wp[i2]; t3m += wm[i2]*wm[i2]*wm[i2]; }
            fprintf(stderr,"%s n=%3d s=%d  frob: |R+|=%.4f |R-|=%.4f ratio=%.4f | op: |H+|=%.4f |H-|=%.4f ratio=%.4f"
                           " | tr(H^3): +%.3e / %.3e  (|[.,.]|=%.3f 2pi|D|=%.3f)\n",
                    tag, n, s, np, nm, std::max(np,nm)/std::min(np,nm),
                    op_p, op_m, std::max(op_p,op_m)/std::min(op_p,op_m),
                    t3p, t3m, ncm, nd);
        };
        for(int n : {16, 32, 64, 128}){ std::vector<cd> CA; build_chiral_window(4*n, n, CA); run("chiral", CA, n, 1); }
        for(int n : {16, 32, 64, 128}){
            int L=2*n; std::vector<double> h,C; build_h(h,L,0,0.0,0); ground_cov(h,L,C);
            std::vector<cd> CA((size_t)n*n);
            for(int c=0;c<n;c++) for(int r=0;r<n;r++) CA[(size_t)c*n+r] = cd(C[(size_t)(n+r)*L+(n+c)],0.0);
            run("t-inv ", CA, n, 1);
        }
        return 0;
    }
    if(getenv("HSMI_PROBE") && atoi(getenv("HSMI_PROBE"))==3){   // v1.1 FUNCTIONAL probe: Borchers generator G
        // G = (k_window - k_subwindow)/2pi; true hsm <=> G >= 0 (Wiesbrock). delta_minus ~ negative part.
        for(int n : {16, 32, 64, 128}){
            std::vector<cd> CA; build_chiral_window(4*n, n, CA);
            probe_G_of("chiral", CA, n, 1);
        }
        for(int n : {16, 32, 64, 128}){                          // T-invariant control: expect negsum==possum
            int L=2*n; std::vector<double> h,C; build_h(h,L,0,0.0,0); ground_cov(h,L,C);
            std::vector<cd> CA((size_t)n*n);
            for(int c=0;c<n;c++) for(int r=0;r<n;r++) CA[(size_t)c*n+r] = cd(C[(size_t)(n+r)*L+(n+c)],0.0);
            probe_G_of("t-inv ", CA, n, 1);
        }
        for(int n : {32, 64}){                                   // shift=2 on the chiral model
            std::vector<cd> CA; build_chiral_window(4*n, n, CA);
            probe_G_of("chir-2", CA, n, 2);
        }
        return 0;
    }
    if(getenv("HSMI_PROBE") && atoi(getenv("HSMI_PROBE"))==2){   // v1.1 model probe: chiral log-lattice
        for(double a : {0.25, 0.5, 1.0}){
            for(int m : {32, 64, 128, 256}){
                std::vector<cd> C; build_chiral_CA(m, a, C);
                ModularC M = modular_of_c(C, m);
                double spill = std::max(-(M.min_c), M.max_c - 1.0);
                fprintf(stderr,"a=%.2f m=%3d  min_c=%+.3e  1-max_c=%+.3e  spill=%+.3e\n   t: ",
                        a, m, M.min_c, 1.0-M.max_c, spill);
                double dp=0,dm=0;
                for(double t : {0.05,0.1,0.2,0.4,0.8,1.6,3.2,6.4,12.8}){
                    double vp=viol_at_c(M,+t,1), vm=viol_at_c(M,-t,1);
                    dp=std::max(dp,vp); dm=std::max(dm,vm);
                    fprintf(stderr,"[%.2f +%.4f -%.4f] ", t, vp, vm);
                }
                fprintf(stderr,"\n   dplus=%.6f dminus=%.6f arrow=%.2f\n",
                        std::max(dp,dm), std::min(dp,dm),
                        std::min(dp,dm)>0 ? std::max(dp,dm)/std::min(dp,dm) : 1e12);
            }
        }
        return 0;
    }
    if(getenv("HSMI_PROBE")){                      // TEMPORARY build-session probe (not in the contract)
        for(int n : {32, 64, 128}){
            Params Q; Q.sites=n; Q.shift=1; Q.t_points=2; Q.seed=0; Q.seed_set=true;
            std::vector<double> hh,CC; build_h(hh,2*n,0,0.0,0); ground_cov(hh,2*n,CC);
            Modular M = modular_of(CC,2*n,n);
            fprintf(stderr,"n=%d  t: ", n);
            for(double t : {0.05,0.1,0.2,0.4,0.8,1.6,3.2,6.28}){
                double vp = viol_at(M,+t,nullptr,nullptr,1), vm = viol_at(M,-t,nullptr,nullptr,1);
                fprintf(stderr,"[t=%.2f +%.4f -%.4f] ", t, vp, vm);
            }
            fprintf(stderr,"\n");
        }
        return 0;
    }
    if(P.sites<8||P.sites>2048)          die2("--sites out of range [8,2048]");
    if(P.shift<1||P.shift>P.sites/4)     die2("--shift out of range [1,sites/4]");
    if(!(P.eps_max>0.0&&P.eps_max<=0.5)) die2("--eps-max out of range (0,0.5]");
    if(P.eps_points<3||P.eps_points>64)  die2("--eps-points out of range [3,64]");
    if(!(P.t_max>0.0&&P.t_max<=20.0))    die2("--t-max out of range (0,20]");
    if(P.t_points<8||P.t_points>512)     die2("--t-points out of range [8,512]");
    if(P.k_min<0.0||P.k_min>8.0)         die2("--k-min out of range [0,8]");
    if(!(P.snap_frac>0.0&&P.snap_frac<=1.0)) die2("--snap-frac out of range (0,1]");
    if(P.arrow_min<1.0)                  die2("--arrow-min must be >= 1");
    if(!P.seed_set)                      die2("--seed is required (>=0)");
    if(P.seed<0)                         die2("--seed must be >=0");
    if(!P.json && !P.csv)                P.json=true;
    return run_config(P,true,nullptr);
}
