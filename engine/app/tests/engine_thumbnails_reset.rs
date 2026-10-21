//! Thumbnail scheduling across a refused start and a project change (P1-021 review).

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::proto::{
    Command, Event, ImportMedia, MediaItem, MediaKind, NewProject, RequestThumbnails, command,
    event,
};
use framix_app::thumbnail::{ThumbnailHost, ThumbnailRequest};

type Requests = Arc<Mutex<Vec<ThumbnailRequest>>>;

/// Refuses while `down` is set (no platform yet), then records requests.
struct Host {
    down: Arc<AtomicBool>,
    seen: Requests,
}

impl ThumbnailHost for Host {
    fn request(&self, request: ThumbnailRequest) -> Result<(), String> {
        if self.down.load(Ordering::SeqCst) {
            return Err("no platform".into());
        }
        self.seen.lock().unwrap().push(request);
        Ok(())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) -> Event {
    engine.handle(Command { kind: Some(kind) })
}

fn import(engine: &mut Engine) -> u64 {
    let e = run(
        engine,
        command::Kind::ImportMedia(ImportMedia {
            items: vec![MediaItem {
                uri: "content://media/external/video/1".into(),
                kind: MediaKind::Video as i32,
                duration_value: 4000,
                duration_timescale: 1000,
                width: 1080,
                height: 1920,
                rotation: 0,
                codec: String::new(),
            }],
        }),
    );
    match e.kind {
        Some(event::Kind::TimelineChanged(t)) => t.tracks[0].clips[0].media_id,
        other => panic!("{other:?}"),
    }
}

fn ask(engine: &mut Engine, media_id: u64) -> Event {
    run(
        engine,
        command::Kind::RequestThumbnails(RequestThumbnails {
            media_id,
            times: vec![0],
            max_side: 96,
        }),
    )
}

fn setup() -> (Engine, Arc<AtomicBool>, Requests) {
    let down = Arc::new(AtomicBool::new(false));
    let seen = Requests::default();
    let engine = Engine::default().with_thumbnails(Box::new(Host {
        down: down.clone(),
        seen: seen.clone(),
    }));
    (engine, down, seen)
}

#[test]
fn a_refused_request_fails_and_is_asked_again_later() {
    let (mut engine, down, seen) = setup();
    let media = import(&mut engine);
    down.store(true, Ordering::SeqCst);
    assert!(matches!(
        ask(&mut engine, media).kind,
        Some(event::Kind::CommandFailed(_))
    ));
    down.store(false, Ordering::SeqCst);
    assert!(matches!(
        ask(&mut engine, media).kind,
        Some(event::Kind::CommandAccepted(_))
    ));
    assert_eq!(
        seen.lock().unwrap().len(),
        1,
        "the platform was asked again"
    );
}

#[test]
fn a_new_project_forgets_the_old_thumbnails() {
    let (mut engine, _, seen) = setup();
    let old = import(&mut engine);
    ask(&mut engine, old);
    let old_key = seen.lock().unwrap()[0].key;

    run(&mut engine, command::Kind::NewProject(NewProject {}));
    let new = import(&mut engine);
    assert_eq!(new, old, "ids restart, so the keys look the same");
    ask(&mut engine, new);
    assert_eq!(
        seen.lock().unwrap().len(),
        2,
        "the new media is made, not skipped"
    );

    // The old project's answer arrives late: it must not show up as the new media's frame.
    assert!(
        engine
            .thumbnail_ready(old_key, Ok("/old.jpg".into()))
            .is_none()
    );
    let new_key = seen.lock().unwrap()[1].key;
    assert!(
        engine
            .thumbnail_ready(new_key, Ok("/new.jpg".into()))
            .is_some()
    );
}
