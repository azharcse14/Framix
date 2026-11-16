//! ENG-063: when the library opens, app media copies (`<app>/media`) and cache files that no
//! saved project, backup or open undo history refers to are deleted; nothing else is touched,
//! and a project that can't be read keeps everything.

use std::collections::{BTreeSet, HashMap};
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

use framix_app::engine::Engine;
use framix_app::project::encode_for_save;
use framix_app::proto::{
    Command, ImportMedia, MediaItem, MediaKind, OpenLibrary, RemoveClip, Undo, command, event,
};
use framix_app::store::ProjectStore;
use framix_core::media::{Media, MediaKind as CoreKind, RawMedia};
use framix_core::timeline::Timeline;

const DIR: &str = "/data/projects";
const CACHE: &str = "/data/cache";
/// SHA-256 of `media/a.jpg` and `media/gone.jpg` (`shasum -a 256`): their cache file names.
const KEY_A: &str = "7aecb2d1a8f1e1a1bb1a226552bf563f3fc4eab13817d66dd0e3fc4817775b33";
const KEY_GONE: &str = "2213a821787e981936ffda22bddce83134e8ee845e41e170f8018904fb71b196";

/// The store's clock: a day after the files below were written.
const NOW: Duration = Duration::from_secs(24 * 60 * 60);

/// File bytes and write time by path.
type Files = HashMap<PathBuf, (Vec<u8>, SystemTime)>;

/// In-memory files with their write times.
#[derive(Clone, Default)]
struct MemStore {
    files: Arc<Mutex<Files>>,
}

impl MemStore {
    fn put_at(&self, path: &str, bytes: &[u8], at: Duration) {
        self.files
            .lock()
            .unwrap()
            .insert(path.into(), (bytes.to_vec(), SystemTime::UNIX_EPOCH + at));
    }

    fn put(&self, path: &str, bytes: &[u8]) {
        self.put_at(path, bytes, Duration::from_secs(1));
    }

    fn project(&self, path: &str, uris: &[&str]) {
        let mut tl = Timeline::default();
        tl.import(uris.iter().map(|u| photo(u)).collect()).unwrap();
        self.put(path, &encode_for_save(&tl).unwrap());
    }

    fn paths(&self) -> BTreeSet<PathBuf> {
        self.files.lock().unwrap().keys().cloned().collect()
    }
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        self.put_at(path.to_str().unwrap(), bytes, NOW);
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

    fn sizes(&self, dir: &Path) -> io::Result<Vec<(PathBuf, u64)>> {
        let files = self.files.lock().unwrap();
        Ok(files
            .iter()
            .filter(|(path, _)| path.parent() == Some(dir))
            .map(|(path, (bytes, _))| (path.clone(), bytes.len() as u64))
            .collect())
    }

    fn backups(&self, path: &Path) -> Vec<PathBuf> {
        (1..=3)
            .map(|n| PathBuf::from(format!("{}.bak{n}", path.display())))
            .collect()
    }

    fn put(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        self.put_at(path.to_str().unwrap(), bytes, NOW);
        Ok(())
    }

    fn remove(&self, path: &Path) -> io::Result<()> {
        self.files.lock().unwrap().remove(path);
        Ok(())
    }

    fn now(&self) -> SystemTime {
        SystemTime::UNIX_EPOCH + NOW
    }
}

fn photo(uri: &str) -> Media {
    Media::validate(RawMedia {
        uri: uri.into(),
        kind: CoreKind::Image,
        duration_value: 0,
        duration_timescale: 0,
        width: 4,
        height: 3,
        rotation: 0,
        codec: String::new(),
    })
    .unwrap()
}

fn run(engine: &mut Engine, kind: command::Kind) -> Option<event::Kind> {
    engine
        .handle(Command {
            id: 1,
            kind: Some(kind),
        })
        .kind
}

fn open_library(engine: &mut Engine) {
    let reply = run(
        engine,
        command::Kind::OpenLibrary(OpenLibrary {
            dir: DIR.into(),
            cache_dir: CACHE.into(),
        }),
    );
    assert!(
        matches!(reply, Some(event::Kind::CommandAccepted(_))),
        "{reply:?}"
    );
}

/// Opens the library on `store` and returns the paths deleted.
fn sweep(store: &MemStore) -> BTreeSet<PathBuf> {
    let before = store.paths();
    open_library(&mut Engine::with_store(Box::new(store.clone())));
    before.difference(&store.paths()).cloned().collect()
}

fn paths(list: &[&str]) -> BTreeSet<PathBuf> {
    list.iter().map(PathBuf::from).collect()
}

#[test]
fn a_copy_no_project_uses_is_deleted() {
    let store = MemStore::default();
    store.project("/data/projects/p1.framix", &["media/a.jpg"]);
    store.put("/data/media/a.jpg", b"a");
    store.put("/data/media/gone.jpg", b"g");
    assert_eq!(sweep(&store), paths(&["/data/media/gone.jpg"]));
}

