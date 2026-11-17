use framix_core::time::{Rate, TICKS_PER_SECOND, Time};
use proptest::prelude::*;

const COMMON: [(u32, u32); 12] = [
    (24, 1),
    (25, 1),
    (30, 1),
    (50, 1),
    (60, 1),
    (120, 1),
    (24000, 1001),
    (30000, 1001),
    (60000, 1001),
    (44100, 1),
    (48000, 1),
    (96000, 1),
];

fn rate(num: u32, den: u32) -> Rate {
    Rate::new(num, den).unwrap()
}

#[test]
fn zero_parts_are_rejected() {
    assert_eq!(Rate::new(0, 1), None);
    assert_eq!(Rate::new(30, 0), None);
}

#[test]
fn common_rates_are_exact() {
    for (num, den) in COMMON {
        let r = rate(num, den);
        let one_second = r.frame_to_time(i64::from(num)).unwrap();
        assert_eq!(
            one_second,
            Time(TICKS_PER_SECOND * i64::from(den)),
            "{num}/{den}"
        );
    }
    assert_eq!(rate(30000, 1001).frame_to_time(1), Some(Time(23_543_520)));
}

#[test]
fn negative_time_floors_to_previous_frame() {
    assert_eq!(rate(30, 1).time_to_frame(Time(-1)), Some(-1));
}

#[test]
fn overflow_is_none() {
    assert_eq!(rate(1, 1).frame_to_time(i64::MAX), None);
    // ENG-047: a rate this fast is rejected, and no accepted rate has a frame shorter than a
    // tick, so time_to_frame cannot overflow even at the fastest accepted rate.
    assert_eq!(Rate::new(u32::MAX, 1), None);
    assert_eq!(
        rate(705_600_000, 1).time_to_frame(Time(i64::MAX)),
        Some(i64::MAX)
    );
}

#[test]
fn frames_shorter_than_a_tick_are_rejected() {
    // ENG-047: media headers are untrusted; a frame under one tick breaks the round-trip.
    let max = u32::try_from(TICKS_PER_SECOND).unwrap();
    assert!(Rate::new(max, 1).is_some());
    assert_eq!(Rate::new(max + 1, 1), None);
    assert!(Rate::new(2 * max, 2).is_some());
    assert_eq!(Rate::new(2 * max + 1, 2), None);
    assert!(Rate::new(u32::MAX, 7).is_some());
    assert_eq!(Rate::new(u32::MAX, 6), None);
}

#[test]
fn whole_caps_at_one_frame_per_tick() {
    let max = u32::try_from(TICKS_PER_SECOND).unwrap();
    assert_eq!(Rate::whole(u32::MAX), rate(max, 1));
}

fn any_rate() -> impl Strategy<Value = Rate> {
    prop_oneof![
        proptest::sample::select(COMMON.to_vec()).prop_map(|(n, d)| rate(n, d)),
        (1u32..=192_000, 1u32..=1001).prop_map(|(n, d)| rate(n, d)),
    ]
}

/// Any (num, den), with small denominators weighted so the 1-tick boundary is hit often.
fn any_parts() -> impl Strategy<Value = (u32, u32)> {
    prop_oneof![(any::<u32>(), 1u32..=7), (any::<u32>(), any::<u32>())]
}

/// An accepted rate and a frame whose start fits in [`Time`], so no input is filtered out
/// (filtering random i64 frames rejects too many and proptest aborts).
fn accepted_rate_and_frame() -> impl Strategy<Value = (Rate, i64)> {
    any_parts()
        .prop_filter_map("rejected rate", |(num, den)| {
            let r = Rate::new(num, den)?;
            // Last frame whose start fits: i64::MAX * num / (den * TICKS_PER_SECOND).
            let ticks_per_frame_num = i128::from(den) * i128::from(TICKS_PER_SECOND);
            let max = i128::from(i64::MAX) * i128::from(num) / ticks_per_frame_num;
            Some((r, i64::try_from(max).unwrap_or(i64::MAX)))
        })
        .prop_flat_map(|(r, max)| (Just(r), -max..=max))
}

proptest! {
    /// ENG-047: `new` accepts exactly the rates whose frame is at least one tick long.
    #[test]
    fn new_accepts_only_frames_of_at_least_a_tick((num, den) in any_parts()) {
        let fits = num != 0 && den != 0 && i64::from(num) <= i64::from(den) * TICKS_PER_SECOND;
        prop_assert_eq!(Rate::new(num, den).is_some(), fits);
    }

    /// ENG-047: every accepted rate round-trips frame -> time -> frame.
    #[test]
    fn every_accepted_rate_round_trips((r, frame) in accepted_rate_and_frame()) {
        let t = r.frame_to_time(frame);
        prop_assume!(t.is_some());
        prop_assert_eq!(r.time_to_frame(t.unwrap()), Some(frame));
    }

    #[test]
    fn frame_time_round_trips(r in any_rate(), frame in -1_000_000_000i64..1_000_000_000) {
        // Slow rates (e.g. 1/14 fps) push far frames past i64 ticks; those correctly give
        // None (see overflow_is_none), so the property covers representable frames only.
        let t = r.frame_to_time(frame);
        prop_assume!(t.is_some());
        prop_assert_eq!(r.time_to_frame(t.unwrap()), Some(frame));
    }

    #[test]
    fn frame_starts_strictly_increase(r in any_rate(), frame in -1_000_000_000i64..1_000_000_000) {
        let (this, next) = (r.frame_to_time(frame), r.frame_to_time(frame + 1));
        prop_assume!(this.is_some() && next.is_some());
        prop_assert!(next.unwrap() > this.unwrap());
    }

    #[test]
    fn time_falls_inside_its_frame(r in any_rate(), ticks in -(1i64 << 50)..(1i64 << 50)) {
        let f = r.time_to_frame(Time(ticks)).unwrap();
        prop_assert!(r.frame_to_time(f).unwrap() <= Time(ticks));
        prop_assert!(Time(ticks) < r.frame_to_time(f + 1).unwrap());
    }
}
