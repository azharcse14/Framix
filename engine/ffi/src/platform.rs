//! The platform layer's (Swift/Kotlin) callbacks into the engine (docs/adr/0003-platform-callbacks.md).

use std::ffi::c_void;
use std::sync::OnceLock;
use std::sync::mpsc::Sender;

use framix_app::preview::{PlatformTexture, PreviewHost, PreviewRenderer};

use crate::{
    ENGINE_ERR_ALREADY, ENGINE_ERR_NULL, ENGINE_ERR_PROTOCOL, ENGINE_OK, EngineMessage, ffi_guard,
};

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
pub unsafe extern "C" fn engine_platform_register(platform: *const EnginePlatform) -> i32 {
    ffi_guard(|| {
        // SAFETY: per the contract, a non-null `platform` is a valid EnginePlatform.
        let Some(platform) = (unsafe { platform.as_ref() }) else {
            return ENGINE_ERR_NULL;
        };
        if platform.version != ENGINE_PLATFORM_VERSION {
            return ENGINE_ERR_PROTOCOL;
        }
        let (Some(create_preview_texture), Some(frame_available)) =
            (platform.create_preview_texture, platform.frame_available)
        else {
            return ENGINE_ERR_NULL;
        };
        let registered = Registered {
            ctx: platform.ctx,
            create_preview_texture,
            frame_available,
        };
        match PLATFORM.set(registered) {
            Ok(()) => ENGINE_OK,
            Err(_) => ENGINE_ERR_ALREADY,
        }
    })
}

/// The registered callbacks, checked for null.
struct Registered {
    ctx: *mut c_void,
    create_preview_texture:
        unsafe extern "C" fn(*mut c_void, u32, u32, EnginePreviewTextureDone, *mut c_void),
    frame_available: unsafe extern "C" fn(*mut c_void, i64),
}

// SAFETY: engine_platform_register's contract makes the callbacks callable from any engine
// thread and `ctx` valid for the process; Rust never dereferences `ctx`.
unsafe impl Send for Registered {}
// SAFETY: as above; the fields are never mutated after registration.
unsafe impl Sync for Registered {}

static PLATFORM: OnceLock<Registered> = OnceLock::new();

/// [`PreviewHost`] over the registered callbacks; answers come back on `engine`'s queue.
pub(crate) struct PlatformHost {
    pub(crate) engine: Sender<EngineMessage>,
}

impl PreviewHost for PlatformHost {
    fn create_texture(&self, width: u32, height: u32) -> Result<(), String> {
        let platform = PLATFORM.get().ok_or("no platform registered")?;
        // Owned by the platform until it calls `preview_texture_done` with it.
        let done_ctx = Box::into_raw(Box::new(self.engine.clone())).cast::<c_void>();
        // SAFETY: registered callbacks stay valid for the process (register's contract).
        unsafe {
            (platform.create_preview_texture)(
                platform.ctx,
                width,
                height,
                preview_texture_done,
                done_ctx,
            )
        };
        Ok(())
    }

    fn frame_available(&self, id: i64) {
        if let Some(platform) = PLATFORM.get() {
            // SAFETY: as in create_texture.
            unsafe { (platform.frame_available)(platform.ctx, id) };
        }
    }
}

/// [`EnginePreviewTextureDone`]: hands the platform's answer to the engine thread.
///
/// # Safety
/// `done_ctx` must come from [`PlatformHost::create_texture`] and be passed exactly once.
unsafe extern "C" fn preview_texture_done(
    done_ctx: *mut c_void,
    status: i32,
    texture_id: i64,
    texture: *mut c_void,
) {
    ffi_guard(|| {
        if done_ctx.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: per the contract, done_ctx is the Box::into_raw from create_texture, given
        // back once, so ownership returns here.
        let engine = unsafe { Box::from_raw(done_ctx.cast::<Sender<EngineMessage>>()) };
        let texture = if status != ENGINE_OK {
            Err(format!("platform could not make the texture ({status})"))
        } else if texture.is_null() {
            Err("platform gave a null texture".to_owned())
        } else {
            Ok(PlatformTexture {
                id: texture_id,
                handle: texture as usize,
            })
        };
        // A stopped engine no longer wants the answer.
        let _ = engine.send(EngineMessage::PreviewTexture(texture));
        ENGINE_OK
    });
}

/// [`PreviewRenderer`] on the render crate; opens the GPU on first use.
#[derive(Default)]
pub(crate) struct GpuRenderer {
    gpu: Option<framix_render::Gpu>,
}

impl PreviewRenderer for GpuRenderer {
    fn draw(&mut self, target: PlatformTexture) -> Result<(), String> {
        let gpu = match &mut self.gpu {
            Some(gpu) => gpu,
            empty => empty.insert(framix_render::Gpu::new().map_err(|e| e.to_string())?),
        };
        draw_into(gpu, target)
    }
}

#[cfg(target_vendor = "apple")]
fn draw_into(gpu: &framix_render::Gpu, target: PlatformTexture) -> Result<(), String> {
    // SAFETY: the handle came from a successful `done`, whose contract makes it a live
    // id<MTLTexture> on Apple platforms.
    let texture = unsafe { gpu.wrap_metal_texture(target.handle as *mut c_void) }
        .map_err(|e| e.to_string())?;
    gpu.draw_test_pattern(&texture).map_err(|e| e.to_string())
}

#[cfg(not(target_vendor = "apple"))]
fn draw_into(_: &framix_render::Gpu, _: PlatformTexture) -> Result<(), String> {
    Err("no platform texture support on this OS yet".to_owned())
}
