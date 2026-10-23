//! Canvas position and scale in the project file (P1-030, format 4).

use framix_app::project::{ProjectError, decode, encode};
use framix_app::project_proto::{
    ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack, SavedTrackKind,
};
use prost::Message;

fn file(clip: SavedClip) -> Vec<u8> {
    ProjectFile {
        format_version: 4,
        min_reader_version: 4,
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
fn position_and_scale_round_trip() {
    let t = decode(&file(SavedClip {
        x: -1234,
        y: 567,
        scale: 2500,
        ..Default::default()
    }))
    .unwrap();
    let back = decode(&encode(&t)).unwrap();
    let tr = back.tracks()[0].clips()[0].transform;
    assert_eq!((tr.x, tr.y, tr.scale), (-1234, 567, 2500));
}

#[test]
fn a_saved_scale_of_zero_is_fit_and_older_files_are_centred() {
    let t = decode(&file(SavedClip::default())).unwrap();
    let tr = t.tracks()[0].clips()[0].transform;
    assert_eq!((tr.x, tr.y, tr.scale), (0, 0, 1000));
    let v3 = decode(include_bytes!("fixtures/project_v3.framix")).unwrap();
    assert_eq!(v3.tracks()[0].clips()[0].transform.scale, 1000);
}

#[test]
fn the_v4_fixture_opens() {
    let bytes = std::fs::read(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/fixtures/project_v4.framix"
    ))
    .expect("v4 fixture");
    assert_eq!(
        ProjectFile::decode(bytes.as_slice())
            .unwrap()
            .format_version,
        4
    );
    let t = decode(&bytes).unwrap();
    assert_ne!(t.tracks()[0].clips()[0].transform.scale, 1000);
}

#[test]
fn out_of_range_values_are_refused() {
    for bad in [
        SavedClip {
            x: 20001,
            ..Default::default()
        },
        SavedClip {
            scale: 5,
            ..Default::default()
        },
        SavedClip {
            scale: 10001,
            ..Default::default()
        },
    ] {
        assert!(matches!(decode(&file(bad)), Err(ProjectError::Invalid(_))));
    }
}
