//! Recently deleted: a deleted project can be restored for 30 days, then it is gone (P1-016).

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, DeleteProject, ListProjects, MoveProject, NewProject, OpenLibrary,
    OpenProject, ProjectList, RenameProject, RestoreProject, TrackKind, command, event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";
const DAY: u64 = 24 * 60 * 60;

type Files = HashMap<PathBuf, (Vec<u8>, SystemTime)>;

/// In-memory files with one backup each; its clock ticks a second per write and can jump.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<Files>>,
    clock: Arc<Mutex<u64>>,
}

impl MemStore {
    fn at(&self) -> SystemTime {
        SystemTime::UNIX_EPOCH + Duration::from_secs(*self.clock.lock().unwrap())
    }

    fn advance(&self, secs: u64) {
        *self.clock.lock().unwrap() += secs;
    }

    fn has(&self, path: &Path) -> bool {
        self.files.lock().unwrap().contains_key(path)
    }
}

fn backup(path: &Path) -> PathBuf {
    PathBuf::from(format!("{}.bak1", path.display()))
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        self.advance(1);
        let at = self.at();
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

    fn remove(&self, path: &Path) -> io::Result<()> {
        self.files.lock().unwrap().remove(path);
        Ok(())
    }

    fn now(&self) -> SystemTime {
        self.at()
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
    let dir = OpenLibrary {
        dir: DIR.into(),
        cache_dir: String::new(),
    };
    run(&mut engine, command::Kind::OpenLibrary(dir));
    engine
}

fn list_with(engine: &mut Engine, deleted: bool) -> ProjectList {
    let op = ListProjects {
        deleted,
        ..ListProjects::default()
    };
    match run(engine, command::Kind::ListProjects(op)) {
        Some(event::Kind::ProjectList(list)) => list,
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn ids(engine: &mut Engine, deleted: bool) -> Vec<String> {
    let mut ids: Vec<String> = list_with(engine, deleted)
        .projects
        .into_iter()
        .map(|p| p.id)
        .collect();
    ids.sort();
    ids
}

fn accepted(e: Option<event::Kind>) -> bool {
    matches!(e, Some(event::Kind::CommandAccepted(_)))
}

fn refused(e: Option<event::Kind>) -> bool {
    matches!(e, Some(event::Kind::CommandFailed(_)))
}

fn delete(engine: &mut Engine, id: &str) -> Option<event::Kind> {
    run(
        engine,
        command::Kind::DeleteProject(DeleteProject { id: id.into() }),
    )
}

fn restore(engine: &mut Engine, id: &str) -> Option<event::Kind> {
    run(
        engine,
        command::Kind::RestoreProject(RestoreProject { id: id.into() }),
    )
}

/// Starts a project and returns its id.
fn project(engine: &mut Engine) -> String {
    run(engine, command::Kind::NewProject(NewProject {}));
    let add = AddTrack {
        kind: TrackKind::Video as i32,
    };
    run(engine, command::Kind::AddTrack(add));
    list_with(engine, false).projects[0].id.clone()
}

fn file(id: &str) -> PathBuf {
    PathBuf::from(format!("{DIR}/{id}.framix"))
}

#[test]
fn a_deleted_project_moves_to_recently_deleted_and_back() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let keep = project(&mut engine);
    let gone = project(&mut engine);
    let rename = RenameProject {
        id: gone.clone(),
        name: "Trip".into(),
    };
    assert!(accepted(run(
        &mut engine,
        command::Kind::RenameProject(rename)
    )));
    let to = MoveProject {
        id: gone.clone(),
        folder: "Travel".into(),
    };
    assert!(accepted(run(&mut engine, command::Kind::MoveProject(to))));

    assert!(accepted(delete(&mut engine, &gone)));
    let list = list_with(&mut engine, false);
    assert_eq!(list.projects.len(), 1);
    assert_eq!(list.projects[0].id, keep);
    assert_eq!(list.deleted, 1);
    assert_eq!(
        list.folders,
        Vec::<String>::new(),
        "a deleted project's folder is not listed"
    );
    let deleted = list_with(&mut engine, true);
    assert_eq!(deleted.projects.len(), 1);
    let at = store.now();
    let ms = |t: SystemTime| {
        t.duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_millis() as i64
    };
    let purge = deleted.projects[0].purge_ms;
    assert!(
        purge > ms(at) + 29 * DAY as i64 * 1000 && purge <= ms(at) + 30 * DAY as i64 * 1000,
        "removed for good 30 days after the delete"
    );
    assert_eq!(list.projects[0].purge_ms, 0);

    assert!(accepted(restore(&mut engine, &gone)));
    let list = list_with(&mut engine, false);
    let back = list.projects.iter().find(|p| p.id == gone).unwrap();
    assert_eq!(
        (back.name.as_str(), back.folder.as_str()),
        ("Trip", "Travel")
    );
    assert_eq!(back.purge_ms, 0);
    assert_eq!(list.deleted, 0);
    assert!(ids(&mut engine, true).is_empty());
}

#[test]
fn a_deleted_project_is_removed_for_good_after_30_days() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine);
    project(&mut engine); // a second save of `id` would make a backup; one is enough here
    let add = AddTrack {
        kind: TrackKind::Video as i32,
    };
    run(
        &mut engine,
        command::Kind::OpenProject(OpenProject {
            id: id.clone(),
            ..OpenProject::default()
        }),
    );
    run(&mut engine, command::Kind::AddTrack(add));
    list_with(&mut engine, false); // saves `id` again: its file now has a backup
    assert!(store.has(&backup(&file(&id))));

    assert!(accepted(delete(&mut engine, &id)));
    store.advance(29 * DAY);
    assert_eq!(
        ids(&mut engine, true),
        [id.as_str()],
        "29 days: still there"
    );
    assert!(store.has(&file(&id)));

    store.advance(DAY);
    assert!(ids(&mut engine, true).is_empty());
    assert!(!ids(&mut engine, false).contains(&id));
    assert!(!store.has(&file(&id)), "the file is gone");
    assert!(!store.has(&backup(&file(&id))), "so are its backups");
    assert_eq!(list_with(&mut engine, false).deleted, 0);
}

#[test]
fn recently_deleted_survives_a_restart() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine);
    assert!(accepted(delete(&mut engine, &id)));
    drop(engine);

    let mut again = library(&store);
    assert!(ids(&mut again, false).is_empty());
    assert_eq!(ids(&mut again, true), [id]);
}

#[test]
fn a_deleted_project_does_not_open() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine);
    project(&mut engine);
    assert!(accepted(delete(&mut engine, &id)));
    let open = OpenProject {
        id: id.clone(),
        ..OpenProject::default()
    };
    assert!(refused(run(&mut engine, command::Kind::OpenProject(open))));
    assert!(accepted(restore(&mut engine, &id)));
    let open = OpenProject {
        id,
        ..OpenProject::default()
    };
    assert!(!refused(run(&mut engine, command::Kind::OpenProject(open))));
}

#[test]
fn bad_deletes_and_restores_are_refused() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine);
    assert!(refused(delete(&mut engine, "nothere")));
    assert!(refused(delete(&mut engine, "../x")));
    assert!(refused(restore(&mut engine, &id)), "not deleted");
    assert!(accepted(delete(&mut engine, &id)));
    assert!(refused(delete(&mut engine, &id)), "already deleted");

    let mut bare = Engine::with_store(Box::new(MemStore::default()));
    assert!(refused(delete(&mut bare, &id)));
    assert!(refused(restore(&mut bare, &id)));
}
