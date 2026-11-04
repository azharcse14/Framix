//! Project library for Home (P1-089): OpenLibrary, ListProjects, NewProject and
//! OpenProject{id}, each project autosaved to its own file.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, EnableAutosave, ImportMedia, ListProjects, MediaItem, MediaKind, NewProject,
    OpenLibrary, OpenProject, ProjectSummary, TrackKind, command, event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";

/// File bytes and write time by path.
type Files = HashMap<PathBuf, (Vec<u8>, SystemTime)>;

/// In-memory files; each write stamps the file one second later than the one before.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<Files>>,
    clock: Arc<Mutex<u64>>,
}

impl MemStore {
    fn put(&self, path: &str, bytes: &[u8]) {
        let mut clock = self.clock.lock().unwrap();
        *clock += 1;
        let at = SystemTime::UNIX_EPOCH + Duration::from_secs(*clock);
        self.files
            .lock()
            .unwrap()
            .insert(path.into(), (bytes.to_vec(), at));
    }

    fn paths(&self) -> Vec<PathBuf> {
        let mut paths: Vec<_> = self.files.lock().unwrap().keys().cloned().collect();
        paths.sort();
        paths
    }
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        self.put(path.to_str().unwrap(), bytes);
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
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary { dir: DIR.into() }),
    );
    assert!(matches!(e, Some(event::Kind::CommandAccepted(_))), "{e:?}");
    engine
}

fn list(engine: &mut Engine) -> Vec<ProjectSummary> {
    match run(engine, command::Kind::ListProjects(ListProjects {})) {
        Some(event::Kind::ProjectList(list)) => list.projects,
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn tracks_after(e: Option<event::Kind>) -> usize {
    match e {
        Some(event::Kind::TimelineChanged(t)) => t.tracks.len(),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn add_track(engine: &mut Engine) -> usize {
    tracks_after(run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    ))
}

fn new_project(engine: &mut Engine) -> usize {
    tracks_after(run(engine, command::Kind::NewProject(NewProject {})))
}

fn open(engine: &mut Engine, id: &str) -> Option<event::Kind> {
    run(
        engine,
        command::Kind::OpenProject(OpenProject {
            path: String::new(),
            id: id.into(),
        }),
    )
}

fn refused(e: Option<event::Kind>) -> bool {
    matches!(e, Some(event::Kind::CommandFailed(_)))
}

#[test]
fn listing_needs_a_library() {
    let mut engine = Engine::with_store(Box::new(MemStore::default()));
    assert!(refused(run(
        &mut engine,
        command::Kind::ListProjects(ListProjects {})
    )));
}

#[test]
fn an_untouched_new_project_leaves_no_file() {
    let store = MemStore::default();
    let mut engine = library(&store);
    assert_eq!(list(&mut engine), []);
    assert_eq!(new_project(&mut engine), 0);
    assert_eq!(list(&mut engine), []);
    assert_eq!(engine.autosave(), None);
    assert_eq!(store.paths(), Vec::<PathBuf>::new());
}

#[test]
fn an_edited_project_is_saved_in_the_library_and_listed() {
    let store = MemStore::default();
    let mut engine = library(&store);
    new_project(&mut engine);
    add_track(&mut engine);

    // ListProjects saves the current project first, so its row is fresh.
    let projects = list(&mut engine);
    assert_eq!(projects.len(), 1);
    let p = &projects[0];
    assert!(!p.id.is_empty() && p.id.len() <= 32, "id {:?}", p.id);
    assert!(
        p.id.bytes()
            .all(|b| b.is_ascii_digit() || b.is_ascii_lowercase())
    );
    assert_eq!((p.duration, p.clips), (0, 0));
    assert!(p.ticks_per_second > 0);
    assert_eq!(p.modified_ms, 1000);
    assert_eq!(
        store.paths(),
        [PathBuf::from(format!("{DIR}/{}.framix", p.id))]
    );
}

#[test]
fn projects_are_listed_newest_first_with_duration_and_clips() {
    let store = MemStore::default();
    let mut engine = library(&store);
    new_project(&mut engine);
    add_track(&mut engine);
    new_project(&mut engine);
    let item = MediaItem {
        color: 0,
        uri: "media/a.jpg".into(),
        kind: MediaKind::Image as i32,
        duration_value: 0,
        duration_timescale: 0,
        width: 10,
        height: 10,
        rotation: 0,
        codec: String::new(),
    };
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![item.clone(), item],
        }),
    );

    let projects = list(&mut engine);
    assert_eq!(projects.len(), 2);
    let (newest, older) = (&projects[0], &projects[1]);
    assert!(newest.modified_ms > older.modified_ms);
    assert_eq!(newest.clips, 2);
    assert!(newest.duration > 0);
    assert_eq!(older.clips, 0);
    assert_ne!(newest.id, older.id);
}

#[test]
fn opening_a_project_restores_it_and_autosaves_there() {
    let store = MemStore::default();
    let mut engine = library(&store);
    new_project(&mut engine);
    add_track(&mut engine);
    new_project(&mut engine);
    add_track(&mut engine);
    add_track(&mut engine);
    let projects = list(&mut engine);
    let (two, one) = (projects[0].id.clone(), projects[1].id.clone());

    assert_eq!(tracks_after(open(&mut engine, &one)), 1);
    add_track(&mut engine);
    let projects = list(&mut engine);
    assert_eq!(projects[0].id, one, "the edit went to the opened project");
    assert_eq!(projects.len(), 2);

    assert_eq!(tracks_after(open(&mut engine, &two)), 2);
    assert_eq!(tracks_after(open(&mut engine, &one)), 2);
}

#[test]
fn switching_projects_saves_the_current_one_first() {
    let store = MemStore::default();
    let mut engine = library(&store);
    new_project(&mut engine);
    add_track(&mut engine);
    // No autosave tick between the edit and NewProject.
    new_project(&mut engine);
    assert_eq!(store.paths().len(), 1);
}

#[test]
fn bad_or_unknown_ids_are_refused_and_the_project_stays() {
    let store = MemStore::default();
    let mut engine = library(&store);
    new_project(&mut engine);
    add_track(&mut engine);
    for id in [
        "",
        "../x",
        "a/b",
        "A",
        "x.framix",
        &"a".repeat(33),
        "nothere",
    ] {
        assert!(refused(open(&mut engine, id)), "{id:?}");
    }
    assert_eq!(add_track(&mut engine), 2, "the current project stayed");
}

#[test]
fn unreadable_files_are_skipped() {
    let store = MemStore::default();
    store.put(&format!("{DIR}/broken.framix"), b"not a project");
    store.put(&format!("{DIR}/notes.txt"), b"x");
    store.put("/data/other/abc.framix", b"x");
    let mut engine = library(&store);
    assert_eq!(list(&mut engine), []);
}

#[test]
fn the_library_opens_once() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let again = |engine: &mut Engine, dir: &str| {
        run(
            engine,
            command::Kind::OpenLibrary(OpenLibrary { dir: dir.into() }),
        )
    };
    assert!(matches!(
        again(&mut engine, DIR),
        Some(event::Kind::CommandAccepted(_))
    ));
    assert!(refused(again(&mut engine, "/data/elsewhere")));

    let mut autosaving = Engine::with_store(Box::new(store.clone()));
    run(
        &mut autosaving,
        command::Kind::EnableAutosave(EnableAutosave {
            path: "/data/a.framix".into(),
        }),
    );
    assert!(refused(again(&mut autosaving, DIR)));
}
