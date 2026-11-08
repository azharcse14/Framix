//! Port for project persistence. `framix_storage` implements it with files; tests use fakes.

use std::path::{Path, PathBuf};
use std::time::SystemTime;

use framix_core::timeline::Timeline;
use thiserror::Error;

use crate::project::{self, ProjectError};

/// Reads and writes whole project files.
pub trait ProjectStore: Send {
    /// Writes `bytes` to `path` so a crash leaves either the old or the new file, never a
    /// torn one, and keeps the previous saves as backups.
    fn save(&self, path: &Path, bytes: &[u8]) -> std::io::Result<()>;
    /// Reads the project file at `path`.
    fn load(&self, path: &Path) -> std::io::Result<Vec<u8>>;
    /// Files directly in `dir` with when each was last written.
    fn list(&self, dir: &Path) -> std::io::Result<Vec<(PathBuf, SystemTime)>> {
        let _ = dir;
        Err(std::io::ErrorKind::Unsupported.into())
    }
    /// Regular files directly in `dir` (no folders, links or recursion) with their sizes.
    fn sizes(&self, dir: &Path) -> std::io::Result<Vec<(PathBuf, u64)>> {
        let _ = dir;
        Err(std::io::ErrorKind::Unsupported.into())
    }
    /// The backups [`ProjectStore::save`] keeps for `path`, newest first (they may not exist).
    fn backups(&self, path: &Path) -> Vec<PathBuf> {
        let _ = path;
        Vec::new()
    }
    /// Writes a small file in place: no temp file, no backups (a marker that may be lost).
    fn put(&self, path: &Path, bytes: &[u8]) -> std::io::Result<()> {
        let _ = (path, bytes);
        Err(std::io::ErrorKind::Unsupported.into())
    }
    /// Removes the file at `path`; a missing file is not an error.
    fn remove(&self, path: &Path) -> std::io::Result<()> {
        let _ = path;
        Err(std::io::ErrorKind::Unsupported.into())
    }
    /// Removes the file at `path` and every copy this store keeps of it (backups, a file set
    /// aside); missing ones are not an error.
    fn remove_all(&self, path: &Path) -> std::io::Result<()> {
        self.remove(path)?;
        self.backups(path).iter().try_for_each(|b| self.remove(b))
    }
    /// Now, by the clock that stamps this store's files (see [`ProjectStore::list`]).
    fn now(&self) -> SystemTime {
        SystemTime::now()
    }
    /// Moves the file at `path` aside (replacing an earlier one set aside), so a new save
    /// can't overwrite or rotate it away.
    fn set_aside(&self, path: &Path) -> std::io::Result<()> {
        let _ = path;
        Err(std::io::ErrorKind::Unsupported.into())
    }
}

/// Why a project file didn't load.
#[derive(Debug, Error)]
pub enum LoadError {
    /// There is no file.
    #[error("no project file")]
    Missing,
    /// The file couldn't be read (the kind only: messages may hold the path).
    #[error("project file unreadable: {0}")]
    Unreadable(std::io::ErrorKind),
    /// The bytes are not a project this engine reads.
    #[error(transparent)]
    Project(#[from] ProjectError),
}

impl LoadError {
    /// The file is there but damaged, so a backup may stand in for it. A file from a newer
    /// app or one the OS won't read now is not damaged and is never replaced.
    pub fn is_broken(&self) -> bool {
        match self {
            Self::Project(ProjectError::TooNew(_)) => false,
            Self::Project(_) => true,
            Self::Unreadable(kind) => *kind == std::io::ErrorKind::InvalidData,
            Self::Missing => false,
        }
    }
}

/// Reads and decodes the project at `path`.
pub fn load(store: &dyn ProjectStore, path: &Path) -> Result<Timeline, LoadError> {
    let bytes = store.load(path).map_err(|e| match e.kind() {
        std::io::ErrorKind::NotFound => LoadError::Missing,
        kind => LoadError::Unreadable(kind),
    })?;
    Ok(project::decode(&bytes)?)
}

/// The project at `path`, or when that file is broken the newest backup that loads (`true`:
/// it came from a backup). The file's own error when no backup helps.
pub fn load_or_backup(
    store: &dyn ProjectStore,
    path: &Path,
) -> Result<(Timeline, bool), LoadError> {
    match load(store, path) {
        Err(e) if e.is_broken() => store
            .backups(path)
            .iter()
            .find_map(|b| load(store, b).ok())
            .map(|t| (t, true))
            .ok_or(e),
        loaded => loaded.map(|t| (t, false)),
    }
}
