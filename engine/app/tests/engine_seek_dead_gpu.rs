//! A dead preview never turns an applied edit or seek into CommandFailed (P1-020 review): the
//! playhead and the timeline are state, the redraw is best effort.

use framix_app::engine::Engine;
use framix_app::preview::{PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, Event, ImportMedia, MediaItem, MediaKind, NewProject, RemoveClip, Seek,
    command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};

const SECOND: i64 = TICKS_PER_SECOND;

struct Host;

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
}

/// A GPU that is gone.
struct Dead;

impl PreviewRenderer for Dead {
    fn draw(&mut self, _: PlatformTexture, _: Time) -> Result<(), String> {
        Err("device lost".into())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn engine_with_dead_preview() -> Engine {
    let mut engine = Engine::default().with_preview(Box::new(Host), Box::new(Dead));
    let items = [2, 3]
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
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia { items }),
    );
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    // The first draw fails: the platform made a texture, the GPU could not draw.
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    engine
}

#[test]
fn seek_with_a_dead_preview_still_moves_and_reports_the_playhead() {
    let mut engine = engine_with_dead_preview();
    let e = run(&mut engine, command::Kind::Seek(Seek { time: 4 * SECOND }));
    match e.kind {
        Some(event::Kind::PlayheadChanged(p)) => assert_eq!(p.time, 4 * SECOND),
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

#[test]
fn an_edit_that_pulls_the_playhead_in_is_reported_even_with_a_dead_preview() {
    let mut engine = engine_with_dead_preview();
    let clips = match run(&mut engine, command::Kind::GetTimeline(Default::default())).kind {
        Some(event::Kind::TimelineChanged(t)) => t.tracks[0].clips.clone(),
        other => panic!("{other:?}"),
    };
    run(&mut engine, command::Kind::Seek(Seek { time: 4 * SECOND }));
    let e = run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip {
            clip_id: clips[1].id,
        }),
    );
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => {
            assert_eq!(t.tracks[0].clips.len(), 1);
            assert_eq!(t.playhead, 2 * SECOND);
        }
        other => panic!("the edit was applied, so it must be reported: {other:?}"),
    }
}

#[test]
fn a_new_project_starts_at_zero() {
    let mut engine = engine_with_dead_preview();
    run(&mut engine, command::Kind::Seek(Seek { time: SECOND }));
    let e = run(&mut engine, command::Kind::NewProject(NewProject {}));
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => assert_eq!(t.playhead, 0),
        other => panic!("{other:?}"),
    }
}

/// Draws once, then the GPU is lost; counts draw attempts.
struct DiesAfterFirst(std::sync::Arc<std::sync::atomic::AtomicU32>);

impl PreviewRenderer for DiesAfterFirst {
    fn draw(&mut self, _: PlatformTexture, _: Time) -> Result<(), String> {
        let n = self.0.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        if n == 0 {
            Ok(())
        } else {
            Err("device lost".into())
        }
    }
}

#[test]
fn a_preview_lost_after_its_first_frame_stops_being_redrawn() {
    let draws = std::sync::Arc::new(std::sync::atomic::AtomicU32::new(0));
    let mut engine =
        Engine::default().with_preview(Box::new(Host), Box::new(DiesAfterFirst(draws.clone())));
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "content://media/external/video/0".into(),
                kind: MediaKind::Video as i32,
                duration_value: 4000,
                duration_timescale: 1000,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: "avc1".into(),
            }],
        }),
    );
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 7, handle: 1 }));
    for t in 1..=3 {
        let e = run(&mut engine, command::Kind::Seek(Seek { time: t * SECOND }));
        assert!(matches!(e.kind, Some(event::Kind::PlayheadChanged(_))));
    }
    let attempts = draws.load(std::sync::atomic::Ordering::SeqCst);
    assert_eq!(
        attempts, 2,
        "first frame, one failed redraw, then no more attempts"
    );
}
