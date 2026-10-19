// An RGBA8 decoder frame (already converted to RGB) drawn to fill the target. Composed after
// shaders/common/fullscreen.wgsl.
@group(0) @binding(0) var frame: texture_2d<f32>;
@group(0) @binding(1) var frame_sampler: sampler;

@fragment
fn fs(in: VsOut) -> @location(0) vec4<f32> {
  return vec4<f32>(textureSample(frame, frame_sampler, in.uv).rgb, 1.0);
}
