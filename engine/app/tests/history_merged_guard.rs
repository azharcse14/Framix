//! A gesture never merges into a step it did not make; undo/redo keep its end state (P1-030
//! review).

use framix_app::history::History;
use framix_core::aspect::AspectRatio;
use framix_core::timeline::Timeline;

fn set(h: &mut History, w: u32, hgt: u32, key: Option<u64>) {
    let aspect = AspectRatio::new(w, hgt).unwrap();
    let edit = |tl: &mut Timeline| {
        tl.set_aspect(aspect);
        Ok::<_, ()>(())
    };
    match key {
        Some(key) => h.apply_merged(key, edit).unwrap(),
        None => h.apply(edit).unwrap(),
    }
}

fn aspect(h: &History) -> (u32, u32) {
    let a = h.timeline().aspect();
    (a.width(), a.height())
}

#[test]
fn a_no_op_gesture_start_does_not_take_over_the_previous_step() {
    let mut h = History::default();
    set(&mut h, 1, 1, None);
    // Same value: no step, so the gesture has not made one yet.
    set(&mut h, 1, 1, Some(7));
    set(&mut h, 16, 9, Some(7));
    assert!(h.undo());
    assert_eq!(aspect(&h), (1, 1), "the plain edit's step is intact");
}

#[test]
fn undo_then_redo_restores_the_end_of_the_gesture() {
    let mut h = History::default();
    set(&mut h, 1, 1, Some(9));
    set(&mut h, 4, 5, Some(9));
    assert!(h.undo());
    assert!(h.redo());
    assert_eq!(aspect(&h), (4, 5));
}
