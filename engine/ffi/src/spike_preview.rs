//! SPIKE (P1-001): draws the wgpu test pattern into a texture Flutter shows. Bypasses the
//! command queue and blocks the caller until the GPU is done; the real path (render thread,
//! fences, platform callbacks) comes with P1-005.

use std::ffi::c_void;

use crate::{ENGINE_ERR_NULL, ffi_guard};

/// The GPU could not be opened, or this platform has no preview path yet.
pub const ENGINE_ERR_GPU: i32 = -5;

/// SPIKE (P1-001): renders the test pattern into `mtl_texture`, an `id<MTLTexture>` backed by
/// the IOSurface of the CVPixelBuffer that the iOS layer registered as a Flutter texture.
/// Returns after the GPU finished, so the caller can mark the Flutter texture frame available.
///
/// # Safety
/// `mtl_texture` must be null or a live BGRA8Unorm render-target `id<MTLTexture>` of size
/// `width` x `height` on the system default Metal device.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_spike_render_metal(
    mtl_texture: *mut c_void,
    width: u32,
    height: u32,
) -> i32 {
    ffi_guard(|| {
        if mtl_texture.is_null() {
            return ENGINE_ERR_NULL;
        }
        render(mtl_texture, width, height)
    })
}

#[cfg(target_vendor = "apple")]
fn render(mtl_texture: *mut c_void, width: u32, height: u32) -> i32 {
    use std::sync::OnceLock;
    static GPU: OnceLock<Option<framix_render::Gpu>> = OnceLock::new();
    let Some(gpu) = GPU.get_or_init(|| {
        framix_render::Gpu::new()
            .inspect_err(|e| eprintln!("framix spike: {e}"))
            .ok()
    }) else {
        return ENGINE_ERR_GPU;
    };
    // SAFETY: forwarded from engine_spike_render_metal's contract.
    match unsafe { gpu.wrap_metal_texture(mtl_texture, width, height) } {
        Ok(target) => {
            gpu.draw_test_pattern(&target);
            crate::ENGINE_OK
        }
        Err(e) => {
            eprintln!("framix spike: {e}");
            ENGINE_ERR_GPU
        }
    }
}

#[cfg(not(target_vendor = "apple"))]
fn render(_: *mut c_void, _: u32, _: u32) -> i32 {
    ENGINE_ERR_GPU
}
