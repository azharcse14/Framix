//! File storage: project files with atomic save and backups.

use std::ffi::OsString;
use std::fs::{self, File};
use std::io::{self, Read as _, Write as _};
use std::path::{Path, PathBuf};

use framix_app::store::ProjectStore;

/// Largest project file [`FileStore::load`] reads (defined with the format's other limits).
pub use framix_app::project::MAX_PROJECT_BYTES;

/// How many previous saves are kept next to the project (`<file>.bak1` is the newest).
pub const BACKUPS: usize = 2;

/// Project files on the local file system.
#[derive(Debug, Default)]
pub struct FileStore;

impl ProjectStore for FileStore {
    /// Writes `<file>.tmp`, syncs it, rotates the backups, then renames the temp file over
    /// the project. The project file exists at every point: the newest backup is a hard link
    /// to the old file, and the rename replaces it atomically.
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        let tmp = sibling(path, ".tmp");
        let written = write_synced(&tmp, bytes)
            .and_then(|()| rotate_backups(path))
            .and_then(|()| fs::rename(&tmp, path));
        if written.is_err() {
            // Don't leave a large orphan behind (e.g. after a disk-full failure).
            let _ = fs::remove_file(&tmp);
        }
        written?;
        sync_parent(path)
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        let mut bytes = Vec::new();
        File::open(path)?
            .take(MAX_PROJECT_BYTES + 1)
            .read_to_end(&mut bytes)?;
        if bytes.len() as u64 > MAX_PROJECT_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "project file too large",
            ));
        }
        Ok(bytes)
    }
}

fn write_synced(path: &Path, bytes: &[u8]) -> io::Result<()> {
    let mut file = File::create(path)?;
    file.write_all(bytes)?;
    file.sync_all()
}

/// `path` with `suffix` appended to its file name (`p.framix` -> `p.framix.bak1`).
fn sibling(path: &Path, suffix: &str) -> PathBuf {
    let mut name = OsString::from(path.as_os_str());
    name.push(suffix);
    PathBuf::from(name)
}

fn backup(path: &Path, n: usize) -> PathBuf {
    sibling(path, &format!(".bak{n}"))
}

/// Shifts `.bak1`.. up by one (dropping the oldest) and makes `.bak1` the current file.
fn rotate_backups(path: &Path) -> io::Result<()> {
    for n in (1..BACKUPS).rev() {
        match fs::rename(backup(path, n), backup(path, n + 1)) {
            Err(e) if e.kind() != io::ErrorKind::NotFound => return Err(e),
            _ => {}
        }
    }
    if !path.exists() {
        return Ok(());
    }
    let newest = backup(path, 1);
    match fs::remove_file(&newest) {
        Err(e) if e.kind() != io::ErrorKind::NotFound => return Err(e),
        _ => {}
    }
    // A hard link keeps the old file in place until the rename; copy where links fail.
    fs::hard_link(path, &newest).or_else(|_| fs::copy(path, &newest).map(drop))
}

/// Makes the rename durable: syncs the directory entry (Unix; a no-op elsewhere).
fn sync_parent(path: &Path) -> io::Result<()> {
    #[cfg(unix)]
    if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
        File::open(dir)?.sync_all()?;
    }
    #[cfg(not(unix))]
    let _ = path;
    Ok(())
}
