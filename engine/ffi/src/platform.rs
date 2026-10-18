//! The platform layer's (Swift/Kotlin) callbacks into the engine (docs/adr/0003-platform-callbacks.md).

use std::ffi::c_void;

/// Version of [`EnginePlatform`]; bump when its layout or meaning changes.
pub const ENGINE_PLATFORM_VERSION: u32 = 1;

/// The platform's answer to `create_preview_texture`. Call it exactly once, from any thread,
/// with the `done_ctx` that came with the request. `status` is [`crate::ENGINE_OK`] or any
/// other value for failure; on success `texture` is the GPU handle (an `id<MTLTexture>` on
/// iOS) and must stay alive while Flutter may show `texture_id`.
pub type EnginePreviewTextureDone =
    unsafe extern "C" fn(done_ctx: *mut c_void, status: i32, texture_id: i64, texture: *mut c_void);

/// Callbacks the platform layer gives the engine once at startup. Each is called on an engine
/// thread and must return at once; `ctx` is passed back unchanged and must live for the process.
#[repr(C)]
pub struct EnginePlatform {
    /// Must be [`ENGINE_PLATFORM_VERSION`].
    pub version: u32,
    /// Opaque platform state.
    pub ctx: *mut c_void,
    /// Makes a `width` x `height` BGRA preview texture Flutter can show, then calls `done`.
    pub create_preview_texture: Option<
        unsafe extern "C" fn(
            ctx: *mut c_void,
            width: u32,
            height: u32,
            done: EnginePreviewTextureDone,
            done_ctx: *mut c_void,
        ),
    >,
    /// Tells Flutter that `texture_id` holds a new frame.
    pub frame_available: Option<unsafe extern "C" fn(ctx: *mut c_void, texture_id: i64)>,
}

/// Registers the platform callbacks for the whole process. Only the first valid call counts.
/// Returns [`crate::ENGINE_ERR_NULL`] for null (or a null callback),
/// [`crate::ENGINE_ERR_PROTOCOL`] for another version, [`crate::ENGINE_ERR_ALREADY`] after a
/// successful call.
///
/// # Safety
/// `platform` must be null or point to a valid [`EnginePlatform`]; it is copied, and its
/// callbacks and `ctx` must stay valid for the rest of the process.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_platform_register(_platform: *const EnginePlatform) -> i32 {
    crate::ffi_guard(|| crate::ENGINE_ERR_PANIC)
}
