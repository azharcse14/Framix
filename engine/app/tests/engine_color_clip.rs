//! Color (blank) clips through the UI contract and the project file (P1-048).

use framix_app::engine::Engine;
use framix_app::project::{decode, encode};
use framix_app::proto::{Command, Event, ImportMedia, MediaItem, MediaKind, command, event};
use framix_core::media::MediaKind as CoreKind;

fn color_item(rgba: u32) -> MediaItem {
    MediaItem {
        kind: MediaKind::Color as i32,
        color: rgba,
        ..Default::default()
    }
}

fn import(engine: &mut Engine, items: Vec<MediaItem>) -> Event {
    engine.handle(Command {
        id: 1,
        kind: Some(command::Kind::ImportMedia(ImportMedia { items })),
    })
}

#[test]
fn importing_a_color_item_adds_a_color_clip() {
    let mut engine = Engine::default();
    match import(&mut engine, vec![color_item(0x3366_99ff)]).kind {
        Some(event::Kind::TimelineChanged(t)) => {
            let clip = &t.tracks[0].clips[0];
            assert_eq!(clip.media_kind, MediaKind::Color as i32);
            assert_eq!(clip.color, 0x3366_99ff);
        }
        other => panic!("{other:?}"),
    }
}

#[test]
fn a_color_item_with_a_file_is_refused() {
    let mut engine = Engine::default();
    let mut item = color_item(0xff);
    item.uri = "media/a.jpg".into();
    assert!(matches!(
        import(&mut engine, vec![item]).kind,
        Some(event::Kind::CommandFailed(_))
    ));
}

#[test]
fn other_clips_report_no_color() {
    let mut engine = Engine::default();
    let photo = MediaItem {
        uri: "media/p.jpg".into(),
        kind: MediaKind::Image as i32,
        width: 10,
        height: 10,
        ..Default::default()
    };
    match import(&mut engine, vec![photo]).kind {
        Some(event::Kind::TimelineChanged(t)) => assert_eq!(t.tracks[0].clips[0].color, 0),
        other => panic!("{other:?}"),
    }
}

#[test]
fn the_color_survives_save_and_open() {
    let mut timeline = framix_core::timeline::Timeline::default();
    timeline
        .import(vec![framix_core::media::Media::color(0x1234_56ff)])
        .unwrap();
    let back = decode(&encode(&timeline)).unwrap();
    let media: Vec<_> = back
        .all_media()
        .map(|(_, m)| (m.kind(), m.color()))
        .collect();
    assert_eq!(media, vec![(CoreKind::Color, 0x1234_56ff)]);
}
