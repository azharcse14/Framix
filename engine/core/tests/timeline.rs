use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, MediaId, Timeline, TimelineError, TrackId, TrackKind,
};
use proptest::prelude::*;

fn place(start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(0),
        start: Time(start),
        duration: Time(duration),
    }
}

fn starts(tl: &Timeline, track: TrackId) -> Vec<i64> {
    tl.track(track)
        .unwrap()
        .clips()
        .iter()
        .map(|c| c.start.0)
        .collect()
}

#[test]
fn tracks_get_distinct_ids_and_keep_kind() {
    let mut tl = Timeline::default();
    let v = tl.add_track(TrackKind::Video);
    let a = tl.add_track(TrackKind::Audio);
    assert_ne!(v, a);
    assert_eq!(tl.tracks().len(), 2);
    assert_eq!(tl.track(a).unwrap().kind(), TrackKind::Audio);
}

#[test]
fn clips_stay_sorted_and_get_distinct_ids() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let c1 = tl.insert_clip(t, place(200, 100)).unwrap();
    let c2 = tl.insert_clip(t, place(0, 100)).unwrap();
    let c3 = tl.insert_clip(t, place(100, 100)).unwrap();
    assert_eq!(starts(&tl, t), vec![0, 100, 200]);
    assert!(c1 != c2 && c2 != c3 && c1 != c3);
}

#[test]
fn overlapping_clip_is_rejected_and_timeline_unchanged() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let first = tl.insert_clip(t, place(100, 100)).unwrap();
    let before = tl.clone();
    assert_eq!(
        tl.insert_clip(t, place(150, 10)),
        Err(TimelineError::Overlap(first))
    );
    assert_eq!(
        tl.insert_clip(t, place(50, 51)),
        Err(TimelineError::Overlap(first))
    );
    assert_eq!(tl, before);
}

#[test]
fn touching_clips_are_allowed() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    tl.insert_clip(t, place(100, 100)).unwrap();
    tl.insert_clip(t, place(0, 100)).unwrap();
    tl.insert_clip(t, place(200, 1)).unwrap();
    assert_eq!(starts(&tl, t), vec![0, 100, 200]);
}

#[test]
fn bad_clips_are_rejected() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    assert_eq!(
        tl.insert_clip(t, place(0, 0)),
        Err(TimelineError::NonPositiveDuration)
    );
    assert_eq!(
        tl.insert_clip(t, place(0, -5)),
        Err(TimelineError::NonPositiveDuration)
    );
    assert_eq!(
        tl.insert_clip(t, place(i64::MAX, 1)),
        Err(TimelineError::TimeOverflow)
    );
    assert_eq!(
        tl.insert_clip(TrackId(999), place(0, 1)),
        Err(TimelineError::UnknownTrack(TrackId(999)))
    );
}

#[test]
fn tracks_are_independent() {
    let mut tl = Timeline::default();
    let v = tl.add_track(TrackKind::Video);
    let a = tl.add_track(TrackKind::Audio);
    tl.insert_clip(v, place(0, 100)).unwrap();
    tl.insert_clip(a, place(0, 100)).unwrap();
    assert_eq!(starts(&tl, a), vec![0]);
}

#[test]
fn clip_at_uses_half_open_ranges() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let a = tl.insert_clip(t, place(0, 100)).unwrap();
    let b = tl.insert_clip(t, place(100, 50)).unwrap();
    let track = tl.track(t).unwrap();
    let at = |x| track.clip_at(Time(x)).map(|c| c.id);
    assert_eq!(at(0), Some(a));
    assert_eq!(at(99), Some(a));
    assert_eq!(at(100), Some(b));
    assert_eq!(at(150), None);
    assert_eq!(at(-1), None);
}

#[test]
fn duration_is_latest_clip_end() {
    let mut tl = Timeline::default();
    assert_eq!(tl.duration(), Time(0));
    let v = tl.add_track(TrackKind::Video);
    let a = tl.add_track(TrackKind::Audio);
    tl.insert_clip(v, place(0, 100)).unwrap();
    tl.insert_clip(a, place(50, 300)).unwrap();
    assert_eq!(tl.duration(), Time(350));
}

proptest! {
    #[test]
    fn random_inserts_keep_track_invariants(
        ops in proptest::collection::vec((-1_000i64..1_000, -10i64..200), 0..60),
        probe in -1_200i64..1_400,
    ) {
        let mut tl = Timeline::default();
        let t = tl.add_track(TrackKind::Video);
        for (start, duration) in ops {
            let _ = tl.insert_clip(t, place(start, duration));
        }
        let clips = tl.track(t).unwrap().clips();
        for c in clips {
            prop_assert!(c.duration.0 > 0);
        }
        for pair in clips.windows(2) {
            prop_assert!(pair[0].end() <= pair[1].start);
        }
        let linear = clips.iter().find(|c| c.start.0 <= probe && probe < c.end().0).map(|c| c.id);
        let found: Option<ClipId> = tl.track(t).unwrap().clip_at(Time(probe)).map(|c| c.id);
        prop_assert_eq!(found, linear);
    }
}
