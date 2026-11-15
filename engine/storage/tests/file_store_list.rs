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
