//! The user's projects for Home (P1-089): files `<dir>/<id>.framix` in one folder.

use std::cmp::{Ordering, Reverse};
use std::collections::HashMap;
use std::hash::{BuildHasher, Hasher};
use std::path::{Path, PathBuf};
use std::time::SystemTime;

use framix_core::time::TICKS_PER_SECOND;
use prost::Message as _;

use crate::cache::CacheSizes;
use crate::project_proto::{LibraryEntry, LibraryIndex};
use crate::proto::{ListProjects, ProjectSort, ProjectSummary};
use crate::store::ProjectStore;

/// File extension of a library project.
const EXTENSION: &str = "framix";

/// Longest project id.
const MAX_ID_LEN: usize = 32;

/// Whether `id` is one the engine could have made: 1..=32 of `[0-9a-z]`, so it can't leave
/// the library folder.
pub fn valid_id(id: &str) -> bool {
    (1..=MAX_ID_LEN).contains(&id.len())
        && id
            .bytes()
            .all(|b| b.is_ascii_digit() || b.is_ascii_lowercase())
}

/// The file of project `id` in `dir`; None for an id [`valid_id`] refuses.
pub fn path(dir: &Path, id: &str) -> Option<PathBuf> {
    valid_id(id).then(|| dir.join(format!("{id}.{EXTENSION}")))
}

/// A fresh random id (16 hex digits) with no file in `dir` yet.
pub fn new_id(store: &dyn ProjectStore, dir: &Path) -> Result<String, String> {
    // A few tries: a clash among 2^64 ids means something else is wrong.
    for _ in 0..4 {
        // RandomState is seeded from the OS's randomness: no clock and no new dependency.
        let id = format!(
            "{:016x}",
            std::collections::hash_map::RandomState::new()
                .build_hasher()
                .finish()
        );
        let free = path(dir, &id).is_some_and(
            |p| matches!(store.load(&p), Err(e) if e.kind() == std::io::ErrorKind::NotFound),
        );
        if free {
            return Ok(id);
        }
    }
    Err("no free project id".into())
}

/// The file in the library folder naming the project open in the editor. It stays when the
/// engine stops without closing (a crash, or the OS ending the app), so the next launch knows.
/// Not a project file (no `.framix`), so [`list`] skips it.
const OPEN_MARKER: &str = "open-project";

/// Notes that project `id` is open in the editor. Best effort: without the marker a crash
/// only goes unreported.
pub fn mark_open(store: &dyn ProjectStore, dir: &Path, id: &str) {
    let _ = store.put(&dir.join(OPEN_MARKER), id.as_bytes());
}

/// Notes that no project is open (Home shows, or the engine stops normally). Best effort.
pub fn clear_open(store: &dyn ProjectStore, dir: &Path) {
    let _ = store.remove(&dir.join(OPEN_MARKER));
}

/// The project that was open when the last engine stopped without closing, if the marker
/// names a valid id; the marker is cleared.
// ponytail: the engine clears the marker while autosave fails, but edits of the last
// AUTOSAVE_DELAY before a crash are still not in the file; "saved up to your last edit" is
// that close. Save on every edit if it must be exact.
pub fn take_open(store: &dyn ProjectStore, dir: &Path) -> Option<String> {
    let bytes = store.load(&dir.join(OPEN_MARKER)).ok()?;
    clear_open(store, dir);
    String::from_utf8(bytes).ok().filter(|id| valid_id(id))
}

