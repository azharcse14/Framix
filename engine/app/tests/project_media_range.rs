//! ENG-053: an untrusted file is held to the same rule as an edit: a video clip stays inside its
//! media. Format 1 media is sized from its clips (SYS-039), so its files still open.
use framix_app::project::{ProjectError, decode};
use framix_app::project_proto::{ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack};
use framix_core::timeline::TimelineError;
use prost::Message as _;

fn video(duration: i64) -> SavedMedia {
    SavedMedia {
        id: 1,
        uri: "media/v.mp4".into(),
        kind: SavedMediaKind::Video as i32,
        duration,
        width: 4,
        height: 3,
        ..Default::default()
    }
}

fn file(version: u32, media: Vec<SavedMedia>, source_start: i64, duration: i64) -> Vec<u8> {
    ProjectFile {
        format_version: version,
        min_reader_version: version,
        media,
        tracks: vec![SavedTrack {
            kind: 1,
            clips: vec![SavedClip {
                media_id: 1,
                source_start,
                start: 0,
                duration,
                ..Default::default()
            }],
            ..Default::default()
        }],
        ..Default::default()
    }
    .encode_to_vec()
}

#[test]
fn a_clip_past_its_listed_media_end_is_refused() {
    assert!(matches!(
        decode(&file(2, vec![video(100)], 50, 51)),
        Err(ProjectError::Invalid(TimelineError::PastMediaEnd))
    ));
    decode(&file(2, vec![video(100)], 50, 50)).unwrap();
}

#[test]
fn format_1_media_is_long_enough_for_its_clips() {
    let tl = decode(&file(1, vec![], 50, 51)).unwrap();
    let clip = &tl.tracks()[0].clips()[0];
    assert_eq!((clip.source_start.0, clip.duration.0), (50, 51));
}
