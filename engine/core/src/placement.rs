//! Where a clip's picture lands on the canvas (P1-060), as the map the shader samples with.
//! Geometry, not time, so floats are fine here.

use crate::aspect::AspectRatio;
use crate::media::Media;
use crate::timeline::{ClipTransform, FIT_SCALE};

/// Offsets `x`/`y` are in 1/10000 of the canvas.
const OFFSET_UNIT: f64 = 10_000.0;

/// An affine map of UVs: `u' = m[0] u + m[1] v + m[2]`, `v' = m[3] u + m[4] v + m[5]`.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Affine {
    /// Row-major 2x3 coefficients.
    pub m: [f32; 6],
}

impl Affine {
    /// The map that changes nothing: the picture fills the target.
    pub const IDENTITY: Self = Self {
        m: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
    };

    /// The map applied to `(u, v)`.
    pub fn apply(&self, u: f32, v: f32) -> (f32, f32) {
        let m = self.m;
        (m[0] * u + m[1] * v + m[2], m[3] * u + m[4] * v + m[5])
    }

    /// This map followed by `next`.
    pub fn then(&self, next: &Affine) -> Affine {
        let (a, b) = (self.m, next.m);
        Affine {
            m: [
                b[0] * a[0] + b[1] * a[3],
                b[0] * a[1] + b[1] * a[4],
                b[0] * a[2] + b[1] * a[5] + b[2],
                b[3] * a[0] + b[4] * a[3],
                b[3] * a[1] + b[4] * a[4],
                b[3] * a[2] + b[4] * a[5] + b[5],
            ],
        }
    }
}

/// Maps the UV of a `width` x `height` render target to canvas UV, with the canvas fitted in
/// the target and centred (UVs outside 0..1 are the bars around it).
pub fn target_to_canvas(canvas: AspectRatio, width: u32, height: u32) -> Affine {
    let (cw, ch) = (f64::from(canvas.width()), f64::from(canvas.height()));
    let (tw, th) = (f64::from(width.max(1)), f64::from(height.max(1)));
    let fit = (tw / cw).min(th / ch);
    // The canvas's share of the target each way.
    let (sx, sy) = (cw * fit / tw, ch * fit / th);
    let m = [1.0 / sx, 0.0, 0.5 - 0.5 / sx, 0.0, 1.0 / sy, 0.5 - 0.5 / sy];
    Affine {
        m: m.map(|c| c as f32),
    }
}

/// The size of `media`'s picture on the canvas, placed by `transform` (crop, turns, fit, scale),
/// as fractions of the canvas width and height. Centred at the transform's offset.
pub fn picture_size(media: &Media, transform: &ClipTransform, canvas: AspectRatio) -> (f32, f32) {
    // A color fills the canvas (render's draw_color), whatever its 1x1 picture says.
    if media.kind() == crate::media::MediaKind::Color {
        return (1.0, 1.0);
    }
    let f = Fitted::new(media, transform, canvas);
    (
        (f.shown_w * f.size / f.canvas_w) as f32,
        (f.shown_h * f.size / f.canvas_h) as f32,
    )
}

/// Whether the clip's picture covers the whole canvas, so nothing under it shows. A color always
/// does. Every layer is opaque today; opacity and blend modes (P3-011, P3-012) must revisit this.
pub fn covers_canvas(media: &Media, transform: &ClipTransform, canvas: AspectRatio) -> bool {
    let (width, height) = picture_size(media, transform, canvas);
    // The frame's edges as fractions of the canvas; a same-shape picture at fit must count, so
    // allow rounding.
    const SLACK: f64 = 1e-6;
    let reaches = |size: f32, offset: i32| {
        let (centre, half) = (0.5 + f64::from(offset) / OFFSET_UNIT, f64::from(size) / 2.0);
        centre - half <= SLACK && centre + half >= 1.0 - SLACK
    };
    reaches(width, transform.x) && reaches(height, transform.y)
}

