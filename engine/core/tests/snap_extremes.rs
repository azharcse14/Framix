//! Snap with untrusted extreme times must not overflow (P1-022 review).

use framix_core::time::Time;
use framix_core::timeline::Timeline;

#[test]
fn extreme_times_do_not_overflow() {
    let tl = Timeline::default();
    assert_eq!(tl.snap(Time(i64::MIN), Time(1)), None);
    assert_eq!(tl.snap(Time(i64::MAX), Time(1)), None);
    assert_eq!(tl.snap(Time(i64::MIN), Time(i64::MAX)), Some(Time(0)));
}
