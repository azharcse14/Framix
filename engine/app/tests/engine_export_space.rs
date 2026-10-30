//! Export pre-flight (P1-040, OVL-020): an export that would not fit in the free storage is
//! refused before it starts, with how much it needs and how much is free.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::export::{FreeSpace, bytes_needed};
use framix_app::proto::{
    Command, Event, ExportFinished, ExportProject, ImportMedia, MediaItem, MediaKind, command,
    event,
};

/// Reports `free` for every path and records the paths it was asked about.
struct Space {
    free: Option<u64>,
    asked: Arc<Mutex<Vec<String>>>,
}

impl FreeSpace for Space {
    fn free_bytes(&self, path: &str) -> Option<u64> {
        self.asked.lock().unwrap().push(path.to_owned());
        self.free
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

/// An exporting engine with one 3 s photo clip; returns it and the export's estimated size.
fn setup(free: Option<u64>) -> (Engine, u64, Arc<Mutex<Vec<String>>>) {
    let asked = Arc::default();
    let mut engine = Engine::default()
        .with_export()
        .with_free_space(Box::new(Space {
            free,
            asked: Arc::clone(&asked),
        }));
    let e = run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "media/p.jpg".into(),
                kind: MediaKind::Image as i32,
                duration_value: 0,
                duration_timescale: 0,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: String::new(),
            }],
        }),
    );
    let estimated = match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t.export.unwrap().estimated_bytes,
        other => panic!("{other:?}"),
    };
    (engine, estimated, asked)
}

fn export(engine: &mut Engine) -> Event {
    run(
        engine,
        command::Kind::ExportProject(ExportProject {
            path: "/out/a.mp4".into(),
        }),
    )
}

#[test]
fn the_margin_is_a_tenth_plus_32_mib() {
    assert_eq!(bytes_needed(0), 32 << 20);
    assert_eq!(bytes_needed(1_000_000_000), 1_100_000_000 + (32 << 20));
    assert_eq!(bytes_needed(u64::MAX), u64::MAX, "saturates");
}

#[test]
fn an_export_that_does_not_fit_is_refused_with_the_sizes() {
    let (mut engine, estimated, asked) = setup(Some(1000));
    let e = export(&mut engine);
    assert_eq!(
        e.kind,
        Some(event::Kind::ExportFinished(ExportFinished {
            ok: false,
            reason: "not enough storage".into(),
            cancelled: false,
            needed_bytes: bytes_needed(estimated),
            free_bytes: 1000,
        }))
    );
    assert_eq!(*asked.lock().unwrap(), vec!["/out/a.mp4".to_owned()]);
    assert!(engine.take_export_job().is_none(), "nothing started");
    // Not running, so a second try is checked again rather than refused as a duplicate.
    let again = export(&mut engine);
    assert!(matches!(again.kind, Some(event::Kind::ExportFinished(_))));
}

#[test]
fn an_export_that_fits_starts() {
    let (mut engine, _, _) = setup(None);
    assert!(matches!(
        export(&mut engine).kind,
        Some(event::Kind::CommandAccepted(_))
    ));
    let (mut engine, estimated, _) = setup(Some(u64::MAX));
    assert!(bytes_needed(estimated) < u64::MAX);
    assert!(matches!(
        export(&mut engine).kind,
        Some(event::Kind::CommandAccepted(_))
    ));
    assert!(engine.take_export_job().is_some());
}

#[test]
fn just_enough_space_is_enough() {
    let (_, estimated, _) = setup(None);
    let (mut engine, _, _) = setup(Some(bytes_needed(estimated)));
    assert!(matches!(
        export(&mut engine).kind,
        Some(event::Kind::CommandAccepted(_))
    ));
}
