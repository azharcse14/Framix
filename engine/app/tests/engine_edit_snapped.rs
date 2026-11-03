//! TimelineChanged.snapped (P1-085): a SnapTrim or SnapMove that landed on a snap point says
//! so, as a snapping Seek does, so the UI can give the same haptic tick.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, SnapMove, SnapTrim, TimelineChanged, command, event,
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
        uri: format!("content://media/external/video/{n}"),
        kind: MediaKind::Video as i32,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        codec: "avc1".into(),
        ..Default::default()
    }
}

fn trim(clip_id: u64, start: i64, end: i64, snap_within: i64) -> command::Kind {
    command::Kind::SnapTrim(SnapTrim {
        clip_id,
        start,
        end,
        snap_within,
    })
}

fn mv(clip_id: u64, track_id: u64, start: i64, snap_within: i64) -> command::Kind {
    command::Kind::SnapMove(SnapMove {
        clip_id,
        track_id,
        start,
        snap_within,
    })
}

#[test]
fn snapping_edits_say_so_and_others_do_not() {
    let mut engine = Engine::default();
    let t = run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video(1), video(2)],
        }),
    );
    assert!(!t.snapped, "an import does not snap");
    let (track, a, b) = (
        t.tracks[0].id,
        t.tracks[0].clips[0].id,
        t.tracks[0].clips[1].id,
    );

    let t = run(&mut engine, mv(b, track, 4 * S, 0));
    assert!(!t.snapped, "no tolerance, no snap");
    // The first clip's end dropped at 3.95 s lands on the second clip's start (4 s).
    let t = run(&mut engine, trim(a, 0, 395 * S / 100, S / 10));
    assert!(t.snapped, "a trim that snapped");
    let t = run(&mut engine, trim(a, 0, S, S / 10));
    assert!(!t.snapped, "a trim near nothing");
    // Dropped at 1.95 s, the 1 s clip ends at 2.95 s: near nothing. At 2.97 s it ends 0.03 s
    // before 4 s and snaps.
    let t = run(&mut engine, mv(a, track, 195 * S / 100, S / 100));
    assert!(!t.snapped, "a move near nothing");
    let t = run(&mut engine, mv(a, track, 297 * S / 100, S / 10));
    assert!(t.snapped, "a move that snapped");
}
