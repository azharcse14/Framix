//! P1-018 review: overflow paths and cross-track merges.
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TimelineError, TrackKind};

fn place(source_start: i64, start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(source_start),
        start: Time(start),
        duration: Time(duration),
    }
}

#[test]
fn overflowing_source_or_end_is_refused() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let c = tl.insert_clip(t, place(i64::MAX - 5, 0, 100)).unwrap();
    assert_eq!(tl.split_clip(c, Time(50)), Err(TimelineError::TimeOverflow));
    assert_eq!(
        tl.trim_clip(c, Time(50), Time(100)),
        Err(TimelineError::TimeOverflow)
    );

    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let c = tl.insert_clip(t, place(0, i64::MAX - 100, 60)).unwrap();
    assert_eq!(tl.duplicate_clip(c), Err(TimelineError::TimeOverflow));
}

#[test]
fn clips_on_different_tracks_never_merge() {
    let mut tl = Timeline::default();
    let a = tl.add_track(TrackKind::Video);
    let b = tl.add_track(TrackKind::Video);
    let left = tl.insert_clip(a, place(0, 0, 10)).unwrap();
    let right = tl.insert_clip(b, place(10, 10, 10)).unwrap();
    assert_eq!(
        tl.merge_clips(left, right),
        Err(TimelineError::NotMergeable)
    );
}
