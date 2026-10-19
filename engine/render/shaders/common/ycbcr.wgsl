// YCbCr -> RGB for decoder frames. Coefficients come from Rust (YcbcrSpace::uniform), so each
// standard is defined once.
struct Ycbcr {
  // Luma weights of red and blue: BT.601 0.299 / 0.114, BT.709 0.2126 / 0.0722.
  kr: f32,
  kb: f32,
  // 1 for video range (Y 16-235, CbCr 16-240), 0 for full range (0-255).
  video_range: u32,
  _pad: u32,
};

// `y` and `cbcr` are the normalized 8-bit samples as the texture returns them.
fn ycbcr_to_rgb(y: f32, cbcr: vec2<f32>, k: Ycbcr) -> vec3<f32> {
  var luma = y;
  var chroma = cbcr - vec2<f32>(128.0 / 255.0);
  if (k.video_range == 1u) {
    luma = (y * 255.0 - 16.0) / 219.0;
    chroma = (cbcr * 255.0 - 128.0) / 224.0;
  }
  let r = luma + 2.0 * (1.0 - k.kr) * chroma.y;
  let b = luma + 2.0 * (1.0 - k.kb) * chroma.x;
  let g = (luma - k.kr * r - k.kb * b) / (1.0 - k.kr - k.kb);
  return clamp(vec3<f32>(r, g, b), vec3<f32>(0.0), vec3<f32>(1.0));
}
