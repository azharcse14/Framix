//! ApplyExportPreset (P1-037): canvas and export settings change together, as one undo step.

use framix_app::engine::Engine;
use framix_app::proto::{
    ApplyExportPreset, Command, ExportFps, ExportPreset, ExportResolution, SetExportSettings,
    TimelineChanged, Undo, command, event,
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

fn apply(preset: ExportPreset) -> command::Kind {
    command::Kind::ApplyExportPreset(ApplyExportPreset {
        preset: preset as i32,
    })
}

/// (aspect width, aspect height, resolution, fps, kbps)
fn shape(t: &TimelineChanged) -> (u32, u32, i32, i32, u32) {
    let e = t.export.as_ref().expect("export info");
    (t.aspect_width, t.aspect_height, e.resolution, e.fps, e.kbps)
}

#[test]
fn a_preset_sets_canvas_and_export_in_one_step() {
    let mut engine = Engine::default();
    let custom = SetExportSettings {
        resolution: ExportResolution::ExportResolution4k as i32,
        fps: ExportFps::ExportFps60 as i32,
        kbps: 20_000,
    };
    let before = shape(&changed(run(
        &mut engine,
        command::Kind::SetExportSettings(custom),
    )));

    let t = changed(run(&mut engine, apply(ExportPreset::Youtube)));
    let hd = ExportResolution::ExportResolution1080p as i32;
    let fps30 = ExportFps::ExportFps30 as i32;
    assert_eq!(shape(&t), (16, 9, hd, fps30, 0));

    let t = changed(run(&mut engine, apply(ExportPreset::InstagramFeed)));
    assert_eq!(shape(&t), (4, 5, hd, fps30, 0));
    let t = changed(run(&mut engine, apply(ExportPreset::ShortVideo)));
    assert_eq!(shape(&t), (9, 16, hd, fps30, 0));

    run(&mut engine, command::Kind::Undo(Undo {}));
    run(&mut engine, command::Kind::Undo(Undo {}));
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(shape(&t), before, "each preset is one undo step");
}

#[test]
fn an_unknown_preset_is_refused() {
    let mut engine = Engine::default();
    for preset in [0, 99] {
        let e = run(
            &mut engine,
            command::Kind::ApplyExportPreset(ApplyExportPreset { preset }),
        );
        assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{preset}: {e:?}");
    }
}
