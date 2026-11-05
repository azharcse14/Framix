//! Playback (P1-061): Play advances the playhead with the clock until Pause or the end; the
//! engine reports each step as PlayheadChanged with `playing` set.

use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex};

use framix_app::clock::Clock;
use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, Event, ImportMedia, MediaItem, MediaKind, NewProject, Pause, Play,
    PlayheadChanged, RemoveClip, Seek, StepFrame, TimelineChanged, Undo, command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::Layer;

const SECOND: i64 = TICKS_PER_SECOND;

/// A clock the test moves by hand.
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

fn engine() -> (Engine, FakeClock) {
    let clock = FakeClock::default();
    // A clock far from 0, so nothing works only because both start at 0.
    clock.advance(1000 * SECOND);
    (Engine::default().with_clock(Box::new(clock.clone())), clock)
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

fn play(engine: &mut Engine) -> PlayheadChanged {
    head(run(engine, command::Kind::Play(Play {})))
}

fn pause(engine: &mut Engine) -> PlayheadChanged {
    head(run(engine, command::Kind::Pause(Pause {})))
}

fn seek(engine: &mut Engine, time: i64) -> PlayheadChanged {
    head(run(
        engine,
        command::Kind::Seek(Seek {
            time,
            snap_within: 0,
        }),
    ))
}

fn advance(engine: &mut Engine) -> Option<PlayheadChanged> {
    engine.advance_playback().map(head)
}

/// Imports `seconds` long videos back to back; returns the timeline.
fn import(engine: &mut Engine, seconds: &[i64]) -> TimelineChanged {
    let items = seconds
        .iter()
        .enumerate()
        .map(|(i, s)| MediaItem {
            color: 0,
            uri: format!("content://media/external/video/{i}"),
            kind: MediaKind::Video as i32,
            duration_value: s * 1000,
            duration_timescale: 1000,
            width: 1080,
            height: 1920,
            rotation: 0,
            codec: "avc1".into(),
        })
        .collect();
    changed(run(
        engine,
        command::Kind::ImportMedia(ImportMedia { items }),
    ))
}

#[test]
fn play_advances_the_playhead_with_the_clock() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[4]);
    seek(&mut engine, SECOND);
    let started = play(&mut engine);
    assert!(started.playing);
    assert_eq!(started.time, SECOND);
    assert!(engine.is_playing());

    clock.advance(SECOND / 2);
    let step = advance(&mut engine).expect("a step while playing");
    assert!(step.playing);
    assert_eq!(step.time, SECOND + SECOND / 2);
    clock.advance(SECOND / 2);
    assert_eq!(advance(&mut engine).expect("step").time, 2 * SECOND);
}

#[test]
fn nothing_advances_while_paused() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[4]);
    clock.advance(SECOND);
    assert!(advance(&mut engine).is_none());
    assert!(!engine.is_playing());
}

#[test]
fn pause_stops_where_the_clock_is_now() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[4]);
    play(&mut engine);
    clock.advance(SECOND / 3);
    // No step since Play: Pause still lands on the clock's time, not the last step's.
    let paused = pause(&mut engine);
    assert!(!paused.playing);
    assert_eq!(paused.time, SECOND / 3);
    assert!(!engine.is_playing());
    clock.advance(SECOND);
    assert!(advance(&mut engine).is_none());
    assert_eq!(
        pause(&mut engine).time,
        SECOND / 3,
        "pause again is a no-op"
    );
}

#[test]
fn playback_stops_at_the_end() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[2]);
    play(&mut engine);
    clock.advance(5 * SECOND);
    let last = advance(&mut engine).expect("the last step");
    assert_eq!(last.time, 2 * SECOND);
    assert!(!last.playing);
    assert!(!engine.is_playing());
    assert!(advance(&mut engine).is_none());
}

#[test]
fn play_at_the_end_starts_again_from_zero() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[2]);
    seek(&mut engine, 2 * SECOND);
    let started = play(&mut engine);
    assert!(started.playing);
    assert_eq!(started.time, 0);
    clock.advance(SECOND);
    assert_eq!(advance(&mut engine).expect("step").time, SECOND);
}

