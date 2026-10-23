//! P1-011 review: untrusted ids, dangling media, the save-side media cap, and a full media
//! round trip.
use framix_app::project::{MAX_CLIPS, MAX_ID, ProjectError, decode, encode, encode_for_save};
use framix_app::project_proto::{ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::timeline::{MediaId, Timeline};
use prost::Message as _;

fn photo() -> Media {
    Media::validate(RawMedia {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 4,
        height: 3,
        rotation: 90,
        codec: String::new(),
    })
    .unwrap()
}

fn saved_media(id: u64) -> SavedMedia {
    SavedMedia {
        id,
        uri: "media/p.jpg".into(),
        kind: SavedMediaKind::Image as i32,
        width: 4,
        height: 3,
        ..Default::default()
    }
}

fn track_with_clip(media_id: u64) -> SavedTrack {
    SavedTrack {
        kind: 1,
        clips: vec![SavedClip {
            media_id,
            source_start: 0,
            start: 0,
            duration: 10,
            ..Default::default()
        }],
        ..Default::default()
    }
}

fn file(version: u32, media: Vec<SavedMedia>, tracks: Vec<SavedTrack>) -> Vec<u8> {
    ProjectFile {
        format_version: version,
        min_reader_version: version,
        media,
        tracks,
        ..Default::default()
    }
    .encode_to_vec()
}

#[test]
fn huge_ids_are_refused() {
    let bad = file(
        2,
        vec![saved_media(u64::MAX)],
        vec![track_with_clip(u64::MAX)],
    );
    assert!(matches!(decode(&bad), Err(ProjectError::IdOutOfRange(_))));
    let bad_v1 = file(1, vec![], vec![track_with_clip(MAX_ID + 1)]);
    assert!(matches!(
        decode(&bad_v1),
        Err(ProjectError::IdOutOfRange(_))
    ));
    let at_bound = file(2, vec![saved_media(MAX_ID)], vec![track_with_clip(MAX_ID)]);
    decode(&at_bound).unwrap();
}

#[test]
fn format_2_clips_must_use_listed_media() {
    let dangling = file(2, vec![saved_media(1)], vec![track_with_clip(2)]);
    assert!(matches!(
        decode(&dangling),
        Err(ProjectError::UnknownMedia(2))
    ));
    // Format 1 had no media list, so its clips may refer to anything.
    decode(&file(1, vec![], vec![track_with_clip(2)])).unwrap();
}

#[test]
fn media_and_clip_spans_survive_a_round_trip() {
    let mut tl = Timeline::default();
    tl.import(vec![photo()]).unwrap();
    let opened = decode(&encode(&tl)).unwrap();
    let (before, after) = (tl.tracks()[0].clips()[0], opened.tracks()[0].clips()[0]);
    assert_eq!(opened.media(after.media), tl.media(before.media));
    assert_eq!(
        (after.media, after.source_start, after.start, after.duration),
        (
            before.media,
            before.source_start,
            before.start,
            before.duration
        )
    );
}

#[test]
fn saving_more_media_than_open_allows_is_refused() {
    let mut tl = Timeline::default();
    for id in 1..=MAX_CLIPS as u64 + 1 {
        tl.restore_media(MediaId(id), photo());
    }
    assert!(matches!(encode_for_save(&tl), Err(ProjectError::TooLarge)));
}
