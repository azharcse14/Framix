//! CancelExport, ExportProgress and a cancelled ExportFinished (P1-035).

use std::sync::atomic::Ordering;

use framix_app::engine::Engine;
use framix_app::proto::{
    CancelExport, Command, Event, ExportProject, ImportMedia, MediaItem, MediaKind, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn ready() -> Engine {
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
    engine
}

fn export(engine: &mut Engine) {
    let e = run(
        engine,
        command::Kind::ExportProject(ExportProject {
            path: "/tmp/o.mp4".into(),
        }),
    );
    assert!(matches!(e.kind, Some(event::Kind::CommandAccepted(_))));
}

fn cancel(engine: &mut Engine) -> Event {
    run(engine, command::Kind::CancelExport(CancelExport {}))
}

fn failed(e: &Event) -> bool {
    matches!(e.kind, Some(event::Kind::CommandFailed(_)))
}

#[test]
fn cancel_without_an_export_is_refused() {
    let mut engine = ready();
    assert!(failed(&cancel(&mut engine)));
}

#[test]
fn cancel_sets_the_running_exports_flag_once() {
    let mut engine = ready();
    export(&mut engine);
    let job = engine.take_export_job().unwrap();
    assert!(!job.cancel.load(Ordering::SeqCst));
    assert!(matches!(
        cancel(&mut engine).kind,
        Some(event::Kind::CommandAccepted(_))
    ));
    assert!(job.cancel.load(Ordering::SeqCst));
    assert!(failed(&cancel(&mut engine)), "already cancelling");
    match engine.export_cancelled().kind {
        Some(event::Kind::ExportFinished(f)) => assert!(f.cancelled && !f.ok),
        other => panic!("expected ExportFinished, got {other:?}"),
    }
    assert!(failed(&cancel(&mut engine)), "nothing runs now");
    export(&mut engine);
    let next = engine.take_export_job().unwrap();
    assert!(
        !next.cancel.load(Ordering::SeqCst),
        "a new export starts uncancelled"
    );
}

#[test]
fn a_failed_export_is_not_cancelled() {
    let mut engine = ready();
    export(&mut engine);
    engine.take_export_job().unwrap();
    match engine.export_finished(Err("disk full".into())).kind {
        Some(event::Kind::ExportFinished(f)) => assert!(!f.ok && !f.cancelled),
        other => panic!("{other:?}"),
    }
}

#[test]
fn progress_becomes_an_event() {
    let mut engine = ready();
    match engine.export_progress(45, 90).kind {
        Some(event::Kind::ExportProgress(p)) => assert_eq!((p.frame, p.frames), (45, 90)),
        other => panic!("expected ExportProgress, got {other:?}"),
    }
}

#[test]
fn stopping_the_engine_cancels_the_running_export() {
    let mut engine = ready();
    engine.cancel_running_export();
    export(&mut engine);
    let job = engine.take_export_job().unwrap();
    engine.cancel_running_export();
    assert!(job.cancel.load(Ordering::SeqCst));
}
