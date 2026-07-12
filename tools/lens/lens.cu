// lens.cu — ORRERY tool `lens` (v1.0.0)
// Headless, deterministic OptiX RT-core renderer + oracle-gated geometric measurement.
// Contract: contracts/lens.contract.md (+ lens.schema.json). Contract is authoritative.
//
// Measures a physics-scene silhouette's projected CROSS-SECTION (structure/optics); says
// NOTHING about qualia. §III-sealed. Honest scope (D-004): renders geometry; does NOT
// integrate curved null geodesics (that light-bending render + any RT-speedup claim is the
// pre-registered compute-SPIKE in the contract). The declared measurement is an analytic
// CPU baseline (the deterministic golden anchor + I-11 oracle); the OptiX RT path is
// cross-checked against it (I-13 paired-oracle). OptiX pipeline pattern: C:\RAYFORMER\src\render.cu.
//
// Build (from tools/lens/, see MODULE.md — three chained steps, one command):
//   nvcc -ptx lens_device.cu -> python embed_ptx.py -> nvcc lens.cu ../../lib/envelope.cpp

#include <optix.h>
#include <optix_stubs.h>
#include <optix_function_table_definition.h>   // exactly one TU per linked image
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include "../../lib/envelope.h"   // blake2b, fmt6/fmti/jesc, golden plumbing, CLI spine, CUDA_OK (D-020)
#include "lens_params.h"
#include "lens_device_ptx.h"      // generated: LENS_DEVICE_PTX / LENS_DEVICE_PTX_len (embed_ptx.py)
using namespace orrery;

static const char* LENS_VERSION = "1.0.0";
static const char* FIREWALL =
    "This measures the geometric cross-section of a physics-scene silhouette (structure/optics); "
    "it says nothing about whether anything feels (acquaintance) - III-sealed. Honest scope (D-004): "
    "renders geometry, does NOT integrate curved null geodesics; the geodesic render and any RT "
    "speedup claim are the pre-registered compute-SPIKE, not asserted here.";

static const double PI     = 3.14159265358979323846;
static const double SQRT27 = 5.19615242270663188058;   // 3*sqrt(3) = sqrt(27) = b_crit / M

// ------------------------------------------------------------------ params / result
struct Params {
    std::string scene = "sphere";
    double radius = 1.0, mass = 1.0;
    int width = 1024, height = 1024;
    double extent = -1.0;        // <0 => derive 1.5*silhouette_radius
    std::string engine = "both"; // baseline | both
    double tol_oracle = -1.0;    // <0 => derive (resolution-aware)
    long long tol_rt_px = 64;
    long long seed = 0;
    bool json=false, csv=false, selftest=false, golden=false;
    std::string csv_path, render_path;
    bool render=false;
};
struct Result {
    double silhouette_radius=0, image_extent=0, hit_fraction=0;
    double area_measured=0, area_oracle=0, area_rel_err=0;
    long long total_pixels=0, hit_pixels=0, hit_pixels_rt=-1, rt_baseline_delta=-1;
    int rt_agrees=-1;
    bool g_oracle=false, g_rt=false;
    double g_oracle_val=0, g_oracle_thr=0, g_rt_val=-1, g_rt_thr=0;
};

// ------------------------------------------------------------------ scene geometry (exact oracles)
static double silhouette_radius(const Params& P){ return P.scene=="sphere" ? P.radius : SQRT27*P.mass; }
static double area_oracle_of  (const Params& P){ return P.scene=="sphere" ? PI*P.radius*P.radius : 27.0*PI*P.mass*P.mass; }

// Resolve derived defaults (extent, tol_oracle) in place; validate extent > silhouette (else exit 2).
static void resolve(Params& P){
    double silR = silhouette_radius(P);
    if(P.extent < 0.0) P.extent = 1.5*silR;
    if(P.extent <= silR) die2("--extent must strictly exceed the silhouette radius");
    if(P.tol_oracle < 0.0){ double t = 8.0*P.extent/((double)P.width*silR); P.tol_oracle = (t>1e-3)?t:1e-3; }
}

