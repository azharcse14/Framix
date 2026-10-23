//! Clip position and scale on the canvas, and the clip canvas gestures act on (P1-030).

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, ClipTransform, MediaId, Timeline, TimelineError, TrackFlags, TrackId,
    TrackKind,
};
use proptest::prelude::*;

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

fn place(tl: &mut Timeline, track: TrackId, start: i64, duration: i64) -> ClipId {
    tl.insert_clip(
        track,
        ClipPlacement {
            media: MediaId(1),
            source_start: Time(0),
            start: Time(start),
            duration: Time(duration),
        },
    )
    .unwrap()
}

fn setup() -> (Timeline, TrackId, ClipId) {
    let mut tl = Timeline::default();
    tl.restore_media(MediaId(1), photo());
    let track = tl.add_track(TrackKind::Video);
    let clip = place(&mut tl, track, 0, 1000);
    (tl, track, clip)
}

fn at(x: i32, y: i32, scale: u32) -> ClipTransform {
    ClipTransform {
        x,
        y,
        scale,
        ..ClipTransform::default()
    }
}

#[test]
fn the_default_fits_the_canvas_at_its_centre() {
    let t = ClipTransform::default();
    assert_eq!((t.x, t.y, t.scale), (0, 0, 1000));
}

#[test]
fn position_and_scale_ranges() {
    let (mut tl, _, clip) = setup();
    for ok in [
        at(20000, -20000, 10),
        at(-20000, 20000, 10000),
        at(1, 2, 1500),
    ] {
        assert_eq!(tl.set_clip_transform(clip, ok), Ok(()), "{ok:?}");
    }
    for bad in [
        at(20001, 0, 1000),
        at(0, -20001, 1000),
        at(0, 0, 9),
        at(0, 0, 10001),
        at(0, 0, 0),
    ] {
        assert_eq!(
            tl.set_clip_transform(clip, bad),
            Err(TimelineError::BadTransform),
            "{bad:?}"
        );
    }
}

#[test]
fn the_top_visible_video_track_wins() {
    let (mut tl, lower, low_clip) = setup();
    let upper = tl.add_track(TrackKind::Video);
    let audio = tl.add_track(TrackKind::Audio);
    let high_clip = place(&mut tl, upper, 200, 300);
    place(&mut tl, audio, 0, 1000);
    assert_eq!(tl.top_clip_at(Time(250)), Some(high_clip));
    assert_eq!(
        tl.top_clip_at(Time(100)),
        Some(low_clip),
        "nothing above at 100"
    );
    tl.set_track_flags(
        upper,
        TrackFlags {
            hidden: true,
            ..TrackFlags::default()
        },
    )
    .unwrap();
    assert_eq!(
        tl.top_clip_at(Time(250)),
        Some(low_clip),
        "hidden tracks are skipped"
    );
    let _ = lower;
    assert_eq!(tl.top_clip_at(Time(5000)), None, "past every clip");
}

proptest! {
    #[test]
    fn split_keeps_position_and_scale(
        x in -20000i32..=20000,
        y in -20000i32..=20000,
        scale in 10u32..=10000,
        cut in 1i64..1000,
    ) {
        let (mut tl, _, clip) = setup();
        tl.set_clip_transform(clip, at(x, y, scale)).unwrap();
        let right = tl.split_clip(clip, Time(cut)).unwrap();
        let t = tl.tracks()[0].clips().iter().find(|c| c.id == right).unwrap().transform;
        prop_assert_eq!((t.x, t.y, t.scale), (x, y, scale));
    }
}
