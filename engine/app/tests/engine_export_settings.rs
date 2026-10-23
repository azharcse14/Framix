//! SetExportSettings and what TimelineChanged reports (P1-032).

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ExportFps, ExportResolution, SetAspectRatio, SetExportSettings,
    TimelineChanged, Undo, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn set(resolution: ExportResolution, fps: ExportFps, kbps: u32) -> command::Kind {
    command::Kind::SetExportSettings(SetExportSettings {
        resolution: resolution as i32,
        fps: fps as i32,
        kbps,
    })
}

#[test]
fn the_default_is_reported_with_its_frame_size() {
    let mut engine = Engine::default();
    let t = changed(run(
        &mut engine,
        command::Kind::GetTimeline(Default::default()),
    ));
    let e = t.export.expect("export info");
    assert_eq!(e.resolution, ExportResolution::ExportResolution1080p as i32);
    assert_eq!(e.fps, ExportFps::ExportFps30 as i32);
    assert_eq!(
        (e.kbps, e.width, e.height),
        (0, 1080, 1920),
        "9:16 canvas by default"
    );
    assert!(e.effective_kbps > 0);
}

#[test]
fn settings_are_one_undo_step_and_follow_the_canvas() {
    let mut engine = Engine::default();
    let t = changed(run(
        &mut engine,
        set(
            ExportResolution::ExportResolution4k,
            ExportFps::ExportFps60,
            40_000,
        ),
    ));
    let e = t.export.unwrap();
    assert_eq!(
        (e.width, e.height, e.kbps, e.effective_kbps),
        (2160, 3840, 40_000, 40_000)
    );
    let t = changed(run(
        &mut engine,
        command::Kind::SetAspectRatio(SetAspectRatio {
            width: 16,
            height: 9,
        }),
    ));
    let e = t.export.unwrap();
    assert_eq!((e.width, e.height), (3840, 2160));
    run(&mut engine, command::Kind::Undo(Undo {}));
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(
        t.export.unwrap().resolution,
        ExportResolution::ExportResolution1080p as i32
    );
    assert!(!t.can_undo);
}

#[test]
fn the_same_settings_are_no_step() {
    let mut engine = Engine::default();
    let t = changed(run(
        &mut engine,
        set(
            ExportResolution::ExportResolution1080p,
            ExportFps::ExportFps30,
            0,
        ),
    ));
    assert!(!t.can_undo);
}

#[test]
fn bad_settings_are_refused() {
    let mut engine = Engine::default();
    for bad in [
        set(ExportResolution::Unspecified, ExportFps::ExportFps30, 0),
        set(
            ExportResolution::ExportResolution720p,
            ExportFps::Unspecified,
            0,
        ),
        set(
            ExportResolution::ExportResolution720p,
            ExportFps::ExportFps30,
            999,
        ),
        command::Kind::SetExportSettings(SetExportSettings {
            resolution: 9,
            fps: 1,
            kbps: 0,
        }),
    ] {
        assert!(matches!(
            run(&mut engine, bad).kind,
            Some(event::Kind::CommandFailed(_))
        ));
    }
}
