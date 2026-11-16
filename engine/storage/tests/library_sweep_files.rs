//! ENG-063 on real folders: opening the library deletes only the unused regular files listed
//! directly in `media/`, `thumbs/` and `proxies/`; links, what they point to, and sub-folders
//! stay.

use std::fs;
use std::path::Path;
use std::time::{Duration, SystemTime};

mod common;
use common::TempDir;

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, ImportMedia, ListProjects, MediaItem, MediaKind, NewProject, OpenLibrary, command,
    event,
};
use framix_storage::FileStore;

/// SHA-256 hex of `media/a.jpg` and `media/gone.jpg` (`shasum -a 256`).
const A_HASH: &str = "7aecb2d1a8f1e1a1bb1a226552bf563f3fc4eab13817d66dd0e3fc4817775b33";
const GONE_HASH: &str = "2213a821787e981936ffda22bddce83134e8ee845e41e170f8018904fb71b196";

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 0,
            kind: Some(kind),
        })
        .kind
}

fn library(lib: &Path, cache: &Path) -> Engine {
    let mut engine = Engine::with_store(Box::new(FileStore));
    let e = run(
        &mut engine,
        command::Kind::OpenLibrary(OpenLibrary {
            dir: lib.to_str().unwrap().into(),
            cache_dir: cache.to_str().unwrap().into(),
        }),
    );
    assert!(matches!(e, Some(event::Kind::CommandAccepted(_))), "{e:?}");
    engine
}

/// A file written a day ago, so it is not a fresh copy.
fn old_file(path: &Path) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, b"x").unwrap();
    let day_ago = SystemTime::now() - Duration::from_secs(24 * 60 * 60);
    fs::File::options()
        .write(true)
        .open(path)
        .unwrap()
        .set_modified(day_ago)
        .unwrap();
}

/// Every path under `dir`, links and folders included, relative and sorted.
fn tree(dir: &Path) -> Vec<String> {
    fn walk(root: &Path, dir: &Path, out: &mut Vec<String>) {
        for entry in fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            out.push(path.strip_prefix(root).unwrap().display().to_string());
            if path.is_dir() && !path.is_symlink() {
                walk(root, &path, out);
            }
        }
    }
    let mut out = Vec::new();
    walk(dir, dir, &mut out);
    out.sort();
    out
}

#[test]
fn only_unused_regular_files_in_the_app_folders_are_deleted() {
    let root = TempDir::new("framix-sweep-files");
    let (lib, cache) = (root.join("projects"), root.join("cache"));
    fs::create_dir_all(&lib).unwrap();
    {
        let mut engine = library(&lib, &cache);
        run(&mut engine, command::Kind::NewProject(NewProject {}));
        let e = run(
            &mut engine,
            command::Kind::ImportMedia(ImportMedia {
                items: vec![MediaItem {
                    uri: "media/a.jpg".into(),
                    kind: MediaKind::Image as i32,
                    width: 10,
                    height: 10,
                    ..Default::default()
                }],
            }),
        );
        assert!(matches!(e, Some(event::Kind::TimelineChanged(_))), "{e:?}");
        // Listing saves the open project first.
        let e = run(
            &mut engine,
            command::Kind::ListProjects(ListProjects::default()),
        );
        assert!(
            matches!(e, Some(event::Kind::ProjectList(l)) if l.projects.len() == 1),
            "the project is saved"
        );
    }
    let outside = root.join("outside.jpg");
    for file in [
        root.join("media/a.jpg"),
        root.join("media/gone.jpg"),
        root.join("media/sub/gone.jpg"),
        cache.join(format!("thumbs/{A_HASH}-0-128.jpg")),
        cache.join(format!("thumbs/{GONE_HASH}-0-128.jpg")),
        cache.join(format!("proxies/{GONE_HASH}-1280.mov")),
        outside.clone(),
    ] {
        old_file(&file);
    }
    #[cfg(unix)]
    {
        std::os::unix::fs::symlink(&outside, root.join("media/link.jpg")).unwrap();
        std::os::unix::fs::symlink(&outside, cache.join(format!("thumbs/{GONE_HASH}-9.jpg")))
            .unwrap();
    }
    let before = tree(&root);

    library(&lib, &cache);

    let gone = [
        "cache/proxies/{GONE_HASH}-1280.mov",
        "cache/thumbs/{GONE_HASH}-0-128.jpg",
        "media/gone.jpg",
    ]
    .map(|p| p.replace("{GONE_HASH}", GONE_HASH));
    let expected: Vec<String> = before.into_iter().filter(|p| !gone.contains(p)).collect();
    assert_eq!(tree(&root), expected);
    assert!(expected.contains(&"media/sub/gone.jpg".to_owned()));
    assert_eq!(fs::read(&outside).unwrap(), b"x");
}
