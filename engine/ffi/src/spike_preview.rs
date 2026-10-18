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
/// Size, format and device are read from the texture; anything unusable gives
/// [`ENGINE_ERR_GPU`].
///
/// # Safety
/// `mtl_texture` must be null or a live `id<MTLTexture>`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_spike_render_metal(mtl_texture: *mut c_void) -> i32 {
    ffi_guard(|| {
        if mtl_texture.is_null() {
            return ENGINE_ERR_NULL;
        }
        render(mtl_texture)
    })
}

/// The engine's one GPU, opened on first use; None if it could not be opened.
#[cfg(any(target_vendor = "apple", target_os = "android"))]
fn gpu() -> Option<&'static framix_render::Gpu> {
    use std::sync::OnceLock;
    static GPU: OnceLock<Option<framix_render::Gpu>> = OnceLock::new();
    GPU.get_or_init(|| {
        framix_render::Gpu::new()
            .inspect_err(|e| eprintln!("framix spike: {e}"))
            .ok()
    })
    .as_ref()
}

/// Maps a draw result to an FFI code, logging the reason on failure.
#[cfg(any(target_vendor = "apple", target_os = "android"))]
fn report(drawn: Result<(), framix_render::RenderError>) -> i32 {
    match drawn {
        Ok(()) => crate::ENGINE_OK,
        Err(e) => {
            eprintln!("framix spike: {e}");
            ENGINE_ERR_GPU
        }
    }
}

#[cfg(target_vendor = "apple")]
fn render(mtl_texture: *mut c_void) -> i32 {
    let Some(gpu) = gpu() else {
        return ENGINE_ERR_GPU;
    };
    // SAFETY: forwarded from engine_spike_render_metal's contract.
    let drawn = unsafe { gpu.wrap_metal_texture(mtl_texture) }
        .and_then(|target| gpu.draw_test_pattern(&target));
    report(drawn)
}

#[cfg(not(target_vendor = "apple"))]
fn render(_: *mut c_void) -> i32 {
    ENGINE_ERR_GPU
}

/// SPIKE (P1-001): JNI entry for `SpikePreview.nativeRender(surface)` in the Android app. Draws
/// one test-pattern frame into `surface`, the Surface of a Flutter SurfaceProducer, and
/// presents it; Flutter samples the window's HardwareBuffers directly. Returns an engine code.
///
/// # Safety
/// Called by the JVM: `env` is the calling thread's `JNIEnv*` and `surface` a live local
/// reference to an `android.view.Surface` (or null).
#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn Java_com_travela_framix_SpikePreview_nativeRender(
    env: *mut c_void,
    _class: *mut c_void,
    surface: *mut c_void,
) -> i32 {
    #[link(name = "android")]
    unsafe extern "C" {
        fn ANativeWindow_fromSurface(env: *mut c_void, surface: *mut c_void) -> *mut c_void;
        fn ANativeWindow_getWidth(window: *mut c_void) -> i32;
        fn ANativeWindow_getHeight(window: *mut c_void) -> i32;
        fn ANativeWindow_release(window: *mut c_void);
    }
    ffi_guard(|| {
        if surface.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: env and surface come from the JVM per this fn's contract; the returned
        // window holds its own reference, released below.
        let Some(window) =
            std::ptr::NonNull::new(unsafe { ANativeWindow_fromSurface(env, surface) })
        else {
            return ENGINE_ERR_NULL;
        };
        let Some(gpu) = gpu() else {
            // SAFETY: we own one reference from ANativeWindow_fromSurface.
            unsafe { ANativeWindow_release(window.as_ptr()) };
            return ENGINE_ERR_GPU;
        };
        // SAFETY: window is live until released below.
        let (width, height) = unsafe {
            (
                ANativeWindow_getWidth(window.as_ptr()),
                ANativeWindow_getHeight(window.as_ptr()),
            )
        };
        let drawn = match (u32::try_from(width), u32::try_from(height)) {
            (Ok(w), Ok(h)) if w > 0 && h > 0 => {
                // SAFETY: window stays live until released below.
                unsafe { gpu.draw_to_android_window(window, w, h) }
            }
            _ => Err(framix_render::RenderError::SurfaceUnusable),
        };
        // SAFETY: the surface wgpu made from window was dropped inside the draw call.
        unsafe { ANativeWindow_release(window.as_ptr()) };
        report(drawn)
    })
}
