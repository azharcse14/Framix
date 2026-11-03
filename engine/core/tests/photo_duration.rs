//! Set one duration on every photo at once (P1-028): photos get the new length, and the clips
//! after them on the same track move by the change, so gaps and order are kept.

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{Clip, Timeline, TimelineError, TrackFlags};
use proptest::prelude::*;

const S: i64 = TICKS_PER_SECOND;

fn raw(kind: MediaKind) -> Media {
    Media::validate(RawMedia {
        uri: "media/a.jpg".into(),
        kind,
        duration_value: 2000,
        duration_timescale: 1000,
        width: 640,
        height: 480,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap()
}

fn photo() -> Media {
    raw(MediaKind::Image)
}

/// A 2 s video.
fn video() -> Media {
    raw(MediaKind::Video)
}

/// (start, duration) in seconds of track `t`'s clips.
fn spans(tl: &Timeline, t: usize) -> Vec<(i64, i64)> {
    tl.tracks()[t]
        .clips()
        .iter()
        .map(|c| (c.start.0 / S, c.duration.0 / S))
        .collect()
}

#[test]
fn photos_get_the_duration_and_later_clips_follow() {
    let mut tl = Timeline::default();
    tl.import(vec![photo(), video(), photo(), Media::solid(0xff)])
        .unwrap();
    assert_eq!(spans(&tl, 0), [(0, 3), (3, 2), (5, 3), (8, 3)]);
    tl.set_photo_durations(Time(S)).unwrap();
    // The color clip is not a photo: it keeps its length and only moves.
    assert_eq!(spans(&tl, 0), [(0, 1), (1, 2), (3, 1), (4, 3)]);
    tl.set_photo_durations(Time(5 * S)).unwrap();
    assert_eq!(spans(&tl, 0), [(0, 5), (5, 2), (7, 5), (12, 3)]);
}

#[test]
fn gaps_are_kept() {
    let mut tl = Timeline::default();
    let ids = tl.import(vec![photo(), video()]).unwrap();
    let track = tl.tracks()[0].id();
    tl.move_clip(ids[1], track, Time(10 * S)).unwrap();
    tl.set_photo_durations(Time(S)).unwrap();
    assert_eq!(spans(&tl, 0), [(0, 1), (8, 2)], "the 7 s gap stays");
}

#[test]
fn locked_tracks_are_left_alone_and_other_tracks_do_not_move() {
    let mut tl = Timeline::default();
    tl.import(vec![photo(), video()]).unwrap();
    let first = tl.tracks()[0].id();
    tl.set_track_flags(
        first,
        TrackFlags {
            locked: true,
            ..TrackFlags::default()
        },
    )
    .unwrap();
    // The next import goes to a new track, since the first is locked.
    tl.import(vec![video(), photo()]).unwrap();
    tl.set_photo_durations(Time(S)).unwrap();
    assert_eq!(spans(&tl, 0), [(0, 3), (3, 2)]);
    assert_eq!(spans(&tl, 1), [(0, 2), (2, 1)]);
}

#[test]
fn a_bad_duration_is_refused_and_changes_nothing() {
    let mut tl = Timeline::default();
    tl.import(vec![photo(), photo()]).unwrap();
    let before = tl.clone();
    assert_eq!(
        tl.set_photo_durations(Time(0)),
        Err(TimelineError::NonPositiveDuration)
    );
    assert_eq!(
        tl.set_photo_durations(Time(-S)),
        Err(TimelineError::NonPositiveDuration)
    );
    assert_eq!(
        tl.set_photo_durations(Time(i64::MAX / 2 + 1)),
        Err(TimelineError::TimeOverflow),
        "two such photos end past the largest time"
    );
    assert_eq!(tl, before);
}

#[test]
fn a_timeline_without_photos_is_unchanged() {
    let mut tl = Timeline::default();
    tl.import(vec![video()]).unwrap();
    let before = tl.clone();
    tl.set_photo_durations(Time(S)).unwrap();
    assert_eq!(tl, before);
}

proptest! {
    /// Photos get exactly `d`, others keep theirs, order and gaps between clips are kept.
    #[test]
    fn durations_order_and_gaps_hold(
        kinds in prop::collection::vec(any::<bool>(), 1..12),
        gaps in prop::collection::vec(0i64..5, 12),
        d in 1i64..10 * S,
    ) {
        let mut tl = Timeline::default();
        let media = kinds.iter().map(|&p| if p { photo() } else { video() }).collect();
        let ids = tl.import(media).unwrap();
        let track = tl.tracks()[0].id();
        // Spread the clips out, back to front so each move lands in free space.
        let mut start = 0;
        let mut starts = Vec::new();
        for (i, c) in tl.tracks()[0].clips().iter().enumerate() {
            start += gaps[i] * S;
            starts.push(start);
            start += c.duration.0;
        }
        for (i, id) in ids.iter().enumerate().rev() {
            tl.move_clip(*id, track, Time(starts[i])).unwrap();
        }
        let before: Vec<_> = tl.tracks()[0].clips().to_vec();
        tl.set_photo_durations(Time(d)).unwrap();
        let after = tl.tracks()[0].clips();
        prop_assert_eq!(after.len(), before.len());
        for (i, (a, b)) in after.iter().zip(&before).enumerate() {
            prop_assert_eq!(a.id, b.id);
            let is_photo = tl.media(a.media).unwrap().kind() == MediaKind::Image;
            prop_assert_eq!(a.duration, if is_photo { Time(d) } else { b.duration });
            if i > 0 {
                let gap = |c: &[Clip]| c[i].start.0 - c[i - 1].end().0;
                prop_assert_eq!(gap(after), gap(&before));
            }
        }
        prop_assert_eq!(after[0].start, before[0].start);
    }
}
