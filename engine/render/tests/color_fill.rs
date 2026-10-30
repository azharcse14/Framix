//! A color clip (P1-048) fills the canvas with its color, black around it.
#![cfg(target_vendor = "apple")]

mod common;

use common::{bgra_target, ptr, rgb};

use framix_core::placement::Affine;
use framix_render::Gpu;

#[test]
fn fills_the_canvas_with_the_color() {
    let gpu = Gpu::new().expect("gpu");
    let (w, h) = (32, 8);
    let target = bgra_target(w, h);
    // SAFETY: `target` is a live id<MTLTexture> on the system default device.
    let out = unsafe { gpu.wrap_metal_texture(ptr(&target)) }.expect("wrap target");
    // The canvas is the target's left half.
    let canvas = Affine {
        m: [2.0, 0.0, 0.0, 0.0, 1.0, 0.0],
    };
    gpu.draw_color(&out, 0x3366_99ff, canvas).expect("draw");
    assert_eq!(rgb(&target, w / 4, h / 2), [0x33, 0x66, 0x99]);
    assert_eq!(rgb(&target, 3 * w / 4, h / 2), [0, 0, 0]);
}
