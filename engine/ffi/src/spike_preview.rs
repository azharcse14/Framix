//! SPIKE (P1-001): Android only. Draws the wgpu test pattern into a Flutter SurfaceProducer's
//! Surface over JNI. iOS uses the platform callbacks (platform.rs); Android moves there once it
//! has a vtable.

use std::ffi::c_void;

use crate::{ENGINE_ERR_GPU, ENGINE_ERR_NULL, ffi_guard};

/// The engine's one GPU, opened on first use; None if it could not be opened.
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
fn report(drawn: Result<(), framix_render::RenderError>) -> i32 {
    match drawn {
        Ok(()) => crate::ENGINE_OK,
        Err(e) => {
            eprintln!("framix spike: {e}");
            ENGINE_ERR_GPU
        }
    }
}

/// SPIKE (P1-001): JNI entry for `SpikePreview.nativeRender(surface)` in the Android app. Draws
/// one test-pattern frame into `surface`, the Surface of a Flutter SurfaceProducer, and
/// presents it; Flutter samples the window's HardwareBuffers directly. Returns an engine code.
///
/// # Safety
/// Called by the JVM: `env` is the calling thread's `JNIEnv*` and `surface` a live local
/// reference to an `android.view.Surface` (or null).
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
        /// One owned `ANativeWindow` reference, released on drop (also when a panic unwinds).
        struct Window(std::ptr::NonNull<c_void>);
        impl Drop for Window {
            fn drop(&mut self) {
                // SAFETY: we own exactly one reference, from ANativeWindow_fromSurface.
                unsafe { ANativeWindow_release(self.0.as_ptr()) };
            }
        }
        // SAFETY: env and surface come from the JVM per this fn's contract; the returned
        // window holds its own reference, owned by `Window`.
        let Some(window) =
            std::ptr::NonNull::new(unsafe { ANativeWindow_fromSurface(env, surface) }).map(Window)
        else {
            return ENGINE_ERR_NULL;
        };
        let Some(gpu) = gpu() else {
            return ENGINE_ERR_GPU;
        };
        // SAFETY: window is live while `window` is in scope.
        let (width, height) = unsafe {
            (
                ANativeWindow_getWidth(window.0.as_ptr()),
                ANativeWindow_getHeight(window.0.as_ptr()),
            )
        };
        let drawn = match (u32::try_from(width), u32::try_from(height)) {
            (Ok(w), Ok(h)) if w > 0 && h > 0 => {
                // SAFETY: `window` outlives the call; wgpu's surface is dropped inside it.
                unsafe { gpu.draw_to_android_window(window.0, w, h) }
            }
            _ => Err(framix_render::RenderError::SurfaceUnusable),
        };
        report(drawn)
    })
}
