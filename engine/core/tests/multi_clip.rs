//! Edits on several clips at once (P1-024): remove, move and duplicate a selection.

use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, MediaId, Timeline, TimelineError, TrackFlags, TrackId, TrackKind,
};
use proptest::prelude::*;

fn place(start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(5),
        start: Time(start),
        duration: Time(duration),
    }
}

/// (id, start) of each clip on `t`.
fn starts(tl: &Timeline, t: TrackId) -> Vec<(ClipId, i64)> {
    tl.track(t)
        .unwrap()
        .clips()
        .iter()
        .map(|c| (c.id, c.start.0))
        .collect()
}

/// Two video tracks: v1 has a [0,10) b [10,20) c [40,50); v2 has d [5,15).
fn sample() -> (Timeline, TrackId, TrackId, [ClipId; 4]) {
    let mut tl = Timeline::default();
    let v1 = tl.add_track(TrackKind::Video);
    let v2 = tl.add_track(TrackKind::Video);
    let a = tl.insert_clip(v1, place(0, 10)).unwrap();
    let b = tl.insert_clip(v1, place(10, 10)).unwrap();
    let c = tl.insert_clip(v1, place(40, 10)).unwrap();
    let d = tl.insert_clip(v2, place(5, 10)).unwrap();
    (tl, v1, v2, [a, b, c, d])
}

#[test]
fn remove_clips_removes_every_listed_clip() {
    let (mut tl, v1, v2, [a, b, c, d]) = sample();
    tl.remove_clips(&[a, d, c]).unwrap();
    assert_eq!(starts(&tl, v1), [(b, 10)]);
    assert!(starts(&tl, v2).is_empty());
}

#[test]
fn move_clips_shifts_neighbours_onto_each_others_spots() {
    let (mut tl, v1, v2, [a, b, c, d]) = sample();
    // Right by 10: b lands where nothing is, a lands on b's old spot.
    tl.move_clips(&[a, b, d], Time(10)).unwrap();
    assert_eq!(starts(&tl, v1), [(a, 10), (b, 20), (c, 40)]);
    assert_eq!(starts(&tl, v2), [(d, 15)]);
    // Left by 10: back again, a first so b can take a's old spot.
    tl.move_clips(&[b, a, d], Time(-10)).unwrap();
    assert_eq!(starts(&tl, v1), [(a, 0), (b, 10), (c, 40)]);
    assert_eq!(starts(&tl, v2), [(d, 5)]);
}

#[test]
fn duplicate_clips_copies_the_selection_as_a_block_after_it() {
    let (mut tl, v1, v2, [a, b, _, d]) = sample();
    // The selection spans [0, 20); the copies start 20 later, each on its own track.
    let copies = tl.duplicate_clips(&[a, b, d]).unwrap();
    assert_eq!(copies.len(), 3);
    let v1_clips = starts(&tl, v1);
    assert_eq!(
        v1_clips.iter().map(|(_, s)| *s).collect::<Vec<_>>(),
        [0, 10, 20, 30, 40]
    );
    assert_eq!(
        starts(&tl, v2).iter().map(|(_, s)| *s).collect::<Vec<_>>(),
        [5, 25]
    );
    for copy in &copies {
        let clip = tl.clip(*copy).unwrap();
        assert_eq!((clip.duration.0, clip.source_start.0), (10, 5));
    }
}

#[test]
fn refused_edits_change_nothing() {
    let (tl, v1, _, [a, b, c, d]) = sample();
    let refusals: [(
        &str,
        fn(&mut Timeline, &[ClipId]) -> Result<(), TimelineError>,
        Vec<ClipId>,
        TimelineError,
    ); 9] = [
        (
            "empty remove",
            |t, ids| t.remove_clips(ids),
            vec![],
            TimelineError::EmptySelection,
        ),
        (
            "repeated remove",
            |t, ids| t.remove_clips(ids),
            vec![a, b, a],
            TimelineError::RepeatedClip(a),
        ),
        (
            "unknown remove",
            |t, ids| t.remove_clips(ids),
            vec![a, ClipId(99)],
            TimelineError::UnknownClip(ClipId(99)),
        ),
        (
            "empty move",
            |t, ids| t.move_clips(ids, Time(1)),
            vec![],
            TimelineError::EmptySelection,
        ),
        (
            "repeated move",
            |t, ids| t.move_clips(ids, Time(1)),
            vec![d, d],
            TimelineError::RepeatedClip(d),
        ),
        // b would run into c.
        (
            "overlap move",
            |t, ids| t.move_clips(ids, Time(25)),
            vec![a, b],
            TimelineError::Overlap(c),
        ),
        (
            "negative move",
            |t, ids| t.move_clips(ids, Time(-6)),
            vec![b, d],
            TimelineError::NegativeTime,
        ),
        (
            "empty duplicate",
            |t, ids| t.duplicate_clips(ids).map(drop),
            vec![],
            TimelineError::EmptySelection,
        ),
        // Copies of a and d (block [0,15)) land at [15,25) and [20,30): v1's b at [10,20) is in the way.
        (
            "overlap duplicate",
            |t, ids| t.duplicate_clips(ids).map(drop),
            vec![a, d],
            TimelineError::Overlap(b),
        ),
    ];
    for (name, edit, ids, error) in refusals {
        let mut edited = tl.clone();
        assert_eq!(edit(&mut edited, &ids), Err(error), "{name}");
        assert_eq!(edited, tl, "{name} changed nothing");
        assert_eq!(starts(&edited, v1), starts(&tl, v1), "{name}");
    }
}

#[test]
fn a_locked_track_refuses_the_whole_edit() {
    let (mut tl, _, v2, [a, _, _, d]) = sample();
    tl.set_track_flags(
        v2,
        TrackFlags {
            locked: true,
            ..TrackFlags::default()
        },
    )
    .unwrap();
    let before = tl.clone();
    assert_eq!(
        tl.remove_clips(&[a, d]),
        Err(TimelineError::TrackLocked(v2))
    );
    assert_eq!(
        tl.move_clips(&[a, d], Time(100)),
        Err(TimelineError::TrackLocked(v2))
    );
    assert_eq!(
        tl.duplicate_clips(&[a, d]),
        Err(TimelineError::TrackLocked(v2))
    );
    assert_eq!(tl, before);
}

proptest! {
    /// Moving a selection by `by` and back by `-by` restores the timeline (when the move fits).
    #[test]
    fn move_then_move_back_restores(by in -60i64..60, pick in 1usize..16) {
        let (tl, _, _, ids) = sample();
        let chosen: Vec<ClipId> = ids
            .iter()
            .enumerate()
            .filter(|(i, _)| pick & (1 << i) != 0)
            .map(|(_, id)| *id)
            .collect();
        let mut moved = tl.clone();
        if moved.move_clips(&chosen, Time(by)).is_ok() {
            moved.move_clips(&chosen, Time(-by)).unwrap();
            prop_assert_eq!(moved, tl);
        } else {
            prop_assert_eq!(moved, tl);
        }
    }
}
