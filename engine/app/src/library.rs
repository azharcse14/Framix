//! The user's projects for Home (P1-089): files `<dir>/<id>.framix` in one folder.

use std::cmp::{Ordering, Reverse};
use std::collections::{BTreeSet, HashMap};
use std::hash::{BuildHasher, Hasher};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

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
/// `cache` gives each project's [`ProjectSummary::cache_bytes`]; `cache_dir` is the cache
/// folder, cleaned of the media of projects purged for good.
pub fn list(
    store: &dyn ProjectStore,
    dir: &Path,
    cache: &CacheSizes,
    cache_dir: Option<&Path>,
) -> Result<Vec<ProjectSummary>, String> {
    // A newer app's index can't be read here; its projects are still listed.
    let index = match read_index(store, dir) {
        Ok(index) => purge(store, dir, index, cache_dir),
        Err(_) => HashMap::new(),
    };
    let files = store.list(dir).map_err(|e| e.kind().to_string())?;
    let disk: HashMap<PathBuf, u64> = store.sizes(dir).unwrap_or_default().into_iter().collect();
    let media = media_sizes(store, dir);
    let mut projects: Vec<ProjectSummary> = files
        .into_iter()
        .filter_map(|(file, modified)| summary(store, &file, modified, cache, &disk, &media))
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

/// The project file's size (even when a backup stood in for it) plus its copies' (backups,
/// a file set aside), all deleted with it. `raw` stands in for the file when the store can't
/// list sizes.
fn project_bytes(
    store: &dyn ProjectStore,
    file: &Path,
    raw: Option<Vec<u8>>,
    disk: &HashMap<PathBuf, u64>,
) -> u64 {
    let own = disk
        .get(file)
        .copied()
        .or_else(|| raw.map(|b| b.len() as u64))
        .unwrap_or(0);
    store
        .copies(file)
        .iter()
        .filter_map(|b| disk.get(b))
        .fold(own, |sum, len| sum.saturating_add(*len))
}

/// Bytes of the media copies (`media/<name>`) `timeline` uses; one used twice counts once.
/// `content://` originals are the user's files, not the app's, and never count.
fn media_bytes(timeline: &framix_core::timeline::Timeline, media: &HashMap<String, u64>) -> u64 {
    timeline
        .all_media()
        .map(|(_, m)| m.uri())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .filter_map(|uri| media.get(uri))
        .fold(0, |sum, len| sum.saturating_add(*len))
}

/// How many days Recently deleted keeps a project (ProjectList.keep_deleted_days).
pub const KEEP_DELETED_DAYS: u32 = 30;
const KEEP_DELETED_MS: i64 = KEEP_DELETED_DAYS as i64 * 24 * 60 * 60 * 1000;

/// Removes for good, with their backups and the cache files of their media (in `cache_dir`),
/// the projects deleted [`KEEP_DELETED_MS`] ago or more, and returns the index without them.
/// Best effort: what fails is tried next time; caches of a project that won't load stay.
fn purge(
    store: &dyn ProjectStore,
    dir: &Path,
    mut index: HashMap<String, LibraryEntry>,
    cache_dir: Option<&Path>,
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
        // Read before the file goes: its media uris name the cache files.
        if let (Some(cache_dir), Ok((timeline, _))) =
            (cache_dir, crate::store::load_or_backup(store, &file))
        {
            let _ = crate::cache::clean(store, cache_dir, &timeline);
        }
        if store.remove_all(&file).is_ok() {
            index.remove(&id);
            removed = true;
        }
    }
    if removed {
        // Lost on a power loss: the next list drops the entries again (files already gone).
        let _ = write_index(store, dir, index.clone(), Durability::Unsynced);
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
    // A lost restore would bring back the old deleted time, and purge would remove the
    // project for good while the user thinks it is back: that write goes to the disk.
    let durability = if before.deleted_ms != 0 && entry.deleted_ms == 0 {
        Durability::Synced
    } else {
        Durability::Unsynced
    };
    if entry.name.is_empty() && entry.folder.is_empty() && entry.deleted_ms == 0 {
        index.remove(id);
    } else {
        index.insert(id.to_owned(), entry);
    }
    write_index(store, dir, index, durability)
}

/// The library's file of names and folders, apart from the projects so autosave never
/// rewrites it. Saved atomically with backups like a project; not a `.framix` file, so
/// [`list`] skips it.
///
/// It is not a cache: names, folders and Recently deleted live only here. Still, most writes
/// don't wait for the disk flush (P1-114): two F_FULLFSYNCs per op stalled Home 1-2 s under
/// disk load, so [`ProjectStore::save_unsynced`] flushes in the background. An app crash or
/// kill loses nothing (the OS already has the bytes and the rename); only a power loss or
/// kernel panic in the flush window can, and then [`read_index`] falls back to a backup or to
/// empty. That costs at most the latest names, folders or deletes (a deleted project comes
/// back); project files keep their full durability. A restore waits for the flush (see
/// `update_entry`).
// ponytail: in-flight backup renames may reach the disk in any order on a power loss, so a
// synced restore can still be lost if later writes rotate it out and all are torn. Sync every
// write whose loss could purge a project if that ever shows up.
const INDEX: &str = "library.index";
/// Index format this engine writes and the newest it reads.
const INDEX_FORMAT_VERSION: u32 = 1;
/// Largest index read or written; far above 80-character names for thousands of projects.
pub const MAX_INDEX_BYTES: usize = 1024 * 1024;

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

/// Whether an index write is forced to the disk (see [`INDEX`]).
enum Durability {
    Synced,
    Unsynced,
}

fn write_index(
    store: &dyn ProjectStore,
    dir: &Path,
    index: HashMap<String, LibraryEntry>,
    durability: Durability,
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
    let file = dir.join(INDEX);
    match durability {
        Durability::Synced => store.save(&file, &bytes),
        Durability::Unsynced => store.save_unsynced(&file, &bytes),
    }
    .map_err(|e| e.kind().to_string())
}

/// Folder of the media the app copied in, next to the library folder: a `media/<name>` uri
/// is relative to the library's parent (the platform's app folder, P1-011). iOS sets this layout
/// in app/ios/Runner/MediaPicker.swift (projectsDir, store()); change both together.
const MEDIA: &str = "media";

/// The app's media copies by uri (`media/<name>`), from one listing of the media folder; a
/// missing or unlistable folder counts as empty.
fn media_sizes(store: &dyn ProjectStore, dir: &Path) -> HashMap<String, u64> {
    let Some(app) = dir.parent() else {
        return HashMap::new();
    };
    store
        .sizes(&app.join(MEDIA))
        .unwrap_or_default()
        .into_iter()
        .filter_map(|(file, len)| Some((media_uri(&file)?, len)))
        .collect()
}

/// The uri a project names the media copy `file` by: `media/<name>`.
fn media_uri(file: &Path) -> Option<String> {
    Some(format!("{MEDIA}/{}", file.file_name()?.to_str()?))
}

/// How long a media copy stays after its last write even when nothing refers to it: the
/// platform copies a picked file in before the engine hears of it (an import in flight).
const FRESH_COPY: Duration = Duration::from_secs(60 * 60);

/// Deletes the app's media copies (`media/` next to `dir`) and the cache files (in
/// `cache_dir`) of media that no project in `dir` (its file, backups or other copies) and no
/// timeline of `open` refers to (ENG-063). Only files listed in those folders are removed; no
/// path is built from a project's uri. Deletes nothing when a project file or backup can't be
/// read: it may refer to any copy. A copy written within [`FRESH_COPY`] stays. Best effort.
// ponytail: decodes every project on the command thread, like [`list`]; move it to a worker
// with the summary cache (OVL-015) if launches slow down.
pub fn sweep<'a>(
    store: &dyn ProjectStore,
    dir: &Path,
    cache_dir: Option<&Path>,
    open: impl IntoIterator<Item = &'a framix_core::timeline::Timeline>,
) {
    let Some(mut used) = saved_uris(store, dir) else {
        return;
    };
    for timeline in open {
        used.extend(uris(timeline));
    }
    if let Some(app) = dir.parent() {
        let now = store.now();
        for (file, written) in store.list(&app.join(MEDIA)).unwrap_or_default() {
            // A write time ahead of the clock counts as fresh.
            let fresh = now
                .duration_since(written)
                .map_or(true, |age| age < FRESH_COPY);
            if !fresh && media_uri(&file).is_some_and(|uri| !used.contains(&uri)) {
                let _ = store.remove(&file);
            }
        }
    }
    if let Some(cache_dir) = cache_dir {
        crate::cache::keep_only(store, cache_dir, &used);
    }
}

