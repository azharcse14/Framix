//! ENG-053: a video clip's source range `[source_start, source_start + duration)` stays inside
//! its media; photos and colors have no length, so their clips may be any length.
mod common;

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, MediaId, Timeline, TimelineError, TrackId, TrackKind,
};
use proptest::prelude::*;

/// Length of media 3, a video.
const LEN: i64 = 100;
const VIDEO: u64 = 3;
const PHOTO: u64 = 4;
const COLOR: u64 = 5;

fn photo() -> Media {
    Media::validate(RawMedia {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 4,
        height: 3,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap()
}

/// A video track and a timeline with a `LEN`-tick video, a photo and a color registered.
fn timeline() -> (Timeline, TrackId) {
    let mut tl = common::timeline();
    tl.restore_media(MediaId(VIDEO), Media::missing(Time(LEN)).unwrap());
    tl.restore_media(MediaId(PHOTO), photo());
    tl.restore_media(MediaId(COLOR), Media::solid(0xff0000ff));
    let t = tl.add_track(TrackKind::Video);
    (tl, t)
}

fn place(media: u64, source_start: i64, start: i64, duration: i64) -> ClipPlacement {
    ClipPlacement {
        media: MediaId(media),
        source_start: Time(source_start),
        start: Time(start),
        duration: Time(duration),
    }
}

#[test]
fn insert_past_the_media_end_is_refused() {
    let (mut tl, t) = timeline();
    let before = tl.clone();
    assert_eq!(
        tl.insert_clip(t, place(VIDEO, 1, 0, LEN)),
        Err(TimelineError::PastMediaEnd)
    );
    assert_eq!(
        tl.insert_clip(t, place(VIDEO, 0, 0, LEN + 1)),
        Err(TimelineError::PastMediaEnd)
    );
    assert_eq!(
        tl.insert_clip(t, place(VIDEO, LEN, 0, 1)),
        Err(TimelineError::PastMediaEnd)
    );
    assert_eq!(tl, before);
    tl.insert_clip(t, place(VIDEO, 10, 0, LEN - 10)).unwrap();
}

#[test]
fn trim_past_the_media_end_is_refused() {
    let (mut tl, t) = timeline();
    // Timeline [50, 90), source [20, 60).
    let c = tl.insert_clip(t, place(VIDEO, 20, 50, 40)).unwrap();
    let before = tl.clone();
    // The tail may grow to the media end (source 100 = timeline 130), not one tick further.
    assert_eq!(
        tl.trim_clip(c, Time(50), Time(131)),
        Err(TimelineError::PastMediaEnd)
    );
    // Trim start to a playhead in the gap before the clip: the source would start before 0.
    assert_eq!(
        tl.trim_clip(c, Time(29), Time(90)),
        Err(TimelineError::NegativeTime)
    );
    assert_eq!(tl, before);
    tl.trim_clip(c, Time(30), Time(130)).unwrap();
    let clip = tl.clip(c).unwrap();
    assert_eq!((clip.source_start, clip.duration), (Time(0), Time(LEN)));
}

#[test]
fn photo_and_color_clips_trim_to_any_length() {
    let (mut tl, t) = timeline();
    for (i, media) in [PHOTO, COLOR].into_iter().enumerate() {
        let start = i64::try_from(i).unwrap() * 10_000;
        let c = tl.insert_clip(t, place(media, 0, start, 10)).unwrap();
        tl.trim_clip(c, Time(start), Time(start + 5_000)).unwrap();
    }
}

#[test]
fn photo_and_color_clips_lengthen_at_their_start() {
    // ENG-060: a still has no source range, so growing its head never moves its source below 0.
    let (mut tl, t) = timeline();
    for (i, media) in [PHOTO, COLOR].into_iter().enumerate() {
        let start = 1_000 + i64::try_from(i).unwrap() * 10_000;
        let c = tl.insert_clip(t, place(media, 0, start, 10)).unwrap();
        assert_eq!(
            tl.trim_clip(c, Time(start - 1_000), Time(start + 10)),
            Ok(())
        );
        let clip = tl.clip(c).unwrap();
        assert_eq!(
            (clip.source_start, clip.start, clip.duration),
            (Time(0), Time(start - 1_000), Time(1_010))
        );
    }
}

#[test]
fn still_halves_merge_after_the_left_grows_at_its_start() {
    // ENG-062: the left half's source offset stops at 0 (ENG-060), yet the halves still merge.
    let (mut tl, t) = timeline();
    for (i, media) in [PHOTO, COLOR].into_iter().enumerate() {
        let start = 5_000 + i64::try_from(i).unwrap() * 10_000;
        let c = tl.insert_clip(t, place(media, 0, start, 100)).unwrap();
        let right = tl.split_clip(c, Time(start + 50)).unwrap();
        tl.trim_clip(c, Time(start - 1_000), Time(start + 50))
            .unwrap();
        assert_eq!(tl.clip(c).unwrap().source_start, Time(0));
        assert_eq!(tl.merge_clips(c, right), Ok(()));
        let clip = tl.clip(c).unwrap();
        assert_eq!(
            (clip.source_start, clip.start, clip.duration),
            (Time(0), Time(start - 1_000), Time(1_100))
        );
    }
}

#[test]
fn a_still_duplicate_does_not_merge_with_its_original() {
    // ENG-062: a copy placed right after its original is not one of its halves.
    let (mut tl, t) = timeline();
    for (i, media) in [PHOTO, COLOR].into_iter().enumerate() {
        let start = i64::try_from(i).unwrap() * 10_000;
        let c = tl.insert_clip(t, place(media, 0, start, 100)).unwrap();
        let copy = tl.duplicate_clip(c).unwrap();
        assert_eq!(tl.merge_clips(c, copy), Err(TimelineError::NotMergeable));
    }
}

#[test]
fn two_inserts_of_one_photo_do_not_merge() {
    let (mut tl, t) = timeline();
    let a = tl.insert_clip(t, place(PHOTO, 0, 0, 100)).unwrap();
    let b = tl.insert_clip(t, place(PHOTO, 0, 100, 100)).unwrap();
    assert_eq!(tl.merge_clips(a, b), Err(TimelineError::NotMergeable));
}

/// Every video clip on `t` plays only frames its media has.
fn assert_inside_media(tl: &Timeline, t: TrackId) -> Result<(), TestCaseError> {
    for c in tl.track(t).unwrap().clips() {
        if c.media == MediaId(VIDEO) {
            prop_assert!(c.source_start.0 >= 0, "{c:?}");
            prop_assert!(c.source_start.0 + c.duration.0 <= LEN, "{c:?}");
        }
    }
    Ok(())
}

proptest! {
    #[test]
    fn edits_never_leave_the_media(
        ops in proptest::collection::vec((0u8..5, 0usize..8, -50i64..300, -50i64..300), 0..80),
    ) {
        let (mut tl, t) = timeline();
        let _ = tl.insert_clip(t, place(VIDEO, 0, 0, LEN));
        for (op, pick, a, b) in ops {
            let ids: Vec<ClipId> = tl.track(t).unwrap().clips().iter().map(|c| c.id).collect();
            let Some(&id) = ids.get(pick % ids.len().max(1)) else { break };
            let _ = match op {
                0 => tl.split_clip(id, Time(a)).map(drop),
                1 => tl.trim_clip(id, Time(a), Time(b)),
                2 => tl.duplicate_clip(id).map(drop),
                3 => ids.get(pick % ids.len() + 1).map_or(Ok(()), |&r| tl.merge_clips(id, r)),
                _ => tl.move_clip(id, t, Time(a.max(0) * 10)),
            };
            assert_inside_media(&tl, t)?;
        }
    }

    #[test]
    fn a_still_clip_trims_either_way_without_a_source_error(
        media in prop_oneof![Just(PHOTO), Just(COLOR)],
        source in 0i64..1_000,
        trims in proptest::collection::vec((0i64..10_000, 1i64..10_000), 1..20),
    ) {
        // ENG-060: any edges in [0, ..) are fine for a photo or color, whatever its source offset.
        let (mut tl, t) = timeline();
        let c = tl.insert_clip(t, place(media, source, 5_000, 10)).unwrap();
        for (start, len) in trims {
            prop_assert_eq!(tl.trim_clip(c, Time(start), Time(start + len)), Ok(()));
            prop_assert!(tl.clip(c).unwrap().source_start.0 >= 0);
        }
    }

    #[test]
    fn still_split_then_start_trim_then_merge_restores_the_end(
        media in prop_oneof![Just(PHOTO), Just(COLOR)],
        source in 0i64..1_000,
        start in 0i64..10_000,
        duration in 2i64..1_000,
        cut_seed in 0i64..i64::MAX,
        left_seed in 0i64..i64::MAX,
    ) {
        // ENG-062: growing or shrinking the left half's start never stops the halves merging.
        let (mut tl, t) = timeline();
        let cut = 1 + cut_seed % (duration - 1);
        // The left half's new start: anywhere in [0, start + cut).
        let left = left_seed % (start + cut);
        let c = tl.insert_clip(t, place(media, source, start, duration)).unwrap();
        let right = tl.split_clip(c, Time(start + cut)).unwrap();
        tl.trim_clip(c, Time(left), Time(start + cut)).unwrap();
        prop_assert_eq!(tl.merge_clips(c, right), Ok(()));
        let clips = tl.track(t).unwrap().clips();
        prop_assert_eq!(clips.len(), 1);
        prop_assert_eq!((clips[0].start, clips[0].end()), (Time(left), Time(start + duration)));
        prop_assert!(clips[0].source_start.0 >= 0);
    }

    #[test]
    fn split_then_merge_restores_a_clip_inside_its_media(
        source in 0i64..LEN - 1,
        start in 0i64..1_000,
        cut_seed in 0i64..i64::MAX,
        len_seed in 0i64..i64::MAX,
    ) {
        let (mut tl, t) = timeline();
        // 2..=LEN - source ticks, so there is a point to cut at.
        let duration = 2 + len_seed % (LEN - source - 1);
        let cut = 1 + cut_seed % (duration - 1);
        let c = tl.insert_clip(t, place(VIDEO, source, start, duration)).unwrap();
        let before = tl.clone();
        let right = tl.split_clip(c, Time(start + cut)).unwrap();
        assert_inside_media(&tl, t)?;
        tl.merge_clips(c, right).unwrap();
        prop_assert_eq!(tl.track(t), before.track(t));
    }
}
