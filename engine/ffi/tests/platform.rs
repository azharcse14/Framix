//! CreatePreview through registered platform callbacks (P1-005). The fake platform answers
//! from another thread like Swift's main queue would. Tests take turns: the platform and the
//! event callback are process-wide.

use std::ffi::c_void;
use std::sync::atomic::{AtomicU8, Ordering};
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

/// How the fake platform answers: fail, succeed with a null texture, or never.
const FAIL: u8 = 0;
const NULL_TEXTURE: u8 = 1;
const NEVER: u8 = 2;
static MODE: AtomicU8 = AtomicU8::new(FAIL);

/// `done_ctx` crosses threads as an address, like Swift's `UInt(bitPattern:)`.
unsafe extern "C" fn create(
    _: *mut c_void,
    _: u32,
    _: u32,
    done: EnginePreviewTextureDone,
    done_ctx: *mut c_void,
) {
    let mode = MODE.load(Ordering::SeqCst);
    if mode == NEVER {
        return;
    }
    let ctx = done_ctx as usize;
    std::thread::spawn(move || {
        let status = if mode == FAIL { -1 } else { ENGINE_OK };
        // SAFETY: called once with the ctx that came with the request.
        unsafe { done(ctx as *mut c_void, status, 7, std::ptr::null_mut()) };
    });
}

unsafe extern "C" fn frame(_: *mut c_void, _: i64) {}

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
            };
            // SAFETY: valid platform with static callbacks and a null ctx.
            assert_eq!(unsafe { engine_platform_register(&platform) }, ENGINE_OK);
        });
        let turn = TURN.lock().unwrap_or_else(|e| e.into_inner());
        MODE.store(mode, Ordering::SeqCst);
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

#[test]
fn a_platform_failure_comes_back_as_command_failed() {
    let s = Session::start(FAIL);
    s.create_preview();
    assert_eq!(
        s.next_event(),
        event::Kind::CommandAccepted(Default::default())
    );
    assert!(matches!(s.next_event(), event::Kind::CommandFailed(_)));
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(s.engine) }, ENGINE_OK);
}

#[test]
fn a_null_texture_is_refused() {
    let s = Session::start(NULL_TEXTURE);
    s.create_preview();
    assert_eq!(
        s.next_event(),
        event::Kind::CommandAccepted(Default::default())
    );
    assert!(matches!(s.next_event(), event::Kind::CommandFailed(_)));
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(s.engine) }, ENGINE_OK);
}

#[test]
fn destroy_returns_when_the_platform_never_answers() {
    let s = Session::start(NEVER);
    s.create_preview();
    assert_eq!(
        s.next_event(),
        event::Kind::CommandAccepted(Default::default())
    );
    let engine = s.engine as usize;
    let (tx, done) = channel();
    std::thread::spawn(move || {
        // SAFETY: not used after this.
        tx.send(unsafe { engine_destroy(engine as *mut Engine) })
            .unwrap();
    });
    assert_eq!(done.recv_timeout(Duration::from_secs(5)), Ok(ENGINE_OK));
}
