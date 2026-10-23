//! Export settings in the project file (P1-032, format 5).

use framix_app::project::{FORMAT_VERSION, ProjectError, decode, encode};
use framix_app::project_proto::ProjectFile;
use framix_core::export::{Bitrate, ExportSettings, FrameRate, Resolution};
use framix_core::timeline::Timeline;
use prost::Message;

#[test]
fn settings_round_trip() {
    let mut tl = Timeline::default();
    let s = ExportSettings {
        resolution: Resolution::P2K,
        fps: FrameRate::F24,
        bitrate: Bitrate::kbps(12_000).unwrap(),
    };
    tl.set_export(s);
    assert_eq!(decode(&encode(&tl)).unwrap().export(), s);
    assert_eq!(FORMAT_VERSION, 5);
}

#[test]
fn older_files_get_the_default() {
    for bytes in [
        &include_bytes!("fixtures/project_v1.framix")[..],
        &include_bytes!("fixtures/project_v4.framix")[..],
    ] {
        assert_eq!(decode(bytes).unwrap().export(), ExportSettings::default());
    }
}

#[test]
fn the_v5_fixture_opens() {
    let bytes = std::fs::read(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/fixtures/project_v5.framix"
    ))
    .expect("v5 fixture");
    assert_eq!(
        ProjectFile::decode(bytes.as_slice())
            .unwrap()
            .format_version,
        5
    );
    assert_ne!(decode(&bytes).unwrap().export(), ExportSettings::default());
}

#[test]
fn tampered_settings_are_refused() {
    for (resolution, fps, kbps) in [(9, 1, 0), (1, 9, 0), (1, 1, 50), (1, 1, 200_000)] {
        let bytes = ProjectFile {
            format_version: 5,
            min_reader_version: 5,
            export_resolution: resolution,
            export_fps: fps,
            export_kbps: kbps,
            ..Default::default()
        }
        .encode_to_vec();
        assert!(
            matches!(decode(&bytes), Err(ProjectError::InvalidExport)),
            "{resolution} {fps} {kbps}"
        );
    }
}
