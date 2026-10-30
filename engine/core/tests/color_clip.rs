//! Color (blank) clips (P1-048): a solid color that plays for as long as its clip, like a photo,
//! with no file behind it.

use framix_core::media::{Media, MediaKind, PHOTO_DEFAULT_DURATION};
use framix_core::time::Time;
use framix_core::timeline::Timeline;

#[test]
fn a_color_media_has_its_color_and_no_file() {
    let red = Media::color(0xff00_00ff);
    assert_eq!(red.kind(), MediaKind::Color);
    assert_eq!(red.color(), 0xff00_00ff);
    assert_eq!(red.uri(), "");
    assert_eq!(red.duration(), Time(0));
    assert_eq!(red.proxy_side(), None);
}

#[test]
fn other_media_have_no_color() {
    let black = Media::color(0x0000_00ff);
    assert_eq!(black.color(), 0x0000_00ff);
    assert_ne!(Media::color(0), black, "the color tells them apart");
}

#[test]
fn a_color_clip_plays_for_the_photo_duration_and_is_always_at_0() {
    let mut timeline = Timeline::default();
    let ids = timeline.import(vec![Media::color(0x00ff_00ff)]).unwrap();
    assert_eq!(ids.len(), 1);
    assert_eq!(timeline.duration(), PHOTO_DEFAULT_DURATION);
    let layer = timeline
        .layer_at(Time(PHOTO_DEFAULT_DURATION.0 / 2))
        .unwrap();
    assert_eq!(layer.media.kind(), MediaKind::Color);
    assert_eq!(layer.source_time, Time(0));
    assert_eq!(layer.proxy_side, None);
}
