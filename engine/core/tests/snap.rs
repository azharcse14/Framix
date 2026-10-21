//! Snapping (P1-022): the nearest edge within a tolerance.

use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TrackKind};
use proptest::prelude::*;

fn place(start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(0),
        start: Time(start),
        duration: Time(duration),
    }
}

/// Video [100, 200) and [300, 450); audio [120, 180).
fn timeline() -> Timeline {
    let mut tl = Timeline::default();
    let v = tl.add_track(TrackKind::Video);
    let a = tl.add_track(TrackKind::Audio);
    tl.insert_clip(v, place(100, 100)).unwrap();
    tl.insert_clip(v, place(300, 150)).unwrap();
    tl.insert_clip(a, place(120, 60)).unwrap();
    tl
}

fn snap(tl: &Timeline, time: i64, within: i64) -> Option<i64> {
    tl.snap(Time(time), Time(within)).map(|t| t.0)
}

#[test]
fn snaps_to_the_nearest_edge_on_any_track() {
    let tl = timeline();
    assert_eq!(snap(&tl, 205, 10), Some(200), "video clip end");
    assert_eq!(
        snap(&tl, 118, 10),
        Some(120),
        "audio clip start beats video start (100)"
    );
    assert_eq!(snap(&tl, 295, 10), Some(300));
}

#[test]
fn zero_and_the_end_are_snap_points() {
    let tl = timeline();
    assert_eq!(snap(&tl, 7, 10), Some(0));
    assert_eq!(snap(&tl, 455, 10), Some(450));
}

#[test]
fn a_tie_picks_the_earlier_point() {
    let tl = timeline();
    // 110 is 10 from 100 and 10 from 120.
    assert_eq!(snap(&tl, 110, 10), Some(100));
}

#[test]
fn nothing_in_range_is_none() {
    let tl = timeline();
    assert_eq!(snap(&tl, 250, 10), None);
    assert_eq!(
        snap(&tl, 205, 0),
        None,
        "zero tolerance only matches an exact edge"
    );
    assert_eq!(snap(&tl, 200, 0), Some(200));
}

#[test]
fn an_empty_timeline_snaps_only_to_zero() {
    let tl = Timeline::default();
    assert_eq!(snap(&tl, 5, 10), Some(0));
    assert_eq!(snap(&tl, 50, 10), None);
}

/// Every snap point of `tl`, the slow way.
fn points(tl: &Timeline) -> Vec<i64> {
    let mut p = vec![0, tl.duration().0];
    for track in tl.tracks() {
        for clip in track.clips() {
            p.push(clip.start.0);
            p.push(clip.end().0);
        }
    }
    p
}

proptest! {
    #[test]
    fn snap_returns_the_closest_point_in_range(time in -100i64..600, within in 0i64..80) {
        let tl = timeline();
        let all = points(&tl);
        match snap(&tl, time, within) {
            Some(p) => {
                prop_assert!(all.contains(&p));
                prop_assert!((p - time).abs() <= within);
                let best = all.iter().map(|q| (q - time).abs()).min().unwrap();
                prop_assert_eq!((p - time).abs(), best);
            }
            None => prop_assert!(all.iter().all(|q| (q - time).abs() > within)),
        }
    }
}
