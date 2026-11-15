//! P1-053: with the draw on the render thread, a GPU loss arrives after the draw returned.
//! The engine then drops the shown texture once, reports PreviewLost once, and stops drawing.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{
    Command, CreatePreview, ImportMedia, MediaItem, MediaKind, PreviewLost, Seek, command, event,
};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::Layer;

struct Host(Arc<Mutex<Vec<i64>>>);

impl PreviewHost for Host {
    fn create_texture(&self, _: u32, _: u32) -> Result<(), String> {
        Ok(())
    }
    fn frame_available(&self, _: i64) {}
    fn release_texture(&self, texture: PlatformTexture) {
        self.0.lock().unwrap().push(texture.id);
    }
}

/// Every draw returns at once; how it went is reported later.
struct Queued(Arc<Mutex<u32>>);

impl PreviewRenderer for Queued {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        *self.0.lock().unwrap() += 1;
        Ok(())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    });
}

fn seek(engine: &mut Engine, seconds: i64) {
    run(
        engine,
        command::Kind::Seek(Seek {
            time: seconds * TICKS_PER_SECOND,
            snap_within: 0,
        }),
    );
}

fn shown(released: Arc<Mutex<Vec<i64>>>, draws: Arc<Mutex<u32>>) -> Engine {
    let mut engine =
        Engine::default().with_preview(Box::new(Host(released)), Box::new(Queued(draws)));
    run(
        &mut engine,
        command::Kind::ImportMedia(ImportMedia {
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
        }),
    );
    run(
        &mut engine,
        command::Kind::CreatePreview(CreatePreview {
            width: 64,
            height: 64,
        }),
    );
    engine.preview_texture_ready(Ok(PlatformTexture { id: 1, handle: 1 }));
    engine
}

#[test]
fn a_loss_reported_after_the_draw_releases_the_texture_and_reports_preview_lost_once() {
    let released = Arc::new(Mutex::new(Vec::new()));
    let draws = Arc::new(Mutex::new(0));
    let mut engine = shown(released.clone(), draws.clone());
    seek(&mut engine, 1);
    engine.preview_draw_lost(1);
    assert_eq!(*released.lock().unwrap(), vec![1]);
    let lost = engine.flush_preview().expect("PreviewLost");
    assert_eq!(
        lost.kind,
        Some(event::Kind::PreviewLost(PreviewLost { texture_id: 1 }))
    );
    assert_eq!(engine.flush_preview(), None, "reported once");
    let before = *draws.lock().unwrap();
    seek(&mut engine, 2);
    assert_eq!(*draws.lock().unwrap(), before, "a lost preview is not drawn");
    drop(engine);
    assert_eq!(*released.lock().unwrap(), vec![1], "released once");
}

#[test]
fn a_loss_of_a_texture_no_longer_shown_is_ignored() {
    let released = Arc::new(Mutex::new(Vec::new()));
    let draws = Arc::new(Mutex::new(0));
    let mut engine = shown(released.clone(), draws.clone());
    engine.preview_draw_lost(99);
    assert_eq!(engine.flush_preview(), None);
    assert!(released.lock().unwrap().is_empty());
    let before = *draws.lock().unwrap();
    seek(&mut engine, 1);
    assert_eq!(*draws.lock().unwrap(), before + 1, "still drawing");
}
