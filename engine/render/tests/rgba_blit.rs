//! The last step of the Android decode path (P1-056): a converted RGBA frame is drawn into the
//! preview target. The frame comes from an AHardwareBuffer on Android; here it is a plain wgpu
//! texture so the pass runs on the host GPU (macOS).
#![cfg(target_vendor = "apple")]

mod common;

use common::{bgra_target, ptr, rgb};

use framix_core::placement::Affine;
use framix_render::{Gpu, Placement};

const W: u32 = 16;
const H: u32 = 8;
/// RGBA per quadrant: top-left, top-right, bottom-left, bottom-right.
const QUADRANTS: [[u8; 4]; 4] = [
    [255, 0, 0, 255],
    [0, 255, 0, 255],
    [0, 0, 255, 255],
    [128, 128, 128, 255],
];

fn source(gpu: &Gpu, format: wgpu::TextureFormat) -> wgpu::Texture {
    let texture = gpu.device().create_texture(&wgpu::TextureDescriptor {
        label: Some("decoded frame"),
        size: wgpu::Extent3d {
            width: W,
            height: H,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });
    let pixels: Vec<u8> = (0..H)
        .flat_map(|y| (0..W).map(move |x| (x, y)))
        .flat_map(|(x, y)| QUADRANTS[usize::from(y >= H / 2) * 2 + usize::from(x >= W / 2)])
        .collect();
    gpu.queue().write_texture(
        texture.as_image_copy(),
        &pixels,
        wgpu::TexelCopyBufferLayout {
            offset: 0,
            bytes_per_row: Some(W * 4),
            rows_per_image: None,
        },
        texture.size(),
    );
    texture
}

#[test]
fn draws_an_rgba_frame_into_the_preview() {
    let gpu = Gpu::new().expect("gpu");
    let frame = source(&gpu, wgpu::TextureFormat::Rgba8Unorm);
    let target = bgra_target(W as usize, H as usize);
    // SAFETY: `target` is a live id<MTLTexture> on the system default device.
    let out = unsafe { gpu.wrap_metal_texture(ptr(&target)) }.expect("wrap target");
    gpu.draw_rgba(&out, &frame, &Placement::FILL).expect("draw");

    let (w, h, qx, qy) = (W as usize, H as usize, W as usize / 4, H as usize / 4);
    let got = [
        rgb(&target, qx, qy),
        rgb(&target, w - qx, qy),
        rgb(&target, qx, h - qy),
        rgb(&target, w - qx, h - qy),
    ];
    let want = QUADRANTS.map(|[r, g, b, _]| [r, g, b]);
    assert_eq!(got, want);
}

#[test]
fn rejects_a_frame_that_is_not_rgba8() {
    let gpu = Gpu::new().expect("gpu");
    let frame = source(&gpu, wgpu::TextureFormat::Bgra8Unorm);
    let target = bgra_target(W as usize, H as usize);
    // SAFETY: `target` is a live id<MTLTexture> on the system default device.
    let out = unsafe { gpu.wrap_metal_texture(ptr(&target)) }.expect("wrap target");
    assert!(gpu.draw_rgba(&out, &frame, &Placement::FILL).is_err());
}

#[test]
fn places_the_frame_on_the_canvas_with_black_around() {
    let gpu = Gpu::new().expect("gpu");
    let frame = source(&gpu, wgpu::TextureFormat::Rgba8Unorm);
    let (w, h) = (2 * W as usize, H as usize);
    let target = bgra_target(w, h);
    // SAFETY: `target` is a live id<MTLTexture> on the system default device.
    let out = unsafe { gpu.wrap_metal_texture(ptr(&target)) }.expect("wrap target");
    // The canvas is the target's left half; the picture fills it, flipped left to right.
    let canvas = Affine {
        m: [2.0, 0.0, 0.0, 0.0, 1.0, 0.0],
    };
    let flip = Affine {
        m: [-1.0, 0.0, 1.0, 0.0, 1.0, 0.0],
    };
    let placement = Placement {
        canvas,
        source: canvas.then(&flip),
    };
    gpu.draw_rgba(&out, &frame, &placement).expect("draw");

    let (qx, qy) = (w / 8, h / 4);
    let [tl, tr, bl, br] = QUADRANTS.map(|[r, g, b, _]| [r, g, b]);
    let got = [
        rgb(&target, qx, qy),
        rgb(&target, w / 2 - qx, qy),
        rgb(&target, qx, h - qy),
        rgb(&target, w / 2 - qx, h - qy),
    ];
    assert_eq!(got, [tr, tl, br, bl], "mirrored on the canvas");
    assert_eq!(
        rgb(&target, w - qx, qy),
        [0, 0, 0],
        "off the canvas is black"
    );
}
