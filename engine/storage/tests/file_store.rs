use std::fs;
use std::path::PathBuf;

use framix_app::store::ProjectStore;
use framix_storage::{BACKUPS, FileStore, MAX_PROJECT_BYTES};

/// A fresh, empty directory under the system temp dir.
fn temp_dir(name: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("framix-storage-{name}-{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    dir
}

#[test]
fn save_then_load_round_trips() {
    let path = temp_dir("round").join("p.framix");
    FileStore.save(&path, b"one").unwrap();
    assert_eq!(FileStore.load(&path).unwrap(), b"one");
}

#[test]
fn saves_keep_the_previous_versions_as_backups() {
    let dir = temp_dir("backups");
    let path = dir.join("p.framix");
    for bytes in [b"v1", b"v2", b"v3", b"v4"] {
        FileStore.save(&path, bytes).unwrap();
    }
    assert_eq!(FileStore.load(&path).unwrap(), b"v4");
    assert_eq!(fs::read(dir.join("p.framix.bak1")).unwrap(), b"v3");
    assert_eq!(fs::read(dir.join("p.framix.bak2")).unwrap(), b"v2");
    assert_eq!(BACKUPS, 2);
    assert!(!dir.join("p.framix.bak3").exists());
}

#[test]
fn a_stale_temp_file_from_a_crash_does_not_break_saving() {
    let dir = temp_dir("stale");
    let path = dir.join("p.framix");
    fs::write(dir.join("p.framix.tmp"), b"half written").unwrap();
    FileStore.save(&path, b"good").unwrap();
    assert_eq!(FileStore.load(&path).unwrap(), b"good");
    assert!(!dir.join("p.framix.tmp").exists());
}

#[test]
fn load_refuses_missing_and_oversized_files() {
    let dir = temp_dir("refuse");
    assert!(FileStore.load(&dir.join("missing.framix")).is_err());
    let big = dir.join("big.framix");
    fs::File::create(&big)
        .unwrap()
        .set_len(MAX_PROJECT_BYTES + 1)
        .unwrap();
    assert!(FileStore.load(&big).is_err());
}

#[test]
fn backups_are_named_newest_first() {
    let dir = temp_dir("backup-names");
    let path = dir.join("p.framix");
    assert_eq!(
        FileStore.backups(&path),
        vec![dir.join("p.framix.bak1"), dir.join("p.framix.bak2")]
    );
}

#[test]
fn a_file_set_aside_survives_later_saves() {
    let dir = temp_dir("aside");
    let path = dir.join("p.framix");
    fs::write(&path, b"old broken").unwrap();
    FileStore.set_aside(&path).unwrap();
    fs::write(&path, b"broken").unwrap();
    FileStore.set_aside(&path).unwrap();
    assert!(!path.exists());
    for bytes in [b"v1", b"v2", b"v3"] {
        FileStore.save(&path, bytes).unwrap();
    }
    assert_eq!(fs::read(dir.join("p.framix.broken")).unwrap(), b"broken");
    assert!(
        FileStore
            .set_aside(&dir.join("missing.framix"))
            .is_err_and(|e| e.kind() == std::io::ErrorKind::NotFound)
    );
}

#[test]
fn a_save_with_no_current_file_keeps_the_backups() {
    let dir = temp_dir("aside-save");
    let path = dir.join("p.framix");
    for bytes in [b"B", b"A", b"X"] {
        FileStore.save(&path, bytes).unwrap();
    }
    // Main is X (say broken), .bak1 = A, .bak2 = B; set X aside and write A back.
    FileStore.set_aside(&path).unwrap();
    FileStore.save(&path, b"A").unwrap();
    assert_eq!(fs::read(dir.join("p.framix.bak1")).unwrap(), b"A");
    assert_eq!(fs::read(dir.join("p.framix.bak2")).unwrap(), b"B");
}