// ------------------------------------------------------------------ analytic baseline (CPU fp64, deterministic)
// Orthographic parallel ray through pixel-center (u,v) hits the origin-centered sphere of radius silR
// iff u^2+v^2 <= silR^2. Pure integer count; driver-independent; the declared anchor + I-11 oracle.
static long long baseline_hits(const Params& P, std::vector<unsigned char>* buf){
    const long long W=P.width, H=P.height; const double ext=P.extent;
    const double silR = silhouette_radius(P); const double r2 = silR*silR;
    if(buf) buf->assign((size_t)W*H, 0);
    long long hits=0;
    for(long long y=0;y<H;y++){
        const double v = ext*(2.0*((double)y+0.5)/(double)H - 1.0);
        for(long long x=0;x<W;x++){
            const double u = ext*(2.0*((double)x+0.5)/(double)W - 1.0);
            if(u*u+v*v <= r2){ hits++; if(buf) (*buf)[(size_t)y*W+x]=1; }
        }
    }
    return hits;
}

// ------------------------------------------------------------------ OptiX RT path (mirror render.cu; PTX embedded)
#define OX_TRY(x) do{ OptixResult r_=(x); if(r_!=OPTIX_SUCCESS){ \
    fprintf(stderr,"[lens] OptiX error %d (%s) @ %s:%d\n",(int)r_,optixGetErrorName(r_),__FILE__,__LINE__); std::exit(2);} }while(0)

template <typename T> struct SbtRecord {
    __align__(OPTIX_SBT_RECORD_ALIGNMENT) char header[OPTIX_SBT_RECORD_HEADER_SIZE];
    T data;
};
struct Empty {}; using EmptyRec = SbtRecord<Empty>;
static void lens_optix_log(unsigned int level, const char* tag, const char* msg, void*){
    if(level <= 3) fprintf(stderr,"[optix][%u][%s] %s\n", level, tag?tag:"", msg?msg:"");
}