/// The readable projects in `dir` with their names and folders, most recently saved first.
/// Files that are not projects (other names, backups, temp files, the index) or don't decode,
/// with no backup that does, are skipped.
// ponytail: decodes every project for its duration; keep a summary cache when lists grow
// long (OVL-015).
/// `cache` gives each project's [`ProjectSummary::cache_bytes`].
pub fn list(
    store: &dyn ProjectStore,
    dir: &Path,
    cache: &CacheSizes,
) -> Result<Vec<ProjectSummary>, String> {
    // A newer app's index can't be read here; its projects are still listed.
    let index = match read_index(store, dir) {
        Ok(index) => purge(store, dir, index),
        Err(_) => HashMap::new(),
    };
    let files = store.list(dir).map_err(|e| e.kind().to_string())?;
    let mut projects: Vec<ProjectSummary> = files
        .into_iter()
        .filter_map(|(file, modified)| summary(store, &file, modified, cache))
        .map(|mut p| {
            if let Some(entry) = index.get(&p.id) {
                p.name.clone_from(&entry.name);
                p.folder.clone_from(&entry.folder);
                if entry.deleted_ms != 0 {
                    p.purge_ms = entry.deleted_ms.saturating_add(KEEP_DELETED_MS);
                }
            }
            p
        })
        .collect();
    projects.sort_by(newest_first);
    Ok(projects)
}

/// How long Recently deleted keeps a project: 30 days.
const KEEP_DELETED_MS: i64 = 30 * 24 * 60 * 60 * 1000;

/// Removes for good, with their backups, the projects deleted [`KEEP_DELETED_MS`] ago or
/// more, and returns the index without them. Best effort: what fails is tried next time.
fn purge(
    store: &dyn ProjectStore,
    dir: &Path,
    mut index: HashMap<String, LibraryEntry>,
) -> HashMap<String, LibraryEntry> {
    let now = unix_ms(store.now());
    let expired: Vec<String> = index
        .values()
        .filter(|e| e.deleted_ms != 0 && now >= e.deleted_ms.saturating_add(KEEP_DELETED_MS))
        .map(|e| e.id.clone())
        .collect();
    let mut removed = false;
    for id in expired {
        let Some(file) = path(dir, &id) else { continue };
        if store.remove_all(&file).is_ok() {
            index.remove(&id);
            removed = true;
        }
    }
    if removed {
        let _ = write_index(store, dir, index.clone());
    }
    index
}

/// `at` in milliseconds since the Unix epoch (0 before it).
fn unix_ms(at: SystemTime) -> i64 {
    at.duration_since(SystemTime::UNIX_EPOCH)
        .map_or(0, |d| i64::try_from(d.as_millis()).unwrap_or(i64::MAX))
}

fn newest_first(a: &ProjectSummary, b: &ProjectSummary) -> Ordering {
    b.modified_ms.cmp(&a.modified_ms).then(a.id.cmp(&b.id))
}

/// What [`find`] lists.
pub struct Found {
    /// The projects `op` asked for, in its order.
    pub projects: Vec<ProjectSummary>,
    /// Every folder that holds a project not deleted, A to Z ignoring case.
    pub folders: Vec<String>,
    /// How many projects are in Recently deleted.
    pub deleted: u32,
}

/// `projects` (from [`list`]) as `op` asks: Recently deleted or the others, searched by name,
/// in one folder, sorted.
pub fn find(projects: Vec<ProjectSummary>, op: &ListProjects) -> Found {
    let deleted = projects.iter().filter(|p| p.purge_ms != 0).count();
    let mut folders: Vec<String> = projects
        .iter()
        .filter(|p| !p.folder.is_empty() && p.purge_ms == 0)
        .map(|p| p.folder.clone())
        .collect();
    folders.sort_by_cached_key(|f| (f.to_lowercase(), f.clone()));
    folders.dedup();
    let query = op.query.trim().to_lowercase();
    let mut found: Vec<ProjectSummary> = projects
        .into_iter()
        .filter(|p| (p.purge_ms != 0) == op.deleted)
        .filter(|p| p.name.to_lowercase().contains(&query))
        .filter(|p| op.folder.is_empty() || p.folder == op.folder)
        .collect();
    match ProjectSort::try_from(op.sort) {
        Ok(ProjectSort::Name) => found.sort_by_cached_key(|p| {
            let newest = (Reverse(p.modified_ms), p.id.clone());
            (p.name.is_empty(), p.name.to_lowercase(), newest)
        }),
        Ok(ProjectSort::Size) => {
            found.sort_by(|a, b| b.bytes.cmp(&a.bytes).then_with(|| newest_first(a, b)));
        }
        // Already newest first; so is an order from a newer UI this engine doesn't know.
        Ok(ProjectSort::Unspecified) | Err(_) => {}
    }
    Found {
        projects: found,
        folders,
        // Far below u32::MAX: one per project file.
        deleted: u32::try_from(deleted).unwrap_or(u32::MAX),
    }
}