/// The picture after crop and turns, fitted to the canvas and scaled: one home for the sizes
/// both the frame ([`picture_size`]) and the sampling map ([`canvas_to_source`]) use.
struct Fitted {
    width: f64,
    height: f64,
    cropped_w: f64,
    cropped_h: f64,
    quarter_turns: u32,
    /// Shown sides in source pixels (after the turns).
    shown_w: f64,
    shown_h: f64,
    canvas_w: f64,
    canvas_h: f64,
    /// Canvas units per shown source pixel.
    size: f64,
}

impl Fitted {
    fn new(media: &Media, t: &ClipTransform, canvas: AspectRatio) -> Self {
        let (width, height) = media.size();
        let (width, height) = (f64::from(width), f64::from(height));
        let crop = t.crop;
        // The timeline keeps at least one pixel each way after the crop.
        let cropped_w = width - f64::from(crop.left) - f64::from(crop.right);
        let cropped_h = height - f64::from(crop.top) - f64::from(crop.bottom);
        let quarter_turns = (media.rotation() / 90 + u32::from(t.turns)) % 4;
        let (shown_w, shown_h) = if quarter_turns % 2 == 1 {
            (cropped_h, cropped_w)
        } else {
            (cropped_w, cropped_h)
        };
        // Fit inside the canvas, then scale.
        let (canvas_w, canvas_h) = (f64::from(canvas.width()), f64::from(canvas.height()));
        let fit = (canvas_w / shown_w).min(canvas_h / shown_h);
        Self {
            width,
            height,
            cropped_w,
            cropped_h,
            quarter_turns,
            shown_w,
            shown_h,
            canvas_w,
            canvas_h,
            size: fit * f64::from(t.scale) / f64::from(FIT_SCALE),
        }
    }
}

/// Maps canvas UV (0..1 from the top-left) to the UV of `media`'s stored pixels, placing the
/// picture as the clip's transform says: crop, then the media's rotation plus the clip's turns
/// (clockwise), then the flips, then fit inside the canvas, then scale and position. UVs outside
/// 0..1 are off the picture.
pub fn canvas_to_source(media: &Media, transform: &ClipTransform, canvas: AspectRatio) -> Affine {
    let map = |u: f64, v: f64| source_uv(media, transform, canvas, u, v);
    // Every step is affine, so three points fix the whole map.
    let (ox, oy) = map(0.0, 0.0);
    let (ux, uy) = map(1.0, 0.0);
    let (vx, vy) = map(0.0, 1.0);
    let m = [ux - ox, vx - ox, ox, uy - oy, vy - oy, oy];
    Affine {
        m: m.map(|c| c as f32),
    }
}

/// [`canvas_to_source`] for one point, undoing each step from the canvas back to the source.
fn source_uv(media: &Media, t: &ClipTransform, canvas: AspectRatio, u: f64, v: f64) -> (f64, f64) {
    let Fitted {
        width,
        height,
        cropped_w,
        cropped_h,
        quarter_turns,
        shown_w,
        shown_h,
        canvas_w,
        canvas_h,
        size,
    } = Fitted::new(media, t, canvas);
    let crop = t.crop;
    // Centred plus the offset.
    let centre_x = canvas_w * (0.5 + f64::from(t.x) / OFFSET_UNIT);
    let centre_y = canvas_h * (0.5 + f64::from(t.y) / OFFSET_UNIT);
    let mut px = (u * canvas_w - centre_x) / (shown_w * size) + 0.5;
    let mut py = (v * canvas_h - centre_y) / (shown_h * size) + 0.5;

    if t.flip_h {
        px = 1.0 - px;
    }
    if t.flip_v {
        py = 1.0 - py;
    }
    // A clockwise quarter turn shows source (sx, sy) at (1 - sy, sx).
    let (sx, sy) = match quarter_turns {
        0 => (px, py),
        1 => (py, 1.0 - px),
        2 => (1.0 - px, 1.0 - py),
        _ => (1.0 - py, px),
    };
    (
        (f64::from(crop.left) + sx * cropped_w) / width,
        (f64::from(crop.top) + sy * cropped_h) / height,
    )
}
