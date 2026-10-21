//! Thumbnails through the platform vtable (P1-021): the fake platform answers from another
//! thread with a file path, and the engine reports it as ThumbnailReady. Own test binary: the
//! platform registration is process-wide.

use std::ffi::c_void;
use std::sync::Mutex;
use std::sync::mpsc::{Sender, channel};
use std::time::Duration;

use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, RequestThumbnails, command, event,
};
use framix_ffi::{
    ENGINE_ERR_NULL, ENGINE_MEDIA_VIDEO, ENGINE_OK, ENGINE_PLATFORM_VERSION,
    ENGINE_PROTOCOL_VERSION, EngineBuffer, EnginePlatform, EnginePreviewTextureDone,
    EngineThumbnailDone, engine_create, engine_destroy, engine_free_buffer,
    engine_platform_register, engine_send, engine_set_event_callback,
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

/// What the fake saw: uri, kind, time in microseconds, max side.
static SEEN: Mutex<Vec<(String, u32, i64, u32)>> = Mutex::new(Vec::new());

unsafe extern "C" fn thumbnail(
    _: *mut c_void,
    uri: *const u8,
    uri_len: usize,
    kind: u32,
    time_us: i64,
    max_side: u32,
    done: EngineThumbnailDone,
    done_ctx: *mut c_void,
) {
    // SAFETY: the engine passes `uri_len` valid bytes for this call.
    let uri =
        String::from_utf8(unsafe { std::slice::from_raw_parts(uri, uri_len) }.to_vec()).unwrap();
    SEEN.lock().unwrap().push((uri, kind, time_us, max_side));
    let ctx = done_ctx as usize;
    std::thread::spawn(move || {
        let path = format!("/cache/thumbs/{time_us}.jpg");
        // SAFETY: called once with the ctx that came with the request; path lives for the call.
        unsafe { done(ctx as *mut c_void, ENGINE_OK, path.as_ptr(), path.len()) };
    });
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
fn a_thumbnail_made_by_the_platform_comes_back_as_thumbnail_ready() {
    let mut platform = EnginePlatform {
        version: ENGINE_PLATFORM_VERSION,
        ctx: std::ptr::null_mut(),
        create_preview_texture: Some(create),
        frame_available: Some(frame),
        request_thumbnail: None,
    };
    // SAFETY: valid platform with static callbacks and a null ctx.
    unsafe {
        assert_eq!(
            engine_platform_register(&platform),
            ENGINE_ERR_NULL,
            "v2 needs thumbnails"
        );
        platform.request_thumbnail = Some(thumbnail);
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
                uri: "content://media/external/video/1".into(),
                kind: MediaKind::Video as i32,
                duration_value: 4000,
                duration_timescale: 1000,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: "avc1".into(),
            }],
        }),
    );
    let media_id = match next() {
        event::Kind::TimelineChanged(t) => t.tracks[0].clips[0].media_id,
        other => panic!("{other:?}"),
    };
    let step = framix_core::time::TICKS_PER_SECOND;
    send(
        engine,
        command::Kind::RequestThumbnails(RequestThumbnails {
            media_id,
            times: vec![2 * step],
            max_side: 96,
        }),
    );
    assert!(matches!(next(), event::Kind::CommandAccepted(_)));
    match next() {
        event::Kind::ThumbnailReady(r) => {
            assert_eq!((r.media_id, r.time, r.max_side), (media_id, 2 * step, 96));
            assert_eq!(r.path, "/cache/thumbs/2000000.jpg");
        }
        other => panic!("expected ThumbnailReady, got {other:?}"),
    }
    assert_eq!(
        *SEEN.lock().unwrap(),
        vec![(
            "content://media/external/video/1".to_owned(),
            ENGINE_MEDIA_VIDEO,
            2_000_000,
            96
        )]
    );
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(engine) }, ENGINE_OK);
}