/// The media uris of every project file in `dir` (a `<name>.framix` and each copy next to
/// it). None when `dir` can't be listed or a project or backup doesn't load; copies the
/// engine never loads (set aside as damaged, or left by a crash mid-save) count only when
/// they decode.
fn saved_uris(store: &dyn ProjectStore, dir: &Path) -> Option<BTreeSet<String>> {
    let files = store.list(dir).ok()?;
    let mut loadable = BTreeSet::new();
    for (file, _) in &files {
        if file.extension().is_some_and(|e| e == EXTENSION) {
            loadable.insert(file.clone());
            loadable.extend(store.backups(file));
        }
    }
    let marker = format!(".{EXTENSION}");
    let mut used = BTreeSet::new();
    for (file, _) in files {
        let project = file
            .file_name()
            .and_then(|n| n.to_str())
            .is_some_and(|n| n.contains(&marker));
        if !project {
            continue;
        }
        match crate::store::load(store, &file) {
            Ok(timeline) => used.extend(uris(&timeline)),
            // Gone since the listing.
            Err(crate::store::LoadError::Missing) => {}
            Err(_) if !loadable.contains(&file) => {}
            Err(_) => return None,
        }
    }
    Some(used)
}

/// Every media uri `timeline` registers.
fn uris(timeline: &framix_core::timeline::Timeline) -> impl Iterator<Item = String> + '_ {
    timeline.all_media().map(|(_, m)| m.uri().to_owned())
}

/// `disk` is the library folder's file sizes, `media` [`media_sizes`].
fn summary(
    store: &dyn ProjectStore,
    file: &Path,
    modified: SystemTime,
    cache: &CacheSizes,
    disk: &HashMap<PathBuf, u64>,
    media: &HashMap<String, u64>,
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
        bytes: project_bytes(store, file, raw.ok(), disk)
            .saturating_add(media_bytes(&timeline, media)),
        cache_bytes: crate::cache::project_bytes(cache, &timeline),
        ..ProjectSummary::default()
    })
}
