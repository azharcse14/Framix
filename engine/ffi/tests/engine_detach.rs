//! engine_destroy returns at once; the engine finishes queued work and ends with
//! EngineStopped (P1-044).

use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

use framix_app::proto::{AddTrack, Command, Event, TrackKind, command, event};
use framix_ffi::{
    ENGINE_OK, ENGINE_PROTOCOL_VERSION, Engine, EngineBuffer, engine_create, engine_destroy,
    engine_free_buffer, engine_send, engine_set_event_callback,
};
use prost::Message;

/// Events go here; the first callback waits on `RELEASE` before returning.
static EVENTS: OnceLock<Mutex<Sender<Event>>> = OnceLock::new();
static ENTERED: OnceLock<Mutex<Sender<()>>> = OnceLock::new();
static RELEASE: OnceLock<Mutex<Receiver<()>>> = OnceLock::new();

unsafe extern "C" fn on_event(ptr: *mut u8, len: usize) {
    // SAFETY: the engine passes a live buffer of `len` bytes that this callback now owns.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    // SAFETY: ownership came with the call; freed exactly once here.
    unsafe { engine_free_buffer(EngineBuffer { ptr, len }) };
    let event = Event::decode(bytes.as_slice()).unwrap();
    // Block the engine thread inside the first callback until the test lets go.
    if let Some(entered) = ENTERED.get() {
        let _ = entered.lock().unwrap().send(());
        let _ = RELEASE.get().unwrap().lock().unwrap().recv();
    }
    EVENTS.get().unwrap().lock().unwrap().send(event).unwrap();
}

#[test]
fn destroy_returns_while_the_engine_is_busy_and_stopped_comes_last() {
    let (events_tx, events) = channel();
    let (entered_tx, entered) = channel();
    let (release, release_rx) = channel();
    EVENTS.set(Mutex::new(events_tx)).unwrap();
    ENTERED.set(Mutex::new(entered_tx)).unwrap();
    RELEASE.set(Mutex::new(release_rx)).unwrap();

    let add = Command {
        kind: Some(command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Audio as i32,
        })),
    }
    .encode_to_vec();
    let mut engine: *mut Engine = std::ptr::null_mut();
    // SAFETY: valid out pointer; `on_event` is a static fn; `add` outlives each send.
    unsafe {
        assert_eq!(
            engine_create(ENGINE_PROTOCOL_VERSION, &mut engine),
            ENGINE_OK
        );
        assert_eq!(engine_set_event_callback(engine, Some(on_event)), ENGINE_OK);
        for _ in 0..3 {
            assert_eq!(engine_send(engine, add.as_ptr(), add.len()), ENGINE_OK);
        }
    }
    entered
        .recv_timeout(Duration::from_secs(5))
        .expect("engine reached the callback");

    // The engine thread is stuck in the callback; destroy must not wait for it.
    let handle = engine as usize;
    let (done_tx, done) = channel();
    std::thread::spawn(move || {
        // SAFETY: the engine is not used after this call.
        done_tx
            .send(unsafe { engine_destroy(handle as *mut Engine) })
            .unwrap();
    });
    assert_eq!(
        done.recv_timeout(Duration::from_secs(5)),
        Ok(ENGINE_OK),
        "destroy blocked"
    );

    // Only the first callback blocks.
    drop(release);
    let mut kinds = Vec::new();
    loop {
        let e = events.recv_timeout(Duration::from_secs(5)).expect("event");
        let stopped = matches!(e.kind, Some(event::Kind::EngineStopped(_)));
        kinds.push(e.kind);
        if stopped {
            break;
        }
    }
    let tracks: Vec<usize> = kinds[..kinds.len() - 1]
        .iter()
        .map(|k| match k {
            Some(event::Kind::TimelineChanged(t)) => t.tracks.len(),
            other => panic!("expected TimelineChanged, got {other:?}"),
        })
        .collect();
    assert_eq!(
        tracks,
        vec![1, 2, 3],
        "queued commands answered before the end"
    );
    assert!(
        events.recv_timeout(Duration::from_millis(200)).is_err(),
        "nothing after EngineStopped"
    );
}
