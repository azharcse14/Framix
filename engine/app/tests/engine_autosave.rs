//! Autosave and crash recovery (P1-038).

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, EnableAutosave, Event, TrackKind, Undo, command, event,
};
use framix_app::store::ProjectStore;

const PATH: &str = "/data/autosave.framix";

/// In-memory files plus a write counter; clones share them.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
    writes: Arc<Mutex<usize>>,
    fail: bool,
}

impl MemStore {
    fn writes(&self) -> usize {
        *self.writes.lock().unwrap()
    }
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        if self.fail {
            return Err(io::ErrorKind::StorageFull.into());
        }
        *self.writes.lock().unwrap() += 1;
        self.files
            .lock()
            .unwrap()
            .insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        self.files
            .lock()
            .unwrap()
            .get(path)
            .cloned()
            .ok_or_else(|| io::ErrorKind::NotFound.into())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn enable(engine: &mut Engine) -> Event {
    run(
        engine,
        command::Kind::EnableAutosave(EnableAutosave { path: PATH.into() }),
    )
}

fn add_track(engine: &mut Engine) {
    let e = run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Audio as i32,
        }),
    );
    assert!(matches!(e.kind, Some(event::Kind::TimelineChanged(_))));
}

fn tracks(e: &Event) -> (usize, bool) {
    match &e.kind {
        Some(event::Kind::TimelineChanged(t)) => (t.tracks.len(), t.can_undo),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn nothing_is_written_while_autosave_is_off() {
    let store = MemStore::default();
    let mut engine = Engine::with_store(Box::new(store.clone()));
    add_track(&mut engine);
    assert_eq!(engine.autosave(), None);
    assert_eq!(store.writes(), 0);
}

#[test]
fn only_changes_are_written() {
    let store = MemStore::default();
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert_eq!(tracks(&enable(&mut engine)), (0, false));
    assert_eq!(engine.autosave(), None);
    assert_eq!(store.writes(), 0, "nothing changed yet");
    add_track(&mut engine);
    assert_eq!(engine.autosave(), None);
    assert_eq!(store.writes(), 1);
    engine.autosave();
    assert_eq!(store.writes(), 1, "already saved");
    run(&mut engine, command::Kind::Undo(Undo {}));
    engine.autosave();
    assert_eq!(store.writes(), 2, "undo is a change too");
}

#[test]
fn enabling_recovers_the_saved_project() {
    let store = MemStore::default();
    let mut first = Engine::with_store(Box::new(store.clone()));
    enable(&mut first);
    add_track(&mut first);
    add_track(&mut first);
    first.autosave();

    let mut second = Engine::with_store(Box::new(store.clone()));
    assert_eq!(tracks(&enable(&mut second)), (2, false));
    assert_eq!(second.autosave(), None);
    assert_eq!(store.writes(), 1, "a recovered project is not dirty");
}

#[test]
fn a_broken_file_is_refused_and_never_overwritten() {
    let store = MemStore::default();
    store
        .files
        .lock()
        .unwrap()
        .insert(PATH.into(), vec![0xff, 0xff, 0xff]);
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert!(matches!(
        enable(&mut engine).kind,
        Some(event::Kind::CommandFailed(_))
    ));
    add_track(&mut engine);
    engine.autosave();
    assert_eq!(store.load(Path::new(PATH)).unwrap(), vec![0xff, 0xff, 0xff]);
}

#[test]
fn a_failed_autosave_is_reported_without_the_path() {
    let store = MemStore {
        fail: true,
        ..MemStore::default()
    };
    let mut engine = Engine::with_store(Box::new(store));
    enable(&mut engine);
    add_track(&mut engine);
    match engine.autosave().and_then(|e| e.kind) {
        Some(event::Kind::CommandFailed(f)) => {
            assert!(f.reason.contains("autosave"), "{}", f.reason);
            assert!(!f.reason.contains("data"), "no path: {}", f.reason);
        }
        other => panic!("expected CommandFailed, got {other:?}"),
    }
}
