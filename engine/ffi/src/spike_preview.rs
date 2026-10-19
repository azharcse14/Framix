//! SPIKE (P1-001): Android only. Draws the wgpu test pattern into a Flutter SurfaceProducer's
//! Surface over JNI. iOS uses the platform callbacks (platform.rs); Android moves there once it
//! has a vtable.
//!
//! SPIKE (P1-056): Android also draws one decoded frame, converted to an RGBA8 HardwareBuffer by
//! the app's GLES pass and imported into wgpu.
//!
//! SPIKE (P1-002): iOS only. Draws one decoded NV12 frame into the preview texture, so the
//! simulator shows a VideoToolbox frame reaching wgpu with no copy. The Decoder port replaces it.

use std::ffi::c_void;

use crate::{ENGINE_ERR_GPU, ENGINE_ERR_NULL, ffi_guard};

#[cfg(target_vendor = "apple")]
use framix_render::{YcbcrMatrix, YcbcrRange, YcbcrSpace};

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

/// SPIKE (P1-002): converts one NV12 decoder frame into the preview texture. `y` and `cbcr`
/// are Metal textures on the frame's IOSurface planes (R8Unorm, RG8Unorm); `target` is the
/// preview's BGRA texture. `bt709` picks BT.709 over BT.601, `video_range` video over full
/// range (both 0 or 1). Returns an engine code once the GPU is done.
///
/// # Safety
/// `target`, `y` and `cbcr` must each be null or a live `id<MTLTexture>` for the call, and the
/// decoder must have finished writing the frame.
#[cfg(target_vendor = "apple")]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_spike_draw_nv12(
    target: *mut c_void,
    y: *mut c_void,
    cbcr: *mut c_void,
    bt709: u32,
    video_range: u32,
) -> i32 {
    ffi_guard(|| {
        if target.is_null() || y.is_null() || cbcr.is_null() {
            return ENGINE_ERR_NULL;
        }
        let Some(gpu) = gpu() else {
            return ENGINE_ERR_GPU;
        };
        let space = YcbcrSpace {
            matrix: if bt709 == 0 {
                YcbcrMatrix::Bt601
            } else {
                YcbcrMatrix::Bt709
            },
            range: if video_range == 0 {
                YcbcrRange::Full
            } else {
                YcbcrRange::Video
            },
        };
        // SAFETY: all three are live id<MTLTexture>s per this fn's contract.
        let drawn = unsafe { gpu.wrap_metal_texture(target) }.and_then(|out| {
            // SAFETY: as above; the decoder is done with the frame.
            let (y, cbcr) = unsafe { (gpu.wrap_metal_plane(y)?, gpu.wrap_metal_plane(cbcr)?) };
            gpu.draw_nv12(&out, &y, &cbcr, space)
        });
        report(drawn)
    })
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
    // SAFETY: forwarded from this fn's contract.
    ffi_guard(|| unsafe { render_into_surface(env, surface, None) })
}

/// SPIKE (P1-056): JNI entry for `SpikePreview.nativeRenderFrame(surface, frame)`. Draws `frame`,
/// a `android.hardware.HardwareBuffer` holding a decoded video frame the app converted to RGBA8
/// on the GPU, into `surface` with no CPU copy. Returns an engine code.
///
/// # Safety
/// Called by the JVM: `env` is the calling thread's `JNIEnv*`; `surface` and `frame` are live
/// local references (or null), and the GPU work that wrote `frame` is done.
#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub unsafe extern "C" fn Java_com_travela_framix_SpikePreview_nativeRenderFrame(
    env: *mut c_void,
    _class: *mut c_void,
    surface: *mut c_void,
    frame: *mut c_void,
) -> i32 {
    #[link(name = "android")]
    unsafe extern "C" {
        fn AHardwareBuffer_fromHardwareBuffer(env: *mut c_void, buffer: *mut c_void)
        -> *mut c_void;
    }
    ffi_guard(|| {
        if frame.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: env and frame come from the JVM per this fn's contract. The AHardwareBuffer
        // is borrowed from the Java object, which outlives this call (a JNI local reference).
        let Some(ahb) =
            std::ptr::NonNull::new(unsafe { AHardwareBuffer_fromHardwareBuffer(env, frame) })
        else {
            return ENGINE_ERR_NULL;
        };
        // SAFETY: forwarded from this fn's contract; `ahb` is live for the call.
        unsafe { render_into_surface(env, surface, Some(ahb)) }
    })
}

/// Draws into `surface`'s window: the imported `frame` when given, else the test pattern.
///
/// # Safety
/// `env` is the calling thread's `JNIEnv*`, `surface` a live `android.view.Surface` local
/// reference (or null), and `frame` a live `AHardwareBuffer*` whose writes are done.
#[cfg(target_os = "android")]
unsafe fn render_into_surface(
    env: *mut c_void,
    surface: *mut c_void,
    frame: Option<std::ptr::NonNull<c_void>>,
) -> i32 {
    #[link(name = "android")]
    unsafe extern "C" {
        fn ANativeWindow_fromSurface(env: *mut c_void, surface: *mut c_void) -> *mut c_void;
        fn ANativeWindow_getWidth(window: *mut c_void) -> i32;
        fn ANativeWindow_getHeight(window: *mut c_void) -> i32;
        fn ANativeWindow_release(window: *mut c_void);
    }
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
    // SAFETY: env and surface are live per this fn's contract; the returned window holds its
    // own reference, owned by `Window`.
    let Some(window) =
        std::ptr::NonNull::new(unsafe { ANativeWindow_fromSurface(env, surface) }).map(Window)
    else {
        return ENGINE_ERR_NULL;
    };
    let Some(gpu) = gpu() else {
        return ENGINE_ERR_GPU;
    };
    // The Kotlin side calls from the main thread and a decode thread; one lock keeps wgpu's
    // draws and presents apart from the frame import's raw queue submit.
    static GPU_USE: std::sync::Mutex<()> = std::sync::Mutex::new(());
    let _gpu_use = GPU_USE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    // SAFETY: window is live while `window` is in scope.
    let (width, height) = unsafe {
        (
            ANativeWindow_getWidth(window.0.as_ptr()),
            ANativeWindow_getHeight(window.0.as_ptr()),
        )
    };
    let (Ok(w), Ok(h)) = (u32::try_from(width), u32::try_from(height)) else {
        return report(Err(framix_render::RenderError::SurfaceUnusable));
    };
    if w == 0 || h == 0 {
        return report(Err(framix_render::RenderError::SurfaceUnusable));
    }
    // SAFETY: `frame` is live and finished per this fn's contract; `GPU_USE` is held, so no
    // other thread uses the queue.
    let source = frame
        .map(|ahb| unsafe { gpu.import_android_frame(ahb) })
        .transpose();
    let drawn = source.and_then(|source| {
        // SAFETY: `window` outlives the call; wgpu's surface is dropped inside it.
        unsafe { gpu.draw_to_android_window(window.0, w, h, source.as_ref()) }
    });
    report(drawn)
}