/// Longest project name, in characters.
const MAX_NAME_CHARS: usize = 80;
/// Longest folder name, in characters.
const MAX_FOLDER_CHARS: usize = 40;

/// Names project `id`; empty clears the name.
pub fn rename(store: &dyn ProjectStore, dir: &Path, id: &str, name: &str) -> Result<(), String> {
    let name = label(name, MAX_NAME_CHARS)?;
    update_entry(store, dir, id, |e| {
        e.name = name;
        Ok(())
    })
}

/// Puts project `id` in `folder`; empty takes it out of its folder.
pub fn move_to(store: &dyn ProjectStore, dir: &Path, id: &str, folder: &str) -> Result<(), String> {
    let folder = label(folder, MAX_FOLDER_CHARS)?;
    update_entry(store, dir, id, |e| {
        e.folder = folder;
        Ok(())
    })
}

/// Moves project `id` to Recently deleted.
pub fn delete(store: &dyn ProjectStore, dir: &Path, id: &str) -> Result<(), String> {
    let now = unix_ms(store.now()).max(1);
    update_entry(store, dir, id, |e| {
        if e.deleted_ms != 0 {
            return Err("already deleted".into());
        }
        e.deleted_ms = now;
        Ok(())
    })
}

/// Takes project `id` out of Recently deleted.
pub fn restore(store: &dyn ProjectStore, dir: &Path, id: &str) -> Result<(), String> {
    update_entry(store, dir, id, |e| {
        if e.deleted_ms == 0 {
            return Err("not deleted".into());
        }
        e.deleted_ms = 0;
        Ok(())
    })
}

/// Whether project `id` is in Recently deleted. An unreadable index says no.
pub fn is_deleted(store: &dyn ProjectStore, dir: &Path, id: &str) -> bool {
    read_index(store, dir).is_ok_and(|index| index.get(id).is_some_and(|e| e.deleted_ms != 0))
}

/// `text` trimmed; refused when longer than `max` characters or holding a control character.
fn label(text: &str, max: usize) -> Result<String, String> {
    let text = text.trim();
    if text.chars().count() > max {
        return Err(format!("longer than {max} characters"));
    }
    if text.chars().any(char::is_control) {
        return Err("control character".into());
    }
    Ok(text.to_owned())
}

fn update_entry(
    store: &dyn ProjectStore,
    dir: &Path,
    id: &str,
    change: impl FnOnce(&mut LibraryEntry) -> Result<(), String>,
) -> Result<(), String> {
    let file = path(dir, id).ok_or("malformed project id")?;
    store.load(&file).map_err(|_| "no such project")?;
    let mut index = read_index(store, dir)?;
    let before = index.get(id).cloned().unwrap_or_else(|| LibraryEntry {
        id: id.to_owned(),
        ..LibraryEntry::default()
    });
    let mut entry = before.clone();
    change(&mut entry)?;
    // Unchanged: a write would only rotate a good backup away.
    if entry == before {
        return Ok(());
    }
    if entry.name.is_empty() && entry.folder.is_empty() && entry.deleted_ms == 0 {
        index.remove(id);
    } else {
        index.insert(id.to_owned(), entry);
    }
    write_index(store, dir, index)
}

