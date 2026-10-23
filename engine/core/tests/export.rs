//! Export settings (P1-032).

use framix_core::aspect::AspectRatio;
use framix_core::export::{Bitrate, ExportSettings, FrameRate, KBPS_RANGE, Resolution};
use framix_core::timeline::Timeline;
use proptest::prelude::*;

fn settings(resolution: Resolution, fps: FrameRate) -> ExportSettings {
    ExportSettings {
        resolution,
        fps,
        bitrate: Bitrate::Auto,
    }
}

fn aspect(w: u32, h: u32) -> AspectRatio {
    AspectRatio::new(w, h).unwrap()
}

#[test]
fn the_default_is_1080p30_auto() {
    let s = ExportSettings::default();
    assert_eq!(
        (s.resolution, s.fps, s.bitrate),
        (Resolution::P1080, FrameRate::F30, Bitrate::Auto)
    );
    assert_eq!(Timeline::default().export(), s);
}

#[test]
fn frame_sizes_follow_the_canvas() {
    let s = |r| settings(r, FrameRate::F30);
    assert_eq!(s(Resolution::P1080).frame_size(aspect(9, 16)), (1080, 1920));
    assert_eq!(s(Resolution::P4K).frame_size(aspect(16, 9)), (3840, 2160));
    assert_eq!(s(Resolution::P720).frame_size(aspect(1, 1)), (720, 720));
    assert_eq!(s(Resolution::P2K).frame_size(aspect(16, 9)), (2560, 1440));
    // 4:5 at 1080: 1080 x 1350.
    assert_eq!(s(Resolution::P1080).frame_size(aspect(4, 5)), (1080, 1350));
    // 21:9 at 720: 1680 x 720.
    assert_eq!(s(Resolution::P720).frame_size(aspect(21, 9)), (1680, 720));
}

#[test]
fn auto_bitrate_grows_with_pixels_and_frames_and_stays_in_range() {
    let a = aspect(16, 9);
    let kbps = |r, f| settings(r, f).effective_kbps(a);
    assert!(kbps(Resolution::P720, FrameRate::F30) < kbps(Resolution::P1080, FrameRate::F30));
    assert!(kbps(Resolution::P1080, FrameRate::F30) < kbps(Resolution::P1080, FrameRate::F60));
    assert!(kbps(Resolution::P1080, FrameRate::F24) < kbps(Resolution::P1080, FrameRate::F30));
    for r in [
        Resolution::P720,
        Resolution::P1080,
        Resolution::P2K,
        Resolution::P4K,
    ] {
        for f in [FrameRate::F24, FrameRate::F30, FrameRate::F60] {
            assert!(KBPS_RANGE.contains(&kbps(r, f)), "{r:?} {f:?}");
        }
    }
}

#[test]
fn a_set_bitrate_is_kept_and_checked() {
    let s = ExportSettings {
        bitrate: Bitrate::kbps(8_000).unwrap(),
        ..ExportSettings::default()
    };
    assert_eq!(s.effective_kbps(aspect(9, 16)), 8_000);
    assert_eq!(Bitrate::kbps(999), None);
    assert_eq!(Bitrate::kbps(150_001), None);
    assert_eq!(Bitrate::kbps(1_000), Some(Bitrate::Kbps(1_000)));
}

#[test]
fn frame_rates_are_whole_frames_per_second() {
    use framix_core::time::{TICKS_PER_SECOND, Time};
    for (f, n) in [
        (FrameRate::F24, 24),
        (FrameRate::F30, 30),
        (FrameRate::F60, 60),
    ] {
        assert_eq!(f.rate().frame_to_time(n), Some(Time(TICKS_PER_SECOND)));
    }
}

#[test]
fn settings_are_part_of_the_timeline() {
    let mut tl = Timeline::default();
    let s = settings(Resolution::P4K, FrameRate::F60);
    tl.set_export(s);
    assert_eq!(tl.export(), s);
    assert_ne!(tl, Timeline::default(), "equality sees export settings");
}

proptest! {
    #[test]
    fn frame_sizes_are_even_and_keep_the_aspect(w in 1u32..40, h in 1u32..40, r in 0usize..4) {
        prop_assume!(AspectRatio::new(w, h).is_some());
        let res = [Resolution::P720, Resolution::P1080, Resolution::P2K, Resolution::P4K][r];
        let a = aspect(w, h);
        let (fw, fh) = settings(res, FrameRate::F30).frame_size(a);
        prop_assert!(fw > 0 && fh > 0 && fw % 2 == 0 && fh % 2 == 0);
        prop_assert_eq!(fw.min(fh), res.short_side());
        // fw / fh is a.width / a.height within one even step.
        let ideal = u64::from(fh) * u64::from(a.width());
        prop_assert!((u64::from(fw) * u64::from(a.height())).abs_diff(ideal) <= 2 * u64::from(a.height()));
    }
}
