use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Mutex, MutexGuard};
use std::time::Duration;

use framix_app::proto::{AddTrack, Command, Event, TrackKind, command, event};
use framix_ffi::{
    ENGINE_ERR_NULL, ENGINE_ERR_PROTOCOL, ENGINE_OK, ENGINE_PROTOCOL_VERSION, Engine, EngineBuffer,
    engine_create, engine_destroy, engine_free_buffer, engine_send, engine_set_event_callback,
};
use prost::Message;

// The C callback has no user-data pointer, so events go through one global channel and
// tests take turns.
static SINK: Mutex<Option<Sender<Vec<u8>>>> = Mutex::new(None);
static TURN: Mutex<()> = Mutex::new(());

unsafe extern "C" fn on_event(ptr: *mut u8, len: usize) {
    // SAFETY: the engine passes a live buffer of `len` bytes that this callback now owns.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    // SAFETY: ownership of the buffer came with the call; it is freed exactly once here.
    unsafe { engine_free_buffer(EngineBuffer { ptr, len }) };
    if let Some(tx) = SINK.lock().unwrap().as_ref() {
        tx.send(bytes).unwrap();
    }
}

struct Session {
    engine: *mut Engine,
    events: Receiver<Vec<u8>>,
    _turn: MutexGuard<'static, ()>,
}

impl Session {
    fn start() -> Self {
        let turn = TURN.lock().unwrap_or_else(|e| e.into_inner());
        let (tx, events) = channel();
        *SINK.lock().unwrap() = Some(tx);
        let mut engine = std::ptr::null_mut();
        // SAFETY: `engine` is a valid out pointer.
        assert_eq!(
            unsafe { engine_create(ENGINE_PROTOCOL_VERSION, &mut engine) },
            ENGINE_OK
        );
        assert!(!engine.is_null());
        // SAFETY: fresh engine; `on_event` is a static fn.
        assert_eq!(
            unsafe { engine_set_event_callback(engine, Some(on_event)) },
            ENGINE_OK
        );
        Self {
            engine,
            events,
            _turn: turn,
        }
    }

    fn send(&self, bytes: &[u8]) -> i32 {
        // SAFETY: live engine; `bytes` is a valid slice.
        unsafe { engine_send(self.engine, bytes.as_ptr(), bytes.len()) }
    }

    fn next_event(&self) -> Event {
        let bytes = self
            .events
            .recv_timeout(Duration::from_secs(5))
            .expect("no event");
        Event::decode(bytes.as_slice()).unwrap()
    }
}

impl Drop for Session {
    fn drop(&mut self) {
        // SAFETY: the engine is not used after this.
        unsafe { engine_destroy(self.engine) };
    }
}

fn add_track() -> Vec<u8> {
    Command {
        kind: Some(command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        })),
    }
    .encode_to_vec()
}

#[test]
fn wrong_protocol_version_is_refused() {
    let mut engine = std::ptr::null_mut();
    // SAFETY: `engine` is a valid out pointer.
    let code = unsafe { engine_create(ENGINE_PROTOCOL_VERSION + 1, &mut engine) };
    assert_eq!(code, ENGINE_ERR_PROTOCOL);
    assert!(engine.is_null());
}

#[test]
fn null_arguments_are_refused() {
    // SAFETY: null pointers are documented as rejected.
    unsafe {
        assert_eq!(
            engine_create(ENGINE_PROTOCOL_VERSION, std::ptr::null_mut()),
            ENGINE_ERR_NULL
        );
        assert_eq!(
            engine_send(std::ptr::null(), std::ptr::null(), 0),
            ENGINE_ERR_NULL
        );
        assert_eq!(
            engine_set_event_callback(std::ptr::null(), None),
            ENGINE_ERR_NULL
        );
        assert_eq!(engine_destroy(std::ptr::null_mut()), ENGINE_OK);
    }
}

#[test]
fn command_round_trips_to_an_event() {
    let s = Session::start();
    assert_eq!(s.send(&add_track()), ENGINE_OK);
    match s.next_event().kind {
        Some(event::Kind::TimelineChanged(t)) => assert_eq!(t.tracks.len(), 1),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn commands_are_answered_in_order() {
    let s = Session::start();
    for _ in 0..3 {
        assert_eq!(s.send(&add_track()), ENGINE_OK);
    }
    for n in 1..=3 {
        match s.next_event().kind {
            Some(event::Kind::TimelineChanged(t)) => assert_eq!(t.tracks.len(), n),
            other => panic!("expected TimelineChanged, got {other:?}"),
        }
    }
}

#[test]
fn undecodable_bytes_give_command_failed() {
    let s = Session::start();
    assert_eq!(s.send(&[0xff, 0xff, 0xff]), ENGINE_OK);
    assert!(matches!(
        s.next_event().kind,
        Some(event::Kind::CommandFailed(_))
    ));
}
