//! A project file that won't load doesn't end crash protection (P1-067): EnableAutosave
//! recovers the newest backup that decodes (or starts empty), keeps the broken file aside and
//! autosaves on; Home lists and opens a library project from its backup too.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use framix_app::engine::Engine;
use framix_app::project::encode_for_save;
use framix_app::proto::{
    AddTrack, Command, EnableAutosave, Event, ListProjects, OpenLibrary, OpenProject, TrackKind,
    command, event,
};
use framix_app::store::ProjectStore;
use framix_core::timeline::{Timeline, TrackKind as CoreTrackKind};

const PATH: &str = "/data/autosave.framix";
const BROKEN: &[u8] = &[0xff, 0xff, 0xff];

/// In-memory files with `.bak1`/`.bak2` backups and a `.broken` slot, like FileStore.
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
        if let Some(old) = files.remove(&suffixed(path, ".bak1")) {
            files.insert(suffixed(path, ".bak2"), old);
        }
        if let Some(current) = files.get(path).cloned() {
            files.insert(suffixed(path, ".bak1"), current);
        }
        files.insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
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

/// A project file holding `tracks` audio tracks.
fn project(tracks: usize) -> Vec<u8> {
    let mut timeline = Timeline::default();
    for _ in 0..tracks {
        timeline.add_track(CoreTrackKind::Audio);
    }
    encode_for_save(&timeline).unwrap()
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    })
}

fn tracks(e: Event) -> usize {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t.tracks.len(),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn enable(engine: &mut Engine) -> Event {
    run(
        engine,
        command::Kind::EnableAutosave(EnableAutosave { path: PATH.into() }),
    )
}

fn add_track(engine: &mut Engine) -> usize {
    tracks(run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Audio as i32,
        }),
    ))
}

#[test]
fn a_broken_file_is_recovered_from_its_newest_backup() {
    let store = MemStore::default();
    store.put(PATH, BROKEN);
    store.put(format!("{PATH}.bak1"), &project(2));
    store.put(format!("{PATH}.bak2"), &project(1));
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert_eq!(tracks(enable(&mut engine)), 2, "the newest backup");
    assert_eq!(
        store.get(format!("{PATH}.broken")).as_deref(),
        Some(BROKEN),
        "the broken file is kept aside"
    );
    // Autosave is on: the recovered project is written back to the file soon.
    assert_eq!(engine.autosave(), None);
    assert_eq!(store.get(PATH), Some(project(2)));
    add_track(&mut engine);
    assert_eq!(engine.autosave(), None);
    assert_eq!(store.get(PATH), Some(project(3)));
}

#[test]
fn a_broken_backup_is_skipped_for_an_older_one() {
    let store = MemStore::default();
    store.put(PATH, BROKEN);
    store.put(format!("{PATH}.bak1"), BROKEN);
    store.put(format!("{PATH}.bak2"), &project(1));
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert_eq!(tracks(enable(&mut engine)), 1);
}

#[test]
fn with_no_good_backup_it_starts_empty_and_still_autosaves() {
    let store = MemStore::default();
    store.put(PATH, BROKEN);
    let mut engine = Engine::with_store(Box::new(store.clone()));
    assert_eq!(tracks(enable(&mut engine)), 0);
    assert_eq!(store.get(format!("{PATH}.broken")).as_deref(), Some(BROKEN));
    assert_eq!(add_track(&mut engine), 1);
    assert_eq!(engine.autosave(), None);
    assert_eq!(store.get(PATH), Some(project(1)));
}

const DIR: &str = "/data/projects";
const ID: &str = "0123456789abcdef";

fn library(store: &MemStore) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary {
            dir: DIR.into(),
            cache_dir: String::new(),
        }),
    );
    assert!(
        matches!(e.kind, Some(event::Kind::CommandAccepted(_))),
        "{e:?}"
    );
    engine
}

#[test]
fn home_lists_and_opens_a_project_from_its_backup() {
    let store = MemStore::default();
    let file = format!("{DIR}/{ID}.framix");
    store.put(&file, BROKEN);
    store.put(format!("{file}.bak1"), &project(2));
    let mut engine = library(&store);
    let listed = match run(&mut engine, command::Kind::ListProjects(ListProjects {})).kind {
        Some(event::Kind::ProjectList(l)) => l.projects,
        other => panic!("expected ProjectList, got {other:?}"),
    };
    assert_eq!(listed.len(), 1, "{listed:?}");
    assert_eq!(listed[0].id, ID);
    let opened = run(
        &mut engine,
        command::Kind::OpenProject(OpenProject {
            id: ID.into(),
            ..Default::default()
        }),
    );
    assert_eq!(tracks(opened), 2);
}
