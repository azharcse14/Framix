//! Replace a clip's media (P1-031).

use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{
    ClipId, ClipPlacement, ClipTransform, MediaId, Timeline, TimelineError, TrackFlags, TrackId,
    TrackKind,
};
use proptest::prelude::*;

fn media(uri: &str, kind: MediaKind, ms: i64) -> Media {
    Media::validate(RawMedia {
        uri: uri.into(),
        kind,
        duration_value: ms,
        duration_timescale: if ms > 0 { 1000 } else { 0 },
        width: 100,
        height: 50,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap()
}

fn video(ms: i64) -> Media {
    media("media/v.mov", MediaKind::Video, ms)
}

/// A 4 s video clip at 1 s, with a transform and a source offset.
fn setup() -> (Timeline, TrackId, ClipId) {
    let mut tl = Timeline::default();
    tl.restore_media(MediaId(1), video(10_000));
    let track = tl.add_track(TrackKind::Video);
    let second = video(1000).duration().0;
    let clip = tl
        .insert_clip(
            track,
            ClipPlacement {
                media: MediaId(1),
                source_start: Time(2 * second),
                start: Time(second),
                duration: Time(4 * second),
            },
        )
        .unwrap();
    let t = ClipTransform {
        turns: 1,
        ..ClipTransform::default()
    };
    tl.set_clip_transform(clip, t).unwrap();
    (tl, track, clip)
}

fn the(tl: &Timeline, clip: ClipId) -> framix_core::timeline::Clip {
    *tl.tracks()
        .iter()
        .flat_map(|t| t.clips())
        .find(|c| c.id == clip)
        .unwrap()
}

#[test]
fn a_longer_video_takes_the_clip_s_place() {
    let (mut tl, _, clip) = setup();
    let before = the(&tl, clip);
    let id = tl.replace_clip(clip, video(5000)).unwrap();
    let after = the(&tl, clip);
    assert_ne!(id, MediaId(1));
    assert_eq!(after.media, id);
    assert_eq!(
        (after.start, after.duration),
        (before.start, before.duration)
    );
    assert_eq!(after.source_start, Time(0));
    assert_eq!(after.transform, ClipTransform::default());
    assert!(
        tl.media(MediaId(1)).is_some(),
        "the old media stays for undo"
    );
    assert_eq!(tl.media(id).unwrap().uri(), "media/v.mov");
}

#[test]
fn a_shorter_video_is_refused_and_nothing_changes() {
    let (mut tl, _, clip) = setup();
    let before = tl.clone();
    assert_eq!(
        tl.replace_clip(clip, video(3000)),
        Err(TimelineError::MediaTooShort)
    );
    assert_eq!(tl, before);
    // No id was used up: the next id is the same as without the attempt.
    let mut other = before.clone();
    assert_eq!(
        tl.add_track(TrackKind::Audio),
        other.add_track(TrackKind::Audio)
    );
}

#[test]
fn a_photo_fits_any_clip() {
    let (mut tl, _, clip) = setup();
    let id = tl
        .replace_clip(clip, media("media/p.jpg", MediaKind::Image, 0))
        .unwrap();
    assert_eq!(the(&tl, clip).media, id);
}

#[test]
fn locked_tracks_and_unknown_clips_are_refused() {
    let (mut tl, track, clip) = setup();
    assert_eq!(
        tl.replace_clip(ClipId(999), video(5000)),
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
        tl.replace_clip(clip, video(5000)),
        Err(TimelineError::TrackLocked(track))
    );
}

proptest! {
    #[test]
    fn place_and_length_never_change(extra_ms in 0i64..100_000) {
        let (mut tl, _, clip) = setup();
        let before = the(&tl, clip);
        let clips = tl.tracks()[0].clips().len();
        tl.replace_clip(clip, video(4000 + extra_ms)).unwrap();
        let after = the(&tl, clip);
        prop_assert_eq!((after.start, after.duration), (before.start, before.duration));
        prop_assert_eq!(tl.tracks()[0].clips().len(), clips);
    }
}
