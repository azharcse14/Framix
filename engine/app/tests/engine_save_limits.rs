//! P1-009 review: the engine must never write a project file it would refuse to open.
use std::io;
use std::path::Path;
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::project::MAX_TRACKS;
use framix_app::proto::{AddTrack, Command, SaveProject, TrackKind, command, event};
use framix_app::store::ProjectStore;

#[derive(Clone, Default)]
struct CountingStore(Arc<Mutex<usize>>);

impl ProjectStore for CountingStore {
    fn save(&self, _: &Path, _: &[u8]) -> io::Result<()> {
        *self.0.lock().unwrap() += 1;
        Ok(())
    }

    fn load(&self, _: &Path) -> io::Result<Vec<u8>> {
        Err(io::ErrorKind::NotFound.into())
    }
}

#[test]
fn saving_more_than_the_open_limits_fails_without_writing() {
    let store = CountingStore::default();
    let mut engine = Engine::with_store(Box::new(store.clone()));
    for _ in 0..=MAX_TRACKS {
        let kind = Some(command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }));
        engine.handle(Command { kind });
    }
    let saved = engine.handle(Command {
        kind: Some(command::Kind::SaveProject(SaveProject {
            path: "/p/big.framix".into(),
        })),
    });
    assert!(
        matches!(saved.kind, Some(event::Kind::CommandFailed(_))),
        "{saved:?}"
    );
    assert_eq!(*store.0.lock().unwrap(), 0, "nothing may be written");
}
