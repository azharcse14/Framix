//! Edges of transform validation and decode order (P1-029 review).

use framix_app::project::{ProjectError, decode, encode};
use framix_app::project_proto::{
    ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack, SavedTrackKind,
};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{
    ClipPlacement, ClipTransform, Crop, MediaId, Timeline, TimelineError, TrackFlags, TrackKind,
};
use prost::Message;

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

fn file(clips: Vec<SavedClip>, locked: bool) -> Vec<u8> {
    ProjectFile {
        format_version: 3,
        min_reader_version: 3,
        tracks: vec![SavedTrack {
            kind: SavedTrackKind::Video as i32,
            clips,
            locked,
            ..Default::default()
        }],
        media: vec![SavedMedia {
            id: 1,
            uri: "media/p.jpg".into(),
            kind: SavedMediaKind::Image as i32,
            width: 100,
            height: 50,
            ..Default::default()
        }],
        ..Default::default()
    }
    .encode_to_vec()
}

fn clip(start: i64, turns: u32) -> SavedClip {
    SavedClip {
        media_id: 1,
        start,
        duration: 10,
        turns,
        ..Default::default()
    }
}

#[test]
fn turns_that_do_not_fit_a_byte_are_refused_not_wrapped() {
    for turns in [256, u32::MAX] {
        assert!(matches!(
            decode(&file(vec![clip(0, turns)], false)),
            Err(ProjectError::Invalid(_))
        ));
    }
}

#[test]
fn a_crop_must_leave_a_pixel_vertically_too() {
    let mut tl = Timeline::default();
    tl.restore_media(MediaId(1), photo());
    let track = tl.add_track(TrackKind::Video);
    let c = tl
        .insert_clip(
            track,
            ClipPlacement {
                media: MediaId(1),
                source_start: Time(0),
                start: Time(0),
                duration: Time(10),
            },
        )
        .unwrap();
    let with = |top| ClipTransform {
        crop: Crop {
            top,
            ..Crop::default()
        },
        ..ClipTransform::default()
    };
    assert_eq!(
        tl.set_clip_transform(c, with(50)),
        Err(TimelineError::BadCrop)
    );
    assert_eq!(tl.set_clip_transform(c, with(49)), Ok(()));
}

#[test]
fn a_locked_track_keeps_its_transformed_clips_through_save_and_open() {
    let bytes = file(vec![clip(0, 1), clip(20, 2)], true);
    let t = decode(&bytes).unwrap();
    let track = &t.tracks()[0];
    assert_eq!(
        track.flags(),
        TrackFlags {
            locked: true,
            ..TrackFlags::default()
        }
    );
    assert_eq!(track.clips()[1].transform.turns, 2);
    let again = decode(&encode(&t)).unwrap();
    assert_eq!(again.tracks()[0].clips()[0].transform.turns, 1);
}

#[test]
fn many_transformed_clips_open_quickly() {
    let clips: Vec<_> = (0..50_000).map(|i| clip(i * 10, 1)).collect();
    let bytes = file(clips, false);
    let started = std::time::Instant::now();
    let t = decode(&bytes).unwrap();
    assert_eq!(t.tracks()[0].clips().len(), 50_000);
    // Linear decode takes milliseconds; a scan per clip takes far longer.
    assert!(started.elapsed().as_secs() < 2, "{:?}", started.elapsed());
}
