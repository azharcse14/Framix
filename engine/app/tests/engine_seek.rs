//! The playhead (P1-020): Seek moves it inside the timeline, edits keep it there, and the
//! preview redraws at it.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, Event, ImportMedia, MediaItem, MediaKind, RemoveClip, Seek,
    TimelineChanged, Undo, command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};

const SECOND: i64 = TICKS_PER_SECOND;

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn playhead(e: Event) -> i64 {
    match e.kind {
        Some(event::Kind::PlayheadChanged(p)) => p.time,
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

fn seek(time: i64) -> command::Kind {
    command::Kind::Seek(Seek { time })
}

/// Imports `seconds` long videos back to back; returns the timeline.
fn import(engine: &mut Engine, seconds: &[i64]) -> TimelineChanged {
    let items = seconds
        .iter()
        .enumerate()
        .map(|(i, s)| MediaItem {
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
fn seek_moves_the_playhead_inside_the_timeline() {
    let mut engine = Engine::default();
    import(&mut engine, &[4]);
    assert_eq!(playhead(run(&mut engine, seek(SECOND))), SECOND);
    assert_eq!(playhead(run(&mut engine, seek(-5))), 0, "clamped at 0");
    assert_eq!(
        playhead(run(&mut engine, seek(60 * SECOND))),
        4 * SECOND,
        "clamped at the duration"
    );
}

#[test]
fn seek_on_an_empty_timeline_stays_at_zero() {
    let mut engine = Engine::default();
    assert_eq!(playhead(run(&mut engine, seek(SECOND))), 0);
}

#[test]
fn seek_is_not_an_undo_step() {
    let mut engine = Engine::default();
    import(&mut engine, &[4]);
    run(&mut engine, seek(2 * SECOND));
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert!(t.tracks.is_empty(), "undo removed the import, not the seek");
    assert!(!t.can_undo);
}

#[test]
fn timeline_reports_the_playhead_and_tick_rate() {
    let mut engine = Engine::default();
    import(&mut engine, &[4]);
    run(&mut engine, seek(3 * SECOND));
    let t = changed(run(
        &mut engine,
        command::Kind::GetTimeline(Default::default()),
    ));
    assert_eq!(t.playhead, 3 * SECOND);
    assert_eq!(t.ticks_per_second, TICKS_PER_SECOND);
}

#[test]
fn edits_that_shorten_the_timeline_pull_the_playhead_in() {
    let mut engine = Engine::default();
    let t = import(&mut engine, &[2, 3]);
    run(&mut engine, seek(4 * SECOND));
    let second_clip = t.tracks[0].clips[1].id;
    let t = changed(run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip {
            clip_id: second_clip,
        }),
    ));
    assert_eq!(t.duration, 2 * SECOND);
    assert_eq!(t.playhead, 2 * SECOND);

    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(
        t.playhead,
        2 * SECOND,
        "undo does not move the playhead back"
    );
}

/// Draws the renderer saw, with their times.
type Draws = Arc<Mutex<Vec<(i64, Time)>>>;

struct Host;

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
}

struct Renderer(Draws);

impl PreviewRenderer for Renderer {
    fn draw(&mut self, target: PlatformTexture, time: Time) -> Result<(), String> {
        self.0.lock().unwrap().push((target.id, time));
        Ok(())
    }
}

#[test]
fn seek_redraws_the_preview_at_the_new_time_once() {
    let draws = Draws::default();
    let mut engine =
        Engine::default().with_preview(Box::new(Host), Box::new(Renderer(draws.clone())));
    import(&mut engine, &[4]);
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));

    run(&mut engine, seek(SECOND));
    run(&mut engine, seek(SECOND));
    assert_eq!(
        *draws.lock().unwrap(),
        vec![(7, Time(0)), (7, Time(SECOND))],
        "first frame, then one redraw; the repeated seek changes nothing"
    );
}