#[test]
fn copies_another_project_or_a_backup_uses_are_kept() {
    let store = MemStore::default();
    store.project("/data/projects/p1.framix", &["media/a.jpg"]);
    store.project("/data/projects/p2.framix", &["media/b.jpg"]);
    store.project("/data/projects/p1.framix.bak2", &["media/c.jpg"]);
    for name in ["a", "b", "c"] {
        store.put(&format!("/data/media/{name}.jpg"), b"x");
    }
    assert_eq!(sweep(&store), BTreeSet::new());
}

#[test]
fn copies_only_the_open_undo_history_uses_are_kept() {
    let store = MemStore::default();
    store.put("/data/media/undone.jpg", b"u");
    store.put("/data/media/removed.jpg", b"r");
    store.put("/data/media/gone.jpg", b"g");
    let mut engine = Engine::with_store(Box::new(store.clone()));
    let import = |uri: &str| {
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: uri.into(),
                kind: MediaKind::Image as i32,
                width: 4,
                height: 3,
                ..Default::default()
            }],
        })
    };
    // Only the redo step has it.
    run(&mut engine, import("media/undone.jpg"));
    run(&mut engine, command::Kind::Undo(Undo {}));
    // Its clip is gone; the undo step has it.
    let Some(event::Kind::TimelineChanged(t)) = run(&mut engine, import("media/removed.jpg"))
    else {
        panic!("import refused");
    };
    let clip_id = t.tracks[0].clips[0].id;
    run(
        &mut engine,
        command::Kind::RemoveClip(RemoveClip { clip_id }),
    );
    open_library(&mut engine);
    assert_eq!(
        store.paths(),
        paths(&["/data/media/undone.jpg", "/data/media/removed.jpg"])
    );
}

#[test]
fn a_project_that_does_not_decode_keeps_every_file() {
    let store = MemStore::default();
    store.project("/data/projects/p1.framix", &["media/a.jpg"]);
    store.put("/data/projects/p2.framix", b"\xff\xff\xff not a project");
    store.put("/data/media/gone.jpg", b"g");
    store.put(&format!("{CACHE}/thumbs/{KEY_GONE}-1.jpg"), b"t");
    assert_eq!(sweep(&store), BTreeSet::new());
}

#[test]
fn a_backup_that_does_not_decode_keeps_every_file() {
    let store = MemStore::default();
    store.project("/data/projects/p1.framix", &["media/a.jpg"]);
    store.put(
        "/data/projects/p1.framix.bak1",
        b"\xff\xff\xff not a project",
    );
    store.put("/data/media/gone.jpg", b"g");
    assert_eq!(sweep(&store), BTreeSet::new());
}

#[test]
fn only_files_in_the_media_and_cache_folders_are_deleted() {
    let store = MemStore::default();
    // The decoder refuses uris out of the media folder; an original the user owns is kept.
    store.project(
        "/data/projects/p1.framix",
        &["content://media/external/x.jpg"],
    );
    store.put("/data/projects/notes.txt", b"n");
    store.put("/data/projects/library.index", b"i");
    store.put("/data/elsewhere/x.jpg", b"x");
    store.put("/data/elsewhere/y.jpg", b"y");
    store.put("/data/x.jpg", b"x");
    store.put("/data/media/sub/x.jpg", b"x");
    store.put(&format!("{CACHE}/other/{KEY_GONE}-1.jpg"), b"o");
    store.put("/data/media/gone.jpg", b"g");
    assert_eq!(sweep(&store), paths(&["/data/media/gone.jpg"]));
}

#[test]
fn a_copy_written_within_the_hour_is_kept() {
    let store = MemStore::default();
    store.project("/data/projects/p1.framix", &["media/a.jpg"]);
    // An import in flight: copied, not yet known to the engine.
    store.put_at("/data/media/new.jpg", b"n", NOW - Duration::from_secs(60));
    store.put("/data/media/gone.jpg", b"g");
    assert_eq!(sweep(&store), paths(&["/data/media/gone.jpg"]));
}

#[test]
fn cache_files_of_media_no_project_uses_are_deleted() {
    let store = MemStore::default();
    store.project("/data/projects/p1.framix", &["media/a.jpg"]);
    store.put(&format!("{CACHE}/thumbs/{KEY_A}-1.jpg"), b"t");
    store.put(&format!("{CACHE}/proxies/{KEY_A}-540.mov"), b"p");
    store.put(&format!("{CACHE}/thumbs/{KEY_GONE}-1.jpg"), b"t");
    store.put(&format!("{CACHE}/proxies/{KEY_GONE}-540.mov"), b"p");
    // Being written now: never removed mid-write.
    store.put_at(&format!("{CACHE}/thumbs/{KEY_GONE}-2.jpg.part"), b"t", NOW);
    assert_eq!(
        sweep(&store),
        paths(&[
            &format!("{CACHE}/thumbs/{KEY_GONE}-1.jpg"),
            &format!("{CACHE}/proxies/{KEY_GONE}-540.mov"),
        ])
    );
}
