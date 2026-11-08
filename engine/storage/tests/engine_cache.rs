//! Per-project storage and cache clean (P1-017), end to end on real folders: the engine with
//! FileStore, a library folder and a cache folder laid out as the platform writes it.

use std::fs;
use std::path::{Path, PathBuf};

use framix_app::engine::Engine;
use framix_app::proto::{
    CleanProjectCache, Command, ImportMedia, ListProjects, MediaItem, MediaKind, NewProject,
    OpenLibrary, ProjectSummary, command, event,
};
use framix_storage::FileStore;

/// SHA-256 hex of the media uris (as the platform names cache files), from `shasum -a 256`.
const A: &str = "media/a.jpg";
const A_HASH: &str = "7aecb2d1a8f1e1a1bb1a226552bf563f3fc4eab13817d66dd0e3fc4817775b33";
const B: &str = "media/b.jpg";
const B_HASH: &str = "4aab6d0694fe23d0bd3c6ab4f31a71687370098815f4737c2614a7c211066dbf";
/// Longer than one SHA-256 block.
const LONG_HASH: &str = "045788fa643c3903af748c631edf5c70114f58bc8e1ed747d39294b1388a846a";

fn long_uri() -> String {
    format!("media/{}.jpg", "x".repeat(100))
}

fn temp_dir(name: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("framix-cache-{name}-{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    dir
}

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn library(dir: &Path, cache: &str) -> Engine {
    let mut engine = Engine::with_store(Box::new(FileStore));
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary {
            dir: dir.to_str().unwrap().into(),
            cache_dir: cache.into(),
        }),
    );
    assert!(matches!(e, Some(event::Kind::CommandAccepted(_))), "{e:?}");
    engine
}

fn photo(uri: &str) -> MediaItem {
    MediaItem {
        color: 0,
        uri: uri.into(),
        kind: MediaKind::Image as i32,
        duration_value: 0,
        duration_timescale: 0,
        width: 10,
        height: 10,
        rotation: 0,
        codec: String::new(),
    }
}

/// A new project holding photos `uris`.
fn project_with(engine: &mut Engine, uris: &[&str]) {
    run(engine, command::Kind::NewProject(NewProject {}));
    let e = run(
        engine,
        command::Kind::ImportMedia(ImportMedia {
            items: uris.iter().map(|u| photo(u)).collect(),
        }),
    );
    assert!(matches!(e, Some(event::Kind::TimelineChanged(_))), "{e:?}");
}

fn projects(e: Option<event::Kind>) -> Vec<ProjectSummary> {
    match e {
        Some(event::Kind::ProjectList(list)) => list.projects,
        other => panic!("expected ProjectList, got {other:?}"),
    }
}

fn list(engine: &mut Engine) -> Vec<ProjectSummary> {
    projects(run(engine, command::Kind::ListProjects(ListProjects {})))
}

fn clean(engine: &mut Engine, id: &str) -> Option<event::Kind> {
    run(
        engine,
        command::Kind::CleanProjectCache(CleanProjectCache { id: id.into() }),
    )
}

fn write(path: &Path, len: usize) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, vec![7u8; len]).unwrap();
}

/// Bytes of the project file and its backups, read straight from the folder.
fn project_bytes(dir: &Path, id: &str) -> u64 {
    ["", ".bak1", ".bak2"]
        .iter()
        .filter_map(|s| fs::metadata(dir.join(format!("{id}.framix{s}"))).ok())
        .map(|m| m.len())
        .sum()
}

/// Every file under `dir`, relative, sorted.
fn tree(dir: &Path) -> Vec<String> {
    fn walk(root: &Path, dir: &Path, out: &mut Vec<String>) {
        for entry in fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            if path.is_dir() && !path.is_symlink() {
                walk(root, &path, out);
            } else {
                out.push(path.strip_prefix(root).unwrap().display().to_string());
            }
        }
    }
    let mut out = Vec::new();
    walk(dir, dir, &mut out);
    out.sort();
    out
}

/// Two projects: the first uses A and the long uri, the second B. Returns (first, second).
fn two_projects(engine: &mut Engine) -> (ProjectSummary, ProjectSummary) {
    let long = long_uri();
    project_with(engine, &[A, &long]);
    let first = list(engine)[0].id.clone();
    project_with(engine, &[B]);
    let all = list(engine);
    let pick = |id: &str| all.iter().find(|p| p.id == id).unwrap().clone();
    let second = all.iter().find(|p| p.id != first).unwrap().id.clone();
    (pick(&first), pick(&second))
}

#[test]
fn each_project_counts_its_files_and_the_caches_of_its_media() {
    let root = temp_dir("count");
    let (lib, cache) = (root.join("projects"), root.join("cache"));
    fs::create_dir_all(&lib).unwrap();
    write(&cache.join(format!("thumbs/{A_HASH}-0-128.jpg")), 100);
    write(&cache.join(format!("thumbs/{A_HASH}-1000000-128.jpg")), 50);
    write(&cache.join(format!("proxies/{LONG_HASH}-1280.mov")), 1000);
    write(&cache.join(format!("thumbs/{B_HASH}-0-128.jpg")), 7);
    // Not any project's: another media, and a name without the separator.
    write(&cache.join("thumbs/unrelated.jpg"), 3);
    write(&cache.join(format!("thumbs/{A_HASH}")), 11);

    let mut engine = library(&lib, cache.to_str().unwrap());
    let (first, second) = two_projects(&mut engine);

    assert_eq!(first.cache_bytes, 1150);
    assert_eq!(second.cache_bytes, 7);
    assert!(first.project_bytes > 0);
    assert_eq!(first.project_bytes, project_bytes(&lib, &first.id));
    assert_eq!(second.project_bytes, project_bytes(&lib, &second.id));
}

