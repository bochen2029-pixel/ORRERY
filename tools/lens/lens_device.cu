// lens_device.cu — OptiX device programs for `lens` (the RT-core silhouette render).
// Compiled to PTX by `nvcc -ptx` (NO --use_fast_math, per D-021), embedded into
// lens.exe by embed_ptx.py, and loaded at runtime via optixModuleCreate.
//
// Orthographic parallel-ray raygen + built-in sphere intersection. The closest-hit
// / miss programs return a single payload bit (1 hit / 0 miss); raygen writes it to
// the per-pixel hit buffer. No shading here — the declared measurement is the
// integer hit-count; the (non-declared) --render image is shaded on the host.
#include <optix.h>
#include "lens_params.h"

extern "C" { __constant__ LensParams params; }

extern "C" __global__ void __raygen__lens() {
  const uint3 idx = optixGetLaunchIndex();
  const unsigned x = idx.x, y = idx.y;
  // Pixel-center orthographic ray: origin on the image plane, direction +z.
  const float u = params.extent * (2.0f * ((float)x + 0.5f) / (float)params.width  - 1.0f);
  const float v = params.extent * (2.0f * ((float)y + 0.5f) / (float)params.height - 1.0f);
  const float Z0 = 100.0f * params.extent;           // start well outside the sphere
  const float3 origin = make_float3(u, v, -Z0);
  const float3 dir    = make_float3(0.0f, 0.0f, 1.0f);
  unsigned int hit = 0u;
  optixTrace(params.handle, origin, dir, 0.0f, 1e16f, 0.0f,
             OptixVisibilityMask(255), OPTIX_RAY_FLAG_NONE, 0u, 0u, 0u, hit);
  params.hits[y * params.width + x] = (unsigned char)hit;
}

extern "C" __global__ void __miss__lens()       { optixSetPayload_0(0u); }
extern "C" __global__ void __closesthit__lens() { optixSetPayload_0(1u); }
