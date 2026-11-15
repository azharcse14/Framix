//! SYS-003: the last saves are kept (`.bak1`, `.bak2`), and a damaged latest save opens from
//! the newest good one, end to end: the engine with FileStore on a real library folder.

use std::fs;
use std::path::{Path, PathBuf};

mod common;
use common::TempDir;

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, ListProjects, NewProject, OpenLibrary, OpenProject, TrackKind, command,
    event,
};
use framix_app::store::{ProjectStore, load};
use framix_storage::FileStore;

fn temp_dir(name: &str) -> TempDir {
    TempDir::new(&format!("framix-backup-{name}"))
}

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn library(dir: &Path) -> Engine {
    let mut engine = Engine::with_store(Box::new(FileStore));
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary {
            dir: dir.to_str().unwrap().into(),
            cache_dir: String::new(),
        }),
    );
    assert!(matches!(e, Some(event::Kind::CommandAccepted(_))), "{e:?}");
    engine
}

fn tracks_in(path: &Path) -> usize {
    load(&FileStore, path).unwrap().tracks().len()
}

/// A library project saved after each of three edits (1, 2, 3 tracks): its id and file.
fn saved_project(lib: &Path) -> (String, PathBuf) {
    let mut engine = library(lib);
    run(&mut engine, command::Kind::NewProject(NewProject {}));
    for _ in 0..3 {
        run(
            &mut engine,
            command::Kind::AddTrack(AddTrack {
                kind: TrackKind::Video as i32,
            }),
        );
        engine.autosave();
    }
    let id = match run(
        &mut engine,
        command::Kind::ListProjects(ListProjects::default()),
    ) {
        Some(event::Kind::ProjectList(l)) => l.projects[0].id.clone(),
        other => panic!("expected ProjectList, got {other:?}"),
    };
    let file = lib.join(format!("{id}.framix"));
    let [bak1, bak2] = [0, 1].map(|n| FileStore.backups(&file)[n].clone());
    // The last three saves, newest first, each one edit apart.
    assert_eq!(
        [tracks_in(&file), tracks_in(&bak1), tracks_in(&bak2)],
        [3, 2, 1]
    );
    (id, file)
}

fn open(lib: &Path, id: &str) -> usize {
    let mut engine = library(lib);
    match run(
        &mut engine,
        command::Kind::OpenProject(OpenProject {
            id: id.into(),
            ..Default::default()
        }),
    ) {
        Some(event::Kind::TimelineChanged(t)) => t.tracks.len(),
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn a_damaged_latest_save_opens_from_the_newest_backup() {
    let lib = temp_dir("newest");
    let (id, file) = saved_project(&lib);
    fs::write(&file, b"torn by a power cut").unwrap();
    assert_eq!(open(&lib, &id), 2);
}

#[test]
fn a_damaged_newest_backup_is_skipped_for_the_older_one() {
    let lib = temp_dir("older");
    let (id, file) = saved_project(&lib);
    fs::write(&file, b"torn").unwrap();
    fs::write(&FileStore.backups(&file)[0], b"torn too").unwrap();
    assert_eq!(open(&lib, &id), 1);
}