#[test]
fn without_a_cache_folder_projects_have_no_cache_and_cleaning_is_refused() {
    let lib = temp_dir("nocache");
    let mut engine = library(&lib, "");
    project_with(&mut engine, &[A]);
    let p = list(&mut engine).remove(0);
    assert_eq!(p.cache_bytes, 0);
    assert_eq!(p.project_bytes, project_bytes(&lib, &p.id));
    assert!(matches!(
        clean(&mut engine, &p.id),
        Some(event::Kind::CommandFailed(_))
    ));
}

#[test]
fn a_relative_cache_folder_is_refused() {
    let lib = temp_dir("relative");
    let mut engine = Engine::with_store(Box::new(FileStore));
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary {
            dir: lib.to_str().unwrap().into(),
            cache_dir: "cache".into(),
        }),
    );
    assert!(matches!(e, Some(event::Kind::CommandFailed(_))), "{e:?}");
}

#[test]
fn cleaning_removes_only_that_projects_cache_files() {
    let root = temp_dir("clean");
    let (lib, cache) = (root.join("projects"), root.join("cache"));
    fs::create_dir_all(&lib).unwrap();
    write(&cache.join(format!("thumbs/{A_HASH}-0-128.jpg")), 100);
    write(
        &cache.join(format!("thumbs/{A_HASH}-0-128.jpg1234.part")),
        5,
    );
    write(&cache.join(format!("proxies/{LONG_HASH}-1280.mov")), 1000);
    write(&cache.join(format!("thumbs/{B_HASH}-0-128.jpg")), 7);
    write(&cache.join("thumbs/unrelated.jpg"), 3);
    // A folder with a matching name is never entered or removed.
    write(&cache.join(format!("thumbs/{A_HASH}-dir/inner.jpg")), 9);
    // A link with a matching name: what it points to stays.
    let outside = root.join("outside.jpg");
    write(&outside, 4);
    #[cfg(unix)]
    std::os::unix::fs::symlink(&outside, cache.join(format!("thumbs/{A_HASH}-9-128.jpg"))).unwrap();

    let mut engine = library(&lib, cache.to_str().unwrap());
    let (first, second) = two_projects(&mut engine);
    let library_before = tree(&lib);
    let bytes_before: Vec<_> = library_before
        .iter()
        .map(|f| fs::read(lib.join(f)).unwrap())
        .collect();

    let after = projects(clean(&mut engine, &first.id));
    let row = |id: &str| after.iter().find(|p| p.id == id).unwrap().clone();
    assert_eq!(row(&first.id).cache_bytes, 0);
    assert_eq!(row(&second.id).cache_bytes, 7);
    assert_eq!(row(&first.id).project_bytes, first.project_bytes);

    let mut left = vec![
        format!("thumbs/{B_HASH}-0-128.jpg"),
        "thumbs/unrelated.jpg".to_owned(),
        format!("thumbs/{A_HASH}-dir/inner.jpg"),
    ];
    #[cfg(unix)]
    left.push(format!("thumbs/{A_HASH}-9-128.jpg"));
    left.sort();
    assert_eq!(tree(&cache), left);
    assert_eq!(fs::read(&outside).unwrap(), [7u8; 4]);

    // Project files and backups are untouched.
    assert_eq!(tree(&lib), library_before);
    for (f, bytes) in library_before.iter().zip(bytes_before) {
        assert_eq!(fs::read(lib.join(f)).unwrap(), bytes, "{f}");
    }
}

#[test]
fn cleaning_with_an_empty_cache_folder_is_fine() {
    let root = temp_dir("empty");
    let (lib, cache) = (root.join("projects"), root.join("cache"));
    fs::create_dir_all(&lib).unwrap();
    let mut engine = library(&lib, cache.to_str().unwrap());
    project_with(&mut engine, &[A]);
    let p = list(&mut engine).remove(0);
    assert_eq!(projects(clean(&mut engine, &p.id))[0].cache_bytes, 0);
}

#[test]
fn cleaning_refuses_a_malformed_or_unknown_id() {
    let root = temp_dir("ids");
    let (lib, cache) = (root.join("projects"), root.join("cache"));
    fs::create_dir_all(&lib).unwrap();
    write(&cache.join(format!("thumbs/{A_HASH}-0-128.jpg")), 100);
    let mut engine = library(&lib, cache.to_str().unwrap());
    project_with(&mut engine, &[A]);
    list(&mut engine);
    for id in ["../projects", "", "nosuchproject", "UPPER"] {
        assert!(
            matches!(clean(&mut engine, id), Some(event::Kind::CommandFailed(_))),
            "{id:?}"
        );
    }
    assert_eq!(tree(&cache), [format!("thumbs/{A_HASH}-0-128.jpg")]);
}

#[test]
fn cleaning_needs_a_library() {
    let mut engine = Engine::with_store(Box::new(FileStore));
    assert!(matches!(
        clean(&mut engine, "abc"),
        Some(event::Kind::CommandFailed(_))
    ));
}
