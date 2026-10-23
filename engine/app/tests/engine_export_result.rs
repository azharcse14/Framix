//! The worker's result becomes one ExportFinished (P1-035 review).

use framix_app::engine::Engine;
use framix_app::export::ExportError;
use framix_app::proto::{ExportFinished, event};

fn finished(engine: &mut Engine, result: Result<(), ExportError>) -> ExportFinished {
    match engine.export_result(result).kind {
        Some(event::Kind::ExportFinished(f)) => f,
        other => panic!("expected ExportFinished, got {other:?}"),
    }
}

#[test]
fn each_result_maps_to_its_finish() {
    let mut engine = Engine::default().with_export();
    let ok = finished(&mut engine, Ok(()));
    assert!(ok.ok && !ok.cancelled && ok.reason.is_empty());
    let cancelled = finished(&mut engine, Err(ExportError::Cancelled));
    assert!(!cancelled.ok && cancelled.cancelled && cancelled.reason.is_empty());
    let failed = finished(&mut engine, Err(ExportError::Failed("disk full".into())));
    assert!(!failed.ok && !failed.cancelled);
    assert_eq!(failed.reason, "disk full");
}
