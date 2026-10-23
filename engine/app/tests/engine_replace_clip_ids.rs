//! A media id from an undone replace is never handed out again (P1-043 rule, P1-031 review).

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, ReplaceClip, TimelineChanged, Undo, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> TimelineChanged {
    match engine.handle(Command { kind: Some(kind) }).kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn item(n: u32) -> MediaItem {
    MediaItem {
        uri: format!("content://media/external/video/{n}"),
        kind: MediaKind::Video as i32,
        duration_value: 5000,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: String::new(),
    }
}

#[test]
fn ids_are_not_reused_after_undo() {
    let mut engine = Engine::default();
    let t = run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![item(1)],
        }),
    );
    let clip = t.tracks[0].clips[0].id;
    let replace = |n| {
        command::Kind::ReplaceClip(ReplaceClip {
            clip_id: clip,
            media: Some(item(n)),
        })
    };
    let first = run(&mut engine, replace(2)).tracks[0].clips[0].media_id;
    run(&mut engine, command::Kind::Undo(Undo {}));
    let second = run(&mut engine, replace(3)).tracks[0].clips[0].media_id;
    assert_ne!(first, second);
}
