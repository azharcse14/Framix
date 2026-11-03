//! Clip.placement_locked (P1-080): the engine says which clips it refuses to move or scale on
//! the canvas, so the canvas gestures don't copy its rules.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, SetTrackFlags, TimelineChanged, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> TimelineChanged {
    match engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
    {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn locked(t: &TimelineChanged) -> Vec<bool> {
    t.tracks[0]
        .clips
        .iter()
        .map(|c| c.placement_locked)
        .collect()
}

#[test]
fn a_color_or_a_locked_track_is_placement_locked() {
    let mut engine = Engine::default();
    let video = MediaItem {
        uri: "content://media/external/video/1".into(),
        kind: MediaKind::Video as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        codec: "avc1".into(),
        ..Default::default()
    };
    let color = MediaItem {
        kind: MediaKind::Color as i32,
        color: 0x3366_99ff,
        ..Default::default()
    };
    let t = run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video, color],
        }),
    );
    assert_eq!(locked(&t), [false, true], "a color fills the canvas");

    let t = run(
        &mut engine,
        command::Kind::SetTrackFlags(SetTrackFlags {
            track_id: t.tracks[0].id,
            muted: None,
            hidden: None,
            locked: Some(true),
        }),
    );
    assert_eq!(
        locked(&t),
        [true, true],
        "a locked track refuses every edit"
    );
}
