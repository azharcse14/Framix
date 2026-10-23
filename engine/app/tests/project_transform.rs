//! Clip transforms in the project file (P1-029, format 3).

use framix_app::project::{FORMAT_VERSION, ProjectError, decode, encode};
use framix_app::project_proto::{
    ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack, SavedTrackKind,
};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, ClipTransform, Crop, MediaId, Timeline, TrackKind};
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

fn transformed() -> (Timeline, ClipTransform) {
    let mut tl = Timeline::default();
    tl.restore_media(MediaId(1), photo());
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
    let t = ClipTransform {
        turns: 3,
        flip_h: false,
        flip_v: true,
        crop: Crop {
            left: 1,
            top: 2,
            right: 3,
            bottom: 4,
        },
    };
    tl.set_clip_transform(clip, t).unwrap();
    (tl, t)
}

#[test]
fn transforms_survive_save_and_open() {
    let (tl, t) = transformed();
    let back = decode(&encode(&tl)).unwrap();
    assert_eq!(back.tracks()[0].clips()[0].transform, t);
}

#[test]
fn older_formats_open_with_the_identity() {
    for bytes in [
        &include_bytes!("fixtures/project_v1.framix")[..],
        &include_bytes!("fixtures/project_v2.framix")[..],
    ] {
        let t = decode(bytes).unwrap();
        for clip in t.tracks().iter().flat_map(|t| t.clips()) {
            assert_eq!(clip.transform, ClipTransform::default());
        }
    }
}

#[test]
fn the_v3_fixture_opens_with_its_transform() {
    let bytes = std::fs::read(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/fixtures/project_v3.framix"
    ))
    .expect("v3 fixture");
    let file = ProjectFile::decode(bytes.as_slice()).unwrap();
    assert_eq!(file.format_version, 3);
    let t = decode(&bytes).unwrap();
    assert_ne!(t.tracks()[0].clips()[0].transform, ClipTransform::default());
    assert_eq!(FORMAT_VERSION, 3);
}

/// A format-3 file with one 100 x 50 photo clip carrying `clip`'s transform fields.
fn file_with(clip: SavedClip) -> Vec<u8> {
    ProjectFile {
        format_version: 3,
        min_reader_version: 3,
        tracks: vec![SavedTrack {
            kind: SavedTrackKind::Video as i32,
            clips: vec![SavedClip {
                media_id: 1,
                start: 0,
                duration: 1000,
                ..clip
            }],
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

#[test]
fn tampered_transforms_are_refused() {
    for bad in [
        SavedClip {
            turns: 4,
            ..Default::default()
        },
        SavedClip {
            crop_left: 50,
            crop_right: 50,
            ..Default::default()
        },
        SavedClip {
            crop_bottom: u32::MAX,
            ..Default::default()
        },
    ] {
        assert!(matches!(
            decode(&file_with(bad)),
            Err(ProjectError::Invalid(_))
        ));
    }
}
