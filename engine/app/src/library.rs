//! The user's projects for Home (P1-089): files `<dir>/<id>.framix` in one folder.

use std::hash::{BuildHasher, Hasher};
use std::path::{Path, PathBuf};
use std::time::SystemTime;

use framix_core::time::TICKS_PER_SECOND;

use crate::proto::ProjectSummary;
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

/// The readable projects in `dir`, most recently saved first. Files that are not projects
/// (other names, backups, temp files) or don't decode, with no backup that does, are skipped.
// ponytail: decodes every project for its duration; keep a summary cache when lists grow
// long (OVL-015).
pub fn list(store: &dyn ProjectStore, dir: &Path) -> Result<Vec<ProjectSummary>, String> {
    let files = store.list(dir).map_err(|e| e.kind().to_string())?;
    let mut projects: Vec<ProjectSummary> = files
        .into_iter()
        .filter_map(|(file, modified)| summary(store, &file, modified))
        .collect();
    projects.sort_by(|a, b| b.modified_ms.cmp(&a.modified_ms).then(a.id.cmp(&b.id)));
    Ok(projects)
}

fn summary(store: &dyn ProjectStore, file: &Path, modified: SystemTime) -> Option<ProjectSummary> {
    if file.extension()? != EXTENSION {
        return None;
    }
    let id = file.file_stem()?.to_str()?;
    if !valid_id(id) {
        return None;
    }
    let (timeline, _) = crate::store::load_or_backup(store, file).ok()?;
    let modified_ms = modified
        .duration_since(SystemTime::UNIX_EPOCH)
        .map_or(0, |d| i64::try_from(d.as_millis()).unwrap_or(i64::MAX));
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
        project_bytes: 0,
        cache_bytes: 0,
    })
}
