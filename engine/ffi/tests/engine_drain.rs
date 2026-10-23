use std::sync::Mutex;

use framix_app::proto::{AddTrack, Command, Event, TrackKind, command, event};
use framix_ffi::{
    ENGINE_OK, ENGINE_PROTOCOL_VERSION, EngineBuffer, engine_create, engine_destroy,
    engine_free_buffer, engine_send, engine_set_event_callback,
};
use prost::Message;

static EVENTS: Mutex<Vec<Event>> = Mutex::new(Vec::new());

unsafe extern "C" fn on_event(ptr: *mut u8, len: usize) {
    // SAFETY: the engine passes a live buffer of `len` bytes that this callback now owns.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len) }.to_vec();
    // SAFETY: ownership came with the call; freed exactly once here.
    unsafe { engine_free_buffer(EngineBuffer { ptr, len }) };
    EVENTS
        .lock()
        .unwrap()
        .push(Event::decode(bytes.as_slice()).unwrap());
}

#[test]
fn destroy_answers_queued_commands_first() {
    let add = Command {
        kind: Some(command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Audio as i32,
        })),
    }
    .encode_to_vec();
    let mut engine = std::ptr::null_mut();
    // SAFETY: valid out pointer; the engine is used only in this test and destroyed once;
    // `on_event` is a static fn; `add` outlives each send.
    unsafe {
        assert_eq!(
            engine_create(ENGINE_PROTOCOL_VERSION, &mut engine),
            ENGINE_OK
        );
        assert_eq!(engine_set_event_callback(engine, Some(on_event)), ENGINE_OK);
        for _ in 0..3 {
            assert_eq!(engine_send(engine, add.as_ptr(), add.len()), ENGINE_OK);
        }
        assert_eq!(engine_destroy(engine), ENGINE_OK);
    }
    // P1-044: destroy returns at once; wait for the end-of-stream marker.
    let start = std::time::Instant::now();
    while !EVENTS
        .lock()
        .unwrap()
        .last()
        .is_some_and(|e| matches!(e.kind, Some(event::Kind::EngineStopped(_))))
    {
        assert!(start.elapsed().as_secs() < 5, "no EngineStopped");
        std::thread::sleep(std::time::Duration::from_millis(5));
    }
    let events = EVENTS.lock().unwrap();
    let counts: Vec<usize> = events[..events.len() - 1]
        .iter()
        .map(|e| match &e.kind {
            Some(event::Kind::TimelineChanged(t)) => t.tracks.len(),
            other => panic!("expected TimelineChanged, got {other:?}"),
        })
        .collect();
    assert_eq!(counts, vec![1, 2, 3]);
}
