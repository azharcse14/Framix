//! The picture's frame on the canvas (P1-063): what the canvas outline draws, from the same
//! placement the shader samples with.

use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::placement::{canvas_to_source, picture_size};
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
fn size_is(m: &Media, t: ClipTransform, canvas: AspectRatio, want: (f32, f32)) {
    let (w, h) = picture_size(m, &t, canvas);
    assert!(
        (w - want.0).abs() < 1e-4 && (h - want.1).abs() < 1e-4,
        "({w}, {h}), want {want:?}"
    );
}

#[test]
fn a_picture_of_the_canvas_shape_fills_it() {
    size_is(
        &media(160, 90, 0),
        ClipTransform::default(),
        aspect(16, 9),
        (1.0, 1.0),
    );
}

#[test]
fn a_wide_picture_on_a_tall_canvas_is_full_width_and_short() {
    size_is(
        &media(1920, 1080, 0),
        ClipTransform::default(),
        aspect(9, 16),
        (1.0, 81.0 / 256.0),
    );
}

#[test]
fn turns_and_the_media_rotation_swap_the_sides() {
    let turned = ClipTransform {
        turns: 1,
        ..ClipTransform::default()
    };
    size_is(&media(1920, 1080, 0), turned, aspect(9, 16), (1.0, 1.0));
    size_is(
        &media(1920, 1080, 90),
        ClipTransform::default(),
        aspect(9, 16),
        (1.0, 1.0),
    );
}

#[test]
fn crop_and_scale_shrink_the_frame() {
    // 160x90 with the left half cropped: 80x90, fitted by height on 16:9.
    let cropped = ClipTransform {
        crop: Crop {
            left: 80,
            ..Crop::default()
        },
        ..ClipTransform::default()
    };
    size_is(&media(160, 90, 0), cropped, aspect(16, 9), (0.5, 1.0));
    let half = ClipTransform {
        scale: 500,
        x: 2500,
        ..ClipTransform::default()
    };
    size_is(&media(160, 90, 0), half, aspect(16, 9), (0.5, 0.5));
}

#[test]
fn the_frame_edges_are_where_the_shader_meets_the_source_edges() {
    let m = media(1920, 1080, 90);
    let t = ClipTransform {
        turns: 1,
        flip_h: true,
        flip_v: false,
        crop: Crop {
            left: 100,
            top: 40,
            right: 300,
            bottom: 0,
        },
        x: -1200,
        y: 800,
        scale: 730,
    };
    let canvas = aspect(4, 5);
    let (w, h) = picture_size(&m, &t, canvas);
    let (cx, cy) = (0.5 + t.x as f32 / 1e4, 0.5 + t.y as f32 / 1e4);
    let map = canvas_to_source(&m, &t, canvas);
    // Each corner of the frame lands on a corner of the cropped source.
    for (u, v) in [
        (cx - w / 2.0, cy - h / 2.0),
        (cx + w / 2.0, cy - h / 2.0),
        (cx - w / 2.0, cy + h / 2.0),
        (cx + w / 2.0, cy + h / 2.0),
    ] {
        let (sx, sy) = map.apply(u, v);
        let on_x = [100.0 / 1920.0, 1620.0 / 1920.0]
            .iter()
            .any(|e: &f32| (sx - e).abs() < 1e-3);
        let on_y = [40.0 / 1080.0, 1.0]
            .iter()
            .any(|e: &f32| (sy - e).abs() < 1e-3);
        assert!(on_x && on_y, "corner ({u}, {v}) -> ({sx}, {sy})");
    }
}

#[test]
fn a_color_fills_the_canvas_whatever_its_shape() {
    // A color is a 1x1 picture, but render fills the whole canvas with it.
    size_is(
        &Media::solid(0xff00_00ff),
        ClipTransform::default(),
        aspect(16, 9),
        (1.0, 1.0),
    );
}

#[test]
fn an_odd_quarter_turn_frame_meets_the_shader_too() {
    let m = media(1920, 1080, 0);
    let t = ClipTransform {
        turns: 1,
        scale: 640,
        x: 900,
        y: -300,
        ..ClipTransform::default()
    };
    let canvas = aspect(16, 9);
    let (w, h) = picture_size(&m, &t, canvas);
    let (cx, cy) = (0.5 + t.x as f32 / 1e4, 0.5 + t.y as f32 / 1e4);
    let map = canvas_to_source(&m, &t, canvas);
    for (u, v) in [(cx - w / 2.0, cy - h / 2.0), (cx + w / 2.0, cy + h / 2.0)] {
        let (sx, sy) = map.apply(u, v);
        let edge = |s: f32| s.abs() < 1e-3 || (s - 1.0).abs() < 1e-3;
        assert!(edge(sx) && edge(sy), "corner ({u}, {v}) -> ({sx}, {sy})");
    }
}
