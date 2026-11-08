//! Crash recovery notice (P1-066): a library project open when the engine stopped without
//! closing is reported once, in the first ProjectList after OpenLibrary.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ListProjects, NewProject, OpenLibrary, OpenProject, TrackKind, command,
    event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";

/// In-memory files shared by every engine of one test (the same device across launches).
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
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

/// An app launch: an engine on the shared files with the library open.
fn launch(store: &MemStore) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary { dir: DIR.into() }),
    );
    assert!(matches!(e, Some(event::Kind::CommandAccepted(_))), "{e:?}");
    engine
}

/// ListProjects: the listed ids and the recovered one.
fn list(engine: &mut Engine) -> (Vec<String>, String) {
    match run(engine, command::Kind::ListProjects(ListProjects {})) {
        Some(event::Kind::ProjectList(list)) => (
            list.projects.into_iter().map(|p| p.id).collect(),
            list.recovered,
        ),
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn ids(store: &MemStore) -> Vec<String> {
    let files = store.files.lock().unwrap();
    let mut ids: Vec<String> = files
        .keys()
        .filter(|p| p.extension().is_some_and(|e| e == "framix"))
        .map(|p| p.file_stem().unwrap().to_str().unwrap().to_owned())
        .collect();
    ids.sort();
    ids
}

/// Starts a new project with one track, autosaves it, and returns its id.
fn new_edited(engine: &mut Engine, store: &MemStore) -> String {
    let before = ids(store);
    run(engine, command::Kind::NewProject(NewProject {}));
    run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    );
    assert_eq!(engine.autosave(), None);
    ids(store)
        .into_iter()
        .find(|id| !before.contains(id))
        .expect("the new project's file")
}

#[test]
fn a_project_open_at_a_crash_is_reported_once_at_the_next_launch() {
    let store = MemStore::default();
    let mut first = launch(&store);
    let id = new_edited(&mut first, &store);
    // A crash: the engine goes away without close().
    drop(first);

    let mut next = launch(&store);
    assert_eq!(list(&mut next), (vec![id.clone()], id));
    assert_eq!(list(&mut next).1, "", "reported only once");

    // Nor at the launch after that.
    drop(next);
    let mut third = launch(&store);
    assert_eq!(list(&mut third).1, "");
}

#[test]
fn a_project_opened_from_home_and_open_at_a_crash_is_reported() {
    let store = MemStore::default();
    let mut first = launch(&store);
    let a = new_edited(&mut first, &store);
    let b = new_edited(&mut first, &store);
    list(&mut first);
    let e = run(
        &mut first,
        command::Kind::OpenProject(OpenProject {
            path: String::new(),
            id: a.clone(),
        }),
    );
    assert!(matches!(e, Some(event::Kind::TimelineChanged(_))), "{e:?}");
    drop(first);

    let mut next = launch(&store);
    let (listed, recovered) = list(&mut next);
    assert_eq!(listed.len(), 2, "{listed:?} has {b}");
    assert_eq!(recovered, a);
}

#[test]
fn a_clean_stop_reports_nothing() {
    let store = MemStore::default();
    let mut first = launch(&store);
    new_edited(&mut first, &store);
    first.close();
    drop(first);

    let mut next = launch(&store);
    assert_eq!(list(&mut next).1, "");
}

#[test]
fn a_crash_on_home_reports_nothing() {
    let store = MemStore::default();
    let mut first = launch(&store);
    new_edited(&mut first, &store);
    // Back on Home: the editor closed.
    list(&mut first);
    drop(first);

    let mut next = launch(&store);
    assert_eq!(list(&mut next).1, "");
}

#[test]
fn a_crash_in_an_untouched_new_project_reports_nothing() {
    let store = MemStore::default();
    let mut first = launch(&store);
    new_edited(&mut first, &store);
    // A second, untouched project has no file to recover.
    run(&mut first, command::Kind::NewProject(NewProject {}));
    assert_eq!(first.autosave(), None);
    drop(first);

    let mut next = launch(&store);
    assert_eq!(list(&mut next).1, "");
}
