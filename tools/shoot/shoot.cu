// shoot.cu — ORRERY tool `shoot` (v1.0.0)
// Headless, deterministic ODE-shooting eigenvalue solver (TinyUniverse R-6; D-032).
// Contract: contracts/shoot.contract.md (+ shoot.schema.json). Contract is authoritative.
//
// Solves the 1D Schrodinger / Sturm-Liouville eigenvalue problem  psi'' = 2(V(x)-E) psi  by the
// shooting method (fixed-step fp64 RK4 + scan/bisect on E for psi->0 at both ends). Built-in potentials
// have EXACT analytic spectra (the I-11 oracle): harmonic (E_j=j+1/2), square well (E_j=(j+1)^2 pi^2/2L^2).
// Measures the SPECTRUM of a linear differential operator (structure/mathematics); says nothing about
// qualia. III-sealed. Host C++ (no GPU kernel in v1); deterministic (no RNG, no transcendentals in the
// declared path). The reusable eigenvalue core the leverage suite (hsmi-stab/trace-born/carve) consumes.
//
// Build (from tools/shoot/, see MODULE.md):
//   cmd /c '"...\vcvars64.bat" >nul 2>&1 && nvcc -O3 -arch=sm_89 shoot.cu ../../lib/envelope.cpp -o shoot.exe'
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <utility>
#include "../../lib/envelope.h"   // blake2b, fmt6/fmti/jesc, golden plumbing, CLI spine (D-020)
using namespace orrery;

static const char* SHOOT_VERSION = "1.0.0";
static const char* FIREWALL =
    "This measures the spectrum of a linear differential operator (structure/mathematics); it says "
    "nothing about whether anything feels (acquaintance) - III-sealed.";
static const double PI = 3.14159265358979323846;

// ------------------------------------------------------------------ params / result
struct Params {
    std::string potential = "harmonic";  // harmonic | square
    int levels = 6;
    double xmax = 8.0;
    double length = PI;
    int steps = 4000;
    double tol = 1e-4;
    long long seed = 0;
    bool json=false, csv=false, selftest=false, golden=false; std::string csv_path;
};
struct Result {
    std::vector<double> eigenvalues, oracles, rel_errs;
    std::vector<int> node_counts;
    double max_rel_err = 0.0;
    bool g_mismatch=false;
};

// ------------------------------------------------------------------ potential V(x)  (0=harmonic, 1=square)
static inline double Vpot(int code, double x){ return code==0 ? 0.5*x*x : 0.0; }

// integrate psi''=2(V-E)psi from x0 with psi=0, psi'=1 across `steps`; return endpoint psi (rescaled;
// only its SIGN is used) and the interior node count. Overflow-safe via positive magnitude rescale.
struct ShootOut { double psi_end; int nodes; };
static ShootOut shoot_endpoint(double E, const Params& P, int code){
    double x0, x1;
    if(code==0){ x0=-P.xmax; x1=P.xmax; } else { x0=0.0; x1=P.length; }
    const double h=(x1-x0)/(double)P.steps;
    double p=0.0, q=1.0, x=x0, prev=p; int nodes=0;
    for(int i=0;i<P.steps;i++){
        double k1p=q,                     k1q=2.0*(Vpot(code,x)-E)*p;
        double k2p=q+0.5*h*k1q,           k2q=2.0*(Vpot(code,x+0.5*h)-E)*(p+0.5*h*k1p);
        double k3p=q+0.5*h*k2q,           k3q=2.0*(Vpot(code,x+0.5*h)-E)*(p+0.5*h*k2p);
        double k4p=q+h*k3q,               k4q=2.0*(Vpot(code,x+h)-E)*(p+h*k3p);
        p += (h/6.0)*(k1p+2.0*k2p+2.0*k3p+k4p);
        q += (h/6.0)*(k1q+2.0*k2q+2.0*k3q+k4q);
        x += h;
        if(prev!=0.0 && p!=0.0 && ((prev<0.0)!=(p<0.0))){          // interior node (sign change)
            // count only in the classically-allowed region (|x| < turning point); the exponentially-small
            // forbidden tails carry numerical sign-wiggles that are not physical nodes.
            // harmonic: only inside the turning point; square: exclude the wall zero at x=L (a boundary
            // condition, not an interior node) via a hair below L.
            double xlim = (code==0) ? sqrt(2.0*(E>0.0?E:0.0))+1.0 : 0.999*P.length;
            if(fabs(x) < xlim) nodes++;
        }
        double m = fabs(p)>fabs(q) ? fabs(p) : fabs(q);
        if(m>1e6){ p/=m; q/=m; }                                    // rescale (sign-preserving)
        prev = p;
    }
    return { p, nodes };
}

