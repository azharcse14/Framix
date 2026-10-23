//! ExportProject: validation, the job, and ExportFinished (P1-034).

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ExportProject, ImportMedia, MediaItem, MediaKind, command, event,
};

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn export(engine: &mut Engine) -> Event {
    run(
        engine,
        command::Kind::ExportProject(ExportProject {
            path: "/tmp/out.mp4".into(),
        }),
    )
}

fn import_photo(engine: &mut Engine) {
    run(
        engine,
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
}

fn failed(e: &Event) -> bool {
    matches!(e.kind, Some(event::Kind::CommandFailed(_)))
}

#[test]
fn an_engine_without_an_encoder_refuses() {
    let mut engine = Engine::default();
    import_photo(&mut engine);
    assert!(failed(&export(&mut engine)));
    assert!(engine.take_export_job().is_none());
}

#[test]
fn an_empty_timeline_is_refused() {
    let mut engine = Engine::default().with_export();
    assert!(failed(&export(&mut engine)));
    assert!(engine.take_export_job().is_none());
}

#[test]
fn an_export_is_accepted_once_and_finishes_with_one_event() {
    let mut engine = Engine::default().with_export();
    import_photo(&mut engine);
    assert!(matches!(
        export(&mut engine).kind,
        Some(event::Kind::CommandAccepted(_))
    ));
    let job = engine.take_export_job().expect("a job");
    assert_eq!(job.path, "/tmp/out.mp4");
    assert!(job.timeline.duration().0 > 0);
    assert!(engine.take_export_job().is_none(), "taken once");

    assert!(failed(&export(&mut engine)), "one export at a time");
    assert!(engine.take_export_job().is_none());

    match engine.export_finished(Err("disk full".into())).kind {
        Some(event::Kind::ExportFinished(f)) => {
            assert!(!f.ok);
            assert_eq!(f.reason, "disk full");
        }
        other => panic!("expected ExportFinished, got {other:?}"),
    }
    assert!(matches!(
        export(&mut engine).kind,
        Some(event::Kind::CommandAccepted(_))
    ));
    engine.take_export_job().unwrap();
    match engine.export_finished(Ok(())).kind {
        Some(event::Kind::ExportFinished(f)) => assert!(f.ok && f.reason.is_empty()),
        other => panic!("expected ExportFinished, got {other:?}"),
    }
}

#[test]
fn the_job_is_a_snapshot() {
    let mut engine = Engine::default().with_export();
    import_photo(&mut engine);
    export(&mut engine);
    let job = engine.take_export_job().unwrap();
    import_photo(&mut engine);
    assert_eq!(job.timeline.duration().0 * 2, {
        // The live timeline grew; the job's did not.
        let mut e2 = Engine::default();
        import_photo(&mut e2);
        import_photo(&mut e2);
        match run(&mut e2, command::Kind::GetTimeline(Default::default())).kind {
            Some(event::Kind::TimelineChanged(t)) => {
                t.tracks[0].clips.iter().map(|c| c.duration).sum::<i64>()
            }
            other => panic!("{other:?}"),
        }
    });
}
