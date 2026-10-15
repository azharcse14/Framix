//! Port for project persistence. `framix_storage` implements it with files; tests use fakes.

use std::path::Path;

/// Reads and writes whole project files.
pub trait ProjectStore: Send {
    /// Writes `bytes` to `path` so a crash leaves either the old or the new file, never a
    /// torn one, and keeps the previous saves as backups.
    fn save(&self, path: &Path, bytes: &[u8]) -> std::io::Result<()>;
    /// Reads the project file at `path`.
    fn load(&self, path: &Path) -> std::io::Result<Vec<u8>>;
}
