//! File storage: project files with atomic save and backups.

use std::ffi::OsString;
use std::fs::{self, File};
use std::io::{self, Read as _, Write as _};
use std::path::{Path, PathBuf};
use std::time::SystemTime;

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
        replace(path, bytes, true).map(drop)
    }

    /// [`FileStore::save`] with its file and directory syncs (each an F_FULLFSYNC on Apple, a
    /// flush of the whole drive cache) on a thread of their own, so the caller doesn't wait.
    /// The thread syncs the handle it wrote, not the path, so every version is synced even
    /// when later saves have already rotated it into the backups (a hard link shares that
    /// handle's inode); a `.bak1` copied where hard links fail is synced on that thread too.
    fn save_unsynced(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        let (file, backup_copy) = replace(path, bytes, false)?;
        let path = path.to_path_buf();
        // Best effort: if the thread doesn't start or the sync fails, the OS writes the file
        // back on its own schedule.
        let _ = std::thread::Builder::new()
            .name("framix-flush".into())
            .spawn(move || {
                if let Some(copy) = backup_copy {
                    let _ = copy.sync_all();
                }
                let _ = file.sync_all().and_then(|()| sync_parent(&path));
            });
        Ok(())
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

    /// Regular files directly in `dir` (no folders, no recursion); an entry that vanishes or
    /// can't be read while listing is skipped.
    fn list(&self, dir: &Path) -> io::Result<Vec<(PathBuf, SystemTime)>> {
        files(dir, false, |meta| meta.modified().ok())
    }

    /// Like [`FileStore::list`], but an entry that can't be read fails it (one that vanished
    /// is still skipped).
    fn list_strict(&self, dir: &Path) -> io::Result<Vec<(PathBuf, SystemTime)>> {
        files(dir, true, |meta| meta.modified().ok())
    }

    /// Like [`FileStore::list`]; a link is not a regular file, so what it points to is never
    /// counted (or removed by a caller cleaning what this lists). Names that share an inode (a
    /// hard link, e.g. a crash-left `.bak.tmp` or `.bak1` still linked to the project) hold its
    /// bytes once: the first listed gets the size, the others 0.
    fn sizes(&self, dir: &Path) -> io::Result<Vec<(PathBuf, u64)>> {
        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt as _;
            let mut seen = std::collections::HashSet::new();
            let mut sizes = files(dir, false, |meta| {
                Some((meta.dev(), meta.ino(), meta.len()))
            })?;
            sizes.sort();
            Ok(sizes
                .into_iter()
                .map(|(path, (dev, ino, len))| {
                    (path, if seen.insert((dev, ino)) { len } else { 0 })
                })
                .collect())
        }
        #[cfg(not(unix))]
        files(dir, false, |meta| Some(meta.len()))
    }

    fn backups(&self, path: &Path) -> Vec<PathBuf> {
        (1..=BACKUPS).map(|n| backup(path, n)).collect()
    }

    /// Plain write: a marker lost or torn by a crash only goes unreported.
    fn put(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        fs::write(path, bytes)
    }

    fn remove(&self, path: &Path) -> io::Result<()> {
        match fs::remove_file(path) {
            Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
            done => done,
        }
    }

    /// The backups, the `.broken` copy ([`ProjectStore::set_aside`]) and the temp files a
    /// crash mid-save can leave (`.tmp`, `.bak.tmp`). Never loaded: only counted and removed.
    fn copies(&self, path: &Path) -> Vec<PathBuf> {
        let mut copies = self.backups(path);
        copies.extend([aside(path), temp(path), backup_temp(path)]);
        copies
    }

    /// Renames the file to `<file>.broken`, over an earlier one.
    // ponytail: one slot; a second damaged file replaces the first. Keep numbered slots if a
    // validator change could ever refuse good files.
    fn set_aside(&self, path: &Path) -> io::Result<()> {
        fs::rename(path, aside(path))?;
        sync_parent(path)
    }
}

