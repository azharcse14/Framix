//! Format 5 files written before P1-078 may hold a moved or scaled color clip (the canvas
//! gestures sent it and the engine took it); they open with the transform dropped.
use framix_app::project::decode;
use framix_app::project_proto::{
    ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack, SavedTrackKind,
};
use framix_core::timeline::ClipTransform;
use prost::Message;

#[test]
fn a_saved_color_clip_transform_is_dropped_on_open() {
    let bytes = ProjectFile {
        format_version: 5,
        min_reader_version: 5,
        tracks: vec![SavedTrack {
            kind: SavedTrackKind::Video as i32,
            clips: vec![SavedClip {
                media_id: 1,
                start: 0,
                duration: 1000,
                x: 500,
                scale: 2000,
                flip_h: true,
                ..Default::default()
            }],
            ..Default::default()
        }],
        media: vec![SavedMedia {
            id: 1,
            kind: SavedMediaKind::Color as i32,
            color: 0xff00_00ff,
            ..Default::default()
        }],
        ..Default::default()
    }
    .encode_to_vec();
    let t = decode(&bytes).expect("opens");
    assert_eq!(t.tracks()[0].clips()[0].transform, ClipTransform::default());
}
