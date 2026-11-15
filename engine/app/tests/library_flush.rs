//! Library ops don't force the index to the disk, except restoring a project (P1-114).

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use framix_app::library;
use framix_app::store::ProjectStore;

const DIR: &str = "/data/projects";
const ID: &str = "abc";

/// In-memory files that count the writes forced to the disk ([`ProjectStore::save`]).
#[derive(Default)]
struct MemStore {
    files: Mutex<HashMap<PathBuf, Vec<u8>>>,
    full_flushes: Mutex<usize>,
}

impl MemStore {
    fn with_project() -> Self {
        let store = Self::default();
        store
            .files
            .lock()
            .unwrap()
            .insert(PathBuf::from(format!("{DIR}/{ID}.framix")), Vec::new());
        store
    }

    /// Full flushes during `op`.
    fn flushes(&self, op: impl FnOnce(&Self) -> Result<(), String>) -> usize {
        let before = *self.full_flushes.lock().unwrap();
        op(self).expect("library op");
        *self.full_flushes.lock().unwrap() - before
    }
}

impl ProjectStore for MemStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        *self.full_flushes.lock().unwrap() += 1;
        self.save_unsynced(path, bytes)
    }

    fn save_unsynced(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
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
}

#[test]
fn rename_move_and_delete_write_the_index_without_a_full_flush() {
    let store = MemStore::with_project();
    let dir = Path::new(DIR);
    assert_eq!(store.flushes(|s| library::rename(s, dir, ID, "Trip")), 0);
    assert_eq!(store.flushes(|s| library::move_to(s, dir, ID, "Travel")), 0);
    assert_eq!(store.flushes(|s| library::delete(s, dir, ID)), 0);
    assert!(library::is_deleted(&store, dir, ID));
}

#[test]
fn restore_forces_the_index_to_the_disk() {
    // A lost restore would bring back the old deleted time, and the project would be purged
    // for good while the user thinks it is back.
    let store = MemStore::with_project();
    let dir = Path::new(DIR);
    library::delete(&store, dir, ID).expect("delete");
    assert_eq!(store.flushes(|s| library::restore(s, dir, ID)), 1);
    assert!(!library::is_deleted(&store, dir, ID));
}

#[test]
fn renaming_or_moving_a_deleted_project_keeps_it_deleted_without_a_full_flush() {
    let store = MemStore::with_project();
    let dir = Path::new(DIR);
    library::delete(&store, dir, ID).expect("delete");
    assert_eq!(store.flushes(|s| library::rename(s, dir, ID, "Trip")), 0);
    assert_eq!(store.flushes(|s| library::move_to(s, dir, ID, "Travel")), 0);
    assert!(library::is_deleted(&store, dir, ID));
}
