//! A format 5 project with a color clip (P1-048) keeps opening (testing.md: fixtures).
use framix_app::project::decode;
use framix_core::media::MediaKind;

#[test]
fn the_color_clip_fixture_opens_with_its_color() {
    let t = decode(include_bytes!("fixtures/project_v5_color.framix")).unwrap();
    let clip = t.tracks()[0].clips()[0];
    let m = t.media(clip.media).expect("clip refers to listed media");
    assert_eq!(
        (m.kind(), m.color(), m.uri()),
        (MediaKind::Color, 0xff00_00ff, "")
    );
}
