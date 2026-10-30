//! Which media get a preview proxy, and how big it is (P1-039, docs/adr/0007-proxy-media.md).

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::Timeline;

fn media(kind: MediaKind, width: u32, height: u32) -> Media {
    let video = kind == MediaKind::Video;
    Media::validate(RawMedia {
        uri: "media/v.mp4".into(),
        kind,
        duration_value: if video { 1000 } else { 0 },
        duration_timescale: if video { 1000 } else { 0 },
        width,
        height,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap()
}

#[test]
fn a_4k_video_gets_a_1080p_proxy() {
    assert_eq!(media(MediaKind::Video, 3840, 2160).proxy_side(), Some(1920));
    assert_eq!(media(MediaKind::Video, 2160, 3840).proxy_side(), Some(1920));
}

#[test]
fn a_1440p_video_gets_a_720p_proxy() {
    assert_eq!(media(MediaKind::Video, 2560, 1440).proxy_side(), Some(1280));
    assert_eq!(media(MediaKind::Video, 1921, 1080).proxy_side(), Some(1280));
    assert_eq!(media(MediaKind::Video, 2561, 1440).proxy_side(), Some(1920));
}

#[test]
fn full_hd_and_smaller_videos_and_photos_get_none() {
    assert_eq!(media(MediaKind::Video, 1920, 1080).proxy_side(), None);
    assert_eq!(media(MediaKind::Video, 1080, 1920).proxy_side(), None);
    assert_eq!(media(MediaKind::Image, 4032, 3024).proxy_side(), None);
}

#[test]
fn the_timeline_layer_uses_the_original() {
    let mut t = Timeline::default();
    t.import(vec![media(MediaKind::Video, 3840, 2160)]).unwrap();
    assert_eq!(t.layer_at(Time(0)).unwrap().proxy_side, None);
}
