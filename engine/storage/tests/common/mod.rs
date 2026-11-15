//! Shared helpers for the storage integration tests.

use std::fs;
use std::ops::Deref;
use std::path::{Path, PathBuf};

/// A fresh, empty directory under the system temp dir, removed again on drop.
pub struct TempDir(PathBuf);

impl TempDir {
    /// Creates `<temp>/<name>-<pid>`, emptying any leftover from an earlier run.
    pub fn new(name: &str) -> Self {
        let dir = std::env::temp_dir().join(format!("{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        Self(dir)
    }
}

impl Deref for TempDir {
    type Target = Path;
    fn deref(&self) -> &Path {
        &self.0
    }
}

impl AsRef<Path> for TempDir {
    fn as_ref(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        // Best effort: a failed cleanup must not turn a passing test into a panic.
        let _ = fs::remove_dir_all(&self.0);
    }
}
