use framix_app::project::{FORMAT_VERSION, ProjectError, decode, encode};
use framix_app::project_proto::{ProjectFile, SavedClip, SavedTrack, SavedTrackKind};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TrackKind};
use prost::Message as _;

/// Kind and clip placements (media, source start, start, duration) of every track.
type Shape = Vec<(TrackKind, Vec<(u64, i64, i64, i64)>)>;

/// The timeline's shape, ignoring ids (they are reassigned on load).
fn shape(t: &Timeline) -> Shape {
    t.tracks()
        .iter()
        .map(|track| {
            let clips = track
                .clips()
                .iter()
                .map(|c| (c.media.0, c.source_start.0, c.start.0, c.duration.0))
                .collect();
            (track.kind(), clips)
        })
        .collect()
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
fn encode_then_decode_keeps_tracks_and_clips() {
    let mut t = Timeline::default();
    let video = t.add_track(TrackKind::Video);
    let audio = t.add_track(TrackKind::Audio);
    t.insert_clip(video, place(7, 0, 0, 100)).unwrap();
    t.insert_clip(audio, place(9, 5, 20, 30)).unwrap();
    t.insert_clip(video, place(8, 10, 100, 50)).unwrap();
    assert_eq!(shape(&decode(&encode(&t)).unwrap()), shape(&t));
}

#[test]
fn the_v1_fixture_opens() {
    let t = decode(include_bytes!("fixtures/project_v1.framix")).unwrap();
    assert_eq!(
        shape(&t),
        [
            (TrackKind::Video, vec![(7, 0, 0, 100), (8, 10, 100, 50)]),
            (TrackKind::Audio, vec![(9, 0, 20, 30)]),
        ]
    );
}

#[test]
fn encoded_files_carry_the_format_version() {
    let file = ProjectFile::decode(encode(&Timeline::default()).as_slice()).unwrap();
    assert_eq!(
        (file.format_version, file.min_reader_version),
        (FORMAT_VERSION, 1)
    );
}

#[test]
fn garbage_is_refused() {
    assert!(matches!(
        decode(&[0xff, 0xff, 0xff]),
        Err(ProjectError::Corrupt(_))
    ));
}

fn file(min_reader_version: u32, tracks: Vec<SavedTrack>) -> Vec<u8> {
    ProjectFile {
        format_version: min_reader_version.max(1),
        min_reader_version,
        tracks,
        ..Default::default()
    }
    .encode_to_vec()
}

fn track(kind: SavedTrackKind, clips: Vec<SavedClip>) -> SavedTrack {
    SavedTrack {
        kind: kind as i32,
        clips,
        ..Default::default()
    }
}

fn clip(start: i64, duration: i64) -> SavedClip {
    SavedClip {
        media_id: 1,
        source_start: 0,
        start,
        duration,
    }
}

#[test]
fn files_from_a_newer_app_are_refused() {
    let bytes = file(FORMAT_VERSION + 1, vec![]);
    assert!(matches!(decode(&bytes), Err(ProjectError::TooNew(v)) if v == FORMAT_VERSION + 1));
}

#[test]
fn invalid_clips_and_kinds_are_refused() {
    let overlap = file(
        1,
        vec![track(
            SavedTrackKind::Video,
            vec![clip(0, 100), clip(50, 10)],
        )],
    );
    assert!(matches!(decode(&overlap), Err(ProjectError::Invalid(_))));
    let empty_clip = file(1, vec![track(SavedTrackKind::Audio, vec![clip(0, 0)])]);
    assert!(matches!(decode(&empty_clip), Err(ProjectError::Invalid(_))));
    let unknown = file(1, vec![track(SavedTrackKind::Unspecified, vec![])]);
    assert!(matches!(
        decode(&unknown),
        Err(ProjectError::UnknownTrackKind(0))
    ));
}
