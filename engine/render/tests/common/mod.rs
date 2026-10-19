//! Metal helpers shared by the host GPU tests (macOS).
#![cfg(target_vendor = "apple")]

use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2_metal::{
    MTLCreateSystemDefaultDevice, MTLDevice, MTLOrigin, MTLPixelFormat, MTLRegion, MTLSize,
    MTLStorageMode, MTLTexture, MTLTextureDescriptor, MTLTextureUsage,
};

/// A retained `id<MTLTexture>`.
pub type Texture = Retained<ProtocolObject<dyn MTLTexture>>;

/// A shared-storage BGRA8 Metal texture usable as a render target, like the preview's.
pub fn bgra_target(w: usize, h: usize) -> Texture {
    let device = MTLCreateSystemDefaultDevice().expect("Metal device");
    // SAFETY: plain descriptor setup on a fresh object.
    unsafe {
        let desc = MTLTextureDescriptor::texture2DDescriptorWithPixelFormat_width_height_mipmapped(
            MTLPixelFormat::BGRA8Unorm,
            w,
            h,
            false,
        );
        desc.setUsage(MTLTextureUsage::RenderTarget | MTLTextureUsage::ShaderRead);
        desc.setStorageMode(MTLStorageMode::Shared);
        device.newTextureWithDescriptor(&desc).expect("texture")
    }
}

/// The raw `id<MTLTexture>` pointer the wraps take.
pub fn ptr(texture: &Texture) -> *mut std::ffi::c_void {
    Retained::as_ptr(texture).cast_mut().cast()
}

/// RGB of pixel (x, y), read straight from the Metal texture's memory.
pub fn rgb(texture: &Texture, x: usize, y: usize) -> [u8; 3] {
    let mut out = [0u8; 4];
    let region = MTLRegion {
        origin: MTLOrigin { x, y, z: 0 },
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
    [out[2], out[1], out[0]]
}
