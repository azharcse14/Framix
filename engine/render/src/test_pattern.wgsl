// SPIKE (P1-001): a horizontal red ramp and a vertical green ramp, so a readback can tell
// orientation and that the shader ran. Composed after shaders/common/fullscreen.wgsl.
@fragment
fn fs(in: VsOut) -> @location(0) vec4<f32> {
  return vec4<f32>(in.uv.x, in.uv.y, 0.5, 1.0);
}
