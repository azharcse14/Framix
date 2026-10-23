//! ExportProject refuses paths that are not an .mp4 file (P1-034 review): the platform
//! replaces whatever is at the path.

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ExportProject, ImportMedia, MediaItem, MediaKind, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

#[test]
fn only_mp4_paths_are_accepted() {
    let mut engine = Engine::default().with_export();
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "content://media/external/images/1".into(),
                kind: MediaKind::Image as i32,
                width: 1080,
                height: 1920,
                ..Default::default()
            }],
        }),
    );
    for bad in ["", ".mp4", "/tmp/", "/tmp/project.framix", "/tmp/a.MP4.txt"] {
        let e = run(
            &mut engine,
            command::Kind::ExportProject(ExportProject { path: bad.into() }),
        );
        assert!(
            matches!(e.kind, Some(event::Kind::CommandFailed(_))),
            "{bad:?}"
        );
        assert!(engine.take_export_job().is_none(), "{bad:?}");
    }
    let e = run(
        &mut engine,
        command::Kind::ExportProject(ExportProject {
            path: "/tmp/out.mp4".into(),
        }),
    );
    assert!(matches!(e.kind, Some(event::Kind::CommandAccepted(_))));
}
