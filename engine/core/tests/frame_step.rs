//! Frame-by-frame nudge (P1-025): step from the frame showing at a time to the start of a
//! frame `n` frames away.

use framix_core::time::{Rate, TICKS_PER_SECOND, Time};
use proptest::prelude::*;

const S: i64 = TICKS_PER_SECOND;

#[test]
fn steps_land_on_frame_starts() {
    let r = Rate::whole(30);
    let frame = S / 30;
    assert_eq!(r.step(Time(0), 1), Some(Time(frame)));
    assert_eq!(r.step(Time(frame), -1), Some(Time(0)));
    // From inside a frame: forward to the next frame, back to the one before it.
    assert_eq!(r.step(Time(frame + 7), 1), Some(Time(2 * frame)));
    assert_eq!(r.step(Time(frame + 7), -1), Some(Time(0)));
    assert_eq!(r.step(Time(0), 30), Some(Time(S)));
    assert_eq!(r.step(Time(0), 0), Some(Time(0)));
}

#[test]
fn ntsc_frames_round_trip() {
    let r = Rate::new(30_000, 1001).unwrap();
    let t = r.step(Time(0), 3).unwrap();
    assert_eq!(r.time_to_frame(t), Some(3));
    assert_eq!(r.step(t, -3), Some(Time(0)));
}

#[test]
fn far_steps_do_not_overflow() {
    let r = Rate::whole(60);
    assert_eq!(r.step(Time(i64::MAX), i64::MAX), None);
    assert_eq!(r.step(Time(0), i64::MIN), None);
}

proptest! {
    /// A step lands on a frame start, n frames from the frame showing at `t`.
    #[test]
    fn a_step_moves_exactly_n_frames(t in 0i64..3600 * S, n in -1000i64..1000, fps in 1u32..=120) {
        let r = Rate::whole(fps);
        let to = r.step(Time(t), n).unwrap();
        let from = r.time_to_frame(Time(t)).unwrap();
        prop_assert_eq!(r.time_to_frame(to), Some(from + n));
        prop_assert_eq!(r.frame_to_time(from + n), Some(to));
    }
}
