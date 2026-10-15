use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TimelineError, TrackKind};
use proptest::prelude::*;

fn place(source_start: i64, start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(source_start),
        start: Time(start),
        duration: Time(duration),
    }
}

#[test]
fn negative_times_are_rejected() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    assert_eq!(
        tl.insert_clip(t, place(0, -100, 50)),
        Err(TimelineError::NegativeTime)
    );
    assert_eq!(
        tl.insert_clip(t, place(-1, 0, 50)),
        Err(TimelineError::NegativeTime)
    );
    assert_eq!(tl.duration(), Time(0));
}

proptest! {
    #[test]
    fn insert_succeeds_exactly_when_valid(
        ops in proptest::collection::vec((-50i64..50, -200i64..1_000, -10i64..200), 0..60),
    ) {
        let mut tl = Timeline::default();
        let t = tl.add_track(TrackKind::Video);
        let mut placed: Vec<(i64, i64)> = Vec::new();
        for (source_start, start, duration) in ops {
            let before = tl.clone();
            let result = tl.insert_clip(t, place(source_start, start, duration));
            let end = start + duration;
            let valid = source_start >= 0
                && start >= 0
                && duration > 0
                && placed.iter().all(|&(s, e)| end <= s || e <= start);
            prop_assert_eq!(result.is_ok(), valid);
            if valid {
                placed.push((start, end));
            } else {
                prop_assert_eq!(&tl, &before);
            }
            prop_assert!(tl.duration() >= Time(0));
        }
    }
}
