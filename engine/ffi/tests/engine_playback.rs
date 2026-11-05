//! The engine thread plays on its own (P1-061): after Play it sends PlayheadChanged about 30
//! times a second until the end or Pause, and still answers commands meanwhile.

use std::sync::Mutex;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::time::{Duration, Instant};

use framix_app::proto::{
    Command, Event, GetTimeline, ImportMedia, MediaItem, MediaKind, Pause, Play, PlayheadChanged,
    command, event,
};
use framix_core::time::TICKS_PER_SECOND;
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
    let bytes = Command {
        id: 0,
        kind: Some(kind),
    }
    .encode_to_vec();
    // SAFETY: live engine; `bytes` outlives the call.
    assert_eq!(
        unsafe { engine_send(engine, bytes.as_ptr(), bytes.len()) },
        ENGINE_OK
    );
}

fn next(rx: &Receiver<Event>) -> Event {
    rx.recv_timeout(Duration::from_secs(10)).expect("an event")
}

fn head(e: Event) -> PlayheadChanged {
    match e.kind {
        Some(event::Kind::PlayheadChanged(p)) => p,
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

/// Runs `during` on an engine holding one `seconds` long video, then shuts it down.
fn with_engine(seconds: i64, during: impl FnOnce(*mut Engine, &Receiver<Event>)) {
    let _turn = TURN.lock().unwrap_or_else(|e| e.into_inner());
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
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                color: 0,
                uri: "content://media/external/video/1".into(),
                kind: MediaKind::Video as i32,
                duration_value: seconds * 1000,
                duration_timescale: 1000,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: "avc1".into(),
            }],
        }),
    );
    assert!(matches!(
        next(&rx).kind,
        Some(event::Kind::TimelineChanged(_))
    ));
    during(engine, &rx);
    // SAFETY: not used after this.
    assert_eq!(unsafe { engine_destroy(engine) }, ENGINE_OK);
    while !matches!(next(&rx).kind, Some(event::Kind::EngineStopped(_))) {}
}

#[test]
fn plays_to_the_end_at_about_30_steps_a_second() {
    with_engine(1, |engine, rx| {
        send(engine, command::Kind::Play(Play {}));
        let started = head(next(rx));
        assert!(started.playing);
        let start = Instant::now();
        let mut steps = Vec::new();
        let mut asked = false;
        let last = loop {
            let e = next(rx);
            match e.kind {
                Some(event::Kind::PlayheadChanged(p)) => {
                    if !p.playing {
                        break p;
                    }
                    steps.push((start.elapsed(), p.time));
                }
                Some(event::Kind::TimelineChanged(t)) => {
                    assert!(t.playing, "a command answered mid-playback");
                    asked = true;
                }
                other => panic!("unexpected {other:?}"),
            }
            if steps.len() == 5 && !asked {
                send(engine, command::Kind::GetTimeline(GetTimeline {}));
            }
        };
        assert!(asked, "GetTimeline was answered while playing");
        assert_eq!(last.time, TICKS_PER_SECOND, "stopped at the end");
        assert!(
            steps.windows(2).all(|w| w[0].1 <= w[1].1),
            "time only moves forward: {steps:?}"
        );
        let in_half_second = steps
            .iter()
            .filter(|(at, _)| *at < Duration::from_millis(500))
            .count();
        assert!(
            (5..=20).contains(&in_half_second),
            "{in_half_second} steps in the first 500 ms"
        );
    });
}

#[test]
fn pause_stops_the_steps() {
    with_engine(10, |engine, rx| {
        send(engine, command::Kind::Play(Play {}));
        assert!(head(next(rx)).playing);
        std::thread::sleep(Duration::from_millis(200));
        send(engine, command::Kind::Pause(Pause {}));
        // Steps sent before the Pause was handled come first; its reply is the last one.
        let paused = loop {
            let p = head(next(rx));
            if !p.playing {
                break p;
            }
        };
        assert!(paused.time > 0, "it played for a while");
        assert!(
            rx.recv_timeout(Duration::from_millis(150)).is_err(),
            "nothing after the Pause"
        );
    });
}
