use framix_core::media::{
    MAX_IMPORT, Media, MediaError, MediaKind, PHOTO_DEFAULT_DURATION, RawMedia,
};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{Timeline, TimelineError, TrackFlags, TrackKind};
use proptest::prelude::*;

fn video(uri: &str, ms: i64) -> RawMedia {
    RawMedia {
        uri: uri.into(),
        kind: MediaKind::Video,
        duration_value: ms,
        duration_timescale: 1000,
        width: 1920,
        height: 1080,
        rotation: 90,
        codec: "hvc1".into(),
    }
}

fn image(uri: &str) -> RawMedia {
    RawMedia {
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        codec: String::new(),
        ..video(uri, 0)
    }
}

fn ok(raw: RawMedia) -> Media {
    Media::validate(raw).unwrap()
}

#[test]
fn valid_media_is_accepted_and_durations_are_exact() {
    let v = ok(video("content://media/external/video/42", 1500));
    assert_eq!(v.duration(), Time(TICKS_PER_SECOND * 3 / 2));
    assert_eq!(
        (v.size(), v.rotation(), v.codec()),
        ((1920, 1080), 90, "hvc1")
    );
    let i = ok(image("media/0b7c-4d1e.heic"));
    assert_eq!((i.kind(), i.duration()), (MediaKind::Image, Time(0)));
}

#[test]
fn only_content_uris_and_plain_media_paths_are_allowed() {
    let long = format!("content://{}", "a".repeat(2049));
    for uri in [
        "",
        "../x.mov",
        "/var/mobile/media/a.mov",
        "file:///a.mov",
        "media/../a.mov",
        "media/a",
        "media/a.toolong",
        "media/a b.mov",
        "media/sub/a.mov",
        "MEDIA/a.mov",
        "http://x/a.mov",
        long.as_str(),
    ] {
        assert_eq!(
            Media::validate(video(uri, 1000)),
            Err(MediaError::BadUri),
            "{uri:?}"
        );
    }
}

#[test]
fn sizes_rotations_codecs_and_durations_are_bounded() {
    let bad = |f: &dyn Fn(&mut RawMedia), err| {
        let mut raw = video("media/a.mov", 1000);
        f(&mut raw);
        assert_eq!(Media::validate(raw), Err(err));
    };
    bad(&|r| r.width = 0, MediaError::BadSize);
    bad(&|r| r.height = 16_385, MediaError::BadSize);
    bad(&|r| r.rotation = 45, MediaError::BadRotation);
    bad(&|r| r.codec = "x".repeat(17), MediaError::BadCodec);
    bad(&|r| r.codec = "hév1".into(), MediaError::BadCodec);
    bad(&|r| r.duration_value = 0, MediaError::BadDuration);
    bad(&|r| r.duration_timescale = 0, MediaError::BadDuration);
    bad(
        &|r| r.duration_value = 24 * 3600 * 1000 + 1,
        MediaError::BadDuration,
    );
    bad(&|r| r.duration_value = i64::MAX, MediaError::BadDuration);
    ok(video("media/a.mov", 24 * 3600 * 1000));
}

#[test]
fn import_appends_back_to_back_on_a_new_video_track() {
    let mut tl = Timeline::default();
    let clips = tl
        .import(vec![
            ok(video("media/a.mov", 2000)),
            ok(image("media/b.jpg")),
        ])
        .unwrap();
    assert_eq!(clips.len(), 2);
    let track = &tl.tracks()[0];
    assert_eq!(track.kind(), TrackKind::Video);
    let spans: Vec<(i64, i64)> = track
        .clips()
        .iter()
        .map(|c| (c.start.0, c.duration.0))
        .collect();
    let two_s = 2 * TICKS_PER_SECOND;
    assert_eq!(spans, [(0, two_s), (two_s, PHOTO_DEFAULT_DURATION.0)]);
    for c in track.clips() {
        assert!(
            tl.media(c.media).is_some(),
            "every clip's media is registered"
        );
        assert_eq!(c.source_start, Time(0));
    }
}

#[test]
fn import_appends_after_existing_clips_and_skips_locked_tracks() {
    let mut tl = Timeline::default();
    tl.import(vec![ok(video("media/a.mov", 1000))]).unwrap();
    tl.import(vec![ok(video("media/b.mov", 1000))]).unwrap();
    assert_eq!(tl.tracks().len(), 1);
    assert_eq!(tl.tracks()[0].clips()[1].start, Time(TICKS_PER_SECOND));

    let first = tl.tracks()[0].id();
    let locked = TrackFlags {
        locked: true,
        ..TrackFlags::default()
    };
    tl.set_track_flags(first, locked).unwrap();
    tl.import(vec![ok(image("media/c.png"))]).unwrap();
    assert_eq!(tl.tracks().len(), 2, "a locked video track is skipped");
    assert_eq!(tl.tracks()[1].clips()[0].start, Time(0));
}

#[test]
fn oversized_imports_change_nothing() {
    let mut tl = Timeline::default();
    let before = tl.clone();
    let many = (0..=MAX_IMPORT).map(|_| ok(image("media/a.jpg"))).collect();
    assert_eq!(tl.import(many), Err(TimelineError::TooManyMedia));
    assert_eq!(tl, before);
    assert_eq!(tl.import(vec![]), Ok(vec![]));
}

proptest! {
    #[test]
    fn imported_clips_are_back_to_back_in_order(ms in proptest::collection::vec(1i64..100_000, 1..20)) {
        let mut tl = Timeline::default();
        let batch = ms.iter().map(|&m| ok(video("media/a.mov", m))).collect();
        tl.import(batch).unwrap();
        let clips = tl.tracks()[0].clips();
        prop_assert_eq!(clips.len(), ms.len());
        let mut at = 0;
        for (c, m) in clips.iter().zip(&ms) {
            prop_assert_eq!(c.start.0, at);
            prop_assert_eq!(c.duration.0, m * (TICKS_PER_SECOND / 1000));
            prop_assert!(tl.media(c.media).is_some());
            at += c.duration.0;
        }
        prop_assert_eq!(tl.duration().0, at);
    }
}