static double oracle_of(const Params& P, int code, int j){
    if(code==0) return (double)j + 0.5;                             // harmonic: E_j = j + 1/2
    double n = (double)(j+1);                                       // square: E_j = (j+1)^2 pi^2 / (2 L^2)
    return n*n*PI*PI/(2.0*P.length*P.length);
}

// scan E with fixed dE, bracket sign flips of psi_end, bisect (fixed iters) -> eigenvalues (ascending).
// Returns false if fewer than `levels` eigenvalues were bracketed in the domain (-> exit 2).
static bool find_eigs(const Params& P, int code, Result& R){
    const double dE = 0.1;
    const double Elo = 0.02;
    const double Ecap = oracle_of(P, code, P.levels) * 1.25 + 2.0;  // one past the last needed level
    ShootOut a = shoot_endpoint(Elo, P, code);
    double Eprev=Elo, sprev=a.psi_end;
    int found=0;
    for(double E=Elo+dE; found<P.levels && E<=Ecap; E+=dE){
        ShootOut b = shoot_endpoint(E, P, code);
        if((sprev<0.0)!=(b.psi_end<0.0)){                           // eigenvalue in (Eprev, E)
            double lo=Eprev, hi=E, slo=sprev;
            for(int it=0; it<80; it++){
                double mid=0.5*(lo+hi); ShootOut m=shoot_endpoint(mid,P,code);
                if((slo<0.0)!=(m.psi_end<0.0)) hi=mid; else { lo=mid; slo=m.psi_end; }
            }
            double Eeig=0.5*(lo+hi); ShootOut fe=shoot_endpoint(Eeig,P,code);
            R.eigenvalues.push_back(Eeig); R.node_counts.push_back(fe.nodes);
            found++;
        }
        Eprev=E; sprev=b.psi_end;
    }
    return found==P.levels;
}

// ------------------------------------------------------------------ run -> Result
static bool run_shoot(const Params& P, Result& R){
    int code = (P.potential=="harmonic") ? 0 : 1;
    if(!find_eigs(P, code, R)) return false;
    R.max_rel_err = 0.0;
    for(int j=0;j<P.levels;j++){
        double orc = oracle_of(P, code, j);
        R.oracles.push_back(orc);
        double re = fabs(R.eigenvalues[j]-orc)/fabs(orc);
        R.rel_errs.push_back(re);
        if(re>R.max_rel_err) R.max_rel_err=re;
    }
    R.g_mismatch = (R.max_rel_err > P.tol);
    return true;
}

