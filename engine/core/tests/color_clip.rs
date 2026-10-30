//! Color (blank) clips (P1-048): a solid color that plays for as long as its clip, like a photo,
//! with no file behind it.

use framix_core::media::{Media, MediaKind, PHOTO_DEFAULT_DURATION};
use framix_core::time::Time;
use framix_core::timeline::Timeline;

#[test]
fn a_color_media_has_its_color_and_no_file() {
    let red = Media::solid(0xff00_00ff);
    assert_eq!(red.kind(), MediaKind::Color);
    assert_eq!(red.color(), 0xff00_00ff);
    assert_eq!(red.uri(), "");
    assert_eq!(red.duration(), Time(0));
    assert_eq!(red.proxy_side(), None);
}

#[test]
fn other_media_have_no_color() {
    let black = Media::solid(0x0000_00ff);
    assert_eq!(black.color(), 0x0000_00ff);
    assert_ne!(Media::solid(0), black, "the color tells them apart");
}

#[test]
fn a_color_clip_plays_for_the_photo_duration_and_is_always_at_0() {
    let mut timeline = Timeline::default();
    let ids = timeline.import(vec![Media::solid(0x00ff_00ff)]).unwrap();
    assert_eq!(ids.len(), 1);
    assert_eq!(timeline.duration(), PHOTO_DEFAULT_DURATION);
    let layer = timeline
        .layer_at(Time(PHOTO_DEFAULT_DURATION.0 / 2))
        .unwrap();
    assert_eq!(layer.media.kind(), MediaKind::Color);
    assert_eq!(layer.source_time, Time(0));
    assert_eq!(layer.proxy_side, None);
}

// P1-048 review.

#[test]
fn the_platform_cannot_report_a_color() {
    let raw = framix_core::media::RawMedia {
        uri: "media/a.jpg".into(),
        kind: MediaKind::Color,
        duration_value: 0,
        duration_timescale: 0,
        width: 10,
        height: 10,
        rotation: 0,
        codec: String::new(),
    };
    assert!(Media::validate(raw).is_err());
}

// P1-078: a color fills the canvas; it has no picture to crop, turn, scale or move.

#[test]
fn a_color_clip_refuses_a_transform() {
    use framix_core::timeline::{ClipTransform, TimelineError};
    let mut timeline = Timeline::default();
    timeline.import(vec![Media::solid(0x00ff_00ff)]).unwrap();
    let clip = timeline.tracks()[0].clips()[0].id;
    for transform in [
        ClipTransform {
            scale: ClipTransform::default().scale * 2,
            ..Default::default()
        },
        ClipTransform {
            x: 100,
            ..Default::default()
        },
        ClipTransform {
            turns: 1,
            ..Default::default()
        },
        ClipTransform {
            flip_h: true,
            ..Default::default()
        },
    ] {
        assert_eq!(
            timeline.set_clip_transform(clip, transform),
            Err(TimelineError::BadTransform),
            "{transform:?}"
        );
    }
    assert_eq!(
        timeline.set_clip_transform(clip, ClipTransform::default()),
        Ok(()),
        "the default is fine"
    );
}
