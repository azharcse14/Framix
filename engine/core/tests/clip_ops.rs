use framix_core::time::Time;
use framix_core::timeline::{
    Clip, ClipId, ClipPlacement, MediaId, Timeline, TimelineError, TrackId, TrackKind,
};
use proptest::prelude::*;

fn place(media: u64, source_start: i64, start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(media),
        source_start: Time(source_start),
        start: Time(start),
        duration: Time(duration),
    }
}

/// One video track holding one clip: media 1, source 10, timeline [0, 100).
fn one_clip() -> (Timeline, TrackId, ClipId) {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let c = tl.insert_clip(t, place(1, 10, 0, 100)).unwrap();
    (tl, t, c)
}

/// (media, source_start, start, duration) of every clip on `t`.
fn spans(tl: &Timeline, t: TrackId) -> Vec<(u64, i64, i64, i64)> {
    tl.track(t)
        .unwrap()
        .clips()
        .iter()
        .map(|c: &Clip| (c.media.0, c.source_start.0, c.start.0, c.duration.0))
        .collect()
}

#[test]
fn split_cuts_the_clip_and_shifts_the_right_source() {
    let (mut tl, t, c) = one_clip();
    let right = tl.split_clip(c, Time(40)).unwrap();
    assert_eq!(spans(&tl, t), [(1, 10, 0, 40), (1, 50, 40, 60)]);
    let ids: Vec<ClipId> = tl.track(t).unwrap().clips().iter().map(|c| c.id).collect();
    assert_eq!(ids, [c, right]);
    assert_ne!(right, c);
}

#[test]
fn split_points_on_or_outside_the_edges_are_refused() {
    let (mut tl, t, c) = one_clip();
    for at in [-5, 0, 100, 150] {
        assert_eq!(
            tl.split_clip(c, Time(at)),
            Err(TimelineError::SplitOutside),
            "{at}"
        );
    }
    assert_eq!(spans(&tl, t), [(1, 10, 0, 100)]);
    assert_eq!(
        tl.split_clip(ClipId(999), Time(40)),
        Err(TimelineError::UnknownClip(ClipId(999)))
    );
}

#[test]
fn merge_joins_neighbours_and_refuses_the_rest() {
    let (mut tl, t, c) = one_clip();
    let right = tl.split_clip(c, Time(40)).unwrap();
    tl.merge_clips(c, right).unwrap();
    assert_eq!(spans(&tl, t), [(1, 10, 0, 100)]);

    // Gap, other media, and a source jump are not mergeable.
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let a = tl.insert_clip(t, place(1, 0, 0, 10)).unwrap();
    let gap = tl.insert_clip(t, place(1, 10, 20, 10)).unwrap();
    let other = tl.insert_clip(t, place(2, 20, 30, 10)).unwrap();
    let jump = tl.insert_clip(t, place(2, 99, 40, 10)).unwrap();
    for (l, r) in [(a, gap), (gap, other), (other, jump), (gap, a)] {
        assert_eq!(tl.merge_clips(l, r), Err(TimelineError::NotMergeable));
    }
    assert_eq!(tl.track(t).unwrap().clips().len(), 4);
}

#[test]
fn remove_deletes_one_clip() {
    let (mut tl, t, c) = one_clip();
    let right = tl.split_clip(c, Time(40)).unwrap();
    tl.remove_clip(c).unwrap();
    assert_eq!(spans(&tl, t), [(1, 50, 40, 60)]);
    assert_eq!(tl.remove_clip(c), Err(TimelineError::UnknownClip(c)));
    tl.remove_clip(right).unwrap();
    assert!(spans(&tl, t).is_empty());
}

#[test]
fn trim_moves_edges_and_keeps_frames_in_place() {
    let (mut tl, t, c) = one_clip();
    tl.trim_clip(c, Time(20), Time(90)).unwrap();
    assert_eq!(
        spans(&tl, t),
        [(1, 30, 20, 70)],
        "head trim shifts the source by 20"
    );
    tl.trim_clip(c, Time(15), Time(120)).unwrap();
    assert_eq!(spans(&tl, t), [(1, 25, 15, 105)], "edges can grow back out");
}

