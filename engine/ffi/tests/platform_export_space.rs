//! Export pre-flight through the platform vtable (P1-040): the engine asks the platform how
//! much storage is free at the export path and refuses an export that does not fit. Own test
//! binary: the platform registration is process-wide.

use std::ffi::c_void;
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::mpsc::{Sender, channel};
use std::time::Duration;

use framix_app::proto::{
    Command, Event, ExportProject, ImportMedia, MediaItem, MediaKind, command, event,
};
use framix_ffi::{
    ENGINE_ERR_NULL, ENGINE_OK, ENGINE_PLATFORM_VERSION, ENGINE_PROTOCOL_VERSION, EngineBuffer,
    EnginePlatform, EnginePreviewTextureDone, EngineProxyDone, EngineThumbnailDone, engine_create,
    engine_destroy, engine_free_buffer, engine_platform_register, engine_send,
    engine_set_event_callback,
};
use prost::Message;

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

unsafe extern "C" fn thumbnail(
    _: *mut c_void,
    _: *const u8,
    _: usize,
    _: u32,
    _: i64,
    _: u32,
    _: EngineThumbnailDone,
    _: *mut c_void,
) {
}

unsafe extern "C" fn no_proxy(
    _: *mut c_void,
    _: *const u8,
    _: usize,
    _: u32,
    _: EngineProxyDone,
    _: *mut c_void,
) {
}

/// What `free_bytes` answers; -1 = unknown.
static FREE: AtomicI64 = AtomicI64::new(-1);
/// The paths it was asked about.
static ASKED: Mutex<Vec<String>> = Mutex::new(Vec::new());

unsafe extern "C" fn free_bytes(_: *mut c_void, path: *const u8, path_len: usize) -> i64 {
    // SAFETY: the engine passes `path_len` valid bytes for this call.
    let path =
        String::from_utf8(unsafe { std::slice::from_raw_parts(path, path_len) }.to_vec()).unwrap();
    ASKED.lock().unwrap().push(path);
    FREE.load(Ordering::SeqCst)
}

static SINK: Mutex<Option<Sender<Vec<u8>>>> = Mutex::new(None);

unsafe extern "C" fn on_event(ptr: *mut u8, len: usize) {
    // SAFETY: the engine passes a live buffer of `len` bytes that this callback now owns.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    // SAFETY: ownership came with the call; freed exactly once here.
    unsafe { engine_free_buffer(EngineBuffer { ptr, len }) };
    if let Some(tx) = SINK.lock().unwrap().as_ref() {
        let _ = tx.send(bytes);
    }
}

#[test]
fn an_export_that_does_not_fit_the_free_storage_is_refused() {
    let mut platform = EnginePlatform {
        version: ENGINE_PLATFORM_VERSION,
        ctx: std::ptr::null_mut(),
        create_preview_texture: Some(create),
        frame_available: Some(frame),
        request_thumbnail: Some(thumbnail),
        encoder_open: Some(no_encoder),
        encoder_frame: Some(no_frame),
        encoder_finish: Some(no_finish),
        decoder_open: Some(no_decoder_open),
        decoder_frame: Some(no_decoder_frame),
        decoder_close: Some(no_decoder_close),
        request_proxy: Some(no_proxy),
        free_bytes: None,
        release_preview_texture: Some(no_release),
    };
    // SAFETY: valid platform with static callbacks and a null ctx.
    unsafe {
        assert_eq!(
            engine_platform_register(&platform),
            ENGINE_ERR_NULL,
            "free_bytes is required"
        );
        platform.free_bytes = Some(free_bytes);
        assert_eq!(engine_platform_register(&platform), ENGINE_OK);
    }

    let (tx, events) = channel();
    *SINK.lock().unwrap() = Some(tx);
    let mut engine = std::ptr::null_mut();
    // SAFETY: valid out pointer, then a fresh engine and a static callback.
    unsafe {
        assert_eq!(
            engine_create(ENGINE_PROTOCOL_VERSION, &mut engine),
            ENGINE_OK
        );
        assert_eq!(engine_set_event_callback(engine, Some(on_event)), ENGINE_OK);
    }
    let send = |kind| {
        let bytes = Command {
            id: 0,
            kind: Some(kind),
        }
        .encode_to_vec();
        // SAFETY: live engine; valid slice.
        assert_eq!(
            unsafe { engine_send(engine, bytes.as_ptr(), bytes.len()) },
            ENGINE_OK
        );
        let reply = events
            .recv_timeout(Duration::from_secs(5))
            .expect("no event");
        Event::decode(reply.as_slice()).unwrap().kind.expect("kind")
    };
    let photo = MediaItem {
        color: 0,
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image as i32,
        duration_value: 0,
        duration_timescale: 0,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: String::new(),
    };
    let reply = send(command::Kind::ImportMedia(ImportMedia {
        items: vec![photo],
    }));
    assert!(matches!(reply, event::Kind::TimelineChanged(_)));

    FREE.store(1000, Ordering::SeqCst);
    let export = || {
        command::Kind::ExportProject(ExportProject {
            path: "/out/a.mp4".into(),
        })
    };
    match send(export()) {
        event::Kind::ExportFinished(f) => {
            assert!(!f.ok && !f.cancelled);
            assert!(f.needed_bytes > 1000);
            assert_eq!(f.free_bytes, 1000);
        }
        other => panic!("expected ExportFinished, got {other:?}"),
    }
    assert_eq!(*ASKED.lock().unwrap(), vec!["/out/a.mp4".to_owned()]);

    // Unknown free space does not block: the export is accepted (and then fails to open the
    // fake encoder).
    FREE.store(-1, Ordering::SeqCst);
    assert!(matches!(send(export()), event::Kind::CommandAccepted(_)));
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(engine) }, ENGINE_OK);
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
    _: u32,
    _: *mut framix_ffi::EngineFrame,
) -> i32 {
    -1
}

unsafe extern "C" fn no_decoder_close(_: *mut c_void, _: *mut c_void) {}

unsafe extern "C" fn no_release(_: *mut c_void, _: i64, _: *mut c_void) {}
