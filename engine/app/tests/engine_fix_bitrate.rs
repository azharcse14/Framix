//! FixBitrate (P1-083): automatic bitrate off keeps the bitrate the engine uses now, for the
//! settings the engine has now.

use framix_app::engine::Engine;
use framix_app::proto::{
    ChangeExportSettings, Command, ExportInfo, ExportResolution, FixBitrate, Undo, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn info(e: Option<event::Kind>) -> ExportInfo {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t.export.expect("export info"),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn fixes_the_current_automatic_bitrate() {
    let mut engine = Engine::default();
    let four_k = ChangeExportSettings {
        resolution: Some(ExportResolution::ExportResolution4k as i32),
        fps: None,
        kbps: None,
    };
    let auto = info(run(
        &mut engine,
        command::Kind::ChangeExportSettings(four_k),
    ));
    assert_eq!(auto.kbps, 0);
    let fixed = info(run(&mut engine, command::Kind::FixBitrate(FixBitrate {})));
    assert_eq!(fixed.kbps, auto.effective_kbps, "4K's bitrate, not 1080p's");
    assert_eq!(fixed.effective_kbps, auto.effective_kbps);

    // Already fixed: nothing changes, no step.
    let again = info(run(&mut engine, command::Kind::FixBitrate(FixBitrate {})));
    assert_eq!(again.kbps, fixed.kbps);
    let undone = info(run(&mut engine, command::Kind::Undo(Undo {})));
    assert_eq!(undone.kbps, 0, "one step back is automatic again");
}