#[test]
fn play_on_an_empty_timeline_does_not_start() {
    let (mut engine, _) = engine();
    let reply = play(&mut engine);
    assert!(!reply.playing);
    assert_eq!(reply.time, 0);
    assert!(!engine.is_playing());
}

#[test]
fn play_while_playing_keeps_going() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[4]);
    play(&mut engine);
    clock.advance(SECOND);
    let again = play(&mut engine);
    assert!(again.playing);
    assert_eq!(again.time, SECOND);
    clock.advance(SECOND);
    assert_eq!(advance(&mut engine).expect("step").time, 2 * SECOND);
}

#[test]
fn play_without_a_clock_is_refused() {
    let mut engine = Engine::default();
    import(&mut engine, &[4]);
    let reply = run(&mut engine, command::Kind::Play(Play {}));
    assert!(
        matches!(reply.kind, Some(event::Kind::CommandFailed(_))),
        "{reply:?}"
    );
}

#[test]
fn seeking_while_playing_plays_on_from_the_new_time() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[4]);
    play(&mut engine);
    clock.advance(SECOND);
    let moved = seek(&mut engine, 3 * SECOND);
    assert!(moved.playing);
    assert_eq!(moved.time, 3 * SECOND);
    clock.advance(SECOND / 2);
    assert_eq!(
        advance(&mut engine).expect("step").time,
        3 * SECOND + SECOND / 2
    );

    let stepped = head(run(
        &mut engine,
        command::Kind::StepFrame(StepFrame { frames: -15 }),
    ));
    assert!(stepped.playing);
    clock.advance(SECOND / 4);
    assert_eq!(
        advance(&mut engine).expect("step").time,
        stepped.time + SECOND / 4
    );
}

#[test]
fn edits_keep_playing_and_a_shorter_timeline_ends_it_sooner() {
    let (mut engine, clock) = engine();
    let t = import(&mut engine, &[2, 3]);
    play(&mut engine);
    clock.advance(SECOND);
    let second_clip = t.tracks[0].clips[1].id;
    let edited = changed(run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip {
            clip_id: second_clip,
        }),
    ));
    assert!(edited.playing, "an edit does not stop playback");
    let undone = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert!(undone.playing, "undo does not stop playback");
    run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip {
            clip_id: second_clip,
        }),
    );
    clock.advance(2 * SECOND);
    let last = advance(&mut engine).expect("the last step");
    assert_eq!(last.time, 2 * SECOND, "stops at the new end");
    assert!(!last.playing);
}

#[test]
fn a_new_project_stops_playback() {
    let (mut engine, clock) = engine();
    import(&mut engine, &[4]);
    play(&mut engine);
    clock.advance(SECOND);
    let t = changed(run(&mut engine, command::Kind::NewProject(NewProject {})));
    assert!(!t.playing);
    assert_eq!(t.playhead, 0);
    assert!(!engine.is_playing());
    assert!(advance(&mut engine).is_none());
}

/// Draws the renderer saw, with their times.
type Draws = Arc<Mutex<Vec<Time>>>;

struct Host;

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
}

struct Renderer(Draws);

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        _: PlatformTexture,
        time: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        self.0.lock().unwrap().push(time);
        Ok(())
    }
}

#[test]
fn each_step_redraws_the_preview_once_flushed() {
    let draws = Draws::default();
    let clock = FakeClock::default();
    let mut engine = Engine::default()
        .with_clock(Box::new(clock.clone()))
        .with_preview(Box::new(Host), Box::new(Renderer(draws.clone())));
    import(&mut engine, &[4]);
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    play(&mut engine);
    clock.advance(SECOND);
    engine.advance_playback();
    assert!(engine.flush_preview().is_none());
    assert_eq!(*draws.lock().unwrap(), vec![Time(0), Time(SECOND)]);
}