/// The library's file of names and folders, apart from the projects so autosave never
/// rewrites it. Saved like a project (atomic, with backups); not a `.framix` file, so [`list`]
/// skips it.
const INDEX: &str = "library.index";
/// Index format this engine writes and the newest it reads.
const INDEX_FORMAT_VERSION: u32 = 1;
/// Largest index read; far above 80-character names for thousands of projects.
const MAX_INDEX_BYTES: usize = 1024 * 1024;

/// The index by project id. Missing: empty. Damaged: its newest backup that decodes, else
/// empty (only names and folders are lost). Refused when a newer app wrote it, so a write
/// here can't drop what that app keeps.
fn read_index(
    store: &dyn ProjectStore,
    dir: &Path,
) -> Result<HashMap<String, LibraryEntry>, String> {
    let file = dir.join(INDEX);
    let decode = |bytes: Vec<u8>| {
        if bytes.len() > MAX_INDEX_BYTES {
            return None;
        }
        // proto3 decodes junk or empty bytes as zero fields; a real index has a version.
        LibraryIndex::decode(bytes.as_slice())
            .ok()
            .filter(|i| i.format_version != 0 && i.min_reader_version != 0)
    };
    let index = match store.load(&file) {
        Ok(bytes) => decode(bytes),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(HashMap::new()),
        // Not damaged, just unreadable now: a write would lose every entry.
        Err(e) => return Err(format!("library index unreadable: {}", e.kind())),
    };
    let index = index.or_else(|| {
        store
            .backups(&file)
            .iter()
            .find_map(|b| store.load(b).ok().and_then(decode))
    });
    let Some(index) = index else {
        return Ok(HashMap::new());
    };
    if index.min_reader_version > INDEX_FORMAT_VERSION {
        return Err("library index is from a newer app".into());
    }
    Ok(index
        .projects
        .into_iter()
        .map(|e| (e.id.clone(), e))
        .collect())
}

fn write_index(
    store: &dyn ProjectStore,
    dir: &Path,
    index: HashMap<String, LibraryEntry>,
) -> Result<(), String> {
    let mut projects: Vec<LibraryEntry> = index.into_values().collect();
    projects.sort_by(|a, b| a.id.cmp(&b.id));
    let bytes = LibraryIndex {
        format_version: INDEX_FORMAT_VERSION,
        min_reader_version: INDEX_FORMAT_VERSION,
        projects,
    }
    .encode_to_vec();
    if bytes.len() > MAX_INDEX_BYTES {
        return Err("library index full".into());
    }
    store
        .save(&dir.join(INDEX), &bytes)
        .map_err(|e| e.kind().to_string())
}

fn summary(
    store: &dyn ProjectStore,
    file: &Path,
    modified: SystemTime,
    cache: &CacheSizes,
) -> Option<ProjectSummary> {
    if file.extension()? != EXTENSION {
        return None;
    }
    let id = file.file_stem()?.to_str()?;
    if !valid_id(id) {
        return None;
    }
    let raw = store.load(file);
    let timeline = match raw.as_deref().map(crate::project::decode) {
        Ok(Ok(timeline)) => timeline,
        _ => crate::store::load_or_backup(store, file).ok()?.0,
    };
    let modified_ms = unix_ms(modified);
    let clips = timeline
        .tracks()
        .iter()
        .map(|t| t.clips().len())
        .sum::<usize>();
    Some(ProjectSummary {
        id: id.to_owned(),
        duration: timeline.duration().0,
        ticks_per_second: TICKS_PER_SECOND,
        modified_ms,
        // Timeline caps clips far below u32::MAX (project::MAX_CLIPS).
        clips: u32::try_from(clips).unwrap_or(u32::MAX),
        // The project file's size, even when a backup stood in for it.
        bytes: raw.map_or(0, |b| b.len() as u64),
        cache_bytes: crate::cache::project_bytes(cache, &timeline),
        ..ProjectSummary::default()
    })
}
