//! The engine thread autosaves on its own, without a shutdown (P1-038 review).

use std::path::PathBuf;
use std::sync::Mutex;
use std::sync::mpsc::{Sender, channel};
use std::time::{Duration, Instant};

use framix_app::proto::{
    AddTrack, Command, EnableAutosave, Event, GetTimeline, TrackKind, command, event,
};
use framix_ffi::{
    ENGINE_OK, ENGINE_PROTOCOL_VERSION, Engine, EngineBuffer, engine_create, engine_destroy,
    engine_free_buffer, engine_send, engine_set_event_callback,
};
use prost::Message;

static SINK: Mutex<Option<Sender<Event>>> = Mutex::new(None);
static TURN: Mutex<()> = Mutex::new(());

unsafe extern "C" fn on_event(ptr: *mut u8, len: usize) {
    // SAFETY: the engine passes a live buffer of `len` bytes that this callback now owns.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    // SAFETY: ownership came with the call; freed exactly once here.
    unsafe { engine_free_buffer(EngineBuffer { ptr, len }) };
    if let Some(tx) = SINK.lock().unwrap().as_ref() {
        let _ = tx.send(Event::decode(bytes.as_slice()).unwrap());
    }
}

fn send(engine: *mut Engine, kind: command::Kind) {
    let bytes = Command { kind: Some(kind) }.encode_to_vec();
    // SAFETY: live engine; `bytes` outlives the call.
    assert_eq!(
        unsafe { engine_send(engine, bytes.as_ptr(), bytes.len()) },
        ENGINE_OK
    );
}

/// Starts an engine with autosave at a fresh path and one edit; runs `during` while it is
/// alive, then destroys it and waits for EngineStopped.
fn with_engine(name: &str, during: impl FnOnce(*mut Engine, &PathBuf)) {
    let _turn = TURN.lock().unwrap_or_else(|e| e.into_inner());
    let dir = std::env::temp_dir().join(format!("framix-{name}-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("autosave.framix");
    let _ = std::fs::remove_file(&path);
    let (tx, rx) = channel();
    *SINK.lock().unwrap() = Some(tx);
    let mut engine: *mut Engine = std::ptr::null_mut();
    // SAFETY: valid out pointer; `on_event` is a static fn.
    unsafe {
        assert_eq!(
            engine_create(ENGINE_PROTOCOL_VERSION, &mut engine),
            ENGINE_OK
        );
        assert_eq!(engine_set_event_callback(engine, Some(on_event)), ENGINE_OK);
    }
    send(
        engine,
        command::Kind::EnableAutosave(EnableAutosave {
            path: path.to_str().unwrap().into(),
        }),
    );
    send(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Audio as i32,
        }),
    );
    during(engine, &path);
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(engine) }, ENGINE_OK);
    while !matches!(
        rx.recv_timeout(Duration::from_secs(10))
            .expect("event")
            .kind,
        Some(event::Kind::EngineStopped(_))
    ) {}
    std::fs::remove_dir_all(&dir).unwrap();
}

#[test]
fn an_idle_engine_saves_within_two_seconds() {
    with_engine("autosave-idle", |_, path| {
        std::thread::sleep(Duration::from_millis(2000));
        assert!(path.exists(), "saved while the engine was still running");
    });
}

#[test]
fn a_busy_engine_still_saves_within_two_seconds() {
    with_engine("autosave-busy", |engine, path| {
        let start = Instant::now();
        while start.elapsed() < Duration::from_millis(2000) {
            send(engine, command::Kind::GetTimeline(GetTimeline {}));
            std::thread::sleep(Duration::from_millis(50));
        }
        assert!(path.exists(), "saved during a stream of commands");
    });
}
