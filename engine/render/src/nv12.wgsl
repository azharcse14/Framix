// NV12 decoder frame (R8 luma + RG8 half-size chroma) to RGB. Composed after
// shaders/common/fullscreen.wgsl and shaders/common/ycbcr.wgsl.
@group(0) @binding(0) var luma: texture_2d<f32>;
@group(0) @binding(1) var chroma: texture_2d<f32>;
@group(0) @binding(2) var planes: sampler;
@group(0) @binding(3) var<uniform> space: Ycbcr;

@fragment
fn fs(in: VsOut) -> @location(0) vec4<f32> {
  let y = textureSample(luma, planes, in.uv).r;
  let cbcr = textureSample(chroma, planes, in.uv).rg;
  return vec4<f32>(ycbcr_to_rgb(y, cbcr, space), 1.0);
}