// ------------------------------------------------------------------ serialize (declared body + envelope)
static std::string darr(const std::vector<double>& v){ std::string s="["; for(size_t i=0;i<v.size();i++){ if(i)s+=","; s+=fmt6(v[i]); } return s+"]"; }
static std::string iarr(const std::vector<int>& v){ std::string s="["; for(size_t i=0;i<v.size();i++){ if(i)s+=","; s+=fmti(v[i]); } return s+"]"; }
static std::string params_json(const Params& P){
    return "{\"potential\":\""+P.potential+"\",\"levels\":"+fmti(P.levels)+",\"xmax\":"+fmt6(P.xmax)
         + ",\"length\":"+fmt6(P.length)+",\"steps\":"+fmti(P.steps)+",\"tol\":"+fmt6(P.tol)+"}";
}
static std::string result_json(const Params& P, const Result& R){
    return "{\"potential\":\""+P.potential+"\",\"levels\":"+fmti(P.levels)+",\"xmax\":"+fmt6(P.xmax)
         + ",\"length\":"+fmt6(P.length)+",\"steps\":"+fmti(P.steps)
         + ",\"eigenvalues\":"+darr(R.eigenvalues)+",\"oracles\":"+darr(R.oracles)
         + ",\"rel_errs\":"+darr(R.rel_errs)+",\"max_rel_err\":"+fmt6(R.max_rel_err)
         + ",\"node_counts\":"+iarr(R.node_counts)+"}";
}
static std::string gates_json(const Params& P, const Result& R){
    return std::string("[{\"id\":\"G-ORACLE-MISMATCH\",\"fired\":")+(R.g_mismatch?"true":"false")
         + ",\"value\":"+fmt6(R.max_rel_err)+",\"threshold\":"+fmt6(P.tol)+"}]";
}
static std::string declared_body(const Params& P, const Result& R, const std::string& v){
    return "\"seed\":"+fmti(P.seed)+",\"params\":"+params_json(P)+",\"result\":"+result_json(P,R)
         + ",\"gates\":"+gates_json(P,R)+",\"verdict\":\""+v+"\"";
}
static std::string declared_object(const Params& P, const Result& R, const std::string& v){ return "{"+declared_body(P,R,v)+"}"; }
static std::string full_envelope(const Params& P, const Result& R, const std::string& v){
    return orrery::full_envelope("shoot", SHOOT_VERSION, declared_body(P,R,v), FIREWALL);
}

// ------------------------------------------------------------------ run one config (print + exit code)
static int run_config(const Params& P, bool do_print, std::string* declared_out){
    Result R;
    if(!run_shoot(P, R)) die2("scan failed to bracket --levels eigenvalues in the domain (raise --xmax / lower --levels)");
    std::string verdict = R.g_mismatch ? "fail" : "pass";
    if(declared_out) *declared_out = declared_object(P,R,verdict);
    if(do_print){
        if(P.csv){
            FILE* f=fopen(P.csv_path.c_str(),"wb");
            if(!f){ fprintf(stderr,"error: cannot open --csv path: %s\n",P.csv_path.c_str()); std::exit(2); }
            fprintf(f,"level,eigenvalue,oracle,rel_err,node_count\n");
            for(int j=0;j<P.levels;j++) fprintf(f,"%d,%.10f,%.10f,%.3e,%d\n",j,R.eigenvalues[j],R.oracles[j],R.rel_errs[j],R.node_counts[j]);
            fclose(f);
        }
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str());
    }
    return R.g_mismatch ? 1 : 0;
}

// ------------------------------------------------------------------ golden
static Params golden_params(){
    Params P; P.potential="harmonic"; P.levels=6; P.xmax=8.0; P.steps=4000; P.tol=1e-4; P.seed=0; P.json=true; return P;
}
static int run_golden(){
    Params P=golden_params(); Result R; if(!run_shoot(P,R)) { fprintf(stderr,"golden: scan failed\n"); return 2; }
    std::string verdict = R.g_mismatch?"fail":"pass";
    return golden_check("shoot", declared_object(P,R,verdict), full_envelope(P,R,verdict));
}

