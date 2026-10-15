//! Every project format version has a fixture that must keep opening (testing.md).
use framix_app::project::decode;
use framix_core::media::MediaKind;

#[test]
fn the_v2_fixture_opens_with_its_media() {
    let t = decode(include_bytes!("fixtures/project_v2.framix")).unwrap();
    let clip = t.tracks()[0].clips()[0];
    let m = t.media(clip.media).expect("clip refers to listed media");
    assert_eq!(
        (m.uri(), m.kind(), m.size(), m.rotation()),
        ("media/v2.mov", MediaKind::Video, (1280, 720), 90)
    );
    assert_eq!(clip.duration, m.duration());
}
