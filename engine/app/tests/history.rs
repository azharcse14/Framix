use framix_app::history::History;
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

fn with_track() -> History {
    let mut h = History::default();
    h.apply(|tl| Ok::<_, TimelineError>(tl.add_track(TrackKind::Video)))
        .unwrap();
    h
}

fn insert(h: &mut History, start: i64, duration: i64) -> Result<(), TimelineError> {
    let track = h.timeline().tracks()[0].id();
    h.apply(|tl| tl.insert_clip(track, place(start, duration)).map(|_| ()))
}

#[test]
fn undo_restores_and_redo_reapplies() {
    let mut h = with_track();
    let before = h.timeline().clone();
    insert(&mut h, 0, 100).unwrap();
    let after = h.timeline().clone();

    assert!(h.undo());
    assert_eq!(h.timeline(), &before);
    assert!(h.redo());
    assert_eq!(h.timeline(), &after);
}

#[test]
fn failed_edit_leaves_no_step() {
    let mut h = with_track();
    insert(&mut h, 0, 100).unwrap();
    let state = h.timeline().clone();
    assert!(insert(&mut h, 50, 100).is_err());
    assert_eq!(h.timeline(), &state);
    assert!(h.undo());
    assert!(h.timeline().tracks()[0].clips().is_empty());
}

#[test]
fn edit_that_mutates_then_fails_is_rolled_back() {
    let mut h = with_track();
    let state = h.timeline().clone();
    let result: Result<(), &str> = h.apply(|tl| {
        tl.add_track(TrackKind::Audio);
        Err("later step failed")
    });
    assert!(result.is_err());
    assert_eq!(h.timeline(), &state);
}

#[test]
fn new_edit_after_undo_drops_redo() {
    let mut h = with_track();
    insert(&mut h, 0, 100).unwrap();
    assert!(h.undo());
    insert(&mut h, 200, 100).unwrap();
    assert!(!h.redo());
}

#[test]
fn empty_history_cannot_undo_or_redo() {
    let mut h = History::new(Timeline::default());
    assert!(!h.undo());
    assert!(!h.redo());
}

#[derive(Clone, Debug)]
enum Op {
    Insert(i64, i64),
    Undo,
    Redo,
}

fn op() -> impl Strategy<Value = Op> {
    prop_oneof![
        (0i64..500, -5i64..100).prop_map(|(s, d)| Op::Insert(s, d)),
        Just(Op::Undo),
        Just(Op::Redo),
    ]
}

proptest! {
    #[test]
    fn matches_a_linear_state_model(ops in proptest::collection::vec(op(), 0..80)) {
        let mut h = with_track();
        // Model: every committed state, and the index of the current one.
        let mut states = vec![h.timeline().clone()];
        let mut at = 0usize;
        for op in ops {
            match op {
                Op::Insert(s, d) => {
                    if insert(&mut h, s, d).is_ok() {
                        states.truncate(at + 1);
                        states.push(h.timeline().clone());
                        at += 1;
                    }
                }
                Op::Undo => {
                    prop_assert_eq!(h.undo(), at > 0);
                    at = at.saturating_sub(1);
                }
                Op::Redo => {
                    prop_assert_eq!(h.redo(), at + 1 < states.len());
                    at = (at + 1).min(states.len() - 1);
                }
            }
            prop_assert_eq!(h.timeline(), &states[at]);
        }
    }
}
