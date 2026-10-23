//! ReplaceClip (P1-031).

use std::io;
use std::path::Path;
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::project::decode;
use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, ReplaceClip, SaveProject, SetClipTransform,
    TimelineChanged, Undo, command, event,
};
use framix_app::store::ProjectStore;

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn changed(e: Event) -> TimelineChanged {
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t,
        other => panic!("expected TimelineChanged, got {other:?}"),
    }
}

fn item(uri: &str, ms: i64) -> MediaItem {
    MediaItem {
        uri: uri.into(),
        kind: MediaKind::Video as i32,
        duration_value: ms,
        duration_timescale: 1000,
        width: 1080,
        height: 1920,
        rotation: 0,
        codec: String::new(),
    }
}

fn replace(clip_id: u64, media: MediaItem) -> command::Kind {
    command::Kind::ReplaceClip(ReplaceClip {
        clip_id,
        media: Some(media),
    })
}

fn setup() -> (Engine, u64, u64) {
    let mut engine = Engine::default();
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![item("content://media/external/video/1", 3000)],
        }),
    ));
    let c = &t.tracks[0].clips[0];
    let (clip, media) = (c.id, c.media_id);
    run(
        &mut engine,
        command::Kind::SetClipTransform(SetClipTransform {
            clip_id: clip,
            rotation: 90,
            ..Default::default()
        }),
    );
    (engine, clip, media)
}

#[test]
fn replace_is_one_undo_step() {
    let (mut engine, clip, old) = setup();
    let t = changed(run(
        &mut engine,
        replace(clip, item("content://media/external/video/2", 5000)),
    ));
    let c = &t.tracks[0].clips[0];
    assert_ne!(c.media_id, old);
    assert_eq!(c.rotation, 0, "the transform resets");
    let t = changed(run(&mut engine, command::Kind::Undo(Undo {})));
    let c = &t.tracks[0].clips[0];
    assert_eq!((c.media_id, c.rotation), (old, 90));
}

#[test]
fn bad_media_is_refused() {
    let (mut engine, clip, _) = setup();
    for bad in [
        item("../../etc/passwd", 5000),
        item("content://media/external/video/3", 1000),
    ] {
        let e = run(&mut engine, replace(clip, bad));
        assert!(matches!(e.kind, Some(event::Kind::CommandFailed(_))));
    }
    let missing = run(
        &mut engine,
        command::Kind::ReplaceClip(ReplaceClip {
            clip_id: clip,
            media: None,
        }),
    );
    assert!(matches!(missing.kind, Some(event::Kind::CommandFailed(_))));
}

/// Keeps saved bytes in memory.
struct Mem(Arc<Mutex<Vec<u8>>>);

impl ProjectStore for Mem {
    fn save(&self, _: &Path, bytes: &[u8]) -> io::Result<()> {
        *self.0.lock().unwrap() = bytes.to_vec();
        Ok(())
    }
    fn load(&self, _: &Path) -> io::Result<Vec<u8>> {
        Ok(self.0.lock().unwrap().clone())
    }
}

#[test]
fn the_replacement_is_saved() {
    let saved = Arc::new(Mutex::new(Vec::new()));
    let mut engine = Engine::with_store(Box::new(Mem(saved.clone())));
    let t = changed(run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![item("content://media/external/video/1", 3000)],
        }),
    ));
    let clip = t.tracks[0].clips[0].id;
    run(
        &mut engine,
        replace(clip, item("content://media/external/video/2", 5000)),
    );
    let e = run(
        &mut engine,
        command::Kind::SaveProject(SaveProject {
            path: "p.framix".into(),
        }),
    );
    assert!(matches!(e.kind, Some(event::Kind::ProjectSaved(_))));
    let tl = decode(&saved.lock().unwrap()).unwrap();
    let c = tl.tracks()[0].clips()[0];
    assert_eq!(
        tl.media(c.media).unwrap().uri(),
        "content://media/external/video/2"
    );
}
