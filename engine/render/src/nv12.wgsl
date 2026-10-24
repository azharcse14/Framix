// NV12 decoder frame (R8 luma + RG8 half-size chroma) to RGB, placed on the target. Composed
// after shaders/common/fullscreen.wgsl, shaders/common/ycbcr.wgsl and
// shaders/common/placement.wgsl.
@group(0) @binding(0) var luma: texture_2d<f32>;
@group(0) @binding(1) var chroma: texture_2d<f32>;
@group(0) @binding(2) var planes: sampler;
@group(0) @binding(3) var<uniform> space: Ycbcr;
@group(0) @binding(4) var<uniform> placement: Placement;

@fragment
fn fs(in: VsOut) -> @location(0) vec4<f32> {
  let uv = source_uv(in.uv, placement);
  let y = textureSample(luma, planes, uv).r;
  let cbcr = textureSample(chroma, planes, uv).rg;
  return vec4<f32>(on_picture(ycbcr_to_rgb(y, cbcr, space), in.uv, placement), 1.0);
}
