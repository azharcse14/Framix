//! SPIKE (P1-001): the same path as the iOS app. wgpu draws into a Metal texture made on an
//! IOSurface, and the pixels are read straight from the IOSurface's memory, which is what a
//! CVPixelBuffer on that surface (the Flutter texture) shows. No copy anywhere.
#![cfg(target_vendor = "apple")]

use framix_render::Gpu;
use objc2::rc::Retained;
use objc2_core_foundation::{CFDictionary, CFNumber, CFString};
use objc2_io_surface::{
    IOSurfaceLockOptions, IOSurfaceRef, kIOSurfaceBytesPerElement, kIOSurfaceHeight,
    kIOSurfacePixelFormat, kIOSurfaceWidth,
};
use objc2_metal::{
    MTLCreateSystemDefaultDevice, MTLDevice, MTLPixelFormat, MTLStorageMode, MTLTextureDescriptor,
    MTLTextureUsage,
};

const W: i32 = 64;
const H: i32 = 32;
/// 'BGRA', kCVPixelFormatType_32BGRA.
const BGRA: i32 = 0x4247_5241;

#[test]
fn renders_into_an_iosurface_backed_texture() {
    // SAFETY: the keys are the documented IOSurface property names with CFNumber values.
    let surface = unsafe {
        let keys = [
            kIOSurfaceWidth,
            kIOSurfaceHeight,
            kIOSurfaceBytesPerElement,
            kIOSurfacePixelFormat,
        ];
        let values = [W, H, 4, BGRA].map(CFNumber::new_i32);
        let refs: Vec<&CFNumber> = values.iter().map(|v| &**v).collect();
        let props = CFDictionary::<CFString, CFNumber>::from_slices(&keys, &refs);
        IOSurfaceRef::new(props.as_opaque()).expect("IOSurface")
    };

    let device = MTLCreateSystemDefaultDevice().expect("Metal device");
    // SAFETY: descriptor matches the surface (BGRA8, W x H, one plane).
    let texture = unsafe {
        let desc = MTLTextureDescriptor::texture2DDescriptorWithPixelFormat_width_height_mipmapped(
            MTLPixelFormat::BGRA8Unorm,
            W as usize,
            H as usize,
            false,
        );
        desc.setUsage(MTLTextureUsage::RenderTarget | MTLTextureUsage::ShaderRead);
        desc.setStorageMode(MTLStorageMode::Shared);
        device
            .newTextureWithDescriptor_iosurface_plane(&desc, &surface, 0)
            .expect("texture on IOSurface")
    };

    let gpu = Gpu::new().expect("gpu");
    let ptr = Retained::as_ptr(&texture).cast_mut().cast();
    // SAFETY: `texture` is a live id<MTLTexture>.
    let target = unsafe { gpu.wrap_metal_texture(ptr) }.expect("wrap");
    gpu.draw_test_pattern(&target).expect("draw");

    // SAFETY: read-only lock while reading the surface's base address; unlocked right after.
    let pixel = |x: usize, y: usize| unsafe {
        surface.lock(IOSurfaceLockOptions::ReadOnly, std::ptr::null_mut());
        let row = surface.bytes_per_row();
        let base = surface.base_address().as_ptr().cast::<u8>();
        let p = std::slice::from_raw_parts(base.add(y * row + x * 4), 4).to_vec();
        surface.unlock(IOSurfaceLockOptions::ReadOnly, std::ptr::null_mut());
        p
    };
    let (w, h) = (W as usize, H as usize);
    // BGRA bytes: red ramps left to right, green top to bottom, blue 0.5.
    let top_left = pixel(0, 0);
    assert!(top_left[2] < 8 && top_left[1] < 8 && (120..=136).contains(&top_left[0]));
    let top_right = pixel(w - 1, 0);
    assert!(top_right[2] > 247 && top_right[1] < 8, "{top_right:?}");
    let bottom_left = pixel(0, h - 1);
    assert!(
        bottom_left[2] < 8 && bottom_left[1] > 247,
        "{bottom_left:?}"
    );
}
