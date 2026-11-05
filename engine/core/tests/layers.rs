//! Every visible video layer at a time, bottom to top (P1-071), from the topmost one that
//! covers the canvas; layers under it are never seen and are left out.

use framix_core::aspect::AspectRatio;
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, ClipTransform, MediaId, Timeline, TrackFlags, TrackId, TrackKind,
};

fn media(kind: MediaKind, width: u32, height: u32, rotation: u32) -> Media {
    Media::validate(RawMedia {
        uri: "media/m".into(),
        kind,
        duration_value: if kind == MediaKind::Video { 100_000 } else { 0 },
        duration_timescale: if kind == MediaKind::Video { 1000 } else { 0 },
        width,
        height,
        rotation,
        codec: if kind == MediaKind::Video {
            "avc1".into()
        } else {
            String::new()
        },
    })
    .unwrap()
}

const WIDE: u64 = 1; // 1920x1080 video
const FOUR_THREE: u64 = 2; // 1440x1080 video
const PORTRAIT: u64 = 3; // 1920x1080 video turned 90
const RED: u64 = 4;
const PHOTO: u64 = 5; // 1000x500

/// A 16:9 timeline with all media, and `n` video tracks (bottom first).
fn timeline(n: usize) -> (Timeline, Vec<TrackId>) {
    let mut tl = Timeline::default();
    tl.set_aspect(AspectRatio::LANDSCAPE_16_9);
    tl.restore_media(MediaId(WIDE), media(MediaKind::Video, 1920, 1080, 0));
    tl.restore_media(MediaId(FOUR_THREE), media(MediaKind::Video, 1440, 1080, 0));
    tl.restore_media(MediaId(PORTRAIT), media(MediaKind::Video, 1920, 1080, 90));
    tl.restore_media(MediaId(RED), Media::solid(0xff00_00ff));
    tl.restore_media(MediaId(PHOTO), media(MediaKind::Image, 1000, 500, 0));
    tl.add_track(TrackKind::Audio);
    let tracks = (0..n).map(|_| tl.add_track(TrackKind::Video)).collect();
    (tl, tracks)
}

fn place(tl: &mut Timeline, track: TrackId, media: u64, start: i64, len: i64) -> ClipId {
    tl.insert_clip(
        track,
        ClipPlacement {
            media: MediaId(media),
            source_start: Time(0),
            start: Time(start),
            duration: Time(len),
        },
    )
    .unwrap()
}

fn shown(tl: &Timeline, at: i64) -> Vec<u64> {
    let ids: Vec<u64> = tl.layers_at(Time(at)).map(|l| l.media_id.0).collect();
    assert_eq!(
        tl.layer_at(Time(at)).map(|l| l.media_id.0),
        ids.last().copied(),
        "layer_at is the top of layers_at"
    );
    ids
}

fn transform(scale: u32, x: i32) -> ClipTransform {
    ClipTransform {
        scale,
        x,
        ..ClipTransform::default()
    }
}

#[test]
fn a_smaller_top_shows_the_bottom_under_it() {
    let (mut tl, t) = timeline(2);
    place(&mut tl, t[0], PHOTO, 0, 100);
    let top = place(&mut tl, t[1], WIDE, 0, 50);
    tl.set_clip_transform(top, transform(500, 0)).unwrap();
    assert_eq!(shown(&tl, 10), [PHOTO, WIDE], "bottom to top");
    assert_eq!(shown(&tl, 60), [PHOTO], "the top clip ended");
    assert_eq!(shown(&tl, 200), Vec::<u64>::new(), "past the end");
}

#[test]
fn hidden_tracks_and_tracks_without_a_clip_are_skipped() {
    let (mut tl, t) = timeline(3);
    place(&mut tl, t[0], PHOTO, 0, 100);
    place(&mut tl, t[1], FOUR_THREE, 50, 50);
    let top = place(&mut tl, t[2], WIDE, 0, 100);
    tl.set_clip_transform(top, transform(500, 0)).unwrap();
    assert_eq!(shown(&tl, 10), [PHOTO, WIDE]);
    tl.set_track_flags(
        t[2],
        TrackFlags {
            hidden: true,
            ..TrackFlags::default()
        },
    )
    .unwrap();
    assert_eq!(shown(&tl, 10), [PHOTO]);
}

#[test]
fn a_color_hides_everything_under_it() {
    let (mut tl, t) = timeline(2);
    place(&mut tl, t[0], PHOTO, 0, 100);
    place(&mut tl, t[1], RED, 0, 100);
    assert_eq!(shown(&tl, 10), [RED]);
}

#[test]
fn a_top_that_covers_the_canvas_hides_the_rest() {
    let (mut tl, t) = timeline(2);
    place(&mut tl, t[0], PHOTO, 0, 100);
    let top = place(&mut tl, t[1], WIDE, 0, 100);
    assert_eq!(shown(&tl, 10), [WIDE], "same shape at fit");
    tl.set_clip_transform(top, transform(1000, 100)).unwrap();
    assert_eq!(shown(&tl, 10), [PHOTO, WIDE], "moved off an edge");
    tl.set_clip_transform(top, transform(2000, 1000)).unwrap();
    assert_eq!(shown(&tl, 10), [WIDE], "big enough to cover while moved");

    let (mut tl, t) = timeline(2);
    place(&mut tl, t[0], PHOTO, 0, 100);
    place(&mut tl, t[1], FOUR_THREE, 0, 100);
    assert_eq!(shown(&tl, 10), [PHOTO, FOUR_THREE], "4:3 on 16:9 leaves bars");
}

#[test]
fn a_turned_portrait_covers_a_portrait_canvas() {
    let (mut tl, t) = timeline(2);
    tl.set_aspect(AspectRatio::PORTRAIT_9_16);
    place(&mut tl, t[0], PHOTO, 0, 100);
    place(&mut tl, t[1], PORTRAIT, 0, 100);
    assert_eq!(shown(&tl, 10), [PORTRAIT]);
}
