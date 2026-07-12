// rt_bench.cu — SPIKE measurement: raw OptiX trace throughput on this GPU (traces/sec).
// Reuses the lens v1 embedded PTX + sphere-GAS pipeline: one orthographic sphere trace per ray.
// This is the per-trace cost that an RT-accelerated geodesic "shell-marcher" pays PER SEGMENT.
// Compared against geodesic.exe's fp64 baseline (full integration in one pass), it decides the
// D-004 compute-SPIKE: RT wins only if (throughput / traces-per-ray-at-matched-accuracy) beats
// the baseline's ray-integration rate. THROWAWAY spike code (SPIKES.md).
//
// Build: nvcc -O3 -arch=sm_89 -std=c++17 -I"<OptiX>\include" rt_bench.cu -o rt_bench.exe -lcuda -ladvapi32
#include <optix.h>
#include <optix_stubs.h>
#include <optix_function_table_definition.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdint>
#include <vector>
#include "../lens_params.h"
#include "../lens_device_ptx.h"   // LENS_DEVICE_PTX / LENS_DEVICE_PTX_len (v1 ortho sphere raygen)

#define OX(x) do{ OptixResult r=(x); if(r!=OPTIX_SUCCESS){ fprintf(stderr,"OptiX %d (%s) @ %d\n",(int)r,optixGetErrorName(r),__LINE__); return 2;} }while(0)
#define CU(x) do{ cudaError_t e=(x); if(e!=cudaSuccess){ fprintf(stderr,"CUDA %s @ %d\n",cudaGetErrorString(e),__LINE__); return 2;} }while(0)

template<typename T> struct Rec { __align__(OPTIX_SBT_RECORD_ALIGNMENT) char h[OPTIX_SBT_RECORD_HEADER_SIZE]; T d; };
struct Empty{}; using ER=Rec<Empty>;

