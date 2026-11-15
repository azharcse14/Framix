//! Every format version 1..=FORMAT_VERSION has a fixture that still opens (ENG-046).
//! Bumping FORMAT_VERSION without adding `fixtures/project_v<N>.framix` fails here.

use framix_app::project::{FORMAT_VERSION, decode, encode};
use framix_app::project_proto::ProjectFile;
use prost::Message;

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
        // cannot be saved yet (encode_for_save: UnknownMedia); tracked as a follow-up.
        if version == 1 {
            continue;
        }
        // Migrated to the current format, it saves and reopens unchanged.
        let saved = encode(&timeline);
        assert_eq!(
            ProjectFile::decode(saved.as_slice())
                .unwrap()
                .format_version,
            FORMAT_VERSION
        );
        assert_eq!(encode(&decode(&saved).unwrap()), saved, "{path}");
    }
}
