//! FileStore::list for the project library (P1-089).

use std::fs;
use std::time::SystemTime;

mod common;
use common::TempDir;

use framix_app::store::ProjectStore;
use framix_storage::FileStore;

fn temp_dir(name: &str) -> TempDir {
    TempDir::new(&format!("framix-list-{name}"))
}

#[test]
fn lists_the_files_in_a_folder_with_their_write_times() {
    let tmp = temp_dir("files");
    let dir = tmp.to_path_buf();
    let before = SystemTime::now() - std::time::Duration::from_secs(5);
    FileStore.save(&dir.join("a.framix"), b"1").unwrap();
    FileStore.save(&dir.join("a.framix"), b"2").unwrap();
    fs::create_dir(dir.join("sub")).unwrap();
    fs::write(dir.join("sub/b.framix"), b"x").unwrap();

    let mut listed = FileStore.list(&dir).unwrap();
    listed.sort();
    let names: Vec<_> = listed
        .iter()
        .map(|(p, _)| p.file_name().unwrap().to_str().unwrap().to_owned())
        .collect();
    // Backups are listed too (callers filter by name); folders are not.
    assert_eq!(names, ["a.framix", "a.framix.bak1"]);
    assert!(
        listed
            .iter()
            .all(|(p, _)| p.parent() == Some(dir.as_path()))
    );
    assert!(listed.iter().all(|(_, at)| *at >= before));
}

#[test]
fn a_missing_folder_is_not_found() {
    let tmp = temp_dir("missing");
    let dir = tmp.join("nope");
    let e = FileStore.list(&dir).unwrap_err();
    assert_eq!(e.kind(), std::io::ErrorKind::NotFound);
}

/// ENG-064: `list` leaves out an entry it can't stat; `list_strict` fails instead.
#[cfg(unix)]
#[test]
fn a_strict_listing_fails_on_an_entry_it_can_not_read() {
    use std::os::unix::fs::PermissionsExt as _;

    let tmp = temp_dir("strict");
    let dir = tmp.join("lib");
    fs::create_dir(&dir).unwrap();
    fs::write(dir.join("a.framix"), b"1").unwrap();
    fs::set_permissions(&dir, fs::Permissions::from_mode(0o444)).unwrap();
    let enforced = fs::symlink_metadata(dir.join("a.framix")).is_err();
    let lenient = FileStore.list(&dir).map(|l| l.len());
    let strict = FileStore.list_strict(&dir).map_err(|e| e.kind());
    fs::set_permissions(&dir, fs::Permissions::from_mode(0o755)).unwrap();

    // Root ignores permissions, so the entry can't be made unreadable there.
    if !enforced {
        eprintln!("skipped: permissions are not enforced for this user");
        return;
    }
    assert_eq!(lenient.unwrap(), 0, "list skips it (Home shows the rest)");
    assert_eq!(strict.unwrap_err(), std::io::ErrorKind::PermissionDenied);
}
