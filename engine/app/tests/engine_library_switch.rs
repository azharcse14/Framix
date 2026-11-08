//! Switching library projects never loses edits (P1-089 review): the current project is
//! saved before another is read, and a failed save refuses the switch.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ListProjects, NewProject, OpenLibrary, OpenProject, ProjectSummary,
    TrackKind, command, event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";

/// In-memory files whose saves can be made to fail.
#[derive(Clone, Default)]
struct Store {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
    full: Arc<AtomicBool>,
}

impl ProjectStore for Store {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        if self.full.load(Ordering::Relaxed) {
            return Err(io::ErrorKind::StorageFull.into());
        }
        self.files
            .lock()
            .unwrap()
            .insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        let files = self.files.lock().unwrap();
        files
            .get(path)
            .cloned()
            .ok_or(io::ErrorKind::NotFound.into())
    }

    fn list(&self, dir: &Path) -> io::Result<Vec<(PathBuf, SystemTime)>> {
        let files = self.files.lock().unwrap();
        Ok(files
            .keys()
            .filter(|p| p.parent() == Some(dir))
            .map(|p| (p.clone(), SystemTime::UNIX_EPOCH + Duration::from_secs(1)))
            .collect())
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

fn tracks(e: Option<event::Kind>) -> usize {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t.tracks.len(),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn add_track(engine: &mut Engine) -> usize {
    tracks(run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    ))
}

fn list(engine: &mut Engine) -> Vec<ProjectSummary> {
    match run(engine, command::Kind::ListProjects(ListProjects::default())) {
        Some(event::Kind::ProjectList(l)) => l.projects,
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn open(id: &str) -> command::Kind {
    command::Kind::OpenProject(OpenProject {
        path: String::new(),
        id: id.into(),
    })
}

fn library(store: &Store) -> Engine {
    let mut engine = Engine::with_store(Box::new(store.clone()));
    run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary { dir: DIR.into() }),
    );
    run(&mut engine, command::Kind::NewProject(NewProject {}));
    engine
}

#[test]
fn reopening_the_open_project_keeps_its_unsaved_edits() {
    let store = Store::default();
    let mut engine = library(&store);
    add_track(&mut engine);
    let id = list(&mut engine)[0].id.clone();
    add_track(&mut engine);

    assert_eq!(tracks(run(&mut engine, open(&id))), 2);
    assert_eq!(add_track(&mut engine), 3);
}

#[test]
fn a_failed_save_refuses_new_and_open_and_keeps_the_project() {
    let store = Store::default();
    let mut engine = library(&store);
    add_track(&mut engine);
    let id = list(&mut engine)[0].id.clone();
    add_track(&mut engine);
    store.full.store(true, Ordering::Relaxed);

    let refused = |e: Option<event::Kind>| matches!(e, Some(event::Kind::CommandFailed(_)));
    assert!(refused(run(
        &mut engine,
        command::Kind::NewProject(NewProject {})
    )));
    assert!(refused(run(&mut engine, open(&id))));
    assert_eq!(add_track(&mut engine), 3, "the unsaved project stayed");

    store.full.store(false, Ordering::Relaxed);
    assert_eq!(
        tracks(run(&mut engine, open(&id))),
        3,
        "saved once space is back"
    );
}

#[test]
fn an_empty_or_relative_library_folder_is_refused() {
    for dir in ["", "projects", "./p"] {
        let mut engine = Engine::with_store(Box::new(Store::default()));
        let e = run(
            &mut engine,
            command::Kind::OpenLibrary(OpenLibrary { dir: dir.into() }),
        );
        assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{dir:?}");
    }
}
