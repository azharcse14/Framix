//! TimelineChanged.snapped edges (P1-085 review): a clamp at 0 or a rolled-back snap is no
//! snap; a trim's start and a move's start snap too.

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

/// [0, 2 s) and [4 s, 6 s) on one track: (track, first, second).
fn apart(engine: &mut Engine) -> (u64, u64, u64) {
    let t = run(
        engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video(1), video(2)],
        }),
    );
    let (track, a, b) = (
        t.tracks[0].id,
        t.tracks[0].clips[0].id,
        t.tracks[0].clips[1].id,
    );
    run(engine, mv(b, track, 4 * S, 0));
    (track, a, b)
}

#[test]
fn a_move_clamped_at_zero_is_no_snap() {
    let mut engine = Engine::default();
    let (track, a, _) = apart(&mut engine);
    assert!(!run(&mut engine, mv(a, track, -S / 2, S / 10)).snapped);
}

#[test]
fn a_trimmed_start_snaps_and_says_so() {
    let mut engine = Engine::default();
    let (_, a, b) = apart(&mut engine);
    // [0, 4 s) and [5 s, 6 s): the second clip has 1 s of source before its start.
    run(&mut engine, trim(a, 0, 4 * S, 0));
    run(&mut engine, trim(b, 5 * S, 6 * S, 0));
    // Its start dropped at 4.03 s lands on the first clip's end (4 s).
    let t = run(&mut engine, trim(b, 403 * S / 100, 6 * S, S / 10));
    assert!(t.snapped);
    assert_eq!(t.tracks[0].clips[1].start, 4 * S);
}

#[test]
fn a_snap_rolled_back_is_no_snap() {
    let mut engine = Engine::default();
    let (_, a, b) = apart(&mut engine);
    // [0, 4 s) and [4.05 s, 6 s).
    run(&mut engine, trim(a, 0, 4 * S, 0));
    run(&mut engine, trim(b, 405 * S / 100, 6 * S, 0));
    // The end at 4.1 s would snap to 4 s, before the start (4.05 s): it stays where dropped.
    let t = run(&mut engine, trim(b, 405 * S / 100, 41 * S / 10, S / 10));
    assert!(!t.snapped);
    assert_eq!(t.tracks[0].clips[1].duration, 5 * S / 100);
}

#[test]
fn a_move_snapping_by_its_start_says_so() {
    let mut engine = Engine::default();
    let (track, a, _) = apart(&mut engine);
    // Dropped at 6.03 s, the first clip's start lands on the second clip's end (6 s).
    let t = run(&mut engine, mv(a, track, 603 * S / 100, S / 10));
    assert!(t.snapped);
    assert_eq!(t.tracks[0].clips[1].start, 6 * S);
}
