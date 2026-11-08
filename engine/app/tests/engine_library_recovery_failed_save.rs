//! Crash recovery notice after a failed autosave (P1-066 review): Home must not say the work
//! is saved when the last autosave before the crash failed.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ListProjects, NewProject, OpenLibrary, TrackKind, command, event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";

/// In-memory files shared across launches; project saves fail while `fail` is set (a full
/// disk), small marker writes still work.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
    fail: Arc<AtomicBool>,
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        if self.fail.load(Ordering::SeqCst) {
            return Err(io::ErrorKind::StorageFull.into());
        }
        self.put(path, bytes)
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

fn launch(store: &MemStore) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary { dir: DIR.into() }),
    );
    engine
}

fn add_track(engine: &mut Engine) {
    run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    );
}

fn recovered(engine: &mut Engine) -> String {
    match run(engine, command::Kind::ListProjects(ListProjects {})) {
        Some(event::Kind::ProjectList(list)) => list.recovered,
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

/// A saved project, then an edit whose autosave fails.
fn failed_save(store: &MemStore) -> Engine {
    let mut engine = launch(store);
    run(&mut engine, command::Kind::NewProject(NewProject {}));
    add_track(&mut engine);
    assert_eq!(engine.autosave(), None);
    store.fail.store(true, Ordering::SeqCst);
    add_track(&mut engine);
    assert!(engine.autosave().is_some(), "the failure is reported");
    engine
}

#[test]
fn a_crash_after_a_failed_autosave_claims_nothing() {
    let store = MemStore::default();
    drop(failed_save(&store));
    store.fail.store(false, Ordering::SeqCst);

    let mut next = launch(&store);
    assert_eq!(recovered(&mut next), "");
}

#[test]
fn a_crash_after_autosave_works_again_is_reported() {
    let store = MemStore::default();
    let mut first = failed_save(&store);
    store.fail.store(false, Ordering::SeqCst);
    assert_eq!(first.autosave(), None);
    drop(first);

    let mut next = launch(&store);
    assert_ne!(recovered(&mut next), "");
}
