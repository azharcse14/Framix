//! Port for project persistence. `framix_storage` implements it with files; tests use fakes.

use std::path::{Path, PathBuf};
use std::time::SystemTime;

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
}
