//! OpenProject tells the UI when the project's last save was damaged and it opened from a
//! backup (SYS-040), so the user hears about it once.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ListProjects, NewProject, OpenLibrary, OpenProject, TimelineChanged,
    TrackKind, command, event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";

type Files = HashMap<PathBuf, (Vec<u8>, SystemTime)>;

/// In-memory files with one backup each.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<Files>>,
    clock: Arc<Mutex<u64>>,
}

fn backup(path: &Path) -> PathBuf {
    PathBuf::from(format!("{}.bak1", path.display()))
}

impl MemStore {
    fn damage(&self, id: &str) {
        let path = PathBuf::from(format!("{DIR}/{id}.framix"));
        let mut files = self.files.lock().unwrap();
        files.get_mut(&path).unwrap().0 = b"not a project".to_vec();
    }
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        let mut clock = self.clock.lock().unwrap();
        *clock += 1;
        let at = SystemTime::UNIX_EPOCH + Duration::from_secs(*clock);
        let mut files = self.files.lock().unwrap();
        if let Some(old) = files.remove(path) {
            files.insert(backup(path), old);
        }
        files.insert(path.into(), (bytes.to_vec(), at));
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        let files = self.files.lock().unwrap();
        let (bytes, _) = files.get(path).ok_or(io::ErrorKind::NotFound)?;
        Ok(bytes.clone())
    }

    fn list(&self, dir: &Path) -> io::Result<Vec<(PathBuf, SystemTime)>> {
        let files = self.files.lock().unwrap();
        Ok(files
            .iter()
            .filter(|(path, _)| path.parent() == Some(dir))
            .map(|(path, (_, at))| (path.clone(), *at))
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

fn timeline(e: Option<event::Kind>) -> TimelineChanged {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn library(store: &MemStore) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    let dir = OpenLibrary {
        dir: DIR.into(),
        cache_dir: String::new(),
    };
    run(&mut engine, command::Kind::OpenLibrary(dir));
    engine
}

/// Lists the library (which saves the open project) and returns the one project's id.
fn save_and_list(engine: &mut Engine) -> String {
    match run(engine, command::Kind::ListProjects(ListProjects::default())) {
        Some(event::Kind::ProjectList(list)) => list.projects[0].id.clone(),
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn add_track(engine: &mut Engine) -> TimelineChanged {
    let add = AddTrack {
        kind: TrackKind::Video as i32,
    };
    timeline(run(engine, command::Kind::AddTrack(add)))
}

fn open(engine: &mut Engine, id: &str) -> TimelineChanged {
    let open = OpenProject {
        id: id.into(),
        ..OpenProject::default()
    };
    timeline(run(engine, command::Kind::OpenProject(open)))
}

/// A library with one project saved twice: one track in the backup, two in the file.
fn saved_twice(store: &MemStore) -> String {
    let mut engine = library(store);
    run(&mut engine, command::Kind::NewProject(NewProject {}));
    add_track(&mut engine);
    save_and_list(&mut engine);
    add_track(&mut engine);
    save_and_list(&mut engine)
}

#[test]
fn a_damaged_last_save_opens_from_its_backup_and_says_so_once() {
    let store = MemStore::default();
    let id = saved_twice(&store);
    store.damage(&id);

    let mut engine = library(&store);
    let opened = open(&mut engine, &id);
    assert_eq!(opened.tracks.len(), 1, "the backup's project");
    assert!(opened.from_backup, "the reply says it came from a backup");
    assert!(!add_track(&mut engine).from_backup, "only the open says it");
}

#[test]
fn a_good_save_opens_without_the_flag() {
    let store = MemStore::default();
    let id = saved_twice(&store);
    let opened = open(&mut library(&store), &id);
    assert_eq!(opened.tracks.len(), 2);
    assert!(!opened.from_backup);
}
