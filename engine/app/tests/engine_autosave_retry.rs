//! Autosave failures and repeated EnableAutosave (P1-038 review).

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::proto::{AddTrack, Command, EnableAutosave, Event, TrackKind, command, event};
use framix_app::store::ProjectStore;

const PATH: &str = "/data/autosave.framix";

/// In-memory files; saves fail while `failing` is set.
#[derive(Clone, Default)]
struct FlakyStore {
    files: Arc<Mutex<HashMap<PathBuf, Vec<u8>>>>,
    failing: Arc<Mutex<bool>>,
}

impl FlakyStore {
    fn fail(&self, on: bool) {
        *self.failing.lock().unwrap() = on;
    }

    fn saved(&self) -> bool {
        self.files.lock().unwrap().contains_key(Path::new(PATH))
    }
}

impl ProjectStore for FlakyStore {
    fn save(&self, path: &Path, bytes: &[u8]) -> io::Result<()> {
        if *self.failing.lock().unwrap() {
            return Err(io::ErrorKind::Interrupted.into());
        }
        self.files
            .lock()
            .unwrap()
            .insert(path.into(), bytes.to_vec());
        Ok(())
    }

    fn load(&self, path: &Path) -> io::Result<Vec<u8>> {
        self.files
            .lock()
            .unwrap()
            .get(path)
            .cloned()
            .ok_or_else(|| io::ErrorKind::NotFound.into())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn enable(engine: &mut Engine) -> Event {
    run(
        engine,
        command::Kind::EnableAutosave(EnableAutosave { path: PATH.into() }),
    )
}

fn add_track(engine: &mut Engine) {
    run(
        engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Audio as i32,
        }),
    );
}

fn failed(e: Option<Event>) -> bool {
    matches!(e.and_then(|e| e.kind), Some(event::Kind::CommandFailed(_)))
}

#[test]
fn a_failed_save_is_retried_without_a_new_edit() {
    let store = FlakyStore::default();
    let mut engine = Engine::with_store(Box::new(store.clone()));
    enable(&mut engine);
    add_track(&mut engine);
    store.fail(true);
    assert!(failed(engine.autosave()));
    store.fail(false);
    assert_eq!(engine.autosave(), None);
    assert!(store.saved(), "the edit reached the file on the next try");
}

#[test]
fn a_lasting_failure_is_reported_once() {
    let store = FlakyStore::default();
    let mut engine = Engine::with_store(Box::new(store.clone()));
    enable(&mut engine);
    store.fail(true);
    add_track(&mut engine);
    assert!(failed(engine.autosave()));
    assert_eq!(engine.autosave(), None, "same failure, no new report");
    add_track(&mut engine);
    assert_eq!(engine.autosave(), None, "still failing, still quiet");
    store.fail(false);
    assert_eq!(engine.autosave(), None);
    store.fail(true);
    add_track(&mut engine);
    assert!(
        failed(engine.autosave()),
        "a new failure after a success is reported"
    );
}

#[test]
fn enabling_again_keeps_the_live_project() {
    let store = FlakyStore::default();
    let mut engine = Engine::with_store(Box::new(store.clone()));
    enable(&mut engine);
    add_track(&mut engine);
    engine.autosave();
    add_track(&mut engine);
    match enable(&mut engine).kind {
        Some(event::Kind::TimelineChanged(t)) => {
            assert_eq!(t.tracks.len(), 2, "the unsaved edit stays");
            assert!(t.can_undo, "undo stays");
        }
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn ids_after_recovery_do_not_collide() {
    let store = FlakyStore::default();
    let mut first = Engine::with_store(Box::new(store.clone()));
    enable(&mut first);
    add_track(&mut first);
    first.autosave();
    let mut second = Engine::with_store(Box::new(store.clone()));
    enable(&mut second);
    match run(
        &mut second,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Audio as i32,
        }),
    )
    .kind
    {
        Some(event::Kind::TimelineChanged(t)) => {
            assert_eq!(t.tracks.len(), 2);
            assert_ne!(t.tracks[0].id, t.tracks[1].id);
        }
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

#[test]
fn enabling_for_another_file_is_refused() {
    let store = FlakyStore::default();
    let mut engine = Engine::with_store(Box::new(store));
    enable(&mut engine);
    let other = run(
        &mut engine,
        command::Kind::EnableAutosave(EnableAutosave {
            path: "/data/other.framix".into(),
        }),
    );
    assert!(failed(Some(other)));
}
