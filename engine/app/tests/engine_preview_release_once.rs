//! A texture is released exactly once (P1-055 review): lost on a redraw, then the engine drops.

use std::sync::{Arc, Mutex};

use framix_app::engine::Engine;
use framix_app::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use framix_app::proto::{Command, CreatePreview, ImportMedia, MediaItem, MediaKind, Seek, command};
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

/// Every draw after the first fails on the GPU.
struct Renderer(u32);

impl PreviewRenderer for Renderer {
    fn draw(
        &mut self,
        _: PlatformTexture,
        _: Time,
        _: &mut dyn Iterator<Item = Layer<'_>>,
    ) -> Result<(), DrawError> {
        self.0 += 1;
        if self.0 > 1 {
            return Err(DrawError::Gpu("lost".into()));
        }
        Ok(())
    }
}

fn run(engine: &mut Engine, kind: command::Kind) {
    engine.handle(Command {
        id: 0,
        kind: Some(kind),
    });
}

#[test]
fn a_lost_texture_is_not_released_again_when_the_engine_drops() {
    let released = Arc::new(Mutex::new(Vec::new()));
    let mut engine =
        Engine::default().with_preview(Box::new(Host(released.clone())), Box::new(Renderer(0)));
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
    run(
        &mut engine,
        command::Kind::Seek(Seek {
            time: TICKS_PER_SECOND,
            snap_within: 0,
        }),
    );
    assert!(engine.flush_preview().is_some(), "PreviewLost");
    drop(engine);
    assert_eq!(*released.lock().unwrap(), vec![1]);
}
