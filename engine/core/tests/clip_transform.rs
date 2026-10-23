//! Crop, rotate and mirror per clip (P1-029).

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, ClipTransform, Crop, MediaId, Timeline, TimelineError, TrackFlags,
    TrackId, TrackKind,
};
use proptest::prelude::*;

/// A 100 x 50 photo registered as media 1, on one video track with a clip [0, 1000).
fn setup() -> (Timeline, TrackId, ClipId) {
    let mut tl = Timeline::default();
    let media = Media::validate(RawMedia {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 100,
        height: 50,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap();
    tl.restore_media(MediaId(1), media);
    let track = tl.add_track(TrackKind::Video);
    let clip = tl
        .insert_clip(
            track,
            ClipPlacement {
                media: MediaId(1),
                source_start: Time(0),
                start: Time(0),
                duration: Time(1000),
            },
        )
        .unwrap();
    (tl, track, clip)
}

fn transform_of(tl: &Timeline, clip: ClipId) -> ClipTransform {
    tl.tracks()
        .iter()
        .flat_map(|t| t.clips())
        .find(|c| c.id == clip)
        .unwrap()
        .transform
}

fn turned(turns: u8, flip_h: bool, crop: Crop) -> ClipTransform {
    ClipTransform {
        turns,
        flip_h,
        flip_v: false,
        crop,
    }
}

#[test]
fn a_new_clip_has_the_identity() {
    let (tl, _, clip) = setup();
    assert_eq!(transform_of(&tl, clip), ClipTransform::default());
}

#[test]
fn set_then_get() {
    let (mut tl, _, clip) = setup();
    let t = turned(
        1,
        true,
        Crop {
            left: 10,
            top: 5,
            right: 20,
            bottom: 0,
        },
    );
    tl.set_clip_transform(clip, t).unwrap();
    assert_eq!(transform_of(&tl, clip), t);
}

#[test]
fn a_crop_must_leave_a_pixel() {
    let (mut tl, _, clip) = setup();
    let all_wide = Crop {
        left: 60,
        right: 40,
        ..Crop::default()
    };
    assert_eq!(
        tl.set_clip_transform(clip, turned(0, false, all_wide)),
        Err(TimelineError::BadCrop)
    );
    let one_left = Crop {
        left: 60,
        right: 39,
        top: 49,
        bottom: 0,
    };
    assert_eq!(
        tl.set_clip_transform(clip, turned(0, false, one_left)),
        Ok(())
    );
    let huge = Crop {
        bottom: u32::MAX,
        ..Crop::default()
    };
    assert_eq!(
        tl.set_clip_transform(clip, turned(0, false, huge)),
        Err(TimelineError::BadCrop)
    );
}

#[test]
fn four_turns_are_refused() {
    let (mut tl, _, clip) = setup();
    assert_eq!(
        tl.set_clip_transform(clip, turned(4, false, Crop::default())),
        Err(TimelineError::BadTransform)
    );
}

#[test]
fn locked_tracks_and_unknown_clips_are_refused() {
    let (mut tl, track, clip) = setup();
    assert_eq!(
        tl.set_clip_transform(ClipId(999), turned(1, false, Crop::default())),
        Err(TimelineError::UnknownClip(ClipId(999)))
    );
    tl.set_track_flags(
        track,
        TrackFlags {
            locked: true,
            ..TrackFlags::default()
        },
    )
    .unwrap();
    assert_eq!(
        tl.set_clip_transform(clip, turned(1, false, Crop::default())),
        Err(TimelineError::TrackLocked(track))
    );
}

#[test]
fn split_and_duplicate_keep_the_transform() {
    let (mut tl, _, clip) = setup();
    let t = turned(
        2,
        true,
        Crop {
            top: 3,
            ..Crop::default()
        },
    );
    tl.set_clip_transform(clip, t).unwrap();
    let right = tl.split_clip(clip, Time(400)).unwrap();
    assert_eq!(transform_of(&tl, right), t);
    let copy = tl.duplicate_clip(right).unwrap();
    assert_eq!(transform_of(&tl, copy), t);
}

#[test]
fn merging_needs_equal_transforms() {
    let (mut tl, _, clip) = setup();
    let right = tl.split_clip(clip, Time(400)).unwrap();
    tl.set_clip_transform(right, turned(1, false, Crop::default()))
        .unwrap();
    assert_eq!(
        tl.merge_clips(clip, right),
        Err(TimelineError::TransformsDiffer)
    );
    tl.set_clip_transform(right, ClipTransform::default())
        .unwrap();
    assert_eq!(tl.merge_clips(clip, right), Ok(()));
}

proptest! {
    #[test]
    fn split_keeps_the_transform_on_both_halves(
        turns in 0u8..4,
        flip_h: bool,
        flip_v: bool,
        left in 0u32..50,
        top in 0u32..25,
        at in 1i64..1000,
    ) {
        let (mut tl, _, clip) = setup();
        let t = ClipTransform { turns, flip_h, flip_v, crop: Crop { left, top, right: 0, bottom: 0 } };
        tl.set_clip_transform(clip, t).unwrap();
        prop_assert_eq!(transform_of(&tl, clip), t);
        let right = tl.split_clip(clip, Time(at)).unwrap();
        prop_assert_eq!(transform_of(&tl, clip), t);
        prop_assert_eq!(transform_of(&tl, right), t);
    }
}
