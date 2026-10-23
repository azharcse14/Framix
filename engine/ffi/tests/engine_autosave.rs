//! Autosave through the real engine thread and file store (P1-038).

use std::path::PathBuf;
use std::sync::Mutex;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::time::Duration;

use framix_app::proto::{AddTrack, Command, EnableAutosave, Event, TrackKind, command, event};
use framix_ffi::{
    ENGINE_OK, ENGINE_PROTOCOL_VERSION, Engine, EngineBuffer, engine_create, engine_destroy,
    engine_free_buffer, engine_send, engine_set_event_callback,
};
use prost::Message;

static SINK: Mutex<Option<Sender<Event>>> = Mutex::new(None);

unsafe extern "C" fn on_event(ptr: *mut u8, len: usize) {
    // SAFETY: the engine passes a live buffer of `len` bytes that this callback now owns.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    // SAFETY: ownership came with the call; freed exactly once here.
    unsafe { engine_free_buffer(EngineBuffer { ptr, len }) };
    if let Some(tx) = SINK.lock().unwrap().as_ref() {
        let _ = tx.send(Event::decode(bytes.as_slice()).unwrap());
    }
}

/// Starts an engine, sends `commands`, destroys it, and returns its events up to and
/// including EngineStopped.
fn session(commands: &[command::Kind]) -> Vec<event::Kind> {
    let (tx, rx): (Sender<Event>, Receiver<Event>) = channel();
    *SINK.lock().unwrap() = Some(tx);
    let mut engine: *mut Engine = std::ptr::null_mut();
    // SAFETY: valid out pointer; `on_event` is a static fn; each buffer outlives its send;
    // the engine is not used after destroy.
    unsafe {
        assert_eq!(
            engine_create(ENGINE_PROTOCOL_VERSION, &mut engine),
            ENGINE_OK
        );
        assert_eq!(engine_set_event_callback(engine, Some(on_event)), ENGINE_OK);
        for kind in commands {
            let bytes = Command {
                kind: Some(kind.clone()),
            }
            .encode_to_vec();
            assert_eq!(engine_send(engine, bytes.as_ptr(), bytes.len()), ENGINE_OK);
        }
        assert_eq!(engine_destroy(engine), ENGINE_OK);
    }
    let mut kinds = Vec::new();
    loop {
        let kind = rx
            .recv_timeout(Duration::from_secs(10))
            .expect("event")
            .kind
            .unwrap();
        let stopped = matches!(kind, event::Kind::EngineStopped(_));
        kinds.push(kind);
        if stopped {
            return kinds;
        }
    }
}

fn track_count(kind: &event::Kind) -> usize {
    match kind {
        event::Kind::TimelineChanged(t) => t.tracks.len(),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn work_is_saved_at_shutdown_and_recovered_next_time() {
    let dir = std::env::temp_dir().join(format!("framix-autosave-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path: PathBuf = dir.join("autosave.framix");
    let _ = std::fs::remove_file(&path);
    let enable = command::Kind::EnableAutosave(EnableAutosave {
        path: path.to_str().unwrap().into(),
    });
    let add = command::Kind::AddTrack(AddTrack {
        kind: TrackKind::Audio as i32,
    });

    let first = session(&[enable.clone(), add]);
    assert_eq!(track_count(&first[0]), 0, "nothing to recover yet");
    assert!(path.exists(), "saved before EngineStopped");

    let second = session(&[enable]);
    assert_eq!(track_count(&second[0]), 1, "recovered");
    std::fs::remove_dir_all(&dir).unwrap();
}
