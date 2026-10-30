//! Replies name the command they answer (ENG-056): CommandAccepted and CommandFailed echo the
//! command's id, so the UI can tell its own reply from another feature's.

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ExportProject, ImportMedia, MediaItem, MediaKind, RemoveClip, TrackKind,
    command, event,
};

#[test]
fn a_failure_echoes_the_command_id() {
    let mut engine = Engine::default();
    let e = engine.handle(Command {
        id: 41,
        kind: Some(command::Kind::RemoveClip(RemoveClip { clip_id: 999 })),
    });
    match e.kind {
        Some(event::Kind::CommandFailed(f)) => assert_eq!(f.command_id, 41),
        other => panic!("{other:?}"),
    }
}

#[test]
fn an_accepted_command_echoes_its_id() {
    let mut engine = Engine::default().with_export();
    engine.handle(Command {
        id: 1,
        kind: Some(command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "media/p.jpg".into(),
                kind: MediaKind::Image as i32,
                width: 1080,
                height: 1920,
                ..Default::default()
            }],
        })),
    });
    let e = engine.handle(Command {
        id: 7,
        kind: Some(command::Kind::ExportProject(ExportProject {
            path: "/out/a.mp4".into(),
        })),
    });
    match e.kind {
        Some(event::Kind::CommandAccepted(a)) => assert_eq!(a.command_id, 7),
        other => panic!("{other:?}"),
    }
}

#[test]
fn a_command_without_kind_still_echoes_its_id() {
    let mut engine = Engine::default();
    match engine.handle(Command { id: 9, kind: None }).kind {
        Some(event::Kind::CommandFailed(f)) => assert_eq!(f.command_id, 9),
        other => panic!("{other:?}"),
    }
}

#[test]
fn other_replies_are_unchanged() {
    let mut engine = Engine::default();
    let e = engine.handle(Command {
        id: 3,
        kind: Some(command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        })),
    });
    assert!(matches!(e.kind, Some(event::Kind::TimelineChanged(_))));
}