#[test]
fn bad_trims_are_refused_and_change_nothing() {
    let (mut tl, t, c) = one_clip();
    let next = tl.insert_clip(t, place(1, 0, 150, 10)).unwrap();
    let cases = [
        (50, 50, TimelineError::NonPositiveDuration),
        (60, 40, TimelineError::NonPositiveDuration),
        (-20, 50, TimelineError::NegativeTime), // start below zero
        (0, 160, TimelineError::Overlap(next)),
    ];
    for (start, end, err) in cases {
        assert_eq!(
            tl.trim_clip(c, Time(start), Time(end)),
            Err(err),
            "{start}..{end}"
        );
    }
    // Source would go below zero: the clip's source starts at 10, so start -11 is too early.
    let mut tl2 = Timeline::default();
    let t2 = tl2.add_track(TrackKind::Video);
    let c2 = tl2.insert_clip(t2, place(1, 10, 50, 10)).unwrap();
    assert_eq!(
        tl2.trim_clip(c2, Time(39), Time(60)),
        Err(TimelineError::NegativeTime)
    );
    assert_eq!(spans(&tl, t), [(1, 10, 0, 100), (1, 0, 150, 10)]);
}

#[test]
fn duplicate_places_a_copy_right_after() {
    let (mut tl, t, c) = one_clip();
    let copy = tl.duplicate_clip(c).unwrap();
    assert_ne!(copy, c);
    assert_eq!(spans(&tl, t), [(1, 10, 0, 100), (1, 10, 100, 100)]);
    assert_eq!(tl.duplicate_clip(c), Err(TimelineError::Overlap(copy)));
}

proptest! {
    #[test]
    fn split_then_merge_restores_the_clip(
        source in 0i64..1_000, start in 0i64..1_000, duration in 2i64..1_000, cut in 1i64..1_000,
    ) {
        let cut = 1 + cut % (duration - 1);
        let mut tl = Timeline::default();
        let t = tl.add_track(TrackKind::Video);
        let c = tl.insert_clip(t, place(1, source, start, duration)).unwrap();
        let before = spans(&tl, t);
        let right = tl.split_clip(c, Time(start + cut)).unwrap();
        tl.merge_clips(c, right).unwrap();
        prop_assert_eq!(spans(&tl, t), before);
    }

    #[test]
    fn random_clip_ops_keep_track_invariants(
        ops in proptest::collection::vec((0u8..5, 0usize..8, -50i64..300, -50i64..300), 0..80),
    ) {
        let mut tl = Timeline::default();
        let t = tl.add_track(TrackKind::Video);
        let _ = tl.insert_clip(t, place(1, 0, 0, 100));
        for (op, pick, a, b) in ops {
            let ids: Vec<ClipId> = tl.track(t).unwrap().clips().iter().map(|c| c.id).collect();
            let Some(&id) = ids.get(pick % ids.len().max(1)) else { break };
            let _ = match op {
                0 => tl.split_clip(id, Time(a)).map(drop),
                1 => tl.trim_clip(id, Time(a), Time(b)),
                2 => tl.duplicate_clip(id).map(drop),
                3 => ids.get(pick % ids.len() + 1).map_or(Ok(()), |&r| tl.merge_clips(id, r)),
                _ => if ids.len() > 1 { tl.remove_clip(id) } else { Ok(()) },
            };
        }
        let clips = tl.track(t).unwrap().clips();
        for c in clips {
            prop_assert!(c.duration.0 > 0 && c.start.0 >= 0 && c.source_start.0 >= 0);
        }
        for w in clips.windows(2) {
            prop_assert!(w[0].end() <= w[1].start, "sorted, no overlap: {:?}", w);
        }
    }
}
