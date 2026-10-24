//! engine_platform_register validation (P1-005). Its own test binary: registration is
//! process-wide and happens once.

use std::ffi::c_void;

use framix_ffi::{
    ENGINE_ERR_ALREADY, ENGINE_ERR_NULL, ENGINE_ERR_PROTOCOL, ENGINE_OK, ENGINE_PLATFORM_VERSION,
    EnginePlatform, EnginePreviewTextureDone, engine_platform_register,
};

/// Thumbnails are not exercised here (engine_thumbnails.rs and platform_thumbnail.rs are).
unsafe extern "C" fn no_thumbnail(
    _: *mut c_void,
    _: *const u8,
    _: usize,
    _: u32,
    _: i64,
    _: u32,
    _: framix_ffi::EngineThumbnailDone,
    _: *mut c_void,
) {
}

unsafe extern "C" fn create(
    _: *mut c_void,
    _: u32,
    _: u32,
    _: EnginePreviewTextureDone,
    _: *mut c_void,
) {
}
unsafe extern "C" fn frame(_: *mut c_void, _: i64) {}

unsafe extern "C" fn no_encoder(
    _: *mut c_void,
    _: u32,
    _: u32,
    _: u32,
    _: u32,
    _: *const u8,
    _: usize,
) -> *mut c_void {
    std::ptr::null_mut()
}
unsafe extern "C" fn no_frame(_: *mut c_void, _: *mut c_void, _: i64) -> *mut c_void {
    std::ptr::null_mut()
}
unsafe extern "C" fn no_finish(_: *mut c_void, _: *mut c_void, _: bool) -> i32 {
    -1
}

fn platform(version: u32) -> EnginePlatform {
    EnginePlatform {
        version,
        ctx: std::ptr::null_mut(),
        create_preview_texture: Some(create),
        frame_available: Some(frame),
        request_thumbnail: Some(no_thumbnail),
        encoder_open: Some(no_encoder),
        encoder_frame: Some(no_frame),
        encoder_finish: Some(no_finish),
        decoder_open: Some(no_decoder_open),
        decoder_frame: Some(no_decoder_frame),
        decoder_close: Some(no_decoder_close),
    }
}

#[test]
fn register_validates_then_accepts_once() {
    let missing = EnginePlatform {
        frame_available: None,
        request_thumbnail: Some(no_thumbnail),
        ..platform(ENGINE_PLATFORM_VERSION)
    };
    // SAFETY: null and valid pointers to stack values that outlive each call; the accepted
    // platform has static callbacks and a null ctx, valid for the process.
    unsafe {
        assert_eq!(engine_platform_register(std::ptr::null()), ENGINE_ERR_NULL);
        assert_eq!(engine_platform_register(&missing), ENGINE_ERR_NULL);
        assert_eq!(
            engine_platform_register(&platform(ENGINE_PLATFORM_VERSION + 1)),
            ENGINE_ERR_PROTOCOL
        );
        assert_eq!(
            engine_platform_register(&platform(ENGINE_PLATFORM_VERSION)),
            ENGINE_OK
        );
        assert_eq!(
            engine_platform_register(&platform(ENGINE_PLATFORM_VERSION)),
            ENGINE_ERR_ALREADY
        );
    }
}

/// The decoder is not exercised here (platform_frame.rs and the simulator check it).
unsafe extern "C" fn no_decoder_open(_: *mut c_void) -> *mut c_void {
    std::ptr::null_mut()
}

unsafe extern "C" fn no_decoder_frame(
    _: *mut c_void,
    _: *mut c_void,
    _: *const u8,
    _: usize,
    _: u32,
    _: i64,
    _: *mut framix_ffi::EngineFrame,
) -> i32 {
    -1
}

unsafe extern "C" fn no_decoder_close(_: *mut c_void, _: *mut c_void) {}
