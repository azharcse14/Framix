//! The platform layer's (Swift/Kotlin) callbacks into the engine (docs/adr/0003-platform-callbacks.md).

use std::ffi::c_void;
use std::sync::OnceLock;
use std::sync::mpsc::Sender;

use framix_app::preview::{PlatformTexture, PreviewHost};
use framix_app::thumbnail::{ThumbnailHost, ThumbnailKey, ThumbnailRequest};
use framix_core::media::MediaKind;

use crate::{
    ENGINE_ERR_ALREADY, ENGINE_ERR_NULL, ENGINE_ERR_PROTOCOL, ENGINE_OK, EngineMessage, ffi_guard,
};

/// Version of [`EnginePlatform`]; bump when its layout or meaning changes.
pub const ENGINE_PLATFORM_VERSION: u32 = 2;

/// The platform's answer to `create_preview_texture`. Call it exactly once, from any thread,
/// with the `done_ctx` that came with the request. `status` is [`crate::ENGINE_OK`] or any
/// other value for failure; on success `texture` is the GPU handle (an `id<MTLTexture>` on
/// iOS, an `ANativeWindow*` reference the engine then owns on Android) and must stay alive while
/// Flutter may show `texture_id`.
pub type EnginePreviewTextureDone =
    unsafe extern "C" fn(done_ctx: *mut c_void, status: i32, texture_id: i64, texture: *mut c_void);

/// The platform's answer to `request_thumbnail`. Call it exactly once, from any thread, with the
/// `done_ctx` that came with the request. On success (`status` [`crate::ENGINE_OK`]) `path` is
/// `path_len` UTF-8 bytes naming the image file, valid for the call only.
pub type EngineThumbnailDone =
    unsafe extern "C" fn(done_ctx: *mut c_void, status: i32, path: *const u8, path_len: usize);

/// [`EnginePlatform::request_thumbnail`]'s `kind`: a video.
pub const ENGINE_MEDIA_VIDEO: u32 = 1;
/// [`EnginePlatform::request_thumbnail`]'s `kind`: a photo.
pub const ENGINE_MEDIA_IMAGE: u32 = 2;

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
    /// Makes a thumbnail image file of the media `uri` (`uri_len` UTF-8 bytes, valid for the
    /// call) of `kind` at `time_us` microseconds, longest side at most `max_side`, then calls
    /// `done`. Must return at once and do the work elsewhere.
    pub request_thumbnail: Option<
        unsafe extern "C" fn(
            ctx: *mut c_void,
            uri: *const u8,
            uri_len: usize,
            kind: u32,
            time_us: i64,
            max_side: u32,
            done: EngineThumbnailDone,
            done_ctx: *mut c_void,
        ),
    >,
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
        let (Some(create_preview_texture), Some(frame_available), Some(request_thumbnail)) = (
            platform.create_preview_texture,
            platform.frame_available,
            platform.request_thumbnail,
        ) else {
            return ENGINE_ERR_NULL;
        };
        let registered = Registered {
            ctx: platform.ctx,
            create_preview_texture,
            frame_available,
            request_thumbnail,
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
    request_thumbnail: unsafe extern "C" fn(
        *mut c_void,
        *const u8,
        usize,
        u32,
        i64,
        u32,
        EngineThumbnailDone,
        *mut c_void,
    ),
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

impl ThumbnailHost for PlatformHost {
    fn request(&self, request: ThumbnailRequest) -> Result<(), String> {
        let platform = PLATFORM.get().ok_or("no platform registered")?;
        let kind = match request.kind {
            MediaKind::Video => ENGINE_MEDIA_VIDEO,
            MediaKind::Image => ENGINE_MEDIA_IMAGE,
        };
        // Owned by the platform until it calls `thumbnail_done` with it.
        let done_ctx = Box::into_raw(Box::new((self.engine.clone(), request.key))).cast::<c_void>();
        // SAFETY: registered callbacks stay valid for the process (register's contract); the
        // uri bytes outlive the call.
        unsafe {
            (platform.request_thumbnail)(
                platform.ctx,
                request.uri.as_ptr(),
                request.uri.len(),
                kind,
                request.time_us,
                request.key.max_side,
                thumbnail_done,
                done_ctx,
            )
        };
        Ok(())
    }
}

/// [`EngineThumbnailDone`]: hands the platform's answer to the engine thread.
///
/// # Safety
/// `done_ctx` must come from [`PlatformHost::request`] and be passed exactly once; a non-null
/// `path` must point to `path_len` readable bytes.
pub(crate) unsafe extern "C" fn thumbnail_done(
    done_ctx: *mut c_void,
    status: i32,
    path: *const u8,
    path_len: usize,
) {
    ffi_guard(|| {
        if done_ctx.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: per the contract, done_ctx is the Box::into_raw from request, given back
        // once, so ownership returns here.
        let ctx =
            unsafe { Box::from_raw(done_ctx.cast::<(Sender<EngineMessage>, ThumbnailKey)>()) };
        let (engine, key) = *ctx;
        let path = if status != ENGINE_OK || path.is_null() {
            Err(format!("platform could not make the thumbnail ({status})"))
        } else {
            // SAFETY: non-null `path` points to `path_len` bytes for this call (contract).
            let bytes = unsafe { std::slice::from_raw_parts(path, path_len) };
            String::from_utf8(bytes.to_vec()).map_err(|_| "thumbnail path is not UTF-8".to_owned())
        };
        // A stopped engine no longer wants the answer.
        let _ = engine.send(EngineMessage::Thumbnail(key, path));
        ENGINE_OK
    });
}

/// [`EnginePreviewTextureDone`]: hands the platform's answer to the engine thread.
///
/// # Safety
/// `done_ctx` must come from [`PlatformHost::create_texture`] and be passed exactly once.
pub(crate) unsafe extern "C" fn preview_texture_done(
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
