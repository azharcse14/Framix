//! SnapMove review (P1-076): a move to another track may land on the clip's old time, a start
//! before 0 stays at 0, and no dropped start ever panics or lands before 0.

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ImportMedia, MediaItem, MediaKind, SnapMove, TimelineChanged, TrackKind,
    command, event,
};
use framix_core::time::TICKS_PER_SECOND;
use proptest::prelude::*;

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

fn mv(clip_id: u64, track_id: u64, start: i64, snap_within: i64) -> command::Kind {
    command::Kind::SnapMove(SnapMove {
        clip_id,
        track_id,
        start,
        snap_within,
    })
}

/// Two 2 s clips on V1, [0, 2 s) and [2 s, 4 s), and an empty V2: (v1, v2, first, second).
fn two_tracks(engine: &mut Engine) -> (u64, u64, u64, u64) {
    let t = changed(run(
        engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video(1), video(2)],
        }),
    ));
    let (v1, a, b) = (
        t.tracks[0].id,
        t.tracks[0].clips[0].id,
        t.tracks[0].clips[1].id,
    );
    let t = changed(run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    ));
    let v2 = t.tracks.iter().map(|t| t.id).find(|&id| id != v1).unwrap();
    (v1, v2, a, b)
}

fn start_of(t: &TimelineChanged, clip: u64) -> (u64, i64) {
    t.tracks
        .iter()
        .find_map(|tr| {
            tr.clips
                .iter()
                .find(|c| c.id == clip)
                .map(|c| (tr.id, c.start))
        })
        .unwrap()
}

#[test]
fn a_move_to_another_track_can_land_on_its_old_time() {
    let mut engine = Engine::default();
    let (_, v2, a, b) = two_tracks(&mut engine);
    changed(run(&mut engine, mv(a, v2, 4 * S, 0)));
    // V2 holds [4 s, 6 s); the second clip ([2 s, 4 s)) dropped at 2.03 s fits at 2 s exactly.
    let t = changed(run(&mut engine, mv(b, v2, 203 * S / 100, S / 10)));
    assert_eq!(start_of(&t, b), (v2, 2 * S));
}

#[test]
fn a_start_before_zero_stays_at_zero_next_to_a_near_edge() {
    let mut engine = Engine::default();
    let (v1, v2, a, b) = two_tracks(&mut engine);
    changed(run(&mut engine, mv(b, v2, 5 * S / 100, 0)));
    // V2 has an edge at 0.05 s; the first clip, already at 0, is dropped before 0.
    let t = changed(run(&mut engine, mv(a, v1, -S, S / 10)));
    assert_eq!(start_of(&t, a), (v1, 0));
}

proptest! {
    /// Any dropped start and tolerance: no panic; a landed clip starts at 0 or later and at
    /// most the tolerance away from where it was dropped (after the clamp at 0).
    #[test]
    fn a_dropped_start_never_panics_or_lands_before_zero(
        start in prop_oneof![any::<i64>(), -20 * S..20 * S],
        within in 0..2 * S,
    ) {
        let mut engine = Engine::default();
        let (v1, _, _, b) = two_tracks(&mut engine);
        if let Some(event::Kind::TimelineChanged(t)) = run(&mut engine, mv(b, v1, start, within)) {
            let (_, landed) = start_of(&t, b);
            prop_assert!(landed >= 0);
            prop_assert!(landed.abs_diff(start.max(0)) <= within.unsigned_abs());
        }
    }
}
