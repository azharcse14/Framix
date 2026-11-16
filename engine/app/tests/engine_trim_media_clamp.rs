//! ENG-061: SnapTrim and TrimToPlayhead are gestures, so an edge dragged or trimmed past either
//! end of a video's media stops at that end instead of refusing the whole trim (ENG-053).

use framix_app::engine::Engine;
use framix_app::proto::{
    ClipEdge, Command, ImportMedia, MediaItem, MediaKind, Seek, SnapMove, SnapTrim,
    TimelineChanged, TrimToPlayhead, command, event,
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

/// A clip id and its track's id.
#[derive(Clone, Copy)]
struct Placed {
    clip: u64,
    track: u64,
}

/// Imports a `ms` long video onto the first track.
fn import(engine: &mut Engine, n: u32, ms: i64) -> Placed {
    let item = MediaItem {
        uri: format!("content://media/external/video/{n}"),
        kind: MediaKind::Video as i32,
        duration_value: ms,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        codec: "avc1".into(),
        ..Default::default()
    };
    let t = changed(run(
        engine,
        command::Kind::ImportMedia(ImportMedia { items: vec![item] }),
    ));
    let track = &t.tracks[0];
    let clip = track.clips.iter().map(|c| c.id).max().expect("a clip");
    Placed {
        clip,
        track: track.id,
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

fn to_playhead(clip_id: u64, edge: ClipEdge) -> command::Kind {
    command::Kind::TrimToPlayhead(TrimToPlayhead {
        clip_id,
        edge: edge as i32,
    })
}

/// Moves a clip to `start` on its own track, without snapping.
fn move_to(engine: &mut Engine, p: Placed, start: i64) {
    changed(run(
        engine,
        command::Kind::SnapMove(SnapMove {
            clip_id: p.clip,
            track_id: p.track,
            start,
            snap_within: 0,
        }),
    ));
}

fn seek(engine: &mut Engine, time: i64) {
    run(
        engine,
        command::Kind::Seek(Seek {
            time,
            snap_within: 0,
        }),
    );
}

/// (start, end, source_start) of `clip`.
fn span(t: &TimelineChanged, clip: u64) -> (i64, i64, i64) {
    let c = t
        .tracks
        .iter()
        .flat_map(|t| &t.clips)
        .find(|c| c.id == clip)
        .expect("clip on the timeline");
    (c.start, c.start + c.duration, c.source_start)
}

#[test]
fn a_snap_trim_end_past_the_media_stops_at_its_end() {
    let mut engine = Engine::default();
    let a = import(&mut engine, 1, 5000).clip;
    changed(run(&mut engine, trim(a, 0, 2 * S, 0)));
    let t = changed(run(&mut engine, trim(a, 0, 7 * S, 0)));
    assert_eq!(span(&t, a), (0, 5 * S, 0));
}

#[test]
fn a_snap_trim_start_before_the_media_stops_at_its_first_frame() {
    let mut engine = Engine::default();
    let a = import(&mut engine, 1, 5000);
    changed(run(&mut engine, trim(a.clip, S, 3 * S, 0)));
    // Now [4 s, 6 s) playing source 1 s..3 s: the media's first frame sits at 3 s.
    move_to(&mut engine, a, 4 * S);
    let t = changed(run(&mut engine, trim(a.clip, S, 6 * S, 0)));
    assert_eq!(span(&t, a.clip), (3 * S, 6 * S, 0));
}

#[test]
fn a_snap_point_past_the_media_end_is_no_snap() {
    let mut engine = Engine::default();
    let a = import(&mut engine, 1, 2500).clip;
    changed(run(&mut engine, trim(a, 0, 2 * S, 0)));
    let b = import(&mut engine, 2, 1000);
    move_to(&mut engine, b, 3 * S);
    // 2.95 s would snap to b's start (3 s), past a's media end (2.5 s): the edge stops at 2.5 s.
    let t = changed(run(&mut engine, trim(a, 0, 295 * S / 100, S / 10)));
    assert_eq!(span(&t, a), (0, 5 * S / 2, 0));
    assert!(!t.snapped, "the media end is no snap point");
}

#[test]
fn an_edge_inside_the_media_never_snaps_past_it() {
    let mut engine = Engine::default();
    let a = import(&mut engine, 1, 2500).clip;
    changed(run(&mut engine, trim(a, 0, 2 * S, 0)));
    let b = import(&mut engine, 2, 1000);
    move_to(&mut engine, b, 255 * S / 100);
    // 2.45 s is inside a's media; b's start (2.55 s) is near but past it: no snap at all.
    let t = changed(run(&mut engine, trim(a, 0, 245 * S / 100, S / 10)));
    assert_eq!(span(&t, a), (0, 245 * S / 100, 0));
    assert!(!t.snapped, "a snap point past the media is no target");
}

#[test]
fn trim_end_to_a_playhead_past_the_media_stops_at_its_end() {
    let mut engine = Engine::default();
    let a = import(&mut engine, 1, 2000).clip;
    changed(run(&mut engine, trim(a, 0, S, 0)));
    let b = import(&mut engine, 2, 2000);
    move_to(&mut engine, b, 4 * S);
    seek(&mut engine, 3 * S);
    let t = changed(run(&mut engine, to_playhead(a, ClipEdge::End)));
    assert_eq!(span(&t, a), (0, 2 * S, 0));
}

#[test]
fn trim_start_to_a_playhead_before_the_media_stops_at_its_first_frame() {
    let mut engine = Engine::default();
    let a = import(&mut engine, 1, 2000);
    changed(run(&mut engine, trim(a.clip, S, 2 * S, 0)));
    // Now [3 s, 4 s) playing source 1 s..2 s: the media's first frame sits at 2 s.
    move_to(&mut engine, a, 3 * S);
    seek(&mut engine, S);
    let t = changed(run(&mut engine, to_playhead(a.clip, ClipEdge::Start)));
    assert_eq!(span(&t, a.clip), (2 * S, 4 * S, 0));
}

const PAST_END: &str = "clip runs past the end of its media";
const NEGATIVE: &str = "clip start and source offset must not be negative";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(64))]

    /// A snapped trim of a video never leaves its media and never fails for a source reason.
    #[test]
    fn a_snap_trim_stays_inside_the_media(
        start in 0..8 * S,
        end in 0..10 * S,
        within in 0..2 * S,
    ) {
        let mut engine = Engine::default();
        let a = import(&mut engine, 1, 5000);
        changed(run(&mut engine, trim(a.clip, S, 3 * S, 0)));
        // [2 s, 4 s) playing source 1 s..3 s: the media spans 1 s..6 s on the timeline.
        move_to(&mut engine, a, 2 * S);
        match run(&mut engine, trim(a.clip, start, end, within)) {
            Some(event::Kind::TimelineChanged(t)) => {
                let (s, e, src) = span(&t, a.clip);
                prop_assert!(src >= 0 && src + (e - s) <= 5 * S, "{:?}", (s, e, src));
            }
            Some(event::Kind::CommandFailed(f)) => {
                prop_assert!(
                    !f.reason.contains(PAST_END) && !f.reason.contains(NEGATIVE),
                    "{}",
                    f.reason
                );
            }
            other => prop_assert!(false, "unexpected {other:?}"),
        }
    }
}
