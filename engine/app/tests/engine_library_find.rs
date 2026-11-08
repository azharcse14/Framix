//! Project library names, folders, search and sort (P1-015).

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ImportMedia, ListProjects, MediaItem, MediaKind, MoveProject, NewProject,
    OpenLibrary, ProjectSort, ProjectSummary, RenameProject, TrackKind, command, event,
};
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";

type Files = HashMap<PathBuf, (Vec<u8>, SystemTime)>;

/// In-memory files; each write stamps the file one second later than the one before.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<Files>>,
    clock: Arc<Mutex<u64>>,
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        let mut clock = self.clock.lock().unwrap();
        *clock += 1;
        let at = SystemTime::UNIX_EPOCH + Duration::from_secs(*clock);
        self.files
            .lock()
            .unwrap()
            .insert(path.into(), (bytes.to_vec(), at));
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
    let dir = OpenLibrary { dir: DIR.into() };
    run(&mut engine, command::Kind::OpenLibrary(dir));
    engine
}

/// The listed projects and folders.
fn list_with(engine: &mut Engine, op: ListProjects) -> (Vec<ProjectSummary>, Vec<String>) {
    match run(engine, command::Kind::ListProjects(op)) {
        Some(event::Kind::ProjectList(list)) => (list.projects, list.folders),
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn list(engine: &mut Engine) -> Vec<ProjectSummary> {
    list_with(engine, ListProjects::default()).0
}

fn names(projects: &[ProjectSummary]) -> Vec<&str> {
    projects.iter().map(|p| p.name.as_str()).collect()
}

fn accepted(e: Option<event::Kind>) -> bool {
    matches!(e, Some(event::Kind::CommandAccepted(_)))
}

fn refused(e: Option<event::Kind>) -> bool {
    matches!(e, Some(event::Kind::CommandFailed(_)))
}

fn rename(engine: &mut Engine, id: &str, name: &str) -> Option<event::Kind> {
    let op = RenameProject {
        id: id.into(),
        name: name.into(),
    };
    run(engine, command::Kind::RenameProject(op))
}

fn move_to(engine: &mut Engine, id: &str, folder: &str) -> Option<event::Kind> {
    let op = MoveProject {
        id: id.into(),
        folder: folder.into(),
    };
    run(engine, command::Kind::MoveProject(op))
}

/// Starts a project with `tracks` video tracks and returns its id (the newest in the list).
fn project(engine: &mut Engine, tracks: usize) -> String {
    run(engine, command::Kind::NewProject(NewProject {}));
    for _ in 0..tracks.max(1) {
        let add = AddTrack {
            kind: TrackKind::Video as i32,
        };
        run(engine, command::Kind::AddTrack(add));
    }
    list(engine)[0].id.clone()
}

/// Projects named `names`, oldest first; returns their ids in the same order.
fn named(engine: &mut Engine, names: &[&str]) -> Vec<String> {
    names
        .iter()
        .map(|name| {
            let id = project(engine, 1);
            assert!(accepted(rename(engine, &id, name)), "{name:?}");
            id
        })
        .collect()
}

#[test]
fn a_renamed_and_moved_project_is_listed_with_its_name_and_folder() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine, 1);
    assert_eq!(
        (
            list(&mut engine)[0].name.as_str(),
            list(&mut engine)[0].folder.as_str()
        ),
        ("", "")
    );

    assert!(accepted(rename(&mut engine, &id, "  Holiday  ")));
    assert!(accepted(move_to(&mut engine, &id, " Trips ")));
    let (projects, folders) = list_with(&mut engine, ListProjects::default());
    assert_eq!(projects.len(), 1);
    assert_eq!(projects[0].name, "Holiday", "trimmed");
    assert_eq!(projects[0].folder, "Trips");
    assert_eq!(folders, ["Trips"]);

    assert!(accepted(move_to(&mut engine, &id, "")));
    let (projects, folders) = list_with(&mut engine, ListProjects::default());
    assert_eq!(projects[0].folder, "");
    assert_eq!(folders, Vec::<String>::new(), "an empty folder is gone");
}

#[test]
fn names_survive_autosave_and_a_restart() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine, 1);
    assert!(accepted(rename(&mut engine, &id, "Kept")));
    // The renamed project is the open one: editing and autosaving it keeps the name.
    let add = AddTrack {
        kind: TrackKind::Video as i32,
    };
    run(&mut engine, command::Kind::AddTrack(add));
    assert_eq!(names(&list(&mut engine)), ["Kept"]);
    drop(engine);

    let mut again = library(&store);
    assert_eq!(names(&list(&mut again)), ["Kept"]);
}

#[test]
fn search_finds_names_ignoring_case_and_spaces() {
    let store = MemStore::default();
    let mut engine = library(&store);
    named(&mut engine, &["Beach day", "Birthday", "Wedding", "বিয়ে"]);
    project(&mut engine, 1); // unnamed

    let find = |engine: &mut Engine, query: &str| {
        let op = ListProjects {
            query: query.into(),
            ..ListProjects::default()
        };
        let mut found: Vec<String> = names(&list_with(engine, op).0)
            .into_iter()
            .map(str::to_owned)
            .collect();
        found.sort();
        found
    };
    assert_eq!(find(&mut engine, "DAY"), ["Beach day", "Birthday"]);
    assert_eq!(find(&mut engine, "  beach "), ["Beach day"]);
    assert_eq!(find(&mut engine, "বিয়ে"), ["বিয়ে"]);
    assert_eq!(find(&mut engine, "nothing"), Vec::<String>::new());
    assert_eq!(find(&mut engine, "  ").len(), 5, "a blank query lists all");
}

