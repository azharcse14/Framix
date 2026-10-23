//! Review fixes for P1-009: untrusted project files must not open as empty projects or make
//! loading slow or huge.
mod common;

use framix_app::project::{MAX_CLIPS, MAX_TRACKS, ProjectError, decode, encode};
use framix_app::project_proto::{ProjectFile, SavedClip, SavedTrack, SavedTrackKind};
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TrackKind};
use prost::Message as _;

fn file(tracks: Vec<SavedTrack>) -> Vec<u8> {
    ProjectFile {
        format_version: 1,
        min_reader_version: 1,
        tracks,
        ..Default::default()
    }
    .encode_to_vec()
}

fn video(clips: Vec<SavedClip>) -> SavedTrack {
    SavedTrack {
        kind: SavedTrackKind::Video as i32,
        clips,
        ..Default::default()
    }
}

fn clip(start: i64) -> SavedClip {
    SavedClip {
        media_id: 1,
        source_start: 0,
        start,
        duration: 1,
        ..Default::default()
    }
}

#[test]
fn empty_or_unversioned_files_are_refused() {
    assert!(matches!(decode(&[]), Err(ProjectError::MissingVersion)));
    let unversioned = ProjectFile {
        format_version: 0,
        min_reader_version: 0,
        tracks: vec![video(vec![clip(0)])],
        ..Default::default()
    }
    .encode_to_vec();
    assert!(matches!(
        decode(&unversioned),
        Err(ProjectError::MissingVersion)
    ));
}

#[test]
fn clips_out_of_order_are_refused() {
    let reversed = file(vec![video(vec![clip(10), clip(0)])]);
    assert!(matches!(decode(&reversed), Err(ProjectError::Unsorted)));
}

#[test]
fn too_many_tracks_or_clips_are_refused() {
    let tracks = file((0..=MAX_TRACKS).map(|_| video(vec![])).collect());
    assert!(matches!(decode(&tracks), Err(ProjectError::TooLarge)));
    let clips = file(vec![video((0..=MAX_CLIPS as i64).map(clip).collect())]);
    assert!(matches!(decode(&clips), Err(ProjectError::TooLarge)));
}

#[test]
fn ids_after_open_never_collide_with_loaded_ones() {
    let mut t = Timeline::default();
    let track = t.add_track(TrackKind::Video);
    let placement = |start| ClipPlacement {
        media: MediaId(1),
        source_start: Time(0),
        start: Time(start),
        duration: Time(1),
    };
    common::register(&mut t, &[1]); // P1-011: saved clips need registered media
    t.insert_clip(track, placement(0)).unwrap();
    t.insert_clip(track, placement(1)).unwrap();

    let mut opened = decode(&encode(&t)).unwrap();
    let used: Vec<u64> = opened
        .tracks()
        .iter()
        .flat_map(|t| std::iter::once(t.id().0).chain(t.clips().iter().map(|c| c.id.0)))
        .collect();
    let new_track = opened.add_track(TrackKind::Audio).0;
    assert!(
        !used.contains(&new_track),
        "{new_track} reused from {used:?}"
    );
}
