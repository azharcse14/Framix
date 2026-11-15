//! P1-127: a panicking store save is an autosave failure like any other: one report per
//! streak shared with failed saves, and the crash marker says the work is unsaved.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ListProjects, NewProject, OpenLibrary, TrackKind, command, event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";
const WORKS: u8 = 0;
const FAILS: u8 = 1;
const PANICS: u8 = 2;

/// In-memory files shared across launches; project saves work, fail, or panic by `mode`,
/// small marker writes always work.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
    mode: Arc<AtomicU8>,
}

impl MemStore {
    fn set(&self, mode: u8) {
        self.mode.store(mode, Ordering::SeqCst);
    }
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        match self.mode.load(Ordering::SeqCst) {
            FAILS => Err(io::ErrorKind::StorageFull.into()),
            PANICS => panic!("save panicked (test)"),
            _ => self.put(path, bytes),
        }
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        let files = self.files.lock().unwrap();
        Ok(files.get(path).ok_or(io::ErrorKind::NotFound)?.clone())
    }

    fn list(&self, dir: &Path) -> io::Result<Vec<(PathBuf, SystemTime)>> {
        let files = self.files.lock().unwrap();
        Ok(files
            .keys()
            .filter(|path| path.parent() == Some(dir))
            .map(|path| (path.clone(), SystemTime::UNIX_EPOCH))
            .collect())
    }

    fn put(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        self.files
            .lock()
            .unwrap()
            .insert(path.to_owned(), bytes.to_vec());
        Ok(())
    }

    fn remove(&self, path: &Path) -> io::Result<()> {
        self.files.lock().unwrap().remove(path);
        Ok(())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn add_track(engine: &mut Engine) {
    run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    );
}

fn launch(store: &MemStore) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary {
            dir: DIR.into(),
            cache_dir: String::new(),
        }),
    );
    engine
}

/// A library engine with a new project whose first autosave worked.
fn saved_project(store: &MemStore) -> Engine {
    let mut engine = launch(store);
    run(&mut engine, command::Kind::NewProject(NewProject {}));
    add_track(&mut engine);
    assert_eq!(engine.autosave(), None);
    engine
}

fn recovered(engine: &mut Engine) -> String {
    match run(engine, command::Kind::ListProjects(ListProjects::default())) {
        Some(event::Kind::ProjectList(list)) => list.recovered,
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

#[test]
fn failures_and_panics_in_one_streak_are_reported_once() {
    let store = MemStore::default();
    let mut engine = saved_project(&store);
    store.set(FAILS);
    add_track(&mut engine);
    assert!(engine.autosave().is_some(), "the failure is reported");
    store.set(PANICS);
    add_track(&mut engine);
    assert_eq!(
        engine.autosave(),
        None,
        "a panic in the same streak stays quiet"
    );
    store.set(FAILS);
    assert_eq!(engine.autosave(), None, "and so does the next failure");
}

#[test]
fn a_panicking_save_is_reported_once_until_saved() {
    let store = MemStore::default();
    let mut engine = saved_project(&store);
    store.set(PANICS);
    add_track(&mut engine);
    assert!(engine.autosave().is_some(), "the panic is reported");
    assert_eq!(engine.autosave(), None, "only once");
    store.set(WORKS);
    assert_eq!(engine.autosave(), None, "saved");
    store.set(PANICS);
    add_track(&mut engine);
    assert!(engine.autosave().is_some(), "a new streak is reported");
}

#[test]
fn a_crash_after_a_panicking_autosave_claims_nothing() {
    let store = MemStore::default();
    let mut engine = saved_project(&store);
    store.set(PANICS);
    add_track(&mut engine);
    assert!(engine.autosave().is_some(), "the panic is reported");
    drop(engine);
    store.set(WORKS);

    let mut next = launch(&store);
    assert_eq!(recovered(&mut next), "");
}
