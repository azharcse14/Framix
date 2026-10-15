use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, Event, NewProject, OpenProject, SaveProject, TimelineChanged, TrackKind,
    command, event,
};
use framix_app::store::ProjectStore;

/// In-memory files; clones share them, so a test can inspect what the engine wrote.
#[derive(Clone, Default)]
struct MemStore(Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>);

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        self.0.lock().unwrap().insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        let files = self.0.lock().unwrap();
        files
            .get(path)
            .cloned()
            .ok_or_else(|| io::ErrorKind::NotFound.into())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn add_track(engine: &mut Engine, kind: TrackKind) -> TimelineChanged {
    changed(run(
        engine,
        command::Kind::AddTrack(AddTrack { kind: kind as i32 }),
    ))
}

fn save(path: &str) -> command::Kind {
    command::Kind::SaveProject(SaveProject { path: path.into() })
}

fn open(path: &str) -> command::Kind {
    command::Kind::OpenProject(OpenProject { path: path.into() })
}

#[test]
fn save_new_open_restores_the_project_without_undo() {
    let store = MemStore::default();
    let mut engine = Engine::with_store(Box::new(store.clone()));
    add_track(&mut engine, TrackKind::Video);
    add_track(&mut engine, TrackKind::Audio);

    let saved = run(&mut engine, save("/p/a.framix"));
    assert!(
        matches!(saved.kind, Some(event::Kind::ProjectSaved(_))),
        "{saved:?}"
    );
    assert!(
        store
            .0
            .lock()
            .unwrap()
            .contains_key(Path::new("/p/a.framix"))
    );

    let fresh = changed(run(&mut engine, command::Kind::NewProject(NewProject {})));
    assert!(fresh.tracks.is_empty());
    assert!(!fresh.can_undo && !fresh.can_redo);

    let opened = changed(run(&mut engine, open("/p/a.framix")));
    let kinds: Vec<i32> = opened.tracks.iter().map(|t| t.kind).collect();
    assert_eq!(kinds, [TrackKind::Video as i32, TrackKind::Audio as i32]);
    assert!(!opened.can_undo, "opening starts a new history");
}

#[test]
fn a_failed_open_keeps_the_current_project() {
    let store = MemStore::default();
    store
        .save(Path::new("/p/bad.framix"), &[0xff, 0xff])
        .unwrap();
    let mut engine = Engine::with_store(Box::new(store));
    add_track(&mut engine, TrackKind::Video);

    for path in ["/p/missing.framix", "/p/bad.framix"] {
        let e = run(&mut engine, open(path));
        assert!(
            matches!(e.kind, Some(event::Kind::CommandFailed(_))),
            "{path}: {e:?}"
        );
    }
    let t = changed(run(
        &mut engine,
        command::Kind::GetTimeline(Default::default()),
    ));
    assert_eq!(t.tracks.len(), 1);
    assert!(t.can_undo, "undo history survives a failed open");
}

#[test]
fn an_engine_without_a_store_refuses_save_and_open() {
    let mut engine = Engine::default();
    for kind in [save("/p/a.framix"), open("/p/a.framix")] {
        let e = run(&mut engine, kind);
        assert!(
            matches!(e.kind, Some(event::Kind::CommandFailed(_))),
            "{e:?}"
        );
    }
}
