// Fullscreen triangle: one draw of 3 vertices covers the target; uv (0, 0) is the top-left.
struct VsOut {
  @builtin(position) pos: vec4<f32>,
  @location(0) uv: vec2<f32>,
};

@vertex
fn vs(@builtin(vertex_index) i: u32) -> VsOut {
  let uv = vec2<f32>(f32((i << 1u) & 2u), f32(i & 2u));
  var out: VsOut;
  out.pos = vec4<f32>(uv * 2.0 - 1.0, 0.0, 1.0);
  out.uv = vec2<f32>(uv.x, 1.0 - uv.y);
  return out;
}