// ------------------------------------------------------------------ selftest
static bool st(const char* n, bool ok){ return st_check(n,ok); }
static int run_selftest(){
    bool ok=true; fprintf(stderr,"shoot --selftest (v%s)\n",SHOOT_VERSION);
    ok &= st("blake2b-256(\"\") KAT", blake2b_hex("")=="0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8");
    ok &= st("blake2b-256(\"abc\") KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // oracle formulas
    { Params P; P.potential="harmonic"; ok &= st("harmonic oracle E_0=0.5", fabs(oracle_of(P,0,0)-0.5)<1e-12);
      ok &= st("harmonic oracle E_5=5.5", fabs(oracle_of(P,0,5)-5.5)<1e-12); }
    { Params P; P.potential="square"; P.length=PI; ok &= st("square oracle E_0=0.5 (L=pi)", fabs(oracle_of(P,1,0)-0.5)<1e-12);
      ok &= st("square oracle E_1=2.0 (L=pi)", fabs(oracle_of(P,1,1)-2.0)<1e-12); }
    // harmonic spectrum reproduced + node labeling
    { Params P; P.potential="harmonic"; P.levels=6; P.xmax=8.0; P.steps=4000; P.tol=1e-4; Result R;
      ok &= st("harmonic scan found 6 levels", run_shoot(P,R));
      ok &= st("harmonic max_rel_err < 1e-4", R.max_rel_err<1e-4);
      bool nodesok=true; for(int j=0;j<6;j++) if(R.node_counts[j]!=j) nodesok=false;
      ok &= st("harmonic node_counts = [0..5]", nodesok);
      ok &= st("harmonic E_0 ~ 0.5", fabs(R.eigenvalues[0]-0.5)<1e-3); }
    // square well spectrum reproduced
    { Params P; P.potential="square"; P.length=PI; P.levels=4; P.steps=4000; P.tol=1e-4; Result R;
      ok &= st("square scan found 4 levels", run_shoot(P,R));
      ok &= st("square max_rel_err < 1e-4", R.max_rel_err<1e-4);
      bool sn=true; for(int j=0;j<4;j++) if(R.node_counts[j]!=j) sn=false;
      ok &= st("square node_counts = [0..3]", sn); }
    // determinism
    { Params P=golden_params(); std::string a,b; run_config(P,false,&a); run_config(P,false,&b);
      ok &= st("declared identical across 2 runs", a==b); }
    // gate teeth: coarse steps -> mismatch fires (exit 1) at a tight tol
    { Params P; P.potential="harmonic"; P.levels=6; P.xmax=8.0; P.steps=200; P.tol=1e-9; P.json=false;
      ok &= st("G-ORACLE-MISMATCH fires when forced (exit 1)", run_config(P,false,nullptr)==1); }
    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n"); return ok?0:1;
}

// ------------------------------------------------------------------ CLI
int main(int argc,char** argv){
    Params P;
    for(int i=1;i<argc;i++){ std::string a=argv[i];
        auto val=[&](const char* f)->const char*{ if(i+1>=argc) die2(std::string("missing value for ")+f); return argv[++i]; };
        if(a=="--potential") P.potential=val("--potential");
        else if(a=="--levels") P.levels=(int)parse_ll(val("--levels"),"--levels");
        else if(a=="--xmax") P.xmax=parse_d(val("--xmax"),"--xmax");
        else if(a=="--length") P.length=parse_d(val("--length"),"--length");
        else if(a=="--steps") P.steps=(int)parse_ll(val("--steps"),"--steps");
        else if(a=="--tol") P.tol=parse_d(val("--tol"),"--tol");
        else if(a=="--seed") P.seed=parse_ll(val("--seed"),"--seed");
        else if(a=="--json") P.json=true;
        else if(a=="--csv"){ P.csv=true; P.csv_path=val("--csv"); }
        else if(a=="--selftest") P.selftest=true;
        else if(a=="--golden") P.golden=true;
        else die2("unknown flag: "+a);
    }
    if(P.selftest) return run_selftest();
    if(P.golden)   return run_golden();
    if(P.potential!="harmonic" && P.potential!="square") die2("--potential must be harmonic|square");
    if(P.levels<1||P.levels>64)          die2("--levels out of range [1,64]");
    if(!(P.xmax>0.0))                    die2("--xmax must be >0");
    if(!(P.length>0.0))                  die2("--length must be >0");
    if(P.steps<100||P.steps>4000000)     die2("--steps out of range [100,4000000]");
    if(P.tol<0.0)                        die2("--tol must be >=0");
    if(P.seed<0)                         die2("--seed must be >=0");
    if(!P.json && !P.csv) P.json=true;
    return run_config(P,true,nullptr);
}
