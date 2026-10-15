//! P1-018 review: an edit that leaves the timeline unchanged is not an undo step.
use framix_app::history::History;
use framix_core::timeline::{Timeline, TimelineError, TrackKind};

#[test]
fn no_op_edits_keep_undo_and_redo() {
    let mut h = History::new(Timeline::default());
    h.apply(|tl| Ok::<_, TimelineError>(tl.add_track(TrackKind::Video)))
        .unwrap();
    h.apply(|tl| Ok::<_, TimelineError>(tl.add_track(TrackKind::Audio)))
        .unwrap();
    assert!(h.undo());
    h.apply(|_| Ok::<_, TimelineError>(())).unwrap();
    assert!(h.can_redo(), "a no-op edit must not drop redo");
    assert!(h.undo());
    assert!(!h.can_undo(), "a no-op edit must not add an undo step");
}
