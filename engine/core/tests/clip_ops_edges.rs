//! P1-018 review: overflow paths and cross-track merges.
mod common;

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, TimelineError, TrackKind};

fn place(source_start: i64, start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(1),
        source_start: Time(source_start),
        start: Time(start),
        duration: Time(duration),
    }
}

#[test]
fn overflowing_source_or_end_is_refused() {
    let mut tl = common::timeline();
    let t = tl.add_track(TrackKind::Video);
    // A video's source must end inside it (ENG-053); a photo has no length, so its clip
    // can carry the largest source offset.
    let photo = Media::validate(RawMedia {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 4,
        height: 3,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap();
    tl.restore_media(MediaId(3), photo);
    let huge_source = ClipPlacement {
        media: MediaId(3),
        ..place(i64::MAX - 5, 0, 100)
    };
    let c = tl.insert_clip(t, huge_source).unwrap();
    assert_eq!(tl.split_clip(c, Time(50)), Err(TimelineError::TimeOverflow));
    // A still's trim keeps its source offset (ENG-064), so nothing can overflow there.
    assert_eq!(tl.trim_clip(c, Time(50), Time(100)), Ok(()));
    assert_eq!(tl.clip(c).unwrap().source_start, Time(i64::MAX - 5));

    let mut tl = common::timeline();
    let t = tl.add_track(TrackKind::Video);
    let c = tl.insert_clip(t, place(0, i64::MAX - 100, 60)).unwrap();
    assert_eq!(tl.duplicate_clip(c), Err(TimelineError::TimeOverflow));
}

#[test]
fn clips_on_different_tracks_never_merge() {
    let mut tl = common::timeline();
    let a = tl.add_track(TrackKind::Video);
    let b = tl.add_track(TrackKind::Video);
    let left = tl.insert_clip(a, place(0, 0, 10)).unwrap();
    let right = tl.insert_clip(b, place(10, 10, 10)).unwrap();
    assert_eq!(
        tl.merge_clips(left, right),
        Err(TimelineError::NotMergeable)
    );
}