int main(int argc,char**argv){
    int N = argc>1 ? atoi(argv[1]) : 4096;      // NxN rays
    int iters = argc>2 ? atoi(argv[2]) : 20;
    float silR = 5.196152422706632f;            // b_crit = sqrt(27) (M=1)
    float extent = 1.5f*silR;

    CU(cudaFree(nullptr)); OX(optixInit());
    OptixDeviceContext ctx=nullptr; OptixDeviceContextOptions co={};
    OX(optixDeviceContextCreate(0,&co,&ctx));
    float3 center=make_float3(0,0,0); CUdeviceptr dC=0,dR=0;
    CU(cudaMalloc((void**)&dC,sizeof(float3))); CU(cudaMemcpy((void*)dC,&center,sizeof(float3),cudaMemcpyHostToDevice));
    CU(cudaMalloc((void**)&dR,sizeof(float)));  CU(cudaMemcpy((void*)dR,&silR,sizeof(float),cudaMemcpyHostToDevice));
    OptixBuildInput bi={}; bi.type=OPTIX_BUILD_INPUT_TYPE_SPHERES;
    bi.sphereArray.vertexBuffers=&dC; bi.sphereArray.numVertices=1; bi.sphereArray.radiusBuffers=&dR; bi.sphereArray.singleRadius=1;
    unsigned gf[1]={OPTIX_GEOMETRY_FLAG_DISABLE_ANYHIT}; bi.sphereArray.flags=gf; bi.sphereArray.numSbtRecords=1;
    OptixAccelBuildOptions ao={}; ao.buildFlags=OPTIX_BUILD_FLAG_PREFER_FAST_TRACE; ao.operation=OPTIX_BUILD_OPERATION_BUILD;
    OptixAccelBufferSizes sz={}; OX(optixAccelComputeMemoryUsage(ctx,&ao,&bi,1,&sz));
    CUdeviceptr dT=0,dG=0; CU(cudaMalloc((void**)&dT,sz.tempSizeInBytes)); CU(cudaMalloc((void**)&dG,sz.outputSizeInBytes));
    OptixTraversableHandle gas=0; OX(optixAccelBuild(ctx,0,&ao,&bi,1,dT,sz.tempSizeInBytes,dG,sz.outputSizeInBytes,&gas,nullptr,0)); CU(cudaDeviceSynchronize());
    OptixModuleCompileOptions mco={}; mco.maxRegisterCount=OPTIX_COMPILE_DEFAULT_MAX_REGISTER_COUNT; mco.optLevel=OPTIX_COMPILE_OPTIMIZATION_DEFAULT; mco.debugLevel=OPTIX_COMPILE_DEBUG_LEVEL_MINIMAL;
    OptixPipelineCompileOptions pco={}; pco.traversableGraphFlags=OPTIX_TRAVERSABLE_GRAPH_FLAG_ALLOW_SINGLE_GAS; pco.numPayloadValues=1; pco.numAttributeValues=1; pco.pipelineLaunchParamsVariableName="params"; pco.usesPrimitiveTypeFlags=OPTIX_PRIMITIVE_TYPE_FLAGS_SPHERE;
    char log[4096]; size_t ls=sizeof(log); OptixModule mod=nullptr;
    OX(optixModuleCreate(ctx,&mco,&pco,(const char*)LENS_DEVICE_PTX,LENS_DEVICE_PTX_len,log,&ls,&mod));
    OptixBuiltinISOptions bis={}; bis.builtinISModuleType=OPTIX_PRIMITIVE_TYPE_SPHERE; OptixModule sm=nullptr; OX(optixBuiltinISModuleGet(ctx,&mco,&pco,&bis,&sm));
    OptixProgramGroupOptions po={}; OptixProgramGroup rg=nullptr,ms=nullptr,ht=nullptr;
    OptixProgramGroupDesc drg={}; drg.kind=OPTIX_PROGRAM_GROUP_KIND_RAYGEN; drg.raygen.module=mod; drg.raygen.entryFunctionName="__raygen__lens"; ls=sizeof(log); OX(optixProgramGroupCreate(ctx,&drg,1,&po,log,&ls,&rg));
    OptixProgramGroupDesc dms={}; dms.kind=OPTIX_PROGRAM_GROUP_KIND_MISS; dms.miss.module=mod; dms.miss.entryFunctionName="__miss__lens"; ls=sizeof(log); OX(optixProgramGroupCreate(ctx,&dms,1,&po,log,&ls,&ms));
    OptixProgramGroupDesc dht={}; dht.kind=OPTIX_PROGRAM_GROUP_KIND_HITGROUP; dht.hitgroup.moduleCH=mod; dht.hitgroup.entryFunctionNameCH="__closesthit__lens"; dht.hitgroup.moduleIS=sm; ls=sizeof(log); OX(optixProgramGroupCreate(ctx,&dht,1,&po,log,&ls,&ht));
    OptixProgramGroup grp[]={rg,ms,ht}; OptixPipelineLinkOptions plo={}; plo.maxTraceDepth=1; OptixPipeline pipe=nullptr; ls=sizeof(log); OX(optixPipelineCreate(ctx,&pco,&plo,grp,3,log,&ls,&pipe)); OX(optixPipelineSetStackSize(pipe,0,0,2048,1));
    ER rrg,rms,rht; OX(optixSbtRecordPackHeader(rg,&rrg)); OX(optixSbtRecordPackHeader(ms,&rms)); OX(optixSbtRecordPackHeader(ht,&rht));
    CUdeviceptr sRg=0,sMs=0,sHt=0; CU(cudaMalloc((void**)&sRg,sizeof(ER))); CU(cudaMalloc((void**)&sMs,sizeof(ER))); CU(cudaMalloc((void**)&sHt,sizeof(ER)));
    CU(cudaMemcpy((void*)sRg,&rrg,sizeof(ER),cudaMemcpyHostToDevice)); CU(cudaMemcpy((void*)sMs,&rms,sizeof(ER),cudaMemcpyHostToDevice)); CU(cudaMemcpy((void*)sHt,&rht,sizeof(ER),cudaMemcpyHostToDevice));
    OptixShaderBindingTable sbt={}; sbt.raygenRecord=sRg; sbt.missRecordBase=sMs; sbt.missRecordStrideInBytes=sizeof(ER); sbt.missRecordCount=1; sbt.hitgroupRecordBase=sHt; sbt.hitgroupRecordStrideInBytes=sizeof(ER); sbt.hitgroupRecordCount=1;
    unsigned char* dhits=nullptr; CU(cudaMalloc((void**)&dhits,(size_t)N*N));
    LensParams lp={}; lp.handle=gas; lp.hits=dhits; lp.width=N; lp.height=N; lp.extent=extent;
    CUdeviceptr dp=0; CU(cudaMalloc((void**)&dp,sizeof(LensParams))); CU(cudaMemcpy((void*)dp,&lp,sizeof(LensParams),cudaMemcpyHostToDevice));
    // warmup
    OX(optixLaunch(pipe,0,dp,sizeof(LensParams),&sbt,N,N,1)); CU(cudaDeviceSynchronize());
    cudaEvent_t a,b; cudaEventCreate(&a); cudaEventCreate(&b);
    cudaEventRecord(a);
    for(int i=0;i<iters;i++) OX(optixLaunch(pipe,0,dp,sizeof(LensParams),&sbt,N,N,1));
    cudaEventRecord(b); CU(cudaDeviceSynchronize());
    float ms_total=0; cudaEventElapsedTime(&ms_total,a,b);
    double rays=(double)N*N*iters; double sec=ms_total/1000.0;
    printf("[rt_bench] %dx%d rays x %d iters = %.3g traces in %.2f ms  ->  %.3g traces/sec (1 trace/ray)\n",
           N,N,iters,rays,ms_total,rays/sec);
    printf("[rt_bench] per-launch: %.3f ms for %d rays  (%.3g rays/sec at 1 trace each)\n", ms_total/iters, N*N, (double)N*N/(ms_total/iters/1000.0));
    return 0;
}
