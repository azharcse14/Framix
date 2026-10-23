//! Export through the platform vtable (P1-034): the engine opens the platform's encoder from
//! the export settings on a worker thread and ends with ExportFinished. The fake encoder gives
//! no buffer, so the run fails and the file is cancelled; a successful run needs a real Metal
//! texture and is checked on the simulator. Own test binary: registration is process-wide.

use std::ffi::c_void;
use std::sync::Mutex;
use std::sync::mpsc::{Sender, channel};
use std::time::Duration;

use framix_app::proto::{
    Command, Event, ExportProject, ImportMedia, MediaItem, MediaKind, command, event,
};
use framix_ffi::{
    ENGINE_ERR_NULL, ENGINE_OK, ENGINE_PLATFORM_VERSION, ENGINE_PROTOCOL_VERSION, EngineBuffer,
    EnginePlatform, EnginePreviewTextureDone, EngineThumbnailDone, engine_create, engine_destroy,
    engine_free_buffer, engine_platform_register, engine_send, engine_set_event_callback,
};
use prost::Message;

#[derive(Debug, PartialEq)]
enum Call {
    Open(u32, u32, u32, String),
    Frame(i64),
    Finish(bool),
}

static CALLS: Mutex<Vec<Call>> = Mutex::new(Vec::new());
static SINK: Mutex<Option<Sender<Vec<u8>>>> = Mutex::new(None);
const ENCODER: usize = 0xE1C0;

unsafe extern "C" fn create(
    _: *mut c_void,
    _: u32,
    _: u32,
    _: EnginePreviewTextureDone,
    _: *mut c_void,
) {
}
unsafe extern "C" fn frame(_: *mut c_void, _: i64) {}
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
unsafe extern "C" fn open(
    _: *mut c_void,
    width: u32,
    height: u32,
    fps: u32,
    _kbps: u32,
    path: *const u8,
    path_len: usize,
) -> *mut c_void {
    // SAFETY: the engine passes `path_len` valid bytes for the call.
    let path = unsafe { std::slice::from_raw_parts(path, path_len) };
    CALLS.lock().unwrap().push(Call::Open(
        width,
        height,
        fps,
        String::from_utf8(path.to_vec()).unwrap(),
    ));
    ENCODER as *mut c_void
}
unsafe extern "C" fn next_frame(_: *mut c_void, encoder: *mut c_void, time_us: i64) -> *mut c_void {
    assert_eq!(encoder as usize, ENCODER);
    CALLS.lock().unwrap().push(Call::Frame(time_us));
    std::ptr::null_mut()
}
unsafe extern "C" fn finish(_: *mut c_void, encoder: *mut c_void, ok: bool) -> i32 {
    assert_eq!(encoder as usize, ENCODER);
    CALLS.lock().unwrap().push(Call::Finish(ok));
    ENGINE_OK
}

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
fn an_export_opens_the_encoder_and_ends_with_export_finished() {
    let platform = EnginePlatform {
        version: ENGINE_PLATFORM_VERSION,
        ctx: std::ptr::null_mut(),
        create_preview_texture: Some(create),
        frame_available: Some(frame),
        request_thumbnail: Some(thumbnail),
        encoder_open: Some(open),
        encoder_frame: Some(next_frame),
        encoder_finish: Some(finish),
    };
    let no_encoder = EnginePlatform {
        encoder_finish: None,
        ..platform
    };
    // SAFETY: valid platforms with static callbacks and a null ctx.
    unsafe {
        assert_eq!(
            engine_platform_register(&no_encoder),
            ENGINE_ERR_NULL,
            "v3 needs the encoder"
        );
        assert_eq!(engine_platform_register(&platform), ENGINE_OK);
    }

    let (tx, events) = channel();
    *SINK.lock().unwrap() = Some(tx);
    let mut engine = std::ptr::null_mut();
    let send = |engine, kind| {
        let bytes = Command { kind: Some(kind) }.encode_to_vec();
        // SAFETY: live engine; valid slice.
        assert_eq!(
            unsafe { engine_send(engine, bytes.as_ptr(), bytes.len()) },
            ENGINE_OK
        );
    };
    let next = || {
        let bytes = events
            .recv_timeout(Duration::from_secs(5))
            .expect("no event");
        Event::decode(bytes.as_slice()).unwrap().kind.expect("kind")
    };
    // SAFETY: valid out pointer, then a fresh engine and a static callback.
    unsafe {
        assert_eq!(
            engine_create(ENGINE_PROTOCOL_VERSION, &mut engine),
            ENGINE_OK
        );
        assert_eq!(engine_set_event_callback(engine, Some(on_event)), ENGINE_OK);
    }
    send(
        engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "content://media/external/images/1".into(),
                kind: MediaKind::Image as i32,
                width: 1080,
                height: 1920,
                ..Default::default()
            }],
        }),
    );
    assert!(matches!(next(), event::Kind::TimelineChanged(_)));
    send(
        engine,
        command::Kind::ExportProject(ExportProject {
            path: "/tmp/framix-export.mp4".into(),
        }),
    );
    assert!(matches!(next(), event::Kind::CommandAccepted(_)));
    match next() {
        event::Kind::ExportFinished(f) => {
            assert!(!f.ok);
            assert!(
                !f.reason.contains("/tmp"),
                "no path in the reason: {}",
                f.reason
            );
        }
        other => panic!("expected ExportFinished, got {other:?}"),
    }
    assert_eq!(
        *CALLS.lock().unwrap(),
        vec![
            // Default export: 1080p 30 fps on the default 9:16 canvas.
            Call::Open(1080, 1920, 30, "/tmp/framix-export.mp4".into()),
            Call::Frame(0),
            Call::Finish(false),
        ]
    );
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(engine) }, ENGINE_OK);
}
