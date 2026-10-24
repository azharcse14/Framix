// Where the picture lands (framix_core::placement): maps the target's uv to the canvas's uv
// (the canvas is fitted in the target) and to the source's uv. The maps come from Rust, so
// the placement rules live in one place. Each map is two rows of a 2x3 matrix; w unused.
struct Placement {
  canvas0: vec4<f32>,
  canvas1: vec4<f32>,
  source0: vec4<f32>,
  source1: vec4<f32>,
};

fn apply_map(row0: vec4<f32>, row1: vec4<f32>, uv: vec2<f32>) -> vec2<f32> {
  let h = vec3<f32>(uv, 1.0);
  return vec2<f32>(dot(row0.xyz, h), dot(row1.xyz, h));
}

fn source_uv(uv: vec2<f32>, p: Placement) -> vec2<f32> {
  return apply_map(p.source0, p.source1, uv);
}

fn inside(uv: vec2<f32>) -> bool {
  return all(uv >= vec2<f32>(0.0)) && all(uv <= vec2<f32>(1.0));
}

// The sampled colour where the target's `uv` shows the picture on the canvas; black elsewhere.
fn on_picture(rgb: vec3<f32>, uv: vec2<f32>, p: Placement) -> vec3<f32> {
  let shown = inside(apply_map(p.canvas0, p.canvas1, uv)) && inside(source_uv(uv, p));
  return select(vec3<f32>(0.0), rgb, shown);
}
