//! ENG-052: InsertClip must refer to media registered in the project. A clip on unknown media
//! would make every later save fail with UnknownMedia.
use std::io;
use std::path::Path;

use framix_app::engine::Engine;
use framix_app::proto::{
    AddTrack, Command, Event, ImportMedia, InsertClip, MediaItem, MediaKind, SaveProject,
    TimelineChanged, TrackKind, command, event,
};
use framix_app::store::ProjectStore;

/// Accepts every write; nothing is ever there to read.
struct SinkStore;

impl ProjectStore for SinkStore {
    fn save(&self, _: &Path, _: &[u8]) -> io::Result<()> {
        Ok(())
    }

    fn load(&self, _: &Path) -> io::Result<Vec<u8>> {
        Err(io::ErrorKind::NotFound.into())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn insert(track_id: u64, media_id: u64, start: i64) -> command::Kind {
    command::Kind::InsertClip(InsertClip {
        track_id,
        media_id,
        source_start: 0,
        start,
        duration: 100,
    })
}

fn save(engine: &mut Engine) -> Event {
    run(
        engine,
        command::Kind::SaveProject(SaveProject {
            path: "/p/a.framix".into(),
        }),
    )
}

fn video() -> MediaItem {
    MediaItem {
        uri: "media/a.mp4".into(),
        kind: MediaKind::Video as i32,
        duration_value: 4000,
        duration_timescale: 1000,
        width: 1920,
        height: 1080,
        ..Default::default()
    }
}

#[test]
fn insert_clip_on_unregistered_media_is_refused_and_the_project_stays_saveable() {
    let mut engine = Engine::with_store(Box::new(SinkStore));
    let t = changed(run(
        &mut engine,
        command::Kind::AddTrack(AddTrack {
            kind: TrackKind::Video as i32,
        }),
    ));
    let track = t.tracks[0].id;

    let e = run(&mut engine, insert(track, 9999, 0));
    assert!(
        matches!(e.kind, Some(event::Kind::CommandFailed(_))),
        "a clip on unknown media must be refused: {e:?}"
    );
    let saved = save(&mut engine);
    assert!(
        matches!(saved.kind, Some(event::Kind::ProjectSaved(_))),
        "{saved:?}"
    );
}

#[test]
fn insert_clip_on_imported_media_still_works() {
    let mut engine = Engine::with_store(Box::new(SinkStore));
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![video()],
        }),
    ));
    let (track, media, end) = (t.tracks[0].id, t.tracks[0].clips[0].media_id, t.duration);
    let t = changed(run(&mut engine, insert(track, media, end)));
    assert_eq!(t.tracks[0].clips.len(), 2);
    let saved = save(&mut engine);
    assert!(
        matches!(saved.kind, Some(event::Kind::ProjectSaved(_))),
        "{saved:?}"
    );
}
