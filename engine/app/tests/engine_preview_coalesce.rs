//! P1-053: queued Seeks draw once for the latest position (handle_deferred + flush_preview),
//! and a preview lost on the GPU is reported once as PreviewLost instead of going quiet.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, Event, ImportMedia, MediaItem, MediaKind, PreviewLost, Seek, command,
    event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::Layer;

const SECOND: i64 = TICKS_PER_SECOND;

struct Host;

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
}

/// Records the time of every draw; fails with a GPU error while `dead` is set.
#[derive(Clone, Default)]
struct Gpu {
    draws: Arc<Mutex<Vec<Time>>>,
    dead: Arc<Mutex<bool>>,
}

impl PreviewRenderer for Gpu {
    fn draw(&mut self, _: PlatformTexture, time: Time, _: Option<&Layer>) -> Result<(), DrawError> {
        self.draws.lock().unwrap().push(time);
        match *self.dead.lock().unwrap() {
            true => Err(DrawError::Gpu("device lost".into())),
            false => Ok(()),
        }
    }
}

fn command(kind: command::Kind) -> Command {
    Command {
        id: 0,
        kind: Some(kind),
    }
}

fn seek(time: i64) -> Command {
    command(command::Kind::Seek(Seek {
        time,
        snap_within: 0,
    }))
}

fn playhead(e: Event) -> i64 {
    match e.kind {
        Some(event::Kind::PlayheadChanged(p)) => p.time,
        other => panic!("expected PlayheadChanged, got {other:?}"),
    }
}

/// An engine with a 4 s video and a shown preview (texture 7) drawn once at 0.
fn engine_with_preview(gpu: &Gpu) -> Engine {
    let mut engine = Engine::default().with_preview(Box::new(Host), Box::new(gpu.clone()));
    engine.handle(command(command::Kind::ImportMedia(ImportMedia {
        items: vec![MediaItem {
            color: 0,
            uri: "content://media/external/video/0".into(),
            kind: MediaKind::Video as i32,
            duration_value: 4000,
            duration_timescale: 1000,
            width: 1080,
            height: 1920,
            rotation: 0,
            codec: "avc1".into(),
        }],
    })));
    show_preview(&mut engine, 7);
    engine
}

fn show_preview(engine: &mut Engine, id: i64) {
    engine.handle(command(command::Kind::CreatePreview(CreatePreview {
        width: 64,
        height: 64,
    })));
    let ready = engine.preview_texture_ready(Ok(PlatformTexture { id, handle: 1 }));
    assert!(matches!(ready.kind, Some(event::Kind::PreviewReady(_))));
}

#[test]
fn queued_seeks_draw_once_for_the_latest_position() {
    let gpu = Gpu::default();
    let mut engine = engine_with_preview(&gpu);
    gpu.draws.lock().unwrap().clear();
    for t in 1..=3 {
        // Every Seek is still answered with its own playhead.
        assert_eq!(
            playhead(engine.handle_deferred(seek(t * SECOND))),
            t * SECOND
        );
    }
    assert!(
        gpu.draws.lock().unwrap().is_empty(),
        "deferred seeks must not draw"
    );
    assert_eq!(
        engine.flush_preview(),
        None,
        "a working preview reports nothing"
    );
    assert_eq!(*gpu.draws.lock().unwrap(), vec![Time(3 * SECOND)]);
    assert_eq!(engine.flush_preview(), None);
    assert_eq!(
        gpu.draws.lock().unwrap().len(),
        1,
        "nothing stale: a second flush draws nothing"
    );
}

#[test]
fn a_preview_lost_on_the_gpu_is_reported_once() {
    let gpu = Gpu::default();
    let mut engine = engine_with_preview(&gpu);
    *gpu.dead.lock().unwrap() = true;
    engine.handle_deferred(seek(SECOND));
    let lost = engine.flush_preview();
    assert_eq!(
        lost,
        Some(Event {
            kind: Some(event::Kind::PreviewLost(PreviewLost { texture_id: 7 })),
        })
    );
    engine.handle_deferred(seek(2 * SECOND));
    assert_eq!(engine.flush_preview(), None, "reported once, never redrawn");
}

#[test]
fn an_eager_redraw_that_loses_the_preview_is_reported_at_the_next_flush() {
    let gpu = Gpu::default();
    let mut engine = engine_with_preview(&gpu);
    *gpu.dead.lock().unwrap() = true;
    assert_eq!(playhead(engine.handle(seek(SECOND))), SECOND);
    assert!(matches!(
        engine.flush_preview().and_then(|e| e.kind),
        Some(event::Kind::PreviewLost(PreviewLost { texture_id: 7 }))
    ));
}

#[test]
fn a_new_preview_after_a_loss_redraws_again() {
    let gpu = Gpu::default();
    let mut engine = engine_with_preview(&gpu);
    *gpu.dead.lock().unwrap() = true;
    engine.handle_deferred(seek(SECOND));
    assert!(engine.flush_preview().is_some());
    *gpu.dead.lock().unwrap() = false;
    show_preview(&mut engine, 8);
    gpu.draws.lock().unwrap().clear();
    engine.handle_deferred(seek(2 * SECOND));
    assert_eq!(engine.flush_preview(), None);
    assert_eq!(*gpu.draws.lock().unwrap(), vec![Time(2 * SECOND)]);
}
