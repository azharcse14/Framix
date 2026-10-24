//! Where a clip's picture lands on the canvas (P1-060): canvas UV to source texture UV.
//! UVs run 0..1 from the top-left; the source is the media's stored (unrotated) pixels.

use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::placement::canvas_to_source;
use framix_core::timeline::{ClipTransform, Crop};

fn media(width: u32, height: u32, rotation: u32) -> Media {
    Media::validate(RawMedia {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width,
        height,
        rotation,
        codec: String::new(),
    })
    .unwrap()
}

fn aspect(w: u32, h: u32) -> AspectRatio {
    AspectRatio::new(w, h).unwrap()
}

#[track_caller]
fn maps(
    m: &Media,
    t: ClipTransform,
    canvas: AspectRatio,
    pairs: &[((f32, f32), (f32, f32))],
) {
    let a = canvas_to_source(m, &t, canvas);
    for &((u, v), (su, sv)) in pairs {
        let (x, y) = a.apply(u, v);
        assert!(
            (x - su).abs() < 1e-4 && (y - sv).abs() < 1e-4,
            "canvas ({u}, {v}) -> ({x}, {y}), want ({su}, {sv})"
        );
    }
}

#[test]
fn identity_fills_a_canvas_of_the_same_shape() {
    maps(
        &media(160, 90, 0),
        ClipTransform::default(),
        aspect(16, 9),
        &[
            ((0.0, 0.0), (0.0, 0.0)),
            ((1.0, 1.0), (1.0, 1.0)),
            ((0.25, 0.75), (0.25, 0.75)),
        ],
    );
}

#[test]
fn a_wide_picture_is_letterboxed_on_a_tall_canvas() {
    // 16:9 in 9:16: full width, 81/256 of the height, centred.
    let half = 81.0 / 512.0;
    maps(
        &media(160, 90, 0),
        ClipTransform::default(),
        aspect(9, 16),
        &[
            ((0.0, 0.5 - half), (0.0, 0.0)),
            ((1.0, 0.5 + half), (1.0, 1.0)),
            ((0.5, 0.5), (0.5, 0.5)),
        ],
    );
    let a = canvas_to_source(&media(160, 90, 0), &ClipTransform::default(), aspect(9, 16));
    let (_, v) = a.apply(0.5, 0.0);
    assert!(v < 0.0, "the bar above the picture samples outside the source");
}

#[test]
fn a_quarter_turn_shows_the_left_edge_on_top() {
    let turn = ClipTransform {
        turns: 1,
        ..ClipTransform::default()
    };
    maps(
        &media(100, 100, 0),
        turn,
        aspect(1, 1),
        &[((0.0, 0.0), (0.0, 1.0)), ((1.0, 0.0), (0.0, 0.0))],
    );
}

#[test]
fn turns_add_to_the_media_rotation() {
    // Stored 160x90 shown at 90 degrees, turned three more quarters: upright again.
    let back = ClipTransform {
        turns: 3,
        ..ClipTransform::default()
    };
    maps(
        &media(160, 90, 90),
        back,
        aspect(16, 9),
        &[((0.0, 0.0), (0.0, 0.0)), ((1.0, 1.0), (1.0, 1.0))],
    );
}

#[test]
fn the_media_rotation_alone_turns_the_picture() {
    // A portrait phone video: stored 160x90, shown 90x160.
    maps(
        &media(160, 90, 90),
        ClipTransform::default(),
        aspect(9, 16),
        &[((0.0, 0.0), (0.0, 1.0)), ((1.0, 0.0), (0.0, 0.0))],
    );
}

#[test]
fn flips_mirror_after_the_turn() {
    let mirror = ClipTransform {
        flip_h: true,
        ..ClipTransform::default()
    };
    maps(
        &media(100, 100, 0),
        mirror,
        aspect(1, 1),
        &[((0.0, 0.5), (1.0, 0.5)), ((0.25, 0.0), (0.75, 0.0))],
    );
    // Turn then mirror left-right is a transpose.
    let both = ClipTransform {
        turns: 1,
        flip_h: true,
        ..ClipTransform::default()
    };
    maps(
        &media(100, 100, 0),
        both,
        aspect(1, 1),
        &[((0.0, 0.0), (0.0, 0.0)), ((1.0, 0.0), (0.0, 1.0))],
    );
    let upside = ClipTransform {
        flip_v: true,
        ..ClipTransform::default()
    };
    maps(
        &media(100, 100, 0),
        upside,
        aspect(1, 1),
        &[((0.5, 0.0), (0.5, 1.0))],
    );
}

#[test]
fn the_crop_cuts_source_pixels_before_the_fit() {
    // 200x100 minus the left 100 pixels is a 100x100 square that fills a square canvas.
    let crop = ClipTransform {
        crop: Crop {
            left: 100,
            ..Crop::default()
        },
        ..ClipTransform::default()
    };
    maps(
        &media(200, 100, 0),
        crop,
        aspect(1, 1),
        &[((0.0, 0.0), (0.5, 0.0)), ((1.0, 1.0), (1.0, 1.0))],
    );
}

#[test]
fn scale_and_position_move_the_fitted_picture() {
    let double = ClipTransform {
        scale: 2000,
        ..ClipTransform::default()
    };
    maps(
        &media(100, 100, 0),
        double,
        aspect(1, 1),
        &[((0.25, 0.25), (0.0, 0.0)), ((0.5, 0.5), (0.5, 0.5))],
    );
    // x and y are in 1/10000 of the canvas: half a canvas right, a quarter down.
    let moved = ClipTransform {
        x: 5000,
        y: 2500,
        ..ClipTransform::default()
    };
    maps(
        &media(100, 100, 0),
        moved,
        aspect(1, 1),
        &[((1.0, 0.75), (0.5, 0.5)), ((0.5, 0.25), (0.0, 0.0))],
    );
}
