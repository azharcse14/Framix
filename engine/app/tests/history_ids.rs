mod common;

use framix_app::history::History;
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TimelineError, TrackKind};

fn place(start: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(0),
        start: Time(start),
        duration: Time(10),
    }
}

#[test]
fn ids_are_not_reused_after_undo() {
    let mut tl = Timeline::default();
    common::register(&mut tl, &[1]);
    let mut h = History::new(tl);
    let track = h
        .apply(|tl| Ok::<_, TimelineError>(tl.add_track(TrackKind::Video)))
        .unwrap();
    let first = h.apply(|tl| tl.insert_clip(track, place(0))).unwrap();
    assert!(h.undo());
    let second = h.apply(|tl| tl.insert_clip(track, place(100))).unwrap();
    assert_ne!(first, second);

    assert!(h.undo());
    assert!(h.undo());
    let new_track = h
        .apply(|tl| Ok::<_, TimelineError>(tl.add_track(TrackKind::Audio)))
        .unwrap();
    assert_ne!(new_track, track);
}
