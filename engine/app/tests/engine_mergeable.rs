//! Clip.mergeable_with_next (P1-075): the engine says which clips MergeClips would join with
//! the next one, so the UI never offers a merge it would refuse.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, SetTrackFlags, SplitClip, TimelineChanged, command,
    event,
};
use framix_core::time::TICKS_PER_SECOND;

const S: i64 = TICKS_PER_SECOND;

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

fn video(n: u32) -> MediaItem {
    MediaItem {
        color: 0,
        uri: format!("content://media/external/video/{n}"),
        kind: MediaKind::Video as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: "avc1".into(),
    }
}

fn mergeable(t: &TimelineChanged) -> Vec<bool> {
    t.tracks[0]
        .clips
        .iter()
        .map(|c| c.mergeable_with_next)
        .collect()
}

#[test]
fn split_halves_merge_and_other_media_does_not() {
    let mut engine = Engine::default();
    let t = run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video(1), video(2)],
        }),
    );
    assert_eq!(mergeable(&t), [false, false], "two media never merge");

    let first = t.tracks[0].clips[0].id;
    let t = run(
        &mut engine,
        command::Kind::SplitClip(SplitClip {
            clip_id: first,
            at: S,
        }),
    );
    assert_eq!(mergeable(&t), [true, false, false]);

    let track = t.tracks[0].id;
    let t = run(
        &mut engine,
        command::Kind::SetTrackFlags(SetTrackFlags {
            track_id: track,
            muted: None,
            hidden: None,
            locked: Some(true),
        }),
    );
    assert_eq!(
        mergeable(&t),
        [false, false, false],
        "a locked track merges nothing"
    );
}
