//! P1-019 review: self-skip on both sides, touching edges, and a model-based proptest.
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TimelineError, TrackKind};
use proptest::prelude::*;

fn place(start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(0),
        start: Time(start),
        duration: Time(duration),
    }
}

#[test]
fn small_moves_both_ways_and_touching_edges() {
    let mut tl = Timeline::default();
    let t = tl.add_track(TrackKind::Video);
    let a = tl.insert_clip(t, place(0, 10)).unwrap();
    let b = tl.insert_clip(t, place(20, 10)).unwrap();
    tl.move_clip(b, t, Time(25)).unwrap(); // right, over its own old spot
    tl.move_clip(b, t, Time(22)).unwrap(); // left, over its own old spot
    tl.move_clip(a, t, Time(12)).unwrap(); // touches b's start exactly
    assert_eq!(tl.move_clip(b, t, Time(5)), Err(TimelineError::Overlap(a)));
    tl.move_clip(b, t, Time(0)).unwrap(); // ends exactly where a starts
}

proptest! {
    #[test]
    fn moves_match_a_free_span_model_and_can_be_undone(
        clips in proptest::collection::vec((0i64..200, 1i64..30), 1..8),
        pick in 0usize..8,
        to in -10i64..260,
    ) {
        let mut tl = Timeline::default();
        let t = tl.add_track(TrackKind::Video);
        let mut ids = Vec::new();
        for (start, dur) in clips {
            if let Ok(id) = tl.insert_clip(t, place(start, dur)) {
                ids.push(id);
            }
        }
        let id = ids[pick % ids.len()];
        let track = tl.track(t).unwrap();
        let moving = *track.clips().iter().find(|c| c.id == id).unwrap();
        let (from, dur) = (moving.start.0, moving.duration.0);
        let free = to >= 0
            && track
                .clips()
                .iter()
                .filter(|c| c.id != id)
                .all(|c| to + dur <= c.start.0 || c.end().0 <= to);
        let before = tl.clone();

        let moved = tl.move_clip(id, t, Time(to));
        prop_assert_eq!(moved.is_ok(), free);
        let clips = tl.track(t).unwrap().clips();
        for w in clips.windows(2) {
            prop_assert!(w[0].end() <= w[1].start);
        }
        if moved.is_ok() {
            tl.move_clip(id, t, Time(from)).unwrap();
        }
        prop_assert_eq!(tl, before);
    }
}
