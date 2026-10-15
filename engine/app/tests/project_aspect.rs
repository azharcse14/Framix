use framix_app::project::{ProjectError, decode, encode};
use framix_app::project_proto::ProjectFile;
use framix_core::aspect::AspectRatio;
use framix_core::timeline::Timeline;
use prost::Message as _;

fn sides(a: AspectRatio) -> (u32, u32) {
    (a.width(), a.height())
}

#[test]
fn the_aspect_ratio_round_trips() {
    let mut t = Timeline::default();
    t.set_aspect(AspectRatio::new(4, 5).unwrap());
    assert_eq!(sides(decode(&encode(&t)).unwrap().aspect()), (4, 5));
}

#[test]
fn files_without_an_aspect_open_with_the_default() {
    let t = decode(include_bytes!("fixtures/project_v1.framix")).unwrap();
    assert_eq!(sides(t.aspect()), (9, 16));
}

#[test]
fn invalid_aspect_ratios_in_files_are_refused() {
    let bytes = ProjectFile {
        format_version: 1,
        min_reader_version: 1,
        tracks: vec![],
        aspect_width: 5,
        aspect_height: 0,
        ..Default::default()
    }
    .encode_to_vec();
    assert!(matches!(decode(&bytes), Err(ProjectError::InvalidAspect)));
}
