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
    assert_eq!(rate(u32::MAX, 1).time_to_frame(Time(i64::MAX)), None);
}

fn any_rate() -> impl Strategy<Value = Rate> {
    prop_oneof![
        proptest::sample::select(COMMON.to_vec()).prop_map(|(n, d)| rate(n, d)),
        (1u32..=192_000, 1u32..=1001).prop_map(|(n, d)| rate(n, d)),
    ]
}

proptest! {
    #[test]
    fn frame_time_round_trips(r in any_rate(), frame in -1_000_000_000i64..1_000_000_000) {
        let t = r.frame_to_time(frame).unwrap();
        prop_assert_eq!(r.time_to_frame(t), Some(frame));
    }

    #[test]
    fn frame_starts_strictly_increase(r in any_rate(), frame in -1_000_000_000i64..1_000_000_000) {
        prop_assert!(r.frame_to_time(frame + 1).unwrap() > r.frame_to_time(frame).unwrap());
    }

    #[test]
    fn time_falls_inside_its_frame(r in any_rate(), ticks in -(1i64 << 50)..(1i64 << 50)) {
        let f = r.time_to_frame(Time(ticks)).unwrap();
        prop_assert!(r.frame_to_time(f).unwrap() <= Time(ticks));
        prop_assert!(Time(ticks) < r.frame_to_time(f + 1).unwrap());
    }
}