/// Regular files directly in `dir` with `info` of each; an entry that vanishes while listing
/// is skipped, one that can't be read (or has no `info`) is skipped too or, when `strict`,
/// fails the listing. The entry's own metadata: links are not followed.
fn files<T>(
    dir: &Path,
    strict: bool,
    info: impl Fn(&fs::Metadata) -> Option<T>,
) -> io::Result<Vec<(PathBuf, T)>> {
    let mut files = Vec::new();
    for entry in fs::read_dir(dir)? {
        let (path, meta) = match entry.and_then(|e| Ok((e.path(), e.metadata()?))) {
            Ok(listed) => listed,
            Err(e) if strict && e.kind() != io::ErrorKind::NotFound => return Err(e),
            Err(_) => continue,
        };
        if !meta.is_file() {
            continue;
        }
        match info(&meta) {
            Some(info) => files.push((path, info)),
            None if strict => return Err(io::ErrorKind::Unsupported.into()),
            None => {}
        }
    }
    Ok(files)
}

/// Writes `<file>.tmp`, rotates the backups, then renames the temp file over `path`; with
/// `sync`, the temp file is synced before and the directory after. Returns the written file
/// and, without `sync`, a `.bak1` copy that still needs a sync (see [`rotate_backups`]).
fn replace(path: &Path, bytes: &[u8], sync: bool) -> io::Result<(File, Option<File>)> {
    let tmp = temp(path);
    let written = write(&tmp, bytes, sync)
        .and_then(|file| rotate_backups(path, sync).map(|copy| (file, copy)))
        .and_then(|files| fs::rename(&tmp, path).map(|()| files));
    if written.is_err() {
        // Don't leave a large orphan behind (e.g. after a disk-full failure).
        let _ = fs::remove_file(&tmp);
    }
    let files = written?;
    if sync {
        sync_parent(path)?;
    }
    Ok(files)
}

fn write(path: &Path, bytes: &[u8], sync: bool) -> io::Result<File> {
    let mut file = File::create(path)?;
    file.write_all(bytes)?;
    if sync {
        file.sync_all()?;
    }
    Ok(file)
}

/// `path` with `suffix` appended to its file name (`p.framix` -> `p.framix.bak1`).
fn sibling(path: &Path, suffix: &str) -> PathBuf {
    let mut name = OsString::from(path.as_os_str());
    name.push(suffix);
    PathBuf::from(name)
}

/// Where [`FileStore::set_aside`] moves `path`.
fn aside(path: &Path) -> PathBuf {
    sibling(path, ".broken")
}

/// Where [`replace`] writes the new version before renaming it over `path`.
fn temp(path: &Path) -> PathBuf {
    sibling(path, ".tmp")
}

/// Where [`rotate_backups`] builds the new `.bak1`.
fn backup_temp(path: &Path) -> PathBuf {
    sibling(path, ".bak.tmp")
}

fn backup(path: &Path, n: usize) -> PathBuf {
    sibling(path, &format!(".bak{n}"))
}

/// Builds the new backup of the current file as `<file>.bak.tmp`, then shifts `.bak1`.. up
/// by one (dropping the oldest) and renames the temp to `.bak1`; a failure while building
/// leaves the backups as they were. Where hard links fail the backup is a copy, a new inode:
/// with `sync` it is synced here, otherwise it is returned for the caller to sync.
fn rotate_backups(path: &Path, sync: bool) -> io::Result<Option<File>> {
    // No current file (new, or set aside): nothing to keep, so the backups stay as they are.
    if !path.exists() {
        return Ok(None);
    }
    let tmp = backup_temp(path);
    let rotated = build_backup(path, &tmp, sync).and_then(|copy| {
        for n in (1..BACKUPS).rev() {
            match fs::rename(backup(path, n), backup(path, n + 1)) {
                Err(e) if e.kind() != io::ErrorKind::NotFound => return Err(e),
                _ => {}
            }
        }
        fs::rename(&tmp, backup(path, 1)).map(|()| copy)
    });
    if rotated.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    rotated
}

/// Makes `tmp` a copy of `path`: a hard link, which keeps the old file in place until the
/// rename, or a real copy where links fail (synced with `sync`, else returned to sync).
fn build_backup(path: &Path, tmp: &Path, sync: bool) -> io::Result<Option<File>> {
    // A crash may have left a temp that shares an inode with a kept version: unlink it, as
    // copying over it would overwrite that version.
    match fs::remove_file(tmp) {
        Err(e) if e.kind() != io::ErrorKind::NotFound => return Err(e),
        _ => {}
    }
    if fs::hard_link(path, tmp).is_ok() {
        return Ok(None);
    }
    fs::copy(path, tmp)?;
    let copy = File::open(tmp)?;
    if !sync {
        return Ok(Some(copy));
    }
    // On failure the save stops before the rename and the project file stays as it was.
    copy.sync_all()?;
    Ok(None)
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
