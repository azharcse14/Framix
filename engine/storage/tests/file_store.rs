use std::fs;

mod common;
use common::TempDir;

use framix_app::store::ProjectStore;
use framix_storage::{BACKUPS, FileStore, MAX_PROJECT_BYTES};

fn temp_dir(name: &str) -> TempDir {
    TempDir::new(&format!("framix-storage-{name}"))
}

#[test]
fn save_then_load_round_trips() {
    let dir = temp_dir("round");
    let path = dir.join("p.framix");
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

#[test]
fn remove_all_leaves_no_copy_of_the_file() {
    let dir = temp_dir("remove-all");
    let path = dir.join("p.framix");
    for bytes in [b"v1", b"v2", b"v3", b"v4"] {
        FileStore.save(&path, bytes).unwrap();
    }
    FileStore.set_aside(&path).unwrap();
    FileStore.save(&path, b"v5").unwrap();
    fs::write(dir.join("other.framix"), b"kept").unwrap();

    FileStore.remove_all(&path).unwrap();
    let left: Vec<_> = fs::read_dir(&dir)
        .unwrap()
        .map(|e| e.unwrap().file_name())
        .collect();
    assert_eq!(left, ["other.framix"], "no backup or set-aside copy left");
    FileStore.remove_all(&path).unwrap();
}

#[test]
fn remove_all_takes_temp_files_a_crash_left_behind() {
    let dir = temp_dir("remove-all-crash");
    let path = dir.join("p.framix");
    FileStore.save(&path, b"v1").unwrap();
    fs::write(dir.join("p.framix.tmp"), b"half a save").unwrap();
    fs::write(dir.join("p.framix.bak.tmp"), b"half a backup").unwrap();

    FileStore.remove_all(&path).unwrap();
    let left: Vec<_> = fs::read_dir(&dir).unwrap().collect();
    assert!(left.is_empty(), "crash leftovers kept: {left:?}");
}

#[test]
fn unsynced_saves_are_atomic_and_keep_backups_too() {
    let dir = temp_dir("unsynced");
    let path = dir.join("p.framix");
    FileStore.save(&path, b"v1").unwrap();
    FileStore.save_unsynced(&path, b"v2").unwrap();
    assert_eq!(FileStore.load(&path).unwrap(), b"v2");
    assert_eq!(fs::read(dir.join("p.framix.bak1")).unwrap(), b"v1");
    assert!(!dir.join("p.framix.tmp").exists());
}

/// Saves v1..v3, so the file is v3, `.bak1` v2 and `.bak2` v1.
fn three_saves(name: &str) -> (TempDir, std::path::PathBuf) {
    let dir = temp_dir(name);
    let path = dir.join("p.framix");
    for bytes in [b"v1", b"v2", b"v3"] {
        FileStore.save(&path, bytes).unwrap();
    }
    (dir, path)
}

fn versions(dir: &TempDir) -> [Vec<u8>; 3] {
    ["p.framix", "p.framix.bak1", "p.framix.bak2"].map(|n| fs::read(dir.join(n)).unwrap())
}

#[test]
fn a_save_that_cannot_build_its_backup_keeps_the_old_backups() {
    for sync in [true, false] {
        let (dir, path) = three_saves(&format!("rotate-fail-{sync}"));
        // A folder where the new backup is built makes building it fail.
        fs::create_dir(dir.join("p.framix.bak.tmp")).unwrap();
        for _retry in 0..2 {
            let saved = if sync {
                FileStore.save(&path, b"v4")
            } else {
                FileStore.save_unsynced(&path, b"v4")
            };
            assert_eq!(versions(&dir), [b"v3", b"v2", b"v1"], "sync: {sync}");
            assert!(saved.is_err(), "sync: {sync}");
        }
    }
}

#[test]
fn a_stale_backup_temp_from_a_crash_does_not_break_saving() {
    let (dir, path) = three_saves("stale-backup");
    // A crash after linking the new backup leaves the temp sharing the project's inode.
    fs::hard_link(&path, dir.join("p.framix.bak.tmp")).unwrap();
    FileStore.save(&path, b"v4").unwrap();
    assert_eq!(versions(&dir), [b"v4", b"v3", b"v2"]);
    assert!(!dir.join("p.framix.bak.tmp").exists());
}
