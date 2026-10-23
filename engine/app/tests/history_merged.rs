//! Edits of one gesture make one undo step (P1-030).

use framix_app::history::History;
use framix_core::aspect::AspectRatio;
use framix_core::timeline::Timeline;

fn set(history: &mut History, w: u32, h: u32, key: Option<u64>) {
    let aspect = AspectRatio::new(w, h).unwrap();
    let edit = |tl: &mut Timeline| {
        tl.set_aspect(aspect);
        Ok::<_, ()>(())
    };
    match key {
        Some(key) => history.apply_merged(key, edit).unwrap(),
        None => history.apply(edit).unwrap(),
    }
}

fn aspect(history: &History) -> (u32, u32) {
    let a = history.timeline().aspect();
    (a.width(), a.height())
}

#[test]
fn one_gesture_is_one_step() {
    let mut h = History::default();
    let start = aspect(&h);
    set(&mut h, 1, 1, Some(7));
    set(&mut h, 4, 5, Some(7));
    set(&mut h, 16, 9, Some(7));
    assert!(h.undo());
    assert_eq!(aspect(&h), start);
    assert!(!h.can_undo());
}

#[test]
fn another_key_a_plain_edit_or_an_undo_ends_the_run() {
    let mut h = History::default();
    set(&mut h, 1, 1, Some(7));
    set(&mut h, 4, 5, Some(8));
    assert!(h.undo());
    assert_eq!(aspect(&h), (1, 1), "a new key is a new step");

    set(&mut h, 16, 9, Some(8));
    set(&mut h, 3, 4, None);
    set(&mut h, 21, 9, Some(8));
    assert!(h.undo());
    assert_eq!(aspect(&h), (3, 4), "a plain edit ended the run");

    // After an undo the same key starts a fresh step.
    set(&mut h, 2, 3, Some(8));
    assert!(h.undo());
    assert_eq!(aspect(&h), (3, 4));
}
