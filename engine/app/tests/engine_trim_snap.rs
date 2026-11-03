//! SnapTrim (P1-074): TrimClip with a tolerance;: trimmed edges snap to the nearest edge, as Seek does.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, SnapTrim, TimelineChanged, command, event,
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

fn trim(clip_id: u64, start: i64, end: i64, snap_within: i64) -> command::Kind {
    command::Kind::SnapTrim(SnapTrim {
        clip_id,
        start,
        end,
        snap_within,
    })
}

/// Two 2 s clips back to back: [0, 2 s) and [2 s, 4 s). Returns their ids.
fn two_clips(engine: &mut Engine) -> (u64, u64) {
    let t = changed(run(
        engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video(1), video(2)],
        }),
    ));
    let clips = &t.tracks[0].clips;
    (clips[0].id, clips[1].id)
}

fn span(t: &TimelineChanged, i: usize) -> (i64, i64) {
    let c = &t.tracks[0].clips[i];
    (c.start, c.start + c.duration)
}

#[test]
fn a_trimmed_edge_snaps_to_a_near_clip_edge() {
    let mut engine = Engine::default();
    let (a, b) = two_clips(&mut engine);
    changed(run(&mut engine, trim(b, 5 * S / 2, 4 * S, 0)));
    // 2.45 s is 0.05 s from the second clip's new start.
    let t = changed(run(&mut engine, trim(a, 0, 245 * S / 100, S / 10)));
    assert_eq!(span(&t, 0), (0, 5 * S / 2));
}

#[test]
fn without_a_tolerance_nothing_snaps() {
    let mut engine = Engine::default();
    let (a, b) = two_clips(&mut engine);
    changed(run(&mut engine, trim(b, 5 * S / 2, 4 * S, 0)));
    let t = changed(run(&mut engine, trim(a, 0, 245 * S / 100, 0)));
    assert_eq!(span(&t, 0), (0, 245 * S / 100));
}

#[test]
fn a_start_never_snaps_onto_its_own_end() {
    let mut engine = Engine::default();
    let (a, _) = two_clips(&mut engine);
    let t = changed(run(&mut engine, trim(a, 195 * S / 100, 2 * S, S / 10)));
    assert_eq!(span(&t, 0), (195 * S / 100, 2 * S));
}

#[test]
fn a_negative_tolerance_is_refused() {
    let mut engine = Engine::default();
    let (a, _) = two_clips(&mut engine);
    assert!(matches!(
        run(&mut engine, trim(a, 0, S, -1)),
        Some(event::Kind::CommandFailed(_))
    ));
}

// P1-074 review: the trimmed clip's own edges are no snap targets, and an edge that did not
// move stays put.

#[test]
fn an_edge_moved_less_than_the_tolerance_still_moves() {
    let mut engine = Engine::default();
    let (_, b) = two_clips(&mut engine);
    // The old end (4 s) is also the timeline end; neither pulls it back.
    let t = changed(run(&mut engine, trim(b, 2 * S, 405 * S / 100, S / 10)));
    assert_eq!(span(&t, 1), (2 * S, 405 * S / 100));
}

#[test]
fn an_end_snapped_before_its_start_stays_where_dropped() {
    let mut engine = Engine::default();
    let (_, b) = two_clips(&mut engine);
    changed(run(&mut engine, trim(b, 205 * S / 100, 4 * S, 0)));
    // 2.1 s is 0.1 s from the first clip's end (2 s), which lies before this start (2.05 s);
    // the start did not move, so it does not snap to 2 s either.
    let t = changed(run(
        &mut engine,
        trim(b, 205 * S / 100, 21 * S / 10, S / 10),
    ));
    assert_eq!(span(&t, 1), (205 * S / 100, 21 * S / 10));
}
