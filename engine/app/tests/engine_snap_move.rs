//! SnapMove (P1-076): MoveClip that snaps the clip's start or end to the nearest edge and
//! clamps a start before 0 to 0.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, SnapMove, TimelineChanged, command, event,
};
use framix_core::time::TICKS_PER_SECOND;

const S: i64 = TICKS_PER_SECOND;

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn changed(e: Option<event::Kind>) -> TimelineChanged {
    match e {
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

/// Two 2 s clips back to back, [0, 2 s) and [2 s, 4 s): (track, first, second).
fn two_clips(engine: &mut Engine) -> (u64, u64, u64) {
    let t = changed(run(
        engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video(1), video(2)],
        }),
    ));
    let track = &t.tracks[0];
    (track.id, track.clips[0].id, track.clips[1].id)
}

fn mv(clip_id: u64, track_id: u64, start: i64, snap_within: i64) -> command::Kind {
    command::Kind::SnapMove(SnapMove {
        clip_id,
        track_id,
        start,
        snap_within,
    })
}

fn starts(t: &TimelineChanged) -> Vec<(u64, i64)> {
    t.tracks[0].clips.iter().map(|c| (c.id, c.start)).collect()
}

#[test]
fn the_end_snaps_to_a_near_clip_start() {
    let mut engine = Engine::default();
    let (track, a, b) = two_clips(&mut engine);
    changed(run(&mut engine, mv(b, track, 4 * S, 0)));
    // Dropped at [1.95 s, 3.95 s): the end is 0.05 s from the second clip's start (4 s).
    let t = changed(run(&mut engine, mv(a, track, 195 * S / 100, S / 10)));
    assert_eq!(starts(&t), [(a, 2 * S), (b, 4 * S)]);
}

#[test]
fn the_start_snaps_too_and_the_nearer_edge_wins() {
    let mut engine = Engine::default();
    let (track, a, b) = two_clips(&mut engine);
    changed(run(&mut engine, mv(b, track, 5 * S, 0)));
    // Start 7.03 s is 0.03 s from the second clip's end (7 s); the end (9.03 s) is near nothing.
    let t = changed(run(&mut engine, mv(a, track, 703 * S / 100, S / 10)));
    assert_eq!(starts(&t), [(b, 5 * S), (a, 7 * S)]);
}

#[test]
fn a_small_move_is_not_pulled_back_to_where_it_was() {
    let mut engine = Engine::default();
    let (track, _, b) = two_clips(&mut engine);
    changed(run(&mut engine, mv(b, track, 5 * S, 0)));
    let t = changed(run(&mut engine, mv(b, track, 505 * S / 100, S / 10)));
    assert_eq!(starts(&t)[1].1, 505 * S / 100);
}

#[test]
fn a_start_before_zero_lands_at_zero() {
    let mut engine = Engine::default();
    let (track, a, b) = two_clips(&mut engine);
    changed(run(&mut engine, mv(a, track, 10 * S, 0)));
    let t = changed(run(&mut engine, mv(b, track, -S, 0)));
    assert_eq!(starts(&t), [(b, 0), (a, 10 * S)]);
}

#[test]
fn a_negative_tolerance_is_refused() {
    let mut engine = Engine::default();
    let (track, a, _) = two_clips(&mut engine);
    assert!(matches!(
        run(&mut engine, mv(a, track, 10 * S, -1)),
        Some(event::Kind::CommandFailed(_))
    ));
}
