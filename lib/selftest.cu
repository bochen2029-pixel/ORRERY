// lib/selftest.cu — liborrery KAT selftest (the library's --selftest; D-020).
//
// Build (from lib/):  see lib/MODULE.md.   Run (from the REPO ROOT):  .\lib\orrery_selftest.exe
// (repo root because the read_golden_hash integration check resolves goldens/<tool>/ from there).
//
// What is pinned here and why it is load-bearing:
//   1. Hash KATs        — blake2b-256 (RFC 7693 vectors) and SHA-256 (FIPS 180-4 vectors): the
//                         golden hasher and the sidecar hasher are proven, not assumed.
//   2. REF CROSS-CHECK  — a verbatim copy of the template's RNG functions (tools/someone v1.1.0)
//                         lives in namespace ref below; lib must equal ref bit-for-bit across a
//                         sweep. This mechanically proves the D-020 extraction is verbatim.
//   3. RNG value KATs   — pinned bit patterns (host AND device SEPARATELY). Ground truth harvested
//                         2026-07-09 on the pinned toolchain (CUDA 13.1, MSVC 2022, sm_89) and
//                         cross-checked against an independent Python computation for the integer/
//                         u01 paths. NOTE: counter_gauss(20260705,7,11,13) differs HOST vs DEVICE
//                         by 1 ULP (MSVC libm vs CUDA libm) — REAL, measured, and pinned on both
//                         sides. Never assert host==device for counter_gauss. The DEVICE pins are
//                         the drift-detector: if a CUDA toolkit update shifts device log/cos, this
//                         selftest fires BEFORE a tool golden silently breaks.
//   4. Reductions       — blockReduceSum/3 vs exact integer-valued sums + bit-stability across
//                         launches; fixed-point atomic accumulator order-invariance (forward vs
//                         reversed thread order vs host integer sum: all three bit-equal).
//   5. Envelope pieces  — fmt6 (-0 normalization), fmti, jesc, declared_object, full_envelope,
//                         read_golden_hash (integration: reads the frozen someone hash), Kahan,
//                         stable_gather_sum, Regime, ckpt round-trip + TAMPER detection, lock writer.

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <string>
#include <vector>
#include <random>
#include "envelope.h"
#include "rng.cuh"
#include "reduce.cuh"
#include "regime.h"
#include "ckpt.h"

static const char* LIB_VERSION = "1.0.0";

// ------------------------------------------------------------------ ref: the template's originals
// VERBATIM from tools/someone/someone.cu v1.1.0 (host side). The cross-check below pins
// orrery::* == ref::* forever; an edit to lib/rng.cuh that drifts from the template fails here.
namespace ref {
inline uint64_t splitmix64(uint64_t x){
    x += 0x9E3779B97F4A7C15ULL;
    x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ULL;
    x = (x ^ (x >> 27)) * 0x94D049BB133111EBULL;
    return x ^ (x >> 31);
}
inline uint64_t hash4(uint64_t a, uint64_t b, uint64_t c, uint64_t d){
    uint64_t h = splitmix64(a);
    h = splitmix64(h ^ (b + 0x9E3779B97F4A7C15ULL));
    h = splitmix64(h ^ (c + 0x7F4A7C15A5A5A5A5ULL));
    h = splitmix64(h ^ (d + 0xD1B54A32D192ED03ULL));
    return h;
}
inline double u01(uint64_t h){ return (double)(h >> 11) * (1.0 / 9007199254740992.0); }
inline double counter_uniform(uint64_t seed, uint64_t a, uint64_t b, uint64_t c){ return u01(hash4(seed,a,b,c)); }
inline double counter_gauss(uint64_t seed, uint64_t a, uint64_t b, uint64_t c){
    double u1 = u01(hash4(seed ^ 0xA5A5A5A5A5A5A5A5ULL, a, b, c));
    double u2 = u01(hash4(seed ^ 0x5A5A5A5A5A5A5A5AULL, a, b, c));
    if (u1 < 1e-12) u1 = 1e-12;
    const double TWO_PI = 6.283185307179586476925286766559;
    return sqrt(-2.0 * log(u1)) * cos(TWO_PI * u2);
}
inline std::string fmt6(double x){
    if (std::fabs(x) < 0.5e-6) x = 0.0;
    char b[64]; snprintf(b,sizeof(b),"%.6f",x); return std::string(b);
}
} // namespace ref

