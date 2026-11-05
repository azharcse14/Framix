//! Loop playback edges (P1-027 review): a loop ending at or past the timeline's end.

use std::sync::Arc;
use std::sync::atomic::{AtomicI64, Ordering};

use framix_app::clock::Clock;
use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, Play, PlayheadChanged, Seek, SetLoop,
    command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};

const SECOND: i64 = TICKS_PER_SECOND;

#[derive(Clone, Default)]
struct FakeClock(Arc<AtomicI64>);

impl Clock for FakeClock {
    fn now(&self) -> Time {
        Time(self.0.load(Ordering::SeqCst))
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    })
}

fn head(e: Event) -> PlayheadChanged {
    match e.kind {
        Some(event::Kind::PlayheadChanged(p)) => p,
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

/// A playing engine on a `seconds` long video, looping [start, end), from `from`.
fn playing(seconds: i64, start: i64, end: i64, from: i64) -> (Engine, FakeClock) {
    let clock = FakeClock::default();
    clock.0.store(1000 * SECOND, Ordering::SeqCst);
    let mut engine = Engine::default().with_clock(Box::new(clock.clone()));
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                color: 0,
                uri: "content://media/external/video/0".into(),
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
    run(&mut engine, command::Kind::SetLoop(SetLoop { start, end }));
    run(
        &mut engine,
        command::Kind::Seek(Seek {
            time: from,
            snap_within: 0,
        }),
    );
    run(&mut engine, command::Kind::Play(Play {}));
    (engine, clock)
}

fn step(engine: &mut Engine, clock: &FakeClock, by: i64) -> PlayheadChanged {
    clock.0.fetch_add(by, Ordering::SeqCst);
    head(engine.advance_playback().expect("playing"))
}

#[test]
fn a_loop_ending_at_the_timeline_end_wraps_on_a_tick_landing_there() {
    let (mut engine, clock) = playing(8, 4 * SECOND, 8 * SECOND, 6 * SECOND);
    let p = step(&mut engine, &clock, 2 * SECOND);
    assert_eq!(p.time, 4 * SECOND);
    assert!(p.playing);
    assert_eq!(step(&mut engine, &clock, SECOND).time, 5 * SECOND);
}

#[test]
fn a_loop_partly_past_the_end_wraps_at_the_timeline_end() {
    let (mut engine, clock) = playing(4, 2 * SECOND, 8 * SECOND, 3 * SECOND);
    let p = step(&mut engine, &clock, 3 * SECOND / 2);
    assert_eq!(p.time, 2 * SECOND + SECOND / 2, "wraps at 4 s, not 8 s");
    assert!(p.playing);
}
