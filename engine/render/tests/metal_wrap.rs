//! SPIKE (P1-001): wgpu renders into a Metal texture it does not own, and the pixels land in
//! that texture's memory (no copy). Runs on the host GPU (macOS).
#![cfg(target_vendor = "apple")]

use framix_render::Gpu;
use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_metal::{
    MTLCreateSystemDefaultDevice, MTLDevice, MTLOrigin, MTLPixelFormat, MTLRegion, MTLSize,
    MTLStorageMode, MTLTexture, MTLTextureDescriptor, MTLTextureUsage,
};

const W: u32 = 64;
const H: u32 = 32;

fn external_texture() -> Retained<ProtocolObject<dyn MTLTexture>> {
    let device = MTLCreateSystemDefaultDevice().expect("Metal device");
    // SAFETY: plain descriptor setup on a fresh object.
    unsafe {
        let desc = MTLTextureDescriptor::texture2DDescriptorWithPixelFormat_width_height_mipmapped(
            MTLPixelFormat::BGRA8Unorm,
            W as usize,
            H as usize,
            false,
        );
        desc.setUsage(MTLTextureUsage::RenderTarget | MTLTextureUsage::ShaderRead);
        desc.setStorageMode(MTLStorageMode::Shared);
        device.newTextureWithDescriptor(&desc).expect("texture")
    }
}

/// BGRA bytes of pixel (x, y), read straight from the Metal texture's memory.
fn pixel(texture: &ProtocolObject<dyn MTLTexture>, x: u32, y: u32) -> [u8; 4] {
    let mut out = [0u8; 4];
    let region = MTLRegion {
        origin: MTLOrigin {
            x: x as usize,
            y: y as usize,
            z: 0,
        },
        size: MTLSize {
            width: 1,
            height: 1,
            depth: 1,
        },
    };
    // SAFETY: `out` holds exactly one BGRA8 pixel; shared storage is CPU readable.
    unsafe {
        texture.getBytes_bytesPerRow_fromRegion_mipmapLevel(
            std::ptr::NonNull::new(out.as_mut_ptr().cast()).unwrap(),
            4,
            region,
            0,
        )
    };
    out
}

#[test]
fn renders_into_a_platform_owned_metal_texture() {
    let gpu = Gpu::new().expect("gpu");
    let external = external_texture();
    let ptr = Retained::as_ptr(&external).cast_mut().cast();
    // SAFETY: `external` is a live BGRA8 render-target texture on the system default device.
    let target = unsafe { gpu.wrap_metal_texture(ptr, W, H) }.expect("wrap");
    gpu.draw_test_pattern(&target);

    // Red ramps left to right, green top to bottom; blue is 0.5 everywhere.
    let [b, g, r, a] = pixel(&external, 0, 0);
    assert!(r < 8 && g < 8, "top-left should be dark, got r={r} g={g}");
    assert!((120..=136).contains(&b) && a == 255, "blue {b}, alpha {a}");
    let [_, g, r, _] = pixel(&external, W - 1, 0);
    assert!(r > 247 && g < 8, "top-right should be red, got r={r} g={g}");
    let [_, g, r, _] = pixel(&external, 0, H - 1);
    assert!(
        r < 8 && g > 247,
        "bottom-left should be green, got r={r} g={g}"
    );
}

#[test]
fn rejects_null_and_empty_textures() {
    let gpu = Gpu::new().expect("gpu");
    // SAFETY: null and zero sizes are rejected before the pointer is used.
    unsafe {
        assert!(gpu.wrap_metal_texture(std::ptr::null_mut(), W, H).is_err());
        let external = external_texture();
        let ptr = Retained::as_ptr(&external).cast_mut().cast();
        assert!(gpu.wrap_metal_texture(ptr, 0, H).is_err());
    }
}
