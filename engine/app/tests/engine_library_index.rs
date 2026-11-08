//! The library index (names, folders) falls back to its backup, and is never overwritten when
//! it can't be read or a newer app wrote it (P1-015 review).

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use framix_app::engine::Engine;
use framix_app::project_proto::{LibraryEntry, LibraryIndex};
use framix_app::proto::{
    AddTrack, Command, ListProjects, NewProject, OpenLibrary, ProjectSummary, RenameProject,
    TrackKind, command, event,
};
use framix_app::store::ProjectStore;
use prost::Message as _;

const DIR: &str = "/data/projects";

/// In-memory files with one backup each; reading the index can be made to fail.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
    index_unreadable: Arc<Mutex<bool>>,
}

fn index() -> PathBuf {
    PathBuf::from(format!("{DIR}/library.index"))
}

fn backup(path: &Path) -> PathBuf {
    PathBuf::from(format!("{}.bak1", path.display()))
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        let mut files = self.files.lock().unwrap();
        if let Some(old) = files.remove(path) {
            files.insert(backup(path), old);
        }
        files.insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        if path == index() && *self.index_unreadable.lock().unwrap() {
            return Err(io::ErrorKind::PermissionDenied.into());
        }
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

    fn backups(&self, path: &Path) -> Vec<PathBuf> {
        vec![backup(path)]
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

fn library(store: &MemStore) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    let dir = OpenLibrary { dir: DIR.into() };
    run(&mut engine, command::Kind::OpenLibrary(dir));
    engine
}

fn list(engine: &mut Engine) -> Vec<ProjectSummary> {
    let op = ListProjects::default();
    match run(engine, command::Kind::ListProjects(op)) {
        Some(event::Kind::ProjectList(list)) => list.projects,
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn rename(engine: &mut Engine, id: &str, name: &str) -> Option<event::Kind> {
    let op = RenameProject {
        id: id.into(),
        name: name.into(),
    };
    run(engine, command::Kind::RenameProject(op))
}

fn accepted(e: Option<event::Kind>) -> bool {
    matches!(e, Some(event::Kind::CommandAccepted(_)))
}

/// Starts a project and returns its id: the one not listed before (all files share a time).
fn project(engine: &mut Engine) -> String {
    let before: Vec<String> = list(engine).into_iter().map(|p| p.id).collect();
    run(engine, command::Kind::NewProject(NewProject {}));
    let add = AddTrack {
        kind: TrackKind::Video as i32,
    };
    run(engine, command::Kind::AddTrack(add));
    list(engine)
        .into_iter()
        .map(|p| p.id)
        .find(|id| !before.contains(id))
        .unwrap()
}

#[test]
fn a_damaged_index_falls_back_to_its_backup() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine);
    assert!(accepted(rename(&mut engine, &id, "x")));
    // A second write puts the first into the backup; then the index itself breaks.
    assert!(accepted(rename(&mut engine, &id, "y")));
    store
        .files
        .lock()
        .unwrap()
        .insert(index(), b"garbage".to_vec());
    assert_eq!(list(&mut engine)[0].name, "x");
}

#[test]
fn an_unreadable_index_is_not_overwritten() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let a = project(&mut engine);
    let b = project(&mut engine);
    assert!(accepted(rename(&mut engine, &a, "kept")));
    *store.index_unreadable.lock().unwrap() = true;
    assert!(!accepted(rename(&mut engine, &b, "other")));
    *store.index_unreadable.lock().unwrap() = false;
    let projects = list(&mut engine);
    let name = |id: &str| projects.iter().find(|p| p.id == id).unwrap().name.clone();
    assert_eq!(name(&a), "kept");
    assert_eq!(name(&b), "");
}

#[test]
fn a_newer_apps_index_is_listed_without_names_and_never_rewritten() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine);
    let newer = LibraryIndex {
        format_version: 2,
        min_reader_version: 2,
        projects: vec![LibraryEntry {
            id: id.clone(),
            name: "from the future".into(),
            ..LibraryEntry::default()
        }],
    }
    .encode_to_vec();
    store.save(&index(), &newer).unwrap();

    assert_eq!(list(&mut engine).len(), 1, "projects still listed");
    assert!(!accepted(rename(&mut engine, &id, "x")));
    assert_eq!(store.load(&index()).unwrap(), newer);
}