// ------------------------------------------------------------------ device probes
__global__ void kRngDevice(unsigned long long* out){
    out[0] = orrery::hash4(1,2,3,4);
    out[1] = (unsigned long long)__double_as_longlong(orrery::u01(orrery::hash4(123,4,5,6)));
    out[2] = (unsigned long long)__double_as_longlong(orrery::counter_uniform(123,4,5,6));
    out[3] = (unsigned long long)__double_as_longlong(orrery::counter_gauss(123,4,5,6));
    out[4] = (unsigned long long)__double_as_longlong(orrery::counter_gauss(20260705,7,11,13));
}
__global__ void kReduce(float* out){                 // launch with exactly 256 threads, 1 block
    __shared__ float sh[96];
    float v = (float)((threadIdx.x % 7) + 1);
    float s = orrery::blockReduceSum(v, sh);
    if(threadIdx.x==0) out[0]=s;
    __syncthreads();
    float3 t = make_float3(v, 2.0f*v, (float)(threadIdx.x & 1));
    float3 r = orrery::blockReduceSum3(t, sh);
    if(threadIdx.x==0){ out[1]=r.x; out[2]=r.y; out[3]=r.z; }
}
__global__ void kFixedFwd(const double* v, int n, unsigned long long* acc){
    int i=blockIdx.x*blockDim.x+threadIdx.x; if(i<n) orrery::fixed_atomic_add(acc, v[i]);
}
__global__ void kFixedRev(const double* v, int n, unsigned long long* acc){
    int i=blockIdx.x*blockDim.x+threadIdx.x; if(i<n) orrery::fixed_atomic_add(acc, v[n-1-i]);
}

static unsigned long long dbits(double d){ unsigned long long u; memcpy(&u,&d,8); return u; }

