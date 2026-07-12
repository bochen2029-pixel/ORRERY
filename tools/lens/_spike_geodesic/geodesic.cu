// geodesic.cu — SPIKE (D-004): the honest fp64 CUDA baseline for the lens compute-SPIKE.
// Integrates REAL Schwarzschild null geodesics (Binet equation u'' = -u + 3M u^2, u=1/r)
// to (a) DERIVE the photon-capture shadow cross-section by integration and validate it against
// the exact oracle sigma = 27*pi*M^2 (b_crit = sqrt(27) M), and (b) render the gravitationally
// lensed black-hole image (a finite observer; escaped rays sample a lensed celestial checker).
//
// This is the SPIKE's BASELINE arm. The RT-accelerated arm (polyline segments + OptiX BVH) is
// measured against it; the >=1.5x kill decides graduate-vs-retire. THROWAWAY spike code (SPIKES.md):
// the deliverable is validated numbers + the ruling, not this file.
//
// Determinism: fp64, fixed phi-step count, no RNG. Captured-pixel count is an integer.
// Build: nvcc -O3 -arch=sm_89 geodesic.cu -o geodesic.exe
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <chrono>

#define CU(call) do{ cudaError_t e=(call); if(e!=cudaSuccess){ \
  fprintf(stderr,"CUDA error %s @ %d: %s\n",#call,__LINE__,cudaGetErrorString(e)); std::exit(2);} }while(0)

#define PI 3.14159265358979323846

// ---- classification codes ----
enum { ESCAPED=0, CAPTURED=1 };

// ---- device: integrate one null geodesic from infinity with impact parameter b ----
// Ortho ray from infinity: u(0)=0, du/dphi(0)=1/b. Step phi forward.
//   u >= 1/(2M)  -> CAPTURED (crossed horizon)
//   w = du/dphi <= 0 (turning point) before capture -> ESCAPED
// Returns 1 if captured, else 0.
__device__ int integrate_capture(double b, double M, double dphi, int maxsteps) {
    if (b <= 1e-9) return CAPTURED;                 // dead-center ray plunges in
    double u = 0.0, w = 1.0 / b;
    const double uh = 1.0 / (2.0 * M);
    for (int s = 0; s < maxsteps; ++s) {
        // RK4 on (u' = w, w' = -u + 3M u^2)
        double k1u = w,               k1w = -u + 3.0*M*u*u;
        double u2 = u + 0.5*dphi*k1u, w2 = w + 0.5*dphi*k1w;
        double k2u = w2,              k2w = -u2 + 3.0*M*u2*u2;
        double u3 = u + 0.5*dphi*k2u, w3 = w + 0.5*dphi*k2w;
        double k3u = w3,              k3w = -u3 + 3.0*M*u3*u3;
        double u4 = u + dphi*k3u,     w4 = w + dphi*k3w;
        double k4u = w4,              k4w = -u4 + 3.0*M*u4*u4;
        u += (dphi/6.0)*(k1u + 2.0*k2u + 2.0*k3u + k4u);
        w += (dphi/6.0)*(k1w + 2.0*k2w + 2.0*k3w + k4w);
        if (u >= uh) return CAPTURED;
        if (w <= 0.0) return ESCAPED;               // passed the turning point -> escapes
    }
    // Neither triggered within the step budget (near the separatrix b~b_crit, measure zero):
    // classify by whether we are inside the photon sphere.
    return (u > 1.0/(3.0*M)) ? CAPTURED : ESCAPED;
}

// ---- VALIDATE kernel: orthographic b-grid; count captured pixels ----
__global__ void validate_kernel(int W, int H, double extent, double M, double dphi, int maxsteps,
                                unsigned int* captured) {
    int x = blockIdx.x*blockDim.x + threadIdx.x;
    int y = blockIdx.y*blockDim.y + threadIdx.y;
    if (x >= W || y >= H) return;
    double u = extent * (2.0*(x+0.5)/W - 1.0);
    double v = extent * (2.0*(y+0.5)/H - 1.0);
    double b = sqrt(u*u + v*v);
    if (integrate_capture(b, M, dphi, maxsteps) == CAPTURED)
        atomicAdd(captured, 1u);
}

// ---- device 3D vec helpers ----
struct V3 { double x,y,z; };
__device__ __host__ inline V3 v3(double x,double y,double z){ V3 r{x,y,z}; return r; }
__host__ __device__ inline V3 add(V3 a,V3 b){ return v3(a.x+b.x,a.y+b.y,a.z+b.z); }
__host__ __device__ inline V3 sub(V3 a,V3 b){ return v3(a.x-b.x,a.y-b.y,a.z-b.z); }
__host__ __device__ inline V3 mul(V3 a,double s){ return v3(a.x*s,a.y*s,a.z*s); }
__host__ __device__ inline double dot(V3 a,V3 b){ return a.x*b.x+a.y*b.y+a.z*b.z; }
__host__ __device__ inline V3 cross(V3 a,V3 b){ return v3(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x); }
__host__ __device__ inline double len(V3 a){ return sqrt(dot(a,a)); }
__host__ __device__ inline V3 norm(V3 a){ double l=len(a); return l>1e-300? mul(a,1.0/l):a; }

// ---- RENDER kernel: finite observer; per-pixel geodesic; escaped -> lensed celestial checker ----
// Camera at C looking toward origin; disk optional (off in v1 spike -> the classic lensed-grid image).
__global__ void render_kernel(int W, int H, V3 C, V3 fwd, V3 right, V3 up, double tanhalf,
                              double M, double dphi, int maxsteps, double r_esc,
                              double diskIn, double diskOut, unsigned char* img) {
    int px = blockIdx.x*blockDim.x + threadIdx.x;
    int py = blockIdx.y*blockDim.y + threadIdx.y;
    if (px >= W || py >= H) return;
    double sx = (2.0*(px+0.5)/W - 1.0) * tanhalf * (double)W/H;
    double sy = (2.0*(py+0.5)/H - 1.0) * tanhalf;
    V3 D0 = norm(add(add(fwd, mul(right, sx)), mul(up, sy)));
    V3 P0 = C;
    double r0 = len(P0);
    // orbital-plane basis
    V3 er = norm(P0);
    double d_r = dot(D0, er);
    V3 ephi = sub(D0, mul(er, d_r));
    double ephilen = len(ephi);
    unsigned char R=0,G=0,B=0;
    if (ephilen < 1e-9) {
        // radial ray: straight in or out
        if (d_r < 0.0) { R=G=B=0; }                 // aimed inward -> into hole -> black
        else { R=8; G=10; B=16; }
    } else {
        ephi = mul(ephi, 1.0/ephilen);
        double u = 1.0/r0;
        double w = -u * (d_r/ephilen);              // w0 = -u0 (D.er)/(D.ephi)
        const double uh = 1.0/(2.0*M);
        double phi = 0.0; int code = 1;             // 1=still integrating
        double r = r0;
        for (int s=0; s<maxsteps; ++s) {
            double k1u=w,               k1w=-u+3.0*M*u*u;
            double u2=u+0.5*dphi*k1u,   w2=w+0.5*dphi*k1w;
            double k2u=w2,              k2w=-u2+3.0*M*u2*u2;
            double u3=u+0.5*dphi*k2u,   w3=w+0.5*dphi*k2w;
            double k3u=w3,              k3w=-u3+3.0*M*u3*u3;
            double u4=u+dphi*k3u,       w4=w+dphi*k3w;
            double k4u=w4,              k4w=-u4+3.0*M*u4*u4;
            double du=(dphi/6.0)*(k1u+2.0*k2u+2.0*k3u+k4u);
            double dw=(dphi/6.0)*(k1w+2.0*k2w+2.0*k3w+k4w);
            u+=du; w+=dw; phi+=dphi;
            r = 1.0/u;
            if (u >= uh) { code=CAPTURED; break; }
            if (r >= r_esc && w < 0.0) { code=ESCAPED; break; }  // receding to infinity
        }
        if (code==CAPTURED) { R=G=B=0; }            // the shadow
        else {
            // outgoing 3D direction = tangent d(Pos)/dphi, Pos = r(cosphi er + sinphi ephi)
            double rp = -w/(u*u);                    // dr/dphi
            V3 basis = add(mul(er, cos(phi)), mul(ephi, sin(phi)));
            V3 dbasis = add(mul(er, -sin(phi)), mul(ephi, cos(phi)));
            V3 outdir = norm(add(mul(basis, rp), mul(dbasis, r)));
            // lensed celestial checker from the outgoing direction
            double th = atan2(outdir.y, outdir.x);
            double cc = acos(fmax(-1.0,fmin(1.0,outdir.z)));
            int chk = ((int)floor(th*6.0/PI) + (int)floor(cc*6.0/PI)) & 1;
            if (chk) { R=176; G=196; B=222; }        // light cells
            else     { R=30;  G=52;  B=92;  }        // dark cells
            // subtle brightening near the shadow edge (photon ring hint)
        }
    }
    long idx = ((long)py*W + px)*3;
    img[idx]=R; img[idx+1]=G; img[idx+2]=B;
}

// ---- host helpers ----
static double argd(int argc,char**argv,const char*flag,double def){
    for(int i=1;i<argc-1;i++) if(!strcmp(argv[i],flag)) return atof(argv[i+1]);
    return def;
}
static long argl(int argc,char**argv,const char*flag,long def){
    for(int i=1;i<argc-1;i++) if(!strcmp(argv[i],flag)) return atol(argv[i+1]);
    return def;
}
static const char* args(int argc,char**argv,const char*flag,const char*def){
    for(int i=1;i<argc-1;i++) if(!strcmp(argv[i],flag)) return argv[i+1];
    return def;
}
static bool hasflag(int argc,char**argv,const char*flag){
    for(int i=1;i<argc;i++) if(!strcmp(argv[i],flag)) return true;
    return false;
}

int main(int argc,char**argv){
    double M = argd(argc,argv,"--mass",1.0);
    int W = (int)argl(argc,argv,"--width",1024);
    int H = (int)argl(argc,argv,"--height",1024);
    int steps = (int)argl(argc,argv,"--steps",6000);
    double dphi = argd(argc,argv,"--dphi",0.004);
    const char* renderPath = args(argc,argv,"--render",nullptr);

    dim3 blk(16,16), grd((W+15)/16,(H+15)/16);

    if (renderPath) {
        // ---- lensed render (finite observer) ----
        double D    = argd(argc,argv,"--obs-dist",30.0)*M;
        double fov  = argd(argc,argv,"--fov",25.0);
        double r_esc= argd(argc,argv,"--r-esc",60.0)*M;
        // camera on -z, looking +z, slight +y elevation so the lensing reads
        double elev = argd(argc,argv,"--elev",0.0)*M;
        V3 C = v3(0.0, elev, -D);
        V3 fwd = norm(sub(v3(0,0,0), C));
        V3 right = norm(cross(fwd, v3(0,1,0)));
        V3 up = cross(right, fwd);
        double tanhalf = tan(0.5*fov*PI/180.0);
        unsigned char* dimg=nullptr; CU(cudaMalloc(&dimg,(size_t)W*H*3));
        auto t0=std::chrono::high_resolution_clock::now();
        render_kernel<<<grd,blk>>>(W,H,C,fwd,right,up,tanhalf,M,dphi,steps,r_esc,6.0*M,18.0*M,dimg);
        CU(cudaGetLastError()); CU(cudaDeviceSynchronize());
        auto t1=std::chrono::high_resolution_clock::now();
        std::vector<unsigned char> img((size_t)W*H*3);
        CU(cudaMemcpy(img.data(),dimg,(size_t)W*H*3,cudaMemcpyDeviceToHost));
        cudaFree(dimg);
        FILE* f=fopen(renderPath,"wb");
        if(!f){ fprintf(stderr,"cannot open %s\n",renderPath); return 2; }
        fprintf(f,"P6\n%d %d\n255\n",W,H); fwrite(img.data(),1,img.size(),f); fclose(f);
        double ms=std::chrono::duration<double,std::milli>(t1-t0).count();
        printf("[render] %dx%d geodesics -> %s  (%.1f ms, %d phi-steps)\n",W,H,renderPath,ms,steps);
        return 0;
    }

    // ---- VALIDATE: derive the shadow cross-section by integration, check vs 27 pi M^2 ----
    double extent = argd(argc,argv,"--extent",1.5*sqrt(27.0)*M);
    unsigned int* dcap=nullptr; CU(cudaMalloc(&dcap,sizeof(unsigned int)));
    CU(cudaMemset(dcap,0,sizeof(unsigned int)));
    auto t0=std::chrono::high_resolution_clock::now();
    validate_kernel<<<grd,blk>>>(W,H,extent,M,dphi,steps,dcap);
    CU(cudaGetLastError()); CU(cudaDeviceSynchronize());
    auto t1=std::chrono::high_resolution_clock::now();
    unsigned int cap=0; CU(cudaMemcpy(&cap,dcap,sizeof(unsigned int),cudaMemcpyDeviceToHost));
    cudaFree(dcap);
    double frac=(double)cap/((double)W*H);
    double area_meas = frac*(2.0*extent)*(2.0*extent);
    double area_oracle = 27.0*PI*M*M;
    double rel = fabs(area_meas-area_oracle)/area_oracle;
    // derived b_crit from the captured area: b_crit = sqrt(area/pi)
    double bcrit_meas = sqrt(area_meas/PI);
    double bcrit_oracle = sqrt(27.0)*M;
    double ms=std::chrono::duration<double,std::milli>(t1-t0).count();
    printf("[validate] %dx%d geodesics integrated (%.0f ms, %d phi-steps, dphi=%.4f)\n",W,H,ms,steps,dphi);
    printf("  captured pixels     : %u / %d  (frac %.6f)\n",cap,W*H,frac);
    printf("  shadow cross-section: measured %.6f  vs oracle 27*pi*M^2 = %.6f  rel_err %.3e\n",
           area_meas,area_oracle,rel);
    printf("  b_crit (derived)    : %.6f  vs sqrt(27)*M = %.6f  rel_err %.3e\n",
           bcrit_meas,bcrit_oracle,fabs(bcrit_meas-bcrit_oracle)/bcrit_oracle);
    printf(rel < 5e-3 ? "  RESULT: PASS (geodesic-derived shadow reproduces the 27 pi M^2 oracle)\n"
                      : "  RESULT: FAIL (does not reproduce the oracle within 5e-3)\n");
    return rel < 5e-3 ? 0 : 1;
}
