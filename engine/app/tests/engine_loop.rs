//! Loop playback (P1-027): SetLoop makes Play repeat a range of the timeline.

use std::sync::Arc;
use std::sync::atomic::{AtomicI64, Ordering};

use framix_app::clock::Clock;
use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, NewProject, Play, PlayheadChanged,
    RemoveClip, Seek, SetLoop, TimelineChanged, command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};

const SECOND: i64 = TICKS_PER_SECOND;

#[derive(Clone, Default)]
struct FakeClock(Arc<AtomicI64>);

impl FakeClock {
    fn advance(&self, ticks: i64) {
        self.0.fetch_add(ticks, Ordering::SeqCst);
    }
}

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

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn head(e: Event) -> PlayheadChanged {
    match e.kind {
        Some(event::Kind::PlayheadChanged(p)) => p,
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

/// An engine with a clock and two 4 s videos back to back (8 s).
fn engine() -> (Engine, FakeClock, TimelineChanged) {
    let clock = FakeClock::default();
    clock.advance(1000 * SECOND);
    let mut engine = Engine::default().with_clock(Box::new(clock.clone()));
    let items = (0..2)
        .map(|i| MediaItem {
            color: 0,
            uri: format!("content://media/external/video/{i}"),
            kind: MediaKind::Video as i32,
            duration_value: 4000,
            duration_timescale: 1000,
            width: 1080,
            height: 1920,
            rotation: 0,
            codec: "avc1".into(),
        })
        .collect();
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia { items }),
    ));
    (engine, clock, t)
}

fn set_loop(engine: &mut Engine, start: i64, end: i64) -> TimelineChanged {
    changed(run(engine, command::Kind::SetLoop(SetLoop { start, end })))
}

fn play(engine: &mut Engine) -> PlayheadChanged {
    head(run(engine, command::Kind::Play(Play {})))
}

fn seek(engine: &mut Engine, time: i64) {
    run(
        engine,
        command::Kind::Seek(Seek {
            time,
            snap_within: 0,
        }),
    );
}

fn step(engine: &mut Engine, clock: &FakeClock, by: i64) -> PlayheadChanged {
    clock.advance(by);
    head(engine.advance_playback().expect("playing"))
}

#[test]
fn the_loop_is_reported_and_cleared() {
    let (mut engine, _, _) = engine();
    let t = set_loop(&mut engine, SECOND, 3 * SECOND);
    assert_eq!((t.loop_start, t.loop_end), (SECOND, 3 * SECOND));
    let t = set_loop(&mut engine, 2 * SECOND, 2 * SECOND);
    assert_eq!(
        (t.loop_start, t.loop_end),
        (0, 0),
        "an empty range clears it"
    );
}

#[test]
fn play_outside_the_loop_starts_at_its_start() {
    let (mut engine, _, _) = engine();
    set_loop(&mut engine, 2 * SECOND, 3 * SECOND);
    seek(&mut engine, 5 * SECOND);
    let p = play(&mut engine);
    assert_eq!(p.time, 2 * SECOND);
    assert!(p.playing);
}

#[test]
fn play_inside_the_loop_starts_where_it_is() {
    let (mut engine, _, _) = engine();
    set_loop(&mut engine, 2 * SECOND, 4 * SECOND);
    seek(&mut engine, 3 * SECOND);
    assert_eq!(play(&mut engine).time, 3 * SECOND);
}

#[test]
fn reaching_the_end_goes_on_from_the_start_without_drift() {
    let (mut engine, clock, _) = engine();
    set_loop(&mut engine, 2 * SECOND, 3 * SECOND);
    play(&mut engine);
    let p = step(&mut engine, &clock, SECOND / 2);
    assert_eq!(p.time, 2 * SECOND + SECOND / 2);
    // 0.75 s later: 0.25 s past the end is 0.25 s into the loop again.
    let p = step(&mut engine, &clock, 3 * SECOND / 4);
    assert_eq!(p.time, 2 * SECOND + SECOND / 4);
    assert!(p.playing);
    // Many laps later it is still exact: 10 laps plus 0.5 s.
    let p = step(&mut engine, &clock, 10 * SECOND + SECOND / 4);
    assert_eq!(p.time, 2 * SECOND + SECOND / 2);
    assert!(engine.is_playing());
}

#[test]
fn a_loop_past_the_timeline_ends_at_the_timeline_end() {
    let (mut engine, clock, t) = engine();
    set_loop(&mut engine, 6 * SECOND, 8 * SECOND);
    // The second clip goes: the timeline is 4 s, so the loop is past it.
    run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip {
            clip_id: t.tracks[0].clips[1].id,
        }),
    );
    seek(&mut engine, 3 * SECOND);
    play(&mut engine);
    let p = step(&mut engine, &clock, 2 * SECOND);
    assert_eq!(p.time, 4 * SECOND, "a loop off the timeline is no loop");
    assert!(!p.playing);
}

#[test]
fn a_new_project_clears_the_loop() {
    let (mut engine, _, _) = engine();
    set_loop(&mut engine, SECOND, 2 * SECOND);
    let t = changed(run(&mut engine, command::Kind::NewProject(NewProject {})));
    assert_eq!((t.loop_start, t.loop_end), (0, 0));
}
