//! The platform layer's (Swift/Kotlin) callbacks into the engine (docs/adr/0003-platform-callbacks.md).

use std::ffi::c_void;
use std::sync::OnceLock;
use std::sync::mpsc::Sender;

use framix_app::export::{Encoder, EncoderConfig, EncoderHost};
use framix_app::preview::{PlatformTexture, PreviewHost};
use framix_app::thumbnail::{ThumbnailHost, ThumbnailKey, ThumbnailRequest};
use framix_core::media::MediaKind;
use framix_core::time::Time;

use crate::{
    ENGINE_ERR_ALREADY, ENGINE_ERR_NULL, ENGINE_ERR_PROTOCOL, ENGINE_OK, EngineMessage, ffi_guard,
};

/// Version of [`EnginePlatform`]; bump when its layout or meaning changes.
pub const ENGINE_PLATFORM_VERSION: u32 = 3;

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

/// Callbacks the platform layer gives the engine once at startup. `ctx` is passed back unchanged
/// and must live for the process. The preview and thumbnail calls come from the engine thread
/// and must return at once; the `encoder_*` calls come only from the export worker thread and
/// may block (docs/adr/0005-export-encoder.md).
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
    /// Opens a hardware video encoder writing an MP4 to `path` (`path_len` UTF-8 bytes, valid
    /// for the call): `width` x `height` (even), `fps` frames per second, `kbps` kbit/s. Returns
    /// the encoder, or null if it could not open.
    pub encoder_open: Option<
        unsafe extern "C" fn(
            ctx: *mut c_void,
            width: u32,
            height: u32,
            fps: u32,
            kbps: u32,
            path: *const u8,
            path_len: usize,
        ) -> *mut c_void,
    >,
    /// Appends the previous frame (if any), then returns the render target for the frame at
    /// `time_us` microseconds: a BGRA texture (an `id<MTLTexture>` on iOS) valid until the next
    /// `encoder_frame` or `encoder_finish`. Null on failure.
    pub encoder_frame: Option<
        unsafe extern "C" fn(ctx: *mut c_void, encoder: *mut c_void, time_us: i64) -> *mut c_void,
    >,
    /// `ok`: appends the last frame and closes the file; otherwise cancels and removes it.
    /// Returns once the file is closed, frees `encoder`, and gives [`crate::ENGINE_OK`] or
    /// another value for failure. Called exactly once per opened encoder.
    pub encoder_finish:
        Option<unsafe extern "C" fn(ctx: *mut c_void, encoder: *mut c_void, ok: bool) -> i32>,
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
        let (
            Some(create_preview_texture),
            Some(frame_available),
            Some(request_thumbnail),
            Some(encoder_open),
            Some(encoder_frame),
            Some(encoder_finish),
        ) = (
            platform.create_preview_texture,
            platform.frame_available,
            platform.request_thumbnail,
            platform.encoder_open,
            platform.encoder_frame,
            platform.encoder_finish,
        )
        else {
            return ENGINE_ERR_NULL;
        };
        let registered = Registered {
            ctx: platform.ctx,
            create_preview_texture,
            frame_available,
            request_thumbnail,
            encoder_open,
            encoder_frame,
            encoder_finish,
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
    encoder_open:
        unsafe extern "C" fn(*mut c_void, u32, u32, u32, u32, *const u8, usize) -> *mut c_void,
    encoder_frame: unsafe extern "C" fn(*mut c_void, *mut c_void, i64) -> *mut c_void,
    encoder_finish: unsafe extern "C" fn(*mut c_void, *mut c_void, bool) -> i32,
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

/// [`EncoderHost`] over the registered `encoder_*` callbacks. Used only on the export worker.
pub(crate) struct PlatformEncoderHost;

impl EncoderHost for PlatformEncoderHost {
    fn open(&self, config: &EncoderConfig) -> Result<Box<dyn Encoder>, String> {
        let platform = PLATFORM.get().ok_or("no platform registered")?;
        // SAFETY: registered callback (engine_platform_register's contract); `path` is valid
        // for the call.
        let encoder = unsafe {
            (platform.encoder_open)(
                platform.ctx,
                config.width,
                config.height,
                config.fps,
                config.kbps,
                config.path.as_ptr(),
                config.path.len(),
            )
        };
        if encoder.is_null() {
            return Err("the encoder could not open".into());
        }
        Ok(Box::new(PlatformEncoder {
            platform,
            encoder: Some(encoder),
        }))
    }
}

/// One open platform encoder; finished exactly once (by `finish`, or cancelled on drop).
struct PlatformEncoder {
    platform: &'static Registered,
    encoder: Option<*mut c_void>,
}

// SAFETY: the encoder handle is only passed back to the platform, from the one worker thread
// that owns this value; the platform's encoder calls may come from any thread (ADR 0005).
unsafe impl Send for PlatformEncoder {}

impl Encoder for PlatformEncoder {
    fn frame(&mut self, time: Time) -> Result<PlatformTexture, String> {
        let encoder = self.encoder.ok_or("the encoder is finished")?;
        // Whole microseconds, rounded down; ticks stay the engine's time unit.
        let time_us = i64::try_from(
            i128::from(time.0) * 1_000_000 / i128::from(framix_core::time::TICKS_PER_SECOND),
        )
        .map_err(|_| "frame time out of range")?;
        // SAFETY: registered callback; `encoder` came from encoder_open and is not finished.
        let target = unsafe { (self.platform.encoder_frame)(self.platform.ctx, encoder, time_us) };
        if target.is_null() {
            return Err("the encoder gave no buffer".into());
        }
        Ok(PlatformTexture {
            id: 0,
            handle: target as usize,
        })
    }

    fn finish(mut self: Box<Self>, ok: bool) -> Result<(), String> {
        let encoder = self.encoder.take().ok_or("the encoder is finished")?;
        // SAFETY: registered callback; `encoder` is finished exactly once (taken above).
        let status = unsafe { (self.platform.encoder_finish)(self.platform.ctx, encoder, ok) };
        match status {
            ENGINE_OK => Ok(()),
            _ => Err("the encoder could not finish the file".into()),
        }
    }
}

impl Drop for PlatformEncoder {
    fn drop(&mut self) {
        if let Some(encoder) = self.encoder.take() {
            // SAFETY: as in finish; this encoder was never finished.
            unsafe { (self.platform.encoder_finish)(self.platform.ctx, encoder, false) };
        }
    }
}
