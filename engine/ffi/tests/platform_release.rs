//! A platform answer that arrives after the engine stopped still gives its texture back
//! (P1-065, P1-055): nobody else will release it.

use std::ffi::c_void;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Mutex, MutexGuard, Once};
use std::time::Duration;

use framix_app::proto::{Command, CreatePreview, Event, command, event};
use framix_ffi::{
    ENGINE_OK, ENGINE_PLATFORM_VERSION, ENGINE_PROTOCOL_VERSION, Engine, EngineBuffer,
    EnginePlatform, EnginePreviewTextureDone, engine_create, engine_destroy, engine_free_buffer,
    engine_platform_register, engine_send, engine_set_event_callback,
};
use prost::Message;

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

/// The request the fake platform holds: its `done` and `done_ctx`, as addresses.
static HELD: Mutex<Option<(usize, usize)>> = Mutex::new(None);
/// What `release_preview_texture` got: (texture_id, texture).
static RELEASED: Mutex<Vec<(i64, usize)>> = Mutex::new(Vec::new());
static MODE: AtomicUsize = AtomicUsize::new(0);

/// Never answers by itself; the test answers later through [`HELD`].
unsafe extern "C" fn create(
    _: *mut c_void,
    _: u32,
    _: u32,
    done: EnginePreviewTextureDone,
    done_ctx: *mut c_void,
) {
    *HELD.lock().unwrap() = Some((done as usize, done_ctx as usize));
}

unsafe extern "C" fn release(_: *mut c_void, texture_id: i64, texture: *mut c_void) {
    RELEASED
        .lock()
        .unwrap()
        .push((texture_id, texture as usize));
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

static SINK: Mutex<Option<Sender<Vec<u8>>>> = Mutex::new(None);
static TURN: Mutex<()> = Mutex::new(());

unsafe extern "C" fn on_event(ptr: *mut u8, len: usize) {
    // SAFETY: the engine passes a live buffer of `len` bytes that this callback now owns.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    // SAFETY: ownership came with the call; freed exactly once here.
    unsafe { engine_free_buffer(EngineBuffer { ptr, len }) };
    if let Some(tx) = SINK.lock().unwrap().as_ref() {
        let _ = tx.send(bytes);
    }
}

struct Session {
    engine: *mut Engine,
    events: Receiver<Vec<u8>>,
    _turn: MutexGuard<'static, ()>,
}

impl Drop for Session {
    /// Tests destroy the engine themselves; hold the turn until its last event (P1-044:
    /// destroy returns at once) so the marker can't land in the next session.
    fn drop(&mut self) {
        while let Ok(bytes) = self.events.recv_timeout(Duration::from_secs(5)) {
            if matches!(
                Event::decode(bytes.as_slice()).map(|e| e.kind),
                Ok(Some(event::Kind::EngineStopped(_)))
            ) {
                break;
            }
        }
    }
}

impl Session {
    fn start(mode: u8) -> Self {
        static REGISTER: Once = Once::new();
        REGISTER.call_once(|| {
            let platform = EnginePlatform {
                version: ENGINE_PLATFORM_VERSION,
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
                request_proxy: Some(no_proxy),
                free_bytes: Some(no_free_bytes),
                release_preview_texture: Some(release),
            };
            // SAFETY: valid platform with static callbacks and a null ctx.
            assert_eq!(unsafe { engine_platform_register(&platform) }, ENGINE_OK);
        });
        let turn = TURN.lock().unwrap_or_else(|e| e.into_inner());
        MODE.store(mode as usize, Ordering::SeqCst);
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
        Self {
            engine,
            events,
            _turn: turn,
        }
    }

    fn create_preview(&self) {
        let bytes = Command {
            id: 0,
            kind: Some(command::Kind::CreatePreview(CreatePreview {
                width: 1280,
                height: 720,
            })),
        }
        .encode_to_vec();
        // SAFETY: live engine; valid slice.
        assert_eq!(
            unsafe { engine_send(self.engine, bytes.as_ptr(), bytes.len()) },
            ENGINE_OK
        );
    }

    fn next_event(&self) -> event::Kind {
        let bytes = self
            .events
            .recv_timeout(Duration::from_secs(5))
            .expect("no event");
        Event::decode(bytes.as_slice())
            .unwrap()
            .kind
            .expect("event kind")
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
    _: u32,
    _: *mut framix_ffi::EngineFrame,
) -> i32 {
    -1
}

unsafe extern "C" fn no_decoder_close(_: *mut c_void, _: *mut c_void) {}

unsafe extern "C" fn no_proxy(
    _: *mut c_void,
    _: *const u8,
    _: usize,
    _: u32,
    _: framix_ffi::EngineProxyDone,
    _: *mut c_void,
) {
}

unsafe extern "C" fn no_free_bytes(_: *mut c_void, _: *const u8, _: usize) -> i64 {
    -1
}

#[test]
fn a_texture_made_after_the_engine_stopped_is_released() {
    let s = Session::start(0);
    s.create_preview();
    assert_eq!(
        s.next_event(),
        event::Kind::CommandAccepted(Default::default())
    );
    let (done, ctx) = HELD.lock().unwrap().take().expect("a held request");
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(s.engine) }, ENGINE_OK);
    // Waits for EngineStopped: the engine is gone before the platform answers.
    drop(s);
    // SAFETY: `done` is the EnginePreviewTextureDone the engine passed with `ctx`, answered
    // once, here.
    unsafe {
        let done: EnginePreviewTextureDone = std::mem::transmute(done);
        done(ctx as *mut c_void, ENGINE_OK, 9, 0x99 as *mut c_void);
    }
    assert!(RELEASED.lock().unwrap().contains(&(9, 0x99)));
}

#[test]
fn a_failed_answer_after_the_engine_stopped_releases_nothing() {
    let s = Session::start(0);
    s.create_preview();
    assert_eq!(
        s.next_event(),
        event::Kind::CommandAccepted(Default::default())
    );
    let (done, ctx) = HELD.lock().unwrap().take().expect("a held request");
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(s.engine) }, ENGINE_OK);
    // Waits for EngineStopped: the engine is gone before the platform answers.
    drop(s);
    // SAFETY: as above.
    unsafe {
        let done: EnginePreviewTextureDone = std::mem::transmute(done);
        done(ctx as *mut c_void, -1, 8, std::ptr::null_mut());
    }
    assert!(RELEASED.lock().unwrap().iter().all(|&(id, _)| id != 8));
}
