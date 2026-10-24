// An RGBA8 frame (a photo, or a decoder frame already converted to RGB) placed on the target.
// Composed after shaders/common/fullscreen.wgsl and shaders/common/placement.wgsl.
@group(0) @binding(0) var frame: texture_2d<f32>;
@group(0) @binding(1) var frame_sampler: sampler;
@group(0) @binding(2) var<uniform> placement: Placement;

@fragment
fn fs(in: VsOut) -> @location(0) vec4<f32> {
  let uv = source_uv(in.uv, placement);
  // Sampled before the select: textureSample needs uniform control flow.
  let rgb = textureSample(frame, frame_sampler, uv).rgb;
  return vec4<f32>(on_picture(rgb, in.uv, placement), 1.0);
}
