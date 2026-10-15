//! File storage: project files with atomic save and backups.

use std::io;
use std::path::Path;

use framix_app::store::ProjectStore;

/// Largest project file [`FileStore::load`] reads; anything bigger is refused as not ours.
pub const MAX_PROJECT_BYTES: u64 = 64 * 1024 * 1024;

/// How many previous saves are kept next to the project (`<file>.bak1` is the newest).
pub const BACKUPS: usize = 2;

/// Project files on the local file system.
#[derive(Debug, Default)]
pub struct FileStore;

impl ProjectStore for FileStore {
    fn save(&self, _path: &Path, _bytes: &[u8]) -> io::Result<()> {
        Err(io::ErrorKind::Unsupported.into())
    }

    fn load(&self, _path: &Path) -> io::Result<Vec<u8>> {
        Err(io::ErrorKind::Unsupported.into())
    }
}
