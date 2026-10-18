use framix_core::aspect::AspectRatio;
use framix_core::timeline::Timeline;

fn sides(a: AspectRatio) -> (u32, u32) {
    (a.width(), a.height())
}

#[test]
fn ratios_are_stored_reduced() {
    assert_eq!(AspectRatio::new(18, 32).map(sides), Some((9, 16)));
    assert_eq!(AspectRatio::new(21, 9).map(sides), Some((7, 3)));
    assert_eq!(AspectRatio::new(1, 1).map(sides), Some((1, 1)));
}

#[test]
fn the_six_presets_are_valid() {
    for (w, h) in [(9, 16), (16, 9), (1, 1), (4, 5), (3, 4), (21, 9)] {
        assert!(AspectRatio::new(w, h).is_some(), "{w}:{h}");
    }
}

#[test]
fn zero_huge_and_extreme_ratios_are_refused() {
    for (w, h) in [(0, 1), (1, 0), (0, 0), (101, 100), (4, 1), (1, 4)] {
        assert!(AspectRatio::new(w, h).is_none(), "{w}:{h}");
    }
}

#[test]
fn the_default_is_portrait() {
    assert_eq!(sides(AspectRatio::default()), (9, 16));
    assert_eq!(sides(Timeline::default().aspect()), (9, 16));
}

#[test]
fn timelines_keep_and_compare_their_aspect() {
    let mut t = Timeline::default();
    t.set_aspect(AspectRatio::new(16, 9).unwrap());
    assert_eq!(sides(t.aspect()), (16, 9));
    assert_ne!(t, Timeline::default());
}
