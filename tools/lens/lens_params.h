// lens_params.h — launch params shared by the OptiX device programs (lens_device.cu)
// and the host pipeline (lens.cu). NOT the public contract (that is
// contracts/lens.contract.md) — this is the internal host/device boundary.
//
// The RT path casts orthographic parallel rays (dir = +z) from an image plane
// spanning [-extent, extent]^2 in x,y at z = -100*extent, against a single-sphere
// GAS centered at the origin. Each pixel records 1 (hit) or 0 (miss). This is the
// silhouette render whose hit-count is cross-checked against the analytic baseline.
#pragma once
#include <optix.h>
#include <vector_types.h>
#include <cstdint>

struct LensParams {
  OptixTraversableHandle handle;   // GAS over the single silhouette sphere
  unsigned char*         hits;     // [width*height] row-major, 1=hit 0=miss
  int                    width;
  int                    height;
  float                  extent;   // orthographic half-extent (world units)
};
