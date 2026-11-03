//! ChangeExportSettings (P1-082): unset fields keep their value, so quick edits of different
//! settings never undo each other.

use framix_app::engine::Engine;
use framix_app::proto::{
    ChangeExportSettings, Command, ExportFps, ExportInfo, ExportResolution, TimelineChanged, Undo,
    command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn changed(e: Option<event::Kind>) -> TimelineChanged {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn change(
    resolution: Option<ExportResolution>,
    fps: Option<ExportFps>,
    kbps: Option<u32>,
) -> command::Kind {
    command::Kind::ChangeExportSettings(ChangeExportSettings {
        resolution: resolution.map(|r| r as i32),
        fps: fps.map(|f| f as i32),
        kbps,
    })
}

fn info(e: Option<event::Kind>) -> ExportInfo {
    changed(e).export.expect("export info")
}

#[test]
fn each_change_keeps_the_other_settings() {
    let mut engine = Engine::default();
    let e = info(run(
        &mut engine,
        change(Some(ExportResolution::ExportResolution4k), None, None),
    ));
    assert_eq!(
        (e.resolution, e.fps, e.kbps),
        (
            ExportResolution::ExportResolution4k as i32,
            ExportFps::ExportFps30 as i32,
            0
        )
    );
    let e = info(run(
        &mut engine,
        change(None, Some(ExportFps::ExportFps60), None),
    ));
    assert_eq!(
        (e.resolution, e.fps),
        (
            ExportResolution::ExportResolution4k as i32,
            ExportFps::ExportFps60 as i32
        ),
        "the earlier 4K stays"
    );
    let e = info(run(&mut engine, change(None, None, Some(20_000))));
    assert_eq!(
        (e.resolution, e.fps, e.kbps),
        (
            ExportResolution::ExportResolution4k as i32,
            ExportFps::ExportFps60 as i32,
            20_000
        )
    );
    let e = info(run(&mut engine, change(None, None, Some(0))));
    assert_eq!(e.kbps, 0, "0 is automatic");

    let e = info(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(e.kbps, 20_000, "each change is one undo step");
}

#[test]
fn nothing_set_is_no_step_and_bad_values_are_refused() {
    let mut engine = Engine::default();
    assert!(!changed(run(&mut engine, change(None, None, None))).can_undo);
    for bad in [
        command::Kind::ChangeExportSettings(ChangeExportSettings {
            resolution: Some(0),
            fps: None,
            kbps: None,
        }),
        command::Kind::ChangeExportSettings(ChangeExportSettings {
            resolution: None,
            fps: Some(42),
            kbps: None,
        }),
        change(None, None, Some(999)),
    ] {
        let e = run(&mut engine, bad);
        assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{e:?}");
    }
}
