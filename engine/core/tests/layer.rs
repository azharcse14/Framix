//! The picture under a time (P1-060): the top visible video clip and where in its media.

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{
    ClipPlacement, ClipTransform, MediaId, Timeline, TrackFlags, TrackId, TrackKind,
};
use proptest::prelude::*;

fn video(seconds: i64) -> Media {
    Media::validate(RawMedia {
        uri: "media/v.mp4".into(),
        kind: MediaKind::Video,
        duration_value: seconds * 1000,
        duration_timescale: 1000,
        width: 160,
        height: 90,
        rotation: 0,
        codec: "avc1".into(),
    })
    .unwrap()
}

fn photo() -> Media {
    Media::validate(RawMedia {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 100,
        height: 50,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap()
}

fn place(tl: &mut Timeline, track: TrackId, media: u64, source: i64, start: i64, len: i64) {
    tl.insert_clip(
        track,
        ClipPlacement {
            media: MediaId(media),
            source_start: Time(source),
            start: Time(start),
            duration: Time(len),
        },
    )
    .unwrap();
}

fn setup() -> (Timeline, TrackId, TrackId) {
    let mut tl = Timeline::default();
    tl.restore_media(MediaId(1), video(100));
    tl.restore_media(MediaId(2), photo());
    let low = tl.add_track(TrackKind::Video);
    let high = tl.add_track(TrackKind::Video);
    (tl, low, high)
}

#[test]
fn the_layer_is_the_clip_on_the_top_visible_video_track() {
    let (mut tl, low, high) = setup();
    place(&mut tl, low, 1, 0, 0, 1000);
    place(&mut tl, high, 2, 0, 500, 1000);

    let l = tl.layer_at(Time(200)).unwrap();
    assert_eq!(l.media_id, MediaId(1), "only the lower track has a clip at 200");
    let l = tl.layer_at(Time(600)).unwrap();
    assert_eq!(l.media_id, MediaId(2), "the later track draws on top");

    tl.set_track_flags(
        high,
        TrackFlags {
            hidden: true,
            ..TrackFlags::default()
        },
    )
    .unwrap();
    assert_eq!(tl.layer_at(Time(600)).unwrap().media_id, MediaId(1));
    assert!(tl.layer_at(Time(1200)).is_none(), "nothing visible there");
    assert_eq!(
        tl.top_clip_at(Time(600)),
        tl.tracks()[0].clips().first().map(|c| c.id),
        "canvas gestures act on the clip the preview shows"
    );
}

#[test]
fn the_source_time_follows_the_trim() {
    let (mut tl, low, _) = setup();
    place(&mut tl, low, 1, 3000, 1000, 2000);
    let l = tl.layer_at(Time(1500)).unwrap();
    assert_eq!(l.source_time, Time(3500));
    assert_eq!(l.media.uri(), "media/v.mp4");
    assert_eq!(l.transform, ClipTransform::default());
}

#[test]
fn a_photo_is_always_its_one_frame() {
    let (mut tl, low, _) = setup();
    place(&mut tl, low, 2, 0, 0, 5000);
    assert_eq!(tl.layer_at(Time(10)).unwrap().source_time, Time(0));
    assert_eq!(
        tl.layer_at(Time(10)).unwrap().key(),
        tl.layer_at(Time(4000)).unwrap().key(),
        "same picture, same key"
    );
}

#[test]
fn keys_differ_when_the_picture_does() {
    let (mut tl, low, _) = setup();
    place(&mut tl, low, 1, 0, 0, 5000);
    let a = tl.layer_at(Time(10)).unwrap().key();
    let b = tl.layer_at(Time(20)).unwrap().key();
    assert_ne!(a, b);
}

proptest! {
    #[test]
    fn the_source_time_stays_inside_the_clip(
        source in 0i64..50_000,
        start in 0i64..10_000,
        len in 1i64..50_000,
        at in 0i64..70_000,
    ) {
        let (mut tl, low, _) = setup();
        place(&mut tl, low, 1, source, start, len);
        match tl.layer_at(Time(at)) {
            Some(l) => {
                prop_assert!(at >= start && at < start + len);
                prop_assert!(l.source_time.0 >= source && l.source_time.0 < source + len);
            }
            None => prop_assert!(at < start || at >= start + len),
        }
    }
}
