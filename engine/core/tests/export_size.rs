//! Estimated export size (P1-033).

use framix_core::aspect::AspectRatio;
use framix_core::export::{Bitrate, ExportSettings, Resolution};
use framix_core::time::{TICKS_PER_SECOND, Time};
use proptest::prelude::*;

const SECOND: i64 = TICKS_PER_SECOND;

fn portrait() -> AspectRatio {
    AspectRatio::new(9, 16).unwrap()
}

#[test]
fn an_empty_timeline_is_nothing() {
    assert_eq!(
        ExportSettings::default().estimated_bytes(portrait(), Time(0)),
        0
    );
}

#[test]
fn ten_seconds_of_1080p30_auto() {
    // Video 6220 kbps (1080 x 1920 x 30 / 10 / 1000) + audio 128 = 6348 kbps;
    // 6348 * 1000 / 8 * 10 s = 7_935_000 bytes; +1 % = 8_014_350.
    let bytes = ExportSettings::default().estimated_bytes(portrait(), Time(10 * SECOND));
    assert_eq!(bytes, 8_014_350);
}

#[test]
fn twice_as_long_is_twice_as_big() {
    let s = ExportSettings::default();
    let one = s.estimated_bytes(portrait(), Time(7 * SECOND));
    let two = s.estimated_bytes(portrait(), Time(14 * SECOND));
    assert!(two.abs_diff(2 * one) <= 1, "{one} {two}");
}

#[test]
fn higher_resolution_and_set_bitrates_count() {
    let d = Time(30 * SECOND);
    let hd = ExportSettings::default().estimated_bytes(portrait(), d);
    let uhd = ExportSettings {
        resolution: Resolution::P4K,
        ..ExportSettings::default()
    }
    .estimated_bytes(portrait(), d);
    assert!(uhd > hd);
    let set = ExportSettings {
        bitrate: Bitrate::kbps(2_000).unwrap(),
        ..ExportSettings::default()
    }
    .estimated_bytes(portrait(), d);
    assert!(set < hd);
}

#[test]
fn a_day_at_the_top_bitrate_does_not_overflow() {
    let s = ExportSettings {
        bitrate: Bitrate::kbps(150_000).unwrap(),
        ..ExportSettings::default()
    };
    let bytes = s.estimated_bytes(portrait(), Time(24 * 3600 * SECOND));
    // (150000 + 128) kbps for 86400 s, +1 %: about 1.64 TB.
    assert!(
        bytes > 1_600_000_000_000 && bytes < 1_700_000_000_000,
        "{bytes}"
    );
}

proptest! {
    #[test]
    fn longer_never_estimates_smaller(a in 0i64..(3600 * SECOND), extra in 0i64..(3600 * SECOND)) {
        let s = ExportSettings::default();
        prop_assert!(s.estimated_bytes(portrait(), Time(a)) <= s.estimated_bytes(portrait(), Time(a + extra)));
    }
}