int main(){
    using orrery::st_check;
    bool ok = true;
    fprintf(stderr, "liborrery --selftest (v%s)\n", LIB_VERSION);

    // 1 · hash KATs
    ok &= st_check("blake2b-256(\"\") KAT",
        orrery::blake2b_hex("")=="0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8");
    ok &= st_check("blake2b-256(\"abc\") KAT",
        orrery::blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    ok &= st_check("sha256(\"\") KAT",
        orrery::sha256_hex(std::string(""))=="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    ok &= st_check("sha256(\"abc\") KAT",
        orrery::sha256_hex(std::string("abc"))=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    ok &= st_check("sha256 two-block KAT",
        orrery::sha256_hex(std::string("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))
        =="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");

    // 2 · REF CROSS-CHECK: lib == template, bit-for-bit, across a sweep
    { bool same=true;
      for(uint64_t i=0;i<1000 && same;i++){
        uint64_t a=i*0x9E3779B97F4A7C15ULL, b=i*7+1, c=i*13+2, d=i*29+3;
        if(orrery::splitmix64(a)!=ref::splitmix64(a)) same=false;
        if(orrery::hash4(a,b,c,d)!=ref::hash4(a,b,c,d)) same=false;
        if(dbits(orrery::u01(orrery::hash4(a,b,c,d)))!=dbits(ref::u01(ref::hash4(a,b,c,d)))) same=false;
        if(dbits(orrery::counter_uniform(a,b,c,d&3))!=dbits(ref::counter_uniform(a,b,c,d&3))) same=false;
        if(dbits(orrery::counter_gauss(a,b,c,d&3))!=dbits(ref::counter_gauss(a,b,c,d&3))) same=false;
      }
      for(double x : {0.0,-0.0,-1e-9,1.5,-2.5,3.141593,-0.456938,1e9})
        if(orrery::fmt6(x)!=ref::fmt6(x)) same=false;
      ok &= st_check("lib == template (ref-namespace cross-check, 1000-pt sweep + fmt6)", same); }

    // 3 · RNG value KATs — host pins (ground truth 2026-07-09, CUDA 13.1 / MSVC 2022 / sm_89;
    //     integer + u01 paths independently confirmed in Python)
    ok &= st_check("splitmix64(0) KAT (Vigna vector)", orrery::splitmix64(0)==0xe220a8397b1dcdafULL);
    ok &= st_check("splitmix64(1) KAT", orrery::splitmix64(1)==0x910a2dec89025cc1ULL);
    ok &= st_check("hash4(1,2,3,4) KAT", orrery::hash4(1,2,3,4)==0xfe9701a65a097b0aULL);
    ok &= st_check("hash4(20260705,0,0,0) KAT", orrery::hash4(20260705,0,0,0)==0xa5e68b9e2388999eULL);
    ok &= st_check("u01(hash4(123,4,5,6)) bits KAT", dbits(orrery::u01(orrery::hash4(123,4,5,6)))==0x3fe444d24ec22163ULL);
    ok &= st_check("host counter_gauss(123,4,5,6) bits KAT", dbits(orrery::counter_gauss(123,4,5,6))==0xbfee3cfb3691aedeULL);
    ok &= st_check("host counter_gauss(20260705,7,11,13) bits KAT", dbits(orrery::counter_gauss(20260705,7,11,13))==0x3ff93972b6ee9d3bULL);
    { std::mt19937_64 g(42);  ok &= st_check("h_u01(mt19937_64(42)) bits KAT", dbits(orrery::h_u01(g))==0x3fe82a3befaddcbcULL); }
    { std::mt19937_64 g(42);  ok &= st_check("h_normal(mt19937_64(42)) bits KAT", dbits(orrery::h_normal(g))==0xbfdecc4552b9eff1ULL); }

    // 3b · RNG value KATs — DEVICE pins (the CUDA-libm drift detector). Note cg2 device pin ends
    //     ...9d3a vs host ...9d3b: the measured 1-ULP MSVC/CUDA libm divergence, pinned per side.
    { unsigned long long *d=nullptr, h1[5], h2[5];
      CUDA_OK(cudaMalloc(&d,5*sizeof(unsigned long long)));
      kRngDevice<<<1,1>>>(d); CUDA_OK(cudaGetLastError());
      CUDA_OK(cudaMemcpy(h1,d,5*sizeof(unsigned long long),cudaMemcpyDeviceToHost));
      kRngDevice<<<1,1>>>(d); CUDA_OK(cudaGetLastError());
      CUDA_OK(cudaMemcpy(h2,d,5*sizeof(unsigned long long),cudaMemcpyDeviceToHost));
      cudaFree(d);
      ok &= st_check("device hash4 == host hash4 (integer path)", h1[0]==orrery::hash4(1,2,3,4));
      ok &= st_check("device u01 == host u01 (exact multiply path)", h1[1]==dbits(orrery::u01(orrery::hash4(123,4,5,6))));
      ok &= st_check("device counter_uniform == host", h1[2]==dbits(orrery::counter_uniform(123,4,5,6)));
      ok &= st_check("device counter_gauss(123,4,5,6) bits KAT", h1[3]==0xbfee3cfb3691aedeULL);
      ok &= st_check("device counter_gauss(20260705,7,11,13) bits KAT (1-ULP vs host, pinned)", h1[4]==0x3ff93972b6ee9d3aULL);
      ok &= st_check("device RNG bit-identical across two launches", memcmp(h1,h2,sizeof(h1))==0); }

    // 4 · deterministic reductions
    { float *d=nullptr, h1[4], h2[4];
      CUDA_OK(cudaMalloc(&d,4*sizeof(float)));
      kReduce<<<1,256>>>(d); CUDA_OK(cudaGetLastError());
      CUDA_OK(cudaMemcpy(h1,d,4*sizeof(float),cudaMemcpyDeviceToHost));
      kReduce<<<1,256>>>(d); CUDA_OK(cudaGetLastError());
      CUDA_OK(cudaMemcpy(h2,d,4*sizeof(float),cudaMemcpyDeviceToHost));
      cudaFree(d);
      // sum_{t=0}^{255} ((t%7)+1) = 36*28 + (1+2+3+4) = 1018 (integer-valued: exact in float)
      ok &= st_check("blockReduceSum exact (1018)", h1[0]==1018.0f);
      ok &= st_check("blockReduceSum3 exact (1018, 2036, 128)", h1[1]==1018.0f && h1[2]==2036.0f && h1[3]==128.0f);
      ok &= st_check("block reductions bit-identical across two launches", memcmp(h1,h2,sizeof(h1))==0); }

    // 4b · fixed-point accumulator: order-invariance (fwd == rev == host integer sum)
    { const int n=4096;
      std::vector<double> v(n); long long hostSum=0;
      for(int i=0;i<n;i++){ v[i]=((i%17)-8)*0.25; hostSum += orrery::fixed_encode(v[i]); }
      double *dv=nullptr; unsigned long long *da=nullptr, accF=0, accR=0;
      CUDA_OK(cudaMalloc(&dv,n*sizeof(double)));
      CUDA_OK(cudaMalloc(&da,sizeof(unsigned long long)));
      CUDA_OK(cudaMemcpy(dv,v.data(),n*sizeof(double),cudaMemcpyHostToDevice));
      CUDA_OK(cudaMemset(da,0,sizeof(unsigned long long)));
      kFixedFwd<<<16,256>>>(dv,n,da); CUDA_OK(cudaGetLastError());
      CUDA_OK(cudaMemcpy(&accF,da,sizeof(accF),cudaMemcpyDeviceToHost));
      CUDA_OK(cudaMemset(da,0,sizeof(unsigned long long)));
      kFixedRev<<<16,256>>>(dv,n,da); CUDA_OK(cudaGetLastError());
      CUDA_OK(cudaMemcpy(&accR,da,sizeof(accR),cudaMemcpyDeviceToHost));
      cudaFree(dv); cudaFree(da);
      ok &= st_check("fixed-point atomic: forward == reversed (order-invariant)", accF==accR);
      ok &= st_check("fixed-point atomic == host integer sum", (long long)accF==hostSum);
      ok &= st_check("fixed-point decode exact (-2.0)", orrery::fixed_decode((long long)accF)==-2.0); }

    // 5 · envelope pieces
    ok &= st_check("fmt6(-0.0)/-1e-9 normalize to 0.000000",
        orrery::fmt6(-0.0)=="0.000000" && orrery::fmt6(-1e-9)=="0.000000");
    ok &= st_check("fmt6(1.5) / fmt6(-0.456938)",
        orrery::fmt6(1.5)=="1.500000" && orrery::fmt6(-0.456938)=="-0.456938");
    ok &= st_check("fmti(-42)", orrery::fmti(-42)=="-42");
    ok &= st_check("jesc escapes", orrery::jesc("a\"b\\c\nd\te\rf")=="a\\\"b\\\\c\\nd\\te\\rf");
    ok &= st_check("declared_object wraps", orrery::declared_object("\"seed\":7")=="{\"seed\":7}");
    ok &= st_check("full_envelope shape",
        orrery::full_envelope("t","1.2.3","\"seed\":7","n\"x")
        =="{\"tool\":\"t\",\"version\":\"1.2.3\",\"seed\":7,\"notes\":\"n\\\"x\"}");
    { std::string h; bool found=orrery::read_golden_hash("someone",h);
      bool hex = found && h.size()==64;
      if(hex) for(char c: h) if(!((c>='0'&&c<='9')||(c>='a'&&c<='f'))) hex=false;
      ok &= st_check("read_golden_hash finds frozen someone hash (run from repo root)", hex); }
    { double s=0,c=0; for(int i=0;i<10;i++) orrery::kahan_add(s,c,0.1);
      ok &= st_check("kahan_add 10x0.1 ~= 1.0 (<1e-15)", std::fabs(s-1.0)<1e-15); }
    { std::vector<int> k={2,0,1,0,2,1,0}; std::vector<double> v={1.5,2.0,3.25,4.0,5.5,6.75,8.0};
      std::vector<double> a=orrery::stable_gather_sum(k,v,3), b=orrery::stable_gather_sum(k,v,3);
      ok &= st_check("stable_gather_sum exact (14, 10, 7)", a[0]==14.0 && a[1]==10.0 && a[2]==7.0);
      ok &= st_check("stable_gather_sum deterministic (two calls bit-equal)",
          memcmp(a.data(),b.data(),3*sizeof(double))==0); }

    // 6 · regime bitmask
    { orrery::Regime r; r.derive(0,true); r.derive(1,false); r.derive(3,true);
      static const char* NAMES[4]={"a","b","c","d"};
      ok &= st_check("regime derive/test/raw", r.test(0)&&!r.test(1)&&r.test(3)&&r.raw()==9u);
      ok &= st_check("regime to_json", r.to_json(NAMES,4)=="{\"mask\":9,\"set\":[\"a\",\"d\"]}"); }

    // 7 · ckpt round-trip + tamper detection
    { std::vector<uint8_t> data(1024); for(size_t i=0;i<data.size();i++) data[i]=(uint8_t)(i*7+3);
      const char* P="_libtest.ckpt";
      bool w = orrery::ckpt_write(P,data.data(),data.size());
      std::vector<uint8_t> back;
      bool r = w && orrery::ckpt_read_verified(P,back) && back==data;
      ok &= st_check("ckpt write + sidecar + verified read round-trip", r);
      { FILE* f=fopen(P,"r+b"); bool t=false;
        if(f){ fseek(f,100,SEEK_SET); fputc(data[100]^0xFF,f); fclose(f);
               std::vector<uint8_t> x; t = !orrery::ckpt_read_verified(P,x); }
        ok &= st_check("ckpt tamper detected (verify fails on corrupt byte)", t); }
      remove(P); remove(orrery::ckpt_sidecar_path(P).c_str()); }

    // 8 · result.lock writer
    { orrery::ResultLockInfo L; L.tool="libtest"; L.version="1.0.0"; L.result_kind="selftest";
      L.binary_blake2b="deadbeef"; L.gpu_arch="sm_89"; L.gpu_device="RTX 4070 Ti SUPER";
      L.cuda="13.1"; L.host_compiler="MSVC 2022"; L.build_cmd="nvcc ...";
      L.seed="7"; L.params="x=1"; L.cli="libtest --x 1"; L.declared_blake2b="abc123";
      L.determinism="n/a"; L.hash_domain="D-013";
      const char* P="_libtest.lock";
      bool w = orrery::write_result_lock(P,L); std::string body;
      if(w){ FILE* f=fopen(P,"rb"); char b[4096]; size_t n=fread(b,1,sizeof(b)-1,f); fclose(f); b[n]=0; body=b; }
      ok &= st_check("write_result_lock emits the manifest keys",
          w && body.find("tool:            libtest")!=std::string::npos
            && body.find("declared_blake2b: abc123")!=std::string::npos
            && body.find("# --- binary / toolchain ---")!=std::string::npos);
      remove(P); }

    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n");
    return ok?0:1;
}
