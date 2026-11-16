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
