//! P1-067 review: a project recovered from a backup is written back at once (so it never
//! vanishes from Home or is lost to a crash), and files that are not damaged (from a newer app,
//! or one the OS won't read) are never set aside or replaced.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use framix_app::engine::Engine;
use framix_app::project::{FORMAT_VERSION, encode_for_save};
use framix_app::project_proto::ProjectFile;
use framix_app::proto::{
    Command, EnableAutosave, Event, ListProjects, OpenLibrary, OpenProject, command, event,
};
use framix_app::store::ProjectStore;
use framix_core::timeline::{Timeline, TrackKind};
use prost::Message as _;

const BROKEN: &[u8] = &[0xff, 0xff, 0xff];
/// Reading this file is refused, as the OS might.
const DENIED: &str = "/data/denied.framix";

/// In-memory files with `.bak1`/`.bak2` backups and a `.broken` slot.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
}

fn suffixed(path: &Path, suffix: &str) -> PathBuf {
    PathBuf::from(format!("{}{suffix}", path.display()))
}

impl MemStore {
    fn put(&self, path: impl Into<PathBuf>, bytes: &[u8]) {
        self.files
            .lock()
            .unwrap()
            .insert(path.into(), bytes.to_vec());
    }

    fn get(&self, path: impl AsRef<Path>) -> Option<Vec<u8>> {
        self.files.lock().unwrap().get(path.as_ref()).cloned()
    }
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        let mut files = self.files.lock().unwrap();
        if let Some(current) = files.get(path).cloned() {
            if let Some(old) = files.remove(&suffixed(path, ".bak1")) {
                files.insert(suffixed(path, ".bak2"), old);
            }
            files.insert(suffixed(path, ".bak1"), current);
        }
        files.insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        if path == Path::new(DENIED) {
            return Err(io::ErrorKind::PermissionDenied.into());
        }
        self.get(path).ok_or_else(|| io::ErrorKind::NotFound.into())
    }

    fn list(&self, dir: &Path) -> io::Result<Vec<(PathBuf, SystemTime)>> {
        Ok(self
            .files
            .lock()
            .unwrap()
            .keys()
            .filter(|p| p.parent() == Some(dir))
            .map(|p| (p.clone(), SystemTime::UNIX_EPOCH))
            .collect())
    }

    fn backups(&self, path: &Path) -> Vec<PathBuf> {
        vec![suffixed(path, ".bak1"), suffixed(path, ".bak2")]
    }

    fn set_aside(&self, path: &Path) -> io::Result<()> {
        let mut files = self.files.lock().unwrap();
        let bytes = files.remove(path).ok_or(io::ErrorKind::NotFound)?;
        files.insert(suffixed(path, ".broken"), bytes);
        Ok(())
    }
}

fn project(tracks: usize) -> Vec<u8> {
    let mut timeline = Timeline::default();
    for _ in 0..tracks {
        timeline.add_track(TrackKind::Audio);
    }
    encode_for_save(&timeline).unwrap()
}

/// A project file only a newer app can read.
fn too_new() -> Vec<u8> {
    let mut file = ProjectFile::decode(project(1).as_slice()).unwrap();
    file.min_reader_version = FORMAT_VERSION + 1;
    file.encode_to_vec()
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    })
}

fn enable(engine: &mut Engine, path: &str) -> Event {
    run(
        engine,
        command::Kind::EnableAutosave(EnableAutosave { path: path.into() }),
    )
}

fn failed(e: &Event) -> bool {
    matches!(e.kind, Some(event::Kind::CommandFailed(_)))
}

const PATH: &str = "/data/autosave.framix";

#[test]
fn a_recovered_autosave_is_written_back_before_any_autosave() {
    let store = MemStore::default();
    store.put(PATH, BROKEN);
    store.put(format!("{PATH}.bak1"), &project(2));
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert!(!failed(&enable(&mut engine, PATH)));
    assert_eq!(
        store.get(PATH),
        Some(project(2)),
        "a crash now loses nothing"
    );
}

#[test]
fn an_autosave_from_a_newer_app_is_refused_and_kept() {
    let store = MemStore::default();
    store.put(PATH, &too_new());
    store.put(format!("{PATH}.bak1"), &project(2));
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert!(failed(&enable(&mut engine, PATH)));
    assert_eq!(store.get(PATH), Some(too_new()));
    assert_eq!(store.get(format!("{PATH}.broken")), None);
}

#[test]
fn an_autosave_the_os_wont_read_is_refused_not_set_aside() {
    let store = MemStore::default();
    store.put(format!("{DENIED}.bak1"), &project(2));
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert!(failed(&enable(&mut engine, DENIED)));
    assert_eq!(store.get(format!("{DENIED}.broken")), None);
}

const DIR: &str = "/data/projects";
const ID: &str = "0123456789abcdef";

fn library(store: &MemStore) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary { dir: DIR.into() }),
    );
    assert!(
        matches!(e.kind, Some(event::Kind::CommandAccepted(_))),
        "{e:?}"
    );
    engine
}

fn open(engine: &mut Engine) -> Event {
    run(
        engine,
        command::Kind::OpenProject(OpenProject {
            id: ID.into(),
            ..Default::default()
        }),
    )
}

fn listed(engine: &mut Engine) -> Vec<String> {
    match run(engine, command::Kind::ListProjects(ListProjects::default())).kind {
        Some(event::Kind::ProjectList(l)) => l.projects.into_iter().map(|p| p.id).collect(),
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

#[test]
fn a_project_opened_from_its_backup_stays_on_home_without_an_edit() {
    let store = MemStore::default();
    let file = format!("{DIR}/{ID}.framix");
    store.put(&file, BROKEN);
    store.put(format!("{file}.bak1"), &project(2));
    let mut engine = library(&store);
    assert!(!failed(&open(&mut engine)));
    assert_eq!(listed(&mut engine), [ID]);
    assert_eq!(store.get(&file), Some(project(2)));
}

#[test]
fn a_library_project_from_a_newer_app_is_not_opened_from_a_backup() {
    let store = MemStore::default();
    let file = format!("{DIR}/{ID}.framix");
    store.put(&file, &too_new());
    store.put(format!("{file}.bak1"), &project(2));
    let mut engine = library(&store);
    assert!(failed(&open(&mut engine)));
    assert_eq!(store.get(&file), Some(too_new()));
}
