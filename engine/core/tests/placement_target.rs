//! The canvas inside a render target of another shape (P1-060): the preview texture is a fixed
//! size, so the canvas is fitted in it, centred, with black around.

use framix_core::aspect::AspectRatio;
use framix_core::placement::{Affine, target_to_canvas};

fn close(a: (f32, f32), b: (f32, f32)) -> bool {
    (a.0 - b.0).abs() < 1e-4 && (a.1 - b.1).abs() < 1e-4
}

#[test]
fn a_tall_canvas_is_pillarboxed_in_a_wide_target() {
    // 9:16 in 1280x720: the canvas is 405 px wide, centred.
    let t = target_to_canvas(AspectRatio::new(9, 16).unwrap(), 1280, 720);
    let left = (1280.0 - 405.0) / 2.0 / 1280.0;
    assert!(close(t.apply(left, 0.0), (0.0, 0.0)));
    assert!(close(t.apply(1.0 - left, 1.0), (1.0, 1.0)));
    assert!(t.apply(0.0, 0.5).0 < 0.0, "left of the canvas is outside it");
}

#[test]
fn a_matching_target_is_the_canvas() {
    let t = target_to_canvas(AspectRatio::new(16, 9).unwrap(), 1920, 1080);
    assert!(close(t.apply(0.0, 0.0), (0.0, 0.0)));
    assert!(close(t.apply(1.0, 1.0), (1.0, 1.0)));
}

#[test]
fn maps_compose_in_order() {
    let half = Affine {
        m: [0.5, 0.0, 0.0, 0.0, 0.5, 0.0],
    };
    let shift = Affine {
        m: [1.0, 0.0, 0.25, 0.0, 1.0, 0.0],
    };
    // Halve, then shift.
    assert!(close(half.then(&shift).apply(1.0, 1.0), (0.75, 0.5)));
    assert!(close(Affine::IDENTITY.then(&shift).apply(0.0, 0.0), (0.25, 0.0)));
}
