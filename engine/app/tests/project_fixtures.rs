//! Every format version 1..=FORMAT_VERSION has a fixture that still opens (ENG-046).
//! Bumping FORMAT_VERSION without adding `fixtures/project_v<N>.framix` fails here.

use framix_app::project::{FORMAT_VERSION, decode, encode_for_save};
use framix_app::project_proto::ProjectFile;
use framix_core::timeline::{Timeline, TrackFlags};
use prost::Message;

/// What a project file holds, comparable (Timeline itself has no PartialEq).
fn contents(t: &Timeline) -> impl std::fmt::Debug + PartialEq + '_ {
    (
        t.tracks(),
        t.all_media().collect::<Vec<_>>(),
        t.aspect(),
        t.export(),
    )
}

#[test]
fn every_format_version_has_a_fixture_that_migrates() {
    for version in 1..=FORMAT_VERSION {
        let path = format!(
            "{}/tests/fixtures/project_v{version}.framix",
            env!("CARGO_MANIFEST_DIR")
        );
        let bytes = std::fs::read(&path).unwrap_or_else(|e| panic!("{path}: {e}"));
        let file = ProjectFile::decode(bytes.as_slice()).expect("protobuf");
        assert_eq!(file.format_version, version, "{path}");
        let timeline = decode(&bytes).unwrap_or_else(|e| panic!("{path}: {e}"));
        // Format 1 clips refer to media the file never listed, so a migrated v1 project
        // cannot be saved yet (encode_for_save: UnknownMedia); SYS-039.
        if version == 1 {
            continue;
        }
        // Migrated to the current format, it saves and reopens with the same contents.
        let saved = encode_for_save(&timeline).unwrap_or_else(|e| panic!("{path}: {e}"));
        assert_eq!(
            ProjectFile::decode(saved.as_slice())
                .unwrap()
                .format_version,
            FORMAT_VERSION
        );
        let reopened = decode(&saved).unwrap_or_else(|e| panic!("{path}: {e}"));
        assert_eq!(contents(&reopened), contents(&timeline), "{path}");
    }
}

#[test]
fn v1_tracks_open_unmuted_visible_and_unlocked() {
    let t = decode(include_bytes!("fixtures/project_v1.framix")).unwrap();
    assert!(!t.tracks().is_empty());
    for track in t.tracks() {
        assert_eq!(track.flags(), TrackFlags::default());
    }
}