// Returns the number of primary rays intersecting the silhouette sphere via OptiX. Exit 2 on any failure.
static long long rt_hits(const Params& P){
    const int W=P.width, H=P.height; const float silR=(float)silhouette_radius(P);
    CUDA_OK(cudaFree(nullptr));
    OX_TRY(optixInit());
    OptixDeviceContext ctx=nullptr;
    OptixDeviceContextOptions copt={}; copt.logCallbackFunction=&lens_optix_log; copt.logCallbackLevel=3;
    OX_TRY(optixDeviceContextCreate(0,&copt,&ctx));

    // sphere GAS (one sphere at origin, radius silR)
    float3 center=make_float3(0,0,0);
    CUdeviceptr dCenter=0,dRadius=0;
    CUDA_OK(cudaMalloc((void**)&dCenter,sizeof(float3)));
    CUDA_OK(cudaMemcpy((void*)dCenter,&center,sizeof(float3),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMalloc((void**)&dRadius,sizeof(float)));
    CUDA_OK(cudaMemcpy((void*)dRadius,&silR,sizeof(float),cudaMemcpyHostToDevice));
    OptixBuildInput bi={}; bi.type=OPTIX_BUILD_INPUT_TYPE_SPHERES;
    bi.sphereArray.vertexBuffers=&dCenter; bi.sphereArray.numVertices=1;
    bi.sphereArray.radiusBuffers=&dRadius; bi.sphereArray.singleRadius=1;
    unsigned int gflags[1]={OPTIX_GEOMETRY_FLAG_DISABLE_ANYHIT}; bi.sphereArray.flags=gflags; bi.sphereArray.numSbtRecords=1;
    OptixAccelBuildOptions ao={}; ao.buildFlags=OPTIX_BUILD_FLAG_PREFER_FAST_TRACE; ao.operation=OPTIX_BUILD_OPERATION_BUILD;
    OptixAccelBufferSizes sz={}; OX_TRY(optixAccelComputeMemoryUsage(ctx,&ao,&bi,1,&sz));
    CUdeviceptr dTemp=0,dGas=0;
    CUDA_OK(cudaMalloc((void**)&dTemp,sz.tempSizeInBytes)); CUDA_OK(cudaMalloc((void**)&dGas,sz.outputSizeInBytes));
    OptixTraversableHandle gas=0;
    OX_TRY(optixAccelBuild(ctx,0,&ao,&bi,1,dTemp,sz.tempSizeInBytes,dGas,sz.outputSizeInBytes,&gas,nullptr,0));
    CUDA_OK(cudaDeviceSynchronize());

    // module from embedded PTX
    OptixModuleCompileOptions mco={}; mco.maxRegisterCount=OPTIX_COMPILE_DEFAULT_MAX_REGISTER_COUNT;
    mco.optLevel=OPTIX_COMPILE_OPTIMIZATION_DEFAULT; mco.debugLevel=OPTIX_COMPILE_DEBUG_LEVEL_MINIMAL;
    OptixPipelineCompileOptions pco={}; pco.traversableGraphFlags=OPTIX_TRAVERSABLE_GRAPH_FLAG_ALLOW_SINGLE_GAS;
    pco.numPayloadValues=1; pco.numAttributeValues=1; pco.pipelineLaunchParamsVariableName="params";
    pco.usesPrimitiveTypeFlags=OPTIX_PRIMITIVE_TYPE_FLAGS_SPHERE;
    char log[4096]; size_t logSize=sizeof(log); OptixModule module=nullptr;
    OX_TRY(optixModuleCreate(ctx,&mco,&pco,(const char*)LENS_DEVICE_PTX,LENS_DEVICE_PTX_len,log,&logSize,&module));
    OptixBuiltinISOptions bis={}; bis.builtinISModuleType=OPTIX_PRIMITIVE_TYPE_SPHERE;
    OptixModule sphereModule=nullptr; OX_TRY(optixBuiltinISModuleGet(ctx,&mco,&pco,&bis,&sphereModule));

    // program groups
    OptixProgramGroupOptions pgo={};
    OptixProgramGroup pgRg=nullptr,pgMs=nullptr,pgHit=nullptr;
    OptixProgramGroupDesc dRg={}; dRg.kind=OPTIX_PROGRAM_GROUP_KIND_RAYGEN; dRg.raygen.module=module; dRg.raygen.entryFunctionName="__raygen__lens";
    logSize=sizeof(log); OX_TRY(optixProgramGroupCreate(ctx,&dRg,1,&pgo,log,&logSize,&pgRg));
    OptixProgramGroupDesc dMs={}; dMs.kind=OPTIX_PROGRAM_GROUP_KIND_MISS; dMs.miss.module=module; dMs.miss.entryFunctionName="__miss__lens";
    logSize=sizeof(log); OX_TRY(optixProgramGroupCreate(ctx,&dMs,1,&pgo,log,&logSize,&pgMs));
    OptixProgramGroupDesc dHit={}; dHit.kind=OPTIX_PROGRAM_GROUP_KIND_HITGROUP; dHit.hitgroup.moduleCH=module; dHit.hitgroup.entryFunctionNameCH="__closesthit__lens";
    dHit.hitgroup.moduleIS=sphereModule; dHit.hitgroup.entryFunctionNameIS=nullptr;
    logSize=sizeof(log); OX_TRY(optixProgramGroupCreate(ctx,&dHit,1,&pgo,log,&logSize,&pgHit));

    // pipeline
    OptixProgramGroup groups[]={pgRg,pgMs,pgHit};
    OptixPipelineLinkOptions plo={}; plo.maxTraceDepth=1; OptixPipeline pipeline=nullptr;
    logSize=sizeof(log); OX_TRY(optixPipelineCreate(ctx,&pco,&plo,groups,3,log,&logSize,&pipeline));
    OX_TRY(optixPipelineSetStackSize(pipeline,0,0,2048,1));

    // SBT
    EmptyRec rg,ms,ht; OX_TRY(optixSbtRecordPackHeader(pgRg,&rg)); OX_TRY(optixSbtRecordPackHeader(pgMs,&ms)); OX_TRY(optixSbtRecordPackHeader(pgHit,&ht));
    CUdeviceptr dRgR=0,dMsR=0,dHtR=0;
    CUDA_OK(cudaMalloc((void**)&dRgR,sizeof(EmptyRec))); CUDA_OK(cudaMalloc((void**)&dMsR,sizeof(EmptyRec))); CUDA_OK(cudaMalloc((void**)&dHtR,sizeof(EmptyRec)));
    CUDA_OK(cudaMemcpy((void*)dRgR,&rg,sizeof(EmptyRec),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy((void*)dMsR,&ms,sizeof(EmptyRec),cudaMemcpyHostToDevice));
    CUDA_OK(cudaMemcpy((void*)dHtR,&ht,sizeof(EmptyRec),cudaMemcpyHostToDevice));
    OptixShaderBindingTable sbt={}; sbt.raygenRecord=dRgR;
    sbt.missRecordBase=dMsR; sbt.missRecordStrideInBytes=sizeof(EmptyRec); sbt.missRecordCount=1;
    sbt.hitgroupRecordBase=dHtR; sbt.hitgroupRecordStrideInBytes=sizeof(EmptyRec); sbt.hitgroupRecordCount=1;

    // launch
    unsigned char* dHits=nullptr; CUDA_OK(cudaMalloc((void**)&dHits,(size_t)W*H));
    LensParams lp={}; lp.handle=gas; lp.hits=dHits; lp.width=W; lp.height=H; lp.extent=(float)P.extent;
    CUdeviceptr dParams=0; CUDA_OK(cudaMalloc((void**)&dParams,sizeof(LensParams)));
    CUDA_OK(cudaMemcpy((void*)dParams,&lp,sizeof(LensParams),cudaMemcpyHostToDevice));
    OX_TRY(optixLaunch(pipeline,0,dParams,sizeof(LensParams),&sbt,(unsigned)W,(unsigned)H,1));
    CUDA_OK(cudaDeviceSynchronize());

    std::vector<unsigned char> hits((size_t)W*H);
    CUDA_OK(cudaMemcpy(hits.data(),dHits,(size_t)W*H,cudaMemcpyDeviceToHost));
    long long n=0; for(size_t i=0;i<hits.size();++i) n+=hits[i];

    // cleanup
    cudaFree((void*)dParams); cudaFree(dHits); cudaFree((void*)dRgR); cudaFree((void*)dMsR); cudaFree((void*)dHtR);
    optixPipelineDestroy(pipeline); optixProgramGroupDestroy(pgRg); optixProgramGroupDestroy(pgMs); optixProgramGroupDestroy(pgHit);
    optixModuleDestroy(sphereModule); optixModuleDestroy(module);
    cudaFree((void*)dGas); cudaFree((void*)dTemp); cudaFree((void*)dRadius); cudaFree((void*)dCenter);
    optixDeviceContextDestroy(ctx);
    return n;
}

// ------------------------------------------------------------------ --render (NON-DECLARED, Invariant 3): binary PPM
static void write_ppm(const Params& P, const std::vector<unsigned char>& hit){
    FILE* f=fopen(P.render_path.c_str(),"wb");
    if(!f){ fprintf(stderr,"error: cannot open --render path: %s\n",P.render_path.c_str()); std::exit(2); }
    fprintf(f,"P6\n%d %d\n255\n",P.width,P.height);
    std::vector<unsigned char> row((size_t)P.width*3);
    for(int y=0;y<P.height;y++){
        for(int x=0;x<P.width;x++){
            unsigned char r,g,b;
            if(hit[(size_t)y*P.width+x]){ r=18; g=18; b=24; }        // silhouette (the shadow)
            else                       { r=182; g=196; b=214; }     // background
            row[(size_t)x*3+0]=r; row[(size_t)x*3+1]=g; row[(size_t)x*3+2]=b;
        }
        fwrite(row.data(),1,row.size(),f);
    }
    fclose(f);
}

// ------------------------------------------------------------------ serialize (declared body + envelope) [ratchet shape]
static std::string params_json(const Params& P){
    return "{\"scene\":\""+P.scene+"\",\"radius\":"+fmt6(P.radius)+",\"mass\":"+fmt6(P.mass)
         + ",\"width\":"+fmti(P.width)+",\"height\":"+fmti(P.height)+",\"extent\":"+fmt6(P.extent)
         + ",\"engine\":\""+P.engine+"\",\"tol_oracle\":"+fmt6(P.tol_oracle)+",\"tol_rt_px\":"+fmti(P.tol_rt_px)+"}";
}
static std::string result_json(const Params& P, const Result& R){
    return "{\"scene\":\""+P.scene+"\",\"silhouette_radius\":"+fmt6(R.silhouette_radius)
         + ",\"image_extent\":"+fmt6(R.image_extent)+",\"width\":"+fmti(P.width)+",\"height\":"+fmti(P.height)
         + ",\"total_pixels\":"+fmti(R.total_pixels)+",\"hit_pixels\":"+fmti(R.hit_pixels)
         + ",\"hit_fraction\":"+fmt6(R.hit_fraction)+",\"area_measured\":"+fmt6(R.area_measured)
         + ",\"area_oracle\":"+fmt6(R.area_oracle)+",\"area_rel_err\":"+fmt6(R.area_rel_err)
         + ",\"engine\":\""+P.engine+"\",\"hit_pixels_rt\":"+fmti(R.hit_pixels_rt)
         + ",\"rt_baseline_delta\":"+fmti(R.rt_baseline_delta)+",\"rt_agrees\":"+fmti(R.rt_agrees)+"}";
}
static std::string gates_json(const Result& R){
    return std::string("[{\"id\":\"G-ORACLE-MISMATCH\",\"fired\":")+(R.g_oracle?"true":"false")
         + ",\"value\":"+fmt6(R.g_oracle_val)+",\"threshold\":"+fmt6(R.g_oracle_thr)+"},"
         + "{\"id\":\"G-RT-DIVERGE\",\"fired\":"+(R.g_rt?"true":"false")
         + ",\"value\":"+fmt6(R.g_rt_val)+",\"threshold\":"+fmt6(R.g_rt_thr)+"}]";
}
static std::string declared_body(const Params& P, const Result& R, const std::string& v){
    return "\"seed\":"+fmti(P.seed)+",\"params\":"+params_json(P)+",\"result\":"+result_json(P,R)
         + ",\"gates\":"+gates_json(R)+",\"verdict\":\""+v+"\"";
}
static std::string declared_object(const Params& P, const Result& R, const std::string& v){ return "{"+declared_body(P,R,v)+"}"; }
static std::string full_envelope(const Params& P, const Result& R, const std::string& v){
    return orrery::full_envelope("lens", LENS_VERSION, declared_body(P,R,v), FIREWALL);
}

// ------------------------------------------------------------------ compute one config -> Result
static Result compute(const Params& P, std::vector<unsigned char>* renderBuf){
    Result R;
    R.silhouette_radius = silhouette_radius(P);
    R.image_extent = P.extent;
    R.total_pixels = (long long)P.width*(long long)P.height;
    R.hit_pixels = baseline_hits(P, renderBuf);
    R.hit_fraction = (double)R.hit_pixels/(double)R.total_pixels;
    R.area_measured = R.hit_fraction * (2.0*P.extent)*(2.0*P.extent);
    R.area_oracle = area_oracle_of(P);
    R.area_rel_err = fabs(R.area_measured-R.area_oracle)/R.area_oracle;
    if(P.engine=="both"){
        R.hit_pixels_rt = rt_hits(P);
        R.rt_baseline_delta = R.hit_pixels_rt>=R.hit_pixels ? (R.hit_pixels_rt-R.hit_pixels) : (R.hit_pixels-R.hit_pixels_rt);
        R.rt_agrees = (R.rt_baseline_delta<=P.tol_rt_px) ? 1 : 0;
    }
    R.g_oracle = R.area_rel_err > P.tol_oracle; R.g_oracle_val=R.area_rel_err; R.g_oracle_thr=P.tol_oracle;
    R.g_rt = (P.engine=="both") && (R.rt_baseline_delta > P.tol_rt_px);
    R.g_rt_val = (P.engine=="both") ? (double)R.rt_baseline_delta : -1.0; R.g_rt_thr=(double)P.tol_rt_px;
    return R;
}

// ------------------------------------------------------------------ run one config (print + exit code)
static int run_config(const Params& P, bool do_print, std::string* declared_out){
    std::vector<unsigned char> rbuf;
    Result R = compute(P, P.render ? &rbuf : nullptr);
    std::string verdict = (R.g_oracle||R.g_rt) ? "fail" : "pass";
    if(declared_out) *declared_out = declared_object(P,R,verdict);
    if(do_print){
        if(P.render) write_ppm(P,rbuf);
        if(P.csv){
            FILE* f=fopen(P.csv_path.c_str(),"wb");
            if(!f){ fprintf(stderr,"error: cannot open --csv path: %s\n",P.csv_path.c_str()); std::exit(2); }
            fprintf(f,"scene,width,height,hit_pixels,hit_fraction,area_measured,area_oracle,area_rel_err,hit_pixels_rt,rt_baseline_delta\n");
            fprintf(f,"%s,%d,%d,%lld,%.6f,%.6f,%.6f,%.6f,%lld,%lld\n",P.scene.c_str(),P.width,P.height,
                    R.hit_pixels,R.hit_fraction,R.area_measured,R.area_oracle,R.area_rel_err,R.hit_pixels_rt,R.rt_baseline_delta);
            fclose(f);
        }
        if(P.json) printf("%s\n", full_envelope(P,R,verdict).c_str());
    }
    return (R.g_oracle||R.g_rt) ? 1 : 0;
}

// ------------------------------------------------------------------ golden
static Params golden_params(){
    Params P; P.scene="bhshadow"; P.mass=1.0; P.width=1024; P.height=1024; P.engine="both";
    P.tol_rt_px=64; P.seed=0; P.json=true; resolve(P); return P;
}
static int run_golden(){
    Params P=golden_params(); Result R=compute(P,nullptr);
    std::string verdict=(R.g_oracle||R.g_rt)?"fail":"pass";
    return golden_check("lens", declared_object(P,R,verdict), full_envelope(P,R,verdict));
}

// ------------------------------------------------------------------ selftest
static bool st(const char* n, bool ok){ return st_check(n,ok); }
static int run_selftest(){
    bool ok=true; fprintf(stderr,"lens --selftest (v%s)\n",LENS_VERSION);
    // blake2b KATs (RFC 7693)
    ok &= st("blake2b-256(\"\") KAT", blake2b_hex("")=="0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8");
    ok &= st("blake2b-256(\"abc\") KAT", blake2b_hex("abc")=="bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319");
    // exact scene oracles
    { Params P; P.scene="bhshadow"; P.mass=1.0; ok &= st("b_crit=sqrt(27) M", fabs(silhouette_radius(P)-5.196152422706632)<1e-9);
      ok &= st("shadow cross-section = 27 pi M^2", fabs(area_oracle_of(P)-27.0*PI)<1e-9); }
    { Params P; P.scene="sphere"; P.radius=2.0; ok &= st("sphere oracle = pi R^2", fabs(area_oracle_of(P)-4.0*PI)<1e-9); }
    // resolve derives extent + tol_oracle
    { Params P; P.scene="sphere"; P.radius=1.0; resolve(P);
      ok &= st("extent derive = 1.5*silR", fabs(P.extent-1.5)<1e-12);
      ok &= st("tol_oracle derived >0", P.tol_oracle>0.0); }
    // baseline edge cases
    { Params P; P.scene="sphere"; P.radius=10.0; P.width=4; P.height=4; P.extent=1.0;
      ok &= st("baseline all-inside", baseline_hits(P,nullptr)==16); }
    { Params P; P.scene="sphere"; P.radius=0.0001; P.width=4; P.height=4; P.extent=1.0;
      ok &= st("baseline all-outside", baseline_hits(P,nullptr)==0); }
    // baseline reproduces the oracle (convergence)
    { Params P; P.scene="sphere"; P.radius=1.0; P.width=512; P.height=512; resolve(P);
      Result R=compute(P,nullptr); ok &= st("baseline area_rel_err<0.005 @512", R.area_rel_err<0.005); }
    // OptiX RT agrees with the baseline (I-13 paired-oracle) + gate passes
    { Params P; P.scene="sphere"; P.radius=1.0; P.width=256; P.height=256; P.engine="both"; resolve(P);
      Result R=compute(P,nullptr);
      ok &= st("RT ran (hit_pixels_rt>=0)", R.hit_pixels_rt>=0);
      ok &= st("RT agrees with baseline (delta<=tol_rt_px)", R.rt_agrees==1);
      ok &= st("no gate fired at good config", !R.g_oracle && !R.g_rt); }
    // determinism: full declared object (incl. RT count) identical across 2 runs
    { Params P; P.scene="bhshadow"; P.mass=1.0; P.width=256; P.height=256; P.engine="both"; resolve(P);
      std::string a,b; run_config(P,false,&a); run_config(P,false,&b);
      ok &= st("declared identical across 2 runs (RT deterministic)", a==b); }
    // gate teeth: an impossibly tight oracle tolerance fires G-ORACLE-MISMATCH -> exit 1
    { Params P; P.scene="sphere"; P.radius=1.0; P.width=64; P.height=64; P.engine="baseline"; resolve(P); P.tol_oracle=1e-9;
      ok &= st("G-ORACLE-MISMATCH fires when forced (exit 1)", run_config(P,false,nullptr)==1); }
    fprintf(stderr, ok?"SELFTEST PASS\n":"SELFTEST FAIL\n"); return ok?0:1;
}

// ------------------------------------------------------------------ CLI
int main(int argc,char** argv){
    Params P;
    for(int i=1;i<argc;i++){ std::string a=argv[i];
        auto val=[&](const char* f)->const char*{ if(i+1>=argc) die2(std::string("missing value for ")+f); return argv[++i]; };
        if(a=="--scene") P.scene=val("--scene");
        else if(a=="--radius") P.radius=parse_d(val("--radius"),"--radius");
        else if(a=="--mass") P.mass=parse_d(val("--mass"),"--mass");
        else if(a=="--width") P.width=(int)parse_ll(val("--width"),"--width");
        else if(a=="--height") P.height=(int)parse_ll(val("--height"),"--height");
        else if(a=="--extent") P.extent=parse_d(val("--extent"),"--extent");
        else if(a=="--engine") P.engine=val("--engine");
        else if(a=="--tol-oracle") P.tol_oracle=parse_d(val("--tol-oracle"),"--tol-oracle");
        else if(a=="--tol-rt-px") P.tol_rt_px=parse_ll(val("--tol-rt-px"),"--tol-rt-px");
        else if(a=="--render"){ P.render=true; P.render_path=val("--render"); }
        else if(a=="--seed") P.seed=parse_ll(val("--seed"),"--seed");
        else if(a=="--json") P.json=true;
        else if(a=="--csv"){ P.csv=true; P.csv_path=val("--csv"); }
        else if(a=="--selftest") P.selftest=true;
        else if(a=="--golden") P.golden=true;
        else die2("unknown flag: "+a);
    }
    if(P.selftest) return run_selftest();
    if(P.golden)   return run_golden();
    // validation (bad input -> exit 2)
    if(P.scene!="sphere" && P.scene!="bhshadow") die2("--scene must be sphere|bhshadow");
    if(P.engine!="baseline" && P.engine!="both")  die2("--engine must be baseline|both");
    if(!(P.radius>0.0)) die2("--radius must be >0");
    if(!(P.mass>0.0))   die2("--mass must be >0");
    if(P.width<16||P.width>8192)   die2("--width out of range [16,8192]");
    if(P.height<16||P.height>8192) die2("--height out of range [16,8192]");
    if(P.tol_rt_px<0)  die2("--tol-rt-px must be >=0");
    if(P.seed<0)       die2("--seed must be >=0");
    resolve(P);   // derives extent+tol_oracle; validates extent>silhouette (exit 2)
    if(!P.json && !P.csv && !P.render) P.json=true;
    return run_config(P,true,nullptr);
}