#[test]
fn sort_by_date_name_or_size() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let ids = named(&mut engine, &["banana", "Apple", "cherry"]);
    let unnamed = project(&mut engine, 1);
    let sorted = |engine: &mut Engine, sort: ProjectSort| {
        let op = ListProjects {
            sort: sort as i32,
            ..ListProjects::default()
        };
        list_with(engine, op)
            .0
            .into_iter()
            .map(|p| p.id)
            .collect::<Vec<_>>()
    };

    assert_eq!(
        sorted(&mut engine, ProjectSort::Unspecified),
        [&*unnamed, &ids[2], &ids[1], &ids[0]],
        "newest saved first"
    );
    assert_eq!(
        sorted(&mut engine, ProjectSort::Name),
        [&*ids[1], &ids[0], &ids[2], &unnamed],
        "A to Z ignoring case, unnamed last"
    );

    // A project with more in it is a bigger file.
    let big = project(&mut engine, 1);
    let item = MediaItem {
        color: 0,
        uri: "media/a-long-name-that-takes-room.jpg".into(),
        kind: MediaKind::Image as i32,
        duration_value: 0,
        duration_timescale: 0,
        width: 10,
        height: 10,
        rotation: 0,
        codec: String::new(),
    };
    let items = vec![item; 5];
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia { items }),
    );
    let projects = list(&mut engine);
    let size = |id: &str| projects.iter().find(|p| p.id == id).unwrap().bytes;
    assert!(size(&big) > size(&ids[0]));
    assert!(size(&ids[0]) > 0);
    assert_eq!(sorted(&mut engine, ProjectSort::Size)[0], big);
}

#[test]
fn bytes_is_the_project_file_size() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine, 2);
    let file = PathBuf::from(format!("{DIR}/{id}.framix"));
    let on_disk = store.load(&file).unwrap().len() as u64;
    assert_eq!(list(&mut engine)[0].bytes, on_disk);
}

#[test]
fn a_folder_lists_only_its_projects() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let ids = named(&mut engine, &["a", "b", "c", "d"]);
    assert!(accepted(move_to(&mut engine, &ids[0], "Trips")));
    assert!(accepted(move_to(&mut engine, &ids[1], "Trips")));
    assert!(accepted(move_to(&mut engine, &ids[2], "school")));

    let in_folder = |engine: &mut Engine, folder: &str| {
        let op = ListProjects {
            folder: folder.into(),
            ..ListProjects::default()
        };
        list_with(engine, op)
    };
    let (projects, folders) = in_folder(&mut engine, "Trips");
    assert_eq!(names(&projects), ["b", "a"]);
    assert_eq!(
        folders,
        ["school", "Trips"],
        "every folder, A to Z ignoring case"
    );
    assert_eq!(names(&in_folder(&mut engine, "school").0), ["c"]);
    assert_eq!(in_folder(&mut engine, "").0.len(), 4);
    assert_eq!(in_folder(&mut engine, "none").0.len(), 0);
}

#[test]
fn bad_names_folders_and_ids_are_refused() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine, 1);
    assert!(accepted(rename(&mut engine, &id, "Old")));

    assert!(
        accepted(rename(&mut engine, &id, &"ক".repeat(80))),
        "80 characters fit"
    );
    assert!(refused(rename(&mut engine, &id, &"a".repeat(81))));
    assert!(refused(rename(&mut engine, &id, "a\nb")));
    assert!(refused(rename(&mut engine, "nothere", "x")));
    assert!(refused(rename(&mut engine, "../x", "x")));
    assert!(accepted(move_to(&mut engine, &id, &"f".repeat(40))));
    assert!(refused(move_to(&mut engine, &id, &"f".repeat(41))));
    assert!(refused(move_to(&mut engine, &id, "a\tb")));
    assert!(refused(move_to(&mut engine, "nothere", "x")));
    assert_eq!(list(&mut engine)[0].name, "ক".repeat(80));
    assert_eq!(list(&mut engine)[0].folder, "f".repeat(40));
}

#[test]
fn renaming_needs_a_library() {
    let mut engine = Engine::with_store(Box::new(MemStore::default()));
    assert!(refused(rename(&mut engine, "abc", "x")));
    assert!(refused(move_to(&mut engine, "abc", "x")));
}

#[test]
fn a_damaged_index_loses_names_not_projects() {
    let store = MemStore::default();
    let mut engine = library(&store);
    let id = project(&mut engine, 1);
    assert!(accepted(rename(&mut engine, &id, "x")));
    store
        .save(Path::new(&format!("{DIR}/library.index")), b"garbage")
        .unwrap();
    // The index's backup still holds the name.
    let projects = list(&mut engine);
    assert_eq!(projects.len(), 1);
    assert!(projects[0].name == "x" || projects[0].name.is_empty());
}
